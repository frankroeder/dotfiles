#!/usr/bin/env bash
set -euo pipefail

apt_update() {
  sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get update -y && sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold upgrade
}

install_default() {
  apt_update;
  local PKGS="
    smem
    bash
    cmake
    curl
    ffmpeg
    git
    htop
    ifstat
    imagemagick
    iputils-ping
    jq
    lsof
    make
    man
    python3-dev
    python3-pip
    ripgrep
    sudo
    tmux
    tree
    wget
    zsh
  "
  sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get install -y $PKGS
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
    mpv
    wl-clipboard
    i3
  "
  sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get install -y $DESKTOP_PKGS
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
