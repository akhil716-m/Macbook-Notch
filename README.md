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
  - **Teleprompter.** Your script scrolls right under the camera.
  - **Mirror.** A quick look at your camera before a call.
  - **Emoji.** Search by name, click to copy.
  - **Converter.** Length, weight, temperature, volume, speed, data, and
    31 currencies (European Central Bank rates via Frankfurter).
  - **Stocks.** A small watchlist, with your own free Finnhub key.
  - **Revenue.** Today's sales from Stripe, Shopify, Lemon Squeezy, Gumroad,
    Paddle, Polar or Dodo, with your own read-only keys (Settings ›
    Integrations). Keys are kept in the Keychain and sent only to that service.
- **The closed notch shows what's going on:** the volume when it changes,
  else a timer counting down, else music playing, else a cup when Keep Awake
  is on. Hiding the macOS volume popup is optional (Settings › General, needs
  Accessibility permission).
- **Typing in the notch** (Notes, To-dos) keeps it open; Escape closes it.
- **Settings** (menu bar icon › Settings…, ⌘, or the gear in the notch):
  open at login, displays, hover timing, tools on/off and their order, shelf
  retention, clipboard size and ignored apps.

Everything is stored only on this Mac, in
`~/Library/Application Support/MacbookNotch/` (keys in the Keychain). The app
goes online only for: Weather ([Open-Meteo](https://open-meteo.com)), currency
rates ([Frankfurter](https://frankfurter.app)), and Stocks and Revenue if you
add keys for them.

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

### Quickest: one command installs the newest build

Once, in Terminal: `brew install gh && gh auth login` (install
[Homebrew](https://brew.sh) first if you don't have it).

Then, any time you want the latest build:

```bash
gh api "repos/akhil716-m/Macbook-Notch/contents/scripts/install-latest.sh?ref=claude/jolly-turing-rqk3tt" -H "Accept: application/vnd.github.raw" | bash
```

It downloads the newest passing CI build, installs it to `/Applications`,
clears the "downloaded" flag and restarts the app. If you've cloned the repo,
`./scripts/install-latest.sh` does the same. With Xcode installed,
`./scripts/build-and-run.sh` builds and runs your local copy instead.

If something's wrong, this collects the details (macOS version, whether the
app is running, its newest crash report and recent errors) and copies them
to the clipboard to paste into a bug report:

```bash
gh api "repos/akhil716-m/Macbook-Notch/contents/scripts/diagnose.sh?ref=claude/jolly-turing-rqk3tt" -H "Accept: application/vnd.github.raw" | bash
```

### Option A: download a build from CI by hand (no Xcode needed)

1. Open the repo's **Actions** tab, pick the latest green **CI** run, and
   download the `MacbookNotch-…` artifact.
2. Unzip it and move `MacbookNotch.app` to `/Applications`.
3. The build isn't signed with an Apple Developer certificate, so macOS says
   *"MacbookNotch" Not Opened*. Click **Done** (not Move to Bin), then either:
   - open **System Settings › Privacy & Security**, scroll to **Security**,
     click **Open Anyway** next to MacbookNotch, and confirm; or
   - run `xattr -dr com.apple.quarantine /Applications/MacbookNotch.app`
     in Terminal and open the app again.

   (Right-click › Open no longer skips this check on macOS 15 and later.)
   This goes away once the app is signed and notarised with a Developer ID.

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
  Utilities/            teleprompter, mirror, emoji, converter
  Integrations/         stocks and revenue (your own API keys)
  Settings/             settings window
  Shared/               settings, services, design tokens, launch at login
Packages/NotchCore/     pure Swift logic with unit tests
project.yml             XcodeGen spec (the .xcodeproj is generated, not committed)
replica/                recon, architecture and build log
```
