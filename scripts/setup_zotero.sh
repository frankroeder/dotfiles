#!/usr/bin/env bash
set -euo pipefail

DOWNLOAD_URL="https://www.zotero.org/download/client/dl?channel=release&platform=linux-arm64"
INSTALL_DIR="/opt/zotero"
APP_NAME="zotero"
DESKTOP_FILE_NAME="zotero.desktop"
LOCAL_APPS_DIR="${HOME}/.local/share/applications"
TMP_DIR="$(mktemp -d)"
ARCH="$(uname -m)"
OS_ID=""

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

log() {
  printf '[zotero-setup] %s\n' "$*"
}

fail() {
  printf '[zotero-setup] ERROR: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

check_platform() {
  if [[ "$ARCH" != "aarch64" && "$ARCH" != "arm64" ]]; then
    fail "This script is for ARM64 (Asahi Linux). Detected architecture: $ARCH"
  fi

  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    OS_ID="${ID:-}"
    if [[ "$OS_ID" != "fedora" ]]; then
      log "Warning: Detected distro '$OS_ID'. Continuing anyway."
    fi
  fi
}

pick_downloader() {
  if command -v curl >/dev/null 2>&1; then
    echo "curl"
  elif command -v wget >/dev/null 2>&1; then
    echo "wget"
  else
    fail "Need curl or wget to download Zotero"
  fi
}

download_zotero() {
  local out_file="$TMP_DIR/zotero.tar.xz"
  local dl
  dl="$(pick_downloader)"

  log "Downloading Zotero ARM64 release..."
  if [[ "$dl" == "curl" ]]; then
    curl -fL "$DOWNLOAD_URL" -o "$out_file"
  else
    wget -O "$out_file" "$DOWNLOAD_URL"
  fi

  [[ -s "$out_file" ]] || fail "Downloaded file is empty"
  echo "$out_file"
}

extract_zotero() {
  local archive="$1"
  local extract_dir="$TMP_DIR/extracted"

  mkdir -p "$extract_dir"
  log "Extracting archive..."
  tar -xf "$archive" -C "$extract_dir"

  local top_dir
  top_dir="$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d -print -quit)"
  [[ -n "$top_dir" ]] || fail "Could not find extracted Zotero directory"
  echo "$top_dir"
}

install_zotero() {
  local source_dir="$1"

  require_cmd sudo
  log "Installing to $INSTALL_DIR (requires sudo)..."
  sudo mkdir -p /opt
  sudo rm -rf "$INSTALL_DIR"
  sudo cp -a "$source_dir" "$INSTALL_DIR"
  sudo chown -R root:root "$INSTALL_DIR"

  [[ -x "$INSTALL_DIR/zotero" ]] || fail "Installed Zotero binary not found at $INSTALL_DIR/zotero"
}

fix_desktop_entry() {
  local desktop_path="$INSTALL_DIR/$DESKTOP_FILE_NAME"

  [[ -f "$desktop_path" ]] || fail "Desktop file not found: $desktop_path"

  log "Fixing desktop entry paths..."
  sudo sed -i "s|^Icon=.*|Icon=$INSTALL_DIR/icons/icon128.png|" "$desktop_path"
  sudo sed -i "s|^Exec=.*|Exec=$INSTALL_DIR/zotero -url %U|" "$desktop_path"

  mkdir -p "$LOCAL_APPS_DIR"
  ln -sfn "$desktop_path" "$LOCAL_APPS_DIR/$DESKTOP_FILE_NAME"

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$LOCAL_APPS_DIR" || true
  fi
}

main() {
  require_cmd tar
  require_cmd find
  check_platform

  local archive
  local extracted
  archive="$(download_zotero)"
  extracted="$(extract_zotero "$archive")"

  install_zotero "$extracted"
  fix_desktop_entry

  log "Done. Zotero is installed at $INSTALL_DIR"
  log "Launch from app grid or run: $INSTALL_DIR/zotero"
}

main "$@"
