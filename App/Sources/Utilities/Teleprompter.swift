import NotchCore
import SwiftUI

/// The script scrolls right under the camera, which on a MacBook sits in
/// the notch, so you can read while looking (almost) at the lens.
@MainActor
final class TeleprompterService: ObservableObject {
    struct Saved: Codable {
        var text: String
        var speed: Double
        var fontSize: Double
    }

    static let speedRange: ClosedRange<Double> = 10...120
    static let fontRange: ClosedRange<Double> = 14...32

    @Published var text: String = "" { didSet { save() } }
    /// Points per second.
    @Published var speed: Double = 32 { didSet { save() } }
    @Published var fontSize: Double = 20 { didSet { save() } }
    @Published private(set) var isPlaying = false

    private var startedAt: Date?
    private var offsetAtStart: CGFloat = 0
    private let file: LocalFile<Saved>
    private var loading = false

    init(fileURL: URL) {
        file = LocalFile(url: fileURL)
    }

    func start() {
        guard let saved = file.load() else { return }
        loading = true
        text = saved.text
        speed = Self.speedRange.clamped(saved.speed)
        fontSize = Self.fontRange.clamped(saved.fontSize)
        loading = false
    }

    func offset(at date: Date) -> CGFloat {
        guard isPlaying, let startedAt else { return offsetAtStart }
        return offsetAtStart + CGFloat(date.timeIntervalSince(startedAt) * speed)
    }

    func play() {
        guard !isPlaying, !text.isEmpty else { return }
        startedAt = Date()
        isPlaying = true
    }

    func pause() {
        guard isPlaying else { return }
        offsetAtStart = offset(at: Date())
        isPlaying = false
        startedAt = nil
    }

    func restart() {
        let wasPlaying = isPlaying
        isPlaying = false
        startedAt = nil
        offsetAtStart = 0
        if wasPlaying { play() }
    }

    /// Speed changes mid-read keep the current position.
    func setSpeed(_ value: Double) {
        let now = Date()
        offsetAtStart = offset(at: now)
        if isPlaying { startedAt = now }
        speed = Self.speedRange.clamped(value)
    }

    private func save() {
        guard !loading else { return }
        file.save(Saved(text: text, speed: speed, fontSize: fontSize))
    }
}

extension ClosedRange where Bound == Double {
    func clamped(_ value: Double) -> Double {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}

struct TeleprompterPanel: View {
    @ObservedObject var prompter: TeleprompterService
    @State private var editing = false
    @State private var textHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: NotchStyle.Space.m) {
            if editing || prompter.text.isEmpty {
                TextEditor(text: $prompter.text)
                    .font(NotchStyle.Font.notes)
                    .scrollContentBackground(.hidden)
                    .padding(NotchStyle.Space.s)
                    .background(NotchCardBackground(radius: NotchStyle.Card.radius + 4))
                    .overlay(alignment: .topLeading) {
                        if prompter.text.isEmpty {
                            Text("Paste or type your script here")
                                .font(NotchStyle.Font.notes)
                                .foregroundStyle(NotchStyle.Palette.tertiaryText)
                                .padding(NotchStyle.Space.m + 2)
                                .allowsHitTesting(false)
                        }
                    }
            } else {
                reader
            }
            TeleprompterControls(
                isPlaying: prompter.isPlaying,
                isEditing: editing,
                hasText: !prompter.text.isEmpty,
                speed: Binding(get: { prompter.speed }, set: { prompter.setSpeed($0) }),
                onEdit: {
                    prompter.pause()
                    editing.toggle()
                },
                onPlayPause: {
                    editing = false
                    prompter.isPlaying ? prompter.pause() : prompter.play()
                },
                onRestart: { prompter.restart() },
                onSmaller: { prompter.fontSize = TeleprompterService.fontRange.clamped(prompter.fontSize - 2) },
                onLarger: { prompter.fontSize = TeleprompterService.fontRange.clamped(prompter.fontSize + 2) }
            )
        }
    }

    private var reader: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !prompter.isPlaying)) { context in
            let offset = prompter.offset(at: context.date)
            GeometryReader { geometry in
                ScriptText(text: prompter.text, fontSize: prompter.fontSize)
                    .frame(width: geometry.size.width)
                    .background(
                        GeometryReader { text in
                            Color.clear
                                .onAppear { textHeight = text.size.height }
                                .onChange(of: text.size.height) { _, height in textHeight = height }
                        }
                    )
                    .offset(y: -offset)
                    .onChange(of: offset > textHeight && textHeight > 0) { _, finished in
                        if finished { prompter.pause() }
                    }
            }
            .clipped()
            .mask(ScriptFade())
        }
        .accessibilityLabel("Script")
        .accessibilityValue(prompter.text)
    }
}

/// The script, centred, at the reading size.
struct ScriptText: View {
    let text: String
    let fontSize: CGFloat

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .medium))
            .foregroundStyle(NotchStyle.Palette.primaryText)
            .lineSpacing(fontSize * 0.25)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Lines fade in at the bottom and out at the top, so the eye stays on the
/// middle of the script.
struct ScriptFade: View {
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .frame(height: NotchStyle.Teleprompter.fade)
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: NotchStyle.Teleprompter.fade)
        }
    }
}

/// Edit, play and restart in round buttons, then speed and text size.
struct TeleprompterControls: View {
    let isPlaying: Bool
    let isEditing: Bool
    let hasText: Bool
    @Binding var speed: Double
    let onEdit: () -> Void
    let onPlayPause: () -> Void
    let onRestart: () -> Void
    let onSmaller: () -> Void
    let onLarger: () -> Void

    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        HStack(spacing: NotchStyle.Space.s) {
            let small = NotchStyle.RoundButton.small
            RoundIconButton(symbol: isEditing ? "checkmark" : "pencil", label: isEditing ? "Done editing" : "Edit script", size: small, action: onEdit)
                .disabled(!hasText && !isEditing)
            RoundIconButton(
                symbol: isPlaying ? "pause.fill" : "play.fill",
                label: isPlaying ? "Pause" : "Play",
                kind: .primary,
                size: NotchStyle.Teleprompter.playSize,
                action: onPlayPause
            )
            .disabled(!hasText)
            RoundIconButton(symbol: "arrow.counterclockwise", label: "Back to the start", size: small, action: onRestart)

            HStack(spacing: NotchStyle.Space.xs) {
                Image(systemName: "tortoise.fill")
                if isSnapshot {
                    MeterBar(fraction: (speed - TeleprompterService.speedRange.lowerBound)
                        / (TeleprompterService.speedRange.upperBound - TeleprompterService.speedRange.lowerBound))
                        .frame(width: NotchStyle.Teleprompter.sliderWidth)
                } else {
                    Slider(value: $speed, in: TeleprompterService.speedRange)
                        .controlSize(.small)
                        .frame(width: NotchStyle.Teleprompter.sliderWidth)
                        .accessibilityLabel("Scroll speed")
                }
                Image(systemName: "hare.fill")
            }
            .font(.system(size: NotchStyle.Row.iconSize))
            .foregroundStyle(NotchStyle.Palette.tertiaryText)
            .padding(.leading, NotchStyle.Space.m)

            IconButton(symbol: "textformat.size.smaller", label: "Smaller text", action: onSmaller)
            IconButton(symbol: "textformat.size.larger", label: "Larger text", action: onLarger)
        }
        .frame(maxWidth: .infinity)
    }
}
