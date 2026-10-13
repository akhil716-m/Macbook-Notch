import SwiftUI

/// Design tokens. Every size, colour and timing the views use lives here.
/// Values come from the design pass (replica/design/tokens.json, measured
/// against reference screenshots); roles stay put when the brand changes.
enum NotchStyle {
    // MARK: Geometry
    static let openSize = CGSize(width: 640, height: 312)
    /// Width added on each side of the notch for a live activity.
    static let wingWidth: CGFloat = 72
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
        static let compact: CGFloat = 12
        static let open: CGFloat = 32
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
        /// Subtitles and labels.
        static let secondaryText = Color.white.opacity(0.72)
        /// Timestamps, hints, footnotes.
        static let tertiaryText = Color.white.opacity(0.56)
        /// The empty part of meters and sliders. The filled part carries the
        /// meaning and is checked against this (contrast pair fill/track).
        static let track = Color.white.opacity(0.15)
        static let fill = Color.white
        static let placeholder = Color.white.opacity(0.12)
        static let shadow = Color.black.opacity(0.45)
        /// Selected tab, selected pill.
        static let selection = Color.white.opacity(0.16)
        /// Cards and rows.
        static let rowBackground = Color.white.opacity(0.06)
        /// The hairline round cards, inputs and secondary buttons.
        static let border = Color.white.opacity(0.10)
        /// Secondary round buttons and the sent chat bubble.
        static let raised = Color.white.opacity(0.24)
        static let dropOutline = Color.white.opacity(0.7)
        static let removeBackground = Color.gray
        /// Running timers, Keep Awake, meters.
        static let accent = Color(red: 0.90, green: 0.59, blue: 0.25)
        static let overdue = Color(red: 0.87, green: 0.34, blue: 0.32)
        static let live = Color.green
        static let gain = Color.green
    }

    // MARK: Type
    enum Font {
        /// The tool name at the top left of the open panel.
        static let header = SwiftUI.Font.system(size: 17, weight: .bold)
        static let title = SwiftUI.Font.system(size: 15, weight: .semibold)
        static let subtitle = SwiftUI.Font.system(size: 13)
        static let caption = SwiftUI.Font.system(size: 11).monospacedDigit()
        static let emptyTitle = SwiftUI.Font.system(size: 14, weight: .semibold)
        static let emptyBody = SwiftUI.Font.system(size: 12)
        static let tab = SwiftUI.Font.system(size: 15, weight: .medium)
        static let rowTitle = SwiftUI.Font.system(size: 13)
        static let tileName = SwiftUI.Font.system(size: 11)
        static let body = SwiftUI.Font.system(size: 13)
        static let chip = SwiftUI.Font.system(size: 12, weight: .medium)
        static let segment = SwiftUI.Font.system(size: 13, weight: .medium)
        static let countdown = SwiftUI.Font.system(size: 15, weight: .semibold).monospacedDigit()
        static let statValue = SwiftUI.Font.system(size: 15, weight: .semibold).monospacedDigit()
        /// Big readouts: stopwatch, converter results.
        static let display = SwiftUI.Font.system(size: 36, weight: .regular).monospacedDigit()
        static let compactIcon = SwiftUI.Font.system(size: 12, weight: .semibold)
        static let compactValue = SwiftUI.Font.system(size: 15, weight: .semibold).monospacedDigit()
    }

    enum Chip {
        static let height: CGFloat = 24
        static let horizontalPadding: CGFloat = 10
    }

    /// Dark grey containers with a hairline border.
    enum Card {
        static let radius: CGFloat = 12
        static let padding: CGFloat = 12
        static let border: CGFloat = 1
    }

    /// The Timer / Stopwatch style switch.
    enum Segment {
        static let height: CGFloat = 26
        static let radius: CGFloat = 8
        static let inset: CGFloat = 2
        static let padding: CGFloat = 14
    }

    /// Circular action buttons: white for the main action, grey for the rest.
    enum RoundButton {
        static let large: CGFloat = 44
        static let small: CGFloat = 32
        static let largeSymbol: CGFloat = 17
        static let smallSymbol: CGFloat = 13
    }

    /// The row across the top of the open panel: tool name, pin, settings.
    enum Header {
        static let height: CGFloat = 30
        static let buttonSize: CGFloat = 28
        static let symbolSize: CGFloat = 14
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

    /// Live activities in the closed notch.
    enum Compact {
        static let ring: CGFloat = 20
        static let ringWidth: CGFloat = 2
        static let ringSymbol: CGFloat = 9
    }

    enum StatRow {
        static let iconWidth: CGFloat = 16
        static let labelWidth: CGFloat = 64
        static let valueWidth: CGFloat = 92
    }

    enum KeepAwake {
        static let buttonSize: CGFloat = 56
        static let symbolSize: CGFloat = 24
    }

    // MARK: Header
    enum Tab {
        static let width: CGFloat = 29
        static let height: CGFloat = 26
        static let spacing: CGFloat = 3
        static let radius: CGFloat = 8
        static let barHeight: CGFloat = 30
        /// Gap between the bar's centre and the panel's bottom edge.
        static let bottomInset: CGFloat = 13
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
        static let compactSize: CGFloat = 24
        static let compactRadius: CGFloat = 6
        static let openSize: CGFloat = 96
        static let openRadius: CGFloat = 12
    }

    enum Controls {
        static let skipSize: CGFloat = 18
        static let playSize: CGFloat = 24
        static let hitSize: CGFloat = 36
        static let spacing: CGFloat = 24
    }

    enum Scrubber {
        static let height: CGFloat = 4
        static let activeHeight: CGFloat = 7
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
    static let shadowRadius: CGFloat = 18
    static let shadowOffset: CGFloat = 6
}
