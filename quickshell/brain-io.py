#!/usr/bin/env python3
"""Ask the local Brain. Same core as GTK nyxus_brain.py (nothing leaves the machine)."""
from __future__ import annotations

import json
import subprocess
import sys


def cmd_ask(q: str) -> None:
    r = subprocess.run(
        ["python3", "/opt/nyxus/nyxus_brain.py", "--ask", q],
        capture_output=True, text=True, timeout=180,
    )
    out = (r.stdout or "").strip()
    err = (r.stderr or "").strip()
    json.dump({
        "ok": r.returncode == 0 and bool(out),
        "text": out or err or "No answer.",
    }, sys.stdout)


def cmd_reindex() -> None:
    r = subprocess.run(
        ["python3", "/opt/nyxus/nyxus_brain.py", "--reindex"],
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
