import NotchCore
import SwiftUI
import UniformTypeIdentifiers

/// Fills the fixed-size notch window. The black shape hangs from the top
/// centre and morphs between closed, compact and open.
struct NotchRootView: View {
    @ObservedObject var model: NotchViewModel
    let services: AppServices
    @ObservedObject var settings: AppSettings
    @ObservedObject var nowPlaying: NowPlayingService
    @ObservedObject var license: LicenseService
    let onTapClosed: () -> Void

    var body: some View {
        let presentation = model.presentation
        let size = model.layout.shapeSize(for: presentation)
        let ear = Self.earRadius(for: presentation)
        let shape = NotchShape(earRadius: ear, bottomRadius: Self.bottomRadius(for: presentation))

        ZStack(alignment: .top) {
            content(for: presentation)
                .id(presentation)
                .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
                .frame(width: size.width, height: size.height)
        }
        .frame(width: size.width + ear * 2, height: size.height)
        .background(shape.fill(NotchStyle.Palette.background))
        .clipShape(shape)
        .contentShape(shape)
        .shadow(
            color: presentation == .open ? NotchStyle.Palette.shadow : .clear,
            radius: NotchStyle.shadowRadius,
            y: NotchStyle.shadowOffset
        )
        .onTapGesture {
            if !model.isOpen { onTapClosed() }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $model.isDropTargeted) { providers in
            handleDrop(providers)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(NotchStyle.spring, value: presentation)
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func content(for presentation: NotchPresentation) -> some View {
        switch presentation {
        case .closed:
            Color.clear
        case .compact:
            compactContent(model.liveActivity)
        case .open:
            let selected = settings.tools.resolvedSelection(settings.selectedTool) ?? .home
            VStack(spacing: 0) {
                // Nothing goes level with the notch or the menu bar: the
                // camera housing and the menu bar can cover it.
                Color.clear.frame(height: model.layout.contentTop)
                PanelHeader(
                    title: selected == .home
                        ? Greeting.text(hour: Calendar.current.component(.hour, from: Date()), fullName: NSFullUserName())
                        : selected.title,
                    isPinned: model.isPinned,
                    onTogglePin: { model.isPinned.toggle() },
                    onOpenSettings: { services.openSettings() }
                )
                .padding(.leading, NotchStyle.Space.xl)
                .padding(.trailing, NotchStyle.Space.l)
                Group {
                    if license.allowsUse {
                        toolView(selected)
                    } else {
                        LicenseGate(license: license)
                    }
                }
                    .padding(.horizontal, NotchStyle.Space.xl)
                    .padding(.top, NotchStyle.Space.s)
                    .padding(.bottom, NotchStyle.Space.m)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                ToolTabBar(
                    tools: settings.tools.enabled,
                    selected: selected,
                    onSelect: { settings.selectedTool = $0 }
                )
                .padding(.horizontal, NotchStyle.Space.l)
                .padding(.bottom, NotchStyle.Tab.bottomInset)
            }
        }
    }

    @ViewBuilder
    private func toolView(_ tool: NotchTool) -> some View {
        switch tool {
        case .home:
            HomePanel(
                nowPlaying: nowPlaying,
                calendar: services.calendar,
                reminders: services.reminders,
                onShow: { settings.selectedTool = $0 }
            )
        case .nowPlaying:
            NowPlayingPanel(service: nowPlaying)
        case .shelf:
            ShelfPanel(shelf: services.shelf, model: model, retention: settings.shelfRetention)
        case .clipboard:
            ClipboardPanel(clipboard: services.clipboard, model: model)
        case .timers:
            TimersPanel(timers: services.timers)
        case .todos:
            TodosPanel(todos: services.todos, model: model)
        case .notes:
            NotesPanel(notes: services.notes)
        case .systemStats:
            SystemStatsPanel(stats: services.systemStats)
        case .keepAwake:
            KeepAwakePanel(keepAwake: services.keepAwake, settings: settings)
        case .calendar:
            CalendarPanel(calendar: services.calendar)
        case .reminders:
            RemindersPanel(reminders: services.reminders)
        case .weather:
            WeatherPanel(weather: services.weather, settings: settings)
        case .ask:
            AskPanel(ask: services.ask)
        case .aiUsage:
            AIUsagePanel(usage: services.aiUsage)
        case .teleprompter:
            TeleprompterPanel(prompter: services.teleprompter)
        case .mirror:
            MirrorPanel(camera: services.camera)
        case .emoji:
            EmojiPanel(settings: settings)
        case .converter:
            ConverterPanel(currency: services.currency)
        case .stocks:
            StocksPanel(stocks: services.stocks, settings: settings, onOpenSettings: { services.openSettings() })
        case .revenue:
            RevenuePanel(revenue: services.revenue, settings: settings, onOpenSettings: { services.openSettings() })
        }
    }

    @ViewBuilder
    private func compactContent(_ activity: LiveActivity) -> some View {
        let notchWidth = model.layout.notchSize.width
        switch activity {
        case .none:
            Color.clear
        case .music:
            CompactMusicActivity(
                artwork: nowPlaying.artwork,
                isPlaying: nowPlaying.track?.status == .playing,
                notchWidth: notchWidth
            )
        case .timer(let id):
            CompactTimerActivity(timers: services.timers, timerID: id, finished: false, notchWidth: notchWidth)
        case .timerFinished(let id):
            CompactTimerActivity(timers: services.timers, timerID: id, finished: true, notchWidth: notchWidth)
        case .keepAwake:
            CompactKeepAwakeActivity(notchWidth: notchWidth)
        case .pomodoro:
            CompactPomodoroActivity(timers: services.timers, notchWidth: notchWidth)
        case .stopwatch:
            CompactStopwatchActivity(timers: services.timers, notchWidth: notchWidth)
        case .volume:
            CompactVolumeActivity(volume: services.volume, notchWidth: notchWidth)
        }
    }

    /// Files dropped on the notch go to the shelf.
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard settings.tools.isEnabled(.shelf) else { return false }
        let fileProviders = providers.filter { $0.canLoadObject(ofClass: URL.self) }
        guard !fileProviders.isEmpty else { return false }
        settings.selectedTool = .shelf
        let shelf = services.shelf
        Task { @MainActor in
            var urls: [URL] = []
            for provider in fileProviders {
                if let url = await provider.loadFileURL() {
                    urls.append(url)
                }
            }
            shelf.add(urls)
        }
        return true
    }

    private static func earRadius(for presentation: NotchPresentation) -> CGFloat {
        switch presentation {
        case .closed: return NotchStyle.EarRadius.closed
        case .compact: return NotchStyle.EarRadius.compact
        case .open: return NotchStyle.EarRadius.open
        }
    }

    private static func bottomRadius(for presentation: NotchPresentation) -> CGFloat {
        switch presentation {
        case .closed: return NotchStyle.BottomRadius.closed
        case .compact: return NotchStyle.BottomRadius.compact
        case .open: return NotchStyle.BottomRadius.open
        }
    }
}

/// The top row of the open panel: the tool's name on the left, Pin and
/// Settings on the right.
struct PanelHeader: View {
    let title: String
    let isPinned: Bool
    let onTogglePin: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: NotchStyle.Space.xs) {
            Text(title)
                .font(NotchStyle.Font.header)
                .foregroundStyle(NotchStyle.Palette.primaryText)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: NotchStyle.Space.m)
            HeaderIconButton(
                symbol: isPinned ? "pin.fill" : "pin",
                label: isPinned ? "Unpin: close when the pointer leaves" : "Pin: keep open when the pointer leaves",
                isOn: isPinned,
                action: onTogglePin
            )
            HeaderIconButton(symbol: "gearshape", label: "Settings", action: onOpenSettings)
        }
        .frame(height: NotchStyle.Header.height)
    }
}

/// The tool icons along the bottom of the open panel, centred. When there
/// are more than fit, the row scrolls sideways and its ends fade.
struct ToolTabBar: View {
    let tools: [NotchTool]
    let selected: NotchTool
    let onSelect: (NotchTool) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    row.padding(.horizontal, NotchStyle.Space.m)
                }
                .mask(ScrollEdgeFade(width: NotchStyle.Space.m))
                .onAppear { proxy.scrollTo(selected, anchor: .center) }
                .onChange(of: selected) { _, tool in
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(tool, anchor: .center) }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: NotchStyle.Tab.barHeight)
    }

    private var row: some View {
        HStack(spacing: NotchStyle.Tab.spacing) {
            ForEach(tools) { tool in
                tab(tool).id(tool)
            }
        }
    }

    private func tab(_ tool: NotchTool) -> some View {
        let isSelected = tool == selected
        return Button {
            onSelect(tool)
        } label: {
            Image(systemName: tool.symbolName)
                .font(NotchStyle.Font.tab)
                .foregroundStyle(isSelected ? NotchStyle.Palette.primaryText : NotchStyle.Palette.secondaryText)
                .frame(width: NotchStyle.Tab.width, height: NotchStyle.Tab.height)
                .background(
                    RoundedRectangle(cornerRadius: NotchStyle.Tab.radius, style: .continuous)
                        .fill(isSelected ? NotchStyle.Palette.selection : Color.clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: NotchStyle.Tab.radius, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(tool.title)
        .accessibilityLabel(tool.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Opaque in the middle, fading to clear over `width` at each end.
private struct ScrollEdgeFade: View {
    let width: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: width)
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: width)
        }
    }
}

extension NSItemProvider {
    /// The file URL this provider carries, or nil.
    func loadFileURL() async -> URL? {
        await withCheckedContinuation { continuation in
            _ = loadObject(ofClass: URL.self) { url, _ in
                continuation.resume(returning: url?.isFileURL == true ? url : nil)
            }
        }
    }
}
