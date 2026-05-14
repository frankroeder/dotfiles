#!/usr/bin/env bash

set -euo pipefail

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

printf '[zram0]\nzram-size = 16384\n' > "$tmp"

sudo install -Dm0644 "$tmp" /etc/systemd/zram-generator.conf
sudo systemctl daemon-reload

if systemctl --quiet is-active systemd-zram-setup@zram0.service; then
  sudo systemctl restart systemd-zram-setup@zram0.service
else
  echo "zram config installed. Reboot to apply."
fi

swapon --show
