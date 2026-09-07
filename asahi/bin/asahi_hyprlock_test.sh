#!/usr/bin/env bash
# Hyprlock.conf still wires wallpaper, battery, and uptime.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

conf="$ROOT/../hypr/hyprlock.conf"
if grep -q 'lock-wallpaper' "$conf" && grep -q 'asahi-battery text' "$conf" && grep -q 'uptime -p' "$conf"; then
  pass "hyprlock.conf has wallpaper, battery, uptime"
else
  fail_at "hyprlock.conf missing wallpaper/battery/uptime"
fi

if [ "$fail" -ne 0 ]; then
  echo "$fail failed"
  exit 1
fi
echo "all passed"
