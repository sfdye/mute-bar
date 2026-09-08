#!/bin/bash
# Smoke test without a browser: app <-> host round trip over the native
# messaging framing. Verifies the socket server, the host relay, and the
# ping/pong keepalive.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=.build/app/MuteBar.app
[ -x "$APP/Contents/MacOS/MuteBar" ] || scripts/build-app.sh >/dev/null

SOCK="$HOME/Library/Application Support/MuteBar/socket"
rm -f "$SOCK"

"$APP/Contents/MacOS/MuteBar" > /tmp/mutebar-smoke.log 2>&1 &
APP_PID=$!
trap 'kill $APP_PID 2>/dev/null || true' EXIT

for i in $(seq 1 20); do [ -S "$SOCK" ] && break; sleep 0.2; done
[ -S "$SOCK" ] || { echo "FAIL: socket never appeared"; exit 1; }

RESULT=$(python3 - <<'EOF'
import struct, subprocess, json
def frame(obj):
    b = json.dumps(obj).encode()
    return struct.pack('<I', len(b)) + b
p = subprocess.run([".build/app/MuteBar.app/Contents/MacOS/mutebar-host"],
                   input=frame({"type": "ping"}) + frame({"type": "toggle"}),
                   capture_output=True, timeout=10)
out, i = p.stdout, 0
replies = []
while i + 4 <= len(out):
    n = struct.unpack('<I', out[i:i+4])[0]
    replies.append(json.loads(out[i+4:i+4+n]))
    i += 4 + n
print(json.dumps(replies))
EOF
)

echo "$RESULT"
echo "$RESULT" | grep -q '"pong"' || { echo "FAIL: no pong"; exit 1; }
grep -q "toggle" /tmp/mutebar-smoke.log || { echo "FAIL: app never received toggle"; exit 1; }
echo "SMOKE TEST PASSED"
