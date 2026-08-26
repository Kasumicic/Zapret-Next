#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
CASE=$(mktemp -d)
trap 'rm -rf "$CASE"' EXIT
mkdir -p "$CASE/lib" "$CASE/data"
cp "$ROOT/action.sh" "$CASE/action.sh"
cat >"$CASE/lib/zapret.sh" <<'EOF'
LOGGING=0
DATA="$MODDIR/data"
LOG_FILE="$DATA/zapret.log"
STRATEGY='general (ALT).bat'
die(){ echo "$*" >&2; return 1; }
zapret_set_logging(){ :; }
zapret_set_strategy(){ :; }
zapret_set_mode(){ echo "$1" >"$DATA/mode"; }
nfqws_running(){ [ -e "$DATA/running" ]; }
rotate_log(){ :; }
EOF
cat >"$CASE/zapret" <<'EOF'
#!/bin/sh
echo "$*" >"${0%/*}/data/called"
case "$1" in start) : >"${0%/*}/data/running";; stop) rm -f "${0%/*}/data/running";; esac
EOF
chmod 755 "$CASE/action.sh" "$CASE/zapret"
message=$(sh "$CASE/action.sh")
[ "$(cat "$CASE/data/called")" = start ]
[ "$message" = '🟢 Zapret запущен | Стратегия: general (ALT).bat' ]
message=$(sh "$CASE/action.sh")
[ "$(cat "$CASE/data/called")" = stop ]
[ "$message" = '🔴 Zapret остановлен' ]
echo start >"$CASE/data/action.request"
: >"$CASE/data/action.busy"
sh "$CASE/action.sh"
[ "$(cat "$CASE/data/called")" = start ]
[ ! -e "$CASE/data/action.busy" ]
echo mode >"$CASE/data/action.request"
echo domains >"$CASE/data/action.mode"
sh "$CASE/action.sh"
[ "$(cat "$CASE/data/mode")" = domains ]
[ "$(cat "$CASE/data/called")" = restart ]
echo OK
