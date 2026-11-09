#!/usr/bin/env bash
# Tests for asahi-captive-portal. Fake xdg-open + nmcli (portal, then full); no browser, no NM.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export XDG_RUNTIME_DIR="$tmp/rt"
mkdir -p "$XDG_RUNTIME_DIR"
echo 0 >"$tmp/calls"

cat >"$tmp/xdg-open" <<'EOF'
#!/usr/bin/env bash
echo "$1" >>"$OPENED"
EOF
cat >"$tmp/nmcli" <<'EOF'
#!/usr/bin/env bash
n=$(cat "$COUNT")
echo $((n + 1)) >"$COUNT"
[ "$n" -ge 2 ] && echo full || echo portal
EOF
chmod +x "$tmp/xdg-open" "$tmp/nmcli"
export PATH="$tmp:$PATH" OPENED="$tmp/opened" COUNT="$tmp/calls"

"$ROOT/asahi-captive-portal" http://example.invalid/check.txt
[ "$(cat "$OPENED")" = "http://example.invalid/check.txt" ] && pass "opens the given URL" || fail_at "opened: $(cat "$OPENED" 2>/dev/null)"
[ "$(cat "$COUNT")" -ge 3 ] && pass "waits through portal until full" || fail_at "nmcli calls: $(cat "$COUNT")"

if "$ROOT/asahi-captive-portal" 2>/dev/null; then fail_at "missing URL exits 0"; else pass "missing URL errors"; fi

# Contended lock: a second click only resurfaces the page (the opener backgrounds xdg-open: poll).
: >"$OPENED"
flock -n "$XDG_RUNTIME_DIR/asahi-captive-portal.lock" \
  "$ROOT/asahi-captive-portal" http://example.invalid/check.txt
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [ -s "$OPENED" ] && break
  sleep 0.2
done
[ "$(cat "$OPENED")" = "http://example.invalid/check.txt" ] && pass "contended lock resurfaces page" \
  || fail_at "resurface opened: $(cat "$OPENED" 2>/dev/null)"

# Dead launcher: xdg-open failing exits 1 instead of waiting forever.
cat >"$tmp/xdg-open" <<'EOF'
#!/usr/bin/env bash
exit 3
EOF
echo 0 >"$COUNT"
if "$ROOT/asahi-captive-portal" http://example.invalid/check.txt 2>/dev/null; then
  fail_at "failed xdg-open exits 0"
else
  pass "failed xdg-open exits 1"
fi

if [ "$fail" -ne 0 ]; then
  echo "$fail failed"
  exit 1
fi
echo "all passed"
