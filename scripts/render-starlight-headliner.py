#!/usr/bin/env python3
"""Nyxus Suxyn — render headliner.frag to a still PNG.

`quickshell/shaders/headliner.frag` has claimed this file exists since it
was written:

    "Everything below is ordinary GLSL and is copied BYTE FOR BYTE by
     scripts/render-starlight-headliner.py … That is why the still, the
     measurements, the live canvas in the brief and the desktop are all
     the same shader: only one of them is written by hand."

It did not exist. The claim was true in intent and false in fact, which is
worse than no claim at all — anybody auditing this build would have gone
looking for the thing that guarantees the still matches the desktop and
found nothing there. This is that file, and it keeps the guarantee by a
stronger route than the one the comment describes: rather than copying the
GLSL body into a second header (two texts that can drift), it renders the
SHIPPED `headliner.frag.qsb` — the exact artefact the running shell loads.
Same bytes, same GPU, same result, nothing to keep in sync.

WHY IT NEEDS A COMPOSITOR
`QT_QPA_PLATFORM=offscreen` has no RHI pipeline on this class of host and
every ShaderEffect renders pure black (measured, not assumed). So this runs
qml6 nested inside `cage`. cage sizes its window to its own output, which is
never the wallpaper size, so the press pins its canvas Item to the requested
pixel size and sets `layer.enabled` to force a full-size FBO.

Usage:
    scripts/render-starlight-headliner.py OUT.png [--size WxH]
        [--density F] [--twinkle F] [--master F] [--gauge F] [--time F]

Star plates for the layered wallpapers are cut from one oversized render so
that no two walls share a field; see bin/nyxus-gen-wall.
"""
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "tools", "wallgen"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("--size", default="1920x1200")
    ap.add_argument("--density", type=float, default=1.7)
    ap.add_argument("--twinkle", type=float, default=0.55)
    ap.add_argument("--master", type=float, default=1.15)
    ap.add_argument("--gauge", type=float, default=1.0)
    ap.add_argument("--time", type=float, default=7.0)
    a = ap.parse_args()

    w, _, h = a.size.partition("x")
    from drive import press

    spec = [{
        # the SHIPPED artefact, not a second copy of the source
        "shader": "headliner.frag.qsb",
        "out": os.path.abspath(a.out),
        "w": int(w), "h": int(h),
        "res4": True, "gauge": a.gauge, "uTime": a.time,
        "uLook": [a.twinkle, a.density, a.master, 0.0],
    }]
    made = press(spec)
    if not made:
        print("render failed — no output written", file=sys.stderr)
        return 1
    print(a.out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
