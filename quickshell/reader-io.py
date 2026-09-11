#!/usr/bin/env python3
"""PDF info/render for Reader.qml. Same poppler CLI as GTK nyxus_reader.py."""
from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

STORE = Path.home() / ".config/nyxus/reader.json"
CACHE = Path(os.environ.get("XDG_CACHE_HOME") or (Path.home() / ".cache")) / "nyxus" / "reader"


def _run(cmd: list[str], timeout: int = 30) -> tuple[int, str, str]:
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout or "", r.stderr or ""
    except Exception as e:
        return 1, "", str(e)


def _load_store() -> dict:
    try:
        raw = json.loads(STORE.read_text())
        return raw.get("docs") if isinstance(raw, dict) else {}
    except (OSError, json.JSONDecodeError, TypeError):
        return {}


def _save_store(docs: dict) -> None:
    try:
        STORE.parent.mkdir(parents=True, exist_ok=True)
        items = sorted(
            docs.items(),
            key=lambda kv: float((kv[1] or {}).get("seen") or 0),
            reverse=True,
        )[:200]
        tmp = STORE.with_suffix(".json.tmp")
        tmp.write_text(json.dumps({"version": 1, "docs": dict(items)}, indent=0) + "\n")
        os.replace(tmp, STORE)
    except Exception:
        pass


def _key(path: Path) -> str:
    try:
        st = path.stat()
        return f"{path.resolve()}::{st.st_size}"
    except OSError:
        return str(path)


def cmd_info(path: str) -> None:
    p = Path(path).expanduser()
    if not p.is_file():
        json.dump({"ok": False, "error": "not a file"}, sys.stdout)
        return
    rc, out, err = _run(["pdfinfo", "-f", "1", "-l", "999999", str(p)])
    if rc != 0:
        low = (err or "").lower()
        json.dump({
            "ok": False,
            "error": "password" if ("password" in low or "encrypted" in low) else (err.strip() or "pdfinfo failed"),
            "password": "password" in low or "encrypted" in low,
        }, sys.stdout)
        return
    pages = 0
    title = p.name
    sizes: dict[int, list[float]] = {}
    meta = []
    for line in out.splitlines():
        m = re.match(r"Page\s+(\d+)\s+size:\s+([\d.]+) x ([\d.]+)", line)
        if m:
            sizes[int(m.group(1))] = [float(m.group(2)), float(m.group(3))]
            continue
        if ":" not in line:
            continue
        k, v = line.split(":", 1)
        k, v = k.strip(), v.strip()
        if k == "Pages":
            try:
                pages = int(v)
            except ValueError:
                pass
        elif k == "Title" and v:
            title = v
        if k in ("Title", "Author", "Subject", "Pages", "Page size", "File size", "PDF version"):
            if v:
                meta.append({"k": k, "v": v})
    docs = _load_store()
    st = docs.get(_key(p)) or {}
    json.dump({
        "ok": True,
        "path": str(p.resolve()),
        "name": p.name,
        "title": title,
        "pages": pages,
        "width": (sizes.get(1) or [612, 792])[0],
        "height": (sizes.get(1) or [612, 792])[1],
        "page": max(1, min(int(st.get("page") or 1), pages or 1)),
        "zoom": st.get("zoom") or "width",
        "rot": int(st.get("rot") or 0),
        "sidebar": bool(st.get("sidebar")),
        "sidePage": st.get("side_page") or "pages",
        "marks": st.get("marks") or [],
        "meta": meta,
    }, sys.stdout)


def cmd_render(path: str, page: str, dpi: str, rot: str) -> None:
    p = Path(path).expanduser()
    try:
        n = max(1, int(page))
        r = int(dpi)
        rotation = int(rot) if int(rot) in (0, 90, 180, 270) else 0
    except ValueError:
        json.dump({"ok": False, "error": "bad render"}, sys.stdout)
        return
    r = max(36, min(r, 220))
    CACHE.mkdir(parents=True, exist_ok=True)
    h = hashlib.sha1(f"{p.resolve()}::{p.stat().st_mtime_ns}::{n}::{r}::{rotation}".encode()).hexdigest()[:20]
    out_base = str(CACHE / h)
    png = out_base + ".png"
    if not Path(png).is_file():
        cmd = ["pdftocairo", "-png", "-f", str(n), "-l", str(n), "-r", str(r), "-singlefile"]
        if rotation:
            cmd += ["-rotate", str(rotation)]
        cmd += [str(p), out_base]
        rc, _o, err = _run(cmd, timeout=45)
        if rc != 0 or not Path(png).is_file():
            json.dump({"ok": False, "error": err.strip() or "render failed"}, sys.stdout)
            return
    json.dump({"ok": True, "png": png, "page": n}, sys.stdout)


def cmd_toc(path: str) -> None:
    p = Path(path).expanduser()
    rc, out, _err = _run(
        ["pdftohtml", "-f", "1", "-l", "1", "-i", "-q", "-stdout", "-xml", str(p)],
        timeout=20,
    )
    items = []
    if rc == 0:
        import html as htmlmod
        depth = 0
        for tok in re.finditer(
            r"<outline>|</outline>|<item page=\"(\d+)\"[^>]*>(.*?)</item>",
            out, re.S,
        ):
            if tok.group(0) == "<outline>":
                depth += 1
            elif tok.group(0) == "</outline>":
                depth -= 1
            elif tok.group(1):
                items.append({
                    "depth": max(depth - 1, 0),
                    "title": htmlmod.unescape(tok.group(2)).strip(),
                    "page": int(tok.group(1)),
                })
    json.dump({"ok": True, "toc": items}, sys.stdout)


def cmd_last() -> None:
    docs = _load_store()
    best = None
    best_seen = -1.0
    for k, st in (docs or {}).items():
        if not isinstance(st, dict):
            continue
        path = k.split("::")[0]
        if not Path(path).is_file():
            continue
        seen = float(st.get("seen") or 0)
        if seen >= best_seen:
            best_seen = seen
            best = path
    json.dump({"ok": True, "path": best or ""}, sys.stdout)


def cmd_save(path: str, page: str, zoom: str, rot: str, sidebar: str, marks: str) -> None:
    p = Path(path).expanduser()
    if not p.is_file():
        json.dump({"ok": False}, sys.stdout)
        return
    docs = _load_store()
    try:
        mark_list = [int(x) for x in (marks or "").split(",") if x.strip()]
    except ValueError:
        mark_list = []
    docs[_key(p)] = {
        "page": max(1, int(page or 1)),
        "zoom": zoom if zoom in ("width", "page") else zoom,
        "rot": int(rot or 0),
        "sidebar": sidebar == "1",
        "side_page": "pages",
        "marks": mark_list,
        "seen": __import__("time").time(),
    }
    _save_store(docs)
    json.dump({"ok": True}, sys.stdout)


def cmd_find(path: str, query: str) -> None:
    p = Path(path).expanduser()
    q = (query or "").strip()
    if not p.is_file() or not q:
        json.dump({"ok": False, "hits": [], "error": "nothing to search"}, sys.stdout)
        return
    if not shutil.which("pdftotext"):
        json.dump({"ok": False, "hits": [], "error": "pdftotext is not installed"}, sys.stdout)
        return
    rc, out, err = _run(["pdftotext", "-q", str(p), "-"], timeout=60)
    if rc != 0:
        json.dump({"ok": False, "hits": [], "error": err or "pdftotext failed"}, sys.stdout)
        return
    needle = q.lower()
    hits = []
    for i, text in enumerate((out or "").split("\f"), 1):
        low = text.lower()
        at = low.find(needle)
        if at < 0:
            continue
        snip = " ".join(text[max(0, at - 42):at + len(q) + 42].split())
        hits.append({"page": i, "snip": snip})
        if len(hits) >= 40:
            break
    json.dump({"ok": True, "hits": hits, "query": q}, sys.stdout)


def cmd_print(path: str) -> None:
    p = Path(path).expanduser()
    if not p.is_file():
        json.dump({"ok": False, "error": "no document"}, sys.stdout)
        return
    printer = shutil.which("lp") or shutil.which("lpr")
    if not printer:
        json.dump({"ok": False, "error": "no lp/lpr on this machine"}, sys.stdout)
        return
    rc, out, err = _run([printer, str(p)], timeout=60)
    json.dump({"ok": rc == 0, "error": (err or out).strip()}, sys.stdout)


def cmd_pick() -> None:
    rc, out, _err = _run([
        "zenity", "--file-selection", "--title=Open a PDF",
        "--file-filter=PDF documents | *.pdf *.PDF",
    ], timeout=300)
    path = (out or "").strip()
    json.dump({"ok": bool(path) and Path(path).is_file(), "path": path}, sys.stdout)


if __name__ == "__main__":
    op = sys.argv[1] if len(sys.argv) > 1 else "last"
    args = sys.argv[2:]
    if op == "info" and args:
        cmd_info(args[0])
    elif op == "render" and len(args) >= 2:
        cmd_render(args[0], args[1], args[2] if len(args) > 2 else "110",
                   args[3] if len(args) > 3 else "0")
    elif op == "toc" and args:
        cmd_toc(args[0])
    elif op == "save" and len(args) >= 1:
        cmd_save(args[0],
                 args[1] if len(args) > 1 else "1",
                 args[2] if len(args) > 2 else "width",
                 args[3] if len(args) > 3 else "0",
                 args[4] if len(args) > 4 else "0",
                 args[5] if len(args) > 5 else "")
    elif op == "find" and len(args) >= 2:
        cmd_find(args[0], args[1])
    elif op == "print" and args:
        cmd_print(args[0])
    elif op == "pick":
        cmd_pick()
    else:
        cmd_last()
