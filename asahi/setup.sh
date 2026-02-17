#!/usr/bin/env bash
# Bootstrap script for Asahi Linux (Fedora) with Dank Linux
# Dank Linux provides: hyprland, DMS (Dank Material Shell), and desktop components

set -euo pipefail

DOTFILES="$HOME/.dotfiles"

# Install Dank Linux (Hyprland + DMS desktop)
curl -fsSL https://install.danklinux.com | sh

# Install system packages (must run before make targets that need zsh, neovim, uv)
bash "$DOTFILES/asahi/dnf.sh"

# Install fzf
if ! command -v fzf >/dev/null 2>&1; then
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf && ~/.fzf/install --bin
fi

# Install Claude Code
curl -fsSL https://claude.ai/install.sh | bash

# Apply dotfiles
cd "$DOTFILES"
make asahi
