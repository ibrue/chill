#!/bin/bash
set -e

# Chill Helper Installation Script
# Installs ChillHelper as a privileged LaunchDaemon

echo "Installing Chill Helper..."

# Generate the Xcode project if needed
if [ ! -d "Chill.xcodeproj" ]; then
    echo "Generating Xcode project..."
    xcodegen generate
fi

BUILT_HELPER=".build/Build/Products/Release/com.chill.helper"

# Build ChillHelper if not already built
if [ ! -f "$BUILT_HELPER" ]; then
    echo "Building ChillHelper..."
    xcodebuild \
        -project Chill.xcodeproj \
        -scheme ChillHelper \
        -configuration Release \
        -destination 'platform=macOS' \
        -derivedDataPath .build \
        build
fi

HELPER_PATH="/Library/PrivilegedHelperTools/com.chill.helper"
PLIST_PATH="/Library/LaunchDaemons/com.chill.helper.plist"
HELPER_LABEL="com.chill.helper"

# Check if built helper exists
if [ ! -f "$BUILT_HELPER" ]; then
    echo "Error: ChillHelper binary not found at $BUILT_HELPER"
    echo "Please build the ChillHelper target first."
    exit 1
fi

echo "Requesting sudo access to install helper..."

if sudo launchctl print "system/$HELPER_LABEL" >/dev/null 2>&1; then
    echo "Stopping existing LaunchDaemon..."
    sudo launchctl bootout system "$PLIST_PATH" 2>/dev/null || \
        sudo launchctl unload "$PLIST_PATH" 2>/dev/null || true
fi

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
sudo launchctl bootstrap system "$PLIST_PATH" 2>/dev/null || \
    sudo launchctl load "$PLIST_PATH"
sudo launchctl enable "system/$HELPER_LABEL" 2>/dev/null || true
sudo launchctl kickstart -k "system/$HELPER_LABEL" 2>/dev/null || true

echo "Installation complete!"
echo "ChillHelper is now running as root."
echo ""
echo "To verify: sudo launchctl print system/$HELPER_LABEL"
echo "To uninstall: ./uninstall.sh"
