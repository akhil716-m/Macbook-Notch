import NotchCore
import SwiftUI

// MARK: Stocks

struct StocksPanel: View {
    @ObservedObject var stocks: StocksService
    @ObservedObject var settings: AppSettings
    let onOpenSettings: () -> Void

    private let columns = [GridItem(.adaptive(minimum: NotchStyle.Stocks.cardWidth), spacing: NotchStyle.Space.s)]

    var body: some View {
        Group {
            if !stocks.hasKey {
                PermissionPrompt(
                    symbol: "chart.line.uptrend.xyaxis",
                    title: "Add a Finnhub key",
                    message: "Stocks uses your own free key from finnhub.io. Add it in Settings › Integrations.",
                    buttonTitle: "Open Settings",
                    action: onOpenSettings
                )
            } else if settings.stockSymbols.isEmpty {
                PermissionPrompt(
                    symbol: "chart.line.uptrend.xyaxis",
                    title: "No symbols yet",
                    message: "Add tickers like AAPL or RELIANCE.NS in Settings › Integrations.",
                    buttonTitle: "Open Settings",
                    action: onOpenSettings
                )
            } else {
                VStack(alignment: .leading, spacing: NotchStyle.Space.s) {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: NotchStyle.Space.s) {
                        ForEach(settings.stockSymbols.prefix(StocksService.maxSymbols), id: \.self) { symbol in
                            QuoteCard(symbol: symbol, quote: stocks.quotes[symbol])
                        }
                    }
                    if let problem = stocks.problem {
                        Text(problem)
                            .font(NotchStyle.Font.caption)
                            .foregroundStyle(NotchStyle.Palette.overdue)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .onAppear { stocks.beginViewing() }
        .onDisappear { stocks.endViewing() }
    }
}

private struct QuoteCard: View {
    let symbol: String
    let quote: StockQuote?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(symbol)
                .font(NotchStyle.Font.caption)
                .foregroundStyle(NotchStyle.Palette.secondaryText)
                .lineLimit(1)
            Text(quote.map { ConversionFormat.string($0.price) } ?? "–")
                .font(NotchStyle.Font.statValue)
                .foregroundStyle(NotchStyle.Palette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let quote {
                Text(String(format: "%@%.2f%%", quote.isUp ? "+" : "", quote.changePercent))
                    .font(NotchStyle.Font.caption)
                    .foregroundStyle(quote.isUp ? NotchStyle.Palette.gain : NotchStyle.Palette.overdue)
            }
        }
        .padding(NotchStyle.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: NotchStyle.Clipboard.rowRadius, style: .continuous)
                .fill(NotchStyle.Palette.rowBackground)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: Revenue

struct RevenuePanel: View {
    @ObservedObject var revenue: RevenueService
    @ObservedObject var settings: AppSettings
    let onOpenSettings: () -> Void

    var body: some View {
        Group {
            if settings.revenueSources.isEmpty {
                PermissionPrompt(
                    symbol: "dollarsign.circle",
                    title: "See today's sales here",
                    message: "Connect Stripe, Shopify, Lemon Squeezy, Gumroad, Paddle, Polar or Dodo with a read-only key in Settings › Integrations.",
                    buttonTitle: "Open Settings",
                    action: onOpenSettings
                )
            } else {
                HStack(alignment: .top, spacing: NotchStyle.Space.l) {
                    VStack(alignment: .leading, spacing: NotchStyle.Space.xxs) {
                        Text("TODAY")
                            .font(NotchStyle.Font.caption)
                            .foregroundStyle(NotchStyle.Palette.secondaryText)
                        let combined = revenue.combined
                        if combined.minorUnits.isEmpty {
                            Text(revenue.states.values.contains(.loading) ? "…" : "No sales yet")
                                .font(NotchStyle.Font.statValue)
                                .foregroundStyle(NotchStyle.Palette.primaryText)
                        } else {
                            ForEach(combined.currencies, id: \.self) { code in
                                Text(CurrencyMath.format(minor: combined.minorUnits[code] ?? 0, currency: code))
                                    .font(NotchStyle.Font.display)
                                    .foregroundStyle(NotchStyle.Palette.primaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                            }
                        }
                        Text(combined.orderCount == 1 ? "1 sale" : "\(combined.orderCount) sales")
                            .font(NotchStyle.Font.caption)
                            .foregroundStyle(NotchStyle.Palette.secondaryText)
                    }
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: NotchStyle.Space.xxs) {
                            ForEach(settings.revenueSources) { source in
                                SourceRow(source: source, state: revenue.states[source.id])
                            }
                        }
                    }
                    IconButton(symbol: "arrow.clockwise", label: "Refresh") { revenue.refreshAll() }
                }
            }
        }
        .onAppear { revenue.beginViewing() }
        .onDisappear { revenue.endViewing() }
    }
}

private struct SourceRow: View {
    let source: RevenueSource
    let state: RevenueService.SourceState?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text(source.name)
                    .font(NotchStyle.Font.rowTitle)
                    .foregroundStyle(NotchStyle.Palette.primaryText)
                    .lineLimit(1)
                Text(source.provider.title)
                    .font(NotchStyle.Font.caption)
                    .foregroundStyle(NotchStyle.Palette.secondaryText)
            }
            Spacer()
            Text(valueText)
                .font(NotchStyle.Font.caption)
                .foregroundStyle(isFailure ? NotchStyle.Palette.overdue : NotchStyle.Palette.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, NotchStyle.Space.m)
        .padding(.vertical, NotchStyle.Space.xs)
        .background(
            RoundedRectangle(cornerRadius: NotchStyle.Clipboard.rowRadius, style: .continuous)
                .fill(NotchStyle.Palette.rowBackground)
        )
    }

    private var valueText: String {
        switch state {
        case .loaded(let totals):
            if totals.minorUnits.isEmpty { return "0 sales" }
            return totals.currencies
                .map { CurrencyMath.format(minor: totals.minorUnits[$0] ?? 0, currency: $0) }
                .joined(separator: " + ")
        case .failed(let message):
            return message
        case .loading, .none:
            return "…"
        }
    }

    private var isFailure: Bool {
        if case .failed = state { return true }
        return false
    }
}

// MARK: Settings

/// Settings › Integrations: the keys for Stocks and Revenue.
struct IntegrationsSettings: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var stocks: StocksService
    @ObservedObject var revenue: RevenueService

    @State private var finnhubKey = ""
    @State private var newSymbol = ""
    @State private var provider: RevenueProvider = .stripe
    @State private var sourceName = ""
    @State private var shopDomain = ""
    @State private var sourceKey = ""

    var body: some View {
        Form {
            Section {
                if stocks.hasKey {
                    LabeledContent("Finnhub key", value: "Saved in Keychain")
                    Button("Remove Key", role: .destructive) { stocks.setKey(nil) }
                } else {
                    SecureField("Finnhub API key", text: $finnhubKey)
                    Button("Save Key") {
                        stocks.setKey(finnhubKey)
                        finnhubKey = ""
                    }
                    .disabled(finnhubKey.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ForEach(settings.stockSymbols, id: \.self) { symbol in
                    HStack {
                        Text(symbol)
                        Spacer()
                        Button {
                            settings.stockSymbols.removeAll { $0 == symbol }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remove \(symbol)")
                    }
                }
                HStack {
                    TextField("Add a ticker (AAPL, RELIANCE.NS)", text: $newSymbol)
                        .onSubmit { addSymbol() }
                    Button("Add") { addSymbol() }
                        .disabled(StockSymbol.normalize(newSymbol) == nil || settings.stockSymbols.count >= StocksService.maxSymbols)
                }
            } header: {
                Text("Stocks")
            } footer: {
                Text("Get a free key at finnhub.io. Up to \(StocksService.maxSymbols) tickers; prices refresh once a minute while the Stocks tool is open.")
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(settings.revenueSources) { source in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(source.name)
                            Text(source.provider.title).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            revenue.removeSource(source)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remove \(source.name)")
                    }
                }
                Picker("Service", selection: $provider) {
                    ForEach(RevenueProvider.allCases) { Text($0.title).tag($0) }
                }
                TextField("Name (e.g. My App)", text: $sourceName)
                if provider.needsShopDomain {
                    TextField("Shop domain (your-store.myshopify.com)", text: $shopDomain)
                }
                SecureField(provider.keyHint, text: $sourceKey)
                Button("Add Source") { addSource() }
                    .disabled(!canAddSource)
            } header: {
                Text("Revenue")
            } footer: {
                Text("Use read-only keys where the service offers them. Keys are kept in your Keychain and only sent to that service.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var canAddSource: Bool {
        !sourceKey.trimmingCharacters(in: .whitespaces).isEmpty
            && (!provider.needsShopDomain || RevenueAPI.normalizedShopDomain(shopDomain) != nil)
    }

    private func addSymbol() {
        guard let symbol = StockSymbol.normalize(newSymbol),
              !settings.stockSymbols.contains(symbol),
              settings.stockSymbols.count < StocksService.maxSymbols
        else { return }
        settings.stockSymbols.append(symbol)
        newSymbol = ""
        stocks.refresh()
    }

    private func addSource() {
        let name = sourceName.trimmingCharacters(in: .whitespaces)
        let source = RevenueSource(
            provider: provider,
            name: name.isEmpty ? provider.title : name,
            shopDomain: provider.needsShopDomain ? RevenueAPI.normalizedShopDomain(shopDomain) : nil
        )
        revenue.addSource(source, key: sourceKey)
        sourceName = ""
        shopDomain = ""
        sourceKey = ""
    }
}
