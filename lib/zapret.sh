#!/system/bin/sh
# Shared runtime. Kept POSIX-compatible for Android's shell and BusyBox ash.
[ -n "${ZAPRET_LIB_LOADED:-}" ] && return 0
ZAPRET_LIB_LOADED=1

MODDIR=${MODDIR:-${0%/*}}
if [ -f "$MODDIR/config.conf" ]; then . "$MODDIR/config.conf"
else . "$MODDIR/config.conf.example"
fi
: "${LOGGING:=1}"
DATA="$MODDIR/data"
BIN="$MODDIR/bin/nfqws"
PID_FILE="$DATA/nfqws.pid"
LOG_FILE="$DATA/zapret.log"
CHAIN=ZAPRET_ANDROID
PRE_CHAIN=ZAPRET_ANDROID_PRE
# Never send local, VPN or tunnel traffic to nfqws.
TUNNEL_INTERFACES='lo tun+ utun+ tap+ wg+ ppp+ ipsec+ vti+ xfrm+ gre+ gretap+ ipip+ sit+ ip6tnl+ tailscale+ zt+'
V2RAY_CHAIN=CORE_FILTER
V2RAY_MARKS='0x1 0xff'

if [ -x /data/adb/ksu/bin/busybox ]; then BB=/data/adb/ksu/bin/busybox
elif [ -x /data/adb/magisk/busybox ]; then BB=/data/adb/magisk/busybox
else BB=busybox
fi

log() { echo "[$(date '+%F %T')] $*"; }
die() { log "ERROR: $*" >&2; return 1; }
download() {
  url=$1 out=$2
  if command -v curl >/dev/null 2>&1; then curl -fL --connect-timeout 20 "$url" -o "$out"
  else "$BB" wget -T 20 -O "$out" "$url"
  fi
}

save_config() {
  tmp="$DATA/config.tmp"
  sed "s|^STRATEGY=.*|STRATEGY='$STRATEGY'|" "$MODDIR/config.conf" >"$tmp" && mv "$tmp" "$MODDIR/config.conf"
}

save_setting() {
  key=$1 value=$2 tmp="$DATA/config.tmp"
  if grep -q "^$key=" "$MODDIR/config.conf"; then
    sed "s|^$key=.*|$key=$value|" "$MODDIR/config.conf" >"$tmp"
  else
    cp "$MODDIR/config.conf" "$tmp" && echo "$key=$value" >>"$tmp"
  fi
  mv "$tmp" "$MODDIR/config.conf"
}

zapret_set_logging() {
  case "$1" in on|1) LOGGING=1;; off|0) LOGGING=0;; *) die "logging: use on/off"; return 1;; esac
  save_setting LOGGING "$LOGGING"
  [ "$LOGGING" = 1 ] && log "Logging enabled" >>"$LOG_FILE" || : >"$LOG_FILE"
}

zapret_logging_status() { [ "$LOGGING" = 1 ] && echo on || echo off; }

v2ray_uids() {
  if command -v cmd >/dev/null 2>&1; then packages=$(cmd package list packages -U 2>/dev/null)
  elif command -v pm >/dev/null 2>&1; then packages=$(pm list packages -U 2>/dev/null)
  else return
  fi
  printf '%s\n' "$packages" | sed -n 's/^package:com\.v2ray\.ang[^ ]* uid:\([0-9][0-9]*\)$/\1/p'
}

zapret_list() { find "$DATA/strategies" -maxdepth 1 -type f -name '*.bat' -exec basename {} \; 2>/dev/null | sort; }
zapret_set_strategy() {
  case "$1" in */*|*..*|*"'"*) die "Invalid strategy name"; return 1;; esac
  name=$1; [ -f "$DATA/strategies/$name" ] || [ -f "$DATA/strategies/$name.bat" ] && name=${name%.bat}.bat
  [ -f "$DATA/strategies/$name" ] || { die "Strategy not found: $1"; return 1; }
  STRATEGY=$name; save_config; log "Selected $name"
}

# Converts Flowseal's single winws command into nfqws arguments.
parse_strategy() {
  file=$1
  content=$(tr -d '\r' <"$file" | sed -n '/winws\.exe/,$p' | sed 's/[[:space:]]*\^[[:space:]]*$//')
  [ -n "$content" ] || { die "winws.exe command not found in $file"; return 1; }
  content=$(printf '%s\n' "$content" | tr '\n' ' ' | sed \
    -e 's/.*winws\.exe"[[:space:]]*//' -e 's/.*winws\.exe[[:space:]]*//' \
    -e 's/--wf-tcp=[^ ]*[[:space:]]*//' -e 's/--wf-udp=[^ ]*[[:space:]]*//' \
    -e 's/%GameFilterTCP%/1024-65535/g' -e 's/%GameFilterUDP%/1024-65535/g' \
    -e "s|%BIN%|$DATA/bin/|g" -e "s|%LISTS%|$DATA/lists/|g" \
    -e 's|\\|/|g' -e 's|//*|/|g' -e 's/"//g' -e 's/ -ipset-/ --ipset-/g')
  printf '%s\n' "$content"
}

strategy_ports() {
  tr -d '\r' <"$1" | sed -n 's/.*--wf-'"$2"'=\([^ ]*\).*/\1/p' | head -n1 | \
    sed -e 's/%GameFilterTCP%/1024-65535/g' -e 's/%GameFilterUDP%/1024-65535/g' -e 's/,$//' -e 's/^,//'
}

ipt_clear() {
  cmd=$1
  "$cmd" -t mangle -D OUTPUT -j "$CHAIN" 2>/dev/null
  "$cmd" -t mangle -D PREROUTING -j "$PRE_CHAIN" 2>/dev/null
  "$cmd" -t mangle -F "$CHAIN" 2>/dev/null
  "$cmd" -t mangle -X "$CHAIN" 2>/dev/null
  "$cmd" -t mangle -F "$PRE_CHAIN" 2>/dev/null
  "$cmd" -t mangle -X "$PRE_CHAIN" 2>/dev/null
  return 0
}

ipt_setup() {
  cmd=$1 tcp=$2 udp=$3
  ipt_clear "$cmd"
  "$cmd" -t mangle -N "$CHAIN" || return 1
  for tunnel in $TUNNEL_INTERFACES; do
    "$cmd" -t mangle -A "$CHAIN" -o "$tunnel" -j RETURN || return 1
  done
  # nfqws marks reinjected packets; returning them prevents an NFQUEUE loop.
  "$cmd" -t mangle -A "$CHAIN" -m mark --mark "$FW_MARK" -j RETURN || return 1
  for uid in $(v2ray_uids); do
    "$cmd" -t mangle -A "$CHAIN" -m owner --uid-owner "$uid" -j RETURN || return 1
  done
  # Run v2rayNG's root chain first even when v2rayNG starts after this module.
  "$cmd" -t mangle -N "$V2RAY_CHAIN" 2>/dev/null || true
  "$cmd" -t mangle -A "$CHAIN" -j "$V2RAY_CHAIN" || return 1
  for mark in $V2RAY_MARKS; do
    "$cmd" -t mangle -A "$CHAIN" -m mark --mark "$mark" -j RETURN || return 1
  done
  iface=""; [ "$INTERFACE" != any ] && iface="-o $INTERFACE"
  [ -n "$tcp" ] && "$cmd" -t mangle -A "$CHAIN" $iface -p tcp -m multiport --dports "$(echo "$tcp" | tr '-' ':')" -j NFQUEUE --queue-num "$QUEUE_NUM" --queue-bypass
  [ -n "$udp" ] && "$cmd" -t mangle -A "$CHAIN" $iface -p udp -m multiport --dports "$(echo "$udp" | tr '-' ':')" -j NFQUEUE --queue-num "$QUEUE_NUM" --queue-bypass
  "$cmd" -t mangle -A OUTPUT -j "$CHAIN" || return 1
  # PREROUTING handles forwarded/hotspot traffic; only original destination ports match.
  "$cmd" -t mangle -N "$PRE_CHAIN" || return 1
  for tunnel in $TUNNEL_INTERFACES; do
    "$cmd" -t mangle -A "$PRE_CHAIN" -i "$tunnel" -j RETURN || return 1
  done
  for mark in $V2RAY_MARKS; do
    "$cmd" -t mangle -A "$PRE_CHAIN" -m mark --mark "$mark" -j RETURN || return 1
  done
  [ -n "$tcp" ] && "$cmd" -t mangle -A "$PRE_CHAIN" -p tcp -m multiport --dports "$(echo "$tcp" | tr '-' ':')" -m mark ! --mark "$FW_MARK" -j NFQUEUE --queue-num "$QUEUE_NUM" --queue-bypass
  [ -n "$udp" ] && "$cmd" -t mangle -A "$PRE_CHAIN" -p udp -m multiport --dports "$(echo "$udp" | tr '-' ':')" -m mark ! --mark "$FW_MARK" -j NFQUEUE --queue-num "$QUEUE_NUM" --queue-bypass
  "$cmd" -t mangle -A PREROUTING -j "$PRE_CHAIN"
}

firewall_clear() {
  ipt_clear iptables
  command -v ip6tables >/dev/null 2>&1 && ipt_clear ip6tables
  command -v nft >/dev/null 2>&1 && nft delete table inet zapret_android 2>/dev/null
  return 0
}

firewall_setup() {
  tcp=$1 udp=$2
  if [ "$FIREWALL" != nft ] && command -v iptables >/dev/null 2>&1; then
    ipt_setup iptables "$tcp" "$udp" || return 1
    command -v ip6tables >/dev/null 2>&1 && ipt_setup ip6tables "$tcp" "$udp"
    return
  fi
  command -v nft >/dev/null 2>&1 || { die "iptables/nft not found"; return 1; }
  nft delete table inet zapret_android 2>/dev/null
  nft add table inet zapret_android
  # Run after iptables mangle/OUTPUT, where v2rayNG applies its route mark.
  nft 'add chain inet zapret_android out { type filter hook output priority -140; }'
  for tunnel in $TUNNEL_INTERFACES; do
    nft add rule inet zapret_android out oifname "${tunnel%+}*" return
  done
  nft add rule inet zapret_android out meta mark "$FW_MARK" return
  for uid in $(v2ray_uids); do
    nft add rule inet zapret_android out meta skuid "$uid" return
  done
  nft add rule inet zapret_android out meta mark "{ 0x1, 0xff }" return
  [ -n "$tcp" ] && nft add rule inet zapret_android out tcp dport "{ $tcp }" queue num "$QUEUE_NUM" bypass
  [ -n "$udp" ] && nft add rule inet zapret_android out udp dport "{ $udp }" queue num "$QUEUE_NUM" bypass
  nft 'add chain inet zapret_android pre { type filter hook prerouting priority -140; }'
  for tunnel in $TUNNEL_INTERFACES; do
    nft add rule inet zapret_android pre iifname "${tunnel%+}*" return
  done
  nft add rule inet zapret_android pre meta mark "{ 0x1, 0xff }" return
  [ -n "$tcp" ] && nft add rule inet zapret_android pre tcp dport "{ $tcp }" meta mark != "$FW_MARK" queue num "$QUEUE_NUM" bypass
  [ -n "$udp" ] && nft add rule inet zapret_android pre udp dport "{ $udp }" meta mark != "$FW_MARK" queue num "$QUEUE_NUM" bypass
}

zapret_stop() {
  old_pid=$(cat "$PID_FILE" 2>/dev/null)
  log "Stop requested: pid=${old_pid:-none}; clearing firewall rules"
  [ -f "$PID_FILE" ] && kill "$(cat "$PID_FILE")" 2>/dev/null
  pkill -f "$MODDIR/bin/nfqws" 2>/dev/null
  rm -f "$PID_FILE"
  firewall_clear
  log "Stopped: process and firewall rules removed"
}

nfqws_running() {
  [ -f "$PID_FILE" ] || return 1
  pid=$(cat "$PID_FILE" 2>/dev/null)
  case "$pid" in ''|*[!0-9]*) rm -f "$PID_FILE"; return 1;; esac
  [ -r "/proc/$pid/stat" ] || { rm -f "$PID_FILE"; return 1; }
  state=$(sed 's/.*) \([^ ]\).*/\1/' "/proc/$pid/stat" 2>/dev/null)
  [ "$state" != Z ] || { rm -f "$PID_FILE"; return 1; }
  tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -Fq "$BIN" || { rm -f "$PID_FILE"; return 1; }
}

zapret_start() {
  log "Start requested: strategy=$STRATEGY; abi=$(uname -m); interface=$INTERFACE; queue=$QUEUE_NUM"
  [ -x "$BIN" ] || { die "nfqws missing; run: zapret update"; return 1; }
  strategy="$DATA/strategies/$STRATEGY"
  [ -f "$strategy" ] || { die "Strategy missing: $STRATEGY; run update/list"; return 1; }
  args=$(parse_strategy "$strategy") || return 1
  tcp=$(strategy_ports "$strategy" tcp); udp=$(strategy_ports "$strategy" udp)
  [ -n "$tcp$udp" ] || { die "No --wf-tcp/udp ports in strategy"; return 1; }
  if [ "$FIREWALL" != nft ] && command -v iptables >/dev/null 2>&1; then firewall=iptables
  else firewall=nft
  fi
  log "Parsed strategy: tcp=${tcp:-none}; udp=${udp:-none}; firewall=$firewall"
  log "nfqws arguments: $args"
  zapret_stop >/dev/null 2>&1
  log "Preparing data permissions and $firewall rules"
  chmod -R 755 "$DATA" || { die "Cannot set data permissions"; return 1; }
  firewall_setup "$tcp" "$udp" || { firewall_clear; die "Firewall setup failed (NFQUEUE kernel support required)"; return 1; }
  log "Firewall ready; launching nfqws as uid=0:0"
  cd "$DATA" || return 1
  # Strategy files are trusted input downloaded from the configured repository.
  "$BIN" --uid=0:0 --daemon --pidfile="$PID_FILE" --qnum="$QUEUE_NUM" --dpi-desync-fwmark="$FW_MARK" $args || { firewall_clear; return 1; }
  log "Started: strategy=$STRATEGY; pid=$(cat "$PID_FILE" 2>/dev/null); tcp=${tcp:-none}; udp=${udp:-none}"
}

zapret_toggle() {
  if nfqws_running; then
    log "Toggle requested: service is running, stopping"
    zapret_stop
  else
    log "Toggle requested: service is stopped, starting last strategy $STRATEGY"
    zapret_start
  fi
}

zapret_status() {
  if nfqws_running; then echo "running, PID $(cat "$PID_FILE"), $STRATEGY"
  else echo "stopped, $STRATEGY"; return 1
  fi
}

zapret_update() {
  mkdir -p "$DATA/strategies" "$DATA/lists" "$DATA/bin" "$MODDIR/bin"
  tmp="$DATA/update.$$"; mkdir "$tmp" || return 1
  trap 'rm -rf "$tmp"' EXIT INT TERM
  if [ "$SOURCE" = sergeydigl3 ]; then repo=Sergeydigl3/zapret-discord-youtube-linux; branch=master
  else repo=Flowseal/zapret-discord-youtube; branch=main
  fi
  log "Downloading strategies from $repo"
  download "https://github.com/$repo/archive/refs/heads/$branch.tar.gz" "$tmp/strategies.tgz" || return 1
  "$BB" tar -xzf "$tmp/strategies.tgz" -C "$tmp" || return 1
  root=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n1)
  find "$root" -type f -name '*.bat' -exec cp {} "$DATA/strategies/" \;
  [ -d "$root/lists" ] && cp -R "$root/lists/." "$DATA/lists/"
  [ -d "$root/bin" ] && find "$root/bin" -type f -name '*.bin' -exec cp {} "$DATA/bin/" \;

  log "Downloading official nfqws"
  api="$tmp/release.json"
  download "https://api.github.com/repos/bol-van/zapret/releases/latest" "$api" || return 1
  tag=$(sed -n 's/.*"tag_name"[ ]*:[ ]*"\([^"]*\)".*/\1/p' "$api" | head -n1)
  [ -n "$tag" ] || { die "Cannot resolve zapret release"; return 1; }
  download "https://github.com/bol-van/zapret/releases/download/$tag/zapret-$tag.tar.gz" "$tmp/zapret.tgz" || return 1
  "$BB" tar -xzf "$tmp/zapret.tgz" -C "$tmp" || return 1
  case "$(uname -m)" in aarch64|arm64) platform=linux-arm64;; arm*|aarch32) platform=linux-arm;; x86_64) platform=linux-x86_64;; *) die "Unsupported ABI: $(uname -m)"; return 1;; esac
  nfq=$(find "$tmp" -type f -path "*/binaries/$platform/nfqws" | head -n1)
  [ -n "$nfq" ] || { die "nfqws $platform not found in release"; return 1; }
  cp "$nfq" "$BIN" && chmod 755 "$BIN" || return 1
  date +%s >"$DATA/last_update"
  rm -rf "$tmp"; trap - EXIT INT TERM
  log "Update complete: $tag"
}
