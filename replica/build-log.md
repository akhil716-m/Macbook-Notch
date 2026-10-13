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

## Milestone 3a: could-haves without accounts

| ID | date | status | missing | harder than expected |
| --- | --- | --- | --- | --- |
| S19 Teleprompter | 2026-10-13 | partial | mirrored text for beam-splitter rigs; multiple scripts | the notch must stay open while you read, even with the pointer elsewhere |
| S20 Mirror | 2026-10-13 | partial | — | needs the camera entitlement under the hardened runtime |
| S21 Emoji | 2026-10-13 | partial | flags, skin tones and multi-person emoji (sequences, not single characters) | none: names come from Swift's built-in Unicode data, so no list ships with the app |
| S22 Converter | 2026-10-13 | partial | maths expressions ("5 km + 300 m") | — |

## Milestone 3b: could-haves with your own keys

| ID | date | status | missing | harder than expected |
| --- | --- | --- | --- | --- |
| S15 Stocks | 2026-10-13 | partial | charts; more than 8 tickers (free-tier rate limit) | — |
| S18 Revenue | 2026-10-13 | partial | **Lemon Squeezy, Gumroad, Paddle, Polar and Dodo are written from their public docs and need a check with a real key**; only the first page of today's orders is read | every service reports money differently (cents vs decimal strings, 0- and 3-decimal currencies), so totals are kept per currency in minor units and never added across currencies |

With 23 tools, most now sit in the overflow menu. The tab bar needs a
rethink in the design pass (favourites, or a grid home screen).

## First run on a real Mac (2026-10-13)

MacBook on macOS 27.0.1, Apple silicon.

- Gatekeeper blocks the unsigned build; right-click › Open no longer bypasses
  it, so the README now says to use Open Anyway or `xattr`. Goes away with a
  Developer ID signature and notarisation.
- The app launches and runs. **Hover over the notch opens the panel: S01/S03
  confirmed.**
- **The hardened runtime + ad-hoc signing crash is real.** I reverted the
  fix after a CI diagnostic launched a hardened ad-hoc copy, but that test
  was wrong twice over: `codesign --deep` re-signed Sparkle ad hoc too (so
  the teams matched), and GitHub's runners have SIP off, so library
  validation isn't enforced there. The user's Mac crash report showed dyld
  refusing Sparkle.framework ("different Team IDs"). Test builds (CI and
  `build-and-run.sh`) now turn the hardened runtime off; `project.yml` keeps
  it on for Developer ID builds. CI checks that embedded frameworks share the
  app's team whenever the runtime is on, since its launch check can't catch
  this. `scripts/diagnose.sh` collects crash reports from a tester's Mac.
- **Tool tabs were invisible on the real Mac** (screenshot: open panel showed
  Now Playing, nothing in the strip beside the notch), so no other tool was
  reachable. The tabs now sit in a scrollable row inside the panel, below
  the notch strip, which this Mac was already drawing correctly. The strip
  itself is left empty. Settings › General now shows the screen and notch
  measurements to help diagnose layout problems.
- **Tabs confirmed** on the real Mac once the Sparkle crash was fixed: the
  scrolling row under the notch shows, and switching to Shelf works. The row
  holds about 15 of 19 tools at once, so its ends now fade to show it scrolls.
- The user asked for the tab row at the **bottom** of the panel, like a dock,
  with the tool's content above it. Content still starts below the taller of
  the notch and the menu bar.
- **Full test pass on the real Mac (macOS 27.0.1, MacBook Air M2): all
  working.** Music (Music/Spotify control and the closed-notch activity),
  Shelf drag in and out, Clipboard, Timer countdown in the closed notch,
  Volume in the notch, typing in Notes with Escape to close, Calendar,
  Reminders, Weather and Mirror (each after its permission prompt).
  features.csv: 14 of 32 features now `yes`; parity 70.3 (was 53.6).

## Design pass (2026-10-13)

- 15 reference screenshots from the user (kept local, git-ignored) measured
  for colour roles, type, spacing, radii and layout. Tokens in
  `replica/design/tokens.json`, specs in `replica/design/components.md`,
  contrast check: 20 pairs, 0 AA failures.
- Shell: 640 x 312 pt panel; header with tool name, Pin and Settings; icon
  tabs centred along the bottom; wider closed-notch wings with a timer
  progress ring.
- Shared components: card, segmented picker, round buttons, header icon
  buttons. Applied to Converter, System, Now Playing and Timers.
- Verification without a Mac: `--design-snapshots` renders sample panels;
  a commit message containing `[snapshots]` makes CI commit the PNGs to
  `replica/design/snapshots/`. First render matched the specs; one fix
  (System label wrapping).
- Feature gaps spotted (not design): Stopwatch / Pomodoro, disk and battery
  stats, a Home tab, lyrics, AI cost totals. Listed in components.md.
