#!/bin/bash
# Packages the extension for Chrome Web Store upload.
# Strips the dev-only "key" field (the store assigns its own ID) and zips
# the rest into dist/mutebar-extension-<version>.zip.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=$(python3 -c "import json; print(json.load(open('extension/manifest.json'))['version'])")

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -R extension/ "$STAGE/extension"

python3 - "$STAGE/extension/manifest.json" <<'EOF'
import json, sys
path = sys.argv[1]
manifest = json.load(open(path))
manifest.pop("key", None)
json.dump(manifest, open(path, "w"), indent=2, ensure_ascii=False)
EOF

mkdir -p dist
ZIP="dist/mutebar-extension-$VERSION.zip"
rm -f "$ZIP"
(cd "$STAGE/extension" && zip -qr "$OLDPWD/$ZIP" .)
echo "$ZIP ($(du -h "$ZIP" | cut -f1))"
