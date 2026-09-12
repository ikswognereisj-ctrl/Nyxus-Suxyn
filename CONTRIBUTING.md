# Contributing / scope

Thanks for the interest — but a heads-up on what this repo **is** first.

**Nyxus Suxyn is a single-machine personal shell**, tuned for one Alienware 15
(`eDP-1`, 1920×1200 @ 165 Hz). It is public as a **showcase / reference
build**, not as a distribution or a drop-in theme that fits every desktop.

## What that means for issues & PRs

- **Welcome:** bug reports with logs, QML/shell correctness fixes, shader
  fixes, portability improvements that don't regress the target machine,
  docs corrections.
- **Probably out of scope:** "make it work on my ThinkPad / multi-monitor /
  NVIDIA" feature requests, requests to turn it into a full distro/ISO, or
  app feature requests unrelated to this desktop.

If you want to adapt it to your own machine, **fork it** — that's the
intended path. See `DEPENDENCIES.md` for the stack it expects and run
`tools/apply-shell.sh --preflight-only` before anything else.

## Conventions

- QML: `pragma ComponentBehavior: Bound`, reactive bindings, singletons for
  shared state (`Theme`, `Prefs`, `Sys`, …).
- Shell scripts: `#!/usr/bin/env bash`, `set -uo pipefail`, quote expansions.
- Don't hardcode user/home paths or real coordinates — keep it adaptable.
- Explain *why* in comments (this repo reads its git history as a decision
  log); tag open threads with the existing `WIP-`/`TRK-` markers.
