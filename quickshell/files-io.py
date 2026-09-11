#!/usr/bin/env python3
"""Places + directory listing for Files.qml. Same bookmarks as GTK Files."""
from __future__ import annotations

import json
import os
import shutil
import stat
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home()
TRASH_FILES = HOME / ".local/share/Trash/files"
TRASH_INFO = HOME / ".local/share/Trash/info"
DISCOVERED_CAP = 6


def _xdg_user_dirs() -> dict[str, Path]:
    out: dict[str, Path] = {}
    cfg = HOME / ".config/user-dirs.dirs"
    try:
        for line in cfg.read_text(encoding="utf-8", errors="replace").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            v = v.strip().strip('"').replace("$HOME", str(HOME))
            out[k] = Path(v)
    except OSError:
        pass
    return out


def places() -> list[dict]:
    xdg = _xdg_user_dirs()

    def user_dir(key: str, fallback: str) -> Path:
        p = xdg.get(key)
        if p is not None and p != HOME:
            return p
        return HOME / fallback

    known = [
        ("Home", str(HOME)),
        ("Desktop", str(user_dir("XDG_DESKTOP_DIR", "Desktop"))),
        ("Documents", str(user_dir("XDG_DOCUMENTS_DIR", "Documents"))),
        ("Downloads", str(user_dir("XDG_DOWNLOAD_DIR", "Downloads"))),
        ("Pictures", str(user_dir("XDG_PICTURES_DIR", "Pictures"))),
        ("Music", str(user_dir("XDG_MUSIC_DIR", "Music"))),
        ("Videos", str(user_dir("XDG_VIDEOS_DIR", "Videos"))),
    ]
    out = []
    seen: set[str] = set()
    for label, raw in known:
        p = Path(raw)
        try:
            if not p.is_dir():
                continue
            if p != HOME:
                try:
                    if next(os.scandir(p), None) is None:
                        continue
                except OSError:
                    continue
            out.append({"label": label, "path": str(p), "kind": "place"})
            seen.add(os.path.realpath(p))
        except OSError:
            continue
    rest = []
    try:
        for entry in HOME.iterdir():
            if entry.name.startswith("."):
                continue
            try:
                if not entry.is_dir():
                    continue
                real = os.path.realpath(entry)
            except OSError:
                continue
            if real in seen:
                continue
            seen.add(real)
            rest.append(entry)
    except OSError:
        pass
    rest.sort(key=lambda p: (p.name.lower(), p.name))
    for entry in rest[:DISCOVERED_CAP]:
        out.append({"label": entry.name, "path": str(entry), "kind": "folder"})
    out.append({"label": "Trash", "path": "trash:///", "kind": "trash"})
    out.append({"label": "Root", "path": "/", "kind": "root"})
    return out


def _fmt_size(n: int) -> str:
    if n < 1024:
        return f"{n} B"
    for unit, div in (("KB", 1024), ("MB", 1024 ** 2), ("GB", 1024 ** 3), ("TB", 1024 ** 4)):
        if n < div * 1024 or unit == "TB":
            v = n / div
            return f"{v:.0f} {unit}" if v >= 10 else f"{v:.1f} {unit}"
    return f"{n} B"


def _list_dir(path: Path) -> dict:
    folders, files = [], []
    try:
        entries = list(os.scandir(path))
    except OSError as e:
        return {"ok": False, "error": str(e), "path": str(path), "entries": [],
                "folders": 0, "files": 0, "free": ""}
    for ent in entries:
        if ent.name.startswith("."):
            continue
        try:
            st = ent.stat(follow_symlinks=False)
            is_dir = stat.S_ISDIR(st.st_mode)
        except OSError:
            continue
        rec = {
            "name": ent.name,
            "path": str(Path(path) / ent.name),
            "dir": is_dir,
            "size": 0 if is_dir else int(st.st_size),
            "sizeText": "—" if is_dir else _fmt_size(int(st.st_size)),
            "mtime": int(st.st_mtime),
            "mtimeText": time.strftime("%Y-%m-%d %H:%M", time.localtime(st.st_mtime)),
        }
        (folders if is_dir else files).append(rec)
    folders.sort(key=lambda r: r["name"].lower())
    files.sort(key=lambda r: r["name"].lower())
    entries_out = folders + files
    free = ""
    try:
        du = shutil.disk_usage(path)
        free = f"{du.free / (1024 ** 3):.1f} GB free"
    except OSError:
        pass
    return {
        "ok": True,
        "path": str(path),
        "label": "Home" if path == HOME else path.name or str(path),
        "entries": entries_out,
        "folders": len(folders),
        "files": len(files),
        "free": free,
    }


def _list_trash() -> dict:
    entries = []
    if TRASH_FILES.is_dir():
        try:
            for ent in os.scandir(TRASH_FILES):
                try:
                    st = ent.stat(follow_symlinks=False)
                    is_dir = stat.S_ISDIR(st.st_mode)
                except OSError:
                    continue
                entries.append({
                    "name": ent.name,
                    "path": str(Path(TRASH_FILES) / ent.name),
                    "dir": is_dir,
                    "size": 0 if is_dir else int(st.st_size),
                    "sizeText": "—" if is_dir else _fmt_size(int(st.st_size)),
                    "mtime": int(st.st_mtime),
                    "mtimeText": time.strftime("%Y-%m-%d %H:%M", time.localtime(st.st_mtime)),
                })
        except OSError:
            pass
    entries.sort(key=lambda r: r["name"].lower())
    return {
        "ok": True,
        "path": "trash:///",
        "label": "Trash",
        "entries": entries,
        "folders": sum(1 for e in entries if e["dir"]),
        "files": sum(1 for e in entries if not e["dir"]),
        "free": "",
    }


def cmd_list(raw: str) -> None:
    if raw in ("trash:///", "trash:"):
        json.dump(_list_trash(), sys.stdout)
        return
    p = Path(os.path.expanduser(raw or str(HOME))).resolve()
    json.dump(_list_dir(p), sys.stdout)


def cmd_mkdir(raw: str) -> None:
    p = Path(os.path.expanduser(raw))
    p.mkdir(parents=False, exist_ok=False)
    json.dump({"ok": True, "path": str(p)}, sys.stdout)


def cmd_trash(raw: str) -> None:
    p = Path(os.path.expanduser(raw))
    r = subprocess.run(["gio", "trash", str(p)], capture_output=True, text=True)
    if r.returncode != 0:
        dest = TRASH_FILES / p.name
        TRASH_FILES.mkdir(parents=True, exist_ok=True)
        shutil.move(str(p), str(dest))
    json.dump({"ok": True}, sys.stdout)


def cmd_open(raw: str) -> None:
    subprocess.Popen(["xdg-open", raw], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    json.dump({"ok": True}, sys.stdout)


if __name__ == "__main__":
    op = sys.argv[1] if len(sys.argv) > 1 else "places"
    arg = sys.argv[2] if len(sys.argv) > 2 else ""
    if op == "places":
        json.dump({"places": places()}, sys.stdout)
    elif op == "list":
        cmd_list(arg or str(HOME))
    elif op == "mkdir":
        cmd_mkdir(arg)
    elif op == "trash":
        cmd_trash(arg)
    elif op == "open":
        cmd_open(arg)
    else:
        json.dump({"ok": False, "error": "unknown"}, sys.stdout)
