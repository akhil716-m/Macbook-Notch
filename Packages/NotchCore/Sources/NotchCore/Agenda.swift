import Foundation

/// A calendar event, copied out of EventKit so it can be sorted and tested
/// without a calendar database.
public struct AgendaEvent: Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var start: Date
    public var end: Date
    public var isAllDay: Bool
    public var location: String?
    public var calendarTitle: String
    /// sRGB components 0...1, or nil for the default colour.
    public var color: ColorComponents?
    /// A video-call link found in the event, if any.
    public var meetingURL: URL?

    public init(
        id: String,
        title: String,
        start: Date,
        end: Date,
        isAllDay: Bool,
        location: String? = nil,
        calendarTitle: String = "",
        color: ColorComponents? = nil,
        meetingURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.location = location
        self.calendarTitle = calendarTitle
        self.color = color
        self.meetingURL = meetingURL
    }

    public func isHappening(at date: Date) -> Bool {
        start <= date && date < end
    }
}

public struct ColorComponents: Hashable, Codable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}

public struct AgendaSection: Identifiable, Hashable, Sendable {
    public var id: String { title }
    public var title: String
    public var events: [AgendaEvent]
}

public enum Agenda {
    /// "Today" and "Tomorrow", without events that have already ended.
    /// Events that began earlier but are still going count as today.
    /// All-day events come first, then by start time.
    public static func sections(_ events: [AgendaEvent], now: Date, calendar: Calendar) -> [AgendaSection] {
        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday),
              let startOfDayAfter = calendar.date(byAdding: .day, value: 2, to: startOfToday)
        else { return [] }

        let upcoming = events.filter { $0.end > now }
        let today = upcoming.filter { $0.start < startOfTomorrow }
        let tomorrow = upcoming.filter { $0.start >= startOfTomorrow && $0.start < startOfDayAfter }

        var sections: [AgendaSection] = []
        if !today.isEmpty { sections.append(AgendaSection(title: "Today", events: ordered(today))) }
        if !tomorrow.isEmpty { sections.append(AgendaSection(title: "Tomorrow", events: ordered(tomorrow))) }
        return sections
    }

    /// The next timed event that hasn't started yet.
    public static func nextEvent(_ events: [AgendaEvent], after now: Date) -> AgendaEvent? {
        events
            .filter { !$0.isAllDay && $0.start > now }
            .min { $0.start < $1.start }
    }

    private static func ordered(_ events: [AgendaEvent]) -> [AgendaEvent] {
        events.sorted {
            if $0.isAllDay != $1.isAllDay { return $0.isAllDay }
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }
}

/// Finds a video-call link in an event's URL, location or notes.
public enum MeetingLink {
    /// Hosts that mean "this is a call you join".
    static let hosts = [
        "zoom.us", "meet.google.com", "teams.microsoft.com", "teams.live.com",
        "webex.com", "whereby.com", "around.co", "meet.jit.si", "facetime.apple.com",
    ]

    public static func find(in texts: [String?]) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        for text in texts.compactMap({ $0 }) where !text.isEmpty {
            let range = NSRange(text.startIndex..., in: text)
            for match in detector.matches(in: text, options: [], range: range) {
                guard let url = match.url, isMeeting(url) else { continue }
                return url
            }
        }
        return nil
    }

    public static func isMeeting(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = url.host?.lowercased()
        else { return false }
        return hosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}

// MARK: Reminders

public struct ReminderItem: Identifiable, Hashable, Sendable {
    public let id: String
    public var title: String
    public var dueDate: Date?
    /// False for "due on a day" without a time.
    public var dueHasTime: Bool
    public var listTitle: String
    public var color: ColorComponents?

    public init(
        id: String,
        title: String,
        dueDate: Date? = nil,
        dueHasTime: Bool = false,
        listTitle: String = "",
        color: ColorComponents? = nil
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.dueHasTime = dueHasTime
        self.listTitle = listTitle
        self.color = color
    }
}

public enum ReminderBucket: Int, Comparable, Sendable {
    case overdue
    case today
    case upcoming
    case someday

    public static func < (lhs: ReminderBucket, rhs: ReminderBucket) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum ReminderOrder {
    public static func bucket(_ item: ReminderItem, now: Date, calendar: Calendar) -> ReminderBucket {
        guard let due = item.dueDate else { return .someday }
        let startOfToday = calendar.startOfDay(for: now)
        let isOverdue = item.dueHasTime ? due < now : due < startOfToday
        if isOverdue { return .overdue }
        return calendar.isDate(due, inSameDayAs: now) ? .today : .upcoming
    }

    /// Overdue, then today, then later (each by due date), then undated in
    /// their original order.
    public static func sorted(_ items: [ReminderItem], now: Date, calendar: Calendar) -> [ReminderItem] {
        items.enumerated().sorted { lhs, rhs in
            let left = bucket(lhs.element, now: now, calendar: calendar)
            let right = bucket(rhs.element, now: now, calendar: calendar)
            if left != right { return left < right }
            if let a = lhs.element.dueDate, let b = rhs.element.dueDate, a != b { return a < b }
            return lhs.offset < rhs.offset
        }
        .map(\.element)
    }
}
