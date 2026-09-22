#!/usr/bin/env bash
# Smart-click snap: smallest rect under the pointer, not the monitor.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAP="$ROOT/asahi-capture-region"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/hyprctl" <<'EOF'
#!/bin/sh
case "$*" in
  "monitors -j")
    printf '%s\n' '[{"focused":true,"x":0,"y":0,"width":2000,"height":1200,"scale":2,"transform":0,"activeWorkspace":{"id":1}}]'
    ;;
  "clients -j")
    printf '%s\n' '[{"workspace":{"id":1},"hidden":false,"at":[100,80],"size":[200,150]}]'
    ;;
  *) exit 1 ;;
esac
EOF

cat >"$tmp/slurp" <<'EOF'
#!/bin/sh
cat >/dev/null
printf '%s\n' "$SLURP_OUT"
EOF
chmod +x "$tmp/hyprctl" "$tmp/slurp" "$CAP"

run() {
  PATH="$tmp:$PATH" SLURP_OUT="$1" "$CAP" smart
}

got=$(run "120,90 2x2")
[ "$got" = "100,80 200x150" ] && pass "click inside window snaps to window" || fail_at "window snap got=$got"

got=$(run "10,10 1x1")
[ "$got" = "0,0 1000x600" ] && pass "click on empty monitor snaps to monitor" || fail_at "monitor snap got=$got"

got=$(run "100,80 50x40")
[ "$got" = "100,80 50x40" ] && pass "real drag is kept" || fail_at "drag got=$got"

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "all ok"
