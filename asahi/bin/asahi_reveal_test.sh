#!/usr/bin/env bash
# Tests for asahi-reveal. Fake gdbus (records the call, or fails) and asahi-launch's xdg-open fallback.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/dir with space"
export CALLS="$tmp/calls"
printf '#!/bin/sh\necho "gdbus $*" >>"$CALLS"\n[ -z "$GDBUS_FAIL" ]\n' >"$tmp/bin/gdbus"
printf '#!/bin/sh\necho "xdg-open $*" >>"$CALLS"\n' >"$tmp/bin/xdg-open"
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"
f="$tmp/dir with space/Bild ä.png"
: >"$f"

: >"$CALLS"
"$ROOT/asahi-reveal" "$f"
if grep -q "ShowItems \['file://$tmp/dir%20with%20space/Bild%20%C3%A4.png'\]" "$CALLS"; then
  pass "ShowItems with a percent-encoded file:// URI (spaces, umlauts)"
else
  fail_at "ShowItems call: $(cat "$CALLS")"
fi

: >"$CALLS"
GDBUS_FAIL=1 "$ROOT/asahi-reveal" "$f"
grep -q "xdg-open $tmp/dir with space$" "$CALLS" && pass "no FileManager1: opens the folder" || fail_at "fallback: $(cat "$CALLS")"

if "$ROOT/asahi-reveal" "$tmp/missing" 2>/dev/null; then fail_at "a missing path was accepted"; else pass "missing path refused"; fi

[ "$fail" = 0 ] && echo "all passed"
exit "$fail"
