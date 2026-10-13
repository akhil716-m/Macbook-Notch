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

/// One cell of the month calendar.
public struct MonthDay: Identifiable, Hashable, Sendable {
    /// Midnight at the start of this day.
    public let date: Date
    public let dayNumber: Int
    /// False for the leading and trailing days of the neighbouring months.
    public let isInMonth: Bool
    public var id: Date { date }
}

/// The days shown for a month: whole weeks starting on the calendar's first
/// weekday, so the grid always has 7 columns and 4 to 6 rows.
public struct MonthGrid: Hashable, Sendable {
    /// Midnight on the first day of the month.
    public let monthStart: Date
    public let days: [MonthDay]
    /// Short weekday names in column order, e.g. ["M", "T", "W", ...].
    public let weekdaySymbols: [String]

    public init(containing date: Date, calendar: Calendar) {
        let start = calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        monthStart = start
        let month = calendar.component(.month, from: start)
        let dayCount = calendar.range(of: .day, in: .month, for: start)?.count ?? 30

        // How many days of the previous month lead into the first row.
        let firstWeekday = calendar.component(.weekday, from: start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let cells = Int(((Double(leading + dayCount)) / 7).rounded(.up)) * 7

        var days: [MonthDay] = []
        days.reserveCapacity(cells)
        for offset in 0..<cells {
            guard let day = calendar.date(byAdding: .day, value: offset - leading, to: start) else { continue }
            days.append(MonthDay(
                date: day,
                dayNumber: calendar.component(.day, from: day),
                isInMonth: calendar.component(.month, from: day) == month
            ))
        }
        self.days = days

        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        weekdaySymbols = Array(symbols[first...] + symbols[..<first])
    }

    /// From the first shown day to just after the last, for fetching events.
    public var interval: DateInterval {
        let start = days.first?.date ?? monthStart
        let end = days.last.map { $0.date.addingTimeInterval(86_400) } ?? monthStart
        return DateInterval(start: start, end: max(start, end))
    }

    public var rowCount: Int { days.count / 7 }

    /// The same grid for the month before (-1) or after (+1).
    public func shifted(by months: Int, calendar: Calendar) -> MonthGrid {
        let target = calendar.date(byAdding: .month, value: months, to: monthStart) ?? monthStart
        return MonthGrid(containing: target, calendar: calendar)
    }
}

extension Array where Element == AgendaEvent {
    /// The events that touch the given day (all-day events first, then by
    /// start time). Multi-day events appear on every day they cover.
    public func on(day: Date, calendar: Calendar) -> [AgendaEvent] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        return filter { ($0.start < end && $0.end > start) || ($0.start == start && $0.end == start) }
            .sorted { lhs, rhs in
                if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
                return lhs.start < rhs.start
            }
    }

    /// Midnights of the days that have at least one event.
    public func busyDays(calendar: Calendar) -> Set<Date> {
        var days = Set<Date>()
        for event in self {
            var day = calendar.startOfDay(for: event.start)
            // Cap long events so a year-long one can't spin for ever.
            var count = 0
            repeat {
                days.insert(day)
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
                count += 1
            } while day < event.end && count < 62
        }
        return days
    }
}
