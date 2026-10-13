import NotchCore
import SwiftUI

// MARK: Stocks

struct StocksPanel: View {
    @ObservedObject var stocks: StocksService
    @ObservedObject var settings: AppSettings
    let onOpenSettings: () -> Void

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
                StocksContent(
                    symbols: Array(settings.stockSymbols.prefix(StocksService.maxSymbols)),
                    quotes: stocks.quotes,
                    problem: stocks.problem
                )
            }
        }
        .onAppear { stocks.beginViewing() }
        .onDisappear { stocks.endViewing() }
    }
}

/// One row per ticker: symbol, price, and the day's change as a coloured
/// badge. From plain values so it can also be drawn with sample data.
struct StocksContent: View {
    let symbols: [String]
    let quotes: [String: StockQuote]
    let problem: String?

    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: NotchStyle.Space.s) {
            if symbols.count <= NotchStyle.Stocks.rowsWithoutScrolling || isSnapshot {
                VStack(spacing: 0) { rows }
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) { rows }
                }
            }
            if let problem {
                Text(problem)
                    .font(NotchStyle.Font.caption)
                    .foregroundStyle(NotchStyle.Palette.overdue)
            }
        }
    }

    private var rows: some View {
        ForEach(symbols, id: \.self) { symbol in
            QuoteRow(symbol: symbol, quote: quotes[symbol])
        }
    }
}

private struct QuoteRow: View {
    let symbol: String
    let quote: StockQuote?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: NotchStyle.Space.m) {
            Text(symbol)
                .font(NotchStyle.Font.title)
                .foregroundStyle(NotchStyle.Palette.primaryText)
                .lineLimit(1)
            Spacer(minLength: NotchStyle.Space.s)
            Text(quote.map { ConversionFormat.string($0.price) } ?? "–")
                .font(NotchStyle.Font.title)
                .monospacedDigit()
                .foregroundStyle(NotchStyle.Palette.primaryText)
                .lineLimit(1)
            Text(changeText)
                .font(NotchStyle.Font.chip.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(quote == nil ? NotchStyle.Palette.secondaryText : NotchStyle.Palette.background)
                .frame(width: NotchStyle.Stocks.badgeWidth, height: NotchStyle.Chip.height)
                .background(
                    RoundedRectangle(cornerRadius: NotchStyle.Tab.radius, style: .continuous)
                        .fill(badgeFill)
                )
        }
        .padding(.horizontal, NotchStyle.Space.s)
        .padding(.vertical, NotchStyle.Space.xs + 1)
        .background(
            RoundedRectangle(cornerRadius: NotchStyle.Clipboard.rowRadius, style: .continuous)
                .fill(isHovered ? NotchStyle.Palette.rowBackground : Color.clear)
        )
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
    }

    private var changeText: String {
        guard let quote else { return "–" }
        return String(format: "%@%.2f%%", quote.isUp ? "+" : "", quote.changePercent)
    }

    private var badgeFill: Color {
        guard let quote else { return NotchStyle.Palette.rowBackground }
        return quote.isUp ? NotchStyle.Palette.gain : NotchStyle.Palette.overdue
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
                RevenueContent(
                    sources: settings.revenueSources,
                    states: revenue.states,
                    combined: revenue.combined,
                    onRefresh: { revenue.refreshAll() }
                )
            }
        }
        .onAppear { revenue.beginViewing() }
        .onDisappear { revenue.endViewing() }
    }
}

/// Today's total, large, on the left; each store on the right. From plain
/// values so it can also be drawn with sample data.
struct RevenueContent: View {
    let sources: [RevenueSource]
    let states: [UUID: RevenueService.SourceState]
    let combined: MoneyTotals
    let onRefresh: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: NotchStyle.Space.xl) {
            VStack(alignment: .leading, spacing: NotchStyle.Space.xxs) {
                Text("Today")
                    .font(NotchStyle.Font.title)
                    .foregroundStyle(NotchStyle.Palette.secondaryText)
                if combined.minorUnits.isEmpty {
                    Text(states.values.contains(.loading) ? "…" : "No sales yet")
                        .font(NotchStyle.Font.display)
                        .foregroundStyle(NotchStyle.Palette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                } else {
                    ForEach(combined.currencies, id: \.self) { code in
                        Text(CurrencyMath.format(minor: combined.minorUnits[code] ?? 0, currency: code))
                            .font(combined.currencies.count == 1 ? NotchStyle.Font.hero : NotchStyle.Font.display)
                            .tracking(-1)
                            .foregroundStyle(NotchStyle.Palette.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                }
                Text(combined.orderCount == 1 ? "1 sale" : "\(combined.orderCount) sales")
                    .font(NotchStyle.Font.subtitle)
                    .foregroundStyle(NotchStyle.Palette.secondaryText)
                Spacer(minLength: 0)
                Button(action: onRefresh) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(ChipButtonStyle())
            }
            .frame(width: NotchStyle.Revenue.totalWidth, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .top)

            VStack(spacing: 0) {
                ForEach(sources) { source in
                    SourceRow(source: source, state: states[source.id])
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

private struct SourceRow: View {
    let source: RevenueSource
    let state: RevenueService.SourceState?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: NotchStyle.Space.m) {
            VStack(alignment: .leading, spacing: 0) {
                Text(source.name)
                    .font(NotchStyle.Font.rowTitle)
                    .foregroundStyle(NotchStyle.Palette.primaryText)
                    .lineLimit(1)
                Text(source.provider.title)
                    .font(NotchStyle.Font.caption)
                    .foregroundStyle(NotchStyle.Palette.tertiaryText)
            }
            Spacer()
            Text(valueText)
                .font(NotchStyle.Font.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(isFailure ? NotchStyle.Palette.overdue : NotchStyle.Palette.primaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, NotchStyle.Space.s)
        .padding(.vertical, NotchStyle.Space.xs + 1)
        .background(
            RoundedRectangle(cornerRadius: NotchStyle.Clipboard.rowRadius, style: .continuous)
                .fill(isHovered ? NotchStyle.Palette.rowBackground : Color.clear)
        )
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
    }

    private var valueText: String {
        switch state {
        case .loaded(let totals):
            if totals.minorUnits.isEmpty { return "No sales" }
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
