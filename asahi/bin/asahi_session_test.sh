#!/usr/bin/env bash
# Tests for asahi-session. Fake hyprctl (windows close on request, or one stays), systemctl, notify-send, sleep.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export CALLS="$tmp/calls" OPEN="$tmp/open" STUCK="$tmp/stuck"
cat >"$tmp/hyprctl" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  clients)
    printf '['; sep=""
    while read -r a c; do [ -n "$a" ] && printf '%s{"address":"%s","class":"%s","mapped":true}' "$sep" "$a" "$c" && sep=","; done <"$OPEN"
    printf ']\n' ;;
  dispatch)
    echo "dispatch $2" >>"$CALLS"
    a=$(sed -n 's/.*address:\(0x[0-9a-f]*\).*/\1/p' <<<"$2")
    if [ -n "$a" ] && ! grep -q "^$a" "$STUCK" 2>/dev/null; then grep -v "^$a " "$OPEN" >"$OPEN.n" || true; mv "$OPEN.n" "$OPEN"; fi ;;
esac
EOF
printf '#!/bin/sh\necho "systemctl $*" >>"$CALLS"\n' >"$tmp/systemctl"
printf '#!/bin/sh\necho "notify $*" >>"$CALLS"\n' >"$tmp/notify-send"
printf '#!/bin/sh\nexit 0\n' >"$tmp/sleep"
chmod +x "$tmp/hyprctl" "$tmp/systemctl" "$tmp/notify-send" "$tmp/sleep"
export PATH="$tmp:$PATH"

printf '0xa1 org.mozilla.firefox\n0xb2 com.mitchellh.ghostty\n' >"$OPEN"; : >"$CALLS"
"$ROOT/asahi-session" reboot
if [ "$(grep -c 'hl.dsp.window.close' "$CALLS")" = 2 ] && grep -q '^systemctl reboot$' "$CALLS"; then
  pass "reboot: closes every window, then reboots"
else
  fail_at "reboot: $(cat "$CALLS")"
fi

printf '0xa1 org.mozilla.firefox\n0xc3 org.libreoffice.LibreOffice.writer\n' >"$OPEN"; echo 0xc3 >"$STUCK"; : >"$CALLS"
if "$ROOT/asahi-session" poweroff; then fail_at "a window left open must cancel (exit 1)"; fi
if ! grep -q 'systemctl' "$CALLS" && grep -q 'notify .*Poweroff cancelled.*Still open: org.libreoffice.LibreOffice.writer' "$CALLS"; then
  pass "a window that stays (unsaved changes) cancels, naming it"
else
  fail_at "cancel: $(cat "$CALLS")"
fi
rm -f "$STUCK"

: >"$OPEN"; : >"$CALLS"
"$ROOT/asahi-session" logout
grep -q "dispatch hl.dsp.exit()" "$CALLS" && pass "logout without windows: exits Hyprland" || fail_at "logout: $(cat "$CALLS")"

if "$ROOT/asahi-session" halt 2>/dev/null; then fail_at "unknown action accepted"; else pass "unknown action refused"; fi
# Restart into macOS: the one-shot macOS boot is set only after the windows are gone (a cancel must leave it unset).
printf '#!/bin/sh\necho "pkexec $*" >>"$CALLS"\n' >"$tmp/pkexec"; chmod +x "$tmp/pkexec"
printf '0xc3 org.libreoffice.LibreOffice.writer\n' >"$OPEN"; echo 0xc3 >"$STUCK"; : >"$CALLS"
if "$ROOT/asahi-session" reboot-macos; then fail_at "reboot-macos with a window left must cancel"; fi
! grep -q 'pkexec\|systemctl' "$CALLS" && pass "reboot-macos cancelled: no macOS boot armed, no reboot" || fail_at "reboot-macos cancel: $(cat "$CALLS")"
rm -f "$STUCK"; : >"$OPEN"; : >"$CALLS"
"$ROOT/asahi-session" reboot-macos
[ "$(tr '\n' '|' <"$CALLS")" = "pkexec /usr/bin/asahi-bless --set-boot-macos --next -y|systemctl reboot|" ] \
  && pass "reboot-macos: windows gone, then the one-shot macOS boot, then reboot" || fail_at "reboot-macos: $(cat "$CALLS")"
# The polkit prompt dismissed: the windows are closed already, so a card says nothing was armed (no reboot).
printf '#!/bin/sh\necho "pkexec $*" >>"$CALLS"\nexit 126\n' >"$tmp/pkexec"; : >"$CALLS"
if "$ROOT/asahi-session" reboot-macos; then fail_at "a dismissed polkit prompt must fail"; fi
grep -q 'notify .*Restart into macOS failed macOS was not set' "$CALLS" && ! grep -q 'systemctl' "$CALLS" \
  && pass "reboot-macos, prompt dismissed: a card, no reboot" || fail_at "dismissed prompt: $(cat "$CALLS")"
# A refused reboot (a block inhibitor) says so too.
printf '#!/bin/sh\necho "systemctl $*" >>"$CALLS"\nexit 1\n' >"$tmp/systemctl"; : >"$CALLS"
if "$ROOT/asahi-session" reboot; then fail_at "a refused reboot must fail"; fi
grep -q 'notify .*Reboot failed' "$CALLS" && pass "refused reboot: a card" || fail_at "refused reboot: $(cat "$CALLS")"

[ "$fail" = 0 ] && echo "all passed"
exit "$fail"
