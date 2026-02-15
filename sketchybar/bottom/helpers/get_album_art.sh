#!/bin/bash

# Get album art from Music.app and save to /tmp
osascript <<EOF
tell application "Music"
    try
        if player state is not stopped then
            tell artwork 1 of current track
                if format is JPEG picture then
                    set imgFormat to ".jpg"
                else
                    set imgFormat to ".png"
                end if
            end tell
            set rawData to (get raw data of artwork 1 of current track)
            set imgPath to "/tmp/sketchybar_album_art" & imgFormat

            set fileRef to open for access POSIX file imgPath with write permission
            write rawData to fileRef starting at 0
            close access fileRef

            return imgPath
        end if
    on error
        return ""
    end try
end tell
EOF
