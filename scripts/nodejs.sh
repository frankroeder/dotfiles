#!/usr/bin/env bash

LATEST_VERSION=$(curl -sL https://api.github.com/repos/nodejs/node/releases/latest | jq -r '.tag_name')
DISTRO=linux-x64
RELEASE="node-$LATEST_VERSION-$DISTRO"
PKG="$RELEASE.tar.xz"
TARGET_DIR="$HOME/tmp/"

curl -L https://nodejs.org/dist/$LATEST_VERSION/$PKG > "$TARGET_DIR/$PKG";
cd $TARGET_DIR;
tar -xJf "$PKG";
mkdir -p "$HOME/.local/nodejs"
ln -sfv "$TARGET_DIR$RELEASE/bin" "$HOME/.local/nodejs/";
rm -rfv  "$PKG";
