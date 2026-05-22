#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.02}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

swift build -c release

APP_DIR="dist/EfficientTime.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp ".build/release/EfficientTimeApp" "$MACOS_DIR/EfficientTime"
chmod +x "$MACOS_DIR/EfficientTime"
if [[ -f "Resources/AppIcon.icns" ]]; then
  cp "Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleExecutable</key>
  <string>EfficientTime</string>
  <key>CFBundleIdentifier</key>
  <string>local.zhangjinyang.EfficientTime</string>
  <key>CFBundleName</key>
  <string>EfficientTime</string>
  <key>CFBundleDisplayName</key>
  <string>EfficientTime</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_NUMBER}</string>
  <key>LSMinimumSystemVersion</key>
  <string>15.0</string>
  <key>LSUIElement</key>
  <false/>
  <key>NSMicrophoneUsageDescription</key>
  <string>EfficientTime 需要使用麦克风把语音计划转成文本。</string>
  <key>NSSpeechRecognitionUsageDescription</key>
  <string>EfficientTime 需要使用系统语音识别把口述计划转成文本。</string>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 EfficientTime.</string>
</dict>
</plist>
PLIST

echo "$APP_DIR"
