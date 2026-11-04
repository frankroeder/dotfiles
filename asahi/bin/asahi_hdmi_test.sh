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

# dcp_crashed reads the kernel log; notifications land in a file, logger nowhere.
klog="$tmp/klog"
notes="$tmp/notes"
: >"$klog"
: >"$notes"
mkdir -p "$tmp/dt/aliases" "$tmp/run"
printf '/soc/dcp@315c00000\0' >"$tmp/dt/aliases/dcpext1"
printf '#!/bin/sh\ncat "%s"\n' "$klog" >"$tmp/bin/journalctl"
printf '#!/bin/sh\necho "$*" >>"%s"\n' "$notes" >"$tmp/bin/notify-send"
printf '#!/bin/sh\nexit 0\n' >"$tmp/bin/logger"
chmod +x "$tmp/bin/journalctl" "$tmp/bin/notify-send" "$tmp/bin/logger"

run() {
  PATH="$tmp/bin:$PATH" ASAHI_DRM_PATH="$drm" ASAHI_HDMI_SETTLE_S=0 ASAHI_DT_PATH="$tmp/dt" XDG_RUNTIME_DIR="$tmp/run" \
    ASAHI_SCALE_DIR="$tmp/scales" ASAHI_LAYOUT_FILE="$tmp/layout.json" "$HOT" "$@"
}

dell='[{"name":"eDP-1","disabled":false},{"name":"HDMI-A-1","disabled":true,"description":"Dell Inc. DELL P2723DE ABC1234"}]'

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

printf '[{"name":"HDMI-A-1","disabled":false,"description":"Dell Inc. DELL P2723DE ABC1234","x":-2048,"y":321,"scale":1.25}]\n' >"$mon_json"
: >"$kw_log"
run sync
if grep -q . "$kw_log"; then
  fail_at "sync no-op when Dell layout already matches (got $(tr '\n' ' ' <"$kw_log"))"
else
  pass "sync no-op when already enabled"
fi

printf '[{"name":"HDMI-A-1","disabled":false,"description":"Dell Inc. DELL P2723DE ABC1234","x":-2048,"y":-360,"scale":1.875}]\n' >"$mon_json"
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
printf '[{"name":"HDMI-A-1","disabled":true,"description":"LG Electronics LG ULTRAFINE 000ABC123456","availableModes":["2560x1440@59.95Hz","1920x1080@60.00Hz"]}]\n' >"$mon_json"
: >"$kw_log"
run sync
grep -q 'disabled = false' "$kw_log" || fail_at "stale LG name still enables"
grep -q 'mode = "2560x1440@59.95100"' "$kw_log" \
  || fail_at "stale LG name uses Dell 1440p (got $(tr '\n' ' ' <"$kw_log"))"
grep -q '3840x2160' "$kw_log" && fail_at "must not 4K when that mode is missing"
pass "stale LG description with Dell modes uses 1440p"

printf '[{"name":"HDMI-A-1","disabled":true,"description":"LG Electronics LG ULTRAFINE 000ABC123456","availableModes":["3840x2160@60.00Hz","2560x1440@59.95Hz"]}]\n' >"$mon_json"
: >"$kw_log"
run on
grep -q 'mode = "3840x2160@60.000"' "$kw_log" \
  || fail_at "real UltraFine keeps 4K (got $(tr '\n' ' ' <"$kw_log"))"
pass "UltraFine with 4K in modes keeps 4K"

printf 'connected\n' >"$drm/card2-HDMI-A-1/status"
printf '%s\n' "$dell" >"$mon_json"
: >"$kw_log"
PATH="$tmp/bin:$PATH" ASAHI_DRM_PATH="$drm" ASAHI_HDMI_SETTLE_S=1 \
  ASAHI_SCALE_DIR="$tmp/scales" XDG_RUNTIME_DIR="$tmp/run" "$HOT" added HDMI-A-1 &
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
grep -A2 'output = "DP-1"' "$cfg" | grep -q 'disabled = true' \
  || fail_at "monitors.lua must disable DP-1"
grep -q 'asahi-hdmi' "$cfg" || fail_at "monitors.lua must call asahi-hdmi"
grep -A4 'ULTRAFINE' "$cfg" | grep -q -- '-2048x-360' \
  || fail_at "monitors.lua LG position must match asahi-hdmi"
grep -A4 'P2723DE' "$cfg" | grep -q -- '-2048x321' \
  || fail_at "monitors.lua Dell position must match asahi-hdmi"
pass "monitors.lua disables HDMI and DP-1 until asahi-hdmi"

grep -q 'asahi-hdmi sync' "$ROOT/../hypr/conf.d/autostart.lua" \
  && pass "autostart.lua runs asahi-hdmi sync" \
  || fail_at "autostart.lua missing asahi-hdmi sync"

lua_out=$(lua "$ROOT/../hypr/monitors_test.lua" 2>&1) \
  && pass "monitors.lua hotplug hooks (monitors_test.lua)" \
  || fail_at "monitors_test.lua: $(grep -v '^ok' <<<"$lua_out" | tr '\n' ' ')"

login="$ROOT/../systemd/logind.conf.d/10-asahi-sleep.conf"
udev="$ROOT/../udev/99-asahi-hdmi-lid-inhibit.rules"
unit="$ROOT/../systemd/system/asahi-hdmi-lid-inhibit.service"
inst="$ROOT/../../install/components.sh"
grep -q '^LidSwitchIgnoreInhibited=no' "$login" || fail_at "need LidSwitchIgnoreInhibited=no"
grep -q '^HandleLidSwitch=' "$login" && fail_at "must not set HandleLidSwitch"
grep -q 'KERNEL=="card\[0-9\]\*", ENV{HOTPLUG}=="1"' "$udev" || fail_at "udev must match the card's HOTPLUG uevent (connectors get none)"
grep -q 'card\*-HDMI-A-\*/status /sys/class/drm/card\*-DP-\*/status' "$udev" || fail_at "udev must re-check HDMI-A and USB-C DP"
grep -q 'systemd-run --no-block --collect --on-active=' "$udev" || fail_at "udev must re-check later (sysfs status is stale inside RUN)"
grep -q eDP "$udev" && fail_at "udev must not mention eDP"
grep -q 'systemctl --no-block start asahi-hdmi-lid-inhibit.service' "$udev" \
  && grep -q 'systemctl --no-block stop asahi-hdmi-lid-inhibit.service' "$udev" \
  || fail_at "udev must start lid-inhibit while an external is connected and stop it otherwise"
grep -q 'card\*-DP-\*/status' "$unit" || fail_at "lid-inhibit ExecCondition must cover USB-C DP"
grep -q 'handle-lid-switch' "$unit" || fail_at "unit must inhibit handle-lid-switch"
grep -q 'ExecStart=.*--why=[^ ]* --mode' "$unit" || fail_at "unit --why must be one token (systemd splits on spaces)"
grep -q 'ExecCondition=.*HDMI-A-\*/status' "$unit" || fail_at "unit must gate on HDMI status at boot"
grep -q 'WantedBy=multi-user.target' "$unit" || fail_at "lid-inhibit must be enabled at boot"
grep -q 99-asahi-hdmi-lid-inhibit "$inst" || fail_at "asahi-logind must install lid-inhibit"
grep -q 'systemctl enable asahi-hdmi-lid-inhibit' "$inst" || fail_at "asahi-logind must enable lid-inhibit"
pass "HDMI lid-inhibit: udev holds handle-lid-switch, logind honors it"

# HDMI unplugged: Hyprland must not keep a leftover enabled output.
printf 'disconnected\n' >"$drm/card2-HDMI-A-1/status"
printf '[{"name":"HDMI-A-1","disabled":false,"description":"Dell Inc. DELL P2723DE ABC1234","x":0,"y":-1152,"scale":1.25}]\n' >"$mon_json"
: >"$kw_log"
run sync
grep -q 'disabled = true' "$kw_log" \
  || fail_at "sync must disable HDMI when DRM is disconnected (got $(tr '\n' ' ' <"$kw_log"))"
pass "sync disables HDMI when DRM is disconnected"

# Kept position (Displays pane drag + Keep): used while the scales match, dropped by reset.
printf 'connected\n' >"$drm/card2-HDMI-A-1/status"
printf '[{"name":"eDP-1","disabled":false,"scale":2},{"name":"HDMI-A-1","disabled":false,"description":"Dell Inc. DELL P2723DE ABC1234","x":1512,"y":0,"scale":1.25,"availableModes":["2560x1440@59.95Hz"]}]\n' >"$mon_json"
rm -f "$tmp/layout.json"
run save HDMI-A-1 1512x0 && [ -s "$tmp/layout.json" ] || fail_at "save should write the layout file"
: >"$kw_log"
run on
grep -q 'position = "1512x0"' "$kw_log" || fail_at "on should use the kept position (got $(tr '\n' ' ' <"$kw_log"))"
run save HDMI-A-1 'x;rm' 2>/dev/null && fail_at "save must reject a bad position" || true
run reset HDMI-A-1
: >"$kw_log"
run on
grep -q 'position = "-2048x' "$kw_log" || fail_at "reset should restore the derived position (got $(tr '\n' ' ' <"$kw_log"))"
pass "kept position: save, on, reset"

# USB-C DP: same settle-then-enable as HDMI. drm status is this connector, not HDMI's.
# eDP scale 2 -> Dell bottom-aligned at y = -170.
mkdir -p "$drm/card2-DP-1" "$tmp/scales"
printf 'disconnected\n' >"$drm/card2-HDMI-A-1/status"
printf 'connected\n' >"$drm/card2-DP-1/status"
printf '2\n' >"$tmp/scales/eDP-1"
printf '[{"name":"eDP-1","disabled":false,"scale":2},{"name":"DP-1","disabled":true,"description":"Dell Inc. DELL P2723DE ABC1234","x":-2048,"y":321,"scale":1.25,"availableModes":["2560x1440@59.95Hz"]}]\n' >"$mon_json"
: >"$kw_log"
run added DP-1
grep -q 'output = "DP-1"' "$kw_log" && grep -q 'disabled = false' "$kw_log" \
  && grep -q 'position = "-2048x-170"' "$kw_log" \
  || fail_at "added DP-1 enables the Dell at -2048x-170 (got $(tr '\n' ' ' <"$kw_log"))"
pass "added DP-1 enables from DP status, not HDMI"

# USB-C DCP crashed at a lit unplug (no dcp_poweroff after it): an enabled DP-1 aborted Hyprland (2026-11-03).
d='apple-dcp 315c00000.dcp:'
printf '%s\n' "$d set_digital_out_mode finished:8214" "$d cb_hotplug() connected:0, valid_mode:1" \
  "$d cb_hotplug() connected:1, valid_mode:0" >"$klog"
: >"$kw_log"
run added DP-1
run sync DP-1
! grep -q 'disabled = false' "$kw_log" && grep -q 'output = "DP-1", disabled = true' "$kw_log" \
  && [ "$(grep -c 'USB-C display stays off' "$notes")" = 1 ] \
  && pass "crashed USB-C DCP: DP-1 stays off, one notification" \
  || fail_at "crashed DCP must keep DP-1 off and notify once (eval: $(tr '\n' ' ' <"$kw_log"); notes: $(wc -l <"$notes"))"
: >"$kw_log"
printf 'connected\n' >"$drm/card2-HDMI-A-1/status"
run added HDMI-A-1
grep -q 'output = "HDMI-A-1", disabled = false' "$kw_log" \
  && pass "crashed USB-C DCP does not block HDMI" || fail_at "HDMI must ignore the USB-C DCP state"
printf 'disconnected\n' >"$drm/card2-HDMI-A-1/status"

# Healthy: power-off right after the lit unplug, or the unplug came while DPMS-off.
printf '%s\n' "$d set_digital_out_mode finished:8214" "$d cb_hotplug() connected:0, valid_mode:1" \
  "$d dcp_poweroff() done" >"$klog"
: >"$kw_log"
run added DP-1
grep -q 'output = "DP-1", disabled = false' "$kw_log" || fail_at "power-off after the unplug = healthy, enable"
printf '%s\n' "$d set_digital_out_mode finished:8214" "$d dcp_poweroff() done" \
  "$d cb_hotplug() connected:0, valid_mode:1" >"$klog"
: >"$kw_log"
run added DP-1
grep -q 'output = "DP-1", disabled = false' "$kw_log" || fail_at "unplug while DPMS-off = healthy, enable"
# Kernel with AsahiLinux/linux PR #582: the clear-swap timeout warns instead of latching ->crashed.
printf '%s\n' "$d set_digital_out_mode finished:8214" "$d cb_hotplug() connected:0, valid_mode:1" \
  "$d iomfb_poweroff_v13_3: timed out waiting for the poweroff clear swap; continuing" >"$klog"
: >"$kw_log"
run added DP-1
grep -q 'output = "DP-1", disabled = false' "$kw_log" || fail_at "PR #582 timeout warning = healthy, enable"
pass "healthy USB-C unplugs still enable DP-1 (also PR #582's timeout)"
: >"$klog"

printf '[{"name":"eDP-1","disabled":false,"scale":2},{"name":"DP-1","disabled":false,"description":"Dell Inc. DELL P2723DE ABC1234","x":-2048,"y":321,"scale":1.25,"availableModes":["2560x1440@59.95Hz"]}]\n' >"$mon_json"
: >"$kw_log"
run place DP-1
grep -qx 'hl.monitor({ output = "DP-1", position = "-2048x-170", scale = 1.25 })' "$kw_log" \
  || fail_at "place DP-1 should move the Dell to -2048x-170 at scale 1.25 (got $(tr '\n' ' ' <"$kw_log"))"
run save DP-1 -2048x-100 && run place DP-1 && grep -q 'position = "-2048x-100"' "$kw_log" \
  || fail_at "place DP-1 should use the kept position"
pass "DP-1: place derives / keeps the position"

# Scale 1 kept layout, no scale file: do not apply the 1.25 anchor (x=-2048 overlaps).
rm -f "$tmp/scales/DP-1"
printf '2\n' >"$tmp/scales/eDP-1"
printf '%s\n' '{"Dell Inc. DELL P2723DE ABC1234":{"key":"1.000@2.000","pos":"-2560x-458"}}' >"$tmp/layout.json"
printf '[{"name":"eDP-1","disabled":false,"scale":2},{"name":"DP-1","disabled":false,"description":"Dell Inc. DELL P2723DE ABC1234","x":-2048,"y":0,"scale":1,"width":2560,"height":1440,"availableModes":["2560x1440@59.95Hz"]}]\n' >"$mon_json"
: >"$kw_log"
run place DP-1
grep -qx 'hl.monitor({ output = "DP-1", position = "-2560x-458", scale = 1.000 })' "$kw_log" \
  || fail_at "place must restore scale 1 with its kept position (got $(tr '\n' ' ' <"$kw_log"))"
pass "DP-1 scale 1 kept layout is not placed at the 1.25 anchor"

if [ "$fail" -ne 0 ]; then
  echo "asahi_hdmi_test.sh: FAILED"
  exit 1
fi
echo "asahi_hdmi_test.sh: all ok"
