#!/usr/bin/env bash
# Compile every *.frag in this directory into a Qt6 *.qsb bundle.
# Targets GLSL 300es, 330, plus HLSL and Metal for portability. GLSL 100es
# (gles2) is intentionally omitted — the retro shaders use bitwise ops on
# ints, which 100es doesn't support, and modern Linux desktops with
# Quickshell all have GL 3+ available.
set -euo pipefail

QSB="${QSB:-/usr/lib/qt6/bin/qsb}"
if ! [ -x "$QSB" ]; then
    QSB="$(command -v qsb)" || {
        echo "qsb not found. Install qt6-shadertools." >&2
        exit 1
    }
fi

cd "$(dirname "$0")"
for f in *.frag; do
    [ -e "$f" ] || continue
    echo "qsb $f -> $f.qsb"
    "$QSB" --glsl 300es,330 --hlsl 50 --msl 12 -o "$f.qsb" "$f"
done
