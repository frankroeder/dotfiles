#!/usr/bin/env bash

case "$(yabai -m query --windows --window | jq '."is-floating"')" in
    true)
    sketchybar -m --set yabai_float label=""
    ;;
    false)
    sketchybar -m --set yabai_float label=""
    ;;
esac
