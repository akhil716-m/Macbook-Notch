import AppKit
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
    }

    func start() {
        nowPlaying.start()
        shelf.start()
        clipboard.start()
        timers.start()
        notes.start()
        todos.start()
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
