#!/usr/bin/env bash

install_default() {
  # pre-release
  sudo add-apt-repository ppa:neovim-ppa/unstable -y;
  sudo apt update -y && sudo apt upgrade -y;
  local PKGS="
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
  sudo apt install $PKGS -y;
}

install_desktop() {
  sudo apt update -y && sudo apt upgrade -y;
  local DESKTOP_PKGS="
    xclip
    chromium-browser
    python3-tk
    sox
    portaudio19-dev
    pavucontrol
    network-manager-l2tp
    network-manager-l2tp-gnome
  "
  sudo apt install $DESKTOP_PKGS -y;
}
main() {
  case $1 in
    "default") echo "Installing default applications" && install_default ;;
    "desktop") echo "Installing desktop applications" && install_desktop ;;
    *) echo "No valid option found" ;;
  esac
}
main "$@";
