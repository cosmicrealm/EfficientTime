#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-0.01}"
APP_DIR="dist/EfficientTime.app"
ZIP_PATH="dist/EfficientTime-${VERSION}-macOS.zip"
DMG_STAGING_DIR="dist/dmg-staging"
DMG_PATH="dist/EfficientTime-${VERSION}.dmg"

"$(dirname "$0")/build_app_bundle.sh"

rm -f "$ZIP_PATH"
ditto -c -k --keepParent --norsrc --noextattr "$APP_DIR" "$ZIP_PATH"

rm -rf "$DMG_STAGING_DIR"
mkdir -p "$DMG_STAGING_DIR"
ditto --norsrc --noextattr "$APP_DIR" "$DMG_STAGING_DIR/EfficientTime.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "EfficientTime ${VERSION}" \
  -srcfolder "$DMG_STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

rm -rf "$DMG_STAGING_DIR"

echo "$ZIP_PATH"
echo "$DMG_PATH"
