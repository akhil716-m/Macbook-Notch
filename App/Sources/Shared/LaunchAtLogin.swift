import Foundation
import ServiceManagement

/// Registers the app itself as a login item (macOS 13+, no helper app).
final class LaunchAtLogin: ObservableObject {
    @Published private(set) var isEnabled = SMAppService.mainApp.status == .enabled

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("MacbookNotch: could not change login item: \(error.localizedDescription)")
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
