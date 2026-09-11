#!/usr/bin/env python3
"""bsdtar listing + extract for Archive.qml. Same rules as GTK nyxus_archive.py."""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

TAR = shutil.which("bsdtar") or shutil.which("tar")


def _run(cmd, timeout=60):
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout or "", r.stderr or ""
    except Exception as e:
        return 1, "", str(e)


def _children(entries, cwd, filt, sort):
    pre = cwd or ""
    dirs = {}
    files = []
    q = (filt or "").lower()
    for member, size, mode, when in entries:
        if pre and not member.startswith(pre):
            continue
        rest = member[len(pre):].lstrip("/")
        if not rest:
            continue
        if "/" in rest.rstrip("/"):
            top = rest.split("/", 1)[0]
            if q and q not in top.lower():
                continue
            dirs[top] = dirs.get(top, 0) + size
        elif rest.endswith("/"):
            name = rest.rstrip("/")
            if q and q not in name.lower():
                continue
            dirs.setdefault(name, 0)
        else:
            if q and q not in rest.lower():
                continue
            files.append({"name": rest, "member": member, "size": size,
                          "mode": mode, "when": when, "dir": False})
    if sort == "size":
        files.sort(key=lambda f: f["size"], reverse=True)
    elif sort == "when":
        files.sort(key=lambda f: f["when"], reverse=True)
    else:
        files.sort(key=lambda f: f["name"].lower())
    out = [{"name": n, "member": (pre.rstrip("/") + "/" + n).lstrip("/"),
            "size": s, "mode": "d", "when": "", "dir": True}
           for n, s in sorted(dirs.items())]
    return out + files


def cmd_list(path: str, cwd: str = "", filt: str = "", sort: str = "name") -> None:
    if not TAR:
        json.dump({"ok": False, "error": "bsdtar is not installed."}, sys.stdout)
        return
    p = Path(path).expanduser()
    if not p.is_file():
        json.dump({"ok": False, "error": "not a file"}, sys.stdout)
        return
    rc, out, err = _run([TAR, "-tvf", str(p)], timeout=60)
    if rc != 0:
        first = (err or "").strip().splitlines()[:1]
        json.dump({"ok": False, "error": first[0] if first else "Not an archive I can read."}, sys.stdout)
        return
    entries = []
    for line in out.splitlines():
        parts = line.split(None, 8)
        if len(parts) < 9:
            continue
        try:
            size = int(parts[4])
        except ValueError:
            size = 0
        entries.append((parts[8], size, parts[0], " ".join(parts[5:8])))
    rows = _children(entries, cwd, filt, sort)
    json.dump({
        "ok": True,
        "path": str(p.resolve()),
        "name": p.name,
        "bytes": p.stat().st_size,
        "count": len(entries),
        "cwd": cwd,
        "entries": rows,
    }, sys.stdout)


def _dest_folder(archive: Path, dest_parent: Path) -> Path:
    stem = archive.name
    for suf in (".tar.gz", ".tar.bz2", ".tar.xz", ".tar.zst", ".tgz", ".tbz2"):
        if stem.lower().endswith(suf):
            stem = stem[: -len(suf)]
            break
    else:
        stem = archive.stem
    return dest_parent / stem


def cmd_extract(path: str, dest: str = "") -> None:
    if not TAR:
        json.dump({"ok": False, "error": "bsdtar is not installed."}, sys.stdout)
        return
    p = Path(path).expanduser()
    if dest:
        target = Path(dest).expanduser()
    else:
        target = _dest_folder(p, p.parent)
    try:
        target.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        json.dump({"ok": False, "error": str(e)}, sys.stdout)
        return
    rc, out, err = _run([TAR, "-xf", str(p), "-C", str(target)], timeout=600)
    json.dump({
        "ok": rc == 0,
        "dest": str(target),
        "error": (err or out or "")[-400:] if rc else "",
    }, sys.stdout)


def cmd_pick() -> None:
    try:
        r = subprocess.run(
            ["zenity", "--file-selection", "--title=Open an archive",
             "--file-filter=Archives | *.zip *.tar *.tar.gz *.tgz *.tar.xz *.tar.bz2 *.7z *.rar *.gz"],
            capture_output=True, text=True, timeout=300,
        )
        path = (r.stdout or "").strip()
    except Exception:
        path = ""
    if path and Path(path).is_file():
        cmd_list(path)
    else:
        json.dump({"ok": False, "entries": []}, sys.stdout)


def cmd_compress(folder: str) -> None:
    src = Path(folder).expanduser()
    if not src.is_dir():
        json.dump({"ok": False, "error": "not a folder"}, sys.stdout)
        return
    if not TAR:
        json.dump({"ok": False, "error": "bsdtar is not installed."}, sys.stdout)
        return
    out = src.parent / (src.name + ".tar.gz")
    rc, _o, err = _run([TAR, "-czf", str(out), "-C", str(src.parent), src.name], timeout=600)
    json.dump({"ok": rc == 0, "path": str(out), "error": err[-300:] if rc else ""}, sys.stdout)


if __name__ == "__main__":
    op = sys.argv[1] if len(sys.argv) > 1 else "pick"
    args = sys.argv[2:]
    if op == "list" and args:
        cmd_list(args[0], args[1] if len(args) > 1 else "",
                 args[2] if len(args) > 2 else "",
                 args[3] if len(args) > 3 else "name")
    elif op == "extract" and args:
        cmd_extract(args[0], args[1] if len(args) > 1 else "")
    elif op == "compress" and args:
        cmd_compress(args[0])
    else:
        cmd_pick()
