import NotchCore
import SwiftUI

// MARK: Calendar

/// The Calendar tool: what's left of today, and tomorrow.
struct CalendarPanel: View {
    @ObservedObject var calendar: CalendarService

    var body: some View {
        content
            .onAppear { calendar.reload() }
    }

    @ViewBuilder
    private var content: some View {
        switch calendar.access {
        case .notAsked:
            PermissionPrompt(
                symbol: "calendar",
                title: "See your day at a glance",
                message: "Show today's and tomorrow's events here. They stay on your Mac.",
                buttonTitle: "Allow Calendar Access",
                action: { calendar.requestAccess() }
            )
        case .denied:
            PermissionPrompt(
                symbol: "calendar.badge.exclamationmark",
                title: "Calendar access is off",
                message: "Turn on MacbookNotch in Privacy & Security › Calendars.",
                buttonTitle: "Open System Settings",
                action: { SystemSettingsLink.open("Privacy_Calendars") }
            )
        case .granted:
            TimelineView(.everyMinute) { context in
                let sections = Agenda.sections(calendar.events, now: context.date, calendar: .current)
                if sections.isEmpty {
                    EmptyToolState(symbol: "calendar", title: "Nothing scheduled", message: "Today and tomorrow are free.")
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: NotchStyle.Space.xs) {
                            ForEach(sections) { section in
                                Text(section.title.uppercased())
                                    .font(NotchStyle.Font.caption)
                                    .foregroundStyle(NotchStyle.Palette.secondaryText)
                                ForEach(section.events) { event in
                                    EventRow(
                                        event: event,
                                        isNow: event.isHappening(at: context.date),
                                        onOpen: { calendar.open(event) },
                                        onJoin: { calendar.join(event) }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct EventRow: View {
    let event: AgendaEvent
    let isNow: Bool
    let onOpen: () -> Void
    let onJoin: () -> Void

    var body: some View {
        HStack(spacing: NotchStyle.Space.m) {
            Capsule()
                .fill(Color(event.color, fallback: NotchStyle.Palette.accent))
                .frame(width: NotchStyle.Agenda.colorBarWidth)
            Text(timeText)
                .font(NotchStyle.Font.caption)
                .foregroundStyle(NotchStyle.Palette.secondaryText)
                .frame(width: NotchStyle.Agenda.timeColumn, alignment: .leading)
            VStack(alignment: .leading, spacing: 0) {
                Text(event.title)
                    .font(NotchStyle.Font.rowTitle)
                    .foregroundStyle(NotchStyle.Palette.primaryText)
                    .lineLimit(1)
                if let location = event.location, !location.isEmpty, event.meetingURL == nil {
                    Text(location)
                        .font(NotchStyle.Font.caption)
                        .foregroundStyle(NotchStyle.Palette.secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: NotchStyle.Space.xs)
            if isNow {
                Text("Now")
                    .font(NotchStyle.Font.caption)
                    .foregroundStyle(NotchStyle.Palette.live)
            }
            if event.meetingURL != nil {
                Button("Join", action: onJoin)
                    .buttonStyle(ChipButtonStyle(isProminent: true))
                    .accessibilityLabel("Join \(event.title)")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, NotchStyle.Space.xxs)
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the event in Calendar")
    }

    private var timeText: String {
        event.isAllDay ? "All day" : event.start.formatted(date: .omitted, time: .shortened)
    }
}

// MARK: Reminders

/// The Reminders tool: what's due, most urgent first. Tick to complete,
/// type to add to your default list.
struct RemindersPanel: View {
    @ObservedObject var reminders: RemindersService
    @State private var draft = ""

    var body: some View {
        content
            .onAppear { reminders.reload() }
    }

    @ViewBuilder
    private var content: some View {
        switch reminders.access {
        case .notAsked:
            PermissionPrompt(
                symbol: "list.bullet.circle",
                title: "Your reminders, one hover away",
                message: "See what's due and tick things off from the notch.",
                buttonTitle: "Allow Reminders Access",
                action: { reminders.requestAccess() }
            )
        case .denied:
            PermissionPrompt(
                symbol: "exclamationmark.circle",
                title: "Reminders access is off",
                message: "Turn on MacbookNotch in Privacy & Security › Reminders.",
                buttonTitle: "Open System Settings",
                action: { SystemSettingsLink.open("Privacy_Reminders") }
            )
        case .granted:
            VStack(alignment: .leading, spacing: NotchStyle.Space.s) {
                HStack(spacing: NotchStyle.Space.s) {
                    TextField("New reminder, then Return", text: $draft)
                        .textFieldStyle(.plain)
                        .font(NotchStyle.Font.body)
                        .padding(.horizontal, NotchStyle.Space.m)
                        .frame(height: NotchStyle.Chip.height + NotchStyle.Space.xs)
                        .background(
                            RoundedRectangle(cornerRadius: NotchStyle.Clipboard.rowRadius, style: .continuous)
                                .fill(NotchStyle.Palette.rowBackground)
                        )
                        .onSubmit {
                            reminders.add(draft)
                            draft = ""
                        }
                    Button("Open Reminders") { reminders.openRemindersApp() }
                        .buttonStyle(ChipButtonStyle())
                }
                if reminders.reminders.isEmpty {
                    EmptyToolState(
                        symbol: "checkmark.circle",
                        title: reminders.isLoading ? "Loading…" : "All done",
                        message: reminders.isLoading ? "" : "No open reminders."
                    )
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: NotchStyle.Space.xxs) {
                            ForEach(reminders.reminders) { item in
                                ReminderRow(item: item, onComplete: { reminders.complete(item) })
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct ReminderRow: View {
    let item: ReminderItem
    let onComplete: () -> Void

    var body: some View {
        let now = Date()
        let bucket = ReminderOrder.bucket(item, now: now, calendar: .current)
        HStack(spacing: NotchStyle.Space.m) {
            Button(action: onComplete) {
                Image(systemName: "circle")
                    .font(.system(size: NotchStyle.Row.iconSize + 2))
                    .foregroundStyle(Color(item.color, fallback: NotchStyle.Palette.secondaryText))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Complete \(item.title)")

            Text(item.title)
                .font(NotchStyle.Font.body)
                .foregroundStyle(NotchStyle.Palette.primaryText)
                .lineLimit(1)
            Spacer(minLength: NotchStyle.Space.xs)
            if let due = Self.dueText(item, bucket: bucket, now: now) {
                Text(due)
                    .font(NotchStyle.Font.caption)
                    .foregroundStyle(bucket == .overdue ? NotchStyle.Palette.overdue : NotchStyle.Palette.secondaryText)
            }
        }
        .padding(.horizontal, NotchStyle.Space.m)
        .padding(.vertical, NotchStyle.Space.xxs)
    }

    static func dueText(_ item: ReminderItem, bucket: ReminderBucket, now: Date) -> String? {
        guard let due = item.dueDate else { return nil }
        let calendar = Calendar.current
        let time = item.dueHasTime ? due.formatted(date: .omitted, time: .shortened) : nil
        switch bucket {
        case .overdue:
            return calendar.isDate(due, inSameDayAs: now)
                ? "Overdue, \(time ?? "today")"
                : "Overdue, \(due.formatted(.dateTime.month(.abbreviated).day()))"
        case .today:
            return time.map { "Today \($0)" } ?? "Today"
        case .upcoming:
            if calendar.isDateInTomorrow(due) {
                return time.map { "Tomorrow \($0)" } ?? "Tomorrow"
            }
            return due.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        case .someday:
            return nil
        }
    }
}
