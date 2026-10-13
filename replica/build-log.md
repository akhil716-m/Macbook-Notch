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

## Milestone 2a: everyday should-haves

| ID | date | status | missing | harder than expected |
| --- | --- | --- | --- | --- |
| S09 Timers | 2026-10-13 | partial | no custom length or label yet | — |
| S12 To-dos | 2026-10-13 | partial | no editing of a title after adding | — |
| S13 Quick notes | 2026-10-13 | partial | one scratchpad, not multiple notes | typing in a notch that never activates the app: the panel becomes key only for text fields, and routes ⌘C / ⌘V / ⌘Z itself because our Edit menu never receives them |
| S16 System stats | 2026-10-13 | partial | no per-core view, no battery | network counters are 32-bit and wrap at 4 GB, handled |
| S23 Keep Awake | 2026-10-13 | partial | — | — |
| S02 Live activities | 2026-10-13 | partial | the shelf has no indicator | priority: finished timer > running timer > music > Keep Awake |

Needs checking on a real Mac:

- Typing in Notes / To-dos, then moving the pointer away: the notch should
  stay open while a text field has focus, close on Escape, and hand the
  keyboard back to the app you were in.
- The timer notification permission prompt appears the first time a timer starts.

## Milestone 2b: Apple data

| ID | date | status | missing | harder than expected |
| --- | --- | --- | --- | --- |
| S10 Calendar | 2026-10-13 | partial | no "up next" live activity in the closed notch yet | the hardened runtime needs the calendars entitlement as well as the usage strings |
| S11 Reminders | 2026-10-13 | partial | no due dates when adding; one default list | EventKit returns reminders on a background queue, so they're copied into plain values there |
| S14 Weather | 2026-10-13 | partial | **Open-Meteo is a stand-in**: its free tier is non-commercial. Before selling, switch to WeatherKit (needs the paid Apple Developer Program) or Open-Meteo's commercial plan | — |

Privacy note: Weather is the first tool that talks to a server. It sends the
chosen place's coordinates (rounded to about 10 m) to Open-Meteo, and city
searches to its geocoding API. Nothing else leaves the Mac.

## Milestone 2c: volume and on-device AI

| ID | date | status | missing | harder than expected |
| --- | --- | --- | --- | --- |
| S24 Volume HUD | 2026-10-13 | partial | no brightness HUD | showing changes needs nothing, but hiding the macOS popup means catching the volume keys with an event tap, which needs Accessibility. Ad-hoc builds lose that permission on every rebuild |
| S05 Ask (on-device chat) | 2026-10-13 | partial | answers arrive all at once (no streaming yet); renamed from the original's "Ask Omni" | Apple's FoundationModels exists only in the macOS 26 SDK (Xcode 26), so the code is compiled only when available, and macOS 14/15 users get an explanation instead |

## Milestone 2d: AI usage, licensing, onboarding, updates

| ID | date | status | missing | harder than expected |
| --- | --- | --- | --- | --- |
| S17 AI usage | 2026-10-13 | partial | Copilot (keeps no local usage); Claude limits as a % (its logs have tokens, not limits); Cursor / Grok | log files can be large, so each scan reads only lines added since the last one, and Claude Code logs some calls twice (deduplicated by message + request id) |
| S28 Licence activation | 2026-10-13 | partial | **needs your Lemon Squeezy store**: set MNLicenseStoreID, MNLicenseProductID, MNPurchaseURL in project.yml; activation limit 3 is set on the product | every key is checked against our store and product IDs, otherwise any Lemon Squeezy key would unlock the app |
| S27 Onboarding | 2026-10-13 | partial | — | — |
| Updates (Sparkle) | 2026-10-13 | partial | **needs an appcast and signing key**: set SUFeedURL and SUPublicEDKey in project.yml (generate_keys from Sparkle) | — |

Until those IDs and keys are filled in, licensing is off (everything is
unlocked) and the update menu item is hidden, so test builds keep working.
