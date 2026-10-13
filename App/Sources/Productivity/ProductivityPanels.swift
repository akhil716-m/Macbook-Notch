import NotchCore
import SwiftUI

// MARK: Notes

/// The Notes tool: one scratchpad, saved as you type.
struct NotesPanel: View {
    @ObservedObject var notes: NotesService

    var body: some View {
        VStack(alignment: .leading, spacing: NotchStyle.Space.xs) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $notes.text)
                    .font(NotchStyle.Font.body)
                    .scrollContentBackground(.hidden)
                    .padding(NotchStyle.Space.xs)
                    .accessibilityLabel("Notes")
                if notes.text.isEmpty {
                    Text("Jot something down…")
                        .font(NotchStyle.Font.body)
                        .foregroundStyle(NotchStyle.Palette.secondaryText)
                        .padding(.horizontal, NotchStyle.Space.m + 1)
                        .padding(.vertical, NotchStyle.Space.xs)
                        .allowsHitTesting(false)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: NotchStyle.Clipboard.rowRadius, style: .continuous)
                    .fill(NotchStyle.Palette.rowBackground)
            )
            Text(notes.wordCount == 1 ? "1 word" : "\(notes.wordCount) words")
                .font(NotchStyle.Font.caption)
                .foregroundStyle(NotchStyle.Palette.secondaryText)
        }
    }
}

// MARK: To-dos

/// The To-dos tool: type and press Return to add; click the circle to tick.
struct TodosPanel: View {
    @ObservedObject var todos: TodoService
    @ObservedObject var model: NotchViewModel
    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: NotchStyle.Space.s) {
            HStack(spacing: NotchStyle.Space.s) {
                TextField("Add a to-do and press Return", text: $draft)
                    .textFieldStyle(.plain)
                    .font(NotchStyle.Font.body)
                    .padding(.horizontal, NotchStyle.Space.m)
                    .frame(height: NotchStyle.Chip.height + NotchStyle.Space.xs)
                    .background(
                        RoundedRectangle(cornerRadius: NotchStyle.Clipboard.rowRadius, style: .continuous)
                            .fill(NotchStyle.Palette.rowBackground)
                    )
                    .onSubmit {
                        todos.add(draft)
                        draft = ""
                    }
                if todos.list.hasCompleted {
                    Button("Clear done") { todos.clearCompleted() }
                        .buttonStyle(ChipButtonStyle())
                }
            }

            if todos.list.items.isEmpty {
                EmptyToolState(symbol: "checklist", title: "Nothing to do", message: "Add something above when it comes up.")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: NotchStyle.Space.xxs) {
                        ForEach(todos.list.items) { item in
                            TodoRow(
                                item: item,
                                showsRemove: model.optionHeld,
                                onToggle: { todos.toggle(item) },
                                onRemove: { todos.remove(item) }
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct TodoRow: View {
    let item: TodoItem
    let showsRemove: Bool
    let onToggle: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: NotchStyle.Space.m) {
            Button(action: onToggle) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: NotchStyle.Row.iconSize + 2))
                    .foregroundStyle(item.isDone ? NotchStyle.Palette.accent : NotchStyle.Palette.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isDone ? "Mark as not done" : "Mark as done")

            Text(item.title)
                .font(NotchStyle.Font.body)
                .strikethrough(item.isDone)
                .foregroundStyle(item.isDone ? NotchStyle.Palette.secondaryText : NotchStyle.Palette.primaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            if showsRemove {
                IconButton(symbol: "xmark", label: "Delete", action: onRemove)
            }
        }
        .padding(.horizontal, NotchStyle.Space.m)
        .padding(.vertical, NotchStyle.Space.xxs)
        .contextMenu {
            Button(item.isDone ? "Mark as Not Done" : "Mark as Done", action: onToggle)
            Button("Delete", role: .destructive, action: onRemove)
        }
    }
}

// MARK: Keep Awake

/// The Keep Awake tool: one big switch, plus how long.
struct KeepAwakePanel: View {
    @ObservedObject var keepAwake: KeepAwakeService
    @ObservedObject var settings: AppSettings

    var body: some View {
        KeepAwakeContent(
            isActive: keepAwake.isActive,
            endsAt: keepAwake.endsAt,
            displayOn: settings.keepAwakeDisplayOn,
            onToggle: {
                if keepAwake.isActive {
                    keepAwake.turnOff()
                } else {
                    keepAwake.turnOn(for: .indefinitely)
                }
            },
            onChoose: { keepAwake.turnOn(for: $0) },
            onDisplayOn: {
                settings.keepAwakeDisplayOn = $0
                keepAwake.applyDisplaySetting()
            }
        )
    }
}

/// One centred column: the big switch, what it means right now, and the
/// quick durations. From plain values so it can be drawn with sample data.
struct KeepAwakeContent: View {
    let isActive: Bool
    let endsAt: Date?
    let displayOn: Bool
    let onToggle: () -> Void
    let onChoose: (KeepAwakeDuration) -> Void
    let onDisplayOn: (Bool) -> Void

    var body: some View {
        VStack(spacing: NotchStyle.Space.m) {
            Button(action: onToggle) {
                Image(systemName: isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                    .font(.system(size: NotchStyle.KeepAwake.symbolSize, weight: .medium))
                    .foregroundStyle(isActive ? NotchStyle.Palette.background : NotchStyle.Palette.primaryText)
                    .frame(width: NotchStyle.KeepAwake.buttonSize, height: NotchStyle.KeepAwake.buttonSize)
                    .background(Circle().fill(isActive ? NotchStyle.Palette.accent : NotchStyle.Palette.selection))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isActive ? "Turn off Keep Awake" : "Keep the Mac awake")

            VStack(spacing: NotchStyle.Space.xxs) {
                Text(isActive ? "Staying awake" : "Sleeping as usual")
                    .font(NotchStyle.Font.title)
                    .foregroundStyle(NotchStyle.Palette.primaryText)
                Text(status)
                    .font(NotchStyle.Font.subtitle)
                    .foregroundStyle(NotchStyle.Palette.secondaryText)
            }

            HStack(spacing: NotchStyle.Space.xs) {
                ForEach(KeepAwakeDuration.allCases.filter { $0 != .indefinitely }) { duration in
                    Button(duration.title) { onChoose(duration) }
                        .buttonStyle(ChipButtonStyle())
                }
                Toggle("Display on too", isOn: Binding(get: { displayOn }, set: onDisplayOn))
                    .toggleStyle(.checkbox)
                    .font(NotchStyle.Font.caption)
                    .foregroundStyle(NotchStyle.Palette.secondaryText)
                    .padding(.leading, NotchStyle.Space.s)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var status: String {
        guard isActive else { return "Your Mac sleeps on its normal schedule." }
        guard let endsAt else { return "Until you turn it off." }
        return "Until \(endsAt.formatted(date: .omitted, time: .shortened))."
    }
}

/// The closed notch while Keep Awake is on.
struct CompactKeepAwakeActivity: View {
    let notchWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "cup.and.saucer.fill")
                .font(NotchStyle.Font.compactIcon)
                .foregroundStyle(NotchStyle.Palette.accent)
            Spacer(minLength: notchWidth)
            Text("On")
                .font(NotchStyle.Font.compactValue)
                .foregroundStyle(NotchStyle.Palette.secondaryText)
        }
        .padding(.horizontal, NotchStyle.Space.l)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Keep Awake is on")
    }
}
