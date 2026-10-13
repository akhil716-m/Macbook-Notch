# MacbookNotch

A Mac app that turns the MacBook notch into a live, hover-to-open panel.
Working name until it's branded.

The plan, feature list and build order are in [`replica/`](replica/):
`recon.md` (what we're building), `architecture.md` (how) and
`build-log.md` (where we are).

## What works now (milestone 0)

- A black notch panel over the hardware notch. On Macs or displays without
  a notch it draws a floating one at the top centre.
- Hover the notch and it springs open; move away and it closes. Clicking the
  closed notch opens it straight away.
- **Now Playing** for Apple Music and Spotify: artwork, title, artist, a
  draggable progress bar, and previous / play-pause / next.
- While music plays, the closed notch shows the artwork on the left and a
  small equaliser on the right.
- Menu bar item with **Open at Login** and **Quit**.

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
  Notch/                notch window, shape, hover handling
  NowPlaying/           Music / Spotify bridge and views
  Shared/               design tokens, launch at login
Packages/NotchCore/     pure Swift logic with unit tests
project.yml             XcodeGen spec (the .xcodeproj is generated, not committed)
replica/                recon, architecture and build log
```
