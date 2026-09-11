#!/usr/bin/env python3
"""Agenda I/O for Calendar.qml. Same ~/.config/nyxus/agenda.json as GTK."""
from __future__ import annotations

import json
import sys
from datetime import date, datetime, timedelta
from pathlib import Path

OPT = Path("/opt/nyxus")
if str(OPT) not in sys.path:
    sys.path.insert(0, str(OPT))

from nyxus_agenda import (  # noqa: E402
    CATEGORIES, add_item, delete_item, items_between, set_done,
)

CAT_COLOUR = {
    "General": "#4f7fa6",
    "Work": "#5b6cff",
    "Personal": "#c45ad4",
    "Health": "#3ecf8e",
    "Birthday": "#ae206c",
    "Travel": "#3d8fd6",
    "Urgent": "#ff2d55",
}


def _iso_day(d: date) -> str:
    return d.isoformat()


def _pack(when: datetime, it: dict) -> dict:
    return {
        "id": it.get("id"),
        "title": it.get("title") or "",
        "category": it.get("category") or "General",
        "colour": CAT_COLOUR.get(it.get("category") or "General", "#4f7fa6"),
        "due": when.isoformat(timespec="minutes"),
        "iso": when.date().isoformat(),
        "allDay": bool(it.get("all_day")),
        "done": bool(it.get("done")),
        "notes": it.get("notes") or "",
        "location": it.get("location") or "",
        "kind": it.get("kind") or "event",
    }


def cmd_range(a: str, b: str) -> None:
    start = date.fromisoformat(a)
    end = date.fromisoformat(b)
    rows = [_pack(when, it) for when, it in items_between(start, end)]
    json.dump({
        "ok": True,
        "events": rows,
        "categories": [{"id": c, "colour": CAT_COLOUR[c]} for c in CATEGORIES],
    }, sys.stdout)


def cmd_add(title: str, day: str, category: str = "General") -> None:
    title = (title or "").strip()
    if not title:
        json.dump({"ok": False, "error": "need a title"}, sys.stdout)
        return
    d = date.fromisoformat(day)
    due = datetime(d.year, d.month, d.day, 9, 0).isoformat(timespec="minutes")
    cat = category if category in CATEGORIES else "General"
    it = add_item(kind="event", title=title, due=due, category=cat, all_day=True)
    json.dump({"ok": True, "id": it.get("id")}, sys.stdout)


def cmd_delete(eid: str) -> None:
    delete_item(eid)
    json.dump({"ok": True}, sys.stdout)


def cmd_done(eid: str) -> None:
    set_done(eid, True)
    json.dump({"ok": True}, sys.stdout)


if __name__ == "__main__":
    op = sys.argv[1] if len(sys.argv) > 1 else "range"
    args = sys.argv[2:]
    if op == "range" and len(args) >= 2:
        cmd_range(args[0], args[1])
    elif op == "add" and len(args) >= 2:
        cmd_add(args[0], args[1], args[2] if len(args) > 2 else "General")
    elif op == "delete" and args:
        cmd_delete(args[0])
    elif op == "done" and args:
        cmd_done(args[0])
    else:
        today = date.today()
        start = today.replace(day=1) - timedelta(days=7)
        end = start + timedelta(days=50)
        cmd_range(start.isoformat(), end.isoformat())
