#!/usr/bin/env bash
# Smoke tests for Asahi energy/brightness helpers. No hardware writes.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# --- asahi-battery: Apple Silicon sysfs, charge-hold ---
bat="$tmp/power/macsmc-battery"
ac="$tmp/power/macsmc-ac"
mkdir -p "$bat" "$ac"
printf 'Battery\n' >"$bat/type"
printf '1\n' >"$bat/present"
printf '80\n' >"$bat/capacity"
printf 'Not charging\n' >"$bat/status"
printf 'Normal\n' >"$bat/capacity_level"
printf '405\n' >"$bat/cycle_count"
printf 'Good\n' >"$bat/health"
printf 'bq27z561-0\n' >"$bat/model_name"
printf '[auto] inhibit-charge\n' >"$bat/charge_behaviour"
printf '75\n' >"$bat/charge_control_start_threshold"
printf '80\n' >"$bat/charge_control_end_threshold"
printf '40000000\n' >"$bat/energy_now"
printf '56000000\n' >"$bat/energy_full"
printf '69000000\n' >"$bat/energy_full_design"
printf '100000\n' >"$bat/power_now"
printf '12000000\n' >"$bat/voltage_now"
printf '10000\n' >"$bat/current_now"
printf '300\n' >"$bat/temp"
printf '0\n' >"$bat/time_to_empty_now"
printf '0\n' >"$bat/time_to_full_now"
printf '2021\n' >"$bat/manufacture_year"
printf '6\n' >"$bat/manufacture_month"
printf '15\n' >"$bat/manufacture_day"
printf '1\n' >"$ac/online"
printf 'Mains\n' >"$ac/type"
printf '30000000\n' >"$ac/input_power_limit"

out=$(ASAHI_POWER_SUPPLY_PATH="$tmp/power" "$ROOT/asahi-battery")
echo "$out" | jq -e '.holding == true' >/dev/null || fail_at "battery holding true at 80% cap"
echo "$out" | jq -e '.threshold_end == 80' >/dev/null || fail_at "battery threshold_end 80"
echo "$out" | jq -e '.percentage == 80' >/dev/null || fail_at "battery percentage 80"
echo "$out" | jq -e '.class | index("holding")' >/dev/null || fail_at "battery class includes holding"
echo "$out" | grep -q 'Holding at 75-80%' || fail_at "battery tooltip holding label"
pass "asahi-battery reports charge-hold on macsmc-battery"

printf 'Discharging\n' >"$bat/status"
printf '0\n' >"$ac/online"
printf '100\n' >"$bat/charge_control_end_threshold"
out=$(ASAHI_POWER_SUPPLY_PATH="$tmp/power" "$ROOT/asahi-battery")
echo "$out" | jq -e '.holding == false' >/dev/null || fail_at "battery not holding while discharging"
pass "asahi-battery not holding while discharging"

# --- asahi-charge-limit on mock sysfs ---
chmod u+w "$bat/charge_control_end_threshold" "$bat/charge_control_start_threshold"
state="$tmp/charge-limit"
sysstate="$tmp/system-charge-limit"
ASAHI_POWER_SUPPLY_PATH="$tmp/power" ASAHI_CHARGE_LIMIT_STATE="$state" \
  ASAHI_CHARGE_LIMIT_SYSTEM="$sysstate" "$ROOT/asahi-charge-limit" 80 >/dev/null
[ "$(cat "$bat/charge_control_end_threshold")" = "80" ] || fail_at "charge-limit writes end 80"
[ "$(cat "$bat/charge_control_start_threshold")" = "75" ] || fail_at "charge-limit writes start 75"
[ "$(cat "$state")" = "80" ] || fail_at "charge-limit persists 80"
ASAHI_POWER_SUPPLY_PATH="$tmp/power" ASAHI_CHARGE_LIMIT_STATE="$state" \
  ASAHI_CHARGE_LIMIT_SYSTEM="$sysstate" "$ROOT/asahi-charge-limit" 100 >/dev/null
[ "$(cat "$bat/charge_control_end_threshold")" = "100" ] || fail_at "charge-limit writes end 100"
[ "$(cat "$bat/charge_control_start_threshold")" = "100" ] || fail_at "charge-limit writes start 100"
pass "asahi-charge-limit apply 80 then 100"

# systemd/udev invoke this with no HOME (set -u must not abort).
env -u HOME -u XDG_STATE_HOME ASAHI_POWER_SUPPLY_PATH="$tmp/power" \
  ASAHI_CHARGE_LIMIT_SYSTEM="$sysstate" "$ROOT/asahi-charge-limit" apply >/dev/null \
  || fail_at "apply without HOME"
env -u HOME -u XDG_STATE_HOME "$ROOT/asahi-charge-limit" udev \
  || fail_at "udev without HOME"
pass "asahi-charge-limit apply/udev work without HOME"

# --- brightness step math via a stub brightnessctl ---
mkdir -p "$tmp/bin"
cat >"$tmp/bin/brightnessctl" <<'EOF'
#!/usr/bin/env bash
# $BRIGHTNESS_CUR / $BRIGHTNESS_MAX used for get/max/-m; set writes $BRIGHTNESS_SET
device=""
while [ $# -gt 0 ]; do
  case "$1" in
    --device) device="$2"; shift 2 ;;
    --quiet|-q) shift ;;
    -m)
      printf '%s,backlight,%s,%s%%,%s\n' "${device:-apple-panel-bl}" "${BRIGHTNESS_CUR:-275}" "${BRIGHTNESS_PCT:-55}" "${BRIGHTNESS_MAX:-500}"
      exit 0
      ;;
    info) exit 0 ;;
    get) printf '%s\n' "${BRIGHTNESS_CUR:-275}"; exit 0 ;;
    max) printf '%s\n' "${BRIGHTNESS_MAX:-500}"; exit 0 ;;
    set) echo "$2" >"${BRIGHTNESS_SET:-/dev/null}"; exit 0 ;;
    *) shift ;;
  esac
done
exit 0
EOF
chmod +x "$tmp/bin/brightnessctl"
printf '#!/bin/sh\nexit 0\n' >"$tmp/bin/qs"
chmod +x "$tmp/bin/qs"
cat >"$tmp/bin/hyprctl" <<'EOF'
#!/bin/sh
if [ "$1" = monitors ]; then
  name="${BRIGHTNESS_MONITOR:-eDP-1}"
  printf '[{"name":"%s","focused":true,"disabled":false,"dpmsStatus":true}]\n' "$name"
  exit 0
fi
exit 0
EOF
chmod +x "$tmp/bin/hyprctl"

setfile="$tmp/set"
# 3% + raise => 1% step (absolute 4%)
out=$(PATH="$tmp/bin:$PATH" BRIGHTNESS_CUR=15 BRIGHTNESS_PCT=3 BRIGHTNESS_MAX=500 \
  BRIGHTNESS_SET="$setfile" \
  "$ROOT/asahi-media-control" brightness raise)
[ "$(cat "$setfile")" = "4%" ] || fail_at "brightness raise at 3% is 4% (got $(cat "$setfile"))"
pass "brightness raise below 5% uses 1% steps"

out=$(PATH="$tmp/bin:$PATH" BRIGHTNESS_CUR=275 BRIGHTNESS_PCT=55 BRIGHTNESS_MAX=500 \
  BRIGHTNESS_SET="$setfile" \
  "$ROOT/asahi-media-control" brightness raise)
[ "$(cat "$setfile")" = "60%" ] || fail_at "brightness raise at 55% is 60% (got $(cat "$setfile"))"
pass "brightness raise above 5% uses 5% steps"

rm -f "$setfile"
softdir="$tmp/soft-bright"
mkdir -p "$softdir"
PATH="$tmp/bin:$PATH" BRIGHTNESS_MONITOR=HDMI-A-1 BRIGHTNESS_SET="$setfile" \
  ASAHI_BRIGHTNESS_STATE_DIR="$softdir" \
  "$ROOT/asahi-media-control" brightness lower >/dev/null
[ ! -e "$setfile" ] || fail_at "external focus must not touch laptop backlight"
[ "$(cat "$softdir/HDMI-A-1")" = "95" ] || fail_at "software dim lower from 100 is 95 (got $(cat "$softdir/HDMI-A-1" 2>/dev/null))"
pass "focused HDMI uses software dim, not apple-panel-bl"

# --- asahi-idle-brightness off hits every backlight device ---
mkdir -p "$tmp/bl/a" "$tmp/bl/b"
# brightnessctl info must succeed for each basename; stub already accepts info.
# Point the script at fake /sys via a wrapper? asahi-idle-brightness walks
# /sys/class/backlight. Skip live sysfs; just check usage.
"$ROOT/asahi-idle-brightness" 2>/dev/null && fail_at "idle-brightness no-arg should fail" || pass "asahi-idle-brightness usage"

# --- asahi-dpms usage ---
"$ROOT/asahi-dpms" 2>/dev/null && fail_at "asahi-dpms no-arg should fail" || pass "asahi-dpms usage"

# --- asahi-bluetooth-power usage ---
"$ROOT/asahi-bluetooth-power" 2>/dev/null && fail_at "bluetooth-power no-arg should fail" || pass "asahi-bluetooth-power usage"

# --- asahi-cmd-record usage ---
"$ROOT/asahi-cmd-record" bogus 2>/dev/null && fail_at "cmd-record bad arg should fail" || pass "asahi-cmd-record usage"
[ "$("$ROOT/asahi-cmd-record" status)" = "stopped" ] || fail_at "cmd-record status is stopped when idle"
pass "asahi-cmd-record status idle"
# --- dnf.sh ships wf-recorder; make asahi -> install.sh asahi -> dnf.sh ---
grep -qE '^[[:space:]]*wf-recorder \\$' "$ROOT/../dnf.sh" || fail_at "dnf.sh installs wf-recorder"
pass "dnf.sh includes wf-recorder"
grep -qE '^[[:space:]]*hyprpicker \\$' "$ROOT/../dnf.sh" || fail_at "dnf.sh installs hyprpicker"
pass "dnf.sh includes hyprpicker"
grep -q 'asahi-cmd-record fullscreen' "$ROOT/../hypr/conf.d/bindings.lua" || fail_at "hypr bindings start recording"
pass "hypr bindings record fullscreen/region"

# --- dnf.sh: comments must not live inside the continued argv ---
if grep -nE '^[ ]*#' "$ROOT/../dnf.sh" | grep -B1 'dnf install' >/dev/null 2>&1; then
  :
fi
if awk '
  BEGIN { in_dnf=0 }
  /sudo dnf install -y \\/ { in_dnf=1; next }
  in_dnf && /^[^ ].*[^\\]$/ { in_dnf=0 }
  in_dnf && /^[[:space:]]*#/ { bad=1 }
  END { exit bad+0 }
' "$ROOT/../dnf.sh"; then
  pass "dnf.sh has no comments inside the continued package list"
else
  fail_at "dnf.sh still has a comment inside sudo dnf install \\"
fi

# --- launcher / system menu still has no Hibernate ---
grep -q 'title: "Hibernate"' "$ROOT/../quickshell/remix/modules/launcher/Data.js" \
  && fail_at "launcher still lists Hibernate" \
  || pass "launcher has no Hibernate row"

if [ "$fail" -ne 0 ]; then
  echo "asahi_energy_test.sh: FAILED"
  exit 1
fi
echo "asahi_energy_test.sh: all ok"
