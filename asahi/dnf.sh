#!/usr/bin/env bash
# Install packages for Asahi Linux (Fedora)

set -euo pipefail

LIBREWOLF_REPO_URL="https://repo.librewolf.net/librewolf.repo"
FLATHUB_REPO_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"
FLATPAK_EXPORT_DIR="${HOME}/.local/share/flatpak/exports/share"
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FEDORA_VERSION="$(rpm -E %fedora)"

# solopasha/hyprland has no fedora-44-aarch64 metadata (404 on --refresh).
# Hyprland wiki and this machine's packages use the lionheartp fork instead.
if sudo dnf repolist --all 2>/dev/null | grep -q 'solopasha:hyprland'; then
  sudo dnf copr remove -y solopasha/hyprland
fi
sudo dnf copr enable -y scottames/ghostty
sudo dnf copr enable -y lionheartp/Hyprland
sudo dnf copr enable -y errornointernet/quickshell

sudo dnf upgrade -y
sudo dnf remove -y kitty kitty-terminfo || true

if ! sudo dnf repolist --all | grep -q '^librewolf'; then
  if [ "$FEDORA_VERSION" -ge 41 ]; then
    # dnf5 (Fedora 41+)
    sudo dnf config-manager addrepo --from-repofile="$LIBREWOLF_REPO_URL"
  else
    # dnf4
    sudo dnf config-manager --add-repo "$LIBREWOLF_REPO_URL"
  fi
fi

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
  cava \
  chromium \
  cmake \
  cups \
  cups-browsed \
  curl \
  fd-find \
  fastfetch \
  ffmpeg \
  flatpak \
  ghostty \
  google-noto-color-emoji-fonts \
  grim \
  # Secret Service for Hyprland (kwallet disabled). Not GNOME Shell; SSH stays with keychain.
  gnome-keyring \
  gwenview \
  hypridle \
  hyprland \
  hyprlock \
  hyprpaper \
  hyprsunset \
  git \
  htop \
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
  openconnect \
  okular \
  papirus-icon-theme \
  pipewire \
  pipewire-pulseaudio \
  pipewire-utils \
  pipewire-alsa \
  playerctl \
  speakersafetyd \
  ripgrep \
  slurp \
  texlive-scheme-full \
  terminus-fonts-console \
  thunderbird \
  Thunar \
  tumbler \
  tree \
  uv \
  quickshell-git \
  wireplumber \
  wl-clipboard \
  xdg-utils \
  xdg-desktop-portal \
  xdg-desktop-portal-gtk \
  xdg-desktop-portal-hyprland \
  desktop-file-utils \
  qt6-qtwayland \
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

sudo systemctl enable --now cups cups-browsed

# Optional Asahi extras (not in minimal dnf to avoid bloat):
# - hyprdynamicmonitors (Go tool for dynamic monitor profiles/lid/hotplug on Mac hw): go install github.com/fiffeek/hyprdynamicmonitors@latest
# - matugen (theming, per DankMaterialShell patterns): dnf or cargo install; integrate with QS for wallpaper-driven colors if chosen
# - power-profiles-daemon: Omarchy wraps powerprofilesctl with no Apple Silicon
#   backend. This machine is apple-cpufreq/schedutil; PPD does not drive it.
# - seahorse / gnome-shell / gdm: not needed. gnome-keyring is Secret Service
#   only (Hyprland autostart, no ssh component; keychain owns SSH).
# - NetworkManager-openconnect / NetworkManager-vpnc: not used. TUHH VPN
#   is `scripts/tuhhvpn.sh` → `sudo openconnect --useragent=AnyConnect any1.rz.tuhh.de`.

sudo systemctl enable --now speakersafetyd >/dev/null 2>&1 || true

systemctl --user daemon-reload
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service
