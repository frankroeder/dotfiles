#!/usr/bin/env bash
# Smoke-test wallpaper → adaptive theme pipeline (Asahi).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export DOTFILES="${DOTFILES:-$ROOT}"
export PATH="$DOTFILES/asahi/bin:$PATH"

WALL="${1:-$HOME/Pictures/wallpaper/aesthetic_deer.jpg}"
if [[ ! -f "$WALL" ]]; then
  echo "skip: wallpaper not found: $WALL" >&2
  exit 0
fi

OUT="${2:-$(mktemp -d /tmp/asahi-autotheme-smoke.XXXXXX)}"
mkdir -p "$OUT"

echo "== extract/apply =="
asahi-autotheme --no-apply "$WALL" | tee "$OUT/apply.txt"

STATE="${XDG_STATE_HOME:-$HOME/.local/state}/asahi-theme"
for f in colors.json colors.toml ghostty.theme hyprland.lua hyprlock.conf librewolf.css gtk.css chromium-theme.json wallpaper screensaver-colors.toml theme.name; do
  test -s "$STATE/$f" || { echo "missing $STATE/$f" >&2; exit 1; }
done

python3 -c "
import json, sys
p = json.load(open(sys.argv[1]))
hex_keys = ['accent', 'background', 'foreground', 'base', 'text', 'blue', 'red']
missing = [k for k in hex_keys if k not in p or not str(p[k]).startswith('#')]
if missing:
    raise SystemExit('colors.json missing/invalid: ' + str(missing))
if p.get('mode') not in ('dark', 'light'):
    raise SystemExit('bad mode ' + str(p.get('mode')))
print('colors.json ok:', p['mode'], p['accent'], p['background'])
" "$STATE/colors.json"

test -s "$HOME/.config/ghostty/themes/asahi-adaptive" \
  || test -s "$DOTFILES/asahi/ghostty/themes/asahi-adaptive" \
  || { echo "ghostty theme not installed" >&2; exit 1; }

test -s "$HOME/.config/ghostty/adaptive.conf" \
  || test -s "$DOTFILES/asahi/ghostty/adaptive.conf" \
  || { echo "ghostty adaptive.conf missing" >&2; exit 1; }

test -s "$HOME/.config/ghostty/adaptive.css" \
  || test -s "$DOTFILES/asahi/ghostty/adaptive.css" \
  || { echo "ghostty adaptive.css missing" >&2; exit 1; }

rg -q "window-theme = ghostty" "$HOME/.config/ghostty/adaptive.conf" \
  "$DOTFILES/asahi/ghostty/adaptive.conf" 2>/dev/null \
  || { echo "adaptive.conf missing window-theme=ghostty" >&2; exit 1; }
rg -q "gtk-custom-css" "$HOME/.config/ghostty/adaptive.conf" \
  "$DOTFILES/asahi/ghostty/adaptive.conf" 2>/dev/null \
  || { echo "adaptive.conf missing gtk-custom-css" >&2; exit 1; }
rg -q "window_bg_color" "$HOME/.config/ghostty/adaptive.css" \
  "$DOTFILES/asahi/ghostty/adaptive.css" 2>/dev/null \
  || { echo "adaptive.css missing Adwaita vars" >&2; exit 1; }

rg -q "BrowserThemeColor" "$STATE/chromium-theme.json" \
  || { echo "chromium-theme.json missing BrowserThemeColor" >&2; exit 1; }
rg -q "accent_bg_color" "$STATE/gtk.css" \
  || { echo "gtk.css missing accent_bg_color" >&2; exit 1; }
rg -q "lock_accent" "$STATE/hyprlock.conf" \
  || { echo "hyprlock.conf missing lock_accent" >&2; exit 1; }

test -s "$HOME/.config/gtk-3.0/asahi-adaptive.css" \
  || { echo "gtk-3.0/asahi-adaptive.css not installed" >&2; exit 1; }
test -s "$HOME/.config/gtk-4.0/asahi-adaptive.css" \
  || { echo "gtk-4.0/asahi-adaptive.css not installed" >&2; exit 1; }

echo "== dry-run variants =="
for v in source calm vibrant deep; do
  asahi-autotheme --dry-run --variant "$v" "$WALL" >/dev/null
  echo "  $v ok"
done

STYLE="$DOTFILES/asahi/quickshell/remix/Style.qml"
rg -q "menuAccent:\s*accent" "$STYLE" || { echo "Style.qml menuAccent must be wallpaper accent" >&2; exit 1; }
rg -q 'menuRowSel:\s*themedAlpha\("text", 0\.08\)' "$STYLE" \
  || { echo "Style.qml menuRowSel must be text@0.08 (omarchy selected-background)" >&2; exit 1; }
rg -q "<<<<<<|>>>>>>|======" "$STYLE" && { echo "Style.qml still has conflict markers" >&2; exit 1; }
rg -q "asahi-hdmi sync" "$DOTFILES/asahi/hypr/conf.d/autostart.lua" \
  || { echo "autostart.lua missing asahi-hdmi sync" >&2; exit 1; }
rg -q "asahi-autotheme" "$DOTFILES/asahi/hypr/conf.d/autostart.lua" \
  || { echo "autostart.lua missing asahi-autotheme" >&2; exit 1; }
rg -q "Settings=gtk" "$DOTFILES/asahi/xdg-desktop-portal/portals.conf" \
  || { echo "portals.conf must pin Settings=gtk" >&2; exit 1; }
rg -q "QT_QPA_PLATFORMTHEME" "$DOTFILES/asahi/hypr/conf.d/env.lua" \
  || { echo "env.lua missing QT_QPA_PLATFORMTHEME" >&2; exit 1; }

echo "PASS asahi-autotheme smoke ($OUT)"
