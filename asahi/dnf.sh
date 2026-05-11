#!/usr/bin/env bash
# Install packages for Asahi Linux (Fedora)

set -euo pipefail

LIBREWOLF_REPO_URL="https://repo.librewolf.net/librewolf.repo"
FEDORA_VERSION="$(rpm -E %fedora)"
ARCHITECTURE="$(uname -m)"
SWAYOSD_COPR_CHROOT="fedora-${FEDORA_VERSION}-${ARCHITECTURE}"

if [ "$FEDORA_VERSION" -ge 44 ]; then
  SWAYOSD_COPR_CHROOT="fedora-43-${ARCHITECTURE}"
fi

sudo dnf upgrade -y
sudo dnf remove -y kitty kitty-terminfo wofi || true
sudo dnf remove -y dms dms-cli dms-greeter DankMaterialShell dgop || true

if ! sudo dnf repolist --all | grep -q '^librewolf'; then
  sudo dnf config-manager addrepo --add-or-replace --overwrite --from-repofile="$LIBREWOLF_REPO_URL"
fi

sudo dnf copr enable -y erikreider/swayosd "$SWAYOSD_COPR_CHROOT"
sudo dnf copr enable -y errornointernet/walker

sudo dnf makecache --refresh

# if ! sudo dnf list --available librewolf >/dev/null 2>&1; then
#   echo "LibreWolf package is not available from configured DNF repositories." >&2
#   exit 1
# fi

sudo dnf install -y \
  brightnessctl \
  blueman \
  bluez-tools \
  cargo \
  cmake \
  cascadia-code-nf-fonts \
  cascadia-mono-nf-fonts \
  curl \
  elephant \
  elephant-calc \
  elephant-desktopapplications \
  elephant-files \
  elephant-providerlist \
  elephant-websearch \
  fd-find \
  ffmpeg \
  google-noto-color-emoji-fonts \
  google-noto-sans-symbols-2-fonts \
  google-noto-sans-symbols-fonts \
  grim \
  gwenview \
  git \
  hypridle \
  hyprland \
  hyprlock \
  hyprpaper \
  ImageMagick \
  keychain \
  jq \
  libnotify \
  librewolf \
  lsof \
  make \
  mako \
  neovim \
  NetworkManager-wifi \
  NetworkManager-tui \
  nm-connection-editor \
  chromium \
  nextcloud-client \
  mpv \
  okular \
  papirus-icon-theme \
  playerctl \
  power-profiles-daemon \
  ripgrep \
  slurp \
  swayosd \
  texlive-scheme-full \
  terminus-fonts-console \
  thunderbird \
  tree \
  uv \
  waybar \
  walker \
  wireplumber \
  wl-clipboard \
  wget \
  fastfetch \
  xclip \
  xdg-utils \
  xdg-desktop-portal-hyprland \
  zsh
