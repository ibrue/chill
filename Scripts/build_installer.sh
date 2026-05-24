#!/bin/bash
set -euo pipefail

VERSION="${VERSION:-1.0.0}"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-.build}"
OUTPUT_DIR="${OUTPUT_DIR:-dist}"
PACKAGE_ID="${PACKAGE_ID:-com.chill.installer}"
HELPER_LABEL="com.chill.helper"

APP_BUILD_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/Chill.app"
HELPER_BUILD_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/com.chill.helper"
PKG_PATH="$OUTPUT_DIR/Chill-v$VERSION.pkg"

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: $1 is required." >&2
        exit 1
    fi
}

require_command xcodegen
require_command xcodebuild
require_command pkgbuild

export COPYFILE_DISABLE=1

mkdir -p "$OUTPUT_DIR"

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

if [ ! -d "$APP_BUILD_PATH" ]; then
    echo "Error: built app not found at $APP_BUILD_PATH" >&2
    exit 1
fi

if [ ! -f "$HELPER_BUILD_PATH" ]; then
    echo "Error: built helper not found at $HELPER_BUILD_PATH" >&2
    exit 1
fi

WORKDIR="$(mktemp -d)"
cleanup() {
    rm -rf "$WORKDIR"
}
trap cleanup EXIT

PAYLOAD="$WORKDIR/payload"
SCRIPTS="$WORKDIR/scripts"

mkdir -p \
    "$PAYLOAD/Applications" \
    "$PAYLOAD/Library/PrivilegedHelperTools" \
    "$PAYLOAD/Library/LaunchDaemons" \
    "$SCRIPTS"

ditto --norsrc --noextattr --noacl "$APP_BUILD_PATH" "$PAYLOAD/Applications/Chill.app"
install -m 744 "$HELPER_BUILD_PATH" "$PAYLOAD/Library/PrivilegedHelperTools/com.chill.helper"
install -m 644 Config/com.chill.helper.plist "$PAYLOAD/Library/LaunchDaemons/com.chill.helper.plist"
if command -v xattr >/dev/null 2>&1; then
    xattr -cr "$PAYLOAD"
fi
find "$PAYLOAD" -name '._*' -delete
chmod 544 "$PAYLOAD/Library/PrivilegedHelperTools/com.chill.helper"

cat > "$SCRIPTS/preinstall" <<'EOF'
#!/bin/bash
set -e

HELPER_PLIST="/Library/LaunchDaemons/com.chill.helper.plist"
HELPER_LABEL="com.chill.helper"

if pgrep -f '/Chill.app/Contents/MacOS/Chill' >/dev/null 2>&1; then
    pkill -f '/Chill.app/Contents/MacOS/Chill' || true
fi

if launchctl print "system/$HELPER_LABEL" >/dev/null 2>&1; then
    launchctl bootout system "$HELPER_PLIST" 2>/dev/null || \
        launchctl unload "$HELPER_PLIST" 2>/dev/null || true
fi

exit 0
EOF

cat > "$SCRIPTS/postinstall" <<'EOF'
#!/bin/bash
set -e

APP_PATH="/Applications/Chill.app"
HELPER_PATH="/Library/PrivilegedHelperTools/com.chill.helper"
HELPER_PLIST="/Library/LaunchDaemons/com.chill.helper.plist"
HELPER_LABEL="com.chill.helper"

chown -R root:wheel "$APP_PATH"
chown root:wheel "$HELPER_PATH" "$HELPER_PLIST"
chmod 544 "$HELPER_PATH"
chmod 644 "$HELPER_PLIST"

launchctl bootstrap system "$HELPER_PLIST" 2>/dev/null || \
    launchctl load "$HELPER_PLIST"
launchctl enable "system/$HELPER_LABEL" 2>/dev/null || true
launchctl kickstart -k "system/$HELPER_LABEL" 2>/dev/null || true

CONSOLE_USER="$(/usr/sbin/scutil <<< 'show State:/Users/ConsoleUser' | /usr/bin/awk '/Name :/ && $3 != "loginwindow" { print $3; exit }')"
if [ -n "$CONSOLE_USER" ]; then
    CONSOLE_UID="$(id -u "$CONSOLE_USER" 2>/dev/null || true)"
    if [ -n "$CONSOLE_UID" ]; then
        launchctl asuser "$CONSOLE_UID" open "$APP_PATH" >/dev/null 2>&1 || true
    fi
fi

exit 0
EOF

chmod +x "$SCRIPTS/preinstall" "$SCRIPTS/postinstall"

echo "Building installer package..."
pkgbuild \
    --root "$PAYLOAD" \
    --scripts "$SCRIPTS" \
    --identifier "$PACKAGE_ID" \
    --version "$VERSION" \
    --install-location / \
    "$PKG_PATH"

echo "Created $PKG_PATH"
