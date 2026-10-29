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
cp "$ROOT/asahi-idle" "$bin/"
cp -r "$ROOT/lib" "$bin/"
run="$tmp/run"
idle_log="$tmp/state/asahi/idle.log"
edp='[{"name":"eDP-1","disabled":false,"dpmsStatus":false}]'
export CALLS="$tmp/calls" XDG_RUNTIME_DIR="$run" XDG_STATE_HOME="$tmp/state" PATH="$fake:$PATH"
export FAKE_LID=false FAKE_MON="$edp" FAKE_SUSPEND_FAILED=0 WAKE_AFTER=0 ASAHI_PSY_DIR="$tmp/psy"
# On AC: thresholds saver 180, dim 300, off 600 (the real /sys would make the test follow the charger).
mkdir -p "$tmp/psy/ac" "$tmp/psy/macsmc-battery" && echo Mains >"$tmp/psy/ac/type" && echo 1 >"$tmp/psy/ac/online"

# Siblings log their call; clamshell / stay-awake status follow flag files.
for s in asahi-screensaver asahi-dpms asahi-idle-brightness; do
  printf '#!/bin/sh\necho "%s $*" >>"$CALLS"\n' "$s" >"$bin/$s"
done
printf '#!/bin/sh\n[ -e "$XDG_RUNTIME_DIR/clamshell" ]\n' >"$bin/asahi-clamshell"
printf '#!/bin/sh\n[ -e "$XDG_RUNTIME_DIR/stay-awake" ]\n' >"$bin/asahi-stay-awake"

printf '#!/bin/sh\nprintf "%%s\\n" "$FAKE_MON"\n' >"$fake/hyprctl"
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
idle wake
/usr/bin/sleep 0.3
[ "$(grep -c ' slept ' "$idle_log")" = 2 ] && pass "a later wake logs no sleep" || fail_at "$(grep slept "$idle_log")"
rm -f "$run/now" "$run/on-sleep-90"
idle why >/dev/null && pass "why is read-only and exits 0" || fail_at "why exited non-zero"

if [ "$fail" -ne 0 ]; then
  echo "asahi_idle_test.sh: FAILED"
  exit 1
fi
echo "asahi_idle_test.sh: all ok"
