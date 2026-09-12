#!/usr/bin/env bash
# Nyxus Suxyn — pre-flight diagnostics before deploying the shell.
set -euo pipefail

ICE='\033[38;2;183;230;242m'
MAGMA='\033[38;2;255;120;71m'
GOLD='\033[38;2;255;202;107m'
DIM='\033[38;2;138;164;176m'
RST='\033[0m'

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

status() {
  local tag=$1 color=$2 text=$3
  printf '%b[%s]%b %s\n' "$color" "$tag" "$RST" "$text"
}

pass() { PASS_COUNT=$((PASS_COUNT + 1)); status "PASS" "$ICE" "$1"; }
warn() { WARN_COUNT=$((WARN_COUNT + 1)); status "WARN" "$GOLD" "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); status "FAIL" "$MAGMA" "$1"; }

have() { command -v "$1" >/dev/null 2>&1; }

version_of() {
  local cmd=$1
  shift || true
  "$cmd" "$@" 2>/dev/null | head -n 1 | tr -d '\r'
}

check_binary() {
  local label=$1; shift
  local path=""
  for cand in "$@"; do
    if have "$cand"; then
      path="$(command -v "$cand")"
      break
    fi
  done
  if [[ -n $path ]]; then
    pass "$label found at $path"
    return 0
  fi
  fail "$label missing"
  return 1
}

check_audio_tool() {
  local label=$1 tool=$2
  if have "$tool"; then
    pass "$label available"
  else
    warn "$label missing — some audio monitoring or fallback paths may be reduced"
  fi
}

check_gpu() {
  local cmdline driver vendor risk
  cmdline="$(cat /proc/cmdline 2>/dev/null || true)"
  driver="unknown"
  vendor="unknown"
  risk=""

  if lsmod 2>/dev/null | grep -q '^nvidia_drm'; then
    driver="nvidia_drm"
    vendor="NVIDIA"
    if [[ $cmdline == *"nvidia-drm.modeset=1"* ]]; then
      pass "GPU: NVIDIA proprietary stack detected with nvidia-drm.modeset=1"
    else
      warn "GPU: NVIDIA driver detected but nvidia-drm.modeset=1 is not present; Wayland shader paths can misbehave"
    fi
    risk="GLSL driver-extension behavior can vary on NVIDIA; rebuild qsb shaders after shader edits."
  elif lsmod 2>/dev/null | grep -q '^amdgpu'; then
    driver="amdgpu"
    vendor="AMD"
    pass "GPU: AMD amdgpu stack detected"
    risk="AMDGPU is usually stable here; watch for fp16/precision differences on older Mesa builds."
  elif lsmod 2>/dev/null | grep -q '^xe'; then
    driver="xe"
    vendor="Intel"
    pass "GPU: Intel xe stack detected"
    risk="Intel drivers can show precision-sensitive banding; validate Swirl/Headliner after shader changes."
  elif lsmod 2>/dev/null | grep -q '^i915'; then
    driver="i915"
    vendor="Intel"
    pass "GPU: Intel i915 stack detected"
    risk="Intel drivers can show precision-sensitive banding; validate Swirl/Headliner after shader changes."
  else
    local pci
    pci="$(lspci 2>/dev/null | grep -Ei 'vga|3d|display' | head -n 1 || true)"
    if [[ -n $pci ]]; then
      warn "GPU driver stack could not be identified from loaded modules (${pci})"
    else
      warn "GPU vendor/driver could not be identified automatically"
    fi
    risk="Unknown GPU stack — validate shader precision, driver extensions, and fullscreen occlusion behavior manually."
  fi

  if [[ -n $risk ]]; then
    warn "Shader risk note: $risk"
  fi
}

check_versions() {
  local hypr_ver quickshell_ver
  if have hyprctl; then
    hypr_ver="$(version_of hyprctl version)"
    if [[ -n $hypr_ver ]]; then
      pass "Hyprland reports: $hypr_ver"
      if [[ $hypr_ver =~ ([0-9]+)\.([0-9]+)\. ]]; then
        if [[ ${BASH_REMATCH[1]} -ne 0 || ${BASH_REMATCH[2]} -lt 56 || ${BASH_REMATCH[2]} -gt 56 ]]; then
          warn "Hyprland is outside the repository-tested 0.56.x range; ABI/plugin behavior may drift"
        fi
      fi
    else
      fail "Hyprland is not reachable via hyprctl version"
    fi
  fi

  local have_quickshell=0
  if have qs; then
    have_quickshell=1
    quickshell_ver="$(version_of qs --version)"
  elif have quickshell; then
    have_quickshell=1
    quickshell_ver="$(version_of quickshell --version)"
  else
    quickshell_ver=""
  fi
  if [[ -n $quickshell_ver ]]; then
    pass "Quickshell reports: $quickshell_ver"
    if [[ $quickshell_ver =~ ([0-9]+)\.([0-9]+)\. ]]; then
      if [[ ${BASH_REMATCH[1]} -ne 0 || ${BASH_REMATCH[2]} -ne 3 ]]; then
        warn "Quickshell is outside the repository-tested 0.3.x range; verify Hyprland integration after deploy"
      fi
    fi
  elif [[ $have_quickshell -eq 1 ]]; then
    fail "Quickshell CLI is present but its version could not be read"
  fi
}

check_resolution() {
  local report focused baseline_w baseline_h
  baseline_w=1920
  baseline_h=1200

  if have hyprctl; then
    report="$(hyprctl -j monitors 2>/dev/null | python3 -c '
import json, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
for mon in data:
    width = mon.get("width") or 0
    height = mon.get("height") or 0
    rr = mon.get("refreshRate") or 0
    name = mon.get("name") or "unknown"
    focused = "focused" if mon.get("focused") else "idle"
    print(f"{name}\\t{width}\\t{height}\\t{rr:.2f}\\t{focused}")
')" || report=""
  else
    report=""
  fi

  if [[ -z $report ]]; then
    warn "Could not read active monitor geometry with hyprctl; resolution baseline not verified"
    return
  fi

  while IFS=$'\t' read -r name width height refresh focus; do
    [[ -z ${name:-} ]] && continue
    if [[ $focus == focused ]]; then
      focused="$name ${width}x${height}@${refresh}Hz"
      if [[ $width -eq $baseline_w && $height -eq $baseline_h ]]; then
        pass "Focused monitor matches baseline layout ${focused}"
      else
        warn "Focused monitor ${focused} differs from the 1920x1200 layout baseline; bar/spectrum geometry may scale differently"
      fi
    else
      pass "Detected monitor ${name} ${width}x${height}@${refresh}Hz"
    fi
  done <<< "$report"
}

main() {
  printf 'Nyxus Suxyn · pre-flight diagnostics\n'
  printf '%b%s%b\n' "$DIM" "Checking GPU stack, dependencies, monitor geometry, and audio monitor tooling." "$RST"

  check_gpu
  check_binary "Hyprland control" hyprctl || true
  check_binary "PipeWire" pipewire || true
  check_binary "WirePlumber" wireplumber || true
  check_binary "Quickshell" qs quickshell || true
  check_versions
  check_audio_tool "PipeWire control (wpctl)" wpctl
  check_audio_tool "Pulse compatibility layer (pactl)" pactl
  check_audio_tool "MPRIS status bridge (playerctl)" playerctl
  check_audio_tool "Spectrum fallback (cava)" cava
  check_audio_tool "PipeWire inspection tool (pw-cli)" pw-cli
  check_resolution

  if [[ $FAIL_COUNT -gt 0 ]]; then
    printf '\n'
    fail "Pre-flight failed: ${FAIL_COUNT} blocking issue(s), ${WARN_COUNT} warning(s)"
    exit 1
  fi

  printf '\n'
  if [[ $WARN_COUNT -gt 0 ]]; then
    warn "Pre-flight passed with ${WARN_COUNT} warning(s)"
  else
    pass "Pre-flight passed cleanly"
  fi
}

main "$@"
