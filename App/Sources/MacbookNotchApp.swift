import AppKit
import SwiftUI

@main
struct MacbookNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("MacbookNotch", systemImage: "rectangle.topthird.inset.filled") {
            Button("Settings…") {
                appDelegate.openSettings()
            }
            .keyboardShortcut(",")
            Button("Welcome Guide…") {
                appDelegate.openOnboarding()
            }
            if UpdateService.isConfigured(in: .main) {
                Button("Check for Updates…") {
                    appDelegate.checkForUpdates()
                }
            }
            Divider()
            Button("Quit MacbookNotch") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var services: AppServices?
    private var coordinator: NotchCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            let services = AppServices()
            services.start()
            let coordinator = NotchCoordinator(services: services)
            coordinator.start()
            self.services = services
            self.coordinator = coordinator
        }
    }

    func openSettings() {
        MainActor.assumeIsolated {
            services?.openSettings()
        }
    }

    func openOnboarding() {
        MainActor.assumeIsolated {
            services?.openOnboarding()
        }
    }

    func checkForUpdates() {
        MainActor.assumeIsolated {
            services?.updates.checkForUpdates()
        }
    }

}
