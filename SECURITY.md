# Security Policy

## Scope

Nyxus Suxyn is the user-level shell layer of one machine: Quickshell
configuration, Hyprland configuration, helper scripts, and documentation.
It is not an operating system, an ISO builder, or a privileged service, and
nothing in this repository requests root except the two explicitly
sudo-guarded login-repair helpers in `tools/` (`nyxus-pin-gtk-greeter`,
`nyxus-repair-at-root`), which are machine-specific recovery tools, not part
of the normal install path.

## What this repository does to a system

- `tools/apply-shell.sh` copies `quickshell/`, `hypr/`, `gtk-3.0/`,
  `gtk-4.0/`, and `ghostty/` into the **current user's** `~/.config`, after a
  timestamped backup. It does not touch `/etc`, greetd, initramfs, or the
  boot chain.
- `docs/get.sh` clones this repository over HTTPS and runs a read-only
  pre-flight diagnostic. It changes nothing outside the clone.
- Runtime helpers (`quickshell/*-io.py`, `hypr/scripts/*.sh`) read and write
  state under `~/.config/nyxus`, `~/.local/share/nyxus`, and `~/.cache/nyxus`.
- Session locking authenticates through PAM via `hyprlock` / the Quickshell
  lock surface; no credentials are stored, logged, or transmitted by anything
  in this repository.

## Reporting a vulnerability

This is a personal project maintained by one person. If you believe you have
found a security issue — for example a script that writes outside the paths
listed above, a shell-injection vector in a helper, or a lock-screen
weakness — please **do not** open a public issue with exploit details.

Instead, open a
[GitHub security advisory](https://github.com/ikswognereisj-ctrl/Nyxus-Suxyn/security/advisories/new)
(privately visible to the maintainer) or open an issue that says only that a
security concern exists and asks for a private contact channel.

There is no formal SLA. Reports are read and answered on a best-effort
basis. Please include the file and line, the observed behavior, and the
impact you believe is possible.

## Out of scope

- Issues that require an already-compromised local account.
- The machine-specific recovery helpers being able to modify the system when
  run with `sudo` — that is their documented purpose; they are interactive,
  verbose about what they restore, and never run by the install path.
- Vulnerabilities in upstream dependencies (Hyprland, Quickshell, PipeWire,
  Qt, …). Report those to their respective projects.

## Supply-chain notes

- No build step in this repository downloads or executes third-party code at
  install time. `get.sh` fetches only this repository over HTTPS from
  GitHub.
- `.gitignore` excludes common secret material (`*.pem`, `id_rsa*`,
  `github_pat_*`, `*token*`, `.env`) so credentials are not committed by
  accident.
