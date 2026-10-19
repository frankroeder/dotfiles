#!/usr/bin/env bash
# Install packages for Asahi Linux (Fedora)

set -euo pipefail

FLATHUB_REPO_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"
FLATPAK_EXPORT_DIR="${HOME}/.local/share/flatpak/exports/share"

sudo dnf copr enable -y scottames/ghostty
sudo dnf copr enable -y lionheartp/Hyprland

# quickshell stays Fedora's (provides qs): lionheartp/Hyprland ships its own, newer build. Excluded on the
# repo itself, else every update check (bar chip, Upgrade all, zsh `update`) offers it.
sudo dnf config-manager setopt 'copr:copr.fedorainfracloud.org:lionheartp:Hyprland.excludepkgs=quickshell*'
sudo dnf upgrade -y --refresh

# No comments inside this argv — bash treats `#` as ending the command.
sudo dnf install -y \
  adw-gtk3-theme \
  brightnessctl \
  blueman \
  btop \
  cargo \
  cliphist \
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
  gnome-keyring \
  gnome-keyring-pam \
  hyprpicker \
  gwenview \
  hypridle \
  hyprland \
  hyprlock \
  hyprpaper \
  hyprsunset \
  git \
  htop \
  hunspell-de \
  ImageMagick \
  keychain \
  jq \
  libnotify \
  make \
  mpv \
  neovim \
  NetworkManager-wifi \
  NetworkManager-tui \
  nm-connection-editor \
  openconnect \
  NetworkManager-openconnect \
  okular \
  papirus-icon-theme \
  pavucontrol \
  pipewire \
  pipewire-pulseaudio \
  pipewire-utils \
  pipewire-alsa \
  pulseaudio-utils \
  playerctl \
  speakersafetyd \
  restic \
  ripgrep \
  slurp \
  swappy \
  tesseract \
  tesseract-langpack-eng \
  zbar \
  qrencode \
  texlive-scheme-full \
  terminus-fonts-console \
  thunderbird \
  Thunar \
  tumbler \
  tmux \
  tree \
  upower \
  uv \
  v4l-utils \
  wf-recorder \
  wireplumber \
  wl-clipboard \
  xdg-utils \
  xdg-desktop-portal \
  xdg-desktop-portal-gtk \
  xdg-desktop-portal-hyprland \
  xdg-native-messaging-proxy \
  desktop-file-utils \
  qt6-qtwayland \
  zsh

sudo dnf install -y --from-repo=fedora,updates quickshell

# After the install: hyprland Recommends kitty (Ghostty is the terminal here).
sudo dnf remove -y kitty kitty-terminfo || true

flatpak remote-add --user --if-not-exists flathub "$FLATHUB_REPO_URL"

FLATPAK_APPS=(
  org.mozilla.firefox
  com.protonvpn.www
  org.zotero.Zotero
  net.ankiweb.Anki
  com.nextcloud.desktopclient.nextcloud
  org.signal.Signal
  org.libreoffice.LibreOffice
)

# Locale extensions (hunspell dictionaries, langpacks) in English and German, not just the system locale.
flatpak config --user --set languages "en;de"
flatpak install --user -y flathub "${FLATPAK_APPS[@]}"
flatpak update --user -y

# Signal defaults to a plaintext key store; use gnome-keyring (secrets component) instead.
flatpak override --user --env=SIGNAL_PASSWORD_STORE=gnome-libsecret org.signal.Signal
# CaelestiaFox reaches asahi-firefox-theme on the host through xdg-native-messaging-proxy.
flatpak override --user --talk-name=org.freedesktop.NativeMessagingProxy org.mozilla.firefox

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q "${FLATPAK_EXPORT_DIR}/icons/hicolor" >/dev/null 2>&1 || true
fi

systemctl --user import-environment XDG_DATA_DIRS || true

sudo systemctl enable --now cups cups-browsed

# Skip: power-profiles-daemon (no Apple Silicon backend), seahorse/gdm,
# NetworkManager-vpnc, NetworkManager-openconnect-gnome (nmcli --ask is enough).

# The only enabler of speakersafetyd: without it the kernel keeps the speakers locked.
sudo systemctl enable --now speakersafetyd || {
  echo "speakersafetyd did not start (speakers stay locked): systemctl status speakersafetyd" >&2
  exit 1
}

systemctl --user daemon-reload
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service
