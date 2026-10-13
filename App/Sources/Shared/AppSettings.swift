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
        static let temperatureUnit = "weather.unit"
        static let weatherLocation = "weather.location"
        static let showVolumeInNotch = "volume.showInNotch"
        static let replaceSystemVolumeHUD = "volume.replaceSystemHUD"
        static let onboardingCompleted = "onboarding.completed"
        static let recentEmoji = "emoji.recent"
        static let stockSymbols = "stocks.symbols"
        static let revenueSources = "revenue.sources"
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

    @Published var temperatureUnit: TemperatureUnit {
        didSet { defaults.set(temperatureUnit.rawValue, forKey: Key.temperatureUnit) }
    }

    /// The place the Weather tool shows. Nil until the user picks one.
    @Published var weatherLocation: WeatherLocation? {
        didSet {
            if let weatherLocation, let data = try? JSONEncoder().encode(weatherLocation) {
                defaults.set(data, forKey: Key.weatherLocation)
            } else {
                defaults.removeObject(forKey: Key.weatherLocation)
            }
        }
    }

    /// Show volume changes in the closed notch.
    @Published var showVolumeInNotch: Bool {
        didSet { defaults.set(showVolumeInNotch, forKey: Key.showVolumeInNotch) }
    }

    /// Catch the volume keys so the macOS popup doesn't appear (needs Accessibility).
    @Published var replaceSystemVolumeHUD: Bool {
        didSet { defaults.set(replaceSystemVolumeHUD, forKey: Key.replaceSystemVolumeHUD) }
    }

    /// The welcome window has been seen and closed.
    @Published var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: Key.onboardingCompleted) }
    }

    @Published var recentEmoji: [String] {
        didSet { defaults.set(recentEmoji, forKey: Key.recentEmoji) }
    }

    /// Tickers for the Stocks tool.
    @Published var stockSymbols: [String] {
        didSet { defaults.set(stockSymbols, forKey: Key.stockSymbols) }
    }

    /// Stores connected to the Revenue tool. Their keys are in the Keychain.
    @Published var revenueSources: [RevenueSource] {
        didSet {
            if let data = try? JSONEncoder().encode(revenueSources) {
                defaults.set(data, forKey: Key.revenueSources)
            }
        }
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
        selectedTool = defaults.string(forKey: Key.selectedTool).flatMap(NotchTool.init(rawValue:)) ?? .home
        shelfRetention = defaults.string(forKey: Key.shelfRetention).flatMap(ShelfRetention.init(rawValue:)) ?? .default
        let storedLimit = defaults.integer(forKey: Key.clipboardLimit)
        clipboardLimit = ClipboardHistory.limitOptions.contains(storedLimit) ? storedLimit : ClipboardHistory.defaultLimit
        ignoredApps = defaults.stringArray(forKey: Key.ignoredApps) ?? PasteboardFilter.defaultIgnoredApps
        keepAwakeDisplayOn = defaults.object(forKey: Key.keepAwakeDisplayOn) as? Bool ?? true
        temperatureUnit = defaults.string(forKey: Key.temperatureUnit).flatMap(TemperatureUnit.init(rawValue:))
            ?? TemperatureUnit.preferred(usesMetric: Locale.current.measurementSystem != .us)
        weatherLocation = defaults.data(forKey: Key.weatherLocation)
            .flatMap { try? JSONDecoder().decode(WeatherLocation.self, from: $0) }
        showVolumeInNotch = defaults.object(forKey: Key.showVolumeInNotch) as? Bool ?? true
        replaceSystemVolumeHUD = defaults.bool(forKey: Key.replaceSystemVolumeHUD)
        onboardingCompleted = defaults.bool(forKey: Key.onboardingCompleted)
        recentEmoji = defaults.stringArray(forKey: Key.recentEmoji) ?? []
        stockSymbols = defaults.stringArray(forKey: Key.stockSymbols) ?? ["AAPL", "MSFT", "NVDA"]
        revenueSources = defaults.data(forKey: Key.revenueSources)
            .flatMap { try? JSONDecoder().decode([RevenueSource].self, from: $0) } ?? []
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
