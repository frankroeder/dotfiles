#!/usr/bin/env sh
# arrange-displays.sh
# First space (index 1) on display 1, all others on display 2.

# wait briefly for macOS/yabai to settle display + space state on hotplug
sleep 1.0

yabai=$(command -v yabai)
jq=$(command -v jq)
sketchybar_top=$(command -v sketchybar-top)

if [ -z "$yabai" ] || [ -z "$jq" ]; then
  exit 0
fi

trigger_top() {
  [ -n "$sketchybar_top" ] || return 0
  "$sketchybar_top" -m --trigger "$1" >/dev/null 2>&1 || true
}

displays=$("$yabai" -m query --displays 2>/dev/null | "$jq" 'length' 2>/dev/null || echo 0)
if [ "$displays" -lt 2 ]; then
  # still notify to reassign spaces to remaining display on unplug
  trigger_top space_windows_refresh
  trigger_top layout_change
  trigger_top display_change
  exit 0
fi

"$yabai" -m query --spaces 2>/dev/null | "$jq" -r '.[] | "\(.index) \(.display)"' 2>/dev/null |
while read -r idx cur; do
  target=2
  [ "$idx" -eq 1 ] && target=1
  [ "$cur" != "$target" ] && "$yabai" -m space "$idx" --display "$target" 2>/dev/null || true
done

# force sketchybar to update after space moves on display change/hotplug
trigger_top space_windows_refresh
trigger_top layout_change
trigger_top display_change
