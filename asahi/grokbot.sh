#!/usr/bin/env bash
# Grok Bot from Cursor's update API.
# The feed is an AppImage. Running it needs libfuse.so.2, which this host does
# not have, so the payload is extracted and launched directly. A binary under
# /opt/Grok Bot is the old package and stays stale.
set -euo pipefail

if [ "$(uname -m)" != "aarch64" ]; then
  echo "Skipping Grok Bot (linux/arm64 only; this host is $(uname -m))"
  exit 0
fi

api="https://api2.cursor.sh/updates/api/update/linux-arm64/sand/0.0.0/stable"
mapfile -t meta < <(curl -fsSL -A "Mozilla/5.0" "$api" | python3 -c '
import json, sys
data = json.load(sys.stdin)
ver = str(data.get("version") or data.get("productVersion") or "")
url = str(data.get("url") or "")
sha = str(data.get("sha256hash") or "")
if not ver or not url:
    sys.exit("could not parse grok-bot update metadata")
print(ver)
print(url)
print(sha)
')
ver="${meta[0]}"
url="${meta[1]}"
sha="${meta[2]}"

same_sha() {
  [ -n "$sha" ] && [ -f "$1" ] || return 1
  printf '%s  %s\n' "$sha" "$1" | sha256sum -c --status
}

install_rpm() {
  if [ "$(rpm -q --qf '%{VERSION}' grok-bot 2>/dev/null || true)" = "$ver" ]; then
    echo "Grok Bot ${ver} already installed"
    exit 0
  fi
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  echo "Installing Grok Bot ${ver}"
  curl -fL -A "Mozilla/5.0" -o "${tmp}/Grok_Bot_${ver}.rpm" "$url"
  if [ -n "$sha" ]; then
    printf '%s  %s\n' "$sha" "${tmp}/Grok_Bot_${ver}.rpm" | sha256sum -c --status
  fi
  sudo dnf install -y "${tmp}/Grok_Bot_${ver}.rpm"
  rpm -q grok-bot >/dev/null
}

install_appimage() {
  if [ -z "$sha" ]; then
    echo "Grok Bot AppImage metadata has no sha256" >&2
    exit 1
  fi
  data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  root="${data_home}/grok-bot"
  image="${root}/Grok_Bot.AppImage"
  app_dir="${root}/app"
  bin="${app_dir}/grok-bot"
  mkdir -p "$root" "$HOME/.local/bin" "${data_home}/applications"

  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  if ! same_sha "$image"; then
    echo "Downloading Grok Bot ${ver}"
    curl -fL -A "Mozilla/5.0" -o "${work}/Grok_Bot.AppImage" "$url"
    printf '%s  %s\n' "$sha" "${work}/Grok_Bot.AppImage" | sha256sum -c --status
    chmod 755 "${work}/Grok_Bot.AppImage"
    mv -f "${work}/Grok_Bot.AppImage" "$image"
  fi

  if [ -x "$bin" ] && [ "$(cat "${root}/version" 2>/dev/null || true)" = "$ver" ]; then
    echo "Grok Bot ${ver} already installed"
  else
    echo "Installing Grok Bot ${ver}"
    ( cd "$work" && "$image" --appimage-extract >/dev/null )
    rm -rf "$app_dir"
    mv "$work/squashfs-root" "$app_dir"
    printf '%s\n' "$ver" > "${root}/version"
    echo "Grok Bot ${ver} ready at ${bin}"
  fi

  # No X-GrokBot-Integrator: 0.58 deletes that desktop file when it was not
  # started as an AppImage and a system grok-bot.desktop still exists.
  rm -f "$HOME/.local/bin/grok-bot-appimage" "${root}/appimage"
  ln -sfn "$bin" "$HOME/.local/bin/grok-bot"
  printf '%s\n' \
    "[Desktop Entry]" \
    "Type=Application" \
    "Name=Grok Bot" \
    "Exec=${bin} %U" \
    "Icon=grok-bot" \
    "Terminal=false" \
    "StartupWMClass=grok-bot" \
    "Comment=Grok Bot desktop agent" \
    "MimeType=x-scheme-handler/grokbot;x-scheme-handler/sand;" \
    "Categories=Development;" \
    > "${data_home}/applications/grok-bot.desktop"
  chmod 644 "${data_home}/applications/grok-bot.desktop"
  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "${data_home}/applications" >/dev/null 2>&1 || true
  fi
  if command -v xdg-mime >/dev/null 2>&1; then
    xdg-mime default grok-bot.desktop x-scheme-handler/grokbot || true
    xdg-mime default grok-bot.desktop x-scheme-handler/sand || true
  fi
}

case "$url" in
  *.rpm) install_rpm ;;
  *.AppImage) install_appimage ;;
  *)
    echo "Unknown Grok Bot package: ${url}" >&2
    exit 1
    ;;
esac
