#!/usr/bin/env bash
# Copy this repo's Quickshell + Hyprland chrome onto the current user.
# Makes a timestamped backup. Does not touch greetd, initramfs, or /etc.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP=$(date +%Y%m%d-%H%M%S)
BAK="$HOME/.local/share/nyxus/shell-bak-$STAMP"

printf 'Nyxus Suxyn · apply shell\n'
printf '  from  %s\n' "$ROOT"
printf '  bak   %s\n' "$BAK"

mkdir -p "$BAK"
[[ -d "$HOME/.config/quickshell" ]] && cp -a "$HOME/.config/quickshell" "$BAK/quickshell"
[[ -d "$HOME/.config/hypr" ]] && cp -a "$HOME/.config/hypr" "$BAK/hypr"

mkdir -p "$HOME/.config"
cp -a "$ROOT/quickshell" "$HOME/.config/quickshell"
# hypr: copy conf, keep user's walls
mkdir -p "$HOME/.config/hypr"
find "$ROOT/hypr" -maxdepth 1 -type f -exec cp -a {} "$HOME/.config/hypr/" \;
if [[ -d "$ROOT/hypr/conf.d" ]]; then
  mkdir -p "$HOME/.config/hypr/conf.d"
  cp -a "$ROOT/hypr/conf.d/." "$HOME/.config/hypr/conf.d/"
fi

printf 'done. reload:  qs ipc call nyxus reload\n'
printf 'undo:          copy %s back over ~/.config\n' "$BAK"
