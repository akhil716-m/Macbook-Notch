import AppKit
import NotchCore
import SwiftUI

/// The Now Playing tool inside the open notch, with its three states:
/// a track, nothing playing, and permission needed.
struct NowPlayingPanel: View {
    @ObservedObject var service: NowPlayingService

    var body: some View {
        if let track = service.track {
            NowPlayingCard(track: track, artwork: service.artwork, service: service)
        } else if let player = service.permissionNeeded {
            AutomationPermissionPrompt(player: player)
        } else {
            NothingPlaying()
        }
    }
}

private struct NowPlayingCard: View {
    let track: NowPlayingTrack
    let artwork: NSImage?
    let service: NowPlayingService

    var body: some View {
        HStack(spacing: NotchStyle.Space.l) {
            ArtworkView(image: artwork, size: NotchStyle.Artwork.openSize, cornerRadius: NotchStyle.Artwork.openRadius)

            VStack(alignment: .leading, spacing: NotchStyle.Space.s) {
                Text(track.title.isEmpty ? "Untitled" : track.title)
                    .font(NotchStyle.Font.title)
                    .foregroundStyle(NotchStyle.Palette.primaryText)
                    .lineLimit(1)
                Text(subtitle)
                    .font(NotchStyle.Font.subtitle)
                    .foregroundStyle(NotchStyle.Palette.secondaryText)
                    .lineLimit(1)

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    PlaybackScrubber(
                        duration: track.duration,
                        elapsed: track.elapsed(at: context.date),
                        onSeek: { service.seek(to: $0) }
                    )
                }

                PlaybackControls(isPlaying: track.status == .playing, service: service)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var subtitle: String {
        let parts = [track.artist, track.album].filter { !$0.isEmpty }
        return parts.isEmpty ? track.player.displayName : parts.joined(separator: " · ")
    }
}

private struct PlaybackControls: View {
    let isPlaying: Bool
    let service: NowPlayingService

    var body: some View {
        HStack(spacing: NotchStyle.Controls.spacing) {
            controlButton("backward.fill", size: NotchStyle.Controls.skipSize, label: "Previous track") {
                service.previousTrack()
            }
            controlButton(isPlaying ? "pause.fill" : "play.fill", size: NotchStyle.Controls.playSize, label: isPlaying ? "Pause" : "Play") {
                service.togglePlayPause()
            }
            controlButton("forward.fill", size: NotchStyle.Controls.skipSize, label: "Next track") {
                service.nextTrack()
            }
        }
    }

    private func controlButton(_ symbol: String, size: CGFloat, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(NotchStyle.Palette.primaryText)
                .frame(width: NotchStyle.Controls.hitSize, height: NotchStyle.Controls.hitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// A thin progress bar you can drag to seek, with elapsed and remaining time.
struct PlaybackScrubber: View {
    let duration: TimeInterval
    let elapsed: TimeInterval
    let onSeek: (TimeInterval) -> Void

    @State private var dragFraction: Double?

    var body: some View {
        VStack(spacing: NotchStyle.Space.xxs) {
            GeometryReader { geometry in
                let fraction = dragFraction ?? (duration > 0 ? min(max(elapsed / duration, 0), 1) : 0)
                ZStack(alignment: .leading) {
                    Capsule().fill(NotchStyle.Palette.track)
                    Capsule()
                        .fill(NotchStyle.Palette.fill)
                        .frame(width: geometry.size.width * fraction)
                }
                .frame(height: dragFraction == nil ? NotchStyle.Scrubber.height : NotchStyle.Scrubber.activeHeight)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dragFraction = Self.fraction(value.location.x, width: geometry.size.width)
                        }
                        .onEnded { value in
                            let target = Self.fraction(value.location.x, width: geometry.size.width) * duration
                            dragFraction = nil
                            onSeek(target)
                        }
                )
            }
            .frame(height: NotchStyle.Scrubber.hitHeight)

            HStack {
                Text(PlaybackTimeFormatter.string(from: shownElapsed))
                Spacer()
                Text(duration > 0 ? "-" + PlaybackTimeFormatter.string(from: duration - shownElapsed) : "")
            }
            .font(NotchStyle.Font.caption)
            .foregroundStyle(NotchStyle.Palette.secondaryText)
        }
        .disabled(duration <= 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playback position")
        .accessibilityValue("\(PlaybackTimeFormatter.string(from: shownElapsed)) of \(PlaybackTimeFormatter.string(from: duration))")
    }

    private var shownElapsed: TimeInterval {
        if let dragFraction { return dragFraction * duration }
        return elapsed
    }

    private static func fraction(_ x: CGFloat, width: CGFloat) -> Double {
        guard width > 0 else { return 0 }
        return Double(min(max(x / width, 0), 1))
    }
}

private struct NothingPlaying: View {
    var body: some View {
        VStack(spacing: NotchStyle.Space.xs) {
            Image(systemName: "music.note")
                .font(.system(size: NotchStyle.Controls.playSize))
                .foregroundStyle(NotchStyle.Palette.secondaryText)
            Text("No music right now")
                .font(NotchStyle.Font.emptyTitle)
                .foregroundStyle(NotchStyle.Palette.primaryText)
            Text("Start a song in Music or Spotify and it will appear here.")
                .font(NotchStyle.Font.emptyBody)
                .foregroundStyle(NotchStyle.Palette.secondaryText)
                .multilineTextAlignment(.center)
        }
    }
}

private struct AutomationPermissionPrompt: View {
    let player: MediaPlayer

    var body: some View {
        VStack(spacing: NotchStyle.Space.s) {
            Text("MacbookNotch can't see \(player.displayName) yet")
                .font(NotchStyle.Font.emptyTitle)
                .foregroundStyle(NotchStyle.Palette.primaryText)
            Text("Allow it under Privacy & Security › Automation in System Settings.")
                .font(NotchStyle.Font.emptyBody)
                .foregroundStyle(NotchStyle.Palette.secondaryText)
                .multilineTextAlignment(.center)
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                    NSWorkspace.shared.open(url)
                }
            }
            .controlSize(.small)
        }
    }
}
