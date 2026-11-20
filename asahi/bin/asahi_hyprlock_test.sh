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
  && [ "$(grep -c 'capslock_color = \$lock_caps$' "$conf")" = 2 ] \
  && grep -q 'animation = inputFieldColors, 1, 3, out' "$conf" \
  && grep -q '\$lock_caps = rgb(f9e2af)' "$ROOT/../hypr/hyprlock-theme.conf" \
  && ! grep -q '\$lock_caps =' "$conf" \
  && ! grep -q 'capslock_color = \$lock_fail' "$conf"; then
  pass "caps lock border and tag use the theme warning color"
else
  fail_at "hyprlock caps lock indicator"
fi
# The CAPS word is hyprlock's own: a borderless field that fills while Caps Lock is on, under a static label in the
# capsule's colour (the capsule is solid $lock_bg for that: on glass the word left a ghost). No script polls for it
# (asahi-lock-caps is gone: two runs a second were ~15 ms of CPU).
tag=$(awk '/^input-field \{/ { blk = "" } { blk = blk $0 "\n" } /^\}/ { if (blk ~ /size = 100, 46/) printf "%s", blk; blk = "" }' "$conf")
word=$(awk '/^label \{/ { blk = "" } { blk = blk $0 "\n" } /^\}/ { if (blk ~ /<b>CAPS<\/b>/) printf "%s", blk; blk = "" }' "$conf")
if grep -q 'outline_thickness = 0' <<<"$tag" && grep -q 'capslock_color = \$lock_caps$' <<<"$tag" \
  && grep -q 'inner_color = rgba(00000000)' <<<"$tag" && grep -q 'fail_color = rgba(00000000)' <<<"$tag" \
  && ! grep -q 'swap_font_color' <<<"$tag" \
  && grep -q 'text = <b>CAPS</b>$' <<<"$word" && grep -q 'color = \$lock_bg$' <<<"$word" \
  && [ "$(sed -n 's/^  position = \([-0-9]*\),.*/\1/p' <<<"$tag")" = "$(sed -n 's/^  position = \([-0-9]*\),.*/\1/p' <<<"$word")" ] \
  && grep -A5 '^  size = 832, 134' "$conf" | grep -q '^  inner_color = \$lock_bg$' \
  && ! grep -q 'asahi-lock-caps' "$conf" && [ ! -e "$ROOT/asahi-lock-caps" ]; then
  pass "CAPS tag: a field filled by Caps Lock + a static word in the capsule's own colour (solid \$lock_bg), no polling script"
else
  fail_at "CAPS tag: tag=[$tag] word=[$word]"
fi
# swap_font_color on a borderless field redraws the idle lock screen at the refresh rate (hyprlock 0.9.7: the
# placeholder is requested again every frame, each answer schedules a frame). The dots field colours its texts itself.
dots=$(awk '/^input-field \{/ { blk = "" } { blk = blk $0 "\n" } /^\}/ { if (blk ~ /size = 624, 134/) printf "%s", blk; blk = "" }' "$conf")
if ! grep -q '^ *swap_font_color' "$conf" \
  && grep -qF "fail_text = <span foreground='##\$lock_hexfail'>Failed (\$ATTEMPTS)</span>" <<<"$dots" \
  && grep -qF "check_text = <span foreground='##\$lock_hexcheck'>Checking…</span>" <<<"$dots" \
  && grep -q 'font_color = \$lock_fg$' <<<"$dots" && grep -q 'invert_numlock = true' <<<"$dots" \
  && [ "$(grep -c '_color = rgba(00000000)' <<<"$dots")" = 6 ]; then
  pass "dots field: no swap_font_color (it redrew every frame), texts coloured by markup, no state fills"
else
  fail_at "dots field: [$dots]"
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
RUNS="$tmp/runs" ASAHI_LOCKER=hyprlock XDG_RUNTIME_DIR="$tmp" XDG_STATE_HOME="$tmp" ASAHI_LOCK_RETRY_S=0 PATH="$tmp:$PATH" "$ROOT/asahi-lock"
if [ "$(cat "$tmp/runs")" = 3 ] && [ "$(grep -c 'hyprlock exit' "$tmp/asahi/hyprlock.log")" = 3 ]; then
  pass "asahi-lock restarts a crashed hyprlock until exit 0, logs each exit"
else
  fail_at "asahi-lock ran hyprlock $(cat "$tmp/runs" 2>/dev/null) times, want 3"
fi
# hyprlock 0.9.7 segfaults in its exit teardown after unlocking: no relock.
rm -f "$tmp/runs"
printf '#!/usr/bin/env bash\necho x >>"$RUNS"\necho "[DEBUG]: Unlocked, exiting!"\nkill -SEGV $$\n' >"$tmp/hyprlock"
printf '#!/bin/sh\nexit 1\n' >"$tmp/qs"; chmod +x "$tmp/qs"   # never the live shell's intro
rc=0
RUNS="$tmp/runs" ASAHI_LOCKER=hyprlock XDG_RUNTIME_DIR="$tmp" XDG_STATE_HOME="$tmp" ASAHI_LOCK_RETRY_S=0 PATH="$tmp:$PATH" "$ROOT/asahi-lock" \
  2>/dev/null || rc=$?
if [ "$rc" = 0 ] && [ "$(wc -l <"$tmp/runs")" = 1 ] && grep -q 'crashed after unlock' "$tmp/asahi/hyprlock.log"; then
  pass "asahi-lock does not relock after hyprlock crashes past its unlock"
else
  fail_at "crash after unlock: rc=$rc runs=$(wc -l <"$tmp/runs" 2>/dev/null)"
fi
# This session's hyprlock already up: no second one. Only its WAYLAND_DISPLAY counts (not a nested preview's).
rm -f "$tmp/runs"
printf '#!/usr/bin/env bash\necho "$*" >"%s/pgrep-args"\n' "$tmp" >"$tmp/pgrep"
WAYLAND_DISPLAY=wayland-1 RUNS="$tmp/runs" ASAHI_LOCKER=hyprlock XDG_RUNTIME_DIR="$tmp" XDG_STATE_HOME="$tmp" PATH="$tmp:$PATH" "$ROOT/asahi-lock"
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
ASAHI_LOCKER=hyprlock XDG_RUNTIME_DIR="$tmp" XDG_STATE_HOME="$tmp" PATH="$tmp:$PATH" "$ROOT/asahi-lock"
if [ "$(tr "\n" "|" <"$tmp/qs-calls" 2>/dev/null)" = "arm|ready|ready|hyprlock|play|hyprlock-exit|play|" ]; then
  pass "lock arms the wallpaper intro, waits for it; the unlock line plays it, before hyprlock exits"
else
  fail_at "intro on unlock: [$(cat "$tmp/qs-calls" 2>/dev/null)]"
fi
# Out of retries (hyprlock keeps crashing): play still runs, else the held first frame stays over the wallpaper.
rm -f "$tmp/qs-calls"
printf '#!/bin/sh\nexit 1\n' >"$tmp/hyprlock"
rc=0
ASAHI_LOCKER=hyprlock XDG_RUNTIME_DIR="$tmp" XDG_STATE_HOME="$tmp" ASAHI_LOCK_RETRY_S=0 PATH="$tmp:$PATH" "$ROOT/asahi-lock" || rc=$?
if [ "$rc" = 1 ] && [ "$(tail -n 1 "$tmp/qs-calls")" = play ]; then
  pass "asahi-lock out of retries releases the held intro (exit 1)"
else
  fail_at "asahi-lock out of retries: rc=$rc last call [$(tail -n 1 "$tmp/qs-calls" 2>/dev/null)]"
fi
# Quickshell island lock (`locker` quickshell / ASAHI_LOCKER): qs -n -p remix/lock.qml, same unlock line and guard.
rm -f "$tmp/qs-calls" "$tmp/runs"
cat >"$tmp/qs" <<SH
#!/bin/sh
case "\$*" in
  *"-p "*lock.qml*) echo lock >>"$tmp/qs-calls"; [ -e "$tmp/qs-lock-fails" ] && exit 1; echo "  WARN qml: Unlocked, exiting!" >&2 ;;
  *wallpaperIntro*) echo intro >>"$tmp/qs-calls"; [ "\$7" = ready ] && echo true ;;
esac
exit 0
SH
printf '#!/bin/sh\necho hyprlock >>"%s/qs-calls"\n' "$tmp" >"$tmp/hyprlock"
chmod +x "$tmp/qs" "$tmp/hyprlock"
rc=0
ASAHI_LOCKER=quickshell XDG_RUNTIME_DIR="$tmp" XDG_STATE_HOME="$tmp" ASAHI_LOCK_RETRY_S=0 PATH="$tmp:$PATH" "$ROOT/asahi-lock" || rc=$?
if [ "$rc" = 0 ] && [ "$(grep -c '^lock$' "$tmp/qs-calls")" = 1 ] && ! grep -q hyprlock "$tmp/qs-calls" \
  && grep -q 'quickshell exit 0' "$tmp/asahi/hyprlock.log" && grep -q '^unlocked$' "$tmp/asahi-lock.reader"; then
  pass "asahi-lock runs the Quickshell island lock when locker = quickshell (its unlock line counts)"
else
  fail_at "quickshell locker: rc=$rc calls=[$(tr '\n' ' ' <"$tmp/qs-calls" 2>/dev/null)]"
fi
if grep -q '/asahi/locker" 2>/dev/null || echo quickshell)}' "$ROOT/asahi-lock"; then
  pass "the island lock is the default locker (locker file = hyprlock switches back)"
else
  fail_at "asahi-lock default locker is not quickshell"
fi
# Three quickshell runs without the unlock line: hyprlock takes over this lock.
rm -f "$tmp/qs-calls"; : >"$tmp/qs-lock-fails"
rc=0
ASAHI_LOCKER=quickshell XDG_RUNTIME_DIR="$tmp" XDG_STATE_HOME="$tmp" ASAHI_LOCK_RETRY_S=0 PATH="$tmp:$PATH" "$ROOT/asahi-lock" || rc=$?
if [ "$rc" = 0 ] && [ "$(grep -c '^lock$' "$tmp/qs-calls")" = 3 ] && [ "$(grep -c '^hyprlock$' "$tmp/qs-calls")" = 1 ]; then
  pass "a failing Quickshell lock falls back to hyprlock after three runs"
else
  fail_at "quickshell fallback: rc=$rc calls=[$(tr '\n' ' ' <"$tmp/qs-calls" 2>/dev/null)]"
fi
rm -f "$tmp/qs-lock-fails"
# The lock's PAM: a password file (pam_unix only, no pam_fprintd: it would hold a typed password) beside the finger.
pamd="$ROOT/../quickshell/lockpam"
if grep -qx 'auth     required  pam_unix.so' "$pamd/password" && ! grep -q '^[^#]*pam_fprintd' "$pamd/password" \
  && grep -q '^auth  required  pam_fprintd.so max-tries=3' "$pamd/fingerprint" \
  && grep -q 'enabled: lock.demo' "$ROOT/../quickshell/remix/lock.qml"; then
  pass "lock PAM: password = pam_unix alone, finger = pam_fprintd; the state IPC exists only in demo mode"
else
  fail_at "lock PAM files / demo-only IPC"
fi
# Touch ID orb: fingerprint auth on; glyph, ring and caption are one script's three parts with the theme's colors.
orb_args='"$FPRINTPROMPT" "$lock_fg" "$lock_muted" "$lock_accent" "$lock_accent2" "$lock_warn" "$lock_fail" "$lock_on"'
if grep -q '^  fingerprint:enabled = true' "$conf" && grep -q '^  fingerprint:present_message = reading$' "$conf" \
  && grep -q '^  fingerprint:ready_message = ready$' "$conf" \
  && for part in glyph ring caption; do grep -qF "cmd[update:5000] ~/.dotfiles/asahi/bin/asahi-lock-touchid $part $orb_args" "$conf" || exit 1; done; then
  pass "hyprlock.conf: Touch ID auth + orb glyph, ring and caption"
  grep -q '^  animation = fadeOut, 0' "$conf" && pass "hyprlock.conf: no fade-out (dimmed the intro's first frame to grey)" \
    || fail_at "hyprlock.conf fades out again"
else
  fail_at "hyprlock.conf lost fingerprint:enabled or the Touch ID orb"
fi
# A label run is ~7 ms of CPU (hyprlock forks, a shell starts, the text is drawn, every output gets a frame): only
# the clock runs every second; the orb ticks 5 s after hyprlock's last fingerprint event (it re-runs those labels
# itself), and its script counts on that 5 s.
fast=$(grep -o 'cmd\[update:[0-9]*' "$conf" | cut -d: -f2 | awk '$1 < 5000' | tr '\n' ' ')
if [ "$fast" = "1000 " ] && grep -qF "cmd[update:1000] date +\"<span weight='bold'>%H:%M</span><span foreground='##\$lock_hexaccent'>:%S</span>\"" "$conf" \
  && grep -q '^tick=5000000 ' "$ROOT/asahi-lock-touchid"; then
  pass "hyprlock.conf: only the clock runs every second, nothing else under 5 s; the orb script knows its tick"
else
  fail_at "hyprlock.conf label runs under 5 s: [$fast], or the clock / the orb's tick changed"
fi
# The ring is a hairline glyph of Adwaita Sans (a bold one "looked cheap"): the font comes with dnf.sh, the disc has no
# border of its own under it.
if grep -q '^  adwaita-sans-fonts \\$' "$ROOT/../dnf.sh" && ! grep -q '󰝦' "$ROOT/asahi-lock-touchid" \
  && [ "$(grep -c 'border_size = 0' "$conf")" -ge 3 ] && ! grep -q 'border_color = \$lock_ring' "$conf" \
  && [ "$(grep -c 'asahi-lock-touchid ' "$conf")" = 3 ]; then
  pass "orb ring: Adwaita Sans hairline (font installed by dnf.sh), no bold ring, no second border; three labels poll, not four"
else
  fail_at "orb ring: font / bold ring / border"
fi
# No haze behind orb and pill, no glow shadows (2026-11-18: "blurry green fog").
if ! grep -q 'lock-glow\|lock_glow' "$conf" "$theme" && ! grep -q 'shadow_passes = [1-9]' "$conf"; then
  pass "hyprlock.conf: no glow image, no glow shadows"
else
  fail_at "hyprlock.conf glows again"
fi
# Every theme variable the conf uses has a Mocha fallback (the state file may predate it).
missing=$(grep -o '\$lock_[a-z0-9]*' "$conf" | sort -u | while read -r v; do
  grep -q "^\\$v = " "$theme" "$conf" || printf '%s ' "$v"; done)
[ -z "$missing" ] && pass "hyprlock-theme.conf defines every \$lock_ variable the conf uses" \
  || fail_at "no fallback for: $missing"
printf '#!/bin/sh\necho x >>"%s/fp-calls"\nif [ -e "%s/enrolled" ]; then printf "Fingerprints for user u on sensor (press):\\n - #0: right-index-finger\\n"; elif [ -e "%s/noreader" ]; then echo "No devices available"; fi\nexit 0\n' \
  "$tmp" "$tmp" "$tmp" >"$tmp/fprintd-list"
chmod +x "$tmp/fprintd-list"
colors=("rgb(cdd6f4)" "rgb(a6adc8)" "rgb(94e2d5)" "rgba(89dcebee)" "rgb(f9e2af)" "rgb(f38ba8)" "rgb(11111b)")
touchid() { XDG_RUNTIME_DIR="$tmp" PATH="$tmp:$PATH" "$ROOT/asahi-lock-touchid" "$1" "${2:-}" "${colors[@]}"; }
orb() { printf '%s|%s|%s' "$(touchid glyph "${1:-}")" "$(touchid ring "${1:-}")" "$(touchid caption "${1:-}")"; }
ring() { printf "<span font_family='Adwaita Sans' weight='100' line_height='2' foreground='%s' alpha='%s%%'>◯</span>" "$1" "$2"; }
disc() { printf "<span font_family='Adwaita Sans' weight='100' line_height='2' foreground='%s' alpha='100%%'>⬤</span>" "$1"; }   # the ring's label, solid
rm -f "$tmp/asahi-lock-touchid"*
none=$(orb)
: >"$tmp/noreader"; rm -f "$tmp/asahi-lock-touchid"
noreader=$(orb)
rm -f "$tmp/noreader"; : >"$tmp/enrolled"; rm -f "$tmp/asahi-lock-touchid"
ready=$(orb ready)
calls=$(wc -l <"$tmp/fp-calls")
sleep 0.35
steady=$(orb ready)
if [[ $none == *"󰌾</span>|$(ring '#cdd6f4' 90)|"*"Type your password"* ]] \
  && [[ $noreader == *"󰺱</span>|$(ring '#a6adc8' 70)|"*"Touch ID unavailable"* ]] \
  && [ "$calls" = 3 ] && [[ $ready == "<span foreground='#94e2d5' alpha='100%'>󰈷</span>|$(ring '#94e2d5' 100)|"*"Touch ID ready"* ]] \
  && [ "$ready" = "$steady" ]; then
  pass "orb: lock without a finger, crossed without a reader, ready = accent fingerprint + hairline ring, clear glass, nothing pulsing; fprintd cached"
  [ "$(XDG_RUNTIME_DIR="$tmp" PATH="$tmp:$PATH" "$ROOT/asahi-lock-touchid" glyph ready)" = "<span foreground='#94e2d5' alpha='100%'>󰈷</span>" ] \
    || fail_at "orb without colours must fall back to Mocha"
else
  fail_at "orb: none=[$none] noreader=[$noreader] ready=[$ready] steady=[$steady] calls=$calls"
fi
# The labels (and every output's copies) tick together: when the cache runs out, one of them asks fprintd, not all.
calls=$(wc -l <"$tmp/fp-calls")
printf '#!/bin/sh\necho x >>"%s/fp-calls"\nsleep 0.4\nprintf "Fingerprints for user u on sensor (press):\\n - #0: right-index-finger\\n"\n' "$tmp" >"$tmp/fprintd-list"
printf '%s 1\n' "$(($(date +%s) - 120))" >"$tmp/asahi-lock-touchid"
touchid ring >/dev/null &
sleep 0.1
late=$(touchid glyph)
wait
if [ "$(($(wc -l <"$tmp/fp-calls") - calls))" = 1 ] && [[ $late == *"󰈷"* ]]; then
  pass "orb: one label refreshes the enrolment cache, the others keep the last answer meanwhile"
else
  fail_at "orb cache refresh: $(($(wc -l <"$tmp/fp-calls") - calls)) fprintd-list calls, late=[$late]"
fi
printf '#!/bin/sh\necho x >>"%s/fp-calls"\n[ -e "%s/enrolled" ] && printf "Fingerprints for user u on sensor (press):\\n - #0: right-index-finger\\n"\nexit 0\n' "$tmp" "$tmp" >"$tmp/fprintd-list"
# asahi-lock: hyprlock's fingerprint log lines become the orb's note and phase.
printf '#!/bin/sh\nexit 1\n' >"$tmp/qs"
printf '#!/bin/sh\necho "$*" >>"%s/systemctl-calls"\n' "$tmp" >"$tmp/systemctl"
chmod +x "$tmp/systemctl"
note_after() {   # the note one lock leaves for hyprlock printing these lines
  { printf '#!/bin/sh\n'; printf 'echo "[DEBUG]: fprint: %s"\n' "$@"; printf 'sleep 0.3\n'; } >"$tmp/hyprlock"
  ASAHI_LOCKER=hyprlock XDG_RUNTIME_DIR="$tmp" XDG_STATE_HOME="$tmp" PATH="$tmp:$PATH" "$ROOT/asahi-lock"
  cut -d' ' -f2- "$tmp/asahi-lock-touchid.note" 2>/dev/null
}
nm="handling status verify-no-match"
n1=$(note_after "claimed device" "started verifying" "$nm" "started verifying")
nomatch=$(orb)
again=$(orb reading)
n3=$(note_after "$nm" "started verifying" "$nm" "started verifying" "$nm" "started verifying")
n_retry=$(note_after "started verifying" "handling status verify-retry-scan")
n4=$(note_after "$nm" "started verifying" "$nm" "started verifying" "$nm" "started verifying" "$nm")
n_lock=$(note_after "started verifying" "handling status verify-lockout" "unknown status: verify-lockout")
n_pw=$(note_after "started verifying" "handling status verify-password-required-after-boot")
n_gone=$(note_after "started verifying" "handling status verify-disconnected")
n_back=$(note_after "handling status verify-disconnected" "started verifying"; echo .)
calls_before=$(cat "$tmp/systemctl-calls" 2>/dev/null || true)
n_claim=$(note_after "could not claim device, [net.reactivated.Fprint.Error.Internal] Open failed with error: The device has already been opened!")
sticky=$(orb reading)
if [ "$n1" = "nomatch No match" ] \
  && [[ $nomatch == "<span foreground='#11111b'>󰈷</span>|$(disc '#f38ba8')|"*"No match"*"touch again"* ]] \
  && [[ $again == "<span foreground='#11111b'>󰈷</span>|$(disc '#89dceb')|"*"Reading"* ]] \
  && [ "$n3" = "nomatch No match · last try" ] && [ "$n_retry" = "retry Not read" ] \
  && [ "$n4" = "exhausted Too many failed attempts" ] && [ "$n_lock" = "lockout Touch ID locked" ] \
  && [ "$n_pw" = "password Password needed to re-enable Touch ID" ] && [ "$n_gone" = "unavailable Touch ID disconnected" ] \
  && [ "$n_back" = . ] && [ -z "$calls_before" ] && [ "$n_claim" = "unavailable Touch ID unavailable" ] \
  && [[ $sticky == "<span foreground='#11111b'>󰺱</span>|$(disc '#f9e2af')|"*"Touch ID unavailable"*"type your password"* ]] \
  && [ "$(cat "$tmp/systemctl-calls")" = "--no-ask-password --no-block restart fprintd.service" ]; then
  pass "orb notes: no match (last try), not read, too many, locked, password clock, disconnected, unavailable (fprintd restarted)"
else
  fail_at "orb notes: [$n1] [$nomatch] [$again] [$n3] [$n_retry] [$n4] [$n_lock] [$n_pw] [$n_gone] [$n_back] [$n_claim] [$sticky] \
    calls [$(cat "$tmp/systemctl-calls" 2>/dev/null)]"
fi
# No prompt = hyprlock has not started fprintd's verify: dim, and "not responding" 5 s into the lock (asahi-lock's
# stamp; the labels' first tick). A finger read 4 s = stalled.
now=$(date +%s)
rm -f "$tmp/asahi-lock-touchid.note" "$tmp/asahi-lock-touchid.reading"
printf '%s\n' "$now" >"$tmp/asahi-lock-touchid.start"
starting=$(orb "")
printf '%s\n' "$((now - 3))" >"$tmp/asahi-lock-touchid.start"
early=$(orb "")
printf '%s\n' "$((now - 5))" >"$tmp/asahi-lock-touchid.start"
stuck=$(orb "")
live=$(orb ready)
retrying=$(orb "Could not match fingerprint. Try again.")
five=$((($(date +%s%N) / 1000) - 5000000))
printf 'r %s %s\n' "$five" "$five" >"$tmp/asahi-lock-touchid.reading"
stalled=$(orb reading)
lifted=$(touchid glyph ready; cat "$tmp/asahi-lock-touchid.reading")
printf '%s old\n' "$((now - 5))" >"$tmp/asahi-lock-touchid.note"
expired=$(orb ready)
rm -f "$tmp/asahi-lock-touchid.start"
bare=$(orb "")
if [[ $starting == *"alpha='45%'>󰈷"*"Starting Touch ID"* ]] && [[ $early == *"Starting Touch ID"* ]] \
  && [[ $stuck == *"󰺱"*"Touch ID not responding"*"type your password"* ]] \
  && [[ $live == *"Touch ID ready"* ]] && [[ $retrying == *"Touch ID ready"* ]] \
  && [[ $stalled == *"#f9e2af"*"Still reading"*"lift and touch again"* ]] \
  && [[ $lifted == *"󰈷</span>" ]] && [[ $expired == *"Touch ID ready"* ]] && [[ $bare == *"Starting Touch ID"* ]]; then
  pass "orb phase: starting without a prompt, not responding after 5 s, ready once hyprlock has a prompt; still reading after 4 s; expired notes go"
else
  fail_at "orb phase: [$starting] [$early] [$stuck] [$live] [$retrying] [$stalled] [$lifted] [$expired] [$bare]"
fi
# A wrong finger left lying: fprintd reports it again the moment the sensor re-arms after the miss, and hyprlock
# says `reading` again. That is no new touch: the miss stays, no "Reading" flickers back in (2026-11-19). The labels'
# tick (5 s after their last run) changes nothing either; a finger reported at any other time is a new touch.
us() { echo $(($(date +%s%N) / 1000)); }
caption() { touchid caption "$1" | sed 's/<[^>]*>//g'; }
stamp="$tmp/asahi-lock-touchid.reading"
rm -f "$stamp" "$tmp/asahi-lock-touchid.note"
h_down=$(caption reading)
sleep 0.05   # the note is newer than the touch
printf '%s nomatch No match\n' "$(($(date +%s) + 2))" >"$tmp/asahi-lock-touchid.note"
h_miss=$(orb reading)                                        # hyprlock's fail event: the prompt is still `reading`
h_armed=$(caption "Could not match fingerprint. Try again.")
h_echo=$(orb reading)                                        # the lying finger, reported again
read -r _ failed _ <"$stamp"
# Should the sensor read the lying finger once more: its next miss shows at once, no "Reading" before it.
printf 's %s %s\n' "$((failed - 3000000))" "$(($(us) - 2600000))" >"$stamp"
sleep 0.05
printf '%s nomatch No match · last try\n' "$(($(date +%s) + 2))" >"$tmp/asahi-lock-touchid.note"
h_again=$(caption reading)
rm -f "$tmp/asahi-lock-touchid.note"                         # the note ran out
printf 's %s %s\n' "$((failed - 6000000))" "$(($(us) - 5000000))" >"$stamp"
h_tick=$(orb reading)                                        # the labels' tick, 5 s after their last run
h_state=$(cut -d' ' -f1 "$stamp")
printf 's %s %s\n' "$((failed - 6000000))" "$(($(us) - 2300000))" >"$stamp"
h_new=$(orb reading)                                         # hyprlock ran the labels at another time: a new touch
# A short touch, lifted: the next touch 2 s on reads again, over the old note. One within 1.5 s of the miss does not.
printf '%s nomatch No match\n' "$(($(date +%s) + 2))" >"$tmp/asahi-lock-touchid.note"
printf 's %s %s\n' "$(($(us) - 2000000))" "$(($(us) - 1750000))" >"$stamp"
h_retry=$(caption reading)
printf 's %s %s\n' "$(($(us) - 900000))" "$(($(us) - 650000))" >"$stamp"
h_quick=$(caption reading)
rm -f "$tmp/asahi-lock-touchid.note" "$stamp"
if [ "$h_down" = "Reading…" ] && [[ $h_miss == "<span foreground='#11111b'>󰈷</span>|$(disc '#f38ba8')|"*"No match"*"touch again"* ]] \
  && [ "$h_armed" = "No match  ·  touch again" ] && [ "$h_echo" = "$h_miss" ] && [ "$h_again" = "No match · last try  ·  touch again" ] \
  && [[ $h_tick == *"$(ring '#94e2d5' 100)"*"Touch ID ready"* ]] && [ "$h_state" = s ] \
  && [[ $h_new == *"$(disc '#89dceb')"*"Reading…"* ]] && [ "$h_retry" = "Reading…" ] && [ "$h_quick" = "No match  ·  touch again" ]; then
  pass "orb: a wrong finger left lying shows its miss, not Reading again; the tick keeps that; a new touch reads"
else
  fail_at "orb, finger left lying: down=[$h_down] miss=[$h_miss] armed=[$h_armed] echo=[$h_echo] again=[$h_again] tick=[$h_tick] ($h_state) new=[$h_new] retry=[$h_retry] quick=[$h_quick]"
fi
grep -q 'printf .%s.n. "\$EPOCHSECONDS" >"\$began"' "$lock" && ! grep -q 'asahi-lock-touchid.live' "$lock" "$ROOT/asahi-lock-touchid" \
  && pass "asahi-lock stamps when each hyprlock run began (the orb's \"not responding\" clock)" \
  || fail_at "asahi-lock does not stamp the lock's start for the orb"
rm -rf "$tmp"

if [ "$fail" -ne 0 ]; then
  echo "$fail failed"
  exit 1
fi
echo "all passed"
