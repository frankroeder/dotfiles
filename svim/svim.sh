#!/usr/bin/env sh

COLOR=0xff9dd274
if [ "$MODE" = "" ]; then
  COLOR=0xffff6578
fi

DRAW_CMD="off"
if [ "$CMDLINE" != "" ]; then
  DRAW_CMD="on"
fi

sketchybar --set svim.mode label="[$MODE]" \
  label.drawing=$(if [ "$MODE" = "" ]; then echo "off"; else echo "on"; fi) \
  icon.color=$COLOR popup.drawing=$DRAW_CMD \
  --set svim.cmdline label="$CMDLINE"
