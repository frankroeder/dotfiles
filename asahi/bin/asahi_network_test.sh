#!/usr/bin/env bash
# Smoke tests for asahi-network age format + JSON keys. No NM writes.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NET="$ROOT/asahi-network"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

eq() {
  local got="$1" expected="$2" msg="$3"
  if [ "$got" = "$expected" ]; then pass "$msg"
  else fail_at "$msg got=$got expected=$expected"
  fi
}

eq "$("$NET" --fmt-age 0)" "0m" "0s → 0m"
eq "$("$NET" --fmt-age 59)" "0m" "59s → 0m"
eq "$("$NET" --fmt-age 60)" "1m" "60s → 1m"
eq "$("$NET" --fmt-age 3599)" "59m" "3599s → 59m"
eq "$("$NET" --fmt-age 3600)" "1h 0m" "3600s → 1h 0m"
eq "$("$NET" --fmt-age 5400)" "1h 30m" "5400s → 1h 30m"
eq "$("$NET" --fmt-age 86400)" "1d 0h" "1d"
eq "$("$NET" --fmt-age $((2 * 86400 + 5 * 3600)))" "2d 5h" "2d 5h"
eq "$("$NET" --fmt-channel 2412)" "1" "2412 → channel 1"
eq "$("$NET" --fmt-channel 2484)" "14" "2484 → channel 14"
eq "$("$NET" --fmt-channel 5180)" "36" "5180 → channel 36"
eq "$("$NET" --fmt-channel 5320.0)" "64" "iw's 5320.0 → channel 64"
eq "$("$NET" --fmt-channel 5745)" "149" "5745 → channel 149"
eq "$("$NET" --fmt-channel 5955)" "1" "5955 → 6 GHz channel 1"
eq "$("$NET" --fmt-channel 2400)" "0" "off-band → 0"

out=$("$NET" || true)
if echo "$out" | jq -e 'has("vpn") and has("vpnSince") and has("vpnName")' >/dev/null; then
  pass "live JSON has vpn / vpnSince / vpnName"
else
  fail_at "live JSON missing vpn keys: $out"
fi
# BarData.qml reads text / name / vpn*, NetworkPane.qml the tooltip: nothing else.
echo "$out" | jq -e 'keys == ["name", "text", "tooltip", "vpn", "vpnName", "vpnSince"]' >/dev/null \
  && pass "live JSON has only the read keys" || fail_at "live JSON keys: $out"

qml="$ROOT/../quickshell/remix/modules/bar/components/Network.qml"
if grep -q 'font.pixelSize: Style.barFontGlyphTall' "$qml" && grep -q 'visible: root.vpnUp' "$qml" && grep -q 'root.vpnName' "$qml"; then
  pass "Network.qml shows the VPN shield (and its name when granted) while the VPN is up"
else
  fail_at "Network.qml missing the VPN glyph"
fi

if [ "$fail" -ne 0 ]; then
  echo "$fail failed"
  exit 1
fi
echo "all passed"
