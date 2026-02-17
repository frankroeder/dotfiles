#!/usr/bin/env bash

LATEST_VERSION=$(curl -sL https://api.github.com/repos/tree-sitter/tree-sitter/releases/latest | jq -r '.name')
DEST="$HOME/bin/tree-sitter"

ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
  PLATFORM="linux-arm64"
else
  PLATFORM="linux-x64"
fi
curl -sL "https://github.com/tree-sitter/tree-sitter/releases/download/$LATEST_VERSION/tree-sitter-$PLATFORM.gz" | gunzip > "$DEST"
chmod +x $DEST
