#version 440
// Nyxus Suxyn — THE LOCK SKY. The weather, drawn, at the display's own rate.
//
// This is the layer that makes the lock screen show you the world: rain that
// falls, snow that drifts, a sun that burns, a crescent moon, cloud decks, fog
// banks and lightning. It draws OVER `starlight3d.frag`'s star volume and
// UNDER the glass card, in one fragment pass.
//
// ── why this file exists at all ──────────────────────────────────────────
// The build already had a living sky on the lock, and it was not this. It was
// 116 pre-rendered PNGs stepped by hyprlock's `background { reload_cmd }` at
// exactly 1000 ms — because `hyprlock.conf` has a hard rule, learned by
// locking the owner out of his own machine, that NOTHING in it may poll faster
// than one second (two labels spawning subprocesses every 50 ms starved the
// event loop until the password field drew but would not accept input).
//
// One frame per second is a slideshow. Rain does not read as rain at 1 fps; it
// reads as a picture that keeps changing. `hyprlock.conf`'s own header already
// named the way out and nobody had built it yet:
//
//     "anything faster than 1 Hz belongs in the Quickshell lock surface
//      (WlSessionLock), where it is an animated property rather than a
//      process spawn per frame."
//
// So: this. Every moving thing here is a function of `geom.z` (seconds), which
// a QML Timer advances. There is no process, no file read and no allocation
// per frame — the 2026-08-02 lockout class is not reachable from this file,
// because there is nothing here to spawn.
//
// ── what is NOT decided here ─────────────────────────────────────────────
// The lightning FLASH is a uniform (`fx.x`), not a hash of time. A shader that
// rolls its own dice cannot be tested: you wait for the strike. Driving it from
// a QML animation means the whole storm can be run on demand, and it means the
// bolt and the flash are guaranteed to be the same event.
//
// Rebuild with shell/shaders/build.sh (it globs *.frag — nothing to list).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 geom;   // x,y = px size · z = seconds · w = master (0..1)
    vec4 wx;     // x = condition 0..6 · y = dayness 0..1 · z = intensity · w = wind
    vec4 fx;     // x = lightning flash 0..1 · y = fog · z = cloud · w = star dim
};

// ── the palette ──────────────────────────────────────────────────────────
// Same contract as pane.frag and starlight3d.frag: a .qsb cannot reach QML, so
// the stops are frozen here. Every one is a stop `theme/accent.json` names —
// gate 13q11 checks that claim against the whole shipped tree, and a colour
// invented here would fail it.
const vec3 P_TEAL        = vec3(0.039, 0.635, 0.839);  // #0aa2d6 teal
const vec3 P_TEAL_GLOW   = vec3(0.361, 0.776, 0.918);  // #5cc6ea teal_glow
const vec3 P_TEAL_DEEP   = vec3(0.008, 0.384, 0.510);  // #026282 teal_deep
const vec3 P_AZURE       = vec3(0.024, 0.310, 0.584);  // #064f95 azure
const vec3 P_AZURE_GLOW  = vec3(0.322, 0.627, 0.918);  // #52a0ea azure glow
const vec3 P_INDIGO      = vec3(0.118, 0.012, 0.678);  // #1e03ad indigo
const vec3 P_INDIGO_GLOW = vec3(0.478, 0.388, 0.941);  // #7a63f0 indigo_glow
const vec3 P_VIOLET      = vec3(0.322, 0.118, 0.447);  // #521e72 violet
const vec3 P_VIOLET_GLOW = vec3(0.667, 0.431, 0.808);  // #aa6ece violet_glow
const vec3 P_PLUM        = vec3(0.682, 0.125, 0.424);  // #ae206c plum accent
const vec3 P_PLUM_GLOW   = vec3(0.843, 0.396, 0.635);  // #d765a2 plum glow
const vec3 P_GOLD        = vec3(0.608, 0.384, 0.106);  // #9b621b gold
const vec3 P_GOLD_GLOW   = vec3(0.847, 0.643, 0.392);  // #d8a464 gold_glow
const vec3 P_RIM_LIGHT   = vec3(0.663, 0.702, 0.851);  // #a9b3d9 rim_light
const vec3 P_TEXT        = vec3(0.929, 0.945, 1.000);  // #edf1ff text

// Condition indices. Kept in one place because LockWeather.qml maps the same
// seven strings and a disagreement would be silent — snow rendered as rain.
const float C_CLEAR  = 0.0;
const float C_PARTLY = 1.0;
const float C_CLOUDS = 2.0;
const float C_FOG    = 3.0;
const float C_RAIN   = 4.0;
const float C_SNOW   = 5.0;
const float C_STORM  = 6.0;

float isC(float c) { return step(abs(wx.x - c), 0.5); }

// ── noise ────────────────────────────────────────────────────────────────
float hash11(float p) { return fract(sin(p * 127.1) * 43758.5453); }
vec2  hash22(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    q += dot(q, q.yzx + 33.33);
    return fract((q.xx + q.yz) * q.zy);
}
float hash21(vec2 p) {
    vec3 q = fract(vec3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i), b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0)), d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Five octaves is where a cloud stops looking like a stain. Four is visibly
// soft at 1080p; six costs a third more for a difference nobody sees at arm's
// length on a lock screen.
float fbm(vec2 p) {
    float s = 0.0, a = 0.5;
    for (int i = 0; i < 5; i++) { s += a * vnoise(p); p *= 2.02; a *= 0.5; }
    return s;
}

// ── cloud decks ──────────────────────────────────────────────────────────
// Two sheets at different depths, scrolling at different speeds. Parallax is
// the whole trick: one sheet is a texture, two are weather.
vec3 clouds(vec2 uv, float amount, float t, out float cover) {
    cover = 0.0;
    if (amount <= 0.001) return vec3(0.0);

    float w = wx.w;
    float far  = fbm(vec2(uv.x * 2.4 + t * 0.010 * w, uv.y * 3.4 + 4.0));
    float near = fbm(vec2(uv.x * 1.5 - t * 0.022 * w, uv.y * 2.1));

    // Weighted to the top of the frame; a deck that reaches the floor reads as
    // fog, and fog is a different condition with its own look below.
    float band = smoothstep(-0.10, 0.62, 1.0 - uv.y);

    float f = (far * 0.45 + near * 0.75) * band;
    f = smoothstep(0.30, 0.86, f) * amount;
    cover = f;

    // Lit from above: the crown of a cloud catches the day, its belly does not.
    float lit = smoothstep(0.25, 0.95, near) * (0.35 + 0.65 * wx.y);

    vec3 dayDeck   = mix(P_TEAL_DEEP, P_TEAL_GLOW, lit);
    vec3 nightDeck = mix(P_INDIGO * 0.55, P_VIOLET_GLOW * 0.60, lit);
    vec3 col = mix(nightDeck, dayDeck, wx.y);

    return col * f;
}

// ── fog banks ────────────────────────────────────────────────────────────
// Low, wide, slow, and never opaque. Fog that hides the clock is a bug.
//
// The first cut got this wrong in a way worth writing down: `low` ramped from
// the very top of the frame, so "fog" covered the whole screen, and with a
// broad fbm behind it the result was a flat teal wall — no structure, no
// depth, and it swallowed the day wash underneath. Fog is BANDS. It lives in
// the bottom half, it is stretched hard in x so it reads as strata rather than
// clouds, and it tops out well below opaque.
vec3 fogBanks(vec2 uv, float amount, float t) {
    if (amount <= 0.001) return vec3(0.0);

    // Stretched 5:1 in x — this is what makes it lie in layers.
    float a = fbm(vec2(uv.x * 0.9 + t * 0.014, uv.y * 6.5 + 1.0));
    float b = fbm(vec2(uv.x * 1.5 - t * 0.026, uv.y * 11.0 + 9.0));

    // Two thin decks rather than one mass, so there is an edge to see.
    float body = smoothstep(0.42, 0.86, a) * 0.65
               + smoothstep(0.52, 0.92, b) * 0.45;

    // Confined to the lower 55% and gone by mid-frame, so the clock and the
    // slab always sit in clear air.
    float low = smoothstep(0.45, 1.0, uv.y);

    float f = body * low * amount * 0.42;
    vec3 col = mix(mix(P_INDIGO, P_VIOLET, 0.45), P_TEAL_DEEP, wx.y);
    return col * f;
}

// ── the sun ──────────────────────────────────────────────────────────────
// Core, corona, and eight rays that breathe. Gold is points of light only in
// this build's palette — a sun is the one thing gold was always allowed to be.
vec3 sun(vec2 p, float t) {
    vec2 sp = p - vec2(0.62, -0.34);
    float d = length(sp);

    float core   = smoothstep(0.085, 0.052, d);
    float corona = pow(max(0.0, 1.0 - d / 0.85), 3.2);

    float ang = atan(sp.y, sp.x);
    float rays = 0.5 + 0.5 * sin(ang * 8.0 + sin(t * 0.30) * 0.8);
    rays *= pow(max(0.0, 1.0 - d / 0.62), 2.6) * 0.45;

    // A slow breath, not a flicker. The sun is the calmest thing in the sky.
    float breath = 0.94 + 0.06 * sin(t * 0.55);

    vec3 col = P_TEXT * core * 1.35
             + P_GOLD_GLOW * (corona * 0.85 + rays)
             + P_GOLD * corona * 0.30;
    return col * breath;
}

// ── the moon ─────────────────────────────────────────────────────────────
// A crescent is a disc minus an offset disc. Doing it with two SDFs rather
// than a texture means the phase is a number, and the terminator stays sharp
// at any resolution.
vec3 moon(vec2 p, float t) {
    vec2 mp = p - vec2(0.58, -0.40);
    float d = length(mp);

    float disc  = smoothstep(0.076, 0.066, d);
    float shade = smoothstep(0.076, 0.066, length(mp - vec2(0.030, 0.014)));
    float cres  = clamp(disc - shade, 0.0, 1.0);

    // Maria: the grey seas, just enough that it is not a blank coin.
    float sea = fbm(mp * 26.0) * 0.16;
    cres *= (1.0 - sea);

    float halo = pow(max(0.0, 1.0 - d / 0.42), 3.0) * 0.16;
    float glint = 0.97 + 0.03 * sin(t * 0.4);

    return (P_TEXT * cres * 1.20 + P_RIM_LIGHT * halo) * glint;
}

// ── rain ─────────────────────────────────────────────────────────────────
// Three depths. Each layer is a grid of cells; one drop lives in each cell,
// placed and phased by a hash of the cell, falling at the layer's speed and
// sheared sideways by the wind. Near layers are faster, longer and brighter,
// which is the only cue that makes a flat plane of streaks read as depth.
vec3 rain(vec2 uv, float t, float amount) {
    if (amount <= 0.001) return vec3(0.0);
    vec3 acc = vec3(0.0);
    float aspect = geom.x / max(geom.y, 1.0);

    for (int i = 0; i < 3; i++) {
        float fi    = float(i);
        float depth = 0.55 + fi * 0.45;              // 0.55 · 1.00 · 1.45
        float dens  = 16.0 + fi * 13.0;              // cells across
        float speed = 0.85 + fi * 0.75;
        float len   = 0.028 + fi * 0.026;            // streak length
        float wide  = 0.0022 - fi * 0.0004;          // and it thins with depth

        vec2 g = vec2(uv.x * aspect, uv.y) * dens;
        // Wind shears the whole grid; the shear is applied before the cell
        // split so a drop stays in its own cell and cannot tear.
        g.x += uv.y * wx.w * 2.2 * depth;

        vec2 id = floor(g);
        vec2 f  = fract(g);

        vec2  h  = hash22(id);
        float ph = h.x;
        float xj = 0.18 + h.y * 0.64;                // where in the cell it falls

        float y = fract(ph + t * speed * 0.55);      // 0 at the top of its cell
        float dy = f.y - y;
        float dx = f.x - xj;

        // A streak: tight in x, a soft tail in y trailing UP behind the head.
        float sx = smoothstep(wide * dens, 0.0, abs(dx));
        float sy = smoothstep(len * dens, 0.0, max(0.0, -dy)) * step(dy, 0.0);
        float drop = sx * sy;

        // Cull most cells or the sky is a curtain, not rain.
        drop *= step(hash21(id + 3.7), 0.34 + amount * 0.30);

        vec3 tint = mix(P_TEAL_GLOW, P_AZURE_GLOW, fi * 0.5);
        acc += tint * drop * (0.30 + 0.34 * fi);
    }

    // Splash glints along the floor: short-lived points where drops land.
    float sy = smoothstep(0.82, 1.0, uv.y);
    if (sy > 0.0) {
        vec2 g = vec2(uv.x * aspect, 0.0) * 30.0;
        float id = floor(g.x);
        float ph = hash11(id * 1.7);
        float life = fract(t * 1.6 + ph);
        float pop = smoothstep(0.0, 0.10, life) * smoothstep(0.55, 0.10, life);
        float dx = fract(g.x) - 0.5;
        float glint = smoothstep(0.16, 0.0, abs(dx)) * pop;
        acc += P_TEAL_GLOW * glint * sy * 0.42;
    }

    return acc * amount;
}

// ── snow ─────────────────────────────────────────────────────────────────
// Same cell scheme, different physics: slower, round, and each flake sways on
// its own phase so the field never pulses in unison.
//
// ⚠ The first cut drew flakes at radius 0.052 of a cell — roughly six pixels,
// hard-edged, near-white. On a black sky that would have been fine. On THIS
// sky it was invisible: the background is a star volume, and a six-pixel white
// dot over a field of six-pixel white stars is a star. The 08-10 proof grid
// showed "snow · night" and "clear · night" as the same picture.
//
// So a flake is now bigger, SOFT (a core inside a halo — stars in the volume
// below have hard diffraction spikes, and softness is the cue that separates
// them), and it carries a little of the sweep rather than being pure white.
vec3 snow(vec2 uv, float t, float amount) {
    if (amount <= 0.001) return vec3(0.0);
    vec3 acc = vec3(0.0);
    float aspect = geom.x / max(geom.y, 1.0);

    for (int i = 0; i < 3; i++) {
        float fi    = float(i);
        float dens  = 7.0 + fi * 6.0;                // fewer, larger cells
        float speed = 0.055 + fi * 0.055;
        float rad   = 0.115 - fi * 0.028;

        vec2 g = vec2(uv.x * aspect, uv.y) * dens;
        g.x += uv.y * wx.w * 1.1;

        vec2 id = floor(g);
        vec2 f  = fract(g);
        vec2 h  = hash22(id);

        float y  = fract(h.x + t * speed);
        float sway = sin(t * (0.5 + h.y * 0.9) + h.x * 6.28318) * 0.18;
        vec2  c  = vec2(0.20 + h.y * 0.60 + sway, y);

        float d = length(f - c);

        // Core plus halo. The halo is what makes it read as a flake tumbling
        // through air rather than a point of light behind it.
        float core = smoothstep(rad * 0.55, 0.0, d);
        float halo = smoothstep(rad, rad * 0.30, d) * 0.45;
        float flake = core + halo;

        flake *= step(hash21(id + 11.3), 0.42 + amount * 0.26);

        acc += mix(P_RIM_LIGHT, P_TEXT, fi * 0.5) * flake * (0.42 + 0.26 * fi);
    }

    // Snow-light: the ground throws some of it back up. Raised from 0.05,
    // which was below the noise floor of the sky behind it.
    acc += P_RIM_LIGHT * smoothstep(0.62, 1.0, uv.y) * 0.16 * amount;
    return acc * amount;
}

// ── lightning ────────────────────────────────────────────────────────────
// The bolt is a line whose x wanders with fbm(y) — cheap, and it forks because
// the second segment starts from a point on the first with a different seed.
float bolt(vec2 uv, float seed, float w) {
    float x = 0.5 + (hash11(seed) - 0.5) * 0.55;
    x += (fbm(vec2(seed * 7.3, uv.y * 5.5)) - 0.5) * 0.30;
    float d = abs(uv.x - x);
    float body = smoothstep(w, 0.0, d);
    // Fades out toward the floor: bolts hit cloud base, not the taskbar.
    return body * smoothstep(0.95, 0.05, uv.y);
}

vec3 lightning(vec2 uv, float flash, float seed) {
    if (flash <= 0.001) return vec3(0.0);
    float b = bolt(uv, seed, 0.0035) * 1.0
            + bolt(uv, seed + 4.0, 0.0022) * 0.55;   // the fork
    float sheet = 0.06 + 0.22 * smoothstep(0.9, 0.0, uv.y);  // sky lights up
    return (P_TEXT * b * 1.6 + mix(P_INDIGO_GLOW, P_TEXT, 0.5) * sheet) * flash;
}

void main() {
    vec2 uv = qt_TexCoord0;          // 0..1, y DOWN
    vec2 p  = (uv - 0.5) * vec2(geom.x / max(geom.y, 1.0), 1.0) * 2.0;
    p.y = -p.y;                      // +y UP for the sky bodies
    float t = geom.z;

    float day   = clamp(wx.y, 0.0, 1.0);
    float amt   = clamp(wx.z, 0.0, 2.0);
    float clear  = isC(C_CLEAR);
    float partly = isC(C_PARTLY);
    float storm  = isC(C_STORM);

    vec3 col = vec3(0.0);

    // ── the daylight wash · REMOVED by owner ruling, 2026-08-17 ──────────
    // It was, and it is written out because a deletion nobody can read is a
    // deletion somebody re-adds:
    //
    //     float horizon = smoothstep(1.0, -0.15, uv.y);
    //     vec3 dayTop = mix(P_AZURE, P_TEAL, 0.22);
    //     vec3 dayLow = mix(P_TEAL_DEEP, P_TEAL, 0.26);
    //     col += mix(dayLow, dayTop, horizon) * day * 0.34;
    //
    // THE RULING: "an additive full-surface application of three stops, which
    // is the forbidden role ... a full-surface tint isn't the mechanism
    // regardless." So this is not a hue complaint and re-adding it in another
    // colour would miss the ruling entirely.
    //
    // THE SHAPE, because it is the `#891955` shape again: P_AZURE, P_TEAL and
    // P_TEAL_DEEP are all LEGAL palette members, and membership was never the
    // violated property. The violation was ROLE — three accent stops added
    // across the whole surface as a ground. Measured on the real lock surface
    // (headless-nested Hyprland, real WlSessionLock, noon/clear), over the
    // 3,330,000 px outside the glass card: pixels in the 175-215 deg hue band
    // at S>=0.15, V>=0.04 went 96.00% -> 3.19% of that region when these four
    // lines were removed, and mean sRGB went (7.9, 33.0, 45.0) -> (7.0, 8.8,
    // 8.8). Teal survives at 3% as an accent, which is the role it is for.
    //
    // NOT A CONTRAST FIX, and the numbers are here so nobody claims it was:
    // the password field measured 6.31:1 before and 6.30:1 after (WCAG 2.1,
    // AA body floor 4.5:1). Legibility was never the defect and did not move.
    //
    // The 08-10 pass cut the coefficient 0.55 -> 0.34 against this same
    // complaint. That mitigated the AMOUNT and left the ROLE untouched, which
    // is why the complaint came back.
    //
    // Nothing replaces it pending the owner's call. `day` still reaches the
    // sun, the bodies and LockWeather's `starDim`, so daylight still empties
    // the star volume and still lights a sun — see the rendered frames.

    // ── bodies ───────────────────────────────────────────────────────────
    float bodyVis = clear + partly * 0.65;
    col += sun(p, t)  * day * bodyVis;
    col += moon(p, t) * (1.0 - day) * bodyVis;

    // ── decks ────────────────────────────────────────────────────────────
    float cover;
    col += clouds(uv, fx.z, t, cover);
    col += fogBanks(uv, fx.y, t);

    // ── precipitation ────────────────────────────────────────────────────
    float rainAmt = isC(C_RAIN) * amt + storm * amt * 1.35;
    float snowAmt = isC(C_SNOW) * amt;
    col += rain(uv, t, rainAmt);
    col += snow(uv, t, snowAmt);

    // ── the strike ───────────────────────────────────────────────────────
    col += lightning(uv, fx.x * storm, floor(t * 0.25));

    // Premultiplied out. The rgb may exceed the alpha on purpose: this layer
    // ADDS light to the star volume beneath it rather than covering it, which
    // is how a sun can sit in front of a galaxy without punching a hole in it.
    float a = clamp(max(max(col.r, col.g), col.b), 0.0, 1.0);
    fragColor = vec4(col, a) * geom.w * qt_Opacity;
}
