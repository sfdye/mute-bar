#!/bin/bash
# Generates resources/AppIcon.icns (the macOS app icon) from the same
# SF Symbols tile design as the extension icons. Committed, like extension/icons.
set -euo pipefail
cd "$(dirname "$0")/.."

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

swift scripts/gen-icons.swift "$STAGE" 16 32 64 128 256 512 1024 >/dev/null

ICONSET="$STAGE/AppIcon.iconset"
mkdir "$ICONSET"
ln "$STAGE/icon16.png" "$ICONSET/icon_16x16.png"
ln "$STAGE/icon32.png" "$ICONSET/icon_16x16@2x.png"
ln "$STAGE/icon32.png" "$ICONSET/icon_32x32.png"
ln "$STAGE/icon64.png" "$ICONSET/icon_32x32@2x.png"
ln "$STAGE/icon128.png" "$ICONSET/icon_128x128.png"
ln "$STAGE/icon256.png" "$ICONSET/icon_128x128@2x.png"
ln "$STAGE/icon256.png" "$ICONSET/icon_256x256.png"
ln "$STAGE/icon512.png" "$ICONSET/icon_256x256@2x.png"
ln "$STAGE/icon512.png" "$ICONSET/icon_512x512.png"
ln "$STAGE/icon1024.png" "$ICONSET/icon_512x512@2x.png"

mkdir -p resources
iconutil -c icns -o resources/AppIcon.icns "$ICONSET"
echo "wrote resources/AppIcon.icns"
