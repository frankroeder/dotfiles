#!/usr/bin/env bash

# set codesigning certificate name here (default: yabai-cert)
export YABAI_CERT=

# stop yabai
yabai --stop-service

# reinstall yabai
brew reinstall koekeishiya/formulae/yabai
codesign -fs "${YABAI_CERT:-yabai-cert}" "$(brew --prefix yabai)/bin/yabai"

# finally, start yabai
yabai --start-service

echo "Now configure the scripting addition"
