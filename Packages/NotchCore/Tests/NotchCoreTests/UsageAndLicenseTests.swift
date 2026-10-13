import XCTest
@testable import NotchCore

final class AIUsageTests: XCTestCase {
    private let claudeLine = #"{"parentUuid":"a","type":"assistant","message":{"id":"msg_01","role":"assistant","model":"claude-x","content":[{"type":"text","text":"hi"}],"usage":{"input_tokens":10,"cache_creation_input_tokens":200,"cache_read_input_tokens":3000,"output_tokens":45}},"requestId":"req_9","timestamp":"2026-10-13T10:15:30.123Z"}"#

    private let codexLine = #"{"timestamp":"2026-10-13T10:20:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":9000},"last_token_usage":{"input_tokens":800,"output_tokens":200,"total_tokens":1000}},"rate_limits":{"primary":{"used_percent":42.5,"window_minutes":300,"resets_in_seconds":3600},"secondary":{"used_percent":12.0,"window_minutes":10080,"resets_at":1791900000}}}}"#

    func testParsesClaudeCodeUsage() throws {
        let parsed = try XCTUnwrap(ClaudeCodeLog.parse(Substring(claudeLine)))
        XCTAssertEqual(parsed.entry?.tokens, 3_255)
        XCTAssertEqual(parsed.entry?.dedupeKey, "msg_01:req_9")
        XCTAssertNotNil(parsed.entry?.timestamp)
        XCTAssertNil(parsed.limits)
    }

    func testClaudeLinesWithoutUsageAreSkipped() {
        XCTAssertNil(ClaudeCodeLog.parse(#"{"type":"user","message":{"role":"user","content":"hello"},"timestamp":"2026-10-13T10:00:00Z"}"#))
        XCTAssertNil(ClaudeCodeLog.parse("not json with \"usage\" in it"))
    }

    func testParsesCodexTokensAndRateLimits() throws {
        let parsed = try XCTUnwrap(CodexLog.parse(Substring(codexLine)))
        XCTAssertEqual(parsed.entry?.tokens, 1_000)
        let limits = try XCTUnwrap(parsed.limits)
        XCTAssertEqual(limits.primary?.usedPercent, 42.5)
        XCTAssertEqual(limits.primary?.label, "5-hour")
        XCTAssertEqual(limits.primary?.resetsAt, limits.observedAt.addingTimeInterval(3_600))
        XCTAssertEqual(limits.secondary?.label, "Weekly")
        XCTAssertEqual(limits.secondary?.resetsAt, Date(timeIntervalSince1970: 1_791_900_000))
    }

    func testCodexLinesWithNullInfoStillGiveLimits() throws {
        let line = #"{"timestamp":"2026-10-13T10:20:00Z","type":"event_msg","payload":{"type":"token_count","info":null,"rate_limits":{"primary":{"used_percent":5,"window_minutes":300}}}}"#
        let parsed = try XCTUnwrap(CodexLog.parse(Substring(line)))
        XCTAssertNil(parsed.entry)
        XCTAssertEqual(parsed.limits?.primary?.usedPercent, 5)
        XCTAssertNil(parsed.limits?.primary?.resetsAt)
    }

    func testOtherCodexEventsAreSkipped() {
        XCTAssertNil(CodexLog.parse(#"{"timestamp":"2026-10-13T10:20:00Z","type":"event_msg","payload":{"type":"agent_message","message":"done"}}"#))
    }

    // MARK: Blocks

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func entry(_ minutes: Double, _ tokens: Int, key: String? = nil) -> TokenUsageEntry {
        let hour = (t0.timeIntervalSince1970 / 3_600).rounded(.down) * 3_600
        return TokenUsageEntry(timestamp: Date(timeIntervalSince1970: hour + minutes * 60), tokens: tokens, dedupeKey: key)
    }

    func testBlocksStartOnTheHourAndLastFiveHours() {
        let blocks = UsageMath.blocks([entry(30, 100), entry(200, 50), entry(310, 10)])
        // 0:30 and 3:20 share a block (0:00–5:00); 5:10 starts a new one at 5:00.
        XCTAssertEqual(blocks.count, 2)
        XCTAssertEqual(blocks[0].tokens, 150)
        XCTAssertEqual(blocks[0].end.timeIntervalSince(blocks[0].start), 5 * 3_600)
        XCTAssertEqual(blocks[1].start, entry(300, 0).timestamp)
        XCTAssertEqual(blocks[1].tokens, 10)
    }

    func testActiveBlockOnlyWhileItLasts() {
        let entries = [entry(30, 100)]
        XCTAssertEqual(UsageMath.activeBlock(entries, now: entry(120, 0).timestamp)?.tokens, 100)
        XCTAssertNil(UsageMath.activeBlock(entries, now: entry(301, 0).timestamp))
    }

    func testDuplicatesAreCountedOnce() {
        let entries = [entry(1, 100, key: "a"), entry(2, 100, key: "a"), entry(3, 5), entry(4, 5)]
        XCTAssertEqual(UsageMath.deduplicated(entries).map(\.tokens), [100, 5, 5])
    }

    func testTotalsSince() {
        let entries = [entry(0, 1), entry(60, 2), entry(120, 4)]
        XCTAssertEqual(UsageMath.total(entries, since: entry(60, 0).timestamp), 6)
    }

    func testTokenFormatting() {
        XCTAssertEqual(TokenFormat.short(950), "950")
        XCTAssertEqual(TokenFormat.short(1_000), "1K")
        XCTAssertEqual(TokenFormat.short(12_400), "12K")
        XCTAssertEqual(TokenFormat.short(1_240_000), "1.2M")
        XCTAssertEqual(TokenFormat.short(3_400_000_000), "3.4B")
    }

    // MARK: Scanner

    func testScannerReadsOnlyNewWholeLines() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let folder = root.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = folder.appendingPathComponent("session.jsonl")

        let now = LogTimestamp.parse("2026-10-13T12:00:00Z")!
        try Data((claudeLine + "\n" + #"{"partial": "#).utf8).write(to: file)

        let scanner = UsageLogScanner(roots: [root], maxAge: 7 * 86_400, parse: { ClaudeCodeLog.parse($0) })
        let first = await scanner.scan(now: now)
        XCTAssertTrue(first.foundLogs)
        XCTAssertEqual(first.entries.count, 1)

        // The same call logged again (resumed session) plus a new one.
        let second = claudeLine.replacingOccurrences(of: "msg_01", with: "msg_02")
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(("\"x\"}\n" + claudeLine + "\n" + second + "\n").utf8))
        try handle.close()

        let next = await scanner.scan(now: now)
        XCTAssertEqual(next.entries.count, 2, "msg_01 is counted once")
    }

    func testScannerReportsMissingTool() async {
        let scanner = UsageLogScanner(roots: [URL(fileURLWithPath: "/nonexistent-\(UUID())")], maxAge: 86_400, parse: { CodexLog.parse($0) })
        let result = await scanner.scan()
        XCTAssertFalse(result.foundLogs)
        XCTAssertTrue(result.entries.isEmpty)
    }
}

final class LicensingTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func record(validatedDaysAgo days: Double, status: LicenseRecord.Status = .active) -> LicenseRecord {
        LicenseRecord(
            key: "ABCD-1234-EFGH-5678",
            instanceID: "inst",
            instanceName: "Mac",
            productName: "MacbookNotch",
            activatedAt: t0.addingTimeInterval(-90 * 86_400),
            lastValidatedAt: t0.addingTimeInterval(-days * 86_400),
            status: status
        )
    }

    func testStanding() {
        XCTAssertEqual(LicensePolicy.standing(nil, now: t0), .unlicensed)
        XCTAssertEqual(LicensePolicy.standing(record(validatedDaysAgo: 1), now: t0), .licensed)
        XCTAssertEqual(LicensePolicy.standing(record(validatedDaysAgo: 8), now: t0), .needsCheck)
        XCTAssertEqual(LicensePolicy.standing(record(validatedDaysAgo: 31), now: t0), .graceExpired)
        XCTAssertEqual(LicensePolicy.standing(record(validatedDaysAgo: 1, status: .revoked), now: t0), .revoked)
        XCTAssertTrue(LicenseStanding.needsCheck.allowsUse)
        XCTAssertFalse(LicenseStanding.graceExpired.allowsUse)
    }

    func testMaskedKey() {
        XCTAssertEqual(record(validatedDaysAgo: 0).maskedKey, "ABCD…5678")
    }

    func testFormBodyIsSortedAndEncoded() {
        let body = String(decoding: LemonSqueezy.formBody(["license_key": "AB CD+1", "instance_name": "Akhil's Mac"]), as: UTF8.self)
        XCTAssertEqual(body, "instance_name=Akhil%27s%20Mac&license_key=AB%20CD%2B1")
    }

    func testRequestShape() {
        let request = LemonSqueezy.request(.activate, fields: ["license_key": "k"])
        XCTAssertEqual(request.url?.absoluteString, "https://api.lemonsqueezy.com/v1/licenses/activate")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func testDecodesActivation() throws {
        let json = #"{"activated":true,"error":null,"license_key":{"id":1,"status":"active","key":"k","activation_limit":3,"activation_usage":1},"instance":{"id":"47596ad9-a811-4ebf-ac8a-03fc7b6d2a17","name":"Mac","created_at":"2026-10-13T10:00:00.000000Z"},"meta":{"store_id":11,"order_id":2,"product_id":22,"product_name":"MacbookNotch","variant_id":3}}"#
        let response = try LemonSqueezy.decode(Data(json.utf8), for: .activate)
        XCTAssertTrue(response.succeeded)
        XCTAssertEqual(response.instanceID, "47596ad9-a811-4ebf-ac8a-03fc7b6d2a17")
        XCTAssertTrue(response.isFor(storeID: 11, productID: 22))
        XCTAssertFalse(response.isFor(storeID: 11, productID: 99))
    }

    func testDecodesFailures() throws {
        let limit = #"{"activated":false,"error":"This license key has reached the activation limit.","license_key":{"status":"active"},"meta":{"store_id":11,"product_id":22}}"#
        let response = try LemonSqueezy.decode(Data(limit.utf8), for: .activate)
        XCTAssertFalse(response.succeeded)
        XCTAssertEqual(response.error, "This license key has reached the activation limit.")

        let invalid = #"{"valid":false,"error":"license_key not found.","license_key":null,"instance":null,"meta":null}"#
        XCTAssertFalse(try LemonSqueezy.decode(Data(invalid.utf8), for: .validate).succeeded)
        XCTAssertTrue(try LemonSqueezy.decode(Data(#"{"deactivated":true,"error":null}"#.utf8), for: .deactivate).succeeded)
    }
}
