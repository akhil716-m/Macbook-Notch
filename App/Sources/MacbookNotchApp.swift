import AppKit
import SwiftUI

@main
struct MacbookNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var launchAtLogin = LaunchAtLogin()

    var body: some Scene {
        MenuBarExtra("MacbookNotch", systemImage: "rectangle.topthird.inset.filled") {
            Toggle("Open at Login", isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.setEnabled($0) }
            ))
            Divider()
            Button("Quit MacbookNotch") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var nowPlaying: NowPlayingService?
    private var notch: NotchWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            let nowPlaying = NowPlayingService()
            nowPlaying.start()
            let notch = NotchWindowController(nowPlaying: nowPlaying)
            notch.show()
            self.nowPlaying = nowPlaying
            self.notch = notch
        }
    }
}
