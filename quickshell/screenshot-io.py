#!/usr/bin/env python3
"""grim/slurp/hyprpicker/record for Screenshot.qml. Same folder as GTK."""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

PIC_DIR = Path.home() / "Pictures" / "Screenshots"


def have(cmd: str) -> bool:
    return shutil.which(cmd) is not None


def shutter_path() -> Path:
    PIC_DIR.mkdir(parents=True, exist_ok=True)
    return PIC_DIR / f"nyxus-{datetime.now():%Y%m%d-%H%M%S}.png"


def _run(cmd, timeout=60):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout or "").strip(), (r.stderr or "").strip()
    except Exception as e:
        return 1, "", str(e)


def cmd_capture(mode: str) -> None:
    if not have("grim"):
        json.dump({"ok": False, "error": "grim is not installed"}, sys.stdout)
        return
    out = shutter_path()
    geom = ""
    if mode == "region":
        if not have("slurp"):
            json.dump({"ok": False, "error": "slurp is not installed"}, sys.stdout)
            return
        rc, geom, err = _run(["slurp"], timeout=120)
        if rc != 0 or not geom:
            json.dump({"ok": False, "error": "cancelled"}, sys.stdout)
            return
        rc, _, err = _run(["grim", "-g", geom, str(out)])
    elif mode == "window":
        rc, raw, err = _run(["hyprctl", "activewindow", "-j"])
        try:
            w = json.loads(raw)
            at, sz = w.get("at") or [0, 0], w.get("size") or [0, 0]
            geom = f"{int(at[0])},{int(at[1])} {int(sz[0])}x{int(sz[1])}"
        except Exception:
            json.dump({"ok": False, "error": "could not determine active window"}, sys.stdout)
            return
        rc, _, err = _run(["grim", "-g", geom, str(out)])
    else:
        rc, _, err = _run(["grim", str(out)])
    if rc != 0 or not out.is_file():
        json.dump({"ok": False, "error": err or "grim failed"}, sys.stdout)
        return
    if have("wl-copy"):
        subprocess.Popen(["wl-copy", "-t", "image/png"], stdin=open(out, "rb"),
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    json.dump({"ok": True, "path": str(out)}, sys.stdout)


def cmd_recents() -> None:
    PIC_DIR.mkdir(parents=True, exist_ok=True)
    today = datetime.now().strftime("%Y%m%d")
    shots = []
    for p in sorted(PIC_DIR.glob("*.png"), key=lambda x: x.stat().st_mtime, reverse=True):
        if today in p.name or datetime.fromtimestamp(p.stat().st_mtime).strftime("%Y%m%d") == today:
            shots.append({"path": str(p), "name": p.name, "mtime": int(p.stat().st_mtime)})
        if len(shots) >= 24:
            break
    json.dump({"ok": True, "shots": shots, "dir": str(PIC_DIR)}, sys.stdout)


def cmd_eyedrop() -> None:
    if not have("hyprpicker"):
        json.dump({"ok": False, "error": "hyprpicker is not installed"}, sys.stdout)
        return
    rc, out, err = _run(["hyprpicker", "-a", "-n"], timeout=120)
    json.dump({"ok": rc == 0 and bool(out), "color": out, "error": err}, sys.stdout)


def cmd_record(kind: str) -> None:
    rec = shutil.which("nyxus-record") or "/usr/local/bin/nyxus-record"
    if not Path(rec).exists():
        json.dump({"ok": False, "error": "nyxus-record not installed"}, sys.stdout)
        return
    try:
        subprocess.Popen([rec, kind], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        json.dump({"ok": True}, sys.stdout)
    except OSError as e:
        json.dump({"ok": False, "error": str(e)}, sys.stdout)


if __name__ == "__main__":
    op = sys.argv[1] if len(sys.argv) > 1 else "recents"
    if op in ("region", "window", "fullscreen"):
        cmd_capture(op)
    elif op == "eyedrop":
        cmd_eyedrop()
    elif op == "record" and len(sys.argv) > 2:
        cmd_record(sys.argv[2])
    else:
        cmd_recents()
