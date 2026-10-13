import Foundation
import NotchCore

/// How much of your AI coding tools' limits you've used, read only from the
/// log files those tools already write on this Mac. No login tokens are
/// read and nothing is sent anywhere.
@MainActor
final class AIUsageService: ObservableObject {
    struct ClaudeSummary: Equatable {
        var foundLogs: Bool
        var block: UsageBlock?
        var lastWeek: Int
    }

    struct CodexSummary: Equatable {
        var foundLogs: Bool
        var limits: RateLimits?
        var lastWeek: Int
    }

    @Published private(set) var claude = ClaudeSummary(foundLogs: false, block: nil, lastWeek: 0)
    @Published private(set) var codex = CodexSummary(foundLogs: false, limits: nil, lastWeek: 0)
    @Published private(set) var lastScan: Date?

    private static let week: TimeInterval = 7 * 24 * 3_600
    private static let refreshInterval: TimeInterval = 60

    private let claudeScanner: UsageLogScanner
    private let codexScanner: UsageLogScanner
    private var viewers = 0
    private var timer: Timer?
    private var scanning = false

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        claudeScanner = UsageLogScanner(
            roots: [
                home.appendingPathComponent(".claude/projects", isDirectory: true),
                home.appendingPathComponent(".config/claude/projects", isDirectory: true),
            ],
            maxAge: Self.week,
            parse: { ClaudeCodeLog.parse($0) }
        )
        codexScanner = UsageLogScanner(
            roots: [home.appendingPathComponent(".codex/sessions", isDirectory: true)],
            maxAge: Self.week,
            parse: { CodexLog.parse($0) }
        )
    }

    /// Scans while the AI Usage tool is on screen, once a minute.
    func beginViewing() {
        viewers += 1
        guard viewers == 1 else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
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
        guard !scanning else { return }
        scanning = true
        Task {
            let now = Date()
            let since = now.addingTimeInterval(-Self.week)
            async let claudeResult = self.claudeScanner.scan(now: now)
            async let codexResult = self.codexScanner.scan(now: now)
            let (claudeScan, codexScan) = await (claudeResult, codexResult)

            self.claude = ClaudeSummary(
                foundLogs: claudeScan.foundLogs,
                block: UsageMath.activeBlock(claudeScan.entries, now: now),
                lastWeek: UsageMath.total(claudeScan.entries, since: since)
            )
            self.codex = CodexSummary(
                foundLogs: codexScan.foundLogs,
                limits: codexScan.latestLimits,
                lastWeek: UsageMath.total(codexScan.entries, since: since)
            )
            self.lastScan = now
            self.scanning = false
        }
    }
}
