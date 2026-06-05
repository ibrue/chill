#!/bin/bash
set -euo pipefail

VERSION="${VERSION:-1.0.0}"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-.build}"
OUTPUT_DIR="${OUTPUT_DIR:-dist}"
PACKAGE_ID="${PACKAGE_ID:-com.chill.installer}"
HELPER_LABEL="com.chill.helper"
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:-}"
INSTALLER_SIGN_IDENTITY="${INSTALLER_SIGN_IDENTITY:-}"
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALLER_SCRIPTS_DIR="$SCRIPT_DIR/installer-scripts"

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

if [ -n "$NOTARY_PROFILE" ]; then
    require_command xcrun
    if [ -z "$APP_SIGN_IDENTITY" ] || [ -z "$INSTALLER_SIGN_IDENTITY" ]; then
        echo "Error: NOTARY_PROFILE requires APP_SIGN_IDENTITY and INSTALLER_SIGN_IDENTITY." >&2
        exit 1
    fi
fi

export COPYFILE_DISABLE=1

mkdir -p "$OUTPUT_DIR"

echo "Generating Xcode project..."
xcodegen generate

BUILD_SETTINGS=()
if [ -n "$APP_SIGN_IDENTITY" ]; then
    BUILD_SETTINGS+=(
        CODE_SIGN_STYLE=Manual
        CODE_SIGN_IDENTITY="$APP_SIGN_IDENTITY"
        OTHER_CODE_SIGN_FLAGS=--timestamp
        # Hardened Runtime is required for notarization. Letting xcodebuild apply
        # it means the embedded Sparkle.framework and its nested XPC services /
        # Updater.app get signed correctly inside-out, which `codesign --deep`
        # (below, now removed) would have mangled.
        ENABLE_HARDENED_RUNTIME=YES
    )
    if [ -n "$DEVELOPMENT_TEAM" ]; then
        BUILD_SETTINGS+=(DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM")
    fi
fi

echo "Building Chill ($CONFIGURATION)..."
if [ ${#BUILD_SETTINGS[@]} -gt 0 ]; then
    xcodebuild \
        -project Chill.xcodeproj \
        -scheme Chill \
        -configuration "$CONFIGURATION" \
        -destination 'platform=macOS' \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        "${BUILD_SETTINGS[@]}" \
        build
else
    xcodebuild \
        -project Chill.xcodeproj \
        -scheme Chill \
        -configuration "$CONFIGURATION" \
        -destination 'platform=macOS' \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        build
fi

if [ ! -d "$APP_BUILD_PATH" ]; then
    echo "Error: built app not found at $APP_BUILD_PATH" >&2
    exit 1
fi

if [ ! -f "$HELPER_BUILD_PATH" ]; then
    echo "Error: built helper not found at $HELPER_BUILD_PATH" >&2
    exit 1
fi

if [ -n "$APP_SIGN_IDENTITY" ]; then
    echo "Re-signing helper with explicit identifier and hardened runtime..."
    # codesign derives the identifier from the filename and strips what looks
    # like an extension, so `com.chill.helper` would otherwise become `com.chill`.
    codesign --force \
        --sign "$APP_SIGN_IDENTITY" \
        --identifier com.chill.helper \
        --options runtime \
        --timestamp \
        --entitlements Config/ChillHelper.entitlements \
        "$HELPER_BUILD_PATH"

    echo "Re-sealing the app bundle (NOT --deep, to preserve Xcode's inside-out"
    echo "signatures on Sparkle's nested code)..."
    # Re-sign only the outer app so its identifier/entitlements/hardened-runtime
    # are exactly what we want; the already-correctly-signed Sparkle components
    # underneath are left intact (required for notarization to pass).
    codesign --force \
        --sign "$APP_SIGN_IDENTITY" \
        --identifier com.chill.app \
        --options runtime \
        --timestamp \
        --entitlements Config/Chill.entitlements \
        "$APP_BUILD_PATH"

    echo "Verifying Developer ID signatures..."
    codesign --verify --deep --strict --verbose=2 "$APP_BUILD_PATH"
    codesign --verify --strict --verbose=2 "$HELPER_BUILD_PATH"
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
# Resource forks inside Chill.app/Contents/* break the code-signature seal at
# install time. Strip them aggressively.
xattr -cr "$PAYLOAD"
dot_clean -m "$PAYLOAD" 2>/dev/null || true
find "$PAYLOAD" \( -name '._*' -o -name '.DS_Store' \) -delete
chmod 544 "$PAYLOAD/Library/PrivilegedHelperTools/com.chill.helper"

# Installer scripts are committed under Scripts/installer-scripts/ so they can be
# unit-tested in isolation (see Scripts/test_installer.sh). Stage them with
# `install` (no resource forks) rather than copying, to keep the package clean.
if [ ! -f "$INSTALLER_SCRIPTS_DIR/preinstall" ] || [ ! -f "$INSTALLER_SCRIPTS_DIR/postinstall" ]; then
    echo "Error: installer scripts not found in $INSTALLER_SCRIPTS_DIR" >&2
    exit 1
fi
echo "Staging installer scripts..."
install -m 755 "$INSTALLER_SCRIPTS_DIR/preinstall" "$SCRIPTS/preinstall"
install -m 755 "$INSTALLER_SCRIPTS_DIR/postinstall" "$SCRIPTS/postinstall"
find "$SCRIPTS" \( -name '._*' -o -name '.DS_Store' \) -delete

# Disable bundle relocation. By default pkgbuild marks Chill.app as a
# relocatable component, so the Installer "shoves" the payload on top of any
# existing com.chill.app it finds registered with Launch Services (e.g. a dev
# build under .build/) instead of installing to /Applications. That leaves
# /Applications/Chill.app absent and the app never opens. We generate a
# component plist and force BundleIsRelocatable = false for every bundle.
COMPONENT_PLIST="$WORKDIR/component.plist"
pkgbuild --analyze --root "$PAYLOAD" "$COMPONENT_PLIST"
python3 - "$COMPONENT_PLIST" <<'PY'
import sys, plistlib
path = sys.argv[1]
with open(path, "rb") as f:
    components = plistlib.load(f)
for c in components:
    c["BundleIsRelocatable"] = False
with open(path, "wb") as f:
    plistlib.dump(components, f)
PY

PKGBUILD_ARGS=(
    --root "$PAYLOAD"
    --component-plist "$COMPONENT_PLIST"
    --scripts "$SCRIPTS"
    --identifier "$PACKAGE_ID"
    --version "$VERSION"
    --install-location /
)
if [ -n "$INSTALLER_SIGN_IDENTITY" ]; then
    PKGBUILD_ARGS+=(
        --sign "$INSTALLER_SIGN_IDENTITY"
        --timestamp
    )
fi

echo "Building installer package..."
pkgbuild "${PKGBUILD_ARGS[@]}" "$PKG_PATH"

if [ -n "$NOTARY_PROFILE" ]; then
    echo "Submitting package for notarization..."
    xcrun notarytool submit "$PKG_PATH" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait

    echo "Stapling notarization ticket..."
    xcrun stapler staple "$PKG_PATH"
    xcrun stapler validate "$PKG_PATH"
fi

echo "Created $PKG_PATH"
