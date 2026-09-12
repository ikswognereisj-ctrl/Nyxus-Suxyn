# Dependencies

Nyxus Suxyn is the **shell layer only**. It assumes a working Arch-based
system that already has the Wayland desktop stack installed. Nothing here
installs a distribution or pulls in packages for you — `tools/apply-shell.sh`
replaces user-level shell configuration on a machine that already has
everything below.

## Core (hard requirements)

| Component | Package / binary | Used for |
|---|---|---|
| Compositor | `hyprland` (0.56.x) | everything |
| Shell | `quickshell` (`qs`) | bar, lock, Settings, widgets |
| Terminal | `ghostty` | default terminal |
| Audio server | `pipewire` + `wireplumber` | sound, media routing |
| Session lock | `hyprlock` (fallback) / Quickshell lock | locking |
| Idle daemon | `hypridle` | idle pipeline (lock/suspend triggers) |
| Wallpaper | `awww` (or `swww`) | still backgrounds; `hyprpaper` is retired — see `hypr/hyprpaper.conf` |

## Desktop helpers (called from configs / scripts)

`hyprctl` · `wpctl` · `pactl` · `playerctl` · `cava` (spectrum) ·
`dbus-update-activation-environment` · `gsettings` · `dex` (autostart) ·
`easyeffects` (audio FX) · `kdeconnectd` + `kdeconnect-indicator` ·
`python3` (the `quickshell/*-io.py` helpers)

## Fonts and themes (referenced by gtk-3.0 / gtk-4.0 / ghostty)

`Inter` · `JetBrains Mono Nerd Font` · `adw-gtk3-dark` ·
`NYXUS-Dark` icon theme · `NYXUS-Aurora` cursor theme

The two `NYXUS-*` themes live on the built image, not in this repository;
`gsettings` falls back to the system defaults where they are absent.

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
