#!/usr/bin/env bash
# Install packages for Asahi Linux (Fedora)

set -euo pipefail

sudo dnf upgrade -y

sudo dnf install -y \
  cargo \
  cmake \
  ffmpeg \
  htop \
  imagemagick \
  jq \
  lsof \
  neovim \
  nextcloud-client \
  python3-devel \
  python3-pip \
  ripgrep \
  tmux \
  tree \
  latexmk \
  texlive-scheme-medium \
  texlive-luahbtex \
  uv \
  wget \
  zathura \
  zathura-pdf-poppler \
  zsh
