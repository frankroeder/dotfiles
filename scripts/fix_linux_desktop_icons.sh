#!/usr/bin/env bash

set -euo pipefail

LOCAL_APPS_DIR="${HOME}/.local/share/applications"

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

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$LOCAL_APPS_DIR" >/dev/null 2>&1 || true
fi
