#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="轻解压"
TARGET="/Applications/$APP_NAME.app"

"$ROOT/scripts/build-app.sh" release

echo "==> Installing to /Applications"
osascript -e 'tell application "轻解压" to quit' >/dev/null 2>&1 || true
pkill -x Unzippy >/dev/null 2>&1 || true
sleep 0.4
rm -rf "$TARGET"
ditto "$ROOT/build/$APP_NAME.app" "$TARGET"
xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null || true
open "$TARGET"
echo "==> Installed: $TARGET"
