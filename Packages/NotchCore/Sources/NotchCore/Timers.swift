import Foundation

/// A countdown. Stores absolute times, so it survives sleep and relaunch
/// without drifting.
public struct CountdownTimer: Codable, Identifiable, Hashable, Sendable {
    public enum State: Hashable, Sendable {
        case running
        case paused
        case finished
    }

    public let id: UUID
    public var label: String
    public var duration: TimeInterval
    /// Set while running.
    public var endsAt: Date?
    /// Set while paused.
    public var remainingWhenPaused: TimeInterval?
    public let createdAt: Date

    public init(id: UUID = UUID(), label: String, duration: TimeInterval, startedAt: Date) {
        self.id = id
        self.label = label
        self.duration = max(1, duration)
        self.endsAt = startedAt.addingTimeInterval(max(1, duration))
        self.remainingWhenPaused = nil
        self.createdAt = startedAt
    }

    public func state(at date: Date) -> State {
        if remainingWhenPaused != nil { return .paused }
        guard let endsAt else { return .finished }
        return date >= endsAt ? .finished : .running
    }

    public func remaining(at date: Date) -> TimeInterval {
        if let remainingWhenPaused { return remainingWhenPaused }
        guard let endsAt else { return 0 }
        return max(0, endsAt.timeIntervalSince(date))
    }

    /// 0 at the start, 1 when done.
    public func progress(at date: Date) -> Double {
        guard duration > 0 else { return 1 }
        return min(1, max(0, 1 - remaining(at: date) / duration))
    }

    public mutating func pause(at date: Date) {
        guard state(at: date) == .running else { return }
        remainingWhenPaused = remaining(at: date)
        endsAt = nil
    }

    public mutating func resume(at date: Date) {
        guard let left = remainingWhenPaused else { return }
        endsAt = date.addingTimeInterval(left)
        remainingWhenPaused = nil
    }

    /// Starts again from the full duration.
    public mutating func restart(at date: Date) {
        endsAt = date.addingTimeInterval(duration)
        remainingWhenPaused = nil
    }
}

public enum TimerPresets {
    /// Quick-start lengths in minutes. 25 is a classic focus session.
    public static let minutes = [1, 5, 10, 15, 25, 45]

    public static func label(forMinutes minutes: Int) -> String {
        minutes == 25 ? "Focus" : "\(minutes) min"
    }
}

public enum CountdownFormatter {
    /// "4:05", "12:00", "1:02:03". Rounds up, so a timer never shows 0:00
    /// while it still has a fraction of a second to go.
    public static func string(from remaining: TimeInterval) -> String {
        guard remaining.isFinite, remaining > 0 else { return "0:00" }
        let total = Int(remaining.rounded(.up))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// What the closed notch shows when something is going on. Higher cases win.
public enum LiveActivity: Equatable, Sendable {
    case none
    case keepAwake
    case music
    case timer(id: UUID)
    case timerFinished(id: UUID)
    /// The volume just changed; shown for a moment.
    case volume

    public static func pick(
        finishedTimer: UUID?,
        runningTimer: UUID?,
        musicPlaying: Bool,
        keepAwake: Bool,
        volumeChanged: Bool = false
    ) -> LiveActivity {
        if volumeChanged { return .volume }
        if let finishedTimer { return .timerFinished(id: finishedTimer) }
        if let runningTimer { return .timer(id: runningTimer) }
        if musicPlaying { return .music }
        if keepAwake { return .keepAwake }
        return .none
    }

    public var isActive: Bool { self != .none }
}

extension Array where Element == CountdownTimer {
    /// The running timer that ends soonest: the one worth showing.
    public func nextToFinish(at date: Date) -> CountdownTimer? {
        filter { $0.state(at: date) == .running }
            .min { ($0.endsAt ?? .distantFuture) < ($1.endsAt ?? .distantFuture) }
    }
}
