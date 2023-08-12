#!/usr/bin/env bash
###################### CENTER ITEMS ###################

# music
sketchybar -m --add event song_update com.apple.Music.playerInfo \
              --add item music_info center \
              --set music_info script="$PLUGIN_DIR/music.sh" \
              --subscribe music_info song_update
