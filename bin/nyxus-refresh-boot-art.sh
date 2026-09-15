#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
# nyxus-refresh-boot-art.sh
#
# Installs the staged Nyxus Suxyn GRUB + Plymouth identity:
#   Inter Bold 16 menu, glacier ice selection (not stock cyan),
#   void #020506 starlight still, Inter Display ice splash wordmark.
#
# THIS SCRIPT IS THE ROOT STEP. Theme files live in
#   ~/.local/share/nyxus/boot-art/{grub,plymouth}
# composed without root by compose-boot-art.py. Copying into /usr/share
# and rebuilding the initramfs needs sudo.
#
#   sudo nyxus-refresh-boot-art.sh
#
# What GRUB actually loads
#   /etc/default/grub has
#     GRUB_THEME='/usr/share/grub/themes/nyxus/theme.txt'
#   grub-mkconfig's 00_header emits `set theme=($root)/usr/share/grub/themes/nyxus/theme.txt`
#   and loadfont-s every *.pf2 next to it. Root is unencrypted btrfs, so GRUB
#   reads that path at menu time. Do NOT run grub-mkconfig for this refresh:
#   bold16.pf2 keeps its filename (only the face inside changed to Inter),
#   so the existing loadfont line still hits it. A new pf2 filename WOULD
#   need `grub-mkconfig -o /boot/grub/grub.cfg`.
#
#   /boot/grub/themes/starfield is the grub package default. It is not
#   GRUB_THEME. If a future mkconfig ever drops GRUB_THEME, that is what
#   would show — a different OS. Keep GRUB_THEME pointed at nyxus.
#
# Plymouth
#   /etc/plymouth/plymouthd.conf Theme=suxyn. The initcpio plymouth hook
#   does add_full_dir on the theme, so hero.png / suxyn.script only appear
#   on the next splash after `mkinitcpio -P`. GRUB picks up /usr/share
#   copies on the next reboot with no mkconfig.
#
# Login
#   /etc/greetd/nyxus-login-bg.png (B&W milky way + vortex Earth) STAYS.
#   Do not copy it onto GRUB or the splash. Boot chapter is starlight;
#   login is the vortex. That split is the product.
#
# MENU_BOX in theme.txt is 15/25/70/62 — the still is uniformly dark so
# the menu stays readable. Leading `+` on every component block is
# load-bearing (WIP-85). Missing `+` drops GRUB to the text menu.
#
# Revert: the pre-refresh copies are snapshotted at
#   ~/.local/share/nyxus/boot-art/src/{grub,plymouth}
#   sudo cp -a that tree back onto /usr/share/... and rerun mkinitcpio -P.
#
# © 2026 JOSEPH A. SIERENGOWSKI · NYX-J5W-2026-SIERENGOWSKI-LOCKED
# ════════════════════════════════════════════════════════════════════
# 2026-09-11: this + mkinitcpio is parked after the splash hang.
if [[ "${NYXUS_I_MEAN_IT:-}" != "1" ]]; then
  echo "REFUSED: nyxus-refresh-boot-art.sh is parked after the splash hang." >&2
  echo "Use: sudo nyxus-repair-at-root" >&2
  exit 2
fi

set -euo pipefail

# sudo resets HOME to /root. The staged art lives in the owner's tree.
if [[ -n "${SUDO_USER:-}" ]]; then
  OWNER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
fi
# Resolve the invoking user's home, never a hardcoded account (see
# nyxus-repair-at-root, which established this idiom).
OWNER_HOME="${OWNER_HOME:-$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)}"
OWNER_HOME="${OWNER_HOME:-$HOME}"
STAGE="${OWNER_HOME}/.local/share/nyxus/boot-art"
GRUB_SRC="${STAGE}/grub"
PLY_SRC="${STAGE}/plymouth"
GRUB_DST="/usr/share/grub/themes/nyxus"
PLY_DST="/usr/share/plymouth/themes/suxyn"
GRUB_DEFAULT="/etc/default/grub"

[[ ${EUID} -eq 0 ]] || {
  echo "run me with sudo: sudo $(basename "$0")" >&2
  exit 1
}

[[ -f "${GRUB_SRC}/theme.txt" && -f "${PLY_SRC}/hero.png" ]] || {
  echo "staged art missing under ${STAGE} — run compose-boot-art.py first" >&2
  exit 1
}

if ! grep -q "^+ boot_menu" "${GRUB_SRC}/theme.txt" \
   || ! grep -q "^+ progress_bar" "${GRUB_SRC}/theme.txt"; then
  echo "refusing: staged theme.txt is missing load-bearing '+' prefixes (WIP-85)" >&2
  exit 1
fi

if [[ -f "${GRUB_DEFAULT}" ]] && ! grep -q "GRUB_THEME=.*/usr/share/grub/themes/nyxus/theme.txt" "${GRUB_DEFAULT}"; then
  echo "warning: ${GRUB_DEFAULT} does not point GRUB_THEME at ${GRUB_DST}/theme.txt" >&2
  echo "         /boot/grub/themes/starfield is the package fallback — not this product." >&2
fi

echo "installing GRUB theme → ${GRUB_DST}"
install -d -m 0755 "${GRUB_DST}"
cp -a "${GRUB_SRC}/." "${GRUB_DST}/"
chmod 644 "${GRUB_DST}"/*

echo "installing Plymouth suxyn → ${PLY_DST}"
install -d -m 0755 "${PLY_DST}"
cp -a "${PLY_SRC}/." "${PLY_DST}/"
chmod 644 "${PLY_DST}"/*

echo "rebuilding initramfs so the splash wordmark is in the image (mkinitcpio -P)…"
mkinitcpio -P

echo
echo "boot art installed."
echo "  GRUB     ${GRUB_DST}/theme.txt   (no grub-mkconfig needed)"
echo "  splash   ${PLY_DST}/hero.png     (initramfs rebuilt)"
echo "  login    /etc/greetd/nyxus-login-bg.png  (untouched — vortex stays unique)"
echo "reboot to see GRUB → splash → login."
