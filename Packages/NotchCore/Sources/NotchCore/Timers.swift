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
    case stopwatch
    case pomodoro
    case timer(id: UUID)
    case timerFinished(id: UUID)
    /// The volume just changed; shown for a moment.
    case volume

    public static func pick(
        finishedTimer: UUID?,
        runningTimer: UUID?,
        musicPlaying: Bool,
        keepAwake: Bool,
        volumeChanged: Bool = false,
        pomodoroRunning: Bool = false,
        stopwatchRunning: Bool = false
    ) -> LiveActivity {
        if volumeChanged { return .volume }
        if let finishedTimer { return .timerFinished(id: finishedTimer) }
        if let runningTimer { return .timer(id: runningTimer) }
        if pomodoroRunning { return .pomodoro }
        if stopwatchRunning { return .stopwatch }
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

// MARK: Stopwatch

/// A stopwatch with laps. Like the countdown, it stores when it started
/// rather than ticking, so it keeps time across sleep and relaunch.
public struct Stopwatch: Codable, Equatable, Sendable {
    /// Set while running.
    public private(set) var startedAt: Date?
    /// Time counted before the current run.
    public private(set) var accumulated: TimeInterval = 0
    /// Total elapsed time at each lap, oldest first.
    public private(set) var laps: [TimeInterval] = []

    public init() {}

    public var isRunning: Bool { startedAt != nil }

    public func elapsed(at date: Date) -> TimeInterval {
        guard let startedAt else { return accumulated }
        return accumulated + max(0, date.timeIntervalSince(startedAt))
    }

    /// Whether there is anything to reset.
    public var hasTime: Bool { isRunning || accumulated > 0 || !laps.isEmpty }

    public mutating func start(at date: Date) {
        guard startedAt == nil else { return }
        startedAt = date
    }

    public mutating func pause(at date: Date) {
        guard startedAt != nil else { return }
        accumulated = elapsed(at: date)
        startedAt = nil
    }

    public mutating func lap(at date: Date) {
        guard isRunning else { return }
        laps.append(elapsed(at: date))
    }

    public mutating func reset() {
        self = Stopwatch()
    }

    /// Each lap's own length, newest first: what a lap list shows.
    public var lapLengths: [TimeInterval] {
        var previous: TimeInterval = 0
        var lengths: [TimeInterval] = []
        for total in laps {
            lengths.append(total - previous)
            previous = total
        }
        return lengths.reversed()
    }
}

public enum StopwatchFormatter {
    /// "00:00.00", "12:04.37", "1:02:03.45". Hundredths round down, so the
    /// display never runs ahead of the clock.
    public static func string(from elapsed: TimeInterval) -> String {
        guard elapsed.isFinite, elapsed > 0 else { return "00:00.00" }
        let hundredths = Int((elapsed * 100).rounded(.down))
        let hours = hundredths / 360_000
        let minutes = (hundredths % 360_000) / 6_000
        let seconds = (hundredths % 6_000) / 100
        let fraction = hundredths % 100
        if hours > 0 {
            return String(format: "%d:%02d:%02d.%02d", hours, minutes, seconds, fraction)
        }
        return String(format: "%02d:%02d.%02d", minutes, seconds, fraction)
    }
}

// MARK: Pomodoro

/// Focus sessions with breaks between them: focus, short break, focus, ...
/// and a long break after every `sessionsPerSet` focus sessions. A finished
/// phase waits for you to start the next one.
public struct Pomodoro: Codable, Equatable, Sendable {
    public enum Phase: String, Codable, Sendable {
        case focus
        case shortBreak
        case longBreak

        public var title: String {
            switch self {
            case .focus: return "Focus"
            case .shortBreak: return "Short break"
            case .longBreak: return "Long break"
            }
        }

        public var isBreak: Bool { self != .focus }
    }

    public enum State: Equatable, Sendable {
        /// Waiting to start the current phase.
        case ready
        case running
        case paused
    }

    /// Focus and break lengths to choose from, in minutes.
    public struct Lengths: Codable, Hashable, Sendable, Identifiable {
        public var focus: Int
        public var shortBreak: Int
        public var longBreak: Int

        public init(focus: Int, shortBreak: Int, longBreak: Int) {
            self.focus = focus
            self.shortBreak = shortBreak
            self.longBreak = longBreak
        }

        public var id: String { "\(focus)/\(shortBreak)" }
        /// "25 / 5 min"
        public var title: String { "\(focus) / \(shortBreak) min" }

        public static let classic = Lengths(focus: 25, shortBreak: 5, longBreak: 15)
        public static let options = [
            Lengths(focus: 15, shortBreak: 3, longBreak: 10),
            classic,
            Lengths(focus: 50, shortBreak: 10, longBreak: 20),
        ]
    }

    public var lengths: Lengths = .classic
    public var sessionsPerSet = 4
    public private(set) var phase: Phase = .focus
    /// Focus sessions finished since the last long break.
    public private(set) var completedInSet = 0
    /// Focus sessions finished on `countedDay`.
    public private(set) var completedToday = 0
    public private(set) var countedDay: Date?
    public private(set) var endsAt: Date?
    public private(set) var remainingWhenPaused: TimeInterval?

    public init(lengths: Lengths = .classic, sessionsPerSet: Int = 4) {
        self.lengths = lengths
        self.sessionsPerSet = max(1, sessionsPerSet)
    }

    public func duration(of phase: Phase) -> TimeInterval {
        switch phase {
        case .focus: return TimeInterval(lengths.focus * 60)
        case .shortBreak: return TimeInterval(lengths.shortBreak * 60)
        case .longBreak: return TimeInterval(lengths.longBreak * 60)
        }
    }

    public var state: State {
        if remainingWhenPaused != nil { return .paused }
        return endsAt == nil ? .ready : .running
    }

    public func remaining(at date: Date) -> TimeInterval {
        if let remainingWhenPaused { return remainingWhenPaused }
        guard let endsAt else { return duration(of: phase) }
        return max(0, endsAt.timeIntervalSince(date))
    }

    /// 0 at the start of the phase, 1 at its end.
    public func progress(at date: Date) -> Double {
        let total = duration(of: phase)
        guard total > 0 else { return 1 }
        return min(1, max(0, 1 - remaining(at: date) / total))
    }

    /// 1-based number of the focus session in the current set, e.g. "2 of 4".
    public var sessionNumber: Int { min(completedInSet + 1, sessionsPerSet) }

    /// Sessions finished today, or 0 if the count is from another day.
    public func sessionsToday(at date: Date, calendar: Calendar) -> Int {
        guard let countedDay, calendar.isDate(countedDay, inSameDayAs: date) else { return 0 }
        return completedToday
    }

    public mutating func start(at date: Date) {
        switch state {
        case .ready: endsAt = date.addingTimeInterval(duration(of: phase))
        case .paused: resume(at: date)
        case .running: break
        }
    }

    public mutating func pause(at date: Date) {
        guard state == .running else { return }
        remainingWhenPaused = remaining(at: date)
        endsAt = nil
    }

    public mutating func resume(at date: Date) {
        guard let left = remainingWhenPaused else { return }
        endsAt = date.addingTimeInterval(left)
        remainingWhenPaused = nil
    }

    /// Ends the current phase now without counting it, and readies the next.
    public mutating func skip() {
        endsAt = nil
        remainingWhenPaused = nil
        phase = nextPhase(afterCompleting: false)
    }

    /// Back to a fresh focus session; today's count is kept.
    public mutating func reset() {
        endsAt = nil
        remainingWhenPaused = nil
        phase = .focus
        completedInSet = 0
    }

    /// If the running phase has ended by `date`, records it and readies the
    /// next phase. Returns the phase that ended, or nil.
    @discardableResult
    public mutating func advanceIfDue(at date: Date, calendar: Calendar) -> Phase? {
        guard let endsAt, date >= endsAt else { return nil }
        let ended = phase
        if ended == .focus {
            if let countedDay, calendar.isDate(countedDay, inSameDayAs: endsAt) {
                completedToday += 1
            } else {
                completedToday = 1
            }
            countedDay = calendar.startOfDay(for: endsAt)
        }
        phase = nextPhase(afterCompleting: true)
        self.endsAt = nil
        remainingWhenPaused = nil
        return ended
    }

    private mutating func nextPhase(afterCompleting completed: Bool) -> Phase {
        switch phase {
        case .focus:
            if completed { completedInSet += 1 }
            if completedInSet >= sessionsPerSet { return .longBreak }
            return .shortBreak
        case .longBreak:
            completedInSet = 0
            return .focus
        case .shortBreak:
            return .focus
        }
    }
}
