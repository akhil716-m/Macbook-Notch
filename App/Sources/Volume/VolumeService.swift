import AppKit
import AudioToolbox
import Combine
import CoreAudio
import NotchCore

/// Shows volume changes in the notch.
///
/// Watching the output device needs no permission. Replacing the macOS volume
/// popup is optional: it catches the volume keys before the system does
/// (needs Accessibility) and changes the volume itself.
@MainActor
final class VolumeService: ObservableObject {
    @Published private(set) var level: Float = 0
    @Published private(set) var isMuted = false
    /// True for a moment after the volume changes.
    @Published private(set) var isShowing = false
    /// Whether the volume-key interception is running.
    @Published private(set) var isReplacingSystemHUD = false

    private let settings: AppSettings
    private var device: AudioObjectID?
    private var deviceListener: AudioObjectPropertyListenerBlock?
    private var volumeListener: AudioObjectPropertyListenerBlock?
    private var hideTask: Task<Void, Never>?
    private var keyTap: MediaKeyTap?
    private var cancellables = Set<AnyCancellable>()

    private static let showFor: Duration = .milliseconds(1500)

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start() {
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.bindToDefaultDevice() }
        }
        var address = AudioOutput.defaultDeviceAddress
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
        deviceListener = listener
        bindToDefaultDevice()

        settings.$replaceSystemVolumeHUD
            .removeDuplicates()
            .sink { [weak self] on in
                MainActor.assumeIsolated { self?.setKeyInterception(on) }
            }
            .store(in: &cancellables)
    }

    // MARK: Watching

    private func bindToDefaultDevice() {
        if let device, let volumeListener {
            for var address in [AudioOutput.volumeAddress, AudioOutput.muteAddress] {
                AudioObjectRemovePropertyListenerBlock(device, &address, .main, volumeListener)
            }
        }
        device = AudioOutput.defaultDevice()
        guard let device else { return }

        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.volumeDidChange() }
        }
        for var address in [AudioOutput.volumeAddress, AudioOutput.muteAddress] {
            AudioObjectAddPropertyListenerBlock(device, &address, .main, listener)
        }
        volumeListener = listener
        readLevel()
    }

    private func readLevel() {
        guard let device else { return }
        level = AudioOutput.volume(of: device) ?? level
        isMuted = AudioOutput.isMuted(device) ?? false
    }

    private func volumeDidChange() {
        readLevel()
        guard settings.showVolumeInNotch else { return }
        isShowing = true
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: Self.showFor)
            guard !Task.isCancelled else { return }
            self.isShowing = false
        }
    }

    // MARK: Replacing the system popup

    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the macOS prompt that leads to Accessibility settings.
    func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func setKeyInterception(_ on: Bool) {
        keyTap?.stop()
        keyTap = nil
        isReplacingSystemHUD = false
        guard on else { return }
        let tap = MediaKeyTap { [weak self] event, fine in
            // Called on the main thread by the tap's run loop source.
            MainActor.assumeIsolated { self?.handle(event, fine: fine) ?? false }
        }
        if tap.start() {
            keyTap = tap
            isReplacingSystemHUD = true
        } else {
            requestAccessibilityPermission()
        }
    }

    /// Returns true if we handled the key and macOS shouldn't see it.
    private func handle(_ event: MediaKeyEvent, fine: Bool) -> Bool {
        // If the notch won't show the change, let macOS show its own popup.
        guard settings.showVolumeInNotch else { return false }
        guard let device, AudioOutput.canSetVolume(device) else {
            return false // e.g. HDMI audio: let macOS show its "can't change" popup
        }
        guard event.isDown else { return true }
        switch event.key {
        case .soundUp, .soundDown:
            let current = AudioOutput.volume(of: device) ?? level
            let next = VolumeStep.next(from: current, up: event.key == .soundUp, fine: fine)
            if isMuted, event.key == .soundUp { AudioOutput.setMuted(device, false) }
            AudioOutput.setVolume(device, next)
        case .mute:
            guard !event.isRepeat else { return true }
            AudioOutput.setMuted(device, !(AudioOutput.isMuted(device) ?? false))
        }
        // The property listener updates the level and shows the notch HUD.
        return true
    }
}

/// The default output device's volume and mute, via CoreAudio.
enum AudioOutput {
    static var defaultDeviceAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioHardwarePropertyDefaultOutputDevice),
            mScope: AudioObjectPropertyScope(kAudioObjectPropertyScopeGlobal),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain)
        )
    }

    static var volumeAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioHardwareServiceDeviceProperty_VirtualMainVolume),
            mScope: AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain)
        )
    }

    static var muteAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: AudioObjectPropertySelector(kAudioDevicePropertyMute),
            mScope: AudioObjectPropertyScope(kAudioDevicePropertyScopeOutput),
            mElement: AudioObjectPropertyElement(kAudioObjectPropertyElementMain)
        )
    }

    static func defaultDevice() -> AudioObjectID? {
        var address = defaultDeviceAddress
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return status == noErr && device != AudioObjectID(kAudioObjectUnknown) ? device : nil
    }

    static func volume(of device: AudioObjectID) -> Float? {
        var address = volumeAddress
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    static func canSetVolume(_ device: AudioObjectID) -> Bool {
        var address = volumeAddress
        guard AudioObjectHasProperty(device, &address) else { return false }
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(device, &address, &settable) == noErr && settable.boolValue
    }

    @discardableResult
    static func setVolume(_ device: AudioObjectID, _ level: Float) -> Bool {
        var address = volumeAddress
        var value = Float32(min(max(level, 0), 1))
        return AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value) == noErr
    }

    static func isMuted(_ device: AudioObjectID) -> Bool? {
        var address = muteAddress
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value != 0
    }

    @discardableResult
    static func setMuted(_ device: AudioObjectID, _ muted: Bool) -> Bool {
        var address = muteAddress
        guard AudioObjectHasProperty(device, &address) else { return false }
        var value: UInt32 = muted ? 1 : 0
        return AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value) == noErr
    }
}
