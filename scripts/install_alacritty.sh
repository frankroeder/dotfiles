#!/usr/bin/env bash

ping -c 1 www.google.com
if [ $? -eq 0 ]; then
  git clone https://github.com/alacritty/alacritty.git ~/tmp/alacritty
  cd ~/tmp/alacritty
  # install manual page
  gzip -c extra/alacritty.man | sudo tee /usr/local/share/man/man1/alacritty.1.gz > /dev/null
  # install shell completions
  cp extra/completions/_alacritty ${ZDOTDIR:-$HOME}/.zsh/completion
fi
