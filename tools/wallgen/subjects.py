#!/usr/bin/env python3
"""Nyxus Suxyn — distinct celestial SUBJECTS for the layered walls.

The first cut of these walls was rejected by the owner, correctly:

    "all those are is the same image but in different corners i want each
     image to be something different not the same in 3 different postions
     that defeats the purpose of what im trying to do here"

He was right. Six walls were one sphere rendered from one material with a
palette swap and a translation, which is variation, not variety. Moving a
thing is not drawing a different thing.

So the material stays shared — that is the point of a house material, and
`Theme.qml` already remaps `paintLayers.glacier` wholesale to magma, so one
field in two palettes IS the build's own idiom — but the SILHOUETTE changes
per wall. Silhouette is what the eye sorts on at thumbnail size, which is
exactly the size the Background picker shows. Six shapes, not six positions:

    crescent   a world lit from behind: one bright rind, the rest occluded
    ringed     a small world inside a ring system that crosses in front
    surface    NO sphere at all — the ground, from low altitude
    fissure    a world split open, the core showing through the wound
    binary     two bodies of different size, one eclipsing nothing
    corona     a black disc with a burning rim and rays: the inverse shape

Every one of them is drawn from the same press output, so the family still
reads as one build.
"""
import numpy as np
from PIL import Image, ImageFilter

from spherepress import sphere, _sample


def rings(W, H, cx, cy, R, inner=1.35, outer=2.35, tilt=0.30, roll=-0.38,
          col=(1.0, 0.55, 0.22), gain=1.0, ss=2):
    """An elliptical ring system, returned RGBA, with the near arc in front.

    The ring is a flat annulus seen at `tilt` (0 = edge on, 1 = face on) and
    rotated by `roll`. The half of the annulus BELOW the planet centre in
    ring space is the near arc and draws over the body; the far half is
    handed back separately so the caller can put the planet between them.
    Returns (far_rgba, near_rgba).
    """
    Wp, Hp = W * ss, H * ss
    yy, xx = np.mgrid[0:Hp, 0:Wp].astype(np.float32)
    dx = (xx - cx * ss) / (R * ss)
    dy = (yy - cy * ss) / (R * ss)

    ca, sa = np.cos(roll), np.sin(roll)
    rx = dx * ca + dy * sa
    ry = -dx * sa + dy * ca
    ry = ry / max(tilt, 1e-3)          # un-squash the projection
    rr = np.sqrt(rx * rx + ry * ry)

    band = np.clip((rr - inner) / 0.05, 0, 1) * np.clip((outer - rr) / 0.05, 0, 1)

    # Cassini-ish structure: a few dark gaps so it is not a painted hoop
    t = np.clip((rr - inner) / max(outer - inner, 1e-4), 0, 1)
    grain = (0.55 + 0.45 * np.sin(t * 47.0) * np.sin(t * 13.0 + 1.7))
    gap = np.clip(1.0 - 1.25 * np.exp(-((t - 0.34) ** 2) / 0.0016), 0, 1)
    gap *= np.clip(1.0 - 1.10 * np.exp(-((t - 0.72) ** 2) / 0.0009), 0, 1)
    dens = band * grain * gap * gain

    # thinner and dimmer where it runs behind the far limb
    a = np.clip(dens, 0, 1)
    rgb = np.array(col, np.float32)[None, None, :] * (0.45 + 0.55 * t)[..., None]

    out = np.concatenate([rgb * a[..., None], a[..., None]], axis=2)
    near_mask = (ry > 0).astype(np.float32)

    def _down(x):
        im = Image.fromarray((np.clip(x, 0, 1) * 255).astype(np.uint8), "RGBA")
        return np.asarray(im.resize((W, H), Image.LANCZOS)).astype(np.float32) / 255.

    far = out * (1 - near_mask)[..., None]
    near = out * near_mask[..., None]
    return _down(far), _down(near)


def corona(W, H, cx, cy, R, col=(0.72, 0.52, 1.0), rays=13, gain=1.0,
           reach=2.1, ss=2):
    """A star burning behind a dark disc: rim + rays, zero inside the disc."""
    Wp, Hp = W * ss, H * ss
    yy, xx = np.mgrid[0:Hp, 0:Wp].astype(np.float32)
    dx = (xx - cx * ss) / (R * ss)
    dy = (yy - cy * ss) / (R * ss)
    r = np.sqrt(dx * dx + dy * dy)
    th = np.arctan2(dy, dx)

    # The rim. NOT a one-texel annulus: a hard even ring reads as a sticker
    # traced round the disc, which is the first thing the eye rejects. This
    # is a wider falloff, brightest at the limb, and it is MODULATED BY
    # ANGLE so the corona is hotter on one side the way a real one is.
    lean = 0.62 + 0.38 * np.cos(th - 0.7)
    rim = np.exp(-np.clip(r - 1.0, 0, None) / 0.055) * 1.05 * lean
    rim *= (r > 0.998)

    # THE STREAMERS — and why the last two attempts were cogs.
    #
    # Attempt 1 raised one sine to a power: identical petals, evenly
    # spaced, a flower. Attempt 2 summed three harmonics but cut the glow
    # off at a radius that varied with angle — a HARD boundary, scalloped,
    # which is a gear tooth by definition, and blurring it only rounded
    # the teeth. Both failures were the same mistake in different clothes:
    # the corona had an EDGE. A corona does not have an edge.
    #
    # So there is no radius cut here at all. The falloff is an exponential
    # whose LENGTH SCALE varies with angle, which means every streamer
    # fades out on its own and none of them end anywhere.
    #
    # The harmonics are INTEGER multiples on purpose. `th` wraps at ±pi, so
    # a non-integer multiple is discontinuous across that seam — attempt 2
    # used rays*0.41 and rays*2.17 and had a hairline join running due
    # left. Integers with coprime-ish spacing and unrelated phases give a
    # pattern that does not visibly repeat without ever breaking.
    ang = (0.50 * np.sin(th * 3.0 + 1.13)
           + 0.38 * np.sin(th * 5.0 - 0.41)
           + 0.30 * np.sin(th * 7.0 + 2.27)
           + 0.22 * np.sin(th * 11.0 + 0.62)
           + 0.15 * np.sin(th * 17.0 - 1.90))
    spokes = np.clip(0.5 + 0.5 * (ang / 1.55), 0, 1)

    length = 0.055 + 0.62 * (spokes ** 1.7)
    glow = np.exp(-np.clip(r - 1.0, 0, None) / length) * (0.07 + 0.58 * spokes)
    glow = glow * (r > 1.0) * np.clip((reach - r) / 0.55, 0, 1)

    a = np.clip((rim + glow) * gain, 0, 1)

    # SOFTEN. Even with three harmonics the streamers came out as triangles
    # with clean edges — the angular function is smooth but its RADIAL cut
    # is not, so each streamer ended on a straight line and the disc wore a
    # crown of teeth. A corona has no edges at all. Blurring the field (and
    # not the colour) turns the teeth into wisps while leaving the rim,
    # which is much brighter and much tighter, essentially where it was.
    ab = Image.fromarray((np.clip(a, 0, 1) * 255).astype(np.uint8))
    ab = ab.filter(ImageFilter.GaussianBlur(max(1.0, R * ss * 0.012)))
    a = np.asarray(ab).astype(np.float32) / 255.
    a = a * (r > 0.998)                      # nothing inside the disc
    rgb = np.array(col, np.float32)[None, None, :]
    hot = np.clip(a * 1.6, 0, 1)[..., None]
    rgb = rgb * (1 - hot) + np.array([1.0, 0.97, 0.93], np.float32) * hot

    out = np.concatenate([rgb * a[..., None], a[..., None]], axis=2)
    im = Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), "RGBA")
    return np.asarray(im.resize((W, H), Image.LANCZOS)).astype(np.float32) / 255.


def surface(tex, emap, W, H, horizon=0.46, scale=2.6, emit=(1.0, 0.42, 0.10),
            emit_gain=1.0, haze=0.0):
    """The ground seen from low altitude — a plane, not a ball.

    This is the wall with no planet in it. The same equirect press is read as
    a GROUND PLANE in perspective, so the silhouette is a horizon line rather
    than a circle, which is the largest possible shape change available
    without a second material.

    `haze` stays 0.0 by default and is never raised by any recipe here: the
    owner ruled fog out by name ("starkight has that haz or fog i dont like
    that or want to use anything like that"), so the depth cue is the plane
    going dark with distance, not air being painted.
    """
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    v = (yy / H - horizon) / (1.0 - horizon)      # 0 at horizon, 1 at bottom
    sky = v <= 0.0
    vv = np.clip(v, 1e-4, None)

    depth = 1.0 / vv                               # perspective foreshortening
    u = (xx / W - 0.5) * depth * 0.5
    w = depth / scale

    # TILE, DO NOT CLAMP. `w` runs to infinity at the horizon, so a
    # `clip(w, 0, 1)` made every row near the horizon sample the SAME
    # texture row — a long horizontal smear across the top of the plane,
    # which is what the first cut of this wall had. Wrapping instead means
    # the plane keeps resolving detail all the way back; it is the light
    # running out that ends it, not the lookup.
    th, ph = np.asarray(tex), np.asarray(emap)
    tv = (w * 0.12) % 1.0
    tu = (u * 0.5) % 1.0
    rgb = _sample(th, tu, tv)
    em = _sample(ph[..., None], tu, tv)[..., 0]

    # distance falloff: the plane loses light as it recedes. The extra
    # `hard` term takes the last stretch to true black BEFORE the horizon
    # line, so the plane ends in darkness rather than in an aliased mess
    # of half-resolved texels one pixel tall.
    hard = np.clip(v / 0.10, 0, 1)
    rgb = rgb * hard[..., None]
    em = em * hard
    near = np.clip(v / 0.55, 0, 1)[..., None]
    lit = rgb * (0.16 + 0.84 * near)
    glow = np.array(emit, np.float32)[None, None, :] * (em * emit_gain)[..., None]
    glow = glow * (0.30 + 0.70 * near)

    out = np.clip(lit + glow, 0, 1)
    a = np.ones((H, W), np.float32)
    out[sky] = 0.0
    a[sky] = 0.0

    # soften the horizon by one pixel so it is not an aliased ruler line
    am = Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.1))
    a = np.asarray(am).astype(np.float32) / 255.
    return np.concatenate([out, a[..., None]], axis=2)


def fissure(rgba, W, H, cx, cy, R, angle=-0.55, width=0.16, depth=0.80,
            col=(1.0, 0.62, 0.20), gain=1.0):
    """Split an already-rendered world open and light the wound from inside."""
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    dx = (xx - cx) / R
    dy = (yy - cy) / R
    r2 = dx * dx + dy * dy
    inside = r2 <= 1.0

    ca, sa = np.cos(angle), np.sin(angle)
    px = dx * ca + dy * sa
    py = -dx * sa + dy * ca

    # A WOUND, NOT A LENS. The first cut was `1 - |px|/w` with a smooth
    # taper, which is a perfect pointed ellipse — it read as a chrome slit
    # set into the surface. A crack is none of those things: its edges are
    # ragged, it wanders off its own axis, and it is not the same width
    # twice. So the axis gets a wander term and both lips get independent
    # high-frequency noise, all keyed to `py` so the two sides never match.
    wander = (0.055 * np.sin(py * 7.3 + 0.9)
              + 0.030 * np.sin(py * 17.1 - 2.1)
              + 0.016 * np.sin(py * 41.7 + 0.4))
    ragged = (0.24 * np.sin(py * 23.0 + 1.7)
              + 0.17 * np.sin(py * 57.0 - 0.6)
              + 0.11 * np.sin(py * 113.0 + 2.9))
    taper = np.clip(1.0 - (py / 0.95) ** 2, 0, 1) ** 0.75
    w = width * taper * (1.0 + ragged) + 1e-4
    wound = np.clip(1.0 - np.abs(px - wander) / np.maximum(w, 1e-4), 0, 1)
    # branch a couple of hairline splits off the main run
    for ph, sc in ((3.1, 0.34), (-1.4, 0.26)):
        bx = px - wander - sc * np.sin(py * 2.1 + ph) * taper
        wound = np.maximum(wound, np.clip(
            1.0 - np.abs(bx) / np.maximum(w * 0.30, 1e-4), 0, 1) * 0.55 * taper)
    wound = wound ** 0.85 * inside * taper

    core = np.clip(wound * depth, 0, 1)
    out = rgba.copy()
    lip = np.clip(wound * 2.2, 0, 1)
    out[..., :3] = out[..., :3] * (1 - lip[..., None] * 0.9)
    glow = np.array(col, np.float32)[None, None, :]
    white = np.clip(core * 1.5, 0, 1)[..., None]
    glow = glow * (1 - white) + np.array([1.0, 0.95, 0.88], np.float32) * white
    out[..., :3] = np.clip(out[..., :3] + glow * (core * gain)[..., None], 0, 1)
    out[..., 3] = np.clip(out[..., 3] + core, 0, 1)
    return out


def over(a, b):
    """Standard source-over: `b` on top of `a`, both premultiplied RGBA."""
    ab, bb = a[..., 3:4], b[..., 3:4]
    rgb = b[..., :3] + a[..., :3] * (1 - bb)
    al = bb + ab * (1 - bb)
    return np.concatenate([np.clip(rgb, 0, 1), np.clip(al, 0, 1)], axis=2)
