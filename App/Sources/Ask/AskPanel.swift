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
        VStack(spacing: NotchStyle.Space.s) {
            if ask.transcript.isEmpty && !ask.isThinking {
                EmptyToolState(symbol: "sparkles", title: AskAvailability.available.title, message: AskAvailability.available.message)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: NotchStyle.Space.s) {
                            ForEach(ask.transcript.messages) { message in
                                MessageBubble(message: message).id(message.id)
                            }
                            if ask.isThinking {
                                ThinkingDots().id("thinking")
                            }
                        }
                    }
                    .onChange(of: ask.transcript.messages.count) { _, _ in
                        scrollToEnd(proxy)
                    }
                    .onChange(of: ask.isThinking) { _, _ in
                        scrollToEnd(proxy)
                    }
                }
            }

            HStack(spacing: NotchStyle.Space.s) {
                TextField("Ask anything, then Return", text: $draft)
                    .textFieldStyle(.plain)
                    .font(NotchStyle.Font.body)
                    .padding(.horizontal, NotchStyle.Space.m)
                    .frame(height: NotchStyle.Chip.height + NotchStyle.Space.xs)
                    .background(
                        RoundedRectangle(cornerRadius: NotchStyle.Clipboard.rowRadius, style: .continuous)
                            .fill(NotchStyle.Palette.rowBackground)
                    )
                    .onSubmit { submit() }
                    .disabled(ask.isThinking)
                IconButton(symbol: "arrow.up.circle.fill", label: "Send", size: NotchStyle.Ask.sendSize) { submit() }
                    .disabled(ask.isThinking || draft.trimmingCharacters(in: .whitespaces).isEmpty)
                if !ask.transcript.isEmpty {
                    IconButton(symbol: "square.and.pencil", label: "New chat") { ask.newChat() }
                }
            }
        }
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

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if ask.isThinking {
                proxy.scrollTo("thinking", anchor: .bottom)
            } else if let last = ask.transcript.messages.last {
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
                .padding(.horizontal, NotchStyle.Space.m)
                .padding(.vertical, NotchStyle.Space.xs + 1)
                .background(
                    RoundedRectangle(cornerRadius: NotchStyle.Ask.bubbleRadius, style: .continuous)
                        .fill(message.role == .user ? NotchStyle.Palette.selection : NotchStyle.Palette.rowBackground)
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
