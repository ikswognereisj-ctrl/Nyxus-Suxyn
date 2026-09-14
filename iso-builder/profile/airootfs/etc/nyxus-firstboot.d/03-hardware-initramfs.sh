#!/usr/bin/env bash
# ============================================================================
# NYXUS · first-boot fragment · hardware-correct initramfs
#
# Run once by /usr/local/sbin/nyxus-firstboot (see nyxus-firstboot.service).
#
# WHAT IT IS FOR. The live ISO ships a COMMON GPU MODULES set (i915 amdgpu
# nvidia …) so unknown PCs can boot. nyxus-hwdetect replaces it with the
# set THIS machine actually has. On a Calamares install that already ran
# inside shellprocess@initramfs, this fragment finds the drop-in correct
# and is a no-op — the common path.
#
# It earns its place on the paths Calamares never touches:
#   · the ISO written straight to a disk with no installer run
#   · a disk moved into different hardware
#   · a GPU added or removed between boots
#
# EXACTLY ONE REBUILD. nyxus-hwdetect exits 10 only when it actually changed
# the drop-in, and only that exit triggers `mkinitcpio -P` here. Exit 0 means
# already-correct and we do not rebuild; exit 1 means detection failed and we
# must NOT rebuild, because regenerating against a half-derived MODULES set
# is how you turn a working boot into a black one.
#
# NEVER FAILS THE BOOT. A first-boot fragment that exits non-zero is noise in
# the journal at best; at worst it makes an otherwise-good machine look
# broken. Every path here ends `exit 0`. The initramfs that already exists
# keeps working in every failure case — this fragment can only ever improve
# it, never remove it.
#
# © 2026 JOSEPH A. SIERENGOWSKI · NYX-J5W-2026-SIERENGOWSKI-LOCKED
# ============================================================================
set -uo pipefail

say() { printf '[firstboot/hardware] %s\n' "$*"; }

# ── NEVER ON THE LIVE ISO (2026-08-23) ─────────────────────────────────────
# nyxus-firstboot.service is enabled at bake time (customize_airootfs.sh), so
# this fragment runs on the LIVE stick as well as on installed systems. On
# live it must do nothing at all:
#
#   · It is pointless. The live system has already booted from the ISO's own
#     initramfs; rebuilding it changes nothing for the running session, and
#     the next live boot reads the ISO again, not the overlay.
#   · It is expensive. The live root is a squashfs with a RAM overlay, so
#     `mkinitcpio -P` would spend minutes of CPU writing tens of MB into RAM
#     that is thrown away at shutdown — on a low-memory machine that is a
#     real cost during the exact session someone is evaluating the distro in.
#   · It would build the WRONG image anyway. /etc/mkinitcpio.conf.d/archiso.conf
#     is still present on live (Calamares removes it on the target, WIP-253),
#     so a -P here regenerates a live/archiso initramfs, not a target one.
#
# /run/archiso is archiso's own marker for "this is the live environment" and
# exists on every archiso-derived ISO. The mkinitcpio.conf.d/archiso.conf test
# is a second, independent signal: it is present precisely while a system has
# not yet had the installer strip it. Either one is enough to stand down.
if [[ -d /run/archiso ]] || [[ -e /etc/mkinitcpio.conf.d/archiso.conf ]]; then
  say "live ISO detected — hardware detection is the installer's job, standing down"
  exit 0
fi

if [[ ! -x /usr/local/bin/nyxus-hwdetect ]]; then
  say "nyxus-hwdetect absent — leaving the shipped initramfs alone"
  exit 0
fi

/usr/local/bin/nyxus-hwdetect
rc=$?

case "${rc}" in
  0)
    say "initramfs MODULES already match this hardware — no rebuild"
    ;;
  10)
    say "hardware differs from the shipped set — regenerating the initramfs ONCE"
    if command -v mkinitcpio >/dev/null 2>&1; then
      if mkinitcpio -P; then
        say "initramfs regenerated for this machine"
      else
        # The drop-in is written and correct; the build failed for some other
        # reason (out of space, a broken DKMS module). Say so loudly and leave
        # the previous, working initramfs in place. The next kernel update
        # will pick the drop-in up anyway.
        say "WARN mkinitcpio -P failed — the PREVIOUS initramfs is untouched and still boots"
      fi
    else
      say "WARN mkinitcpio not installed — drop-in written, rebuild deferred to the next kernel update"
    fi
    ;;
  *)
    say "WARN hardware detection failed (rc=${rc}) — initramfs deliberately left alone"
    ;;
esac

exit 0
