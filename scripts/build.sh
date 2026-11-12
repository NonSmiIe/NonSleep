#!/bin/bash
# Builds build/NonSleep.app and the helper binary. No Apple developer certificate needed.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
bin="$(swift build -c release --show-bin-path)"

app="build/NonSleep.app"
rm -rf build
mkdir -p "$app/Contents/MacOS"
cp "$bin/NonSleep" "$app/Contents/MacOS/NonSleep"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp "$bin/NonSleepHelper" build/nonsleep-helper
codesign --force --sign - build/nonsleep-helper
codesign --force --sign - "$app"
echo "Built $app"
