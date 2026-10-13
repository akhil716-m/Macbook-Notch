import AppKit
import Combine
import Sparkle

/// Automatic updates with Sparkle, the standard for Mac apps sold outside
/// the App Store. Updates are signed with an EdDSA key, so only builds you
/// signed can be installed.
///
/// Turns on once `SUFeedURL` and `SUPublicEDKey` are filled in (project.yml).
/// Until then there's nothing to check and the menu item is hidden.
@MainActor
final class UpdateService: ObservableObject {
    @Published private(set) var canCheck = false

    let isConfigured: Bool
    private let controller: SPUStandardUpdaterController?
    private var cancellables = Set<AnyCancellable>()

    init(bundle: Bundle = .main) {
        isConfigured = Self.isConfigured(in: bundle)
        controller = isConfigured
            ? SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
            : nil
        controller?.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                MainActor.assumeIsolated { self?.canCheck = value }
            }
            .store(in: &cancellables)
    }

    var automaticallyChecks: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set {
            controller?.updater.automaticallyChecksForUpdates = newValue
            objectWillChange.send()
        }
    }

    func checkForUpdates() {
        guard let controller else { return }
        // We have no Dock icon; bring ourselves forward so Sparkle's window shows.
        NSApp.activate()
        controller.checkForUpdates(nil)
    }

    /// Both the appcast URL and the signing key are filled in.
    nonisolated static func isConfigured(in bundle: Bundle) -> Bool {
        let feed = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
        let key = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        return !feed.isEmpty && !key.isEmpty
    }

    static var versionDescription: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
