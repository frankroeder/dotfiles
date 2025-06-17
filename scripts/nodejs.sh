#!/usr/bin/env bash

LATEST_VERSION=$(curl -sL https://api.github.com/repos/nodejs/node/releases/latest | jq -r '.tag_name')

if [ "$OSTYPE" = "Darwin" ]; then
  DISTRO="darwin"
else
  DISTRO=linux
fi
if [[ $(uname -m) == 'arm64' ]]; then
  DISTRO+="-arm64"
else
  DISTRO+="-x64"
fi
RELEASE="node-$LATEST_VERSION-$DISTRO"
echo "RELEASE: $RELEASE"
PKG="$RELEASE.tar.xz"
TARGET_DIR="$HOME/tmp/"

curl -L https://nodejs.org/dist/$LATEST_VERSION/$PKG > "$TARGET_DIR/$PKG";
cd $TARGET_DIR;
tar -xJf "$PKG";
mkdir -p "$HOME/.local/nodejs"
ln -sfv "$TARGET_DIR$RELEASE/bin" "$HOME/.local/nodejs/";
rm -rfv  "$PKG";
