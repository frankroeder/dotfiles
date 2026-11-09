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
if grep -q 'asahi-theme/hyprlock.conf' "$conf" && grep -q '\$lock_bg' "$conf" && grep -q 'asahi/lock-screen' "$conf"; then
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
# Every unlock plays the wallpaper intro: hyprlock starts only once its first frame is on screen (`ready`); play runs on
# hyprlock's unlock line (it lingers after a Touch ID unlock), again at exit (a no-op in WallpaperIntro).
printf '#!/bin/sh\necho hyprlock >>"%s/qs-calls"\necho "[DEBUG]: Unlocked, exiting!"\nsleep 1\necho hyprlock-exit >>"%s/qs-calls"\n' "$tmp" "$tmp" >"$tmp/hyprlock"
printf '#!/bin/sh\nexit 1\n' >"$tmp/pgrep"
printf '#!/bin/sh\necho "$*" | sed "s/.* call wallpaperIntro //" >>"%s/qs-calls"\n[ "$7" = ready ] || exit 0\n[ -e "%s/ready-once" ] && echo true || { : >"%s/ready-once"; echo false; }\n' "$tmp" "$tmp" "$tmp" >"$tmp/qs"
chmod +x "$tmp/hyprlock" "$tmp/pgrep" "$tmp/qs"
XDG_RUNTIME_DIR="$tmp" XDG_STATE_HOME="$tmp" PATH="$tmp:$PATH" "$ROOT/asahi-lock"
if [ "$(tr "\n" "|" <"$tmp/qs-calls" 2>/dev/null)" = "arm|ready|ready|hyprlock|play|hyprlock-exit|play|" ]; then
  pass "lock arms the wallpaper intro, waits for it; the unlock line plays it, before hyprlock exits"
else
  fail_at "intro on unlock: [$(cat "$tmp/qs-calls" 2>/dev/null)]"
fi
# Touch ID: fingerprint auth on, the glyph only with an enrolled finger, fprintd asked once a minute, alpha 30–100 %.
if grep -q '^  fingerprint:enabled = true' "$conf" && grep -q 'cmd\[update:200\] ~/.dotfiles/asahi/bin/asahi-lock-touchid' "$conf"; then
  pass "hyprlock.conf: Touch ID auth + breathing glyph"
  grep -q '^  animation = fadeOut, 0' "$conf" && pass "hyprlock.conf: no fade-out (dimmed the intro's first frame to grey)" \
    || fail_at "hyprlock.conf fades out again"
else
  fail_at "hyprlock.conf lost fingerprint:enabled or the Touch ID glyph"
fi
printf '#!/bin/sh\necho x >>"%s/fp-calls"\n[ -e "%s/enrolled" ] && printf "Fingerprints for user u on sensor (press):\\n - #0: right-index-finger\\n"\nexit 0\n' \
  "$tmp" "$tmp" >"$tmp/fprintd-list"
chmod +x "$tmp/fprintd-list"
touchid() { XDG_RUNTIME_DIR="$tmp" PATH="$tmp:$PATH" "$ROOT/asahi-lock-touchid"; }
a=$(touchid)
: >"$tmp/enrolled"
b=$(touchid)
rm -f "$tmp/asahi-lock-touchid"
c=$(touchid)
d=$(touchid)
alpha=$(sed -n "s/^<span alpha='\([0-9]*\)%'>.*/\1/p" <<<"$c")
if [ -z "$a$b" ] && [ "$(wc -l <"$tmp/fp-calls")" -eq 2 ] && [ -n "$d" ] && [ -n "$alpha" ] && [ "$alpha" -ge 30 ] && [ "$alpha" -le 100 ]; then
  pass "Touch ID glyph: hidden without a finger, fprintd cached, alpha $alpha %"
else
  fail_at "Touch ID glyph: a=[$a] b=[$b] c=[$c] calls=$(wc -l <"$tmp/fp-calls")"
fi
rm -rf "$tmp"

if [ "$fail" -ne 0 ]; then
  echo "$fail failed"
  exit 1
fi
echo "all passed"
