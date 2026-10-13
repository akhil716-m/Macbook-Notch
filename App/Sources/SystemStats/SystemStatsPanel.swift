import NotchCore
import SwiftUI

/// The System tool: CPU, memory and network as three large readouts.
/// Sampling only runs while this view is on screen.
struct SystemStatsPanel: View {
    @ObservedObject var stats: SystemStatsService

    var body: some View {
        SystemReadouts(
            cpu: stats.cpu,
            cpuHistory: stats.cpuHistory,
            memory: stats.memory,
            network: stats.network,
            disk: stats.disk,
            battery: stats.battery
        )
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
    var disk: DiskUsage?
    var battery: BatteryStatus?

    var body: some View {
        VStack(spacing: NotchStyle.Space.l) {
            readouts
            if disk != nil || battery != nil {
                HStack(spacing: NotchStyle.Space.xl) {
                    if let disk {
                        MiniMeter(
                            symbol: "internaldrive",
                            title: "Disk",
                            fraction: disk.usedFraction,
                            value: ByteFormat.string(Double(disk.available)) + " free",
                            tint: disk.usedFraction > 0.9 ? NotchStyle.Palette.overdue : NotchStyle.Palette.fill
                        )
                    }
                    if let battery {
                        MiniMeter(
                            symbol: Self.batterySymbol(battery),
                            title: "Battery",
                            fraction: battery.level,
                            value: "\(Int((battery.level * 100).rounded()))%",
                            tint: battery.level < 0.2 && !battery.isPluggedIn ? NotchStyle.Palette.overdue : NotchStyle.Palette.gain,
                            detail: battery.summary
                        )
                    }
                }
            }
        }
        .padding(.horizontal, NotchStyle.Space.l)
        .padding(.vertical, NotchStyle.Space.l)
        .background(NotchCardBackground(radius: NotchStyle.Card.radius + 4))
        .frame(maxHeight: .infinity)
    }

    private static func batterySymbol(_ battery: BatteryStatus) -> String {
        if battery.isCharging { return "battery.100percent.bolt" }
        switch battery.level {
        case ..<0.13: return "battery.0percent"
        case ..<0.38: return "battery.25percent"
        case ..<0.63: return "battery.50percent"
        case ..<0.88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    private var readouts: some View {
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
    }
}

/// A label, a thin bar and a value on one line, for the secondary stats.
private struct MiniMeter: View {
    let symbol: String
    let title: String
    let fraction: Double
    let value: String
    var tint: Color = NotchStyle.Palette.fill
    var detail: String?

    var body: some View {
        HStack(spacing: NotchStyle.Space.s) {
            Label(title, systemImage: symbol)
                .font(NotchStyle.Font.body)
                .foregroundStyle(NotchStyle.Palette.secondaryText)
                .lineLimit(1)
                .fixedSize()
            MeterBar(fraction: fraction, tint: tint)
            Text(value)
                .font(NotchStyle.Font.body.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(NotchStyle.Palette.primaryText)
                .lineLimit(1)
                .fixedSize()
        }
        .frame(maxWidth: .infinity)
        .help(detail ?? "")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue([value, detail].compactMap { $0 }.joined(separator: ", "))
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
