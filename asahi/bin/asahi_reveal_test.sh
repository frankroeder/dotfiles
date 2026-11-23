#!/usr/bin/env bash
# Tests for asahi-reveal: a copy beside a fake asahi-launch (the real one starts a transient unit in the live session),
# fake gdbus (records the call, or fails).

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
printf '#!/bin/sh\necho "launch $*" >>"$CALLS"\n' >"$tmp/bin/asahi-launch"
cp "$ROOT/asahi-reveal" "$tmp/bin/"
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"
f="$tmp/dir with space/Bild ä.png"
: >"$f"

: >"$CALLS"
"$tmp/bin/asahi-reveal" "$f"
if grep -q "ShowItems \['file://$tmp/dir%20with%20space/Bild%20%C3%A4.png'\]" "$CALLS"; then
  pass "ShowItems with a percent-encoded file:// URI (spaces, umlauts)"
else
  fail_at "ShowItems call: $(cat "$CALLS")"
fi

: >"$CALLS"
GDBUS_FAIL=1 "$tmp/bin/asahi-reveal" "$f"
grep -q "launch xdg-open $tmp/dir with space$" "$CALLS" && pass "no FileManager1: opens the folder" || fail_at "fallback: $(cat "$CALLS")"

if "$tmp/bin/asahi-reveal" "$tmp/missing" 2>/dev/null; then fail_at "a missing path was accepted"; else pass "missing path refused"; fi

[ "$fail" = 0 ] && echo "all passed"
exit "$fail"
