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

out=$("$NET" || true)
if echo "$out" | jq -e 'has("vpn") and has("vpnSince") and has("vpnName")' >/dev/null; then
  pass "live JSON has vpn / vpnSince / vpnName"
else
  fail_at "live JSON missing vpn keys: $out"
fi

qml="$ROOT/../quickshell/remix/modules/bar/components/Network.qml"
if grep -q 'font.pixelSize: Style.barFontGlyph' "$qml" && grep -q 'root.vpnAge' "$qml"; then
  pass "Network.qml VPN glyph matches wifi size and shows age"
else
  fail_at "Network.qml missing large VPN glyph or age"
fi

if [ "$fail" -ne 0 ]; then
  echo "$fail failed"
  exit 1
fi
echo "all passed"
