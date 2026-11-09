#!/usr/bin/env bash
# Tests for lib/common.sh runtime_dir + is_exe. No session bus, no NM.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$ROOT/lib/common.sh"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

export XDG_RUNTIME_DIR="$tmp/run"
[ "$(runtime_dir)" = "$tmp/run" ] && pass "runtime_dir prefers XDG_RUNTIME_DIR" || fail_at "runtime_dir: $(runtime_dir)"
unset XDG_RUNTIME_DIR
export XDG_STATE_HOME="$tmp/state"
[ "$(runtime_dir)" = "$tmp/state/asahi" ] && pass "runtime_dir falls back to state, never /tmp" \
  || fail_at "fallback: $(runtime_dir)"
[ -d "$tmp/state/asahi" ] && pass "fallback dir created" || fail_at "fallback dir missing"

is_exe $$ bash && pass "is_exe matches self" || fail_at "is_exe self"
is_exe $$ nope-not-a-binary 2>/dev/null && fail_at "is_exe wrong name" || pass "is_exe rejects wrong name"
is_exe 999999999 bash 2>/dev/null && fail_at "is_exe dead pid" || pass "is_exe rejects dead pid"
is_exe "" 2>/dev/null && fail_at "is_exe one-arg" || pass "is_exe one-arg safe under set -u"

if [ "$fail" -ne 0 ]; then
  echo "$fail failed"
  exit 1
fi
echo "all passed"
