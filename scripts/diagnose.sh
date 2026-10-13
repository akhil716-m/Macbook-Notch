#!/bin/bash
# Collects what's needed to debug MacbookNotch on this Mac, prints it and
# copies it to the clipboard so it can be pasted into a chat or issue.
# Reads only system info and MacbookNotch's own crash reports and logs.
APP="/Applications/MacbookNotch.app"
out=$(mktemp)

{
    echo "== macOS"
    sw_vers
    uname -m

    echo "== App"
    if [ -d "$APP" ]; then
        echo "version $(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null) ($(defaults read "$APP/Contents/Info.plist" CFBundleVersion 2>/dev/null))"
        codesign -dv "$APP" 2>&1 | grep -E '^(Identifier|Signature|CodeDirectory)'
        codesign --verify --deep "$APP" 2>&1 && echo "signature ok"
        xattr "$APP"
    else
        echo "$APP is missing"
    fi

    echo "== Running"
    pgrep -lf MacbookNotch || echo "not running"

    echo "== Displays"
    system_profiler SPDisplaysDataType 2>/dev/null | grep -E 'Display Type|Resolution|Main Display|Connection Type|UI Looks like'

    echo "== Newest crash report"
    crash=$(ls -t ~/Library/Logs/DiagnosticReports/MacbookNotch* 2>/dev/null | head -1)
    if [ -n "$crash" ]; then
        echo "$crash"
        head -c 6000 "$crash"
        echo
    else
        echo "none"
    fi

    echo "== Log, last 10 minutes"
    log show --last 10m --style compact \
        --predicate 'process == "MacbookNotch" && (messageType == error || messageType == fault || eventMessage CONTAINS "MacbookNotch")' \
        2>/dev/null | tail -40
} > "$out" 2>&1

cat "$out"
pbcopy < "$out"
rm -f "$out"
echo
echo "Copied to the clipboard. Paste it into the chat."
