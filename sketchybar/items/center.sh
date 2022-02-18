#!/usr/bin/env bash
###################### CENTER ITEMS ###################

# music
sketchybar -m --add event song_update com.apple.Music.playerInfo           \
              --add center music_info center                               \
              --set music_info script="$PLUGIN_DIR/music.sh"               \
              --subscribe music_info song_update

# title of frontmost app
sketchybar --add item system_label center                                       \
           --set system_label script="sketchybar --set \$NAME label=\"\$INFO\"" \
           --subscribe system_label front_app_switched
