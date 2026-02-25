#!/usr/bin/env bash
asset_name="sketchybar-app-font.ttf"
dest="$HOME/Library/Fonts/$asset_name"
curl -fsSL "https://github.com/kvndrsslr/sketchybar-app-font/releases/download/latest/$asset_name" -o "$dest"
