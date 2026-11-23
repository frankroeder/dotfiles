#!/usr/bin/env bash
# Tests for asahi-files-here: a copy beside a fake asahi-launch, fake hyprctl answering activewindow.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home/my dir"
cp "$ROOT/asahi-files-here" "$tmp/bin/"
printf '#!/bin/sh\necho "$*" >"%s/launched"\n' "$tmp" >"$tmp/bin/asahi-launch"
printf '#!/bin/sh\nprintf "%%s\\n" "$ACTIVE"\n' >"$tmp/bin/hyprctl"
chmod +x "$tmp/bin/"*
run() { ACTIVE="$1" HOME="$tmp/home" PATH="$tmp/bin:$PATH" "$tmp/bin/asahi-files-here"; cat "$tmp/launched"; }

[ "$(run '{"class":"com.mitchellh.ghostty","title":"~/my dir"}')" = "thunar $tmp/home/my dir" ] \
  && pass "Ghostty at a prompt: its folder (~ expanded, spaces kept)" || fail_at "prompt title"
[ "$(run '{"class":"com.mitchellh.ghostty","title":"nvim notes.md"}')" = "thunar $tmp/home" ] \
  && pass "Ghostty running a command: home" || fail_at "command title"
[ "$(run '{"class":"org.mozilla.firefox","title":"/etc"}')" = "thunar $tmp/home" ] \
  && pass "not a terminal: home" || fail_at "browser"
[ "$(run '{}')" = "thunar $tmp/home" ] && pass "no window: home" || fail_at "no window"

[ "$fail" = 0 ] && echo "all passed"
exit "$fail"
