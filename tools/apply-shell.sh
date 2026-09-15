#!/usr/bin/env bash
# Copy this repo's Quickshell + Hyprland chrome onto the current user.
# Makes a timestamped backup. Does not touch greetd, initramfs, or /etc.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAMP=$(date +%Y%m%d-%H%M%S)
BAK="$HOME/.local/share/nyxus/shell-bak-$STAMP"
PREFLIGHT="$ROOT/tools/preflight-shell.sh"
TMP_QUICKSHELL="$HOME/.config/.nyxus-quickshell-$STAMP"
OLD_QUICKSHELL="$HOME/.config/.nyxus-quickshell-prev-$STAMP"

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
rm -rf "$TMP_QUICKSHELL" "$OLD_QUICKSHELL"
mkdir -p "$TMP_QUICKSHELL"
cp -a "$ROOT/quickshell/." "$TMP_QUICKSHELL/"
if [[ -d "$HOME/.config/quickshell" ]]; then
  mv "$HOME/.config/quickshell" "$OLD_QUICKSHELL"
fi
if ! mv "$TMP_QUICKSHELL" "$HOME/.config/quickshell"; then
  [[ -d "$OLD_QUICKSHELL" ]] && mv "$OLD_QUICKSHELL" "$HOME/.config/quickshell"
  printf 'failed to install quickshell config; restored previous copy\n' >&2
  exit 1
fi
rm -rf "$OLD_QUICKSHELL"
# hypr: copy conf, keep user's walls
mkdir -p "$HOME/.config/hypr"
find "$ROOT/hypr" -maxdepth 1 -type f -exec cp -a {} "$HOME/.config/hypr/" \;
if [[ -d "$ROOT/hypr/conf.d" ]]; then
  mkdir -p "$HOME/.config/hypr/conf.d"
  cp -a "$ROOT/hypr/conf.d/." "$HOME/.config/hypr/conf.d/"
fi

# ── THE TOOLING ───────────────────────────────────────────── TRK-4131 ──
# Audit 2026-09-14: 19 of the 20 programs the shell spawns were not in
# this repository. They lived only in the bin directories of the one
# machine the build was made on, so a fresh install produced a shell that
# started, themed correctly, and then did nothing when you clicked
# brightness, files, media, backup or the updater — and never moved the
# music visualizer, because nyxus-beat-engine was missing too.
#
# The shell is only half the product. These are the other half.
if [[ -d "$ROOT/bin" ]]; then
  mkdir -p "$HOME/.local/bin"
  install -m755 "$ROOT/bin"/* "$HOME/.local/bin/"
  printf '  bin   installed %s tools to ~/.local/bin\n' \
    "$(find "$ROOT/bin" -maxdepth 1 -type f | wc -l)"
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) printf '  warn  ~/.local/bin is not on your PATH — add it or the shell cannot find these\n' >&2 ;;
  esac
fi

# ── THE ICON THEME ────────────────────────────────────────── TRK-4132 ──
# The dock tile is a live shader, but the GLYPH etched into its face is
# an SVG pulled from the icon theme by Quickshell.iconPath(). 51 of those
# glyphs are Nyxus's own and exist in no other theme.
#
# NYXUS-Dark was referenced by gtk-3.0/settings.ini, gtk-4.0/settings.ini
# and the firstboot icon-cache hook — and shipped by none of them. It
# lived in /usr/share/icons on the build machine only. Everywhere else
# every Nyxus app fell back to application-x-executable.
#
# Installed per-user so no root is needed; ~/.local/share/icons wins over
# /usr/share/icons in the XDG lookup order.
if [[ -d "$ROOT/icons" ]]; then
  mkdir -p "$HOME/.local/share/icons"
  cp -a "$ROOT/icons/." "$HOME/.local/share/icons/"
  printf '  icon  installed icon theme(s) to ~/.local/share/icons\n'
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    for theme in "$HOME/.local/share/icons"/*/; do
      [[ -f "$theme/index.theme" ]] && \
        gtk-update-icon-cache -q -f -t "$theme" 2>/dev/null || true
    done
  fi
fi

printf 'done. reload:  qs ipc call nyxus reload\n'
printf 'undo:          copy %s back over ~/.config\n' "$BAK"
