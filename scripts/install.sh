#!/bin/bash
# Builds NonSleep and installs the app and its root helper. Asks for your password once.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ "$(id -u)" = 0 ]; then
    echo "Run this as yourself, not with sudo: it asks for the password when needed." >&2
    exit 1
fi

label="com.nonsmile.nonsleep.helper"
./scripts/build.sh

sudo install -d -o root -g wheel -m 755 /Library/PrivilegedHelperTools
if sudo launchctl bootout "system/$label" 2>/dev/null; then
    # bootout returns before the old helper is gone; bootstrap fails until it is.
    while sudo launchctl print "system/$label" >/dev/null 2>&1; do sleep 0.2; done
fi
sudo install -o root -g wheel -m 755 build/nonsleep-helper "/Library/PrivilegedHelperTools/$label"
sudo install -o root -g wheel -m 644 "Resources/$label.plist" "/Library/LaunchDaemons/$label.plist"
sudo launchctl bootstrap system "/Library/LaunchDaemons/$label.plist"

pkill -x NonSleep 2>/dev/null || true
sudo rm -rf /Applications/NonSleep.app
sudo cp -R build/NonSleep.app /Applications/NonSleep.app
open /Applications/NonSleep.app
echo "Installed. NonSleep is in the menu bar."
