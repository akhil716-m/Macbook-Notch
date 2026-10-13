import NotchCore
import SwiftUI

/// The System tool: CPU, memory and network as rows in one card. Sampling
/// only runs while this view is on screen.
struct SystemStatsPanel: View {
    @ObservedObject var stats: SystemStatsService

    var body: some View {
        VStack(spacing: 0) {
            StatRow(symbol: "cpu", title: "CPU", value: stats.cpu.map { Self.percent($0) } ?? "–") {
                MeterBar(fraction: stats.cpu ?? 0)
            }
            Divider().overlay(NotchStyle.Palette.border)
            StatRow(
                symbol: "memorychip",
                title: "Memory",
                value: stats.memory.map { ByteFormat.string(Double($0.used)) } ?? "–"
            ) {
                MeterBar(fraction: stats.memory?.fraction ?? 0)
            }
            Divider().overlay(NotchStyle.Palette.border)
            StatRow(
                symbol: "network",
                title: "Network",
                value: "",
                spokenValue: "down \(ByteFormat.rate(stats.network.receivedPerSecond)), up \(ByteFormat.rate(stats.network.sentPerSecond))"
            ) {
                HStack(spacing: NotchStyle.Space.m) {
                    Text("↓ " + ByteFormat.rate(stats.network.receivedPerSecond))
                    Text("↑ " + ByteFormat.rate(stats.network.sentPerSecond))
                    Spacer(minLength: 0)
                }
                .font(NotchStyle.Font.caption.weight(.semibold))
                .foregroundStyle(NotchStyle.Palette.primaryText)
            }
            Divider().overlay(NotchStyle.Palette.border)
            StatRow(symbol: "waveform.path.ecg", title: "Recent CPU", value: "", spokenValue: "graph of recent CPU use") {
                Sparkline(values: stats.cpuHistory)
                    .stroke(NotchStyle.Palette.secondaryText, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                    .frame(height: NotchStyle.Space.l)
            }
        }
        .notchCard(padding: NotchStyle.Space.m)
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear { stats.beginViewing() }
        .onDisappear { stats.endViewing() }
    }

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

/// Icon, name, a graphic that fills the middle, and a value on the right.
struct StatRow<Graphic: View>: View {
    let symbol: String
    let title: String
    let value: String
    /// What VoiceOver reads when the value is shown only as a graphic.
    var spokenValue: String?
    @ViewBuilder let graphic: () -> Graphic

    var body: some View {
        HStack(spacing: NotchStyle.Space.m) {
            Image(systemName: symbol)
                .font(.system(size: NotchStyle.Row.iconSize))
                .foregroundStyle(NotchStyle.Palette.secondaryText)
                .frame(width: NotchStyle.StatRow.iconWidth)
            Text(title)
                .font(NotchStyle.Font.rowTitle)
                .foregroundStyle(NotchStyle.Palette.secondaryText)
                .frame(width: NotchStyle.StatRow.labelWidth, alignment: .leading)
            graphic()
                .frame(maxWidth: .infinity)
            if !value.isEmpty {
                Text(value)
                    .font(NotchStyle.Font.caption.weight(.semibold))
                    .foregroundStyle(NotchStyle.Palette.primaryText)
                    .lineLimit(1)
                    .frame(width: NotchStyle.StatRow.valueWidth, alignment: .trailing)
            }
        }
        .padding(.vertical, NotchStyle.Space.s)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(spokenValue ?? value)
    }
}
