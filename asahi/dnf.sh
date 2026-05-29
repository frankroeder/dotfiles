#!/usr/bin/env bash
# Install packages for Asahi Linux (Fedora)

set -euo pipefail

LIBREWOLF_REPO_URL="https://repo.librewolf.net/librewolf.repo"
FLATHUB_REPO_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"
FLATPAK_EXPORT_DIR="${HOME}/.local/share/flatpak/exports/share"
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FEDORA_VERSION="$(rpm -E %fedora)"

sudo dnf upgrade -y
sudo dnf remove -y kitty kitty-terminfo || true

if ! sudo dnf repolist --all | grep -q '^librewolf'; then
  sudo dnf config-manager addrepo --add-or-replace --overwrite --from-repofile="$LIBREWOLF_REPO_URL"
fi

sudo dnf copr enable -y scottames/ghostty
sudo dnf copr enable errornointernet/quickshell

sudo dnf makecache --refresh

# if ! sudo dnf list --available librewolf >/dev/null 2>&1; then
#   echo "LibreWolf package is not available from configured DNF repositories." >&2
#   exit 1
# fi

sudo dnf install -y \
  adw-gtk3-theme \
  brightnessctl \
  blueman \
  cargo \
  cascadia-mono-nf-fonts \
  chromium \
  cmake \
  curl \
  fd-find \
  fastfetch \
  ffmpeg \
  flatpak \
  fuzzel \
  ghostty \
  google-noto-color-emoji-fonts \
  grim \
  gwenview \
  git \
  htop \
  hypridle \
  hyprland \
  hyprlock \
  hyprpaper \
  ImageMagick \
  keychain \
  jq \
  libnotify \
  librewolf \
  make \
  mpv \
  neovim \
  nextcloud-client \
  NetworkManager-wifi \
  NetworkManager-tui \
  nm-connection-editor \
  okular \
  papirus-icon-theme \
  pipewire \
  pipewire-pulseaudio \
  pipewire-utils \
  playerctl \
  ripgrep \
  slurp \
  texlive-scheme-full \
  terminus-fonts-console \
  thunderbird \
  tree \
  uv \
  quickshell-git \
  wireplumber \
  wl-clipboard \
  xdg-utils \
  xdg-desktop-portal \
  xdg-desktop-portal-gtk \
  xdg-desktop-portal-hyprland \
  zsh

flatpak remote-add --user --if-not-exists flathub "$FLATHUB_REPO_URL"

FLATPAK_APPS=(
  com.protonvpn.www
  org.zotero.Zotero
  net.ankiweb.Anki
)

flatpak install --user -y flathub "${FLATPAK_APPS[@]}"

bash "${DOTFILES_DIR}/scripts/fix_linux_desktop_icons.sh"

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q "${FLATPAK_EXPORT_DIR}/icons/hicolor" >/dev/null 2>&1 || true
fi

systemctl --user import-environment XDG_DATA_DIRS || true

# Optional Asahi extras (not in minimal dnf to avoid bloat):
# - hyprdynamicmonitors (Go tool for dynamic monitor profiles/lid/hotplug on Mac hw): go install github.com/fiffeek/hyprdynamicmonitors@latest
# - matugen (theming, per DankMaterialShell patterns): dnf or cargo install; integrate with QS for wallpaper-driven colors if chosen

systemctl --user daemon-reload
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service
