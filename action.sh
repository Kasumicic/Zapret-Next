#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/lib/zapret.sh"
REQUEST="$MODDIR/data/action.request"
BUSY="$MODDIR/data/action.busy"

request=$(cat "$REQUEST" 2>/dev/null)
rm -f "$REQUEST"
trap 'rm -f "$BUSY"' EXIT INT TERM

run() {
  if [ "$LOGGING" = 1 ]; then "$MODDIR/zapret" "$@" >>"$LOG_FILE" 2>&1
  else "$MODDIR/zapret" "$@" >/dev/null 2>&1
  fi
}

case "$request" in
  '') run toggle ;;
  start|stop|restart|update) run "$request" ;;
  logging-on) zapret_set_logging on ;;
  logging-off) zapret_set_logging off ;;
  strategy)
    name=$(cat "$MODDIR/data/action.strategy" 2>/dev/null)
    rm -f "$MODDIR/data/action.strategy"
    zapret_set_strategy "$name" && run restart
    ;;
  *) die "Unknown action request: $request" ;;
esac
