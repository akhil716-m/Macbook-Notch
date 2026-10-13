import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// What we know about the screen the notch lives on. All rects are in global
/// AppKit coordinates (origin bottom-left, y grows upwards).
public struct NotchHardware: Equatable, Sendable {
    public var screenFrame: CGRect
    /// `NSScreen.safeAreaInsets.top`. Zero on screens without a notch.
    public var safeAreaTop: CGFloat
    /// Widths of `NSScreen.auxiliaryTopLeftArea` / `auxiliaryTopRightArea`.
    public var auxiliaryLeftWidth: CGFloat?
    public var auxiliaryRightWidth: CGFloat?
    /// Height of the menu bar, or 0 when it is hidden.
    public var menuBarHeight: CGFloat

    public init(
        screenFrame: CGRect,
        safeAreaTop: CGFloat,
        auxiliaryLeftWidth: CGFloat?,
        auxiliaryRightWidth: CGFloat?,
        menuBarHeight: CGFloat
    ) {
        self.screenFrame = screenFrame
        self.safeAreaTop = safeAreaTop
        self.auxiliaryLeftWidth = auxiliaryLeftWidth
        self.auxiliaryRightWidth = auxiliaryRightWidth
        self.menuBarHeight = menuBarHeight
    }
}

/// The three shapes the notch can take.
public enum NotchPresentation: Hashable, Sendable {
    /// Same size as the hardware notch (or the floating pill).
    case closed
    /// Notch plus a wing on each side, for a live activity such as music.
    case compact
    /// The full panel, opened by hover or click.
    case open
}

/// Pure geometry for the notch window: where the notch is, how big each
/// presentation is, and which rects count for hover and for clicks.
public struct NotchLayout: Equatable, Sendable {
    /// Used on screens without a notch, where we draw a floating one.
    public static let fallbackNotchSize = CGSize(width: 185, height: 32)
    /// How far hover and click rects reach above the screen edge, so the very
    /// top row of pixels (where the pointer stops) is always inside.
    public static let topOverscan: CGFloat = 8
    /// Extra hover tolerance around the closed notch.
    public static let closedHoverPadding: CGFloat = 8
    /// Extra hover tolerance around the open panel.
    public static let openHoverPadding: CGFloat = 2

    public let screenFrame: CGRect
    public let hasHardwareNotch: Bool
    public let notchRect: CGRect
    public let openSize: CGSize
    public let wingWidth: CGFloat
    public let windowMargin: CGFloat
    /// How far down the open panel's content must start to clear both the
    /// notch and the menu bar. On some Macs the menu bar is taller than the
    /// notch and covers anything drawn beside or just below it.
    public let contentTop: CGFloat

    public init(hardware: NotchHardware, openSize: CGSize, wingWidth: CGFloat, windowMargin: CGFloat) {
        let frame = hardware.screenFrame
        screenFrame = frame
        self.openSize = openSize
        self.wingWidth = wingWidth
        self.windowMargin = windowMargin

        if hardware.safeAreaTop > 0,
           let left = hardware.auxiliaryLeftWidth,
           let right = hardware.auxiliaryRightWidth,
           left + right < frame.width {
            hasHardwareNotch = true
            notchRect = CGRect(
                x: frame.minX + left,
                y: frame.maxY - hardware.safeAreaTop,
                width: frame.width - left - right,
                height: hardware.safeAreaTop
            )
        } else {
            hasHardwareNotch = false
            let height = hardware.menuBarHeight > 0 ? hardware.menuBarHeight : Self.fallbackNotchSize.height
            let width = Self.fallbackNotchSize.width
            notchRect = CGRect(x: frame.midX - width / 2, y: frame.maxY - height, width: width, height: height)
        }
        contentTop = max(notchRect.height, hardware.menuBarHeight)
    }

    public var notchSize: CGSize { notchRect.size }

    public func shapeSize(for presentation: NotchPresentation) -> CGSize {
        switch presentation {
        case .closed:
            return notchRect.size
        case .compact:
            return CGSize(width: notchRect.width + wingWidth * 2, height: notchRect.height)
        case .open:
            return CGSize(
                width: max(openSize.width, notchRect.width + wingWidth * 2),
                height: max(openSize.height, notchRect.height)
            )
        }
    }

    /// The black shape, centred on the notch and hanging from the top edge.
    public func shapeRect(for presentation: NotchPresentation) -> CGRect {
        let size = shapeSize(for: presentation)
        return CGRect(
            x: notchRect.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    /// Where the pointer counts as "on the notch" for opening and staying open.
    public func hoverRect(for presentation: NotchPresentation) -> CGRect {
        let shape = shapeRect(for: presentation)
        let pad = presentation == .open ? Self.openHoverPadding : Self.closedHoverPadding
        return CGRect(
            x: shape.minX - pad,
            y: shape.minY - pad,
            width: shape.width + pad * 2,
            height: shape.height + pad + Self.topOverscan
        )
    }

    /// Where the window takes clicks. Everywhere else, clicks fall through to
    /// whatever is underneath (menu bar items, other windows).
    public func interactiveRect(for presentation: NotchPresentation) -> CGRect {
        let shape = shapeRect(for: presentation)
        return CGRect(x: shape.minX, y: shape.minY, width: shape.width, height: shape.height + Self.topOverscan)
    }

    /// One fixed window big enough for the open panel plus room for its shadow.
    /// The presentations animate inside it, so the window never resizes.
    public var windowFrame: CGRect {
        let open = shapeSize(for: .open)
        let width = open.width + windowMargin * 2
        let height = open.height + windowMargin
        return CGRect(x: notchRect.midX - width / 2, y: screenFrame.maxY - height, width: width, height: height)
    }
}
