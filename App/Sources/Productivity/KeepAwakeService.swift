import Foundation
import IOKit.pwr_mgt
import NotchCore

/// Stops the Mac from going to sleep on its own, for a while or until
/// turned off. Uses a standard power assertion (what `caffeinate` does), so
/// it ends automatically if the app quits.
@MainActor
final class KeepAwakeService: ObservableObject {
    @Published private(set) var isActive = false
    /// Nil while active means "until turned off".
    @Published private(set) var endsAt: Date?

    private let settings: AppSettings
    private var assertionID: IOPMAssertionID = 0
    private var hasAssertion = false
    private var endTimer: Timer?

    init(settings: AppSettings) {
        self.settings = settings
    }

    func turnOn(for duration: KeepAwakeDuration) {
        guard createAssertion() else {
            turnOff()
            return
        }
        isActive = true

        endTimer?.invalidate()
        endTimer = nil
        guard let interval = duration.interval else {
            endsAt = nil
            return
        }
        let end = Date().addingTimeInterval(interval)
        endsAt = end
        let timer = Timer(fire: end, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.turnOff() }
        }
        RunLoop.main.add(timer, forMode: .common)
        endTimer = timer
    }

    func turnOff() {
        releaseAssertion()
        endTimer?.invalidate()
        endTimer = nil
        endsAt = nil
        isActive = false
    }

    /// Re-applies the running session after "keep the display on" changes.
    func applyDisplaySetting() {
        guard isActive else { return }
        if !createAssertion() {
            turnOff()
        }
    }

    /// Replaces any current assertion with one matching the settings.
    private func createAssertion() -> Bool {
        releaseAssertion()
        // "Display" also keeps the screen on; "System" lets the screen sleep
        // but keeps the Mac itself running.
        let type = settings.keepAwakeDisplayOn ? "PreventUserIdleDisplaySleep" : "PreventUserIdleSystemSleep"
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            type as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "MacbookNotch Keep Awake" as CFString,
            &id
        )
        guard result == kIOReturnSuccess else {
            NSLog("MacbookNotch: Keep Awake failed (\(result))")
            return false
        }
        assertionID = id
        hasAssertion = true
        return true
    }

    private func releaseAssertion() {
        guard hasAssertion else { return }
        IOPMAssertionRelease(assertionID)
        hasAssertion = false
    }
}
