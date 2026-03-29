#!/usr/bin/env bash
# Bootstrap script for Asahi Linux (Fedora) with Plasma as the base desktop
# Dank Linux is installed afterwards and used with Hyprland as the WM overlay.

set -euo pipefail

DOTFILES="$HOME/.dotfiles"

# Install system packages first so the Plasma base and CLI tooling are ready.
bash "$DOTFILES/asahi/dnf.sh"

# Install Dank Linux after the base Asahi/Linux packages are in place.
curl -fsSL https://install.danklinux.com | sh

# Install Claude Code
curl -fsSL https://claude.ai/install.sh | bash

# Apply Plasma-first dotfiles plus the DankLinux overlay config.
cd "$DOTFILES"
make asahi
