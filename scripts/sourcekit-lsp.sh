#!/usr/bin/env bash

ping -c 1 www.google.com
if [ $? -eq 0 ]; then
  SRC_DIR="$HOME/tmp/sourcekit-lsp"
  if [[ -d $SRC_DIR ]]; then
    cd $SRC_DIR
    git pull
  else
    git clone https://github.com/apple/sourcekit-lsp.git $SRC_DIR
    cd $SRC_DIR
  fi
  swift build && mv .build/debug/sourcekit-lsp /usr/local/bin
fi
