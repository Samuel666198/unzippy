#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

"$ROOT/scripts/build-app.sh" release

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
DMG="$ROOT/build/轻解压-$VERSION.dmg"
STAGE="$(mktemp -d /tmp/unzippy-dmg.XXXXXX)"
trap 'rm -rf "$STAGE"' EXIT

mkdir -p "$STAGE/轻解压"
ditto "$ROOT/build/轻解压.app" "$STAGE/轻解压/轻解压.app"
ln -s /Applications "$STAGE/轻解压/Applications"
cat > "$STAGE/轻解压/安装说明.txt" <<'TXT'
轻解压 · Unzippy

1. 把「轻解压.app」拖到右侧的 Applications 文件夹。
2. 首次打开如果被 Gatekeeper 拦截，请右键点击应用 →「打开」。
3. 之后可以直接把压缩包拖到窗口、Dock 图标，或在 Finder 里右键使用「用轻解压打开」。

完全离线，不收集任何数据。
TXT

rm -f "$DMG"
hdiutil create -volname "轻解压" -srcfolder "$STAGE/轻解压" -ov -format UDZO "$DMG" >/dev/null
echo "DMG: $DMG"
du -sh "$DMG"
