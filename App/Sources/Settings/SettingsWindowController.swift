import AppKit
import SwiftUI

/// A plain AppKit window hosting the SwiftUI settings. We don't use the
/// SwiftUI `Settings` scene because, from macOS 14, it can only be opened
/// from a `SettingsLink`, and we need to open it from the notch too.
@MainActor
final class SettingsWindowController {
    private let services: AppServices
    private var window: NSWindow?

    init(services: AppServices) {
        self.services = services
    }

    func show() {
        if window == nil {
            let view = SettingsView(
                settings: services.settings,
                launchAtLogin: services.launchAtLogin,
                shelf: services.shelf,
                clipboard: services.clipboard,
                license: services.license,
                updates: services.updates,
                stocks: services.stocks,
                revenue: services.revenue
            )
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "MacbookNotch Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        services.launchAtLogin.refresh()
        // We have no Dock icon, so bring ourselves forward or the window opens behind.
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
