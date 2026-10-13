# Recon map: OmniNotch (macOS desktop)

Scope: the whole app. Every tool in the notch panel, plus the shell (notch window, hover-to-open, settings, licensing). Build order starts with the core loop.
For: to confirm with the user. Working assumption: a paid one-time-licence Mac utility under our own brand.
Date: 2026-10-13

## How this map was made, and its limits

omninotch.app, Product Hunt, Peerlist and the other listing sites are all
blocked by this cloud environment's network policy, so no page was opened
directly. Everything below comes from search-engine extracts of those pages,
which were partly quoted and partly summarised. Treat it as a feature
inventory, not a pixel spec:

- **Feature list: high confidence.** Several independent extracts agree on it.
- **Exact layout, animations, settings and copy: not seen.** Rows marked
  `guess` come from how notch apps in this category usually work, not from
  OmniNotch itself.
- **No screenshots yet.** `replica/screens/` is empty. Before `/replica-design`
  we need either the network opened to omninotch.app, or screenshots or a
  screen recording from the user (the site's demo, or their own copy of the app).

## Sources

| # | source | URL | notes |
| --- | --- | --- | --- |
| 1 | marketing site (home) | https://omninotch.app/ | title "OmniNotch for Mac, The Lightest Notch App, 20 Tools". Tool list, price, requirements, "reads local CLI tokens on-device", offline activation, 3 Macs |
| 2 | comparison page | https://omninotch.app/vs/macnotch | positions MacNotch as a "modular dashboard" and OmniNotch as a "fixed suite with on-device Ask Omni, local clipboard and AirDrop". $5 until Oct 5, then $19.99 |
| 3 | guide | https://omninotch.app/guides/best-mac-notch-apps | ranks OmniNotch best overall; macOS Sonoma+, Apple silicon + Intel, 7-day money-back |
| 4 | Product Hunt | https://www.producthunt.com/products/omninotch | "The notch that does it all!" Lifetime $14.99, up to 3 Macs, "live AI CLI usage", no account, no cloud, no telemetry |
| 5 | Peerlist | https://peerlist.io/nerdynikhil/project/omninotch | most detailed feature descriptions. Built on NotchDrop (MIT). Floating notch on Macs without one |
| 6 | TryMacApps | https://www.trymacapps.com/app/omninotch | "It's all in the notch." AI usage for Claude/Codex/Cursor/Copilot/Grok; revenue from Stripe/Shopify/Lemon Squeezy/Gumroad/Dodo/Polar/Paddle |
| 7 | macmenubar.app | https://macmenubar.app/app/omninotch | listing; same tool list |
| 8 | ProductCool | https://www.productcool.com/product/omninotch | listing dated 2026-09-25 |
| 9 | SaaSCity | https://saascity.io/live/omninotch | "opens on hover or click", one-time purchase, no account |
| 10 | Threads @omninotch | https://www.threads.com/@omninotch/post/DdwQ5-OE9_Y/ | shelf demo post; "native, 12 MB, one-time payment" |
| 11 | maker's 2.0 announcement | https://x.com/nerdynikhil/status/2104632807356248452 | 2.0 shipped about a week after 1.0. Aim: quieter, faster, lighter, more native |
| 12 | TrustMRR | https://trustmrr.com/startup/omninotch | ~$542 revenue, paid through Dodo Payments |
| 13 | NotchDrop (open-source base) | https://github.com/Lakr233/NotchDrop | MIT. Drop files on the notch, AirDrop, files kept 1 day (configurable), click to open, ⌥-click × to delete |

## Core loop

Hover over the notch and it opens into a black panel with about twenty tools.
While something is happening (music, a timer, a dropped file), the notch shows
it live without being opened. All of it is on-device, with no account, sold
as a one-time licence.

## Product facts

| fact | value | confidence |
| --- | --- | --- |
| platform | macOS 14 Sonoma+, Apple silicon and Intel | high |
| Macs without a notch | draws a floating notch at the top centre of the screen | high |
| open gesture | hover (also click, per SaaSCity) | high |
| size | ~12 MB app, marketed as "the lightest notch app" | medium |
| privacy | on-device, no account, no cloud, no telemetry | high |
| price | one-time lifetime licence, up to 3 Macs, works offline after activation, lifetime updates. $14.99 at launch, then $5 flash sale for 2.0, regular $19.99 | high |
| refunds | 7-day money-back | medium |
| payments | Dodo Payments (licence keys) | medium |
| Ask Omni requirement | Apple Intelligence Foundation Models, which in practice means macOS 26+ on Apple silicon with Apple Intelligence on. On older Macs the tool must degrade | medium (inferred from Apple's requirements) |

## Screens

A notch app has few "screens". It has states of a single panel, plus one tool
view per tool and a settings window.

| ID | screen | how to reach | purpose | key components | states seen |
| --- | --- | --- | --- | --- | --- |
| S01 | Closed notch | always, at rest | invisible, blends into the hardware notch | notch shape | idle (guess) |
| S02 | Live notch (compact) | something running: music, timer, Keep Awake, dropped file | glanceable status without opening | album art left, waveform/time right; timer countdown; badge (guess) | music, timer, shelf-has-files (guess) |
| S03 | Hover-expanded panel (home) | hover or click on the notch | entry to every tool | black rounded panel growing out of the notch, tool switcher/tab row, current tool view | open, closing on mouse-out (guess on exact layout) |
| S04 | Drop target | drag a file towards the notch | accept files to the shelf | highlighted drop zone, "Drop here" / AirDrop target | dragging over, dropped (high, from NotchDrop) |
| S05 | Ask Omni | tool in S03 | on-device AI chat | prompt field, message list, streaming answer | empty, thinking, answer, Apple Intelligence unavailable |
| S06 | Now Playing | tool in S03 | media control | album art, title, artist, scrubber with times, prev/play-pause/next | playing, paused, nothing playing |
| S07 | Clipboard history | tool in S03 | re-copy past clips | list newest first, click to re-copy, ⌥-delete | empty, filled |
| S08 | File Shelf + AirDrop | tool in S03 / S04 | park files, share them | file tiles with icons, AirDrop button, × on ⌥ | empty, filled |
| S09 | Timers | tool in S03 | countdowns (Pomodoro in one listing only) | presets, start/pause/reset, live countdown | idle, running, finished |
| S10 | Calendar | tool in S03 | today's events | event list, next event | no events, filled, no permission |
| S11 | Reminders | tool in S03 | Apple Reminders | list, tick off | empty, filled, no permission |
| S12 | To-dos | tool in S03 | local to-do list | input, checkboxes | empty, filled |
| S13 | Quick notes | tool in S03 | scratch notes | text area | empty, filled |
| S14 | Weather | tool in S03 | current conditions | temp, condition icon, location | loading, filled, no location |
| S15 | Stocks | tool in S03 | ticker watchlist | symbol, price, change % | empty, filled, loading |
| S16 | System stats | tool in S03 | CPU, memory, network | meters, up/down rates | live |
| S17 | Live AI usage | tool in S03 | usage limits for AI coding CLIs | one row per provider: Claude, Codex, Copilot (+ Cursor, Grok per one listing), usage bar, reset time | not signed in, filled |
| S18 | Revenue | tool in S03 | today's revenue | per-source totals: Stripe, Shopify, Lemon Squeezy, Gumroad, Dodo, Polar, Paddle | not connected, filled, error |
| S19 | Teleprompter | tool in S03 | scroll a script under the camera | text, scroll speed, play/pause | empty, scrolling |
| S20 | Quick Mirror | tool in S03 | camera preview | live camera feed | live, no camera permission |
| S21 | Emoji picker | tool in S03 | pick and copy emoji | search, grid | filled |
| S22 | Unit / currency converter | tool in S03 | convert values | value, from/to units | filled |
| S23 | Keep Awake | tool in S03 / S02 | stop the Mac sleeping | toggle, duration | on, off |
| S24 | Volume HUD | press volume keys | notch-style volume indicator, replacing the system HUD | level bar | showing (medium) |
| S25 | Shortcuts | tool in S03 | run Apple Shortcuts | list of shortcuts | empty, filled (low confidence: one extract only) |
| S26 | Settings window | menu bar icon or panel gear (guess) | toggle tools, hover behaviour, shelf retention, AI/revenue keys, launch at login | tabs, toggles | (not seen) |
| S27 | Onboarding / permissions | first launch | grant calendar, reminders, camera, accessibility, etc. | step list | (not seen, guess) |
| S28 | Licence activation | first launch / settings | enter key, activate up to 3 Macs | key field, status | trial?, active, invalid, limit reached (guess) |

## Flows

```
F01 Glance at the notch and open it
    S01 -> hover -> S03 -> mouse leaves -> S01
    happy path clicks: 0 (hover only)
    edge: menu bar manager apps (Bartender, Ice) hiding items; external display without a notch; full-screen apps; multiple displays

F02 Park a file and AirDrop it
    drag file -> S04 -> drop -> S02 (badge) -> hover -> S08 -> AirDrop -> share sheet
    happy path clicks: 1 drag + 1 click
    edge: many files, folders, large files, file deleted from disk, retention expires (default 1 day in NotchDrop)

F03 Control music
    S02 (live album art) -> hover -> S06 -> play/pause/skip/scrub
    happy path clicks: 1
    edge: Spotify vs Apple Music vs browser; nothing playing; no artwork

F04 Re-copy an old clip
    hover -> S03 -> S07 -> click clip -> on the clipboard
    happy path clicks: 2
    edge: images and files on the clipboard; password-manager clips must be skipped; ⌥-delete

F05 Ask Omni a question
    hover -> S03 -> S05 -> type -> streamed answer
    happy path clicks: 1 + typing
    edge: Apple Intelligence off or unsupported Mac or OS; long answers; panel closing on mouse-out while typing

F06 Run a focus timer
    S09 -> pick preset -> S02 shows countdown -> finishes -> alert in notch
    happy path clicks: 2

F07 Check AI coding limits
    hover -> S17 -> per-provider usage and reset times
    edge: CLI not installed, not logged in, token expired

F08 See today's revenue
    S26 -> add API key for Stripe (etc.) -> S18 shows today's total
    edge: invalid key, rate limits, currencies

F09 Buy and activate
    website checkout -> licence key email -> S28 -> paste -> active
    edge: 4th Mac, offline activation, refund

F10 Keep the Mac awake
    S23 toggle -> S02 indicator -> off
```

## Components

| component | variants | states | used on |
| --- | --- | --- | --- |
| Notch panel | closed, compact live, expanded, floating (no-notch Macs) | animating open/close, hover, drag-over | S01–S04 |
| Tool switcher | icon row or grid (guess) | selected, hover | S03 |
| Live activity (compact) | music, timer, shelf, keep-awake | — | S02 |
| Media controls | prev, play/pause, next, scrubber | playing, paused, disabled | S06 |
| List row | clip, file, event, reminder, to-do, ticker, provider | hover, ⌥-held (delete visible), selected | S07, S08, S10–S12, S15, S17, S18 |
| File tile | file, folder, image thumbnail | hover, dragging out | S08 |
| Meter / progress bar | CPU, memory, AI usage, volume | — | S16, S17, S24 |
| Text input | single line, multiline | focus, empty | S05, S12, S13, S19, S22 |
| Chat bubble | user, assistant | streaming | S05 |
| Toggle | — | on, off | S23, S26 |
| Settings tabs | general, tools, integrations, licence (guess) | — | S26 |

## Inferred data model

Everything is local (no server). User data is stored on the Mac, and
secrets go in the Keychain.

```
ShelfItem     id, bookmark (security-scoped), filename, addedAt, expiresAt
              evidence: NotchDrop README, shelf posts. confidence: high
Clip          id, kind (text | image | file | url), content, sourceApp, copiedAt
              evidence: "every clip kept, most-recent-first", skips password managers. confidence: high
Note          id, body, updatedAt                                 confidence: medium
Todo          id, title, done, createdAt                          confidence: medium
TimerPreset   id, label, seconds; ActiveTimer endsAt, paused      confidence: medium
Ticker        symbol, lastPrice, change, fetchedAt                confidence: medium
WeatherCache  location, temp, condition, fetchedAt                confidence: medium
ChatMessage   id, role, text, createdAt (maybe session-only)      confidence: guess
AIProvider    kind (claude | codex | copilot | cursor | grok), usage %, resetsAt, source (local CLI token)
              evidence: "reads local CLI tokens on-device". confidence: high on what, guess on fields
RevenueSource kind (stripe | shopify | lemonsqueezy | gumroad | dodo | polar | paddle), apiKey (Keychain), todayTotal, currency
              confidence: high on what, guess on fields
Settings      enabledTools[], toolOrder[], hoverDelay, shelfRetention, launchAtLogin, ... confidence: guess
License       key, activatedAt, machineId; server side: max 3 activations   confidence: high
```

Relationships: none to speak of. Separate local stores per tool, plus one
licence record checked against the payment provider.

## Feature matrix

See `features.csv`. Must: 13, should: 12, could: 7, skip: 2.

## Out of scope (cannot or should not be cloned)

- **The name "OmniNotch", the "Ask Omni" name, its logo, icons, site copy and screenshots.** Ours gets its own brand (`/replica-brand`).
- **Its compiled app and source.** We won't decompile or inspect them. NotchDrop is MIT-licensed open source, so we *may* start from it ourselves, keeping its licence notice. That is our call, made openly, not copying OmniNotch.
- **Its customers, reviews and licence server.** We need our own payment/licence provider.

## Hard parts

1. **The notch window itself.** A borderless, always-on-top window shaped like the notch, sitting over the menu bar, with smooth spring animations, drag-and-drop, multiple displays, full-screen apps, and a floating notch for Macs without one.
2. **Now Playing across all players.** macOS has no public system-wide "now playing" API. The private MediaRemote framework was locked down in macOS 15.4. Options: AppleScript for Music/Spotify, or the workarounds open-source notch apps use. This needs a deliberate choice in `/replica-architect`.
3. **Ask Omni on Apple Intelligence.** Apple's FoundationModels framework needs macOS 26 and Apple silicon. The app supports macOS 14+, so the tool must hide or degrade gracefully.
4. **Live AI usage.** Reading each AI coding CLI's local login token and calling the provider's usage endpoint. This is sensitive (handling credentials), uses undocumented endpoints that change, and must never send tokens anywhere else.
5. **Revenue connectors.** 7 payment APIs, each with its own auth and "today" semantics.
6. **Replacing the system volume HUD.** Needs media-key interception (accessibility permission).
7. **Staying "the lightest".** Memory use and idle CPU are part of the pitch, so polling (stats, stocks, usage) has to be careful.

## Size

Screens 28 (one panel, ~21 tool views, settings, onboarding, licence), flows 10,
entities 12. Size: **L**. The shell plus the core loop (F01–F04) takes a few
weeks. All ~20 tools polished is a quarter of focused work.

**Build environment:** this is a native Swift/SwiftUI + AppKit macOS app. It
needs Xcode on a Mac to build, run and test. This cloud Linux container can
write the code and push it, but cannot compile or run a Mac app. You'd build
and try each step on your MacBook.
