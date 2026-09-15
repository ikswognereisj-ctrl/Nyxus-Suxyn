#!/usr/bin/env python3
"""Drive the Nyxus material press: inline a spec into press.tmpl.qml and run it under cage."""
import json
import subprocess
import sys
import os
from pathlib import Path

# Repo-relative, so the generator works from a clone rather than from the
# one machine it was written on.
W = Path(__file__).resolve().parent
SH = (W.parent.parent / "quickshell" / "shaders").as_uri() + "/"


def press(spec, timeout=600):
    # RESOLVE THE SHADER HERE, not in the caller. This prefix used to be
    # applied only in `__main__`, so every in-process caller passed a bare
    # "magma.frag.qsb", Qt resolved it relative to run.qml, found nothing,
    # and the ShaderEffect drew nothing. The grab still succeeded, the file
    # still appeared, and the old success test ("did the file appear?")
    # reported 6/6 rendered for six pure-black plates. One rule, every
    # caller.
    spec = [dict(p) for p in spec]
    for p in spec:
        if not str(p["shader"]).startswith("file://"):
            p["shader"] = SH + p["shader"]

    tmpl = (W / "press.tmpl.qml").read_text()
    qml = tmpl.replace("SPEC_JSON_HERE", json.dumps(spec))
    (W / "run.qml").write_text(qml)
    for p in spec:
        Path(p["out"]).unlink(missing_ok=True)
    env = dict(os.environ, XDG_RUNTIME_DIR=os.environ.get("XDG_RUNTIME_DIR",
                                      f"/run/user/{os.getuid()}"))
    r = subprocess.run(["cage", "-s", "--", "qml6", str(W / "run.qml")],
                       cwd=W, env=env, capture_output=True, text=True, timeout=timeout)
    # A FILE IS NOT A RENDER. `cage` swallows console output, so the only
    # signal available is the pixels — and a failed ShaderEffect produces a
    # perfectly valid, perfectly black PNG. Anything that comes back with no
    # light in it at all is a failure, and saying so here is what stops a
    # black plate being quietly composited into a wallpaper.
    made = []
    for p in spec:
        out = Path(p["out"])
        if not out.exists():
            continue
        try:
            from PIL import Image, ImageStat
            im = Image.open(out).convert("RGB")
            if max(ImageStat.Stat(im).mean) <= 1e-6:
                print(f"   BLACK (render failed): {out.name}")
                continue
        except Exception:
            pass
        made.append(p["out"])
    print(f"press: {len(made)}/{len(spec)} rendered (rc={r.returncode})")
    for p in spec:
        if p["out"] not in made:
            print("   MISSING:", p["out"])
    err = "\n".join(l for l in (r.stdout + r.stderr).splitlines()
                    if any(k in l for k in ("qml:", "Error", "error", "PRESS", "PRESSED")))
    if err:
        print(err[:2000])
    return made


if __name__ == "__main__":
    spec = json.load(open(sys.argv[1]))
    for p in spec:
        p["shader"] = SH + p["shader"]
    press(spec)
