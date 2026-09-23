#!/usr/bin/env bash
# The host must emit a length-prefixed palette, then another when the file is replaced.
set -euo pipefail

root=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
host=$root/asahi-librewolf-theme
dir=$(mktemp -d)
colors=$dir/colors.json
printf '%s\n' '{"base":"#112233","mode":"dark"}' >"$colors"

read_one() {
  EXPECT="$1" uv run --no-project python -c '
import json, os, struct, sys
n = struct.unpack("<I", sys.stdin.buffer.read(4))[0]
body = sys.stdin.buffer.read(n)
msg = json.loads(body)
assert msg["base"] == os.environ["EXPECT"], msg
print("ok ", os.environ["EXPECT"])
'
}

coproc HOST { "$host" "$colors"; }
sleep 0.2
read_one "#112233" <&"${HOST[0]}"

printf '%s\n' '{"base":"#abcdef","mode":"light"}' >"$dir/colors.json.next"
mv "$dir/colors.json.next" "$colors"
sleep 0.4
read_one "#abcdef" <&"${HOST[0]}"

kill "$HOST_PID" 2>/dev/null || true
wait "$HOST_PID" 2>/dev/null || true
echo "all passed"
