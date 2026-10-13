import Foundation

/// Turns raw "pointer inside / outside" samples into a calm open/closed state:
/// open only after the pointer rests on the notch for `openDelay`, close only
/// after it has been away for `closeDelay`. Time is passed in, so this is
/// fully deterministic and testable.
public struct HoverDebouncer: Equatable, Sendable {
    public var openDelay: TimeInterval
    public var closeDelay: TimeInterval
    public private(set) var isOpen = false

    private var insideSince: TimeInterval?
    private var outsideSince: TimeInterval?

    public init(openDelay: TimeInterval, closeDelay: TimeInterval) {
        self.openDelay = openDelay
        self.closeDelay = closeDelay
    }

    /// Feed the latest pointer state. `holdOpen` keeps an open panel open
    /// regardless of the pointer (e.g. while dragging the scrubber).
    /// Returns true when `isOpen` changed.
    @discardableResult
    public mutating func update(pointerInside: Bool, holdOpen: Bool = false, now: TimeInterval) -> Bool {
        if pointerInside {
            outsideSince = nil
            if isOpen { return false }
            let since = insideSince ?? now
            insideSince = since
            if now - since >= openDelay {
                isOpen = true
                insideSince = nil
                return true
            }
            return false
        }

        insideSince = nil
        guard isOpen else { return false }
        if holdOpen {
            outsideSince = nil
            return false
        }
        let since = outsideSince ?? now
        outsideSince = since
        if now - since >= closeDelay {
            isOpen = false
            outsideSince = nil
            return true
        }
        return false
    }

    /// Open immediately (a click on the notch).
    @discardableResult
    public mutating func openNow() -> Bool {
        insideSince = nil
        outsideSince = nil
        guard !isOpen else { return false }
        isOpen = true
        return true
    }

    /// Close immediately.
    @discardableResult
    public mutating func closeNow() -> Bool {
        insideSince = nil
        outsideSince = nil
        guard isOpen else { return false }
        isOpen = false
        return true
    }

    /// When the caller should call `update` again even if the pointer has not
    /// moved, because a pending open or close is due. Nil when nothing is pending.
    public var nextDeadline: TimeInterval? {
        if !isOpen, let since = insideSince { return since + openDelay }
        if isOpen, let since = outsideSince { return since + closeDelay }
        return nil
    }
}
