import Foundation

public enum ConversionCategory: String, CaseIterable, Identifiable, Sendable {
    case length
    case mass
    case temperature
    case volume
    case speed
    case data
    case currency

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .length: return "Length"
        case .mass: return "Weight"
        case .temperature: return "Temperature"
        case .volume: return "Volume"
        case .speed: return "Speed"
        case .data: return "Data"
        case .currency: return "Currency"
        }
    }
}

public struct ConversionUnit: Hashable, Identifiable, Sendable {
    /// e.g. "length.km", or "currency.EUR".
    public let id: String
    public let name: String
    public let symbol: String
    public let category: ConversionCategory

    public init(id: String, name: String, symbol: String, category: ConversionCategory) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.category = category
    }
}

/// Units the converter offers, backed by Foundation's `Measurement`.
public enum UnitCatalog {
    private struct Entry {
        let key: String
        let name: String
        let unit: Dimension
    }

    private static let entries: [ConversionCategory: [Entry]] = [
        .length: [
            Entry(key: "km", name: "Kilometres", unit: UnitLength.kilometers),
            Entry(key: "m", name: "Metres", unit: UnitLength.meters),
            Entry(key: "cm", name: "Centimetres", unit: UnitLength.centimeters),
            Entry(key: "mm", name: "Millimetres", unit: UnitLength.millimeters),
            Entry(key: "mi", name: "Miles", unit: UnitLength.miles),
            Entry(key: "yd", name: "Yards", unit: UnitLength.yards),
            Entry(key: "ft", name: "Feet", unit: UnitLength.feet),
            Entry(key: "in", name: "Inches", unit: UnitLength.inches),
            Entry(key: "nmi", name: "Nautical miles", unit: UnitLength.nauticalMiles),
        ],
        .mass: [
            Entry(key: "kg", name: "Kilograms", unit: UnitMass.kilograms),
            Entry(key: "g", name: "Grams", unit: UnitMass.grams),
            Entry(key: "mg", name: "Milligrams", unit: UnitMass.milligrams),
            Entry(key: "t", name: "Tonnes", unit: UnitMass.metricTons),
            Entry(key: "lb", name: "Pounds", unit: UnitMass.pounds),
            Entry(key: "oz", name: "Ounces", unit: UnitMass.ounces),
            Entry(key: "st", name: "Stones", unit: UnitMass.stones),
        ],
        .temperature: [
            Entry(key: "c", name: "Celsius", unit: UnitTemperature.celsius),
            Entry(key: "f", name: "Fahrenheit", unit: UnitTemperature.fahrenheit),
            Entry(key: "k", name: "Kelvin", unit: UnitTemperature.kelvin),
        ],
        .volume: [
            Entry(key: "l", name: "Litres", unit: UnitVolume.liters),
            Entry(key: "ml", name: "Millilitres", unit: UnitVolume.milliliters),
            Entry(key: "gal", name: "US gallons", unit: UnitVolume.gallons),
            Entry(key: "qt", name: "US quarts", unit: UnitVolume.quarts),
            Entry(key: "pt", name: "US pints", unit: UnitVolume.pints),
            Entry(key: "cup", name: "US cups", unit: UnitVolume.cups),
            Entry(key: "floz", name: "US fluid ounces", unit: UnitVolume.fluidOunces),
            Entry(key: "tbsp", name: "Tablespoons", unit: UnitVolume.tablespoons),
            Entry(key: "tsp", name: "Teaspoons", unit: UnitVolume.teaspoons),
        ],
        .speed: [
            Entry(key: "kmh", name: "Km per hour", unit: UnitSpeed.kilometersPerHour),
            Entry(key: "mph", name: "Miles per hour", unit: UnitSpeed.milesPerHour),
            Entry(key: "ms", name: "Metres per second", unit: UnitSpeed.metersPerSecond),
            Entry(key: "kn", name: "Knots", unit: UnitSpeed.knots),
        ],
        .data: [
            Entry(key: "b", name: "Bytes", unit: UnitInformationStorage.bytes),
            Entry(key: "kb", name: "Kilobytes", unit: UnitInformationStorage.kilobytes),
            Entry(key: "mb", name: "Megabytes", unit: UnitInformationStorage.megabytes),
            Entry(key: "gb", name: "Gigabytes", unit: UnitInformationStorage.gigabytes),
            Entry(key: "tb", name: "Terabytes", unit: UnitInformationStorage.terabytes),
            Entry(key: "mbit", name: "Megabits", unit: UnitInformationStorage.megabits),
        ],
    ]

    /// Currencies the European Central Bank publishes rates for (via Frankfurter).
    public static let currencyCodes = [
        "USD", "EUR", "GBP", "INR", "JPY", "CNY", "AUD", "CAD", "CHF", "SGD", "HKD", "SEK", "NOK",
        "DKK", "NZD", "KRW", "BRL", "MXN", "ZAR", "TRY", "PLN", "THB", "IDR", "MYR", "PHP", "ILS",
        "CZK", "HUF", "RON", "ISK", "BGN",
    ]

    public static func units(for category: ConversionCategory) -> [ConversionUnit] {
        if category == .currency {
            return currencyCodes.map { code in
                let name = Locale(identifier: "en_US").localizedString(forCurrencyCode: code) ?? code
                return ConversionUnit(id: "currency.\(code)", name: name, symbol: code, category: .currency)
            }
        }
        return (entries[category] ?? []).map {
            ConversionUnit(id: "\(category.rawValue).\($0.key)", name: $0.name, symbol: $0.unit.symbol, category: category)
        }
    }

    public static func unit(id: String) -> ConversionUnit? {
        guard let raw = id.split(separator: ".").first, let category = ConversionCategory(rawValue: String(raw)) else {
            return nil
        }
        return units(for: category).first { $0.id == id }
    }

    /// A sensible pair to start with.
    public static func defaultPair(for category: ConversionCategory) -> (ConversionUnit, ConversionUnit) {
        let all = units(for: category)
        let preferred: [ConversionCategory: (String, String)] = [
            .length: ("length.km", "length.mi"),
            .mass: ("mass.kg", "mass.lb"),
            .temperature: ("temperature.c", "temperature.f"),
            .volume: ("volume.l", "volume.gal"),
            .speed: ("speed.kmh", "speed.mph"),
            .data: ("data.gb", "data.mb"),
            .currency: ("currency.USD", "currency.INR"),
        ]
        let pair = preferred[category]
        let from = all.first { $0.id == pair?.0 } ?? all[0]
        let to = all.first { $0.id == pair?.1 } ?? all[min(1, all.count - 1)]
        return (from, to)
    }

    /// Converts between two units of the same physical category. Currency
    /// needs rates, see `CurrencyRates`.
    public static func convert(_ value: Double, from: ConversionUnit, to: ConversionUnit) -> Double? {
        guard from.category == to.category, from.category != .currency,
              let source = dimension(for: from), let target = dimension(for: to)
        else { return nil }
        return Measurement(value: value, unit: source).converted(to: target).value
    }

    private static func dimension(for unit: ConversionUnit) -> Dimension? {
        let key = unit.id.split(separator: ".").dropFirst().joined(separator: ".")
        return entries[unit.category]?.first { $0.key == key }?.unit
    }
}

/// Exchange rates against one base currency.
public struct CurrencyRates: Codable, Equatable, Sendable {
    public var base: String
    /// The day the central bank published them, "yyyy-MM-dd".
    public var date: String
    public var rates: [String: Double]
    public var fetchedAt: Date

    public func convert(_ amount: Double, from: String, to: String) -> Double? {
        if from == to { return amount }
        let all = rates.merging([base: 1]) { current, _ in current }
        guard let fromRate = all[from], let toRate = all[to], fromRate > 0 else { return nil }
        return amount / fromRate * toRate
    }

    public func isStale(at date: Date, maxAge: TimeInterval) -> Bool {
        date.timeIntervalSince(fetchedAt) > maxAge
    }

    /// Frankfurter (frankfurter.app): free, no key, European Central Bank data.
    public static func frankfurterURL(base: String) -> URL? {
        URL(string: "https://api.frankfurter.app/latest?from=\(base)")
    }

    public static func decodeFrankfurter(_ data: Data, fetchedAt: Date) throws -> CurrencyRates {
        struct Response: Decodable {
            let base: String
            let date: String
            let rates: [String: Double]
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        return CurrencyRates(base: response.base, date: response.date, rates: response.rates, fetchedAt: fetchedAt)
    }
}

public enum NumberInput {
    /// Reads "1234.5", "1,234.5", "1.234,5", "1 234,5" and "12,5".
    public static func parse(_ text: String) -> Double? {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "_", with: "")
        guard !cleaned.isEmpty else { return nil }
        let lastComma = cleaned.lastIndex(of: ",")
        let lastDot = cleaned.lastIndex(of: ".")
        switch (lastComma, lastDot) {
        case let (comma?, dot?):
            // Whichever comes last is the decimal mark.
            if comma > dot {
                cleaned = cleaned.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else {
                cleaned = cleaned.replacingOccurrences(of: ",", with: "")
            }
        case (_?, nil):
            // Several commas, or one followed by exactly three digits, are
            // thousands separators ("1,234,567", "1,234"). Otherwise it's a
            // decimal comma ("12,5").
            let parts = cleaned.split(separator: ",", omittingEmptySubsequences: false)
            let isGrouping = parts.count > 2 || (parts.count == 2 && parts[1].count == 3 && !parts[0].isEmpty)
            cleaned = isGrouping
                ? cleaned.replacingOccurrences(of: ",", with: "")
                : cleaned.replacingOccurrences(of: ",", with: ".")
        default:
            break
        }
        return Double(cleaned)
    }
}

public enum ConversionFormat {
    /// Up to 6 significant digits, no trailing zeros, grouped thousands.
    public static func string(_ value: Double, locale: Locale = .current) -> String {
        guard value.isFinite else { return "–" }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesSignificantDigits = true
        formatter.maximumSignificantDigits = abs(value) >= 1_000_000 ? 12 : 6
        formatter.minimumSignificantDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }
}
