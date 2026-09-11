#!/usr/bin/env python3
"""Store catalog + install for Store.qml. Same catalog as GTK nyxus_store.py.

AUR / Flatpak are real backends, gated by --aur/--no-aur and
--flatpak/--no-flatpak (default both on). Missing helpers are skipped,
never faked.
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

CATALOG = Path.home() / ".config/nyxus/store-catalog.json"
RECO = Path("/usr/share/nyxus/store-recommended.json")
OPT = Path("/opt/nyxus")
if str(OPT) not in sys.path:
    sys.path.insert(0, str(OPT))

# Theme-icon aliases when AppStream is keyed on a different package name.
THEME_ALIAS = {
    "spotify-launcher": "spotify",
    "obs-studio": "obs",
    "telegram-desktop": "telegram",
    "signal-desktop": "signal-desktop",
    "libreoffice-fresh": "libreoffice",
    "code": "code",
}

_AS = None
AUR_HELPER = shutil.which("paru") or shutil.which("yay")
HAS_FLATPAK = bool(shutil.which("flatpak"))


def _appstream():
    """Shared AppStream catalogue. None if the data package is missing."""
    global _AS
    if _AS is False:
        return None
    if _AS is not None:
        return _AS
    try:
        import nyxus_appstream as appstream
        if not appstream.Catalog.available():
            _AS = False
            return None
        _AS = appstream
        return _AS
    except Exception:
        _AS = False
        return None


def _theme_icon(pkg: str) -> str:
    names = [pkg]
    stem = pkg.split("-")[0]
    if stem and stem not in names:
        names.append(stem)
    alias = THEME_ALIAS.get(pkg)
    if alias and alias not in names:
        names.append(alias)
    for n in names:
        for size in ("128x128", "64x64", "48x48"):
            p = Path(f"/usr/share/icons/hicolor/{size}/apps/{n}.png")
            if p.is_file():
                return str(p)
        for size in ("64x64", "48x48", "128x128"):
            p = Path(f"/usr/share/icons/Papirus/{size}/apps/{n}.svg")
            if p.is_file():
                return str(p)
        p = Path(f"/usr/share/pixmaps/{n}.png")
        if p.is_file():
            return str(p)
    return ""


def _art_for(pkg: str) -> tuple[str, str, str]:
    """(icon_path, shot_path, kind) — local files only. No network."""
    icon = ""
    shot = ""
    mod = _appstream()
    info = None
    if mod is not None:
        try:
            cat = mod.catalog()
            info = cat.get(pkg)
            if info is None:
                stem = pkg.split("-")[0]
                if stem != pkg:
                    info = cat.get(stem)
        except Exception:
            info = None
    if info is not None:
        try:
            ip = info.icon_path()
            if ip is not None:
                icon = str(ip)
        except Exception:
            pass
        urls = list(getattr(info, "screenshots", None) or [])
        if urls:
            try:
                cached = mod.cached_screenshot(urls[0])
                if cached is not None:
                    shot = str(cached)
            except Exception:
                pass
    if not icon:
        icon = _theme_icon(pkg)
    kind = "shot" if shot else ("icon" if icon else "")
    return icon, shot, kind


def _appstream_repo(pkg: str) -> str:
    mod = _appstream()
    if mod is None:
        return ""
    try:
        info = mod.catalog().get(pkg)
        if info is None:
            return ""
        return str(getattr(info, "repo", "") or "")
    except Exception:
        return ""


def _decorate(app: dict, inst: dict[str, str], fp_inst: dict[str, str] | None = None) -> dict:
    art_pkg = app.get("id") or (app.get("pkgs") or [""])[0] or ""
    icon, shot, kind = _art_for(art_pkg)
    app["icon"] = icon
    app["shot"] = shot
    app["art"] = shot or icon
    app["artKind"] = kind
    src = (app.get("source") or "pacman").lower()
    repo = str(app.get("repo") or "")
    if not repo:
        if src == "aur":
            repo = "AUR"
        elif src == "flatpak":
            repo = "flatpak"
        else:
            repo = _appstream_repo(art_pkg) or "pacman"
    app["repo"] = repo
    ver = str(app.get("version") or "")
    if not ver:
        if src == "flatpak" and fp_inst is not None:
            pkg0 = (app.get("pkgs") or [""])[0] or ""
            ver = fp_inst.get(pkg0, "") or fp_inst.get(art_pkg, "")
        else:
            ver = inst.get(art_pkg, "")
            if not ver:
                for p in app.get("pkgs") or []:
                    if p in inst:
                        ver = inst[p]
                        break
    app["version"] = ver
    return app


def _installed() -> dict[str, str]:
    try:
        r = subprocess.run(["pacman", "-Q"], capture_output=True, text=True, timeout=8)
        out: dict[str, str] = {}
        for line in r.stdout.splitlines():
            parts = line.split()
            if parts:
                out[parts[0]] = parts[1] if len(parts) > 1 else ""
        return out
    except Exception:
        return {}


def _flatpak_installed() -> dict[str, str]:
    if not HAS_FLATPAK:
        return {}
    try:
        r = subprocess.run(
            ["flatpak", "list", "--app", "--columns=application,version"],
            capture_output=True, text=True, timeout=10,
        )
        out: dict[str, str] = {}
        for line in (r.stdout or "").splitlines():
            parts = line.split(maxsplit=1)
            if parts:
                out[parts[0]] = parts[1] if len(parts) > 1 else ""
        return out
    except Exception:
        return {}


def _keep_source(source: str, include_aur: bool, include_flatpak: bool) -> bool:
    s = (source or "pacman").lower()
    if s == "aur" and not include_aur:
        return False
    if s in ("flatpak", "flathub") and not include_flatpak:
        return False
    return True


def _load_catalog() -> dict:
    try:
        return json.loads(CATALOG.read_text())
    except (OSError, json.JSONDecodeError):
        return {"featured": [], "categories": []}


def _apps_from_catalog(
    cat: dict,
    inst: dict[str, str],
    fp_inst: dict[str, str],
    include_aur: bool,
    include_flatpak: bool,
) -> tuple[list, list]:
    cats = []
    for c in cat.get("categories") or []:
        apps = []
        for a in c.get("apps") or []:
            src = a.get("source") or "pacman"
            if not _keep_source(src, include_aur, include_flatpak):
                continue
            pkgs = list(a.get("pkgs") or [a.get("id")])
            if src == "flatpak":
                installed = all(p in fp_inst for p in pkgs) if pkgs else False
            else:
                installed = all(p in inst for p in pkgs) if pkgs else False
            apps.append(_decorate({
                "id": a.get("id"),
                "name": a.get("name"),
                "summary": a.get("summary") or "",
                "pkgs": pkgs,
                "source": src,
                "installed": installed,
            }, inst, fp_inst))
        if apps:
            cats.append({"id": c.get("id"), "name": c.get("name"), "apps": apps})
    featured_ids = list(cat.get("featured") or [])
    featured = []
    for fid in featured_ids:
        for c in cats:
            for a in c["apps"]:
                if a["id"] == fid:
                    featured.append(a)
    return cats, featured


def _recommended(
    inst: dict[str, str],
    fp_inst: dict[str, str],
    include_flatpak: bool,
) -> list:
    try:
        doc = json.loads(RECO.read_text())
    except (OSError, json.JSONDecodeError):
        return []
    out = []
    use_fp = bool(include_flatpak and HAS_FLATPAK)
    for a in doc.get("apps") or []:
        pkg = a.get("pacman") or ""
        fid = a.get("flatpak") or ""
        if use_fp and fid:
            out.append(_decorate({
                "id": pkg or fid,
                "name": a.get("name") or pkg or fid,
                "summary": a.get("why") or "",
                "pkgs": [fid],
                "source": "flatpak",
                "repo": "flatpak",
                "installed": fid in fp_inst,
                "version": fp_inst.get(fid, ""),
            }, inst, fp_inst))
            continue
        if not pkg:
            continue
        out.append(_decorate({
            "id": pkg,
            "name": a.get("name") or pkg,
            "summary": a.get("why") or "",
            "pkgs": [pkg],
            "source": "pacman",
            "installed": pkg in inst,
        }, inst, fp_inst))
    return out


def cmd_catalog(include_aur: bool, include_flatpak: bool) -> None:
    cat = _load_catalog()
    inst = _installed()
    fp_inst = _flatpak_installed() if include_flatpak else {}
    cats, featured = _apps_from_catalog(cat, inst, fp_inst, include_aur, include_flatpak)
    reco = _recommended(inst, fp_inst, include_flatpak)
    json.dump({
        "categories": cats,
        "featured": featured,
        "recommended": reco,
        "installedCount": sum(1 for c in cats for a in c["apps"] if a["installed"]),
        "includeAur": include_aur,
        "includeFlatpak": include_flatpak,
        "hasAurHelper": bool(AUR_HELPER),
        "hasFlatpak": HAS_FLATPAK,
    }, sys.stdout)


def _upd_row(name: str, frm: str, to: str, source: str, repo: str) -> dict:
    return {
        "id": name,
        "name": name,
        "from": frm,
        "to": to,
        "version": to or frm,
        "pkgs": [name],
        "source": source,
        "repo": repo,
    }


def cmd_updates(include_aur: bool, include_flatpak: bool) -> None:
    rows = []
    cmd = ["checkupdates"] if shutil.which("checkupdates") else ["pacman", "-Qu"]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=25)
        for line in (r.stdout or "").splitlines():
            parts = line.split()
            if len(parts) >= 4 and "->" in parts:
                rows.append(_upd_row(parts[0], parts[1], parts[3], "pacman", "pacman"))
            elif len(parts) >= 1:
                rows.append(_upd_row(parts[0], "", "", "pacman", "pacman"))
    except Exception:
        pass
    if include_aur and AUR_HELPER:
        try:
            r = subprocess.run([AUR_HELPER, "-Qua"], capture_output=True, text=True, timeout=30)
            for line in (r.stdout or "").splitlines():
                parts = line.split()
                if len(parts) >= 4 and "->" in parts:
                    rows.append(_upd_row(parts[0], parts[1], parts[3], "aur", "AUR"))
                elif len(parts) >= 1:
                    rows.append(_upd_row(parts[0], "", "", "aur", "AUR"))
        except Exception:
            pass
    if include_flatpak and HAS_FLATPAK:
        try:
            r = subprocess.run(
                ["flatpak", "remote-ls", "--updates", "--columns=application,version"],
                capture_output=True, text=True, timeout=30,
            )
            for line in (r.stdout or "").splitlines():
                parts = line.split(maxsplit=1)
                if not parts:
                    continue
                ver = parts[1] if len(parts) > 1 else ""
                rows.append(_upd_row(parts[0], "", ver, "flatpak", "flatpak"))
        except Exception:
            pass
    json.dump({"updates": rows}, sys.stdout)


def _bad_pkg(p: str) -> bool:
    return (not p) or p.startswith("-") or "/" in p or "\\" in p or "\n" in p


def cmd_install(source: str, pkgs: list[str]) -> None:
    pkgs = [p for p in pkgs if not _bad_pkg(p)]
    if not pkgs:
        json.dump({"ok": False, "error": "bad package"}, sys.stdout)
        return
    src = (source or "pacman").lower()
    if src == "aur":
        helper = AUR_HELPER
        if not helper:
            json.dump({"ok": False, "error": "No AUR helper (yay or paru)."}, sys.stdout)
            return
        r = subprocess.run(
            [helper, "-S", "--needed", "--noconfirm", *pkgs],
            capture_output=True, text=True, timeout=600,
        )
    elif src == "flatpak":
        if not HAS_FLATPAK:
            json.dump({"ok": False, "error": "Flatpak is not installed."}, sys.stdout)
            return
        r = subprocess.run(
            ["flatpak", "install", "-y", "flathub", *pkgs],
            capture_output=True, text=True, timeout=600,
        )
    else:
        r = subprocess.run(
            ["pkexec", "pacman", "-S", "--needed", "--noconfirm", *pkgs],
            capture_output=True, text=True, timeout=600,
        )
    json.dump({
        "ok": r.returncode == 0,
        "pkg": " ".join(pkgs),
        "error": (r.stderr or r.stdout or "")[-400:],
    }, sys.stdout)


def cmd_upgrade(include_aur: bool, include_flatpak: bool) -> None:
    r = subprocess.run(
        ["pkexec", "pacman", "-Syu", "--noconfirm"],
        capture_output=True, text=True, timeout=900,
    )
    ok = r.returncode == 0
    err = (r.stderr or r.stdout or "")[-400:]
    if ok and include_aur and AUR_HELPER:
        r2 = subprocess.run(
            [AUR_HELPER, "-Syu", "--noconfirm"],
            capture_output=True, text=True, timeout=900,
        )
        ok = r2.returncode == 0
        if not ok:
            err = (r2.stderr or r2.stdout or "")[-400:]
    if ok and include_flatpak and HAS_FLATPAK:
        r3 = subprocess.run(
            ["flatpak", "update", "-y"],
            capture_output=True, text=True, timeout=900,
        )
        ok = r3.returncode == 0
        if not ok:
            err = (r3.stderr or r3.stdout or "")[-400:]
    json.dump({"ok": ok, "error": err}, sys.stdout)


def _flags(argv: list[str]) -> tuple[bool, bool, list[str]]:
    include_aur = True
    include_flatpak = True
    rest: list[str] = []
    for a in argv:
        if a in ("--aur", "--include-aur"):
            include_aur = True
        elif a == "--no-aur":
            include_aur = False
        elif a in ("--flatpak", "--include-flatpak"):
            include_flatpak = True
        elif a == "--no-flatpak":
            include_flatpak = False
        else:
            rest.append(a)
    return include_aur, include_flatpak, rest


if __name__ == "__main__":
    include_aur, include_flatpak, argv = _flags(sys.argv[1:])
    op = argv[0] if argv else "catalog"
    if op == "install":
        if len(argv) > 2:
            cmd_install(argv[1], argv[2:])
        elif len(argv) > 1:
            cmd_install("pacman", argv[1:])
        else:
            json.dump({"ok": False, "error": "bad package"}, sys.stdout)
    elif op == "updates":
        cmd_updates(include_aur, include_flatpak)
    elif op == "upgrade":
        cmd_upgrade(include_aur, include_flatpak)
    else:
        cmd_catalog(include_aur, include_flatpak)
