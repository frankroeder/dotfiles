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

# Configure the user-local npm so that `npm ... --location=global` (or -g) writes
# to a writable prefix under ~/.local (bins land in ~/.local/bin which is in PATH).
# This prevents EACCES when a system npm is also present or on later update runs.
"$HOME/.local/nodejs/bin/npm" config set prefix "$HOME/.local" --location=user || true
echo "npm global prefix set to $HOME/.local for the local node"
