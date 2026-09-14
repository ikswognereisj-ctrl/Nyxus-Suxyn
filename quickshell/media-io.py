#!/usr/bin/env python3
"""Library, mixes, play, and EasyEffects EQ for Media.qml."""
from __future__ import annotations

import fcntl
import json
import os
import socket
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

LIB = Path.home() / ".local/share/nyxus/media/library.json"
CFG = Path.home() / ".config/nyxus/media.json"
MIX_DIR = Path.home() / ".local/share/nyxus/media/mixes"
KEEPS = str(Path.home() / "Music/NYXUS Keeps")
CACHE = Path.home() / ".cache/nyxus"
GENRE_CACHE = CACHE / "media-genre.json"
PLAYLIST = CACHE / "media-queue.m3u8"
SOCK = CACHE / "media.sock"
EQ_LOCK = CACHE / "media-eq.lock"
EE_DIRS = (
    Path.home() / ".local/share/easyeffects/output",
    Path.home() / ".config/easyeffects/output",
)
EE_SOCK = Path(os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}") / "EasyEffectsServer"

# Fifteen 10-band curves. First ten match GTK nyxus_media.py; five more
# so the Tone page has a full preset row like the owner remembers.
EQ_PRESETS = {
    "Flat":         [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    "Bass Boost":   [6.5, 5.5, 4.0, 2.0, 0, 0, 0, 0, 0, 0],
    "Bass Cut":     [-6.0, -5.0, -3.5, -1.5, 0, 0, 0, 0, 0, 0],
    "Treble Boost": [0, 0, 0, 0, 0.5, 1.5, 3.0, 5.0, 6.5, 7.0],
    "Vocal":        [-2.0, -1.5, 0, 2.5, 4.0, 4.0, 2.5, 1.0, 0, -1.0],
    "Acoustic":     [3.5, 2.5, 1.5, 0.5, 1.5, 1.0, 2.0, 3.0, 2.5, 1.5],
    "Rock":         [4.5, 3.0, 1.0, -1.0, -1.5, 0.5, 2.5, 4.0, 4.5, 4.0],
    "Pop":          [-1.0, 1.5, 3.0, 3.5, 2.5, 0, -1.0, -1.0, 0, 1.0],
    "Jazz":         [3.0, 2.0, 0.5, 1.5, -1.0, -1.0, 0, 1.0, 2.5, 3.5],
    "Classical":    [3.5, 2.5, 1.0, 0, 0, 0, -1.0, -1.5, -1.5, -2.5],
    "Electronic":   [4.5, 3.5, 0.5, -1.5, -2.0, 1.0, 0.5, 1.5, 4.0, 4.5],
    "Dance":        [5.5, 4.0, 1.5, 0, -1.5, -1.0, 1.0, 2.5, 4.0, 4.5],
    "Hip-Hop":      [7.0, 5.5, 1.5, 0, -1.0, 0.5, 1.5, 2.0, 3.0, 3.5],
    "Loudness":     [5.0, 3.5, 0, -2.0, -3.0, -2.0, 0, 2.0, 4.0, 5.0],
    "Night":        [-3.0, -2.0, 0, 2.0, 3.0, 3.0, 1.5, 0, -1.5, -3.0],
}
EQ_FREQS = [31.0, 62.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0]


def usable_art(p: str) -> str:
    if not p:
        return ""
    path = Path(p)
    if not path.is_file():
        return ""
    if path.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp", ".gif"}:
        return str(path)
    alias = Path(str(path) + ".jpg")
    if not alias.exists():
        try:
            alias.symlink_to(path.name)
        except OSError:
            return str(path)
    return str(alias)


def _load_cfg() -> dict:
    try:
        cfg = json.loads(CFG.read_text())
    except (OSError, json.JSONDecodeError):
        cfg = {}
    return cfg if isinstance(cfg, dict) else {}


def _save_cfg(cfg: dict) -> None:
    CFG.parent.mkdir(parents=True, exist_ok=True)
    tmp = CFG.with_name(f"{CFG.stem}.{os.getpid()}.tmp")
    tmp.write_text(json.dumps(cfg, indent=2) + "\n")
    tmp.replace(CFG)


def _flac_tags(path: Path) -> dict:
    try:
        data = path.read_bytes()
    except OSError:
        return {}
    if data[:4] != b"fLaC":
        return {}
    i = 4
    out = {}
    while i + 4 <= len(data):
        hdr = int.from_bytes(data[i:i + 4], "big")
        last = bool(hdr & 0x80000000)
        typ = (hdr >> 24) & 0x7F
        size = hdr & 0xFFFFFF
        i += 4
        block = data[i:i + size]
        i += size
        if typ == 4 and len(block) >= 8:
            vlen = int.from_bytes(block[0:4], "little")
            o = 4 + vlen
            if o + 4 > len(block):
                break
            n = int.from_bytes(block[o:o + 4], "little")
            o += 4
            for _ in range(n):
                if o + 4 > len(block):
                    break
                sl = int.from_bytes(block[o:o + 4], "little")
                o += 4
                s = block[o:o + sl].decode("utf-8", "replace")
                o += sl
                if "=" in s:
                    k, v = s.split("=", 1)
                    out[k.upper()] = v.strip()
            break
        if last:
            break
    return out


def _id3_genre(path: Path) -> str:
    try:
        tail = path.read_bytes()[-128:]
    except OSError:
        return ""
    if len(tail) == 128 and tail[:3] == b"TAG":
        g = tail[127]
        names = (
            "Blues", "Classic Rock", "Country", "Dance", "Disco", "Funk",
            "Grunge", "Hip-Hop", "Jazz", "Metal", "New Age", "Oldies", "Other",
            "Pop", "R&B", "Rap", "Reggae", "Rock", "Techno", "Industrial",
            "Alternative", "Ska", "Death Metal", "Pranks", "Soundtrack",
            "Euro-Techno", "Ambient", "Trip-Hop", "Vocal", "Jazz+Funk",
            "Fusion", "Trance", "Classical", "Instrumental", "Acid", "House",
        )
        if 0 <= g < len(names):
            return names[g]
    return ""


def _genre_of(path: str, rec: dict, cache: dict) -> str:
    tagged = str(rec.get("genre") or "").strip()
    if tagged:
        return tagged
    try:
        st = Path(path).stat()
        mtime = int(st.st_mtime)
    except OSError:
        return "Untagged"
    hit = cache.get(path)
    if isinstance(hit, dict) and hit.get("mtime") == mtime:
        return str(hit.get("genre") or "Untagged")
    p = Path(path)
    g = ""
    suf = p.suffix.lower()
    if suf == ".flac":
        g = _flac_tags(p).get("GENRE") or ""
    elif suf in {".mp3", ".mp2"}:
        g = _id3_genre(p)
    g = (g or "").strip() or "Untagged"
    cache[path] = {"mtime": mtime, "genre": g}
    return g


def _track(path: str, rec: dict, genre: str) -> dict:
    return {
        "path": path,
        "title": rec.get("title") or Path(path).stem,
        "artist": rec.get("artist") or "",
        "album": rec.get("album") or "",
        "genre": genre,
        "art": usable_art(rec.get("art") or ""),
        "duration": float(rec.get("duration") or 0),
        "mtime": int(rec.get("mtime") or 0),
        "kept": path.startswith(KEEPS),
    }


def _alpha(t: dict) -> str:
    return (t.get("title") or "").casefold()


def _user_mixes() -> list:
    MIX_DIR.mkdir(parents=True, exist_ok=True)
    out = []
    for p in sorted(MIX_DIR.glob("*.m3u8"), key=lambda q: q.stem.casefold()):
        if p.stem.startswith("Auto · "):
            continue
        paths = []
        try:
            for line in p.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if line and not line.startswith("#"):
                    paths.append(line)
        except OSError:
            continue
        out.append({"name": p.stem, "auto": False, "count": len(paths), "paths": paths})
    return out


def _write_mix(name: str, tracks: list[dict]) -> None:
    MIX_DIR.mkdir(parents=True, exist_ok=True)
    safe = "".join(c if c.isalnum() or c in " ·-_" else "_" for c in name)[:80]
    path = MIX_DIR / f"{safe}.m3u8"
    lines = ["#EXTM3U", f"#PLAYLIST:{name}"]
    for t in tracks:
        lines.append(f"#EXTINF:{int(t.get('duration') or 0)},{t.get('title')}")
        lines.append(t["path"])
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _auto_mixes(tracks: list[dict]) -> list:
    by_mtime = sorted(tracks, key=lambda t: t.get("mtime") or 0, reverse=True)
    kept = [t for t in tracks if t.get("kept")]
    packs = [
        ("Auto · Recently Added", by_mtime[:24]),
        ("Auto · Kept", kept[:40]),
        ("Auto · A–Z", sorted(tracks, key=_alpha)[:40]),
    ]
    by_g: dict[str, list] = defaultdict(list)
    for t in tracks:
        g = t.get("genre") or "Untagged"
        if g != "Untagged":
            by_g[g].append(t)
    for g, rows in sorted(by_g.items(), key=lambda kv: kv[0].casefold()):
        if len(rows) >= 4:
            packs.append((f"Auto · {g}", sorted(rows, key=_alpha)[:40]))
    out = []
    for name, rows in packs:
        if not rows:
            continue
        _write_mix(name, rows)
        out.append({
            "name": name,
            "auto": True,
            "count": len(rows),
            "paths": [t["path"] for t in rows],
        })
    return out


AUDIO_EXT = {
    ".mp3", ".flac", ".ogg", ".oga", ".opus", ".m4a", ".mp4", ".aac", ".wav",
    ".wma", ".aiff", ".aif", ".ape", ".wv", ".mpc", ".alac", ".m4b", ".spx",
}


def _folders(cfg: dict) -> list[Path]:
    raw = cfg.get("folders")
    if isinstance(raw, list) and raw:
        out = [Path(p).expanduser() for p in raw if p]
    else:
        out = [Path.home() / "Music"]
    return [p for p in out if p.is_dir()]


def _walk_audio(folders: list[Path]) -> list[Path]:
    found: list[Path] = []
    for root in folders:
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if not d.startswith(".")]
            for name in filenames:
                if os.path.splitext(name)[1].lower() in AUDIO_EXT:
                    found.append(Path(dirpath) / name)
    return found


def _meta_from_path(path: Path, st: os.stat_result) -> dict:
    rec = {
        "mtime": int(st.st_mtime),
        "size": st.st_size,
        "title": path.stem,
        "artist": "",
        "album": "",
        "genre": "",
        "art": "",
        "duration": 0,
    }
    parts = path.parts
    # …/Artist/Album/Track.flac
    if len(parts) >= 3:
        rec["album"] = parts[-2]
        rec["artist"] = parts[-3]
        if rec["artist"] in ("Music", "NYXUS Keeps"):
            rec["artist"] = ""
    if path.suffix.lower() == ".flac":
        tags = _flac_tags(path)
        if tags.get("TITLE"):
            rec["title"] = tags["TITLE"]
        if tags.get("ARTIST"):
            rec["artist"] = tags["ARTIST"]
        if tags.get("ALBUM"):
            rec["album"] = tags["ALBUM"]
        if tags.get("GENRE"):
            rec["genre"] = tags["GENRE"]
    return rec


def _scan_library(cfg: dict) -> dict:
    """Incremental walk of the configured folders into library.json.

    Tape keeps dropping FLACs into NYXUS Keeps; Media used to only *read*
    the cache GTK last wrote, so the count froze while the tape ran.
    """
    lib: dict = {}
    try:
        lib = json.loads(LIB.read_text())
    except (OSError, json.JSONDecodeError):
        lib = {}
    if not isinstance(lib, dict):
        lib = {}
    files = _walk_audio(_folders(cfg))
    dirty = False
    live = {}
    for path in files:
        key = str(path)
        try:
            st = path.stat()
        except OSError:
            continue
        ent = lib.get(key)
        if not (isinstance(ent, dict)
                and ent.get("mtime") == int(st.st_mtime)
                and ent.get("size") == st.st_size):
            ent = _meta_from_path(path, st)
            dirty = True
        live[key] = ent
    if set(live) != set(lib):
        dirty = True
    if dirty:
        LIB.parent.mkdir(parents=True, exist_ok=True)
        tmp = LIB.with_suffix(".json.tmp")
        tmp.write_text(json.dumps(live))
        tmp.replace(LIB)
    return live


def cmd_list() -> None:
    cfg = _load_cfg()
    lib = _scan_library(cfg)
    auto = bool(cfg.get("auto_mixes", True))
    gcache = {}
    try:
        gcache = json.loads(GENRE_CACHE.read_text())
    except (OSError, json.JSONDecodeError):
        gcache = {}
    if not isinstance(gcache, dict):
        gcache = {}

    tracks = []
    for p, rec in lib.items():
        if not rec:
            continue
        g = _genre_of(p, rec, gcache)
        tracks.append(_track(p, rec, g))
    tracks.sort(key=_alpha)
    try:
        CACHE.mkdir(parents=True, exist_ok=True)
        GENRE_CACHE.write_text(json.dumps(gcache))
    except OSError:
        pass

    albums_map: dict[tuple[str, str], dict] = {}
    genre_map: dict[str, list] = defaultdict(list)
    for t in tracks:
        key = (t["album"] or "Unknown album", t["artist"] or "")
        slot = albums_map.get(key)
        if slot is None:
            albums_map[key] = {
                "title": key[0], "artist": key[1], "art": t["art"],
                "count": 1, "paths": [t["path"]],
            }
        else:
            slot["count"] += 1
            slot["paths"].append(t["path"])
            if not slot["art"] and t["art"]:
                slot["art"] = t["art"]
        genre_map[t["genre"] or "Untagged"].append(t)

    albums = sorted(albums_map.values(), key=lambda a: a["title"].casefold())
    genres = []
    for name in sorted(genre_map.keys(), key=str.casefold):
        rows = sorted(genre_map[name], key=_alpha)
        genres.append({
            "name": name,
            "count": len(rows),
            "tracks": rows,
        })
    kept = [t for t in tracks if t["kept"]]
    mixes = _user_mixes()
    if auto:
        mixes = _auto_mixes(tracks) + mixes

    json.dump({
        "tracks": tracks,
        "albums": albums,
        "kept": kept,
        "genres": genres,
        "mixes": mixes,
        "albumCount": len(albums_map),
        "trackCount": len(tracks),
        "genreCount": len(genres),
        "autoMixes": auto,
    }, sys.stdout)


def _eq_af(enabled: bool, bands: list[float]) -> str:
    """ffmpeg equalizer chain for mpv. Used only when EasyEffects is down."""
    if not enabled:
        return ""
    parts = []
    for i, g in enumerate(bands):
        try:
            gain = float(g)
        except (TypeError, ValueError):
            continue
        if abs(gain) < 0.05:
            continue
        parts.append(f"equalizer=f={EQ_FREQS[i]}:t=q:width=1:g={gain:.2f}")
    return ",".join(parts)


def _apply_eq_to_mpv(enabled: bool, bands: list[float]) -> bool:
    return _mpv_cmd(["set_property", "af", _eq_af(enabled, bands)])


def _eq_from_cfg() -> tuple[bool, list[float]]:
    cfg = _load_cfg()
    bands = cfg.get("eq_bands")
    if not isinstance(bands, list) or len(bands) != 10:
        bands = list(EQ_PRESETS.get(str(cfg.get("eq_preset") or "Flat"), EQ_PRESETS["Flat"]))
    return bool(cfg.get("eq_enabled", True)), [float(x) for x in bands]


def _ee_talk(lines: list[str], want_reply: bool = False) -> str | None:
    """Talk to the already-running Easy Effects 8 local server.

    Never spawn `easyeffects`: a second Qt instance SIGSEGVs on teardown
    (coredump 2026-09-10 / 2026-09-12) and nyxus-crashd fires notify-send.
    """
    if not EE_SOCK.exists():
        return None
    blob = "".join(x if x.endswith("\n") else x + "\n" for x in lines).encode()
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(1.0)
    try:
        s.connect(str(EE_SOCK))
        s.sendall(blob)
        if not want_reply:
            return ""
        data = b""
        while True:
            chunk = s.recv(4096)
            if not chunk:
                break
            data += chunk
            if b"\n" in data:
                break
        return data.decode("utf-8", "replace").strip()
    except OSError:
        return None
    finally:
        try:
            s.close()
        except OSError:
            pass


def _apply_eq_to_easyeffects(enabled: bool, bands: list[float]) -> bool:
    """Set live equalizer#0 gains on the running service. No GUI, no -l."""
    probe = _ee_talk(["get_property:output:equalizer:0:bypass"], want_reply=True)
    if probe is None:
        return False
    if probe.startswith("error_"):
        _ee_talk(["load_preset:output:nyxus-media-eq"])
        probe = _ee_talk(["get_property:output:equalizer:0:bypass"], want_reply=True)
        if probe is None or probe.startswith("error_"):
            return False
    cmds = [
        f"set_property:output:equalizer:0:bypass:{'true' if not enabled else 'false'}",
    ]
    split = _ee_talk(["get_property:output:equalizer:0:splitChannels"], want_reply=True)
    channels = ["left"]
    if split == "true":
        channels.append("right")
    for ch in channels:
        for i, g in enumerate(bands[:10]):
            gain = 0.0 if not enabled else float(g)
            cmds.append(f"set_property:output:equalizer:0:{ch}:band{i}Gain:{gain:.3f}")
    if _ee_talk(cmds) is None:
        return False
    check = _ee_talk(["get_property:output:equalizer:0:left:band0Gain"], want_reply=True)
    if check is None or check.startswith("error_"):
        return False
    return True


def _apply_eq(enabled: bool, bands: list[float]) -> bool:
    """EasyEffects socket first (system output). mpv lavfi only if EE is down."""
    if _apply_eq_to_easyeffects(enabled, bands):
        if SOCK.exists():
            _apply_eq_to_mpv(False, bands)
        return True
    return _apply_eq_to_mpv(enabled, bands)


def _mpv_cmd(cmd: list) -> bool:
    try:
        s = socket.socket(socket.AF_UNIX)
        s.settimeout(0.5)
        s.connect(str(SOCK))
        s.sendall((json.dumps({"command": cmd}) + "\n").encode())
        s.close()
        return True
    except OSError:
        return False


def _kill_stale_players() -> None:
    """Stop every mpv bound to our IPC socket. Unlinking the socket does not
    kill them — that is how a pile of headless players kept audio going with
    no window (owner, third time)."""
    marker = str(SOCK)
    me = os.getpid()
    for ent in os.listdir("/proc"):
        if not ent.isdigit():
            continue
        pid = int(ent)
        if pid == me:
            continue
        try:
            raw = Path(f"/proc/{pid}/cmdline").read_bytes()
        except OSError:
            continue
        cmd = raw.replace(b"\0", b" ").decode("utf-8", "replace")
        if "mpv" in cmd and marker in cmd:
            try:
                os.kill(pid, 15)
            except OSError:
                pass
    try:
        SOCK.unlink()
    except OSError:
        pass


def cmd_care() -> None:
    try:
        lib = json.loads(LIB.read_text())
    except (OSError, json.JSONDecodeError):
        lib = {}
    recs = lib.get("tracks") or lib.get("songs") or []
    if not isinstance(recs, list):
        recs = []
    missing = []
    seen: dict[str, list] = defaultdict(list)
    kept = 0
    for rec in recs:
        if not isinstance(rec, dict):
            continue
        path = str(rec.get("path") or "")
        title = str(rec.get("title") or Path(path).stem)
        artist = str(rec.get("artist") or "")
        if rec.get("kept") or path.startswith(KEEPS):
            kept += 1
        if path and not Path(path).is_file():
            missing.append({"title": title, "artist": artist, "path": path})
        key = f"{artist.lower().strip()}|{title.lower().strip()}"
        if artist or title:
            seen[key].append({"title": title, "artist": artist, "path": path})
    dups = [v for v in seen.values() if len(v) > 1]
    json.dump({
        "total": len(recs),
        "kept": kept,
        "missing": missing[:40],
        "missingCount": len(missing),
        "dupGroups": len(dups),
        "dups": [{"title": g[0]["title"], "artist": g[0]["artist"], "n": len(g)}
                 for g in dups[:30]],
    }, sys.stdout)


def cmd_play() -> None:
    raw = sys.argv[2] if len(sys.argv) > 2 else sys.stdin.read()
    req = json.loads(raw)
    paths = [str(p) for p in (req.get("paths") or []) if p]
    start = int(req.get("start") or 0)
    if not paths:
        json.dump({"ok": False, "error": "nothing to play"}, sys.stdout)
        return
    start = max(0, min(start, len(paths) - 1))
    if req.get("shuffle") and len(paths) > 1:
        import random
        head = paths[start]
        rest = paths[:start] + paths[start + 1 :]
        random.shuffle(rest)
        paths = [head] + rest
        start = 0
    CACHE.mkdir(parents=True, exist_ok=True)
    lines = ["#EXTM3U"]
    lines.extend(paths)
    PLAYLIST.write_text("\n".join(lines) + "\n")
    # Reuse the live player if it still answers. NEVER unlink the socket
    # first: that makes IPC fail, starts a second mpv, and the old one
    # keeps playing with no window.
    enabled, bands = _eq_from_cfg()
    ee_live = _apply_eq_to_easyeffects(enabled, bands)
    af = "" if ee_live else _eq_af(enabled, bands)
    if _mpv_cmd(["loadlist", str(PLAYLIST), "replace"]):
        _mpv_cmd(["playlist-play-index", start])
        if not ee_live:
            _apply_eq_to_mpv(enabled, bands)
        json.dump({"ok": True, "n": len(paths), "via": "ipc"}, sys.stdout)
        return
    _kill_stale_players()
    argv = [
        "mpv", "--no-video", "--force-window=no",
        "--idle=yes", "--keep-open=no",
        f"--input-ipc-server={SOCK}",
        f"--playlist-start={start}",
        "--title=Media",
        str(PLAYLIST),
    ]
    if af:
        argv.insert(-1, f"--af={af}")
    mpris = Path("/usr/lib/mpv/scripts/mpris.so")
    if mpris.is_file():
        argv[1:1] = [f"--script={mpris}"]
    subprocess.Popen(
        argv,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
        env=os.environ.copy(),
    )
    json.dump({"ok": True, "n": len(paths), "via": "mpv"}, sys.stdout)


def cmd_stop() -> None:
    _mpv_cmd(["stop"])
    _kill_stale_players()
    json.dump({"ok": True}, sys.stdout)


def cmd_auto(on: bool) -> None:
    cfg = _load_cfg()
    cfg["auto_mixes"] = bool(on)
    _save_cfg(cfg)
    if not on:
        for p in MIX_DIR.glob("Auto · *.m3u8"):
            try:
                p.unlink()
            except OSError:
                pass
    json.dump({"ok": True, "autoMixes": bool(on)}, sys.stdout)


def cmd_eq_get() -> None:
    cfg = _load_cfg()
    bands = cfg.get("eq_bands")
    if not isinstance(bands, list) or len(bands) != 10:
        bands = list(EQ_PRESETS.get(str(cfg.get("eq_preset") or "Flat"), EQ_PRESETS["Flat"]))
    on_player = _mpv_cmd(["get_property", "pause"])
    json.dump({
        "enabled": bool(cfg.get("eq_enabled", True)),
        "preset": str(cfg.get("eq_preset") or "Custom"),
        "bands": [float(x) for x in bands],
        "presets": list(EQ_PRESETS.keys()),
        "applied": on_player or "eq_bands" in cfg or "eq_preset" in cfg,
        "onPlayer": on_player,
    }, sys.stdout)


def _ee_band(i: int, gain: float, enabled: bool) -> dict:
    # Easy Effects 8.2 crashes on Lo-shelf/Hi-shelf and on a `right`
    # block when split-channels is false (coredump 2026-09-10). Match the
    # working NYXUS-Bass-Boost preset: Bell bands, left only, no limiter.
    return {
        "type": "Bell",
        "mode": "RLC (BT)",
        "slope": "x1",
        "solo": False,
        "mute": False,
        "gain": 0.0 if not enabled else float(gain),
        "frequency": EQ_FREQS[i],
        "q": 1.0,
    }


def _write_easyeffects(enabled: bool, bands: list[float]) -> None:
    left = {f"band{i}": _ee_band(i, bands[i], enabled) for i in range(10)}
    eq = {
        "input-gain": 0.0,
        "output-gain": 0.0,
        "mode": "IIR",
        "num-bands": 10,
        "split-channels": False,
        "balance": 0.0,
        "pitch-left": 0.0,
        "pitch-right": 0.0,
        "left": left,
        "bypass": not enabled,
    }
    preset = {
        "output": {
            "blocklist": [],
            "plugins_order": ["equalizer#0"],
            "equalizer#0": eq,
        }
    }
    blob = json.dumps(preset, indent=2)
    for d in EE_DIRS:
        d.mkdir(parents=True, exist_ok=True)
        (d / "nyxus-media-eq.json").write_text(blob)


def cmd_eq_set() -> None:
    raw = sys.argv[2] if len(sys.argv) > 2 else sys.stdin.read()
    try:
        req = json.loads(raw)
    except json.JSONDecodeError as e:
        json.dump({"ok": False, "applied": False, "error": str(e)}, sys.stdout)
        return
    enabled = bool(req.get("enabled", True))
    preset = str(req.get("preset") or "Custom")
    bands = [float(x) for x in (req.get("bands") or EQ_PRESETS["Flat"])]
    if len(bands) != 10:
        bands = list(EQ_PRESETS.get(preset, EQ_PRESETS["Flat"]))
    if preset in EQ_PRESETS and req.get("applyPreset"):
        bands = list(EQ_PRESETS[preset])
        if preset != "Flat":
            enabled = True
    applied = False
    err = ""
    lock_fh = None
    try:
        CACHE.mkdir(parents=True, exist_ok=True)
        lock_fh = open(EQ_LOCK, "a")
        fcntl.flock(lock_fh.fileno(), fcntl.LOCK_EX)
        cfg = _load_cfg()
        cfg["eq_enabled"] = enabled
        cfg["eq_preset"] = preset
        cfg["eq_bands"] = bands
        _save_cfg(cfg)
        try:
            _write_easyeffects(enabled, bands)
        except OSError:
            pass
        applied = _apply_eq(enabled, bands)
    except Exception as e:
        err = str(e)
        applied = False
    finally:
        if lock_fh is not None:
            try:
                fcntl.flock(lock_fh.fileno(), fcntl.LOCK_UN)
            except OSError:
                pass
            try:
                lock_fh.close()
            except OSError:
                pass
    json.dump({
        "ok": True,
        "enabled": enabled,
        "preset": preset,
        "bands": bands,
        "applied": applied,
        "applyPreset": bool(req.get("applyPreset")),
        "error": err,
        "presets": list(EQ_PRESETS.keys()),
    }, sys.stdout)


if __name__ == "__main__":
    op = sys.argv[1] if len(sys.argv) > 1 else "list"
    if op == "eq-get":
        cmd_eq_get()
    elif op == "eq-set":
        cmd_eq_set()
    elif op == "play":
        cmd_play()
    elif op == "stop":
        cmd_stop()
    elif op == "care":
        cmd_care()
    elif op == "auto":
        cmd_auto(sys.argv[2] != "off" if len(sys.argv) > 2 else True)
    else:
        cmd_list()
