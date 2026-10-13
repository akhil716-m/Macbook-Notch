import XCTest
@testable import NotchCore

final class NowPlayingTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000_000)

    private func track(
        _ player: MediaPlayer = .spotify,
        status: PlaybackStatus = .playing,
        duration: TimeInterval = 200,
        position: TimeInterval = 50
    ) -> NowPlayingTrack {
        NowPlayingTrack(
            player: player, status: status, title: "Song", artist: "Artist", album: "Album",
            duration: duration, position: position, positionUpdatedAt: t0
        )
    }

    // MARK: status

    func testPlaybackStatusFromWordsAndRawCodes() {
        XCTAssertEqual(PlaybackStatus(scriptValue: "playing"), .playing)
        XCTAssertEqual(PlaybackStatus(scriptValue: "paused"), .paused)
        XCTAssertEqual(PlaybackStatus(scriptValue: "stopped"), .stopped)
        XCTAssertEqual(PlaybackStatus(scriptValue: "fast forwarding"), .playing)
        XCTAssertEqual(PlaybackStatus(scriptValue: "«constant ****kPSP»"), .playing)
        XCTAssertEqual(PlaybackStatus(scriptValue: "«constant ****kPSp»"), .paused)
        XCTAssertEqual(PlaybackStatus(scriptValue: "«constant ****kPSS»"), .stopped)
    }

    // MARK: parsing

    func testParsesSpotifyResult() {
        let fields: [ScriptField] = [
            .text("playing"), .text("Song"), .text("Artist"), .text("Album"),
            .number(12.5), .number(201.3), .text("https://i.scdn.co/image/abc"),
        ]
        let parsed = NowPlayingTrack.parse(player: .spotify, fields: fields, at: t0)
        XCTAssertEqual(parsed?.status, .playing)
        XCTAssertEqual(parsed?.title, "Song")
        XCTAssertEqual(parsed?.position, 12.5)
        XCTAssertEqual(parsed?.duration, 201.3)
        XCTAssertEqual(parsed?.artworkURL, URL(string: "https://i.scdn.co/image/abc"))
    }

    func testParsesMusicResultWithEmptyArtworkAndMissingDuration() {
        let fields: [ScriptField] = [
            .text("paused"), .text("Live Radio"), .text(""), .text(""), .number(3), .missing, .text(""),
        ]
        let parsed = NowPlayingTrack.parse(player: .appleMusic, fields: fields, at: t0)
        XCTAssertEqual(parsed?.status, .paused)
        XCTAssertEqual(parsed?.duration, 0)
        XCTAssertNil(parsed?.artworkURL)
    }

    func testNumbersAsTextInEitherDecimalStyle() {
        XCTAssertEqual(ScriptField.text("12,5").number, 12.5)
        XCTAssertEqual(ScriptField.text(" 12.5 ").number, 12.5)
        XCTAssertNil(ScriptField.text("abc").number)
        XCTAssertNil(ScriptField.number(.nan).number)
    }

    func testStoppedOrMalformedResultsAreNil() {
        XCTAssertNil(NowPlayingTrack.parse(player: .spotify, fields: [.text("stopped")], at: t0))
        XCTAssertNil(NowPlayingTrack.parse(player: .spotify, fields: [.text("playing"), .text("x")], at: t0))
        XCTAssertNil(NowPlayingTrack.parse(player: .spotify, fields: [], at: t0))
        XCTAssertNil(NowPlayingTrack.parse(player: .spotify, fields: [.number(1)], at: t0))
    }

    // MARK: extrapolation

    func testElapsedMovesWhilePlaying() {
        XCTAssertEqual(track().elapsed(at: t0.addingTimeInterval(10)), 60)
    }

    func testElapsedStaysPutWhilePaused() {
        XCTAssertEqual(track(status: .paused).elapsed(at: t0.addingTimeInterval(10)), 50)
    }

    func testElapsedNeverPassesTheEnd() {
        XCTAssertEqual(track().elapsed(at: t0.addingTimeInterval(1_000)), 200)
        XCTAssertEqual(track().progress(at: t0.addingTimeInterval(1_000)), 1)
    }

    func testUnknownDurationHasNoProgress() {
        XCTAssertEqual(track(duration: 0).progress(at: t0), 0)
        XCTAssertEqual(track(duration: 0).elapsed(at: t0.addingTimeInterval(5)), 55)
    }

    // MARK: selection

    func testPlayingBeatsPaused() {
        let music = track(.appleMusic, status: .paused)
        let spotify = track(.spotify, status: .playing)
        let picked = NowPlayingSelection.pick([music, spotify], lastActive: [.appleMusic: t0.addingTimeInterval(5), .spotify: t0])
        XCTAssertEqual(picked?.player, .spotify)
    }

    func testMostRecentlyActiveWinsBetweenEquals() {
        let music = track(.appleMusic, status: .paused)
        let spotify = track(.spotify, status: .paused)
        let picked = NowPlayingSelection.pick([music, spotify], lastActive: [.spotify: t0.addingTimeInterval(5), .appleMusic: t0])
        XCTAssertEqual(picked?.player, .spotify)
    }

    func testTiesAreStable() {
        let music = track(.appleMusic)
        let spotify = track(.spotify)
        XCTAssertEqual(NowPlayingSelection.pick([music, spotify], lastActive: [:])?.player, .appleMusic)
        XCTAssertEqual(NowPlayingSelection.pick([spotify, music], lastActive: [:])?.player, .appleMusic)
    }

    func testNothingToPick() {
        XCTAssertNil(NowPlayingSelection.pick([], lastActive: [:]))
    }

    // MARK: formatting and scripts

    func testTimeFormatting() {
        XCTAssertEqual(PlaybackTimeFormatter.string(from: 0), "0:00")
        XCTAssertEqual(PlaybackTimeFormatter.string(from: 7.9), "0:07")
        XCTAssertEqual(PlaybackTimeFormatter.string(from: 187), "3:07")
        XCTAssertEqual(PlaybackTimeFormatter.string(from: 3723), "1:02:03")
        XCTAssertEqual(PlaybackTimeFormatter.string(from: -4), "0:00")
        XCTAssertEqual(PlaybackTimeFormatter.string(from: .infinity), "0:00")
    }

    func testSeekScriptUsesADotAndClamps() {
        XCTAssertEqual(
            PlayerScripts.seek(.spotify, to: 12.346),
            "tell application id \"com.spotify.client\" to set player position to 12.35"
        )
        XCTAssertTrue(PlayerScripts.seek(.appleMusic, to: -3).hasSuffix("set player position to 0.00"))
    }

    func testStatusScriptsTargetTheRightApp() {
        for player in MediaPlayer.allCases {
            XCTAssertTrue(PlayerScripts.status(for: player).contains("tell application id \"\(player.bundleIdentifier)\""))
        }
    }
}
