import NotchCore
import SwiftUI

/// The System tool: CPU, memory and network at a glance. Sampling only
/// runs while this view is on screen.
struct SystemStatsPanel: View {
    @ObservedObject var stats: SystemStatsService

    var body: some View {
        HStack(spacing: NotchStyle.Space.m) {
            StatCard(title: "CPU", value: stats.cpu.map { Self.percent($0) } ?? "–", detail: "all cores") {
                Sparkline(values: stats.cpuHistory)
                    .stroke(NotchStyle.Palette.accent, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            }
            StatCard(
                title: "Memory",
                value: stats.memory.map { ByteFormat.string(Double($0.used)) } ?? "–",
                detail: stats.memory.map { "of " + ByteFormat.string(Double($0.total)) } ?? ""
            ) {
                VStack {
                    Spacer()
                    MeterBar(fraction: stats.memory?.fraction ?? 0, tint: NotchStyle.Palette.accent)
                }
            }
            StatCard(
                title: "Network",
                value: "↓ " + ByteFormat.rate(stats.network.receivedPerSecond),
                detail: "↑ " + ByteFormat.rate(stats.network.sentPerSecond)
            ) {
                EmptyView()
            }
        }
        .onAppear { stats.beginViewing() }
        .onDisappear { stats.endViewing() }
    }

    private static func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

private struct StatCard<Graphic: View>: View {
    let title: String
    let value: String
    let detail: String
    @ViewBuilder let graphic: () -> Graphic

    var body: some View {
        VStack(alignment: .leading, spacing: NotchStyle.Space.xxs) {
            Text(title.uppercased())
                .font(NotchStyle.Font.caption)
                .foregroundStyle(NotchStyle.Palette.secondaryText)
            Text(value)
                .font(NotchStyle.Font.statValue)
                .foregroundStyle(NotchStyle.Palette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(NotchStyle.Font.caption)
                .foregroundStyle(NotchStyle.Palette.secondaryText)
                .lineLimit(1)
            graphic()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(NotchStyle.Space.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: NotchStyle.Clipboard.rowRadius, style: .continuous)
                .fill(NotchStyle.Palette.rowBackground)
        )
        .accessibilityElement(children: .combine)
    }
}
