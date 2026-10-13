import NotchCore
import SwiftUI

/// The three ways of timing things.
enum TimerMode: String, CaseIterable, Identifiable {
    case timer
    case stopwatch
    case pomodoro

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timer: return "Timer"
        case .stopwatch: return "Stopwatch"
        case .pomodoro: return "Pomodoro"
        }
    }
}

/// The Timers tool: countdowns, a stopwatch, and focus sessions.
struct TimersPanel: View {
    @ObservedObject var timers: TimerService
    @AppStorage("timers.mode") private var modeRaw = TimerMode.timer.rawValue

    var body: some View {
        let mode = Binding(
            get: { TimerMode(rawValue: modeRaw) ?? .timer },
            set: { modeRaw = $0.rawValue }
        )
        VStack(spacing: NotchStyle.Space.m) {
            SegmentedPicker(options: TimerMode.allCases, selection: mode, title: \.title)
            switch mode.wrappedValue {
            case .timer:
                CountdownList(timers: timers)
            case .stopwatch:
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !timers.stopwatch.isRunning)) { context in
                    StopwatchContent(
                        stopwatch: timers.stopwatch,
                        now: context.date,
                        onStart: { timers.startStopwatch() },
                        onPause: { timers.pauseStopwatch() },
                        onLap: { timers.lapStopwatch() },
                        onReset: { timers.resetStopwatch() }
                    )
                }
            case .pomodoro:
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    PomodoroContent(
                        pomodoro: timers.pomodoro,
                        now: context.date,
                        onStart: { timers.startPomodoro() },
                        onPause: { timers.pausePomodoro() },
                        onSkip: { timers.skipPomodoro() },
                        onReset: { timers.resetPomodoro() },
                        onLengths: { timers.setPomodoroLengths($0) }
                    )
                }
            }
        }
    }
}

/// Quick-start lengths on top, running timers below.
private struct CountdownList: View {
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
                Text("Pick a length to start a timer.")
                    .font(NotchStyle.Font.body)
                    .foregroundStyle(NotchStyle.Palette.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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

/// A large running time with play/pause and lap/reset; the latest laps on
/// the right. From plain values so it can also be drawn with sample data.
struct StopwatchContent: View {
    let stopwatch: Stopwatch
    let now: Date
    let onStart: () -> Void
    let onPause: () -> Void
    let onLap: () -> Void
    let onReset: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: NotchStyle.Space.xl) {
            VStack(spacing: NotchStyle.Space.m) {
                Text(StopwatchFormatter.string(from: stopwatch.elapsed(at: now)))
                    .font(NotchStyle.Font.stopwatch)
                    .tracking(-1)
                    .foregroundStyle(NotchStyle.Palette.primaryText)
                    .accessibilityLabel("Elapsed time")
                HStack(spacing: NotchStyle.Space.m) {
                    if stopwatch.isRunning {
                        RoundIconButton(symbol: "pause.fill", label: "Pause", kind: .primary, action: onPause)
                        RoundIconButton(symbol: "flag.fill", label: "Lap", action: onLap)
                    } else {
                        RoundIconButton(symbol: "play.fill", label: stopwatch.hasTime ? "Resume" : "Start", kind: .primary, action: onStart)
                        RoundIconButton(symbol: "arrow.counterclockwise", label: "Reset", action: onReset)
                            .disabled(!stopwatch.hasTime)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            if !stopwatch.laps.isEmpty {
                VStack(alignment: .leading, spacing: NotchStyle.Space.xs) {
                    let lengths = stopwatch.lapLengths
                    ForEach(Array(lengths.prefix(NotchStyle.Stopwatch.visibleLaps).enumerated()), id: \.offset) { index, length in
                        HStack {
                            Text("Lap \(lengths.count - index)")
                                .foregroundStyle(NotchStyle.Palette.secondaryText)
                            Spacer()
                            Text(StopwatchFormatter.string(from: length))
                                .foregroundStyle(NotchStyle.Palette.primaryText)
                        }
                        .font(NotchStyle.Font.body.monospacedDigit())
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: NotchStyle.Stopwatch.lapColumn)
                .notchCard()
            }
        }
        .frame(maxHeight: .infinity)
    }
}

/// A large ring with the time left, the phase and session dots beside it,
/// and the controls. From plain values so it can also be drawn with sample data.
struct PomodoroContent: View {
    let pomodoro: Pomodoro
    let now: Date
    let onStart: () -> Void
    let onPause: () -> Void
    let onSkip: () -> Void
    let onReset: () -> Void
    let onLengths: (Pomodoro.Lengths) -> Void

    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        let today = pomodoro.sessionsToday(at: now, calendar: .current)
        HStack(alignment: .center, spacing: NotchStyle.Space.xl) {
            ZStack {
                Circle().stroke(NotchStyle.Palette.track, lineWidth: NotchStyle.Pomodoro.ringWidth)
                Circle()
                    .trim(from: 0, to: CGFloat(pomodoro.progress(at: now)))
                    .stroke(
                        pomodoro.phase.isBreak ? NotchStyle.Palette.gain : NotchStyle.Palette.accent,
                        style: StrokeStyle(lineWidth: NotchStyle.Pomodoro.ringWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Text(CountdownFormatter.string(from: pomodoro.remaining(at: now)))
                    .font(NotchStyle.Font.display)
                    .tracking(-0.5)
                    .foregroundStyle(NotchStyle.Palette.primaryText)
            }
            .frame(width: NotchStyle.Pomodoro.ring, height: NotchStyle.Pomodoro.ring)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(pomodoro.phase.title), \(CountdownFormatter.string(from: pomodoro.remaining(at: now))) left")

            VStack(alignment: .leading, spacing: NotchStyle.Space.xs) {
                Label(pomodoro.phase.title, systemImage: pomodoro.phase.isBreak ? "cup.and.saucer.fill" : "brain.head.profile")
                    .font(NotchStyle.Font.header)
                    .foregroundStyle(NotchStyle.Palette.primaryText)
                Text("Session \(pomodoro.sessionNumber) of \(pomodoro.sessionsPerSet)")
                    .font(NotchStyle.Font.subtitle)
                    .foregroundStyle(NotchStyle.Palette.secondaryText)
                HStack(spacing: NotchStyle.Space.xs) {
                    ForEach(0..<pomodoro.sessionsPerSet, id: \.self) { index in
                        Circle()
                            .fill(index < pomodoro.completedInSet ? NotchStyle.Palette.accent : NotchStyle.Palette.track)
                            .frame(width: NotchStyle.Pomodoro.dot, height: NotchStyle.Pomodoro.dot)
                    }
                }
                .padding(.vertical, NotchStyle.Space.xxs)
                .accessibilityHidden(true)
                Text(today == 0 ? "No sessions yet today" : (today == 1 ? "1 session today" : "\(today) sessions today"))
                    .font(NotchStyle.Font.caption)
                    .foregroundStyle(NotchStyle.Palette.tertiaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: NotchStyle.Space.m) {
                HStack(spacing: NotchStyle.Space.s) {
                    if pomodoro.state == .running {
                        RoundIconButton(symbol: "pause.fill", label: "Pause", kind: .primary, action: onPause)
                    } else {
                        RoundIconButton(symbol: "play.fill", label: pomodoro.state == .paused ? "Resume" : "Start \(pomodoro.phase.title.lowercased())", kind: .primary, action: onStart)
                    }
                    RoundIconButton(symbol: "forward.fill", label: "Skip to the next phase", action: onSkip)
                    RoundIconButton(symbol: "arrow.counterclockwise", label: "Start the set again", action: onReset)
                }
                Group {
                    if isSnapshot {
                        Text(pomodoro.lengths.title)
                            .font(NotchStyle.Font.chip)
                            .foregroundStyle(NotchStyle.Palette.primaryText)
                    } else {
                        Menu {
                            ForEach(Pomodoro.Lengths.options) { option in
                                Button(option.title) { onLengths(option) }
                            }
                        } label: {
                            Text(pomodoro.lengths.title)
                                .font(NotchStyle.Font.chip)
                                .foregroundStyle(NotchStyle.Palette.primaryText)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                    }
                }
                .padding(.horizontal, NotchStyle.Chip.horizontalPadding)
                .frame(height: NotchStyle.Chip.height)
                .background(Capsule().fill(NotchStyle.Palette.rowBackground))
                .accessibilityLabel("Session lengths")
            }
        }
        .frame(maxHeight: .infinity)
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
    var tint: Color = NotchStyle.Palette.accent

    var body: some View {
        ZStack {
            Circle().stroke(NotchStyle.Palette.track, lineWidth: NotchStyle.Compact.ringWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(fraction, 0), 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: NotchStyle.Compact.ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: symbol)
                .font(.system(size: NotchStyle.Compact.ringSymbol, weight: .semibold))
                .foregroundStyle(NotchStyle.Palette.primaryText)
        }
        .frame(width: NotchStyle.Compact.ring, height: NotchStyle.Compact.ring)
    }
}
