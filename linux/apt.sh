#!/usr/bin/env bash

apt_update() {
  sudo apt update -y && sudo apt upgrade -y;
}

install_default() {
  apt_update;
  local PKGS="
    bash
    cmake
    curl
    ffmpeg
    git
    htop
    imagemagick
    iputils-ping
    jq
    lsof
    make
    man
    python3-dev
    python3-pip
    python3-venv
    silversearcher-ag
    sqlite
    sudo
    tmux
    tree
    wget
    zsh
  "
  sudo apt install $PKGS -y;
}

install_desktop() {
  apt_update;
  local DESKTOP_PKGS="
    firefox
    network-manager-l2tp
    network-manager-l2tp-gnome
    pavucontrol
    portaudio19-dev
    python3-tk
    sox
    vlc
    xclip
  "
  sudo apt install $DESKTOP_PKGS -y;
}
main() {
  case $1 in
    "default")
      echo "Installing default applications";
      install_default;;
    "desktop")
      echo "Installing desktop applications";
      install_desktop;;
    *)
      echo "No valid option found";;
  esac
}
main "$@";
