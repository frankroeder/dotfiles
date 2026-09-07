#!/usr/bin/env bash
# Smoke tests for asahi-cliphist JSON contract. Does not touch wl-copy.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIP="$ROOT/asahi-cliphist"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

chmod +x "$CLIP"

if "$CLIP" >/dev/null 2>&1; then
  fail_at "no-args should fail"
else
  pass "no-args exits non-zero"
fi

out="$("$CLIP" list)"
if echo "$out" | jq -e 'has("entries") and has("error")' >/dev/null; then
  pass "list JSON has entries/error"
else
  fail_at "list JSON shape: $out"
fi

if command -v cliphist >/dev/null 2>&1; then
  if echo "$out" | jq -e '.error == "" or .error == "cliphist-missing"' >/dev/null; then
    pass "list error field is known"
  else
    fail_at "unexpected list error: $out"
  fi
else
  if echo "$out" | jq -e '.error == "cliphist-missing" and (.entries|length)==0' >/dev/null; then
    pass "missing cliphist returns empty list"
  else
    fail_at "missing cliphist payload: $out"
  fi
fi

if "$CLIP" watch; then
  pass "watch is idempotent"
else
  fail_at "watch failed"
fi

if command -v cliphist >/dev/null 2>&1; then
  marker="asahi-cliphist-delete-$$"
  printf '%s\n' "$marker" | cliphist store
  del_id="$(cliphist list | grep -m1 -F -- "$marker" | cut -f1 || true)"
  if [ -n "$del_id" ]; then
    "$CLIP" delete "$del_id"
    if cliphist list | grep -F -- "$marker" >/dev/null; then
      fail_at "delete left $marker in cliphist"
    else
      pass "delete removes the list line"
    fi
  else
    fail_at "could not store delete marker"
  fi
fi

qml="$ROOT/../quickshell/remix/modules/launcher/LauncherWindow.qml"
if grep -q 'mode: "clipboard"' "$qml" && grep -q 'quickClipboardComp' "$qml"; then
  pass "launcher has clipboard quick tile"
else
  fail_at "launcher missing clipboard quick tile"
fi
if grep -q 'asahi-cliphist", "watch"' "$qml"; then
  pass "launcher starts cliphist watchers"
else
  fail_at "launcher does not call asahi-cliphist watch"
fi

if [ "$fail" -ne 0 ]; then
  echo "$fail failed"
  exit 1
fi
echo "all passed"
