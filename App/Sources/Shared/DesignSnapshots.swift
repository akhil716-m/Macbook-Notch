import AppKit
import NotchCore
import SwiftUI

/// Draws the design system and a few panels with sample content to PNGs,
/// so the look can be checked on a Mac without running the app by hand.
/// CI runs `MacbookNotch --design-snapshots <folder>`; the app writes the
/// images and quits without starting anything else.
///
/// Sample content only: nothing here reads the user's data.
@MainActor
enum DesignSnapshots {
    static let flag = "--design-snapshots"

    /// The output folder if the app was launched to draw snapshots.
    static var requestedFolder: URL? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        let path = arguments.indices.contains(index + 1) ? arguments[index + 1] : "snapshots"
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    static func write(to folder: URL) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let tools = NotchTool.allCases
        let pages: [(String, AnyView)] = [
            ("panel-converter", AnyView(SamplePanel(title: "Converter", selected: .converter, tools: tools) { SampleConverter() })),
            ("panel-system", AnyView(SamplePanel(title: "System", selected: .systemStats, tools: tools) { SampleSystem() })),
            ("panel-music", AnyView(SamplePanel(title: "Now Playing", selected: .nowPlaying, tools: tools) { SampleMusic() })),
            ("panel-timers", AnyView(SamplePanel(title: "Timers", selected: .timers, tools: tools, pinned: true) { SampleTimers() })),
            ("compact", AnyView(SampleCompact())),
            ("primitives", AnyView(SamplePrimitives())),
        ]
        for (name, view) in pages {
            let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark))
            renderer.scale = 2
            guard let image = renderer.nsImage,
                  let tiff = image.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
            else {
                print("snapshot \(name): failed to render")
                continue
            }
            let url = folder.appendingPathComponent("\(name).png")
            do {
                try png.write(to: url)
                print("snapshot \(name): \(url.path)")
            } catch {
                print("snapshot \(name): \(error.localizedDescription)")
            }
        }
    }
}

// MARK: Samples

/// The open panel at its real size, as it sits under a 37 pt menu bar.
private struct SamplePanel<Content: View>: View {
    let title: String
    let selected: NotchTool
    let tools: [NotchTool]
    var pinned = false
    @ViewBuilder let content: () -> Content

    private let menuBar: CGFloat = 37

    var body: some View {
        let size = NotchStyle.openSize
        let shape = NotchShape(earRadius: NotchStyle.EarRadius.open, bottomRadius: NotchStyle.BottomRadius.open)
        VStack(spacing: 0) {
            Color.clear.frame(height: menuBar)
            PanelHeader(title: title, isPinned: pinned, onTogglePin: {}, onOpenSettings: {})
                .padding(.leading, NotchStyle.Space.xl)
                .padding(.trailing, NotchStyle.Space.l)
            content()
                .padding(.horizontal, NotchStyle.Space.xl)
                .padding(.top, NotchStyle.Space.s)
                .padding(.bottom, NotchStyle.Space.m)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            ToolTabBar(tools: tools, selected: selected, onSelect: { _ in })
                .padding(.horizontal, NotchStyle.Space.l)
                .padding(.bottom, NotchStyle.Tab.bottomInset)
        }
        .frame(width: size.width, height: size.height)
        .padding(.horizontal, NotchStyle.EarRadius.open)
        .background(shape.fill(NotchStyle.Palette.background))
        .overlay(alignment: .top) {
            // Where the menu bar and the camera housing sit.
            Rectangle()
                .fill(Color.red.opacity(0.18))
                .frame(height: menuBar)
                .overlay(Text("menu bar / notch").font(.system(size: 10)).foregroundStyle(.red))
        }
        .padding(24)
        .background(Color(white: 0.55))
    }
}

private struct SampleConverter: View {
    @State private var category = ConversionCategory.length

    var body: some View {
        VStack(spacing: NotchStyle.Space.m) {
            SegmentedPicker(options: ConversionCategory.allCases, selection: $category, title: \.title)
            HStack(spacing: NotchStyle.Space.m) {
                valueCard("1", unit: "Metres")
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: NotchStyle.Row.iconSize, weight: .semibold))
                    .frame(width: NotchStyle.Row.iconHit)
                valueCard("0.001", unit: "Kilometres")
            }
        }
    }

    private func valueCard(_ value: String, unit: String) -> some View {
        VStack(spacing: NotchStyle.Space.s) {
            Text(value).font(NotchStyle.Font.display)
            Text(unit)
                .font(NotchStyle.Font.body)
                .padding(.horizontal, NotchStyle.Chip.horizontalPadding)
                .frame(height: NotchStyle.Chip.height)
                .background(Capsule().fill(NotchStyle.Palette.selection))
        }
        .foregroundStyle(NotchStyle.Palette.primaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .notchCard()
    }
}

private struct SampleSystem: View {
    var body: some View {
        VStack(spacing: 0) {
            StatRow(symbol: "cpu", title: "CPU", value: "25%") { MeterBar(fraction: 0.25) }
            Divider().overlay(NotchStyle.Palette.border)
            StatRow(symbol: "memorychip", title: "Memory", value: "12.1 GB") { MeterBar(fraction: 0.7) }
            Divider().overlay(NotchStyle.Palette.border)
            StatRow(symbol: "network", title: "Network", value: "") {
                HStack(spacing: NotchStyle.Space.m) {
                    Text("↓ 932 KB/s")
                    Text("↑ 22 KB/s")
                    Spacer(minLength: 0)
                }
                .font(NotchStyle.Font.caption.weight(.semibold))
                .foregroundStyle(NotchStyle.Palette.primaryText)
            }
            Divider().overlay(NotchStyle.Palette.border)
            StatRow(symbol: "waveform.path.ecg", title: "Recent CPU", value: "") {
                Sparkline(values: [0.2, 0.3, 0.25, 0.6, 0.4, 0.35, 0.5, 0.3, 0.2, 0.45])
                    .stroke(NotchStyle.Palette.secondaryText, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                    .frame(height: NotchStyle.Space.l)
            }
        }
        .notchCard(padding: NotchStyle.Space.m)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct SampleMusic: View {
    var body: some View {
        HStack(spacing: NotchStyle.Space.l) {
            ArtworkView(image: nil, size: NotchStyle.Artwork.openSize, cornerRadius: NotchStyle.Artwork.openRadius)
            VStack(alignment: .leading, spacing: NotchStyle.Space.xs) {
                Text("Song Title").font(NotchStyle.Font.title).foregroundStyle(NotchStyle.Palette.primaryText)
                Text("Artist · Spotify").font(NotchStyle.Font.subtitle).foregroundStyle(NotchStyle.Palette.secondaryText)
                VStack(spacing: NotchStyle.Space.xxs) {
                    MeterBar(fraction: 0.25).frame(height: NotchStyle.Scrubber.hitHeight)
                    HStack { Text("0:55"); Spacer(); Text("3:40") }
                        .font(NotchStyle.Font.caption)
                        .foregroundStyle(NotchStyle.Palette.tertiaryText)
                }
                HStack(spacing: NotchStyle.Controls.spacing) {
                    ForEach(["backward.fill", "pause.fill", "forward.fill"], id: \.self) { symbol in
                        Image(systemName: symbol)
                            .font(.system(size: symbol == "pause.fill" ? NotchStyle.Controls.playSize : NotchStyle.Controls.skipSize, weight: .semibold))
                            .frame(width: NotchStyle.Controls.hitSize, height: NotchStyle.Controls.hitSize)
                    }
                }
                .foregroundStyle(NotchStyle.Palette.primaryText)
                .frame(maxWidth: .infinity)
            }
        }
        .notchCard(padding: NotchStyle.Space.l, radius: NotchStyle.Card.radius + 4)
        .frame(maxHeight: .infinity)
    }
}

private struct SampleTimers: View {
    var body: some View {
        VStack(alignment: .leading, spacing: NotchStyle.Space.s) {
            HStack(spacing: NotchStyle.Space.xs) {
                ForEach(["1m", "5m", "10m", "25 Focus", "45m"], id: \.self) { title in
                    Button(title) {}.buttonStyle(ChipButtonStyle())
                }
            }
            ForEach(SampleTimer.all) { sample in
                let running = sample.running
                HStack(spacing: NotchStyle.Space.m) {
                    VStack(alignment: .leading, spacing: NotchStyle.Space.xxs) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(sample.time).font(NotchStyle.Font.countdown).foregroundStyle(NotchStyle.Palette.primaryText)
                            Text(sample.id).font(NotchStyle.Font.caption).foregroundStyle(NotchStyle.Palette.secondaryText)
                        }
                        MeterBar(fraction: sample.progress, tint: running ? NotchStyle.Palette.accent : NotchStyle.Palette.secondaryText)
                    }
                    RoundIconButton(symbol: running ? "pause.fill" : "play.fill", label: "", kind: .primary, size: NotchStyle.RoundButton.small) {}
                    RoundIconButton(symbol: "xmark", label: "", size: NotchStyle.RoundButton.small) {}
                }
                .notchCard(padding: NotchStyle.Space.m)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct SampleTimer: Identifiable {
    let id: String
    let time: String
    let progress: Double
    let running: Bool

    static let all = [
        SampleTimer(id: "Focus", time: "18:42", progress: 0.25, running: true),
        SampleTimer(id: "Tea", time: "2:10", progress: 0.6, running: false),
    ]
}

private struct SampleCompact: View {
    var body: some View {
        let notch = CGSize(width: 185, height: 32)
        let shape = NotchShape(earRadius: NotchStyle.EarRadius.compact, bottomRadius: NotchStyle.BottomRadius.compact)
        VStack(spacing: 24) {
            HStack(spacing: 0) {
                ProgressRing(fraction: 0.3, symbol: "timer")
                Spacer(minLength: notch.width)
                Text("24:56").font(NotchStyle.Font.compactValue).foregroundStyle(NotchStyle.Palette.primaryText)
            }
            .padding(.horizontal, NotchStyle.Space.l)
            .frame(width: notch.width + NotchStyle.wingWidth * 2, height: notch.height)
            .padding(.horizontal, NotchStyle.EarRadius.compact)
            .background(shape.fill(NotchStyle.Palette.background))

            HStack(spacing: 0) {
                ArtworkView(image: nil, size: NotchStyle.Artwork.compactSize, cornerRadius: NotchStyle.Artwork.compactRadius)
                Spacer(minLength: notch.width)
                EqualizerBars(isAnimating: false)
            }
            .padding(.horizontal, NotchStyle.Space.l)
            .frame(width: notch.width + NotchStyle.wingWidth * 2, height: notch.height)
            .padding(.horizontal, NotchStyle.EarRadius.compact)
            .background(shape.fill(NotchStyle.Palette.background))
        }
        .padding(24)
        .background(Color(white: 0.55))
    }
}

private struct SamplePrimitives: View {
    @State private var segment = "Stopwatch"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SegmentedPicker(options: ["Timer", "Stopwatch", "Pomodoro"], selection: $segment, title: { $0 })
            HStack(spacing: 12) {
                RoundIconButton(symbol: "play.fill", label: "", kind: .primary) {}
                RoundIconButton(symbol: "arrow.counterclockwise", label: "") {}
                RoundIconButton(symbol: "pause.fill", label: "", kind: .primary, size: NotchStyle.RoundButton.small) {}
                RoundIconButton(symbol: "xmark", label: "", size: NotchStyle.RoundButton.small) {}
                HeaderIconButton(symbol: "pin.fill", label: "", isOn: true) {}
                HeaderIconButton(symbol: "gearshape", label: "") {}
            }
            HStack(spacing: 8) {
                Button("Chip") {}.buttonStyle(ChipButtonStyle())
                Button("Prominent") {}.buttonStyle(ChipButtonStyle(isProminent: true))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Card title").font(NotchStyle.Font.title).foregroundStyle(NotchStyle.Palette.primaryText)
                Text("Secondary text").font(NotchStyle.Font.subtitle).foregroundStyle(NotchStyle.Palette.secondaryText)
                Text("Tertiary text, 10:41 AM").font(NotchStyle.Font.caption).foregroundStyle(NotchStyle.Palette.tertiaryText)
                MeterBar(fraction: 0.6)
                MeterBar(fraction: 0.4, tint: NotchStyle.Palette.accent)
                MeterBar(fraction: 0.8, tint: NotchStyle.Palette.overdue)
            }
            .frame(width: 280)
            .notchCard()
        }
        .padding(24)
        .background(NotchStyle.Palette.background)
    }
}
