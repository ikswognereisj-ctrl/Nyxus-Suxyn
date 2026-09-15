#!/usr/bin/env python3
"""Ask the local Brain. Same core as GTK nyxus_brain.py (nothing leaves the machine)."""
from __future__ import annotations

import json
import os
import subprocess
import sys

ENGINE = "/opt/nyxus/nyxus_brain.py"

# TRK-4143 — the engine is not part of Nyxus. It is installed separately and
# is absent on a stock system, so `subprocess.run` was handing the interpreter
# error straight to the chat window:
#
#     python3: can't open file '/opt/nyxus/nyxus_brain.py':
#     [Errno 2] No such file or directory
#
# The Launcher tile and Bus.openBrain() are now gated on this same file, so
# this branch should be unreachable from the UI. It stays anyway: a traceback
# is never the right answer to a typed question, and `qs ipc` can still reach
# Brain directly.
def _missing() -> None:
    json.dump({
        "ok": False,
        "text": "The Brain engine is not installed on this system.",
    }, sys.stdout)


def cmd_ask(q: str) -> None:
    if not os.access(ENGINE, os.R_OK):
        return _missing()
    r = subprocess.run(
        ["python3", ENGINE, "--ask", q],
        capture_output=True, text=True, timeout=180,
    )
    out = (r.stdout or "").strip()
    err = (r.stderr or "").strip()
    json.dump({
        "ok": r.returncode == 0 and bool(out),
        "text": out or err or "No answer.",
    }, sys.stdout)


def cmd_reindex() -> None:
    if not os.access(ENGINE, os.R_OK):
        return _missing()
    r = subprocess.run(
        ["python3", ENGINE, "--reindex"],
        capture_output=True, text=True, timeout=180,
    )
    json.dump({"ok": r.returncode == 0, "text": (r.stdout or r.stderr or "").strip()[-400:]}, sys.stdout)


if __name__ == "__main__":
    op = sys.argv[1] if len(sys.argv) > 1 else "ask"
    if op == "reindex":
        cmd_reindex()
    else:
        q = " ".join(sys.argv[2:] if op == "ask" else sys.argv[1:]).strip()
        if not q:
            json.dump({"ok": False, "text": "Ask something."}, sys.stdout)
        else:
            cmd_ask(q)
