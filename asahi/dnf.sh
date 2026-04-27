#!/usr/bin/env bash
# Install packages for Asahi Linux (Fedora)

set -euo pipefail

LIBREWOLF_REPO_URL="https://repo.librewolf.net/librewolf.repo"

sudo dnf upgrade -y
sudo dnf remove -y kitty kitty-terminfo || true

if ! sudo dnf repolist --all | grep -q '^librewolf'; then
  sudo dnf config-manager addrepo --add-or-replace --overwrite --from-repofile="$LIBREWOLF_REPO_URL"
fi

sudo dnf makecache --refresh

if ! sudo dnf list --available librewolf >/dev/null 2>&1; then
  echo "LibreWolf package is not available from configured DNF repositories." >&2
  exit 1
fi

sudo dnf install -y \
  cargo \
  cmake \
  curl \
  ffmpeg \
  gwenview \
  git \
  ImageMagick \
  keychain \
  jq \
  librewolf \
  lsof \
  make \
  neovim \
  NetworkManager-wifi \
  chromium \
  nextcloud-client \
  mpv \
  okular \
  ripgrep \
  texlive-scheme-full \
  thunderbird \
  tree \
  uv \
  wl-clipboard \
  wget \
  fastfetch \
  xclip \
  xdg-utils \
  zsh
