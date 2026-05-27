#!/usr/bin/env bash

set -euo pipefail

LOCAL_APPS_DIR="${HOME}/.local/share/applications"
LOCAL_ICONS_DIR="${HOME}/.local/share/icons"
FLATPAK_EXPORT_DIR="${HOME}/.local/share/flatpak/exports/share"

mkdir -p "$LOCAL_APPS_DIR"

fix_icon_name() {
  local desktop_file="$1"
  local icon_name="$2"
  local local_name="${3:-$desktop_file}"
  local desktop_path="/usr/share/applications/${desktop_file}"
  local local_path="${LOCAL_APPS_DIR}/${local_name}"

  [[ -f "$desktop_path" ]] || return 0

  sed "s|^Icon=${icon_name}\\.png$|Icon=${icon_name}|" "$desktop_path" > "$local_path"
}

fix_icon_name "librewolf.desktop" "librewolf"
# rm -f "${LOCAL_APPS_DIR}/thunderbird.desktop"

if [[ -d "${FLATPAK_EXPORT_DIR}/applications" ]]; then
  for desktop_file in "${FLATPAK_EXPORT_DIR}/applications"/*.desktop; do
    [[ -e "$desktop_file" ]] || continue
    ln -sf "$desktop_file" "${LOCAL_APPS_DIR}/$(basename "$desktop_file")"
  done
fi

if [[ -d "${FLATPAK_EXPORT_DIR}/icons" ]]; then
  if [[ -f "${FLATPAK_EXPORT_DIR}/icons/hicolor/index.theme" ]]; then
    mkdir -p "${LOCAL_ICONS_DIR}/hicolor"
    ln -sf "${FLATPAK_EXPORT_DIR}/icons/hicolor/index.theme" "${LOCAL_ICONS_DIR}/hicolor/index.theme"
  fi

  while IFS= read -r -d '' icon_file; do
    rel_path="${icon_file#${FLATPAK_EXPORT_DIR}/icons/}"
    local_path="${LOCAL_ICONS_DIR}/${rel_path}"
    mkdir -p "$(dirname "$local_path")"
    ln -sf "$icon_file" "$local_path"
  done < <(find -L "${FLATPAK_EXPORT_DIR}/icons" -type f \( -name '*.png' -o -name '*.svg' -o -name '*.xpm' \) -print0)
fi

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$LOCAL_APPS_DIR" >/dev/null 2>&1 || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q "${LOCAL_ICONS_DIR}/hicolor" >/dev/null 2>&1 || true
fi
