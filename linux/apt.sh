#!/usr/bin/env bash

# pre-release
sudo add-apt-repository ppa:neovim-ppa/unstable -y
sudo apt-get update -y
PACKAGES='git curl wget iputils-ping python3 python3-pip python3-venv silversearcher-ag neovim zsh tmux htop make jq tree cmake'
for PKG in $PACKAGES
do
  echo "Installing $PKG ..."
  sudo apt-get install $PKG -y
done
