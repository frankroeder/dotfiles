#!/usr/bin/env bash
# Drives asahi-window-gesture through a fake hyprctl and checks call order.
set -euo pipefail

root=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
gesture=$root/asahi-window-gesture
fail=0

say() { printf '%s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1" >&2; fail=1; }

run_case() {
  local name=$1 window=$2
  local dir log
  dir=$(mktemp -d)
  log=$dir/log
  cat >"$dir/hyprctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
state=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
case "${1:-}" in
  activewindow) cat "$state/window.json" ;;
  monitors) cat "$state/monitors.json" ;;
  dispatch) printf '%s\n' "$*" >>"$state/log"; ;;
  *) echo "unexpected hyprctl $*" >&2; exit 3 ;;
esac
EOF
  chmod +x "$dir/hyprctl"
  printf '%s\n' "$window" >"$dir/window.json"
  cat >"$dir/monitors.json" <<'EOF'
[{"name":"HDMI-A-1","focused":true,"width":2560,"height":1440,"scale":1.25,"x":-2048,"y":-170,"reserved":[0,44,0,0]}]
EOF
  : >"$log"
  PATH="$dir:$PATH" "$gesture" "$name"
  cat "$log"
}

assert_order() {
  local log=$1 first=$2 second=$3 msg=$4
  local a b
  a=$(grep -n -m 1 -F "$first" "$log" | cut -d: -f1 || true)
  b=$(grep -n -m 1 -F "$second" "$log" | cut -d: -f1 || true)
  if [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]; then
    say "ok  $msg"
  else
    bad "$msg (lines $a then $b)"
  fi
}

tiled='{"address":"0xabc","floating":false,"pinned":false,"fullscreen":0,"tags":[],"size":[900,700],"at":[-1800,-50]}'
floating='{"address":"0xabc","floating":true,"pinned":false,"fullscreen":0,"tags":[],"size":[900,700],"at":[-1800,-50]}'
pipped='{"address":"0xabc","floating":true,"pinned":true,"fullscreen":0,"tags":["pip"],"size":[400,300],"at":[-600,-120]}'
huge='{"address":"0xabc","floating":true,"pinned":false,"fullscreen":0,"tags":[],"size":[2244,1394],"at":[-2252,-420]}'

log=$(mktemp)
run_case float "$tiled" >"$log"
assert_order "$log" 'float({ action = "enable" })' 'resize({ x = 819, y = 460, relative = false })' "float is its own call before the 2/5 resize"
if grep -q 'relative = false' "$log" && grep -q 'center()' "$log"; then
  say "ok  float resize is exact and centered"
else
  bad "float resize/center"
fi

log=$(mktemp)
run_case pin "$tiled" >"$log"
assert_order "$log" 'float({ action = "enable" })' 'pin({ action = "on"' "tiled pin floats before pin"
if grep -q resize "$log"; then bad "pin must not resize"; else say "ok  pin does not resize"; fi

log=$(mktemp)
run_case pin "$floating" >"$log"
if grep -q 'window.pin()' "$log" && ! grep -q 'float({ action = "enable" })' "$log"; then
  say "ok  floating pin toggles pin only"
else
  bad "floating pin path"
fi

log=$(mktemp)
run_case pip "$tiled" >"$log"
assert_order "$log" 'float({ action = "enable" })' 'resize({ x =' "pip floats before resize"
assert_order "$log" 'resize({ x =' 'pin({ action = "on"' "pip pins after the exact resize"
if grep -q 'relative = false' "$log"; then say "ok  pip move/resize is exact"; else bad "pip relative"; fi

log=$(mktemp)
run_case pip "$pipped" >"$log"
if grep -q resize "$log"; then bad "pip toggle off must not resize"; else say "ok  pip second press does not resize"; fi
assert_order "$log" 'pin({ action = "disable" })' 'float({ action = "disable" })' "pip second press unpins then untiles"

log=$(mktemp)
run_case float "$huge" >"$log"
assert_order "$log" 'resize({ x = 2028, y = 1088, relative = false })' 'float({ action = "disable" })' "oversized float is shrunk before it is tiled"
if grep -q 'move({ x = -2038, y = -116, relative = false })' "$log"; then
  say "ok  oversized float is moved onto the monitor"
else
  bad "oversized float move"
fi

if [ "$fail" -ne 0 ]; then
  echo "$fail case(s) failed" >&2
  exit 1
fi
echo "all passed"
