import AppKit
import Combine
import NotchCore

/// Owns the notch window and decides when it is open, closed or showing a
/// live activity. All geometry comes from `NotchLayout`; all hover timing
/// from `HoverDebouncer`.
@MainActor
final class NotchWindowController {
    private let model: NotchViewModel
    private let nowPlaying: NowPlayingService
    private var panel: NotchPanel?
    private var debouncer = HoverDebouncer(openDelay: NotchStyle.hoverOpenDelay, closeDelay: NotchStyle.hoverCloseDelay)
    private var eventMonitors: [Any] = []
    private var deadlineTimer: Timer?
    private var pollTimer: Timer?
    private var screenObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    init(nowPlaying: NowPlayingService) {
        self.nowPlaying = nowPlaying
        self.model = NotchViewModel(layout: Self.makeLayout())
    }

    func show() {
        let panel = NotchPanel(contentRect: model.layout.windowFrame)
        let root = NotchRootView(model: model, nowPlaying: nowPlaying, onTap: { [weak self] in
            self?.openNow()
        })
        panel.contentView = NotchHostingView(rootView: root)
        panel.orderFrontRegardless()
        self.panel = panel

        installEventMonitors()
        observeScreens()
        observeLiveActivity()
        evaluatePointer()
    }

    // MARK: Pointer

    private func installEventMonitors() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .leftMouseUp]
        // Pointer movement over other apps. Mouse events need no Accessibility permission.
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluatePointer() }
        }) {
            eventMonitors.append(global)
        }
        // Pointer movement while our app happens to be active (e.g. the menu bar item is open).
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.evaluatePointer() }
            return event
        }) {
            eventMonitors.append(local)
        }
    }

    private func evaluatePointer() {
        let now = ProcessInfo.processInfo.systemUptime
        let point = NSEvent.mouseLocation
        let inside = model.layout.hoverRect(for: model.presentation).contains(point)
        let holdOpen = debouncer.isOpen && NSEvent.pressedMouseButtons != 0
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

    private func applyOpenState() {
        let open = debouncer.isOpen
        guard model.isOpen != open else { return }
        model.isOpen = open
        nowPlaying.setLiveUpdates(open)
        setPolling(open)
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

    /// While open, also sample the pointer directly so a fast exit is never
    /// missed. Off while closed, so the idle app does no work.
    private func setPolling(_ on: Bool) {
        pollTimer?.invalidate()
        pollTimer = nil
        guard on else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.evaluatePointer() }
        }
    }

    // MARK: Live activity

    private func observeLiveActivity() {
        nowPlaying.$track
            .map { $0?.status == .playing }
            .removeDuplicates()
            .sink { [weak self] active in
                MainActor.assumeIsolated {
                    self?.model.liveActivityActive = active
                    self?.evaluatePointer()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: Screens

    private func observeScreens() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.relayout() }
        }
    }

    private func relayout() {
        let layout = Self.makeLayout()
        model.layout = layout
        panel?.setFrame(layout.windowFrame, display: true)
        evaluatePointer()
    }

    /// Prefers the built-in display with a notch; otherwise the main screen
    /// gets a floating notch.
    private static func makeLayout() -> NotchLayout {
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens.first
        let hardware: NotchHardware
        if let screen {
            hardware = NotchHardware(
                screenFrame: screen.frame,
                safeAreaTop: screen.safeAreaInsets.top,
                auxiliaryLeftWidth: screen.auxiliaryTopLeftArea?.width,
                auxiliaryRightWidth: screen.auxiliaryTopRightArea?.width,
                menuBarHeight: screen.frame.maxY - screen.visibleFrame.maxY
            )
        } else {
            hardware = NotchHardware(
                screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                safeAreaTop: 0,
                auxiliaryLeftWidth: nil,
                auxiliaryRightWidth: nil,
                menuBarHeight: 0
            )
        }
        return NotchLayout(
            hardware: hardware,
            openSize: NotchStyle.openSize,
            wingWidth: NotchStyle.wingWidth,
            windowMargin: NotchStyle.windowMargin
        )
    }
}
