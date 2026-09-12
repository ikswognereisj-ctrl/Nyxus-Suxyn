#!/usr/bin/env bash
# Nyxus Suxyn — update the shell from a terminal.
#
# Pulls the latest commit of this repository, then re-runs the deploy
# (tools/apply-shell.sh), which re-checks pre-flight conditions and makes a
# fresh timestamped rollback snapshot before touching ~/.config.
#
#   ~/src/Nyxus-Suxyn/tools/update-shell.sh
#   ~/src/Nyxus-Suxyn/tools/update-shell.sh --check   # report, change nothing
#
# Local edits in the clone are never discarded: a dirty tree stops the pull
# and is reported. ~/.config/hypr/conf.d/nyxus-user-rules.conf is user-owned
# and is not managed by this script or by apply-shell.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

ICE='\033[38;2;183;230;242m'
MAGMA='\033[38;2;255;120;71m'
GOLD='\033[38;2;255;202;107m'
DIM='\033[38;2;138;164;176m'
RST='\033[0m'

note() { printf '%b→%b  %s\n' "$ICE" "$RST" "$1"; }
warn() { printf '%b!%b  %s\n' "$GOLD" "$RST" "$1"; }
die()  { printf '%b✗%b  %s\n' "$MAGMA" "$RST" "$1" >&2; exit 1; }

CHECK_ONLY=0
[[ ${1:-} == "--check" ]] && CHECK_ONLY=1

need() { command -v "$1" >/dev/null 2>&1 || die "missing $1 — install it, then run this again."; }
need git

[[ -d "$ROOT/.git" ]] || die "$ROOT is not a git clone — reinstall with docs/get.sh."

note "repo    $ROOT"
if ! git -C "$ROOT" remote get-url origin >/dev/null 2>&1; then
  die "no 'origin' remote on $ROOT — reinstall with docs/get.sh."
fi
note "origin  $(git -C "$ROOT" remote get-url origin)"

if [[ -n $(git -C "$ROOT" status --porcelain) ]]; then
  die "local changes in $ROOT — commit or stash them first; update never discards edits."
fi

branch="$(git -C "$ROOT" symbolic-ref --short -q HEAD || true)"
[[ -n $branch ]] || die "detached HEAD in $ROOT — check out a branch first."

note "fetch   origin/$branch"
git -C "$ROOT" fetch --quiet origin "$branch" \
  || die "could not reach origin — check the network and try again."

local_rev="$(git -C "$ROOT" rev-parse HEAD)"
remote_rev="$(git -C "$ROOT" rev-parse "origin/$branch")"

if [[ $local_rev == "$remote_rev" ]]; then
  note "already current ($(git -C "$ROOT" rev-parse --short HEAD))"
  exit 0
fi

if ! git -C "$ROOT" merge-base --is-ancestor "$local_rev" "$remote_rev"; then
  die "local $branch has commits origin does not — refusing to merge. Push or rebase first."
fi

count="$(git -C "$ROOT" rev-list --count "$local_rev..$remote_rev")"
note "behind  $count commit(s):"
git -C "$ROOT" log --oneline --no-decorate "$local_rev..$remote_rev" | sed 's/^/      /'

if [[ $CHECK_ONLY -eq 1 ]]; then
  note "--check: nothing changed. Re-run without it to pull and apply."
  exit 0
fi

note "pull    --ff-only"
git -C "$ROOT" pull --ff-only \
  || die "pull failed — tree is untouched; resolve and re-run."

note "apply   tools/apply-shell.sh (pre-flight + rollback snapshot)"
"$ROOT/tools/apply-shell.sh"

printf '\n%b✓%b  updated to %s\n' "$ICE" "$RST" "$(git -C "$ROOT" rev-parse --short HEAD)"
printf '%b  reload:  qs ipc call nyxus reload%b\n' "$DIM" "$RST"
