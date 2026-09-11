#!/usr/bin/env python3
"""Build the WebGL2 tuning harness from starlight3d.frag.

The shipped shader is Qt-flavoured GLSL: `#version 440`, a std140 uniform
block, `layout(location=...)` on the varying and the output. A browser wants
`#version 300 es`, loose uniforms and no layout qualifiers. Those differences
are ALL in the header — the body below the PORTABLE BODY marker is ordinary
GLSL and is copied byte for byte.

That is the point of doing this with a script rather than by hand. The 2D
headliner was ported from design/starlight-live.html by eye and inherited a
units bug from it (rel measured in cell units, sizes in screen units) that
survived a full version because two copies of the same maths drifted apart.
One copy, mechanically transformed, cannot drift.

    python3 shell/shaders/mkwebgl.py        # writes design/starlight3d-live.html
"""
from __future__ import annotations

import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent
FRAG = HERE / "starlight3d.frag"
OUT = REPO / "design" / "starlight3d-live.html"

MARKER = "PORTABLE BODY BELOW"

# The WebGL2 header that replaces the Qt one. qt_TexCoord0 is flipped in y:
# Qt's varying has its origin at the TOP-left, gl_FragCoord at the bottom-left,
# and the shader relies on that orientation for "down" (the light, the band).
WEBGL_HEADER = """#version 300 es
precision highp float;

uniform float u_time;
uniform vec2  u_resolution;
uniform vec2  u_mouse;
uniform vec4  u_look;
uniform vec4  u_scene;
uniform vec4  u_flags;

// WIP-553 — Theme.surfaceTop/Mid/Deep and Theme.glassBorder, snapshotted as
// consts (this harness has no QML/Theme.qml to read live). Starlight3D.qml
// is the source of truth; re-run this script by hand if those tokens move.
const vec4 u_groundTop  = vec4(0.012, 0.032, 0.040, 1.0);
const vec4 u_groundMid  = vec4(0.010, 0.026, 0.034, 1.0);
const vec4 u_groundDeep = vec4(0.012, 0.032, 0.040, 1.0);
const vec4 u_groundEdge = vec4(0.537, 0.098, 0.333, 1.0);

const float qt_Opacity = 1.0;

#define qt_TexCoord0 (vec2(gl_FragCoord.x, u_resolution.y - gl_FragCoord.y) / u_resolution)

out vec4 fragColor;
"""


def build_fragment_source() -> str:
    src = FRAG.read_text(encoding="utf-8")
    if MARKER not in src:
        sys.exit(f"{FRAG}: marker {MARKER!r} not found — refusing to guess where the body starts")
    body = src.split(MARKER, 1)[1]
    # Drop the REST OF THE MARKER'S OWN LINE first. It is the tail of a box-rule
    # comment whose `//` sat before the marker text, so it does not look like a
    # comment to the loop below and would be emitted as bare GLSL.
    body = body.split("\n", 1)[1] if "\n" in body else ""
    # Then drop the marker's explanatory comment block.
    lines = body.splitlines()
    while lines and (lines[0].lstrip().startswith("//") or not lines[0].strip()):
        lines.pop(0)
    return WEBGL_HEADER + "\n" + "\n".join(lines).rstrip() + "\n"


HTML = """<!doctype html>
<meta charset="utf-8">
<title>Nyxus Suxyn — Starlight Voyage (live)</title>
<!--
  GENERATED FILE — do not edit. Regenerate with:
      python3 shell/shaders/mkwebgl.py

  The fragment body below is copied verbatim from shell/shaders/starlight3d.frag.
  Tune here, then rebuild the .qsb (bash shell/shaders/build.sh); the two cannot
  disagree because only one of them is written by hand.
-->
<style>
  html, body { margin: 0; height: 100%%; background: #000; overflow: hidden; }
  canvas { display: block; width: 100vw; height: 100vh; }
  #hud {
    position: fixed; left: 12px; top: 12px; z-index: 2;
    font: 12px/1.55 ui-monospace, "JetBrains Mono", monospace;
    color: #cfe6ff; background: rgba(2, 8, 14, .62);
    border: 1px solid rgba(120, 200, 255, .22); border-radius: 8px;
    padding: 10px 12px; min-width: 232px; backdrop-filter: blur(6px);
  }
  #hud b { color: #d8a464; font-weight: 600; }
  #hud label { display: flex; align-items: center; gap: 8px; margin-top: 5px; }
  #hud label span:first-child { width: 84px; opacity: .78; }
  #hud input[type=range] { flex: 1; accent-color: #7a63f0; }
  #hud output { width: 34px; text-align: right; opacity: .95; }
  #fps { color: #9fe8c0; }
</style>
<canvas id="c"></canvas>
<div id="hud">
  <div><b>STARLIGHT VOYAGE</b> — <span id="fps">…</span></div>
  <label><span>density</span><input id="density" type="range" min="0" max="2" step="0.05" value="1"><output></output></label>
  <label><span>drift</span><input id="drift" type="range" min="0" max="4" step="0.05" value="1"><output></output></label>
  <label><span>galaxy</span><input id="galaxy" type="range" min="0" max="3" step="0.05" value="1"><output></output></label>
  <label><span>quality</span><input id="quality" type="range" min="0.35" max="1" step="0.05" value="1"><output></output></label>
  <label><span>twinkle</span><input id="twinkle" type="range" min="0" max="2" step="0.05" value="0.55"><output></output></label>
  <label><span>sparkle</span><input id="sparkle" type="range" min="0" max="2" step="0.05" value="0.9"><output></output></label>
  <label><span>warmth</span><input id="warmth" type="range" min="0" max="1" step="0.01" value="0.22"><output></output></label>
  <label><span>master</span><input id="master" type="range" min="0" max="2" step="0.05" value="1"><output></output></label>
  <div style="margin-top:7px;opacity:.66"><b>space</b> pause · ?mode=stars / galaxy / full</div>
</div>
<script id="fs" type="x-shader/x-fragment">
%(FRAGMENT)s
</script>
<script>
const VS = `#version 300 es
in vec2 p; void main() { gl_Position = vec4(p, 0.0, 1.0); }`;

const cv = document.getElementById("c");
const gl = cv.getContext("webgl2", { antialias: false, alpha: false, powerPreference: "high-performance" });
if (!gl) { document.body.innerHTML = "<p style='color:#f88;font:14px monospace;padding:20px'>WebGL2 unavailable.</p>"; throw 0; }

function compile(type, src) {
  const s = gl.createShader(type);
  gl.shaderSource(s, src.trim());
  gl.compileShader(s);
  if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) {
    const log = gl.getShaderInfoLog(s);
    document.body.innerHTML = "<pre style='color:#f88;font:12px monospace;padding:16px;white-space:pre-wrap'>"
      + log.replace(/[&<>]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c])) + "</pre>";
    throw new Error(log);
  }
  return s;
}

const prog = gl.createProgram();
gl.attachShader(prog, compile(gl.VERTEX_SHADER, VS));
gl.attachShader(prog, compile(gl.FRAGMENT_SHADER, document.getElementById("fs").textContent));
gl.bindAttribLocation(prog, 0, "p");
gl.linkProgram(prog);
if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(prog));
gl.useProgram(prog);

const buf = gl.createBuffer();
gl.bindBuffer(gl.ARRAY_BUFFER, buf);
gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
gl.enableVertexAttribArray(0);
gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);

const U = n => gl.getUniformLocation(prog, n);
const uTime = U("u_time"), uRes = U("u_resolution"), uMouse = U("u_mouse"),
      uLook = U("u_look"), uScene = U("u_scene"), uFlags = U("u_flags");

// Scene mode. ?mode=stars → the field alone · ?mode=galaxy → field + dust ·
// anything else → the full scene. These are the lock/login variants, and they
// are the SAME shader: turning the bodies off skips the SDF march and turning
// the dust off skips the volumetric one, so each cut is cheaper than the last.
const MODE = new URLSearchParams(location.search).get("mode") || "galaxy";
const FLAGS = MODE === "stars"  ? [0, 0, 0]
            : MODE === "galaxy" ? [0, 1, 0]
            : MODE === "dust"   ? [0, 1, 1]
            :                     [1, 1, 0];

const S = id => document.getElementById(id);
// ?hud=0 strips the panel, which is how the proof crops in design/ are taken.
if (new URLSearchParams(location.search).get("hud") === "0") S("hud").style.display = "none";
const ctl = ["density", "drift", "galaxy", "quality", "twinkle", "sparkle", "warmth", "master"]
  .reduce((a, id) => (a[id] = S(id), a), {});
for (const id in ctl) {
  const el = ctl[id], out = el.parentElement.querySelector("output");
  const sync = () => out.textContent = (+el.value).toFixed(2);
  el.addEventListener("input", sync); sync();
}

// Same easing the QML uses: frame-rate-independent exponential smoothing, so
// the harness and the desktop feel identical rather than merely similar.
let tx = 0, ty = 0, mx = 0, my = 0;
// Pointer tilt removed on the owner's call — the drift is the motion.
// tx/ty stay at 0 and u_mouse is handed through as a constant zero.

let paused = false;
addEventListener("keydown", e => { if (e.code === "Space") { paused = !paused; e.preventDefault(); } });

function resize() {
  const dpr = Math.min(devicePixelRatio || 1, 2);
  cv.width = Math.round(innerWidth * dpr);
  cv.height = Math.round(innerHeight * dpr);
  gl.viewport(0, 0, cv.width, cv.height);
}
addEventListener("resize", resize); resize();

// A fixed seed time so a screenshot of this page is reproducible; the query
// string ?t=SECONDS pins it, which is how the proof crops are taken.
const pinned = new URLSearchParams(location.search).get("t");
let t = pinned !== null ? parseFloat(pinned) : 0;
let last = performance.now(), acc = 0, frames = 0;

function frame(now) {
  const dt = Math.min((now - last) / 1000, 0.1); last = now;
  if (!paused && pinned === null) t += dt;

  const k = 1 - Math.exp(-dt / 0.18);
  mx += (tx - mx) * k; my += (ty - my) * k;
  if (pinned !== null) { mx = tx; my = ty; }

  gl.uniform1f(uTime, t);
  gl.uniform2f(uRes, cv.width, cv.height);
  gl.uniform2f(uMouse, mx, my);
  gl.uniform4f(uLook, +ctl.twinkle.value, +ctl.sparkle.value, +ctl.warmth.value, +ctl.master.value);
  gl.uniform4f(uScene, +ctl.density.value, +ctl.drift.value, +ctl.galaxy.value, +ctl.quality.value);
  gl.uniform4f(uFlags, FLAGS[0], FLAGS[1], FLAGS[2], 0);
  gl.drawArrays(gl.TRIANGLES, 0, 3);

  acc += dt; frames++;
  if (acc >= 0.5) { S("fps").textContent = (frames / acc).toFixed(0) + " fps"; acc = 0; frames = 0; }
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
</script>
"""


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(HTML % {"FRAGMENT": build_fragment_source()}, encoding="utf-8")
    print(f"✓ {OUT.relative_to(REPO)}  ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
