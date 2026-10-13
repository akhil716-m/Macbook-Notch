import AppKit
import Combine
import NotchCore

/// Owns one screen's notch window and decides when it is open, closed or
/// showing a live activity. Geometry comes from `NotchLayout`, hover timing
/// from `HoverDebouncer`.
@MainActor
final class NotchWindowController {
    private let services: AppServices
    private let model: NotchViewModel
    private var screen: NSScreen
    private var panel: NotchPanel?
    private var debouncer: HoverDebouncer
    private var eventMonitors: [Any] = []
    private var deadlineTimer: Timer?
    private var openPollTimer: Timer?
    private var pressPollTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    /// The drag pasteboard's counter at the last mouse-down. It changes when
    /// a drag starts, which is how we notice files being dragged anywhere.
    private var dragBaseline = 0
    private var fileDragActive = false

    init(screen: NSScreen, services: AppServices) {
        self.screen = screen
        self.services = services
        model = NotchViewModel(layout: Self.makeLayout(for: screen))
        debouncer = HoverDebouncer(openDelay: services.settings.openDelay, closeDelay: services.settings.closeDelay)
    }

    func show() {
        let panel = NotchPanel(contentRect: model.layout.windowFrame)
        let root = NotchRootView(
            model: model,
            services: services,
            settings: services.settings,
            nowPlaying: services.nowPlaying,
            onTapClosed: { [weak self] in self?.openNow() }
        )
        panel.contentView = NotchHostingView(rootView: root)
        panel.onEscape = { [weak self] in self?.closeNow() }
        panel.orderFrontRegardless()
        self.panel = panel

        dragBaseline = NSPasteboard(name: .drag).changeCount
        installEventMonitors()
        observeServices()
        evaluatePointer()
    }

    func update(screen: NSScreen) {
        self.screen = screen
        let layout = Self.makeLayout(for: screen)
        guard layout != model.layout else { return }
        model.layout = layout
        panel?.setFrame(layout.windowFrame, display: true)
        evaluatePointer()
    }

    func close() {
        if model.isOpen {
            services.nowPlaying.setLiveUpdates(false)
        }
        for monitor in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        eventMonitors.removeAll()
        [deadlineTimer, openPollTimer, pressPollTimer].forEach { $0?.invalidate() }
        cancellables.removeAll()
        panel?.orderOut(nil)
        panel = nil
    }

    // MARK: Pointer

    private func installEventMonitors() {
        let mask: NSEvent.EventTypeMask = [
            .mouseMoved, .leftMouseDown, .leftMouseDragged, .leftMouseUp,
            .rightMouseDragged, .otherMouseDragged,
        ]
        // Pointer activity over other apps. Mouse events need no Accessibility permission.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event.type) }
        }) {
            eventMonitors.append(global)
        }
        // Pointer activity while our own app is active (Settings open, menu bar item open).
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.handle(event.type) }
            return event
        }) {
            eventMonitors.append(local)
        }
    }

    private func handle(_ type: NSEvent.EventType) {
        switch type {
        case .leftMouseDown:
            dragBaseline = NSPasteboard(name: .drag).changeCount
            fileDragActive = false
            startPressPolling()
        case .leftMouseDragged:
            detectFileDrag()
        case .leftMouseUp:
            fileDragActive = false
        default:
            break
        }
        evaluatePointer()
    }

    private func detectFileDrag() {
        guard !fileDragActive else { return }
        let pasteboard = NSPasteboard(name: .drag)
        guard pasteboard.changeCount != dragBaseline else { return }
        fileDragActive = pasteboard.types?.contains(.fileURL) == true
    }

    private func evaluatePointer() {
        let now = ProcessInfo.processInfo.systemUptime
        let point = NSEvent.mouseLocation
        let inside = model.layout.hoverRect(for: model.presentation).contains(point)

        // Dragging files onto the notch opens the shelf straight away.
        if fileDragActive, inside, services.settings.tools.isEnabled(.shelf) {
            if services.settings.selectedTool != .shelf {
                services.settings.selectedTool = .shelf
            }
            if debouncer.openNow() {
                applyOpenState()
            }
        }

        // Stay open while a button is held, a file hovers over us, or you're typing in the notch.
        let typing = panel?.isKeyWindow == true && panel?.firstResponder is NSTextView
        let holdOpen = debouncer.isOpen && (NSEvent.pressedMouseButtons != 0 || model.isDropTargeted || typing)
        if debouncer.update(pointerInside: inside, holdOpen: holdOpen, now: now) {
            applyOpenState()
        }
        // Take clicks only on the black shape; everywhere else they fall through.
        panel?.ignoresMouseEvents = !model.layout.interactiveRect(for: model.presentation).contains(point)
        scheduleDeadline(now: now)
    }

    private func openNow() {
        if debouncer.openNow() {
            applyOpenState()
        }
        evaluatePointer()
    }

    private func closeNow() {
        if debouncer.closeNow() {
            applyOpenState()
        }
        evaluatePointer()
    }

    private func applyOpenState() {
        let open = debouncer.isOpen
        guard model.isOpen != open else { return }
        if open {
            // A timer just went off: show it.
            if services.timers.finishedTimerID != nil, services.settings.tools.isEnabled(.timers) {
                services.settings.selectedTool = .timers
            }
            services.timers.acknowledgeFinished()
        } else {
            model.optionHeld = false
            model.isDropTargeted = false
            services.notes.flush()
            giveBackKeyboard()
        }
        model.isOpen = open
        services.nowPlaying.setLiveUpdates(open)
        setOpenPolling(open)
    }

    /// If you were typing in the notch, hand the keyboard back to the app you
    /// were in. Ordering the panel out and back in makes macOS pick that
    /// app's window as key again.
    private func giveBackKeyboard() {
        guard let panel, panel.isKeyWindow else { return }
        panel.orderOut(nil)
        panel.orderFrontRegardless()
    }

    /// Re-check when a pending open or close falls due, even if the pointer is still.
    private func scheduleDeadline(now: TimeInterval) {
        deadlineTimer?.invalidate()
        deadlineTimer = nil
        guard let deadline = debouncer.nextDeadline else { return }
        deadlineTimer = Timer.scheduledTimer(withTimeInterval: max(0.01, deadline - now), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluatePointer() }
        }
    }

    /// While open, sample the pointer and the ⌥ key directly, so a fast exit
    /// is never missed. Off while closed, so the idle app does no work.
    private func setOpenPolling(_ on: Bool) {
        openPollTimer?.invalidate()
        openPollTimer = nil
        guard on else { return }
        openPollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let optionHeld = NSEvent.modifierFlags.contains(.option)
                if self.model.optionHeld != optionHeld {
                    self.model.optionHeld = optionHeld
                }
                self.evaluatePointer()
            }
        }
    }

    /// While a mouse button is down, watch for a file drag starting even if
    /// the system doesn't forward drag events to us. Stops on release.
    private func startPressPolling() {
        pressPollTimer?.invalidate()
        pressPollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { return }
                if NSEvent.pressedMouseButtons == 0 {
                    timer.invalidate()
                    self.fileDragActive = false
                } else {
                    self.detectFileDrag()
                }
                self.evaluatePointer()
            }
        }
    }

    // MARK: Services

    private func observeServices() {
        Publishers.CombineLatest4(
            services.nowPlaying.$track.map { $0?.status == .playing }.removeDuplicates(),
            services.timers.$runningTimerID.removeDuplicates(),
            services.timers.$finishedTimerID.removeDuplicates(),
            services.keepAwake.$isActive.removeDuplicates()
        )
        .map { musicPlaying, runningTimer, finishedTimer, keepAwake in
            LiveActivity.pick(
                finishedTimer: finishedTimer,
                runningTimer: runningTimer,
                musicPlaying: musicPlaying,
                keepAwake: keepAwake
            )
        }
        .removeDuplicates()
        .sink { [weak self] activity in
            MainActor.assumeIsolated {
                self?.model.liveActivity = activity
                self?.evaluatePointer()
            }
        }
        .store(in: &cancellables)

        services.settings.$openDelay
            .sink { [weak self] delay in
                MainActor.assumeIsolated { self?.debouncer.openDelay = delay }
            }
            .store(in: &cancellables)

        services.settings.$closeDelay
            .sink { [weak self] delay in
                MainActor.assumeIsolated { self?.debouncer.closeDelay = delay }
            }
            .store(in: &cancellables)
    }

    // MARK: Layout

    private static func makeLayout(for screen: NSScreen) -> NotchLayout {
        let hardware = NotchHardware(
            screenFrame: screen.frame,
            safeAreaTop: screen.safeAreaInsets.top,
            auxiliaryLeftWidth: screen.auxiliaryTopLeftArea?.width,
            auxiliaryRightWidth: screen.auxiliaryTopRightArea?.width,
            menuBarHeight: screen.frame.maxY - screen.visibleFrame.maxY
        )
        return NotchLayout(
            hardware: hardware,
            openSize: NotchStyle.openSize,
            wingWidth: NotchStyle.wingWidth,
            windowMargin: NotchStyle.windowMargin
        )
    }
}
