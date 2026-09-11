#!/usr/bin/env python3
"""CPU / mem / net / disk / processes for Sysmon.qml. `kill PID` → SIGTERM."""
from __future__ import annotations

import json
import os
import signal
import sys
import time
from pathlib import Path


def _cpu_all():
    """Aggregate + per-core (idle, total) from /proc/stat. Cheap: one read."""
    agg = None
    cores = []
    try:
        lines = Path("/proc/stat").read_text().splitlines()
    except OSError:
        return None, []
    for line in lines:
        if not line.startswith("cpu"):
            if agg is not None:
                break
            continue
        parts = line.split()
        try:
            nums = [int(x) for x in parts[1:]]
        except ValueError:
            continue
        if not nums:
            continue
        idle = nums[3] + (nums[4] if len(nums) > 4 else 0)
        total = sum(nums)
        if parts[0] == "cpu":
            agg = (idle, total)
        elif parts[0][3:].isdigit():
            cores.append((idle, total))
    return agg, cores


def _pct(a, b) -> float:
    if not a or not b:
        return 0.0
    dt = b[1] - a[1]
    if dt <= 0:
        return 0.0
    di = b[0] - a[0]
    return max(0.0, min(100.0, 100.0 * (1.0 - di / dt)))


def _mem():
    info = {}
    try:
        for line in Path("/proc/meminfo").read_text().splitlines():
            k, v = line.split(":", 1)
            info[k] = int(v.strip().split()[0])
    except (OSError, ValueError, IndexError):
        return {"totalKb": 1, "usedKb": 0, "pct": 0.0}
    total = info.get("MemTotal", 1) or 1
    avail = info.get("MemAvailable", 0)
    used = max(0, total - avail)
    return {"totalKb": total, "usedKb": used, "pct": round(100.0 * used / total, 1)}


def _net():
    rx = tx = 0
    try:
        lines = Path("/proc/net/dev").read_text().splitlines()[2:]
    except OSError:
        return {"rx": 0, "tx": 0}
    for line in lines:
        if ":" not in line:
            continue
        name, rest = line.split(":", 1)
        if name.strip() == "lo":
            continue
        cols = rest.split()
        try:
            rx += int(cols[0])
            tx += int(cols[8])
        except (ValueError, IndexError):
            continue
    return {"rx": rx, "tx": tx}


def _disk():
    try:
        st = os.statvfs("/")
    except OSError:
        return {"total": 0, "used": 0, "pct": 0.0}
    total = st.f_frsize * st.f_blocks
    free = st.f_frsize * st.f_bavail
    used = max(0, total - free)
    return {"total": total, "used": used, "pct": round(100.0 * used / total, 1) if total else 0.0}


def _proc_snap():
    """pid → (name, cpu_ticks, rssKb). stat + statm; no status parse."""
    page_kb = max(1, os.sysconf("SC_PAGE_SIZE") // 1024)
    out = {}
    try:
        ents = Path("/proc").iterdir()
    except OSError:
        return out
    for p in ents:
        if not p.name.isdigit():
            continue
        try:
            stat = (p / "stat").read_text()
            comm = stat.split("(", 1)[1].rsplit(")", 1)[0]
            rest = stat.rsplit(")", 1)[1].split()
            ticks = int(rest[11]) + int(rest[12])
            rss_kb = int((p / "statm").read_text().split()[1]) * page_kb
        except (OSError, IndexError, ValueError):
            continue
        out[int(p.name)] = (comm, ticks, rss_kb)
    return out


def _procs(s1, s2, dt_ticks, ncpu):
    rows = []
    ncpu = max(1, ncpu)
    for pid, (name, ticks, rss) in s2.items():
        prev = s1.get(pid)
        d = ticks - prev[1] if prev else 0
        if d < 0:
            d = 0
        cpu = (100.0 * d * ncpu / dt_ticks) if dt_ticks > 0 else 0.0
        rows.append({
            "pid": pid,
            "name": name,
            "cpu": round(cpu, 1),
            "rssKb": rss,
        })
    rows.sort(key=lambda r: (r["cpu"], r["rssKb"]), reverse=True)
    return rows[:32]


def _uptime():
    try:
        sec = float(Path("/proc/uptime").read_text().split()[0])
    except (OSError, ValueError, IndexError):
        return ""
    h = int(sec // 3600)
    m = int((sec % 3600) // 60)
    return f"{h}h {m}m"


def _kill(raw: str) -> dict:
    try:
        pid = int(raw)
    except (TypeError, ValueError):
        return {"ok": False, "error": "bad pid"}
    if pid <= 1:
        return {"ok": False, "error": "refused"}
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        return {"ok": False, "error": "gone"}
    except PermissionError:
        return {"ok": False, "error": "denied"}
    except OSError as e:
        return {"ok": False, "error": str(e)}
    return {"ok": True, "pid": pid}


def _snapshot() -> dict:
    idle1, cores1 = _cpu_all()
    net1 = _net()
    proc1 = _proc_snap()
    time.sleep(0.25)
    idle2, cores2 = _cpu_all()
    net2 = _net()
    proc2 = _proc_snap()
    ncpu = os.cpu_count() or 1
    cpu = round(_pct(idle1, idle2), 1)
    dt_ticks = (idle2[1] - idle1[1]) if idle1 and idle2 else 0
    cores = []
    if cores1 and cores2 and len(cores1) == len(cores2):
        cores = [round(_pct(a, b), 1) for a, b in zip(cores1, cores2)]
    try:
        load = list(os.getloadavg())
    except OSError:
        load = [0, 0, 0]
    rx_bps = max(0, (net2["rx"] - net1["rx"]) * 4)
    tx_bps = max(0, (net2["tx"] - net1["tx"]) * 4)
    return {
        "ok": True,
        "cpu": cpu,
        "cores": cores,
        "load": load,
        "ncpu": ncpu,
        "mem": _mem(),
        "net": {
            "rx": net2["rx"],
            "tx": net2["tx"],
            "rxBps": rx_bps,
            "txBps": tx_bps,
        },
        "disk": _disk(),
        "procs": _procs(proc1, proc2, dt_ticks, ncpu),
        "host": os.uname().nodename,
        "uptime": _uptime(),
        "nproc": len(proc2),
    }


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "kill":
        json.dump(_kill(sys.argv[2] if len(sys.argv) > 2 else ""), sys.stdout)
        sys.stdout.write("\n")
        raise SystemExit(0)
    json.dump(_snapshot(), sys.stdout)
