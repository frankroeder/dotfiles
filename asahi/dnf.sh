#!/usr/bin/env bash
# Install packages for Asahi Linux (Fedora)

set -euo pipefail

sudo dnf upgrade -y

if ! sudo dnf repolist --all | grep -q '^librewolf'; then
  sudo dnf config-manager addrepo --from-repofile=https://repo.librewolf.net/librewolf.repo
fi

sudo dnf install -y \
  biber \
  cargo \
  cmake \
  ffmpeg \
  htop \
  imagemagick \
  jq \
  ksshaskpass \
  librewolf \
  lsof \
  neovim \
  nextcloud-client \
  okular \
  python3-devel \
  python3-pip \
  ripgrep \
  tmux \
  tree \
  latexmk \
  texlive \
  texlive-scheme-medium \
  texlive-luahbtex \
  uv \
  wget \
  zathura \
  zathura-pdf-poppler \
  zsh
