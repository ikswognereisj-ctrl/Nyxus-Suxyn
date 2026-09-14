#!/usr/bin/env python3
"""List system folder names on the mounted ROM library.

Maxdepth 1. Never opens or copies ROMs. sshfs can hang, so the scan
alarms out instead of blocking the shell.
"""
from __future__ import annotations

import json
import os
import signal
import sys
from pathlib import Path

ROOT = Path.home() / "Games" / "roms"
BUDGET_S = 2


class ScanTimeout(Exception):
    pass


def _on_alarm(signum, frame):
    raise ScanTimeout()


def scan(root: Path) -> dict:
    names: list[str] = []
    mounted = False
    try:
        mounted = root.is_dir()
        if not mounted:
            return {"ok": True, "root": str(root), "mounted": False, "dirs": []}
        with os.scandir(root) as it:
            for ent in it:
                if ent.name.startswith("."):
                    continue
                try:
                    if ent.is_dir(follow_symlinks=False):
                        names.append(ent.name)
                except OSError:
                    continue
    except ScanTimeout:
        return {
            "ok": False,
            "root": str(root),
            "mounted": mounted,
            "dirs": [],
            "error": "timeout",
        }
    except OSError as exc:
        return {
            "ok": False,
            "root": str(root),
            "mounted": False,
            "dirs": [],
            "error": str(exc),
        }
    names.sort(key=str.lower)
    return {"ok": True, "root": str(root), "mounted": True, "dirs": names}


def main() -> int:
    old = signal.signal(signal.SIGALRM, _on_alarm)
    signal.alarm(BUDGET_S)
    try:
        result = scan(ROOT)
    finally:
        signal.alarm(0)
        signal.signal(signal.SIGALRM, old)
    json.dump(result, sys.stdout, ensure_ascii=True)
    sys.stdout.write("\n")
    return 0 if result.get("ok") else 1


if __name__ == "__main__":
    raise SystemExit(main())
