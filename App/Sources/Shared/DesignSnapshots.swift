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
            ("panel-calendar", AnyView(SamplePanel(title: "Calendar", selected: .calendar, tools: tools) { SampleCalendar() })),
            ("panel-weather", AnyView(SamplePanel(title: "Weather", selected: .weather, tools: tools) { SampleWeather() })),
            ("panel-keep-awake", AnyView(SamplePanel(title: "Keep Awake", selected: .keepAwake, tools: tools) { SampleKeepAwake() })),
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
        SystemReadouts(
            cpu: 0.23,
            cpuHistory: [0.12, 0.18, 0.15, 0.32, 0.41, 0.28, 0.22, 0.35, 0.19, 0.24, 0.3, 0.23],
            memory: MemoryUsage(used: 12_130_000_000, total: 17_179_869_184),
            network: NetworkRate(receivedPerSecond: 932_000, sentPerSecond: 22_400)
        )
    }
}

private struct SampleCalendar: View {
    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let at: (Int, Int) -> Date = { day, hour in
            calendar.date(byAdding: .hour, value: day * 24 + hour, to: today) ?? today
        }
        let events = [
            AgendaEvent(id: "1", title: "Design review", start: at(0, 10), end: at(0, 11),
                        isAllDay: false, color: ColorComponents(red: 0.35, green: 0.6, blue: 1)),
            AgendaEvent(id: "2", title: "Lunch with Priya", start: at(0, 13), end: at(0, 14),
                        isAllDay: false, location: "Cafe Lota", color: ColorComponents(red: 0.3, green: 0.8, blue: 0.5)),
            AgendaEvent(id: "3", title: "Release call", start: at(0, 16), end: at(0, 16) + 1_800,
                        isAllDay: false, color: ColorComponents(red: 0.9, green: 0.5, blue: 0.3),
                        meetingURL: URL(string: "https://meet.example.com/abc")),
            AgendaEvent(id: "4", title: "Dentist", start: at(2, 9), end: at(2, 10), isAllDay: false),
            AgendaEvent(id: "5", title: "Trip", start: at(5, 0), end: at(7, 0), isAllDay: true),
        ]
        CalendarContent(
            grid: MonthGrid(containing: today, calendar: calendar),
            today: today,
            now: at(0, 12),
            selectedDay: today,
            events: events,
            onSelect: { _ in },
            onShowMonth: { _ in },
            onShowToday: {},
            onOpen: { _ in },
            onJoin: { _ in }
        )
    }
}

private struct SampleWeather: View {
    var body: some View {
        let codes = [61, 0, 0, 2, 0, 1, 3]
        let days = (0..<7).map { offset -> DailyForecast in
            let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = "yyyy-MM-dd"
            return DailyForecast(day: formatter.string(from: date), high: Double(29 + offset % 4), low: Double(21 + offset % 2), code: codes[offset])
        }
        WeatherForecastView(
            snapshot: WeatherSnapshot(
                locationName: "Hyderabad", temperature: 24, apparentTemperature: 26, code: 0, isDay: false,
                windSpeed: 8, days: days, unit: .celsius, fetchedAt: Date()
            ),
            isOffline: false,
            onRefresh: {},
            onChangePlace: {}
        )
    }
}

private struct SampleKeepAwake: View {
    var body: some View {
        KeepAwakeContent(
            isActive: true,
            endsAt: Date().addingTimeInterval(3_600),
            displayOn: false,
            onToggle: {},
            onChoose: { _ in },
            onDisplayOn: { _ in }
        )
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
