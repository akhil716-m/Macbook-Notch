import Foundation
import NotchCore

/// Every user preference, backed by UserDefaults. Services observe the
/// `@Published` properties.
///
/// Note: `@Published` publishers fire *before* the property changes, so
/// subscribers must use the value they're handed, not read the property.
@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let displayMode = "display.mode"
        static let openDelay = "hover.openDelay"
        static let closeDelay = "hover.closeDelay"
        static let toolOrder = "tools.order"
        static let toolsDisabled = "tools.disabled"
        static let selectedTool = "tools.selected"
        static let shelfRetention = "shelf.retention"
        static let clipboardLimit = "clipboard.limit"
        static let ignoredApps = "clipboard.ignoredApps"
        static let keepAwakeDisplayOn = "keepAwake.displayOn"
    }

    static let openDelayRange: ClosedRange<Double> = 0...0.6
    static let closeDelayRange: ClosedRange<Double> = 0.1...1.0

    private let defaults: UserDefaults

    @Published var displayMode: DisplayMode {
        didSet { defaults.set(displayMode.rawValue, forKey: Key.displayMode) }
    }

    /// Seconds the pointer must rest on the notch before it opens.
    @Published var openDelay: Double {
        didSet { defaults.set(openDelay, forKey: Key.openDelay) }
    }

    /// Seconds after the pointer leaves before the notch closes.
    @Published var closeDelay: Double {
        didSet { defaults.set(closeDelay, forKey: Key.closeDelay) }
    }

    @Published private(set) var tools: ToolArrangement {
        didSet {
            defaults.set(tools.storedOrder, forKey: Key.toolOrder)
            defaults.set(tools.storedDisabled, forKey: Key.toolsDisabled)
        }
    }

    /// The tool last shown in the open notch.
    @Published var selectedTool: NotchTool {
        didSet { defaults.set(selectedTool.rawValue, forKey: Key.selectedTool) }
    }

    @Published var shelfRetention: ShelfRetention {
        didSet { defaults.set(shelfRetention.rawValue, forKey: Key.shelfRetention) }
    }

    @Published var clipboardLimit: Int {
        didSet { defaults.set(clipboardLimit, forKey: Key.clipboardLimit) }
    }

    /// Bundle identifiers whose copies are never recorded.
    @Published var ignoredApps: [String] {
        didSet { defaults.set(ignoredApps, forKey: Key.ignoredApps) }
    }

    /// Keep Awake also stops the display from sleeping.
    @Published var keepAwakeDisplayOn: Bool {
        didSet { defaults.set(keepAwakeDisplayOn, forKey: Key.keepAwakeDisplayOn) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        displayMode = defaults.string(forKey: Key.displayMode).flatMap(DisplayMode.init(rawValue:)) ?? .automatic
        openDelay = (defaults.object(forKey: Key.openDelay) as? Double).map(Self.openDelayRange.clamp) ?? NotchStyle.hoverOpenDelay
        closeDelay = (defaults.object(forKey: Key.closeDelay) as? Double).map(Self.closeDelayRange.clamp) ?? NotchStyle.hoverCloseDelay
        tools = ToolArrangement(
            storedOrder: defaults.stringArray(forKey: Key.toolOrder) ?? [],
            storedDisabled: defaults.stringArray(forKey: Key.toolsDisabled) ?? []
        )
        selectedTool = defaults.string(forKey: Key.selectedTool).flatMap(NotchTool.init(rawValue:)) ?? .nowPlaying
        shelfRetention = defaults.string(forKey: Key.shelfRetention).flatMap(ShelfRetention.init(rawValue:)) ?? .default
        let storedLimit = defaults.integer(forKey: Key.clipboardLimit)
        clipboardLimit = ClipboardHistory.limitOptions.contains(storedLimit) ? storedLimit : ClipboardHistory.defaultLimit
        ignoredApps = defaults.stringArray(forKey: Key.ignoredApps) ?? PasteboardFilter.defaultIgnoredApps
        keepAwakeDisplayOn = defaults.object(forKey: Key.keepAwakeDisplayOn) as? Bool ?? true
    }

    func setTool(_ tool: NotchTool, enabled: Bool) {
        var updated = tools
        guard updated.setEnabled(tool, enabled) else { return }
        tools = updated
    }

    func moveTools(fromOffsets source: IndexSet, toOffset destination: Int) {
        var updated = tools
        updated.move(fromOffsets: source, toOffset: destination)
        tools = updated
    }
}

private extension ClosedRange where Bound == Double {
    func clamp(_ value: Double) -> Double {
        Swift.min(Swift.max(value, lowerBound), upperBound)
    }
}
