#!/usr/bin/env bash
# The session lock is the Quickshell lock (remix/lock.qml). Every lock path goes through the asahi-lock restart guard.
# A fake qs plays both the lock (`qs -p …/lock.qml`) and the shell's wallpaperIntro IPC.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

lock="$ROOT/asahi-lock"
lockqml="$ROOT/../quickshell/remix/lock.qml"

idle="$ROOT/../hypr/hypridle.conf"
if grep -q 'lock_cmd = ~/.dotfiles/asahi/bin/asahi-lock$' "$idle" && grep -q '^  inhibit_sleep = 3$' "$idle"; then
  pass "hypridle locks through asahi-lock, inhibit_sleep = 3"
else
  fail_at "hypridle lock_cmd / inhibit_sleep"
fi
if grep -q 'exec_cmd(scripts .. "/asahi-lock")' "$ROOT/../hypr/conf.d/bindings.lua"; then
  pass "Super+Escape uses asahi-lock"
else
  fail_at "bindings.lua Lock bind must run asahi-lock"
fi
if grep -q 'systemd-inhibit --what=handle-lid-switch --who=asahi-clamshell' "$ROOT/asahi-clamshell"; then
  pass "asahi-clamshell holds a handle-lid-switch inhibitor"
else
  fail_at "asahi-clamshell missing lid inhibitor"
fi
# hyprlock is gone (2026-11-22): no fallback, no conf, no orb script, not installed.
if ! grep -v "^#" "$lock" | grep -q hyprlock && [ ! -e "$ROOT/../hypr/hyprlock.conf" ] && [ ! -e "$ROOT/asahi-lock-touchid" ] \
  && ! grep -q '^  hyprlock \\$' "$ROOT/../dnf.sh"; then
  pass "no hyprlock: asahi-lock runs only the Quickshell lock"
else
  fail_at "hyprlock still referenced"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# Fake qs: the lock runs N times per $LOCK_MODE; the intro answers `ready` true on the second ask.
cat >"$tmp/qs" <<SH
#!/bin/sh
case "\$*" in
  *"-p "*lock.qml*)
    n=\$(( \$(cat "$tmp/runs" 2>/dev/null || echo 0) + 1 )); echo "\$n" >"$tmp/runs"
    echo lock >>"$tmp/calls"; [ -e "$tmp/asahi-locked" ] && echo flag >>"$tmp/calls"
    case "\${LOCK_MODE:-ok}" in
      ok) echo "  WARN qml: Session locked" >&2; sleep 1   # a confirmed lock outlives the 0.5 s watchdog window
        echo "  WARN qml: Unlocked, exiting!" >&2; sleep 0.2; echo lock-exit >>"$tmp/calls" ;;
      third) [ "\$n" -ge 3 ] || exit 1 ;;
      crash) echo "  WARN qml: Session locked" >&2; echo "  WARN qml: Unlocked, exiting!" >&2; kill -SEGV \$\$ ;;
      hang1) [ "\$n" -ge 2 ] || exec sleep 30   # runs, never engages: no confirmation line
        echo "  WARN qml: Session locked" >&2; echo "  WARN qml: Unlocked, exiting!" >&2 ;;
      dead) exit 1 ;;
    esac ;;
  *wallpaperIntro*) echo "\$7" >>"$tmp/calls"; [ "\$7" = ready ] || exit 0
    [ -e "$tmp/ready-once" ] && echo true || { : >"$tmp/ready-once"; echo false; } ;;
esac
exit 0
SH
printf '#!/bin/sh\necho "$*" >"%s/pgrep-args"\nexit 1\n' "$tmp" >"$tmp/pgrep"
printf '#!/bin/sh\necho "notify $*" >>"%s/calls"\n' "$tmp" >"$tmp/notify-send"
chmod +x "$tmp/qs" "$tmp/pgrep" "$tmp/notify-send"
guard() { rm -f "$tmp/runs" "$tmp/calls" "$tmp/ready-once"; rc=0
  XDG_RUNTIME_DIR="$tmp" XDG_STATE_HOME="$tmp" ASAHI_LOCK_RETRY_S=0 ASAHI_LOCK_SECURE_TICKS=5 PATH="$tmp:$PATH" LOCK_MODE="$1" \
    "$lock" 2>/dev/null || rc=$?; }

guard ok
if [ "$rc" = 0 ] && [ "$(tr '\n' '|' <"$tmp/calls")" = "arm|ready|ready|lock|flag|play|lock-exit|play|" ] \
  && grep -q 'lock exit 0' "$tmp/asahi/lock.log" && grep -q '^unlocked$' "$tmp/asahi-lock.reader" && [ ! -e "$tmp/asahi-locked" ] \
  && ! grep -q 'no lock after' "$tmp/asahi/lock.log"; then
  pass "lock arms the intro, waits for it, runs qs -p lock.qml under the asahi-locked flag; the unlock line plays the intro"
else
  fail_at "unlock: rc=$rc calls=[$(tr '\n' '|' <"$tmp/calls" 2>/dev/null)]"
fi
guard third
if [ "$rc" = 0 ] && [ "$(cat "$tmp/runs")" = 3 ] && [ "$(grep -c 'lock exit' "$tmp/asahi/lock.log")" -ge 3 ]; then
  pass "a crashed lock is restarted until it exits 0, each exit logged"
else
  fail_at "restart: rc=$rc runs=$(cat "$tmp/runs" 2>/dev/null)"
fi
[ "$(grep -c '^notify .*Lock screen failed' "$tmp/calls")" = 1 ] \
  && pass "a lock crashing at start (a QML error: qs exits at once) is warned about once while the loop retries" \
  || fail_at "crash at start warning: [$(tr '\n' '|' <"$tmp/calls")]"
guard crash
if [ "$rc" = 0 ] && [ "$(cat "$tmp/runs")" = 1 ] && grep -q 'crashed after unlock' "$tmp/asahi/lock.log"; then
  pass "a crash past the unlock line does not lock again"
else
  fail_at "crash after unlock: rc=$rc runs=$(cat "$tmp/runs" 2>/dev/null)"
fi
guard hang1
if [ "$rc" = 0 ] && [ "$(cat "$tmp/runs")" = 2 ] && grep -q 'no lock after' "$tmp/asahi/lock.log" \
  && [ "$(grep -c '^notify .*Lock screen failed' "$tmp/calls")" = 1 ]; then
  pass "a lock that runs but never engages is killed, warned about once, retried"
else
  fail_at "never-engaging lock: rc=$rc runs=$(cat "$tmp/runs" 2>/dev/null) calls=[$(tr '\n' '|' <"$tmp/calls")]"
fi
guard dead
if [ "$rc" = 1 ] && [ "$(cat "$tmp/runs")" = 31 ] && [ "$(tail -n 1 "$tmp/calls")" = play ] && [ ! -e "$tmp/asahi-locked" ]; then
  pass "out of retries: exit 1, the held intro still plays, the flag goes"
else
  fail_at "out of retries: rc=$rc runs=$(cat "$tmp/runs" 2>/dev/null) last=[$(tail -n 1 "$tmp/calls" 2>/dev/null)]"
fi
# This session's lock already up: no second one. Only its WAYLAND_DISPLAY counts (not a nested preview's).
printf '#!/bin/sh\necho "$*" >"%s/pgrep-args"\nexit 0\n' "$tmp" >"$tmp/pgrep"
rm -f "$tmp/runs"
WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR="$tmp" XDG_STATE_HOME="$tmp" PATH="$tmp:$PATH" "$lock"
if [ ! -e "$tmp/runs" ] && grep -qF -- "-f --env WAYLAND_DISPLAY=wayland-1 ^([^ ]*/)?qs -p .*/remix/lock\.qml\$" "$tmp/pgrep-args"; then
  pass "asahi-lock leaves this session's running lock alone (the qs -p process only)"
else
  fail_at "lock already up: runs=$(cat "$tmp/runs" 2>/dev/null) pgrep [$(cat "$tmp/pgrep-args" 2>/dev/null)]"
fi

# The lock's PAM: a password file (pam_unix, then Aurora's Touch ID re-arm as system-auth runs it; no pam_fprintd: it
# would hold a typed password) beside the finger.
pamd="$ROOT/../quickshell/lockpam"
if grep -qx 'auth     requisite  pam_unix.so' "$pamd/password" && grep -qx -- '-auth    optional   pam_aurora_touchid.so' "$pamd/password" \
  && ! grep -q '^[^#]*pam_fprintd' "$pamd/password" \
  && grep -q '^auth  required  pam_fprintd.so max-tries=3' "$pamd/fingerprint" && grep -q 'enabled: lock.demo' "$lockqml"; then
  pass "lock PAM: password = pam_unix + the Touch ID re-arm, finger = pam_fprintd; the state IPC exists only in demo mode"
else
  fail_at "lock PAM files / demo-only IPC"
fi
# Review 2026-11-20: qs without -n (any running instance of the path, a nested preview too, made it exit 0 = "done");
# the orb does not breathe (a loop redraws every output all lock long); printable keys only; MaxTries is final; the
# test submit is gated on LOCK_IPC_SUBMIT.
if ! grep -q 'qs -n' "$lock" && grep -q 'breathe: false' "$lockqml" \
  && grep -qF '/^[^\x00-\x1f\x7f]+$/.test(event.text)' "$lockqml" && grep -q 'result === PamResult.MaxTries' "$lockqml" \
  && grep -q 'LOCK_IPC_SUBMIT' "$lockqml"; then
  pass "lock: no qs -n, no idle breathing, printable keys only, MaxTries final, test submit gated"
else
  fail_at "lock review guards"
fi
if grep -q 'respectInhibitors: false' "$lockqml" && grep -q 'execDetached(\[lock.dpms, "off"\])' "$lockqml" \
  && grep -q 'if (lock.blanked) Quickshell.execDetached(\[lock.dpms, "on"\])' "$lockqml"; then
  pass "lock: displays off after 30 s idle (video inhibitors ignored), back on for a Touch ID unlock in the dark"
else
  fail_at "lock idle blank"
fi
# Lift-off: xray (the desktop drawn under the lock) goes on only in unlock(), after PAM; off at start and release.
unlock_fn=$(awk '/function unlock\(\)/,/^  }/' "$lockqml")
if grep -q 'lock.xray(true)' <<<"$unlock_fn" && [ "$(grep -c 'xray(true)' "$lockqml")" = 1 ] \
  && grep -q 'Component.onCompleted: { lock.xray(false)' "$lockqml" \
  && grep -q 'onLockedChanged: if (!locked) { lock.xray(false); Qt.quit() }' "$lockqml"; then
  pass "lift-off: session_lock_xray only after PAM said yes, off at every start and at release"
else
  fail_at "lift-off xray guards"
fi

if [ "$fail" -ne 0 ]; then
  echo "$fail failed"
  exit 1
fi
echo "all passed"
