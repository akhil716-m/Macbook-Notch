#!/bin/bash
# Installs the newest successful CI build of MacbookNotch into /Applications
# and restarts it. Needs the GitHub CLI, signed in once:
#   brew install gh && gh auth login
set -euo pipefail

REPO="akhil716-m/Macbook-Notch"
BRANCH="${1:-claude/jolly-turing-rqk3tt}"
APP="/Applications/MacbookNotch.app"

if ! command -v gh >/dev/null; then
    echo "The GitHub CLI isn't installed. Run: brew install gh && gh auth login"
    exit 1
fi

echo "Finding the newest successful build on $BRANCH..."
run_id=$(gh run list -R "$REPO" -b "$BRANCH" -w CI -s success -L 1 --json databaseId -q '.[0].databaseId')
if [ -z "$run_id" ]; then
    echo "No successful build found on $BRANCH."
    exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

echo "Downloading build $run_id..."
gh run download "$run_id" -R "$REPO" -D "$work"
zip=$(find "$work" -name 'MacbookNotch.zip' | head -1)
ditto -x -k "$zip" "$work/unzipped"

echo "Installing to $APP..."
pkill -x MacbookNotch 2>/dev/null || true
# Wait for the old copy to quit; if it's still running, `open` would just
# bring it to the front instead of starting the new one.
for _ in $(seq 20); do
    pgrep -x MacbookNotch >/dev/null || break
    sleep 0.5
done
pkill -9 -x MacbookNotch 2>/dev/null || true
rm -rf "$APP"
ditto "$work/unzipped/MacbookNotch.app" "$APP"
# Unsigned test builds: clear the "downloaded from the internet" flag so
# macOS doesn't block them. Not needed once builds are notarised.
xattr -dr com.apple.quarantine "$APP"

open "$APP"
sleep 3
if pgrep -x MacbookNotch >/dev/null; then
    echo "Done: build $run_id is running. Hover over the notch."
else
    echo "Build $run_id was installed but isn't running; it may have crashed."
    echo "Run the diagnose command from the README and send its output."
    exit 1
fi
