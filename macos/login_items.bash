declare -a arr=("/Applications/Raycast.app" "/Applications/LuLu.app")
for app in "${arr[@]}"; do
  if test -e "$app"; then
    osascript - "$app" << EOF > /dev/null
      on run { _app }
        tell app "System Events"
          make new login item with properties { hidden: true, path: _app }
        end tell
      end run
EOF
  fi
done
