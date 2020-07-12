#!/usr/bin/env bash

sudo apt-get update -y
PACKAGES='git curl python3 python3-pip silversearcher-ag neovim zsh tmux htop make jq'
for PKG in $_PACKAGES
do
  INSTALLED=$(dpkg -l $PKG)
  if [ "$INSTALLED" == "" ]; then
    echo "Installing $PKG ..."
    sudo apt install $PKG -y
  fi
done
