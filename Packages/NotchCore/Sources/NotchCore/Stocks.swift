import Foundation

public struct StockQuote: Codable, Equatable, Sendable, Identifiable {
    public var symbol: String
    public var price: Double
    public var change: Double
    public var changePercent: Double
    public var fetchedAt: Date

    public var id: String { symbol }
    public var isUp: Bool { change >= 0 }

    public init(symbol: String, price: Double, change: Double, changePercent: Double, fetchedAt: Date) {
        self.symbol = symbol
        self.price = price
        self.change = change
        self.changePercent = changePercent
        self.fetchedAt = fetchedAt
    }
}

public enum StockSymbol {
    /// Upper-cases and checks a ticker ("aapl" → "AAPL", "BRK.B", "RELIANCE.NS").
    public static func normalize(_ input: String) -> String? {
        let symbol = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-^:=")
        guard (1...20).contains(symbol.count), symbol.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return symbol
    }
}

/// Finnhub (finnhub.io) quotes with the user's own free API key.
public enum Finnhub {
    public static func quoteURL(symbol: String, token: String) -> URL? {
        var components = URLComponents(string: "https://finnhub.io/api/v1/quote")
        components?.queryItems = [
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "token", value: token),
        ]
        return components?.url
    }

    /// Nil for unknown symbols, which Finnhub answers with all zeros.
    public static func decodeQuote(_ data: Data, symbol: String, fetchedAt: Date) throws -> StockQuote? {
        struct Response: Decodable {
            let c: Double?
            let d: Double?
            let dp: Double?
            let pc: Double?
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard let price = response.c, price != 0 || (response.pc ?? 0) != 0 else { return nil }
        return StockQuote(
            symbol: symbol,
            price: price,
            change: response.d ?? 0,
            changePercent: response.dp ?? 0,
            fetchedAt: fetchedAt
        )
    }
}
