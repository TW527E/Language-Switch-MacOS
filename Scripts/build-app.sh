#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
VERSION="${VERSION:-0.2.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
BUILD_ARCHS="${BUILD_ARCHS:-}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
APP_NAME="ShiftInput"
BUNDLE_ID="com.tw527e.ShiftInput"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"

cd "$ROOT"
BUILD_ARGS=(-c "$CONFIGURATION")
if [[ -n "$BUILD_ARCHS" ]]; then
    for arch in $BUILD_ARCHS; do
        BUILD_ARGS+=(--arch "$arch")
    done
fi
swift build "${BUILD_ARGS[@]}"
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
"$ROOT/Scripts/generate-app-icon.sh" "$ROOT/Resources/AppIcon.png" "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>zh_TW</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSAccessibilityUsageDescription</key><string>ShiftInput 需要監聽 Shift 快捷鍵以切換輸入法。</string>
    <key>NSInputMonitoringUsageDescription</key><string>ShiftInput 需要讀取 Shift 快捷鍵以切換輸入法。</string>
    <key>NSHumanReadableCopyright</key><string>Copyright © 2026</string>
</dict>
</plist>
PLIST

plutil -lint "$APP/Contents/Info.plist"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    codesign --force --sign - "$APP"
else
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP"
fi
codesign --verify --deep --strict "$APP"

echo "Built: $APP"
