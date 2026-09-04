#!/usr/bin/env bash
# Smoke tests for asahi-hdmi. No live DRM/Hyprland writes.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

HOT="$ROOT/asahi-hdmi"
chmod +x "$HOT"

"$HOT" 2>/dev/null && fail_at "no-arg should fail" || pass "usage"
"$HOT" added eDP-1 2>/dev/null && fail_at "eDP name should fail" || pass "non-HDMI name"

drm="$tmp/drm"
mkdir -p "$drm/card2-HDMI-A-1" "$tmp/bin"
printf 'disconnected\n' >"$drm/card2-HDMI-A-1/status"
mon_json="$tmp/mon.json"
kw_log="$tmp/eval.log"
gen="$tmp/gen"
: >"$kw_log"
printf '[{"name":"eDP-1","disabled":false}]\n' >"$mon_json"

cat >"$tmp/bin/hyprctl" <<EOF
#!/bin/sh
if [ "\$1" = monitors ]; then
  cat "$mon_json"
  exit 0
fi
if [ "\$1" = eval ]; then
  shift
  printf '%s\n' "\$*" >> "$kw_log"
  exit 0
fi
exit 0
EOF
chmod +x "$tmp/bin/hyprctl"

run() {
  PATH="$tmp/bin:$PATH" ASAHI_DRM_PATH="$drm" ASAHI_HDMI_SETTLE_S=0 \
    ASAHI_HDMI_GEN="$gen" "$HOT" "$@"
}

dell='[{"name":"eDP-1","disabled":false},{"name":"HDMI-A-1","disabled":true,"description":"Dell Inc. DELL P2723DE 895ZNR3"}]'

: >"$kw_log"
run off
grep -qx 'hl.monitor({ output = "HDMI-A-1", disabled = true })' "$kw_log" \
  || fail_at "off disables HDMI (got $(tr '\n' ' ' <"$kw_log"))"
pass "off disables HDMI"

printf 'connected\n' >"$drm/card2-HDMI-A-1/status"
printf '%s\n' "$dell" >"$mon_json"
: >"$kw_log"
run added
grep -q 'disabled = false' "$kw_log" || fail_at "added must pass disabled = false"
grep -q 'mode = "2560x1440@59.95100"' "$kw_log" \
  || fail_at "added uses Dell mode (got $(tr '\n' ' ' <"$kw_log"))"
pass "added enables Dell with disabled = false"

printf '[{"name":"HDMI-A-1","disabled":true,"description":"LG Electronics LG ULTRAFINE"}]\n' >"$mon_json"
: >"$kw_log"
run on
grep -q '3840x2160@60.000' "$kw_log" || fail_at "LG layout (got $(tr '\n' ' ' <"$kw_log"))"
pass "on uses LG layout from description"

printf 'disconnected\n' >"$drm/card2-HDMI-A-1/status"
: >"$kw_log"
run added
grep -qx 'hl.monitor({ output = "HDMI-A-1", disabled = true })' "$kw_log" \
  || fail_at "added unplug during settle disables (got $(tr '\n' ' ' <"$kw_log"))"
pass "added unplug during settle disables"

printf 'connected\n' >"$drm/card2-HDMI-A-1/status"
printf '%s\n' "$dell" >"$mon_json"
: >"$kw_log"
run sync
grep -q 'disabled = false' "$kw_log" || fail_at "sync enables when HDMI is still disabled"
pass "sync enables connected-but-disabled HDMI"

printf '[{"name":"HDMI-A-1","disabled":false,"description":"Dell Inc. DELL P2723DE 895ZNR3"}]\n' >"$mon_json"
: >"$kw_log"
run sync
if grep -q . "$kw_log"; then
  fail_at "sync no-op when already enabled"
else
  pass "sync no-op when already enabled"
fi

printf 'connected\n' >"$drm/card2-HDMI-A-1/status"
printf '%s\n' "$dell" >"$mon_json"
: >"$kw_log"
PATH="$tmp/bin:$PATH" ASAHI_DRM_PATH="$drm" ASAHI_HDMI_SETTLE_S=1 \
  ASAHI_HDMI_GEN="$gen" "$HOT" added HDMI-A-1 &
first=$!
sleep 0.15
run removed
wait "$first" || true
# removed bumps gen so the in-flight added must not enable afterwards.
if grep -q 'disabled = false' "$kw_log"; then
  fail_at "unplug cancels in-flight added (got $(tr '\n' ' ' <"$kw_log"))"
else
  pass "unplug cancels in-flight added"
fi

cfg="$ROOT/../hypr/conf.d/monitors.lua"
grep -q 'output = "HDMI-A-1"' "$cfg" && grep -q 'disabled = true' "$cfg" \
  || fail_at "monitors.lua must disable HDMI-A-1"
grep -q 'asahi-hdmi' "$cfg" || fail_at "monitors.lua must call asahi-hdmi"
pass "monitors.lua disables HDMI until asahi-hdmi"

if [ "$fail" -ne 0 ]; then
  echo "asahi_hdmi_test.sh: FAILED"
  exit 1
fi
echo "asahi_hdmi_test.sh: all ok"
