#!/usr/bin/env python3
"""Spell-check a blob of text with hunspell. Used by Notes.qml."""
from __future__ import annotations

import json
import re
import subprocess
import sys

WORD = re.compile(r"[A-Za-z][A-Za-z']{1,48}")
DICT = "en_US"


def _hunspell(words: list[str]) -> dict[str, list[str]]:
    if not words:
        return {}
    try:
        p = subprocess.run(
            ["hunspell", "-a", "-d", DICT],
            input="!\n" + "\n".join(words) + "\n",
            capture_output=True,
            text=True,
            timeout=4,
        )
    except (OSError, subprocess.TimeoutExpired):
        return {}
    out: dict[str, list[str]] = {}
    i = 0
    for line in p.stdout.splitlines():
        if not line or line.startswith("@") or line.startswith("*") or line.startswith("+"):
            if line.startswith("*") or line.startswith("+"):
                i += 1
            continue
        if line.startswith("#"):
            # # word offset
            parts = line[2:].split()
            if parts:
                out[parts[0]] = []
            i += 1
            continue
        if line.startswith("&"):
            # & word count offset: a, b, c
            body = line[2:]
            if ":" not in body:
                i += 1
                continue
            head, rest = body.split(":", 1)
            bits = head.split()
            word = bits[0] if bits else ""
            sugg = [s.strip() for s in rest.split(",") if s.strip()][:6]
            if word:
                out[word] = sugg
            i += 1
    return out


def cmd_check(text: str) -> None:
    found: list[dict] = []
    seen: dict[str, list[str] | None] = {}
    for m in WORD.finditer(text or ""):
        w = m.group(0)
        if w[0].isupper() and w[1:].islower() and len(w) <= 3:
            continue
        key = w
        if key not in seen:
            seen[key] = None
        found.append({"word": w, "start": m.start()})
    unique = [w for w in seen]
    miss_map = _hunspell(unique)
    miss = []
    for item in found:
        w = item["word"]
        if w in miss_map or w.lower() in miss_map:
            sugg = miss_map.get(w) or miss_map.get(w.lower()) or []
            miss.append({"word": w, "start": item["start"], "suggestions": sugg})
    json.dump({"ok": True, "miss": miss[:80]}, sys.stdout)


def main() -> int:
    op = sys.argv[1] if len(sys.argv) > 1 else "check"
    if op == "check":
        cmd_check(sys.stdin.read())
        return 0
    if op == "file" and len(sys.argv) > 2:
        from pathlib import Path
        cmd_check(Path(sys.argv[2]).read_text(encoding="utf-8", errors="replace"))
        return 0
    print("usage: spell-io.py check < text | file PATH", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
