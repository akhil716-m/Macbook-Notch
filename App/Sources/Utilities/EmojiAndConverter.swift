import AppKit
import NotchCore
import SwiftUI

// MARK: Emoji

/// The Emoji tool: search by name, click to copy. Recent ones come first.
struct EmojiPanel: View {
    @ObservedObject var settings: AppSettings
    @State private var query = ""
    @State private var copied: String?

    private let columns = [GridItem(.adaptive(minimum: NotchStyle.Emoji.cell), spacing: NotchStyle.Space.xxs)]

    var body: some View {
        VStack(alignment: .leading, spacing: NotchStyle.Space.s) {
            HStack(spacing: NotchStyle.Space.s) {
                TextField("Search emoji", text: $query)
                    .textFieldStyle(.plain)
                    .font(NotchStyle.Font.body)
                    .padding(.horizontal, NotchStyle.Space.m)
                    .frame(height: NotchStyle.Chip.height + NotchStyle.Space.xs)
                    .background(
                        RoundedRectangle(cornerRadius: NotchStyle.Clipboard.rowRadius, style: .continuous)
                            .fill(NotchStyle.Palette.rowBackground)
                    )
                if let copied {
                    Text("Copied \(copied)")
                        .font(NotchStyle.Font.caption)
                        .foregroundStyle(NotchStyle.Palette.secondaryText)
                        .transition(.opacity)
                }
            }
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: NotchStyle.Space.xxs) {
                    ForEach(items) { item in
                        Button {
                            copy(item.character)
                        } label: {
                            Text(item.character)
                                .font(.system(size: NotchStyle.Emoji.size))
                                .frame(width: NotchStyle.Emoji.cell, height: NotchStyle.Emoji.cell)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(item.name.capitalized)
                        .accessibilityLabel(item.name)
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: copied)
    }

    private var items: [EmojiItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return EmojiCatalog.search(trimmed) }
        let recents = settings.recentEmoji.map { EmojiItem(character: $0, name: "recently used") }
        let recentSet = Set(settings.recentEmoji)
        return recents + EmojiCatalog.all.filter { !recentSet.contains($0.character) }
    }

    private func copy(_ character: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(character, forType: .string)
        settings.recentEmoji = EmojiCatalog.recordingUse(of: character, in: settings.recentEmoji)
        copied = character
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            if copied == character { copied = nil }
        }
    }
}

// MARK: Converter

/// Exchange rates for the converter: refreshed at most twice a day.
@MainActor
final class CurrencyService: ObservableObject {
    @Published private(set) var rates: CurrencyRates?
    @Published private(set) var failed = false

    private let cache: LocalFile<CurrencyRates>
    private var loading = false
    private static let maxAge: TimeInterval = 12 * 3_600

    init(cacheURL: URL) {
        cache = LocalFile(url: cacheURL)
        rates = cache.load()
    }

    func refreshIfNeeded() {
        guard !loading, rates == nil || rates?.isStale(at: Date(), maxAge: Self.maxAge) == true,
              let url = CurrencyRates.frankfurterURL(base: "USD")
        else { return }
        loading = true
        Task {
            defer { self.loading = false }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let fresh = try CurrencyRates.decodeFrankfurter(data, fetchedAt: Date())
                self.rates = fresh
                self.cache.save(fresh)
                self.failed = false
            } catch {
                self.failed = true
            }
        }
    }
}

/// The Converter tool: units and currencies.
struct ConverterPanel: View {
    @ObservedObject var currency: CurrencyService
    @AppStorage("converter.category") private var categoryRaw = ConversionCategory.length.rawValue
    @AppStorage("converter.from") private var fromID = ""
    @AppStorage("converter.to") private var toID = ""
    @State private var input = "1"

    var body: some View {
        let category = ConversionCategory(rawValue: categoryRaw) ?? .length
        let (from, to) = pair(for: category)
        VStack(alignment: .leading, spacing: NotchStyle.Space.s) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NotchStyle.Space.xs) {
                    ForEach(ConversionCategory.allCases) { option in
                        Button(option.title) { select(option) }
                            .buttonStyle(ChipButtonStyle(isProminent: option == category))
                    }
                }
            }
            HStack(spacing: NotchStyle.Space.m) {
                TextField("Amount", text: $input)
                    .textFieldStyle(.plain)
                    .font(NotchStyle.Font.countdown)
                    .padding(.horizontal, NotchStyle.Space.m)
                    .frame(width: NotchStyle.Converter.inputWidth, height: NotchStyle.Chip.height + NotchStyle.Space.s)
                    .background(
                        RoundedRectangle(cornerRadius: NotchStyle.Clipboard.rowRadius, style: .continuous)
                            .fill(NotchStyle.Palette.rowBackground)
                    )
                unitMenu(selected: from, in: category) { fromID = $0.id }
                IconButton(symbol: "arrow.left.arrow.right", label: "Swap units") {
                    fromID = to.id
                    toID = from.id
                }
                unitMenu(selected: to, in: category) { toID = $0.id }
            }
            HStack(alignment: .firstTextBaseline, spacing: NotchStyle.Space.s) {
                Text(result(from: from, to: to, category: category))
                    .font(NotchStyle.Weather.temperature)
                    .foregroundStyle(NotchStyle.Palette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .textSelection(.enabled)
                Text(to.symbol)
                    .font(NotchStyle.Font.subtitle)
                    .foregroundStyle(NotchStyle.Palette.secondaryText)
            }
            if category == .currency {
                Text(currencyNote)
                    .font(NotchStyle.Font.caption)
                    .foregroundStyle(NotchStyle.Palette.secondaryText)
            }
        }
        .onAppear {
            if category == .currency { currency.refreshIfNeeded() }
        }
    }

    private func pair(for category: ConversionCategory) -> (ConversionUnit, ConversionUnit) {
        let defaults = UnitCatalog.defaultPair(for: category)
        let from = UnitCatalog.unit(id: fromID).flatMap { $0.category == category ? $0 : nil } ?? defaults.0
        let to = UnitCatalog.unit(id: toID).flatMap { $0.category == category ? $0 : nil } ?? defaults.1
        return (from, to)
    }

    private func select(_ category: ConversionCategory) {
        categoryRaw = category.rawValue
        let defaults = UnitCatalog.defaultPair(for: category)
        fromID = defaults.0.id
        toID = defaults.1.id
        if category == .currency { currency.refreshIfNeeded() }
    }

    private func unitMenu(selected: ConversionUnit, in category: ConversionCategory, choose: @escaping (ConversionUnit) -> Void) -> some View {
        Menu {
            ForEach(UnitCatalog.units(for: category)) { unit in
                Button("\(unit.name) (\(unit.symbol))") { choose(unit) }
            }
        } label: {
            Text(category == .currency ? selected.symbol : selected.name)
                .font(NotchStyle.Font.body)
                .foregroundStyle(NotchStyle.Palette.primaryText)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func result(from: ConversionUnit, to: ConversionUnit, category: ConversionCategory) -> String {
        guard let value = NumberInput.parse(input) else { return "–" }
        if category == .currency {
            guard let rates = currency.rates,
                  let converted = rates.convert(value, from: from.symbol, to: to.symbol)
            else { return "–" }
            return ConversionFormat.string(converted)
        }
        guard let converted = UnitCatalog.convert(value, from: from, to: to) else { return "–" }
        return ConversionFormat.string(converted)
    }

    private var currencyNote: String {
        if let rates = currency.rates {
            return "European Central Bank rates from \(rates.date)" + (currency.failed ? " (offline)" : "")
        }
        return currency.failed ? "Couldn't load exchange rates. Check your connection." : "Loading exchange rates…"
    }
}
