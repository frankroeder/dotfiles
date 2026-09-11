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

if grep -q 'asahi-theme/hyprlock.conf' "$conf" && grep -q '\$lock_accent' "$conf"; then
  pass "hyprlock.conf sources wallpaper-adaptive colors"
else
  fail_at "hyprlock.conf missing asahi-theme color source"
fi

theme="$ROOT/../hypr/hyprlock-theme.conf"
if [ -f "$theme" ] && grep -q '\$lock_bg' "$theme"; then
  pass "hyprlock-theme.conf ships mocha fallback"
else
  fail_at "hyprlock-theme.conf missing"
fi

if [ "$fail" -ne 0 ]; then
  echo "$fail failed"
  exit 1
fi
echo "all passed"
