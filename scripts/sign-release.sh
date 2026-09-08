#!/bin/bash
# Sign, notarize, staple, and package a release locally.
#
# Usage: scripts/sign-release.sh "Developer ID Application: Liuyang Wan (TEAMID)"
#
# Notarytool credentials: either a stored keychain profile
#   xcrun notarytool store-credentials mutebar-notary --apple-id ... --team-id ...
# or pass env vars APPLE_ID / APPLE_APP_PASSWORD / APPLE_TEAM_ID.
set -euo pipefail
cd "$(dirname "$0")/.."

IDENTITY="${1:?usage: scripts/sign-release.sh \"Developer ID Application: Name (TEAMID)\"}"
PROFILE="${NOTARY_PROFILE:-mutebar-notary}"

scripts/build-app.sh

echo "==> codesign ($IDENTITY)"
codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" .build/app/MuteBar.app

echo "==> package"
scripts/package-dmg.sh .build/MuteBar.dmg

echo "==> notarize"
if [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_APP_PASSWORD:-}" ] && [ -n "${APPLE_TEAM_ID:-}" ]; then
  xcrun notarytool submit .build/MuteBar.dmg \
    --apple-id "$APPLE_ID" --password "$APPLE_APP_PASSWORD" --team-id "$APPLE_TEAM_ID" --wait
else
  xcrun notarytool submit .build/MuteBar.dmg --keychain-profile "$PROFILE" --wait
fi

echo "==> staple"
xcrun stapler staple .build/MuteBar.dmg

echo "==> done: .build/MuteBar.dmg (signed + notarized + stapled)"
echo "    create the release with: gh release create vX.Y.Z .build/MuteBar.dmg --generate-notes"
