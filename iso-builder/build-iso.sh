#!/usr/bin/env bash
# ============================================================================
# Nyxus Suxyn ISO baker
#
# This image is for ANYONE — different systems, different hardware.
# The machine that runs this script is only the build host.
# Do NOT copy Nyxus-Core. Do NOT clone this Alienware into the squashfs.
#
# HARD RULES (live stick):
#   - Stock Arch `linux` + full `linux-firmware` (do not strip
#     intel/nvidia/amd/atheros/realtek).
#   - Live initramfs MODULES: common GPU set
#       (i915 amdgpu nvidia nvidia_modeset nvidia_drm)
#     OR empty without autodetect. NEVER this laptop's
#     /etc/mkinitcpio.conf.d/20-nyxus-hardware.conf
#     (amdgpu nvidia … from the baker's PCI bus).
#   - Hyprland: `monitor = , preferred, auto, 1`
#     NEVER `eDP-1, 1920x1200@165`. That 165 Hz line stays on the owner's
#     laptop locally, not in the ISO tree.
#   - GPU env (LIBVA, __GLX_VENDOR) is detected per machine. Not NVIDIA-only.
#   - Live user is `nyx`. Calamares creates the real user.
#     NEVER bake `gowski`, this hostname, Wi-Fi secrets, weather
#     lat/lon 42.511/-83.616, or personal Brain/notes.
#   - Do NOT localmodconfig / strip kernel modules.
#
# INSTALLED system:
#   - nyxus-hwdetect writes MODULES from THAT machine's PCI bus
#   - first boot runs /etc/nyxus-firstboot.d/03-hardware-initramfs.sh
#   - nyxus-hwcaps drives Settings ▸ Hardware (hide fans if none)
#   - Shell from this repo (quickshell/hypr) with generic monitors
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
PROFILE_SRC="${SCRIPT_DIR}/profile"
BRANDING_SRC="${REPO_ROOT}/installer/calamares/branding/nyxus"
OUTDIR="${SCRIPT_DIR}/out"
WORKDIR="${WORKDIR:-/tmp/suxyn-iso}"
STAGE="${WORKDIR}/profile"

ISO_DATE="$(date -u +%Y.%m.%d)"
BUILD_TIME="$(date -u +'%Y-%m-%d %H:%M:%S UTC')"
GIT_COMMIT="unknown"
GIT_BRANCH="unknown"
if git -C "${REPO_ROOT}" rev-parse --short HEAD >/dev/null 2>&1; then
    GIT_COMMIT="$(git -C "${REPO_ROOT}" rev-parse --short HEAD)"
    GIT_BRANCH="$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
fi

die() { printf 'build-iso: %s\n' "$*" >&2; exit 1; }
log() { printf 'build-iso: %s\n' "$*"; }

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<EOF
Bake nyxus-suxyn-${ISO_DATE}-x86_64.iso (label NYXUS_SUXYN).

  sudo ${SCRIPT_DIR}/build-iso.sh

Needs archiso on the host:
  sudo pacman -S archiso

Work dir : ${WORKDIR}
Output   : ${OUTDIR}
Profile  : ${PROFILE_SRC}

This stick is for unknown PCs. The baker's laptop is not the target.
Do not upload the ISO to GitHub (release cap 2 GB; this image is ~8 GB).
EOF
    exit 0
fi

# Refuse to run from a Core tree.
if [[ "${REPO_ROOT}" == *Nyxus-Core* ]] || [[ -d "${REPO_ROOT}/../Nyxus-Core/iso-builder" && "${SCRIPT_DIR}" == *Nyxus-Core* ]]; then
    die "this is the Suxyn baker — do not copy or run Nyxus-Core's builder"
fi

if ! command -v mkarchiso >/dev/null 2>&1; then
    cat >&2 <<EOF
build-iso: mkarchiso is not installed.

Install the baker, then re-run this script as root:

  sudo pacman -S archiso
  sudo ${SCRIPT_DIR}/build-iso.sh
EOF
    exit 1
fi

if [[ "$(id -u)" -ne 0 ]]; then
    if command -v sudo >/dev/null 2>&1; then
        log "re-executing as root via sudo"
        exec sudo --preserve-env=WORKDIR SOURCE_DATE_EPOCH -- "$0" "$@"
    fi
    die "must run as root (or with sudo)"
fi

[[ -d "${PROFILE_SRC}" ]] || die "missing profile: ${PROFILE_SRC}"
[[ -f "${PROFILE_SRC}/profiledef.sh" ]] || die "missing ${PROFILE_SRC}/profiledef.sh"
[[ -e "${PROFILE_SRC}/packages.x86_64" ]] || die "missing ${PROFILE_SRC}/packages.x86_64"
[[ -d "${BRANDING_SRC}" ]] || die "missing Calamares branding: ${BRANDING_SRC}"

mkdir -p "${OUTDIR}"
rm -rf "${WORKDIR}"
mkdir -p "${STAGE}"

# Stage a writeable copy so bake stamps never dirty the git profile.
rsync -a --delete \
    --exclude '.git/' \
    --exclude 'packages.x86_64' \
    "${PROFILE_SRC}/" "${STAGE}/"
cp --dereference --remove-destination \
    "${PROFILE_SRC}/packages.x86_64" "${STAGE}/packages.x86_64"

# Required package names must survive the copy.
for pkg in linux linux-firmware mkinitcpio mkinitcpio-archiso grub calamares; do
    grep -qx "${pkg}" "${STAGE}/packages.x86_64" \
        || die "packages.x86_64 is missing required package: ${pkg}"
done
for banned in kage-ryu steam qemu virt-manager vscode code; do
    if grep -qx "${banned}" "${STAGE}/packages.x86_64"; then
        die "packages.x86_64 must not list ${banned}"
    fi
done
# Full firmware — never a stripped subset.
if grep -E '^linux-firmware-(amdgpu|intel|nvidia)$' "${STAGE}/packages.x86_64" \
    && ! grep -qx 'linux-firmware' "${STAGE}/packages.x86_64"; then
    die "do not ship a stripped linux-firmware subset without the meta package"
fi

# Calamares branding from THIS repo (not Core, not the baker's /etc).
install -d "${STAGE}/airootfs/etc/calamares/branding/nyxus"
rsync -a --delete \
    --exclude 'README.md' \
    "${BRANDING_SRC}/" \
    "${STAGE}/airootfs/etc/calamares/branding/nyxus/"

BRANDING_DESC="${STAGE}/airootfs/etc/calamares/branding/nyxus/branding.desc"
[[ -f "${BRANDING_DESC}" ]] || die "branding.desc missing after copy"
sed -i \
    -e "s/^    version:.*/    version:             \"Nyxus Suxyn · ${ISO_DATE}\"/" \
    -e "s/^    shortVersion:.*/    shortVersion:        \"${ISO_DATE}\"/" \
    -e "s/^    versionedName:.*/    versionedName:       \"Nyxus Suxyn · ${ISO_DATE}\"/" \
    "${BRANDING_DESC}"
if grep -E '^    (version|shortVersion|versionedName):' "${BRANDING_DESC}" | grep -vq "${ISO_DATE}"; then
    die "branding.desc version strings still have a stale date after substitution"
fi

# Hardware helpers: host copies if present, else the profile seed.
# NEVER copy /etc/mkinitcpio.conf.d/20-nyxus-hardware.conf from the baker.
install -d "${STAGE}/airootfs/usr/local/bin" "${STAGE}/airootfs/usr/local/sbin"
install -d "${STAGE}/airootfs/etc/nyxus-firstboot.d"
for bin in nyxus-hwdetect nyxus-hwcaps nyxus-gpu-probe; do
    if [[ -x "/usr/local/bin/${bin}" ]]; then
        install -m755 "/usr/local/bin/${bin}" "${STAGE}/airootfs/usr/local/bin/${bin}"
        log "copied /usr/local/bin/${bin}"
    elif [[ -x "${STAGE}/airootfs/usr/local/bin/${bin}" ]]; then
        log "using profile copy of ${bin}"
    else
        die "${bin} missing — install-time hardware detection will not work"
    fi
done
if [[ -x /usr/local/sbin/nyxus-firstboot ]]; then
    install -m755 /usr/local/sbin/nyxus-firstboot "${STAGE}/airootfs/usr/local/sbin/nyxus-firstboot"
fi
if [[ -x /etc/nyxus-firstboot.d/03-hardware-initramfs.sh ]]; then
    install -m755 /etc/nyxus-firstboot.d/03-hardware-initramfs.sh \
        "${STAGE}/airootfs/etc/nyxus-firstboot.d/03-hardware-initramfs.sh"
    log "staged firstboot 03-hardware-initramfs.sh"
fi
[[ -x "${STAGE}/airootfs/etc/nyxus-firstboot.d/03-hardware-initramfs.sh" ]] \
    || die "missing 03-hardware-initramfs.sh"

# ══ THE REFERENCED-BINARY GUARD ════════════════════════════ TRK-4129 ══
#
# Audit 2026-09-14: three binaries — nyxus-fde-wire, nyxus-fde-check and
# nyxus-hibernate — were named by Calamares module configs but were never
# staged into the profile and were never copied by this script. They only
# worked because they happened to exist in /usr/local/bin ON THIS ONE
# MACHINE. Baked anywhere else, the ISO still built and still installed;
# full-disk-encryption wiring and hibernate setup just quietly did not
# happen. The FDE shellprocess ends in `|| true`, so there was not even
# an installer error to notice. They are now committed to the profile.
#
# This guard exists so that cannot come back. Every /usr/local/{bin,sbin}
# nyxus-* path mentioned ANYWHERE under iso-builder/ must resolve to a
# file staged in the image. Adding a new module config that calls a tool
# you only have locally now fails the bake instead of shipping a silently
# broken installer.
#
# Deliberately scans the SOURCE tree, not the stage: the point is to
# catch a reference the moment it is written, and the reference is what
# defines the requirement.
missing_refs=()
while read -r ref; do
    [[ -z "${ref}" ]] && continue
    [[ -e "${STAGE}/airootfs/usr/local/bin/${ref}"  ]] && continue
    [[ -e "${STAGE}/airootfs/usr/local/sbin/${ref}" ]] && continue
    missing_refs+=("${ref}")
done < <(grep -rhoE '/usr/local/(bin|sbin)/nyxus-[a-zA-Z0-9-]+' \
             "${REPO_ROOT}/iso-builder" 2>/dev/null | sed 's|.*/||' | sort -u)
if (( ${#missing_refs[@]} )); then
    die "iso-builder references binaries that are not staged in the image: ${missing_refs[*]}"
fi
log "referenced-binary guard: all /usr/local nyxus-* references are staged"

# ══ THE TOOLING ════════════════════════════════════════════ TRK-4131 ══
#
# Same audit finding as tools/apply-shell.sh. This script used to copy
# binaries out of the BAKER'S /usr/local/bin — and only three of them by
# name. Everything else the shell calls was inherited from whatever
# happened to be installed on the machine doing the bake. That is not a
# build; that is a photograph of one laptop.
#
# repo/bin is now the source of truth and it is staged wholesale, so the
# ISO carries the same tools the repo does, on any machine.
if [[ -d "${REPO_ROOT}/bin" ]]; then
    install -d "${STAGE}/airootfs/usr/local/bin"
    install -m755 "${REPO_ROOT}/bin"/* "${STAGE}/airootfs/usr/local/bin/"
    log "staged $(find "${REPO_ROOT}/bin" -maxdepth 1 -type f | wc -l) tools from repo/bin"
else
    die "repo/bin is missing — the shell's tooling would not ship"
fi

# ── THE SPAWNED-COMMAND GUARD ───────────────────────────────────────────
# Every nyxus-* program the QML actually launches must exist in the
# image. This is the check that would have caught the original problem:
# on the baker's machine all of them resolve on PATH, so nothing looks
# wrong until someone else installs the result.
#
# ⚠ TWO spawn styles, and the guard MUST cover both. A first version
# scanned only `command: [...]` arrays and silently passed while
# nyxus-beat-engine was deleted from the stage — the visualizer's engine
# is launched from inside a shell string (`... exec nyxus-beat-engine
# --tap "$1"`), not from a command array. A guard with a blind spot over
# the exact binary that started this audit is worse than no guard,
# because it reads as proof.
missing_cmds=()
while read -r cmd; do
    [[ -z "${cmd}" ]] && continue
    [[ -e "${STAGE}/airootfs/usr/local/bin/${cmd}" ]] && continue
    missing_cmds+=("${cmd}")
done < <( { grep -rhoE 'command:[[:space:]]*\[[^]]*' "${REPO_ROOT}/quickshell"/*.qml 2>/dev/null \
                | grep -oE '"nyxus-[a-z0-9-]+"' | tr -d '"'
            grep -rhoE '\bexec[[:space:]]+nyxus-[a-z0-9-]+' "${REPO_ROOT}/quickshell"/*.qml 2>/dev/null \
                | grep -oE 'nyxus-[a-z0-9-]+'
          } | sort -u )
if (( ${#missing_cmds[@]} )); then
    die "the shell spawns commands that are not in the image: ${missing_cmds[*]}"
fi
log "spawned-command guard: every nyxus-* command the shell launches is staged"

# Desktop overlay from THIS REPO, never ~/.config (no gowski, no 165 Hz pin).
install -d "${STAGE}/airootfs/etc/skel/.config"
if [[ -d "${REPO_ROOT}/quickshell" ]]; then
    rsync -a --delete \
        --exclude '*.bak' --exclude '__pycache__' --exclude '*.qmlc' \
        "${REPO_ROOT}/quickshell/" \
        "${STAGE}/airootfs/etc/skel/.config/quickshell/"
    log "staged repo quickshell → /etc/skel/.config/quickshell"
fi
if [[ -d "${REPO_ROOT}/hypr" ]]; then
    rsync -a --delete \
        --exclude 'walls/live/' \
        "${REPO_ROOT}/hypr/" \
        "${STAGE}/airootfs/etc/skel/.config/hypr/"
fi
# FORCE the ISO monitor line. Copilot's fallback is correct FOR THE STICK.
install -d "${STAGE}/airootfs/etc/skel/.config/hypr"
cat > "${STAGE}/airootfs/etc/skel/.config/hypr/nyxus-monitors.conf" <<'MON'
# ISO default: any panel. Do not bake the build laptop's eDP-1 @ 165.
# Owner machine keeps its 165 Hz line locally, not in this image.
monitor = , preferred, auto, 1
MON
log "forced generic Hyprland monitor line"

if [[ -f "${REPO_ROOT}/hypr/walls/nyxus-login-wall.png" ]]; then
    install -D -m644 "${REPO_ROOT}/hypr/walls/nyxus-login-wall.png" \
        "${STAGE}/airootfs/usr/share/backgrounds/nyxus/nyxus-login-wall.png"
fi

stamp() {
    local file="$1"
    [[ -f "${file}" ]] || die "missing stamp target: ${file}"
    sed -i \
        -e "s/@ISO_DATE@/${ISO_DATE}/g" \
        -e "s/@GIT_COMMIT@/${GIT_COMMIT}/g" \
        -e "s/@GIT_BRANCH@/${GIT_BRANCH}/g" \
        -e "s/@BUILD_TIME@/${BUILD_TIME}/g" \
        "${file}"
    if grep -q '@[A-Z_]*@' "${file}"; then
        die "unsubstituted stamp token in ${file}"
    fi
}

stamp "${STAGE}/airootfs/etc/os-release"
stamp "${STAGE}/airootfs/etc/nyxus-build"
sed -i "s/^iso_version=.*/iso_version=\"${ISO_DATE}\"/" "${STAGE}/profiledef.sh"

# ── HARD RULE gates (fail the bake, do not ship a one-chassis ISO) ─────────
ROOT="${STAGE}/airootfs"

if [[ -e "${ROOT}/etc/mkinitcpio.conf.d/20-nyxus-hardware.conf" ]]; then
    die "20-nyxus-hardware.conf is install-time only — remove it from the ISO profile"
fi

if grep -RIl --exclude-dir=branding -E '^[[:space:]]*monitor[[:space:]]*=[[:space:]]*eDP-1' \
    "${ROOT}" >/dev/null 2>&1; then
    die "active eDP-1 monitor pin found — ISO default must be monitor = , preferred, auto, 1"
fi

if grep -qxE 'gowski-alienware|gowski' "${ROOT}/etc/hostname" 2>/dev/null; then
    die "hostname leaked from the baker (${ROOT}/etc/hostname)"
fi

if grep -E '^gowski:' "${ROOT}/etc/passwd" >/dev/null 2>&1; then
    die "user gowski must not exist on the stick"
fi

if [[ -d "${ROOT}/etc/NetworkManager/system-connections" ]] && \
   compgen -G "${ROOT}/etc/NetworkManager/system-connections/*" >/dev/null 2>&1; then
    die "Wi-Fi/system-connections leaked into the image"
fi

if grep -RIl -E '42\.511|-83\.616' "${ROOT}" >/dev/null 2>&1; then
    die "baker weather coordinates leaked into airootfs"
fi

# Live MODULES must be the common GPU set (or empty). Fail if it is only
# the baker's amdgpu+nvidia pair without i915.
live_mods="$(grep -E '^MODULES=' "${ROOT}/etc/mkinitcpio.conf.d/archiso.conf" "${ROOT}/etc/mkinitcpio.conf" 2>/dev/null || true)"
if echo "${live_mods}" | grep -q 'amdgpu' && echo "${live_mods}" | grep -q 'nvidia' && ! echo "${live_mods}" | grep -q 'i915'; then
    die "live MODULES looks like this Alienware (amdgpu+nvidia, no i915) — use the common GPU set"
fi
if grep -E '^HOOKS=' "${ROOT}/etc/mkinitcpio.conf.d/archiso.conf" | grep -q autodetect; then
    die "live archiso.conf must not use autodetect (that would bake the host's modules)"
fi

# NVIDIA-only env must not be the only /etc path.
if grep -RIl --include='*.conf' -E '^[[:space:]]*(LIBVA_DRIVER_NAME|__GLX_VENDOR_LIBRARY_NAME)=' \
    "${ROOT}/etc/environment.d" "${ROOT}/etc/environment" >/dev/null 2>&1; then
    die "NVIDIA-only LIBVA/GLX env in /etc — session-start must detect per machine"
fi

[[ -x "${ROOT}/usr/local/bin/nyxus-hwdetect" ]] || die "nyxus-hwdetect not staged"
[[ -x "${ROOT}/usr/local/bin/nyxus-hwcaps" ]] || die "nyxus-hwcaps not staged"
[[ -f "${ROOT}/etc/calamares/settings.conf" ]] || die "Calamares settings.conf not staged"
[[ -f "${ROOT}/etc/calamares/modules/shellprocess_initramfs.conf" ]] || die "shellprocess@initramfs missing"

if ! pacman -Sp calamares --config "${STAGE}/pacman.conf" >/dev/null 2>&1; then
    log "WARN: calamares is listed but not in enabled repos."
    log "WARN: pacstrap will fail until calamares is available to pacman."
fi

log "mkarchiso  work=${WORKDIR}/work  out=${OUTDIR}  date=${ISO_DATE}  commit=${GIT_COMMIT}"
log "kernel: stock linux + full linux-firmware; any typical PC"
log "will not upload to GitHub"

mkarchiso -v -w "${WORKDIR}/work" -o "${OUTDIR}" "${STAGE}"

ISO_PATH="${OUTDIR}/nyxus-suxyn-${ISO_DATE}-x86_64.iso"
if [[ -f "${ISO_PATH}" ]]; then
    sha256sum "${ISO_PATH}" | tee "${ISO_PATH}.sha256"
    log "baked ${ISO_PATH}"
    log "keep this file local — GitHub releases cap at 2 GB"
else
    log "mkarchiso finished; expected ${ISO_PATH}"
    ls -l "${OUTDIR}" || true
fi
