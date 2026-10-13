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
        /// Cards and rows: one step lighter than the panel.
        static let rowBackground = Color.white.opacity(0.07)
        /// Secondary round buttons and the sent chat bubble.
        static let raised = Color.white.opacity(0.24)
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
        static let monthDay = SwiftUI.Font.system(size: 12).monospacedDigit()
        static let notes = SwiftUI.Font.system(size: 14)
        /// The open question on an empty Ask.
        static let prompt = SwiftUI.Font.system(size: 26, weight: .semibold)
        static let tileName = SwiftUI.Font.system(size: 11)
        static let body = SwiftUI.Font.system(size: 13)
        static let chip = SwiftUI.Font.system(size: 12, weight: .medium)
        static let segment = SwiftUI.Font.system(size: 13, weight: .medium)
        static let countdown = SwiftUI.Font.system(size: 15, weight: .semibold).monospacedDigit()
        static let statValue = SwiftUI.Font.system(size: 15, weight: .semibold).monospacedDigit()
        /// Big readouts: stopwatch, converter results.
        static let display = SwiftUI.Font.system(size: 36, weight: .regular).monospacedDigit()
        /// The one very large number on a screen (counts in list tools).
        static let hero = SwiftUI.Font.system(size: 52, weight: .light).monospacedDigit()
        static let compactIcon = SwiftUI.Font.system(size: 12, weight: .semibold)
        static let compactValue = SwiftUI.Font.system(size: 15, weight: .semibold).monospacedDigit()
    }

    enum Chip {
        static let height: CGFloat = 24
        static let horizontalPadding: CGFloat = 10
    }

    /// Text inputs.
    enum Field {
        static let height: CGFloat = 32
        static let radius: CGFloat = 10
    }

    enum Todo {
        static let checkSize: CGFloat = 16
        static let rowsWithoutScrolling = 5
    }

    /// The count column on the left of list tools.
    enum Summary {
        static let width: CGFloat = 132
    }

    /// Dark grey fields, one tone step above the panel.
    enum Card {
        static let radius: CGFloat = 12
        static let padding: CGFloat = 12
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

    enum MonthGrid {
        /// Six rows of these fit the panel: the disc on top, the dot under it.
        static let cell = CGSize(width: 28, height: 23)
        static let disc: CGFloat = 19
        static let dot: CGFloat = 3
    }

    enum Agenda {
        static let colorBarWidth: CGFloat = 3
        static let timeColumn: CGFloat = 52
    }

    enum Weather {
        static let symbolSize: CGFloat = 40
        static let temperature = SwiftUI.Font.system(size: 56, weight: .light).monospacedDigit()
        static let daySymbolSize: CGFloat = 18
        static let nowColumn: CGFloat = 196
    }

    enum Ask {
        static let sendSize: CGFloat = 16
        static let bubbleInset: CGFloat = 60
        static let bubbleRadius: CGFloat = 12
    }

    enum Teleprompter {
        static let fade: CGFloat = 28
        static let playSize: CGFloat = 40
        static let sliderWidth: CGFloat = 110
    }

    enum Volume {
        static let iconWidth: CGFloat = 20
        static let meterWidth: CGFloat = 28
    }

    enum Emoji {
        static let cell: CGFloat = 32
        static let size: CGFloat = 21
        static let recentCell: CGFloat = 40
        static let recentSize: CGFloat = 28
        static let recentCount = 12
    }

    enum Stocks {
        static let badgeWidth: CGFloat = 72
        static let rowsWithoutScrolling = 5
    }

    enum Revenue {
        static let totalWidth: CGFloat = 200
    }

    /// Live activities in the closed notch.
    enum Compact {
        static let ring: CGFloat = 20
        static let ringWidth: CGFloat = 2
        static let ringSymbol: CGFloat = 9
    }

    /// The large numbers in System.
    enum Readout {
        static let graphicHeight: CGFloat = 30
    }

    enum KeepAwake {
        static let buttonSize: CGFloat = 64
        static let symbolSize: CGFloat = 26
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
        static let iconSize: CGFloat = 52
        static let tileWidth: CGFloat = 92
        static let nameHeight: CGFloat = 28
        static let removeSize: CGFloat = 16
        static let emptySymbol: CGFloat = 30
    }

    // MARK: Clipboard
    enum Clipboard {
        static let leadingSize: CGFloat = 30
        static let leadingRadius: CGFloat = 7
        static let rowRadius: CGFloat = 10
        static let symbolSize: CGFloat = 12
        static let rowsWithoutScrolling = 4
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
