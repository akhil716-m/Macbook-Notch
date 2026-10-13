import AppKit
import NotchCore
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

/// The dark grey field most tool content sits on. It is set apart from the
/// black panel by a step in tone alone: no outline, no shadow.
struct NotchCardBackground: View {
    var radius: CGFloat = NotchStyle.Card.radius

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(NotchStyle.Palette.rowBackground)
    }
}

extension View {
    /// Pads the content and puts it on a card.
    func notchCard(padding: CGFloat = NotchStyle.Card.padding, radius: CGFloat = NotchStyle.Card.radius) -> some View {
        self.padding(padding).background(NotchCardBackground(radius: radius))
    }
}

/// A row of mutually exclusive options on a dark track; the chosen one is a
/// white pill with dark text. Arrow keys aren't wired up because the notch
/// panel rarely has keyboard focus; each option is a real button instead.
struct SegmentedPicker<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(NotchStyle.spring) { selection = option }
                } label: {
                    Text(title(option))
                        .font(NotchStyle.Font.segment)
                        .foregroundStyle(isSelected ? NotchStyle.Palette.background : NotchStyle.Palette.primaryText)
                        .lineLimit(1)
                        .padding(.horizontal, NotchStyle.Segment.padding)
                        .frame(maxHeight: .infinity)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: NotchStyle.Segment.radius - NotchStyle.Segment.inset, style: .continuous)
                                    .fill(NotchStyle.Palette.fill)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(NotchStyle.Segment.inset)
        .frame(height: NotchStyle.Segment.height)
        .background(
            RoundedRectangle(cornerRadius: NotchStyle.Segment.radius, style: .continuous)
                .fill(NotchStyle.Palette.rowBackground)
        )
    }
}

/// A circular button. `.primary` is white with a dark symbol, for the one
/// main action (play, start); `.secondary` is dark grey.
struct RoundButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    var kind: Kind = .secondary
    var size: CGFloat = NotchStyle.RoundButton.large

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(
                size: size >= NotchStyle.RoundButton.large ? NotchStyle.RoundButton.largeSymbol : NotchStyle.RoundButton.smallSymbol,
                weight: .semibold
            ))
            .foregroundStyle(kind == .primary ? NotchStyle.Palette.background : NotchStyle.Palette.primaryText)
            .frame(width: size, height: size)
            .background(
                Circle().fill(kind == .primary ? NotchStyle.Palette.fill : NotchStyle.Palette.placeholder)
            )
            .contentShape(Circle())
            .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// A round icon button for a symbol with an accessible label.
struct RoundIconButton: View {
    let symbol: String
    let label: String
    var kind: RoundButtonStyle.Kind = .secondary
    var size: CGFloat = NotchStyle.RoundButton.large
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
        }
        .buttonStyle(RoundButtonStyle(kind: kind, size: size))
        .help(label)
        .accessibilityLabel(label)
    }
}

/// The small buttons at the top right of the open panel. `isOn` gives the
/// button a filled circle, for toggles such as Pin.
struct HeaderIconButton: View {
    let symbol: String
    let label: String
    var isOn = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: NotchStyle.Header.symbolSize, weight: .medium))
                .foregroundStyle(isOn ? NotchStyle.Palette.primaryText : NotchStyle.Palette.secondaryText)
                .frame(width: NotchStyle.Header.buttonSize, height: NotchStyle.Header.buttonSize)
                .background(Circle().fill(isOn ? NotchStyle.Palette.selection : Color.clear))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
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

/// Asks for a macOS permission, or explains how to turn it back on.
struct PermissionPrompt: View {
    let symbol: String
    let title: String
    let message: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: NotchStyle.Space.s) {
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
            Button(buttonTitle, action: action)
                .buttonStyle(ChipButtonStyle(isProminent: true))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

enum SystemSettingsLink {
    static func open(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}

extension Color {
    init(_ rgb: ColorComponents?, fallback: Color) {
        if let rgb {
            self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
        } else {
            self = fallback
        }
    }
}
