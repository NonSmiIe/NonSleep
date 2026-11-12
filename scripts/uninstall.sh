#!/bin/bash
# Switches the mode off, restores the power settings and removes NonSleep.
set -euo pipefail

label="com.nonsmile.nonsleep.helper"
helper="/Library/PrivilegedHelperTools/$label"

pkill -x NonSleep 2>/dev/null || true
sudo launchctl bootout "system/$label" 2>/dev/null || true
if [ -x "$helper" ]; then
    sudo "$helper" --reset
else
    sudo pmset -a disablesleep 0
fi
sudo rm -f "$helper" "/Library/LaunchDaemons/$label.plist"
sudo rm -rf "/Library/Application Support/NonSleep" /Applications/NonSleep.app
echo "NonSleep is removed."
