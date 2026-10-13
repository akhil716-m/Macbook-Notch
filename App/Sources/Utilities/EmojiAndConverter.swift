import AppKit
import NotchCore
import SwiftUI

// MARK: Emoji

/// The Emoji tool: search by name, click to copy. Recent ones come first.
struct EmojiPanel: View {
    @ObservedObject var settings: AppSettings
    @State private var query = ""
    @State private var copied: String?

    var body: some View {
        EmojiContent(
            query: $query,
            recent: settings.recentEmoji,
            results: results,
            copied: copied,
            onCopy: { copy($0) }
        )
        .animation(.easeOut(duration: 0.15), value: copied)
    }

    private var results: [EmojiItem] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return EmojiCatalog.search(trimmed) }
        let recentSet = Set(settings.recentEmoji)
        return EmojiCatalog.all.filter { !recentSet.contains($0.character) }
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

/// Search, your recent emoji large, then everything else. From plain values
/// so it can also be drawn with sample data.
struct EmojiContent: View {
    @Binding var query: String
    let recent: [String]
    let results: [EmojiItem]
    let copied: String?
    let onCopy: (String) -> Void

    @Environment(\.isSnapshot) private var isSnapshot

    private let columns = [GridItem(.adaptive(minimum: NotchStyle.Emoji.cell), spacing: NotchStyle.Space.xxs)]

    var body: some View {
        VStack(alignment: .leading, spacing: NotchStyle.Space.s) {
            HStack(spacing: NotchStyle.Space.s) {
                NotchTextField(placeholder: "Search emoji", text: $query, symbol: "magnifyingglass", onSubmit: {
                    if let first = results.first { onCopy(first.character) }
                })
                if let copied {
                    Label("Copied \(copied)", systemImage: "checkmark")
                        .font(NotchStyle.Font.chip)
                        .foregroundStyle(NotchStyle.Palette.primaryText)
                        .transition(.opacity)
                }
            }
            if query.isEmpty && !recent.isEmpty {
                HStack(spacing: NotchStyle.Space.xs) {
                    ForEach(recent.prefix(NotchStyle.Emoji.recentCount), id: \.self) { character in
                        EmojiCell(character: character, name: "Recently used", size: NotchStyle.Emoji.recentSize,
                                  cell: NotchStyle.Emoji.recentCell, onCopy: onCopy)
                    }
                }
                .padding(NotchStyle.Space.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NotchCardBackground())
            }
            if results.isEmpty {
                Text("No emoji match \u{201C}\(query)\u{201D}.")
                    .font(NotchStyle.Font.body)
                    .foregroundStyle(NotchStyle.Palette.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isSnapshot {
                grid.frame(maxHeight: .infinity, alignment: .top).clipped()
            } else {
                ScrollView(.vertical, showsIndicators: false) { grid }
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: NotchStyle.Space.xxs) {
            ForEach(results) { item in
                EmojiCell(character: item.character, name: item.name, size: NotchStyle.Emoji.size,
                          cell: NotchStyle.Emoji.cell, onCopy: onCopy)
            }
        }
    }
}

private struct EmojiCell: View {
    let character: String
    let name: String
    let size: CGFloat
    let cell: CGFloat
    let onCopy: (String) -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            onCopy(character)
        } label: {
            Text(character)
                .font(.system(size: size))
                .frame(width: cell, height: cell)
                .background(
                    RoundedRectangle(cornerRadius: NotchStyle.Tab.radius, style: .continuous)
                        .fill(isHovered ? NotchStyle.Palette.selection : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(name.capitalized)
        .accessibilityLabel(name)
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
        VStack(spacing: NotchStyle.Space.m) {
            SegmentedPicker(
                options: ConversionCategory.allCases,
                selection: Binding(get: { category }, set: { select($0) }),
                title: \.title
            )
            HStack(spacing: NotchStyle.Space.m) {
                VStack(spacing: NotchStyle.Space.s) {
                    TextField("Amount", text: $input)
                        .textFieldStyle(.plain)
                        .font(NotchStyle.Font.display)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("Amount in \(from.name)")
                    unitMenu(selected: from, in: category) { fromID = $0.id }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .notchCard()

                IconButton(symbol: "arrow.left.arrow.right", label: "Swap units") {
                    fromID = to.id
                    toID = from.id
                }

                VStack(spacing: NotchStyle.Space.s) {
                    Text(result(from: from, to: to, category: category))
                        .font(NotchStyle.Font.display)
                        .foregroundStyle(NotchStyle.Palette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .textSelection(.enabled)
                    unitMenu(selected: to, in: category) { toID = $0.id }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .notchCard()
            }
            if category == .currency {
                Text(currencyNote)
                    .font(NotchStyle.Font.caption)
                    .foregroundStyle(NotchStyle.Palette.tertiaryText)
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
        .padding(.horizontal, NotchStyle.Chip.horizontalPadding)
        .frame(height: NotchStyle.Chip.height)
        .background(Capsule().fill(NotchStyle.Palette.selection))
        .accessibilityLabel(category == .currency ? "Currency" : "Unit")
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
