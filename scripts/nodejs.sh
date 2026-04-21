#!/usr/bin/env bash

set -euo pipefail

LATEST_VERSION=$(curl -sL https://api.github.com/repos/nodejs/node/releases/latest | jq -r '.tag_name')

if [ "$OSTYPE" = "Darwin" ]; then
  DISTRO="darwin"
else
  DISTRO=linux
fi
if [[ $(uname -m) == 'arm64' || $(uname -m) == 'aarch64' ]]; then
  DISTRO+="-arm64"
else
  DISTRO+="-x64"
fi
RELEASE="node-$LATEST_VERSION-$DISTRO"
echo "RELEASE: $RELEASE"
PKG="$RELEASE.tar.xz"
TARGET_DIR="$HOME/tmp/"

mkdir -p "$TARGET_DIR" "$HOME/.local/nodejs"
curl -fL "https://nodejs.org/dist/$LATEST_VERSION/$PKG" -o "$TARGET_DIR/$PKG"
cd "$TARGET_DIR" || exit 1
tar -xJf "$PKG"
ln -sfv "$TARGET_DIR$RELEASE/bin" "$HOME/.local/nodejs/"
rm -fv "$PKG"
