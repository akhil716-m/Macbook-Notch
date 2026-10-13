import Foundation

/// A licence activated on this Mac. Stored in the Keychain.
public struct LicenseRecord: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Sendable {
        case active
        /// The store said no: refunded, disabled, or deactivated elsewhere.
        case revoked
    }

    public var key: String
    public var instanceID: String
    public var instanceName: String
    public var productName: String?
    public var activatedAt: Date
    /// Last time the store confirmed the licence.
    public var lastValidatedAt: Date
    public var status: Status

    public init(
        key: String,
        instanceID: String,
        instanceName: String,
        productName: String?,
        activatedAt: Date,
        lastValidatedAt: Date,
        status: Status = .active
    ) {
        self.key = key
        self.instanceID = instanceID
        self.instanceName = instanceName
        self.productName = productName
        self.activatedAt = activatedAt
        self.lastValidatedAt = lastValidatedAt
        self.status = status
    }

    /// "XXXX-…-1A2B" for showing on screen.
    public var maskedKey: String {
        guard key.count > 8 else { return String(repeating: "•", count: key.count) }
        return String(key.prefix(4)) + "…" + String(key.suffix(4))
    }
}

public enum LicenseStanding: Equatable, Sendable {
    case unlicensed
    case licensed
    /// Licensed, but due for a quiet check with the store.
    case needsCheck
    /// No successful check for too long (offline for a month).
    case graceExpired
    case revoked

    /// Whether the app's tools are usable.
    public var allowsUse: Bool {
        switch self {
        case .licensed, .needsCheck: return true
        case .unlicensed, .graceExpired, .revoked: return false
        }
    }
}

public enum LicensePolicy {
    /// Check with the store about once a week.
    public static let recheckAfter: TimeInterval = 7 * 24 * 3_600
    /// Keep working offline for a month after the last good check.
    public static let offlineGrace: TimeInterval = 30 * 24 * 3_600

    public static func standing(_ record: LicenseRecord?, now: Date) -> LicenseStanding {
        guard let record else { return .unlicensed }
        if record.status == .revoked { return .revoked }
        let age = now.timeIntervalSince(record.lastValidatedAt)
        if age > offlineGrace { return .graceExpired }
        if age > recheckAfter { return .needsCheck }
        return .licensed
    }
}

/// Lemon Squeezy's License API: activate, validate, deactivate.
/// https://docs.lemonsqueezy.com/api/license-api
public enum LemonSqueezy {
    public enum Action: String, Sendable {
        case activate
        case validate
        case deactivate
    }

    public static let baseURL = URL(string: "https://api.lemonsqueezy.com/v1/licenses/")!

    public static func request(_ action: Action, fields: [String: String]) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(action.rawValue))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formBody(fields)
        request.timeoutInterval = 20
        return request
    }

    /// `a=1&b=2`, keys sorted, values percent-encoded for a form body.
    public static func formBody(_ fields: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let body = fields.sorted { $0.key < $1.key }
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")
        return Data(body.utf8)
    }

    public struct Response: Equatable, Sendable {
        /// `activated`, `valid` or `deactivated`, whichever the action returns.
        public var succeeded: Bool
        public var error: String?
        public var licenseStatus: String?
        public var instanceID: String?
        public var storeID: Int?
        public var productID: Int?
        public var productName: String?

        /// The key belongs to our product, not any other Lemon Squeezy store.
        public func isFor(storeID expectedStore: Int, productID expectedProduct: Int) -> Bool {
            storeID == expectedStore && productID == expectedProduct
        }
    }

    public static func decode(_ data: Data, for action: Action) throws -> Response {
        let raw = try JSONDecoder().decode(RawResponse.self, from: data)
        let succeeded: Bool
        switch action {
        case .activate: succeeded = raw.activated ?? false
        case .validate: succeeded = raw.valid ?? false
        case .deactivate: succeeded = raw.deactivated ?? false
        }
        return Response(
            succeeded: succeeded,
            error: raw.error,
            licenseStatus: raw.licenseKey?.status,
            instanceID: raw.instance?.id,
            storeID: raw.meta?.storeID,
            productID: raw.meta?.productID,
            productName: raw.meta?.productName
        )
    }

    private struct RawResponse: Decodable {
        let activated: Bool?
        let valid: Bool?
        let deactivated: Bool?
        let error: String?
        let licenseKey: LicenseKey?
        let instance: Instance?
        let meta: Meta?

        enum CodingKeys: String, CodingKey {
            case activated, valid, deactivated, error, instance, meta
            case licenseKey = "license_key"
        }

        struct LicenseKey: Decodable {
            let status: String?
        }

        struct Instance: Decodable {
            let id: String?
        }

        struct Meta: Decodable {
            let storeID: Int?
            let productID: Int?
            let productName: String?

            enum CodingKeys: String, CodingKey {
                case storeID = "store_id"
                case productID = "product_id"
                case productName = "product_name"
            }
        }
    }
}
