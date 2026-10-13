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
            CompactMusicActivity(
                artwork: nowPlaying.artwork,
                isPlaying: nowPlaying.track?.status == .playing,
                notchWidth: model.layout.notchSize.width
            )
        case .open:
            let selected = settings.tools.resolvedSelection(settings.selectedTool) ?? .nowPlaying
            VStack(spacing: 0) {
                NotchHeader(
                    tools: settings.tools.enabled,
                    selected: selected,
                    notchWidth: model.layout.notchSize.width,
                    height: model.layout.notchSize.height,
                    onSelect: { settings.selectedTool = $0 },
                    onOpenSettings: { services.openSettings() }
                )
                toolView(selected)
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

/// The strip beside the hardware notch: tool tabs on the left, Settings on
/// the right, and nothing underneath the notch itself.
struct NotchHeader: View {
    let tools: [NotchTool]
    let selected: NotchTool
    let notchWidth: CGFloat
    let height: CGFloat
    let onSelect: (NotchTool) -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: NotchStyle.Space.xxs) {
                ForEach(tools) { tool in
                    Button {
                        onSelect(tool)
                    } label: {
                        Image(systemName: tool.symbolName)
                            .font(NotchStyle.Font.tab)
                            .foregroundStyle(tool == selected ? NotchStyle.Palette.primaryText : NotchStyle.Palette.secondaryText)
                            .frame(width: NotchStyle.Tab.width, height: NotchStyle.Tab.height)
                            .background(
                                Capsule().fill(tool == selected ? NotchStyle.Palette.selection : Color.clear)
                            )
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help(tool.title)
                    .accessibilityLabel(tool.title)
                    .accessibilityAddTraits(tool == selected ? .isSelected : [])
                }
            }
            Spacer(minLength: notchWidth + NotchStyle.Space.m * 2)
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
        .padding(.horizontal, NotchStyle.Space.l)
        .frame(height: height)
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
