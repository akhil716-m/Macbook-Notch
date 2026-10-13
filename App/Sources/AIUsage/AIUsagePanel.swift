import NotchCore
import SwiftUI

/// The AI Usage tool: a card for each coding tool found on this Mac.
struct AIUsagePanel: View {
    @ObservedObject var usage: AIUsageService

    var body: some View {
        AIUsageContent(claude: usage.claude, codex: usage.codex, now: Date())
            .onAppear { usage.beginViewing() }
            .onDisappear { usage.endViewing() }
    }
}

/// From plain values so it can also be drawn with sample data. Tools
/// without logs collapse into one line at the bottom instead of empty cards.
struct AIUsageContent: View {
    let claude: AIUsageService.ClaudeSummary
    let codex: AIUsageService.CodexSummary
    let now: Date

    var body: some View {
        if !claude.foundLogs && !codex.foundLogs {
            EmptyToolState(
                symbol: "gauge.with.needle",
                title: "No AI coding tools found",
                message: "Claude Code and Codex usage shows here after they run on this Mac."
            )
        } else {
            VStack(alignment: .leading, spacing: NotchStyle.Space.s) {
                HStack(alignment: .top, spacing: NotchStyle.Space.m) {
                    if claude.foundLogs { claudeCard }
                    if codex.foundLogs { codexCard }
                }
                .frame(maxHeight: .infinity)
                Text(footnote)
                    .font(NotchStyle.Font.caption)
                    .foregroundStyle(NotchStyle.Palette.tertiaryText)
            }
        }
    }

    private var footnote: String {
        var parts: [String] = []
        if !claude.foundLogs { parts.append("Claude Code not found") }
        if !codex.foundLogs { parts.append("Codex not found") }
        parts.append("Copilot keeps no usage on this Mac")
        return parts.joined(separator: " · ")
    }

    private var claudeCard: some View {
        UsageCard(title: "Claude Code", symbol: "terminal") {
            if let block = claude.block, block.isActive(at: now) {
                BigNumber(value: TokenFormat.short(block.tokens), unit: "tokens this session")
                UsageNote("Resets at \(block.end.formatted(date: .omitted, time: .shortened))")
            } else {
                BigNumber(value: "Idle", unit: "no session running")
            }
            Spacer(minLength: 0)
            UsageNote("\(TokenFormat.short(claude.lastWeek)) tokens in the last 7 days")
        }
    }

    private var codexCard: some View {
        UsageCard(title: "Codex", symbol: "chevron.left.forwardslash.chevron.right") {
            if let limits = codex.limits, !limits.windows.isEmpty {
                ForEach(Array(limits.windows.enumerated()), id: \.offset) { _, window in
                    LimitMeter(window: window, now: now)
                }
            } else {
                BigNumber(value: TokenFormat.short(codex.lastWeek), unit: "tokens in 7 days")
                UsageNote("Limits appear after your next Codex run.")
            }
            Spacer(minLength: 0)
            if codex.limits != nil {
                UsageNote("\(TokenFormat.short(codex.lastWeek)) tokens in the last 7 days")
            }
        }
    }
}

/// The one large figure on a usage card.
private struct BigNumber: View {
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(NotchStyle.Font.display)
                .tracking(-0.5)
                .foregroundStyle(NotchStyle.Palette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(unit)
                .font(NotchStyle.Font.subtitle)
                .foregroundStyle(NotchStyle.Palette.secondaryText)
        }
    }
}

private struct UsageCard<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: NotchStyle.Space.s) {
            Label(title, systemImage: symbol)
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

private struct UsageNote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(NotchStyle.Font.caption)
            .foregroundStyle(NotchStyle.Palette.tertiaryText)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct LimitMeter: View {
    let window: RateLimitWindow
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: NotchStyle.Space.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.label + " limit")
                    .font(NotchStyle.Font.body)
                    .foregroundStyle(NotchStyle.Palette.secondaryText)
                Spacer()
                Text("\(Int(window.usedPercent.rounded()))% used")
                    .font(NotchStyle.Font.body.weight(.semibold))
                    .foregroundStyle(window.usedPercent >= 90 ? NotchStyle.Palette.overdue : NotchStyle.Palette.primaryText)
            }
            MeterBar(
                fraction: window.usedPercent / 100,
                tint: window.usedPercent >= 90 ? NotchStyle.Palette.overdue : NotchStyle.Palette.accent
            )
            if let resetsAt = window.resetsAt, resetsAt > now {
                Text("Resets \(resetsAt.formatted(.relative(presentation: .named, unitsStyle: .wide)))")
                    .font(NotchStyle.Font.caption)
                    .foregroundStyle(NotchStyle.Palette.tertiaryText)
            }
        }
    }
}
