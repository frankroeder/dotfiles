#!/usr/bin/env bash
# Smoke tests for Asahi energy/brightness helpers. No hardware writes.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# Locks, saved idle levels and pid files stay in the scratch dir, never the session's.
export XDG_RUNTIME_DIR="$tmp/run"
mkdir -p "$XDG_RUNTIME_DIR"

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
echo "$out" | jq -e '.percentage == 80' >/dev/null || fail_at "battery percentage 80"
echo "$out" | jq -e '.class | index("holding")' >/dev/null || fail_at "battery class includes holding"
echo "$out" | grep -q 'Holding at 75-80%' || fail_at "battery tooltip holding label"
lockline=$(ASAHI_POWER_SUPPLY_PATH="$tmp/power" "$ROOT/asahi-battery" lock)
echo "$lockline" | grep -qx '80% · Holding' || fail_at "battery lock line while holding (got $lockline)"
pass "asahi-battery reports charge-hold on macsmc-battery"

printf 'Discharging\n' >"$bat/status"
printf '0\n' >"$ac/online"
printf '100\n' >"$bat/charge_control_end_threshold"
out=$(ASAHI_POWER_SUPPLY_PATH="$tmp/power" "$ROOT/asahi-battery")
echo "$out" | jq -e '.holding == false' >/dev/null || fail_at "battery not holding while discharging"
lockline=$(ASAHI_POWER_SUPPLY_PATH="$tmp/power" "$ROOT/asahi-battery" lock)
echo "$lockline" | grep -qx '80% · Discharging' || fail_at "battery lock line while discharging (got $lockline)"
printf 'Charging\n' >"$bat/status"
printf '1\n' >"$ac/online"
lockline=$(ASAHI_POWER_SUPPLY_PATH="$tmp/power" "$ROOT/asahi-battery" lock)
echo "$lockline" | grep -qx '80% · Charging' || fail_at "battery lock line while charging (got $lockline)"
pass "asahi-battery not holding while discharging"

# --- asahi-charge-limit on mock sysfs ---
chmod u+w "$bat/charge_control_end_threshold" "$bat/charge_control_start_threshold"
state="$tmp/charge-limit"
cl() { ASAHI_POWER_SUPPLY_PATH="$tmp/power" ASAHI_CHARGE_LIMIT_SYSTEM="$state" "$ROOT/asahi-charge-limit" "$@"; }
cl 80 >/dev/null
[ "$(cat "$bat/charge_control_end_threshold")" = "80" ] || fail_at "charge-limit writes end 80"
[ "$(cat "$state")" = "80" ] || fail_at "charge-limit persists 80"
cl 100 >/dev/null
[ "$(cat "$bat/charge_control_end_threshold")" = "100" ] || fail_at "charge-limit writes end 100"
pass "asahi-charge-limit apply 80 then 100"

# Battery pane stepper: any 60-100 value (CHLS firmware), lower requests clamp to 60; below 100 is a hold.
cl 55 >/dev/null
[ "$(cat "$bat/charge_control_end_threshold")" = "60" ] || fail_at "charge-limit clamps 55 to 60"
[[ "$(cl 99)" == "hold 99%"* ]] || fail_at "charge-limit 99 is a hold"
cl 75 >/dev/null
[ "$(cl status --json | jq -r '"\(.end) \(.desired)"')" = "75 75" ] || fail_at "charge-limit status json"
pass "asahi-charge-limit clamps to 60, 99 holds, reports end/desired"

# A refused write saves nothing: boot and the pane's "Saved" keep the last value the SMC took.
chmod a-w "$bat/charge_control_end_threshold"
if cl 70 >/dev/null 2>&1; then fail_at "charge-limit 70 on read-only sysfs succeeded"; fi
chmod u+w "$bat/charge_control_end_threshold"
[ "$(cat "$state")" = "75" ] || fail_at "refused write changed the saved limit"
# A root-owned 644 state file (after a sudo run) is replaced by rename: only the dir must be writable.
chmod a-w "$state"
cl 80 >/dev/null || fail_at "charge-limit cannot replace a read-only state file"
[ "$(cat "$state")" = "80" ] || fail_at "read-only state file not replaced"
pass "asahi-charge-limit saves only accepted limits, replaces a read-only state file"

# systemd/udev invoke this with no HOME (set -u must not abort).
env -u HOME -u XDG_STATE_HOME ASAHI_POWER_SUPPLY_PATH="$tmp/power" \
  ASAHI_CHARGE_LIMIT_SYSTEM="$state" "$ROOT/asahi-charge-limit" apply >/dev/null \
  || fail_at "apply without HOME"
env -u HOME -u XDG_STATE_HOME ASAHI_POWER_SUPPLY_PATH="$tmp/power" "$ROOT/asahi-charge-limit" udev \
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

dpms_dir="$tmp/dpms"
mkdir -p "$dpms_dir/bin"
dpms_log="$dpms_dir/dispatch.log"
: >"$dpms_log"
cat >"$dpms_dir/bin/hyprctl" <<'EOF'
#!/bin/sh
if [ "$1" = monitors ]; then
  cat "${HYPR_MONITORS_JSON:?}"
  exit 0
fi
if [ "$1" = dispatch ]; then
  printf '%s\n' "$*" >> "${HYPR_DISPATCH_LOG:?}"
  exit 0
fi
exit 0
EOF
chmod +x "$dpms_dir/bin/hyprctl"
run_dpms() {
  PATH="$dpms_dir/bin:$PATH" HYPR_MONITORS_JSON="$dpms_dir/mon.json" \
    HYPR_DISPATCH_LOG="$dpms_log" "$ROOT/asahi-dpms" "$@"
}

# Laptop-only: must DPMS eDP, never a disconnected HDMI-A-1.
printf '[{"name":"eDP-1","disabled":false,"dpmsStatus":true}]\n' >"$dpms_dir/mon.json"
: >"$dpms_log"
run_dpms off
grep -q 'monitor = "eDP-1"' "$dpms_log" || fail_at "dpms off laptop-only hits eDP"
grep -q HDMI "$dpms_log" && fail_at "dpms off laptop-only must not poke HDMI" || pass "dpms off does not poke disconnected HDMI"
: >"$dpms_log"
run_dpms on
if grep -q . "$dpms_log"; then
  fail_at "dpms on is no-op when eDP is already lit"
else
  pass "dpms on is no-op when already lit"
fi

# Docked: both enabled outputs, skip a disabled one.
printf '[{"name":"eDP-1","disabled":false,"dpmsStatus":false},{"name":"HDMI-A-1","disabled":false,"dpmsStatus":false},{"name":"HDMI-A-2","disabled":true,"dpmsStatus":false}]\n' >"$dpms_dir/mon.json"
: >"$dpms_log"
run_dpms on
grep -q 'monitor = "eDP-1"' "$dpms_log" || fail_at "dpms on docked hits eDP"
grep -q 'monitor = "HDMI-A-1"' "$dpms_log" || fail_at "dpms on docked hits live HDMI"
grep -q 'HDMI-A-2' "$dpms_log" && fail_at "dpms on must skip disabled outputs" || pass "dpms on only live outputs"

# --- asahi-bluetooth-power usage ---
"$ROOT/asahi-bluetooth-power" 2>/dev/null && fail_at "bluetooth-power no-arg should fail" || pass "asahi-bluetooth-power usage"

# --- asahi-cmd-record usage ---
"$ROOT/asahi-cmd-record" bogus 2>/dev/null && fail_at "cmd-record bad arg should fail" || pass "asahi-cmd-record usage"
[ "$("$ROOT/asahi-cmd-record" status)" = "stopped" ] || fail_at "cmd-record status is stopped when idle"
pass "asahi-cmd-record status idle"
"$ROOT/asahi-cmd-record" --help >/dev/null 2>&1 && fail_at "cmd-record --help exits 2" || true
grep -q 'webcam' <<<"$("$ROOT/asahi-cmd-record" --help 2>&1 || true)" || fail_at "cmd-record usage mentions webcam"
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

# Keyboard key while idled off: step from the saved level, resume restore is then a no-op.
mkdir -p "$tmp/mc-bin" "$tmp/mc-state" "$tmp/mc-run"
cat >"$tmp/mc-bin/brightnessctl" <<EOS
#!/usr/bin/env bash
v=\$(<"$tmp/mc-led") cmd="" val=""
for a; do
  case "\$a" in -m) cmd=m ;; info|get|max) cmd=\$a ;; set) cmd=set ;; -*) ;; *) val=\$a ;; esac
done
case "\$cmd" in
  m) printf 'kbd_backlight,leds,%s,%s%%,255\n' "\$v" \$(( (v * 100 + 127) / 255 )) ;;
  get) echo "\$v" ;;
  max) echo 255 ;;
  set) [[ \$val == *% ]] && val=\$(( \${val%\%} * 255 / 100 )); echo "\$val" >"$tmp/mc-led" ;;
esac
exit 0
EOS
chmod +x "$tmp/mc-bin/brightnessctl"
cp "$tmp/bin/qs" "$tmp/mc-bin/qs"
mc() { PATH="$tmp/mc-bin:$PATH" XDG_RUNTIME_DIR="$tmp/mc-run" ASAHI_IDLE_STATE_DIR="$tmp/mc-state" "$ROOT/$@"; }
echo 0 >"$tmp/mc-led"; echo 128 >"$tmp/mc-state/keyboard"
mc asahi-media-control keyboard-brightness raise
[[ $(<"$tmp/mc-led") == 140 && ! -e $tmp/mc-state/keyboard ]] \
  || fail_at "key while idled off steps from the saved 50 % to 55 % (got $(<"$tmp/mc-led"))"
mc asahi-idle-brightness keyboard-restore
[[ $(<"$tmp/mc-led") == 140 ]] || fail_at "resume restore undid the key press (got $(<"$tmp/mc-led"))"
mc asahi-media-control keyboard-brightness raise
[[ $(<"$tmp/mc-led") == 153 ]] || fail_at "plain key raise 55 % -> 60 % (got $(<"$tmp/mc-led"))"
pass "keyboard key while idled off steps from the saved level"

# Display key while idle-dimmed: same (a lower used to end at the pre-dim level after the restore).
cp "$tmp/bin/hyprctl" "$tmp/mc-bin/hyprctl"
echo 69 >"$tmp/mc-led"; echo 153 >"$tmp/mc-state/display-apple-panel-bl"
mc asahi-media-control brightness lower
[[ $(<"$tmp/mc-led") == 140 && ! -e $tmp/mc-state/display-apple-panel-bl ]] \
  || fail_at "display key while dimmed steps from the saved 60 % to 55 % (got $(<"$tmp/mc-led"))"
mc asahi-idle-brightness restore
[[ $(<"$tmp/mc-led") == 140 ]] || fail_at "resume restore undid the display key (got $(<"$tmp/mc-led"))"
pass "display key while idle-dimmed steps from the saved level"

grep -F 'enable --now aurora-kbd-light.service' "$ROOT/../../install/components.sh" >/dev/null \
  || fail_at "asahi-system enables Aurora's ALS keyboard daemon"
grep -e "kbd_backlight' set 30%" "$ROOT/../../install/components.sh" >/dev/null \
  && fail_at "asahi-system still forces a one-shot 30% keyboard backlight" \
  || pass "asahi-system leaves the keyboard light to aurora-kbd-light; no 30% oneshot"

# --- asahi-clamshell: lid paths with fake hyprctl / busctl / setsid / brightnessctl / sleep ---
# The real ones would read the live lid and inhibitors, and could zero the backlight and lock the session.
clam_dir="$tmp/clam"
mkdir -p "$clam_dir/bin" "$clam_dir/idle"
clam_eval="$clam_dir/eval.log"
clam_disp="$clam_dir/dispatch.log"
clam_mon="$clam_dir/mon.json"
export CLAM_LOG="$clam_dir/calls.log" FAKE_LID=false FAKE_BLOCK=""
: >"$clam_eval"
: >"$clam_disp"
: >"$CLAM_LOG"
cat >"$clam_dir/bin/hyprctl" <<'EOF'
#!/bin/sh
if [ "$1" = monitors ]; then
  cat "${HYPR_MONITORS_JSON:?}"
  exit 0
fi
if [ "$1" = eval ]; then
  shift
  printf '%s\n' "$*" >> "${HYPR_EVAL_LOG:?}"
  exit 0
fi
if [ "$1" = dispatch ]; then
  printf '%s\n' "$*" >> "${HYPR_DISPATCH_LOG:?}"
  exit 0
fi
exit 0
EOF
cat >"$clam_dir/bin/busctl" <<'EOF'
#!/bin/sh
case "$*" in
  *LidClosed*) echo "b $FAKE_LID" ;;
  *ListInhibitors*)
    if [ -n "$FAKE_BLOCK" ]; then
      echo '{"type":"a(ssssuu)","data":[[["handle-lid-switch","asahi-hdmi","connected","block",0,1]]]}'
    else
      echo '{"type":"a(ssssuu)","data":[[]]}'
    fi
    ;;
esac
EOF
cat >"$clam_dir/bin/brightnessctl" <<'EOF'
#!/bin/sh
echo "brightnessctl $*" >> "$CLAM_LOG"
case "$*" in *" get") echo 50 ;; *" max") echo 100 ;; esac
exit 0
EOF
# setsid only logs: the real one would start asahi-lock on the live session.
printf '#!/bin/sh\necho "setsid $*" >> "$CLAM_LOG"\n' >"$clam_dir/bin/setsid"
printf '#!/bin/sh\nexit 0\n' >"$clam_dir/bin/systemd-inhibit"
# The real logger wrote these fake lid decisions into the journal (`journalctl -t asahi-clamshell`).
printf '#!/bin/sh\nexit 0\n' >"$clam_dir/bin/logger"
printf '#!/bin/sh\nexit 0\n' >"$clam_dir/bin/sleep"
chmod +x "$clam_dir/bin/"*
run_clam() {
  PATH="$clam_dir/bin:$PATH" ASAHI_CLAMSHELL_FLAG="$clam_dir/flag" \
    ASAHI_IDLE_STATE_DIR="$clam_dir/idle" HYPR_MONITORS_JSON="$clam_mon" \
    HYPR_EVAL_LOG="$clam_eval" HYPR_DISPATCH_LOG="$clam_disp" \
    "$ROOT/asahi-clamshell" "$@"
}

printf '[{"name":"eDP-1","disabled":false,"dpmsStatus":true}]\n' >"$clam_mon"
run_clam close
[ ! -e "$clam_dir/flag" ] || fail_at "laptop-only close must not set the clamshell flag"
if grep -q . "$clam_eval" || grep -q . "$CLAM_LOG"; then
  fail_at "laptop-only close must not eval eDP, dim or lock (got $(cat "$clam_eval" "$CLAM_LOG" | tr '\n' ' '))"
else
  pass "laptop-only close is a no-op"
fi

# Someone else's block inhibitor (cable in, external not up) stops logind's suspend: blank + lock.
FAKE_LID=true FAKE_BLOCK=1
: >"$clam_disp"
run_clam close
grep -q 'setsid -f .*/asahi-lock$' "$CLAM_LOG" || fail_at "blocked laptop-only close must start asahi-lock"
grep -q 'action = "disable", monitor = "eDP-1"' "$clam_disp" || fail_at "blocked laptop-only close must DPMS eDP off"
[ ! -e "$clam_dir/flag" ] && pass "blocked laptop-only close blanks and locks" || fail_at "blocked close set the flag"
FAKE_LID=false FAKE_BLOCK=""

printf '[{"name":"eDP-1","disabled":false,"dpmsStatus":false}]\n' >"$clam_mon"
: >"$clam_disp"
run_clam open
grep -q 'monitor = "eDP-1"' "$clam_disp" || fail_at "open must DPMS-on eDP (got $(tr '\n' ' ' <"$clam_disp"))"
grep -q HDMI "$clam_disp" && fail_at "open must not DPMS a disconnected HDMI" \
  || pass "open unblanks eDP"

# USB-C unplugged in clamshell: Hyprland lists only FALLBACK, which is not an external.
printf '[{"name":"FALLBACK","disabled":false,"dpmsStatus":true}]\n' >"$clam_mon"
: >"$clam_dir/flag"
: >"$clam_eval"
echo 300 >"$clam_dir/idle/display-test-bl"
run_clam apply
grep -q 'output = "eDP-1", disabled = false' "$clam_eval" || fail_at "FALLBACK-only apply must re-enable eDP"
[ ! -e "$clam_dir/flag" ] && pass "FALLBACK is not an external: apply re-enables eDP, drops the flag" \
  || fail_at "FALLBACK kept the clamshell flag (lid inhibitor stays up)"
grep -q 'device=test-bl set 300' "$CLAM_LOG" && [ ! -e "$clam_dir/idle/display-test-bl" ] \
  && pass "lid open: apply restores the backlight close zeroed" || fail_at "apply did not restore the backlight"
FAKE_LID=true
: >"$clam_dir/flag"
echo 300 >"$clam_dir/idle/display-test-bl"
run_clam apply
[ -e "$clam_dir/idle/display-test-bl" ] && pass "lid closed: apply leaves the backlight to open" \
  || fail_at "apply relit the closed panel"
FAKE_LID=false

# --- asahi-battery-alertd: low, critical, then the charger: one short low-urgency "Charging" card ---
# Lines are "capacity status ac-online" per poll; the fake sleep applies the next one, then ends the daemon.
ad="$tmp/alertd"
mkdir -p "$ad/bin" "$ad/psy/macsmc-battery" "$ad/psy/macsmc-ac"
echo Battery >"$ad/psy/macsmc-battery/type"
echo Mains >"$ad/psy/macsmc-ac/type"
printf '%s\n' "15 Discharging 0" "9 Discharging 0" "9 Charging 1" "10 Charging 1" >"$ad/polls"
cat >"$ad/bin/sleep" <<EOF
#!/usr/bin/env bash
n=\$((\$(cat "$ad/n" 2>/dev/null || echo 1) + 1)); echo "\$n" >"$ad/n"
read -r c s o < <(sed -n "\${n}p" "$ad/polls") || kill "\$PPID"
echo "\$c" >"$ad/psy/macsmc-battery/capacity"; echo "\$s" >"$ad/psy/macsmc-battery/status"; echo "\$o" >"$ad/psy/macsmc-ac/online"
EOF
printf '#!/bin/sh\nprintf "%%s|" "$@" >>"%s"; echo >>"%s"\n' "$ad/notes" "$ad/notes" >"$ad/bin/notify-send"
chmod +x "$ad/bin/"*
echo 15 >"$ad/psy/macsmc-battery/capacity"; echo Discharging >"$ad/psy/macsmc-battery/status"; echo 0 >"$ad/psy/macsmc-ac/online"
# `|| true` inside: the subshell waits for timeout itself, so its "Terminated" note goes to /dev/null too.
(ASAHI_PSY_DIR="$ad/psy" PATH="$ad/bin:$PATH" timeout 10 "$ROOT/asahi-battery-alertd" || true) 2>/dev/null
[ "$(grep -c . "$ad/notes")" = 3 ] && grep -q '|normal|.*Low battery' "$ad/notes" && grep -q '|critical|.*Critical battery' "$ad/notes" \
  && sed -n 3p "$ad/notes" | grep -q '^-a|Asahi Battery|-u|low|-t|4000|.*Charging · 9%' \
  && pass "battery alerts: low, critical, then one low-urgency Charging card on the charger" \
  || fail_at "battery alerts: $(cat "$ad/notes" 2>/dev/null)"

# --- launcher / system menu still has no Hibernate ---
grep -q 'title: "Hibernate"' "$ROOT/../quickshell/remix/modules/launcher/Data.js" \
  && fail_at "launcher still lists Hibernate" \
  || pass "launcher has no Hibernate row"

# Aurora: time_to_* raise ENODATA outside their charge state; a failed read (a directory here) is empty and quiet.
mv "$bat/time_to_empty_now" "$tmp/tte.bak"; mkdir "$bat/time_to_empty_now"
err=$( { ASAHI_POWER_SUPPLY_PATH="$tmp/power" "$ROOT/asahi-battery" >"$tmp/bat.out"; } 2>&1 ); rc=$?
rmdir "$bat/time_to_empty_now"; mv "$tmp/tte.bak" "$bat/time_to_empty_now"
[ "$rc" -eq 0 ] && [ -z "$err" ] && [ -s "$tmp/bat.out" ] && pass "asahi-battery: unreadable time_to_empty_now is quiet" ||
  fail_at "asahi-battery on a failed time_to read: rc=$rc err=[$err]"

if [ "$fail" -ne 0 ]; then
  echo "asahi_energy_test.sh: FAILED"
  exit 1
fi
echo "asahi_energy_test.sh: all ok"
