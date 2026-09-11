#!/usr/bin/env python3
"""List / create / lock notes for Notes.qml. Same store as the retired GTK app.

Lock is a header, not encryption. `NYXUS-NOTE-LOCK-v1` prepended means the
glass window refuses the body until unlock strips it.
"""
from __future__ import annotations

import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path.home() / ".config/nyxus/notes"
LOCK = "NYXUS-NOTE-LOCK-v1\n"
MEDIA = "_media"
DEFAULT_BOOK = "Notes"


def _title_snip(path: Path) -> tuple[str, str, int, bool]:
    title, snippet, words, locked = path.stem, "", 0, False
    try:
        head = path.read_text(encoding="utf-8", errors="replace")[:4096]
    except OSError:
        return title, snippet, words, locked
    if head.startswith(LOCK):
        return path.stem, "", 0, True
    lines = [ln.strip() for ln in head.split("\n")]
    body: list[str] = []
    got = False
    for ln in lines:
        s = ln.lstrip("#").strip()
        if not s:
            continue
        if not got:
            title, got = s[:70], True
            continue
        if s.startswith("```") or set(s) <= set("-*_= "):
            continue
        body.append(s.lstrip(">-*+ ").strip())
        if len(" ".join(body)) > 120:
            break
    snippet = " ".join(body)[:120]
    words = len(head.split())
    return title, snippet, words, locked


def _inside(path: str) -> Path:
    p = Path(path).expanduser()
    try:
        p = p.resolve()
        p.relative_to(ROOT.resolve())
    except ValueError:
        sys.exit("refusing a file outside the notes folder")
    return p


def cmd_list() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    items = []
    for p in ROOT.rglob("*"):
        if not p.is_file():
            continue
        if p.name.startswith(".") or p.suffix == ".tmp" or p.name.endswith(".migrated"):
            continue
        if MEDIA in p.parts:
            continue
        try:
            st = p.stat()
        except OSError:
            continue
        title, snippet, words, locked = _title_snip(p)
        book = "Notes" if p.parent == ROOT else p.parent.name
        items.append({
            "path": str(p),
            "name": p.name,
            "book": book,
            "title": title,
            "snippet": snippet,
            "words": words,
            "locked": locked,
            "mtime": int(st.st_mtime),
        })
    items.sort(key=lambda r: r["mtime"], reverse=True)
    json.dump(items, sys.stdout)


def _book_dir(book: str) -> Path:
    name = (book or DEFAULT_BOOK).strip() or DEFAULT_BOOK
    if name == DEFAULT_BOOK:
        return ROOT
    if "/" in name or name.startswith(".") or name == MEDIA:
        sys.exit("refusing that notebook name")
    return ROOT / name


def cmd_books() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    books = [DEFAULT_BOOK]
    for p in sorted(ROOT.iterdir()):
        if p.is_dir() and not p.name.startswith(".") and p.name != MEDIA:
            books.append(p.name)
    json.dump(books, sys.stdout)


def cmd_create_book(name: str) -> None:
    name = name.strip()
    if not name or "/" in name or name.startswith(".") or name == MEDIA:
        json.dump({"ok": False, "error": "plain name, no / or leading dot"}, sys.stdout)
        return
    d = ROOT / name
    try:
        d.mkdir(parents=True, exist_ok=True)
    except OSError as e:
        json.dump({"ok": False, "error": str(e)}, sys.stdout)
        return
    json.dump({"ok": True, "book": name}, sys.stdout)


def cmd_create(book: str = DEFAULT_BOOK) -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    d = _book_dir(book)
    d.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("note-%Y%m%d-%H%M%S")
    p = d / f"{stamp}.txt"
    n = 0
    while p.exists():
        n += 1
        p = d / f"{stamp}-{n}.txt"
    p.write_text("Untitled\n\n", encoding="utf-8")
    print(p.as_posix())


def cmd_trash(path: str) -> None:
    p = _inside(path)
    r = subprocess.run(["gio", "trash", str(p)], capture_output=True, text=True)
    if r.returncode != 0:
        p.unlink()
    print("ok")


def cmd_lock(path: str) -> None:
    p = _inside(path)
    try:
        text = p.read_text(encoding="utf-8", errors="replace")
    except OSError as e:
        json.dump({"ok": False, "error": str(e), "locked": False}, sys.stdout)
        return
    if not text.startswith(LOCK):
        p.write_text(LOCK + text, encoding="utf-8")
    json.dump({"ok": True, "locked": True, "path": str(p)}, sys.stdout)


def cmd_unlock(path: str) -> None:
    p = _inside(path)
    try:
        text = p.read_text(encoding="utf-8", errors="replace")
    except OSError as e:
        json.dump({"ok": False, "error": str(e), "locked": True}, sys.stdout)
        return
    if text.startswith(LOCK):
        p.write_text(text[len(LOCK):], encoding="utf-8")
    json.dump({"ok": True, "locked": False, "path": str(p)}, sys.stdout)


def cmd_find(path: str, query: str) -> None:
    p = _inside(path)
    try:
        raw = p.read_text(encoding="utf-8", errors="replace")
    except OSError as e:
        json.dump({"count": 0, "offsets": [], "locked": False, "error": str(e)}, sys.stdout)
        return
    locked = raw.startswith(LOCK)
    if locked:
        json.dump({"count": 0, "offsets": [], "locked": True}, sys.stdout)
        return
    q = query.lower()
    offsets: list[int] = []
    if q:
        hay = raw.lower()
        i = 0
        step = max(1, len(q))
        while True:
            j = hay.find(q, i)
            if j < 0:
                break
            offsets.append(j)
            i = j + step
    json.dump({"count": len(offsets), "offsets": offsets, "locked": False}, sys.stdout)


def main() -> int:
    op = sys.argv[1] if len(sys.argv) > 1 else "list"
    if op == "list":
        cmd_list()
        return 0
    if op == "books":
        cmd_books()
        return 0
    if op == "create-book" and len(sys.argv) > 2:
        cmd_create_book(" ".join(sys.argv[2:]))
        return 0
    if op == "create":
        cmd_create(sys.argv[2] if len(sys.argv) > 2 else DEFAULT_BOOK)
        return 0
    if op == "trash" and len(sys.argv) > 2:
        cmd_trash(sys.argv[2])
        return 0
    if op == "lock" and len(sys.argv) > 2:
        cmd_lock(sys.argv[2])
        return 0
    if op == "unlock" and len(sys.argv) > 2:
        cmd_unlock(sys.argv[2])
        return 0
    if op == "find" and len(sys.argv) > 2:
        cmd_find(sys.argv[2], " ".join(sys.argv[3:]))
        return 0
    print("usage: notes-io.py list|create|trash PATH|lock PATH|unlock PATH|find PATH QUERY",
          file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
