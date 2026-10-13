import XCTest
@testable import NotchCore

final class StocksTests: XCTestCase {
    func testSymbolNormalising() {
        XCTAssertEqual(StockSymbol.normalize(" aapl "), "AAPL")
        XCTAssertEqual(StockSymbol.normalize("brk.b"), "BRK.B")
        XCTAssertEqual(StockSymbol.normalize("RELIANCE.NS"), "RELIANCE.NS")
        XCTAssertNil(StockSymbol.normalize(""))
        XCTAssertNil(StockSymbol.normalize("AA PL"))
        XCTAssertNil(StockSymbol.normalize("<script>"))
    }

    func testQuoteURLCarriesSymbolAndToken() {
        let url = Finnhub.quoteURL(symbol: "AAPL", token: "abc")
        XCTAssertEqual(url?.host, "finnhub.io")
        XCTAssertTrue(url?.query?.contains("symbol=AAPL") == true)
        XCTAssertTrue(url?.query?.contains("token=abc") == true)
    }

    func testDecodesQuote() throws {
        let json = #"{"c":261.74,"d":-2.11,"dp":-0.7997,"h":263.31,"l":260.68,"o":261.07,"pc":263.85,"t":1582641000}"#
        let quote = try XCTUnwrap(Finnhub.decodeQuote(Data(json.utf8), symbol: "AAPL", fetchedAt: Date()))
        XCTAssertEqual(quote.price, 261.74)
        XCTAssertEqual(quote.changePercent, -0.7997)
        XCTAssertFalse(quote.isUp)
    }

    func testUnknownSymbolIsNil() throws {
        let json = #"{"c":0,"d":null,"dp":null,"h":0,"l":0,"o":0,"pc":0,"t":0}"#
        XCTAssertNil(try Finnhub.decodeQuote(Data(json.utf8), symbol: "NOPE", fetchedAt: Date()))
    }
}

final class RevenueTests: XCTestCase {
    /// 2026-10-13 00:00 UTC
    private let since = Date(timeIntervalSince1970: 1_791_849_600)

    private func parse(_ json: String, _ provider: RevenueProvider) throws -> MoneyTotals {
        try RevenueAPI.parse(Data(json.utf8), provider: provider, since: since)
    }

    func testStripeCountsSucceededChargesNetOfRefunds() throws {
        let json = """
        {"object":"list","data":[
          {"amount":2000,"amount_refunded":500,"currency":"usd","paid":true,"status":"succeeded","created":1791850000},
          {"amount":1000,"amount_refunded":0,"currency":"eur","paid":true,"status":"succeeded","created":1791850001},
          {"amount":9999,"amount_refunded":0,"currency":"usd","paid":false,"status":"failed","created":1791850002},
          {"amount":1,"amount_refunded":0,"currency":"usd","paid":true,"status":"succeeded","created":1791850003},
          {"amount":7777,"amount_refunded":0,"currency":"usd","paid":true,"status":"succeeded","created":1791800000}
        ],"has_more":false}
        """
        let totals = try parse(json, .stripe)
        XCTAssertEqual(totals.minorUnits, ["USD": 1_501, "EUR": 1_000])
        XCTAssertEqual(totals.orderCount, 3)
        XCTAssertEqual(totals.currencies, ["EUR", "USD"])
    }

    func testShopifySkipsRefundedAndCancelled() throws {
        let json = """
        {"orders":[
          {"total_price":"49.99","currency":"USD","financial_status":"paid","cancelled_at":null,"created_at":"2026-10-13T09:00:00-04:00"},
          {"total_price":"10.00","currency":"USD","financial_status":"refunded","cancelled_at":null,"created_at":"2026-10-13T09:00:00-04:00"},
          {"total_price":"5.00","currency":"USD","financial_status":"paid","cancelled_at":"2026-10-13T10:00:00-04:00","created_at":"2026-10-13T09:00:00-04:00"},
          {"total_price":"1500","currency":"JPY","financial_status":"paid","cancelled_at":null,"created_at":"2026-10-13T09:00:00+09:00"}
        ]}
        """
        let totals = try parse(json, .shopify)
        XCTAssertEqual(totals.minorUnits, ["USD": 4_999, "JPY": 1_500])
    }

    func testLemonSqueezyPaidOrdersToday() throws {
        let json = """
        {"data":[
          {"type":"orders","id":"1","attributes":{"status":"paid","total":1999,"currency":"USD","created_at":"2026-10-13T10:00:00.000000Z"}},
          {"type":"orders","id":"2","attributes":{"status":"refunded","total":1999,"currency":"USD","created_at":"2026-10-13T11:00:00.000000Z"}},
          {"type":"orders","id":"3","attributes":{"status":"paid","total":500,"currency":"USD","created_at":"2026-10-12T23:59:00.000000Z"}}
        ]}
        """
        XCTAssertEqual(try parse(json, .lemonSqueezy).minorUnits, ["USD": 1_999])
    }

    func testPaddleGumroadPolarDodo() throws {
        let paddle = #"{"data":[{"currency_code":"USD","created_at":"2026-10-13T08:00:00.000Z","details":{"totals":{"grand_total":"1250"}}}]}"#
        XCTAssertEqual(try parse(paddle, .paddle).minorUnits, ["USD": 1_250])

        let gumroad = #"{"success":true,"sales":[{"price":900,"refunded":false,"created_at":"2026-10-13T08:00:00Z"},{"price":900,"refunded":true,"created_at":"2026-10-13T08:00:00Z"}]}"#
        XCTAssertEqual(try parse(gumroad, .gumroad).minorUnits, ["USD": 900])

        let polar = #"{"items":[{"total_amount":3000,"currency":"usd","created_at":"2026-10-13T08:00:00Z","status":"paid"}]}"#
        XCTAssertEqual(try parse(polar, .polar).minorUnits, ["USD": 3_000])

        let dodo = #"{"items":[{"total_amount":2500,"currency":"INR","status":"succeeded","created_at":"2026-10-13T08:00:00Z"},{"total_amount":2500,"currency":"INR","status":"failed","created_at":"2026-10-13T08:00:00Z"}]}"#
        XCTAssertEqual(try parse(dodo, .dodo).minorUnits, ["INR": 2_500])
    }

    func testRequestsCarryTheKeyTheRightWay() throws {
        let stripe = try RevenueAPI.request(for: RevenueSource(provider: .stripe, name: "S"), key: "rk_1", since: since)
        XCTAssertEqual(stripe.value(forHTTPHeaderField: "Authorization"), "Bearer rk_1")
        XCTAssertTrue(stripe.url?.absoluteString.contains("created%5Bgte%5D=1791849600") == true)

        let shop = try RevenueAPI.request(for: RevenueSource(provider: .shopify, name: "Shop", shopDomain: "https://My-Store.myshopify.com/admin"), key: "shpat", since: since)
        XCTAssertEqual(shop.url?.host, "my-store.myshopify.com")
        XCTAssertEqual(shop.value(forHTTPHeaderField: "X-Shopify-Access-Token"), "shpat")

        XCTAssertThrowsError(try RevenueAPI.request(for: RevenueSource(provider: .shopify, name: "x"), key: "k", since: since))
    }

    func testShopDomainNormalising() {
        XCTAssertEqual(RevenueAPI.normalizedShopDomain("my-store"), "my-store.myshopify.com")
        XCTAssertEqual(RevenueAPI.normalizedShopDomain("shop.example.com"), "shop.example.com")
        XCTAssertNil(RevenueAPI.normalizedShopDomain("  "))
    }

    func testCurrencyMath() {
        XCTAssertEqual(CurrencyMath.minorUnits(fromDecimal: "12.34", currency: "USD"), 1_234)
        XCTAssertEqual(CurrencyMath.minorUnits(fromDecimal: "1500", currency: "JPY"), 1_500)
        XCTAssertEqual(CurrencyMath.minorUnits(fromDecimal: "1.234", currency: "KWD"), 1_234)
        XCTAssertNil(CurrencyMath.minorUnits(fromDecimal: "abc", currency: "USD"))
        let posix = Locale(identifier: "en_US")
        XCTAssertEqual(CurrencyMath.format(minor: 123_456, currency: "USD", locale: posix), "$1,234.56")
    }

    func testTotalsAddPerCurrency() {
        var a = MoneyTotals()
        a.add(100, currency: "usd")
        var b = MoneyTotals()
        b.add(50, currency: "USD")
        b.add(10, currency: "EUR")
        let sum = a + b
        XCTAssertEqual(sum.minorUnits, ["USD": 150, "EUR": 10])
        XCTAssertEqual(sum.orderCount, 3)
    }
}
