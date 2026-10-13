import XCTest
@testable import NotchCore

final class ToolsTests: XCTestCase {
    func testDefaultArrangementHasEveryToolOnInDeclarationOrder() {
        let arrangement = ToolArrangement()
        XCTAssertEqual(arrangement.order, NotchTool.allCases)
        XCTAssertEqual(arrangement.enabled, NotchTool.allCases)
    }

    func testStoredOrderIsCleanedAndNewToolsAppended() {
        let arrangement = ToolArrangement(storedOrder: ["clipboard", "bogus", "clipboard", "nowPlaying"])
        XCTAssertEqual(arrangement.order, [.clipboard, .nowPlaying, .shelf])
    }

    func testDisabledToolsAreHidden() {
        let arrangement = ToolArrangement(storedDisabled: ["shelf", "nope"])
        XCTAssertEqual(arrangement.enabled, [.nowPlaying, .clipboard])
        XCTAssertFalse(arrangement.isEnabled(.shelf))
        XCTAssertEqual(arrangement.storedDisabled, ["shelf"])
    }

    func testStoredSettingsCanNeverDisableEverything() {
        let arrangement = ToolArrangement(storedDisabled: NotchTool.allCases.map(\.rawValue))
        XCTAssertEqual(arrangement.enabled.count, 1)
    }

    func testTheLastEnabledToolCannotBeSwitchedOff() {
        var arrangement = ToolArrangement()
        XCTAssertTrue(arrangement.setEnabled(.shelf, false))
        XCTAssertTrue(arrangement.setEnabled(.clipboard, false))
        XCTAssertFalse(arrangement.setEnabled(.nowPlaying, false))
        XCTAssertEqual(arrangement.enabled, [.nowPlaying])
        XCTAssertTrue(arrangement.setEnabled(.shelf, true))
        XCTAssertFalse(arrangement.setEnabled(.shelf, true))
    }

    func testMoveMatchesSwiftUISemantics() {
        var arrangement = ToolArrangement()
        arrangement.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(arrangement.order, [.shelf, .clipboard, .nowPlaying])
        arrangement.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        XCTAssertEqual(arrangement.order, [.nowPlaying, .shelf, .clipboard])
        arrangement.move(fromOffsets: IndexSet([0, 1]), toOffset: 3)
        XCTAssertEqual(arrangement.order, [.clipboard, .nowPlaying, .shelf])
    }

    func testSelectionFallsBackToFirstEnabledTool() {
        var arrangement = ToolArrangement()
        arrangement.setEnabled(.nowPlaying, false)
        XCTAssertEqual(arrangement.resolvedSelection(.nowPlaying), .shelf)
        XCTAssertEqual(arrangement.resolvedSelection(.clipboard), .clipboard)
        XCTAssertEqual(arrangement.resolvedSelection(nil), .shelf)
    }

    // MARK: Displays

    private let builtIn = ScreenSummary(hasNotch: true, isPrimary: false)
    private let externalPrimary = ScreenSummary(hasNotch: false, isPrimary: true)
    private let externalOther = ScreenSummary(hasNotch: false, isPrimary: false)

    func testAutomaticPrefersTheNotchedScreen() {
        XCTAssertEqual(DisplaySelection.screens([externalPrimary, builtIn], mode: .automatic), [1])
    }

    func testAutomaticFallsBackToPrimaryWithoutANotch() {
        XCTAssertEqual(DisplaySelection.screens([externalOther, externalPrimary], mode: .automatic), [1])
    }

    func testPrimaryAndAll() {
        let screens = [builtIn, externalPrimary, externalOther]
        XCTAssertEqual(DisplaySelection.screens(screens, mode: .primary), [1])
        XCTAssertEqual(DisplaySelection.screens(screens, mode: .all), [0, 1, 2])
    }

    func testNoScreensNoNotches() {
        XCTAssertEqual(DisplaySelection.screens([], mode: .all), [])
    }
}
