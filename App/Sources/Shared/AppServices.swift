import AppKit
import EventKit
import NotchCore

/// One instance of every service, shared by all notch windows and Settings.
@MainActor
final class AppServices {
    let settings: AppSettings
    let launchAtLogin: LaunchAtLogin
    let nowPlaying: NowPlayingService
    let shelf: ShelfService
    let clipboard: ClipboardService
    let timers: TimerService
    let keepAwake: KeepAwakeService
    let systemStats: SystemStatsService
    let notes: NotesService
    let todos: TodoService
    let calendar: CalendarService
    let reminders: RemindersService
    let weather: WeatherService
    let volume: VolumeService
    let ask: AskService
    let aiUsage: AIUsageService
    let license: LicenseService
    let updates: UpdateService
    let teleprompter: TeleprompterService
    let camera: CameraService
    let currency: CurrencyService
    let stocks: StocksService
    let revenue: RevenueService
    private var onboardingWindow: OnboardingWindowController?
    private var settingsWindow: SettingsWindowController?

    init() {
        let support = Self.supportDirectory()
        let settings = AppSettings()
        self.settings = settings
        launchAtLogin = LaunchAtLogin()
        nowPlaying = NowPlayingService()
        shelf = ShelfService(
            storage: ShelfStorage(rootURL: support.appendingPathComponent("Shelf", isDirectory: true)),
            settings: settings
        )
        clipboard = ClipboardService(
            storage: ClipboardStorage(rootURL: support.appendingPathComponent("Clipboard", isDirectory: true)),
            settings: settings
        )
        timers = TimerService(fileURL: support.appendingPathComponent("timers.json"))
        keepAwake = KeepAwakeService(settings: settings)
        systemStats = SystemStatsService()
        notes = NotesService(fileURL: support.appendingPathComponent("notes.json"))
        todos = TodoService(fileURL: support.appendingPathComponent("todos.json"))
        // One EventKit store for both calendars and reminders.
        let eventStore = EKEventStore()
        calendar = CalendarService(store: eventStore)
        reminders = RemindersService(store: eventStore)
        weather = WeatherService(settings: settings, cacheURL: support.appendingPathComponent("weather.json"))
        volume = VolumeService(settings: settings)
        ask = AskService()
        aiUsage = AIUsageService()
        license = LicenseService()
        updates = UpdateService()
        teleprompter = TeleprompterService(fileURL: support.appendingPathComponent("teleprompter.json"))
        camera = CameraService()
        currency = CurrencyService(cacheURL: support.appendingPathComponent("rates.json"))
        stocks = StocksService(settings: settings)
        revenue = RevenueService(settings: settings)
    }

    func start() {
        nowPlaying.start()
        shelf.start()
        clipboard.start()
        timers.start()
        notes.start()
        todos.start()
        calendar.start()
        reminders.start()
        weather.start()
        volume.start()
        ask.refreshAvailability()
        license.start()
        teleprompter.start()
        if !settings.onboardingCompleted {
            openOnboarding()
        }
    }

    func openOnboarding() {
        if onboardingWindow == nil {
            onboardingWindow = OnboardingWindowController(services: self)
        }
        onboardingWindow?.show()
    }

    func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(services: self)
        }
        settingsWindow?.show()
    }

    /// ~/Library/Application Support/MacbookNotch
    private static func supportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let url = base.appendingPathComponent("MacbookNotch", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        return url
    }
}
