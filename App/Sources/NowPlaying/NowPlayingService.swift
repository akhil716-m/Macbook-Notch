import AppKit
import Combine
import NotchCore

/// Knows what's playing in Music and Spotify and controls it.
///
/// Changes arrive as the players' own distributed notifications (free, no
/// permission). Details and controls go through AppleScript, which needs the
/// user's one-time Automation approval per player. Between readings the
/// position is extrapolated, so nothing polls while the notch is closed.
@MainActor
final class NowPlayingService: ObservableObject {
    @Published private(set) var track: NowPlayingTrack?
    @Published private(set) var artwork: NSImage?
    /// Set when a running player refused us under Privacy & Security › Automation.
    @Published private(set) var permissionNeeded: MediaPlayer?

    private let runner = AppleScriptRunner()
    private var tracks: [MediaPlayer: NowPlayingTrack] = [:]
    private var lastActive: [MediaPlayer: Date] = [:]
    private var inFlight: Set<MediaPlayer> = []
    private var refreshAgain: Set<MediaPlayer> = []
    private var artworkKey: String?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var liveTimer: Timer?

    /// How often to re-read the player while the notch is open, to catch
    /// seeks made in the player itself.
    private static let liveRefreshInterval: TimeInterval = 3

    func start() {
        let distributed = DistributedNotificationCenter.default()
        for player in MediaPlayer.allCases {
            let token = distributed.addObserver(
                forName: Notification.Name(player.playbackChangedNotification),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.lastActive[player] = Date()
                    self?.refresh(player)
                }
            }
            observers.append((distributed, token))
        }

        let workspace = NSWorkspace.shared.notificationCenter
        let token = workspace.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            let bundleID = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            MainActor.assumeIsolated { self?.playerQuit(bundleID: bundleID) }
        }
        observers.append((workspace, token))

        refreshAll()
    }

    /// Re-read the players every few seconds while the notch is open.
    func setLiveUpdates(_ on: Bool) {
        liveTimer?.invalidate()
        liveTimer = nil
        guard on else { return }
        refreshAll()
        liveTimer = Timer.scheduledTimer(withTimeInterval: Self.liveRefreshInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshAll() }
        }
    }

    // MARK: Controls

    func togglePlayPause() {
        guard var current = track else { return }
        // Flip locally first so the button responds instantly.
        let now = Date()
        current.position = current.elapsed(at: now)
        current.positionUpdatedAt = now
        current.status = current.status == .playing ? .paused : .playing
        tracks[current.player] = current
        publish()
        send(PlayerScripts.playPause(current.player), to: current.player)
    }

    func nextTrack() {
        guard let player = track?.player else { return }
        send(PlayerScripts.nextTrack(player), to: player)
    }

    func previousTrack() {
        guard let player = track?.player else { return }
        send(PlayerScripts.previousTrack(player), to: player)
    }

    func seek(to seconds: TimeInterval) {
        guard var current = track else { return }
        current.position = seconds
        current.positionUpdatedAt = Date()
        tracks[current.player] = current
        publish()
        send(PlayerScripts.seek(current.player, to: seconds), to: current.player)
    }

    private func send(_ source: String, to player: MediaPlayer) {
        guard isRunning(player) else { return }
        Task {
            let result = await self.runner.run(source)
            if case .failure(.notPermitted) = result {
                self.permissionNeeded = player
            }
            self.refresh(player)
        }
    }

    // MARK: Reading

    private func refreshAll() {
        for player in MediaPlayer.allCases {
            refresh(player)
        }
    }

    private func refresh(_ player: MediaPlayer) {
        // Never talk to a player that isn't running: AppleScript would launch it.
        guard isRunning(player) else {
            tracks[player] = nil
            if permissionNeeded == player { permissionNeeded = nil }
            publish()
            return
        }
        guard !inFlight.contains(player) else {
            refreshAgain.insert(player)
            return
        }
        inFlight.insert(player)

        Task {
            let result = await self.runner.fields(PlayerScripts.status(for: player))
            self.inFlight.remove(player)

            switch result {
            case .success(let fields):
                self.tracks[player] = NowPlayingTrack.parse(player: player, fields: fields, at: Date())
                if self.permissionNeeded == player { self.permissionNeeded = nil }
            case .failure(.notPermitted):
                self.tracks[player] = nil
                self.permissionNeeded = player
            case .failure:
                self.tracks[player] = nil
            }
            self.publish()

            if self.refreshAgain.remove(player) != nil {
                self.refresh(player)
            }
        }
    }

    private func playerQuit(bundleID: String?) {
        guard let player = MediaPlayer.allCases.first(where: { $0.bundleIdentifier == bundleID }) else { return }
        tracks[player] = nil
        lastActive[player] = nil
        if permissionNeeded == player { permissionNeeded = nil }
        publish()
    }

    private func isRunning(_ player: MediaPlayer) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: player.bundleIdentifier).isEmpty
    }

    private func publish() {
        let next = NowPlayingSelection.pick(Array(tracks.values), lastActive: lastActive)
        if next != track {
            track = next
        }
        updateArtwork(for: next)
    }

    // MARK: Artwork

    private func updateArtwork(for track: NowPlayingTrack?) {
        guard let track else {
            artworkKey = nil
            artwork = nil
            return
        }
        let key = track.artworkKey
        guard key != artworkKey else { return }
        artworkKey = key
        artwork = nil
        Task {
            let image = await self.loadArtwork(for: track)
            // Ignore it if the track changed while we were loading.
            guard self.artworkKey == key else { return }
            self.artwork = image
        }
    }

    private func loadArtwork(for track: NowPlayingTrack) async -> NSImage? {
        switch track.player {
        case .spotify:
            guard let url = track.artworkURL, url.scheme == "https" else { return nil }
            guard let response = try? await URLSession.shared.data(from: url) else { return nil }
            return NSImage(data: response.0)
        case .appleMusic:
            guard case .success(let data?) = await runner.data(PlayerScripts.musicArtwork) else { return nil }
            return NSImage(data: data)
        }
    }
}
