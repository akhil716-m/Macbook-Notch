import NotchCore
import SwiftUI

// MARK: Notes

/// The Notes tool: one scratchpad on a full-size card, saved as you type.
struct NotesPanel: View {
    @ObservedObject var notes: NotesService

    var body: some View {
        NotesContent(text: $notes.text, wordCount: notes.wordCount)
    }
}

struct NotesContent: View {
    @Binding var text: String
    let wordCount: Int

    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        ZStack(alignment: .topLeading) {
            if isSnapshot {
                Text(text)
                    .font(NotchStyle.Font.notes)
                    .foregroundStyle(NotchStyle.Palette.primaryText)
                    .lineSpacing(NotchStyle.Space.xxs)
                    .padding(.horizontal, NotchStyle.Space.xs + 1)
            } else {
                TextEditor(text: $text)
                    .font(NotchStyle.Font.notes)
                    .lineSpacing(NotchStyle.Space.xxs)
                    .scrollContentBackground(.hidden)
                    .accessibilityLabel("Notes")
            }
            if text.isEmpty {
                Text("Jot something down…")
                    .font(NotchStyle.Font.notes)
                    .foregroundStyle(NotchStyle.Palette.tertiaryText)
                    .padding(.horizontal, NotchStyle.Space.xs + 1)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(NotchStyle.Card.padding)
        .padding(.bottom, NotchStyle.Space.l)
        .background(NotchCardBackground(radius: NotchStyle.Card.radius + 4))
        .overlay(alignment: .bottomTrailing) {
            Text(wordCount == 1 ? "1 word" : "\(wordCount) words")
                .font(NotchStyle.Font.caption)
                .foregroundStyle(NotchStyle.Palette.tertiaryText)
                .padding(NotchStyle.Card.padding)
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
        TodosContent(
            items: todos.list.items,
            draft: $draft,
            showsRemove: model.optionHeld,
            onAdd: {
                todos.add(draft)
                draft = ""
            },
            onToggle: { todos.toggle($0) },
            onRemove: { todos.remove($0) },
            onClearDone: { todos.clearCompleted() }
        )
    }
}

/// The count on the left, the list on the right. From plain values so it
/// can also be drawn with sample data.
struct TodosContent: View {
    let items: [TodoItem]
    @Binding var draft: String
    let showsRemove: Bool
    let onAdd: () -> Void
    let onToggle: (TodoItem) -> Void
    let onRemove: (TodoItem) -> Void
    let onClearDone: () -> Void

    var body: some View {
        let open = items.filter { !$0.isDone }.count
        let done = items.count - open
        HStack(alignment: .top, spacing: NotchStyle.Space.xl) {
            CountSummary(
                count: open,
                label: open == 1 ? "thing to do" : "things to do",
                detail: done > 0 ? "\(done) done" : nil
            ) {
                if done > 0 {
                    Button("Clear done", action: onClearDone)
                        .buttonStyle(ChipButtonStyle())
                }
            }
            VStack(alignment: .leading, spacing: NotchStyle.Space.s) {
                NotchTextField(placeholder: "Add a to-do", text: $draft, onSubmit: onAdd)
                if items.isEmpty {
                    Text("Nothing on the list. Type above and press Return.")
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
            TodoRow(
                item: item,
                showsRemove: showsRemove,
                onToggle: { onToggle(item) },
                onRemove: { onRemove(item) }
            )
        }
    }
}

private struct TodoRow: View {
    let item: TodoItem
    let showsRemove: Bool
    let onToggle: () -> Void
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: NotchStyle.Space.m) {
            Button(action: onToggle) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: NotchStyle.Todo.checkSize))
                    .foregroundStyle(item.isDone ? NotchStyle.Palette.accent : NotchStyle.Palette.secondaryText)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isDone ? "Mark \(item.title) as not done" : "Mark \(item.title) as done")

            Text(item.title)
                .font(NotchStyle.Font.body)
                .strikethrough(item.isDone, color: NotchStyle.Palette.tertiaryText)
                .foregroundStyle(item.isDone ? NotchStyle.Palette.tertiaryText : NotchStyle.Palette.primaryText)
                .lineLimit(1)
            Spacer(minLength: 0)
            if showsRemove {
                IconButton(symbol: "xmark", label: "Delete \(item.title)", action: onRemove)
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
                Button {
                    onDisplayOn(!displayOn)
                } label: {
                    Label("Screen on", systemImage: "display")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(ChipButtonStyle(isProminent: displayOn))
                .padding(.leading, NotchStyle.Space.s)
                .help("Keep the display on too, not just the Mac")
                .accessibilityLabel("Keep the display on too")
                .accessibilityAddTraits(displayOn ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var status: String {
        guard isActive else { return "Your Mac sleeps on its normal schedule." }
        guard let endsAt else { return "Until you turn it off" }
        return "Until \(endsAt.formatted(date: .omitted, time: .shortened))"
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
