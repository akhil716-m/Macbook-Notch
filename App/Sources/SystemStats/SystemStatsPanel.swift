import NotchCore
import SwiftUI

/// The System tool: CPU, memory and network as three large readouts.
/// Sampling only runs while this view is on screen.
struct SystemStatsPanel: View {
    @ObservedObject var stats: SystemStatsService

    var body: some View {
        SystemReadouts(cpu: stats.cpu, cpuHistory: stats.cpuHistory, memory: stats.memory, network: stats.network)
            .onAppear { stats.beginViewing() }
            .onDisappear { stats.endViewing() }
    }
}

/// The three readouts, from plain values so they can also be drawn with
/// sample data. Each is a name, a large number with its unit, and one line
/// of context underneath.
struct SystemReadouts: View {
    let cpu: Double?
    let cpuHistory: [Double]
    let memory: MemoryUsage?
    let network: NetworkRate

    var body: some View {
        HStack(alignment: .top, spacing: NotchStyle.Space.xl) {
            Readout(symbol: "cpu", title: "CPU", value: cpu.map { "\(Int(($0 * 100).rounded()))%" } ?? "–") {
                Sparkline(values: cpuHistory)
                    .stroke(NotchStyle.Palette.accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                    .frame(height: NotchStyle.Readout.graphicHeight)
            }
            Readout(
                symbol: "memorychip",
                title: "Memory",
                value: memory.map { ByteFormat.string(Double($0.used)) } ?? "–"
            ) {
                VStack(alignment: .leading, spacing: NotchStyle.Space.xs) {
                    MeterBar(fraction: memory?.fraction ?? 0)
                    Text(memory.map { "of " + ByteFormat.string(Double($0.total)) } ?? " ")
                        .font(NotchStyle.Font.caption)
                        .foregroundStyle(NotchStyle.Palette.tertiaryText)
                }
                .frame(height: NotchStyle.Readout.graphicHeight, alignment: .bottom)
            }
            Readout(symbol: "arrow.down", title: "Download", value: ByteFormat.rate(network.receivedPerSecond)) {
                Text("↑ " + ByteFormat.rate(network.sentPerSecond) + " up")
                    .font(NotchStyle.Font.caption)
                    .foregroundStyle(NotchStyle.Palette.tertiaryText)
                    .frame(height: NotchStyle.Readout.graphicHeight, alignment: .bottomLeading)
            }
        }
        .padding(.horizontal, NotchStyle.Space.l)
        .padding(.vertical, NotchStyle.Space.l)
        .background(NotchCardBackground(radius: NotchStyle.Card.radius + 4))
        .frame(maxHeight: .infinity)
    }
}

private struct Readout<Graphic: View>: View {
    let symbol: String
    let title: String
    let value: String
    @ViewBuilder let graphic: () -> Graphic

    var body: some View {
        let (number, unit) = Self.split(value)
        VStack(alignment: .leading, spacing: NotchStyle.Space.s) {
            Label(title, systemImage: symbol)
                .font(NotchStyle.Font.body)
                .foregroundStyle(NotchStyle.Palette.secondaryText)
            HStack(alignment: .firstTextBaseline, spacing: NotchStyle.Space.xxs) {
                Text(number)
                    .font(NotchStyle.Font.display)
                    .tracking(-0.5)
                    .foregroundStyle(NotchStyle.Palette.primaryText)
                Text(unit)
                    .font(NotchStyle.Font.title)
                    .foregroundStyle(NotchStyle.Palette.secondaryText)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            graphic()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    /// "12.1 GB" -> ("12.1", "GB"); "25%" -> ("25", "%").
    static func split(_ value: String) -> (String, String) {
        if value.hasSuffix("%") { return (String(value.dropLast()), "%") }
        guard let space = value.lastIndex(of: " ") else { return (value, "") }
        return (String(value[..<space]), String(value[value.index(after: space)...]))
    }
}
