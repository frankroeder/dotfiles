#!/bin/bash

APP_STATE=$(pgrep -x Music)
if [[ ! $APP_STATE ]]; then
  sketchybar -m --set music_info drawing=off
  exit 0
fi

PLAYER_STATE=$(osascript -e "tell application \"Music\" to set playerState to (get player state) as text")
if [[ $PLAYER_STATE == "stopped" ]]; then
  sketchybar -m --set music_info drawing=on
  exit 0
fi

TITLE=$(osascript -e 'tell application "Music" to get name of current track')
ARTIST=$(osascript -e 'tell application "Music" to get artist of current track')
ALBUM=$(osascript -e 'tell application "Music" to get album of current track')
LOVED=$(osascript -l JavaScript -e "Application('Music').currentTrack().loved()")

if [[ $LOVED == "true" ]]; then
  ICON=
else
  [[ $PLAYER_STATE == "paused" ]] && ICON= || ICON=
fi

sketchybar -m --set music_info icon="$ICON" \
                        label=" ${TITLE}  ${ARTIST}" \
                        drawing=on
