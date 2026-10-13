import AppKit
import SwiftUI

/// The closed notch while music plays: artwork in the left wing, a small
/// equaliser in the right wing, the hardware notch untouched in between.
struct CompactMusicActivity: View {
    let artwork: NSImage?
    let isPlaying: Bool
    let notchWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            ArtworkView(
                image: artwork,
                size: NotchStyle.Artwork.compactSize,
                cornerRadius: NotchStyle.Artwork.compactRadius
            )
            Spacer(minLength: notchWidth)
            EqualizerBars(isAnimating: isPlaying)
        }
        .padding(.horizontal, NotchStyle.Space.m)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isPlaying ? "Music playing" : "Music paused")
    }
}

/// Four bars that bounce while music plays. Ticks a few times a second
/// rather than every frame, to keep idle CPU near zero.
struct EqualizerBars: View {
    let isAnimating: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: NotchStyle.Equalizer.tick)) { context in
            let step = Int(context.date.timeIntervalSinceReferenceDate / NotchStyle.Equalizer.tick)
            HStack(alignment: .center, spacing: NotchStyle.Equalizer.spacing) {
                ForEach(0..<NotchStyle.Equalizer.barCount, id: \.self) { index in
                    Capsule()
                        .fill(NotchStyle.Palette.fill)
                        .frame(
                            width: NotchStyle.Equalizer.barWidth,
                            height: isAnimating ? Self.height(step: step, bar: index) : NotchStyle.Equalizer.minHeight
                        )
                }
            }
            .frame(height: NotchStyle.Equalizer.maxHeight)
            .animation(.easeInOut(duration: NotchStyle.Equalizer.tick), value: step)
        }
    }

    /// Cheap deterministic pseudo-random height per bar and step.
    private static func height(step: Int, bar: Int) -> CGFloat {
        let mixed = (step &* 2_654_435_761 &+ bar &* 40_503) & 0xFFFF
        let fraction = CGFloat(mixed % 100) / 100
        let range = NotchStyle.Equalizer.maxHeight - NotchStyle.Equalizer.minHeight
        return NotchStyle.Equalizer.minHeight + range * fraction
    }
}

struct ArtworkView: View {
    let image: NSImage?
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                NotchStyle.Palette.placeholder
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(NotchStyle.Palette.secondaryText)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityLabel("Album artwork")
    }
}
