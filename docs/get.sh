#!/usr/bin/env bash
# Nyxus Suxyn — get the desktop from a terminal.
#   curl -fsSL https://ikswognereisj-ctrl.github.io/Nyxus-Suxyn/get.sh | bash
set -euo pipefail

ICE='\033[38;2;183;230;242m'
MAGMA='\033[38;2;255;120;71m'
DIM='\033[38;2;138;164;176m'
RST='\033[0m'
BOLD='\033[1m'

REPO="https://github.com/ikswognereisj-ctrl/Nyxus-Suxyn.git"
DEST="${NYXUS_GET_DIR:-$HOME/src/Nyxus-Suxyn}"
PAGE="https://ikswognereisj-ctrl.github.io/Nyxus-Suxyn/"
PREFLIGHT_REL="tools/preflight-shell.sh"

banner() {
  printf '\n'
  printf '%b' "$ICE"
  cat <<'EOF'
          ·  ·    ·      ·   ·
       ·     SUXYN     ·
          ·    ·    ·
EOF
  printf '%b\n' "$RST"
  printf '%b%s%b  %s\n' "$BOLD" "Nyxus Suxyn" "$RST" "2026.09.02"
  printf '%b%s%b\n\n' "$DIM" "Hyprland + Quickshell desktop. Starlight, Horizon bar, glass lock." "$RST"
}

need() {
  command -v "$1" >/dev/null 2>&1 && return 0
  printf '%bmissing %s%b — install git, then run this again.\n' "$MAGMA" "$1" "$RST"
  exit 1
}

banner
need git

printf '%b→%b  clone  %s\n' "$ICE" "$RST" "$REPO"
printf '%b→%b  into   %s\n\n' "$ICE" "$RST" "$DEST"

if [[ -d "$DEST/.git" ]]; then
  printf '%balready cloned.%b pulling…\n' "$DIM" "$RST"
  git -C "$DEST" pull --ff-only
else
  mkdir -p "$(dirname "$DEST")"
  git clone --depth 1 "$REPO" "$DEST"
fi

if [[ -x "$DEST/$PREFLIGHT_REL" ]]; then
  printf '\n%b→%b  preflight  %s/%s\n' "$ICE" "$RST" "$DEST" "$PREFLIGHT_REL"
  if ! "$DEST/$PREFLIGHT_REL"; then
    printf '%bpre-flight found blocking issues.%b fix those before running apply-shell.\n' "$MAGMA" "$RST"
  fi
fi

printf '\n%bdesktop is in%b  %s\n' "$ICE" "$RST" "$DEST"
printf '%b  quickshell/%b  bar, Start, lock, Settings\n' "$DIM" "$RST"
printf '%b  hypr/%b        compositor\n' "$DIM" "$RST"
printf '%b  installer/%b   Calamares branding for the next ISO bake\n' "$DIM" "$RST"

printf '\n%bThis is the shell, not a full OS ISO.%b\n' "$DIM" "$RST"
printf 'The live system is still the Nyxus Suxyn image. This repo is the chrome.\n'
printf 'To try it on this machine (backs up first):\n\n'
printf '  %b%s/tools/apply-shell.sh%b\n\n' "$MAGMA" "$DEST" "$RST"
printf 'Pre-flight only:\n\n'
printf '  %b%s/tools/apply-shell.sh --preflight-only%b\n\n' "$MAGMA" "$DEST" "$RST"
printf 'Page: %s\n\n' "$PAGE"
