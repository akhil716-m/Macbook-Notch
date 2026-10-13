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
        // Home wasn't stored, so it joins at the front; other new tools go last.
        XCTAssertEqual(Array(arrangement.order.prefix(3)), [.home, .clipboard, .nowPlaying])
        XCTAssertEqual(arrangement.order.last, NotchTool.allCases.last)
        XCTAssertEqual(arrangement.order.count, NotchTool.allCases.count)
        XCTAssertEqual(Set(arrangement.order), Set(NotchTool.allCases))
    }

    func testDisabledToolsAreHidden() {
        let arrangement = ToolArrangement(storedDisabled: ["shelf", "nope"])
        XCTAssertFalse(arrangement.enabled.contains(.shelf))
        XCTAssertEqual(arrangement.enabled.count, NotchTool.allCases.count - 1)
        XCTAssertFalse(arrangement.isEnabled(.shelf))
        XCTAssertEqual(arrangement.storedDisabled, ["shelf"])
    }

    func testStoredSettingsCanNeverDisableEverything() {
        let arrangement = ToolArrangement(storedDisabled: NotchTool.allCases.map(\.rawValue))
        XCTAssertEqual(arrangement.enabled.count, 1)
    }

    func testTheLastEnabledToolCannotBeSwitchedOff() {
        var arrangement = ToolArrangement()
        for tool in NotchTool.allCases.dropFirst() {
            XCTAssertTrue(arrangement.setEnabled(tool, false))
        }
        XCTAssertFalse(arrangement.setEnabled(.home, false))
        XCTAssertEqual(arrangement.enabled, [.home])
        XCTAssertTrue(arrangement.setEnabled(.shelf, true))
        XCTAssertFalse(arrangement.setEnabled(.shelf, true))
    }

    func testMoveMatchesSwiftUISemantics() {
        var arrangement = ToolArrangement(storedOrder: ["nowPlaying", "shelf", "clipboard", "home"])
        let rest = Array(arrangement.order.dropFirst(3))
        arrangement.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)
        XCTAssertEqual(arrangement.order, [.shelf, .clipboard, .nowPlaying] + rest)
        arrangement.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        XCTAssertEqual(arrangement.order, [.nowPlaying, .shelf, .clipboard] + rest)
        arrangement.move(fromOffsets: IndexSet([0, 1]), toOffset: 3)
        XCTAssertEqual(arrangement.order, [.clipboard, .nowPlaying, .shelf] + rest)
        arrangement.move(fromOffsets: IndexSet(integer: 0), toOffset: arrangement.order.count)
        XCTAssertEqual(arrangement.order.last, .clipboard)
    }

    func testSelectionFallsBackToFirstEnabledTool() {
        var arrangement = ToolArrangement(storedOrder: ["nowPlaying", "shelf", "clipboard", "home"])
        arrangement.setEnabled(.nowPlaying, false)
        XCTAssertEqual(arrangement.resolvedSelection(.nowPlaying), .shelf)
        XCTAssertEqual(arrangement.resolvedSelection(.clipboard), .clipboard)
        XCTAssertEqual(arrangement.resolvedSelection(nil), .shelf)
    }

    func testEveryToolHasATitleAndSymbol() {
        for tool in NotchTool.allCases {
            XCTAssertFalse(tool.title.isEmpty)
            XCTAssertFalse(tool.symbolName.isEmpty)
        }
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
