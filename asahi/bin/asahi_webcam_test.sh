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
# Pid / region files of a live overlay or recording are never read or removed.
export XDG_RUNTIME_DIR="$tmp/run"
mkdir -p "$XDG_RUNTIME_DIR"

chmod +x "$ROOT/asahi-webcam" "$ROOT/asahi-cmd-record"

"$ROOT/asahi-webcam" 2>/dev/null && fail_at "webcam no-arg should fail" || pass "webcam usage"
"$ROOT/asahi-cmd-record" --webcam-size=large 2>/dev/null && fail_at "unknown flag should fail" || pass "record rejects unknown flags"

# list via a stub v4l2-ctl, so the test does not depend on /dev/video*.
mkdir -p "$tmp/bin"
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

sleep 30 &
overlay=$!
echo "$overlay" >"$XDG_RUNTIME_DIR/asahi-webcam.pid"
dry=$(ASAHI_WEBCAM_DRY_RUN=1 PATH="$tmp/bin:$PATH" "$ROOT/asahi-webcam" overlay start --device /dev/video0)
echo "$dry" | grep -q 'av://v4l2:/dev/video0' || fail_at "dry-run mpv v4l2 url"
echo "$dry" | grep -q 'WebcamOverlay-medium' || fail_at "dry-run app-id medium"
kill -0 "$overlay" 2>/dev/null && [ -e "$XDG_RUNTIME_DIR/asahi-webcam.pid" ] || fail_at "dry run stopped the running overlay"
kill "$overlay" 2>/dev/null || true
pass "overlay start dry-run leaves a running overlay alone"

# Aurora's denoised camera: pw-v4l2 maps the open to its PipeWire node (object.serial); raw V4L2 without the node.
printf '#!/bin/sh\necho \x27[{"info":{"props":{"node.name":"aurora_camera_denoise.isp","object.serial":"77"}}}]\x27\n' >"$tmp/bin/pw-dump"
printf '#!/bin/sh\nexit 0\n' >"$tmp/bin/pw-v4l2"
chmod +x "$tmp/bin/pw-dump" "$tmp/bin/pw-v4l2"
dry=$(ASAHI_WEBCAM_DRY_RUN=1 PATH="$tmp/bin:$PATH" "$ROOT/asahi-webcam" overlay start --device /dev/video1)
printf '#!/bin/sh\necho "[]"\n' >"$tmp/bin/pw-dump"
raw=$(ASAHI_WEBCAM_DRY_RUN=1 PATH="$tmp/bin:$PATH" "$ROOT/asahi-webcam" overlay start --device /dev/video1)
if [[ $dry == "env PIPEWIRE_V4L2_TARGET=77 pw-v4l2 mpv av://v4l2:/dev/video1"* && $raw == "mpv av://v4l2:/dev/video1"* ]]; then
  pass "denoised camera via pw-v4l2 (object.serial), raw V4L2 without the node"
else
  fail_at "camera wrap: [$dry] [$raw]"
fi

# Camera only: ffmpeg straight from the (denoised) camera at its largest 16:9 size, the mic as audio, H.264 (libopenh264).
printf '#!/bin/sh\necho \x27[{"info":{"props":{"node.name":"aurora_camera_denoise.isp","object.serial":"77"}}}]\x27\n' >"$tmp/bin/pw-dump"
printf '#!/bin/sh\nexec "$@"\n' >"$tmp/bin/pw-v4l2"
cat >"$tmp/bin/v4l2-ctl" <<'EOF'
#!/bin/sh
case $1 in
  --list-devices) printf '%s\n' "apple-isp (platform:384000000.isp):" "	/dev/video0" ;;
  --device) printf '%s\n' "Device Caps      :" "	Video Capture" ;;
  --list-formats-ext) printf '%s\n' "Size: Discrete 640x480" "Size: Discrete 1280x720" "Size: Discrete 1920x1080" ;;
esac
EOF
args=$(PATH="$tmp/bin:$PATH" "$ROOT/asahi-webcam" record-args /x/rec.mp4 mic | tr '\0' ' ')
silent=$(PATH="$tmp/bin:$PATH" "$ROOT/asahi-webcam" record-args /x/rec.mp4 | tr '\0' ' ')
want="env PIPEWIRE_V4L2_TARGET=77 pw-v4l2 ffmpeg -hide_banner -nostdin -loglevel warning -f v4l2 -framerate 30 -video_size 1920x1080 \
-i /dev/video0 -f pulse -i mic -c:a aac -b:a 160k -c:v libopenh264 -b:v 8M -r 30 -pix_fmt yuv420p -y /x/rec.mp4 "
if [ "$args" = "$want" ] && [[ $silent != *pulse* && $silent == *"-y /x/rec.mp4 " ]]; then
  pass "camera-only recorder: denoised camera, 1080p, mic, H.264"
else
  fail_at "record-args: [$args] silent [$silent]"
fi
grep -q 'asahi-cmd-record camera' "$ROOT/../hypr/conf.d/bindings.lua" || fail_at "hypr bind record camera"
grep -q 'start("camera", false)' "$ROOT/../quickshell/remix/modules/bar/components/RecordPanel.qml" || fail_at "RecordPanel camera tile"
pass "camera-only: bind + panel tile"

# Camera-only lifecycle without a camera: a copy of asahi-cmd-record beside a fake asahi-webcam whose recorder is a
# real ffmpeg on a synthetic source (pid must resolve to ffmpeg naming our file). Fake qs / notify-send / pactl.
rec="$tmp/rec"
mkdir -p "$rec/bin" "$rec/videos"
cp "$ROOT/asahi-cmd-record" "$rec/"
cp -r "$ROOT/lib" "$rec/"
# With the mic the recorder fails late (~0.8 s, past the old 0.4 s check, no file): the silent retry must take over.
cat >"$rec/asahi-webcam" <<EOF
#!/usr/bin/env bash
case \$1 in
  record-args)
    if [ -n "\$3" ]; then printf '%s\0' ffmpeg -nostdin -loglevel error -re -f lavfi -i testsrc -t 1.2 -f null "\$2"
    else printf '%s\0' ffmpeg -nostdin -loglevel error -re -f lavfi -i testsrc=size=160x120:rate=30 -c:v libopenh264 -y "\$2"; fi ;;
  overlay)
    echo "\$2" >>"$rec/overlay.log"
    if [ "\$2" = start ]; then echo \$\$ >"$rec/asahi-webcam.pid"; else rm -f "$rec/asahi-webcam.pid"; fi ;;
esac
EOF
printf '#!/bin/sh\nexit 0\n' >"$rec/bin/qs"
cp "$rec/bin/qs" "$rec/bin/notify-send"
printf '#!/bin/sh\necho mic\n' >"$rec/bin/pactl"
chmod +x "$rec/asahi-webcam" "$rec/asahi-cmd-record" "$rec/bin/"*
recrun() { XDG_VIDEOS_DIR="$rec/videos" XDG_RUNTIME_DIR="$rec" PATH="$rec/bin:$PATH" "$rec/asahi-cmd-record" "$@"; }
recrun camera
st1=$(recrun status)
kill -KILL "$(cat "$rec/asahi-record.pid" 2>/dev/null)" 2>/dev/null || true   # the recorder dies on its own
sleep 2.5
st2=$(recrun status)
ov1=$(tr '\n' ' ' <"$rec/overlay.log")
# A new take's overlay (up before its recorder) when this take's recorder dies: the old watcher leaves it.
recrun camera
echo 999999 >"$rec/asahi-webcam.pid"
kill -KILL "$(cat "$rec/asahi-record.pid" 2>/dev/null)" 2>/dev/null || true
sleep 2.5
ov2=$(tr '\n' ' ' <"$rec/overlay.log")
recrun camera
sleep 1
recrun camera   # toggle: stops
st3=$(recrun status)
marker=$(cat "$rec/asahi-record.file" 2>/dev/null || true)   # cleared: a later foreign stop must not finish it again
last=$(ls -t "$rec/videos"/recording-*-camera.mp4 2>/dev/null | sed -n 1p || true)
dur=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$last" 2>/dev/null || true)
# A stale pid file now naming another ffmpeg (not our file): not ours, never stopped.
ffmpeg -nostdin -loglevel error -re -f lavfi -i testsrc=rate=5 -f null - &
other=$!
sleep 0.3
echo "$other" >"$rec/asahi-record.pid"
echo "$last" >"$rec/asahi-record.file"
st4=$(recrun status)
kill "$other" 2>/dev/null || true
if [ "$st1" = recording ] && [ "$st2" = stopped ] && [ "$ov1" = "start stop " ] && [ "$ov2" = "start stop start " ] \
  && [ "$st3" = stopped ] && [ -z "$marker" ] && [[ $last == *-camera.mp4 && -n $dur ]] && [ "$st4" = stopped ] \
  && [ ! -e "$rec/asahi-record.pid" ]; then
  pass "camera only: late failure retries silent, a dead recorder drops only its own overlay, toggle stops, foreign ffmpeg not ours"
else
  fail_at "camera lifecycle: [$st1] [$st2] overlay [$ov1] [$ov2] [$st3] marker [$marker] [$last $dur] foreign [$st4]"
fi

# finish (detached after a stop): audio muted at the start + loudness-normalised (AAC 48 kHz, video copied), a
# thumbnail card; a file without its MP4 index warns.
printf '#!/bin/sh\necho "$*" >>"%s/notify.log"\n' "$rec" >"$rec/bin/notify-send"
clip="$rec/videos/recording-clip.mp4"
ffmpeg -nostdin -loglevel error -f lavfi -i testsrc=size=160x120:rate=30:duration=1 -f lavfi -i sine=duration=1 \
  -c:v libopenh264 -c:a aac -y "$clip"
head -c 2000 "$clip" >"$rec/videos/recording-broken.mp4"
recrun finish "$clip"
recrun finish "$rec/videos/recording-broken.mp4"
audio=$(ffprobe -v error -select_streams a -show_entries stream=codec_name,sample_rate -of csv=p=0 "$clip")
if [ "$audio" = "aac,48000" ] && [ ! -e "$clip.tmp" ] && [ -s "$rec/asahi-record-recording-clip.png" ] \
  && grep -q -- "-i $rec/asahi-record-recording-clip.png -A default=Open Recording saved $clip" "$rec/notify.log" \
  && grep -q -- "-u critical Recording may be corrupted" "$rec/notify.log"; then
  pass "finish: audio finished, thumbnail card; a broken file warns"
else
  fail_at "finish: audio [$audio] notify [$(tr '\n' '|' <"$rec/notify.log")]"
fi

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
grep -q '{ opaque = true })' "$ROOT/../hypr/conf.d/rules.lua" || fail_at "rules.lua opaque media"
pass "rules.lua media / PiP / webcam / portal"

grep -qE '^[[:space:]]*v4l-utils \\$' "$ROOT/../dnf.sh" || fail_at "dnf.sh installs v4l-utils"
pass "dnf.sh includes v4l-utils"

if [ "$fail" -ne 0 ]; then
  echo "asahi_webcam_test.sh: FAILED"
  exit 1
fi
echo "asahi_webcam_test.sh: all ok"
