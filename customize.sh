#!/system/bin/sh
SKIPUNZIP=0

ui_print "- Installing Zapret-Next"
mkdir -p "$MODPATH/data/strategies" "$MODPATH/data/lists" "$MODPATH/bin"

abi=$(getprop ro.product.cpu.abi)
[ -n "$abi" ] || abi=$(uname -m)
case "$abi" in
  arm64-v8a|aarch64) payload_abi=arm64-v8a ;;
  armeabi-v7a|armeabi|armv7l|armv8l) payload_abi=armeabi-v7a ;;
  *) abort "! Unsupported architecture: $abi (arm64/arm only)" ;;
esac

[ -f "$MODPATH/payload/bin/$payload_abi/nfqws" ] || abort "! nfqws for $payload_abi is missing from ZIP"
cp "$MODPATH/payload/bin/$payload_abi/nfqws" "$MODPATH/bin/nfqws"
cp -R "$MODPATH/payload/data/." "$MODPATH/data/"
rm -rf "$MODPATH/payload"
touch "$MODPATH/data/lists/list-general-user.txt" \
  "$MODPATH/data/lists/list-exclude-user.txt" \
  "$MODPATH/data/lists/ipset-exclude-user.txt"

if [ ! -f "$MODPATH/config.conf" ]; then
  cp "$MODPATH/config.conf.example" "$MODPATH/config.conf"
else
  # Migrate strategy names previously written without shell quotes.
  strategy=$(sed -n 's/^STRATEGY=//p' "$MODPATH/config.conf" | head -n 1)
  case "$strategy" in
    "'"*"'") ;;
    *"'"*) strategy=general.bat ;;
    *) tmp="$MODPATH/config.conf.tmp"
       sed "s|^STRATEGY=.*|STRATEGY='$strategy'|" "$MODPATH/config.conf" >"$tmp" && mv "$tmp" "$MODPATH/config.conf" ;;
  esac
fi

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/zapret" 0 0 0755
set_perm "$MODPATH/lib/zapret.sh" 0 0 0755
set_perm "$MODPATH/system/bin/zapret" 0 0 0755
set_perm "$MODPATH/bin/nfqws" 0 0 0755

ui_print "- Architecture: $abi"
ui_print "- Strategies, lists, dumps and nfqws installed offline"
ui_print "- After reboot open WebUI or run: su -c zapret"
