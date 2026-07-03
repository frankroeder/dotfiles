#!/bin/bash
# Dump current Apple Music album art to /tmp and print its path ("" if none)
osascript <<'EOF'
try
  tell application "Music"
    if not (exists current track) then return ""
    set srcBytes to raw data of artwork 1 of current track
  end tell
  set coverPath to "/tmp/sketchybar_music_cover.jpg"
  set outFile to open for access (POSIX file coverPath) with write permission
  set eof outFile to 0
  write srcBytes to outFile
  close access outFile
  return coverPath
on error
  return ""
end try
EOF
