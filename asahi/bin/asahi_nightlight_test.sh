#!/usr/bin/env bash
# Smoke tests for asahi-nightlight. Mocked hyprctl; no live CTM writes.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NL="$ROOT/asahi-nightlight"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin" "$tmp/state"
printf '6000\n' >"$tmp/temp"
: >"$tmp/log"

cat >"$tmp/hyprsunset.conf" <<'EOF'
profile {
    time = 07:00
    identity = true
}
# profile {
#     time = 20:00
#     temperature = 1500
# }
EOF

cat >"$tmp/bin/hyprctl" <<EOF
#!/bin/sh
echo "\$*" >> "$tmp/log"
if [ "\$1" = hyprsunset ] && [ "\$2" = identity ]; then
  echo ok
  exit 0
fi
if [ "\$1" = hyprsunset ] && [ "\$2" = temperature ]; then
  if [ -n "\${3:-}" ]; then
    printf '%s\n' "\$3" > "$tmp/temp"
    echo ok
    exit 0
  fi
  cat "$tmp/temp"
  exit 0
fi
exit 0
EOF
chmod +x "$tmp/bin/hyprctl"

cat >"$tmp/bin/pgrep" <<'EOF'
#!/bin/sh
[ "${1:-}" = "-x" ] && [ "${2:-}" = "hyprsunset" ]
EOF
chmod +x "$tmp/bin/pgrep"

cat >"$tmp/bin/notify-send" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x "$tmp/bin/notify-send"

run() {
  PATH="$tmp/bin:$PATH" \
    ASAHI_STATE_DIR="$tmp/state" \
    ASAHI_NIGHTLIGHT_STATE="$tmp/state/nightlight.json" \
    ASAHI_NIGHTLIGHT_CONF="$tmp/hyprsunset.conf" \
    ASAHI_NIGHTLIGHT_TRIES=3 \
    ASAHI_NIGHTLIGHT_SETTLE=0 \
    "$NL" "$@"
}

run nope >/dev/null 2>&1 && fail_at "bad cmd should fail" || pass "usage"

: >"$tmp/log"
printf '6000\n' >"$tmp/temp"
rm -f "$tmp/state/nightlight.json"
run toggle
eq_temp=$(cat "$tmp/temp")
[ "$eq_temp" = "1500" ] && pass "toggle on → 1500 from conf" || fail_at "toggle on got=$eq_temp"
on=$(jq -r '.on' "$tmp/state/nightlight.json")
[ "$on" = "true" ] && pass "state on after warm" || fail_at "state on=$on"
grep -q 'hyprsunset temperature 1500' "$tmp/log" && pass "set 1500" || fail_at "no temperature 1500 in log"
grep -q 'hyprsunset identity' "$tmp/log" && fail_at "identity on first toggle" || pass "no identity on warm"

: >"$tmp/log"
run toggle
on=$(jq -r '.on' "$tmp/state/nightlight.json")
[ "$on" = "false" ] && pass "state off after identity" || fail_at "state on=$on"
grep -q 'hyprsunset identity' "$tmp/log" && pass "off → identity" || fail_at "no identity on off"
grep -q 'hyprsunset temperature 6500' "$tmp/log" && fail_at "off set 6500" || pass "off does not set 6500"
# identity leaves reported K unchanged
[ "$(cat "$tmp/temp")" = "1500" ] && pass "reported K still 1500 after identity" || fail_at "temp=$(cat "$tmp/temp")"

# warmer / cooler (the bar chip's wheel): only while on, 250 K steps, clamped, and the next toggle-on keeps it.
: >"$tmp/log"
run cooler
[ ! -s "$tmp/log" ] && pass "cooler while off: nothing" || fail_at "cooler while off: $(cat "$tmp/log")"
run toggle; run cooler; run cooler
[ "$(jq -r '.temperature' "$tmp/state/nightlight.json")" = 2000 ] && pass "cooler twice: 1500 → 2000 K" || fail_at "cooler: $(cat "$tmp/state/nightlight.json")"
run toggle; run toggle
[ "$(cat "$tmp/temp")" = 2000 ] && pass "off and on again keeps the chosen 2000 K" || fail_at "re-on temp=$(cat "$tmp/temp")"
# One run per wheel gesture (n notches); runs at once queue (flock) instead of fighting over the temperature.
run cooler 3
[ "$(jq -r '.temperature' "$tmp/state/nightlight.json")" = 2750 ] && pass "cooler 3: 2000 → 2750 K in one run" || fail_at "cooler 3: $(cat "$tmp/state/nightlight.json")"
: >"$tmp/notified"
printf '#!/bin/sh\necho "$*" >>"%s/notified"\n' "$tmp" >"$tmp/bin/notify-send"
run warmer & run warmer & run warmer & wait
[ "$(jq -r '.temperature' "$tmp/state/nightlight.json")" = 2000 ] && [ "$(cat "$tmp/temp")" = 2000 ] && [ ! -s "$tmp/notified" ] \
  && pass "three runs at once: all three steps land, no failure card" || fail_at "parallel: $(cat "$tmp/state/nightlight.json") temp=$(cat "$tmp/temp") notified=[$(cat "$tmp/notified")]"
printf '#!/bin/sh\nexit 0\n' >"$tmp/bin/notify-send"
for _ in 1 2 3 4 5; do run warmer; done
[ "$(jq -r '.temperature' "$tmp/state/nightlight.json")" = 1000 ] && pass "warmer clamps at 1000 K" || fail_at "warmer clamp: $(cat "$tmp/state/nightlight.json")"
run toggle

cat >"$tmp/hyprsunset.conf" <<'EOF'
profile { identity = true }
profile { temperature = 1800 }
EOF
rm -f "$tmp/state/nightlight.json"
: >"$tmp/log"
run toggle
[ "$(cat "$tmp/temp")" = "1800" ] && pass "conf temperature 1800" || fail_at "got=$(cat "$tmp/temp")"

# Temperature command succeeds but the reported K never moves.
cat >"$tmp/bin/hyprctl" <<EOF
#!/bin/sh
echo "\$*" >> "$tmp/log"
if [ "\$1" = hyprsunset ] && [ "\$2" = temperature ] && [ -z "\${3:-}" ]; then
  cat "$tmp/temp"
  exit 0
fi
exit 0
EOF
chmod +x "$tmp/bin/hyprctl"
rm -f "$tmp/state/nightlight.json"
printf '6000\n' >"$tmp/temp"
rc=0
run toggle || rc=$?
[ "$rc" -ne 0 ] && pass "failed apply exits non-zero" || fail_at "failed apply rc=$rc"
if [ -f "$tmp/state/nightlight.json" ] && [ "$(jq -r '.on' "$tmp/state/nightlight.json")" = "true" ]; then
  fail_at "failed apply wrote on=true"
else
  pass "failed apply does not record on"
fi

bind="$ROOT/../hypr/conf.d/bindings.lua"
if grep -q 'asahi-nightlight' "$bind"; then
  fail_at "nightlight still bound (menu-only now)"
else
  pass "no nightlight bind"
fi
actions="$ROOT/../quickshell/remix/modules/launcher/LauncherWindow.qml"
if grep -q 'key: "nightlight"' "$actions"; then
  pass "nightlight in Launcher Actions"
else
  fail_at "nightlight missing from Launcher Actions"
fi
if grep -q 'temperature = 1500' "$ROOT/../hypr/hyprsunset.conf"; then
  pass "conf night temp 1500"
else
  fail_at "hyprsunset.conf missing temperature = 1500"
fi
if grep -q 'identity = true' "$ROOT/../hypr/hyprsunset.conf"; then
  pass "conf identity profile"
else
  fail_at "hyprsunset.conf missing identity"
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "all ok"
