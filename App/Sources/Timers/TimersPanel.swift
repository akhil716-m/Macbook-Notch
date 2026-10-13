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
                    VStack(spacing: NotchStyle.Space.xxs) {
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
                switch state {
                case .running:
                    IconButton(symbol: "pause.fill", label: "Pause") { timers.pause(timer.id) }
                case .paused:
                    IconButton(symbol: "play.fill", label: "Resume") { timers.resume(timer.id) }
                case .finished:
                    IconButton(symbol: "arrow.counterclockwise", label: "Start again") { timers.restart(timer.id) }
                }
                IconButton(symbol: "xmark", label: "Remove timer") { timers.remove(timer.id) }
            }
            .padding(.horizontal, NotchStyle.Space.m)
            .padding(.vertical, NotchStyle.Space.xs)
            .background(
                RoundedRectangle(cornerRadius: NotchStyle.Clipboard.rowRadius, style: .continuous)
                    .fill(NotchStyle.Palette.rowBackground)
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(timer.label), \(state == .finished ? "done" : CountdownFormatter.string(from: timer.remaining(at: context.date)) + " left")")
        }
    }
}

/// The closed notch while a timer runs: timer icon left, time left right.
struct CompactTimerActivity: View {
    @ObservedObject var timers: TimerService
    let timerID: UUID
    let finished: Bool
    let notchWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: finished ? "bell.fill" : "timer")
                .font(NotchStyle.Font.compactIcon)
                .foregroundStyle(NotchStyle.Palette.accent)
            Spacer(minLength: notchWidth)
            if finished {
                Text("Done")
                    .font(NotchStyle.Font.compactValue)
                    .foregroundStyle(NotchStyle.Palette.accent)
            } else if let timer = timers.timer(timerID) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(CountdownFormatter.string(from: timer.remaining(at: context.date)))
                        .font(NotchStyle.Font.compactValue)
                        .foregroundStyle(NotchStyle.Palette.primaryText)
                }
            }
        }
        .padding(.horizontal, NotchStyle.Space.m)
        .accessibilityElement(children: .combine)
    }
}
