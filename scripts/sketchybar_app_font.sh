#!/usr/bin/env bash
asset_name="sketchybar-app-font.ttf"
dest="$HOME/Library/Fonts/$asset_name"
curl -fsSL -o "$dest" "https://github.com/kvndrsslr/sketchybar-app-font/releases/latest/download/$asset_name"
