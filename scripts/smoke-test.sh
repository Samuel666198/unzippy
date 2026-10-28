#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Building CLI"
swift build -c debug --product unzippy-cli >/dev/null
CLI="$(swift build -c debug --product unzippy-cli --show-bin-path)/unzippy-cli"

WORK="$(mktemp -d /tmp/unzippy-smoke.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

pass=0
check() {
    local label="$1"
    shift
    if "$@"; then
        echo "  ✓ $label"
        pass=$((pass + 1))
    else
        echo "  ✗ $label"
        exit 1
    fi
}

# --- fixtures ---------------------------------------------------------------
mkdir -p src/中文目录/空目录
printf 'hello 世界\n' > src/中文目录/测试文件.txt
printf '#!/bin/sh\necho hi\n' > src/run.sh
chmod 755 src/run.sh
ln -s 中文目录/测试文件.txt src/链接
mkdir -p src/sub && printf 'abc\n' > src/sub/b.txt

echo "==> Archive round-trips"
zip -q -r plain.zip src
check "ZIP list" bash -c "'$CLI' list plain.zip | grep -q 'src/中文目录/测试文件.txt'"
"$CLI" extract plain.zip -o out_zip >/dev/null
check "ZIP extract" test -f out_zip/src/中文目录/测试文件.txt
check "ZIP permissions" test -x out_zip/src/run.sh

"$CLI" create out.7z src --format 7z >/dev/null
"$CLI" extract out.7z -o out_7z >/dev/null
check "7Z round-trip" test -f out_7z/src/中文目录/测试文件.txt

"$CLI" create out.tar.gz src --format tgz >/dev/null
"$CLI" extract out.tar.gz -o out_tgz >/dev/null
check "TAR.GZ round-trip" test -f out_tgz/src/sub/b.txt

gzip -c src/中文目录/测试文件.txt > single.txt.gz
"$CLI" extract single.txt.gz -o out_gz >/dev/null
check "GZIP single file" bash -c "grep -q 世界 out_gz/*"

bzip2 -c src/中文目录/测试文件.txt > single.txt.bz2
"$CLI" extract single.txt.bz2 -o out_bz2 >/dev/null
check "BZIP2 single file" bash -c "grep -q 世界 out_bz2/*"

echo "==> Encryption"
zip -q -P secret -r enc.zip src
"$CLI" extract enc.zip -o out_enc --password secret >/dev/null
check "ZipCrypto extract" test -f out_enc/src/中文目录/测试文件.txt
if "$CLI" extract enc.zip -o out_wrong --password nope >/dev/null 2>&1; then
    echo "  ✗ wrong password should fail"; exit 1
else
    echo "  ✓ wrong password rejected"; pass=$((pass + 1))
fi

"$CLI" create aes.zip src --password secret >/dev/null
"$CLI" extract aes.zip -o out_aes --password secret >/dev/null
check "AES-256 ZIP round-trip" test -f out_aes/src/中文目录/测试文件.txt

echo "==> Chinese GBK filenames"
python3 - <<'PY'
import zipfile
gbk_path = "中文目录/测试文件.txt".encode('gbk')
placeholder = b"aaaaaaaa/bbbbbbbb.txt"
assert len(gbk_path) == len(placeholder)
with zipfile.ZipFile('gbk.zip', 'w', zipfile.ZIP_DEFLATED) as z:
    z.writestr(placeholder.decode(), 'chinese gbk\n')
data = open('gbk.zip', 'rb').read().replace(placeholder, gbk_path)
open('gbk.zip', 'wb').write(data)
PY
check "GBK list" bash -c "'$CLI' list gbk.zip | grep -q '中文目录/测试文件.txt'"
"$CLI" extract gbk.zip -o out_gbk >/dev/null
check "GBK extract" test -f out_gbk/中文目录/测试文件.txt

echo "==> Safety"
python3 - <<'PY'
import zipfile, stat
with zipfile.ZipFile('evil.zip', 'w') as z:
    z.writestr('../evil.txt', 'pwned')
    z.writestr('/tmp/unzippy_smoke_abs.txt', 'pwned')
    z.writestr('safe/ok.txt', 'ok')
    info = zipfile.ZipInfo('link')
    info.create_system = 3
    info.external_attr = (stat.S_IFLNK | 0o777) << 16
    z.writestr(info, '/etc/passwd')
PY
rm -f ../evil.txt /tmp/unzippy_smoke_abs.txt
"$CLI" extract evil.zip -o out_safe >/dev/null
check "path traversal blocked" bash -c "! test -f ../evil.txt"
check "safe entry extracted" test -f out_safe/safe/ok.txt
check "absolute symlink blocked" bash -c "! test -L out_safe/link"

echo "==> Conflicts"
"$CLI" extract plain.zip -o out_conflict >/dev/null
"$CLI" extract plain.zip -o out_conflict >/dev/null
check "rename conflict" test -f "out_conflict/src/中文目录/测试文件 (2).txt"

echo
echo "All $pass checks passed."
