#!/bin/bash
set -euo pipefail

# Build, sign, notarize, and publish a Chill release, including the Sparkle
# auto-update appcast.
#
# Required env:
#   VERSION                   e.g. 1.0.1 (used for the git tag and pkg name)
#   APP_SIGN_IDENTITY         "Developer ID Application: ... (TEAMID)"
#   INSTALLER_SIGN_IDENTITY   "Developer ID Installer: ... (TEAMID)"
#   DEVELOPMENT_TEAM          Apple team ID
#   NOTARY_PROFILE            keychain profile from `xcrun notarytool store-credentials`
#   SPARKLE_BIN_DIR           path to Sparkle's bin/ (contains sign_update)
#
# Optional env:
#   GH_REPO                   owner/repo (default: ibrue/chill)
#   RELEASE_NOTES_FILE        path to release notes markdown
#
# The Sparkle EdDSA private key is read from your login keychain (set up once
# with Sparkle's `generate_keys`); no key file is needed or stored anywhere.
#
# Bumping the app version: raise MARKETING_VERSION / CURRENT_PROJECT_VERSION (so
# the built app's CFBundleShortVersionString / CFBundleVersion go up) before
# releasing, or Sparkle will not offer the update to existing users.

VERSION="${VERSION:?VERSION must be set}"
SPARKLE_BIN_DIR="${SPARKLE_BIN_DIR:?SPARKLE_BIN_DIR must be set}"
GH_REPO="${GH_REPO:-ibrue/chill}"
OUTPUT_DIR="${OUTPUT_DIR:-dist}"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-.build}"
PKG_PATH="$OUTPUT_DIR/Chill-v$VERSION.pkg"
APPCAST_PATH="$OUTPUT_DIR/appcast.xml"
APP_PLIST="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/Chill.app/Contents/Info.plist"

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Error: $1 is required." >&2
        exit 1
    fi
}

require_command gh
if [ ! -x "$SPARKLE_BIN_DIR/sign_update" ]; then
    echo "Error: sign_update not found in $SPARKLE_BIN_DIR" >&2
    exit 1
fi

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

echo "==> Reading the built app's version"
SHORT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PLIST")"
BUILD_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PLIST")"
MIN_OS="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP_PLIST" 2>/dev/null || echo 14.0)"

echo "==> Signing the package for Sparkle (EdDSA key from keychain)"
# generate_appcast does not recognize a bare .pkg, and Chill ships pkg updates
# (so the privileged helper is reinstalled with each update), so we sign the
# package directly and write a package-install appcast entry ourselves.
SIG_LINE="$("$SPARKLE_BIN_DIR/sign_update" "$PKG_PATH")"   # sparkle:edSignature="..." length="..."
PUBDATE="$(date -u '+%a, %d %b %Y %H:%M:%S +0000')"

cat > "$APPCAST_PATH" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Chill</title>
    <link>https://github.com/$GH_REPO</link>
    <description>Smart fan control for Apple Silicon</description>
    <language>en</language>
    <item>
      <title>Version $SHORT_VERSION</title>
      <pubDate>$PUBDATE</pubDate>
      <sparkle:version>$BUILD_VERSION</sparkle:version>
      <sparkle:shortVersionString>$SHORT_VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$MIN_OS</sparkle:minimumSystemVersion>
      <enclosure url="https://github.com/$GH_REPO/releases/download/v$VERSION/Chill-v$VERSION.pkg" type="application/octet-stream" sparkle:installationType="package" $SIG_LINE />
    </item>
  </channel>
</rss>
EOF
xmllint --noout "$APPCAST_PATH"
echo "Wrote $APPCAST_PATH (version $SHORT_VERSION, build $BUILD_VERSION)"

echo "==> Creating GitHub release v$VERSION"
RELEASE_ARGS=(
    "v$VERSION"
    "$PKG_PATH"
    "$APPCAST_PATH"
    --repo "$GH_REPO"
    --target main
    --title "Chill v$VERSION"
)
if [ -n "${RELEASE_NOTES_FILE:-}" ] && [ -f "${RELEASE_NOTES_FILE:-}" ]; then
    RELEASE_ARGS+=(--notes-file "$RELEASE_NOTES_FILE")
else
    RELEASE_ARGS+=(--generate-notes)
fi
gh release create "${RELEASE_ARGS[@]}"

echo "==> Done. Existing installs auto-update from:"
echo "    https://github.com/$GH_REPO/releases/latest/download/appcast.xml"
