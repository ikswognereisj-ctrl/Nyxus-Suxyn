#!/usr/bin/env python3
"""Live hardware I/O for Hardware.qml. Snapshot, procs, kill, profiles, RGB, power."""
from __future__ import annotations

import json
import os
import re
import shutil
import signal
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
NYXUS = HOME / ".config" / "nyxus"
PROFILES = NYXUS / "hardware-profiles.json"
LEGACY_PROFILES = (
    NYXUS / "system_profiles.json",
    HOME / ".nyxus" / "system_profiles.json",
)

_BOOST_INVERTED = Path("/sys/devices/system/cpu/intel_pstate/no_turbo")
_BOOST_DIRECT = Path("/sys/devices/system/cpu/cpufreq/boost")

# LED colours by palette NAME. These are hardware state sent to OpenRGB,
# not chrome. Names match Theme tokens; White is true white as GTK did.
RGB_PALETTE = {
    "Ice":     "#7FE8FF",  # glacier[0]
    "Glacier": "#5CC6EA",  # tealGlow
    "Magma":   "#FF7847",  # magma[5]
    "Red":     "#FF2D55",  # Theme.danger
    "Gold":    "#D8A464",  # goldGlow
    "Green":   "#2CF597",  # Theme.ok
    "Azure":   "#52A0EA",  # azureGlow
    "Violet":  "#AA6ECE",  # violetGlow
    "Plum":    "#D765A2",  # plumGlow
    "White":   "#FFFFFF",
}

_PROFILE_TO_PPD = {
    "silent": "power-saver",
    "balanced": "balanced",
    "performance": "performance",
    "beast mode": "performance",
    "beast": "performance",
}

_CPU_PREV: tuple[int, int] | None = None


def _read(p: Path) -> str:
    try:
        return p.read_text().strip()
    except OSError:
        return ""


def _read_int(p: Path):
    raw = _read(p)
    try:
        return int(raw)
    except ValueError:
        return None


def _out(obj) -> None:
    json.dump(obj, sys.stdout, separators=(",", ":"))
    sys.stdout.write("\n")


def _run(cmd, timeout=4, text=True):
    try:
        return subprocess.run(cmd, capture_output=True, text=text, timeout=timeout)
    except Exception:
        return None


def _write_priv(path: Path, value: str) -> tuple[bool, str]:
    try:
        path.write_text(value + "\n")
        return True, ""
    except PermissionError:
        try:
            r = subprocess.run(
                ["pkexec", "tee", str(path)],
                input=(value + "\n").encode(),
                capture_output=True,
                timeout=20,
            )
            if r.returncode == 0:
                return True, ""
            err = (r.stderr or b"").decode().strip() or "pkexec tee failed"
            return False, err
        except Exception as e:
            return False, str(e)
    except Exception as e:
        return False, str(e)


def _temps() -> list:
    out = []
    root = Path("/sys/class/hwmon")
    if not root.is_dir():
        return out
    for hw in sorted(root.iterdir()):
        name = _read(hw / "name") or hw.name
        for inp in sorted(hw.glob("temp*_input")):
            raw = _read(inp)
            try:
                c = int(raw) / 1000.0
            except ValueError:
                continue
            label = _read(Path(str(inp).replace("_input", "_label"))) or inp.name
            crit = _read_int(Path(str(inp).replace("_input", "_crit")))
            mx = _read_int(Path(str(inp).replace("_input", "_max")))
            row = {"name": f"{name}/{label}", "c": round(c, 1)}
            if crit is not None:
                row["crit"] = crit / 1000.0
            if mx is not None:
                row["max"] = mx / 1000.0
            out.append(row)
    out.sort(key=lambda x: x["c"], reverse=True)
    return out[:24]


def _fans() -> list:
    out = []
    root = Path("/sys/class/hwmon")
    if not root.is_dir():
        return out
    for hw in sorted(root.iterdir()):
        name = _read(hw / "name") or hw.name
        for inp in sorted(hw.glob("fan*_input")):
            raw = _read(inp)
            try:
                rpm = int(raw)
            except ValueError:
                continue
            label = _read(Path(str(inp).replace("_input", "_label"))) or inp.name
            mn = _read_int(Path(str(inp).replace("_input", "_min")))
            mx = _read_int(Path(str(inp).replace("_input", "_max")))
            row = {"name": f"{name}/{label}", "rpm": rpm}
            if mn is not None:
                row["min"] = mn
            if mx is not None:
                row["max"] = mx
            out.append(row)
    out.sort(key=lambda x: x["rpm"], reverse=True)
    return out[:8]


def _pwm() -> list:
    out = []
    root = Path("/sys/class/hwmon")
    if not root.is_dir():
        return out
    for hw in sorted(root.iterdir()):
        name = _read(hw / "name") or hw.name
        for p in sorted(hw.glob("pwm[0-9]")):
            if p.name.endswith("_enable"):
                continue
            val = _read_int(p)
            en = _read_int(Path(str(p) + "_enable"))
            out.append({
                "name": f"{name}/{p.name}",
                "value": val,
                "enable": en,
                "path": str(p),
            })
    return out


def _mem() -> dict:
    info = {}
    try:
        for line in Path("/proc/meminfo").read_text().splitlines():
            k, v = line.split(":", 1)
            info[k] = int(v.strip().split()[0]) * 1024
    except OSError:
        return {"total": 0, "used": 0, "pct": 0}
    total = info.get("MemTotal", 0)
    avail = info.get("MemAvailable", 0)
    used = total - avail
    pct = round(100.0 * used / total, 1) if total else 0
    return {"total": total, "used": used, "pct": pct}


def _cpu_times() -> tuple[int, int]:
    try:
        nums = [int(x) for x in Path("/proc/stat").read_text().splitlines()[0].split()[1:]]
    except (OSError, ValueError):
        return 0, 1
    idle = nums[3] + (nums[4] if len(nums) > 4 else 0)
    return idle, sum(nums)


def _cpu() -> dict:
    global _CPU_PREV
    try:
        load = list(os.getloadavg())
    except OSError:
        load = [0, 0, 0]
    n = os.cpu_count() or 1
    idle, total = _cpu_times()
    pct = 0.0
    if _CPU_PREV is not None:
        di = idle - _CPU_PREV[0]
        dt = total - _CPU_PREV[1]
        if dt > 0:
            pct = max(0.0, min(100.0, (1.0 - di / dt) * 100.0))
    _CPU_PREV = (idle, total)
    freqs = []
    for p in sorted(Path("/sys/devices/system/cpu").glob("cpu[0-9]*/cpufreq/scaling_cur_freq")):
        try:
            mhz = int(p.read_text().strip()) / 1000.0
        except (OSError, ValueError):
            continue
        cpu = p.parent.parent.name
        freqs.append({"cpu": cpu, "mhz": round(mhz)})
    mhzs = [f["mhz"] for f in freqs]
    freq = None
    if mhzs:
        freq = {
            "min": min(mhzs),
            "avg": round(sum(mhzs) / len(mhzs)),
            "max": max(mhzs),
        }
    gov = _read(Path("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"))
    govs = _read(Path("/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors")).split()
    epp = _read(Path("/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference"))
    driver = _read(Path("/sys/devices/system/cpu/cpu0/cpufreq/scaling_driver"))
    return {
        "load": load,
        "n": n,
        "pct": round(pct, 1),
        "cores": freqs,
        "freq": freq,
        "governor": gov,
        "governors": govs,
        "epp": epp,
        "driver": driver,
    }


def _boost_iface():
    if _BOOST_INVERTED.exists():
        return _BOOST_INVERTED, True
    if _BOOST_DIRECT.exists():
        return _BOOST_DIRECT, False
    return None, False


def _boost_read():
    path, inverted = _boost_iface()
    if path is None:
        return None
    raw = _read(path)
    if raw not in ("0", "1"):
        return None
    return (raw == "0") if inverted else (raw == "1")


def _boost_write(on: bool) -> tuple[bool, str]:
    path, inverted = _boost_iface()
    if path is None:
        return False, "no CPU boost control on this kernel"
    val = ("0" if on else "1") if inverted else ("1" if on else "0")
    return _write_priv(path, val)


def _batt() -> dict:
    root = Path("/sys/class/power_supply")
    if not root.is_dir():
        return {"present": False}
    for name in ("BAT0", "BAT1"):
        bat = root / name
        if bat.is_dir():
            cap = _read_int(bat / "capacity") or 0
            return {"present": True, "pct": cap, "status": _read(bat / "status"), "name": name}
    for p in sorted(root.iterdir()):
        if _read(p / "type") == "Battery":
            cap = _read_int(p / "capacity") or 0
            return {"present": True, "pct": cap, "status": _read(p / "status"), "name": p.name}
    return {"present": False}


def _ppd() -> dict:
    r = _run(["powerprofilesctl", "get"], timeout=2)
    active = (r.stdout or "").strip() if r and r.returncode == 0 else ""
    modes = []
    via = ""
    r2 = _run(["powerprofilesctl", "list"], timeout=3)
    if r2 and r2.returncode == 0:
        for line in (r2.stdout or "").splitlines():
            m = re.match(r"^(\*)?\s*([a-z][a-z0-9_-]*):\s*$", line)
            if m:
                modes.append(m.group(2))
                if m.group(1) == "*":
                    active = m.group(2)
        if modes:
            via = "power-profiles-daemon"
    pp = Path("/sys/firmware/acpi/platform_profile")
    choices = _read(Path("/sys/firmware/acpi/platform_profile_choices")).split()
    current = _read(pp)
    if not via and current and choices:
        via = "platform_profile"
        modes = choices
        active = current
    return {
        "active": active,
        "modes": modes,
        "via": via,
        "backed": bool(modes),
        "platform": current,
        "platform_choices": choices,
    }


def _gpu() -> dict:
    r = _run(
        ["nvidia-smi",
         "--query-gpu=name,temperature.gpu,power.draw,power.limit,"
         "memory.used,memory.total,utilization.gpu",
         "--format=csv,noheader,nounits"],
        timeout=4,
    )
    if r and r.returncode == 0 and (r.stdout or "").strip():
        p = [x.strip() for x in r.stdout.strip().split(",")]
        if len(p) >= 7:
            def _f(s):
                try:
                    return float(s)
                except ValueError:
                    return 0.0
            return {
                "detected": True,
                "vendor": "nvidia",
                "name": p[0],
                "temp": _f(p[1]),
                "power_draw": _f(p[2]),
                "power_limit": _f(p[3]),
                "mem_used": _f(p[4]),
                "mem_total": _f(p[5]),
                "util": _f(p[6]),
            }
    name = _read(Path("/sys/class/drm/card0/device/vendor"))
    if Path("/sys/class/drm/card1").exists() or name:
        model = ""
        for p in Path("/sys/class/drm").glob("card*/device/product_name"):
            model = _read(p)
            if model:
                break
        return {"detected": bool(model or name), "vendor": "other", "name": model or "GPU"}
    return {"detected": False}


def _machine() -> dict:
    dmi = Path("/sys/class/dmi/id")
    return {
        "vendor": _read(dmi / "sys_vendor"),
        "product": _read(dmi / "product_name"),
        "board": _read(dmi / "board_name"),
        "bios": _read(dmi / "bios_version"),
        "host": os.uname().nodename,
    }


def _uptime() -> dict:
    try:
        sec = float(Path("/proc/uptime").read_text().split()[0])
    except (OSError, ValueError):
        return {"s": 0, "text": ""}
    s = int(sec)
    d, rem = divmod(s, 86400)
    hh, rem2 = divmod(rem, 3600)
    mm, _ss = divmod(rem2, 60)
    text = f"{d}d {hh:02d}h {mm:02d}m" if d else f"{hh:02d}h {mm:02d}m"
    return {"s": s, "text": text}


def snapshot() -> dict:
    temps = _temps()
    fans = _fans()
    pwm = _pwm()
    cpu = _cpu()
    mem = _mem()
    batt = _batt()
    power = _ppd()
    gpu = _gpu()
    return {
        "ok": True,
        "temps": temps,
        "hot": temps[0] if temps else None,
        "fans": fans,
        "loud": fans[0] if fans else None,
        "pwm": pwm,
        "has_pwm": any(True for _ in pwm),
        "mem": mem,
        "cpu": cpu,
        "batt": batt,
        "boost": _boost_read(),
        "power": power,
        "profile": power.get("active") or "",
        "gpu": gpu,
        "machine": _machine(),
        "host": os.uname().nodename,
        "uptime": _uptime(),
        "caps": {
            "fans": len(fans) > 0,
            "temps": len(temps) > 0,
            "pwm": len(pwm) > 0,
            "boost": _boost_read() is not None,
            "power": bool(power.get("backed")),
        },
        "rgb_binary": bool(shutil.which("openrgb")),
    }


def _procs() -> list:
    r = _run(["ps", "-eo", "pid,comm,pcpu,rss,user", "--sort=-pcpu", "--no-headers"], timeout=3)
    rows = []
    if r and r.returncode == 0:
        for line in (r.stdout or "").splitlines()[:80]:
            parts = line.split(None, 4)
            if len(parts) < 4:
                continue
            try:
                rows.append({
                    "pid": int(parts[0]),
                    "name": parts[1][:40],
                    "cpu": float(parts[2]),
                    "rss": int(parts[3]) * 1024,
                    "user": parts[4][:16] if len(parts) > 4 else "",
                })
            except ValueError:
                continue
        return rows
    for p in Path("/proc").iterdir():
        if not p.name.isdigit():
            continue
        try:
            stat = (p / "stat").read_text()
            comm = stat.split("(")[1].rsplit(")", 1)[0]
            status = (p / "status").read_text()
            rss = 0
            if "VmRSS:" in status:
                rss = int(status.split("VmRSS:")[1].split()[0]) * 1024
        except (OSError, IndexError, ValueError):
            continue
        rows.append({"pid": int(p.name), "name": comm, "cpu": 0.0, "rss": rss, "user": ""})
    rows.sort(key=lambda x: x["rss"], reverse=True)
    return rows[:80]


def _kill(pid: int) -> dict:
    if pid <= 1:
        return {"ok": False, "error": "refusing to signal PID %d" % pid}
    if pid == os.getpid():
        return {"ok": False, "error": "refusing to kill the helper"}
    try:
        os.kill(pid, signal.SIGTERM)
        return {"ok": True, "pid": pid, "signal": "SIGTERM"}
    except PermissionError:
        r = _run(["pkexec", "kill", "-TERM", str(pid)], timeout=12)
        if r and r.returncode == 0:
            return {"ok": True, "pid": pid, "signal": "SIGTERM", "elevated": True}
        err = (r.stderr or "").strip() if r else "permission denied"
        return {"ok": False, "error": err or "permission denied"}
    except ProcessLookupError:
        return {"ok": False, "error": "process %d already gone" % pid}
    except Exception as e:
        return {"ok": False, "error": str(e)}


def _default_profiles() -> list:
    return [
        {"name": "Silent", "governor": "powersave", "boost": False,
         "fan_pwm_pct": 20, "fan_mode": "low",
         "description": "Quiet & cool — minimal fan noise"},
        {"name": "Balanced", "governor": "schedutil", "boost": True,
         "fan_pwm_pct": 50, "fan_mode": "low",
         "description": "Smart everyday performance"},
        {"name": "Performance", "governor": "performance", "boost": True,
         "fan_pwm_pct": 80, "fan_mode": "max",
         "description": "Full speed for demanding tasks"},
        {"name": "Beast Mode", "governor": "performance", "boost": True,
         "fan_pwm_pct": 100, "fan_mode": "max",
         "description": "Maximum everything — hold on"},
    ]


def _load_profiles() -> list:
    if PROFILES.exists():
        try:
            data = json.loads(PROFILES.read_text())
            if isinstance(data, list) and data:
                return data
        except Exception:
            pass
    for legacy in LEGACY_PROFILES:
        if legacy.exists():
            try:
                data = json.loads(legacy.read_text())
                if isinstance(data, list) and data:
                    _save_profiles(data)
                    return data
            except Exception:
                pass
    ps = _default_profiles()
    _save_profiles(ps)
    return ps


def _save_profiles(ps: list) -> None:
    NYXUS.mkdir(parents=True, exist_ok=True)
    PROFILES.write_text(json.dumps(ps, indent=2) + "\n")


def _find_profile(ps: list, key: str):
    key = (key or "").strip()
    if not key:
        return None, -1
    if key.isdigit():
        i = int(key)
        if 0 <= i < len(ps):
            return ps[i], i
    low = key.lower()
    for i, p in enumerate(ps):
        if str(p.get("name", "")).lower() == low:
            return p, i
    return None, -1


def _rgb_probe() -> dict:
    which = _run(["which", "openrgb"], timeout=1)
    if not which or which.returncode != 0:
        return {"backed": False, "binary": False, "devices": [], "n": 0}
    r = _run(["openrgb", "--list-devices"], timeout=6)
    out = ""
    if r:
        out = (r.stdout or "") + (r.stderr or "")
    devices = []
    for m in re.finditer(r"^(\d+):\s+(.+)$", out, re.MULTILINE):
        devices.append({"id": int(m.group(1)), "name": m.group(2).strip()})
    return {
        "backed": len(devices) > 0,
        "binary": True,
        "devices": devices,
        "n": len(devices),
        "names": list(RGB_PALETTE.keys()),
    }


def _rgb_set(name: str) -> dict:
    probe = _rgb_probe()
    if not probe.get("backed"):
        return {"ok": False, "error": "OpenRGB found no controllable devices", "rgb": probe}
    key = (name or "").strip()
    hex_col = RGB_PALETTE.get(key) or RGB_PALETTE.get(key.title())
    if not hex_col:
        return {"ok": False, "error": "unknown palette name", "names": list(RGB_PALETTE.keys())}
    r = _run(["openrgb", "--mode", "static", "--color", hex_col.lstrip("#")], timeout=8)
    if r and r.returncode == 0:
        return {"ok": True, "name": key, "hex": hex_col, "rgb": probe}
    err = (r.stderr or r.stdout or "openrgb failed").strip() if r else "openrgb failed"
    return {"ok": False, "error": err, "name": key, "hex": hex_col, "rgb": probe}


def _rgb_mode(mode: str) -> dict:
    probe = _rgb_probe()
    if not probe.get("backed"):
        return {"ok": False, "error": "OpenRGB found no controllable devices", "rgb": probe}
    mode = (mode or "static").strip().lower()
    cmd = ["openrgb", "--mode", mode]
    r = _run(cmd, timeout=8)
    if r and r.returncode == 0:
        return {"ok": True, "mode": mode, "rgb": probe}
    err = (r.stderr or r.stdout or "openrgb failed").strip() if r else "openrgb failed"
    return {"ok": False, "error": err, "mode": mode, "rgb": probe}


def _power_set(mode: str) -> dict:
    mode = (mode or "").strip()
    if not mode:
        return {"ok": False, "error": "no power mode given"}
    r = _run(["powerprofilesctl", "set", mode], timeout=5)
    if r and r.returncode == 0:
        return {"ok": True, "active": mode, "power": _ppd()}
    err = (r.stderr or "powerprofilesctl failed").strip() if r else "powerprofilesctl not available"
    pp = Path("/sys/firmware/acpi/platform_profile")
    if pp.exists():
        ok, werr = _write_priv(pp, mode)
        if ok:
            return {"ok": True, "active": mode, "power": _ppd(), "via": "platform_profile"}
        err = werr or err
    return {"ok": False, "error": err, "power": _ppd()}


def main(argv: list[str]) -> int:
    cmd = argv[1] if len(argv) > 1 else "snapshot"
    if cmd in ("snapshot", "snap"):
        _out(snapshot())
        return 0
    if cmd in ("procs", "ps"):
        rows = _procs()
        _out({"ok": True, "procs": rows, "n": len(rows)})
        return 0
    if cmd == "kill":
        if len(argv) < 3:
            _out({"ok": False, "error": "kill needs a PID"})
            return 1
        try:
            pid = int(argv[2])
        except ValueError:
            _out({"ok": False, "error": "PID is not a number"})
            return 1
        _out(_kill(pid))
        return 0
    if cmd in ("profiles", "profile"):
        sub = argv[2] if len(argv) > 2 else "list"
        ps = _load_profiles()
        if sub == "list":
            _out({"ok": True, "profiles": ps, "path": str(PROFILES)})
            return 0
        if sub == "apply":
            key = argv[3] if len(argv) > 3 else ""
            p, idx = _find_profile(ps, key)
            if p is None:
                _out({"ok": False, "error": "no such profile", "profiles": ps})
                return 1
            notes = []
            name = str(p.get("name") or "").strip().lower()
            target = _PROFILE_TO_PPD.get(name)
            if target:
                res = _power_set(target)
                notes.append("power " + ("→ " + target if res.get("ok") else "failed"))
            if "boost" in p:
                ok, err = _boost_write(bool(p.get("boost")))
                notes.append("boost " + ("on" if p.get("boost") else "off") if ok else ("boost: " + err))
            _out({"ok": True, "applied": p.get("name"), "index": idx, "profile": p, "notes": notes,
                  "governor": p.get("governor"), "fan_mode": p.get("fan_mode"),
                  "fan_pwm_pct": p.get("fan_pwm_pct"), "boost": p.get("boost")})
            return 0
        if sub == "new":
            ps.append({"name": "New Profile", "governor": "", "boost": True,
                       "fan_pwm_pct": 50, "fan_mode": "low", "description": "Custom"})
            _save_profiles(ps)
            _out({"ok": True, "profiles": ps, "index": len(ps) - 1})
            return 0
        if sub == "delete":
            key = argv[3] if len(argv) > 3 else ""
            p, idx = _find_profile(ps, key)
            if p is None:
                _out({"ok": False, "error": "no such profile"})
                return 1
            if len(ps) <= 1:
                _out({"ok": False, "error": "keep at least one profile"})
                return 1
            gone = ps.pop(idx)
            _save_profiles(ps)
            _out({"ok": True, "deleted": gone.get("name"), "profiles": ps})
            return 0
        if sub == "save":
            raw = argv[3] if len(argv) > 3 else sys.stdin.read()
            try:
                doc = json.loads(raw)
            except json.JSONDecodeError as e:
                _out({"ok": False, "error": "bad JSON: %s" % e})
                return 1
            if not isinstance(doc, list):
                _out({"ok": False, "error": "profiles document must be a list"})
                return 1
            _save_profiles(doc)
            _out({"ok": True, "profiles": doc})
            return 0
        _out({"ok": False, "error": "profiles subcommand unknown"})
        return 1
    if cmd == "rgb":
        sub = argv[2] if len(argv) > 2 else "list"
        if sub == "list":
            probe = _rgb_probe()
            probe["ok"] = True
            _out(probe)
            return 0
        if sub == "set":
            _out(_rgb_set(argv[3] if len(argv) > 3 else ""))
            return 0
        if sub == "mode":
            _out(_rgb_mode(argv[4] if len(argv) > 4 else (argv[3] if len(argv) > 3 else "static")))
            return 0
        _out({"ok": False, "error": "rgb subcommand unknown"})
        return 1
    if cmd == "power":
        sub = argv[2] if len(argv) > 2 else "get"
        if sub == "get":
            p = _ppd()
            p["ok"] = True
            _out(p)
            return 0
        if sub == "set":
            _out(_power_set(argv[3] if len(argv) > 3 else ""))
            return 0
        _out({"ok": False, "error": "power subcommand unknown"})
        return 1
    if cmd == "boost":
        sub = argv[2] if len(argv) > 2 else "get"
        if sub == "get":
            _out({"ok": True, "boost": _boost_read()})
            return 0
        if sub == "set":
            raw = (argv[3] if len(argv) > 3 else "").strip().lower()
            on = raw in ("1", "on", "true", "yes")
            ok, err = _boost_write(on)
            _out({"ok": ok, "boost": _boost_read(), "error": err})
            return 0 if ok else 1
        _out({"ok": False, "error": "boost subcommand unknown"})
        return 1
    _out({"ok": False, "error": "unknown command"})
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
