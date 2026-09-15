#!/usr/bin/env bash
# ── NYXUS SUXYN · BUILD THE GREETER FROM THE SHELL ─────── TRK-4156 ─────────
#
# "for the greeter when changing it to quickshell i want the background image
#  designed by layers so everythin g matches"
#
# ── WHY THIS SCRIPT HAD TO EXIST BEFORE THAT WAS POSSIBLE ──────────────────
# /usr/share/nyxus-greeter/ was a full, hand-made copy of the entire shell --
# 141 QML files -- and it was in no repository anywhere. It was made on
# 2026-09-06 and then left alone while the shell kept moving. Measured on
# 2026-09-15, before this script existed:
#
#     identical to the shell:  25 files
#     drifted:                112 files
#     Theme.qml:              25,653 bytes behind
#     occurrences of `lookMagma` in the greeter's Theme.qml:   0
#     occurrences of `lookMagma` in the shell's  Theme.qml:   78
#
# That last pair is the whole story. The greeter's copy of the theme predates
# MAGMA entirely. It had no concept that a second look existed, so no matter
# what he chose in Settings, the login screen could only ever draw ICE. The
# first screen anybody sees -- the one that sets the expectation for the whole
# system -- was the one place guaranteed not to match it.
#
# It could not be fixed by editing that copy, because the next change to the
# shell would have re-broken it the same way. The fork is the bug. So the
# greeter is now GENERATED, and matching stops being something anyone has to
# remember to do:
#
#     /usr/share/nyxus-greeter  =  quickshell/  +  quickshell/greeter/
#
# The overlay is exactly four components and one entry point. Everything else
# -- Theme, Swirl, the sky, the glass, the shaders -- is the shell's own file,
# byte for byte. There is no second copy of the theme to drift.
#
# ── WHY THE GREETER NEEDS ITS OWN COPY AT ALL ──────────────────────────────
# greetd runs the greeter as the `greeter` user, which cannot read
# /home/gowski. The shell it draws with therefore has to live somewhere
# world-readable, and /usr/share is that place. The copy is not the mistake;
# the copy being hand-maintained was.
#
# ── SAFETY ─────────────────────────────────────────────────────────────────
# This writes only to /usr/share/nyxus-greeter. It does NOT touch
# /etc/greetd/config.toml and it does NOT install anything into /usr/local/bin,
# so running it cannot change which greeter greetd launches at the next boot.
# Turning the Quickshell greeter on is a separate, deliberate act.
#
# Always run --check after --install, and prefer testing nested first:
#
#     cage -s -- env NYXUS_GREET_USER=$USER \
#       qs -p /usr/share/nyxus-greeter/shell.qml
#
# That runs the real greeter inside the running desktop, where a mistake costs
# a window instead of a login.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$REPO/quickshell"
OVERLAY="$SRC/greeter"
DEST="${NYXUS_GREETER_DEST:-/usr/share/nyxus-greeter}"

# The four components that exist only at the login screen, plus the entry
# point. Kept as an explicit list rather than "everything in greeter/" so that
# adding a file to that directory is a deliberate act with a name attached.
OVERLAY_QML=(Greeter.qml GreeterChrome.qml NyxusMark.qml OcularMark.qml)

die() { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }
info() { printf '  %s\n' "$*"; }

[ -d "$SRC" ]     || die "no shell source at $SRC"
[ -d "$OVERLAY" ] || die "no greeter overlay at $OVERLAY"

mode="${1:---install}"

# ── the type manifest ──────────────────────────────────────────────────────
# ⚠ Read quickshell/qmldir's own header before touching this. Once a qmldir
# exists Qt turns OFF implicit same-directory registration, so a component
# that is not listed does not load -- it fails at the use site with "X is not
# a type", which reads like a missing file rather than a missing line. The
# greeter's manifest is therefore the shell's manifest plus exactly the four
# overlay entries, generated here so the two can never disagree.
build_qmldir() {
  cat "$SRC/qmldir"
  printf '\n'
  printf '# ── the greeter overlay ──────────────────────────────────────────\n'
  printf '# Added by scripts/install-greeter.sh. These four exist only at the\n'
  printf '# login screen; everything above is the shell, unmodified.\n'
  printf 'Greeter       1.0 Greeter.qml\n'
  printf 'GreeterChrome 1.0 GreeterChrome.qml\n'
  printf 'NyxusMark     1.0 NyxusMark.qml\n'
  printf 'OcularMark    1.0 OcularMark.qml\n'
}

stage() {
  local out="$1"
  mkdir -p "$out" "$out/shaders" "$out/textures" "$out/i18n"

  # The shell, whole. Every .qml except shell.qml -- the greeter has its own
  # entry point and copying the desktop's over it is a real mistake that was
  # actually made once: it replaced a 5-line ShellRoot with the 712-line
  # desktop and the failure surfaced as "SkyForeground is not a type", which
  # points at the wrong file entirely.
  local f b
  for f in "$SRC"/*.qml; do
    b="$(basename "$f")"
    [ "$b" = "shell.qml" ] && continue
    cp "$f" "$out/$b"
  done

  # ⚠ .js too. Omitting these is the other mistake that has already been made:
  # MediaSource.qml imports LyricPhrase.js, and a missing script does not say
  # so -- it surfaces as a cascade of "Type <X> unavailable" walking the
  # singletons in alphabetical order, with the real cause on the last line.
  for f in "$SRC"/*.js; do [ -e "$f" ] && cp "$f" "$out/"; done

  for f in "$SRC"/*.png "$SRC"/*.conf "$SRC"/*.sh; do
    [ -e "$f" ] && cp "$f" "$out/"
  done
  [ -d "$SRC/shaders" ]  && cp -r "$SRC/shaders/."  "$out/shaders/"
  [ -d "$SRC/textures" ] && cp -r "$SRC/textures/." "$out/textures/"
  [ -d "$SRC/i18n" ]     && cp -r "$SRC/i18n/."     "$out/i18n/"

  # The overlay goes on top, so a greeter-only file always wins.
  for b in "${OVERLAY_QML[@]}"; do
    [ -f "$OVERLAY/$b" ] || die "overlay component missing: $b"
    cp "$OVERLAY/$b" "$out/$b"
  done
  cp "$OVERLAY/shell.qml" "$out/shell.qml"
  for f in "$OVERLAY"/*.png; do [ -e "$f" ] && cp "$f" "$out/"; done

  build_qmldir > "$out/qmldir"
}

case "$mode" in
  --install)
    [ -w "$(dirname "$DEST")" ] || [ -w "$DEST" ] \
      || die "$DEST is not writable -- run as the owner of that directory, or with sudo"
    info "composing greeter into $DEST"
    stage "$DEST"
    info "shell components: $(find "$DEST" -maxdepth 1 -name '*.qml' | wc -l) qml"
    info "overlay:          ${OVERLAY_QML[*]} + shell.qml"
    info "done -- greetd config untouched, next boot unchanged"
    ;;

  --check)
    # Compose into a scratch tree and compare. Exit 1 on any difference, so
    # this is usable as a release gate: it answers "is the installed greeter
    # actually this commit's shell?" without needing a bake.
    tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
    stage "$tmp/g" >/dev/null
    rc=0; n=0
    while IFS= read -r f; do
      b="${f#"$tmp/g/"}"
      if ! cmp -s "$f" "$DEST/$b"; then echo "  DRIFT: $b"; rc=1; n=$((n+1)); fi
    done < <(find "$tmp/g" -type f)
    if [ "$rc" -eq 0 ]; then echo "  greeter matches the shell"; else echo "  $n file(s) drifted"; fi
    exit $rc
    ;;

  *) die "usage: $(basename "$0") [--install|--check]" ;;
esac
