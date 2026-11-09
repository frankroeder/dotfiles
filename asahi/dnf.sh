#!/usr/bin/env bash
# Install packages for Apple Silicon Fedora (Aurora Fedora Remix; Fedora Asahi Remix works too)

set -euo pipefail

FLATHUB_REPO_URL="https://dl.flathub.org/repo/flathub.flatpakrepo"
FLATPAK_EXPORT_DIR="${HOME}/.local/share/flatpak/exports/share"

# copr + config-manager live in dnf5-plugins (a Minimal image may lack it).
sudo dnf install -y dnf5-plugins
sudo dnf copr enable -y scottames/ghostty
sudo dnf copr enable -y lionheartp/Hyprland

# quickshell stays Fedora's (provides qs): lionheartp/Hyprland ships its own, newer build. Excluded on the
# repo itself, else every update check (bar chip, Upgrade all, zsh `update`) offers it.
sudo dnf config-manager setopt 'copr:copr.fedorainfracloud.org:lionheartp:Hyprland.excludepkgs=quickshell*'
sudo dnf upgrade -y --refresh

# No comments inside this argv — bash treats `#` as ending the command.
# /usr/bin/node, not nodejs: Fedora 45's nodejs conflicts with an installed nodejs22-bin (same alternative).
# ffmpeg-free: Fedora's ffmpeg package (nothing in Fedora 45 provides plain "ffmpeg").
sudo dnf install -y \
  adw-gtk3-theme \
  brightnessctl \
  blueman \
  bolt \
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
  ffmpeg-free \
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
  lua \
  make \
  mpv \
  neovim \
  /usr/bin/node \
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
  uwsm \
  inotify-tools \
  v4l-utils \
  wf-recorder \
  widevine-installer \
  pipewire-v4l2 \
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
# H.264 decode (wallpaper intros, mpv): ffmpeg-free has it only through Cisco's openh264 (repo fedora-cisco-openh264,
# on by default); a minimal image may carry the noopenh264 stub instead (then no intro plays).
sudo dnf install -y --allowerasing openh264

sudo dnf install -y --from-repo=fedora,updates quickshell

# Aurora: Flathub's GL.default has no aurora_dri.so, so Flatpak apps need Aurora's GL extension (nothing requires it).
if grep -q '^VARIANT_ID=aurora' /etc/os-release; then
  sudo dnf install -y aurora-flatpak-gl
fi

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
  org.telegram.desktop
  org.localsend.localsend_app
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

# Skip: power-profiles-daemon / tuned-ppd (Aurora runs tuned "balanced" = schedutil; profiles gain nothing), seahorse/gdm,
# NetworkManager-vpnc, NetworkManager-openconnect-gnome (nmcli --ask is enough).

# The only enabler of speakersafetyd: without it the kernel keeps the speakers locked.
sudo systemctl enable --now speakersafetyd || {
  echo "speakersafetyd did not start (speakers stay locked): systemctl status speakersafetyd" >&2
  exit 1
}

systemctl --user daemon-reload
systemctl --user enable --now pipewire.socket pipewire-pulse.socket wireplumber.service
