#!/usr/bin/env bash

DEST="$HOME/bin/nvim"
cd $HOME/tmp
curl -LO https://github.com/neovim/neovim/releases/download/nightly/nvim.appimage
chmod u+x nvim.appimage
# redirect stdout to /dev/null
./nvim.appimage --appimage-extract > /dev/null
ln -sfv $HOME/tmp/squashfs-root/AppRun $DEST
