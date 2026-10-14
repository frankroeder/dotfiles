#!/usr/bin/env bash
# Smoke tests for asahi-cliphist JSON contract. Scratch db + runtime dir, fake wl-paste / hyprctl /
# pgrep / pkill: the real history, clipboard and watchers are never touched.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIP="$ROOT/asahi-cliphist"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

chmod +x "$CLIP"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/run"
printf '#!/usr/bin/env bash\necho "{\\"class\\": \\"$FAKE_CLASS\\"}"\n' >"$tmp/bin/hyprctl"
cat >"$tmp/bin/wl-paste" <<'EOF'
#!/bin/sh
echo "wl-paste $*" >>"$FAKE_LOG"
case "$*" in
  *--watch*) ;;
  *--list-types*) echo text/plain ;;
  *) printf 'seeded-selection' ;;
esac
EOF
printf '#!/bin/sh\nexit 1\n' >"$tmp/bin/pgrep"
printf '#!/bin/sh\nexit 0\n' >"$tmp/bin/pkill"
chmod +x "$tmp/bin/"*
export CLIPHIST_DB_PATH="$tmp/db" XDG_RUNTIME_DIR="$tmp/run" PATH="$tmp/bin:$PATH" FAKE_LOG="$tmp/calls" FAKE_CLASS=""

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
  pass "watch exits 0"
else
  fail_at "watch failed"
fi

if command -v cliphist >/dev/null 2>&1; then
  # setsid -f returns before the fake watcher logs.
  for _ in 1 2 3 4 5 6 7 8 9 10; do grep -q 'image --watch' "$FAKE_LOG" && break; sleep 0.1; done
  self="$(readlink -f "$CLIP")"
  if grep -q -- "--type text --watch $self store" "$FAKE_LOG" && grep -q -- "--type image --watch $self store" "$FAKE_LOG"; then
    pass "watch starts one filtered watcher per type"
  else
    fail_at "watch calls: $(cat "$FAKE_LOG")"
  fi
  if cliphist list | grep -qF 'seeded-selection'; then pass "watch seeds the current selection"; else fail_at "current selection not seeded"; fi

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

  # Proton flow on a fresh db: password copied in Firefox is dropped, its auto-clear ("") must
  # not delete the entry before it.
  run() { CLIPHIST_DB_PATH="$tmp/db2" CLIPBOARD_STATE=data FAKE_CLASS="$1" "$CLIP" store; }
  pw='Tactful-Cartel9-Spinach'
  has() { CLIPHIST_DB_PATH="$tmp/db2" cliphist list | grep -qF -- "$1"; }
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
  # asahi-writing-tools flags its own Ctrl+C: skipped while the flag is fresh, stored again after.
  mkdir -p "$XDG_RUNTIME_DIR/asahi-cliphist" && touch "$XDG_RUNTIME_DIR/asahi-cliphist/skip"
  printf 'writing tools selection' | run com.mitchellh.ghostty
  if has 'writing tools selection'; then fail_at "writing tools capture was stored"; else pass "writing tools capture is skipped"; fi
  touch -d '-5 seconds' "$XDG_RUNTIME_DIR/asahi-cliphist/skip"
  printf 'later copy' | run com.mitchellh.ghostty
  if has 'later copy'; then pass "a stale skip flag stores again"; else fail_at "stale skip flag dropped a copy"; fi
  if [ -z "$(find "$XDG_RUNTIME_DIR" -maxdepth 2 -name 'store.*')" ]; then
    pass "store leaves no staged copy behind"
  else
    fail_at "staged clipboard copy left in runtime dir"
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
