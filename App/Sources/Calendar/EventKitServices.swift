import AppKit
import EventKit
import NotchCore

/// Where we stand with a Privacy & Security permission.
enum AccessState: Equatable {
    case notAsked
    case granted
    case denied
}

extension AccessState {
    init(_ status: EKAuthorizationStatus) {
        switch status {
        case .fullAccess: self = .granted
        case .notDetermined: self = .notAsked
        default: self = .denied // denied, restricted, write-only
        }
    }
}

extension RGBColor {
    init?(_ color: NSColor?) {
        guard let rgb = color?.usingColorSpace(.sRGB) else { return nil }
        self.init(red: Double(rgb.redComponent), green: Double(rgb.greenComponent), blue: Double(rgb.blueComponent))
    }
}

/// Today's and tomorrow's events from every calendar the Mac knows about
/// (iCloud, Google, Exchange... whatever is set up in Calendar).
@MainActor
final class CalendarService: ObservableObject {
    @Published private(set) var events: [AgendaEvent] = []
    @Published private(set) var access: AccessState

    private let store: EKEventStore
    private var observer: NSObjectProtocol?

    init(store: EKEventStore) {
        self.store = store
        access = AccessState(EKEventStore.authorizationStatus(for: .event))
    }

    func start() {
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        reload()
    }

    func requestAccess() {
        Task {
            _ = try? await self.store.requestFullAccessToEvents()
            self.access = AccessState(EKEventStore.authorizationStatus(for: .event))
            self.reload()
        }
    }

    func reload() {
        access = AccessState(EKEventStore.authorizationStatus(for: .event))
        guard access == .granted else {
            events = []
            return
        }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 2, to: start) else { return }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = store.events(matching: predicate).map { event in
            AgendaEvent(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title.flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled",
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay,
                location: event.location,
                calendarTitle: event.calendar?.title ?? "",
                color: RGBColor(event.calendar?.color),
                meetingURL: MeetingLink.find(in: [event.url?.absoluteString, event.location, event.notes])
            )
        }
    }

    /// Opens the event in Calendar.
    func open(_ event: AgendaEvent) {
        let escaped = event.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? event.id
        if let url = URL(string: "ical://ekevent/\(escaped)?method=show&options=more"), NSWorkspace.shared.open(url) {
            return
        }
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.open(app)
        }
    }

    func join(_ event: AgendaEvent) {
        guard let url = event.meetingURL else { return }
        NSWorkspace.shared.open(url)
    }
}

/// Incomplete reminders from Apple Reminders, most urgent first.
@MainActor
final class RemindersService: ObservableObject {
    @Published private(set) var reminders: [ReminderItem] = []
    @Published private(set) var access: AccessState
    @Published private(set) var isLoading = false

    private let store: EKEventStore
    private var observer: NSObjectProtocol?

    init(store: EKEventStore) {
        self.store = store
        access = AccessState(EKEventStore.authorizationStatus(for: .reminder))
    }

    func start() {
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        reload()
    }

    func requestAccess() {
        Task {
            _ = try? await self.store.requestFullAccessToReminders()
            self.access = AccessState(EKEventStore.authorizationStatus(for: .reminder))
            self.reload()
        }
    }

    func reload() {
        access = AccessState(EKEventStore.authorizationStatus(for: .reminder))
        guard access == .granted else {
            reminders = []
            return
        }
        isLoading = true
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        // EventKit calls back on a background queue; copy what we need there.
        store.fetchReminders(matching: predicate) { [weak self] fetched in
            let calendar = Calendar.current
            let items: [ReminderItem] = (fetched ?? []).map { reminder in
                let components = reminder.dueDateComponents
                return ReminderItem(
                    id: reminder.calendarItemIdentifier,
                    title: reminder.title.flatMap { $0.isEmpty ? nil : $0 } ?? "Untitled",
                    dueDate: components.flatMap { calendar.date(from: $0) },
                    dueHasTime: components?.hour != nil,
                    listTitle: reminder.calendar?.title ?? "",
                    color: RGBColor(reminder.calendar?.color)
                )
            }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.reminders = ReminderOrder.sorted(items, now: Date(), calendar: calendar)
                    self.isLoading = false
                }
            }
        }
    }

    func complete(_ item: ReminderItem) {
        guard let reminder = store.calendarItem(withIdentifier: item.id) as? EKReminder else { return }
        reminder.isCompleted = true
        do {
            try store.save(reminder, commit: true)
            reminders.removeAll { $0.id == item.id }
        } catch {
            NSLog("MacbookNotch: could not complete reminder: \(error.localizedDescription)")
        }
    }

    /// Adds to the default Reminders list.
    func add(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let list = store.defaultCalendarForNewReminders() else { return }
        let reminder = EKReminder(eventStore: store)
        reminder.title = trimmed
        reminder.calendar = list
        do {
            try store.save(reminder, commit: true)
            reload()
        } catch {
            NSLog("MacbookNotch: could not add reminder: \(error.localizedDescription)")
        }
    }

    func openRemindersApp() {
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.reminders") {
            NSWorkspace.shared.open(app)
        }
    }
}
