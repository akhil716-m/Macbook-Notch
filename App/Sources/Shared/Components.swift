import SwiftUI

/// A small capsule button for quick choices (timer lengths, durations).
struct ChipButtonStyle: ButtonStyle {
    var isProminent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NotchStyle.Font.chip)
            .foregroundStyle(isProminent ? NotchStyle.Palette.background : NotchStyle.Palette.primaryText)
            .padding(.horizontal, NotchStyle.Chip.horizontalPadding)
            .frame(height: NotchStyle.Chip.height)
            .background(
                Capsule().fill(
                    isProminent
                        ? NotchStyle.Palette.fill.opacity(configuration.isPressed ? 0.8 : 1)
                        : (configuration.isPressed ? NotchStyle.Palette.selection : NotchStyle.Palette.rowBackground)
                )
            )
            .contentShape(Capsule())
    }
}

/// A plain icon button used inside rows.
struct IconButton: View {
    let symbol: String
    let label: String
    var size: CGFloat = NotchStyle.Row.iconSize
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(NotchStyle.Palette.primaryText)
                .frame(width: NotchStyle.Row.iconHit, height: NotchStyle.Row.iconHit)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

/// A line through recent values, 0...1, oldest on the left.
struct Sparkline: Shape {
    var values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }
        let step = rect.width / CGFloat(values.count - 1)
        for (index, value) in values.enumerated() {
            let clamped = CGFloat(min(max(value, 0), 1))
            let point = CGPoint(x: rect.minX + CGFloat(index) * step, y: rect.maxY - clamped * rect.height)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

/// A thin horizontal meter.
struct MeterBar: View {
    let fraction: Double
    var tint: Color = NotchStyle.Palette.fill

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(NotchStyle.Palette.track)
                Capsule()
                    .fill(tint)
                    .frame(width: geometry.size.width * CGFloat(min(max(fraction, 0), 1)))
            }
        }
        .frame(height: NotchStyle.Scrubber.height)
    }
}

/// Centred icon + title + one line, for a tool with nothing in it yet.
struct EmptyToolState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: NotchStyle.Space.xs) {
            Image(systemName: symbol)
                .font(.system(size: NotchStyle.Controls.playSize))
                .foregroundStyle(NotchStyle.Palette.secondaryText)
            Text(title)
                .font(NotchStyle.Font.emptyTitle)
                .foregroundStyle(NotchStyle.Palette.primaryText)
            Text(message)
                .font(NotchStyle.Font.emptyBody)
                .foregroundStyle(NotchStyle.Palette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
