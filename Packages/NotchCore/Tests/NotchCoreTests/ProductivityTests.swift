import XCTest
@testable import NotchCore

// Times are whole seconds so the arithmetic is exact.
final class ProductivityTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)

    // MARK: Timers

    func testRunningTimerCountsDownAndFinishes() {
        let timer = CountdownTimer(label: "Tea", duration: 300, startedAt: t0)
        XCTAssertEqual(timer.state(at: t0), .running)
        XCTAssertEqual(timer.remaining(at: t0.addingTimeInterval(60)), 240)
        XCTAssertEqual(timer.progress(at: t0.addingTimeInterval(150)), 0.5)
        XCTAssertEqual(timer.state(at: t0.addingTimeInterval(300)), .finished)
        XCTAssertEqual(timer.remaining(at: t0.addingTimeInterval(400)), 0)
    }

    func testPauseFreezesAndResumeContinues() {
        var timer = CountdownTimer(label: "Tea", duration: 300, startedAt: t0)
        timer.pause(at: t0.addingTimeInterval(100))
        XCTAssertEqual(timer.state(at: t0.addingTimeInterval(1_000)), .paused)
        XCTAssertEqual(timer.remaining(at: t0.addingTimeInterval(1_000)), 200)

        timer.resume(at: t0.addingTimeInterval(1_000))
        XCTAssertEqual(timer.state(at: t0.addingTimeInterval(1_000)), .running)
        XCTAssertEqual(timer.remaining(at: t0.addingTimeInterval(1_050)), 150)
        XCTAssertEqual(timer.state(at: t0.addingTimeInterval(1_200)), .finished)
    }

    func testPausingAFinishedTimerDoesNothing() {
        var timer = CountdownTimer(label: "x", duration: 10, startedAt: t0)
        timer.pause(at: t0.addingTimeInterval(20))
        XCTAssertEqual(timer.state(at: t0.addingTimeInterval(20)), .finished)
    }

    func testRestartGoesBackToTheFullDuration() {
        var timer = CountdownTimer(label: "x", duration: 60, startedAt: t0)
        timer.pause(at: t0.addingTimeInterval(30))
        timer.restart(at: t0.addingTimeInterval(500))
        XCTAssertEqual(timer.remaining(at: t0.addingTimeInterval(500)), 60)
        XCTAssertEqual(timer.state(at: t0.addingTimeInterval(500)), .running)
    }

    func testTimersSurviveEncoding() throws {
        var timer = CountdownTimer(label: "Focus", duration: 1_500, startedAt: t0)
        timer.pause(at: t0.addingTimeInterval(10))
        let decoded = try JSONDecoder().decode(CountdownTimer.self, from: JSONEncoder().encode(timer))
        XCTAssertEqual(decoded, timer)
    }

    func testNextToFinishIgnoresPausedAndFinished() {
        let soon = CountdownTimer(label: "soon", duration: 60, startedAt: t0)
        let later = CountdownTimer(label: "later", duration: 600, startedAt: t0)
        var paused = CountdownTimer(label: "paused", duration: 5, startedAt: t0)
        paused.pause(at: t0)
        let done = CountdownTimer(label: "done", duration: 1, startedAt: t0.addingTimeInterval(-10))
        XCTAssertEqual([later, paused, done, soon].nextToFinish(at: t0)?.label, "soon")
        XCTAssertNil([paused, done].nextToFinish(at: t0))
    }

    func testCountdownFormatting() {
        XCTAssertEqual(CountdownFormatter.string(from: 0), "0:00")
        XCTAssertEqual(CountdownFormatter.string(from: 0.2), "0:01")
        XCTAssertEqual(CountdownFormatter.string(from: 245), "4:05")
        XCTAssertEqual(CountdownFormatter.string(from: 3_723), "1:02:03")
        XCTAssertEqual(CountdownFormatter.string(from: -5), "0:00")
    }

    func testPresetLabels() {
        XCTAssertEqual(TimerPresets.label(forMinutes: 25), "Focus")
        XCTAssertEqual(TimerPresets.label(forMinutes: 5), "5 min")
    }

    // MARK: Live activity

    func testLiveActivityPriority() {
        let a = UUID()
        let b = UUID()
        XCTAssertEqual(LiveActivity.pick(finishedTimer: a, runningTimer: b, musicPlaying: true, keepAwake: true), .timerFinished(id: a))
        XCTAssertEqual(LiveActivity.pick(finishedTimer: nil, runningTimer: b, musicPlaying: true, keepAwake: true), .timer(id: b))
        XCTAssertEqual(LiveActivity.pick(finishedTimer: nil, runningTimer: nil, musicPlaying: true, keepAwake: true), .music)
        XCTAssertEqual(LiveActivity.pick(finishedTimer: nil, runningTimer: nil, musicPlaying: false, keepAwake: true), .keepAwake)
        XCTAssertEqual(LiveActivity.pick(finishedTimer: nil, runningTimer: nil, musicPlaying: false, keepAwake: false), .none)
        XCTAssertFalse(LiveActivity.none.isActive)
    }

    // MARK: To-dos

    func testAddIgnoresBlankAndTrims() {
        var list = TodoList()
        XCTAssertNil(list.add("   ", at: t0))
        XCTAssertEqual(list.add("  Buy milk ", at: t0)?.title, "Buy milk")
        XCTAssertEqual(list.openCount, 1)
    }

    func testDoneItemsSinkBelowOpenOnes() {
        var list = TodoList()
        let first = list.add("first", at: t0)!
        list.add("second", at: t0.addingTimeInterval(1))
        list.add("third", at: t0.addingTimeInterval(2))
        list.toggle(first.id, at: t0.addingTimeInterval(3))
        XCTAssertEqual(list.items.map(\.title), ["second", "third", "first"])
        XCTAssertTrue(list.hasCompleted)

        list.toggle(first.id, at: t0.addingTimeInterval(4))
        XCTAssertEqual(list.items.map(\.title), ["first", "second", "third"])
        XCTAssertNil(list.items[0].completedAt)
    }

    func testClearCompletedAndRemove() {
        var list = TodoList()
        let a = list.add("a", at: t0)!
        let b = list.add("b", at: t0.addingTimeInterval(1))!
        list.toggle(a.id, at: t0.addingTimeInterval(2))
        list.clearCompleted()
        XCTAssertEqual(list.items.map(\.title), ["b"])
        list.rename(b.id, to: "  b2 ")
        XCTAssertEqual(list.items[0].title, "b2")
        list.remove(b.id)
        XCTAssertTrue(list.items.isEmpty)
    }

    func testScratchpadWordCount() {
        XCTAssertEqual(Scratchpad(text: "one two\nthree  ").wordCount, 3)
        XCTAssertEqual(Scratchpad().wordCount, 0)
    }

    // MARK: Tab strip

    func testTabsFillLeftThenRight() {
        // 150 pt per side, 26 pt tabs, 2 pt gaps: 5 fit on the left.
        let layout = TabStripLayout.split(count: 8, sideWidth: 150, tabWidth: 26, spacing: 2, rightReserved: 28)
        XCTAssertEqual(layout, TabStripLayout(left: 5, right: 3, overflow: 0))
    }

    func testTooManyTabsOverflowIntoAMenu() {
        let layout = TabStripLayout.split(count: 20, sideWidth: 150, tabWidth: 26, spacing: 2, rightReserved: 28)
        // Right side has room for 4; one becomes the overflow button.
        XCTAssertEqual(layout, TabStripLayout(left: 5, right: 3, overflow: 12))
    }

    func testFewTabsStayLeft() {
        XCTAssertEqual(
            TabStripLayout.split(count: 3, sideWidth: 150, tabWidth: 26, spacing: 2, rightReserved: 28),
            TabStripLayout(left: 3, right: 0, overflow: 0)
        )
    }

    func testKeepAwakeDurations() {
        XCTAssertEqual(KeepAwakeDuration.oneHour.interval, 3_600)
        XCTAssertNil(KeepAwakeDuration.indefinitely.interval)
    }
}

final class SystemStatsTests: XCTestCase {
    func testCPUUsageAcrossCores() {
        let before = [CPUTicks(user: 100, system: 50, idle: 850, nice: 0), CPUTicks(user: 0, system: 0, idle: 1_000, nice: 0)]
        let after = [CPUTicks(user: 150, system: 100, idle: 950, nice: 0), CPUTicks(user: 0, system: 0, idle: 1_200, nice: 0)]
        // Core 1: 100 busy of 200. Core 2: 0 of 200. Overall 100 / 400.
        XCTAssertEqual(CPULoad.usage(previous: before, current: after), 0.25)
    }

    func testCPUUsageNeedsMatchingSamples() {
        let one = [CPUTicks(user: 1, system: 1, idle: 1, nice: 0)]
        XCTAssertNil(CPULoad.usage(previous: [], current: one))
        XCTAssertNil(CPULoad.usage(previous: one, current: one))
    }

    func testNetworkRateHandlesWrapAround() {
        let before = ["en0": InterfaceCounters(received: UInt32.max - 99, sent: 10)]
        let after = ["en0": InterfaceCounters(received: 100, sent: 210)]
        let rate = NetworkRate.between(before, after, seconds: 2)
        XCTAssertEqual(rate.receivedPerSecond, 100)
        XCTAssertEqual(rate.sentPerSecond, 100)
    }

    func testNetworkRateSkipsNewInterfacesAndZeroTime() {
        let rate = NetworkRate.between([:], ["en0": InterfaceCounters(received: 5, sent: 5)], seconds: 1)
        XCTAssertEqual(rate, .zero)
        XCTAssertEqual(NetworkRate.between([:], [:], seconds: 0), .zero)
    }

    func testOnlyPhysicalInterfacesCount() {
        XCTAssertTrue(NetworkRate.isCounted(interface: "en0"))
        XCTAssertFalse(NetworkRate.isCounted(interface: "lo0"))
        XCTAssertFalse(NetworkRate.isCounted(interface: "utun3"))
        XCTAssertFalse(NetworkRate.isCounted(interface: "awdl0"))
    }

    func testMemoryUsageFromPages() {
        let usage = MemoryUsage.fromPages(internal: 300, purgeable: 100, wired: 50, compressed: 50, pageSize: 1_000, total: 1_000_000)
        XCTAssertEqual(usage.used, 300_000)
        XCTAssertEqual(usage.fraction, 0.3)
    }

    func testByteFormatting() {
        XCTAssertEqual(ByteFormat.string(512), "512 B")
        XCTAssertEqual(ByteFormat.string(1_400), "1.4 KB")
        XCTAssertEqual(ByteFormat.string(23_000_000), "23 MB")
        XCTAssertEqual(ByteFormat.rate(2_500), "2.5 KB/s")
    }
}
