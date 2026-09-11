#!/usr/bin/env python3
"""Open-Meteo fetch + cache for Weather.qml. Same files as GTK nyxus_weather.py."""
from __future__ import annotations

import json
import sys
import urllib.parse
import urllib.request
from datetime import datetime
from pathlib import Path

CONF = Path.home() / ".config/nyxus/weather.json"
CACHE = Path.home() / ".cache/nyxus/weather-cache.json"
UA = "nyxus-weather/1.0"

WMO = {
    0: "Clear", 1: "Mostly clear", 2: "Partly cloudy", 3: "Overcast",
    45: "Fog", 48: "Rime fog",
    51: "Light drizzle", 53: "Drizzle", 55: "Heavy drizzle",
    61: "Light rain", 63: "Rain", 65: "Heavy rain",
    66: "Freezing rain", 67: "Freezing rain",
    71: "Light snow", 73: "Snow", 75: "Heavy snow", 77: "Snow grains",
    80: "Showers", 81: "Showers", 82: "Violent showers",
    85: "Snow showers", 86: "Snow showers",
    95: "Thunderstorm", 96: "Thunderstorm, hail", 99: "Thunderstorm, hail",
}


def _get(url: str, timeout: int = 12) -> dict:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode())


def _conf() -> dict:
    try:
        return json.loads(CONF.read_text())
    except (OSError, json.JSONDecodeError):
        return {"units": "imperial", "places": []}


def _save_conf(c: dict) -> None:
    try:
        CONF.parent.mkdir(parents=True, exist_ok=True)
        CONF.write_text(json.dumps(c, indent=2) + "\n")
    except OSError:
        pass


def _pack(data: dict, air: dict | None, conf: dict, at: str) -> dict:
    cur = dict(data.get("current") or {})
    units = data.get("current_units") or {}
    code = int(cur.get("weather_code") or 0)
    wunit = units.get("wind_speed_10m", "km/h")
    wunit = {"mp/h": "mph"}.get(wunit, wunit)
    hourly = data.get("hourly") or {}
    hours = []
    times = hourly.get("time") or []
    temps = hourly.get("temperature_2m") or []
    pops = hourly.get("precipitation_probability") or []
    for i in range(min(24, len(times))):
        t = times[i]
        hours.append({
            "t": t[11:16] if len(t) >= 16 else t,
            "temp": temps[i] if i < len(temps) else None,
            "pop": pops[i] if i < len(pops) else None,
        })
    daily = data.get("daily") or {}
    days = []
    dtimes = daily.get("time") or []
    dmax = daily.get("temperature_2m_max") or []
    dmin = daily.get("temperature_2m_min") or []
    dcode = daily.get("weather_code") or []
    dpop = daily.get("precipitation_probability_max") or []
    for i in range(min(7, len(dtimes))):
        days.append({
            "date": dtimes[i],
            "max": dmax[i] if i < len(dmax) else None,
            "min": dmin[i] if i < len(dmin) else None,
            "label": WMO.get(int(dcode[i] if i < len(dcode) else 0), "—"),
            "pop": dpop[i] if i < len(dpop) else None,
        })
    aqi = None
    if air and air.get("current"):
        aqi = air["current"].get("european_aqi")
    return {
        "ok": True,
        "at": at,
        "name": conf.get("name") or "",
        "admin": conf.get("admin") or "",
        "units": conf.get("units") or "metric",
        "places": conf.get("places") or [],
        "temp": cur.get("temperature_2m"),
        "feel": cur.get("apparent_temperature"),
        "label": WMO.get(code, "—"),
        "unit": units.get("temperature_2m", "°C"),
        "wind": cur.get("wind_speed_10m"),
        "wunit": wunit,
        "gust": cur.get("wind_gusts_10m"),
        "hum": cur.get("relative_humidity_2m"),
        "press": cur.get("pressure_msl"),
        "uv": cur.get("uv_index"),
        "cloud": cur.get("cloud_cover"),
        "aqi": aqi,
        "sunrise": (daily.get("sunrise") or [""])[0],
        "sunset": (daily.get("sunset") or [""])[0],
        "hours": hours,
        "days": days,
    }


def cmd_show() -> None:
    conf = _conf()
    try:
        c = json.loads(CACHE.read_text())
        packed = _pack(c["data"], c.get("air"), conf, c.get("at") or "")
        packed["cached"] = True
        json.dump(packed, sys.stdout)
        return
    except Exception:
        pass
    if conf.get("lat") is None:
        json.dump({"ok": True, "empty": True, "units": conf.get("units", "imperial"),
                   "places": conf.get("places") or [], "name": ""}, sys.stdout)
        return
    cmd_fetch()


def cmd_fetch() -> None:
    conf = _conf()
    if conf.get("lat") is None:
        json.dump({"ok": False, "error": "Search for a city to begin."}, sys.stdout)
        return
    imperial = conf.get("units") == "imperial"
    url = (
        "https://api.open-meteo.com/v1/forecast"
        f"?latitude={conf['lat']}&longitude={conf['lon']}"
        "&current=temperature_2m,apparent_temperature,weather_code,"
        "wind_speed_10m,wind_direction_10m,wind_gusts_10m,"
        "relative_humidity_2m,dew_point_2m,precipitation,"
        "cloud_cover,pressure_msl,uv_index,is_day"
        "&hourly=temperature_2m,weather_code,precipitation_probability"
        "&daily=weather_code,temperature_2m_max,temperature_2m_min,"
        "sunrise,sunset,uv_index_max,precipitation_sum,"
        "precipitation_probability_max"
        "&timezone=auto&forecast_days=7&forecast_hours=24"
    )
    if imperial:
        url += "&temperature_unit=fahrenheit&wind_speed_unit=mph"
    data = _get(url)
    air = None
    try:
        aurl = (
            "https://air-quality-api.open-meteo.com/v1/air-quality"
            f"?latitude={conf['lat']}&longitude={conf['lon']}"
            "&current=european_aqi,pm2_5,pm10&timezone=auto"
        )
        air = _get(aurl, timeout=6)
    except Exception:
        air = None
    at = datetime.now().isoformat(timespec="minutes")
    try:
        CACHE.parent.mkdir(parents=True, exist_ok=True)
        CACHE.write_text(json.dumps({"at": at, "conf": conf, "data": data, "air": air}))
    except OSError:
        pass
    packed = _pack(data, air, conf, at)
    packed["cached"] = False
    json.dump(packed, sys.stdout)


def cmd_search(q: str) -> None:
    url = ("https://geocoding-api.open-meteo.com/v1/search?name="
           + urllib.parse.quote(q) + "&count=1&language=en&format=json")
    res = (_get(url).get("results") or [])
    if not res:
        json.dump({"ok": False, "error": f"No place called “{q}”."}, sys.stdout)
        return
    r = res[0]
    place = {"lat": r["latitude"], "lon": r["longitude"],
             "name": r["name"], "admin": r.get("admin1") or r.get("country") or ""}
    conf = _conf()
    conf.update(place)
    places = [p for p in (conf.get("places") or [])
              if not (p.get("lat") == place["lat"] and p.get("lon") == place["lon"])]
    places.insert(0, place)
    conf["places"] = places[:8]
    _save_conf(conf)
    cmd_fetch()


def cmd_units() -> None:
    conf = _conf()
    conf["units"] = "imperial" if conf.get("units") != "imperial" else "metric"
    _save_conf(conf)
    cmd_fetch()


def cmd_place(name: str) -> None:
    conf = _conf()
    for p in conf.get("places") or []:
        if p.get("name") == name:
            conf.update({"lat": p["lat"], "lon": p["lon"],
                         "name": p.get("name", ""), "admin": p.get("admin", "")})
            _save_conf(conf)
            cmd_fetch()
            return
    json.dump({"ok": False, "error": "unknown place"}, sys.stdout)


def _bulletin_from(packed: dict) -> str:
    name = packed.get("name") or "here"
    label = packed.get("label") or "unknown"
    temp = packed.get("temp")
    unit = packed.get("unit") or ""
    feel = packed.get("feel")
    wind = packed.get("wind")
    wunit = packed.get("wunit") or ""
    bits = [f"Weather for {name}. {label}"]
    if temp is not None:
        bits.append(f"{temp}{unit}")
    if feel is not None:
        bits.append(f"feels like {feel}")
    line = ", ".join(bits) if len(bits) > 1 else bits[0]
    if wind is not None:
        line += f". Wind {wind} {wunit}"
    return line + "."


def cmd_bulletin() -> None:
    try:
        c = json.loads(CACHE.read_text())
        packed = _pack(c["data"], c.get("air"), _conf(), c.get("at") or "")
    except Exception:
        conf = _conf()
        if conf.get("lat") is None:
            json.dump({"ok": False, "error": "Search for a city to begin."}, sys.stdout)
            return
        cmd_fetch()
        return
    text = _bulletin_from(packed)
    json.dump({"ok": True, "text": text}, sys.stdout)


def cmd_speak() -> None:
    import shutil
    import subprocess
    try:
        c = json.loads(CACHE.read_text())
        packed = _pack(c["data"], c.get("air"), _conf(), c.get("at") or "")
    except Exception:
        json.dump({"ok": False, "error": "No forecast cached yet."}, sys.stdout)
        return
    text = _bulletin_from(packed)
    voice = shutil.which("espeak-ng") or shutil.which("espeak") or shutil.which("spd-say")
    if not voice:
        json.dump({"ok": False, "error": "No voice on this machine (espeak-ng).", "text": text}, sys.stdout)
        return
    cmd = [voice, "-v", "en-us", "-s", "155", text] if "espeak" in voice else [voice, text]
    try:
        subprocess.Popen(cmd, start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        json.dump({"ok": True, "text": text}, sys.stdout)
    except OSError as e:
        json.dump({"ok": False, "error": str(e), "text": text}, sys.stdout)


if __name__ == "__main__":
    op = sys.argv[1] if len(sys.argv) > 1 else "show"
    if op == "fetch":
        cmd_fetch()
    elif op == "search" and len(sys.argv) > 2:
        cmd_search(" ".join(sys.argv[2:]))
    elif op == "units":
        cmd_units()
    elif op == "place" and len(sys.argv) > 2:
        cmd_place(sys.argv[2])
    elif op == "bulletin":
        cmd_bulletin()
    elif op == "speak":
        cmd_speak()
    else:
        cmd_show()
