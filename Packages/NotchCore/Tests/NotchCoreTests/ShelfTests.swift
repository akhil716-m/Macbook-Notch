import XCTest
@testable import NotchCore

final class ShelfTests: XCTestCase {
    private var tempRoot: URL!
    private var shelfRoot: URL { tempRoot.appendingPathComponent("Shelf") }
    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    private func makeFile(_ name: String, contents: String = "hello") throws -> URL {
        let url = tempRoot.appendingPathComponent(name)
        try Data(contents.utf8).write(to: url)
        return url
    }

    func testAddCopiesFilesAndKeepsThemAfterTheOriginalIsDeleted() async throws {
        let storage = ShelfStorage(rootURL: shelfRoot)
        let source = try makeFile("notes.txt", contents: "keep me")
        let result = try await storage.add([source], retention: 3_600, now: t0)

        XCTAssertEqual(result.added.count, 1)
        XCTAssertTrue(result.failed.isEmpty)
        let item = try XCTUnwrap(result.items.first)
        XCTAssertEqual(item.filename, "notes.txt")
        XCTAssertEqual(item.byteSize, 7)
        XCTAssertEqual(item.expiresAt, t0.addingTimeInterval(3_600))

        try FileManager.default.removeItem(at: source)
        let copy = storage.fileURL(for: item)
        XCTAssertEqual(try String(contentsOf: copy, encoding: .utf8), "keep me")
    }

    func testFoldersAreCopiedToo() async throws {
        let folder = tempRoot.appendingPathComponent("Project", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: folder.appendingPathComponent("a.txt"))

        let storage = ShelfStorage(rootURL: shelfRoot)
        let result = try await storage.add([folder], retention: nil, now: t0)
        let item = try XCTUnwrap(result.added.first)
        XCTAssertTrue(item.isDirectory)
        XCTAssertNil(item.expiresAt)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.fileURL(for: item).appendingPathComponent("a.txt").path))
    }

    func testNewestDropComesFirst() async throws {
        let storage = ShelfStorage(rootURL: shelfRoot)
        _ = try await storage.add([try makeFile("old.txt")], retention: nil, now: t0)
        let result = try await storage.add([try makeFile("new.txt")], retention: nil, now: t0.addingTimeInterval(1))
        XCTAssertEqual(result.items.map(\.filename), ["new.txt", "old.txt"])
    }

    func testMissingSourcesAndShelfItemsThemselvesAreRejected() async throws {
        let storage = ShelfStorage(rootURL: shelfRoot)
        let first = try await storage.add([try makeFile("a.txt")], retention: nil, now: t0)
        let ownCopy = storage.fileURL(for: try XCTUnwrap(first.added.first))
        let missing = tempRoot.appendingPathComponent("gone.txt")

        let result = try await storage.add([ownCopy, missing], retention: nil, now: t0)
        XCTAssertEqual(result.added.count, 0)
        XCTAssertEqual(result.failed.count, 2)
        XCTAssertEqual(result.items.count, 1)
    }

    func testRemoveDeletesTheCopy() async throws {
        let storage = ShelfStorage(rootURL: shelfRoot)
        let result = try await storage.add([try makeFile("a.txt"), try makeFile("b.txt")], retention: nil, now: t0)
        let first = try XCTUnwrap(result.added.first)
        let remaining = try await storage.remove(first.id)
        XCTAssertEqual(remaining.map(\.filename), ["b.txt"])
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.fileURL(for: first).path))

        let none = try await storage.removeAll()
        XCTAssertTrue(none.isEmpty)
    }

    func testExpiredItemsArePurged() async throws {
        let storage = ShelfStorage(rootURL: shelfRoot)
        _ = try await storage.add([try makeFile("short.txt")], retention: 60, now: t0)
        _ = try await storage.add([try makeFile("forever.txt")], retention: nil, now: t0)

        let early = try await storage.purgeExpired(now: t0.addingTimeInterval(59))
        XCTAssertEqual(early.count, 2)
        let later = try await storage.purgeExpired(now: t0.addingTimeInterval(60))
        XCTAssertEqual(later.map(\.filename), ["forever.txt"])
    }

    func testChangingRetentionRecountsFromWhenEachItemWasAdded() async throws {
        let storage = ShelfStorage(rootURL: shelfRoot)
        _ = try await storage.add([try makeFile("a.txt")], retention: nil, now: t0)
        let items = try await storage.applyRetention(3_600)
        XCTAssertEqual(items.first?.expiresAt, t0.addingTimeInterval(3_600))
    }

    func testIndexSurvivesARelaunch() async throws {
        let storage = ShelfStorage(rootURL: shelfRoot)
        _ = try await storage.add([try makeFile("a.txt")], retention: nil, now: t0)

        let reopened = ShelfStorage(rootURL: shelfRoot)
        let items = await reopened.allItems()
        XCTAssertEqual(items.map(\.filename), ["a.txt"])
        XCTAssertEqual(items.first?.addedAt, t0)
    }

    func testRetentionIntervals() {
        XCTAssertEqual(ShelfRetention.default, .oneDay)
        XCTAssertEqual(ShelfRetention.oneDay.interval, 86_400)
        XCTAssertNil(ShelfRetention.forever.interval)
    }
}
