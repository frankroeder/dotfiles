#!/usr/bin/env bash
LATEST_VERSION=$(curl https://github.com/tree-sitter/tree-sitter/releases/latest | cut -d'v' -f2 | cut -d'"' -f1 )
DEST="$HOME/bin/tree-sitter"

curl -sL "https://github.com/tree-sitter/tree-sitter/releases/download/v$LATEST_VERSION/tree-sitter-linux-x64.gz" | gunzip > $DEST
chmod +x $DEST
