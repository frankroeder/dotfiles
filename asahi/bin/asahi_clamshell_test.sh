#!/usr/bin/env bash
# asahi-clamshell close / apply against stub siblings, a fake DRM sysfs and fake hyprctl / busctl /
# systemd-inhibit / sleep. Nothing live: no eDP-1 change, DPMS, lock or inhibitor.
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
bin="$tmp/bin"
fake="$tmp/fake"
drm="$tmp/drm"
mkdir -p "$bin" "$fake" "$tmp/run" "$drm/card2-DP-1"
cp "$ROOT/asahi-clamshell" "$bin/"
cp -r "$ROOT/lib" "$bin/"
export CALLS="$tmp/calls" LOG="$tmp/log" XDG_RUNTIME_DIR="$tmp/run" ASAHI_DRM_PATH="$drm" PATH="$fake:$PATH"

for s in asahi-dpms asahi-idle-brightness asahi-lock; do
  printf '#!/bin/sh\necho "%s $*" >>"$CALLS"\n' "$s" >"$bin/$s"
done
# monitors -j prints $FAKE_MON; eval logs the Lua it was given.
cat >"$fake/hyprctl" <<'EOF'
#!/bin/sh
case "$1" in
  monitors) printf '%s\n' "$FAKE_MON" ;;
  eval) echo "eval $2" >>"$CALLS" ;;
esac
EOF
# Lid closed; ListInhibitors reports a foreign block inhibitor (asahi-hdmi-lid-inhibit) while FAKE_BLOCKED=1.
cat >"$fake/busctl" <<'EOF'
#!/bin/sh
case "$*" in
  *LidClosed*) echo "b true" ;;
  *ListInhibitors*)
    if [ "${FAKE_BLOCKED:-1}" = 1 ]; then
      echo '{"data":[[["handle-lid-switch","asahi-hdmi","HDMI","block",0,0]]]}'
    else
      echo '{"data":[[]]}'
    fi
    ;;
esac
EOF
printf '#!/bin/sh\necho "inhibit" >>"$CALLS"\n' >"$fake/systemd-inhibit"
printf '#!/bin/sh\nexit 0\n' >"$fake/sleep"
printf '#!/bin/sh\nshift 2\n[ "$1" = -- ] && shift\necho "$*" >>"$LOG"\n' >"$fake/logger"
# Synchronous: the detached asahi-lock must log before the checks read $CALLS.
printf '#!/bin/sh\n[ "$1" = -f ] && shift\nexec "$@"\n' >"$fake/setsid"
chmod +x "$bin"/* "$fake"/*

edp='{"name":"eDP-1","disabled":false,"dpmsStatus":true}'
dp() { printf '[%s,{"name":"DP-1","disabled":false,"dpmsStatus":%s}]' "$edp" "$1"; }

close() {
  : >"$CALLS"
  : >"$LOG"
  rm -f "$XDG_RUNTIME_DIR/asahi-clamshell"
  echo "$1" >"$drm/card2-DP-1/enabled"
  FAKE_MON="$2" bash "$bin/asahi-clamshell" close
}

close enabled "$(dp true)"
grep -q 'eval .*eDP-1.*disabled = true' "$CALLS" && [ -e "$XDG_RUNTIME_DIR/asahi-clamshell" ] \
  && pass "lit external: close disables eDP-1 (clamshell)" || fail_at "lit external: $(cat "$CALLS")"

close disabled "$(dp true)"
if grep -q 'eval .*eDP-1' "$CALLS"; then
  fail_at "listed but never modeset: close disabled eDP-1 (zero lit outputs)"
elif grep -q 'asahi-lock' "$CALLS" && [ ! -e "$XDG_RUNTIME_DIR/asahi-clamshell" ]; then
  pass "listed but never modeset: close keeps eDP-1, blanks + locks"
  grep -q 'blank + lock: eDP-1=on/- DP-1=on/disabled' "$LOG" \
    && pass "the journal line says why, with each output's state" || fail_at "log: $(cat "$LOG")"
else
  fail_at "listed but never modeset: $(cat "$CALLS")"
fi

close disabled "$(dp false)"
grep -q 'eval .*eDP-1.*disabled = true' "$CALLS" \
  && pass "idle-blanked (DPMS-off) external still counts: clamshell" || fail_at "DPMS-off external: $(cat "$CALLS")"

FAKE_BLOCKED=0 close disabled "$(dp true)"
[ ! -s "$CALLS" ] && pass "unlit external, nothing blocks the suspend: close leaves it to logind" \
  || fail_at "unblocked unlit close: $(cat "$CALLS")"

close disabled "[$edp]"
grep -q 'asahi-lock' "$CALLS" && ! grep -q 'eval' "$CALLS" \
  && pass "laptop-only, blocked lid: blanks + locks" || fail_at "laptop-only blocked close: $(cat "$CALLS")"

# apply in clamshell: the external turned unlit -> eDP-1 comes back (never zero lit outputs).
: >"$CALLS"
: >"$XDG_RUNTIME_DIR/asahi-clamshell"
echo disabled >"$drm/card2-DP-1/enabled"
FAKE_MON="$(dp true)" bash "$bin/asahi-clamshell" apply
grep -q 'eval .*eDP-1.*disabled = false' "$CALLS" \
  && pass "apply: unlit external in clamshell brings eDP-1 back" || fail_at "apply unlit: $(cat "$CALLS")"

[ "$fail" = 0 ] && echo "asahi_clamshell_test.sh: all ok"
exit "$fail"
