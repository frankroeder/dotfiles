#!/usr/bin/env bash

LATEST_VERSION=$(curl https://github.com/nodejs/node/releases/latest | cut -d'v' -f2 | cut -d'"' -f1)
DISTRO=linux-x64
RELEASE="node-v$LATEST_VERSION-$DISTRO"
PKG="$RELEASE.tar.xz"
TARGET_DIR="$HOME/tmp/"

curl -L https://nodejs.org/dist/v$LATEST_VERSION/$PKG > "$TARGET_DIR/$PKG";
cd $TARGET_DIR;
tar -xJf "$PKG";
mkdir -p "$HOME/.local/nodejs"
ln -sfv "$TARGET_DIR$RELEASE/bin" "$HOME/.local/nodejs/";
rm -rfv  "$PKG";
