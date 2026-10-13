import Foundation

/// Payment and store services the Revenue tool can read today's sales from.
public enum RevenueProvider: String, CaseIterable, Codable, Identifiable, Sendable {
    case stripe
    case shopify
    case lemonSqueezy
    case gumroad
    case paddle
    case polar
    case dodo

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .stripe: return "Stripe"
        case .shopify: return "Shopify"
        case .lemonSqueezy: return "Lemon Squeezy"
        case .gumroad: return "Gumroad"
        case .paddle: return "Paddle"
        case .polar: return "Polar"
        case .dodo: return "Dodo Payments"
        }
    }

    /// What to paste, in the provider's own words.
    public var keyHint: String {
        switch self {
        case .stripe: return "Restricted key with Charges: Read (rk_live_…)"
        case .shopify: return "Admin API access token with read_orders (shpat_…)"
        case .lemonSqueezy: return "API key (Settings › API)"
        case .gumroad: return "Access token (Settings › Advanced › Applications)"
        case .paddle: return "API key with transaction read permission"
        case .polar: return "Organization access token with orders:read"
        case .dodo: return "API key (live mode)"
        }
    }

    public var needsShopDomain: Bool { self == .shopify }
}

public struct RevenueSource: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var provider: RevenueProvider
    public var name: String
    /// Shopify only: "your-store.myshopify.com".
    public var shopDomain: String?

    public init(id: UUID = UUID(), provider: RevenueProvider, name: String, shopDomain: String? = nil) {
        self.id = id
        self.provider = provider
        self.name = name
        self.shopDomain = shopDomain
    }
}

/// Money per currency, in minor units (cents). Different currencies are
/// never added together.
public struct MoneyTotals: Equatable, Sendable {
    public private(set) var minorUnits: [String: Int] = [:]
    public private(set) var orderCount = 0

    public init() {}

    public mutating func add(_ minor: Int, currency: String) {
        let code = currency.uppercased()
        minorUnits[code, default: 0] += minor
        orderCount += 1
    }

    public var currencies: [String] { minorUnits.keys.sorted() }

    public static func + (lhs: MoneyTotals, rhs: MoneyTotals) -> MoneyTotals {
        var result = lhs
        for (code, value) in rhs.minorUnits { result.minorUnits[code, default: 0] += value }
        result.orderCount += rhs.orderCount
        return result
    }
}

public enum CurrencyMath {
    /// Decimal places per ISO 4217 currency (most use 2).
    public static func exponent(for currency: String) -> Int {
        switch currency.uppercased() {
        case "JPY", "KRW", "VND", "CLP", "ISK", "UGX", "XAF", "XOF", "PYG", "RWF", "KMF", "GNF", "VUV", "XPF", "BIF", "DJF":
            return 0
        case "BHD", "KWD", "OMR", "JOD", "TND", "IQD", "LYD":
            return 3
        default:
            return 2
        }
    }

    /// "12.34" USD → 1234.
    public static func minorUnits(fromDecimal text: String, currency: String) -> Int? {
        guard let decimal = Decimal(string: text.trimmingCharacters(in: .whitespaces), locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        var scaled = decimal * pow(Decimal(10), exponent(for: currency))
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return NSDecimalNumber(decimal: rounded).intValue
    }

    public static func format(minor: Int, currency: String, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        let value = Decimal(minor) / pow(Decimal(10), exponent(for: currency))
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "\(currency) \(value)"
    }
}

/// Requests and parsing for each provider: one page of up to 100 recent
/// orders, counting only successful sales since `since`.
///
/// Stripe and Shopify follow their documented APIs closely. The others are
/// written from their public docs and should be checked with a real key.
public enum RevenueAPI {
    public enum Failure: Error, Equatable {
        case missingShopDomain
        case unauthorized
        case server(Int)
    }

    public static func request(for source: RevenueSource, key: String, since: Date) throws -> URLRequest {
        let unix = Int(since.timeIntervalSince1970)
        let iso = ISO8601DateFormatter().string(from: since)
        var request: URLRequest
        switch source.provider {
        case .stripe:
            request = URLRequest(url: URL(string: "https://api.stripe.com/v1/charges?limit=100&created%5Bgte%5D=\(unix)")!)
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .shopify:
            guard let domain = source.shopDomain.flatMap(normalizedShopDomain) else { throw Failure.missingShopDomain }
            var components = URLComponents(string: "https://\(domain)/admin/api/2025-01/orders.json")!
            components.queryItems = [
                URLQueryItem(name: "status", value: "any"),
                URLQueryItem(name: "created_at_min", value: iso),
                URLQueryItem(name: "limit", value: "250"),
                URLQueryItem(name: "fields", value: "total_price,currency,financial_status,cancelled_at,created_at"),
            ]
            request = URLRequest(url: components.url!)
            request.setValue(key, forHTTPHeaderField: "X-Shopify-Access-Token")
        case .lemonSqueezy:
            request = URLRequest(url: URL(string: "https://api.lemonsqueezy.com/v1/orders?page%5Bsize%5D=100&sort=-created_at")!)
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.api+json", forHTTPHeaderField: "Accept")
        case .gumroad:
            var components = URLComponents(string: "https://api.gumroad.com/v2/sales")!
            let day = DateFormatter.posixDay.string(from: since.addingTimeInterval(-86_400))
            components.queryItems = [URLQueryItem(name: "after", value: day)]
            request = URLRequest(url: components.url!)
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .paddle:
            var components = URLComponents(string: "https://api.paddle.com/transactions")!
            components.queryItems = [
                URLQueryItem(name: "status", value: "completed,billed"),
                URLQueryItem(name: "created_at[GTE]", value: iso),
                URLQueryItem(name: "per_page", value: "100"),
            ]
            request = URLRequest(url: components.url!)
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .polar:
            request = URLRequest(url: URL(string: "https://api.polar.sh/v1/orders/?limit=100&sorting=-created_at")!)
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .dodo:
            var components = URLComponents(string: "https://live.dodopayments.com/payments")!
            components.queryItems = [
                URLQueryItem(name: "created_at_gte", value: iso),
                URLQueryItem(name: "page_size", value: "100"),
            ]
            request = URLRequest(url: components.url!)
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }
        request.setValue(request.value(forHTTPHeaderField: "Accept") ?? "application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        return request
    }

    public static func parse(_ data: Data, provider: RevenueProvider, since: Date) throws -> MoneyTotals {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return MoneyTotals() }
        var totals = MoneyTotals()
        switch provider {
        case .stripe:
            for charge in list(root["data"]) {
                guard bool(charge["paid"]) == true, string(charge["status"]) == "succeeded",
                      let created = int(charge["created"]), created >= Int(since.timeIntervalSince1970),
                      let amount = int(charge["amount"]), let currency = string(charge["currency"])
                else { continue }
                totals.add(amount - (int(charge["amount_refunded"]) ?? 0), currency: currency)
            }
        case .shopify:
            for order in list(root["orders"]) {
                guard order["cancelled_at"] == nil || order["cancelled_at"] is NSNull,
                      !["refunded", "voided", "pending"].contains(string(order["financial_status"]) ?? ""),
                      let currency = string(order["currency"]),
                      let price = string(order["total_price"]),
                      let minor = CurrencyMath.minorUnits(fromDecimal: price, currency: currency),
                      isOnOrAfter(order["created_at"], since)
                else { continue }
                totals.add(minor, currency: currency)
            }
        case .lemonSqueezy:
            for order in list(root["data"]) {
                let attributes = order["attributes"] as? [String: Any] ?? [:]
                guard string(attributes["status"]) == "paid",
                      isOnOrAfter(attributes["created_at"], since),
                      let total = int(attributes["total"]),
                      let currency = string(attributes["currency"])
                else { continue }
                totals.add(total, currency: currency)
            }
        case .gumroad:
            for sale in list(root["sales"]) {
                guard bool(sale["refunded"]) != true, bool(sale["chargedback"]) != true,
                      isOnOrAfter(sale["created_at"], since),
                      let price = int(sale["price"])
                else { continue }
                totals.add(price, currency: string(sale["currency"]) ?? "USD")
            }
        case .paddle:
            for transaction in list(root["data"]) {
                let details = transaction["details"] as? [String: Any]
                let money = details?["totals"] as? [String: Any]
                guard isOnOrAfter(transaction["created_at"], since),
                      let total = int(money?["grand_total"] ?? money?["total"]),
                      let currency = string(transaction["currency_code"])
                else { continue }
                totals.add(total, currency: currency)
            }
        case .polar:
            for order in list(root["items"]) {
                guard isOnOrAfter(order["created_at"], since),
                      string(order["status"]).map({ $0 == "paid" || $0 == "succeeded" }) ?? true,
                      let amount = int(order["total_amount"] ?? order["amount"]),
                      let currency = string(order["currency"])
                else { continue }
                totals.add(amount, currency: currency)
            }
        case .dodo:
            for payment in list(root["items"]) {
                guard string(payment["status"]) == "succeeded",
                      isOnOrAfter(payment["created_at"], since),
                      let amount = int(payment["total_amount"]),
                      let currency = string(payment["currency"])
                else { continue }
                totals.add(amount, currency: currency)
            }
        }
        return totals
    }

    public static func normalizedShopDomain(_ input: String) -> String? {
        var domain = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for prefix in ["https://", "http://"] where domain.hasPrefix(prefix) {
            domain.removeFirst(prefix.count)
        }
        domain = domain.split(separator: "/").first.map(String.init) ?? ""
        guard !domain.isEmpty else { return nil }
        return domain.contains(".") ? domain : domain + ".myshopify.com"
    }

    // MARK: Loose JSON helpers

    private static func list(_ value: Any?) -> [[String: Any]] {
        value as? [[String: Any]] ?? []
    }

    private static func string(_ value: Any?) -> String? {
        value as? String
    }

    private static func bool(_ value: Any?) -> Bool? {
        value as? Bool
    }

    /// Accepts JSON numbers and numeric strings ("1250").
    private static func int(_ value: Any?) -> Int? {
        if let number = value as? NSNumber {
            // JSON true/false also arrive as NSNumber; don't read them as 1/0.
            guard CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
            return number.intValue
        }
        if let text = value as? String { return Int(text) }
        return nil
    }

    private static func isOnOrAfter(_ value: Any?, _ since: Date) -> Bool {
        guard let text = value as? String else { return false }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = fractional.date(from: text) ?? ISO8601DateFormatter().date(from: text)
            ?? DateFormatter.loose.date(from: text)
        return date.map { $0 >= since } ?? false
    }
}

private extension DateFormatter {
    static let posixDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// "2026-10-13T10:00:00.000000Z" and similar with more than 3 fractional digits.
    static let loose: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX"
        return formatter
    }()
}
