#!/usr/bin/env bash
set -euo pipefail

if [ "$(uname -s)" = Darwin ] && command -v brew >/dev/null 2>&1 && brew list tree-sitter >/dev/null 2>&1; then
  echo "tree-sitter already installed via Homebrew; skipping"
  exit 0
fi

case "$(uname -s)-$(uname -m)" in
  Darwin-arm64|Darwin-aarch64) PLATFORM=macos-arm64 ;;
  Darwin-*)                    PLATFORM=macos-x64 ;;
  Linux-aarch64|Linux-arm64)   PLATFORM=linux-arm64 ;;
  Linux-*)                     PLATFORM=linux-x64 ;;
  *) echo "Unsupported OS/arch" >&2; exit 1 ;;
esac

DEST="$HOME/bin/tree-sitter"
mkdir -p "$(dirname "$DEST")"
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

url="https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-${PLATFORM}.gz"
curl -fSL -o "$tmp" "$url"
gzip -t "$tmp"
gzip -dc "$tmp" > "$DEST"
chmod +x "$DEST"
