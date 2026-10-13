import AppKit
import Combine
import NotchCore

/// Files parked on the notch: drop in, open, drag out, AirDrop, remove.
/// File copying happens in `ShelfStorage` (an actor), off the main thread.
@MainActor
final class ShelfService: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []
    /// A short message for the shelf to show, e.g. when a file couldn't be added.
    @Published private(set) var notice: String?

    private let storage: ShelfStorage
    private let settings: AppSettings
    private var purgeTimer: Timer?
    private var noticeTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    private static let purgeInterval: TimeInterval = 15 * 60

    init(storage: ShelfStorage, settings: AppSettings) {
        self.storage = storage
        self.settings = settings
    }

    func start() {
        Task {
            self.items = await self.storage.allItems()
            self.purgeExpired()
        }
        purgeTimer = Timer.scheduledTimer(withTimeInterval: Self.purgeInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.purgeExpired() }
        }
        settings.$shelfRetention
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] retention in
                MainActor.assumeIsolated { self?.applyRetention(retention) }
            }
            .store(in: &cancellables)
    }

    func fileURL(for item: ShelfItem) -> URL {
        storage.fileURL(for: item)
    }

    func add(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        let retention = settings.shelfRetention.interval
        Task {
            do {
                let result = try await self.storage.add(urls, retention: retention)
                self.items = result.items
                if !result.failed.isEmpty {
                    self.show(notice: result.failed.count == 1
                        ? "Couldn't add \(result.failed[0].lastPathComponent)"
                        : "Couldn't add \(result.failed.count) items")
                }
            } catch {
                self.show(notice: "Couldn't save the shelf")
            }
        }
    }

    func remove(_ item: ShelfItem) {
        Task {
            if let items = try? await self.storage.remove(item.id) {
                self.items = items
            }
        }
    }

    func removeAll() {
        Task {
            if let items = try? await self.storage.removeAll() {
                self.items = items
            }
        }
    }

    func open(_ item: ShelfItem) {
        NSWorkspace.shared.open(fileURL(for: item))
    }

    func revealInFinder(_ item: ShelfItem) {
        NSWorkspace.shared.activateFileViewerSelecting([fileURL(for: item)])
    }

    var canAirDrop: Bool {
        NSSharingService(named: .sendViaAirDrop) != nil
    }

    /// Opens the AirDrop picker for the given items (all items if empty).
    func airDrop(_ selection: [ShelfItem] = []) {
        let urls = (selection.isEmpty ? items : selection).map { fileURL(for: $0) }
        guard !urls.isEmpty, let service = NSSharingService(named: .sendViaAirDrop) else { return }
        guard service.canPerform(withItems: urls) else {
            show(notice: "AirDrop isn't available right now")
            return
        }
        // The picker is a window of ours, so bring the app forward for it.
        NSApp.activate()
        service.perform(withItems: urls)
    }

    private func purgeExpired() {
        Task {
            if let items = try? await self.storage.purgeExpired() {
                self.items = items
            }
        }
    }

    private func applyRetention(_ retention: ShelfRetention) {
        Task {
            if let items = try? await self.storage.applyRetention(retention.interval) {
                self.items = items
            }
            self.purgeExpired()
        }
    }

    private func show(notice: String) {
        self.notice = notice
        noticeTask?.cancel()
        noticeTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self.notice = nil
        }
    }
}
