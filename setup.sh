#!/bin/bash
set -e

# Chill Helper Installation Script
# Builds ChillHelper and installs it as a privileged LaunchDaemon.

HELPER_DEST="/Library/PrivilegedHelperTools/com.chill.helper"
PLIST_DEST="/Library/LaunchDaemons/com.chill.helper.plist"
DERIVED="./build"

echo "Building ChillHelper..."
xcodebuild \
    -scheme ChillHelper \
    -configuration Release \
    -derivedDataPath "$DERIVED" \
    build

# The helper binary may be named either "ChillHelper" or "com.chill.helper"
# depending on whether EXECUTABLE_PATH is set in project.yml. Look for both.
PRODUCTS="$DERIVED/Build/Products/Release"
if [ -f "$PRODUCTS/ChillHelper" ]; then
    BUILT_HELPER="$PRODUCTS/ChillHelper"
elif [ -f "$PRODUCTS/com.chill.helper" ]; then
    BUILT_HELPER="$PRODUCTS/com.chill.helper"
else
    echo "Error: ChillHelper binary not found under $PRODUCTS"
    echo "Contents:"
    ls -la "$PRODUCTS" 2>/dev/null || echo "(directory missing)"
    exit 1
fi

echo "Found helper at: $BUILT_HELPER"
echo "Requesting sudo to install helper..."

sudo cp "$BUILT_HELPER" "$HELPER_DEST"
sudo chmod 544 "$HELPER_DEST"
sudo chown root:wheel "$HELPER_DEST"

sudo cp Config/com.chill.helper.plist "$PLIST_DEST"
sudo chmod 644 "$PLIST_DEST"
sudo chown root:wheel "$PLIST_DEST"

# Reload (unload-then-load) in case a previous version is already running
sudo launchctl unload "$PLIST_DEST" 2>/dev/null || true
sudo launchctl load "$PLIST_DEST"

echo ""
echo "Installation complete. Verify with:"
echo "  sudo launchctl list | grep com.chill"
echo ""
echo "To uninstall later:"
echo "  sudo launchctl unload $PLIST_DEST"
echo "  sudo rm $HELPER_DEST $PLIST_DEST"
