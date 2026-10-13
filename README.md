# MacbookNotch

A Mac app that turns the MacBook notch into a live, hover-to-open panel.
Working name until it's branded.

The plan, feature list and build order are in [`replica/`](replica/):
`recon.md` (what we're building), `architecture.md` (how) and
`build-log.md` (where we are).

## What works now

- **The notch.** A black panel over the hardware notch. Screens without one
  get a floating notch. Choose built-in, primary or all displays in Settings.
- **Hover to open, move away to close.** Clicking the closed notch opens it
  straight away. Both delays can be changed in Settings.
- **Tools.** Tabs beside the notch switch between them; the gear opens Settings.
  - **Now Playing** for Apple Music and Spotify: artwork, title, artist,
    a draggable progress bar, previous / play-pause / next. While music plays,
    the closed notch shows the artwork and a small equaliser.
  - **Shelf.** Drag files onto the notch and it opens on the shelf. Click a
    file to open it, drag it out to use it, AirDrop one or all, and hold ⌥
    to show remove buttons (or right-click). Files stay for 1 day by default.
  - **Clipboard.** Everything you copy (text, links, images, files), newest
    first. Click to copy it again, hold ⌥ to delete. Password-manager copies
    and ignored apps are never recorded.
  - **Timers.** One click to start 1–45 minutes (25 is "Focus"). Pause,
    resume, restart. The closed notch counts down and says "Done" with a chime.
  - **To-dos.** Type, press Return, tick off. "Clear done" tidies up.
  - **Notes.** A scratchpad that saves as you type.
  - **System.** CPU (with a short history), memory, and network speed.
  - **Keep Awake.** Stop the Mac sleeping until you turn it off or for
    30 min to 4 hours, optionally keeping the display on.
  - **Calendar.** What's left of today and tomorrow, in your calendar
    colours, with a **Join** button for Zoom / Meet / Teams links.
  - **Reminders.** Open reminders, overdue first. Tick to complete, type to add.
  - **Weather.** Now and the next few days, for a city you search or your
    current location.
  - **Ask.** Chat with Apple's on-device model (Apple Intelligence). Needs
    macOS 26 on Apple silicon and a build made with Xcode 26; nothing you
    type leaves the Mac.
  - **AI Usage.** For Claude Code: tokens in the current 5-hour window, when
    it resets, and the last 7 days. For Codex: its real limit percentages.
    Read only from the log files those tools keep on your Mac; their login
    tokens are never touched.
- **The closed notch shows what's going on:** the volume when it changes,
  else a timer counting down, else music playing, else a cup when Keep Awake
  is on. Hiding the macOS volume popup is optional (Settings › General, needs
  Accessibility permission).
- **Typing in the notch** (Notes, To-dos) keeps it open; Escape closes it.
- **Settings** (menu bar icon › Settings…, ⌘, or the gear in the notch):
  open at login, displays, hover timing, tools on/off and their order, shelf
  retention, clipboard size and ignored apps.

Everything is stored only on this Mac, in
`~/Library/Application Support/MacbookNotch/`. The one exception is Weather,
which asks [Open-Meteo](https://open-meteo.com) for the forecast at the place
you picked.

macOS asks for permission the first time you open Calendar, Reminders, or
Weather's "Use My Location".

## Before selling it

Three things in `project.yml` are blank on purpose, so test builds work:

- **Licensing (Lemon Squeezy):** `MNLicenseStoreID`, `MNLicenseProductID`
  and `MNPurchaseURL`. Set the product's activation limit to 3 in Lemon
  Squeezy. While the IDs are 0, every build is unlocked.
- **Updates (Sparkle):** `SUFeedURL` (your appcast) and `SUPublicEDKey`
  (from Sparkle's `generate_keys`). While blank, updates are off.
- **Weather:** swap Open-Meteo's free tier for WeatherKit or their
  commercial plan.

You'll also need an Apple Developer account to sign and notarise the app.

## Run it

### Option A: download a build from CI (no Xcode needed)

1. Open the repo's **Actions** tab, pick the latest green **CI** run, and
   download the `MacbookNotch-…` artifact.
2. Unzip it and move `MacbookNotch.app` to `/Applications`.
3. The build is ad-hoc signed, not notarised, so macOS will block the first
   launch. Either right-click the app › **Open** › **Open**, or run:
   `xattr -dr com.apple.quarantine /Applications/MacbookNotch.app`

### Option B: build it yourself

You need macOS 14+, Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`).

```bash
xcodegen generate
open MacbookNotch.xcodeproj    # then press ⌘R
```

Run the logic tests with `swift test --package-path Packages/NotchCore`.

### First run

Start a song in Music or Spotify. macOS asks once per player whether
MacbookNotch may control it; click **OK**. If you clicked **Don't Allow**,
turn it back on in System Settings › Privacy & Security › Automation.

Ad-hoc builds get a new signature each build, so macOS may ask again after
you rebuild. Signing with your own Apple Developer team in Xcode stops that.

## Layout

```
App/Sources/            the Mac app (SwiftUI views + AppKit window)
  Notch/                notch windows (one per screen), shape, hover, tool tabs
  NowPlaying/           Music / Spotify bridge and views
  Shelf/                file shelf service and view
  Clipboard/            clipboard history service and view
  Timers/               countdown timers
  Productivity/         to-dos, notes, Keep Awake
  SystemStats/          CPU, memory, network
  Calendar/             calendar events and reminders (EventKit)
  Weather/              forecast and location
  Volume/               volume watching and the optional volume-key tap
  Ask/                  on-device chat (FoundationModels)
  AIUsage/              Claude Code and Codex usage from local logs
  Licensing/            licence keys (Lemon Squeezy) and Keychain
  Onboarding/           first-run welcome window
  Settings/             settings window
  Shared/               settings, services, design tokens, launch at login
Packages/NotchCore/     pure Swift logic with unit tests
project.yml             XcodeGen spec (the .xcodeproj is generated, not committed)
replica/                recon, architecture and build log
```
