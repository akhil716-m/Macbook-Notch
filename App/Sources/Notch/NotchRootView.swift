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
            let selected = settings.tools.resolvedSelection(settings.selectedTool) ?? .nowPlaying
            VStack(spacing: 0) {
                NotchHeader(
                    tools: settings.tools.enabled,
                    selected: selected,
                    notchWidth: model.layout.notchSize.width,
                    panelWidth: model.layout.shapeSize(for: .open).width,
                    height: model.layout.notchSize.height,
                    onSelect: { settings.selectedTool = $0 },
                    onOpenSettings: { services.openSettings() }
                )
                Group {
                    if license.allowsUse {
                        toolView(selected)
                    } else {
                        LicenseGate(license: license)
                    }
                }
                    .padding(.horizontal, NotchStyle.Space.xl)
                    .padding(.top, NotchStyle.Space.xs)
                    .padding(.bottom, NotchStyle.Space.l)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func toolView(_ tool: NotchTool) -> some View {
        switch tool {
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

/// The strip beside the hardware notch: tool tabs fill the left side, then
/// the right (before Settings), then an overflow menu. Nothing sits under
/// the notch itself.
struct NotchHeader: View {
    let tools: [NotchTool]
    let selected: NotchTool
    let notchWidth: CGFloat
    let panelWidth: CGFloat
    let height: CGFloat
    let onSelect: (NotchTool) -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        let sideWidth = (panelWidth - notchWidth) / 2 - NotchStyle.Space.l - NotchStyle.Space.m
        let strip = TabStripLayout.split(
            count: tools.count,
            sideWidth: sideWidth,
            tabWidth: NotchStyle.Tab.width,
            spacing: NotchStyle.Space.xxs,
            rightReserved: NotchStyle.Tab.width + NotchStyle.Space.xxs
        )
        let left = Array(tools.prefix(strip.left))
        let right = Array(tools.dropFirst(strip.left).prefix(strip.right))
        let overflow = Array(tools.dropFirst(strip.left + strip.right))

        HStack(spacing: 0) {
            HStack(spacing: NotchStyle.Space.xxs) {
                ForEach(left) { tab($0) }
            }
            Spacer(minLength: notchWidth + NotchStyle.Space.m * 2)
            HStack(spacing: NotchStyle.Space.xxs) {
                ForEach(right) { tab($0) }
                if !overflow.isEmpty {
                    overflowMenu(overflow)
                }
                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape")
                        .font(NotchStyle.Font.tab)
                        .foregroundStyle(NotchStyle.Palette.secondaryText)
                        .frame(width: NotchStyle.Tab.width, height: NotchStyle.Tab.height)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Settings")
                .accessibilityLabel("Settings")
            }
        }
        .padding(.horizontal, NotchStyle.Space.l)
        .frame(height: height)
    }

    private func tab(_ tool: NotchTool) -> some View {
        Button {
            onSelect(tool)
        } label: {
            Image(systemName: tool.symbolName)
                .font(NotchStyle.Font.tab)
                .foregroundStyle(tool == selected ? NotchStyle.Palette.primaryText : NotchStyle.Palette.secondaryText)
                .frame(width: NotchStyle.Tab.width, height: NotchStyle.Tab.height)
                .background(Capsule().fill(tool == selected ? NotchStyle.Palette.selection : Color.clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(tool.title)
        .accessibilityLabel(tool.title)
        .accessibilityAddTraits(tool == selected ? .isSelected : [])
    }

    private func overflowMenu(_ tools: [NotchTool]) -> some View {
        let selectedInside = tools.contains(selected)
        return Menu {
            ForEach(tools) { tool in
                Button {
                    onSelect(tool)
                } label: {
                    Label(tool.title, systemImage: tool.symbolName)
                }
            }
        } label: {
            Image(systemName: selectedInside ? selected.symbolName : "ellipsis")
                .font(NotchStyle.Font.tab)
                .foregroundStyle(selectedInside ? NotchStyle.Palette.primaryText : NotchStyle.Palette.secondaryText)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: NotchStyle.Tab.width, height: NotchStyle.Tab.height)
        .background(Capsule().fill(selectedInside ? NotchStyle.Palette.selection : Color.clear))
        .help("More tools")
        .accessibilityLabel("More tools")
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
