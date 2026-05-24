#!/bin/bash
set -euo pipefail

CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-.build}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/Chill.app"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "Error: xcodegen is required. Install it with: brew install xcodegen" >&2
    exit 1
fi

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

if [ ! -d "$APP_PATH" ]; then
    echo "Error: app bundle not found at $APP_PATH" >&2
    exit 1
fi

echo "Launching $APP_PATH..."
open -n "$APP_PATH"
