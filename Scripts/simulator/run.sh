#!/bin/bash
#
# Builds zContainer for the iOS Simulator, installs it and opens it, to work on
# its interface: the Simulator can't run the apps inside it. The build uses
# xcconfigs/Simulator.xcconfig, which on an Intel Mac leaves out the ARM-only
# code that runs them, and gives it the entitlements in zContainer.entitlements.
#
# usage: Scripts/simulator/run.sh [device]
#   device   a simulator's UDID or name; the booted one by default
#
# Scripts/simulator/seed-home-screen.py fills the Home Screen with placeholder
# apps and folders.

set -euo pipefail
cd "$(dirname "$0")/../.."

# The UDID of the simulator named, or of the first booted one.
UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
want = sys.argv[1]
devices = [d for group in json.load(sys.stdin)["devices"].values() for d in group]
found = [d for d in devices
         if (d["state"] == "Booted" if want == "booted" else want in (d["udid"], d["name"]))]
if not found:
    sys.exit(f"No simulator {want!r}. Boot one, or name one from: xcrun simctl list devices")
print(found[0]["udid"])' "${1:-booted}")
xcrun simctl boot "$UDID" 2>/dev/null || true

DERIVED=build/simulator
xcodebuild -quiet -project LiveContainer.xcodeproj -scheme LiveContainer -configuration Debug \
    -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$DERIVED" \
    -xcconfig xcconfigs/Simulator.xcconfig CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES build

APP="$DERIVED/Build/Products/Debug-iphonesimulator/LiveContainer.app"
codesign --force --deep --sign - --timestamp=none "$APP"

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist")
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
echo "zContainer ($BUNDLE_ID) is open in simulator $UDID."
