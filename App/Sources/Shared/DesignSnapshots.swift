import AppKit
import NotchCore
import SwiftUI
import UniformTypeIdentifiers

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
            ("panel-shelf", AnyView(SamplePanel(title: "Shelf", selected: .shelf, tools: tools) { SampleShelf(empty: false) })),
            ("panel-shelf-empty", AnyView(SamplePanel(title: "Shelf", selected: .shelf, tools: tools) { SampleShelf(empty: true) })),
            ("panel-clipboard", AnyView(SamplePanel(title: "Clipboard", selected: .clipboard, tools: tools) { SampleClipboard() })),
            ("panel-todos", AnyView(SamplePanel(title: "To-dos", selected: .todos, tools: tools) { SampleTodos() })),
            ("panel-notes", AnyView(SamplePanel(title: "Notes", selected: .notes, tools: tools) { SampleNotes() })),
            ("panel-reminders", AnyView(SamplePanel(title: "Reminders", selected: .reminders, tools: tools) { SampleReminders() })),
            ("panel-ask", AnyView(SamplePanel(title: "Ask", selected: .ask, tools: tools) { SampleAsk(empty: false) })),
            ("panel-ask-empty", AnyView(SamplePanel(title: "Ask", selected: .ask, tools: tools) { SampleAsk(empty: true) })),
            ("panel-ai-usage", AnyView(SamplePanel(title: "AI Usage", selected: .aiUsage, tools: tools) { SampleAIUsage() })),
            ("panel-teleprompter", AnyView(SamplePanel(title: "Teleprompter", selected: .teleprompter, tools: tools) { SampleTeleprompter() })),
            ("panel-emoji", AnyView(SamplePanel(title: "Emoji", selected: .emoji, tools: tools) { SampleEmoji() })),
            ("panel-stocks", AnyView(SamplePanel(title: "Stocks", selected: .stocks, tools: tools) { SampleStocks() })),
            ("panel-revenue", AnyView(SamplePanel(title: "Revenue", selected: .revenue, tools: tools) { SampleRevenue() })),
            ("panel-music", AnyView(SamplePanel(title: "Now Playing", selected: .nowPlaying, tools: tools) { SampleMusic() })),
            ("panel-timers", AnyView(SamplePanel(title: "Timers", selected: .timers, tools: tools, pinned: true) { SampleTimers() })),
            ("compact", AnyView(SampleCompact())),
            ("primitives", AnyView(SamplePrimitives())),
        ]
        for (name, view) in pages {
            let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark).environment(\.isSnapshot, true))
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

private struct SampleShelf: View {
    let empty: Bool

    var body: some View {
        let now = Date()
        let files: [(String, UTType)] = [
            ("Q3 report.pdf", .pdf), ("Hero shot.png", .png), ("Invoice 2041.pdf", .pdf),
            ("Demo.mov", .quickTimeMovie), ("Notes.txt", .plainText),
        ]
        let items: [ShelfItem] = empty ? [] : files.map { file in
            ShelfItem(id: UUID(), filename: file.0, relativePath: file.0, isDirectory: false, byteSize: 1_000, addedAt: now, expiresAt: nil)
        }
        let types = Dictionary(uniqueKeysWithValues: files)
        ShelfContent(
            items: items,
            notice: nil,
            retention: .oneDay,
            canAirDrop: true,
            showsRemove: false,
            isDropTargeted: false,
            icon: { NSWorkspace.shared.icon(for: types[$0.filename] ?? .data) },
            dragURL: { _ in nil },
            onAirDropAll: {},
            onOpen: { _ in },
            onReveal: { _ in },
            onAirDrop: { _ in },
            onRemove: { _ in }
        )
    }
}

private struct SampleClipboard: View {
    var body: some View {
        let now = Date()
        let clips = [
            Clip(kind: .link, text: "https://developer.apple.com/documentation/swiftui", sourceAppName: "Safari",
                 copiedAt: now.addingTimeInterval(-40), contentHash: "1"),
            Clip(kind: .text, text: "Ship the notch build before the demo on Thursday.", sourceAppName: "Notes",
                 copiedAt: now.addingTimeInterval(-600), contentHash: "2"),
            Clip(kind: .files, filePaths: ["/Users/sample/Desktop/Q3 report.pdf"], sourceAppName: "Finder",
                 copiedAt: now.addingTimeInterval(-3_600), contentHash: "3"),
            Clip(kind: .text, text: "let spring = Animation.spring(response: 0.38, dampingFraction: 0.82)", sourceAppName: "Xcode",
                 copiedAt: now.addingTimeInterval(-7_200), contentHash: "4"),
        ]
        ClipboardContent(clips: clips, thumbnail: { _ in nil }, recentlyCopiedID: clips[1].id,
                         showsRemove: false, onCopy: { _ in }, onRemove: { _ in })
    }
}

private struct SampleTodos: View {
    var body: some View {
        var list = TodoList()
        let now = Date()
        list.add("Reply to the design review notes", at: now)
        list.add("Book the dentist", at: now.addingTimeInterval(1))
        let done = list.add("Send the Q3 report", at: now.addingTimeInterval(2))
        list.add("Water the plants", at: now.addingTimeInterval(3))
        if let done { list.toggle(done.id, at: now.addingTimeInterval(4)) }
        return TodosContent(items: list.items, draft: .constant(""), showsRemove: false,
                            onAdd: {}, onToggle: { _ in }, onRemove: { _ in }, onClearDone: {})
    }
}

private struct SampleNotes: View {
    var body: some View {
        let text = "Demo checklist\n\nOpen with the closed notch and a timer running. Hover to show the panel, then drop the deck on the Shelf.\nEnd on Calendar: next week is free."
        NotesContent(text: .constant(text), wordCount: Scratchpad(text: text).wordCount)
    }
}

private struct SampleReminders: View {
    var body: some View {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let items = [
            ReminderItem(id: "1", title: "Renew passport", dueDate: calendar.date(byAdding: .day, value: -2, to: today), color: ColorComponents(red: 1, green: 0.6, blue: 0.2)),
            ReminderItem(id: "2", title: "Call the bank", dueDate: now.addingTimeInterval(3_600 * 3), dueHasTime: true),
            ReminderItem(id: "3", title: "Pick up the parcel", dueDate: calendar.date(byAdding: .day, value: 1, to: today)),
            ReminderItem(id: "4", title: "Plan the team offsite"),
        ]
        RemindersContent(items: items, draft: .constant(""), isLoading: false, now: now,
                         onAdd: {}, onComplete: { _ in }, onOpenApp: {})
    }
}

private struct SampleAsk: View {
    let empty: Bool

    var body: some View {
        let messages = empty ? [] : [
            ChatMessage(role: .user, text: "Make this shorter: we're going to need to push the launch back a week because the build isn't ready."),
            ChatMessage(role: .assistant, text: "The build isn't ready, so we're moving the launch back a week."),
        ]
        AskContent(messages: messages, isThinking: false, draft: .constant(""), onSend: {}, onNewChat: {})
    }
}

private struct SampleAIUsage: View {
    var body: some View {
        let now = Date()
        AIUsageContent(
            claude: AIUsageService.ClaudeSummary(
                foundLogs: true,
                block: UsageBlock(start: now.addingTimeInterval(-7_200), end: now.addingTimeInterval(10_800), tokens: 1_240_000, lastActivity: now),
                lastWeek: 8_400_000
            ),
            codex: AIUsageService.CodexSummary(
                foundLogs: true,
                limits: RateLimits(
                    primary: RateLimitWindow(usedPercent: 61, windowMinutes: 300, resetsAt: now.addingTimeInterval(5_400)),
                    secondary: RateLimitWindow(usedPercent: 34, windowMinutes: 10_080, resetsAt: now.addingTimeInterval(300_000)),
                    observedAt: now
                ),
                lastWeek: 2_100_000
            ),
            now: now
        )
    }
}

private struct SampleTeleprompter: View {
    var body: some View {
        VStack(spacing: NotchStyle.Space.m) {
            ScriptText(text: "That means better prompts aren't always the answer.\n\nSmarter context and fewer repeats make an agent cheaper to run.", fontSize: 20)
                .frame(maxHeight: .infinity, alignment: .top)
                .clipped()
                .mask(ScriptFade())
            TeleprompterControls(isPlaying: true, isEditing: false, hasText: true, speed: .constant(32),
                                 onEdit: {}, onPlayPause: {}, onRestart: {}, onSmaller: {}, onLarger: {})
        }
    }
}

private struct SampleEmoji: View {
    var body: some View {
        EmojiContent(query: .constant(""), recent: ["👍", "🎉", "😂", "🙏", "🔥", "✅", "👀", "🚀"],
                     results: Array(EmojiCatalog.all.prefix(120)), copied: "🎉", onCopy: { _ in })
    }
}

private struct SampleStocks: View {
    var body: some View {
        let now = Date()
        let quotes = [
            "AAPL": StockQuote(symbol: "AAPL", price: 241.07, change: 3.6, changePercent: 1.53, fetchedAt: now),
            "MSFT": StockQuote(symbol: "MSFT", price: 516.17, change: 18.2, changePercent: 3.66, fetchedAt: now),
            "RELIANCE.NS": StockQuote(symbol: "RELIANCE.NS", price: 1_402.5, change: -9.1, changePercent: -0.64, fetchedAt: now),
            "TSLA": StockQuote(symbol: "TSLA", price: 438.69, change: -6.2, changePercent: -1.39, fetchedAt: now),
        ]
        StocksContent(symbols: ["AAPL", "MSFT", "RELIANCE.NS", "TSLA"], quotes: quotes, problem: nil)
    }
}

private struct SampleRevenue: View {
    var body: some View {
        let stripe = RevenueSource(provider: .stripe, name: "Notch app")
        let shopify = RevenueSource(provider: .shopify, name: "Merch store")
        var stripeTotals = MoneyTotals()
        stripeTotals.add(4_900, currency: "USD")
        stripeTotals.add(14_900, currency: "USD")
        stripeTotals.add(2_900, currency: "USD")
        var shopifyTotals = MoneyTotals()
        shopifyTotals.add(12_800, currency: "USD")
        let states: [UUID: RevenueService.SourceState] = [stripe.id: .loaded(stripeTotals), shopify.id: .loaded(shopifyTotals)]
        return RevenueContent(sources: [stripe, shopify], states: states, combined: stripeTotals + shopifyTotals, onRefresh: {})
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
