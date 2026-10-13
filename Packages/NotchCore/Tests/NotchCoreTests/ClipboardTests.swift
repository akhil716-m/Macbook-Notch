import XCTest
@testable import NotchCore

final class ClipboardTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func textClip(_ text: String, at offset: TimeInterval = 0, source: String? = nil) -> Clip {
        Clip(
            kind: .text,
            text: text,
            sourceBundleID: source,
            copiedAt: t0.addingTimeInterval(offset),
            contentHash: ContentHash.of(text: text)
        )
    }

    // MARK: History

    func testNewestFirst() {
        var history = ClipboardHistory()
        history.insert(textClip("one"))
        history.insert(textClip("two", at: 1))
        XCTAssertEqual(history.clips.map(\.text), ["two", "one"])
    }

    func testCopyingTheSameThingAgainMovesItUpInsteadOfDuplicating() {
        var history = ClipboardHistory()
        history.insert(textClip("one"))
        let original = history.clips[0]
        history.insert(textClip("two", at: 1))
        history.insert(textClip("one", at: 2, source: "com.apple.Safari"))

        XCTAssertEqual(history.clips.map(\.text), ["one", "two"])
        XCTAssertEqual(history.clips[0].id, original.id, "keeps the existing entry")
        XCTAssertEqual(history.clips[0].copiedAt, t0.addingTimeInterval(2))
        XCTAssertEqual(history.clips[0].sourceBundleID, "com.apple.Safari")
    }

    func testOldestFallOffAtTheLimitAndAreReturned() {
        var history = ClipboardHistory(limit: 2)
        history.insert(textClip("a"))
        history.insert(textClip("b"))
        let evicted = history.insert(textClip("c"))
        XCTAssertEqual(history.clips.map(\.text), ["c", "b"])
        XCTAssertEqual(evicted.map(\.text), ["a"])
    }

    func testLoweringTheLimitTrims() {
        var history = ClipboardHistory(clips: ["a", "b", "c"].map { textClip($0) })
        let evicted = history.setLimit(1)
        XCTAssertEqual(history.clips.map(\.text), ["a"])
        XCTAssertEqual(evicted.count, 2)
    }

    func testRemove() {
        var history = ClipboardHistory()
        history.insert(textClip("a"))
        let id = history.clips[0].id
        XCTAssertEqual(history.remove(id: id)?.text, "a")
        XCTAssertNil(history.remove(id: id))
        history.insert(textClip("b"))
        XCTAssertEqual(history.removeAll().count, 1)
        XCTAssertTrue(history.clips.isEmpty)
    }

    // MARK: Filter

    func testPasswordManagerClipsAreNeverRecorded() {
        XCTAssertFalse(PasteboardFilter.shouldRecord(
            types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"],
            sourceBundleID: nil,
            ignoredApps: []
        ))
        XCTAssertFalse(PasteboardFilter.shouldRecord(
            types: ["public.utf8-plain-text", "org.nspasteboard.TransientType"],
            sourceBundleID: nil,
            ignoredApps: []
        ))
    }

    func testIgnoredAppsAreSkipped() {
        XCTAssertFalse(PasteboardFilter.shouldRecord(
            types: ["public.utf8-plain-text"],
            sourceBundleID: "com.bitwarden.desktop",
            ignoredApps: Set(PasteboardFilter.defaultIgnoredApps)
        ))
        XCTAssertTrue(PasteboardFilter.shouldRecord(
            types: ["public.utf8-plain-text"],
            sourceBundleID: "com.apple.Safari",
            ignoredApps: Set(PasteboardFilter.defaultIgnoredApps)
        ))
    }

    func testImageOrTextFollowsTheCopyingAppsPreference() {
        XCTAssertTrue(PasteboardFilter.prefersImage(types: ["public.png"]))
        XCTAssertTrue(PasteboardFilter.prefersImage(types: ["public.tiff", "public.utf8-plain-text"]))
        XCTAssertFalse(PasteboardFilter.prefersImage(types: ["public.utf8-plain-text", "public.tiff"]))
        XCTAssertFalse(PasteboardFilter.prefersImage(types: ["public.utf8-plain-text"]))
        XCTAssertFalse(PasteboardFilter.prefersImage(types: []))
    }

    func testEmptyPasteboardIsSkipped() {
        XCTAssertFalse(PasteboardFilter.shouldRecord(types: [], sourceBundleID: nil, ignoredApps: []))
    }

    // MARK: Text helpers

    func testLinkDetection() {
        XCTAssertTrue(ClipText.isLink("https://example.com/path?q=1"))
        XCTAssertTrue(ClipText.isLink("  http://example.com \n"))
        XCTAssertFalse(ClipText.isLink("example.com"))
        XCTAssertFalse(ClipText.isLink("see https://example.com"))
        XCTAssertFalse(ClipText.isLink("ftp://example.com"))
        XCTAssertFalse(ClipText.isLink("https://"))
    }

    func testPreviewCollapsesWhitespaceAndCuts() {
        XCTAssertEqual(ClipText.preview("  a\n\n b\tc  "), "a b c")
        XCTAssertEqual(ClipText.preview("abcdef", maxLength: 3), "abc…")
        XCTAssertTrue(ClipText.isBlank(" \n\t"))
        XCTAssertFalse(ClipText.isBlank(" x "))
    }

    func testHashesAreStableAndKindSpecific() {
        XCTAssertEqual(ContentHash.of(text: "a"), ContentHash.of(text: "a"))
        XCTAssertNotEqual(ContentHash.of(text: "a"), ContentHash.of(text: "b"))
        XCTAssertNotEqual(ContentHash.of(text: "/tmp/a"), ContentHash.of(filePaths: ["/tmp/a"]))
        XCTAssertEqual(ContentHash.of(Data()).count, 64)
    }

    // MARK: Storage

    func testStorageRoundTripAndImageCleanup() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = ClipboardStorage(rootURL: root)

        let id = UUID()
        let filename = try await storage.writeImage(Data([1, 2, 3]), id: id)
        let image = Clip(id: id, kind: .image, imageFilename: filename, copiedAt: t0, contentHash: "h")
        let text = textClip("a")
        try await storage.save([image, text])

        let loaded = await storage.load()
        XCTAssertEqual(loaded, [image, text])
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage.imageURL(filename).path))

        await storage.deleteFiles(for: [image])
        XCTAssertFalse(FileManager.default.fileExists(atPath: storage.imageURL(filename).path))
    }
}
