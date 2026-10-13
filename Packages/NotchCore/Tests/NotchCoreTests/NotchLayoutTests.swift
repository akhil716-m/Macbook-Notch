import XCTest
@testable import NotchCore

final class NotchLayoutTests: XCTestCase {
    // A 14-inch MacBook Pro at the default scaled resolution.
    private let macBookPro14 = NotchHardware(
        screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        safeAreaTop: 32,
        auxiliaryLeftWidth: 664,
        auxiliaryRightWidth: 664,
        menuBarHeight: 32
    )

    private func layout(_ hardware: NotchHardware) -> NotchLayout {
        NotchLayout(hardware: hardware, openSize: CGSize(width: 520, height: 190), wingWidth: 36, windowMargin: 24)
    }

    func testHardwareNotchIsMeasuredFromTheAuxiliaryAreas() {
        let l = layout(macBookPro14)
        XCTAssertTrue(l.hasHardwareNotch)
        XCTAssertEqual(l.notchRect, CGRect(x: 664, y: 950, width: 184, height: 32))
    }

    func testContentStartsBelowTheNotchAndTheMenuBar() {
        XCTAssertEqual(layout(macBookPro14).contentTop, 32)
        // A MacBook whose menu bar is taller than its notch.
        var air = macBookPro14
        air.menuBarHeight = 37
        XCTAssertEqual(layout(air).contentTop, 37)
        // Menu bar hidden (full-screen app): just the notch.
        air.menuBarHeight = 0
        XCTAssertEqual(layout(air).contentTop, 32)
    }

    func testShapeSizes() {
        let l = layout(macBookPro14)
        XCTAssertEqual(l.shapeSize(for: .closed), CGSize(width: 184, height: 32))
        XCTAssertEqual(l.shapeSize(for: .compact), CGSize(width: 256, height: 32))
        XCTAssertEqual(l.shapeSize(for: .open), CGSize(width: 520, height: 190))
    }

    func testShapesHangFromTheTopEdgeCentredOnTheNotch() {
        let l = layout(macBookPro14)
        for presentation in [NotchPresentation.closed, .compact, .open] {
            let rect = l.shapeRect(for: presentation)
            XCTAssertEqual(rect.maxY, 982, "\(presentation)")
            XCTAssertEqual(rect.midX, 756, "\(presentation)")
        }
    }

    func testWindowFitsTheOpenPanelPlusMargins() {
        let l = layout(macBookPro14)
        XCTAssertEqual(l.windowFrame, CGRect(x: 472, y: 768, width: 568, height: 214))
        XCTAssertTrue(l.windowFrame.contains(l.shapeRect(for: .open)))
    }

    func testTheTopPixelRowCountsAsHovering() {
        let l = layout(macBookPro14)
        // NSEvent.mouseLocation can report exactly maxY at the top edge.
        XCTAssertTrue(l.hoverRect(for: .closed).contains(CGPoint(x: 756, y: 982)))
        XCTAssertTrue(l.interactiveRect(for: .closed).contains(CGPoint(x: 756, y: 982)))
    }

    func testClosedHoverHasSmallToleranceButNotMore() {
        let l = layout(macBookPro14)
        XCTAssertTrue(l.hoverRect(for: .closed).contains(CGPoint(x: 756, y: 945)))
        XCTAssertFalse(l.hoverRect(for: .closed).contains(CGPoint(x: 756, y: 940)))
        XCTAssertFalse(l.hoverRect(for: .closed).contains(CGPoint(x: 600, y: 975)))
    }

    func testClicksBesideTheClosedNotchFallThrough() {
        let l = layout(macBookPro14)
        // Inside the hover tolerance but outside the shape: menu bar items there stay clickable.
        let besideNotch = CGPoint(x: 664 - 4, y: 970)
        XCTAssertTrue(l.hoverRect(for: .closed).contains(besideNotch))
        XCTAssertFalse(l.interactiveRect(for: .closed).contains(besideNotch))
    }

    func testScreenWithoutNotchGetsAFloatingNotch() {
        let l = layout(NotchHardware(
            screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            safeAreaTop: 0,
            auxiliaryLeftWidth: nil,
            auxiliaryRightWidth: nil,
            menuBarHeight: 24
        ))
        XCTAssertFalse(l.hasHardwareNotch)
        XCTAssertEqual(l.notchRect, CGRect(x: 867.5, y: 1056, width: 185, height: 24))
    }

    func testHiddenMenuBarFallsBackToDefaultHeight() {
        let l = layout(NotchHardware(
            screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            safeAreaTop: 0,
            auxiliaryLeftWidth: nil,
            auxiliaryRightWidth: nil,
            menuBarHeight: 0
        ))
        XCTAssertEqual(l.notchSize, NotchLayout.fallbackNotchSize)
    }

    func testSecondaryScreenOffsetsAreRespected() {
        var hardware = macBookPro14
        hardware.screenFrame = CGRect(x: -1512, y: 200, width: 1512, height: 982)
        let l = layout(hardware)
        XCTAssertEqual(l.notchRect, CGRect(x: -848, y: 1150, width: 184, height: 32))
        XCTAssertEqual(l.windowFrame.maxY, 1182)
    }

    func testOpenPanelIsNeverNarrowerThanTheCompactShape() {
        let l = NotchLayout(hardware: macBookPro14, openSize: CGSize(width: 100, height: 10), wingWidth: 36, windowMargin: 0)
        XCTAssertEqual(l.shapeSize(for: .open), CGSize(width: 256, height: 32))
    }
}
