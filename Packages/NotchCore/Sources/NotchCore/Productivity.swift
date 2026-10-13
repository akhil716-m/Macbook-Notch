import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

public struct TodoItem: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var isDone: Bool
    public let createdAt: Date
    public var completedAt: Date?

    public init(id: UUID = UUID(), title: String, createdAt: Date) {
        self.id = id
        self.title = title
        self.isDone = false
        self.createdAt = createdAt
        self.completedAt = nil
    }
}

/// A simple to-do list: open items in the order they were added, done
/// items below them, most recently finished first.
public struct TodoList: Codable, Equatable, Sendable {
    public private(set) var items: [TodoItem]

    public init(items: [TodoItem] = []) {
        self.items = items
        sort()
    }

    public var openCount: Int { items.filter { !$0.isDone }.count }
    public var hasCompleted: Bool { items.contains { $0.isDone } }

    /// Ignores blank titles. Returns the new item.
    @discardableResult
    public mutating func add(_ title: String, at date: Date) -> TodoItem? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let item = TodoItem(title: trimmed, createdAt: date)
        items.append(item)
        sort()
        return item
    }

    public mutating func toggle(_ id: UUID, at date: Date) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isDone.toggle()
        items[index].completedAt = items[index].isDone ? date : nil
        sort()
    }

    public mutating func rename(_ id: UUID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].title = trimmed
    }

    public mutating func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    public mutating func clearCompleted() {
        items.removeAll(where: \.isDone)
    }

    private mutating func sort() {
        let open = items.filter { !$0.isDone }.sorted { $0.createdAt < $1.createdAt }
        let done = items.filter(\.isDone).sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        items = open + done
    }
}

/// The quick-notes scratchpad.
public struct Scratchpad: Codable, Equatable, Sendable {
    public var text: String
    public var updatedAt: Date?

    public init(text: String = "", updatedAt: Date? = nil) {
        self.text = text
        self.updatedAt = updatedAt
    }

    public var wordCount: Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }
}

/// How long Keep Awake lasts.
public enum KeepAwakeDuration: String, CaseIterable, Codable, Sendable, Identifiable {
    case thirtyMinutes
    case oneHour
    case twoHours
    case fourHours
    case indefinitely

    public var id: String { rawValue }

    public var interval: TimeInterval? {
        switch self {
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 3_600
        case .twoHours: return 2 * 3_600
        case .fourHours: return 4 * 3_600
        case .indefinitely: return nil
        }
    }

    public var title: String {
        switch self {
        case .thirtyMinutes: return "30 min"
        case .oneHour: return "1 hour"
        case .twoHours: return "2 hours"
        case .fourHours: return "4 hours"
        case .indefinitely: return "Until I turn it off"
        }
    }
}

/// Lays out tool tabs on both sides of the notch: as many as fit on the
/// left, then the right (after the Settings button), then an overflow menu.
public struct TabStripLayout: Equatable, Sendable {
    public var left: Int
    public var right: Int
    public var overflow: Int

    public static func split(
        count: Int,
        sideWidth: CGFloat,
        tabWidth: CGFloat,
        spacing: CGFloat,
        rightReserved: CGFloat
    ) -> TabStripLayout {
        func capacity(_ width: CGFloat) -> Int {
            guard width >= tabWidth else { return 0 }
            return Int(((width + spacing) / (tabWidth + spacing)).rounded(.down))
        }
        let left = min(count, capacity(sideWidth))
        let remaining = count - left
        let rightCapacity = capacity(sideWidth - rightReserved)
        if remaining <= rightCapacity {
            return TabStripLayout(left: left, right: remaining, overflow: 0)
        }
        // One right-hand slot becomes the overflow button.
        let right = max(0, rightCapacity - 1)
        return TabStripLayout(left: left, right: right, overflow: remaining - right)
    }
}
