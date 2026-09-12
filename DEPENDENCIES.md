# Dependencies

Nyxus Suxyn is the **shell layer only**. It assumes a working Arch-based
system that already has the Wayland desktop stack installed. Nothing here
installs a distro or pulls in packages for you — `tools/apply-shell.sh`
replaces config on a machine that already has the below.

## Core (hard requirements)

| Component | Package / binary | Used for |
|---|---|---|
| Compositor | `hyprland` (0.56.x) | everything |
| Shell | `quickshell` (`qs`) | bar, lock, Settings, widgets |
| Terminal | `ghostty` | default terminal |
| Audio server | `pipewire` + `wireplumber` | sound, media routing |
| Session lock | `hyprlock` (fallback) / Quickshell lock | locking |
| Idle daemon | `hypridle` | idle / screensaver clock |
| Wallpaper | `hyprpaper` (+ optional `mpvpaper` for live) | backgrounds |

## Desktop helpers (called from configs / scripts)

`hyprctl` · `wpctl` · `pactl` · `playerctl` · `cava` (spectrum) ·
`dbus-update-activation-environment` · `gsettings` · `dex` (autostart) ·
`easyeffects` (audio FX) · `kdeconnectd` + `kdeconnect-indicator` ·
`python3` (the `quickshell/*-io.py` helpers)

## Nyxus-specific binaries (not in this repo)

These live on the built image / in `~/.local/bin` or `/usr/local/bin` and are
referenced by the configs. The shell degrades gracefully if one is missing,
but the matching feature goes quiet:

`nyxus-bootstrap` · `nyxus-wait-bootstrap` · `nyxus-shell-supervisor` ·
`nyxus-sound` / `nyxus-soundd` · `nyxus-lock-guard` · `nyxus-lock-weather` ·
`nyxus-lock-track` · `nyxus-greeter*` · `nyxus-weather` · `nyxus-notepad` ·
`nyxus-plugins` · `nyxus-shader` · `nyxus-wallpaper-autostart` ·
`nyxus-live-wallpaper`

## Installer branding (optional)

The `installer/` tree is **Calamares branding only** (slideshow, stylesheet,
logo) for the next ISO bake. It needs `calamares` on the target image; it is
not an ISO builder.

---

**Tip:** run `tools/apply-shell.sh --preflight-only` (or
`tools/preflight-shell.sh`) to check GPU, Hyprland/Quickshell, PipeWire, and
monitor assumptions before deploying.
