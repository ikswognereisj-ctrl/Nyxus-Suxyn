# Nyxus Suxyn

A daily-driver desktop shell for one Alienware 15 — Hyprland compositor,
Quickshell chrome, a shader sky, a living bar, and a glass session lock.
Shared publicly as a **showcase, reference build, and dotfiles source**.

**Live page:** <https://ikswognereisj-ctrl.github.io/Nyxus-Suxyn/>

[![Horizon desktop](docs/assets/desktop.jpg)](https://ikswognereisj-ctrl.github.io/Nyxus-Suxyn/)

---

## Scope — read this first

**Nyxus Suxyn is built for one machine, on purpose.** It is tuned for a
single Alienware 15 (`eDP-1` · 1920×1200 @ 165 Hz). It is **not** a
distribution, not an ISO, and not a drop-in theme that fits every desktop
unchanged. Where a value is machine-specific (the monitor line, for example),
it ships commented out with a generic fallback — but layouts, keybinds, and
the audio pipeline are still opinions, and those opinions are this laptop's.

If you want it on your own hardware: **fork it and adapt it.** That is the
intended path. [`DEPENDENCIES.md`](DEPENDENCIES.md) lists the stack it
expects; [`CONTRIBUTING.md`](CONTRIBUTING.md) explains what is in scope.

## Build

| | |
|---|---|
| Product | Nyxus Suxyn |
| Image | `nyxus-suxyn` **2026.09.02** |
| Chassis | Alienware 15 DA15265 · 1920×1200 @ 165 Hz · scale 1 |
| Compositor | Hyprland 0.56.2 · blur off |
| Shell | Quickshell 0.3.1 |
| Sky | Starlight (twinkling field) |

## Install from a terminal

On a machine that already has `git` and the
[stack it expects](DEPENDENCIES.md):

```bash
curl -fsSL https://ikswognereisj-ctrl.github.io/Nyxus-Suxyn/get.sh | bash
```

That clones the repository to `~/src/Nyxus-Suxyn` and runs a pre-flight
diagnostic. To then put the shell on the current user (a timestamped backup
is made first):

```bash
~/src/Nyxus-Suxyn/tools/apply-shell.sh
```

Prefer to inspect first? Clone by hand and run the pieces yourself:

```bash
git clone --depth 1 https://github.com/ikswognereisj-ctrl/Nyxus-Suxyn.git ~/src/Nyxus-Suxyn
~/src/Nyxus-Suxyn/tools/apply-shell.sh --preflight-only   # diagnose, change nothing
~/src/Nyxus-Suxyn/tools/apply-shell.sh                    # deploy, with rollback snapshot
```

## Update

The shell can be updated at any time, from the terminal:

```bash
~/src/Nyxus-Suxyn/tools/update-shell.sh
```

`update-shell.sh` pulls the latest commit (fast-forward only — local edits in
the clone are never discarded) and re-runs the deploy, which re-checks
pre-flight conditions and writes a fresh rollback snapshot before touching
`~/.config`. To only check whether an update exists, without changing
anything:

```bash
~/src/Nyxus-Suxyn/tools/update-shell.sh --check
```

Re-running the `get.sh` one-liner above also fast-forwards an existing clone
and re-runs pre-flight, without deploying.

## Rollback

Every deploy snapshots the previous `~/.config/quickshell` and
`~/.config/hypr` to `~/.local/share/nyxus/shell-bak-<timestamp>/` with a
`RESTORE.txt` beside them. Restoring is copying the snapshot back over
`~/.config` — the exact commands are written into that file at deploy time.

## Layout

| Path | What |
|---|---|
| `quickshell/` | Bar, Start, lock, flyout, Settings, widgets, Nyxus apps, shaders |
| `hypr/` | Hyprland, hyprlock, hypridle, hyprpaper, monitor rules, walls |
| `gtk-3.0/` `gtk-4.0/` | Font rendering and dark-theme defaults |
| `ghostty/` | Terminal palette and font |
| `docs/` | Showcase page and the `get.sh` terminal installer |
| `installer/` | Calamares branding for the ISO bake (branding only, not an ISO builder) |
| `tools/` | `apply-shell.sh` (deploy), `update-shell.sh` (update), `preflight-shell.sh` (diagnose), login repair/pin helpers |

## Working on the shell

Reload the shell with `qs ipc call nyxus reload`. Shader pipeline changes
need a targeted `SIGTERM` of the Quickshell process.

Run `tools/apply-shell.sh --preflight-only` before deploy to validate GPU,
Hyprland/Quickshell versions, PipeWire, and monitor-baseline assumptions.

## Documentation

| File | What |
|---|---|
| [`DEPENDENCIES.md`](DEPENDENCIES.md) | The stack this expects before deploy |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Scope, and how to adapt it to your own machine |
| [`SECURITY.md`](SECURITY.md) | Security model and how to report a vulnerability |
| [`LICENSE`](LICENSE) | MIT |

## Disclaimer

This is a personal build shared as-is under the MIT license — see the
[warranty and liability terms](LICENSE). It makes opinionated assumptions
about hardware, session layout, and audio routing. Nothing here installs an
operating system or modifies the boot chain; `tools/apply-shell.sh` replaces
**user-level** shell configuration on a machine that already runs the stack,
after taking a backup. Review a script before running it with `curl | bash`.

## Not in this repo

ISO builder, other machines, personal apps, local AI, and security-stack
tools.
