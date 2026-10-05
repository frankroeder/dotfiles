#!/usr/bin/env bash
# asahi-wifi-band against a fake nmcli: set, no-op, revert on failed reconnect,
# unpin without an active Wi-Fi, usage.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat >"$tmp/bin/nmcli" <<'EOF'
#!/usr/bin/env bash
state="$FAKE_DIR/band"
echo "$*" >>"$FAKE_DIR/log"
case "$*" in
  "-t -f TYPE,UUID connection show --active") [ -n "${FAKE_NO_WIFI:-}" ] || echo "802-11-wireless:u-home" ;;
  "-t -f TYPE,UUID connection show") printf '%s\n' "802-3-ethernet:u-eth" "802-11-wireless:u-home" ;;
  "-e no -g connection.id connection show uuid u-home") echo 'Cafe: 5G\x' ;;
  "-g 802-11-wireless.band connection show uuid u-home") cat "$state" 2>/dev/null || true ;;
  "connection modify uuid u-home 802-11-wireless.band "*) echo "${!#}" >"$state" ;;
  "--wait 20 connection up uuid u-home") [ "$(cat "$state")" != "${FAKE_FAIL_BAND:-none}" ] ;;
  "-t -f IN-USE,FREQ dev wifi list --rescan no") echo "*:5220 MHz" ;;
esac
EOF
chmod +x "$tmp/bin/nmcli"
export PATH="$tmp/bin:$PATH" FAKE_DIR="$tmp"

: >"$tmp/band"
"$ROOT/asahi-wifi-band" 5 && [ "$(cat "$tmp/band")" = a ] && pass "pin 5 GHz" || fail_at "pin 5 GHz"
: >"$tmp/log"
"$ROOT/asahi-wifi-band" 5 && ! grep -q 'connection up' "$tmp/log" && pass "same band is a no-op" || fail_at "no-op"
json=$("$ROOT/asahi-wifi-band" status --json)
[ "$(jq -r .band <<<"$json")" = 5 ] && [ "$(jq -r .connection <<<"$json")" = 'Cafe: 5G\x' ] &&
  pass "status --json keeps the raw name" || fail_at "status --json ($json)"
if FAKE_FAIL_BAND='bg' "$ROOT/asahi-wifi-band" 2.4 2>/dev/null; then
  fail_at "failed reconnect should exit 1"
else
  [ "$(cat "$tmp/band")" = a ] && pass "failed reconnect reverts" || fail_at "revert (band=$(cat "$tmp/band"))"
fi
FAKE_NO_WIFI=1 "$ROOT/asahi-wifi-band" auto && [ -z "$(cat "$tmp/band")" ] &&
  pass "auto without Wi-Fi clears a stuck pin" || fail_at "auto without Wi-Fi"
rc=0; FAKE_NO_WIFI=1 "$ROOT/asahi-wifi-band" 5 2>/dev/null || rc=$?
[ "$rc" = 1 ] && pass "pin without Wi-Fi exits 1" || fail_at "pin without Wi-Fi (rc=$rc)"
rc=0; FAKE_NO_WIFI=1 "$ROOT/asahi-wifi-band" 6 2>/dev/null || rc=$?
[ "$rc" = 2 ] && pass "usage before lookup" || fail_at "usage (rc=$rc)"
"$ROOT/asahi-wifi-band" auto && [ -z "$(cat "$tmp/band")" ] && pass "auto clears the pin" || fail_at "auto"

if [ "$fail" -ne 0 ]; then
  echo "asahi_wifi_band_test.sh: FAILED"
  exit 1
fi
echo "asahi_wifi_band_test.sh: all ok"
