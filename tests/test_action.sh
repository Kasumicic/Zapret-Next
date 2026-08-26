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
die(){ echo "$*" >&2; return 1; }
zapret_set_logging(){ :; }
zapret_set_strategy(){ :; }
EOF
cat >"$CASE/zapret" <<'EOF'
#!/bin/sh
echo "$*" >"${0%/*}/data/called"
EOF
chmod 755 "$CASE/action.sh" "$CASE/zapret"
sh "$CASE/action.sh"
[ "$(cat "$CASE/data/called")" = toggle ]
echo start >"$CASE/data/action.request"
: >"$CASE/data/action.busy"
sh "$CASE/action.sh"
[ "$(cat "$CASE/data/called")" = start ]
[ ! -e "$CASE/data/action.busy" ]
echo OK
