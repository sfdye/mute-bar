#!/bin/bash
# Installs the native messaging host manifest for all detected Chromium browsers.
# Usage: scripts/install.sh [path-to-MuteBar.app]  (defaults to /Applications/MuteBar.app)
set -euo pipefail

cd "$(dirname "$0")/.."
REPO="$PWD"

APP="${1:-/Applications/MuteBar.app}"
HOST_BIN="$APP/Contents/MacOS/mutebar-host"

if [[ ! -x "$HOST_BIN" ]]; then
    echo "ERROR: host binary not found at $HOST_BIN" >&2
    echo "Run scripts/build-app.sh first, and pass the app path if it is not in /Applications." >&2
    exit 1
fi

# Stable dev extension ID (derived from the fixed public key in extension/manifest.json)
# and the Chrome Web Store ID (assigned at publishing; the store zip strips the dev key).
EXTENSION_ID="iggmpoondbifidlpilegncmifabajbep"
STORE_EXTENSION_ID="jdnohcgdlpndiinaklmckmaonpjimkfg"
HOST_NAME="com.lwan.mutebar"

MANIFEST=$(cat <<EOF
{
  "name": "$HOST_NAME",
  "description": "MuteBar native host",
  "path": "$HOST_BIN",
  "type": "stdio",
  "allowed_extensions": ["$EXTENSION_ID"],
  "allowed_origins": ["chrome-extension://$EXTENSION_ID/*", "chrome-extension://$STORE_EXTENSION_ID/*"]
}
EOF
)

# browser-name -> native messaging manifest directory
# (Chrome 151+ reads user-level manifests from the user-data-dir; per-browser
# dirs are kept for older builds and other Chromium forks.)
declare -a DIRS=(
    "$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
    "$HOME/Library/Application Support/Arc/User Data/NativeMessagingHosts"
    "$HOME/Library/Application Support/Microsoft Edge/NativeMessagingHosts"
    "$HOME/Library/Application Support/BraveSoftware/Brave-Browser/NativeMessagingHosts"
    "$HOME/Library/Application Support/Chromium/NativeMessagingHosts"
)

INSTALLED=0
for DIR in "${DIRS[@]}"; do
    BROWSER_DIR="${DIR%/NativeMessagingHosts}"
    if [[ -d "$BROWSER_DIR" ]]; then
        mkdir -p "$DIR"
        printf '%s\n' "$MANIFEST" > "$DIR/$HOST_NAME.json"
        echo "installed: $DIR/$HOST_NAME.json"
        INSTALLED=1
    fi
done

if [[ $INSTALLED -eq 0 ]]; then
    echo "No Chromium browser data directories found." >&2
    exit 1
fi

echo ""
echo "Done. Load the unpacked extension: $REPO/extension"
echo "In chrome://extensions (Arc: arc://extensions) enable Developer mode -> Load unpacked."
echo "Then start MuteBar.app and press F6 in a Google Meet call."
