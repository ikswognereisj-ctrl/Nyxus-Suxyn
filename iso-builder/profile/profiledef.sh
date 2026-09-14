#!/usr/bin/env bash
# shellcheck disable=SC2034
# Nyxus Suxyn — NEW image profile. Not a recover of nyxus-suxyn-2026.09.02.

iso_name="nyxus-suxyn"
iso_label="NYXUS_SUXYN"
iso_publisher="Nyxus Suxyn <https://github.com/ikswognereisj-ctrl/Nyxus-Suxyn>"
iso_application="Nyxus Suxyn Live"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="suxyn"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/etc/sudoers.d/10-nyxus-live"]="0:0:440"
  ["/etc/sudoers.d/10-wheel"]="0:0:440"
  ["/root"]="0:0:750"
  ["/usr/local/bin/"]="0:0:755"
  ["/usr/local/sbin/"]="0:0:755"
  ["/etc/nyxus-firstboot.d/"]="0:0:755"
)
