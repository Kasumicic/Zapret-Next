#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
CASE=$(mktemp -d)
trap 'rm -rf "$CASE"' EXIT
mkdir -p "$CASE/data/strategies" "$CASE/data/lists" "$CASE/data/bin" "$CASE/bin"
cp "$ROOT/config.conf.example" "$CASE/config.conf"
cp "$ROOT/config.conf.example" "$CASE/config.conf.example"
cat >"$CASE/data/strategies/general.bat" <<'EOF'
start "zapret" "%BIN%winws.exe" --wf-tcp=80,443 --wf-udp=443 ^
--filter-tcp=443 --hostlist="%LISTS%list.txt" --dpi-desync=fake
EOF
touch "$CASE/data/lists/list.txt"
cat >"$CASE/bin/nfqws" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >"$CAPTURE"
EOF
chmod 755 "$CASE/bin/nfqws"
chmod 700 "$CASE/data" "$CASE/data/lists/list.txt"
CAPTURE="$CASE/args"; export CAPTURE
MODDIR=$CASE . "$ROOT/lib/zapret.sh"
zapret_set_logging off
[ "$(zapret_logging_status)" = off ]
grep -qx 'LOGGING=0' "$CASE/config.conf"
zapret_set_logging on
[ "$(zapret_logging_status)" = on ]
grep -qx 'LOGGING=1' "$CASE/config.conf"
(
  zapret_stop(){ :; }
  firewall_setup(){ :; }
  firewall_clear(){ :; }
  nfqws_running(){ :; }
  sleep(){ :; }
  zapret_start >"$CASE/start.log"
)
grep -q 'Startup \[1/7\] Request: strategy=general.bat; mode=loaded' "$CASE/start.log"
grep -q 'Startup complete: pid=' "$CASE/start.log"
grep -qx -- '--uid=0:0' "$CAPTURE"
! grep -q -- '--user=' "$CAPTURE"
[ "$(stat -c %a "$CASE/data")" = 755 ]
[ "$(stat -c %a "$CASE/data/lists/list.txt")" = 755 ]

printf '198.51.100.0/24\n' >"$CASE/data/lists/ipset-all.txt"
zapret_set_mode all >/dev/null
[ ! -s "$CASE/data/lists/ipset-all.txt" ]
zapret_set_mode domains >/dev/null
grep -qx '203.0.113.113/32' "$CASE/data/lists/ipset-all.txt"
zapret_set_mode loaded >/dev/null
grep -qx '198.51.100.0/24' "$CASE/data/lists/ipset-all.txt"

LOG_MAX_BYTES=4
printf '12345' >"$LOG_FILE"
rotate_log
[ "$(cat "$LOG_FILE.1")" = 12345 ]
[ ! -e "$LOG_FILE" ]

(
  zapret_stop(){ :; }
  firewall_setup(){ :; }
  firewall_clear(){ : >"$CASE/health-cleared"; }
  nfqws_running(){ return 1; }
  sleep(){ :; }
  ! zapret_start >/dev/null 2>&1
)
[ -e "$CASE/health-cleared" ]

cp "$ROOT/module.prop" "$CASE/module.prop"
set_module_status running
grep -q '^description=🟢 Работает · general.bat · Списки + IP$' "$CASE/module.prop"
(
  firewall_clear(){ :; }
  pkill(){ :; }
  zapret_stop >/dev/null
)
grep -qx 'ENABLED=0' "$CASE/config.conf"
grep -q '^description=🔴 Остановлен' "$CASE/module.prop"
echo $$ >"$PID_FILE"
! nfqws_running
[ ! -e "$PID_FILE" ]

toggle_result=""
nfqws_running(){ [ "$toggle_result" = running ]; }
zapret_start(){ toggle_result=started; }
zapret_stop(){ toggle_result=stopped; }
zapret_toggle >/dev/null
[ "$toggle_result" = started ]
toggle_result=running
zapret_toggle >/dev/null
[ "$toggle_result" = stopped ]

FW_CAPTURE="$CASE/firewall"; export FW_CAPTURE
cat >"$CASE/iptables" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$FW_CAPTURE"
EOF
chmod 755 "$CASE/iptables"
v2ray_uids() { echo 10123; }
ipt_setup "$CASE/iptables" 80,443 443
grep -q -- '-w 5 -t mangle' "$FW_CAPTURE"
grep -q -- '-A ZAPRET_ANDROID -o tun+ -j RETURN' "$FW_CAPTURE"
grep -q -- '-A ZAPRET_ANDROID -o utun+ -j RETURN' "$FW_CAPTURE"
grep -q -- '-A ZAPRET_ANDROID -o wg+ -j RETURN' "$FW_CAPTURE"
grep -q -- '-A ZAPRET_ANDROID -m owner --uid-owner 10123 -j RETURN' "$FW_CAPTURE"
grep -q -- '-A ZAPRET_ANDROID -j CORE_FILTER' "$FW_CAPTURE"
grep -q -- '-A ZAPRET_ANDROID -m mark --mark 0x1 -j RETURN' "$FW_CAPTURE"
grep -q -- '-A ZAPRET_ANDROID -m mark --mark 0xff -j RETURN' "$FW_CAPTURE"
grep -q -- '-A ZAPRET_ANDROID_PRE -i tun+ -j RETURN' "$FW_CAPTURE"
grep -q -- '-A ZAPRET_ANDROID_PRE -m mark --mark 0x1 -j RETURN' "$FW_CAPTURE"
grep -q -- '-A ZAPRET_ANDROID_PRE -i tailscale+ -j RETURN' "$FW_CAPTURE"

(
  ipt_clear(){ :; }
  v2ray_uids(){ :; }
  ipt_exec(){ case " $* " in *' NFQUEUE '*) return 1;; *) return 0;; esac; }
  ! ipt_setup iptables 80 443
)
(
  PATH=$CASE/bin
  iptables(){ :; }
  ipt_setup(){ :; }
  FIREWALL=auto firewall_setup 80 443
)

: >"$FW_CAPTURE"
(
  unset ZAPRET_LIB_LOADED
  MODDIR=$CASE . "$ROOT/lib/zapret.sh"
  nft() { printf '%s\n' "$*" >>"$FW_CAPTURE"; }
  v2ray_uids() { echo 10123; }
  INTERFACE=rmnet+
  FIREWALL=nft firewall_setup 80,443 443
)
grep -q -- 'hook output priority -140' "$FW_CAPTURE"
grep -q -- 'out oifname tun\* return' "$FW_CAPTURE"
grep -q -- 'out oifname utun\* return' "$FW_CAPTURE"
grep -q -- 'out oifname wg\* return' "$FW_CAPTURE"
grep -q -- 'out meta skuid 10123 return' "$FW_CAPTURE"
grep -q -- 'out meta mark { 0x1, 0xff } return' "$FW_CAPTURE"
grep -q -- 'out oifname rmnet\* tcp dport { 80,443 }' "$FW_CAPTURE"
grep -q -- 'pre iifname tun\* return' "$FW_CAPTURE"
grep -q -- 'pre meta mark { 0x1, 0xff } return' "$FW_CAPTURE"
grep -q -- 'pre iifname tailscale\* return' "$FW_CAPTURE"
(
  nft(){ case " $* " in *' queue '*) return 1;; *) return 0;; esac; }
  FIREWALL=nft
  ! firewall_setup 80 443
)

mkdir -p "$CASE/service/lib" "$CASE/service/data"
cp "$ROOT/service.sh" "$CASE/service/service.sh"
cat >"$CASE/service/lib/zapret.sh" <<'EOF'
ENABLED=1
LOGGING=1
AUTO_UPDATE=1
UPDATE_HOURS=0
LOG_FILE=$MODDIR/data/log
rotate_log(){ :; }
getprop(){ echo 1; }
zapret_update(){ echo x >>"$MODDIR/data/update.calls"; return 1; }
zapret_start(){ echo x >>"$MODDIR/data/start.calls"; return 1; }
EOF
sh "$CASE/service/service.sh" || :
[ "$(wc -l <"$CASE/service/data/update.calls")" = 1 ]
[ "$(wc -l <"$CASE/service/data/start.calls")" = 1 ]
echo OK
