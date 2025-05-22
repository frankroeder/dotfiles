#!/usr/bin/env bash
set -euo pipefail

# --- Configuration ---
NVIM_TMP_DIR="/tmp/nvim_install"
DEFAULT_RELEASE="stable"

# --- Helper Functions ---
info() { printf "\033[1;34m[INFO]\033[0m %s\n" "$1"; }
success() { printf "\033[1;32m[SUCCESS]\033[0m %s\n" "$1"; }
error() { printf "\033[1;31m[ERROR]\033[0m %s\n" >&2; exit 1; }
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

  # Check for required tools
  check_command curl; check_command tar; check_command jq
  get_os_arch

  local install_prefix="$HOME/.local"
  mkdir -p "$install_prefix"

  # Fetch release assets from GitHub
  local api_url="https://api.github.com/repos/neovim/neovim/releases/tags/$tag"
  info "Fetching release data from: $api_url"
  local assets_json=$(curl -s "$api_url")
  [[ -z "$assets_json" ]] && error "Failed to fetch release assets."

  if echo "$assets_json" | grep -q '"message": "Not Found"'; then
    error "Tag '$tag' not found on GitHub releases."
  fi
  local asset_names=$(echo "$assets_json" | jq -r '.assets[].name')
  info "Available assets: $asset_names"

  # Define the expected asset based on OS and architecture
  local expected_asset
  if [[ "$OS" == "linux" && "$ARCH" == "x86_64" ]]; then
    expected_asset="nvim-linux-x86_64.tar.gz"
  elif [[ "$OS" == "linux" && "$ARCH" == "arm64" ]]; then
    expected_asset="nvim-linux-arm64.tar.gz"
  elif [[ "$OS" == "macos" && "$ARCH" == "x86_64" ]]; then
    expected_asset="nvim-macos-x86_64.tar.gz"
  elif [[ "$OS" == "macos" && "$ARCH" == "arm64" ]]; then
    expected_asset="nvim-macos-arm64.tar.gz"
  else
    error "Unsupported OS/ARCH: $OS $ARCH"
  fi

  # Select the asset with the exact name
  local asset_name=$(echo "$assets_json" | jq -r ".assets[].name | select(. == \"$expected_asset\")")
  if [[ -z "$asset_name" ]]; then
    error "Asset '$expected_asset' not found for $OS $ARCH in release '$tag'. Available assets: $asset_names"
  fi
  info "Selected asset: $asset_name"

  # Download URLs
  local download_url="https://github.com/neovim/neovim/releases/download/$tag/$asset_name"
  local checksum_file="shasum.txt"
  local checksum_url="https://github.com/neovim/neovim/releases/download/$tag/$checksum_file"

  # Prepare temporary directory
  mkdir -p "$NVIM_TMP_DIR"
  cd "$NVIM_TMP_DIR"

  # Download the asset and checksum file
  info "Downloading $asset_name from $download_url"
  curl -fSLO "$download_url" || error "Failed to download $download_url"
  info "Downloading checksum file from $checksum_url"
  curl -fSLO "$checksum_url" || error "Failed to download $checksum_url"

  # Verify checksum
  info "Verifying checksum"
  local expected_checksum=$(grep "$asset_name" "$checksum_file" | awk '{print $1}')
  [[ -z "$expected_checksum" ]] && error "Checksum not found for $asset_name"
  local computed_checksum=$(sha256sum "$asset_name" | awk '{print $1}')
  [[ "$computed_checksum" != "$expected_checksum" ]] && error "Checksum mismatch"

  # Extract and install
  info "Extracting $asset_name to $install_prefix"
  tar xzf "$asset_name" -C "$install_prefix" --strip-components=1 || error "Failed to extract $asset_name"

  # Verify installation
  local nvim_path="$install_prefix/bin/nvim"
  if [[ -x "$nvim_path" ]]; then
    success "Neovim installed to $nvim_path"
    info "Version: $($nvim_path --version | head -n 1)"
  else
    error "Neovim executable not found at $nvim_path"
  fi

  # Clean up
  info "Cleaning up"
  rm -f "$asset_name" "$checksum_file"
}

install_from_source() {
  local target="${1:-stable}"
  info "Starting Neovim source installation (target: $target)..."

  check_command git; check_command make; check_command cmake
  get_os_arch

  local src_dir="$NVIM_TMP_DIR/neovim_src"
  mkdir -p "$src_dir"
  cd "$src_dir"

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
