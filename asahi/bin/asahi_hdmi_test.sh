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
    ASAHI_SCALE_DIR="$tmp/scales" ASAHI_HDMI_GEN="$gen" "$HOT" "$@"
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
grep -q 'position = "-2048x321"' "$kw_log" \
  || fail_at "Dell sits left of eDP-1, bottoms aligned (got $(tr '\n' ' ' <"$kw_log"))"
pass "added enables Dell with disabled = false"

mkdir -p "$tmp/scales"
printf '2\n' >"$tmp/scales/eDP-1"
: >"$kw_log"
run added
grep -q 'position = "-2048x-170"' "$kw_log" \
  || fail_at "Dell y follows eDP scale 2 (got $(tr '\n' ' ' <"$kw_log"))"
pass "Dell bottoms follow eDP scale 2"
rm -f "$tmp/scales/eDP-1"

printf '[{"name":"HDMI-A-1","disabled":true,"description":"LG Electronics LG ULTRAFINE"}]\n' >"$mon_json"
: >"$kw_log"
run on
grep -q '3840x2160@60.000' "$kw_log" || fail_at "LG layout (got $(tr '\n' ' ' <"$kw_log"))"
grep -q 'position = "-2048x-360"' "$kw_log" \
  || fail_at "LG abuts eDP-1 at logical 2048 (got $(tr '\n' ' ' <"$kw_log"))"
grep -q 'scale = 1.875' "$kw_log" || fail_at "LG scale 1.875 (got $(tr '\n' ' ' <"$kw_log"))"
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

printf '[{"name":"HDMI-A-1","disabled":false,"description":"Dell Inc. DELL P2723DE 895ZNR3","x":-2048,"y":321,"scale":1.25}]\n' >"$mon_json"
: >"$kw_log"
run sync
if grep -q . "$kw_log"; then
  fail_at "sync no-op when Dell layout already matches (got $(tr '\n' ' ' <"$kw_log"))"
else
  pass "sync no-op when already enabled"
fi

printf '[{"name":"HDMI-A-1","disabled":false,"description":"Dell Inc. DELL P2723DE 895ZNR3","x":-2048,"y":-360,"scale":1.875}]\n' >"$mon_json"
: >"$kw_log"
run sync
grep -q 'position = "-2048x321"' "$kw_log" && grep -q 'scale = 1.25' "$kw_log" \
  || fail_at "sync must not keep UltraFine geometry on the Dell (got $(tr '\n' ' ' <"$kw_log"))"
grep -q -- '-360' "$kw_log" && fail_at "Dell sync must not keep LG y (got $(tr '\n' ' ' <"$kw_log"))"
pass "sync reapplies Dell layout after LG leftover"

printf '[{"name":"HDMI-A-1","disabled":false,"description":"LG Electronics LG ULTRAFINE","x":0,"y":-1152,"scale":1.25,"availableModes":["3840x2160@60.00Hz","2560x1440@59.95Hz"]}]\n' >"$mon_json"
: >"$kw_log"
run sync
grep -q 'position = "-2048x-360"' "$kw_log" && grep -q 'scale = 1.875' "$kw_log" \
  || fail_at "sync must restore UltraFine left-of-eDP (got $(tr '\n' ' ' <"$kw_log"))"
pass "sync reapplies LG layout after Dell leftover"

# Stale LG name after a Dell plug: 4K is not in the mode list.
printf '[{"name":"HDMI-A-1","disabled":true,"description":"LG Electronics LG ULTRAFINE 112NTMX6B267","availableModes":["2560x1440@59.95Hz","1920x1080@60.00Hz"]}]\n' >"$mon_json"
: >"$kw_log"
run sync
grep -q 'disabled = false' "$kw_log" || fail_at "stale LG name still enables"
grep -q 'mode = "2560x1440@59.95100"' "$kw_log" \
  || fail_at "stale LG name uses Dell 1440p (got $(tr '\n' ' ' <"$kw_log"))"
grep -q '3840x2160' "$kw_log" && fail_at "must not 4K when that mode is missing"
pass "stale LG description with Dell modes uses 1440p"

printf '[{"name":"HDMI-A-1","disabled":true,"description":"LG Electronics LG ULTRAFINE 112NTMX6B267","availableModes":["3840x2160@60.00Hz","2560x1440@59.95Hz"]}]\n' >"$mon_json"
: >"$kw_log"
run on
grep -q 'mode = "3840x2160@60.000"' "$kw_log" \
  || fail_at "real UltraFine keeps 4K (got $(tr '\n' ' ' <"$kw_log"))"
pass "UltraFine with 4K in modes keeps 4K"

printf 'connected\n' >"$drm/card2-HDMI-A-1/status"
printf '%s\n' "$dell" >"$mon_json"
: >"$kw_log"
PATH="$tmp/bin:$PATH" ASAHI_DRM_PATH="$drm" ASAHI_HDMI_SETTLE_S=1 \
  ASAHI_SCALE_DIR="$tmp/scales" ASAHI_HDMI_GEN="$gen" "$HOT" added HDMI-A-1 &
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
grep -A4 'ULTRAFINE' "$cfg" | grep -q -- '-2048x-360' \
  || fail_at "monitors.lua LG position must match asahi-hdmi"
grep -A4 'P2723DE' "$cfg" | grep -q -- '-2048x321' \
  || fail_at "monitors.lua Dell position must match asahi-hdmi"
pass "monitors.lua disables HDMI until asahi-hdmi"

grep -q 'asahi-hdmi sync' "$ROOT/../hypr/conf.d/autostart.lua" \
  && pass "autostart.lua runs asahi-hdmi sync" \
  || fail_at "autostart.lua missing asahi-hdmi sync"

login="$ROOT/../systemd/logind.conf.d/10-asahi-sleep.conf"
udev="$ROOT/../udev/99-asahi-hdmi-lid-inhibit.rules"
unit="$ROOT/../systemd/system/asahi-hdmi-lid-inhibit.service"
inst="$ROOT/../../install/components.sh"
grep -q '^LidSwitchIgnoreInhibited=no' "$login" || fail_at "need LidSwitchIgnoreInhibited=no"
grep -q '^HandleLidSwitch=' "$login" && fail_at "must not set HandleLidSwitch"
grep -q 'KERNEL=="card\*-HDMI-A-\*"' "$udev" || fail_at "udev must match HDMI-A"
grep -q eDP "$udev" && fail_at "udev must not mention eDP"
grep -q 'systemctl --no-block start asahi-hdmi-lid-inhibit.service' "$udev" \
  && grep -q 'systemctl --no-block stop asahi-hdmi-lid-inhibit.service' "$udev" \
  || fail_at "udev must start/stop lid-inhibit on HDMI status"
grep -q 'handle-lid-switch' "$unit" || fail_at "unit must inhibit handle-lid-switch"
grep -q 'ExecStart=.*--why=[^ ]* --mode' "$unit" || fail_at "unit --why must be one token (systemd splits on spaces)"
grep -q 'ExecCondition=.*HDMI-A-\*/status' "$unit" || fail_at "unit must gate on HDMI status at boot"
grep -q 'WantedBy=multi-user.target' "$unit" || fail_at "lid-inhibit must be enabled at boot"
grep -q 99-asahi-hdmi-lid-inhibit "$inst" || fail_at "asahi-logind must install lid-inhibit"
grep -q 'systemctl enable asahi-hdmi-lid-inhibit' "$inst" || fail_at "asahi-logind must enable lid-inhibit"
pass "HDMI lid-inhibit: udev holds handle-lid-switch, logind honors it"

# HDMI unplugged: Hyprland must not keep a leftover enabled output.
printf 'disconnected\n' >"$drm/card2-HDMI-A-1/status"
printf '[{"name":"HDMI-A-1","disabled":false,"description":"Dell Inc. DELL P2723DE 895ZNR3","x":0,"y":-1152,"scale":1.25}]\n' >"$mon_json"
: >"$kw_log"
run sync
grep -q 'disabled = true' "$kw_log" \
  || fail_at "sync must disable HDMI when DRM is disconnected (got $(tr '\n' ' ' <"$kw_log"))"
pass "sync disables HDMI when DRM is disconnected"

if [ "$fail" -ne 0 ]; then
  echo "asahi_hdmi_test.sh: FAILED"
  exit 1
fi
echo "asahi_hdmi_test.sh: all ok"
