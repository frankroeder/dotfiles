#!/usr/bin/env bash

DEST="$HOME/bin/nvim"
cd $HOME/tmp
RELEASE='nightly'
# RELEASE='v0.5.1'
URL="https://github.com/neovim/neovim/releases/download/$RELEASE/nvim.appimage"
curl -LO  $URL
CURRENT_CHECKSUM=$(openssl sha256 "nvim.appimage" | awk {'print $2'});
EXPECTED_CHECKSUM=$(curl -L "$URL.sha256sum" | awk {'print $1'});
if [[ $CURRENT_CHECKSUM == $EXPECTED_CHECKSUM ]]; then
  printf '%s matches %s\n' "$CURRENT_CHECKSUM" "$EXPECTED_CHECKSUM";
else
  printf '[!] %s is not matching: %s\n' "$CURRENT_CHECKSUM" "$EXPECTED_CHECKSUM";
  exit;
fi

chmod u+x nvim.appimage
# redirect stdout to /dev/null
./nvim.appimage --appimage-extract > /dev/null
ln -sfv $HOME/tmp/squashfs-root/AppRun $DEST
