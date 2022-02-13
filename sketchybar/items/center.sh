#!/usr/bin/env bash
###################### CENTER ITEMS ###################

# music
sketchybar -m --add event song_update com.apple.Music.playerInfo           \
              --add center music_info center                               \
              --set music_info script="$PLUGIN_DIR/music.sh"               \
              --subscribe music_info song_update
# window title
sketchybar -m --add item title center \
              --set title script="$PLUGIN_DIR/window_title.sh" \
              --subscribe title window_focus front_app_switched space_change title_change
