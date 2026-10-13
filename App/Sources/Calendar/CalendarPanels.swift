import NotchCore
import SwiftUI

// MARK: Calendar

/// The Calendar tool: the whole month on the left, the chosen day's events
/// on the right. Opens on today.
struct CalendarPanel: View {
    @ObservedObject var calendar: CalendarService

    var body: some View {
        content
            .onAppear {
                calendar.showToday()
                calendar.reload()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch calendar.access {
        case .notAsked:
            PermissionPrompt(
                symbol: "calendar",
                title: "See your month at a glance",
                message: "Show your calendar and events here. They stay on your Mac.",
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
                CalendarContent(
                    grid: calendar.grid,
                    today: Calendar.current.startOfDay(for: context.date),
                    now: context.date,
                    selectedDay: calendar.selectedDay,
                    events: calendar.monthEvents,
                    onSelect: { calendar.select($0) },
                    onShowMonth: { calendar.showMonth(offset: $0) },
                    onShowToday: { calendar.showToday() },
                    onOpen: { calendar.open($0) },
                    onJoin: { calendar.join($0) }
                )
            }
        }
    }
}

/// The month grid and the day's agenda, from plain values so it can also be
/// drawn with sample data.
struct CalendarContent: View {
    let grid: MonthGrid
    let today: Date
    let now: Date
    let selectedDay: Date
    let events: [AgendaEvent]
    let onSelect: (Date) -> Void
    let onShowMonth: (Int) -> Void
    let onShowToday: () -> Void
    let onOpen: (AgendaEvent) -> Void
    let onJoin: (AgendaEvent) -> Void

    var body: some View {
        let calendar = Calendar.current
        HStack(alignment: .top, spacing: NotchStyle.Space.xl) {
            MonthCalendar(
                grid: grid,
                today: today,
                selectedDay: selectedDay,
                busyDays: events.busyDays(calendar: calendar),
                onSelect: onSelect,
                onShowMonth: onShowMonth,
                onShowToday: onShowToday
            )
            DayAgenda(
                title: Self.title(for: selectedDay, today: today, calendar: calendar),
                events: events.on(day: selectedDay, calendar: calendar),
                now: now,
                onOpen: onOpen,
                onJoin: onJoin
            )
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// "Today", "Tomorrow", "Yesterday", or "Wednesday 14 October".
    static func title(for day: Date, today: Date, calendar: Calendar) -> String {
        let offset = calendar.dateComponents([.day], from: today, to: day).day ?? 0
        switch offset {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        default: return day.formatted(.dateTime.weekday(.wide).day().month(.wide))
        }
    }
}

/// A compact month: title with arrows, weekday initials, and the days.
/// Today is a white disc; the chosen day a grey one; a dot marks days with events.
private struct MonthCalendar: View {
    let grid: MonthGrid
    let today: Date
    let selectedDay: Date
    let busyDays: Set<Date>
    let onSelect: (Date) -> Void
    let onShowMonth: (Int) -> Void
    let onShowToday: () -> Void

    private let cell = NotchStyle.MonthGrid.cell

    var body: some View {
        VStack(alignment: .leading, spacing: NotchStyle.Space.xs) {
            HStack(spacing: 0) {
                Button(action: onShowToday) {
                    Text(grid.monthStart.formatted(.dateTime.month(.wide).year()))
                        .font(NotchStyle.Font.title)
                        .foregroundStyle(NotchStyle.Palette.primaryText)
                }
                .buttonStyle(.plain)
                .help("Go to today")
                Spacer(minLength: NotchStyle.Space.xs)
                IconButton(symbol: "chevron.left", label: "Previous month") { onShowMonth(-1) }
                IconButton(symbol: "chevron.right", label: "Next month") { onShowMonth(1) }
            }
            .frame(width: cell.width * 7)

            HStack(spacing: 0) {
                ForEach(Array(grid.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(NotchStyle.Font.caption)
                        .foregroundStyle(NotchStyle.Palette.tertiaryText)
                        .frame(width: cell.width)
                }
            }
            .accessibilityHidden(true)

            VStack(spacing: 0) {
                ForEach(0..<grid.rowCount, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(grid.days[(row * 7)..<(row * 7 + 7)]) { day in
                            dayCell(day)
                        }
                    }
                }
            }
        }
    }

    private func dayCell(_ day: MonthDay) -> some View {
        let isToday = day.date == today
        let isSelected = day.date == selectedDay
        let isBusy = busyDays.contains(day.date)
        return Button {
            onSelect(day.date)
        } label: {
            Text("\(day.dayNumber)")
                .font(NotchStyle.Font.monthDay.weight(isToday ? .bold : .regular))
                .foregroundStyle(
                    isToday ? NotchStyle.Palette.background
                        : (day.isInMonth ? NotchStyle.Palette.primaryText : NotchStyle.Palette.tertiaryText.opacity(0.6))
                )
                .frame(width: NotchStyle.MonthGrid.disc, height: NotchStyle.MonthGrid.disc)
                .background(
                    Circle().fill(
                        isToday ? NotchStyle.Palette.fill
                            : (isSelected ? NotchStyle.Palette.selection : Color.clear)
                    )
                )
                .frame(width: cell.width, height: cell.height, alignment: .top)
                .overlay(alignment: .bottom) {
                    // Under the disc, so it never touches the number.
                    Circle()
                        .fill(isBusy ? NotchStyle.Palette.accent : Color.clear)
                        .frame(width: NotchStyle.MonthGrid.dot, height: NotchStyle.MonthGrid.dot)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted) + (isBusy ? ", has events" : ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The chosen day's events on a slightly lighter field.
private struct DayAgenda: View {
    let title: String
    let events: [AgendaEvent]
    let now: Date
    let onOpen: (AgendaEvent) -> Void
    let onJoin: (AgendaEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: NotchStyle.Space.s) {
            Text(title)
                .font(NotchStyle.Font.title)
                .foregroundStyle(NotchStyle.Palette.primaryText)
                .lineLimit(1)
            if events.isEmpty {
                Spacer(minLength: 0)
                Text("Nothing scheduled")
                    .font(NotchStyle.Font.body)
                    .foregroundStyle(NotchStyle.Palette.secondaryText)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            } else {
                // Scroll only when the day doesn't fit.
                ViewThatFits(in: .vertical) {
                    list
                    ScrollView(.vertical, showsIndicators: false) { list }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .notchCard()
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: NotchStyle.Space.xs) {
            ForEach(events) { event in
                EventRow(
                    event: event,
                    isNow: event.isHappening(at: now),
                    onOpen: { onOpen(event) },
                    onJoin: { onJoin(event) }
                )
                .opacity(event.end <= now ? 0.5 : 1)
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
            RemindersContent(
                items: reminders.reminders,
                draft: $draft,
                isLoading: reminders.isLoading,
                now: Date(),
                onAdd: {
                    reminders.add(draft)
                    draft = ""
                },
                onComplete: { reminders.complete($0) },
                onOpenApp: { reminders.openRemindersApp() }
            )
        }
    }
}

/// The count on the left, the list on the right, like To-dos. From plain
/// values so it can also be drawn with sample data.
struct RemindersContent: View {
    let items: [ReminderItem]
    @Binding var draft: String
    let isLoading: Bool
    let now: Date
    let onAdd: () -> Void
    let onComplete: (ReminderItem) -> Void
    let onOpenApp: () -> Void

    var body: some View {
        let overdue = items.filter { ReminderOrder.bucket($0, now: now, calendar: .current) == .overdue }.count
        HStack(alignment: .top, spacing: NotchStyle.Space.xl) {
            CountSummary(
                count: items.count,
                label: items.count == 1 ? "reminder" : "reminders",
                detail: overdue > 0 ? "\(overdue) overdue" : (items.isEmpty ? nil : "None overdue"),
                detailTint: overdue > 0 ? NotchStyle.Palette.overdue : NotchStyle.Palette.tertiaryText
            ) {
                Button("Open Reminders", action: onOpenApp)
                    .buttonStyle(ChipButtonStyle())
            }
            VStack(alignment: .leading, spacing: NotchStyle.Space.s) {
                NotchTextField(placeholder: "New reminder", text: $draft, onSubmit: onAdd)
                if items.isEmpty {
                    Text(isLoading ? "Loading…" : "All done. Nothing open in Reminders.")
                        .font(NotchStyle.Font.body)
                        .foregroundStyle(NotchStyle.Palette.secondaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Group {
                        if items.count <= NotchStyle.Todo.rowsWithoutScrolling {
                            VStack(spacing: 0) { rows }
                        } else {
                            ScrollView(.vertical, showsIndicators: false) {
                                LazyVStack(spacing: 0) { rows }
                            }
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                }
            }
        }
    }

    private var rows: some View {
        ForEach(items) { item in
            ReminderRow(item: item, now: now, onComplete: { onComplete(item) })
        }
    }
}

private struct ReminderRow: View {
    let item: ReminderItem
    let now: Date
    let onComplete: () -> Void

    @State private var isHovered = false

    var body: some View {
        let bucket = ReminderOrder.bucket(item, now: now, calendar: .current)
        HStack(spacing: NotchStyle.Space.m) {
            Button(action: onComplete) {
                Image(systemName: "circle")
                    .font(.system(size: NotchStyle.Todo.checkSize))
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
                    .foregroundStyle(bucket == .overdue ? NotchStyle.Palette.overdue : NotchStyle.Palette.tertiaryText)
            }
        }
        .padding(.horizontal, NotchStyle.Space.s)
        .padding(.vertical, NotchStyle.Space.xs + 1)
        .background(
            RoundedRectangle(cornerRadius: NotchStyle.Clipboard.rowRadius, style: .continuous)
                .fill(isHovered ? NotchStyle.Palette.rowBackground : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
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
