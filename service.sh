#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/lib/zapret.sh"
rotate_log

if [ "$ENABLED" != 1 ]; then
  set_module_status stopped
  [ "$LOGGING" = 1 ] && log "Boot start skipped: module was manually stopped" >>"$LOG_FILE"
  exit 0
fi

# Android late_start can run before networking is usable.
i=0
while [ "$(getprop sys.boot_completed)" != 1 ] && [ "$i" -lt 120 ]; do
  sleep 2
  i=$((i + 1))
done

if [ "${AUTO_UPDATE:-0}" = 1 ]; then
  last=$(cat "$MODDIR/data/last_update" 2>/dev/null || echo 0)
  now=$(date +%s)
  if [ $((now - last)) -ge $((UPDATE_HOURS * 3600)) ]; then
    if [ "$LOGGING" = 1 ]; then zapret_update >>"$LOG_FILE" 2>&1
    else zapret_update >/dev/null 2>&1
    fi
  fi
fi
if [ "$LOGGING" = 1 ]; then zapret_start >>"$LOG_FILE" 2>&1
else zapret_start >/dev/null 2>&1
fi
