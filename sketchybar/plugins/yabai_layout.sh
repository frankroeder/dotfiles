#!/usr/bin/env bash

display=$(yabai -m query --spaces --space | jq '.display')

case "$(yabai -m query --spaces --display | jq -r 'map(select(."has-focus" == true))[-1].type')" in
    'float')
    sketchybar -m --set yabai_layout label="" associated_display=${display}
    ;;
    'stack')
    sketchybar -m --set yabai_layout label="" associated_display=${display}
    ;;
    'bsp')
    sketchybar -m --set yabai_layout label="BSP" associated_display=${display}
    ;;
esac
