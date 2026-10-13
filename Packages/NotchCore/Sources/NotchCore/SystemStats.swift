import Foundation

/// Cumulative CPU ticks for one core, as reported by the kernel.
public struct CPUTicks: Equatable, Sendable {
    public var user: UInt64
    public var system: UInt64
    public var idle: UInt64
    public var nice: UInt64

    public init(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }

    var busy: UInt64 { user &+ system &+ nice }
    var total: UInt64 { busy &+ idle }
}

public enum CPULoad {
    /// Overall CPU use between two samples, 0...1, averaged over all cores.
    /// Nil when the samples don't line up (core count changed, no time passed).
    public static func usage(previous: [CPUTicks], current: [CPUTicks]) -> Double? {
        guard !current.isEmpty, previous.count == current.count else { return nil }
        var busy: UInt64 = 0
        var total: UInt64 = 0
        for (before, after) in zip(previous, current) {
            // Counters only grow; a smaller value means a reset, so skip that core.
            guard after.total >= before.total, after.busy >= before.busy else { continue }
            busy += after.busy - before.busy
            total += after.total - before.total
        }
        guard total > 0 else { return nil }
        return min(1, Double(busy) / Double(total))
    }
}

/// Bytes in and out for one network interface. The kernel's per-interface
/// counters are 32-bit and wrap around at 4 GiB.
public struct InterfaceCounters: Equatable, Sendable {
    public var received: UInt32
    public var sent: UInt32

    public init(received: UInt32, sent: UInt32) {
        self.received = received
        self.sent = sent
    }
}

public struct NetworkRate: Equatable, Sendable {
    public var receivedPerSecond: Double
    public var sentPerSecond: Double

    public init(receivedPerSecond: Double, sentPerSecond: Double) {
        self.receivedPerSecond = receivedPerSecond
        self.sentPerSecond = sentPerSecond
    }

    public static let zero = NetworkRate(receivedPerSecond: 0, sentPerSecond: 0)

    /// Bytes per second between two samples, summed over interfaces present
    /// in both. Handles counter wrap-around.
    public static func between(
        _ previous: [String: InterfaceCounters],
        _ current: [String: InterfaceCounters],
        seconds: TimeInterval
    ) -> NetworkRate {
        guard seconds > 0 else { return .zero }
        var received: UInt64 = 0
        var sent: UInt64 = 0
        for (name, now) in current {
            guard let before = previous[name] else { continue }
            received += UInt64(now.received &- before.received)
            sent += UInt64(now.sent &- before.sent)
        }
        return NetworkRate(receivedPerSecond: Double(received) / seconds, sentPerSecond: Double(sent) / seconds)
    }

    /// Only physical Ethernet / Wi-Fi interfaces ("en0", "en1", ...).
    /// Tunnels and bridges would count the same traffic twice.
    public static func isCounted(interface name: String) -> Bool {
        name.hasPrefix("en")
    }
}

public struct MemoryUsage: Equatable, Sendable {
    public var used: UInt64
    public var total: UInt64

    public init(used: UInt64, total: UInt64) {
        self.used = used
        self.total = total
    }

    public var fraction: Double {
        total > 0 ? min(1, Double(used) / Double(total)) : 0
    }

    /// Roughly what Activity Monitor calls "Memory Used": app memory
    /// (internal minus purgeable) plus wired plus compressed.
    public static func fromPages(
        internal: UInt64,
        purgeable: UInt64,
        wired: UInt64,
        compressed: UInt64,
        pageSize: UInt64,
        total: UInt64
    ) -> MemoryUsage {
        let app = internal > purgeable ? internal - purgeable : 0
        let used = (app + wired + compressed) * pageSize
        return MemoryUsage(used: min(used, total), total: total)
    }
}

public enum ByteFormat {
    /// "512 B", "1.4 KB", "23 MB", "1.2 GB" (decimal units, like Finder).
    public static func string(_ bytes: Double) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = max(0, bytes)
        var unit = 0
        while value >= 1000, unit < units.count - 1 {
            value /= 1000
            unit += 1
        }
        if unit == 0 { return "\(Int(value)) B" }
        return value < 10
            ? String(format: "%.1f %@", value, units[unit])
            : String(format: "%.0f %@", value, units[unit])
    }

    public static func rate(_ bytesPerSecond: Double) -> String {
        string(bytesPerSecond) + "/s"
    }
}
