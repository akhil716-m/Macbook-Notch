import XCTest
@testable import NotchCore

// Delays and times are multiples of 1/8 so the arithmetic is exact in binary.
final class HoverDebouncerTests: XCTestCase {
    private func makeDebouncer() -> HoverDebouncer {
        HoverDebouncer(openDelay: 0.125, closeDelay: 0.25)
    }

    func testOpensOnlyAfterTheOpenDelay() {
        var d = makeDebouncer()
        XCTAssertFalse(d.update(pointerInside: true, now: 0))
        XCTAssertEqual(d.nextDeadline, 0.125)
        XCTAssertFalse(d.update(pointerInside: true, now: 0.0625))
        XCTAssertTrue(d.update(pointerInside: true, now: 0.125))
        XCTAssertTrue(d.isOpen)
        XCTAssertNil(d.nextDeadline)
    }

    func testPassingOverTheNotchDoesNotOpenIt() {
        var d = makeDebouncer()
        d.update(pointerInside: true, now: 0)
        d.update(pointerInside: false, now: 0.0625)
        XCTAssertFalse(d.update(pointerInside: true, now: 0.125))
        XCTAssertFalse(d.isOpen)
        XCTAssertEqual(d.nextDeadline, 0.25)
    }

    func testClosesOnlyAfterTheCloseDelay() {
        var d = makeDebouncer()
        d.openNow()
        XCTAssertFalse(d.update(pointerInside: false, now: 1))
        XCTAssertEqual(d.nextDeadline, 1.25)
        XCTAssertFalse(d.update(pointerInside: false, now: 1.125))
        XCTAssertTrue(d.update(pointerInside: false, now: 1.25))
        XCTAssertFalse(d.isOpen)
    }

    func testComingBackCancelsAPendingClose() {
        var d = makeDebouncer()
        d.openNow()
        d.update(pointerInside: false, now: 1)
        d.update(pointerInside: true, now: 1.125)
        XCTAssertNil(d.nextDeadline)
        XCTAssertFalse(d.update(pointerInside: false, now: 1.25))
        XCTAssertTrue(d.isOpen)
        XCTAssertTrue(d.update(pointerInside: false, now: 1.5))
    }

    func testHoldOpenKeepsThePanelOpen() {
        var d = makeDebouncer()
        d.openNow()
        XCTAssertFalse(d.update(pointerInside: false, holdOpen: true, now: 1))
        XCTAssertFalse(d.update(pointerInside: false, holdOpen: true, now: 5))
        XCTAssertTrue(d.isOpen)
        // The close delay starts counting when the hold ends.
        XCTAssertFalse(d.update(pointerInside: false, now: 6))
        XCTAssertTrue(d.update(pointerInside: false, now: 6.25))
    }

    func testOpenNowAndCloseNowReportChangesOnce() {
        var d = makeDebouncer()
        XCTAssertTrue(d.openNow())
        XCTAssertFalse(d.openNow())
        XCTAssertTrue(d.closeNow())
        XCTAssertFalse(d.closeNow())
    }
}
