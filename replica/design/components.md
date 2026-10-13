# Components

The design system for the notch, in SwiftUI. Tokens live in
`App/Sources/Shared/NotchStyle.swift` (values recorded by role in
`tokens.json`); components live in `App/Sources/Shared/Components.swift`
unless noted. Rendered samples: `replica/design/snapshots/` (regenerate by
pushing a commit whose message contains `[snapshots]`).

Measured from reference screenshots of the original (kept local in
`replica/screens/`, never committed). Rebuilt as a system: no icons,
artwork, copy or brand colour taken. Icons are SF Symbols.

## Shell

```
Open panel
  size      640 x 312 pt; black; ears 14, bottom corners 32; shadow 0 6 18 @45%
  layout    [clear strip: max(notch, menu bar)] [Header 30] [tool content] [Tab bar 30, 13 above bottom]
  padding   content 18 pt sides, 6 top, 8 bottom; tab bar 14 sides
  states    closed -> compact (live activity) -> open, one spring (0.38 s, 0.82)
  a11y      the tool name is a header; Escape closes; nothing is placed level
            with the notch or menu bar (they can cover it on some Macs)
  file      App/Sources/Notch/NotchRootView.swift

Header (PanelHeader)
  layout    tool name left (header 17/700), Pin + Settings right (HeaderIconButton)
  states    pinned: filled pin on a selection circle; panel stays open when the
            pointer leaves. Closing (Escape) unpins.
  file      NotchRootView.swift

Tab bar (ToolTabBar)
  layout    icons only, centred; items 29 x 26, gap 3, radius 8; icon 15/500
  states    default (secondary text), selected (white icon on selection fill),
            overflow: becomes a horizontal scroller with faded ends
  a11y      each tab is a button labelled with the tool name, .isSelected on
            the current one; tooltip shows the name
  file      NotchRootView.swift
```

## Containers

```
Card (notchCard / NotchCardBackground)
  tokens    fill surface (white 7%), radius 12, padding 12; no outline, no shadow:
            set apart by a tone step only (taste house rule)
  variants  large (radius 16, padding 14) for Now Playing, System, Weather week
  used on   Converter, System, Now Playing, Timers rows, Calendar agenda, Weather week

Readout (SystemReadouts)                 App/Sources/SystemStats/SystemStatsPanel.swift
  layout    three columns on one large card, centred in the panel:
            label with symbol (13, secondary) / number (36, tracking -0.5) + unit (15,
            secondary) / one line of context 30 pt tall (sparkline, meter + "of 16 GB",
            upload rate)
  a11y      each column is one element: title + value

Month calendar (MonthCalendar)           App/Sources/Calendar/CalendarPanels.swift
  layout    "October 2026" (15/600, click = today) + previous / next arrows;
            weekday initials (11, tertiary); 7 x 4-6 grid of 28 x 23 cells
  states    today: white disc, black bold number; chosen day: grey disc;
            other month: tertiary at 60%; day with events: 3 pt accent dot under the disc
  a11y      each day is a button: full date + "has events"; .isSelected on the chosen day
  logic     MonthGrid / [AgendaEvent].on(day:) / busyDays in NotchCore (tested)

Day agenda (DayAgenda)
  layout    card beside the month: "Today" / "Tomorrow" / "Wednesday 14 October"
            (15/600), then event rows; scrolls only when the day doesn't fit
  states    past events at 50%; "Now" in green; Join chip for meeting links;
            empty: "Nothing scheduled", centred

Weather (WeatherForecastView)            App/Sources/Weather/WeatherPanel.swift
  layout    now (196 pt): place (click = change) + refresh; symbol 40 + temperature
            56 light; condition 15/600; "Feels like · H L" tertiary.
            Week: 7 equal columns on a large card: day (Today in 600), multicolour
            symbol 18, high 13/600, low 11 tertiary
  states    offline note in danger beside the place

Keep Awake (KeepAwakeContent)            App/Sources/Productivity/ProductivityPanels.swift
  layout    one centred column: 64 pt switch (accent when on), title, status,
            duration chips + "Screen on" toggle chip
```

## Controls

```
Segmented picker (SegmentedPicker)
  size      height 26, track radius 8, inset 2, item padding 14
  tokens    track surface; selected pill fill (white) with on-fill text; segment 13/500
  states    default, selected (pill slides with the panel spring), pressed
  a11y      each option is a real button with .isSelected; no arrow-key
            navigation because the panel rarely has keyboard focus
  used on   Converter categories; planned for Timers (Timer / Stopwatch / Pomodoro)

Round button (RoundButtonStyle / RoundIconButton)
  variants  primary (white, black symbol) for the one main action;
            secondary (surface + hairline, white symbol)
  sizes     large 44 (symbol 17), small 32 (symbol 13)
  states    default, pressed (scale 0.94, 75% opacity), disabled (40%)
  a11y      always pass a label; it becomes the accessibility label and tooltip
  used on   Timers rows; planned for stopwatch, teleprompter

Header icon button (HeaderIconButton)
  size      28 hit, symbol 14/500
  states    off (secondary), on (white on selection circle)
  used on   Pin, Settings

Chip (ChipButtonStyle)
  size      height 24, padding 10, chip 12/500
  variants  default (surface + hairline), prominent (white, black text)
  used on   timer presets, Keep Awake durations, permission prompts

Icon button (IconButton)
  size      24 hit, symbol 11/600, no background
  used on   row actions (remove, swap units)

Menu pill (Converter unit menus)
  size      height 24, padding 10, selection fill, borderless menu inside
```

## Data display

```
Meter (MeterBar)
  size      4 pt capsule
  tokens    track white 15%; fill white (default), accent (running), danger
            (over limit), secondary (paused)
  a11y      the parent supplies the value text

Scrubber (PlaybackScrubber)            App/Sources/NowPlaying/NowPlayingPanel.swift
  size      4 pt, 7 pt while dragging, 12 pt hit area
  layout    elapsed left, total right (caption, tertiary)
  a11y      one element: "Playback position", value "0:55 of 3:40"

Sparkline (Sparkline)
  stroke    1.5 pt secondary, round joins

Text levels
  primary   white            titles, values
  secondary white 72%        subtitles, labels
  tertiary  white 56%        times, hints, footnotes
```

## Closed-notch activities

```
Wings      72 pt each side of the notch; content 14 pt from the outer edge
Timer      progress ring 20 pt (2 pt stroke, accent) with symbol 9 pt | time 15/600 white
           finished: bell + "Done" in accent
Music      artwork 24 pt radius 6 | equaliser bars
Volume     speaker symbol | level meter
Keep Awake cup symbol
```

## States every tool must cover

```
Empty      EmptyToolState: symbol, title (14/600), one line (12, secondary), centred
Permission PermissionPrompt: as empty, plus a prominent chip that opens System Settings
Loading    the tool's own layout with "–" placeholders, never a spinner in the notch
Error      one line in danger or secondary text under the content, with what to do next
```

## Gaps found while measuring (features, not design)

- Timers: Stopwatch and Pomodoro modes (with session count) and background sounds.
- System: disk free and battery rows.
- Home tab: greeting, Now Playing card, today's events and reminders side by side.
- Now Playing: synced lyrics view.
- Teleprompter: translucent panel option; a resize grabber under the tab bar.
- AI Usage: cost totals (today / 30 days), Cursor and Grok cards, "expected by reset" tick.
