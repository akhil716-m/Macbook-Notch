import AppKit
import Combine
import NotchCore

/// Decides which screens get a notch and keeps one window controller per
/// screen, rebuilding when displays change or the setting changes.
@MainActor
final class NotchCoordinator {
    private let services: AppServices
    private var controllers: [CGDirectDisplayID: NotchWindowController] = [:]
    private var screenObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    init(services: AppServices) {
        self.services = services
    }

    func start() {
        rebuild(mode: services.settings.displayMode)

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.rebuild(mode: self.services.settings.displayMode)
            }
        }

        services.settings.$displayMode
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] mode in
                MainActor.assumeIsolated { self?.rebuild(mode: mode) }
            }
            .store(in: &cancellables)
    }

    private func rebuild(mode: DisplayMode) {
        let screens = NSScreen.screens
        let primary = screens.first
        let summaries = screens.map {
            ScreenSummary(hasNotch: $0.safeAreaInsets.top > 0, isPrimary: $0 == primary)
        }
        let chosen = DisplaySelection.screens(summaries, mode: mode).map { screens[$0] }
        let chosenIDs = Set(chosen.map { Self.displayID($0) })

        for (id, controller) in controllers where !chosenIDs.contains(id) {
            controller.close()
            controllers[id] = nil
        }
        for screen in chosen {
            let id = Self.displayID(screen)
            if let existing = controllers[id] {
                existing.update(screen: screen)
            } else {
                let controller = NotchWindowController(screen: screen, services: services)
                controller.show()
                controllers[id] = controller
            }
        }
    }

    private static func displayID(_ screen: NSScreen) -> CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (screen.deviceDescription[key] as? NSNumber)?.uint32Value ?? 0
    }
}
