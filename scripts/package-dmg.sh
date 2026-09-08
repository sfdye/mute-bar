#!/bin/bash
# Build and package MuteBar.dmg for distribution.
# Usage: scripts/package-dmg.sh [output.dmg]
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="${1:-.build/MuteBar.dmg}"
# Only build if the app bundle is absent — rebuilding here would wipe a
# Developer ID signature applied by sign-release.sh.
[[ -d .build/app/MuteBar.app ]] || scripts/build-app.sh >/dev/null

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -R .build/app/MuteBar.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"

rm -f "$OUT"
hdiutil create -volname MuteBar -srcfolder "$STAGE" -ov -format UDZO "$OUT" >/dev/null
echo "packaged: $OUT"
