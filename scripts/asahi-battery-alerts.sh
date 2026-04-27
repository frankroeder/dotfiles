#!/usr/bin/env bash

set -euo pipefail

dotfiles="${DOTFILES:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

mkdir -p "$HOME/.local/bin" "$HOME/.config/systemd/user"
ln -sfv "$dotfiles/asahi/bin/asahi-battery-alertd" "$HOME/.local/bin/asahi-battery-alertd"
ln -sfv "$dotfiles/asahi/systemd/user/asahi-battery-alertd.service" "$HOME/.config/systemd/user/asahi-battery-alertd.service"
chmod +x "$dotfiles/asahi/bin/asahi-battery-alertd"

systemctl --user daemon-reload
systemctl --user enable --now asahi-battery-alertd.service
