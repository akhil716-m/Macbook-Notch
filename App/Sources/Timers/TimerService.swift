import AppKit
import NotchCore
import UserNotifications

/// Countdown timers. They keep running across sleep and relaunch because
/// each stores when it ends, not how long it has left.
@MainActor
final class TimerService: ObservableObject {
    @Published private(set) var timers: [CountdownTimer] = []
    /// The running timer that ends soonest, shown in the closed notch.
    @Published private(set) var runningTimerID: UUID?
    /// A timer that just finished, shown in the closed notch until seen.
    @Published private(set) var finishedTimerID: UUID?

    private let file: LocalFile<[CountdownTimer]>
    private var wakeTimer: Timer?
    private var dismissTask: Task<Void, Never>?
    /// Finished timers we've already announced, so a relaunch doesn't ring again.
    private var announced: Set<UUID> = []
    private var askedForNotifications = false

    /// How long "Done" stays in the closed notch if nobody looks.
    private static let finishedDisplayTime: Duration = .seconds(10)

    init(fileURL: URL) {
        file = LocalFile(url: fileURL)
    }

    func start() {
        timers = file.load() ?? []
        let now = Date()
        announced = Set(timers.filter { $0.state(at: now) == .finished }.map(\.id))
        reschedule()
    }

    // MARK: Actions

    func start(minutes: Int, label: String? = nil) {
        let timer = CountdownTimer(
            label: label ?? TimerPresets.label(forMinutes: minutes),
            duration: TimeInterval(minutes * 60),
            startedAt: Date()
        )
        timers.insert(timer, at: 0)
        changed()
        requestNotificationPermissionOnce()
    }

    func pause(_ id: UUID) {
        update(id) { $0.pause(at: Date()) }
    }

    func resume(_ id: UUID) {
        update(id) { $0.resume(at: Date()) }
    }

    func restart(_ id: UUID) {
        announced.remove(id)
        update(id) { $0.restart(at: Date()) }
    }

    func remove(_ id: UUID) {
        timers.removeAll { $0.id == id }
        announced.remove(id)
        if finishedTimerID == id { finishedTimerID = nil }
        changed()
    }

    func clearFinished() {
        let now = Date()
        timers.removeAll { $0.state(at: now) == .finished }
        finishedTimerID = nil
        changed()
    }

    /// The user has seen the "Done" state (opened the notch).
    func acknowledgeFinished() {
        finishedTimerID = nil
        dismissTask?.cancel()
    }

    var hasFinished: Bool {
        let now = Date()
        return timers.contains { $0.state(at: now) == .finished }
    }

    func timer(_ id: UUID) -> CountdownTimer? {
        timers.first { $0.id == id }
    }

    // MARK: Scheduling

    private func update(_ id: UUID, _ change: (inout CountdownTimer) -> Void) {
        guard let index = timers.firstIndex(where: { $0.id == id }) else { return }
        change(&timers[index])
        changed()
    }

    private func changed() {
        file.save(timers)
        reschedule()
    }

    /// One wake-up, at the next end time. Nothing ticks in between.
    private func reschedule() {
        wakeTimer?.invalidate()
        wakeTimer = nil
        let now = Date()
        let next = timers.nextToFinish(at: now)
        runningTimerID = next?.id
        guard let endsAt = next?.endsAt else { return }
        let wake = Timer(fire: endsAt, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.timersFinished() }
        }
        wake.tolerance = 0.05
        RunLoop.main.add(wake, forMode: .common)
        wakeTimer = wake
    }

    private func timersFinished() {
        let now = Date()
        let newlyFinished = timers.filter { $0.state(at: now) == .finished && !announced.contains($0.id) }
        for timer in newlyFinished {
            announced.insert(timer.id)
            notify(timer)
        }
        if let last = newlyFinished.last {
            NSSound(named: "Glass")?.play()
            finishedTimerID = last.id
            dismissTask?.cancel()
            dismissTask = Task {
                try? await Task.sleep(for: Self.finishedDisplayTime)
                guard !Task.isCancelled else { return }
                self.finishedTimerID = nil
            }
        }
        reschedule()
    }

    // MARK: Notifications

    private func requestNotificationPermissionOnce() {
        guard !askedForNotifications else { return }
        askedForNotifications = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notify(_ timer: CountdownTimer) {
        let content = UNMutableNotificationContent()
        content.title = "\(timer.label) is done"
        content.body = "Your \(CountdownFormatter.string(from: timer.duration)) timer finished."
        content.sound = nil // We already play a chime.
        let request = UNNotificationRequest(identifier: timer.id.uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
