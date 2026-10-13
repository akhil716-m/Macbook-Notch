import AppKit
import Combine
import NotchCore

/// Keeps a history of what you copy, newest first, and copies any of it back.
///
/// macOS has no "clipboard changed" notification, so this checks the
/// pasteboard's change counter twice a second, which is a cheap integer read.
/// Nothing is recorded while the Clipboard tool is switched off, from
/// ignored apps, or when the copying app marks the clip as private.
@MainActor
final class ClipboardService: ObservableObject {
    @Published private(set) var clips: [Clip] = []
    /// The clip just copied back, for a brief "Copied" confirmation.
    @Published private(set) var recentlyCopiedID: UUID?

    private let storage: ClipboardStorage
    private let settings: AppSettings
    private var history: ClipboardHistory
    private var pollTimer: Timer?
    private var lastChangeCount = 0
    private var confirmationTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let thumbnails = NSCache<NSString, NSImage>()

    private static let pollInterval: TimeInterval = 0.5
    /// Bigger images are skipped rather than stored.
    private static let maxImageBytes = 25 * 1024 * 1024

    init(storage: ClipboardStorage, settings: AppSettings) {
        self.storage = storage
        self.settings = settings
        history = ClipboardHistory(limit: settings.clipboardLimit)
        thumbnails.countLimit = 100
    }

    func start() {
        Task {
            let stored = await self.storage.load()
            self.history = ClipboardHistory(clips: stored, limit: self.settings.clipboardLimit)
            self.clips = self.history.clips
        }

        settings.$tools
            .map { $0.isEnabled(.clipboard) }
            .removeDuplicates()
            .sink { [weak self] enabled in
                MainActor.assumeIsolated { self?.setRecording(enabled) }
            }
            .store(in: &cancellables)

        settings.$clipboardLimit
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] limit in
                MainActor.assumeIsolated { self?.applyLimit(limit) }
            }
            .store(in: &cancellables)
    }

    // MARK: Actions

    /// Puts a clip back on the clipboard and moves it to the top.
    func copy(_ clip: Clip) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        switch clip.kind {
        case .text, .link:
            pasteboard.setString(clip.text ?? "", forType: .string)
        case .image:
            if let filename = clip.imageFilename, let data = try? Data(contentsOf: storage.imageURL(filename)) {
                pasteboard.setData(data, forType: .png)
            }
        case .files:
            let urls = (clip.filePaths ?? []).map { URL(fileURLWithPath: $0) as NSURL }
            pasteboard.writeObjects(urls)
        }
        // Our own write: don't record it as a new copy.
        lastChangeCount = pasteboard.changeCount

        var promoted = clip
        promoted.copiedAt = Date()
        history.insert(promoted)
        publishAndSave(evicted: [])

        recentlyCopiedID = clip.id
        confirmationTask?.cancel()
        confirmationTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            self.recentlyCopiedID = nil
        }
    }

    func remove(_ clip: Clip) {
        guard let removed = history.remove(id: clip.id) else { return }
        publishAndSave(evicted: [removed])
    }

    func removeAll() {
        let removed = history.removeAll()
        publishAndSave(evicted: removed)
    }

    func thumbnail(for clip: Clip) -> NSImage? {
        guard let filename = clip.imageFilename else { return nil }
        let key = filename as NSString
        if let cached = thumbnails.object(forKey: key) { return cached }
        guard let image = NSImage(contentsOf: storage.imageURL(filename)) else { return nil }
        thumbnails.setObject(image, forKey: key)
        return image
    }

    // MARK: Recording

    private func setRecording(_ on: Bool) {
        pollTimer?.invalidate()
        pollTimer = nil
        // Whatever is on the clipboard when recording starts is not a new copy.
        lastChangeCount = NSPasteboard.general.changeCount
        guard on else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkPasteboard() }
        }
        pollTimer?.tolerance = Self.pollInterval / 2
    }

    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        let types = pasteboard.types?.map(\.rawValue) ?? []
        let source = NSWorkspace.shared.frontmostApplication
        guard PasteboardFilter.shouldRecord(
            types: types,
            sourceBundleID: source?.bundleIdentifier,
            ignoredApps: Set(settings.ignoredApps)
        ) else { return }

        let now = Date()
        let sourceID = source?.bundleIdentifier
        let sourceName = source?.localizedName

        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            let paths = urls.map(\.path)
            record(Clip(
                kind: .files,
                filePaths: paths,
                sourceBundleID: sourceID,
                sourceAppName: sourceName,
                copiedAt: now,
                contentHash: ContentHash.of(filePaths: paths)
            ))
        } else if PasteboardFilter.prefersImage(types: types), let png = Self.pngData(from: pasteboard) {
            recordImage(png, at: now, sourceID: sourceID, sourceName: sourceName)
        } else if let text = pasteboard.string(forType: .string), !ClipText.isBlank(text) {
            record(Clip(
                kind: ClipText.isLink(text) ? .link : .text,
                text: text,
                sourceBundleID: sourceID,
                sourceAppName: sourceName,
                copiedAt: now,
                contentHash: ContentHash.of(text: text)
            ))
        }
    }

    private func record(_ clip: Clip) {
        let evicted = history.insert(clip)
        publishAndSave(evicted: evicted)
    }

    private func recordImage(_ png: Data, at date: Date, sourceID: String?, sourceName: String?) {
        let hash = ContentHash.of(png)
        let id = UUID()
        let base = Clip(
            id: id,
            kind: .image,
            sourceBundleID: sourceID,
            sourceAppName: sourceName,
            copiedAt: date,
            contentHash: hash
        )
        // Same image again: just move it up, no second file.
        if history.clip(withHash: hash) != nil {
            record(base)
            return
        }
        Task {
            guard let filename = try? await self.storage.writeImage(png, id: id) else { return }
            var clip = base
            clip.imageFilename = filename
            self.record(clip)
        }
    }

    private func applyLimit(_ limit: Int) {
        let evicted = history.setLimit(limit)
        publishAndSave(evicted: evicted)
    }

    private func publishAndSave(evicted: [Clip]) {
        clips = history.clips
        let snapshot = history.clips
        for clip in evicted {
            if let filename = clip.imageFilename {
                thumbnails.removeObject(forKey: filename as NSString)
            }
        }
        Task {
            try? await self.storage.save(snapshot)
            await self.storage.deleteFiles(for: evicted)
        }
    }

    private static func pngData(from pasteboard: NSPasteboard) -> Data? {
        if let png = pasteboard.data(forType: .png) {
            return png.count <= maxImageBytes ? png : nil
        }
        guard let tiff = pasteboard.data(forType: .tiff), tiff.count <= maxImageBytes * 4,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]),
              png.count <= maxImageBytes
        else { return nil }
        return png
    }
}
