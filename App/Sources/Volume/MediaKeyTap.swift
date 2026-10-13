import AppKit
import CoreGraphics
import NotchCore

/// Catches the volume keys before macOS handles them, so the notch can show
/// the change instead of the system popup. Needs Accessibility permission;
/// `start()` returns false without it.
///
/// Every other key, and volume keys we choose not to handle, pass through
/// untouched.
final class MediaKeyTap {
    /// Return true to swallow the key. `fine` is true when ⌥⇧ is held.
    typealias Handler = (MediaKeyEvent, _ fine: Bool) -> Bool

    private let handler: Handler
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    /// NX_SYSDEFINED: media and volume keys arrive as this event type. It
    /// isn't one of CGEventType's named cases, so compare raw values.
    static let systemDefinedType: UInt32 = 14
    /// NX_SUBTYPE_AUX_CONTROL_BUTTONS
    static let mediaKeySubtype: Int16 = 8

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    func start() -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let mask = CGEventMask(1) << CGEventMask(Self.systemDefinedType)
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: MediaKeyTap.callback,
            userInfo: userInfo
        ) else { return false }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        source = nil
    }

    deinit {
        stop()
    }

    private static let callback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let owner = Unmanaged<MediaKeyTap>.fromOpaque(userInfo).takeUnretainedValue()

        // macOS turns slow taps off; turn ourselves back on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = owner.tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type.rawValue == MediaKeyTap.systemDefinedType else {
            return Unmanaged.passUnretained(event)
        }

        // The tap's run loop source is on the main run loop.
        let swallow: Bool = MainActor.assumeIsolated {
            guard let nsEvent = NSEvent(cgEvent: event),
                  nsEvent.subtype.rawValue == MediaKeyTap.mediaKeySubtype,
                  let key = MediaKeyEvent.decode(data1: nsEvent.data1)
            else { return false }
            let flags = nsEvent.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let fine = flags.contains(.option) && flags.contains(.shift)
            return owner.handler(key, fine)
        }
        return swallow ? nil : Unmanaged.passUnretained(event)
    }
}
