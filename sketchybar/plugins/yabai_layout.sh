#!/usr/bin/env bash

display=$(yabai -m query --spaces --space | jq '.display')
case "$(yabai -m query --spaces --display | jq -r 'map(select(."has-focus" == true))[-1].type')" in
    'float')
    sketchybar -m --set yabai_layout icon="" label="" associated_display=${display}
    ;;
    'stack')
      # ignore invisible windows
      stack_total=$(yabai -m query --windows --space | jq -r 'map(select(."is-visible" == true)) | length')
      stack_position=$(yabai -m query --windows --space | jq -r 'map(select(."has-focus" == true))[-1]."stack-index"')
      STACK_INDICATOR="[${stack_position}/${stack_total}]"
      sketchybar -m --set yabai_layout icon="﯅" label="$STACK_INDICATOR" associated_display=${display}
    ;;
    'bsp')
    sketchybar -m --set yabai_layout icon="" label="" associated_display=${display}
    ;;
esac
