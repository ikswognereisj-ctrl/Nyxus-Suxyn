#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
# nyxus-set-wallpaper.sh <name-or-path>   ·   rev 2026-08-19 (WIP-839)
#
# Short-name resolver for nyxus-dynamic-wallpaper.sh and
# nyxus-workspace-wallpaperd. Hands a REAL FILE to nyxus-set-wallpaper.
#
# Resolves, in order:
#   1. an existing regular file (absolute/relative path as-is)
#   2. suxyn-<name>.png/.jpg  — the 08-19 stills this build ships
#      then nyxus-bg-<name> / nyxus-<name> / <name> in
#      ~/.config/hypr/walls and /usr/share/backgrounds/nyxus
#   3. fuzzy: first regular file in those dirs whose name contains <name>
#
# Never execs an empty path. Never prints applied: (the setter does that
# only after a readable file). A directory that happens to be -r is not
# a wallpaper.
#
# © 2026 JOSEPH A. SIERENGOWSKI · NYX-J5W-2026-SIERENGOWSKI-LOCKED
# ════════════════════════════════════════════════════════════════════
set -u
export PATH="${HOME}/.local/bin:${PATH}"

NAME="${1:-}"
if [[ -z "${NAME}" || "${NAME}" =~ ^[[:space:]]*$ ]]; then
  echo "usage: nyxus-set-wallpaper.sh <name-or-path>" >&2
  echo "error: empty name — refusing to hand an empty path to the setter" >&2
  exit 2
fi

DIRS=("${HOME}/.config/hypr/walls" "/usr/share/backgrounds/nyxus")
[[ -n "${NYXUS_WALLS:-}" ]] && DIRS+=("${NYXUS_WALLS}")
DIRS+=("${HOME}/.local/share/backgrounds/nyxus")
TARGET=""

if [[ -f "${NAME}" && -r "${NAME}" ]]; then
  TARGET="${NAME}"
else
  for d in "${DIRS[@]}"; do
    for cand in \
        "suxyn-${NAME}.png" "suxyn-${NAME}.jpg" \
        "nyxus-bg-${NAME}.png" "nyxus-${NAME}.png" "${NAME}.png" \
        "nyxus-bg-${NAME}.jpg" "nyxus-${NAME}.jpg" "${NAME}.jpg"; do
      if [[ -f "${d}/${cand}" && -r "${d}/${cand}" ]]; then
        TARGET="${d}/${cand}"
        break 2
      fi
    done
  done
fi

if [[ -z "${TARGET}" ]]; then
  for d in "${DIRS[@]}"; do
    [[ -d "${d}" ]] || continue
    hit="$(find "${d}" -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' \) \
           -iname "*${NAME}*" 2>/dev/null | sort | head -1)"
    if [[ -n "${hit}" && -f "${hit}" && -r "${hit}" ]]; then
      TARGET="${hit}"
      break
    fi
  done
fi

if [[ -z "${TARGET}" || ! -f "${TARGET}" || ! -r "${TARGET}" ]]; then
  echo "nyxus-set-wallpaper.sh: no wallpaper matches '${NAME}'" >&2
  echo "looked in: ${DIRS[*]} (suxyn-/nyxus-bg-/nyxus-/bare .png/.jpg)" >&2
  exit 1
fi

exec nyxus-set-wallpaper "${TARGET}"
