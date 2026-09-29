#!/usr/bin/env bash
# The host must emit a length-prefixed scheme, then another when the file is replaced.
set -euo pipefail

root=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
host=$root/asahi-firefox-theme
state=$(mktemp -d)
dir=$state/asahi-theme
mkdir -p "$dir"
scheme=$dir/firefox.json
printf '%s\n' '{"mode":"dark","colours":{"primary":"112233"}}' >"$scheme"

read_one() {
  EXPECT="$1" uv run --no-project python -c '
import json, os, struct, sys
n = struct.unpack("<I", sys.stdin.buffer.read(4))[0]
body = sys.stdin.buffer.read(n)
msg = json.loads(body)
assert msg["colours"]["primary"] == os.environ["EXPECT"], msg
print("ok ", os.environ["EXPECT"])
'
}

# Firefox passes the manifest path and extension id; the host must ignore them.
coproc HOST { XDG_STATE_HOME="$state" "$host" /nonexistent/caelestiafox.json caelestiafox@caelestia.org; }
sleep 0.2
read_one "112233" <&"${HOST[0]}"

printf '%s\n' '{"mode":"light","colours":{"primary":"abcdef"}}' >"$scheme.next"
mv "$scheme.next" "$scheme"
sleep 0.4
read_one "abcdef" <&"${HOST[0]}"

kill "$HOST_PID" 2>/dev/null || true
wait "$HOST_PID" 2>/dev/null || true
echo "all passed"
