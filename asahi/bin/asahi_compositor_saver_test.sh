#!/usr/bin/env bash
# Tests for asahi-compositor-saver. Fake hyprctl: getoption answers from files, eval calls are logged.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export XDG_RUNTIME_DIR="$tmp/rt" OPT="$tmp/opt" EVALS="$tmp/evals"
mkdir -p "$XDG_RUNTIME_DIR" "$OPT"
echo '{"option": "decoration:blur:enabled", "bool": true, "set": false}' >"$OPT/decoration:blur:enabled"
echo '{"option": "decoration:inactive_opacity", "float": 0.900000, "set": true}' >"$OPT/decoration:inactive_opacity"
echo '{"option": "animations:enabled", "bool": true, "set": false}' >"$OPT/animations:enabled"
cat >"$tmp/hyprctl" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  getoption) cat "$OPT/$2" ;;
  eval) echo "$2" >>"$EVALS" ;;
esac
EOF
chmod +x "$tmp/hyprctl"
export PATH="$tmp:$PATH"
saver() { "$ROOT/asahi-compositor-saver" "$@"; }
state="$XDG_RUNTIME_DIR/asahi-compositor-saver.json"

saver off; saver reload
if [ ! -e "$EVALS" ] && [ ! -e "$state" ]; then pass "off / reload without a saver: nothing"; else fail_at "idle off/reload touched Hyprland"; fi

saver on
if jq -e '.blur == true and .opacity == 0.9 and .anim == true' "$state" >/dev/null \
  && grep -qF 'blur = { enabled = false }, inactive_opacity = 1 }, animations = { enabled = false }' "$EVALS"; then
  pass "on: keeps the live values, blur / translucency / animations off"
else
  fail_at "on: state=$(cat "$state" 2>/dev/null) evals=$(cat "$EVALS")"
fi

# A second `on` (the saver's own values are live now) must not overwrite what to restore.
echo '{"option": "decoration:blur:enabled", "bool": false, "set": true}' >"$OPT/decoration:blur:enabled"
saver on
if [ "$(jq -r .blur "$state")" = true ]; then pass "a second on keeps the first saved values"; else fail_at "second on saved the saver's values"; fi

# After a config reload the config's values are live again: reload saves them afresh.
echo '{"option": "decoration:inactive_opacity", "float": 0.850000, "set": true}' >"$OPT/decoration:inactive_opacity"
echo '{"option": "decoration:blur:enabled", "bool": true, "set": false}' >"$OPT/decoration:blur:enabled"
saver reload
if jq -e '.opacity == 0.85' "$state" >/dev/null && [ "$(grep -c 'enabled = false' "$EVALS")" = 3 ]; then
  pass "reload: saves the reloaded values, applies the saver again"
else
  fail_at "reload: state=$(cat "$state")"
fi

saver off
if [ ! -e "$state" ] && tail -n 1 "$EVALS" | grep -qE 'blur = \{ enabled = true \}, inactive_opacity = 0\.850* \}, animations = \{ enabled = true \}'; then
  pass "off: restores the saved values and forgets them"
else
  fail_at "off: last eval=$(tail -n 1 "$EVALS")"
fi

[ "$fail" = 0 ] && echo "all passed"
exit "$fail"
