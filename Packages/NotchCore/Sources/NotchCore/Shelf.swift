import Foundation

/// A file or folder parked on the shelf. The shelf keeps its own copy, so
/// moving or deleting the original doesn't break it. On APFS the copy is a
/// clone, so it takes no extra disk space until one side changes.
public struct ShelfItem: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var filename: String
    /// Path under the shelf folder: "<id>/<filename>".
    public var relativePath: String
    public var isDirectory: Bool
    public var byteSize: Int64
    public let addedAt: Date
    /// Nil means "keep until removed".
    public var expiresAt: Date?

    public init(
        id: UUID,
        filename: String,
        relativePath: String,
        isDirectory: Bool,
        byteSize: Int64,
        addedAt: Date,
        expiresAt: Date?
    ) {
        self.id = id
        self.filename = filename
        self.relativePath = relativePath
        self.isDirectory = isDirectory
        self.byteSize = byteSize
        self.addedAt = addedAt
        self.expiresAt = expiresAt
    }
}

/// How long the shelf keeps files.
public enum ShelfRetention: String, CaseIterable, Codable, Sendable, Identifiable {
    case oneHour
    case sixHours
    case oneDay
    case threeDays
    case oneWeek
    case forever

    public static let `default` = ShelfRetention.oneDay

    public var id: String { rawValue }

    public var interval: TimeInterval? {
        switch self {
        case .oneHour: return 3_600
        case .sixHours: return 6 * 3_600
        case .oneDay: return 24 * 3_600
        case .threeDays: return 3 * 24 * 3_600
        case .oneWeek: return 7 * 24 * 3_600
        case .forever: return nil
        }
    }

    public var title: String {
        switch self {
        case .oneHour: return "1 hour"
        case .sixHours: return "6 hours"
        case .oneDay: return "1 day"
        case .threeDays: return "3 days"
        case .oneWeek: return "1 week"
        case .forever: return "Until I remove them"
        }
    }
}

public struct ShelfAddResult: Sendable {
    public var items: [ShelfItem]
    public var added: [ShelfItem]
    public var failed: [URL]
}

/// The shelf's files and index on disk. An actor, so copying big files never
/// happens on the main thread.
public actor ShelfStorage {
    public nonisolated let rootURL: URL
    private var items: [ShelfItem]

    private static let indexName = "shelf.json"

    public init(rootURL: URL) {
        self.rootURL = rootURL
        let index = rootURL.appendingPathComponent(Self.indexName)
        let loaded = JSONFileStore.load([ShelfItem].self, from: index) ?? []
        // Drop entries whose files have gone missing.
        items = loaded.filter {
            FileManager.default.fileExists(atPath: rootURL.appendingPathComponent($0.relativePath).path)
        }
    }

    /// Newest first.
    public func allItems() -> [ShelfItem] { items }

    public nonisolated func fileURL(for item: ShelfItem) -> URL {
        rootURL.appendingPathComponent(item.relativePath)
    }

    /// Copies each source in. Sources that are already on the shelf, or that
    /// can't be copied, are skipped and reported in `failed`.
    public func add(_ sources: [URL], retention: TimeInterval?, now: Date = Date()) throws -> ShelfAddResult {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)

        var added: [ShelfItem] = []
        var failed: [URL] = []
        let rootPath = rootURL.standardizedFileURL.path

        for source in sources {
            let sourcePath = source.standardizedFileURL.path
            if sourcePath.hasPrefix(rootPath + "/") {
                failed.append(source)
                continue
            }
            let id = UUID()
            let folder = rootURL.appendingPathComponent(id.uuidString, isDirectory: true)
            let filename = source.lastPathComponent
            let destination = folder.appendingPathComponent(filename)
            do {
                try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
                try fileManager.copyItem(at: source, to: destination)
            } catch {
                try? fileManager.removeItem(at: folder)
                failed.append(source)
                continue
            }
            let values = try? destination.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            let item = ShelfItem(
                id: id,
                filename: filename,
                relativePath: "\(id.uuidString)/\(filename)",
                isDirectory: values?.isDirectory ?? false,
                byteSize: Int64(values?.fileSize ?? 0),
                addedAt: now,
                expiresAt: retention.map { now.addingTimeInterval($0) }
            )
            added.append(item)
        }

        // Newest first; within one drop, keep the order the files came in.
        items.insert(contentsOf: added, at: 0)
        try persist()
        return ShelfAddResult(items: items, added: added, failed: failed)
    }

    public func remove(_ id: UUID) throws -> [ShelfItem] {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return items }
        deleteFiles(of: items.remove(at: index))
        try persist()
        return items
    }

    public func removeAll() throws -> [ShelfItem] {
        for item in items { deleteFiles(of: item) }
        items.removeAll()
        try persist()
        return items
    }

    /// Deletes everything whose time is up.
    public func purgeExpired(now: Date = Date()) throws -> [ShelfItem] {
        let expired = items.filter { ($0.expiresAt ?? .distantFuture) <= now }
        guard !expired.isEmpty else { return items }
        for item in expired { deleteFiles(of: item) }
        items.removeAll { ($0.expiresAt ?? .distantFuture) <= now }
        try persist()
        return items
    }

    /// Applies a new retention to everything already on the shelf, counted
    /// from when each item was added.
    public func applyRetention(_ retention: TimeInterval?) throws -> [ShelfItem] {
        items = items.map { item in
            var item = item
            item.expiresAt = retention.map { item.addedAt.addingTimeInterval($0) }
            return item
        }
        try persist()
        return items
    }

    private func deleteFiles(of item: ShelfItem) {
        try? FileManager.default.removeItem(at: rootURL.appendingPathComponent(item.id.uuidString, isDirectory: true))
    }

    private func persist() throws {
        try JSONFileStore.save(items, to: rootURL.appendingPathComponent(Self.indexName))
    }
}
