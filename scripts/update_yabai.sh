#!/usr/bin/env bash

# set codesigning certificate name here (default: yabai-cert)
export YABAI_CERT="yabai-cert"

# stop yabai
brew services stop koekeishiya/formulae/yabai

# reinstall yabai
brew reinstall koekeishiya/formulae/yabai
codesign -fs "${YABAI_CERT:-yabai-cert}" "$(brew --prefix yabai)/bin/yabai"

# finally, start yabai
brew services start koekeishiya/formulae/yabai
