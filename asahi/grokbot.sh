#!/usr/bin/env bash
# Grok Bot from Cursor's update API.
# The feed is an AppImage. Running it needs libfuse.so.2, which this host does
# not have, so the payload is extracted and launched directly.
set -euo pipefail

if [ "$(uname -m)" != "aarch64" ]; then
  echo "Skipping Grok Bot (linux/arm64 only; this host is $(uname -m))"
  exit 0
fi

api="https://api2.cursor.sh/updates/api/update/linux-arm64/sand/0.0.0/stable"
json="$(curl -fsSL -A "Mozilla/5.0" "$api")" || { echo "Grok Bot: update API request failed ($api)" >&2; exit 1; }
mapfile -t meta < <(python3 -c '
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
' <<<"$json")
[ "${#meta[@]}" -eq 3 ] || { echo "Grok Bot: could not parse update metadata" >&2; exit 1; }
ver="${meta[0]}"
url="${meta[1]}"
sha="${meta[2]}"

install_appimage() {
  if [ -z "$sha" ]; then
    echo "Grok Bot AppImage metadata has no sha256" >&2
    exit 1
  fi
  data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  root="${data_home}/grok-bot"
  app_dir="${root}/app"
  bin="${app_dir}/grok-bot"
  mkdir -p "$root" "$HOME/.local/bin" "${data_home}/applications"

  if [ -x "$bin" ] && [ "$(cat "${root}/version" 2>/dev/null || true)" = "$ver" ]; then
    echo "Grok Bot ${ver} already installed"
  else
    # Only the extracted app is kept; the AppImage lives in a temp dir.
    work="$(mktemp -d)"
    trap 'rm -rf "$work"' EXIT
    echo "Downloading Grok Bot ${ver}"
    curl -fL -A "Mozilla/5.0" -o "${work}/Grok_Bot.AppImage" "$url"
    printf '%s  %s\n' "$sha" "${work}/Grok_Bot.AppImage" | sha256sum -c --status
    chmod 755 "${work}/Grok_Bot.AppImage"
    ( cd "$work" && ./Grok_Bot.AppImage --appimage-extract >/dev/null )
    rm -rf "$app_dir"
    mv "$work/squashfs-root" "$app_dir"
    printf '%s\n' "$ver" > "${root}/version"
    echo "Grok Bot ${ver} ready at ${bin}"
  fi
  rm -f "${root}/Grok_Bot.AppImage"

  # No X-GrokBot-Integrator: 0.58 deletes that desktop file when it was not
  # started as an AppImage and a system grok-bot.desktop still exists.
  ln -sfn "$bin" "$HOME/.local/bin/grok-bot"
  # Icon=grok-bot: the AppImage's hicolor pngs (the old RPM shipped them in /usr/share).
  for icon in "${app_dir}"/usr/share/icons/hicolor/*/apps/grok-bot.png; do
    [ -f "$icon" ] || continue
    dest="${data_home}/icons/hicolor/${icon#"${app_dir}"/usr/share/icons/hicolor/}"
    mkdir -p "$(dirname "$dest")"
    ln -sfn "$icon" "$dest"
  done
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
  *.AppImage) install_appimage ;;
  *)
    echo "Unknown Grok Bot package: ${url}" >&2
    exit 1
    ;;
esac
