#!/usr/bin/env bash

# pre-release
sudo add-apt-repository ppa:neovim-ppa/unstable -y
sudo apt update -y && sudo apt upgrade -y
PKGS="
  git
  bash
  cmake
  curl
  ffmpeg
  htop
  imagemagick
  iputils-ping
  jq
  lsof
  make
  man
  neovim
  python3-dev
  python3-pip
  python3-venv
  silversearcher-ag
  sudo
  tmux
  tree
  wget
  zsh
"

sudo apt install $PKGS -y
