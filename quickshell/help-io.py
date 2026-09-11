#!/usr/bin/env python3
"""Dump Help topics for Help.qml. Same book as GTK nyxus_help_content.py."""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, "/opt/nyxus")
from nyxus_help_content import BY_SLUG, CATEGORIES, TOPICS  # noqa: E402


def cmd_list() -> None:
    topics = [{
        "slug": t.slug,
        "title": t.title,
        "category": t.category,
        "summary": getattr(t, "summary", "") or "",
    } for t in TOPICS]
    json.dump({"ok": True, "categories": list(CATEGORIES), "topics": topics}, sys.stdout)


def cmd_page(slug: str) -> None:
    t = BY_SLUG.get(slug)
    if t is None:
        json.dump({"ok": False, "error": "unknown topic"}, sys.stdout)
        return
    json.dump({
        "ok": True,
        "slug": t.slug,
        "title": t.title,
        "category": t.category,
        "body": t.body or "",
    }, sys.stdout)


if __name__ == "__main__":
    op = sys.argv[1] if len(sys.argv) > 1 else "list"
    if op == "page" and len(sys.argv) > 2:
        cmd_page(sys.argv[2])
    else:
        cmd_list()
