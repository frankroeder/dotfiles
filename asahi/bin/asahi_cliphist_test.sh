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
  secret="asahi-cliphist-secret-$$"
  printf '%s' "$secret" | CLIPBOARD_STATE=sensitive "$CLIP" store
  if cliphist list | grep -F -- "$secret" >/dev/null; then
    fail_at "sensitive clipboard was stored"
  else
    pass "CLIPBOARD_STATE=sensitive is dropped"
  fi
  printf '%s' "$secret" | CLIPBOARD_STATE=data "$CLIP" store
  if cliphist list | grep -F -- "$secret" >/dev/null; then
    pass "CLIPBOARD_STATE=data is stored"
    del_id="$(cliphist list | grep -m1 -F -- "$secret" | cut -f1 || true)"
    [ -n "$del_id" ] && "$CLIP" delete "$del_id"
  else
    fail_at "data clipboard was not stored"
  fi

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

if command -v cliphist >/dev/null 2>&1; then
  # Scratch db and a fake hyprctl: the real history is never touched.
  tmp="$(mktemp -d)"
  printf '#!/usr/bin/env bash\necho "{\\"class\\": \\"$FAKE_CLASS\\"}"\n' >"$tmp/hyprctl"; chmod +x "$tmp/hyprctl"
  run() { CLIPHIST_DB_PATH="$tmp/db" XDG_RUNTIME_DIR="$tmp" PATH="$tmp:$PATH" CLIPBOARD_STATE=data FAKE_CLASS="$1" "$CLIP" store; }
  pw='Tactful-Cartel9-Spinach'
  has() { CLIPHIST_DB_PATH="$tmp/db" cliphist list | grep -qF -- "$1"; }
  # Proton flow: password copied in Firefox is dropped, its auto-clear ("") must
  # not delete the entry before it.
  printf 'keep me' | run com.mitchellh.ghostty
  printf '%s' "$pw" | run org.mozilla.firefox
  if has "$pw"; then fail_at "password-shaped browser copy was stored"; else pass "password-shaped token copied in Firefox is dropped"; fi
  printf '' | run org.mozilla.firefox
  if has 'keep me'; then pass "auto-clear after a dropped secret keeps the older entry"; else fail_at "auto-clear deleted an unrelated entry"; fi
  printf '%s' "$pw" | run com.mitchellh.ghostty
  if has "$pw"; then pass "same token from another app is stored"; else fail_at "non-browser token was dropped"; fi
  printf '' | run com.mitchellh.ghostty
  if has "$pw"; then pass "empty write after a non-browser copy deletes nothing"; else fail_at "empty write deleted a non-browser entry"; fi
  # A browser secret the shape check misses (spaces) is removed on auto-clear.
  printf 'correct horse battery' | run org.mozilla.firefox
  printf '' | run org.mozilla.firefox
  if has 'correct horse battery'; then fail_at "auto-clear left the stored browser secret"; else pass "auto-clear deletes the stored browser copy"; fi
  if has "$pw" && has 'keep me'; then pass "auto-clear deletes only that entry"; else fail_at "auto-clear deleted older entries"; fi
  if [ -z "$(find "$tmp" -maxdepth 2 -name 'store.*')" ]; then
    pass "store leaves no staged copy behind"
  else
    fail_at "staged clipboard copy left in runtime dir"
  fi
  rm -rf "$tmp"
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
