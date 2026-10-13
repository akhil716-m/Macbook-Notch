import NotchCore
import SwiftUI

/// Fills the fixed-size notch window. The black shape hangs from the top
/// centre and morphs between closed, compact and open.
struct NotchRootView: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var nowPlaying: NowPlayingService
    let onTap: () -> Void

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
            if !model.isOpen { onTap() }
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
            VStack(spacing: 0) {
                // Keep the strip under the hardware notch empty.
                Color.clear.frame(height: model.layout.notchSize.height)
                NowPlayingPanel(service: nowPlaying)
                    .padding(.horizontal, NotchStyle.Space.xl)
                    .padding(.bottom, NotchStyle.Space.l)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
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
