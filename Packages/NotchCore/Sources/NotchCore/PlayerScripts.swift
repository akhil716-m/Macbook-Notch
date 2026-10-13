import Foundation

/// AppleScript sources for reading and controlling Music and Spotify.
///
/// Only run these while the app is already running: `tell application` would
/// otherwise launch it, and compiling a script for an app that is not
/// installed fails.
public enum PlayerScripts {
    /// Returns `{"stopped"}` or `{state, name, artist, album, position, duration, artworkURL}`.
    /// Position and duration are in seconds for both players.
    public static func status(for player: MediaPlayer) -> String {
        switch player {
        case .appleMusic:
            return """
            tell application id "\(player.bundleIdentifier)"
                set playerState to player state as text
                if playerState is "stopped" then return {"stopped"}
                set t to current track
                return {playerState, name of t, artist of t, album of t, player position, duration of t, ""}
            end tell
            """
        case .spotify:
            return """
            tell application id "\(player.bundleIdentifier)"
                set playerState to player state as text
                if playerState is "stopped" then return {"stopped"}
                set t to current track
                return {playerState, name of t, artist of t, album of t, player position, (duration of t) / 1000, artwork url of t}
            end tell
            """
        }
    }

    /// Raw image data of the current track's artwork. Music only; Spotify
    /// gives a URL in `status(for:)` instead.
    public static let musicArtwork = """
    tell application id "\(MediaPlayer.appleMusic.bundleIdentifier)"
        try
            return raw data of artwork 1 of current track
        end try
        try
            return data of artwork 1 of current track
        end try
        return missing value
    end tell
    """

    public static func playPause(_ player: MediaPlayer) -> String {
        command("playpause", player)
    }

    public static func nextTrack(_ player: MediaPlayer) -> String {
        command("next track", player)
    }

    public static func previousTrack(_ player: MediaPlayer) -> String {
        command("previous track", player)
    }

    /// AppleScript literals always use "." as the decimal separator,
    /// whatever the user's locale, and `String(format:)` does too.
    public static func seek(_ player: MediaPlayer, to seconds: TimeInterval) -> String {
        let clamped = seconds.isFinite ? max(0, seconds) : 0
        return command("set player position to \(String(format: "%.2f", clamped))", player)
    }

    private static func command(_ body: String, _ player: MediaPlayer) -> String {
        "tell application id \"\(player.bundleIdentifier)\" to \(body)"
    }
}
