#!/usr/bin/env bash
# asahi-apple-music against fake pgrep / hyprctl / uwsm-app: launch flags and profile mode, focus
# instead of a second window, relaunch when the profile runs without a window, anchored profile match.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
printf '#!/bin/sh\nexit 0\n' >"$tmp/bin/notify-send"
cat >"$tmp/bin/uwsm-app" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$FAKE_DIR/launch"
EOF
cat >"$tmp/bin/pgrep" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${!#}" >"$FAKE_DIR/pgrep-pattern"
[ -n "${FAKE_PID:-}" ] && echo "$FAKE_PID"
EOF
cat >"$tmp/bin/hyprctl" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  clients) printf '[{"pid": 1, "address": "0xother"}, {"pid": %s, "address": "0xam"}]\n' "${FAKE_WIN_PID:-0}" ;;
  dispatch) echo "$2" >>"$FAKE_DIR/dispatch" ;;
esac
EOF
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH" FAKE_DIR="$tmp" ASAHI_APPLE_MUSIC_DIR="$tmp/data/asahi-apple-music" XDG_CONFIG_HOME="$tmp/config"
mkdir -p "$XDG_CONFIG_HOME/chromium/WidevineCdm"
echo '{"Path":"/x/WidevineCdm/4.10.3057.0"}' >"$XDG_CONFIG_HOME/chromium/WidevineCdm/latest-component-updated-widevine-cdm"
run() { rm -f "$tmp/launch" "$tmp/dispatch"; "$ROOT/asahi-apple-music"; }

run
grep -qx -- 'chromium-browser' "$tmp/launch" &&
  grep -qx -- "--user-data-dir=$ASAHI_APPLE_MUSIC_DIR" "$tmp/launch" &&
  grep -qx -- '--app=https://music.apple.com/' "$tmp/launch" &&
  grep -qx -- '--password-store=gnome-libsecret' "$tmp/launch" &&
  pass "launches the dedicated profile" || fail_at "launch flags: $(tr '\n' ' ' <"$tmp/launch" 2>/dev/null)"
ext=$(sed -n 's/^--load-extension=//p' "$tmp/launch")
[ -f "$ext/manifest.json" ] && jq -e '.content_scripts[0].world == "MAIN"' "$ext/manifest.json" >/dev/null &&
  pass "loads the bundled extension" || fail_at "extension path '$ext'"
[ "$(stat -c %a "$ASAHI_APPLE_MUSIC_DIR")" = 700 ] && pass "profile is owner-only" || fail_at "profile mode"
[ ! -e "$tmp/dispatch" ] && pass "no focus without a running app" || fail_at "focused nothing"
cmp -s "$XDG_CONFIG_HOME/chromium/WidevineCdm/latest-component-updated-widevine-cdm" \
  "$ASAHI_APPLE_MUSIC_DIR/WidevineCdm/latest-component-updated-widevine-cdm" &&
  pass "Widevine hint from the main profile" || fail_at "Widevine hint"

FAKE_PID=4242 FAKE_WIN_PID=4242 run
[ ! -e "$tmp/launch" ] && grep -q 'address:0xam' "$tmp/dispatch" &&
  pass "running app is focused, not opened twice" || fail_at "focus"

FAKE_PID=4242 FAKE_WIN_PID=7 run
[ -e "$tmp/launch" ] && [ ! -e "$tmp/dispatch" ] &&
  pass "profile without a window opens one" || fail_at "relaunch without window"

pat=$(cat "$tmp/pgrep-pattern")
grep -Eq -- "$pat" <<<"chromium-browser --user-data-dir=$ASAHI_APPLE_MUSIC_DIR --app=https://music.apple.com/" &&
  grep -Eq -- "$pat" <<<"chromium-browser --user-data-dir=$ASAHI_APPLE_MUSIC_DIR" &&
  ! grep -Eq -- "$pat" <<<"chromium-browser --user-data-dir=$ASAHI_APPLE_MUSIC_DIR-old --app=x" &&
  ! grep -Eq -- "$pat" <<<"chromium-browser --user-data-dir=${ASAHI_APPLE_MUSIC_DIR/data/dataX}" &&
  pass "profile match is anchored" || fail_at "pgrep pattern '$pat'"

exit "$fail"
