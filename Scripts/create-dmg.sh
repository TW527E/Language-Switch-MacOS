#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ShiftInput"
VERSION="${VERSION:-0.2.0}"
DIST="$ROOT/dist"
APP="$DIST/$APP_NAME.app"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/shiftinput-dmg.XXXXXX")"

cleanup() {
    rm -rf "$STAGING"
}
trap cleanup EXIT

"$ROOT/Scripts/build-app.sh"

mkdir -p "$STAGING"
ditto "$APP" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -format UDZO \
    -ov \
    "$DMG"

hdiutil verify "$DMG"
echo "Built: $DMG"
