#!/usr/bin/env sh
# arrange-displays.sh
# First space (index 1) on display 1, all others on display 2.

# wait briefly for macOS/yabai to settle display + space state on hotplug
sleep 2.0

yabai=/opt/homebrew/bin/yabai
jq=/opt/homebrew/bin/jq
sketchybar_top=/opt/homebrew/bin/sketchybar-top

displays=$("$yabai" -m query --displays 2>/dev/null | "$jq" 'length' 2>/dev/null || echo 0)
[ "$displays" -lt 2 ] && exit 0

"$yabai" -m query --spaces 2>/dev/null | "$jq" -r '.[] | "\(.index) \(.display)"' 2>/dev/null |
while read -r idx cur; do
  target=2
  [ "$idx" -eq 1 ] && target=1
  [ "$cur" != "$target" ] && "$yabai" -m space "$idx" --display "$target" 2>/dev/null || true
done

# force sketchybar to update after space moves on display change/hotplug
"$sketchybar_top" -m --trigger space_windows_refresh &> /dev/null || true
"$sketchybar_top" -m --trigger layout_change &> /dev/null || true
"$sketchybar_top" -m --trigger display_change &> /dev/null || true
