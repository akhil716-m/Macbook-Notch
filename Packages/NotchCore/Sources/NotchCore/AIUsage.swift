import Foundation

/// Tokens used by one model call, read from a coding tool's local log.
public struct TokenUsageEntry: Hashable, Sendable {
    public var timestamp: Date
    public var tokens: Int
    /// Claude Code writes some calls to more than one log; this identifies a call.
    public var dedupeKey: String?

    public init(timestamp: Date, tokens: Int, dedupeKey: String? = nil) {
        self.timestamp = timestamp
        self.tokens = tokens
        self.dedupeKey = dedupeKey
    }
}

/// One usage-limit window as the tool itself reports it.
public struct RateLimitWindow: Equatable, Sendable {
    public var usedPercent: Double
    public var windowMinutes: Int
    public var resetsAt: Date?

    public init(usedPercent: Double, windowMinutes: Int, resetsAt: Date?) {
        self.usedPercent = usedPercent
        self.windowMinutes = windowMinutes
        self.resetsAt = resetsAt
    }

    /// "5-hour", "Weekly", or "N-hour".
    public var label: String {
        switch windowMinutes {
        case 300: return "5-hour"
        case 10_080: return "Weekly"
        case let minutes where minutes % 60 == 0: return "\(minutes / 60)-hour"
        default: return "\(windowMinutes)-minute"
        }
    }
}

public struct RateLimits: Equatable, Sendable {
    public var primary: RateLimitWindow?
    public var secondary: RateLimitWindow?
    public var observedAt: Date

    public init(primary: RateLimitWindow?, secondary: RateLimitWindow?, observedAt: Date) {
        self.primary = primary
        self.secondary = secondary
        self.observedAt = observedAt
    }

    public var windows: [RateLimitWindow] { [primary, secondary].compactMap { $0 } }
}

/// What one log line told us.
public struct ParsedUsageLine: Equatable, Sendable {
    public var entry: TokenUsageEntry?
    public var limits: RateLimits?

    public init(entry: TokenUsageEntry? = nil, limits: RateLimits? = nil) {
        self.entry = entry
        self.limits = limits
    }
}

enum LogTimestamp {
    static func parse(_ string: String?) -> Date? {
        guard let string else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) { return date }
        return ISO8601DateFormatter().date(from: string)
    }
}

/// Claude Code's session logs (`~/.claude/projects/**/*.jsonl`): one JSON
/// object per line; assistant lines carry `message.usage`.
public enum ClaudeCodeLog {
    public static func parse(_ line: Substring) -> ParsedUsageLine? {
        // Cheap filter before decoding: most lines carry no usage.
        guard line.contains("\"usage\"") else { return nil }
        guard let record = try? JSONDecoder().decode(Line.self, from: Data(line.utf8)),
              let usage = record.message?.usage,
              let timestamp = LogTimestamp.parse(record.timestamp)
        else { return nil }
        let tokens = (usage.input ?? 0) + (usage.output ?? 0) + (usage.cacheCreation ?? 0) + (usage.cacheRead ?? 0)
        guard tokens > 0 else { return nil }
        let key = record.message?.id.map { "\($0):\(record.requestId ?? "")" }
        return ParsedUsageLine(entry: TokenUsageEntry(timestamp: timestamp, tokens: tokens, dedupeKey: key))
    }

    private struct Line: Decodable {
        let timestamp: String?
        let requestId: String?
        let message: Message?

        struct Message: Decodable {
            let id: String?
            let usage: Usage?
        }

        struct Usage: Decodable {
            let input: Int?
            let output: Int?
            let cacheCreation: Int?
            let cacheRead: Int?

            enum CodingKeys: String, CodingKey {
                case input = "input_tokens"
                case output = "output_tokens"
                case cacheCreation = "cache_creation_input_tokens"
                case cacheRead = "cache_read_input_tokens"
            }
        }
    }
}

/// Codex CLI's session logs (`~/.codex/sessions/**/*.jsonl`): `token_count`
/// events carry the last call's tokens and, in recent versions, the
/// account's rate-limit windows.
public enum CodexLog {
    public static func parse(_ line: Substring) -> ParsedUsageLine? {
        guard line.contains("token_count") else { return nil }
        guard let record = try? JSONDecoder().decode(Line.self, from: Data(line.utf8)),
              record.payload?.type == "token_count",
              let timestamp = LogTimestamp.parse(record.timestamp)
        else { return nil }

        var result = ParsedUsageLine()
        if let tokens = record.payload?.info?.lastTokenUsage?.totalTokens, tokens > 0 {
            result.entry = TokenUsageEntry(timestamp: timestamp, tokens: tokens)
        }
        if let limits = record.payload?.rateLimits {
            let parsed = RateLimits(
                primary: limits.primary.flatMap { window(from: $0, observedAt: timestamp) },
                secondary: limits.secondary.flatMap { window(from: $0, observedAt: timestamp) },
                observedAt: timestamp
            )
            if !parsed.windows.isEmpty { result.limits = parsed }
        }
        return result.entry == nil && result.limits == nil ? nil : result
    }

    private static func window(from raw: Line.Window, observedAt: Date) -> RateLimitWindow? {
        guard let used = raw.usedPercent, let minutes = raw.windowMinutes else { return nil }
        var resetsAt: Date?
        if let at = raw.resetsAt {
            resetsAt = Date(timeIntervalSince1970: at)
        } else if let seconds = raw.resetsInSeconds {
            resetsAt = observedAt.addingTimeInterval(seconds)
        }
        return RateLimitWindow(usedPercent: used, windowMinutes: minutes, resetsAt: resetsAt)
    }

    private struct Line: Decodable {
        let timestamp: String?
        let payload: Payload?

        struct Payload: Decodable {
            let type: String?
            let info: Info?
            let rateLimits: Limits?

            enum CodingKeys: String, CodingKey {
                case type, info
                case rateLimits = "rate_limits"
            }
        }

        struct Info: Decodable {
            let lastTokenUsage: Counts?

            enum CodingKeys: String, CodingKey {
                case lastTokenUsage = "last_token_usage"
            }
        }

        struct Counts: Decodable {
            let totalTokens: Int?

            enum CodingKeys: String, CodingKey {
                case totalTokens = "total_tokens"
            }
        }

        struct Limits: Decodable {
            let primary: Window?
            let secondary: Window?
        }

        struct Window: Decodable {
            let usedPercent: Double?
            let windowMinutes: Int?
            let resetsInSeconds: Double?
            let resetsAt: Double?

            enum CodingKeys: String, CodingKey {
                case usedPercent = "used_percent"
                case windowMinutes = "window_minutes"
                case resetsInSeconds = "resets_in_seconds"
                case resetsAt = "resets_at"
            }
        }
    }
}

/// A run of activity inside one usage window, the way Claude's 5-hour
/// limits work: it starts at the hour of the first call and lasts 5 hours.
public struct UsageBlock: Equatable, Sendable {
    public var start: Date
    public var end: Date
    public var tokens: Int
    public var lastActivity: Date

    public init(start: Date, end: Date, tokens: Int, lastActivity: Date) {
        self.start = start
        self.end = end
        self.tokens = tokens
        self.lastActivity = lastActivity
    }

    public func isActive(at date: Date) -> Bool {
        date < end && date >= start
    }
}

public enum UsageMath {
    public static let blockLength: TimeInterval = 5 * 3_600

    /// Drops entries with a dedupe key already seen; keeps the first.
    public static func deduplicated(_ entries: [TokenUsageEntry]) -> [TokenUsageEntry] {
        var seen = Set<String>()
        return entries.filter { entry in
            guard let key = entry.dedupeKey else { return true }
            return seen.insert(key).inserted
        }
    }

    /// Splits activity into 5-hour blocks. A new block starts when a call
    /// lands after the current block ends or after a 5-hour gap; each block
    /// starts at the top of the hour of its first call (UTC hours).
    public static func blocks(_ entries: [TokenUsageEntry], length: TimeInterval = blockLength) -> [UsageBlock] {
        var blocks: [UsageBlock] = []
        for entry in entries.sorted(by: { $0.timestamp < $1.timestamp }) {
            if var current = blocks.last,
               entry.timestamp < current.end,
               entry.timestamp.timeIntervalSince(current.lastActivity) < length {
                current.tokens += entry.tokens
                current.lastActivity = entry.timestamp
                blocks[blocks.count - 1] = current
            } else {
                let hour = (entry.timestamp.timeIntervalSince1970 / 3_600).rounded(.down) * 3_600
                let start = Date(timeIntervalSince1970: hour)
                blocks.append(UsageBlock(start: start, end: start.addingTimeInterval(length), tokens: entry.tokens, lastActivity: entry.timestamp))
            }
        }
        return blocks
    }

    /// The block happening now, if any.
    public static func activeBlock(_ entries: [TokenUsageEntry], now: Date) -> UsageBlock? {
        guard let last = blocks(entries).last, last.isActive(at: now) else { return nil }
        return last
    }

    public static func total(_ entries: [TokenUsageEntry], since: Date) -> Int {
        entries.filter { $0.timestamp >= since }.reduce(0) { $0 + $1.tokens }
    }
}

public enum TokenFormat {
    /// "950", "12K", "1.2M", "3.4B".
    public static func short(_ tokens: Int) -> String {
        let value = Double(max(0, tokens))
        switch value {
        case ..<1_000: return "\(Int(value))"
        case ..<1_000_000: return trimmed(value / 1_000) + "K"
        case ..<1_000_000_000: return trimmed(value / 1_000_000) + "M"
        default: return trimmed(value / 1_000_000_000) + "B"
        }
    }

    private static func trimmed(_ value: Double) -> String {
        value < 10 ? String(format: "%.1f", value).replacingOccurrences(of: ".0", with: "") : String(Int(value.rounded(.down)))
    }
}

/// Reads JSONL logs under some folders, remembering how far it got in each
/// file so later scans only parse new lines. Only files changed within
/// `maxAge` are read.
public actor UsageLogScanner {
    public struct Result: Sendable {
        public var entries: [TokenUsageEntry]
        public var latestLimits: RateLimits?
        /// False when none of the folders exist (the tool isn't installed or never ran).
        public var foundLogs: Bool
    }

    private struct FileState {
        var consumed: UInt64
        var entries: [TokenUsageEntry]
        var latestLimits: RateLimits?
    }

    private let roots: [URL]
    private let maxAge: TimeInterval
    private let parse: @Sendable (Substring) -> ParsedUsageLine?
    private var files: [String: FileState] = [:]

    public init(roots: [URL], maxAge: TimeInterval, parse: @escaping @Sendable (Substring) -> ParsedUsageLine?) {
        self.roots = roots
        self.maxAge = maxAge
        self.parse = parse
    }

    public func scan(now: Date = Date()) -> Result {
        let fileManager = FileManager.default
        let cutoff = now.addingTimeInterval(-maxAge)
        var foundLogs = false
        var seen = Set<String>()

        for root in roots where fileManager.fileExists(atPath: root.path) {
            foundLogs = true
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]
            ) else { continue }
            for case let url as URL in enumerator where url.pathExtension == "jsonl" {
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey])
                guard values?.isRegularFile == true,
                      let modified = values?.contentModificationDate, modified >= cutoff
                else { continue }
                seen.insert(url.path)
                read(url, size: UInt64(values?.fileSize ?? 0))
            }
        }
        // Forget files that aged out or disappeared.
        files = files.filter { seen.contains($0.key) }

        let entries = UsageMath.deduplicated(
            files.values.flatMap(\.entries).filter { $0.timestamp >= cutoff }
        )
        let latest = files.values.compactMap(\.latestLimits).max { $0.observedAt < $1.observedAt }
        return Result(entries: entries, latestLimits: latest, foundLogs: foundLogs)
    }

    private func read(_ url: URL, size: UInt64) {
        var state = files[url.path] ?? FileState(consumed: 0, entries: [], latestLimits: nil)
        // A file that shrank was rewritten: start over.
        if size < state.consumed {
            state = FileState(consumed: 0, entries: [], latestLimits: nil)
        }
        guard size > state.consumed, let handle = try? FileHandle(forReadingFrom: url) else {
            files[url.path] = state
            return
        }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: state.consumed)
            guard let data = try handle.readToEnd(), let lastNewline = data.lastIndex(of: 0x0A) else {
                files[url.path] = state
                return
            }
            // Only whole lines; a half-written last line waits for next time.
            let complete = data[data.startIndex...lastNewline]
            let text = String(decoding: complete, as: UTF8.self)
            for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
                guard let parsed = parse(line) else { continue }
                if let entry = parsed.entry { state.entries.append(entry) }
                if let limits = parsed.limits,
                   limits.observedAt >= (state.latestLimits?.observedAt ?? .distantPast) {
                    state.latestLimits = limits
                }
            }
            state.consumed += UInt64(complete.count)
        } catch {
            // Leave the state as it was; try again next scan.
        }
        files[url.path] = state
    }
}
