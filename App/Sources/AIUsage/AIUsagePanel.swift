import NotchCore
import SwiftUI

/// The AI Usage tool: one card per coding tool.
struct AIUsagePanel: View {
    @ObservedObject var usage: AIUsageService

    var body: some View {
        HStack(spacing: NotchStyle.Space.m) {
            claudeCard
            codexCard
            copilotCard
        }
        .onAppear { usage.beginViewing() }
        .onDisappear { usage.endViewing() }
    }

    private var claudeCard: some View {
        UsageCard(title: "Claude Code") {
            if !usage.claude.foundLogs {
                UsageNote("No Claude Code logs on this Mac.")
            } else {
                if let block = usage.claude.block {
                    UsageLine(label: "This session", value: TokenFormat.short(block.tokens) + " tokens")
                    UsageNote("Resets \(block.end.formatted(date: .omitted, time: .shortened))")
                } else {
                    UsageLine(label: "This session", value: "Idle")
                }
                UsageLine(label: "Last 7 days", value: TokenFormat.short(usage.claude.lastWeek) + " tokens")
            }
        }
    }

    private var codexCard: some View {
        UsageCard(title: "Codex") {
            if !usage.codex.foundLogs {
                UsageNote("No Codex logs on this Mac.")
            } else {
                if let limits = usage.codex.limits {
                    ForEach(Array(limits.windows.enumerated()), id: \.offset) { _, window in
                        LimitMeter(window: window)
                    }
                } else {
                    UsageNote("Limits appear after your next Codex run.")
                }
                UsageLine(label: "Last 7 days", value: TokenFormat.short(usage.codex.lastWeek) + " tokens")
            }
        }
    }

    private var copilotCard: some View {
        UsageCard(title: "Copilot") {
            UsageNote("Copilot doesn't keep usage on your Mac, so there's nothing to read locally yet.")
        }
    }
}

private struct UsageCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: NotchStyle.Space.xs) {
            Text(title)
                .font(NotchStyle.Font.title)
                .foregroundStyle(NotchStyle.Palette.primaryText)
            content()
            Spacer(minLength: 0)
        }
        .padding(NotchStyle.Card.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(NotchCardBackground())
        .accessibilityElement(children: .combine)
    }
}

private struct UsageLine: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(NotchStyle.Font.statValue)
                .foregroundStyle(NotchStyle.Palette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(NotchStyle.Font.caption)
                .foregroundStyle(NotchStyle.Palette.secondaryText)
        }
    }
}

private struct UsageNote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(NotchStyle.Font.caption)
            .foregroundStyle(NotchStyle.Palette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct LimitMeter: View {
    let window: RateLimitWindow

    var body: some View {
        VStack(alignment: .leading, spacing: NotchStyle.Space.xxs) {
            HStack {
                Text(window.label)
                Spacer()
                Text("\(Int(window.usedPercent.rounded()))%")
                    .foregroundStyle(window.usedPercent >= 90 ? NotchStyle.Palette.overdue : NotchStyle.Palette.primaryText)
            }
            .font(NotchStyle.Font.caption)
            .foregroundStyle(NotchStyle.Palette.secondaryText)
            MeterBar(
                fraction: window.usedPercent / 100,
                tint: window.usedPercent >= 90 ? NotchStyle.Palette.overdue : NotchStyle.Palette.accent
            )
            if let resetsAt = window.resetsAt, resetsAt > Date() {
                Text("Resets \(resetsAt.formatted(.relative(presentation: .named)))")
                    .font(NotchStyle.Font.caption)
                    .foregroundStyle(NotchStyle.Palette.secondaryText)
            }
        }
    }
}
