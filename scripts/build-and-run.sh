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
    build

pkill -x MacbookNotch 2>/dev/null || true
sleep 1
open build/Build/Products/Debug/MacbookNotch.app
echo "Running. Hover over the notch."
