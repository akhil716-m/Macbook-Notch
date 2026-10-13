import AppKit
import SwiftUI

/// A borderless, transparent panel that floats above the menu bar on every
/// Space, including next to full-screen apps, and never activates the app.
///
/// It becomes key only when a text field inside needs typing (Notes,
/// To-dos), so clicking a button in the notch doesn't take the keyboard
/// away from the app you're in.
final class NotchPanel: NSPanel {
    /// Called when Escape is pressed inside the notch.
    var onEscape: (() -> Void)?

    convenience init(contentRect: NSRect) {
        self.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = true
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    /// Our app is never active, so its menu bar (and the Edit menu's
    /// shortcuts) never handles key equivalents. Route the standard editing
    /// shortcuts to the focused text field ourselves.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags == .command || flags == [.command, .shift],
           let key = event.charactersIgnoringModifiers?.lowercased(),
           let action = Self.editAction(key: key, shift: flags.contains(.shift)),
           NSApp.sendAction(action, to: nil, from: self) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    private static func editAction(key: String, shift: Bool) -> Selector? {
        switch (key, shift) {
        case ("x", false): return #selector(NSText.cut(_:))
        case ("c", false): return #selector(NSText.copy(_:))
        case ("v", false): return #selector(NSText.paste(_:))
        case ("a", false): return #selector(NSText.selectAll(_:))
        case ("z", false): return Selector(("undo:"))
        case ("z", true): return Selector(("redo:"))
        default: return nil
        }
    }
}

/// Lets the first click on the notch act immediately, even though our app is
/// never the active app.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
