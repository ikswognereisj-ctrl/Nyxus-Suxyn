#!/usr/bin/env bash
# NYXUS easter egg - "comet pulse". Secret chord: SUPER+SHIFT+X.
# Spins the emission border gradient a full 3 turns around every
# window, then settles back to the stock 270deg galaxy ring.
# Single-instance guarded so mashing the chord can't stack spinners.
LOCK=/tmp/.nyxus-galaxy-pulse.lock
exec 9>"$LOCK"
flock -n 9 || exit 0

# The ring this spins is the ROSE sweep (nyxus-cometfire.conf), so the pulse
# has to be the same family or the easter egg flashes a different build.
# These were the pre-rose teal->violet stops; they survived every palette
# sweep because no gate scanned this path until 13ue put it on one.
# Ordered dark->bright so the spin reads as motion rather than a smear --
# the alternating-lightness rule the border and the bar swirl both follow.
# WIP-327: the first stop was #891654, the border hex the 08-09 unification
# retired. The other three had already moved to the rose family; this one had
# not, and it is the only place left in the build still using the old value as
# a LIVE colour rather than in a stale comment (Theme.qml, BorderPulse.qml and
# bleed.frag all mention it, and all three carry #891955 as their actual
# value). Moved onto plumBody so the pulse and the border it spins are one
# colour — 3/255 on green, 1/255 on blue, invisible by eye, which is exactly
# why it needed a value to catch it rather than a look.
COLORS="rgba(891955ff) rgba(ae206cff) rgba(d765a2ff) rgba(ffb3d9ff)"

notify-send -u low -t 2600 "◤ X ◥ COMET PULSE" "the galaxy turns" 2>/dev/null

# 3 revolutions, 15deg per step, ~24ms per step = ~1.7s of spin
for rev in 1 2 3; do
  for ((deg = 270; deg < 630; deg += 15)); do
    hyprctl --batch "keyword general:col.active_border $COLORS $((deg % 360))deg" >/dev/null
    sleep 0.024
  done
done

hyprctl keyword general:col.active_border "$COLORS 270deg" >/dev/null
