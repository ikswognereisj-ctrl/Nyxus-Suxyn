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
for src in *.frag; do
  "$QSB" --glsl "300 es,330" -o "${src}.qsb" "${src}"
  echo "✓ ${src}.qsb"
done
