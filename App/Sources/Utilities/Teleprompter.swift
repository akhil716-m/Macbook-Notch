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
        VStack(spacing: NotchStyle.Space.s) {
            if editing || prompter.text.isEmpty {
                TextEditor(text: $prompter.text)
                    .font(NotchStyle.Font.body)
                    .scrollContentBackground(.hidden)
                    .padding(NotchStyle.Space.xs)
                    .background(
                        RoundedRectangle(cornerRadius: NotchStyle.Clipboard.rowRadius, style: .continuous)
                            .fill(NotchStyle.Palette.rowBackground)
                    )
                    .overlay(alignment: .topLeading) {
                        if prompter.text.isEmpty {
                            Text("Paste or type your script here")
                                .font(NotchStyle.Font.body)
                                .foregroundStyle(NotchStyle.Palette.secondaryText)
                                .padding(NotchStyle.Space.m)
                                .allowsHitTesting(false)
                        }
                    }
            } else {
                reader
            }
            controls
        }
    }

    private var reader: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !prompter.isPlaying)) { context in
            let offset = prompter.offset(at: context.date)
            GeometryReader { geometry in
                Text(prompter.text)
                    .font(.system(size: prompter.fontSize, weight: .medium))
                    .foregroundStyle(NotchStyle.Palette.primaryText)
                    .lineSpacing(prompter.fontSize * 0.25)
                    .frame(width: geometry.size.width, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
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
        }
        .accessibilityLabel("Script")
        .accessibilityValue(prompter.text)
    }

    private var controls: some View {
        HStack(spacing: NotchStyle.Space.s) {
            Button(editing ? "Done" : "Edit") {
                prompter.pause()
                editing.toggle()
            }
            .buttonStyle(ChipButtonStyle())
            .disabled(prompter.text.isEmpty && !editing)

            IconButton(symbol: prompter.isPlaying ? "pause.fill" : "play.fill", label: prompter.isPlaying ? "Pause" : "Play") {
                editing = false
                prompter.isPlaying ? prompter.pause() : prompter.play()
            }
            .disabled(prompter.text.isEmpty)
            IconButton(symbol: "backward.end.fill", label: "Back to the start") { prompter.restart() }

            Image(systemName: "tortoise")
                .foregroundStyle(NotchStyle.Palette.secondaryText)
            Slider(
                value: Binding(get: { prompter.speed }, set: { prompter.setSpeed($0) }),
                in: TeleprompterService.speedRange
            )
            .controlSize(.mini)
            .accessibilityLabel("Scroll speed")
            Image(systemName: "hare")
                .foregroundStyle(NotchStyle.Palette.secondaryText)

            IconButton(symbol: "textformat.size.smaller", label: "Smaller text") {
                prompter.fontSize = TeleprompterService.fontRange.clamped(prompter.fontSize - 2)
            }
            IconButton(symbol: "textformat.size.larger", label: "Larger text") {
                prompter.fontSize = TeleprompterService.fontRange.clamped(prompter.fontSize + 2)
            }
        }
        .font(NotchStyle.Font.caption)
    }
}
