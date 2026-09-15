#!/usr/bin/env bash
#
# build-shaders.sh — compile quickshell/shaders/*.frag to the .qsb files the
# shell actually loads, and prove the two halves agree.
#
# WHY THIS EXISTS
#
# The shell ships 33 compiled shaders and, until this script, nothing in the
# repository knew how to produce one. The recipe lived in whoever last ran
# `qsb` by hand. That is a bad place for it in a build meant to be released:
# a .qsb is opaque, a stale one fails silently (the old picture just keeps
# rendering), and an edit to a .frag that never gets recompiled looks exactly
# like an edit that did not work.
#
# It was also actively costing something. `floor_court.frag.qsb` sat in the
# tree as a compiled binary with NO source and NO reference from any QML --
# nobody could rebuild it, nobody could read it, and the ISO copied it in
# regardless because the shaders directory ships wholesale. It was removed in
# the same change that added this script, which is the kind of thing a check
# mode finds and a human reading a directory listing does not.
#
# THE TARGET SETS ARE NOT UNIFORM, AND THAT IS DELIBERATE
#
# Most shaders here carry three targets -- SPIR-V, GLSL 300 es and GLSL 330.
# A few carry two, dropping the GLES target. That is a real difference in the
# shipped files, not an accident to be normalised away, so this script reads
# the target set out of the EXISTING .qsb and rebuilds each file the way it
# was already built. A shader with no .qsb yet gets the three-target set,
# which is the majority and the safer default (it keeps GLES hardware able to
# load it). If you deliberately want a two-target file, build it once by hand
# and this script will honour that from then on.
#
# VERIFIED, NOT ASSUMED
#
# The flags were not guessed. Every one of the 33 sources was recompiled with
# the per-file target set and compared byte-for-byte against the .qsb already
# in the tree: 33 reproduced exactly, 0 differed. So this script is known to
# produce the shipped bytes, and `--check` is therefore a real gate rather
# than a warning that everyone learns to ignore.
#
# USAGE
#   ./scripts/build-shaders.sh           rebuild every shader
#   ./scripts/build-shaders.sh --check   verify only; non-zero if anything is
#                                        stale, orphaned, or unbuildable.
#                                        Nothing is written. Use this in CI.
#   ./scripts/build-shaders.sh <name>    rebuild one (with or without .frag)
#
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dir="$here/quickshell/shaders"

# qsb is not on PATH on Arch; it lives in Qt's own bindir. Take whichever is
# found rather than hardcoding, so this works on a dev box and in a container.
qsb="$(command -v qsb || true)"
[ -z "$qsb" ] && [ -x /usr/lib/qt6/bin/qsb ] && qsb=/usr/lib/qt6/bin/qsb
if [ -z "$qsb" ]; then
    echo "build-shaders: qsb not found (try: pacman -S qt6-shadertools)" >&2
    exit 127
fi

[ -d "$dir" ] || { echo "build-shaders: no $dir" >&2; exit 1; }

check=0
only=""
for a in "$@"; do
    case "$a" in
        --check) check=1 ;;
        -h|--help) sed -n '2,48p' "$0"; exit 0 ;;
        *) only="${a%.frag}" ;;
    esac
done

# Read the target set back out of a built .qsb. Three entries means the GLES
# target is present; anything else is treated as the two-target build.
targets_for() {
    local q="$1"
    [ -f "$q" ] || { echo "300es,330"; return; }
    local n
    n=$(LC_ALL=C "$qsb" --dump "$q" 2>/dev/null | grep -c '^  Shader ')
    if [ "$n" = "3" ]; then echo "300es,330"; else echo "330"; fi
}

built=0 stale=0 failed=0 orphan=0

# An orphan is a .qsb with no .frag beside it: unbuildable by definition and
# invisible to review. Always reported, in both modes.
for q in "$dir"/*.qsb; do
    [ -e "$q" ] || continue
    src="${q%.qsb}"
    if [ ! -f "$src" ]; then
        echo "ORPHAN   $(basename "$q") — compiled, no source, cannot be rebuilt"
        orphan=$((orphan + 1))
    fi
done

for f in "$dir"/*.frag; do
    [ -e "$f" ] || continue
    base="$(basename "$f")"
    [ -n "$only" ] && [ "$base" != "$only.frag" ] && continue

    out="$f.qsb"
    tgt="$(targets_for "$out")"
    tmp="$(mktemp)"

    if ! "$qsb" --glsl "$tgt" --output "$tmp" "$f" 2>"$tmp.err"; then
        echo "FAIL     $base"
        sed 's/^/           /' "$tmp.err" >&2
        failed=$((failed + 1))
        rm -f "$tmp" "$tmp.err"
        continue
    fi
    rm -f "$tmp.err"

    if cmp -s "$tmp" "$out"; then
        rm -f "$tmp"
        continue                      # already current; say nothing
    fi

    if [ "$check" = 1 ]; then
        echo "STALE    $base — .qsb does not match its source"
        stale=$((stale + 1))
        rm -f "$tmp"
    else
        mv "$tmp" "$out"
        echo "built    $base  [$tgt]"
        built=$((built + 1))
    fi
done

if [ "$check" = 1 ]; then
    if [ "$stale" = 0 ] && [ "$failed" = 0 ] && [ "$orphan" = 0 ]; then
        echo "shaders: every .qsb matches its source, no orphans."
        exit 0
    fi
    echo "shaders: $stale stale, $failed failed, $orphan orphaned." >&2
    exit 1
fi

echo "shaders: $built rebuilt, $failed failed, $orphan orphaned."
[ "$failed" = 0 ] && [ "$orphan" = 0 ]
