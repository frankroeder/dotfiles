#!/usr/bin/env bash
# Tests for asahi-recent-files: a fixture xbel with an old, a new, a repeated, an encoded and a deleted entry.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/Docs"
: >"$tmp/Docs/old.txt"; : >"$tmp/Docs/new.pdf"; : >"$tmp/Docs/Bild ä.png"; : >"$tmp/Docs/Tom & Jerry's.txt"
cat >"$tmp/recent.xbel" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<xbel version="1.0">
  <bookmark href="file://$tmp/Docs/old.txt" added="2026-01-01T10:00:00Z" modified="2026-01-01T10:00:00Z" visited="x">
  </bookmark>
  <bookmark href="file://$tmp/Docs/new.pdf" added="2026-11-20T09:00:00Z" modified="2026-11-20T09:00:00Z" visited="x">
  </bookmark>
  <bookmark href="file://$tmp/Docs/Bild%20%C3%A4.png" added="2026-11-10T09:00:00Z" modified="2026-11-10T09:00:00Z" visited="x">
  </bookmark>
  <bookmark href="file://$tmp/Docs/Tom%20&amp;%20Jerry&#39;s.txt" added="2026-11-05T09:00:00Z" modified="2026-11-05T09:00:00Z" visited="x">
  </bookmark>
  <bookmark href="file://$tmp/Docs/gone.txt" added="2026-11-21T09:00:00Z" modified="2026-11-21T09:00:00Z" visited="x">
  </bookmark>
  <bookmark href="https://example.org/x" added="2026-11-21T09:00:00Z" modified="2026-11-21T09:00:00Z" visited="x">
  </bookmark>
</xbel>
EOF
out=$(ASAHI_RECENT_XBEL="$tmp/recent.xbel" "$ROOT/asahi-recent-files")
want=$(printf '%s\n' "$tmp/Docs/new.pdf" "$tmp/Docs/Bild ä.png" "$tmp/Docs/Tom & Jerry's.txt" "$tmp/Docs/old.txt")
[ "$out" = "$want" ] && pass "newest first, %-decoded, XML entities decoded, gone files and non-file URIs skipped" || fail_at "got: $out"
[ "$(ASAHI_RECENT_XBEL="$tmp/recent.xbel" "$ROOT/asahi-recent-files" 1)" = "$tmp/Docs/new.pdf" ] && pass "max limits the list" || fail_at "max"
[ -z "$(ASAHI_RECENT_XBEL="$tmp/none.xbel" "$ROOT/asahi-recent-files")" ] && pass "no xbel: nothing, exit 0" || fail_at "missing xbel"

[ "$fail" = 0 ] && echo "all passed"
exit "$fail"
