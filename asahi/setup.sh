#!/usr/bin/env bash
# Bootstrap script for Asahi Linux (Fedora) with Plasma as the base desktop
# Dank Linux is installed afterwards and used with Hyprland as the WM overlay.

set -euo pipefail

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
INSTALL_DANKLINUX="${INSTALL_DANKLINUX:-1}"
INSTALL_CLAUDE_CODE="${INSTALL_CLAUDE_CODE:-0}"

if [[ ! -d "$DOTFILES" ]]; then
  echo "Dotfiles directory not found: $DOTFILES" >&2
  exit 1
fi

# Install system packages first so the Plasma base and CLI tooling are ready.
bash "$DOTFILES/asahi/dnf.sh"

if [[ "$INSTALL_DANKLINUX" == "1" ]]; then
  # Install Dank Linux after the base Asahi/Linux packages are in place.
  curl -fsSL https://install.danklinux.com | sh
fi

if [[ "$INSTALL_CLAUDE_CODE" == "1" ]]; then
  curl -fsSL https://claude.ai/install.sh | bash
fi

# Apply Plasma-first dotfiles plus the DankLinux overlay config.
make -C "$DOTFILES" asahi
