import Foundation

/// Every tool that can live in the open notch. New tools are added here;
/// stored settings that don't mention them pick them up automatically.
public enum NotchTool: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case home
    case nowPlaying
    case shelf
    case clipboard
    case timers
    case todos
    case notes
    case systemStats
    case keepAwake
    case calendar
    case reminders
    case weather
    case ask
    case aiUsage
    case teleprompter
    case mirror
    case emoji
    case converter
    case stocks
    case revenue

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .home: return "Home"
        case .nowPlaying: return "Now Playing"
        case .shelf: return "Shelf"
        case .clipboard: return "Clipboard"
        case .timers: return "Timers"
        case .todos: return "To-dos"
        case .notes: return "Notes"
        case .systemStats: return "System"
        case .keepAwake: return "Keep Awake"
        case .calendar: return "Calendar"
        case .reminders: return "Reminders"
        case .weather: return "Weather"
        case .ask: return "Ask"
        case .aiUsage: return "AI Usage"
        case .teleprompter: return "Teleprompter"
        case .mirror: return "Mirror"
        case .emoji: return "Emoji"
        case .converter: return "Converter"
        case .stocks: return "Stocks"
        case .revenue: return "Revenue"
        }
    }

    /// SF Symbol name.
    public var symbolName: String {
        switch self {
        case .home: return "square.grid.2x2.fill"
        case .nowPlaying: return "music.note"
        case .shelf: return "tray.full"
        case .clipboard: return "doc.on.clipboard"
        case .timers: return "timer"
        case .todos: return "checklist"
        case .notes: return "note.text"
        case .systemStats: return "cpu"
        case .keepAwake: return "cup.and.saucer"
        case .calendar: return "calendar"
        case .reminders: return "list.bullet.circle"
        case .weather: return "cloud.sun"
        case .ask: return "sparkles"
        case .aiUsage: return "gauge.with.needle"
        case .teleprompter: return "text.alignleft"
        case .mirror: return "web.camera"
        case .emoji: return "face.smiling"
        case .converter: return "arrow.left.arrow.right"
        case .stocks: return "chart.line.uptrend.xyaxis"
        case .revenue: return "dollarsign.circle"
        }
    }
}

/// The user's order of tools and which ones are switched off.
public struct ToolArrangement: Equatable, Sendable {
    public private(set) var order: [NotchTool]
    public private(set) var disabled: Set<NotchTool>

    /// Builds from stored raw values, dropping unknown and duplicate entries
    /// and adding tools the stored order doesn't know about yet (Home first,
    /// the rest at the end).
    public init(storedOrder: [String] = [], storedDisabled: [String] = []) {
        var order: [NotchTool] = []
        for raw in storedOrder {
            if let tool = NotchTool(rawValue: raw), !order.contains(tool) {
                order.append(tool)
            }
        }
        for tool in NotchTool.allCases where !order.contains(tool) {
            // Home is the overview, so it joins at the front; others at the end.
            if tool == .home {
                order.insert(tool, at: 0)
            } else {
                order.append(tool)
            }
        }
        self.order = order
        var disabled = Set(storedDisabled.compactMap(NotchTool.init(rawValue:)))
        // Never end up with every tool off.
        if disabled.count >= order.count, let first = order.first {
            disabled.remove(first)
        }
        self.disabled = disabled
    }

    public var enabled: [NotchTool] { order.filter { !disabled.contains($0) } }

    public func isEnabled(_ tool: NotchTool) -> Bool { !disabled.contains(tool) }

    /// Switches a tool on or off. Refuses to switch off the last enabled tool.
    @discardableResult
    public mutating func setEnabled(_ tool: NotchTool, _ isOn: Bool) -> Bool {
        if isOn {
            return disabled.remove(tool) != nil
        }
        guard isEnabled(tool), enabled.count > 1 else { return false }
        disabled.insert(tool)
        return true
    }

    /// Same contract as SwiftUI's `move(fromOffsets:toOffset:)`.
    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.sorted().filter { $0 < order.count }.map { order[$0] }
        var remaining = order.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let insertAt = destination - source.filter { $0 < destination }.count
        remaining.insert(contentsOf: moving, at: max(0, min(insertAt, remaining.count)))
        order = remaining
    }

    /// The tool to show: the preferred one if it's on, else the first that is.
    public func resolvedSelection(_ preferred: NotchTool?) -> NotchTool? {
        if let preferred, isEnabled(preferred) { return preferred }
        return enabled.first
    }

    public var storedOrder: [String] { order.map(\.rawValue) }
    public var storedDisabled: [String] { disabled.map(\.rawValue).sorted() }
}

/// Which screens get a notch.
public enum DisplayMode: String, CaseIterable, Codable, Sendable, Identifiable {
    /// The built-in notched screen; if there is none, the primary screen.
    case automatic
    /// The primary screen (the one with the menu bar in Displays settings).
    case primary
    /// Every connected screen.
    case all

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .automatic: return "Built-in display"
        case .primary: return "Primary display"
        case .all: return "All displays"
        }
    }
}

public struct ScreenSummary: Equatable, Sendable {
    public var hasNotch: Bool
    public var isPrimary: Bool

    public init(hasNotch: Bool, isPrimary: Bool) {
        self.hasNotch = hasNotch
        self.isPrimary = isPrimary
    }
}

public enum DisplaySelection {
    /// Indices into `screens` that should get a notch window.
    public static func screens(_ screens: [ScreenSummary], mode: DisplayMode) -> [Int] {
        guard !screens.isEmpty else { return [] }
        let primary = screens.firstIndex(where: \.isPrimary) ?? 0
        switch mode {
        case .automatic:
            let notched = screens.indices.filter { screens[$0].hasNotch }
            return notched.isEmpty ? [primary] : notched
        case .primary:
            return [primary]
        case .all:
            return Array(screens.indices)
        }
    }
}
