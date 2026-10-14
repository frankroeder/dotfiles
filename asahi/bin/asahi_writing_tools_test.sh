#!/usr/bin/env bash
# asahi-writing-tools capture against fake hyprctl / wl-paste / wl-copy: the real clipboard, history
# and windows are never touched. No API call (run is not tested here).
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export FAKE="$tmp" XDG_RUNTIME_DIR="$tmp/run" PATH="$tmp/bin:$PATH"
mkdir -p "$tmp/bin" "$tmp/run"
# The clipboard before capture: a browser copy (text/html offered first) that must come back.
printf 'text/html\ntext/plain;charset=utf-8\n' >"$tmp/types"
printf 'OLD-CLIPBOARD' >"$tmp/clip"

cat >"$tmp/bin/wl-paste" <<'EOF'
#!/bin/sh
case "$*" in
  *--list-types*) cat "$FAKE/types" ;;
  *) cat "$FAKE/clip" ;;
esac
EOF
cat >"$tmp/bin/wl-copy" <<'EOF'
#!/bin/sh
echo "wl-copy $*" >>"$FAKE/calls"
case "$*" in *--clear*) : >"$FAKE/clip"; exit 0 ;; esac
cat >"$FAKE/clip"
EOF
# dispatch = the Ctrl+C sent to the window: the app copies its selection (with a trailing newline).
cat >"$tmp/bin/hyprctl" <<'EOF'
#!/bin/sh
case "$1" in
  activewindow) if [ -n "${FAKE_NOWIN:-}" ]; then echo '{}'; else echo '{"address":"0xabc","class":"org.mozilla.firefox"}'; fi ;;
  cursorpos) echo '{"x":10,"y":20}' ;;
  dispatch)
    flag=no; [ -e "$XDG_RUNTIME_DIR/asahi-cliphist/skip" ] && flag=yes
    echo "dispatch skip=$flag $*" >>"$FAKE/calls"
    printf 'line one\n' >"$FAKE/clip"
    ;;
esac
EOF
chmod +x "$tmp/bin/"*

out="$("$ROOT/asahi-writing-tools" capture)"
[ "$(jq -c .text <<<"$out")" = '"line one\n"' ] \
  && pass "capture keeps the selection's trailing newline" || fail_at "capture text: $out"
grep -q 'dispatch skip=yes' "$tmp/calls" && pass "cliphist skip flag is set before the Ctrl+C" \
  || fail_at "skip flag missing at Ctrl+C: $(cat "$tmp/calls")"
tail -n 1 "$tmp/calls" | grep -qx 'wl-copy --sensitive --type text/plain;charset=utf-8' \
  && [ "$(cat "$tmp/clip")" = OLD-CLIPBOARD ] && pass "old clipboard restored as UTF-8 text, --sensitive" \
  || fail_at "restore: $(tail -n 1 "$tmp/calls") clip=$(cat "$tmp/clip")"

out="$(FAKE_NOWIN=1 "$ROOT/asahi-writing-tools" capture || true)"
jq -e '.text == "" and .address == ""' <<<"$out" >/dev/null 2>&1 \
  && pass "no focused window: capture still prints JSON" || fail_at "no window: '$out'"

if [ "$fail" -ne 0 ]; then
  echo "asahi_writing_tools_test.sh: FAILED"
  exit 1
fi
echo "asahi_writing_tools_test.sh: all ok"
