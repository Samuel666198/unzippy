#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"
APP_NAME="轻解压"
APP="$ROOT/build/$APP_NAME.app"

echo "==> Building Swift package ($CONFIG)"
swift build -c "$CONFIG" --arch arm64 --arch x86_64 --product Unzippy
swift build -c "$CONFIG" --arch arm64 --arch x86_64 --product unzippy-cli
BIN_DIR="$(swift build -c "$CONFIG" --arch arm64 --arch x86_64 --show-bin-path)"

echo "==> Preparing icon"
if [ ! -f "$ROOT/Resources/AppIcon.icns" ] || [ "$ROOT/scripts/make-icon.swift" -nt "$ROOT/Resources/AppIcon.icns" ]; then
    swift "$ROOT/scripts/make-icon.swift" "$ROOT/Resources/icon-1024.png"
    ICONSET="$ROOT/build/AppIcon.iconset"
    rm -rf "$ICONSET"
    mkdir -p "$ICONSET"
    for entry in "16:16x16" "32:16x16@2x" "32:32x32" "64:32x32@2x" "128:128x128" "256:128x128@2x" "256:256x256" "512:256x256@2x" "512:512x512" "1024:512x512@2x"; do
        pixels="${entry%%:*}"
        name="${entry##*:}"
        sips -z "$pixels" "$pixels" "$ROOT/Resources/icon-1024.png" --out "$ICONSET/icon_${name}.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o "$ROOT/Resources/AppIcon.icns"
    rm -rf "$ICONSET"
fi

echo "==> Assembling $APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Helpers"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$BIN_DIR/Unzippy" "$APP/Contents/MacOS/Unzippy"
cp "$BIN_DIR/unzippy-cli" "$APP/Contents/Helpers/unzippy-cli"
chmod +x "$APP/Contents/MacOS/Unzippy" "$APP/Contents/Helpers/unzippy-cli"
printf 'APPL????' > "$APP/Contents/PkgInfo"

if [ -f "$ROOT/README.md" ]; then
    cp "$ROOT/README.md" "$APP/Contents/Resources/README.md"
fi

echo "==> Signing (ad-hoc)"
codesign --force --deep --sign - --identifier com.samuel.unzippy "$APP"
codesign --verify --deep --strict "$APP"

echo "==> Done: $APP"
du -sh "$APP"
