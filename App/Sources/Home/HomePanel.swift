import AppKit
import NotchCore
import SwiftUI

/// The Home tool: what's playing on the left; today's events and open
/// reminders on the right. Section titles jump to the full tool.
struct HomePanel: View {
    @ObservedObject var nowPlaying: NowPlayingService
    @ObservedObject var calendar: CalendarService
    @ObservedObject var reminders: RemindersService
    let onShow: (NotchTool) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let today = Calendar.current.startOfDay(for: context.date)
            HomeContent(
                track: nowPlaying.track,
                artwork: nowPlaying.artwork,
                now: context.date,
                events: calendar.events.on(day: today, calendar: .current).filter { $0.end > context.date },
                calendarAllowed: calendar.access == .granted,
                reminders: reminders.reminders,
                remindersAllowed: reminders.access == .granted,
                onPlayPause: { nowPlaying.togglePlayPause() },
                onNext: { nowPlaying.nextTrack() },
                onPrevious: { nowPlaying.previousTrack() },
                onOpenEvent: { calendar.open($0) },
                onCompleteReminder: { reminders.complete($0) },
                onShow: onShow
            )
        }
        .onAppear {
            calendar.reload()
            reminders.reload()
        }
    }
}

/// From plain values so it can also be drawn with sample data.
struct HomeContent: View {
    let track: NowPlayingTrack?
    let artwork: NSImage?
    let now: Date
    let events: [AgendaEvent]
    let calendarAllowed: Bool
    let reminders: [ReminderItem]
    let remindersAllowed: Bool
    let onPlayPause: () -> Void
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onOpenEvent: (AgendaEvent) -> Void
    let onCompleteReminder: (ReminderItem) -> Void
    let onShow: (NotchTool) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: NotchStyle.Space.l) {
            MiniPlayer(track: track, artwork: artwork, now: now,
                       onPlayPause: onPlayPause, onNext: onNext, onPrevious: onPrevious,
                       onOpen: { onShow(.nowPlaying) })
            VStack(alignment: .leading, spacing: NotchStyle.Space.m) {
                HomeSection(title: "Today", detail: now.formatted(.dateTime.weekday(.wide).day().month(.wide)),
                            symbol: "calendar", onOpen: { onShow(.calendar) }) {
                    if !calendarAllowed {
                        HomeNote("Allow Calendar to see today here.")
                    } else if events.isEmpty {
                        HomeNote("Nothing else today.")
                    } else {
                        ForEach(events.prefix(NotchStyle.Home.visibleEvents)) { event in
                            HomeEventRow(event: event, isNow: event.isHappening(at: now), onOpen: { onOpenEvent(event) })
                        }
                    }
                }
                HomeSection(title: "Reminders", detail: nil, symbol: "list.bullet", onOpen: { onShow(.reminders) }) {
                    if !remindersAllowed {
                        HomeNote("Allow Reminders to see them here.")
                    } else if reminders.isEmpty {
                        HomeNote("All done.")
                    } else {
                        ForEach(reminders.prefix(NotchStyle.Home.visibleReminders)) { item in
                            HomeReminderRow(item: item, now: now, onComplete: { onCompleteReminder(item) })
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(width: NotchStyle.Home.sideColumn, alignment: .leading)
        }
    }
}

/// Now Playing in small: artwork, title, progress and the three controls.
private struct MiniPlayer: View {
    let track: NowPlayingTrack?
    let artwork: NSImage?
    let now: Date
    let onPlayPause: () -> Void
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onOpen: () -> Void

    var body: some View {
        Group {
            if let track {
                HStack(spacing: NotchStyle.Space.l) {
                    ArtworkView(image: artwork, size: NotchStyle.Home.artwork, cornerRadius: NotchStyle.Artwork.openRadius)
                        .onTapGesture(perform: onOpen)
                    VStack(alignment: .leading, spacing: NotchStyle.Space.xs) {
                        Text(track.title.isEmpty ? "Untitled" : track.title)
                            .font(NotchStyle.Font.title)
                            .foregroundStyle(NotchStyle.Palette.primaryText)
                            .lineLimit(1)
                        Text([track.artist, track.player.displayName].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(NotchStyle.Font.subtitle)
                            .foregroundStyle(NotchStyle.Palette.secondaryText)
                            .lineLimit(1)
                        MeterBar(fraction: track.duration > 0 ? track.elapsed(at: now) / track.duration : 0)
                            .padding(.vertical, NotchStyle.Space.xs)
                        HStack(spacing: NotchStyle.Space.l) {
                            control("backward.fill", NotchStyle.Controls.skipSize, "Previous track", onPrevious)
                            control(track.status == .playing ? "pause.fill" : "play.fill", NotchStyle.Controls.playSize,
                                    track.status == .playing ? "Pause" : "Play", onPlayPause)
                            control("forward.fill", NotchStyle.Controls.skipSize, "Next track", onNext)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            } else {
                VStack(spacing: NotchStyle.Space.s) {
                    Image(systemName: "music.note")
                        .font(.system(size: NotchStyle.Controls.playSize))
                        .foregroundStyle(NotchStyle.Palette.secondaryText)
                    Text("Nothing playing")
                        .font(NotchStyle.Font.title)
                        .foregroundStyle(NotchStyle.Palette.primaryText)
                    Text("Start a song in Music or Spotify.")
                        .font(NotchStyle.Font.subtitle)
                        .foregroundStyle(NotchStyle.Palette.secondaryText)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .notchCard(padding: NotchStyle.Space.l, radius: NotchStyle.Card.radius + 4)
    }

    private func control(_ symbol: String, _ size: CGFloat, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(NotchStyle.Palette.primaryText)
                .frame(width: NotchStyle.Controls.hitSize, height: NotchStyle.Controls.hitSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// A titled group on the right of Home. The title opens the full tool.
private struct HomeSection<Content: View>: View {
    let title: String
    let detail: String?
    let symbol: String
    let onOpen: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: NotchStyle.Space.xs) {
            Button(action: onOpen) {
                HStack(spacing: NotchStyle.Space.xs) {
                    Label(title, systemImage: symbol)
                        .font(NotchStyle.Font.title)
                        .foregroundStyle(NotchStyle.Palette.primaryText)
                    Image(systemName: "chevron.right")
                        .font(.system(size: NotchStyle.Row.iconSize - 1, weight: .semibold))
                        .foregroundStyle(NotchStyle.Palette.tertiaryText)
                    Spacer(minLength: NotchStyle.Space.xs)
                    if let detail {
                        Text(detail)
                            .font(NotchStyle.Font.caption)
                            .foregroundStyle(NotchStyle.Palette.tertiaryText)
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens \(title)")
            content()
        }
    }
}

private struct HomeNote: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(NotchStyle.Font.body)
            .foregroundStyle(NotchStyle.Palette.secondaryText)
    }
}

private struct HomeEventRow: View {
    let event: AgendaEvent
    let isNow: Bool
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: NotchStyle.Space.s) {
            Capsule()
                .fill(Color(event.color, fallback: NotchStyle.Palette.accent))
                .frame(width: NotchStyle.Agenda.colorBarWidth, height: NotchStyle.Home.eventBar)
            VStack(alignment: .leading, spacing: 0) {
                Text(event.title)
                    .font(NotchStyle.Font.body)
                    .foregroundStyle(NotchStyle.Palette.primaryText)
                    .lineLimit(1)
                Text(isNow ? "Now" : (event.isAllDay ? "All day" : event.start.formatted(date: .omitted, time: .shortened)))
                    .font(NotchStyle.Font.caption)
                    .foregroundStyle(isNow ? NotchStyle.Palette.live : NotchStyle.Palette.tertiaryText)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

private struct HomeReminderRow: View {
    let item: ReminderItem
    let now: Date
    let onComplete: () -> Void

    var body: some View {
        let overdue = ReminderOrder.bucket(item, now: now, calendar: .current) == .overdue
        HStack(spacing: NotchStyle.Space.s) {
            Button(action: onComplete) {
                Image(systemName: "circle")
                    .font(.system(size: NotchStyle.Todo.checkSize - 2))
                    .foregroundStyle(Color(item.color, fallback: NotchStyle.Palette.secondaryText))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Complete \(item.title)")
            Text(item.title)
                .font(NotchStyle.Font.body)
                .foregroundStyle(overdue ? NotchStyle.Palette.overdue : NotchStyle.Palette.primaryText)
                .lineLimit(1)
        }
    }
}
