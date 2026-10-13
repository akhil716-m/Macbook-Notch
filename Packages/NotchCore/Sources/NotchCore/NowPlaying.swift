import Foundation

/// The media apps we can read and control in v1.
public enum MediaPlayer: String, CaseIterable, Codable, Sendable {
    case appleMusic
    case spotify

    public var bundleIdentifier: String {
        switch self {
        case .appleMusic: return "com.apple.Music"
        case .spotify: return "com.spotify.client"
        }
    }

    public var displayName: String {
        switch self {
        case .appleMusic: return "Music"
        case .spotify: return "Spotify"
        }
    }

    /// Posted by the app on every play, pause and track change. Needs no permission.
    public var playbackChangedNotification: String {
        switch self {
        case .appleMusic: return "com.apple.Music.playerInfo"
        case .spotify: return "com.spotify.client.PlaybackStateChanged"
        }
    }
}

public enum PlaybackStatus: String, Equatable, Sendable {
    case playing
    case paused
    case stopped

    /// Reads `player state as text` from Music or Spotify. Handles both the
    /// English words and the raw four-character codes AppleScript falls back to.
    public init(scriptValue raw: String) {
        let lower = raw.lowercased()
        if raw.contains("kPSP") || lower.hasPrefix("play") || lower.contains("forward") || lower.contains("rewind") {
            self = .playing
        } else if raw.contains("kPSp") || lower.hasPrefix("pause") {
            self = .paused
        } else {
            self = .stopped
        }
    }
}

/// One value from an AppleScript result list.
public enum ScriptField: Equatable, Sendable {
    case text(String)
    case number(Double)
    case missing

    public var text: String? {
        if case .text(let value) = self { return value }
        return nil
    }

    /// Numbers come back as reals, but tolerate text in either decimal style.
    public var number: Double? {
        switch self {
        case .number(let value):
            return value.isFinite ? value : nil
        case .text(let value):
            return Double(value.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
        case .missing:
            return nil
        }
    }
}

public struct NowPlayingTrack: Equatable, Sendable {
    public var player: MediaPlayer
    public var status: PlaybackStatus
    public var title: String
    public var artist: String
    public var album: String
    /// Seconds. Zero when unknown (e.g. a radio stream).
    public var duration: TimeInterval
    /// Seconds into the track at `positionUpdatedAt`.
    public var position: TimeInterval
    public var positionUpdatedAt: Date
    /// Spotify gives us an artwork URL; Music gives raw image data instead.
    public var artworkURL: URL?

    public init(
        player: MediaPlayer,
        status: PlaybackStatus,
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        position: TimeInterval,
        positionUpdatedAt: Date,
        artworkURL: URL? = nil
    ) {
        self.player = player
        self.status = status
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.position = position
        self.positionUpdatedAt = positionUpdatedAt
        self.artworkURL = artworkURL
    }

    /// Identifies the track for artwork caching.
    public var artworkKey: String { "\(player.rawValue)|\(title)|\(artist)|\(album)" }

    /// Where playback is at `date`, extrapolated from the last reading so the
    /// scrubber moves without asking the player every second.
    public func elapsed(at date: Date) -> TimeInterval {
        var value = position
        if status == .playing {
            value += max(0, date.timeIntervalSince(positionUpdatedAt))
        }
        if duration > 0 {
            value = min(value, duration)
        }
        return max(0, value)
    }

    public func progress(at date: Date) -> Double {
        duration > 0 ? elapsed(at: date) / duration : 0
    }

    /// Parses the list returned by `PlayerScripts.status(for:)`:
    /// `{state, name, artist, album, position (s), duration (s), artwork url?}`.
    /// Returns nil when the player is stopped or the result is malformed.
    public static func parse(player: MediaPlayer, fields: [ScriptField], at date: Date) -> NowPlayingTrack? {
        guard let state = fields.first?.text else { return nil }
        let status = PlaybackStatus(scriptValue: state)
        guard status != .stopped, fields.count >= 6 else { return nil }

        var artworkURL: URL?
        if fields.count > 6, let raw = fields[6].text, !raw.isEmpty {
            artworkURL = URL(string: raw)
        }

        return NowPlayingTrack(
            player: player,
            status: status,
            title: fields[1].text ?? "",
            artist: fields[2].text ?? "",
            album: fields[3].text ?? "",
            duration: max(0, fields[5].number ?? 0),
            position: max(0, fields[4].number ?? 0),
            positionUpdatedAt: date,
            artworkURL: artworkURL
        )
    }
}

public enum NowPlayingSelection {
    /// Which track the notch shows when more than one player is running:
    /// anything playing beats anything paused, then the most recently active
    /// player wins, then a fixed order so the choice never flickers.
    public static func pick(_ tracks: [NowPlayingTrack], lastActive: [MediaPlayer: Date]) -> NowPlayingTrack? {
        let order = MediaPlayer.allCases
        return tracks.max { lhs, rhs in
            let left = (lhs.status == .playing ? 1 : 0, lastActive[lhs.player] ?? .distantPast)
            let right = (rhs.status == .playing ? 1 : 0, lastActive[rhs.player] ?? .distantPast)
            if left != right { return left < right }
            // Earlier in `allCases` wins ties.
            return (order.firstIndex(of: lhs.player) ?? 0) > (order.firstIndex(of: rhs.player) ?? 0)
        }
    }
}

public enum PlaybackTimeFormatter {
    /// "3:07", or "1:02:03" past an hour. Anything invalid reads "0:00".
    public static func string(from seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
