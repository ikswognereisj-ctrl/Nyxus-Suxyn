# Contributing

Thank you for the interest. Before opening an issue or a pull request,
please read the scope below — it decides what can be accepted.

## Scope

**Nyxus Suxyn is a single-machine personal shell**, tuned for one Alienware
15 (`eDP-1`, 1920×1200 @ 165 Hz). It is public as a **showcase / reference
build**, not as a distribution or a drop-in theme that fits every desktop.

### In scope

- Bug reports with logs, reproduction steps, and what you expected instead.
- QML/shell correctness fixes.
- Shader correctness fixes.
- Portability improvements that do not regress the target machine.
- Documentation corrections.

### Out of scope

- "Make it work on my ThinkPad / multi-monitor / NVIDIA" feature requests.
- Turning the repository into a full distribution or ISO builder.
- Feature requests for applications unrelated to this desktop.

If you want this desktop on your own machine, **fork it** — that is the
intended path. [`DEPENDENCIES.md`](DEPENDENCIES.md) lists the stack it
expects, and `tools/apply-shell.sh --preflight-only` checks a machine
against those expectations before anything is deployed.

## Conventions

These are enforced by the shape of the tree; matching them keeps a change
reviewable:

- **QML** — `pragma ComponentBehavior: Bound`, reactive bindings, singletons
  for shared state (`Theme`, `Prefs`, `Sys`, …). New `.qml` files must be
  declared in `quickshell/qmldir` or they do not exist as types at runtime.
- **Shell scripts** — `#!/usr/bin/env bash`, `set -uo pipefail`, quoted
  expansions.
- **Paths** — no hardcoded user/home paths or real coordinates. Config goes
  to `~/.config`, state to `~/.local/share/nyxus`, caches to
  `~/.cache/nyxus`.
- **Comments** — explain *why*, not what. This repository reads its git
  history and comments as a decision log; open threads carry the existing
  `WIP-`/`TRK-` markers.
- **Shaders** — after editing a `.frag`, rebuild the `.qsb` beside it with
  `quickshell/shaders/build.sh` (requires `qt6-shadertools`).

## Reporting bugs

Include: the component (bar / lock / Settings page / shader / script), what
you did, what happened, and the relevant log lines. The shell log is at
`/tmp/nyxus-shell.log` on a running session; Hyprland's log is under
`$XDG_RUNTIME_DIR/hypr/`.

## Security issues

Do not open a public issue with exploit details. See
[`SECURITY.md`](SECURITY.md).

## License

By contributing you agree that your contributions are licensed under the
repository's [MIT license](LICENSE).
