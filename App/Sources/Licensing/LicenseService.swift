import AppKit
import NotchCore

/// One-time licence keys through Lemon Squeezy: up to 3 Macs per key (set
/// on the product in Lemon Squeezy), and the app keeps working offline for a
/// month between checks.
///
/// Licensing switches on once the store and product IDs are filled in
/// (`MNLicenseStoreID`, `MNLicenseProductID` in project.yml). Until then
/// every build counts as licensed, so development isn't blocked.
@MainActor
final class LicenseService: ObservableObject {
    @Published private(set) var record: LicenseRecord?
    @Published private(set) var standing: LicenseStanding = .unlicensed
    @Published private(set) var isWorking = false
    @Published private(set) var message: String?

    let storeID: Int
    let productID: Int
    let purchaseURL: URL?

    private static let keychainService = "app.macbooknotch.licence"
    private static let keychainAccount = "licence"

    init(bundle: Bundle = .main) {
        storeID = Self.int(bundle, "MNLicenseStoreID")
        productID = Self.int(bundle, "MNLicenseProductID")
        let purchase = bundle.object(forInfoDictionaryKey: "MNPurchaseURL") as? String ?? ""
        purchaseURL = purchase.isEmpty ? nil : URL(string: purchase)
    }

    /// Whether this build enforces licensing at all.
    var isConfigured: Bool { storeID > 0 && productID > 0 }

    /// Whether the tools are usable right now.
    var allowsUse: Bool { !isConfigured || standing.allowsUse }

    func start() {
        record = Keychain.read(service: Self.keychainService, account: Self.keychainAccount)
            .flatMap { try? JSONDecoder().decode(LicenseRecord.self, from: $0) }
        updateStanding()
        if standing == .needsCheck || standing == .graceExpired {
            validate()
        }
    }

    // MARK: Actions

    func activate(key rawKey: String) {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !isWorking else { return }
        let name = Host.current().localizedName ?? "Mac"
        perform(.activate, fields: ["license_key": key, "instance_name": name]) { response in
            guard response.succeeded, let instanceID = response.instanceID else {
                self.message = response.error ?? "That key didn't work."
                return
            }
            guard response.isFor(storeID: self.storeID, productID: self.productID) else {
                self.message = "That key is for a different product."
                return
            }
            let now = Date()
            self.save(LicenseRecord(
                key: key,
                instanceID: instanceID,
                instanceName: name,
                productName: response.productName,
                activatedAt: now,
                lastValidatedAt: now
            ))
            self.message = "Activated. Thank you!"
        }
    }

    /// Frees this Mac's slot so the key can be used on another Mac.
    func deactivate() {
        guard let record, !isWorking else { return }
        perform(.deactivate, fields: ["license_key": record.key, "instance_id": record.instanceID]) { response in
            if response.succeeded || response.error?.lowercased().contains("not found") == true {
                self.clear()
                self.message = "This Mac is deactivated. You can use the key on another Mac."
            } else {
                self.message = response.error ?? "Couldn't deactivate. Try again when you're online."
            }
        }
    }

    /// Quietly confirms the licence with the store. Network trouble never
    /// takes a licence away; only the store saying "invalid" does.
    func validate() {
        guard var current = record, !isWorking else { return }
        perform(.validate, fields: ["license_key": current.key, "instance_id": current.instanceID], quiet: true) { response in
            if response.succeeded, response.isFor(storeID: self.storeID, productID: self.productID) {
                current.lastValidatedAt = Date()
                current.status = .active
            } else {
                current.status = .revoked
                self.message = response.error ?? "This licence is no longer valid."
            }
            self.save(current)
        }
    }

    func buy() {
        if let purchaseURL {
            NSWorkspace.shared.open(purchaseURL)
        }
    }

    // MARK: Plumbing

    private func perform(
        _ action: LemonSqueezy.Action,
        fields: [String: String],
        quiet: Bool = false,
        then handle: @escaping @MainActor (LemonSqueezy.Response) -> Void
    ) {
        isWorking = true
        if !quiet { message = nil }
        let request = LemonSqueezy.request(action, fields: fields)
        Task {
            defer { self.isWorking = false }
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                handle(try LemonSqueezy.decode(data, for: action))
            } catch {
                if !quiet {
                    self.message = "Couldn't reach the licence server. Check your connection and try again."
                }
            }
            self.updateStanding()
        }
    }

    private func save(_ record: LicenseRecord) {
        self.record = record
        if let data = try? JSONEncoder().encode(record) {
            try? Keychain.write(data, service: Self.keychainService, account: Self.keychainAccount)
        }
        updateStanding()
    }

    private func clear() {
        record = nil
        Keychain.delete(service: Self.keychainService, account: Self.keychainAccount)
        updateStanding()
    }

    private func updateStanding() {
        standing = LicensePolicy.standing(record, now: Date())
    }

    private static func int(_ bundle: Bundle, _ key: String) -> Int {
        if let number = bundle.object(forInfoDictionaryKey: key) as? NSNumber { return number.intValue }
        if let string = bundle.object(forInfoDictionaryKey: key) as? String { return Int(string) ?? 0 }
        return 0
    }
}
