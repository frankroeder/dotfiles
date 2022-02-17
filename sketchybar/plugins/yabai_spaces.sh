#!/usr/bin/env bash

STATIC_NAMES=("" "I" "II" "III" "IV" "V" "VI" "VII" "VIII" "IX" "X" "XI" "XII" "XIII" "XIV" "XV") #0 to 15
args=()
QUERY="$(yabai -m query --spaces | jq -r '.[] | [.index, ."windows[0]", .label, .display, ."is-visible"] | @sh')"
NAMES=""
COUNT=0

# Read the current spaces from the yabai query
while read -r index windows yabai_name display is_visible
do
  COUNT=$((COUNT+1))
  NAME="$(echo "${yabai_name}" | tr -d "'")"
  if [ "${window}" = "null" ]; then
    label="${STATIC_NAMES[${index}]}"
  else
    label="${STATIC_NAMES[${index}]}°"
  fi
  if [ "$NAME" = "" ] || [ "$NAME" = " " ]; then
    NAME="${index}"
  fi

  NAMES="$NAMES $NAME"
  args+=(--clone "$NAME" space_template after \
         --set "$NAME" label="${label}" \
                       label.highlight_color="0xff6ed6e6" \
                       associated_display=${display} \
                       label.highlight=${is_visible} \
                       drawing=on)
done <<< "$QUERY"

# Reorder them and stick them onto sketchybar
args+=(--reorder $NAMES)
sketchybar -m ${args[@]} &> /dev/null

# Get the current space count
CURRENT_SPACE_COUNT=$(sketchybar -m --query bar | jq '.items | map(try tonumber catch 0) | max')

# If our current space count is greater than the count found by the yabai query,
# go through and remove the destroyed spaces
while [ $CURRENT_SPACE_COUNT -gt $COUNT ]
do
  sketchybar -m --remove "${CURRENT_SPACE_COUNT}"
  CURRENT_SPACE_COUNT=$((CURRENT_SPACE_COUNT-1))
done
