#!/usr/bin/env bash

ping -c 1 www.google.com
if [ $? -eq 0 ]; then
  SRC_DIR="$HOME/tmp/alacritty"
  if [[ -d $SRC_DIR ]]; then
    cd $SRC_DIR
    git pull
  else
    git clone https://github.com/alacritty/alacritty.git $SRC_DIR
    cd $SRC_DIR
  fi
  # install manual page
  gzip -c extra/alacritty.man | sudo tee /usr/local/share/man/man1/alacritty.1.gz > /dev/null
  # install shell completions
  cp extra/completions/_alacritty ${ZDOTDIR:-$HOME}/.zsh/completion
fi
