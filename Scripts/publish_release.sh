#!/bin/bash
set -euo pipefail

# Build, sign, notarize, and publish a Chill release.
#
# Required env:
#   VERSION                   — e.g. 1.0.1
#   APP_SIGN_IDENTITY         — "Developer ID Application: ... (TEAMID)"
#   INSTALLER_SIGN_IDENTITY   — "Developer ID Installer: ... (TEAMID)"
#   DEVELOPMENT_TEAM          — Apple team ID
#   NOTARY_PROFILE            — keychain profile name from `xcrun notarytool store-credentials`
#   SPARKLE_BIN_DIR           — path to Sparkle's bin/ (containing generate_appcast and sign_update)
#   SPARKLE_PRIVATE_KEY_FILE  — path to the EdDSA private key file (NOT committed)
#
# Optional env:
#   GH_REPO                   — owner/repo (default: ibrue/chill)
#   RELEASE_NOTES_FILE        — path to release notes markdown

VERSION="${VERSION:?VERSION must be set}"
SPARKLE_BIN_DIR="${SPARKLE_BIN_DIR:?SPARKLE_BIN_DIR must be set}"
SPARKLE_PRIVATE_KEY_FILE="${SPARKLE_PRIVATE_KEY_FILE:?SPARKLE_PRIVATE_KEY_FILE must be set}"
GH_REPO="${GH_REPO:-ibrue/chill}"
OUTPUT_DIR="${OUTPUT_DIR:-dist}"
PKG_PATH="$OUTPUT_DIR/Chill-v$VERSION.pkg"
APPCAST_PATH="$OUTPUT_DIR/appcast.xml"

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: $1 is required." >&2
        exit 1
    fi
}

require_command gh
require_command "$SPARKLE_BIN_DIR/generate_appcast"

echo "==> Building and notarizing $PKG_PATH"
VERSION="$VERSION" \
APP_SIGN_IDENTITY="$APP_SIGN_IDENTITY" \
INSTALLER_SIGN_IDENTITY="$INSTALLER_SIGN_IDENTITY" \
DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
NOTARY_PROFILE="$NOTARY_PROFILE" \
OUTPUT_DIR="$OUTPUT_DIR" \
    ./Scripts/build_installer.sh

if [ ! -f "$PKG_PATH" ]; then
    echo "Error: expected installer at $PKG_PATH" >&2
    exit 1
fi

echo "==> Generating appcast"
# generate_appcast scans the directory for installer artifacts, signs them with
# the EdDSA key, and writes appcast.xml alongside them.
"$SPARKLE_BIN_DIR/generate_appcast" \
    --ed-key-file "$SPARKLE_PRIVATE_KEY_FILE" \
    --download-url-prefix "https://github.com/$GH_REPO/releases/download/v$VERSION/" \
    "$OUTPUT_DIR"

if [ ! -f "$APPCAST_PATH" ]; then
    echo "Error: expected appcast at $APPCAST_PATH" >&2
    exit 1
fi

echo "==> Creating GitHub release v$VERSION"
RELEASE_ARGS=(
    "v$VERSION"
    "$PKG_PATH"
    "$APPCAST_PATH"
    --repo "$GH_REPO"
    --title "Chill v$VERSION"
)
if [ -n "${RELEASE_NOTES_FILE:-}" ] && [ -f "$RELEASE_NOTES_FILE" ]; then
    RELEASE_ARGS+=(--notes-file "$RELEASE_NOTES_FILE")
else
    RELEASE_ARGS+=(--generate-notes)
fi

gh release create "${RELEASE_ARGS[@]}"

echo "==> Done. Sparkle will auto-update existing installs from:"
echo "    https://github.com/$GH_REPO/releases/latest/download/appcast.xml"
