import XCTest
@testable import NotchCore

final class ConverterTests: XCTestCase {
    private func unit(_ id: String) -> ConversionUnit {
        UnitCatalog.unit(id: id)!
    }

    func testLengthAndTemperature() throws {
        let miles = try XCTUnwrap(UnitCatalog.convert(10, from: unit("length.km"), to: unit("length.mi")))
        XCTAssertEqual(miles, 6.21371, accuracy: 0.0001)
        let fahrenheit = try XCTUnwrap(UnitCatalog.convert(100, from: unit("temperature.c"), to: unit("temperature.f")))
        XCTAssertEqual(fahrenheit, 212, accuracy: 0.0001)
        let celsius = try XCTUnwrap(UnitCatalog.convert(32, from: unit("temperature.f"), to: unit("temperature.c")))
        XCTAssertEqual(celsius, 0, accuracy: 0.0001)
    }

    func testDataAndWeight() throws {
        XCTAssertEqual(try XCTUnwrap(UnitCatalog.convert(1, from: unit("data.gb"), to: unit("data.mb"))), 1_000, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(UnitCatalog.convert(1, from: unit("mass.kg"), to: unit("mass.lb"))), 2.20462, accuracy: 0.0001)
    }

    func testMismatchedCategoriesAndCurrencyAreRefused() {
        XCTAssertNil(UnitCatalog.convert(1, from: unit("length.km"), to: unit("mass.kg")))
        XCTAssertNil(UnitCatalog.convert(1, from: unit("currency.USD"), to: unit("currency.EUR")))
    }

    func testEveryCategoryHasADefaultPairAndUniqueIDs() {
        for category in ConversionCategory.allCases {
            let units = UnitCatalog.units(for: category)
            XCTAssertGreaterThanOrEqual(units.count, 2, "\(category)")
            XCTAssertEqual(Set(units.map(\.id)).count, units.count, "\(category)")
            let (from, to) = UnitCatalog.defaultPair(for: category)
            XCTAssertNotEqual(from, to)
            XCTAssertEqual(UnitCatalog.unit(id: from.id), from)
        }
    }

    func testCurrencyConversionGoesThroughTheBase() throws {
        let rates = CurrencyRates(base: "USD", date: "2026-10-13", rates: ["EUR": 0.5, "INR": 80], fetchedAt: Date())
        XCTAssertEqual(rates.convert(10, from: "USD", to: "EUR"), 5)
        XCTAssertEqual(rates.convert(10, from: "EUR", to: "USD"), 20)
        XCTAssertEqual(rates.convert(1, from: "EUR", to: "INR"), 160)
        XCTAssertEqual(rates.convert(7, from: "INR", to: "INR"), 7)
        XCTAssertNil(rates.convert(1, from: "XYZ", to: "USD"))
    }

    func testDecodesFrankfurter() throws {
        let json = #"{"amount":1.0,"base":"USD","date":"2026-10-13","rates":{"EUR":0.92,"INR":83.1}}"#
        let rates = try CurrencyRates.decodeFrankfurter(Data(json.utf8), fetchedAt: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(rates.base, "USD")
        XCTAssertEqual(rates.rates["INR"], 83.1)
        XCTAssertEqual(CurrencyRates.frankfurterURL(base: "USD")?.host, "api.frankfurter.app")
    }

    func testNumberInput() {
        XCTAssertEqual(NumberInput.parse("1234.5"), 1234.5)
        XCTAssertEqual(NumberInput.parse("1,234.5"), 1234.5)
        XCTAssertEqual(NumberInput.parse("1.234,5"), 1234.5)
        XCTAssertEqual(NumberInput.parse("1 234,5"), 1234.5)
        XCTAssertEqual(NumberInput.parse("12,5"), 12.5)
        XCTAssertEqual(NumberInput.parse("1,234"), 1234)
        XCTAssertEqual(NumberInput.parse("1,234,567"), 1_234_567)
        XCTAssertEqual(NumberInput.parse("-3"), -3)
        XCTAssertNil(NumberInput.parse(""))
        XCTAssertNil(NumberInput.parse("abc"))
    }

    func testFormatting() {
        let posix = Locale(identifier: "en_US_POSIX")
        XCTAssertEqual(ConversionFormat.string(6.213711922, locale: posix), "6.21371")
        XCTAssertEqual(ConversionFormat.string(212, locale: posix), "212")
        XCTAssertEqual(ConversionFormat.string(.nan, locale: posix), "–")
    }
}

final class EmojiTests: XCTestCase {
    func testCatalogHasFamiliarEmoji() {
        let grinning = EmojiCatalog.all.first { $0.character == "😀" }
        XCTAssertEqual(grinning?.name, "grinning face")
        XCTAssertTrue(EmojiCatalog.all.contains { $0.character == "🚀" })
        XCTAssertGreaterThan(EmojiCatalog.all.count, 900)
    }

    func testCatalogSkipsSkinToneModifiers() {
        XCTAssertFalse(EmojiCatalog.all.contains { $0.character == "\u{1F3FB}" })
    }

    func testSearchNeedsEveryWord() {
        let results = EmojiCatalog.search("grinning face")
        XCTAssertTrue(results.contains { $0.character == "😀" })
        XCTAssertTrue(results.allSatisfy { $0.name.contains("grinning") && $0.name.contains("face") })
        XCTAssertEqual(EmojiCatalog.search("   ").count, EmojiCatalog.all.count)
    }

    func testRecentsMoveToFrontWithoutDuplicates() {
        XCTAssertEqual(EmojiCatalog.recordingUse(of: "🚀", in: ["😀", "🚀", "🎉"]), ["🚀", "😀", "🎉"])
        XCTAssertEqual(EmojiCatalog.recordingUse(of: "a", in: ["b", "c"], limit: 2), ["a", "b"])
    }
}
