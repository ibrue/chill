#!/bin/bash
set -e

# Chill Helper Installation Script
# Installs ChillHelper as a privileged LaunchDaemon

echo "Installing Chill Helper..."

# Build ChillHelper
echo "Building ChillHelper..."
xcodebuild -scheme ChillHelper -configuration Release build 2>&1 | tail -5

# Find the built binary via Xcode build settings
BUILT_HELPER=$(xcodebuild -scheme ChillHelper -configuration Release -showBuildSettings 2>/dev/null | grep -m1 "BUILT_PRODUCTS_DIR" | awk '{print $3}')
BUILT_HELPER="$BUILT_HELPER/ChillHelper"

if [ ! -f "$BUILT_HELPER" ]; then
    echo "Error: ChillHelper binary not found at $BUILT_HELPER"
    echo "Try building ChillHelper in Xcode first (Product > Build)."
    exit 1
fi

echo "Found helper at: $BUILT_HELPER"

HELPER_PATH="/Library/PrivilegedHelperTools/com.chill.helper"
PLIST_PATH="/Library/LaunchDaemons/com.chill.helper.plist"

echo "Requesting sudo access to install helper..."

# Unload existing daemon if present
sudo launchctl unload "$PLIST_PATH" 2>/dev/null || true

# Copy helper binary
sudo mkdir -p /Library/PrivilegedHelperTools
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

echo ""
echo "Installation complete! ChillHelper is now running as root."
echo "To verify: sudo launchctl list | grep com.chill"
echo "To uninstall: sudo launchctl unload $PLIST_PATH && sudo rm $HELPER_PATH $PLIST_PATH"
