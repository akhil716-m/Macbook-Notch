#!/bin/bash
# Builds MacbookNotch from this checkout and runs it. Needs Xcode and
# XcodeGen (brew install xcodegen). Locally built apps aren't quarantined,
# so macOS doesn't block them.
set -euo pipefail
cd "$(dirname "$0")/.."

git pull --ff-only || echo "(Couldn't pull; building what's here.)"
xcodegen generate --quiet
xcodebuild \
    -project MacbookNotch.xcodeproj \
    -scheme MacbookNotch \
    -configuration Debug \
    -derivedDataPath build \
    -quiet \
    ENABLE_HARDENED_RUNTIME=NO \
    build

pkill -x MacbookNotch 2>/dev/null || true
for _ in $(seq 20); do
    pgrep -x MacbookNotch >/dev/null || break
    sleep 0.5
done
open build/Build/Products/Debug/MacbookNotch.app
echo "Running. Hover over the notch."
