#!/usr/bin/env bash
# Smoke tests for asahi-webcam / asahi-cmd-record --webcam. No live capture.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
cleanup() { rm -rf "$tmp" || true; }
trap cleanup EXIT

chmod +x "$ROOT/asahi-webcam" "$ROOT/asahi-cmd-record"

"$ROOT/asahi-webcam" 2>/dev/null && fail_at "webcam no-arg should fail" || pass "webcam usage"
"$ROOT/asahi-cmd-record" --webcam-size=huge 2>/dev/null && fail_at "bad webcam size should fail" || pass "record rejects bad webcam size"

# sysfs fallback when v4l2-ctl is absent
mkdir -p "$tmp/dev" "$tmp/sys/class/video4linux/video0" "$tmp/bin"
printf 'apple-isp\n' >"$tmp/sys/class/video4linux/video0/name"
# A real char device is not required for the name walk if we bind-mount; instead
# drive list via a stub v4l2-ctl so the test does not depend on /dev/video*.
cat >"$tmp/bin/v4l2-ctl" <<'EOF'
#!/bin/sh
if [[ $1 == --list-devices ]]; then
  printf '%s\n' "apple-isp (platform:384000000.isp):" "	/dev/video0"
  exit 0
fi
if [[ $1 == --device && $3 == --info ]]; then
  printf '%s\n' "Device Caps      :" "	Video Capture"
  exit 0
fi
exit 0
EOF
chmod +x "$tmp/bin/v4l2-ctl"
out=$(PATH="$tmp/bin:$PATH" "$ROOT/asahi-webcam" list)
echo "$out" | grep -q '/dev/video0' || fail_at "list prints /dev/video0 (got $out)"
echo "$out" | grep -q 'apple-isp' || fail_at "list prints apple-isp"
pass "webcam list via v4l2-ctl"

dry=$(ASAHI_WEBCAM_DRY_RUN=1 PATH="$tmp/bin:$PATH" "$ROOT/asahi-webcam" overlay start --device /dev/video0 --size small)
echo "$dry" | grep -q 'av://v4l2:/dev/video0' || fail_at "dry-run mpv v4l2 url"
echo "$dry" | grep -q 'WebcamOverlay-small' || fail_at "dry-run app-id small"
pass "overlay start dry-run"

# Resize: mocked hyprctl clients + monitors
kw="$tmp/hypr.log"
: >"$kw"
cat >"$tmp/bin/hyprctl" <<EOF
#!/bin/sh
if [[ \$1 == clients ]]; then
  printf '%s\n' '[{"title":"WebcamOverlay","address":"0x1","size":[400,450],"monitor":0}]'
  exit 0
fi
if [[ \$1 == monitors ]]; then
  printf '%s\n' '[{"id":0,"x":0,"y":0,"width":1920,"height":1080,"scale":1,"transform":0}]'
  exit 0
fi
if [[ \$1 == dispatch ]]; then
  printf '%s\n' "\$*" >> "$kw"
  exit 0
fi
exit 0
EOF
chmod +x "$tmp/bin/hyprctl"
PATH="$tmp/bin:$PATH" "$ROOT/asahi-webcam" resize medium
grep -q 'x = 240' "$kw" || fail_at "resize medium width (got $(tr '\n' ' ' <"$kw"))"
grep -q 'y = 270' "$kw" || fail_at "resize medium height"
grep -q 'x = 1640' "$kw" || fail_at "resize medium x (1920-240-40)"
grep -q 'y = 770' "$kw" || fail_at "resize medium y (1080-270-40)"
pass "resize medium on 1080p monitor"

grep -q 'asahi-cmd-record webcam' "$ROOT/../hypr/conf.d/bindings.lua" || fail_at "hypr bind record webcam"
grep -q 'asahi-webcam resize smaller' "$ROOT/../hypr/conf.d/bindings.lua" || fail_at "hypr bind overlay smaller"
grep -q 'asahi-webcam resize larger' "$ROOT/../hypr/conf.d/bindings.lua" || fail_at "hypr bind overlay larger"
pass "hypr binds webcam record + resize"

grep -q 'WebcamOverlay-medium' "$ROOT/../hypr/conf.d/rules.lua" || fail_at "rules.lua webcam overlay class"
grep -q 'keep_aspect_ratio = true' "$ROOT/../hypr/conf.d/rules.lua" || fail_at "rules.lua PiP keep_aspect"
grep -q 'xdg-desktop-portal-gtk' "$ROOT/../hypr/conf.d/rules.lua" || fail_at "rules.lua portal-gtk float"
grep -q 'obsproject' "$ROOT/../hypr/conf.d/rules.lua" || fail_at "rules.lua opaque media"
pass "rules.lua media / PiP / webcam / portal"

grep -qE '^[[:space:]]*v4l-utils \\$' "$ROOT/../dnf.sh" || fail_at "dnf.sh installs v4l-utils"
pass "dnf.sh includes v4l-utils"

if [ "$fail" -ne 0 ]; then
  echo "asahi_webcam_test.sh: FAILED"
  exit 1
fi
echo "asahi_webcam_test.sh: all ok"
