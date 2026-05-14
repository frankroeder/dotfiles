#!/usr/bin/env bash

set -euo pipefail

src="${AQUAMARINE_SRC:-/tmp/aquamarine}"
ref="${AQUAMARINE_REF:-main}"

sudo dnf install -y \
  git cmake ninja-build gcc-c++ pkgconf-pkg-config \
  wayland-devel wayland-protocols-devel libdrm-devel libinput-devel libseat-devel \
  mesa-libEGL-devel mesa-libGL-devel mesa-libGLES-devel mesa-libgbm-devel \
  systemd-devel libdisplay-info-devel pixman-devel hwdata-devel \
  hyprutils-devel hyprwayland-scanner-devel

if [[ -d "$src/.git" ]]; then
  git -C "$src" fetch origin
else
  if [[ -e "$src" ]]; then
    echo "$src exists and is not a git checkout" >&2
    exit 1
  fi
  git clone https://github.com/hyprwm/aquamarine.git "$src"
fi

git -C "$src" checkout "$ref"
git -C "$src" pull --ff-only origin "$ref"

cmake -S "$src" -B "$src/build" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_INSTALL_LIBDIR=lib64

cmake --build "$src/build"
sudo cmake --install "$src/build"
sudo ldconfig

git -C "$src" rev-parse --short HEAD
readlink -f /usr/lib64/libaquamarine.so.10
