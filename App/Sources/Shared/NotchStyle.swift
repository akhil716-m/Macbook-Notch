import SwiftUI

/// Interim design tokens. Every size, colour and timing the views use lives
/// here, so `/replica-design` can replace them in one place.
enum NotchStyle {
    // MARK: Geometry
    static let openSize = CGSize(width: 520, height: 190)
    /// Width added on each side of the notch for a live activity.
    static let wingWidth: CGFloat = 44
    /// Room around the open panel for its shadow.
    static let windowMargin: CGFloat = 24

    /// The outward curve where the shape meets the top edge of the screen.
    enum EarRadius {
        static let closed: CGFloat = 0
        static let compact: CGFloat = 6
        static let open: CGFloat = 14
    }

    enum BottomRadius {
        static let closed: CGFloat = 10
        static let compact: CGFloat = 10
        static let open: CGFloat = 28
    }

    // MARK: Spacing
    enum Space {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 6
        static let m: CGFloat = 8
        static let l: CGFloat = 14
        static let xl: CGFloat = 18
        static let xxl: CGFloat = 24
    }

    // MARK: Colour
    enum Palette {
        static let background = Color.black
        static let primaryText = Color.white
        static let secondaryText = Color.white.opacity(0.6)
        static let track = Color.white.opacity(0.2)
        static let fill = Color.white
        static let placeholder = Color.white.opacity(0.12)
        static let shadow = Color.black.opacity(0.45)
        static let selection = Color.white.opacity(0.16)
        static let rowBackground = Color.white.opacity(0.06)
        static let dropOutline = Color.white.opacity(0.7)
        static let removeBackground = Color.gray
        /// Running timers, Keep Awake, meters.
        static let accent = Color.orange
        static let overdue = Color(red: 1, green: 0.45, blue: 0.4)
        static let live = Color.green
        static let gain = Color.green
    }

    // MARK: Type
    enum Font {
        static let title = SwiftUI.Font.system(size: 15, weight: .semibold)
        static let subtitle = SwiftUI.Font.system(size: 12)
        static let caption = SwiftUI.Font.system(size: 10).monospacedDigit()
        static let emptyTitle = SwiftUI.Font.system(size: 13, weight: .semibold)
        static let emptyBody = SwiftUI.Font.system(size: 11)
        static let tab = SwiftUI.Font.system(size: 12, weight: .semibold)
        static let rowTitle = SwiftUI.Font.system(size: 12)
        static let tileName = SwiftUI.Font.system(size: 10)
        static let body = SwiftUI.Font.system(size: 12)
        static let chip = SwiftUI.Font.system(size: 11, weight: .medium)
        static let countdown = SwiftUI.Font.system(size: 15, weight: .semibold).monospacedDigit()
        static let statValue = SwiftUI.Font.system(size: 15, weight: .semibold).monospacedDigit()
        static let compactIcon = SwiftUI.Font.system(size: 12, weight: .semibold)
        static let compactValue = SwiftUI.Font.system(size: 11, weight: .semibold).monospacedDigit()
    }

    enum Chip {
        static let height: CGFloat = 22
        static let horizontalPadding: CGFloat = 9
    }

    enum Row {
        static let iconSize: CGFloat = 11
        static let iconHit: CGFloat = 24
    }

    enum Agenda {
        static let colorBarWidth: CGFloat = 3
        static let timeColumn: CGFloat = 52
    }

    enum Weather {
        static let symbolSize: CGFloat = 34
        static let temperature = SwiftUI.Font.system(size: 32, weight: .light).monospacedDigit()
        static let daySymbolSize: CGFloat = 14
        static let dayColumn: CGFloat = 46
    }

    enum Ask {
        static let sendSize: CGFloat = 16
        static let bubbleInset: CGFloat = 60
        static let bubbleRadius: CGFloat = 10
    }

    enum Volume {
        static let iconWidth: CGFloat = 20
        static let meterWidth: CGFloat = 28
    }

    enum Emoji {
        static let cell: CGFloat = 30
        static let size: CGFloat = 20
    }

    enum Stocks {
        static let cardWidth: CGFloat = 100
    }

    enum Converter {
        static let inputWidth: CGFloat = 110
    }

    enum KeepAwake {
        static let buttonSize: CGFloat = 56
        static let symbolSize: CGFloat = 24
    }

    // MARK: Header
    enum Tab {
        static let width: CGFloat = 26
        static let height: CGFloat = 20
    }

    // MARK: Shelf
    enum Shelf {
        static let iconSize: CGFloat = 44
        static let tileWidth: CGFloat = 72
        static let removeSize: CGFloat = 14
        static let dropRadius: CGFloat = 14
    }

    // MARK: Clipboard
    enum Clipboard {
        static let leadingSize: CGFloat = 26
        static let leadingRadius: CGFloat = 6
        static let rowRadius: CGFloat = 8
        static let symbolSize: CGFloat = 11
    }

    // MARK: Media
    enum Artwork {
        static let compactSize: CGFloat = 20
        static let compactRadius: CGFloat = 5
        static let openSize: CGFloat = 84
        static let openRadius: CGFloat = 12
    }

    enum Controls {
        static let skipSize: CGFloat = 16
        static let playSize: CGFloat = 22
        static let hitSize: CGFloat = 32
        static let spacing: CGFloat = 26
    }

    enum Scrubber {
        static let height: CGFloat = 4
        static let activeHeight: CGFloat = 6
        static let hitHeight: CGFloat = 12
    }

    enum Equalizer {
        static let barCount = 4
        static let barWidth: CGFloat = 3
        static let spacing: CGFloat = 2
        static let minHeight: CGFloat = 3
        static let maxHeight: CGFloat = 14
        static let tick: TimeInterval = 0.3
    }

    // MARK: Motion
    static let hoverOpenDelay: TimeInterval = 0.12
    static let hoverCloseDelay: TimeInterval = 0.3
    static let spring = Animation.spring(response: 0.38, dampingFraction: 0.82)
    static let shadowRadius: CGFloat = 14
    static let shadowOffset: CGFloat = 4
}
