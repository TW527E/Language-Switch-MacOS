#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${1:-$ROOT/Resources/AppIcon.png}"
OUTPUT="${2:-$ROOT/dist/AppIcon.icns}"
ICONSET="$(mktemp -d "${TMPDIR:-/tmp}/shiftinput-icon.XXXXXX")/AppIcon.iconset"

cleanup() {
    rm -rf "$(dirname "$ICONSET")"
}
trap cleanup EXIT

[[ -f "$SOURCE" ]] || { echo "Missing icon source: $SOURCE" >&2; exit 1; }
mkdir -p "$ICONSET" "$(dirname "$OUTPUT")"

make_icon() {
    local pixels="$1"
    local filename="$2"
    sips -z "$pixels" "$pixels" "$SOURCE" --out "$ICONSET/$filename" >/dev/null
}

make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
make_icon 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET" -o "$OUTPUT"
echo "Built icon: $OUTPUT"
