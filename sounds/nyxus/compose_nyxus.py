#!/usr/bin/env python3
"""Suxyn ice-bell sound theme — full OS event stack.

Identity (index.theme): struck ice / glacier bar. Near-harmonic partials
    1, 2.004, 3.012, 4.028, 5.05, 6.09
plus an octave-below hum. Sings; does not clang. Deliberate opposite of
the alien struck-glass set (inharmonic 1, 2.00, 2.76, 5.40, 8.93 + ring
mod). No laughs, yells, chatter.

Two-tier mix (unchanged):
    ui-*           peak 0.106–0.134
    system events  peak 0.850   (~16 dB above the loudest ui stem)

sox is not on this host (nyxus-sound-bake already noted that). Synthesis
is numpy; ffmpeg writes the .oga siblings canberra prefers.

Usage:
    python3 compose_nyxus.py [--out DIR] [--no-oga]
Default --out is this file's stereo/ directory.
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import wave

import numpy as np
from scipy.signal import butter, sosfilt

SR = 48000

# Stiff-bar stretch — a real ice bar, not a harmonic oscillator.
PARTIALS = (
    # ratio, amp, decay (1/s)
    (1.000, 1.00, 3.4),
    (2.004, 0.62, 5.1),
    (3.012, 0.34, 7.2),
    (4.028, 0.18, 9.6),
    (5.050, 0.11, 12.4),
    (6.090, 0.065, 16.0),
)
HUM_RATIO, HUM_AMP, HUM_DECAY = 0.500, 0.22, 2.05

# Peak targets. 20*log10(0.850/0.134) = 16.05 dB.
UI_PEAK = {
    "ui-press": 0.107,
    "ui-release": 0.106,
    "ui-knock": 0.110,
    "ui-arrive": 0.123,
    "ui-notify": 0.134,
    "ui-lock": 0.108,
    "ui-unlock": 0.120,
    "ui-battery": 0.119,
    "ui-error": 0.106,
}
SYS_PEAK = 0.850

# Icy scale around D5–A6.
C5, D5, E5, F5, G5, A5, B5 = 523.25, 587.33, 659.25, 698.46, 783.99, 880.00, 987.77
C6, D6, E6, F6, G6, A6 = 1046.50, 1174.66, 1318.51, 1396.91, 1567.98, 1760.00
A4, B4, C4, D4, E4 = 440.00, 493.88, 261.63, 293.66, 329.63


def _hpf() -> np.ndarray:
    return butter(2, 35.0, btype="highpass", fs=SR, output="sos")


HPF = _hpf()


def _seed(name: str) -> np.random.Generator:
    h = 0
    for ch in name:
        h = (h * 131 + ord(ch)) & 0xFFFFFFFF
    return np.random.default_rng(0x5A17CE ^ h)


def ice_bell(
    freq: float,
    dur: str | float,
    *,
    name: str = "tone",
    strike: float = 0.65,
    brightness: float = 1.0,
    hum: float = 1.0,
    attack: float = 0.0018,
    width: float = 1.0,
    crackle: float = 1.0,
) -> np.ndarray:
    """One struck ice bar. Returns float64 (n, 2), un-normalised."""
    dur = float(dur)
    n = max(8, int(round(dur * SR)))
    t = np.arange(n, dtype=np.float64) / SR
    rng = _seed(f"{name}:{freq:.3f}:{dur:.4f}")

    att = np.minimum(1.0, t / max(attack, 1.0 / SR))
    att = att * att * (3.0 - 2.0 * att)  # smoothstep
    # Tiny end taper so a truncated ring never clicks.
    tail = np.minimum(1.0, (dur - t) / 0.012)
    tail = np.clip(tail, 0.0, 1.0)
    tail = tail * tail * (3.0 - 2.0 * tail)

    detune = 0.00085 * width  # ~1.5 cents, ice shimmer not chorus
    delay_r = int(round(5 * width))  # ~0.1 ms

    left = np.zeros(n, dtype=np.float64)
    right = np.zeros(n, dtype=np.float64)

    for ratio, amp, decay in PARTIALS:
        a = amp * (brightness ** max(0.0, ratio - 1.0))
        # Harder strike couples more into the upper bar.
        a *= 0.72 + 0.45 * strike * min(ratio, 3.0) / 3.0
        d = decay * (0.85 + 0.35 * strike)
        env = att * np.exp(-d * t) * tail
        fl = freq * ratio * (1.0 - detune * 0.5)
        fr = freq * ratio * (1.0 + detune * 0.5)
        left += a * env * np.sin(2.0 * np.pi * fl * t)
        right += a * env * np.sin(2.0 * np.pi * fr * t)

    if hum > 0.0:
        he = att * np.exp(-HUM_DECAY * t) * tail * HUM_AMP * hum
        fh = freq * HUM_RATIO
        # Hum is almost mono — the matte under the ice.
        hwave = he * np.sin(2.0 * np.pi * fh * t)
        left += hwave * 0.96
        right += hwave * 1.00

    # Ice-crack transient: brief band-limited noise at the strike.
    if crackle > 0.0:
        cn = min(n, int(0.006 * SR))
        noise = rng.standard_normal(cn)
        # One-pole-ish brighten then decay.
        k = np.exp(-np.arange(cn) / (0.0016 * SR))
        crack = noise * k * (0.055 * crackle * strike)
        left[:cn] += crack
        right[:cn] += crack * (0.92 + 0.08 * rng.random())

    if delay_r > 0:
        r2 = np.zeros(n, dtype=np.float64)
        r2[delay_r:] = right[:-delay_r]
        right = r2

    stereo = np.stack([left, right], axis=1)
    stereo = sosfilt(HPF, stereo, axis=0)
    stereo -= stereo.mean(axis=0, keepdims=True)
    return stereo


def place(canvas: np.ndarray, tone: np.ndarray, at: float) -> None:
    i0 = int(round(at * SR))
    if i0 >= canvas.shape[0]:
        return
    i1 = min(canvas.shape[0], i0 + tone.shape[0])
    canvas[i0:i1] += tone[: i1 - i0]


def render(dur: float, hits: list, *, name: str) -> np.ndarray:
    n = max(8, int(round(dur * SR)))
    buf = np.zeros((n, 2), dtype=np.float64)
    for hit in hits:
        t0 = hit[0]
        freq = hit[1]
        kw = dict(hit[2]) if len(hit) > 2 else {}
        tone_dur = kw.pop("dur", max(0.04, dur - t0))
        buf_kw = {"name": f"{name}:{t0:.3f}:{freq:.1f}"}
        buf_kw.update(kw)
        place(buf, ice_bell(freq, tone_dur, **buf_kw), t0)
    buf = sosfilt(HPF, buf, axis=0)
    buf -= buf.mean(axis=0, keepdims=True)
    return buf


def peak_norm(buf: np.ndarray, peak: float) -> np.ndarray:
    m = float(np.max(np.abs(buf)))
    if m < 1e-12:
        return buf
    out = buf * (peak / m)
    # Guard against rounding overshoot when we quantise later.
    m2 = float(np.max(np.abs(out)))
    if m2 > 0.97:
        out *= 0.97 / m2
    return out


def write_wav(path: str, buf: np.ndarray) -> None:
    pcm = np.clip(np.round(buf * 32767.0), -32767, 32767).astype(np.int16)
    with wave.open(path, "w") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def stats(buf: np.ndarray) -> dict:
    peak = float(np.max(np.abs(buf)))
    dc = float(np.mean(buf))
    rms = float(np.sqrt(np.mean(buf * buf)))
    return {
        "dur": buf.shape[0] / SR,
        "peak": peak,
        "dc": dc,
        "rms": rms,
        "ch": buf.shape[1],
        "sr": SR,
    }


# ── event book ──────────────────────────────────────────────────────────
# Each entry: (duration_s, hits, peak)
# hit = (time, freq, kwargs)

def _book() -> dict:
    s = SYS_PEAK
    short_ui = dict(attack=0.0012, hum=0.28, crackle=0.55, width=0.7, brightness=1.05)
    mid_ui = dict(attack=0.0016, hum=0.40, crackle=0.70, width=0.85, brightness=1.0)
    sys_k = dict(attack=0.0022, hum=1.0, crackle=1.0, width=1.0, brightness=1.0)
    dull = dict(attack=0.0028, hum=1.15, crackle=0.55, width=0.8, brightness=0.72)
    bright = dict(attack=0.0016, hum=0.75, crackle=1.15, width=1.05, brightness=1.18)

    events = {
        # ── UI family, 40–120 ms, quiet ────────────────────────────────
        "ui-press": (
            0.080,
            [(0.0, A6, {**short_ui, "dur": 0.080, "strike": 0.55, "brightness": 1.12})],
            UI_PEAK["ui-press"],
        ),
        "ui-release": (
            0.070,
            [(0.0, E6, {**short_ui, "dur": 0.070, "strike": 0.40, "brightness": 0.95, "hum": 0.18})],
            UI_PEAK["ui-release"],
        ),
        "ui-knock": (
            0.095,
            [(0.0, G5, {**short_ui, "dur": 0.095, "strike": 0.80, "brightness": 0.70, "hum": 0.55, "crackle": 0.9})],
            UI_PEAK["ui-knock"],
        ),
        "ui-arrive": (
            0.115,
            [
                (0.000, E6, {**mid_ui, "dur": 0.100, "strike": 0.50}),
                (0.038, A6, {**mid_ui, "dur": 0.077, "strike": 0.58, "brightness": 1.10}),
            ],
            UI_PEAK["ui-arrive"],
        ),
        "ui-notify": (
            0.120,
            [
                (0.000, A5, {**mid_ui, "dur": 0.120, "strike": 0.52}),
                (0.028, E6, {**mid_ui, "dur": 0.092, "strike": 0.50, "brightness": 1.08}),
            ],
            UI_PEAK["ui-notify"],
        ),
        "ui-lock": (
            0.120,
            [
                (0.000, A5, {**mid_ui, "dur": 0.100, "strike": 0.55}),
                (0.040, E5, {**mid_ui, "dur": 0.080, "strike": 0.48, "brightness": 0.85, "hum": 0.55}),
            ],
            UI_PEAK["ui-lock"],
        ),
        "ui-unlock": (
            0.120,
            [
                (0.000, E5, {**mid_ui, "dur": 0.100, "strike": 0.48}),
                (0.040, A5, {**mid_ui, "dur": 0.080, "strike": 0.56, "brightness": 1.08}),
            ],
            UI_PEAK["ui-unlock"],
        ),
        "ui-battery": (
            0.120,
            [
                (0.000, D5, {**mid_ui, "dur": 0.120, "strike": 0.50, "brightness": 0.82, "hum": 0.60}),
                (0.036, F5, {**mid_ui, "dur": 0.084, "strike": 0.48, "brightness": 0.88}),
            ],
            UI_PEAK["ui-battery"],
        ),
        "ui-error": (
            0.120,
            [
                (0.000, D5, {**mid_ui, "dur": 0.120, "strike": 0.70, "brightness": 0.78, "hum": 0.70, "crackle": 0.85}),
                (0.055, A4, {**mid_ui, "dur": 0.065, "strike": 0.45, "hum": 0.80, "brightness": 0.70}),
            ],
            UI_PEAK["ui-error"],
        ),
        # ── system events, present, 150–600 ms (boot/login ≤ 1.2 s) ────
        "audio-volume-change": (
            0.090,
            [(0.0, A5, {**bright, "dur": 0.090, "strike": 0.60, "hum": 0.35, "crackle": 0.4})],
            s,
        ),
        "bell": (
            0.280,
            [(0.0, E5, {**sys_k, "dur": 0.280, "strike": 0.62, "brightness": 1.05})],
            s,
        ),
        "bell-terminal": (
            0.220,
            [(0.0, G5, {**sys_k, "dur": 0.220, "strike": 0.58, "brightness": 1.10, "hum": 0.70})],
            s,
        ),
        "complete": (
            0.420,
            [
                (0.000, E5, {**sys_k, "dur": 0.280, "strike": 0.52}),
                (0.090, B5, {**sys_k, "dur": 0.280, "strike": 0.55}),
                (0.180, E6, {**bright, "dur": 0.240, "strike": 0.58}),
            ],
            s,
        ),
        "complete-copy": (
            0.320,
            [
                (0.000, G5, {**sys_k, "dur": 0.240, "strike": 0.52}),
                (0.085, D6, {**bright, "dur": 0.235, "strike": 0.58}),
            ],
            s,
        ),
        "complete-download": (
            0.500,
            [
                (0.000, D5, {**sys_k, "dur": 0.300, "strike": 0.50}),
                (0.110, A5, {**sys_k, "dur": 0.300, "strike": 0.54}),
                (0.220, D6, {**bright, "dur": 0.280, "strike": 0.58}),
            ],
            s,
        ),
        "device-added": (
            0.340,
            [
                (0.000, A5, {**sys_k, "dur": 0.240, "strike": 0.55}),
                (0.080, E6, {**bright, "dur": 0.260, "strike": 0.60}),
            ],
            s,
        ),
        "device-removed": (
            0.340,
            [
                (0.000, E6, {**sys_k, "dur": 0.220, "strike": 0.55, "brightness": 0.95}),
                (0.085, A5, {**dull, "dur": 0.255, "strike": 0.50}),
            ],
            s,
        ),
        "dialog-error": (
            0.520,
            [
                (0.000, D5, {**dull, "dur": 0.320, "strike": 0.75}),
                (0.160, A4, {**dull, "dur": 0.360, "strike": 0.70, "hum": 1.35}),
            ],
            s,
        ),
        "dialog-information": (
            0.360,
            [(0.0, E5, {**sys_k, "dur": 0.360, "strike": 0.50, "brightness": 1.02})],
            s,
        ),
        "dialog-warning": (
            0.420,
            [
                (0.000, D5, {**sys_k, "dur": 0.300, "strike": 0.62, "brightness": 0.88, "hum": 1.1}),
                (0.095, F5, {**sys_k, "dur": 0.325, "strike": 0.58, "brightness": 0.92}),
            ],
            s,
        ),
        "message": (
            0.360,
            [
                (0.000, A5, {**sys_k, "dur": 0.300, "strike": 0.50}),
                (0.055, E6, {**bright, "dur": 0.305, "strike": 0.52}),
            ],
            s,
        ),
        "message-new-instant": (
            0.260,
            [
                (0.000, C6, {**bright, "dur": 0.200, "strike": 0.55}),
                (0.045, G6, {**bright, "dur": 0.215, "strike": 0.58}),
            ],
            s,
        ),
        "message-new-email": (
            0.400,
            [
                (0.000, G5, {**sys_k, "dur": 0.300, "strike": 0.48, "hum": 0.85}),
                (0.070, D6, {**sys_k, "dur": 0.330, "strike": 0.52, "brightness": 1.05}),
            ],
            s,
        ),
        "network-connectivity-established": (
            0.440,
            [
                (0.000, G5, {**sys_k, "dur": 0.260, "strike": 0.50}),
                (0.090, D6, {**sys_k, "dur": 0.260, "strike": 0.54}),
                (0.180, G6, {**bright, "dur": 0.260, "strike": 0.58}),
            ],
            s,
        ),
        "network-connectivity-lost": (
            0.440,
            [
                (0.000, G6, {**sys_k, "dur": 0.240, "strike": 0.55, "brightness": 0.95}),
                (0.095, D6, {**sys_k, "dur": 0.250, "strike": 0.50}),
                (0.190, G5, {**dull, "dur": 0.250, "strike": 0.48}),
            ],
            s,
        ),
        "power-plug": (
            0.280,
            [
                (0.000, E5, {**sys_k, "dur": 0.200, "strike": 0.52}),
                (0.070, B5, {**bright, "dur": 0.210, "strike": 0.58}),
            ],
            s,
        ),
        "power-unplug": (
            0.280,
            [
                (0.000, B5, {**sys_k, "dur": 0.190, "strike": 0.55}),
                (0.075, E5, {**dull, "dur": 0.205, "strike": 0.50}),
            ],
            s,
        ),
        "screen-capture": (
            0.180,
            [
                (0.000, D6, {**bright, "dur": 0.160, "strike": 0.72, "hum": 0.30, "crackle": 1.4, "attack": 0.0008}),
            ],
            s,
        ),
        "camera-shutter": (
            0.200,
            [
                (0.000, E6, {**bright, "dur": 0.090, "strike": 0.80, "hum": 0.22, "crackle": 1.5, "attack": 0.0007}),
                (0.055, A5, {**bright, "dur": 0.145, "strike": 0.55, "hum": 0.35, "crackle": 0.8}),
            ],
            s,
        ),
        "service-login": (
            1.050,
            [
                (0.000, E5, {**sys_k, "dur": 0.620, "strike": 0.48, "hum": 1.05}),
                (0.160, A5, {**sys_k, "dur": 0.620, "strike": 0.50}),
                (0.320, E6, {**bright, "dur": 0.620, "strike": 0.54}),
                (0.480, A6, {**bright, "dur": 0.570, "strike": 0.50, "hum": 0.55}),
            ],
            s,
        ),
        "service-logout": (
            1.050,
            [
                (0.000, A6, {**sys_k, "dur": 0.520, "strike": 0.50, "hum": 0.55}),
                (0.160, E6, {**sys_k, "dur": 0.560, "strike": 0.50}),
                (0.320, A5, {**sys_k, "dur": 0.600, "strike": 0.48}),
                (0.480, E5, {**dull, "dur": 0.570, "strike": 0.46, "hum": 1.15}),
            ],
            s,
        ),
        "trash-empty": (
            0.460,
            [
                (0.000, A5, {**sys_k, "dur": 0.240, "strike": 0.45, "brightness": 0.90}),
                (0.100, E5, {**sys_k, "dur": 0.260, "strike": 0.42, "hum": 0.90}),
                (0.210, C5, {**dull, "dur": 0.250, "strike": 0.40, "hum": 1.10}),
            ],
            s,
        ),
        "window-attention": (
            0.420,
            [
                (0.000, E5, {**sys_k, "dur": 0.220, "strike": 0.62}),
                (0.175, E5, {**sys_k, "dur": 0.245, "strike": 0.58, "brightness": 1.05}),
            ],
            s,
        ),
        "window-question": (
            0.360,
            [
                (0.000, E5, {**sys_k, "dur": 0.240, "strike": 0.50}),
                (0.090, G5, {**bright, "dur": 0.270, "strike": 0.52}),
            ],
            s,
        ),
        "battery-low": (
            0.400,
            [
                (0.000, D5, {**dull, "dur": 0.280, "strike": 0.58}),
                (0.090, F5, {**sys_k, "dur": 0.310, "strike": 0.52, "brightness": 0.88}),
            ],
            s,
        ),
        "battery-caution": (
            0.460,
            [
                (0.000, D5, {**dull, "dur": 0.240, "strike": 0.70}),
                (0.150, D5, {**dull, "dur": 0.310, "strike": 0.66, "hum": 1.25}),
            ],
            s,
        ),
        "battery-full": (
            0.500,
            [
                (0.000, E5, {**sys_k, "dur": 0.300, "strike": 0.48}),
                (0.110, G5, {**sys_k, "dur": 0.300, "strike": 0.50}),
                (0.220, B5, {**bright, "dur": 0.280, "strike": 0.54}),
            ],
            s,
        ),
        "alarm-clock-elapsed": (
            0.600,
            [
                (0.000, A5, {**sys_k, "dur": 0.160, "strike": 0.70}),
                (0.070, A5, {**sys_k, "dur": 0.160, "strike": 0.62, "brightness": 1.05}),
                (0.300, A5, {**sys_k, "dur": 0.180, "strike": 0.70}),
                (0.375, A5, {**sys_k, "dur": 0.225, "strike": 0.64, "brightness": 1.08}),
            ],
            s,
        ),
        "suspend-error": (
            0.500,
            [
                (0.000, D5, {**dull, "dur": 0.280, "strike": 0.72, "hum": 1.30}),
                (0.140, C5, {**dull, "dur": 0.360, "strike": 0.68, "hum": 1.40, "brightness": 0.65}),
            ],
            s,
        ),
        "search-results": (
            0.220,
            [(0.0, C6, {**bright, "dur": 0.220, "strike": 0.52, "hum": 0.45})],
            s,
        ),
        "theme-demo": (
            0.780,
            [
                (0.000, E5, {**sys_k, "dur": 0.420, "strike": 0.50, "hum": 1.0}),
                (0.130, G5, {**sys_k, "dur": 0.420, "strike": 0.52}),
                (0.260, B5, {**sys_k, "dur": 0.420, "strike": 0.54}),
                (0.390, E6, {**bright, "dur": 0.390, "strike": 0.56, "hum": 0.70}),
            ],
            s,
        ),
        "lock": (
            0.360,
            [
                (0.000, A5, {**sys_k, "dur": 0.240, "strike": 0.55}),
                (0.090, E5, {**dull, "dur": 0.270, "strike": 0.50}),
            ],
            s,
        ),
        "unlock": (
            0.360,
            [
                (0.000, E5, {**sys_k, "dur": 0.240, "strike": 0.50}),
                (0.090, A5, {**bright, "dur": 0.270, "strike": 0.56}),
            ],
            s,
        ),
        "screen-locked": (
            0.460,
            [
                (0.000, A5, {**sys_k, "dur": 0.300, "strike": 0.55, "hum": 1.05}),
                (0.110, E5, {**dull, "dur": 0.350, "strike": 0.50}),
            ],
            s,
        ),
        "screen-unlocked": (
            0.460,
            [
                (0.000, E5, {**sys_k, "dur": 0.300, "strike": 0.50}),
                (0.110, A5, {**bright, "dur": 0.350, "strike": 0.56}),
            ],
            s,
        ),
        "notification": (
            0.320,
            [
                (0.000, A5, {**sys_k, "dur": 0.260, "strike": 0.50}),
                (0.050, E6, {**bright, "dur": 0.270, "strike": 0.52}),
            ],
            s,
        ),
        "alert": (
            0.460,
            [
                (0.000, D5, {**sys_k, "dur": 0.240, "strike": 0.72, "brightness": 0.90, "hum": 1.15}),
                (0.170, D5, {**dull, "dur": 0.290, "strike": 0.68, "hum": 1.20}),
            ],
            s,
        ),
        "boot": (
            1.120,
            [
                (0.000, E5, {**sys_k, "dur": 0.780, "strike": 0.42, "hum": 1.20, "attack": 0.012}),
                (0.180, A5, {**sys_k, "dur": 0.780, "strike": 0.46, "attack": 0.010}),
                (0.360, E6, {**bright, "dur": 0.760, "strike": 0.50, "hum": 0.70, "attack": 0.008}),
            ],
            s,
        ),
        "startup": (
            0.920,
            [
                (0.000, E5, {**sys_k, "dur": 0.640, "strike": 0.45, "hum": 1.10, "attack": 0.010}),
                (0.140, A5, {**sys_k, "dur": 0.640, "strike": 0.48, "attack": 0.008}),
                (0.280, E6, {**bright, "dur": 0.640, "strike": 0.52, "hum": 0.65, "attack": 0.006}),
            ],
            s,
        ),
        "battery-critical": (
            0.520,
            [
                (0.000, D5, {**dull, "dur": 0.260, "strike": 0.78, "hum": 1.35}),
                (0.140, A4, {**dull, "dur": 0.240, "strike": 0.72}),
                (0.280, D5, {**dull, "dur": 0.240, "strike": 0.70, "hum": 1.40}),
            ],
            s,
        ),
    }
    return events


ALIASES = {
    "desktop-login": "service-login",
    "desktop-logout": "service-logout",
    "screenshot": "screen-capture",
}


def encode_oga(wav_path: str, oga_path: str) -> None:
    subprocess.run(
        [
            "ffmpeg", "-nostdin", "-hide_banner", "-v", "error", "-y",
            "-i", wav_path,
            "-c:a", "libvorbis", "-qscale:a", "5",
            oga_path,
        ],
        check=True,
    )


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    here = os.path.dirname(os.path.abspath(__file__))
    ap.add_argument("--out", default=os.path.join(here, "stereo"),
                    help="directory for wav/oga stems")
    ap.add_argument("--no-oga", action="store_true")
    args = ap.parse_args()
    out = os.path.abspath(args.out)
    os.makedirs(out, exist_ok=True)

    have_ffmpeg = shutil.which("ffmpeg") is not None
    if not args.no_oga and not have_ffmpeg:
        print("compose_nyxus: ffmpeg not on PATH; writing wav only", file=sys.stderr)

    book = _book()
    rendered: dict[str, np.ndarray] = {}
    report = []

    for name, (dur, hits, peak) in sorted(book.items()):
        buf = peak_norm(render(dur, hits, name=name), peak)
        st = stats(buf)
        if abs(st["dc"]) > 1e-4:
            buf = buf - buf.mean(axis=0, keepdims=True)
            st = stats(buf)
        rendered[name] = buf
        path = os.path.join(out, f"{name}.wav")
        write_wav(path, buf)
        report.append((name, st, path))

    for alias, src in sorted(ALIASES.items()):
        buf = rendered[src]
        path = os.path.join(out, f"{alias}.wav")
        write_wav(path, buf)
        report.append((alias, stats(buf), path))

    if have_ffmpeg and not args.no_oga:
        for name, _st, wav_path in report:
            encode_oga(wav_path, os.path.join(out, f"{name}.oga"))

    ui_peaks = [st["peak"] for name, st, _ in report if name.startswith("ui-")]
    sys_peaks = [st["peak"] for name, st, _ in report if not name.startswith("ui-")]
    loud_ui = max(ui_peaks) if ui_peaks else 0.0
    sys_p = max(sys_peaks) if sys_peaks else 0.0
    gap_db = 20.0 * np.log10(sys_p / loud_ui) if loud_ui > 0 else 0.0

    print(f"wrote {len(report)} wav stems → {out}")
    print(f"  ui peak range  {min(ui_peaks):.4f} – {max(ui_peaks):.4f}")
    print(f"  system peak    {min(sys_peaks):.4f} – {max(sys_peaks):.4f}")
    print(f"  gap            {gap_db:.2f} dB  (want ~16)")
    bad = []
    for name, st, _ in report:
        if st["ch"] != 2 or st["sr"] != SR:
            bad.append(f"{name}: not 48k stereo")
        if abs(st["dc"]) > 5e-4:
            bad.append(f"{name}: DC {st['dc']:+.6f}")
        if st["peak"] > 0.97:
            bad.append(f"{name}: peak {st['peak']:.4f} near clip")
        if name.startswith("ui-") and not (0.09 <= st["peak"] <= 0.16):
            bad.append(f"{name}: ui peak {st['peak']:.4f} off-tier")
        if not name.startswith("ui-") and abs(st["peak"] - SYS_PEAK) > 0.02:
            bad.append(f"{name}: system peak {st['peak']:.4f}")
        if name in ("boot", "startup", "service-login", "service-logout") and st["dur"] > 1.21:
            bad.append(f"{name}: {st['dur']:.3f}s too long")
        if name.startswith("ui-") and st["dur"] > 0.15:
            bad.append(f"{name}: ui {st['dur']:.3f}s too long")
    if bad:
        print("VERIFY FAIL:")
        for line in bad:
            print(" ", line)
        return 1
    print("verify ok: 48 kHz stereo, no DC, two-tier mix, durations in family.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
