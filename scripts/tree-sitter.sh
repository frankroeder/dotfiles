#!/usr/bin/env bash
set -euo pipefail

DEST="$HOME/bin/tree-sitter"
mkdir -p "$(dirname "$DEST")"

OS="$(uname -s)"
ARCH="$(uname -m)"

if [ "$OS" = "Darwin" ]; then
  if command -v brew >/dev/null 2>&1 && brew list tree-sitter >/dev/null 2>&1; then
    echo "tree-sitter already installed via Homebrew; skipping"
    exit 0
  fi
  if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
    PLATFORM="macos-arm64"
  else
    PLATFORM="macos-x64"
  fi
elif [ "$OS" = "Linux" ]; then
  if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    PLATFORM="linux-arm64"
  else
    PLATFORM="linux-x64"
  fi
else
  echo "Unsupported OS: $OS" >&2
  exit 1
fi

tag=""
if command -v gh >/dev/null 2>&1; then
  tag="$(gh api repos/tree-sitter/tree-sitter/releases/latest --jq .tag_name 2>/dev/null || true)"
fi
if [ -z "${tag:-}" ] || [ "$tag" = "null" ]; then
  if command -v jq >/dev/null 2>&1; then
    tag="$(curl -fsSL -A frankroeder-dotfiles https://api.github.com/repos/tree-sitter/tree-sitter/releases/latest 2>/dev/null | jq -r '.tag_name' || true)"
  fi
fi
if [ -n "${tag:-}" ] && [ "$tag" != "null" ]; then
  url="https://github.com/tree-sitter/tree-sitter/releases/download/${tag}/tree-sitter-${PLATFORM}.gz"
else
  echo "Could not resolve tree-sitter tag; using latest/download fallback" >&2
  url="https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-${PLATFORM}.gz"
fi
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

http_code="$(curl -fSL -A frankroeder-dotfiles -o "$tmp" -w "%{http_code}" "$url" || true)"
if [ "$http_code" != "200" ]; then
  echo "Failed to download $url (HTTP ${http_code:-000})" >&2
  exit 1
fi

if ! gzip -t "$tmp" 2>/dev/null; then
  echo "Downloaded file is not a valid gzip archive (possible HTML 404): $url" >&2
  exit 1
fi

gzip -dc "$tmp" > "$DEST"
chmod +x "$DEST"
