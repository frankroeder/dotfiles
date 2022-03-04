#!/usr/bin/env bash

current_properties=( $(yabai -m query --windows --space | jq -r 'map(select(."has-focus" == true))[-1] | [."is-sticky", ."is-topmost", ."is-floating", ."has-parent-zoom"] | @sh' )
)
is_sticky=${current_properties[0]}
is_topmost=${current_properties[1]}
is_floating=${current_properties[2]}
has_parent_zoom=${current_properties[3]}
LABEL=""
if $is_sticky ; then
  LABEL+="S"
fi
if $is_topmost ; then
  LABEL+="T"
fi
if $is_floating; then
  LABEL+="W"
fi
if $has_parent_zoom; then
  LABEL+="Z"
fi
sketchybar -m --set yabai_property label="${LABEL}" associated_display=${display} drawing=on
