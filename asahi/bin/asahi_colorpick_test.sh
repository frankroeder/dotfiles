#!/usr/bin/env bash
# asahi-cmd-colorpick: swatch card (app `screenshot`, no -t), rgb()/hsl() actions re-copy, HSL rounding, Esc = silence.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PICK="$ROOT/asahi-cmd-colorpick"
fail=0
pass() { printf 'ok  %s\n' "$1"; }
fail_at() { printf 'FAIL %s\n' "$1"; fail=1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export T="$tmp"
mkdir -p "$tmp/bin" "$tmp/run"

# hyprpicker prints $T/pick (empty = Esc); notify-send logs one [arg] per arg and answers $T/act.
cat >"$tmp/bin/hyprpicker" <<'EOF'
#!/bin/sh
echo "$*" >"$T/hyprpicker.args"
grep . "$T/pick" || exit 1  # Esc: nothing printed, non-zero
EOF
cat >"$tmp/bin/notify-send" <<'EOF'
#!/bin/sh
printf '[%s]' "$@" >>"$T/notify.log"; echo >>"$T/notify.log"
cat "$T/act"
EOF
cat >"$tmp/bin/wl-copy" <<'EOF'
#!/bin/sh
echo "$*" >>"$T/wl-copy.log"
EOF
cat >"$tmp/bin/magick" <<'EOF'
#!/bin/sh
echo "$*" >>"$T/magick.log"
for a; do :; done
: >"$a"
EOF
# setsid -f would return before the card's answer: run it in place.
printf '#!/bin/sh\n[ "$1" = -f ] && shift\nexec "$@"\n' >"$tmp/bin/setsid"
chmod +x "$tmp/bin/"*

run() {
  rm -f "$tmp/notify.log" "$tmp/wl-copy.log" "$tmp/magick.log"
  printf '%s\n' "$1" >"$tmp/pick"
  printf '%s' "${2:-}" >"$tmp/act"
  PATH="$tmp/bin:$PATH" XDG_RUNTIME_DIR="$tmp/run" bash "$PICK"
}

run '#1E66F5' hsl
card=$(cat "$tmp/notify.log")
png="$tmp/run/asahi-colorpick-1E66F5.png"
[ "$card" = "[-a][screenshot][-i][$png][-A][rgb=rgb()][-A][hsl=hsl()][Copied #1E66F5][rgb(30, 102, 245) · hsl(220, 91%, 54%)]" ] \
  && pass "card: app screenshot, swatch, rgb()/hsl() actions, no -t" || fail_at "card=$card"
[ -f "$png" ] && pass "swatch written to the runtime dir" || fail_at "no swatch $png"
grep -qx -- "-size 48x48 xc:#1E66F5 $png" "$tmp/magick.log" && pass "magick fills the swatch with the hex" || fail_at "magick=$(cat "$tmp/magick.log")"
[ "$(cat "$tmp/hyprpicker.args")" = "-b -f hex" ] && pass "hyprpicker without -a (the script copies)" || fail_at "hyprpicker args=$(cat "$tmp/hyprpicker.args")"
[ "$(cat "$tmp/wl-copy.log")" = $'#1E66F5\nhsl(220, 91%, 54%)' ] && pass "hex copied, hsl() action copies hsl" || fail_at "wl-copy=$(cat "$tmp/wl-copy.log")"

run '#F5C2E7' rgb
[ "$(cat "$tmp/wl-copy.log")" = $'#F5C2E7\nrgb(245, 194, 231)' ] && pass "rgb() action copies rgb" || fail_at "wl-copy=$(cat "$tmp/wl-copy.log")"
swatches=$(cd "$tmp/run" && echo asahi-colorpick-*.png)
[ "$swatches" = "asahi-colorpick-F5C2E7.png" ] && pass "one swatch kept, named by colour" || fail_at "swatches=$swatches"

run '#A6E3A1' ''
[ "$(cat "$tmp/wl-copy.log")" = "#A6E3A1" ] && pass "card closed without action: hex only" || fail_at "copied $(cat "$tmp/wl-copy.log")"

run ''
[ ! -e "$tmp/notify.log" ] && [ ! -e "$tmp/magick.log" ] && [ ! -e "$tmp/wl-copy.log" ] && pass "Esc: no copy, card or swatch" || fail_at "Esc still acted"

# HSL rounding: grey axis, hue wrap (359.8 -> 0), each max channel.
for c in '#FF0000 hsl(0, 100%, 50%)' '#000000 hsl(0, 0%, 0%)' '#FFFFFF hsl(0, 0%, 100%)' '#808080 hsl(0, 0%, 50%)' \
  '#FF0001 hsl(0, 100%, 50%)' '#F5C2E7 hsl(316, 72%, 86%)' '#A6E3A1 hsl(115, 54%, 76%)' '#1E66F5 hsl(220, 91%, 54%)'; do
  run "${c%% *}" ''
  grep -qF " · ${c#* }]" "$tmp/notify.log" && pass "${c%% *} = ${c#* }" || fail_at "${c%% *}: $(cat "$tmp/notify.log")"
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi
echo "all ok"
