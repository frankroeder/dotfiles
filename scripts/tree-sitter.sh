#!/usr/bin/env bash

LATEST_VERSION=$(curl -sL https://api.github.com/repos/tree-sitter/tree-sitter/releases/latest | jq -r '.name')
DEST="$HOME/bin/tree-sitter"

curl -sL "https://github.com/tree-sitter/tree-sitter/releases/download/$LATEST_VERSION/tree-sitter-linux-x64.gz" | gunzip > $DEST
chmod +x $DEST
