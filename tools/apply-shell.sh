#!/usr/bin/env bash
# Copy this repo's Quickshell + Hyprland chrome onto the current user.
# Makes a timestamped backup. Does not touch greetd, initramfs, or /etc.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP=$(date +%Y%m%d-%H%M%S)
BAK="$HOME/.local/share/nyxus/shell-bak-$STAMP"
PREFLIGHT="$ROOT/tools/preflight-shell.sh"

snapshot_existing() {
  mkdir -p "$BAK"
  [[ -d "$HOME/.config/quickshell" ]] && cp -a "$HOME/.config/quickshell" "$BAK/quickshell"
  [[ -d "$HOME/.config/hypr" ]] && cp -a "$HOME/.config/hypr" "$BAK/hypr"
  cat > "$BAK/RESTORE.txt" <<EOF
Nyxus Suxyn rollback snapshot
Created: $(date -Is)

Restore with:
  mkdir -p "$HOME/.config/quickshell" "$HOME/.config/hypr"
  [ -d "$BAK/quickshell" ] && cp -a "$BAK/quickshell/." "$HOME/.config/quickshell/"
  [ -d "$BAK/hypr" ] && cp -a "$BAK/hypr/." "$HOME/.config/hypr/"
EOF
}

if [[ ${1:-} == "--preflight-only" ]]; then
  exec "$PREFLIGHT"
fi

printf 'Nyxus Suxyn · apply shell\n'
printf '  from  %s\n' "$ROOT"
printf '  bak   %s\n' "$BAK"

"$PREFLIGHT"
snapshot_existing
printf '  snap  rollback snapshot created\n'

mkdir -p "$HOME/.config"
rm -rf "$HOME/.config/quickshell"
mkdir -p "$HOME/.config/quickshell"
cp -a "$ROOT/quickshell/." "$HOME/.config/quickshell/"
# hypr: copy conf, keep user's walls
mkdir -p "$HOME/.config/hypr"
find "$ROOT/hypr" -maxdepth 1 -type f -exec cp -a {} "$HOME/.config/hypr/" \;
if [[ -d "$ROOT/hypr/conf.d" ]]; then
  mkdir -p "$HOME/.config/hypr/conf.d"
  cp -a "$ROOT/hypr/conf.d/." "$HOME/.config/hypr/conf.d/"
fi

printf 'done. reload:  qs ipc call nyxus reload\n'
printf 'undo:          copy %s back over ~/.config\n' "$BAK"
