#!/usr/bin/env python3
# ════════════════════════════════════════════════════════════════════
# Nyxus Suxyn — sphere press.
#
# Wraps a flat material render (magma.frag, gem_crystal.frag — the
# build's OWN shaders) onto a lit sphere and writes it as a layered
# wallpaper foreground: premultiplied-looking RGBA whose alpha is zero
# everywhere except the body and its air.
#
# This matches the convention the shipped walls already use, measured
# rather than assumed:
#     -bg  1920x1200 RGB  opaque          (the starfield)
#     -fg  1920x1200 RGBA 66-76% clear    (the subject)
# HeadlinerSky's live stars draw BETWEEN the two, which is why the
# foreground has to be honestly transparent and not a black plate.
#
# No smoke, no fog, no haze: the owner ruled those out explicitly.
# © 2026 Joseph A. Sierengowski
# ════════════════════════════════════════════════════════════════════
import numpy as np
from PIL import Image


def _sample(tex, u, v):
    """Bilinear equirectangular sample. u wraps, v clamps."""
    h, w, _ = tex.shape
    x = (u % 1.0) * (w - 1)
    y = np.clip(v, 0.0, 1.0) * (h - 1)
    x0 = np.floor(x).astype(int) % w
    y0 = np.clip(np.floor(y).astype(int), 0, h - 1)
    x1 = (x0 + 1) % w
    y1 = np.clip(y0 + 1, 0, h - 1)
    fx = (x - np.floor(x))[..., None]
    fy = (y - np.floor(y))[..., None]
    return (tex[y0, x0] * (1 - fx) * (1 - fy) + tex[y0, x1] * fx * (1 - fy)
            + tex[y1, x0] * (1 - fx) * fy + tex[y1, x1] * fx * fy)


def sphere(tex, W, H, cx, cy, R, light=(-0.55, -0.42, 0.72),
           spin=0.0, tilt=0.0, emit_lo=0.30, emit_hi=0.85,
           emit_gain=1.0, ambient=0.055, rim_col=(1.0, 0.42, 0.12),
           rim_gain=1.0, air=0.13, ss=2, emap=None):
    """Render a lit sphere of `tex` into an RGBA float image.

    `emap` is an optional single-channel emission mask in texture space.
    When given it replaces the luminance-threshold guess, which matters
    for a material whose melt is a flat plateau rather than a peak: the
    guess turns whole plates into emitters and the world reads as sand.
    """
    # Supersample, then box-down: the limb is a hard geometric edge and
    # a one-pixel stair on a 1920-wide wall is visible on an OLED panel.
    Wp, Hp, cxp, cyp, Rp = W * ss, H * ss, cx * ss, cy * ss, R * ss
    yy, xx = np.mgrid[0:Hp, 0:Wp].astype(np.float32)
    dx = (xx - cxp) / Rp
    dy = (yy - cyp) / Rp
    r2 = dx * dx + dy * dy

    inside = r2 <= 1.0
    nz = np.sqrt(np.clip(1.0 - r2, 0.0, 1.0))
    nx, ny = dx, dy

    # tilt the pole, then spin the globe under the camera
    ct, st = np.cos(tilt), np.sin(tilt)
    ry = ny * ct - nz * st
    rz = ny * st + nz * ct
    u = 0.5 + np.arctan2(nx, rz) / (2 * np.pi) + spin
    v = 0.5 - np.arcsin(np.clip(ry, -1, 1)) / np.pi
    texel = _sample(tex, u, v)

    L = np.array(light, dtype=np.float32)
    L /= np.linalg.norm(L)
    lam = np.clip(nx * L[0] + ny * L[1] + nz * L[2], 0.0, 1.0)[..., None]

    # Split the material into cold rock and emissive melt. Emission is
    # what makes a molten world read at night: the cracks must still
    # glow on the side the sun has left, exactly as they do on the
    # shipped magma wall.
    lum = texel.mean(axis=2, keepdims=True)
    if emap is not None:
        emit = _sample(np.repeat(emap[..., None], 3, axis=2), u, v)[..., :1] * emit_gain
    else:
        emit = np.clip((lum - emit_lo) / max(emit_hi - emit_lo, 1e-4), 0.0, 1.0)
        emit = emit * emit * emit_gain
    albedo = texel * (1.0 - 0.75 * np.clip(emit, 0.0, 1.0))

    body = albedo * (ambient + (1.0 - ambient) * lam) + texel * emit * (0.55 + 0.45 * lam)

    # limb darkening — a sphere is dimmer where you see it edge-on
    body *= (0.35 + 0.65 * nz[..., None] ** 0.42)

    # rim: the lit crescent of atmosphere, strongest where the light
    # grazes the edge. Not a uniform outline — that reads as a sticker.
    rim = np.clip(1.0 - nz, 0.0, 1.0)[..., None] ** 3.0 * lam ** 0.6
    body += np.array(rim_col, dtype=np.float32) * rim * rim_gain

    alpha = inside.astype(np.float32)[..., None]

    # the air: a thin falloff just outside the limb, lit on the sun side
    if air > 0:
        r = np.sqrt(r2)
        halo = np.clip((1.0 + air - r) / air, 0.0, 1.0) * (r > 1.0)
        halo = (halo ** 2.2)[..., None] * lam ** 0.8
        body = body + np.array(rim_col, dtype=np.float32) * halo * 0.85 * rim_gain
        alpha = np.clip(alpha + halo * 0.85, 0.0, 1.0)

    # PREMULTIPLY. Outside the disc `nz` is 0 and `ry` saturates, so the
    # equirect lookup lands on a pole row and `body` there is a constant
    # smear of texture — harmless while alpha is 0, and NOT harmless the
    # moment a premultiplied compositor reads the RGB anyway. That is
    # exactly what happened: the first build of these walls had bright
    # horizontal bands radiating off every body, which were the pole rows
    # of the material leaking through alpha 0. Everything else in this
    # pipeline (rings, corona, surface, graffiti) is premultiplied, so
    # this is the odd one out being brought into line rather than a new
    # convention. `save_rgba` un-premultiplies on the way to PNG, because
    # PNG stores straight alpha and the shell's Image reads it that way.
    body = body * alpha

    out = np.concatenate([body, alpha], axis=2)
    if ss > 1:
        out = out.reshape(H, ss, W, ss, 4).mean(axis=(1, 3))
    return out


def load_tex(path):
    return np.asarray(Image.open(path).convert("RGB")).astype(np.float32) / 255.0


def _dither(a):
    """Break 8-bit contour banding with sub-LSB noise.

    A glow that falls off slowly crosses each 1/255 step over a wide band
    of pixels, and the eye locks onto that boundary as a hard line — the
    eclipse wall wore a star-shaped outline made entirely of quantisation.
    Adding uniform noise of about one code before rounding turns the step
    into a gradient of mixed codes, which is what dithering is for. It is
    applied at SAVE time so every wall gets it, not just the one that
    happened to show it.
    """
    n = np.random.default_rng(7).random(a.shape).astype(np.float32) - 0.5
    return a + n * (1.15 / 255.0)


def save_rgba(arr, path):
    """Un-premultiply, then write. PNG alpha is straight, not premultiplied."""
    arr = np.asarray(arr, np.float32).copy()
    al = np.clip(arr[..., 3:4], 0.0, 1.0)
    # FLOOR THE DIVISOR. Un-premultiplying is rgb/alpha, and at alpha
    # 1/255 that is a multiply by 255 — it takes the half-code of rounding
    # error that every faint pixel carries and turns it into a saturated
    # colour speckle, which showed up as a green/yellow fringe along the
    # outside of the eclipse glow. Below about 1/64 the pixel contributes
    # almost nothing once alpha is applied again, so clamping the divisor
    # there costs nothing visible and removes the blow-up entirely.
    FLOOR = 1.0 / 64.0
    arr[..., :3] = np.where(al > 1e-4,
                            np.clip(arr[..., :3] / np.maximum(al, FLOOR), 0, 1),
                            0.0)
    arr[..., 3:4] = al
    a = np.clip(_dither(arr), 0.0, 1.0)
    Image.fromarray((a * 255.0 + 0.5).astype(np.uint8), "RGBA").save(path)


def save_rgb(arr, path):
    a = np.clip(_dither(arr[..., :3]), 0.0, 1.0)
    Image.fromarray((a * 255.0 + 0.5).astype(np.uint8), "RGB").save(path)
