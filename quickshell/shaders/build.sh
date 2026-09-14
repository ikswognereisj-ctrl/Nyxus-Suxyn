#!/usr/bin/env bash
# Compile the swirl shaders to .qsb (Qt 6 requires precompiled shaders; there
# is no hot reload for these — tune in design/swirl-live.html first, then
# freeze the numbers here and rebuild).
#
#   bash shell/shaders/build.sh
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

QSB="${QSB:-/usr/lib/qt6/bin/qsb}"
[[ -x "$QSB" ]] || QSB="$(command -v qsb)" || { echo "qsb not found (pacman -S qt6-shadertools)" >&2; exit 1; }

# Every .frag in this directory, so adding a shader cannot mean forgetting to
# list it here — a stale .qsb next to an edited .frag is invisible until it is
# on screen.
#
# Crystal identity shaders are 330-only: they use textureLod / textureSize /
# fwidth, and the 300 es + raymarch combo is the deserialize trap that made
# gem_crystal / crystal_etch drop to an analytical cabochon in the first place.
for src in *.frag; do
  case "$src" in
    ocular_crystal.frag|crystal_etch.frag|gem_crystal.frag|hardened_magma.frag)
      "$QSB" --glsl "330" -o "${src}.qsb" "${src}"
      ;;
    *)
      "$QSB" --glsl "300 es,330" -o "${src}.qsb" "${src}"
      ;;
  esac
  echo "✓ ${src}.qsb"
done
