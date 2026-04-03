#!/bin/bash
set -e

# Chill Helper Installation Script
# Installs ChillHelper as a privileged LaunchDaemon

echo "Installing Chill Helper..."

# Build ChillHelper if not already built
if [ ! -f ".build/Release/ChillHelper" ]; then
    echo "Building ChillHelper..."
    xcodebuild -scheme ChillHelper -configuration Release build
fi

HELPER_PATH="/Library/PrivilegedHelperTools/com.chill.helper"
PLIST_PATH="/Library/LaunchDaemons/com.chill.helper.plist"
BUILT_HELPER=".build/Release/ChillHelper"

# Check if built helper exists
if [ ! -f "$BUILT_HELPER" ]; then
    echo "Error: ChillHelper binary not found at $BUILT_HELPER"
    echo "Please build the ChillHelper target first."
    exit 1
fi

echo "Requesting sudo access to install helper..."

# Copy helper binary
sudo cp "$BUILT_HELPER" "$HELPER_PATH"
sudo chmod 544 "$HELPER_PATH"
sudo chown root:wheel "$HELPER_PATH"

# Copy launchd plist
sudo cp Config/com.chill.helper.plist "$PLIST_PATH"
sudo chmod 644 "$PLIST_PATH"
sudo chown root:wheel "$PLIST_PATH"

# Load the daemon
echo "Loading LaunchDaemon..."
sudo launchctl load "$PLIST_PATH"

echo "Installation complete!"
echo "ChillHelper is now running as root."
echo ""
echo "To verify: sudo launchctl list | grep com.chill"
echo "To uninstall: sudo launchctl unload $PLIST_PATH && sudo rm $HELPER_PATH $PLIST_PATH"
