#!/usr/bin/env python3
"""Persist world zones + alarms for ClockApp.qml. Same ~/.config/nyxus/clock.json."""
from __future__ import annotations

import json
import sys
from pathlib import Path

CONF = Path.home() / ".config/nyxus/clock.json"
DEFAULT_ZONES = ["UTC", "America/New_York", "Europe/London", "Asia/Tokyo"]


def load() -> dict:
    try:
        raw = json.loads(CONF.read_text())
    except (OSError, json.JSONDecodeError, TypeError, ValueError):
        return {"zones": list(DEFAULT_ZONES), "alarms": []}
    if not isinstance(raw, dict):
        return {"zones": list(DEFAULT_ZONES), "alarms": []}
    zones = raw.get("zones")
    if not isinstance(zones, list) or not zones:
        zones = list(DEFAULT_ZONES)
    alarms = raw.get("alarms")
    if not isinstance(alarms, list):
        alarms = []
    return {"zones": [str(z) for z in zones], "alarms": alarms}


def save(data: dict) -> None:
    CONF.parent.mkdir(parents=True, exist_ok=True)
    tmp = CONF.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, indent=2) + "\n")
    tmp.replace(CONF)


def cmd_times(zones: list[str]) -> None:
    from datetime import datetime
    from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

    here = datetime.now().astimezone()
    out = []
    for z in zones:
        try:
            tz = ZoneInfo(z)
        except (ZoneInfoNotFoundError, Exception):
            continue
        now = datetime.now(tz)
        off = now.utcoffset() - here.utcoffset()
        mins = int(off.total_seconds() // 60) if off else 0
        h = now.hour
        if 9 <= h < 18:
            band = "day"
        elif 6 <= h < 9:
            band = "dawn"
        elif 18 <= h < 22:
            band = "dusk"
        else:
            band = "night"
        city = z.split("/")[-1].replace("_", " ")
        out.append({
            "zone": z,
            "city": city,
            "time": now.strftime("%H:%M"),
            "date": now.strftime("%a %-d %b"),
            "offset": mins,
            "band": band,
        })
    json.dump({"ok": True, "times": out, "local": here.strftime("%H:%M:%S")}, sys.stdout)


if __name__ == "__main__":
    op = sys.argv[1] if len(sys.argv) > 1 else "load"
    if op == "load":
        json.dump(load(), sys.stdout)
    elif op == "save" and len(sys.argv) > 2:
        save(json.loads(sys.argv[2]))
        json.dump({"ok": True}, sys.stdout)
    elif op == "save":
        save(json.loads(sys.stdin.read()))
        json.dump({"ok": True}, sys.stdout)
    elif op == "times":
        data = load()
        extra = sys.argv[2:]
        cmd_times(extra or data.get("zones") or DEFAULT_ZONES)
    else:
        json.dump(load(), sys.stdout)
