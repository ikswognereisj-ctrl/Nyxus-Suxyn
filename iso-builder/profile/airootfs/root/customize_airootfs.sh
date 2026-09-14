#!/usr/bin/env bash
# NOT executed by current mkarchiso. Leak guards live in iso-builder/build-iso.sh.
# Kept as a reference checklist if a future bake hook reintroduces a chroot step.
# Nyxus Suxyn airootfs customize (runs inside the mkarchiso work root).
# HARD RULES — this hook must never copy the baker's machine into the stick:
#   - no /etc/mkinitcpio.conf.d/20-nyxus-hardware.conf
#   - no eDP-1 1920x1200@165 as an active monitor line
#   - no user gowski, no baker hostname, no Wi-Fi secrets, no lat/lon
#   - no localmodconfig / firmware strip
set -euo pipefail

say() { printf '[customize] %s\n' "$*"; }

if [[ -e /etc/mkinitcpio.conf.d/20-nyxus-hardware.conf ]]; then
  say "FATAL: 20-nyxus-hardware.conf is install-time only — removing from live root"
  rm -f /etc/mkinitcpio.conf.d/20-nyxus-hardware.conf
fi

if [[ -e /etc/hostname ]] && grep -qi 'gowski\|alienware' /etc/hostname; then
  say "FATAL: hostname leaked from the baker"
  exit 1
fi

if getent passwd gowski >/dev/null 2>&1; then
  say "FATAL: user gowski must not exist on the stick"
  exit 1
fi

if [[ -d /etc/NetworkManager/system-connections ]] && \
   compgen -G '/etc/NetworkManager/system-connections/*' >/dev/null 2>&1; then
  say "FATAL: Wi-Fi/system-connections leaked into the image"
  exit 1
fi

if grep -R -l -E '42\.511|-83\.616' /etc /home /root 2>/dev/null | grep -qv '/proc'; then
  say "FATAL: baker weather coordinates leaked"
  exit 1
fi

# Live user groups (sysusers + usermod: packages create audio/video after overlay).
if id nyx >/dev/null 2>&1; then
  for g in wheel audio video network storage input lp scanner optical rfkill sys users; do
    getent group "${g}" >/dev/null 2>&1 && usermod -aG "${g}" nyx || true
  done
  mkdir -p /home/nyx
  if [[ -d /etc/skel ]]; then
    cp -a /etc/skel/. /home/nyx/ 2>/dev/null || true
  fi
  chown -R nyx:nyx /home/nyx
fi

# Generic monitors on the stick, even if skel was restaged from the repo.
mon=/etc/skel/.config/hypr/nyxus-monitors.conf
if [[ -f "${mon}" ]]; then
  if grep -E '^[[:space:]]*monitor[[:space:]]*=' "${mon}" | grep -q 'eDP-1'; then
    say "stripping baker monitor pin from skel"
  fi
  cat > "${mon}" <<'EOF'
# NYXUS ISO default — generic, any panel.
monitor = , preferred, auto, 1
EOF
  if [[ -f /home/nyx/.config/hypr/nyxus-monitors.conf ]]; then
    cp -a "${mon}" /home/nyx/.config/hypr/nyxus-monitors.conf
    chown nyx:nyx /home/nyx/.config/hypr/nyxus-monitors.conf
  fi
fi

if [[ -f /etc/locale.gen ]]; then
  locale-gen || true
fi

systemctl enable NetworkManager.service || true
systemctl enable bluetooth.service || true
systemctl enable chronyd.service || true
systemctl enable greetd.service || true
systemctl enable nyxus-firstboot.service || true
systemctl set-default graphical.target || true

# Live ISO must not enable systemd-timesyncd next to chrony.
systemctl disable systemd-timesyncd.service >/dev/null 2>&1 || true

chmod 0755 /usr/local/bin/nyxus-* /usr/local/sbin/nyxus-* /usr/local/bin/blast-from-the-past 2>/dev/null || true
chmod 0755 /etc/nyxus-firstboot.d/*.sh 2>/dev/null || true

say "customize complete (generic live root)"
