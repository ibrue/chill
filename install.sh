#!/bin/bash
set -euo pipefail

REPO_URL="${CHILL_REPO_URL:-https://github.com/ibrue/chill.git}"
REF="${CHILL_REF:-main}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-.build}"
CONFIGURATION="Release"

APP_INSTALL_PATH="/Applications/Chill.app"
HELPER_INSTALL_PATH="/Library/PrivilegedHelperTools/com.chill.helper"
HELPER_PLIST_PATH="/Library/LaunchDaemons/com.chill.helper.plist"
HELPER_LABEL="com.chill.helper"

WORKDIR=""
TEMP_DIR=""

cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: $1 is required." >&2
        return 1
    fi
}

if [ -f "project.yml" ] && [ -d "Chill" ] && [ -d "ChillHelper" ]; then
    WORKDIR="$(pwd)"
else
    require_command git
    TEMP_DIR="$(mktemp -d)"
    echo "Cloning Chill from $REPO_URL..."
    git clone "$REPO_URL" "$TEMP_DIR/chill"
    WORKDIR="$TEMP_DIR/chill"
    cd "$WORKDIR"
    git checkout "$REF"
fi

cd "$WORKDIR"

require_command xcodegen || {
    echo "Install XcodeGen with: brew install xcodegen" >&2
    exit 1
}
require_command xcodebuild

echo "Generating Xcode project..."
xcodegen generate

echo "Building Chill ($CONFIGURATION)..."
xcodebuild \
    -project Chill.xcodeproj \
    -scheme Chill \
    -configuration "$CONFIGURATION" \
    -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build

APP_BUILD_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/Chill.app"
HELPER_BUILD_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/com.chill.helper"

if [ ! -d "$APP_BUILD_PATH" ]; then
    echo "Error: built app not found at $APP_BUILD_PATH" >&2
    exit 1
fi

if [ ! -f "$HELPER_BUILD_PATH" ]; then
    echo "Error: built helper not found at $HELPER_BUILD_PATH" >&2
    exit 1
fi

echo "Installing Chill. You may be prompted for your password."

if pgrep -f '/Chill.app/Contents/MacOS/Chill' >/dev/null 2>&1; then
    echo "Stopping running Chill app..."
    pkill -f '/Chill.app/Contents/MacOS/Chill' || true
fi

if sudo launchctl print "system/$HELPER_LABEL" >/dev/null 2>&1; then
    echo "Stopping existing helper..."
    sudo launchctl bootout system "$HELPER_PLIST_PATH" 2>/dev/null || \
        sudo launchctl unload "$HELPER_PLIST_PATH" 2>/dev/null || true
fi

echo "Copying app to $APP_INSTALL_PATH..."
sudo rm -rf "$APP_INSTALL_PATH"
sudo ditto "$APP_BUILD_PATH" "$APP_INSTALL_PATH"
sudo chown -R root:wheel "$APP_INSTALL_PATH"

echo "Installing privileged helper..."
sudo install -m 544 -o root -g wheel "$HELPER_BUILD_PATH" "$HELPER_INSTALL_PATH"
sudo install -m 644 -o root -g wheel Config/com.chill.helper.plist "$HELPER_PLIST_PATH"

echo "Starting helper..."
# bootstrap can return non-zero (e.g. "5: Input/output error") even when it
# works, so never let the fallback abort the script under `set -e`.
sudo launchctl bootstrap system "$HELPER_PLIST_PATH" 2>/dev/null || \
    sudo launchctl load "$HELPER_PLIST_PATH" 2>/dev/null || true
sudo launchctl enable "system/$HELPER_LABEL" 2>/dev/null || true
sudo launchctl kickstart -k "system/$HELPER_LABEL" 2>/dev/null || true

if [ "${CHILL_NO_OPEN:-0}" != "1" ]; then
    echo "Launching Chill..."
    open "$APP_INSTALL_PATH"
fi

echo "Chill installed successfully."
echo "App: $APP_INSTALL_PATH"
echo "Helper: $HELPER_INSTALL_PATH"
