import NotchCore
import SwiftUI

/// The Timers tool: quick-start lengths on top, running timers below.
struct TimersPanel: View {
    @ObservedObject var timers: TimerService

    var body: some View {
        VStack(alignment: .leading, spacing: NotchStyle.Space.s) {
            HStack(spacing: NotchStyle.Space.xs) {
                ForEach(TimerPresets.minutes, id: \.self) { minutes in
                    Button(minutes == 25 ? "25 Focus" : "\(minutes)m") {
                        timers.start(minutes: minutes)
                    }
                    .buttonStyle(ChipButtonStyle())
                    .accessibilityLabel("Start a \(minutes) minute timer")
                }
                Spacer(minLength: 0)
                if timers.hasFinished {
                    Button("Clear done") { timers.clearFinished() }
                        .buttonStyle(ChipButtonStyle())
                }
            }

            if timers.timers.isEmpty {
                EmptyToolState(symbol: "timer", title: "No timers running", message: "Pick a length above to start one.")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: NotchStyle.Space.s) {
                        ForEach(timers.timers) { timer in
                            TimerRow(timer: timer, timers: timers)
                        }
                    }
                }
            }
        }
    }
}

private struct TimerRow: View {
    let timer: CountdownTimer
    let timers: TimerService

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let state = timer.state(at: context.date)
            HStack(spacing: NotchStyle.Space.m) {
                VStack(alignment: .leading, spacing: NotchStyle.Space.xxs) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(state == .finished ? "Done" : CountdownFormatter.string(from: timer.remaining(at: context.date)))
                            .font(NotchStyle.Font.countdown)
                            .foregroundStyle(state == .finished ? NotchStyle.Palette.accent : NotchStyle.Palette.primaryText)
                        Text(timer.label)
                            .font(NotchStyle.Font.caption)
                            .foregroundStyle(NotchStyle.Palette.secondaryText)
                            .lineLimit(1)
                    }
                    MeterBar(
                        fraction: timer.progress(at: context.date),
                        tint: state == .paused ? NotchStyle.Palette.secondaryText : NotchStyle.Palette.accent
                    )
                }
                let small = NotchStyle.RoundButton.small
                switch state {
                case .running:
                    RoundIconButton(symbol: "pause.fill", label: "Pause", kind: .primary, size: small) { timers.pause(timer.id) }
                case .paused:
                    RoundIconButton(symbol: "play.fill", label: "Resume", kind: .primary, size: small) { timers.resume(timer.id) }
                case .finished:
                    RoundIconButton(symbol: "arrow.counterclockwise", label: "Start again", kind: .primary, size: small) { timers.restart(timer.id) }
                }
                RoundIconButton(symbol: "xmark", label: "Remove timer", size: small) { timers.remove(timer.id) }
            }
            .notchCard(padding: NotchStyle.Space.m)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(timer.label), \(state == .finished ? "done" : CountdownFormatter.string(from: timer.remaining(at: context.date)) + " left")")
        }
    }
}

/// The closed notch while a timer runs: a progress ring on the left, the
/// time left on the right.
struct CompactTimerActivity: View {
    @ObservedObject var timers: TimerService
    let timerID: UUID
    let finished: Bool
    let notchWidth: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let timer = timers.timer(timerID)
            HStack(spacing: 0) {
                ProgressRing(
                    fraction: finished ? 1 : (timer?.progress(at: context.date) ?? 0),
                    symbol: finished ? "bell.fill" : "timer"
                )
                Spacer(minLength: notchWidth)
                Group {
                    if finished {
                        Text("Done").foregroundStyle(NotchStyle.Palette.accent)
                    } else if let timer {
                        Text(CountdownFormatter.string(from: timer.remaining(at: context.date)))
                            .foregroundStyle(NotchStyle.Palette.primaryText)
                    }
                }
                .font(NotchStyle.Font.compactValue)
            }
        }
        .padding(.horizontal, NotchStyle.Space.l)
        .accessibilityElement(children: .combine)
    }
}

/// A small ring that fills clockwise, with a symbol in the middle.
struct ProgressRing: View {
    let fraction: Double
    let symbol: String

    var body: some View {
        ZStack {
            Circle().stroke(NotchStyle.Palette.track, lineWidth: NotchStyle.Compact.ringWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(fraction, 0), 1)))
                .stroke(NotchStyle.Palette.accent, style: StrokeStyle(lineWidth: NotchStyle.Compact.ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: symbol)
                .font(.system(size: NotchStyle.Compact.ringSymbol, weight: .semibold))
                .foregroundStyle(NotchStyle.Palette.primaryText)
        }
        .frame(width: NotchStyle.Compact.ring, height: NotchStyle.Compact.ring)
    }
}
