import XCTest
@testable import NotchCore

final class VolumeTests: XCTestCase {
    func testStepsSnapToSixteenths() {
        XCTAssertEqual(VolumeStep.next(from: 0.5, up: true, fine: false), 9.0 / 16)
        XCTAssertEqual(VolumeStep.next(from: 0.5, up: false, fine: false), 7.0 / 16)
        // Off-grid values snap to the nearest step first.
        XCTAssertEqual(VolumeStep.next(from: 0.51, up: true, fine: false), 9.0 / 16)
    }

    func testFineStepsAreQuarterSteps() {
        XCTAssertEqual(VolumeStep.next(from: 0.5, up: true, fine: true), 33.0 / 64)
    }

    func testVolumeStaysInRange() {
        XCTAssertEqual(VolumeStep.next(from: 1, up: true, fine: false), 1)
        XCTAssertEqual(VolumeStep.next(from: 0, up: false, fine: false), 0)
    }

    func testSegments() {
        XCTAssertEqual(VolumeStep.segments(for: 0.5, of: 16), 8)
        XCTAssertEqual(VolumeStep.segments(for: 1.2, of: 16), 16)
        XCTAssertEqual(VolumeStep.segments(for: -1, of: 16), 0)
    }

    func testDecodesVolumeKeys() {
        // Volume up, key down: code 0 << 16 | 0x0A << 8.
        XCTAssertEqual(MediaKeyEvent.decode(data1: 0x0A00), MediaKeyEvent(key: .soundUp, isDown: true, isRepeat: false))
        // Volume down, key up.
        XCTAssertEqual(MediaKeyEvent.decode(data1: (1 << 16) | 0x0B00), MediaKeyEvent(key: .soundDown, isDown: false, isRepeat: false))
        // Mute, key down, repeating.
        XCTAssertEqual(MediaKeyEvent.decode(data1: (7 << 16) | 0x0A01), MediaKeyEvent(key: .mute, isDown: true, isRepeat: true))
    }

    func testIgnoresOtherKeys() {
        // Play/pause (16) and brightness (2) aren't ours.
        XCTAssertNil(MediaKeyEvent.decode(data1: (16 << 16) | 0x0A00))
        XCTAssertNil(MediaKeyEvent.decode(data1: (2 << 16) | 0x0A00))
        XCTAssertNil(MediaKeyEvent.decode(data1: 0x0C00))
    }

    func testVolumeOutranksEverythingInTheNotch() {
        XCTAssertEqual(
            LiveActivity.pick(finishedTimer: UUID(), runningTimer: nil, musicPlaying: true, keepAwake: true, volumeChanged: true),
            .volume
        )
    }
}

final class ChatTests: XCTestCase {
    func testTranscriptIgnoresBlankAndTrims() {
        var transcript = ChatTranscript()
        XCTAssertNil(transcript.append(.user, "  \n "))
        XCTAssertEqual(transcript.append(.user, " hi ")?.text, "hi")
        transcript.append(.assistant, "Hello!")
        XCTAssertEqual(transcript.messages.map(\.role), [.user, .assistant])
    }

    func testTranscriptKeepsTheNewestWithinItsLimit() {
        var transcript = ChatTranscript(limit: 2)
        transcript.append(.user, "1")
        transcript.append(.assistant, "2")
        transcript.append(.user, "3")
        XCTAssertEqual(transcript.messages.map(\.text), ["2", "3"])
        transcript.clear()
        XCTAssertTrue(transcript.isEmpty)
    }

    func testEveryUnavailableStateExplainsItself() {
        let states: [AskAvailability] = [
            .needsNewerMacOS, .notInThisBuild, .deviceNotEligible, .appleIntelligenceOff, .modelNotReady, .unknown,
        ]
        for state in states {
            XCTAssertFalse(state.title.isEmpty)
            XCTAssertFalse(state.message.isEmpty)
        }
        XCTAssertTrue(AskAvailability.appleIntelligenceOff.canOpenSettings)
        XCTAssertFalse(AskAvailability.deviceNotEligible.canOpenSettings)
    }
}
