#!/usr/bin/env python3
"""Build the six layered walls — one distinct SUBJECT each.

See subjects.py for why the silhouette changes per wall rather than the
position. Star plates come from headliner.frag (the owner's own no-bloom,
no-spike, sparse commission) cropped into six non-overlapping windows, so
no two backgrounds are the same field and none of them contain fog.
"""
import argparse
import os

import numpy as np
from PIL import Image

from drive import press

HERE = os.path.dirname(os.path.abspath(__file__))

# The material presses. `uFlags[0] = 1` is magma.frag's NO-GRAVITY switch
# (TRK-4163): drips fall along +y in screen space, and wrapped onto a
# sphere they became streaks glued across the curve pointing at a floor
# that is not there. Every live caller passes zero, so this only affects
# what is rendered here.
MATERIALS = [("mat_w1", 63.0, 6.0), ("mat_w2", 118.0, 5.2),
             ("mat_w3", 177.0, 7.1), ("mat_p1", 231.0, 5.6),
             ("mat_p2", 288.0, 6.6), ("mat_p3", 344.0, 4.8)]

# One oversized starfield, cut into six non-overlapping windows. Crops, not
# flips: mirroring a sky produces visible Rorschach symmetry, which is what
# the rejected first cut of these walls did.
STAR_W, STAR_H = 5760, 2400
CROPS = {"forge": (0, 0), "ember": (1920, 0), "crucible": (3840, 0),
         "geode": (0, 1200), "cryo": (1920, 1200), "halo": (3840, 1200)}


def ensure_sources():
    """Render the material and star plates if they are not already here."""
    want = [m for m, _, _ in MATERIALS
            if not os.path.exists(os.path.join(HERE, m + ".png"))]
    if want:
        spec = [{"out": os.path.join(HERE, m + ".png"),
                 "shader": "magma.frag.qsb", "w": 2048, "h": 1024,
                 "uTime": t, "uLook": [0.55, 0.3, 0.88, 1.0],
                 "uScene": [sc, 0.7, 1.5, 0.9], "uFlags": [1, 0, 0, 0]}
                for m, t, sc in MATERIALS if m in want]
        print(f"  pressing {len(spec)} material plates from magma.frag")
        press(spec)

    big = os.path.join(HERE, "starbig.png")
    if not all(os.path.exists(os.path.join(HERE, f"stars-{k}.png"))
               for k in CROPS):
        if not os.path.exists(big):
            print("  pressing the starfield from headliner.frag")
            press([{"out": big, "shader": "headliner.frag.qsb",
                    "w": STAR_W, "h": STAR_H, "res4": True, "gauge": 1.0,
                    "uTime": 7.0, "uLook": [0.55, 1.7, 1.15, 0.0]}])
        im = Image.open(big).convert("RGB")
        for k, (x, y) in CROPS.items():
            im.crop((x, y, x + 1920, y + 1200)).save(
                os.path.join(HERE, f"stars-{k}.png"))
        print(f"  cut {len(CROPS)} unique star plates")

from spherepress import sphere, save_rgb, save_rgba
from plates import plates
import subjects as S

W, H = 1920, 1200
OUT = os.path.join(HERE, "out")

CORAL = np.array([1.00, 0.42, 0.12], np.float32)
GOLD = np.array([1.00, 0.72, 0.22], np.float32)
VIOLET = np.array([0.62, 0.30, 1.00], np.float32)
ICEB = np.array([0.55, 0.82, 1.00], np.float32)

MAG = dict(rock=(0.030, 0.024, 0.034), rock_hi=(0.115, 0.086, 0.092),
           cool=CORAL, warm=GOLD)
PLM = dict(rock=(0.026, 0.022, 0.040), rock_hi=(0.088, 0.080, 0.125),
           cool=VIOLET, warm=ICEB)


def build():
    global OUT
    os.makedirs(OUT, exist_ok=True)
    ensure_sources()

    # ── the six materials, two palettes ──────────────────────────────────
    mw1, ew1 = plates(os.path.join(HERE, "mat_w1.png"), **MAG)
    mw2, ew2 = plates(os.path.join(HERE, "mat_w2.png"), **MAG)
    mw3, ew3 = plates(os.path.join(HERE, "mat_w3.png"), erode=7, seam_gain=1.15, **MAG)
    mp1, ep1 = plates(os.path.join(HERE, "mat_p1.png"), **PLM)
    mp2, ep2 = plates(os.path.join(HERE, "mat_p2.png"), **PLM)
    mp3, ep3 = plates(os.path.join(HERE, "mat_p3.png"), erode=7, seam_gain=1.15, **PLM)

    walls = {}

    # 1 ── FORGE: a crescent. Light almost straight behind the body, so all
    #      that survives is one burning rind and a vast dark disc. Big, low,
    #      running off the left edge — the body is a WALL, not an ornament.
    walls["suxyn-magma-forge"] = S.over(
        np.zeros((H, W, 4), np.float32),
        sphere(mw1, W, H, cx=430, cy=760, R=690,
               light=(-0.88, -0.30, -0.36), spin=0.15, tilt=0.06,
               emit_gain=1.35, ambient=0.028,
               rim_col=(1.0, 0.46, 0.14), rim_gain=1.9, air=0.10, emap=ew1))

    # 2 ── EMBER: a ringed world. Small body, huge ring system crossing in
    #      front of it — the silhouette is the ellipse, not the circle.
    far, near = S.rings(W, H, cx=1290, cy=520, R=250, inner=1.45, outer=2.55,
                        tilt=0.26, roll=-0.42, col=(1.0, 0.58, 0.24), gain=0.95)
    body = sphere(mw2, W, H, cx=1290, cy=520, R=250,
                  light=(-0.60, -0.45, 0.66), spin=2.1, tilt=-0.18,
                  emit_gain=1.15, ambient=0.05,
                  rim_col=(1.0, 0.50, 0.16), rim_gain=1.2, air=0.12, emap=ew2)
    walls["suxyn-magma-ember"] = S.over(S.over(far, body), near)

    # 3 ── CRUCIBLE: no sphere anywhere. The ground from low altitude, the
    #      horizon as the silhouette. This is the wall that proves the set
    #      is six subjects and not six placements.
    walls["suxyn-magma-crucible"] = S.surface(
        mw3, ew3, W, H, horizon=0.44, scale=2.4,
        emit=(1.0, 0.44, 0.10), emit_gain=1.45)

    # 4 ── GEODE: a world split open, lit from the inside. Violet crust,
    #      ice-white core — the only wall whose light source is interior.
    g = sphere(mp1, W, H, cx=1180, cy=600, R=430,
               light=(-0.52, -0.40, 0.75), spin=0.9, tilt=0.12,
               emit_gain=0.95, ambient=0.05,
               rim_col=(0.66, 0.38, 1.0), rim_gain=1.25, air=0.13, emap=ep1)
    walls["suxyn-plum-geode"] = S.fissure(
        g, W, H, cx=1180, cy=600, R=430, angle=-0.42, width=0.15,
        depth=0.92, col=(0.74, 0.52, 1.0), gain=1.25)

    # 5 ── CRYO: two bodies. A large icy world low-right and a small hard
    #      companion high-left — the only wall with more than one object,
    #      which is its own silhouette even at thumbnail size.
    big = sphere(mp2, W, H, cx=1420, cy=880, R=520,
                 light=(-0.70, -0.38, 0.60), spin=1.5, tilt=-0.10,
                 emit_gain=0.80, ambient=0.06,
                 rim_col=(0.58, 0.80, 1.0), rim_gain=1.15, air=0.12, emap=ep2)
    moon = sphere(mp2, W, H, cx=470, cy=330, R=118,
                  light=(-0.70, -0.38, 0.60), spin=4.4, tilt=0.5,
                  emit_gain=0.55, ambient=0.045,
                  rim_col=(0.58, 0.80, 1.0), rim_gain=0.9, air=0.08, emap=ep2)
    walls["suxyn-plum-cryo"] = S.over(big, moon)

    # 6 ── HALO: an eclipse. A black disc with a burning rim and rays — the
    #      inverse of every other wall here, which is lit crust on a dark
    #      ground. Here the ground is the light and the body is the hole.
    disc = sphere(mp3, W, H, cx=960, cy=560, R=360,
                  light=(-0.20, -0.10, -0.92), spin=3.0, tilt=0.0,
                  emit_gain=0.30, ambient=0.012,
                  rim_col=(0.70, 0.50, 1.0), rim_gain=0.55, air=0.06, emap=ep3)
    cor = S.corona(W, H, cx=960, cy=560, R=360, col=(0.66, 0.46, 1.0),
                   rays=15, gain=1.0, reach=2.4)
    walls["suxyn-plum-halo"] = S.over(cor, disc)

    # ── write the pairs ──────────────────────────────────────────────────
    for slug, fg in walls.items():
        key = slug.rsplit("-", 1)[-1]
        bg = np.asarray(Image.open(os.path.join(HERE, f"stars-{key}.png")).convert("RGB")
                        ).astype(np.float32) / 255.
        save_rgba(fg, f"{OUT}/{slug}-fg.png")
        save_rgb(bg, f"{OUT}/{slug}-bg.png")
        a = fg[..., 3:4]
        flat = np.clip(fg[..., :3] + bg * (1 - a), 0, 1)
        save_rgb(flat, f"{OUT}/{slug}.png")
        cov = float((fg[..., 3] > 0.02).mean())
        print(f"{slug:24s} fg-cover={cov*100:5.1f}%  written")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=OUT)
    a = ap.parse_args()
    OUT = a.out
    build()
