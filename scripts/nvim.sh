#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
NVIM_TMP_DIR="/tmp/nvim_install"
DEFAULT_RELEASE="stable"

# --- Helper Functions ---
info() { printf "\033[1;34m[INFO]\033[0m %s\n" "$1"; }
success() { printf "\033[1;32m[SUCCESS]\033[0m %s\n" "$1"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$1"; }
error() { printf "\033[1;31m[ERROR]\033[0m %s\n" "$1" >&2; exit 1; }
check_command() { command -v "$1" >/dev/null 2>&1 || error "Required command '$1' not installed."; }

# --- OS and Architecture Detection ---
get_os_arch() {
  case "$(uname -s)" in
    Linux) OS="linux" ;;
    Darwin) OS="macos" ;;
    *) error "Unsupported OS" ;;
  esac
  case "$(uname -m)" in
    x86_64) ARCH="x86_64" ;;
    arm64|aarch64) ARCH="arm64" ;;
    *) error "Unsupported architecture" ;;
  esac
  info "Detected OS: $OS, Arch: $ARCH"
}

# --- Installation Function ---
install_binary() {
  local tag="${1:-$DEFAULT_RELEASE}"
  info "Starting Neovim binary installation (tag: $tag)..."

  check_command curl
  check_command tar
  get_os_arch

  local install_prefix="$HOME/.local"
  mkdir -p "$install_prefix"

  local expected_asset
  case "$OS-$ARCH" in
    linux-x86_64) expected_asset="nvim-linux-x86_64.tar.gz" ;;
    linux-arm64)  expected_asset="nvim-linux-arm64.tar.gz" ;;
    macos-x86_64) expected_asset="nvim-macos-x86_64.tar.gz" ;;
    macos-arm64)  expected_asset="nvim-macos-arm64.tar.gz" ;;
    *) error "Unsupported OS/ARCH: $OS $ARCH" ;;
  esac

  local assets_json=""
  if command -v gh >/dev/null 2>&1; then
    info "Fetching release data via gh (tag: $tag)"
    assets_json="$(gh api "repos/neovim/neovim/releases/tags/$tag" 2>/dev/null || true)"
  else
    local api_url="https://api.github.com/repos/neovim/neovim/releases/tags/$tag"
    info "Fetching release data from: $api_url"
    assets_json="$(curl -fsSL -A "frankroeder-dotfiles" "$api_url" 2>/dev/null || true)"
  fi

  local expected_checksum=""
  if [[ -z "$assets_json" ]]; then
    warn "GitHub API returned empty response; falling back to direct download"
  elif command -v jq >/dev/null 2>&1; then
    local msg assets_type
    msg="$(printf '%s' "$assets_json" | jq -r '.message // empty' 2>/dev/null || true)"
    assets_type="$(printf '%s' "$assets_json" | jq -r '.assets | type' 2>/dev/null || true)"
    if [[ -n "$msg" ]]; then
      warn "GitHub API error: $msg; falling back to direct download"
    elif [[ "$assets_type" != "array" ]]; then
      warn "GitHub API missing assets; falling back to direct download"
    else
      expected_checksum="$(printf '%s' "$assets_json" | jq -r --arg n "$expected_asset" \
        '.assets[] | select(.name == $n) | .digest // empty' 2>/dev/null | sed 's/^sha256://')"
    fi
  else
    if printf '%s' "$assets_json" | grep -q '"message"'; then
      warn "GitHub API returned a message; falling back to direct download"
    elif printf '%s' "$assets_json" | grep -Eq '"assets"[[:space:]]*:[[:space:]]*null'; then
      warn "GitHub API missing assets; falling back to direct download"
    elif ! printf '%s' "$assets_json" | grep -q '"assets"'; then
      warn "GitHub API missing assets; falling back to direct download"
    fi
  fi

  local download_url="https://github.com/neovim/neovim/releases/download/$tag/$expected_asset"

  mkdir -p "$NVIM_TMP_DIR"
  cd "$NVIM_TMP_DIR" || error "Failed to enter directory $NVIM_TMP_DIR"

  info "Downloading $expected_asset from $download_url"
  curl -fSL -A "frankroeder-dotfiles" -o "$expected_asset" "$download_url" \
    || error "Failed to download $download_url"

  if ! gzip -t "$expected_asset" 2>/dev/null; then
    error "Downloaded file is not a valid gzip archive (possible HTML 404): $expected_asset"
  fi

  if [[ -n "$expected_checksum" ]]; then
    info "Verifying checksum"
    local computed_checksum=""
    if command -v sha256sum >/dev/null 2>&1; then
      computed_checksum="$(sha256sum "$expected_asset" | awk '{print $1}')"
    elif command -v shasum >/dev/null 2>&1; then
      computed_checksum="$(shasum -a 256 "$expected_asset" | awk '{print $1}')"
    else
      warn "Neither sha256sum nor shasum found; skipping checksum verification"
    fi
    if [[ -n "$computed_checksum" && "$computed_checksum" != "$expected_checksum" ]]; then
      error "Checksum mismatch for $expected_asset"
    fi
  else
    warn "No checksum metadata found for $expected_asset; skipping checksum verification."
  fi

  info "Extracting $expected_asset to $install_prefix"
  tar xzf "$expected_asset" -C "$install_prefix" --strip-components=1 \
    || error "Failed to extract $expected_asset"

  local nvim_path="$install_prefix/bin/nvim"
  if [[ -x "$nvim_path" ]]; then
    success "Neovim installed to $nvim_path"
    info "Version: $($nvim_path --version | head -n 1)"
  else
    error "Neovim executable not found at $nvim_path"
  fi

  info "Cleaning up"
  rm -f "$expected_asset"
}

install_from_source() {
  local target="${1:-stable}"
  info "Starting Neovim source installation (target: $target)..."

  check_command git; check_command make; check_command cmake
  get_os_arch

  local src_dir="$NVIM_TMP_DIR/neovim_src"
  mkdir -p "$src_dir"
  cd "$src_dir" || error "Failed to enter directory $src_dir"

  if [[ -d ".git" ]]; then
    git fetch --all
  else
    git clone https://github.com/neovim/neovim.git .
  fi

  git checkout "$target"

  local jobs=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 1)
  make -j"$jobs" CMAKE_BUILD_TYPE=Release CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$HOME/.local"
  make install

  local nvim_path="$HOME/.local/bin/nvim"
  if [[ -x "$nvim_path" ]]; then
    success "Neovim installed to $nvim_path"
    info "Version: $($nvim_path --version | head -n 1)"
  else
    error "Neovim executable not found at $nvim_path"
  fi
}

main() {
  local action="${1:-binary}"
  local tag="${2:-stable}"
  case "$action" in
    binary) install_binary "$tag" ;;
    source) install_from_source "$tag" ;;
    *) error "Invalid action: $action" ;;
  esac
}

main "$@"
