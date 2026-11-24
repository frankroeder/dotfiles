#!/usr/bin/env bash
# asahi-idle against stub siblings and fake hyprctl / busctl / systemctl / pgrep / loginctl /
# pactl / pw-record / notify-send / sleep / date. Nothing live: no DPMS, backlight, lock or suspend.
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/bin"
fake="$tmp/fake"
mkdir -p "$bin" "$fake" "$tmp/run" "$tmp/state"
cp "$ROOT/asahi-idle" "$ROOT/asahi-claude-activity" "$bin/"
cp -r "$ROOT/lib" "$bin/"
run="$tmp/run"
idle_log="$tmp/state/asahi/idle.log"
edp='[{"name":"eDP-1","disabled":false,"dpmsStatus":false}]'
export CALLS="$tmp/calls" XDG_RUNTIME_DIR="$run" XDG_STATE_HOME="$tmp/state" PATH="$fake:$PATH"
export FAKE_LID=false FAKE_MON="$edp" FAKE_SUSPEND_FAILED=0 WAKE_AFTER=0 ASAHI_PSY_DIR="$tmp/psy" ASAHI_SUSPEND_STATS="$tmp/stats"
# On AC: thresholds saver 180, dim 300, off 600 (the real /sys would make the test follow the charger).
mkdir -p "$tmp/psy/ac" "$tmp/psy/macsmc-battery" && echo Mains >"$tmp/psy/ac/type" && echo 1 >"$tmp/psy/ac/online"

# Siblings log their call; clamshell / stay-awake status follow flag files.
for s in asahi-screensaver asahi-dpms asahi-idle-brightness; do
  printf '#!/bin/sh\necho "%s $*" >>"$CALLS"\n' "$s" >"$bin/$s"
done
printf '#!/bin/sh\n[ -e "$XDG_RUNTIME_DIR/clamshell" ]\n' >"$bin/asahi-clamshell"
printf '#!/bin/sh\n[ -e "$XDG_RUNTIME_DIR/stay-awake" ]\n' >"$bin/asahi-stay-awake"

printf '#!/bin/sh\nif [ "$1" = activewindow ]; then printf "%%s\\n" "${FAKE_ACTIVE:-null}"; else printf "%%s\\n" "$FAKE_MON"; fi\n' >"$fake/hyprctl"
printf '#!/bin/sh\necho "b $FAKE_LID"\n' >"$fake/busctl"
printf '#!/bin/sh\n[ "${FAKE_LOCKED:-1}" = 1 ]\n' >"$fake/pgrep"
printf '#!/bin/sh\nexit 0\n' >"$fake/pactl"
printf '#!/bin/sh\nexit 0\n' >"$fake/pw-record"
printf '#!/bin/sh\necho "loginctl $*" >>"$CALLS"\n' >"$fake/loginctl"
printf '#!/bin/sh\necho "notify $*" >>"$CALLS"\n' >"$fake/notify-send"
# suspend is refused once while $run/refuse exists.
cat >"$fake/systemctl" <<'EOF'
#!/bin/sh
case "$1" in
  is-failed) [ "$FAKE_SUSPEND_FAILED" = 1 ] ;;
  suspend)
    echo "systemctl suspend" >>"$CALLS"
    if [ -e "$XDG_RUNTIME_DIR/refuse" ]; then rm -f "$XDG_RUNTIME_DIR/refuse"; exit 1; fi
    ;;
esac
EOF
# Instant; records its argument; the WAKE_AFTER-th call is input (touches the wake stamp); runs
# $run/on-sleep-<secs> if present (the sleep-drain tests move the clock and the gauge there).
cat >"$fake/sleep" <<'EOF'
#!/bin/sh
echo "$1" >>"$XDG_RUNTIME_DIR/sleeps"
[ "$(wc -l <"$XDG_RUNTIME_DIR/sleeps")" = "$WAKE_AFTER" ] && touch "$XDG_RUNTIME_DIR/asahi-idle-wake"
[ -x "$XDG_RUNTIME_DIR/on-sleep-$1" ] && "$XDG_RUNTIME_DIR/on-sleep-$1"
exit 0
EOF
# `date +%s` reads $run/now while it exists; everything else is the real date.
cat >"$fake/date" <<'EOF'
#!/bin/sh
if [ "$1" = +%s ] && [ -s "$XDG_RUNTIME_DIR/now" ]; then cat "$XDG_RUNTIME_DIR/now"; else exec /usr/bin/date "$@"; fi
EOF
chmod +x "$bin"/asahi-* "$fake"/*
idle() { : >"$CALLS"; rm -f "$run/sleeps"; "$bin/asahi-idle" "$@"; }

touch "$run/asahi-idle-locking"
idle wake
[ ! -s "$CALLS" ] && grep -q 'wake ignored: lock surface' "$idle_log" \
  && pass "fresh locking flag: wake does nothing" || fail_at "wake under the lock surface: $(cat "$CALLS")"
rm -f "$run/asahi-idle-locking"

FAKE_LID=true
idle wake
grep -q 'asahi-dpms on' "$CALLS" && fail_at "lid closed, no clamshell: wake lit the panel" \
  || pass "lid closed, no clamshell: wake keeps the panel dark"
grep -q 'asahi-screensaver stop' "$CALLS" && pass "lid closed: wake still stops the saver" \
  || fail_at "lid closed: saver left running under the lock"
touch "$run/clamshell"
idle wake
grep -q 'asahi-dpms on' "$CALLS" && ! grep -q restore "$CALLS" \
  && pass "clamshell: wake lights the external, keeps the closed panel's backlight" || fail_at "clamshell wake: $(cat "$CALLS")"
rm -f "$run/clamshell"
FAKE_LID=false
idle wake
grep -q 'asahi-dpms on' "$CALLS" && grep -q 'asahi-idle-brightness restore' "$CALLS" \
  && pass "lid open: wake runs dpms on + restore" || fail_at "lid open wake: $(cat "$CALLS")"

FAKE_LID=true
idle keys
[ ! -s "$CALLS" ] && pass "keys with the lid closed does nothing" || fail_at "keys under a closed lid: $(cat "$CALLS")"
FAKE_LID=false
idle keys
grep -q 'keyboard-restore' "$CALLS" && pass "keys with the lid open relights the keyboard" || fail_at "keys: $(cat "$CALLS")"

touch "$run/stay-awake"
idle at 300
[ ! -s "$CALLS" ] && grep -q 'skipped: stay-awake' "$idle_log" && pass "stay-awake skips at 300" || fail_at "stay-awake: $(cat "$CALLS")"
rm -f "$run/stay-awake"

FAKE_MON='[{"name":"FALLBACK","disabled":false,"dpmsStatus":true}]'
idle sleep && grep -q 'systemctl suspend' "$CALLS" \
  && pass "FALLBACK is not an external: manual sleep suspends" || fail_at "FALLBACK sleep: $(cat "$CALLS")"
FAKE_MON='[{"name":"eDP-1","disabled":false,"dpmsStatus":true},{"name":"HDMI-A-1","disabled":false,"dpmsStatus":true}]'
if idle sleep; then fail_at "manual sleep with HDMI on must exit 1"; fi
grep -q 'notify.*Sleep blocked' "$CALLS" && ! grep -q 'systemctl suspend' "$CALLS" \
  && pass "external on: manual sleep is blocked with a notification" || fail_at "blocked sleep: $(cat "$CALLS")"
FAKE_MON=$edp

# AC, 300 s = dim. Unlocked it dims; locked by hand it goes dark (off) instead of staying lit.
FAKE_LOCKED=0 idle at 300
grep -q 'asahi-idle-brightness dim' "$CALLS" && ! grep -q 'asahi-dpms off' "$CALLS" \
  && pass "unlocked: the dim threshold dims" || fail_at "unlocked dim: $(cat "$CALLS")"
idle at 300
grep -q 'asahi-dpms off' "$CALLS" && ! grep -q 'asahi-idle-brightness dim' "$CALLS" \
  && pass "locked: the dim threshold turns the display off" || fail_at "locked dim: $(cat "$CALLS")"

# A fullscreen window keeps the screen on: AC dim skipped; under the lock it still goes dark; on battery the off step
# (lock, display off, sleep) still runs.
export FAKE_ACTIVE='{"fullscreen":2}'
FAKE_LOCKED=0 idle at 300
[ ! -s "$CALLS" ] && grep -q 'ac dim skipped: fullscreen' "$idle_log" && pass "fullscreen: the AC dim step is skipped" \
  || fail_at "fullscreen dim: $(cat "$CALLS")"
idle at 300
grep -q 'asahi-dpms off' "$CALLS" && pass "fullscreen under the lock: the display still goes dark" || fail_at "locked fullscreen: $(cat "$CALLS")"
echo 0 >"$tmp/psy/ac/online"
FAKE_LOCKED=0 idle at 150
grep -q 'battery dim skipped: fullscreen' "$idle_log" && pass "fullscreen on battery: no dim" || fail_at "battery fullscreen dim"
FAKE_LOCKED=0 idle at 300
grep -q 'asahi-dpms off' "$CALLS" && grep -q 'systemctl suspend' "$CALLS" \
  && pass "fullscreen on battery: the off step still locks, darkens and sleeps" || fail_at "battery fullscreen off: $(cat "$CALLS")"
echo 1 >"$tmp/psy/ac/online"
export FAKE_ACTIVE='{"fullscreen":1}'
FAKE_LOCKED=0 idle at 300
grep -q 'asahi-idle-brightness dim' "$CALLS" && pass "maximized is not fullscreen: dims" || fail_at "maximized: $(cat "$CALLS")"
unset FAKE_ACTIVE

# off: refused suspend keeps the loop alive; it polls every 5 s and retries a minute later.
touch "$run/refuse"
idle at 600 || fail_at "off loop exited non-zero after a refused suspend"
[ "$(grep -c 'systemctl suspend' "$CALLS")" = 2 ] && grep -q 'suspend refused' "$idle_log" && grep -q 'sleep (retry)' "$idle_log" \
  && pass "refused suspend: the off loop retries" || fail_at "refused suspend: $(cat "$CALLS")"
[ "$(grep -cx 5 "$run/sleeps")" = 11 ] && pass "blocked-sleep loop polls every 5 s, retries every 12th" \
  || fail_at "retry polls: $(grep -cx 5 "$run/sleeps") x 5 s"

# Last suspend failed: no suspend, one critical notification per boot, the loop ends on input.
FAKE_SUSPEND_FAILED=1 WAKE_AFTER=80
idle at 600
[ "$(grep -c 'notify.*critical.*Suspend is failing' "$CALLS")" = 1 ] && ! grep -q 'systemctl suspend' "$CALLS" \
  && grep -q 'sleep skipped: last suspend failed' "$idle_log" && pass "failed suspend: notified once, no suspend" \
  || fail_at "failed suspend: $(cat "$CALLS")"
idle at 600
grep -q notify "$CALLS" && fail_at "failed suspend notified twice in one boot" || pass "failed suspend: no repeat notification"
# EBUSY (-16): a wake event (key press) aborted the entry, no driver refused: sleep stays on.
mkdir -p "$tmp/stats" && echo -16 >"$tmp/stats/last_failed_errno"
idle at 600
grep -q 'systemctl suspend' "$CALLS" && pass "EBUSY abort: not a failed suspend" || fail_at "EBUSY abort: $(cat "$CALLS")"
rm -f "$tmp/stats/last_failed_errno"

# mark before sleep; the first wake after resume logs the drain 90 s later (the gauge reads high right
# after resume), minus the awake draw meanwhile; a sleep on the charger is tagged and not corrected.
FAKE_SUSPEND_FAILED=0
bat="$tmp/psy/macsmc-battery"
drained() { for _ in $(seq 30); do grep -q "$1" "$idle_log" && return 0; /usr/bin/sleep 0.1; done; return 1; }
echo 0 >"$tmp/psy/ac/online"
echo 1000000 >"$run/now"; echo 50000000 >"$bat/energy_now"
idle mark
echo 1007380 >"$run/now"; echo 49800000 >"$bat/energy_now"
printf '#!/bin/sh\necho 1007470 >%s/now; echo 49000000 >%s/energy_now; echo -6000000 >%s/power_now\n' "$run" "$bat" "$bat" >"$run/on-sleep-90"
chmod +x "$run/on-sleep-90"
idle wake
drained 'slept 2h3m, used 0.85 Wh (0.41 W)' && [ ! -e "$run/asahi-idle-sleep-mark" ] \
  && pass "sleep drain: read 90 s after the wake, minus the awake draw" || fail_at "sleep drain: $(tail -n 2 "$idle_log")"
echo 1 >"$tmp/psy/ac/online"
echo 2000000 >"$run/now"; echo 40000000 >"$bat/energy_now"
idle mark
[ "$(cat "$run/asahi-idle-sleep-mark")" = "2000000 40000000 ac" ] && pass "mark records time, charge and the charger" \
  || fail_at "mark: $(cat "$run/asahi-idle-sleep-mark")"
echo 2003600 >"$run/now"
printf '#!/bin/sh\necho 2003690 >%s/now; echo 41000000 >%s/energy_now\n' "$run" "$bat" >"$run/on-sleep-90"
idle wake
drained 'slept 1h0m on AC, gained 1.00 Wh' && pass "sleep on the charger: tagged, no awake correction" \
  || fail_at "AC sleep: $(tail -n 2 "$idle_log")"
grep -q 'Slept without' "$CALLS" && fail_at "woke locked, yet a no-lock card" || pass "wake after a locked sleep: no card"
# The lock did not come up before sleep (omarchy-system-sleep-lock's report): a critical card at wake.
idle mark
FAKE_LOCKED=0 idle wake
grep -q 'notify -a idle -u critical Slept without the lock screen' "$CALLS" && grep -q 'woke without a lock' "$idle_log" \
  && pass "wake after a sleep without the lock: critical card" || fail_at "no-lock wake: $(cat "$CALLS")"
idle wake
/usr/bin/sleep 0.3
[ "$(grep -c ' slept ' "$idle_log")" = 2 ] && pass "a later wake logs no sleep" || fail_at "$(grep slept "$idle_log")"
rm -f "$run/now" "$run/on-sleep-90"
idle why >/dev/null && pass "why is read-only and exits 0" || fail_at "why exited non-zero"
# why --json (Battery pane card): stay-awake, a logind idle block (a delay is no hold), nothing else here.
cat >"$fake/systemd-inhibit" <<'SI'
#!/bin/sh
echo '[{"who":"mpv","comm":"mpv","what":"idle","why":"Playing video","mode":"block"},{"who":"UPower","comm":"upowerd","what":"sleep","why":"Pause","mode":"delay"}]'
SI
chmod +x "$fake/systemd-inhibit"
: >"$run/stay-awake"
json=$(idle why --json)
if jq -e 'length == 2 and .[0].kind == "stay-awake" and .[1] == {kind: "inhibitor", who: "mpv", why: "Playing video"}' <<<"$json" >/dev/null; then
  pass "why --json: stay-awake and logind blocks as rows (delays left out)"
else
  fail_at "why --json: $json"
fi
rm -f "$run/stay-awake" "$fake/systemd-inhibit"
idle release 'x; rm -rf /' 2>/dev/null && fail_at "release took a bad sender" || pass "release refuses anything but a portal sender id"

# Claude Code hooks: one marker per session_id (sanitized), silent, exit 0; a count file for the bar, gone at 0.
claude() { printf '{"session_id":"%s","hook_event_name":"x"}' "$2" | "$bin/asahi-claude-activity" "$1"; }
out=$(claude start s1; claude beat '../s2'; claude beat s1)
[ -z "$out" ] && [ -e "$run/claude-activity/s1" ] && [ -e "$run/claude-activity/s2" ] && [ "$(cat "$run/claude-activity.count")" = 2 ] \
  && pass "claude-activity: silent, a marker per session (path stripped), count 2" || fail_at "claude markers: $out $(ls "$run/claude-activity")"
claude stop s2
[ "$(cat "$run/claude-activity.count")" = 1 ] && [ ! -e "$run/claude-activity/s2" ] && pass "claude-activity stop: count 1" \
  || fail_at "claude stop: $(ls "$run/claude-activity")"
echo nonsense | "$bin/asahi-claude-activity" beat && [ -e "$run/claude-activity/ppid-$$" ] && rm "$run/claude-activity/ppid-$$" \
  && pass "claude-activity: no session_id falls back to the caller's pid, exit 0" || fail_at "claude fallback: $(ls "$run/claude-activity")"
# macOS (shared settings.json and dotfiles): hooks do nothing, status says none.
mkdir -p "$tmp/mac" && printf '#!/bin/sh\necho Darwin\n' >"$tmp/mac/uname" && chmod +x "$tmp/mac/uname"
PATH="$tmp/mac:$PATH" claude start m1
if [ ! -e "$run/claude-activity/m1" ] && ! PATH="$tmp/mac:$PATH" "$bin/asahi-claude-activity" status >/dev/null; then
  pass "claude-activity off Linux: no marker, status none"
else
  fail_at "claude-activity on macOS"
fi
# Battery fixture: charging (the real battery must not decide these cases).
export ASAHI_BATTERY_DIR="$tmp/bat"; mkdir -p "$ASAHI_BATTERY_DIR"; echo Charging >"$ASAHI_BATTERY_DIR/status"; echo 60 >"$ASAHI_BATTERY_DIR/capacity"
# At work: saver and dim still run; off locks and darkens but does not sleep, then sleeps once the session stops.
FAKE_LOCKED=0 idle at 180
grep -q 'asahi-screensaver start' "$CALLS" && pass "claude working: the saver still starts" || fail_at "claude saver: $(cat "$CALLS")"
FAKE_LOCKED=0 idle at 300
grep -q 'asahi-idle-brightness dim' "$CALLS" && pass "claude working: dim still runs" || fail_at "claude dim: $(cat "$CALLS")"
# (20 lock waits + 62 s, then three retries.)
WAKE_AFTER=120 FAKE_LOCKED=0 idle at 600
grep -q 'loginctl lock-session' "$CALLS" && grep -q 'asahi-dpms off' "$CALLS" && ! grep -q 'systemctl suspend' "$CALLS" \
  && grep -q 'sleep skipped: Claude Code working (1 session)' "$idle_log" \
  && pass "claude working: off locks and darkens, no sleep (nor on retry)" || fail_at "claude off: $(cat "$CALLS")"
printf '#!/bin/sh\nprintf "{\\"session_id\\":\\"s1\\"}" | %s/asahi-claude-activity stop\n' "$bin" >"$run/on-sleep-5"
chmod +x "$run/on-sleep-5"
claude start s1
idle at 600
[ "$(grep -c 'systemctl suspend' "$CALLS")" = 1 ] && [ ! -e "$run/claude-activity.count" ] && tail -n 1 "$idle_log" | grep -q 'sleep (retry)' \
  && pass "claude stops behind the lock: the off loop sleeps without input" || fail_at "claude stop re-arm: $(cat "$CALLS")"
rm -f "$run/on-sleep-5"
# A crashed session (no hook for 15 min) holds nothing and is pruned.
claude start s3
touch -d '-16 minutes' "$run/claude-activity/s3"
idle at 600
grep -q 'systemctl suspend' "$CALLS" && [ ! -e "$run/claude-activity/s3" ] && pass "stale claude marker: sleeps, pruned" \
  || fail_at "stale claude: $(cat "$CALLS")"
# Discharging below 20 %: Claude holds nothing (the 2 % power-off would end the run anyway).
claude start s5
echo Discharging >"$ASAHI_BATTERY_DIR/status"; echo 15 >"$ASAHI_BATTERY_DIR/capacity"
idle at 600
grep -q 'systemctl suspend' "$CALLS" && pass "claude on a low battery: sleeps anyway" || fail_at "claude low battery: $(cat "$CALLS")"
echo Charging >"$ASAHI_BATTERY_DIR/status"; echo 60 >"$ASAHI_BATTERY_DIR/capacity"
claude stop s5
claude start s4
idle why | grep -q 'Claude Code working (1 session)' && idle why --json | jq -e 'any(.[]; .kind == "claude")' >/dev/null \
  && pass "why / why --json name Claude Code" || fail_at "why claude: $(idle why)"
claude stop s4

# asahi-suspend-failed runs only for a real failure: -16 (EBUSY, a key or click during entry) is no fault.
cond=$(sed -n 's/^ExecCondition=//p' "$ROOT/../systemd/system/asahi-suspend-failed.service")
errno_file=$(mktemp)
cond_rc() { echo "$1" >"$errno_file"; eval "${cond//\/sys\/power\/suspend_stats\/last_failed_errno/$errno_file}" >/dev/null 2>&1; echo $?; }
got="$(cond_rc -16) $(cond_rc -22) $(cond_rc 0)"
rm -f "$errno_file"
[ "$got" = "1 0 0" ] && pass "suspend-failed: skipped for -16, runs for -22 / other" || fail_at "suspend-failed ExecCondition (got $got)"

if [ "$fail" -ne 0 ]; then
  echo "asahi_idle_test.sh: FAILED"
  exit 1
fi
echo "asahi_idle_test.sh: all ok"
