#!/usr/bin/env bash
# The session lock is hyprlock. Every lock path goes through the asahi-lock
# restart guard.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

conf="$ROOT/../hypr/hyprlock.conf"
if grep -q 'asahi-battery lock' "$conf" && grep -q '/proc/uptime' "$conf" && grep -q '/etc/hostname' "$conf"; then
  pass "hyprlock.conf has uptime, hostname, and battery charge state"
else
  fail_at "hyprlock.conf missing uptime/hostname/battery"
fi
if grep -q 'blur_passes = 0' "$conf" && ! grep -q 'brightness =' "$conf"; then
  pass "no blur brightness (does nothing while blur_passes is 0)"
else
  fail_at "hyprlock.conf dims with blur brightness, which does not run when blur is off"
fi
if grep -q 'asahi-theme/hyprlock.conf' "$conf" && grep -q '\$lock_bg' "$conf" && grep -q 'lock-wallpaper' "$conf"; then
  pass "hyprlock.conf sources wallpaper-adaptive colors"
else
  fail_at "hyprlock.conf missing theme or wallpaper"
fi
if grep -q 'outline_thickness = 8' "$conf" \
  && grep -q 'capslock_color = \$lock_caps$' "$conf" \
  && grep -q 'animation = inputFieldColors, 1, 3, out' "$conf" \
  && grep -q 'asahi-lock-caps' "$conf" \
  && grep -q '\$lock_caps = rgb(f9e2af)' "$ROOT/../hypr/hyprlock-theme.conf" \
  && ! grep -q '\$lock_caps =' "$conf" \
  && ! grep -q 'capslock_color = \$lock_fail' "$conf"; then
  pass "caps lock border uses the theme warning color"
else
  fail_at "hyprlock caps lock indicator"
fi

lock="$ROOT/asahi-lock"
if grep -q 'hyprlock "$@"' "$lock" && grep -q 'run --no-fade-in' "$lock"; then
  pass "asahi-lock runs hyprlock"
else
  fail_at "asahi-lock does not run hyprlock"
fi

theme="$ROOT/../hypr/hyprlock-theme.conf"
if [ -f "$theme" ] && grep -q '\$lock_bg' "$theme"; then
  pass "hyprlock-theme.conf ships mocha fallback"
else
  fail_at "hyprlock-theme.conf missing"
fi

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

# The uptime program is the one in the conf, not a copy of it.
uptime_prog=$(sed -n "s/.*awk '\\(.*\\)' \\/proc\\/uptime.*/\\1/p" "$conf")
uptime_day=$(awk "$uptime_prog" <<<"90061 0")
uptime_hour=$(awk "$uptime_prog" <<<"3661 0")
uptime_min=$(awk "$uptime_prog" <<<"61 0")
caps="$ROOT/asahi-lock-caps"
tmpcaps="$(mktemp -d)"
mkdir -p "$tmpcaps/input0::capslock" "$tmpcaps/input1::capslock"
printf '0\n' >"$tmpcaps/input0::capslock/brightness"
printf '0\n' >"$tmpcaps/input1::capslock/brightness"
off=$(ASAHI_CAPS_DIR="$tmpcaps" "$caps"; echo .)
printf '1\n' >"$tmpcaps/input1::capslock/brightness"
on=$(ASAHI_CAPS_DIR="$tmpcaps" "$caps")
empty=$(ASAHI_CAPS_DIR="$tmpcaps/none" "$caps"; echo .)
printf '%s\n' '{"keyboards":[{"capsLock": true}]}' >"$tmpcaps/on.json"
printf '%s\n' '{"keyboards":[{"capsLock": false}]}' >"$tmpcaps/off.json"
printf '%s\n' '{' '  "capsLock": false,' '  "capsLock": true' '}' >"$tmpcaps/lines.json"
from_json=$(ASAHI_CAPS_DIR="$tmpcaps/none" ASAHI_CAPS_HYPRCTL_JSON="$tmpcaps/on.json" "$caps")
json_off=$(ASAHI_CAPS_DIR="$tmpcaps/none" ASAHI_CAPS_HYPRCTL_JSON="$tmpcaps/off.json" "$caps"; echo .)
json_lines=$(ASAHI_CAPS_DIR="$tmpcaps/none" ASAHI_CAPS_HYPRCTL_JSON="$tmpcaps/lines.json" "$caps")
rm -rf "$tmpcaps"
if [ "$off" = "." ] && [ "$on" = '<span weight="bold">CAPS</span>' ] && [ "$empty" = "." ] \
  && [ "$from_json" = '<span weight="bold">CAPS</span>' ] && [ "$json_off" = "." ] \
  && [ "$json_lines" = '<span weight="bold">CAPS</span>' ]; then
  pass "asahi-lock-caps follows the LED, and hyprctl only when no LED exists"
else
  fail_at "asahi-lock-caps off=[$off] on=[$on] empty=[$empty] json=[$from_json] json_off=[$json_off] lines=[$json_lines]"
fi

if [ "$uptime_day" = "up  1d  01h  01m" ] && [ "$uptime_hour" = "up  1h  01m" ] && [ "$uptime_min" = "up  1m" ]; then
  pass "uptime label formats days, hours, and minutes"
else
  fail_at "uptime label formatted as [$uptime_day] [$uptime_hour] [$uptime_min]"
fi

# Fake hyprlock: fails twice, then unlocks (exit 0). The guard must run it 3x.
tmp="$(mktemp -d)"
cat >"$tmp/hyprlock" <<'SH'
#!/usr/bin/env bash
n=$(( $(cat "$RUNS" 2>/dev/null || echo 0) + 1 )); echo "$n" >"$RUNS"
[ "$n" -ge 3 ]
SH
chmod +x "$tmp/hyprlock"
printf '#!/usr/bin/env bash\nexit 1\n' >"$tmp/pgrep"; chmod +x "$tmp/pgrep"
RUNS="$tmp/runs" XDG_RUNTIME_DIR="$tmp" XDG_STATE_HOME="$tmp" ASAHI_LOCK_RETRY_S=0 PATH="$tmp:$PATH" "$ROOT/asahi-lock"
if [ "$(cat "$tmp/runs")" = 3 ] && [ "$(grep -c 'hyprlock exit' "$tmp/asahi/hyprlock.log")" = 3 ]; then
  pass "asahi-lock restarts a crashed hyprlock until exit 0, logs each exit"
else
  fail_at "asahi-lock ran hyprlock $(cat "$tmp/runs" 2>/dev/null) times, want 3"
fi
# This session's hyprlock already up: no second one. Only its WAYLAND_DISPLAY counts (not a nested preview's).
rm -f "$tmp/runs"
printf '#!/usr/bin/env bash\necho "$*" >"%s/pgrep-args"\n' "$tmp" >"$tmp/pgrep"
WAYLAND_DISPLAY=wayland-1 RUNS="$tmp/runs" XDG_RUNTIME_DIR="$tmp" XDG_STATE_HOME="$tmp" PATH="$tmp:$PATH" "$ROOT/asahi-lock"
if [ ! -e "$tmp/runs" ] && grep -q -- "-x --env WAYLAND_DISPLAY=wayland-1 hyprlock" "$tmp/pgrep-args"; then
  pass "asahi-lock leaves this session's running hyprlock alone"
else
  fail_at "asahi-lock with hyprlock up: runs=$(cat "$tmp/runs" 2>/dev/null) pgrep $(cat "$tmp/pgrep-args" 2>/dev/null)"
fi
rm -rf "$tmp"

if [ "$fail" -ne 0 ]; then
  echo "$fail failed"
  exit 1
fi
echo "all passed"
