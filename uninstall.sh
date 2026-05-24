#!/bin/bash
set -euo pipefail

APP_INSTALL_PATH="/Applications/Chill.app"
HELPER_INSTALL_PATH="/Library/PrivilegedHelperTools/com.chill.helper"
HELPER_PLIST_PATH="/Library/LaunchDaemons/com.chill.helper.plist"
HELPER_LABEL="com.chill.helper"

echo "Uninstalling Chill. You may be prompted for your password."

if pgrep -f '/Chill.app/Contents/MacOS/Chill' >/dev/null 2>&1; then
    echo "Stopping Chill app..."
    pkill -f '/Chill.app/Contents/MacOS/Chill' || true
fi

if sudo launchctl print "system/$HELPER_LABEL" >/dev/null 2>&1; then
    echo "Stopping helper..."
    sudo launchctl bootout system "$HELPER_PLIST_PATH" 2>/dev/null || \
        sudo launchctl unload "$HELPER_PLIST_PATH" 2>/dev/null || true
fi

echo "Removing installed files..."
sudo rm -rf "$APP_INSTALL_PATH"
sudo rm -f "$HELPER_INSTALL_PATH" "$HELPER_PLIST_PATH"

echo "Chill uninstalled."
