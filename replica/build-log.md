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
  no "hide in full screen" setting yet.

## Milestone 1: must-haves

| ID | date | status | missing | harder than expected |
| --- | --- | --- | --- | --- |
| S03 Expanded panel: tool switcher | 2026-10-13 | partial | room for ~5 tabs beside the notch; ~20 tools will need a different layout | — |
| S04 Drop target | 2026-10-13 | partial | not tested with a real Finder drag | macOS doesn't say "a drag started", so we watch the drag pasteboard's change counter from mouse-down, and poll while a button is held in case drag events don't reach us |
| S07 Clipboard history | 2026-10-13 | partial | re-copy puts back plain text only (no rich text); no search yet; macOS 26 pasteboard privacy prompt untested | copies often carry both text and a picture (spreadsheet cells), so text vs image follows the copying app's own type order |
| S08 File shelf + AirDrop | 2026-10-13 | partial | no "shelf has files" indicator on the closed notch | — |
| S26 Settings window | 2026-10-13 | partial | no "hide in full screen" option yet | the SwiftUI Settings scene can't be opened from code on macOS 14+, so it's a plain window we manage ourselves |
| Multi-display | 2026-10-13 | partial | not tested with an external monitor | — |

Notes:

- **The shelf copies files.** On APFS (every modern Mac) the copy is a clone,
  so it uses no extra disk space until one side changes.
- **⌥ to delete** is detected by checking the modifier keys while the notch
  is open. That needs no Accessibility permission. Right-click › Remove works too.
