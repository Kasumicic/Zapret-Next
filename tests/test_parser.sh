#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TMPDIR=${TMPDIR:-/tmp}
case_file="$TMPDIR/zapret-parser-$$.bat"
trap 'rm -f "$case_file"' EXIT
cat >"$case_file" <<'EOF'
start "zapret" "%BIN%winws.exe" --wf-tcp=80,443 --wf-udp=443 ^
--filter-tcp=443 --hostlist="%LISTS%list.txt" --dpi-desync-fake-tls="%BIN%\fake.bin" --dpi-desync=fake --new ^
--filter-udp=443 --dpi-desync=fake
EOF
MODDIR=$ROOT . "$ROOT/lib/zapret.sh"
out=$(parse_strategy "$case_file")
echo "$out" | grep -q -- '--filter-tcp=443'
echo "$out" | grep -q -- "$ROOT/data/lists/list.txt"
echo "$out" | grep -q -- "$ROOT/data/bin/fake.bin"
! echo "$out" | grep -q '\\'
! echo "$out" | grep -q -- '--wf-tcp'
[ "$(strategy_ports "$case_file" tcp)" = 80,443 ]
mkdir -p "$ROOT/data/strategies"
touch "$ROOT/data/strategies/general (ALT).bat"
trap 'rm -f "$case_file" "$ROOT/data/strategies/general (ALT).bat" "$ROOT/config.conf"; rmdir "$ROOT/data/strategies" "$ROOT/data" 2>/dev/null || true' EXIT
cp "$ROOT/config.conf.example" "$ROOT/config.conf"
zapret_set_strategy 'general (ALT).bat' >/dev/null
grep -qx "STRATEGY='general (ALT).bat'" "$ROOT/config.conf"
(unset ZAPRET_LIB_LOADED; . "$ROOT/lib/zapret.sh"; [ "$STRATEGY" = 'general (ALT).bat' ])
echo OK
