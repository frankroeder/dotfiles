#!/usr/bin/env bash

sudo add-apt-repository ppa:neovim-ppa/stable -y
sudo apt-get update -y
PACKAGES='git curl python3 python3-pip silversearcher-ag neovim zsh tmux htop make jq'
for PKG in $PACKAGES
do
  echo "Installing $PKG ..."
  sudo apt-get install $PKG -y
done
