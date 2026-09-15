#!/usr/bin/env python3
# ════════════════════════════════════════════════════════════════════
# Nyxus Suxyn — plate/seam grader.
#
# magma.frag opens its melt as a PLATEAU, not a peak: measured on a
# 2048x1024 press, 29% of the surface sits at luminance ~0.68 and only
# 4% goes above 0.75. That is the right call for a 36 px bar strip,
# where a few WIDE rivers are the only thing that survives — it is the
# wrong call for a planet, where a 29% emissive area stops reading as
# lava and starts reading as pale sand.
#
# So the wall material keeps the shader's FIELD and throws away its
# fill: the melt regions become dark plates and only their boundaries
# glow. That is also what the shipped magma wall depicts — dark rock
# broken into plates with incandescent seams between them, not molten
# continents.
# ════════════════════════════════════════════════════════════════════
import numpy as np
from PIL import Image, ImageFilter

CORAL = np.array([1.00, 0.20, 0.045], dtype=np.float32)
GOLD = np.array([1.00, 0.63, 0.16], dtype=np.float32)
WHITE = np.array([1.00, 0.95, 0.86], dtype=np.float32)


def _blur(a, r):
    return np.asarray(Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
                      .filter(ImageFilter.GaussianBlur(r))).astype(np.float32) / 255.


def plates(path, erode=5, seam_soft=1.6, rock=(0.030, 0.024, 0.034),
           rock_hi=(0.115, 0.086, 0.092), hot_lo=0.78, hot_hi=0.93,
           cool=CORAL, warm=GOLD, seam_gain=1.0):
    """Return (rgb_texture, emission_mask) from a magma.frag press."""
    a = np.asarray(Image.open(path).convert("RGB")).astype(np.float32) / 255.
    lum = a.mean(axis=2)

    # the melt plateau, as a region
    m = Image.fromarray(((lum > 0.5) * 255).astype(np.uint8))
    er = np.asarray(m.filter(ImageFilter.MinFilter(erode))).astype(np.float32) / 255.
    seam = np.clip(np.asarray(m).astype(np.float32) / 255. - er, 0, 1)
    seam = _blur(seam, seam_soft)
    seam = np.clip(seam * 1.55, 0, 1)

    # crust roughness: the shader's own high-frequency detail, recovered
    # as the difference from its local average so the plates are not flat
    rough = lum - _blur(lum, 9)
    rough = np.clip((rough - rough.min()) / max(float(rough.max() - rough.min()), 1e-5), 0, 1)
    rough = rough[..., None]
    crust = np.array(rock, np.float32) * (1 - rough) + np.array(rock_hi, np.float32) * rough

    # seam temperature: coral at the lip, gold in the channel, white only
    # in the hottest cores the shader actually produced
    t = np.clip((lum - 0.52) / 0.30, 0, 1)[..., None]
    hot = np.clip((lum - hot_lo) / max(hot_hi - hot_lo, 1e-4), 0, 1)[..., None]
    seam_col = cool * (1 - t) + warm * t
    seam_col = seam_col * (1 - hot) + WHITE * hot

    s = (seam * seam_gain)[..., None]
    rgb = crust * (1 - s) + seam_col * s
    return np.clip(rgb, 0, 1), np.clip(seam * seam_gain, 0, 1)
