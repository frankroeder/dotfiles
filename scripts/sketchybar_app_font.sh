#!/usr/bin/env bash

set -euo pipefail

REPO="kvndrsslr/sketchybar-app-font"
API="https://api.github.com/repos/$REPO/releases/latest"

echo "Fetching latest release info..."

TAG=$(curl -fsSL "$API" | jq -r .tag_name)
echo "Latest tag: $TAG"

curl -fsSL "$API" | jq -r '.assets[] | .browser_download_url' | while read -r url; do
  filename=$(basename "$url")
  case "$filename" in
    sketchybar-app-font.ttf)
      dest="$HOME/Library/Fonts/$filename"
      echo "Downloading font → $dest"
      curl -fsSL --create-dirs "$url" -o "$dest"
      ;;
    icon_map.lua)
      dest="${DOTFILES:-$HOME/.config}/sketchybar/helpers/app_icons.lua"
      mkdir -p "$(dirname "$dest")"
      echo "Downloading icon map → $dest"
      curl -fsSL "$url" -o "$dest"
      ;;
  esac
done

echo "Finished."
