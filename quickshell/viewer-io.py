#!/usr/bin/env python3
"""Folder listing + memory for Viewer.qml. Same job as GTK nyxus_viewer.py."""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

EXTS = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".tif", ".tiff",
        ".avif", ".heif", ".heic", ".svg", ".ico"}
CONFIG = Path.home() / ".config/nyxus/viewer.json"
SLIDESHOW_CHOICES = (2, 4, 8, 15, 30)


def _cfg() -> dict:
    cfg = {
        "info_visible": False,
        "strip_visible": True,
        "zoom_mode": "fit",
        "slideshow_seconds": 4,
        "last_file": "",
        "rotations": {},
    }
    try:
        raw = json.loads(CONFIG.read_text())
    except (OSError, json.JSONDecodeError, TypeError, ValueError):
        return cfg
    if not isinstance(raw, dict):
        return cfg
    if isinstance(raw.get("info_visible"), bool):
        cfg["info_visible"] = raw["info_visible"]
    if isinstance(raw.get("strip_visible"), bool):
        cfg["strip_visible"] = raw["strip_visible"]
    if raw.get("zoom_mode") in ("fit", "actual"):
        cfg["zoom_mode"] = raw["zoom_mode"]
    try:
        cfg["slideshow_seconds"] = min(
            SLIDESHOW_CHOICES, key=lambda c: abs(c - int(raw.get("slideshow_seconds"))))
    except (TypeError, ValueError):
        pass
    if isinstance(raw.get("last_file"), str):
        cfg["last_file"] = raw["last_file"]
    rots = raw.get("rotations")
    if isinstance(rots, dict):
        cfg["rotations"] = {
            str(k): int(v) for k, v in rots.items()
            if isinstance(v, int) and not isinstance(v, bool) and int(v) in (90, 180, 270)
        }
    return cfg


def _save(cfg: dict) -> None:
    try:
        CONFIG.parent.mkdir(parents=True, exist_ok=True)
        tmp = CONFIG.with_suffix(".json.tmp")
        tmp.write_text(json.dumps(cfg, indent=2) + "\n")
        os.replace(tmp, CONFIG)
    except OSError:
        pass


def _list(folder: Path) -> list[str]:
    try:
        return sorted(
            str(p) for p in folder.iterdir()
            if p.is_file() and p.suffix.lower() in EXTS
        )
    except OSError:
        return []


def cmd_open(path: str) -> None:
    p = Path(path).expanduser()
    cfg = _cfg()
    if p.is_dir():
        files = _list(p)
        idx = 0
        current = files[0] if files else ""
    elif p.is_file():
        files = _list(p.parent)
        current = str(p.resolve())
        idx = files.index(current) if current in files else 0
    else:
        json.dump({"ok": False, "error": "not found", "files": []}, sys.stdout)
        return
    if current:
        cfg["last_file"] = current
        _save(cfg)
    json.dump({
        "ok": True,
        "files": files,
        "index": idx,
        "current": current,
        "folder": str((p if p.is_dir() else p.parent).resolve()),
        "strip": cfg["strip_visible"],
        "info": cfg["info_visible"],
        "zoom": cfg["zoom_mode"],
        "interval": cfg["slideshow_seconds"],
        "rot": (cfg["rotations"] or {}).get(current, 0),
    }, sys.stdout)


def cmd_last() -> None:
    cfg = _cfg()
    last = cfg.get("last_file") or ""
    if last and Path(last).is_file():
        cmd_open(last)
        return
    json.dump({
        "ok": True, "files": [], "index": 0, "current": "",
        "folder": "", "strip": cfg["strip_visible"], "info": cfg["info_visible"],
        "zoom": cfg["zoom_mode"], "interval": cfg["slideshow_seconds"], "rot": 0,
    }, sys.stdout)


def cmd_save(path: str, strip: str, info: str, zoom: str, interval: str, rot: str) -> None:
    cfg = _cfg()
    if path:
        cfg["last_file"] = path
        try:
            r = int(rot)
            if r in (90, 180, 270):
                rots = dict(cfg.get("rotations") or {})
                rots[path] = r
                if len(rots) > 200:
                    rots = dict(list(rots.items())[-200:])
                cfg["rotations"] = rots
            elif r == 0:
                rots = dict(cfg.get("rotations") or {})
                rots.pop(path, None)
                cfg["rotations"] = rots
        except ValueError:
            pass
    cfg["strip_visible"] = strip == "1"
    cfg["info_visible"] = info == "1"
    if zoom in ("fit", "actual"):
        cfg["zoom_mode"] = zoom
    try:
        cfg["slideshow_seconds"] = min(SLIDESHOW_CHOICES, key=lambda c: abs(c - int(interval)))
    except ValueError:
        pass
    _save(cfg)
    json.dump({"ok": True}, sys.stdout)


def cmd_stat(path: str) -> None:
    p = Path(path).expanduser()
    if not p.is_file():
        json.dump({"ok": False}, sys.stdout)
        return
    st = p.stat()
    exif: dict = {}
    width = height = 0
    try:
        from PIL import Image, ExifTags
        with Image.open(p) as im:
            width, height = im.size
            raw = im.getexif()
            if raw:
                tags = {ExifTags.TAGS.get(k, str(k)): v for k, v in raw.items()}
                for key in ("Make", "Model", "DateTimeOriginal", "DateTime",
                            "LensModel", "FNumber", "ExposureTime",
                            "ISOSpeedRatings", "FocalLength", "Software"):
                    if key in tags and tags[key] not in (None, ""):
                        exif[key] = str(tags[key])
    except Exception:
        pass
    json.dump({
        "ok": True,
        "name": p.name,
        "path": str(p.resolve()),
        "bytes": st.st_size,
        "mtime": int(st.st_mtime),
        "ext": p.suffix.lower(),
        "width": width,
        "height": height,
        "exif": exif,
    }, sys.stdout)


def cmd_pick() -> None:
    rc, out, _ = 1, "", ""
    try:
        r = subprocess.run(
            ["zenity", "--file-selection", "--title=Open a picture",
             "--file-filter=Pictures | *.png *.jpg *.jpeg *.webp *.gif *.bmp *.svg *.tif *.tiff"],
            capture_output=True, text=True, timeout=300,
        )
        rc, out = r.returncode, r.stdout or ""
    except Exception:
        pass
    path = out.strip()
    if path and Path(path).exists():
        cmd_open(path)
    else:
        json.dump({"ok": False, "files": [], "current": ""}, sys.stdout)


def cmd_trash(path: str) -> None:
    p = Path(path).expanduser()
    if not p.is_file():
        json.dump({"ok": False}, sys.stdout)
        return
    folder = p.parent
    try:
        r = subprocess.run(["gio", "trash", str(p)], capture_output=True, timeout=10)
        ok = r.returncode == 0
    except Exception:
        ok = False
    if not ok:
        try:
            trash = Path.home() / ".local/share/Trash/files"
            trash.mkdir(parents=True, exist_ok=True)
            shutil.move(str(p), str(trash / p.name))
            ok = True
        except OSError:
            ok = False
    files = _list(folder) if ok else []
    json.dump({"ok": ok, "files": files, "folder": str(folder)}, sys.stdout)


def cmd_wallpaper(path: str) -> None:
    p = Path(path).expanduser()
    if not p.is_file():
        json.dump({"ok": False}, sys.stdout)
        return
    bin_ = shutil.which("nyxus-set-wallpaper") or "/usr/local/bin/nyxus-set-wallpaper"
    try:
        r = subprocess.run([bin_, str(p)], capture_output=True, timeout=20)
        json.dump({"ok": r.returncode == 0}, sys.stdout)
    except Exception as e:
        json.dump({"ok": False, "error": str(e)}, sys.stdout)


if __name__ == "__main__":
    op = sys.argv[1] if len(sys.argv) > 1 else "last"
    args = sys.argv[2:]
    if op == "open" and args:
        cmd_open(args[0])
    elif op == "stat" and args:
        cmd_stat(args[0])
    elif op == "save" and args:
        cmd_save(args[0],
                 args[1] if len(args) > 1 else "1",
                 args[2] if len(args) > 2 else "0",
                 args[3] if len(args) > 3 else "fit",
                 args[4] if len(args) > 4 else "4",
                 args[5] if len(args) > 5 else "0")
    elif op == "pick":
        cmd_pick()
    elif op == "trash" and args:
        cmd_trash(args[0])
    elif op == "wallpaper" and args:
        cmd_wallpaper(args[0])
    else:
        cmd_last()
