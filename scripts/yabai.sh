#!/bin/zsh

# scripting-addition;
# function to update sudoers file
function suyabai () {
    SHA256=$(shasum -a 256 $(which yabai) | awk "{print \$1;}")
    if [ -f "/private/etc/sudoers.d/yabai" ]; then
        sudo sed -i '' -e 's/sha256:[[:alnum:]]*/sha256:'${SHA256}'/' /private/etc/sudoers.d/yabai
        echo "sudoers > yabai > sha256 hash update complete"
    else
        echo "sudoers file does not exist yet. Please create one before running this script."
    fi
}

# check & unpin yabai from brew
if brew list --pinned | grep -q yabai; then
    brew unpin yabai
fi

# set cert & stop yabai services
export YABAI_CERT=yabai-cert
echo "Stopping yabai.."
yabai --stop-service

# reinstall yabai & codesign
echo "Updating yabai.."
brew reinstall koekeishiya/formulae/yabai
codesign -fs "${YABAI_CERT:-yabai-cert}" "$(brew --prefix yabai)/bin/yabai"

# update sudoers file & start yabai
suyabai
echo "Starting yabai.."
yabai --start-service

# pin yabai back to brew
brew pin yabai
if brew list --pinned | grep -q yabai; then
    echo "Yabai pinned to brew"
fi

# Success message
sleep 1
YABAI_V=$(yabai --version)
echo "Your running $YABAI_V"
echo "Yabai update completed successfully."
