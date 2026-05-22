#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-0.02}"
PATCH_VERSION="${VERSION##*.}"
BUILD_NUMBER="${BUILD_NUMBER:-$((10#$PATCH_VERSION))}"
BUNDLE_ID="${BUNDLE_ID:-com.cosmicrealm.EfficientTime}"
APP_DIR="dist/EfficientTime.app"
PKG_PATH="dist/EfficientTime-${VERSION}-AppStore.pkg"
ENTITLEMENTS_PATH="${ENTITLEMENTS_PATH:-Resources/Entitlements/AppStore.entitlements}"
APP_SIGNING_IDENTITY="${APP_SIGNING_IDENTITY:-}"
INSTALLER_SIGNING_IDENTITY="${INSTALLER_SIGNING_IDENTITY:-}"
PROVISIONING_PROFILE="${PROVISIONING_PROFILE:-}"

if [[ -z "$APP_SIGNING_IDENTITY" ]]; then
  echo "APP_SIGNING_IDENTITY is required, for example: Apple Distribution: Your Name (TEAMID)" >&2
  exit 2
fi

if [[ -z "$INSTALLER_SIGNING_IDENTITY" ]]; then
  echo "INSTALLER_SIGNING_IDENTITY is required, for example: 3rd Party Mac Developer Installer: Your Name (TEAMID)" >&2
  exit 2
fi

if [[ -z "$PROVISIONING_PROFILE" || ! -f "$PROVISIONING_PROFILE" ]]; then
  echo "PROVISIONING_PROFILE must point to the Mac App Store provisioning profile file." >&2
  exit 2
fi

if [[ ! -f "$ENTITLEMENTS_PATH" ]]; then
  echo "Entitlements file not found: $ENTITLEMENTS_PATH" >&2
  exit 2
fi

BUNDLE_ID="$BUNDLE_ID" VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" ./scripts/build_app_bundle.sh

cp "$PROVISIONING_PROFILE" "$APP_DIR/Contents/embedded.provisionprofile"

codesign \
  --force \
  --timestamp \
  --options runtime \
  --entitlements "$ENTITLEMENTS_PATH" \
  --sign "$APP_SIGNING_IDENTITY" \
  "$APP_DIR"

codesign --verify --deep --strict --verbose=2 "$APP_DIR"

rm -f "$PKG_PATH"
productbuild \
  --component "$APP_DIR" /Applications \
  --sign "$INSTALLER_SIGNING_IDENTITY" \
  "$PKG_PATH"

pkgutil --check-signature "$PKG_PATH"

echo "$PKG_PATH"
