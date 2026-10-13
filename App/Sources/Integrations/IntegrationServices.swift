import Foundation
import NotchCore

/// Stock quotes for a short watchlist, from Finnhub with your own free key.
/// Refreshes once a minute while the Stocks tool is on screen.
@MainActor
final class StocksService: ObservableObject {
    @Published private(set) var quotes: [String: StockQuote] = [:]
    @Published private(set) var hasKey = false
    @Published private(set) var problem: String?

    static let maxSymbols = 8
    private static let keychainService = "app.macbooknotch.stocks"
    private static let keychainAccount = "finnhub"

    private let settings: AppSettings
    private var viewers = 0
    private var timer: Timer?
    private var loading = false

    init(settings: AppSettings) {
        self.settings = settings
        hasKey = Keychain.read(service: Self.keychainService, account: Self.keychainAccount) != nil
    }

    func setKey(_ key: String?) {
        let trimmed = key?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            Keychain.delete(service: Self.keychainService, account: Self.keychainAccount)
        } else {
            try? Keychain.write(Data(trimmed.utf8), service: Self.keychainService, account: Self.keychainAccount)
        }
        hasKey = !trimmed.isEmpty
        quotes = [:]
        problem = nil
        if hasKey { refresh() }
    }

    func beginViewing() {
        viewers += 1
        guard viewers == 1 else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func endViewing() {
        viewers = max(0, viewers - 1)
        guard viewers == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard !loading,
              let data = Keychain.read(service: Self.keychainService, account: Self.keychainAccount),
              let key = String(data: data, encoding: .utf8)
        else { return }
        let symbols = Array(settings.stockSymbols.prefix(Self.maxSymbols))
        loading = true
        Task {
            defer { self.loading = false }
            var problem: String?
            for symbol in symbols {
                guard let url = Finnhub.quoteURL(symbol: symbol, token: key) else { continue }
                do {
                    let (body, response) = try await URLSession.shared.data(from: url)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                    if status == 401 || status == 403 {
                        problem = "Finnhub didn't accept the key."
                        break
                    }
                    if status == 429 {
                        problem = "Finnhub's free limit was hit. Prices update again in a minute."
                        break
                    }
                    if let quote = try Finnhub.decodeQuote(body, symbol: symbol, fetchedAt: Date()) {
                        self.quotes[symbol] = quote
                    }
                } catch {
                    problem = "Couldn't reach Finnhub."
                }
            }
            self.problem = problem
        }
    }
}

/// Today's sales from your stores, using read-only keys you add in Settings.
/// Keys live in the Keychain; only the store's own API is ever called.
@MainActor
final class RevenueService: ObservableObject {
    enum SourceState: Equatable {
        case loading
        case loaded(MoneyTotals)
        case failed(String)
    }

    @Published private(set) var states: [UUID: SourceState] = [:]
    @Published private(set) var lastRefresh: Date?

    private static let keychainService = "app.macbooknotch.revenue"
    private static let refreshInterval: TimeInterval = 15 * 60

    private let settings: AppSettings
    private var viewers = 0
    private var timer: Timer?

    init(settings: AppSettings) {
        self.settings = settings
    }

    var sources: [RevenueSource] { settings.revenueSources }

    /// Everything that loaded, added up per currency.
    var combined: MoneyTotals {
        states.values.reduce(MoneyTotals()) { total, state in
            if case .loaded(let totals) = state { return total + totals }
            return total
        }
    }

    func addSource(_ source: RevenueSource, key: String) {
        try? Keychain.write(Data(key.trimmingCharacters(in: .whitespacesAndNewlines).utf8), service: Self.keychainService, account: source.id.uuidString)
        settings.revenueSources.append(source)
        refresh(source)
    }

    func removeSource(_ source: RevenueSource) {
        Keychain.delete(service: Self.keychainService, account: source.id.uuidString)
        settings.revenueSources.removeAll { $0.id == source.id }
        states[source.id] = nil
    }

    func beginViewing() {
        viewers += 1
        guard viewers == 1 else { return }
        if lastRefresh.map({ Date().timeIntervalSince($0) > 5 * 60 }) ?? true {
            refreshAll()
        }
        timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshAll() }
        }
    }

    func endViewing() {
        viewers = max(0, viewers - 1)
        guard viewers == 0 else { return }
        timer?.invalidate()
        timer = nil
    }

    func refreshAll() {
        lastRefresh = Date()
        for source in sources {
            refresh(source)
        }
    }

    private func refresh(_ source: RevenueSource) {
        guard let data = Keychain.read(service: Self.keychainService, account: source.id.uuidString),
              let key = String(data: data, encoding: .utf8)
        else {
            states[source.id] = .failed("No key saved")
            return
        }
        let since = Calendar.current.startOfDay(for: Date())
        states[source.id] = .loading
        Task {
            do {
                let request = try RevenueAPI.request(for: source, key: key, since: since)
                let (body, response) = try await URLSession.shared.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                switch status {
                case 200..<300:
                    self.states[source.id] = .loaded(try RevenueAPI.parse(body, provider: source.provider, since: since))
                case 401, 403:
                    self.states[source.id] = .failed("Key rejected")
                default:
                    self.states[source.id] = .failed("Error \(status)")
                }
            } catch RevenueAPI.Failure.missingShopDomain {
                self.states[source.id] = .failed("Shop domain missing")
            } catch {
                self.states[source.id] = .failed("Couldn't connect")
            }
        }
    }
}
