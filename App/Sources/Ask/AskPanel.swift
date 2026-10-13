import NotchCore
import SwiftUI

/// The Ask tool: a small chat with Apple's on-device model.
struct AskPanel: View {
    @ObservedObject var ask: AskService
    @State private var draft = ""

    var body: some View {
        Group {
            switch ask.availability {
            case .available:
                chat
            default:
                unavailable
            }
        }
        .onAppear { ask.refreshAvailability() }
    }

    private var chat: some View {
        AskContent(
            messages: ask.transcript.messages,
            isThinking: ask.isThinking,
            draft: $draft,
            onSend: { submit() },
            onNewChat: { ask.newChat() }
        )
    }

    private var unavailable: some View {
        VStack(spacing: NotchStyle.Space.s) {
            Image(systemName: "sparkles")
                .font(.system(size: NotchStyle.Controls.playSize))
                .foregroundStyle(NotchStyle.Palette.secondaryText)
            Text(ask.availability.title)
                .font(NotchStyle.Font.emptyTitle)
                .foregroundStyle(NotchStyle.Palette.primaryText)
            Text(ask.availability.message)
                .font(NotchStyle.Font.emptyBody)
                .foregroundStyle(NotchStyle.Palette.secondaryText)
                .multilineTextAlignment(.center)
            if ask.availability.canOpenSettings {
                Button("Open Apple Intelligence Settings") { ask.openAppleIntelligenceSettings() }
                    .buttonStyle(ChipButtonStyle(isProminent: true))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func submit() {
        let text = draft
        draft = ""
        ask.send(text)
    }

}

/// The conversation and the input, from plain values so it can also be
/// drawn with sample data. Empty, it is one large question.
struct AskContent: View {
    let messages: [ChatMessage]
    let isThinking: Bool
    @Binding var draft: String
    let onSend: () -> Void
    let onNewChat: () -> Void

    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        VStack(spacing: NotchStyle.Space.s) {
            if messages.isEmpty && !isThinking {
                VStack(alignment: .leading, spacing: NotchStyle.Space.xs) {
                    Spacer(minLength: 0)
                    Text("What can I help with?")
                        .font(NotchStyle.Font.prompt)
                        .tracking(-0.5)
                        .foregroundStyle(NotchStyle.Palette.primaryText)
                    Text("Answers come from Apple Intelligence on this Mac. Nothing you type leaves it.")
                        .font(NotchStyle.Font.subtitle)
                        .foregroundStyle(NotchStyle.Palette.secondaryText)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if isSnapshot {
                transcript.frame(maxHeight: .infinity, alignment: .bottom)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) { transcript }
                        .onChange(of: messages.count) { _, _ in scrollToEnd(proxy) }
                        .onChange(of: isThinking) { _, _ in scrollToEnd(proxy) }
                        .onAppear { scrollToEnd(proxy) }
                }
            }

            HStack(spacing: NotchStyle.Space.s) {
                NotchTextField(placeholder: "Ask anything", text: $draft, symbol: "sparkles", onSubmit: onSend)
                    .disabled(isThinking)
                if !messages.isEmpty {
                    RoundIconButton(symbol: "square.and.pencil", label: "New chat", size: NotchStyle.Field.height, action: onNewChat)
                }
                RoundIconButton(
                    symbol: "arrow.up",
                    label: "Send",
                    kind: canSend ? .primary : .secondary,
                    size: NotchStyle.Field.height,
                    action: onSend
                )
                .disabled(!canSend)
            }
        }
    }

    private var canSend: Bool {
        !isThinking && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var transcript: some View {
        VStack(alignment: .leading, spacing: NotchStyle.Space.s) {
            ForEach(messages) { message in
                MessageBubble(message: message).id(message.id)
            }
            if isThinking {
                ThinkingDots().id("thinking")
            }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if isThinking {
                proxy.scrollTo("thinking", anchor: .bottom)
            } else if let last = messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: NotchStyle.Ask.bubbleInset) }
            Text(message.text)
                .font(NotchStyle.Font.body)
                .foregroundStyle(message.role == .notice ? NotchStyle.Palette.overdue : NotchStyle.Palette.primaryText)
                .textSelection(.enabled)
                .padding(.horizontal, NotchStyle.Space.m + 2)
                .padding(.vertical, NotchStyle.Space.s)
                .background(
                    RoundedRectangle(cornerRadius: NotchStyle.Ask.bubbleRadius, style: .continuous)
                        .fill(message.role == .user ? NotchStyle.Palette.raised : NotchStyle.Palette.rowBackground)
                )
            if message.role != .user { Spacer(minLength: NotchStyle.Ask.bubbleInset) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message.role == .user ? "You: \(message.text)" : message.text)
    }
}

private struct ThinkingDots: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.35)) { context in
            let step = Int(context.date.timeIntervalSinceReferenceDate / 0.35) % 3
            HStack(spacing: NotchStyle.Space.xs) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(NotchStyle.Palette.secondaryText)
                        .frame(width: 5, height: 5)
                        .opacity(index == step ? 1 : 0.35)
                }
            }
            .padding(.horizontal, NotchStyle.Space.m)
            .padding(.vertical, NotchStyle.Space.s)
            .background(
                RoundedRectangle(cornerRadius: NotchStyle.Ask.bubbleRadius, style: .continuous)
                    .fill(NotchStyle.Palette.rowBackground)
            )
        }
        .accessibilityLabel("Thinking")
    }
}

/// The closed notch while the volume changes: speaker left, level right.
struct CompactVolumeActivity: View {
    @ObservedObject var volume: VolumeService
    let notchWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: symbol)
                .font(NotchStyle.Font.compactIcon)
                .foregroundStyle(NotchStyle.Palette.primaryText)
                .frame(width: NotchStyle.Volume.iconWidth, alignment: .leading)
            Spacer(minLength: notchWidth)
            MeterBar(fraction: volume.isMuted ? 0 : Double(volume.level))
                .frame(width: NotchStyle.Volume.meterWidth)
        }
        .padding(.horizontal, NotchStyle.Space.l)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(volume.isMuted ? "Muted" : "Volume \(Int((volume.level * 100).rounded())) percent")
    }

    private var symbol: String {
        if volume.isMuted || volume.level == 0 { return "speaker.slash.fill" }
        if volume.level < 0.34 { return "speaker.wave.1.fill" }
        if volume.level < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}
