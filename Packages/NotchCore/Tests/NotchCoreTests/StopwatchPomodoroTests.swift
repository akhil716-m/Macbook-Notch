import XCTest
@testable import NotchCore

final class StopwatchTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)

    func testRunsPausesAndResumes() {
        var watch = Stopwatch()
        XCTAssertFalse(watch.hasTime)
        watch.start(at: t0)
        XCTAssertTrue(watch.isRunning)
        XCTAssertEqual(watch.elapsed(at: t0.addingTimeInterval(10)), 10)
        watch.pause(at: t0.addingTimeInterval(10))
        XCTAssertEqual(watch.elapsed(at: t0.addingTimeInterval(500)), 10)
        watch.start(at: t0.addingTimeInterval(500))
        XCTAssertEqual(watch.elapsed(at: t0.addingTimeInterval(505)), 15)
    }

    func testLapsAreSplitNewestFirst() {
        var watch = Stopwatch()
        watch.start(at: t0)
        watch.lap(at: t0.addingTimeInterval(10))
        watch.lap(at: t0.addingTimeInterval(25))
        watch.lap(at: t0.addingTimeInterval(32))
        XCTAssertEqual(watch.lapLengths, [7, 15, 10])
        watch.pause(at: t0.addingTimeInterval(40))
        watch.lap(at: t0.addingTimeInterval(50)) // ignored while paused
        XCTAssertEqual(watch.laps.count, 3)
        watch.reset()
        XCTAssertFalse(watch.hasTime)
        XCTAssertEqual(watch.elapsed(at: t0), 0)
    }

    func testSurvivesEncoding() throws {
        var watch = Stopwatch()
        watch.start(at: t0)
        watch.lap(at: t0.addingTimeInterval(4))
        let decoded = try JSONDecoder().decode(Stopwatch.self, from: JSONEncoder().encode(watch))
        XCTAssertEqual(decoded, watch)
    }

    func testFormatting() {
        XCTAssertEqual(StopwatchFormatter.string(from: 0), "00:00.00")
        XCTAssertEqual(StopwatchFormatter.string(from: 12.375), "00:12.37")
        XCTAssertEqual(StopwatchFormatter.string(from: 724.5), "12:04.50")
        XCTAssertEqual(StopwatchFormatter.string(from: 3_723.25), "1:02:03.25")
    }
}

final class PomodoroTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    func testFocusThenShortBreakThenFocus() {
        var pomodoro = Pomodoro()
        XCTAssertEqual(pomodoro.state, .ready)
        XCTAssertEqual(pomodoro.remaining(at: t0), 1_500)
        pomodoro.start(at: t0)
        XCTAssertEqual(pomodoro.state, .running)
        XCTAssertEqual(pomodoro.progress(at: t0.addingTimeInterval(750)), 0.5)
        XCTAssertNil(pomodoro.advanceIfDue(at: t0.addingTimeInterval(1_499), calendar: calendar))

        XCTAssertEqual(pomodoro.advanceIfDue(at: t0.addingTimeInterval(1_500), calendar: calendar), .focus)
        XCTAssertEqual(pomodoro.phase, .shortBreak)
        XCTAssertEqual(pomodoro.state, .ready)
        XCTAssertEqual(pomodoro.sessionNumber, 2)
        XCTAssertEqual(pomodoro.sessionsToday(at: t0, calendar: calendar), 1)

        pomodoro.start(at: t0.addingTimeInterval(2_000))
        XCTAssertEqual(pomodoro.advanceIfDue(at: t0.addingTimeInterval(2_300), calendar: calendar), .shortBreak)
        XCTAssertEqual(pomodoro.phase, .focus)
    }

    func testLongBreakAfterAFullSet() {
        var pomodoro = Pomodoro(sessionsPerSet: 2)
        var now = t0
        for _ in 0..<2 {
            pomodoro.start(at: now)
            now = now.addingTimeInterval(pomodoro.duration(of: pomodoro.phase))
            pomodoro.advanceIfDue(at: now, calendar: calendar)
            if pomodoro.phase == .shortBreak { pomodoro.skip() }
        }
        XCTAssertEqual(pomodoro.phase, .longBreak)
        XCTAssertEqual(pomodoro.remaining(at: now), 900)
        pomodoro.skip()
        XCTAssertEqual(pomodoro.phase, .focus)
        XCTAssertEqual(pomodoro.sessionNumber, 1)
        XCTAssertEqual(pomodoro.sessionsToday(at: now, calendar: calendar), 2)
    }

    func testSkippingFocusDoesNotCount() {
        var pomodoro = Pomodoro()
        pomodoro.start(at: t0)
        pomodoro.skip()
        XCTAssertEqual(pomodoro.phase, .shortBreak)
        XCTAssertEqual(pomodoro.sessionsToday(at: t0, calendar: calendar), 0)
        XCTAssertEqual(pomodoro.sessionNumber, 1)
    }

    func testPauseResumeAndReset() {
        var pomodoro = Pomodoro()
        pomodoro.start(at: t0)
        pomodoro.pause(at: t0.addingTimeInterval(100))
        XCTAssertEqual(pomodoro.state, .paused)
        XCTAssertEqual(pomodoro.remaining(at: t0.addingTimeInterval(10_000)), 1_400)
        XCTAssertNil(pomodoro.advanceIfDue(at: t0.addingTimeInterval(10_000), calendar: calendar))
        pomodoro.start(at: t0.addingTimeInterval(10_000))
        XCTAssertEqual(pomodoro.remaining(at: t0.addingTimeInterval(10_400)), 1_000)
        pomodoro.reset()
        XCTAssertEqual(pomodoro.state, .ready)
        XCTAssertEqual(pomodoro.phase, .focus)
    }

    func testTodaysCountStartsAgainOnANewDay() {
        var pomodoro = Pomodoro()
        pomodoro.start(at: t0)
        pomodoro.advanceIfDue(at: t0.addingTimeInterval(1_500), calendar: calendar)
        let tomorrow = t0.addingTimeInterval(86_400)
        XCTAssertEqual(pomodoro.sessionsToday(at: tomorrow, calendar: calendar), 0)
        pomodoro.skip()
        pomodoro.start(at: tomorrow)
        pomodoro.advanceIfDue(at: tomorrow.addingTimeInterval(1_500), calendar: calendar)
        XCTAssertEqual(pomodoro.sessionsToday(at: tomorrow, calendar: calendar), 1)
    }

    func testLiveActivityPriorityIncludesFocusModes() {
        XCTAssertEqual(LiveActivity.pick(finishedTimer: nil, runningTimer: nil, musicPlaying: true, keepAwake: false,
                                         pomodoroRunning: true, stopwatchRunning: true), .pomodoro)
        XCTAssertEqual(LiveActivity.pick(finishedTimer: nil, runningTimer: nil, musicPlaying: true, keepAwake: false,
                                         stopwatchRunning: true), .stopwatch)
        let id = UUID()
        XCTAssertEqual(LiveActivity.pick(finishedTimer: nil, runningTimer: id, musicPlaying: false, keepAwake: false,
                                         pomodoroRunning: true), .timer(id: id))
    }
}

final class DiskAndBatteryTests: XCTestCase {
    func testDiskFraction() {
        XCTAssertEqual(DiskUsage(available: 250, total: 1_000).usedFraction, 0.75)
        XCTAssertEqual(DiskUsage(available: 5, total: 0).usedFraction, 0)
    }

    func testBatteryFromPowerSource() {
        let onBattery: [String: Any] = [
            "Type": "InternalBattery", "Current Capacity": 54, "Max Capacity": 100,
            "Is Charging": false, "Power Source State": "Battery Power", "Time to Empty": 200,
        ]
        let battery = BatteryStatus(powerSource: onBattery)
        XCTAssertEqual(battery?.level, 0.54)
        XCTAssertEqual(battery?.summary, "On battery · 3 h 20 min left")

        let charging: [String: Any] = [
            "Type": "InternalBattery", "Current Capacity": 80, "Max Capacity": 100,
            "Is Charging": true, "Power Source State": "AC Power", "Time to Full Charge": 45,
        ]
        XCTAssertEqual(BatteryStatus(powerSource: charging)?.summary, "Charging · 45 min to full")

        let full: [String: Any] = [
            "Type": "InternalBattery", "Current Capacity": 100, "Max Capacity": 100,
            "Is Charging": false, "Power Source State": "AC Power", "Time to Empty": -1,
        ]
        XCTAssertEqual(BatteryStatus(powerSource: full)?.summary, "Fully charged")

        XCTAssertNil(BatteryStatus(powerSource: ["Type": "UPS", "Current Capacity": 5, "Max Capacity": 10]))
        XCTAssertNil(BatteryStatus(powerSource: ["Type": "InternalBattery", "Current Capacity": 5, "Max Capacity": 0]))
    }

    func testBatteryDurations() {
        XCTAssertEqual(BatteryStatus.duration(45), "45 min")
        XCTAssertEqual(BatteryStatus.duration(120), "2 h")
        XCTAssertEqual(BatteryStatus.duration(185), "3 h 5 min")
    }
}
