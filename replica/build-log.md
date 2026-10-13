# Build log

One line per screen: ID, date, status, what is missing, what was harder than expected.

Status meanings: **done**, meaning built and checked on a real Mac; **partial**,
meaning code written and compiled in CI but not yet run on a MacBook. Nothing
can be called done until it has run on one, because this cloud container is
Linux and can't run a Mac app.

## Milestone 0: vertical slice

| ID | date | status | missing | harder than expected |
| --- | --- | --- | --- | --- |
| S01 Closed notch | 2026-10-13 | partial | not yet run on a MacBook | — |
| S02 Live notch (compact) | 2026-10-13 | partial | music only; timer, shelf and keep-awake activities come with their tools | — |
| S03 Expanded panel | 2026-10-13 | partial | no tool switcher yet (one tool) | hover needs separate hover and click rects, so menu bar items beside the notch stay clickable |
| S06 Now Playing | 2026-10-13 | partial | browsers / other players; no screenshot for diff yet | macOS has no public system-wide now-playing API, so it uses AppleScript to Music + Spotify and needs one Automation prompt per player |
| Menu bar item | 2026-10-13 | partial | Settings window (S26) is milestone 1 | — |

Not built in this milestone and why:

- **Design match:** no reference screenshots yet, so the look uses interim
  tokens in `App/Sources/Shared/NotchStyle.swift`.
- **Clone screenshots for `/replica-diff`:** need the app running on a Mac.
- **Full-screen behaviour:** the panel joins full-screen Spaces, but there is
  no "hide in full screen" setting yet. That arrives with Settings in milestone 1.
