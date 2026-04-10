#!/usr/bin/env bash
# Install packages for Asahi Linux (Fedora)

set -euo pipefail

LIBREWOLF_REPO_URL="https://repo.librewolf.net/librewolf.repo"

sudo dnf upgrade -y

if ! sudo dnf repolist --all | grep -q '^librewolf'; then
  sudo dnf config-manager addrepo --add-or-replace --overwrite --from-repofile="$LIBREWOLF_REPO_URL"
fi

sudo dnf makecache --refresh

if ! sudo dnf list --available librewolf >/dev/null 2>&1; then
  echo "LibreWolf package is not available from configured DNF repositories." >&2
  exit 1
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
  chromium \
  nextcloud-client \
  okular \
  ripgrep \
  tmux \
  tree \
  latexmk \
  texlive-scheme-full \
  uv \
  wget \
  fastfetch \
  zsh
