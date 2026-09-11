#version 440
// Nyxus Suxyn — SLIPSTREAM. Flying through the stars, not looking at them.
//
// The space-scene prototype (owner's brief, 2026-08-13): parallax starfield
// with real forward motion, worlds that read as SPHERES, meteors with mass
// and trail physics, and — rarest of all — the visitor. A different
// technique family from both siblings:
//   · `starlight.frag`   — a CEILING: a flat plane of fibre points.
//   · `starlight3d.frag` — a WINDSHIELD: a 48-step SDF march + volumetrics,
//     which the owner turned off 2026-08-10 because a full raymarch is more
//     than the iGPU should pay for a wallpaper.
//   · THIS — full forward FLIGHT as a procedural scene. NO march anywhere:
//     every element is closed-form per pixel, so the budget goes to frame
//     rate and detail instead of stepping.
//
// WHY THE PARALLAX IS HONEST — the paragraph that matters:
// every star is a point in camera space with a real depth d; its screen
// position is world_xy / d, exact perspective. The camera advances, d
// shrinks, and the STREAK is the segment between the projection NOW and the
// projection one shutter-exposure earlier — so streak length is
// (off-axis distance) × (speed / d²), which falls out of the projection
// instead of being a per-layer multiplier. Near stars flare and fly off the
// edges, deep stars creep. That gradient of motion out of one vanishing
// point is what reads as "flying through", not "stars scrolling".
//
// THE SCENE SCHEDULE — worlds, meteors and the visitor are deterministic
// functions of uTime: time is cut into slots per element class, the slot
// index hashes to what appears and on what path. No state, no CPU spawner,
// and any moment is reproducible from a timestamp — which is how demo mode
// (uFlags.w, shell always passes 0) forces each element on screen for the
// proof captures.
//
//   meteors  — two lanes of ~9 s slots, ~45 % occupied, flight 1.1–1.7 s.
//              MASS-CORRELATED: a heavy bolide is bigger, slower, with a
//              wider/longer/brighter trail; a light one is a fast scratch.
//   worlds   — ~150 s slots, ~55 % occupied, one body for ~a minute. Rare
//              on purpose: a planet is an EVENT, not clutter. One in six is
//              the system's sun. Detail budget follows "bold over busy":
//              ONE body with real shading beats five confetti discs.
//   visitor  — ~330 s slots, ~38 % occupied, ~14 s on screen. An easter
//              egg you catch out of the corner of your eye, not a loop.
//
// TRAIL "RING BUFFER", WITHOUT THE BUFFER: the brief asks for trails drawn
// through a history of past positions so they follow curved paths. A
// fragment shader holds no history, but these trajectories are analytic —
// so the trail IS the history: the path (with its gravity bend) is
// re-evaluated at N past instants and the trail drawn as fading segments
// through those points. Identical behaviour, zero state, zero extra passes.
//
// PALETTE LAW: every colour is a measured rung of theme/accent.json →
// _swirl._emission.ladders — the same constants starlight3d.frag carries,
// for the same reason: a sky is emission, so it is built on the emission
// ladder. The hot/neon end the owner asked for is already IN the ladder
// (plum, coral, gold are the rose palette's warm rungs). Pure white cores
// are structure, not colour — the standing 13pu gives black/white in QML.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float uTime;
    vec2  uRes;      // item px
    vec4  uLook;     // x drift-sway · y star colour spread · z nebula gain · w master (beat rides here)
    vec4  uScene;    // x density 0..2 · y speed 0..2 · z streak length 0..2 · w quality (battery drops it)
    vec4  uFlags;    // x meteors · y worlds · z visitor · w demo (0 in the shell; see mkDemo below)
};

// ── the measured emission ladder (theme/accent.json, rungs by name) ──────
const vec3 TEAL_DEEP   = vec3(0.008, 0.384, 0.510);  // #026282
const vec3 TEAL        = vec3(0.039, 0.635, 0.839);  // #0aa2d6
const vec3 TEAL_GLOW   = vec3(0.361, 0.776, 0.918);  // #5cc6ea
const vec3 AZURE_BODY  = vec3(0.078, 0.369, 0.651);  // #145ea6
const vec3 AZURE_GLOW  = vec3(0.322, 0.627, 0.918);  // #52a0ea
const vec3 INDIGO_HAZE = vec3(0.043, 0.012, 0.220);  // #0b0338
const vec3 INDIGO_BODY = vec3(0.169, 0.078, 0.651);  // #2b14a6
const vec3 INDIGO_GLOW = vec3(0.478, 0.388, 0.941);  // #7a63f0
const vec3 VIOLET_HAZE = vec3(0.141, 0.012, 0.220);  // #240338
const vec3 VIOLET_BODY = vec3(0.431, 0.078, 0.651);  // #6e14a6
const vec3 VIOLET_GLOW = vec3(0.667, 0.431, 0.808);  // #aa6ece
const vec3 PLUM_BODY   = vec3(0.651, 0.078, 0.384);  // #a61462
const vec3 PLUM        = vec3(0.682, 0.125, 0.424);  // #ae206c
const vec3 PLUM_GLOW   = vec3(0.843, 0.396, 0.635);  // #d765a2
// the warm rungs serve exactly ONE body: the live magma sun the owner asked
// back in (2026-08-13, over the fifth reference) — nothing else may burn
const vec3 GOLD_BODY   = vec3(0.651, 0.396, 0.078);  // #a66514
const vec3 GOLD_GLOW   = vec3(0.847, 0.643, 0.392);  // #d8a464
const vec3 CORAL_BODY  = vec3(0.651, 0.118, 0.078);  // #a61e14
const vec3 CORAL       = vec3(0.804, 0.369, 0.337);  // #cd5e56

// ── hashes — no trig, same integer-mix family as the siblings ────────────
float hash11(float p) { p = fract(p * 0.1031); p *= p + 33.33; p *= p + p; return fract(p); }
vec2  hash21(float p) {
    vec3 p3 = fract(vec3(p) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}
vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i),              hash12(i + vec2(1, 0)), f.x),
               mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}

// fBm — octave count is most of the nebula's cost, so quality scales it.
float fbm(vec2 p, int oct) {
    float v = 0.0, a = 0.5;
    mat2 r = mat2(0.80, 0.60, -0.60, 0.80);   // rotate per octave: kills the grid
    for (int i = 0; i < 6; i++) {
        if (i >= oct) break;
        v += a * vnoise(p);
        p = r * p * 2.03 + 11.7;
        a *= 0.55;
    }
    return v;
}

// Distance to segment ab; h returns the position along it (0 at a, 1 at b)
// so callers can taper — the streak primitive for stars and trails alike.
float segDist(vec2 p, vec2 a, vec2 b, out float h) {
    vec2 pa = p - a, ba = b - a;
    h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-8), 0.0, 1.0);
    return length(pa - ba * h);
}

// ── star temperature → colour ─────────────────────────────────────────────
// A real field is mostly ice-white with colour as the exception. The ramp
// walks the ladder: teal/azure at the cold end, gold at the warm end, the
// rare coral ember at the very tip. `spread` (uLook.y) widens the ends.
// Two hues do all the work (final style spec): the field runs white→teal
// on the cold side and white→plum/violet on the "warm" side. Actual warmth
// belongs to the galaxy core alone.
vec3 starColor(float temp, float spread) {
    float t = clamp(0.5 + (temp - 0.5) * (0.6 + 0.8 * spread), 0.0, 1.0);
    vec3 cool = mix(vec3(1.0), TEAL_GLOW,  smoothstep(0.50, 0.05, t));
    cool      = mix(cool,      AZURE_GLOW, smoothstep(0.30, 0.00, t) * 0.6);
    vec3 warm = mix(vec3(1.0), PLUM_GLOW,  smoothstep(0.50, 0.90, t));
    warm      = mix(warm,      VIOLET_GLOW, smoothstep(0.86, 1.00, t) * 0.7);
    return t < 0.5 ? cool : warm;
}

// spray droplets, two cell scales — dots, not noise. The can texture of the
// owner's reference piece: glowing flecks blown off every hot stroke.
float spatter(vec2 p, float density) {
    float acc = 0.0;
    for (int s = 0; s < 2; s++) {
        float fs = (s == 0 ? 42.0 : 90.0);
        vec2 cell = floor(p * fs);
        vec2 h = hash22(cell * 1.31 + float(s) * 7.0);
        if (h.x < density * (s == 0 ? 0.55 : 0.35)) {
            vec2 dp = fract(p * fs) - h;
            float r = 0.10 + 0.26 * hash12(cell + float(s) * 13.0);
            acc = max(acc, smoothstep(r, r * 0.55, length(dp)));
        }
    }
    return acc;
}

float gExposure;    // the streak shutter, set once in main
vec2  gVP;          // vanishing point in centered aspect coords
float gCov;         // output alpha: how much this layer OCCLUDES the Swirl
                    // nebula composited beneath it (bodies ~1, empty sky 0)
float gAspect;      // width/height — a BAR strip can be 12:1, and layout
                    // must spread along it or everything bunches mid-bar
float gSpread;      // x-multiplier for scheduled elements in bar mode

// ═══════════════════════ THE DUST FIELD ══════════════════════════════════
// The infinite shells: thousands of pinpoint micro-stars, one hash dot per
// cell, no neighbourhood scan and next to no streak — they are too deep to
// smear. This is the fine speckle the owner's reference is saturated with,
// and it rides the SAME projection as the darts, so even the dust drifts
// out of the vanishing point instead of hanging as a static texture.
vec3 dustField(vec2 sp, float travel, float t) {
    vec3 acc = vec3(0.0);
    for (int k = 0; k < 2; k++) {
        float seed  = 17.0 + float(k) * 9.4;
        float phase = hash11(seed * 7.31);
        float d = 1.0 - fract(travel * 0.35 + phase);     // deep shells crawl
        float env = smoothstep(1.0, 0.9, d) * smoothstep(0.0, 0.15, d);
        if (env < 0.01) continue;

        float grid = 9.0 + 4.0 * hash11(seed);
        vec2  w    = sp * d * grid + seed * 61.7;
        vec2  cell = floor(w);
        vec2  jit  = hash22(cell * 1.13 + seed);
        float dist = length(fract(w) - jit) / grid / max(d, 0.2);

        float lum = hash12(cell * 3.7 + seed);
        if (lum < 0.22) continue;                          // dense — the reference is saturated with speckle
        float r = 0.0022 * (0.4 + lum);
        float g = exp(-dist * dist / (r * r));
        float tw = 0.6 + 0.4 * vnoise(vec2(t * 0.9 + lum * 7.0, cell.x + cell.y));
        vec3 c = mix(vec3(0.9), starColor(hash12(cell * 5.1 + seed), 0.8), 0.5);
        acc += c * g * env * tw * 0.35;
    }
    return acc;
}

// ═══════════════════════ THE STARFIELD ═══════════════════════════════════
// One depth shell of the flight per call. Each shell owns its own lattice
// scale and wrap phase, so shells never blink in sync. Depth d cycles 1→0
// as the camera advances; screen position is lattice_xy / d — exact
// perspective, which is the point of the whole file.
vec3 layerField(vec2 sp, float seed, float travel, float density, float t) {
    vec3 acc = vec3(0.0);

    float phase = hash11(seed * 7.31);
    float d = 1.0 - fract(travel + phase);            // 1 far → 0 at the eye

    // Wrap fade: fade IN over the first 12 % of a star's life and OUT over
    // the last 8 % — without both ends the wrap pops, and a popping star
    // reads as a dead pixel.
    float env = smoothstep(1.0, 0.88, d) * smoothstep(0.0, 0.08, d);
    if (env < 0.002) return acc;

    float grid = mix(2.2, 5.5, hash11(seed * 3.77));  // cells per world unit
    vec2  w    = sp * d;                              // lattice xy at this depth
    vec2  base = floor(w * grid + seed * 61.7);

    // 3×3 neighbourhood: a streak crosses cell borders, so the star that
    // owns this pixel may live one cell over.
    for (int oy = -1; oy <= 1; oy++)
    for (int ox = -1; ox <= 1; ox++) {
        vec2  cell = base + vec2(float(ox), float(oy));
        float own  = hash12(cell + seed);
        // the density dial moves star COUNT, never star brightness
        if (own > density) continue;

        vec2  jit  = hash22(cell * 1.13 + seed * 5.19);
        vec2  swld = (cell + jit - seed * 61.7) / grid;

        // exact projection now, and one shutter-exposure ago (the camera
        // was gExposure deeper then)
        vec2  pNow  = swld / max(d,             1e-4);
        vec2  pPrev = swld / max(d + gExposure, 1e-4);

        float h;
        float dist = segDist(sp, pNow, pPrev, h);

        // apparent size: per-star luminosity, radius ∝ 1/d, clamped so the
        // deep field stays sub-pixel sharp
        float lum  = 0.35 + 1.3 * pow(hash12(cell * 3.7 + seed), 4.0);
        float core = min((0.0026 + 0.0038 * lum) / max(d, 0.05), 0.055);

        // comet profile: tight core, wide faint halo, tail (h→1 is the old
        // position) tapering to nothing — this is the motion blur
        float taper = 1.0 - h * 0.85;
        float body  = core * taper;
        float g     = exp(-dist * dist / max(body * body, 1e-9));
        float halo  = exp(-dist * dist / max(body * body * 34.0, 1e-8)) * 0.10;

        // twinkle: slow fBm-driven scintillation per star — statistical,
        // never synchronized, and it never takes a star fully dark
        float tw = 0.72 + 0.28 * vnoise(vec2(t * (0.6 + 0.8 * hash12(cell * 5.5 + seed)),
                                             hash12(cell * 7.7 + seed) * 90.0));

        // perspective brightness: 1/d² attenuation, normalised so the mid
        // field carries the picture and the near field flares as it passes
        float bright = lum * env * tw * 0.55 / (0.25 + d * d * 3.0);

        // NEON, per the owner's reference: every streak is a tube of light —
        // near-white core inside a coloured halo, the way the piece's
        // letters carry a hot core inside the violet stroke.
        vec3 col = starColor(hash12(cell * 9.1 + seed * 2.3), uLook.y);
        acc += (vec3(0.98) * g * 0.75 + col * (g * 0.25 + halo * 3.4)) * bright;

        // the DOUBLE STROKE — the reference letters run a thin echo line
        // beside the main stroke. Only the fat near darts earn one.
        if (core > 0.016) {
            vec2 dirS = pPrev - pNow;
            vec2 perp = normalize(vec2(-dirS.y, dirS.x) + 1e-6);
            float h2;
            float dist2 = segDist(sp - perp * core * 2.8, pNow, pPrev, h2);
            float w2 = body * 0.35;
            acc += col * exp(-dist2 * dist2 / max(w2 * w2, 1e-9)) * bright * 0.5;
        }
    }
    return acc;
}

// ═══════════════════════ THE WORLDS ══════════════════════════════════════
// One body at a time, drifting past over ~a minute. All shading is closed
// form on the disc: the visible hemisphere's normal comes straight from the
// circle (nz = √(1−x²−y²)), lambert against ONE scene-wide sun, soft
// terminator, atmosphere rim, and surface detail evaluated in the BODY'S
// OWN FRAME (n2-space), never screen space — so the tilt carries the bands
// and the shading stays glued to the sphere.

// Crater field — the normal-mapping trick, not geometry: each crater is a
// radial profile whose GRADIENT perturbs the sphere normal, so the rim
// facing the sun darkens and the far rim catches light, exactly how a
// crater reads in a photograph. TWO bold craters, not a dozen tiny ones —
// at bar scale a dozen is noise, two is "a cratered moon".
vec3 craterPerturb(vec2 lp, float seedv, out float albedoCut) {
    vec2  grad = vec2(0.0);
    albedoCut  = 0.0;
    for (int i = 0; i < 2; i++) {
        vec2  cc = (hash21(seedv * 3.1 + float(i) * 17.0) - 0.5) * 1.1;
        float cr = 0.16 + 0.14 * hash11(seedv * 7.7 + float(i));
        vec2  dq = lp - cc;
        float rr = length(dq) / cr;
        if (rr > 1.4) continue;
        // profile: bowl (in) + raised rim (out) — its slope is the normal kick
        float bowl = smoothstep(1.0, 0.35, rr);                     // 1 centre → 0 rim
        float rim  = smoothstep(1.25, 1.0, rr) * smoothstep(0.75, 1.0, rr);
        float slope = rim * 2.2 - bowl * 1.4;
        grad += normalize(dq + 1e-5) * slope * 0.35;
        albedoCut = max(albedoCut, bowl * 0.35 + rim * 0.15);
    }
    return vec3(grad, 0.0);
}

// banded giants vs rocky/icy surfaces, in body-frame coordinates
float surfDetail(vec2 lp, float kind, float seedv) {
    if (kind < 0.5) {
        float shear = fbm(lp * vec2(1.6, 5.0) + seedv, 4) * 0.8;    // weather curl
        return fbm(lp * vec2(1.2, 7.5) + vec2(shear, seedv), 4);
    }
    float m = fbm(lp * 3.2 + seedv * 3.0, 4);
    float maria = smoothstep(0.55, 0.75, fbm(lp * 1.4 + seedv * 9.0, 3));
    return m * (1.0 - maria * 0.45);
}

vec3 drawWorld(vec2 sp, float t, float demo, float demoScale, out float occl) {
    occl = 0.0;
    vec3 acc = vec3(0.0);

    const float SLOT = 150.0;
    float slot = floor(t / SLOT);
    float ft   = fract(t / SLOT);
    float gate = hash11(slot * 17.93 + 4.2);
    if (demo > 0.5) { ft = 0.45; gate = 0.0; slot = 7.0; }
    if (gate > 0.55) return acc;
    bool demoSun = uFlags.w == 7.0;                   // proof shot for the magma sun                      // an empty slot — most are
    float life = smoothstep(0.08, 0.28, ft) * smoothstep(0.92, 0.72, ft);
    if (life < 0.003) return acc;

    vec2 rnd  = hash21(slot * 3.71);
    vec2 rnd2 = hash21(slot * 9.13 + 5.0);

    // the path: born near the vanishing point, drifting outward and growing
    // as we overtake it — the geometry of passing something far away
    float ang  = rnd.x * 6.2831853;
    vec2  dir  = vec2(cos(ang), sin(ang) * 0.6);      // the sky is wider than tall
    vec2  c    = gVP + dir * (0.12 + ft * 1.15);
    // GENUINELY FAR (clarification #1): small against the frame, and it is
    // never scaled up for legibility — at bar scale the answer is simpler
    // detail, not a bigger disc
    float R    = (0.030 + rnd.y * 0.075) * (0.55 + ft * 0.9);
    // demo modes ≥ 8: the BAR FILL (owner, over his own bar: "I want it
    // full — planets, galaxies, moons, shooting stars"). Each index is one
    // slot of a lattice along the strip: hashed x-jitter, hashed height,
    // hashed size, hashed kind — ten bodies that read as a crowded sky,
    // laid out in fractions of the strip's aspect so any bar works.
    // 7 parks the sun; 1-6 park the prominent planet.
    if (demo > 7.5) {
        float bi = demo - 8.0;                          // slot 0..15
        vec2  hb = hash21(bi * 17.3 + 4.1);
        // CLUMPS AND GAPS, not a necklace: wide jitter lets neighbours
        // overlap into groups and leaves real emptiness between them, and
        // the full bar height is used
        float xf = -0.90 + (bi + 0.5) * 0.1125 + (hb.x - 0.5) * 0.30;
        c = vec2(xf * gAspect, clamp((hb.y - 0.5) * 1.6, -0.82, 0.82));
        // hard size hierarchy: two anchors, a band of mediums, many tiny
        float roll = hash11(bi * 7.7 + 2.2);
        R = roll > 0.87 ? 0.50 + 0.14 * hash11(bi + 3.0)
          : roll > 0.55 ? 0.17 + 0.14 * roll
                        : 0.06 + 0.09 * roll;
    }
    else if (demo > 6.5) { c = gVP + vec2(-0.85, 0.22); R = 0.155; }
    else if (demo > 0.5) { c = gVP + vec2(0.34, 0.10);  R = 0.19;  }
    R *= demoScale;

    // The LIVE MAGMA SUN is back on the owner's word (it left under the
    // no-magma clarification, then returned over his fifth reference).
    // One in six natural worlds is the sun; every other body stays cool.
    float kind  = hash11(slot * 29.7);
    bool  isSun = kind > 0.84;
    bool  ringed = !isSun && kind > 0.52;
    bool  giant  = !isSun && kind > 0.30;
    // the SWIRL PLANET (owner: "a ball that the swirls are in and just
    // swirl around") — a body whose surface is the neon fluid itself
    bool  swirly = !isSun && kind > 0.72 && kind <= 0.84;
    if (swirly) { ringed = false; giant = false; }
    if (demo > 7.5) {
        // bar slots hash their kind — exactly one sun (slot 0), the rest
        // a mix of swirl balls, ringed giants, gas giants and rockies
        float bi = demo - 8.0;
        float bk = hash11(bi * 23.9 + 9.7);
        isSun  = bi < 0.5;
        swirly = !isSun && bk > 0.70;
        ringed = !isSun && !swirly && bk > 0.42;
        giant  = !isSun && !swirly && bk > 0.18;
    }
    else if (demo > 6.5) { isSun = true;  swirly = false; }
    else if (demo > 0.5) { isSun = false; swirly = false; ringed = true; giant = true; }
    float seedv = slot * 13.7 + 3.1 + floor(demo) * 5.7;   // bar bodies differ

    vec2  q = sp - c;
    float r = length(q);
    if (r > R * 3.2) return acc;                      // outside everything, ring included

    // ── the sun — A BALL OF LIVE MAGMA: magma.frag's construction on the
    // sphere. Dark crust rafts separated by branching molten rivers
    // walking the black-body ramp, the one warm object in the sky.
    if (isSun) {
        R *= 0.8;
        float disc = smoothstep(R, R * 0.94, r);
        vec2 mp = q / R * 2.1 + seedv;
        vec2 qw = vec2(fbm(mp * 1.2 + t * 0.020, 3),
                       fbm(mp * 1.2 + 5.2 - t * 0.015, 3));
        float riv = 0.0;
        {   // 3-octave ridged channel — magma.frag's rivers, inlined
            vec2 rp = mp * 1.1 + 2.0 * qw;
            float a = 0.55;
            mat2 m2 = mat2(0.80, 0.60, -0.60, 0.80);
            for (int i = 0; i < 3; i++) {
                float nn = 1.0 - abs(2.0 * vnoise(rp) - 1.0);
                riv += a * nn * nn;
                rp = m2 * rp * 2.13 + 7.7;
                a *= 0.52;
            }
        }
        float melt = smoothstep(0.42, 0.60, riv);
        float tmp  = pow(melt, 1.3) * (0.85 + 0.30 * fbm(mp * 5.0 + t * 0.25, 2));
        vec3 ph = mix(vec3(0.055, 0.020, 0.014), vec3(0.150, 0.058, 0.030),
                      fbm(mp * 3.5 + qw * 1.5, 3));
        ph += CORAL_BODY * smoothstep(0.30, 0.55, riv) * (1.0 - melt) * 0.55;
        ph = mix(ph, CORAL_BODY, smoothstep(0.05, 0.35, tmp));
        ph = mix(ph, GOLD_BODY,  smoothstep(0.30, 0.60, tmp));
        ph = mix(ph, GOLD_GLOW,  smoothstep(0.55, 0.85, tmp));
        ph = mix(ph, vec3(1.02, 0.97, 0.86), smoothstep(0.82, 0.98, tmp));
        ph *= 0.50 + 0.50 * sqrt(max(1.0 - (r / R) * (r / R), 0.0));
        acc += ph * disc * life;
        // corona: a tight blaze and a long veil, streamers round the limb
        float cor  = exp(-(r - R) * 9.0 / R) * step(R, r);
        float veil = exp(-(r - R) * 2.2 / R) * step(R, r);
        float strm = 0.6 + 0.4 * vnoise(vec2(atan(q.y, q.x) * 3.2, t * 0.02) + seedv);
        acc += (GOLD_GLOW * cor * 0.9 + mix(GOLD_BODY, CORAL, 0.35) * veil * 0.30) * strm * life;
        occl = disc * life;
        return acc;
    }

    // ── the SWIRL PLANET — the fluid as a world ─────────────────────────
    // Neon dye churning on a sphere: the same two-generation domain warp
    // the magma runs, at swirl speed, walking the emission ladder's hot
    // rungs. It reads as a storm in a glass ball.
    if (swirly) {
        float disc = smoothstep(R, R * 0.97, r);
        if (disc > 0.001) {
            vec2  n2 = q / R;
            float nz = sqrt(max(1.0 - dot(n2, n2), 0.0));
            vec2  mp = n2 * (0.6 + 0.4 * nz) * 1.7 + seedv;
            vec2  qw = vec2(fbm(mp * 1.1 + t * 0.055, 3),
                            fbm(mp * 1.1 + 5.2 - t * 0.045, 3));
            float sw = fbm(mp * 1.5 + 2.5 * qw + vec2(t * 0.07, 0.0), 4);
            // two temperaments of storm ball: plum-hot and teal-cold
            bool coldBall = hash11(seedv * 4.9) > 0.55;
            vec3 ph;
            if (coldBall) {
                ph = mix(INDIGO_BODY * 0.40, AZURE_BODY, smoothstep(0.18, 0.50, sw));
                ph = mix(ph, TEAL,      smoothstep(0.45, 0.70, sw));
                ph = mix(ph, TEAL_GLOW, smoothstep(0.66, 0.88, sw));
                ph = mix(ph, vec3(0.92, 0.97, 1.0), smoothstep(0.88, 0.98, sw) * 0.6);
            } else {
                ph = mix(INDIGO_BODY * 0.45, VIOLET_BODY, smoothstep(0.18, 0.50, sw));
                ph = mix(ph, PLUM,      smoothstep(0.45, 0.70, sw));
                ph = mix(ph, PLUM_GLOW, smoothstep(0.66, 0.86, sw));
                ph = mix(ph, TEAL_GLOW, smoothstep(0.86, 0.97, sw) * 0.75);
            }
            float lam = clamp(dot(vec3(n2, nz), normalize(vec3(-0.72, 0.34, 0.60))), 0.0, 1.0);
            ph *= 0.45 + 0.55 * lam;
            acc += ph * disc * life;
            // neon rim — the storm glows at its own limb
            acc += PLUM_GLOW * pow(1.0 - nz, 2.6) * disc * 0.55 * life;
            acc += PLUM_GLOW * exp(-(r - R) * 22.0 / R) * step(R, r) * 0.30 * life;
            occl = max(occl, disc * life);
        }
        return acc;
    }

    // ── the planet ───────────────────────────────────────────────────────
    // ONE sun for the whole scene — worlds, meteors and the visitor agree
    // where the light is: frame left, slightly high, out of the screen.
    vec3 L = normalize(vec3(-0.72, 0.34, 0.60));
    float tilt = (rnd2.x - 0.5) * 0.9;
    mat2 rot = mat2(cos(tilt), -sin(tilt), sin(tilt), cos(tilt));
    vec2 lq = rot * q;

    float disc = smoothstep(R, R * 0.985, r);         // a crisp limb that still AA's
    if (disc > 0.001) {
        vec2  n2 = lq / R;
        float nz = sqrt(max(1.0 - dot(n2, n2), 0.0));
        vec3  N  = vec3(n2, nz);

        // surface detail in the body's frame — a cheap equal-ish area unwrap
        vec2  lp  = n2 * (0.5 + 0.5 * nz) * (0.75 + 0.85 * hash11(seedv * 9.3));
        float det = surfDetail(lp, giant ? 0.0 : 1.0, seedv);
        // the fine octave, then the CARVE: a ridged channel cut hard into
        // the value — the deep-relief look of the owner's second reference,
        // rock that reads carved rather than airbrushed
        det = det * 0.80 + fbm(lp * 8.5 + seedv * 5.0, 2) * 0.30;
        float carve = 1.0 - abs(2.0 * fbm(lp * vec2(2.2, 4.6) + seedv * 7.0, 3) - 1.0);
        det -= pow(carve, 3.5) * 0.35;

        // craters (rocky worlds only): perturb the normal, cut the albedo
        float albedoCut = 0.0;
        if (!giant) {
            N = normalize(N + craterPerturb(lp, seedv, albedoCut));
        }

        float lam  = clamp(dot(N, L), 0.0, 1.0);
        float term = smoothstep(0.0, 0.24, lam);      // soft terminator

        // FIVE palette families (owner: "planets all need to be different")
        // — ocean-azure, ice-teal, storm-violet, plum dusk, deep indigo —
        // seeded per body, so the collage never repeats a skin
        float hue = hash11(slot * 41.3 + floor(demo) * 3.3);
        vec3 dayA, dayB;
        if      (hue < 0.20) { dayA = AZURE_BODY;  dayB = TEAL;        }
        else if (hue < 0.40) { dayA = TEAL_DEEP;   dayB = TEAL_GLOW;   }
        else if (hue < 0.60) { dayA = VIOLET_BODY; dayB = PLUM_BODY;   }
        else if (hue < 0.80) { dayA = PLUM_BODY;   dayB = VIOLET_HAZE * 1.7; }
        else                 { dayA = INDIGO_BODY; dayB = AZURE_BODY;  }
        // hard surface contrast + a per-body VALUE roll: some worlds pale
        // and luminous, some near-silhouette — value separation is what
        // makes a crowd read as individuals
        vec3 day  = mix(dayA, dayB, det) * (0.40 + 0.75 * det);
        day *= 0.55 + 1.05 * hash11(seedv * 11.7);
        day *= 1.0 - albedoCut;                       // crater floors sit darker
        if (!giant) day += TEAL_GLOW * pow(lam, 14.0) * 0.25 * smoothstep(0.6, 0.9, det);

        vec3 night = INDIGO_HAZE * 0.5;               // the dark side, barely there
        vec3 srf = mix(night, day, term);
        srf *= 0.35 + 0.65 * lam;

        acc += srf * disc * life;
        occl = max(occl, disc * life);

        // atmosphere: fresnel rim on the day side, in the world's glow rung,
        // plus a thin lit halo just OUTSIDE the limb — light through gas
        // ICY atmosphere, not neon: the rim leans toward the star field's
        // own white so the body and the sky share one light
        vec3 rim = mix(hue < 0.33 ? TEAL_GLOW : (hue < 0.66 ? INDIGO_GLOW : PLUM_GLOW),
                       vec3(0.88, 0.92, 1.0), 0.55);
        float fres = pow(1.0 - nz, 2.5) * term;
        acc += rim * fres * disc * 0.95 * life;
        // the night limb keeps a whisper of atmosphere — without it the
        // dark side reads as a bite out of the nebula, not a sphere
        acc += rim * pow(1.0 - nz, 3.5) * (1.0 - term) * disc * 0.10 * life;
        float halo = exp(-(r - R) * 26.0 / R) * step(R, r)
                   * smoothstep(-0.2, 0.6, dot(normalize(vec3(q, 0.001)), L));
        acc += rim * halo * 0.6 * life;
    }

    // ── the ring ─────────────────────────────────────────────────────────
    if (ringed) {
        float inc = 0.16 + rnd2.y * 0.22;             // inclination: how edge-on
        vec2  rq  = vec2(lq.x, lq.y / inc);
        float rr  = length(rq) / R;                   // in planet radii
        float band = smoothstep(1.35, 1.41, rr) * smoothstep(2.25, 2.15, rr);
        if (band > 0.001) {
            // grooves at three frequencies + the Cassini-style gap
            float gr = 0.55 + 0.45 * vnoise(vec2(rr * 26.0, seedv));
            gr *= 0.7 + 0.3 * vnoise(vec2(rr * 90.0, seedv * 2.0));
            band *= 1.0 - 0.8 * smoothstep(0.035, 0.0, abs(rr - 1.78));
            // the planet hides the far lobe and shadows the near one
            float behind = step(r, R) * step(0.0, lq.y);
            band *= 1.0 - behind;
            float shadow = smoothstep(0.35, 0.0, abs(lq.x) / R) * step(lq.y, 0.0) * 0.75;
            // the ring keeps its metal: gold through plum, never grey
            // three ring metals, hashed per body: pale silver (the real-ice
            // read), violet-dusted, teal-dusted — variety without neon
            float rcv = hash11(seedv * 6.1);
            vec3 ringC = rcv < 0.45 ? vec3(0.58, 0.56, 0.66) * 0.72
                       : rcv < 0.75 ? mix(VIOLET_GLOW, vec3(0.60), 0.45) * 0.62
                                    : mix(TEAL_GLOW,   vec3(0.60), 0.50) * 0.58;
            acc += ringC * band * gr * (1.0 - shadow) * 0.65 * life;
            occl = max(occl, band * 0.6 * life);
        }
    }

    return acc;
}


// ═══════════════════════ THE MOONS ═══════════════════════════════════════
// Two small companions on long slow arcs above the hero — always somewhere,
// never in the same place, shaded like every other body in the scene.
vec3 moons(vec2 sp, float t, int oct) {
    vec3 acc = vec3(0.0);
    vec3 L = normalize(vec3(-0.35, 0.55, 0.75));
    int mc = gSpread > 1.5 ? 5 : 2;                   // a wide bar earns more moons
    for (int i = 0; i < 5; i++) {
        if (i >= mc) break;
        float fi = float(i);
        float ph = t * (0.011 - fi * 0.002) + fi * 2.7;
        vec2  c  = vec2((fract(fi * 0.41 + 0.13) - 0.5) * 1.7 * gSpread,
                        (fract(fi * 0.67 + 0.29) - 0.5) * 0.8)
                 + vec2(cos(ph), sin(ph) * 0.4) * (0.14 + fract(fi * 0.53) * 0.08);
        float R  = 0.016 + 0.020 * hash11(fi * 3.3 + 1.1);
        vec2 q = sp - c;
        if (dot(q, q) > R * R * 2.6) continue;
        q += (vec2(vnoise(q * 30.0 + fi), vnoise(q * 30.0 + fi + 40.0)) - 0.5) * R * 0.03;
        float r = length(q);
        float disc = smoothstep(R, R * 0.95, r);
        if (disc < 0.003) continue;
        vec2  n2 = q / R;
        float nz = sqrt(max(1.0 - dot(n2, n2), 0.0));
        float lam = clamp(dot(vec3(n2, nz), L), 0.0, 1.0);
        float m = fbm(n2 * 5.0 + fi * 9.0, 3);
        float crat = smoothstep(0.30, 0.18, length(n2 - vec2(0.25 - fi * 0.5, 0.2)));
        // stencil moons: dark graphic body, one bright rim edge
        vec3 srf = mix(VIOLET_HAZE * 0.9, vec3(0.42, 0.36, 0.52), m) * (0.14 + 0.30 * lam);
        srf *= 1.0 - crat * 0.30;
        acc += srf * disc;
        acc += mix(PLUM_GLOW, TEAL_GLOW, fi) * pow(1.0 - nz, 2.4)
               * smoothstep(0.1, 0.7, lam) * disc * 0.9;
    }
    return acc;
}

// ═══════════════════════ THE ASTEROIDS ═══════════════════════════════════
// The debris the second reference is full of: small craggy rocks at mid
// depth, more frequent than the worlds, drifting out of the vanishing
// point and growing as we overtake them. The silhouette itself is wobbled
// at rock scale, so they read as carved lumps, not marbles.
vec3 asteroids(vec2 sp, float t, float demo, inout float occl) {
    vec3 acc = vec3(0.0);
    vec3 L = normalize(vec3(-0.72, 0.34, 0.60));
    int alanes = gSpread > 1.5 ? 5 : 3;               // more debris on a wide strip
    for (int lane = 0; lane < 5; lane++) {
        if (lane >= alanes) break;
        float ln = float(lane);
        const float SLOT = 35.0;
        float lt   = t + ln * 12.7;
        float slot = floor(lt / SLOT);
        float ft   = fract(lt / SLOT);
        float gate = hash11(slot * 23.1 + ln * 7.7);
        if (demo > 0.5) { ft = 0.42 + 0.17 * ln; gate = 0.0; slot = 4.0 + ln * 3.0; }
        if (gate > 0.5) continue;

        vec2 rnd  = hash21(slot * 9.7 + ln * 3.3);
        vec2 rnd2 = hash21(slot * 17.3 + ln * 29.0);

        // born off-centre, drifting away from the VP and growing — the same
        // overtake geometry the worlds fly, at a faster clip
        vec2  start = gVP + (rnd - 0.5) * vec2(1.6 * gSpread, 1.1);
        vec2  dir   = normalize(start - gVP + 1e-3);
        vec2  pos   = start + dir * ft * 0.85;
        float R     = (0.013 + rnd2.x * 0.030) * (0.55 + ft * 0.9);
        float life  = smoothstep(0.0, 0.10, ft) * smoothstep(1.0, 0.85, ft);
        if (life < 0.05) continue;

        vec2 q = sp - pos;
        if (dot(q, q) > R * R * 4.0) continue;
        // craggy silhouette: the edge itself is rock
        q += (vec2(vnoise(q * 9.0 / R + slot), vnoise(q * 9.0 / R + slot + 40.0)) - 0.5)
             * R * 0.30;
        float r = length(q);
        float disc = smoothstep(R, R * 0.94, r);
        if (disc < 0.003) continue;

        vec2  n2 = q / R;
        float nz = sqrt(max(1.0 - dot(n2, n2), 0.0));
        float lam = clamp(dot(vec3(n2, nz), L), 0.0, 1.0);

        // carved relief, hard: a ridged channel cut into the rock value
        float rel   = fbm(n2 * 5.0 + slot * 1.7, 3);
        float carve = 1.0 - abs(2.0 * fbm(n2 * vec2(3.0, 6.0) + slot * 3.1, 3) - 1.0);
        float v = (0.35 + 0.65 * rel) * (0.30 + 0.70 * lam) - pow(carve, 3.0) * 0.4;

        vec3 rock = mix(VIOLET_HAZE * 0.8, vec3(0.36, 0.30, 0.47), clamp(v, 0.0, 1.0));
        rock = mix(rock, PLUM_BODY * 0.35, smoothstep(0.6, 0.9, rel) * 0.4);
        acc += rock * disc * life;
        // teal rim on the lit side — the same nebula light every body wears
        acc += TEAL_GLOW * pow(1.0 - nz, 3.0) * lam * disc * 0.35 * life;
        occl = max(occl, disc * life * 0.8);
    }
    return acc;
}

// ═══════════════════════ THE GALAXY (real one this time) ═════════════════
// The owner cut the cartoon spiral and later asked for "a real looking
// galaxy" — which is not arms and a core, it is a soft inclined DISC: an
// elongated glow, brighter toward a slightly warm centre, with a dark dust
// lane crossing it. Photograph language, three gaussians and a stripe.
vec3 galaxyDiscAt(vec2 sp, float t, vec2 c, float ang, float sc) {
    mat2 rot = mat2(cos(ang), -sin(ang), sin(ang), cos(ang));
    vec2 g = rot * (sp - c) / sc;
    float body = exp(-(g.x * g.x) / (0.85 * 0.85) - (g.y * g.y) / (0.16 * 0.16));
    float core = exp(-(g.x * g.x) / (0.22 * 0.22) - (g.y * g.y) / (0.075 * 0.075));
    if (body < 0.004) return vec3(0.0);
    // the dust lane: a dark stripe just under the major axis
    float lane = exp(-(g.y - 0.035) * (g.y - 0.035) / (0.030 * 0.030))
               * smoothstep(0.9, 0.2, abs(g.x));
    // grain along the disc — unresolved stars, not smooth fog
    float grain = 0.75 + 0.5 * vnoise(g * vec2(26.0, 90.0));
    vec3 col = mix(INDIGO_GLOW * 0.30, VIOLET_GLOW * 0.34, 0.5) * body;
    col += vec3(0.92, 0.88, 0.90) * core * 0.55;      // faintly warm heart
    col *= (1.0 - lane * 0.65) * grain;
    // star speckle riding the disc
    col += vec3(0.9) * spatter(g * vec2(1.2, 3.0) + 51.0, body * 0.7) * 0.4;
    return col;
}

// star-cluster knots and beacon stars — the extra furniture a genuinely
// busy sky carries: tight glowing clumps of unresolved stars, and a few
// brilliant individuals with diffraction crosses
vec3 starClusters(vec2 sp, float t) {
    vec3 acc = vec3(0.0);
    for (int i = 0; i < 3; i++) {
        vec2 h = hash21(float(i) * 9.1 + 3.3);
        vec2 c = vec2((h.x - 0.5) * 1.7 * gSpread, (h.y - 0.5) * 0.9);
        vec2 d = sp - c;
        float g = exp(-dot(d, d) * 26.0);
        if (g < 0.01) continue;
        acc += vec3(0.80, 0.85, 1.00) * g * 0.22;
        acc += vec3(0.95) * spatter(d * 3.0 + float(i) * 7.0, g * 1.3) * 0.9;
    }
    for (int i = 0; i < 2; i++) {
        vec2 h = hash21(float(i) * 23.7 + 8.9);
        vec2 c = vec2((h.x - 0.5) * 1.5 * gSpread, (h.y - 0.5) * 0.7);
        vec2 d = sp - c;
        if (dot(d, d) > 0.09) continue;
        float tw = 0.8 + 0.25 * vnoise(vec2(t * 1.3, float(i) * 9.0));
        float core = exp(-dot(d, d) * 2600.0);
        float spike = exp(-abs(d.x) * 260.0) * exp(-abs(d.y) * 26.0)
                    + exp(-abs(d.y) * 260.0) * exp(-abs(d.x) * 26.0);
        acc += (vec3(0.98) * core * 2.2 + TEAL_GLOW * spike * 0.55) * tw;
    }
    return acc;
}

vec3 galaxyDisc(vec2 sp, float t) {
    // one galaxy in a normal frame; a wide strip carries THREE, tilted and
    // tinted differently — violet, teal-leaning, plum-leaning
    vec3 acc = galaxyDiscAt(sp, t,
        vec2(0.62 * gAspect, 0.30 + 0.04 * vnoise(vec2(t * 0.01, 3.0))), -0.32, 1.0);
    if (gSpread > 1.5) {
        acc += galaxyDiscAt(sp, t, vec2(-0.38 * gAspect, -0.30), 0.55, 0.6)
               * vec3(0.75, 0.95, 1.05);
        acc += galaxyDiscAt(sp, t, vec2(0.06 * gAspect, 0.42), -0.75, 0.45)
               * vec3(1.05, 0.80, 0.95);
    }
    return acc;
}

// ═══════════════════════ THE METEORS ═════════════════════════════════════
// Sparse, angled ACROSS the frame — deliberately not radial: the starfield
// owns the radial motion, and a meteor cutting its own line through it is
// what makes both readable. Mass drives everything, one number: size,
// speed (heavier = slower), trail width, length and brightness — the
// correlation that makes a size range read as physics, not random sprites.
// The path carries a slight gravity bend, and the trail is drawn through
// the path's own recent history (see the header) so it follows the curve.
vec2 meteorPos(vec2 a, vec2 v, vec2 gpull, float tt) {
    return a + v * tt + gpull * tt * tt;              // the analytic trajectory
}

// One meteor, complete: mass-correlated head + curved history trail + paint
// drips + head spray. Factored out so the sporadic lanes and the SHOWER
// volleys render through the identical physics — a shower is many of the
// same true thing, not a cheaper particle.
vec3 oneMeteor(vec2 sp, vec2 a, vec2 v, vec2 gpull, float tt, float mt,
               float mass, bool hot, float seed) {
    vec3 acc = vec3(0.0);
    vec2 head = meteorPos(a, v, gpull, tt);
    if (length(sp - head) > 0.9) return acc;          // far from the whole event

    {
        float headR = mix(0.0035, 0.0095, mass);
        float trailT = mix(0.10, 0.26, mass);
        float envl = smoothstep(0.0, 0.08, mt) * smoothstep(1.0, 0.85, mt);
        float slot = seed;
        float ln = seed * 0.37;

        // both meteor families stay cool (clarification #2): the "hot" one
        // burns plum-magenta instead of coral — vivid, never molten
        vec3 headC = vec3(1.0);
        vec3 tailC = hot ? PLUM_GLOW : TEAL_GLOW;
        vec3 wakeC = hot ? PLUM      : VIOLET_GLOW;

        // THE TRAIL — six segments through the trajectory's recent past,
        // fading and thinning backward; because each point is the real path
        // at a real earlier time, the trail bends with the gravity pull
        const int SEGS = 6;
        vec2 pPrev = head;
        for (int s = 1; s <= SEGS; s++) {
            float fs   = float(s) / float(SEGS);
            vec2  pS   = meteorPos(a, v, gpull, max(tt - trailT * fs, 0.0));
            float h;
            float dist = segDist(sp, pS, pPrev, h);
            float age  = fs - (1.0 / float(SEGS)) * h;      // 0 head → 1 oldest
            float wdt  = headR * mix(1.0, 0.25, age);       // thins backward
            float fade = pow(1.0 - age, 2.0);
            float spark = 0.75 + 0.5 * vnoise(vec2(age * 40.0 + slot * 7.0, ln * 9.0));
            vec3  col  = mix(wakeC, tailC, pow(1.0 - age, 1.5));
            acc += col * exp(-dist * dist / (wdt * wdt)) * fade * spark
                   * envl * mix(0.7, 1.6, mass);
            pPrev = pS;
        }

        // THE HEAD — elongated along the velocity vector (motion blur sells
        // speed more than trail length): an anisotropic gaussian, long axis
        // on the flight direction, plus a hot point flare
        vec2 vdir = normalize(v + 2.0 * gpull * tt);
        vec2 hq   = sp - head;
        vec2 hloc = vec2(dot(hq, vdir), dot(hq, vec2(-vdir.y, vdir.x)));
        float stretch = mix(2.2, 4.0, mass);          // heavier = more smear
        float headG = exp(-(hloc.x * hloc.x) / (headR * headR * stretch * stretch)
                          - (hloc.y * hloc.y) / (headR * headR));
        acc += (headC * headG * 2.0
                + headC * exp(-dot(hq, hq) / (headR * headR * 36.0)) * 0.35)
               * envl * mix(0.8, 1.8, mass);

        // THE DRIPS — the reference piece's signature carried into motion:
        // glowing paint runs falling off the trail, three of them, hung
        // from real points on the trajectory's history. They lengthen as
        // the flight goes on, exactly like a fresh stroke starting to run.
        for (int k = 0; k < 3; k++) {
            float fk = 0.22 + 0.28 * float(k);
            vec2  src = meteorPos(a, v, gpull, max(tt - trailT * fk, 0.0));
            float dl  = (0.03 + 0.05 * hash11(slot * 7.1 + float(k) + ln))
                        * smoothstep(0.15, 0.8, mt) * mix(0.6, 1.4, mass);
            float hD;
            float dD = segDist(sp, src, src - vec2(0.0, dl), hD);
            float wD = headR * 0.22 * (1.0 - hD * 0.5);
            float run = exp(-dD * dD / max(wD * wD, 1e-9));
            // the bead at the end of the run
            run += exp(-dot(sp - (src - vec2(0.0, dl)), sp - (src - vec2(0.0, dl)))
                       / max(wD * wD * 4.0, 1e-9)) * 0.8;
            acc += mix(tailC, wakeC, hD) * run * envl * 0.55;
        }

        // spray blowing off the head, upwind of the flight
        acc += tailC * spatter(sp - head + vdir * 0.05 + 13.0,
                               smoothstep(0.20, 0.0, length(hq)) * 0.9) * 0.6 * envl;
    }
    return acc;
}

vec3 meteors(vec2 sp, float t, float demo) {
    vec3 acc = vec3(0.0);

    // ── the sporadic lanes: two independents, as before ─────────────────
    for (int lane = 0; lane < 2; lane++) {
        float ln   = float(lane);
        const float SLOT = 9.0;
        float lt   = t + ln * 4.7;
        float slot = floor(lt / SLOT);
        float ft   = fract(lt / SLOT);
        float gate = hash11(slot * 7.77 + ln * 13.1 + 1.7);
        // demo 1 parks a lane for stills; demo 2 (bar mode) keeps NATURAL
        // flight but opens every slot — meteors that fly, not freeze
        if (demo > 1.5)      { gate = 0.0; }
        else if (demo > 0.5) { ft = 0.5 - ln * 0.12; gate = 0.0; slot = 3.0 + ln * 5.0; }
        if (gate > 0.45) continue;

        vec2 rnd  = hash21(slot * 5.31 + ln * 23.0);
        vec2 rnd2 = hash21(slot * 11.9 + ln * 31.0);
        float mass = rnd2.x;
        float dur  = mix(1.05, 1.9, mass);
        float mt   = ft * SLOT / dur;
        if (demo > 0.5 && demo < 1.5) mt = 0.45 - ln * 0.18;
        if (mt >= 1.0) continue;

        float side = rnd.x < 0.5 ? -1.0 : 1.0;
        vec2  a    = vec2(side * (0.9 + rnd.y * 0.5) * gSpread, 0.25 + rnd2.y * 0.45);
        float ang  = (0.45 + rnd.y * 0.55) * -side;
        vec2  v    = normalize(vec2(-side, ang)) * mix(3.1, 2.0, mass) * max(gSpread * 0.7, 1.0);
        vec2  gp   = vec2(0.0, -mix(0.15, 0.45, mass));
        bool  hot  = hash11(slot * 3.3 + ln) > 0.8;
        acc += oneMeteor(sp, a, v, gp, mt * dur, mt, mass, hot, slot + ln * 9.0);
    }

    // ── THE SHOWER — the owner's ask: a radiant volley cutting through ──
    // Every ~75 s window, ~half occupied: six meteors sharing one radiant
    // direction (showers are parallel — that is what makes them a shower),
    // staggered in time and offset along the entry edge, masses hashed so
    // the volley carries one or two heavies and a spread of scratches.
    {
        const float SW = 75.0;
        float swSlot = floor(t / SW);
        float swGate = hash11(swSlot * 51.3 + 3.3);
        float swT    = fract(t / SW) * SW;
        bool  volley = (swT < 11.0 && (swGate < 0.5 || demo > 1.5)) ||
                       (demo > 0.5 && demo < 1.5);
        if (volley) {
            vec2  rndS  = hash21(swSlot * 7.9 + 1.1);
            float sideS = rndS.x < 0.5 ? -1.0 : 1.0;
            vec2  vS    = normalize(vec2(-sideS, -(0.35 + rndS.y * 0.4))) * 2.7;
            vec2  gpS   = vec2(0.0, -0.22);
            int vk = gSpread > 1.5 ? 8 : 6;           // a wide bar gets a bigger volley
            for (int k = 0; k < 8; k++) {
                if (k >= vk) break;
                float fk = float(k);
                vec2  rk = hash21(swSlot * 13.7 + fk * 5.1 + 2.2);
                float dur = 1.15 + rk.y * 0.5;
                float t0  = fk * 1.15 + rk.x * 0.9;
                float mtk = (swT - t0) / dur;
                if (demo > 0.5 && demo < 1.5) mtk = 0.24 + 0.11 * fk;
                if (mtk <= 0.0 || mtk >= 1.0) continue;
                float mass = 0.20 + 0.65 * rk.y;
                vec2  aK = vec2(sideS * (0.55 + rk.x * 0.75) * gSpread, 0.55 + rk.y * 0.4)
                         + vec2(-sideS, 0.0) * fk * 0.20 * gSpread;
                bool hot = k == 3;                     // one bolide per volley
                acc += oneMeteor(sp, aK, vS, gpS, mtk * dur, mtk, mass, hot,
                                 swSlot * 3.0 + fk * 7.0);
            }
        }
    }
    return acc;
}

// ═══════════════════════ THE VISITOR ═════════════════════════════════════
// The saucer. A silhouette — the build's identity is "urban alien", and a
// silhouette is how you see a craft against a nebula: a hole in the stars
// with a rim the sky itself lights. It crosses low with a bob, HOLDS a
// beat mid-course the way nothing ballistic could — the one move in the
// scene that ignores momentum, and the tell that it is piloted — then
// leaves faster than it came. Three running lights phase plum→teal.
vec3 visitor(vec2 sp, float t, float demo, inout vec3 scene) {
    const float SLOT = 330.0;
    float slot = floor(t / SLOT);
    float ft   = fract(t / SLOT);
    float gate = hash11(slot * 31.7 + 9.1);
    if (demo > 0.5) { gate = 0.0; slot = 11.0; }
    if (gate > 0.38) return vec3(0.0);

    float span = 14.0 / SLOT;                         // ~14 s on screen
    float u0   = 0.25 + hash11(slot * 3.9) * 0.4;
    float mt   = (ft - u0) / span;
    if (demo > 0.5) mt = 0.47;
    if (mt <= 0.0 || mt >= 1.0) return vec3(0.0);

    vec2 rnd = hash21(slot * 13.3);
    float side = rnd.x < 0.5 ? -1.0 : 1.0;

    // the course: glide in, hold, dart out
    float aIn  = smoothstep(0.00, 0.42, mt) * 0.48;
    float aOut = pow(smoothstep(0.58, 1.0, mt), 2.1) * 0.52;
    float cross = aIn + aOut;
    float x = side * (1.25 - cross * 2.5);
    float y = -0.14 + rnd.y * 0.42
            + 0.022 * vnoise(vec2(mt * 9.0, slot))    // the bob — non-linear on purpose
            - 0.05 * smoothstep(0.42, 0.58, mt) * (1.0 - smoothstep(0.58, 0.70, mt));

    vec2  c = vec2(x, y);
    float S = 0.052 + rnd.y * 0.02;                   // hull half-width
    if (demo > 0.5) { c = vec2(-0.58, -0.20); S = 0.15; }
    vec2  q = (sp - c) / S;
    if (dot(q, q) > 9.0) return vec3(0.0);

    // the hull leans into its own acceleration and flattens in the hold
    float lean = -side * 0.10 * (smoothstep(0.0, 0.4, mt)
                                 - smoothstep(0.42, 0.62, mt) * 0.9
                                 + smoothstep(0.62, 1.0, mt) * 1.4);
    mat2 rl = mat2(cos(lean), -sin(lean), sin(lean), cos(lean));
    q = rl * q;

    // hull = a lens; dome = a smaller cap riding it — both smooth masks
    float hull  = length(q * vec2(1.0, 3.4));
    float mHull = smoothstep(1.0, 0.94, hull);
    vec2  dq    = (q - vec2(0.0, 0.16)) * vec2(2.4, 3.2);
    float mDome = smoothstep(1.0, 0.90, length(dq)) * step(-0.15, q.y);
    float mAll  = max(mHull, mDome * 0.9);

    // silhouette: the craft OCCLUDES the scene — near-black with the
    // faintest violet so it reads as an object, not a rendering hole
    scene = mix(scene, VIOLET_HAZE * 0.4, mAll * 0.96);
    gCov = max(gCov, mAll * 0.96);

    vec3 acc = vec3(0.0);
    // rim light: the nebula catching the upper hull edge
    float rim = smoothstep(0.18, 0.0, abs(hull - 0.95)) * smoothstep(-0.02, 0.25, q.y);
    acc += TEAL_GLOW * rim * 1.15;
    // a wider plum after-glow outside the teal — the double stroke every
    // letter in the reference carries
    acc += PLUM_GLOW * smoothstep(0.34, 0.0, abs(hull - 1.10))
           * smoothstep(0.0, 0.25, q.y) * 0.30;
    // hard white glint slash on the dome, sun side — paint, not bloom;
    // bounded INSIDE the dome ellipse or it reads as a scratch across the sky
    float glint = step(abs((q.x + 0.42) * 3.0 + (q.y - 0.30) * 6.0), 0.35)
                * step(length(dq), 0.85);
    acc = mix(acc, vec3(0.97), glint * 0.85);
    // one specular glint on the dome, the sun's side
    vec2 gq = dq - vec2(-0.35, 0.3);
    acc += AZURE_GLOW * exp(-dot(gq, gq) * 30.0) * mDome * 0.5;

    // running lights on the hull seam, phasing in sequence
    for (int i = 0; i < 3; i++) {
        vec2 lp = vec2((float(i) - 1.0) * 0.52, -0.06);
        float ph = fract(t * 0.8 + float(i) * 0.333);
        float on = 0.35 + 0.65 * smoothstep(0.45, 0.0, abs(ph - 0.5) * 2.0 - 0.1);
        vec3 lc = mix(PLUM_GLOW, TEAL, float(i) * 0.5);
        // dot + halo: each light is its own little neon point
        float dd = dot(q - lp, q - lp);
        acc += lc * (exp(-dd * 480.0) * 1.5 + exp(-dd * 90.0) * 0.35) * on;
    }
    // the faintest cold presence under the hull while it holds — not a beam
    float holdAmt = smoothstep(0.42, 0.5, mt) * (1.0 - smoothstep(0.58, 0.66, mt));
    vec2 uq = q - vec2(0.0, -0.5);
    acc += TEAL_DEEP * exp(-dot(uq, uq) * 6.0) * holdAmt * 0.25 * step(q.y, -0.2);

    return acc;
}

// ═══════════════════════ MAIN ════════════════════════════════════════════
void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = uRes.x / max(uRes.y, 1.0);
    gAspect = aspect;
    // BAR MODE (uFlags.w == 8): scheduled elements spread across the whole
    // strip width instead of clustering around the centre
    gSpread = uFlags.w == 8.0 ? max(aspect * 0.55, 1.0) : 1.0;
    vec2 sp = (uv - 0.5) * vec2(aspect, 1.0) * 2.0;
    sp.y = -sp.y;                                     // +y up, so light agrees with itself

    float t   = uTime;
    // the THRUST SURGE: flight speed breathes ±12 % on a slow noise — a
    // craft being flown, not a conveyor. Streak length follows through
    // gExposure, so the surge reads in the streaks too, like a real shutter.
    float spd = max(uScene.y, 0.02) * (0.88 + 0.24 * vnoise(vec2(t * 0.05, 5.5)));

    // demo decode (uFlags.w, 0 in the shell): 1 meteor · 2 world · 3 visitor
    // · 5 everything · 6 bar-scale showcase (world grown to widget size)
    float demoMet = (uFlags.w == 1.0 || uFlags.w == 5.0 || uFlags.w == 6.0) ? 1.0 : 0.0;
    // demo 7 = the COMPOSED scene: the prominent planet AND the magma sun
    // (drawWorld runs twice); 2/5/6 park the planet alone
    float demoWld = (uFlags.w == 2.0 || uFlags.w == 5.0 || uFlags.w == 6.0
                     || uFlags.w == 7.0) ? 2.0 : 0.0;
    float demoVis = (uFlags.w == 3.0 || uFlags.w == 5.0) ? 1.0 : 0.0;
    float demoAst = (uFlags.w == 5.0 || uFlags.w == 6.0 || uFlags.w == 8.0) ? 1.0 : 0.0;
    float demoMet2 = uFlags.w == 8.0 ? 2.0 : 0.0;     // bar: every window flies, nothing parks
    float demoScale = uFlags.w == 6.0 ? 1.6 : 1.0;
    // NO lettering in this scene — the owner's call, 2026-08-13: "dont put
    // nyxus inside of this build". A tagPiece() existed briefly and was
    // removed whole; the wordmark belongs to the other product's art, and
    // this build has been burned by wearing the wrong skin before.

    // the vanishing point: a touch above centre (the horizon chrome owns
    // the bottom of the screen), swaying on two incommensurate slow periods
    // — a pilot's hand, not a rail. uLook.x scales the sway.
    // right-of-centre, per the wide reference: the hero holds the left of
    // the frame and the galaxy answers it from the right
    gVP = vec2(0.18, 0.14)
        + vec2(vnoise(vec2(t * 0.021, 3.7)) - 0.5,
               (vnoise(vec2(t * 0.017, 8.1)) - 0.5) * 0.6) * 0.30 * uLook.x;

    // the shutter: how far back in depth a streak reaches — scales with
    // flight speed like any camera, and with the streak dial
    gExposure = 0.05 * spd * max(uScene.z, 0.0);

    int oct    = uScene.w > 0.6 ? 5 : 3;
    int LAYERS = uScene.w > 0.6 ? 6 : 4;

    // ── assemble, back to front ──────────────────────────────────────────
    // NO cloud system in this file any more (owner's clarification): the
    // nebula layer is the existing, gated Swirl effect running quietly in
    // its own surface UNDERNEATH this one. This pass renders only the
    // flight — stars, distant bodies, meteors, the visitor — over
    // TRANSPARENCY, and gCov below is the alpha that lets the bodies
    // occlude the Swirl behind them while empty sky adds light over it.
    vec3 col = vec3(0.0);
    gCov = 0.0;

    float occl = 0.0;
    float travel = t * spd * 0.11;
    if (uFlags.y > 0.5) {
        vec3 bodies = drawWorld(sp, t, demoWld, demoScale, occl);
        if (uFlags.w == 7.0) {
            float oS = 0.0;
            bodies += drawWorld(sp, t, 7.0, demoScale, oS);
            occl = max(occl, oS);
        }
        if (uFlags.w == 8.0) {
            // the bar fill: sixteen hashed bodies across the strip
            for (int b = 8; b <= 23; b++) {
                float oB = 0.0;
                bodies += drawWorld(sp, t, float(b), demoScale, oB);
                occl = max(occl, oB);
            }
        }
        bodies += asteroids(sp, t, demoAst, occl);
        bodies += moons(sp, t, oct);
        // ATMOSPHERIC DISTANCE (clarification #1): every body sits behind
        // the star layer in depth, so it is softened and partly
        // desaturated — the stars stay the sharp, saturated foreground
        float lumB = dot(bodies, vec3(0.299, 0.587, 0.114));
        bodies = mix(bodies, vec3(lumB), 0.10);
        bodies += INDIGO_HAZE * occl * 0.15;          // the haze veil, light
        col += bodies;
    }
    gCov = max(gCov, occl);

    // the infinite dust — everything nearer stacks over it
    col += dustField(sp - gVP, travel, t) * (1.0 - occl * 0.85);

    vec3 stars = vec3(0.0);
    for (int i = 0; i < 6; i++) {
        if (i >= LAYERS) break;
        stars += layerField(sp - gVP, float(i) * 1.618 + 0.7, travel,
                            clamp(uScene.x, 0.0, 2.0) * 0.5, t);
    }
    // a star streaking OVER a planet is depth done wrong: the world's
    // occlusion mask holds most of the field behind it (the remainder
    // reads as the near shells passing in front)
    col += stars * (1.0 - occl * 0.65);

    if (uFlags.x > 0.5) col += meteors(sp, t, max(demoMet, demoMet2));

    // the real galaxy, riding behind everything bright — bar mode and the
    // full scene both carry it, plus the cluster knots and beacon stars
    col += galaxyDisc(sp, t) * (1.0 - occl);
    col += starClusters(sp, t) * (1.0 - occl * 0.9);

    // the visitor flies nearest of all
    if (uFlags.z > 0.5) col += visitor(sp, t, demoVis, col);

    // ── master, beat, finish ─────────────────────────────────────────────
    col *= uLook.w;

    // a whisper of vignette seats the scene under the glass chrome; the
    // soft knee keeps star cores and the sun from clipping to flat patches
    float vig = 1.0 - 0.16 * smoothstep(0.55, 1.6, length(sp * vec2(0.8, 1.0)));
    col *= vig;
    col = col / (1.0 + col * 0.35);
    col = pow(max(col, 0.0), vec3(0.96));

    // the neon punch — the reference reads vivid because its colour is
    // pushed past comfort: +28 % saturation, hue-locked, after the knee so
    // the white cores stay white
    float lumc = dot(col, vec3(0.299, 0.587, 0.114));
    col = clamp(mix(vec3(lumc), col, 1.28), 0.0, 1.0);

    // subpixel grain: ±1/512 per pixel per frame — banding insurance for
    // 8-bit panels, invisible as texture
    col += (hash12(uv * uRes + fract(t) * 61.7) - 0.5) / 256.0;

    // premultiplied output over the Swirl+Starlight stack beneath: empty
    // sky ADDS light (alpha 0), bodies and the visitor OCCLUDE (alpha→1)
    fragColor = vec4(col, clamp(gCov, 0.0, 1.0)) * qt_Opacity;
}
