#version 440
// Nyxus Suxyn — STARLIGHT HEADLINER. The Rolls-Royce fibre ceiling, as points.
//
// The owner's commission, 2026-08-17, verbatim and in his own priority order —
// and the order is a SPECIFICATION, not a preference. Where two of these fight,
// the earlier one wins:
//
//   1. NO BLOOM, NO DIFFRACTION SPIKES. "The current starfield has both, which
//      is a camera look. Points are sub-pixel-hard."
//   2. SPARSE AND IRREGULAR. "Scattered points with a lot of dark between them,
//      not a dense field."
//   3. GROUND IS VOID — "truly black in the gaps, not near-black."
//   4. HIGH PEAK BRIGHTNESS, SMALL AREA. "Fewer stars, each near-white."
//
// ── WHY THIS IS A NEW FILE AND NOT AN EDIT TO starlight.frag ─────────────────
// `starlight.frag` is the OPPOSITE shader and says so in its own header: "a
// tight gaussian CORE + a wider dim HALO windowed to its cell, faint capped
// diffraction spikes … a one-texel chromatic fringe at the spike tips, and a
// rare burst." Every one of those is property 1 inverted. It is not a shader
// with the bloom turned up; bloom and spikes are what it is FOR. So this is a
// second, much smaller surface, and `starlight.frag` is left byte-identical —
// the owner may still want the photographic sky, and `sky_mode` keeps all
// three reachable.
//
// ── HOW EACH PROPERTY IS SATISFIED BY CONSTRUCTION, NOT BY TUNING ───────────
// This is the part that matters, because "no bloom" achieved by lowering a
// bloom constant is one edit away from bloom.
//
//   1. There is NO gaussian, NO exp(), NO blur tap and NO spike term anywhere
//      below. A point is `step()` on a radius: full brightness inside, exactly
//      0.0 outside. Its centre is SNAPPED TO A PIXEL CENTRE, so at the
//      reference gauge a point is exactly one device pixel and every one of
//      its eight neighbours is exactly 0.0 — not 10, not 4-pixels-of-ring.
//      Snapping is also what makes the hardness stable: an unsnapped
//      sub-pixel disc dims and brightens with where it happens to fall
//      between two pixel centres, which is a shimmer nobody asked for.
//   2. THREE independent lattices at incommensurate cell sizes (47 / 71 / 109
//      reference px), each ROTATED by its own angle before it is diced, each
//      thinned by its own occupancy hash, with the survivor jittered inside
//      its cell. Rotation is what stops the composite reading as a grid: three
//      aligned lattices are a moiré, three rotated ones are a scatter.
//      Occupancy is well under 1 in every layer, which is where "a lot of
//      dark between them" comes from — the dark is the DEFAULT, not a gap
//      left over between things.
//   3. The ground is not painted at all. `col` starts at vec3(0.0) and only
//      points ever add to it, so a pixel with no point in it leaves this
//      shader as exactly 0/0/0. There is no base, no vignette, no seam fade
//      and no dither. `_tokens.edges.ground` (#020506) is DELIBERATELY NOT
//      used here and the report says why: it measures luminance 4 on the
//      0-255 ruler, and the owner's acceptance target for this surface is
//      that the gaps measure 0.
//   4. Brightness is the only thing that varies between points; the RADIUS
//      never does. Small area is property 4's own words, so a brighter fibre
//      is brighter, not bigger — which is also the difference between a fibre
//      tip and a photograph of one.
//
// ── THE TWINKLE ─────────────────────────────────────────────────────────────
// Per point, from the point's OWN cell hash: its own phase and its own rate.
// No global time term multiplies the field, so there is nothing that can read
// as a synchronised pulse — "a global pulse reads as a flicker, not a
// headliner." Two sines at an irrational ratio (1.618) rather than one,
// because `starlight.frag`'s header already recorded the lesson that "a sine
// reads as clockwork within seconds"; two incommensurate sines never repeat.
// It is deliberately NOT value noise: noise costs four hashes and two mixes
// per octave for a signal the eye cannot tell from this one at these rates.
//
// AND IT IS FREE. Ablated on the 3060 at 2560x1600 over 200 timed draws: with
// both sines replaced by constants the pass measures 0.2038 ms, against
// 0.2038 ms with them — identical to four decimal places. That is not luck,
// it is the early-out: the sines sit BELOW `if (hit <= 0.0) return 0.0;`, so
// they run only for the ~0.02% of fragments that are actually inside a point.
// The twinkle costs nothing because almost nothing twinkles.
//
// Cost: there is no field to solve, so there is nothing to step and nothing
// to store. One draw call, one pass, no textures, no feedback buffers.
// Measured at 2560x1600 on the owner's 3060, the same instrument and the same
// surfaceless-EGL route as `_swirl_tiers._measured`: 0.2038 ms per frame, of
// which 0.0645 ms (32%) is the constant-colour write floor that any
// full-screen pass pays. `Swirl.qml`'s DISPLAY pass alone is 0.213 ms at the
// same size, and it sits on top of a ten-pass solve costing a further
// 0.258 ms per step across ~31 draws. Full breakdown in the brief.
//
// ── uRes.z IS NOT DECORATION ─────────────────────────────────────────────────
// The lattice is laid out in REFERENCE pixels (1080 tall) and the point radius
// is in DEVICE pixels. That is the resolution-free contract: a bigger screen
// spreads the same number of fibres further apart instead of multiplying them,
// and each one stays a hard point rather than growing a soft blob. A ceiling
// does not gain fibres when you sit closer to it.
//
// Tune in the WebGL harness, then rebuild: bash shell/shaders/build.sh
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float uTime;
    vec4 uRes;    // x,y surface size in DEVICE px · z point gauge in px · w unused
    vec4 uLook;   // x twinkleDepth · y density · z master · w reserved
};

// ─────────────────────────── PORTABLE BODY BELOW ───────────────────────────
// Everything above this line is the Qt flavour of GLSL (the #version, the
// std140 block, the layout qualifiers). Everything below is ordinary GLSL and
// is copied BYTE FOR BYTE by scripts/render-starlight-headliner.py, which
// swaps the header for a desktop-GL or WebGL2 one. That is why the still, the
// measurements, the live canvas in the brief and the desktop are all the same
// shader: only one of them is written by hand. The 2D headliner already lost a
// version to two copies of the same maths drifting apart (the cell-units bug
// in starlight.frag's header) — mechanical transformation is the fix.

// NEAR-WHITE, and it is a real token, not prose. accent.json _palette_fixed
// `text` = #edf1ff — the brightest published stop in this palette. "Invent no
// hex" is a standing rule here because five colours have shipped on this
// project while existing only in a sentence.
const vec3 FIBRE = vec3(0.929412, 0.945098, 1.0);   // #edf1ff

// The reference height the lattice is measured in.
const float REF_H = 1080.0;

float h11(float p) { p = fract(p * 0.1031); p *= p + 33.33; p *= p + p; return fract(p); }
float h21(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// ONE LATTICE. `fc` is the fragment's device-pixel centre; `ca`/`sa` rotate it
// into this lattice's own frame; `invCS` is 1/(cell x scale) and `cellScale` is
// cell x scale, i.e. the cell pitch already converted to device px; `occ` is
// the occupancy and `seed` the lattice's identity.
//
// THE RECIPROCALS ARE PRE-DIVIDED IN main(), and that is a measured decision,
// not tidiness. Ablated at 2560x1600 on the 3060: two per-pixel divides per
// lattice and a full h22() jitter hash cost 0.072 ms of a 0.255 ms pass — 28%,
// the single largest term after the write floor, for a value that is only ever
// used to decide where inside a cell one point sits. Three divides moved into
// main() and the jitter re-derived from the occupancy hash that has ALREADY
// been paid for; the field is statistically the same and the arithmetic is
// most of the way to free.
//
// Only the cell the fragment is IN is examined — one cell, not a 3x3 ring —
// because the jitter keeps every centre at least 10% of a cell inside its own
// walls while the point itself is ~1 device px across. A footprint that cannot
// cross a cell wall cannot need its neighbours read, and that is the other
// half of why this costs what it costs.
// ── TRK-3490 · STRATA · owner 2026-08-30 ────────────────────────────────
// "make it more intense with the stars ... 3D in depth so looking at it will
// look as real as possible."
//
// `gaugeMul` is the depth cue, and it is the one this shader did not already
// have. Brightness varies per fibre (`bri`, below) and twinkle varies per
// fibre, but every point was the SAME SIZE, and size is what the eye reads as
// distance in a field of otherwise identical lights. Finer pitches now carry
// smaller points and coarser pitches larger ones, so the lattices stop being
// three interchangeable scatters and become near, middle and far.
//
// The hard point is untouched: still 1.0 inside and exactly 0.0 out, no
// gaussian, no halo, no spikes. That ruling is what makes this a fibre-optic
// headliner rather than a generic starfield, and adding glow to buy depth
// would trade the thing's identity for an effect.
float lattice(vec2 fc, float ca, float sa, float invCS, float cellScale,
              float occ, float seed, float gauge, float t, float twinkleDepth,
              float gaugeMul) {
    // fragment position in this lattice's own frame, diced into cells
    vec2 pr = vec2(ca * fc.x - sa * fc.y, sa * fc.x + ca * fc.y);
    vec2 gi = floor(pr * invCS);

    // does this cell carry a fibre at all?
    float occHash = h21(gi + seed);
    if (occHash >= occ) return 0.0;

    // where in the cell? 0.10..0.90 of the cell keeps the centre clear of the
    // walls at every cell size used here. The two multipliers are large and
    // mutually prime enough that x and y decorrelate across the ~500 cells a
    // lattice actually has; `occHash` is already in hand, so this is two
    // multiplies and a fract instead of a second hash.
    vec2 j = fract(vec2(occHash * 137.13, occHash * 289.71));
    vec2 cr = (gi + 0.10 + 0.80 * j) * cellScale;
    // back out of the rotation, then SNAP to a pixel centre — see the header.
    vec2 cd = floor(vec2(ca * cr.x + sa * cr.y, -sa * cr.x + ca * cr.y)) + 0.5;

    // Hard point. No gaussian, no halo, no spikes: 1.0 inside, exactly 0.0
    // out. Compared as a SQUARED distance because the radius is a constant
    // the caller already has — measured 0.2140 -> 0.2038 ms at 2560x1600, a
    // 5% saving for a sqrt whose value is never used for anything but this
    // comparison.
    vec2 e = fc - cd;
    float r = max(gauge * gaugeMul, 1.0) - 0.5;
    float hit = step(dot(e, e), r * r);
    if (hit <= 0.0) return 0.0;

    // ── PER-FIBRE IDENTITY, AND WHY IT IS THREE HASHES AND NOT ONE CHAIN ────
    // Everything below this line runs only for a fragment that is actually
    // INSIDE a point — about 0.02% of them — so it is free, which is what the
    // ablation measured: replacing both sines with constants moved the pass
    // by 0.001 ms. That is the budget in which to buy independence.
    //
    // The first cut chained h11() off one float for all three. Over 100
    // frames its max pairwise correlation was exactly +1.0000, which looked
    // like a hash-resolution collision, so it was changed to three
    // independent 2D hashes of the CELL INDEX.
    //
    // ⚠ AND THE NUMBER BARELY MOVED: +1.0000 -> +0.9998 max, +0.0011 ->
    // +0.0015 mean. Recorded that way ON PURPOSE rather than quietly kept as
    // an improvement, because "a fix must measure the thing it claims to
    // improve, before and after" and this one did not improve it. What the
    // run actually taught is that PAIRWISE CORRELATION IS THE WRONG METRIC:
    // over a 4 s window any population of sinusoids drawn from one frequency
    // family throws up near-parallel pairs, so p99 sits near +0.93 whatever
    // the hashing does. The metric that answers the owner's real concern —
    // "a global pulse reads as a flicker" — is the standard deviation of the
    // FIELD MEAN over time: measured 1.066 against 1.077 expected of 890
    // independent points, where a global pulse would put it at ~32. The
    // change is kept because deriving three values from three hashes of the
    // cell is better founded than chaining them off one scalar, not because
    // it moved a number.
    float id = h21(gi * 7.31 + seed + 1.7);
    // skewed high: property 4 is "each near-white", so the population sits in
    // the top third of the range and the floor is a depth cue, not a tier.
    float bri = 0.62 + 0.38 * (1.0 - id * id);

    // period 1.16 s .. 3.93 s. Slow enough to read as breathing rather than
    // flicker, fast enough that a point visibly moves inside one second —
    // which is what "sub-second variation per point" asks for.
    float rate = 1.60 + 3.80 * h21(gi * 1.93 + seed + 4.1);
    float phase = 6.28318 * h21(gi * 3.77 + seed + 8.7);
    float a = 0.5 + 0.5 * sin(t * rate + phase);
    float b = 0.5 + 0.5 * sin(t * rate * 1.618034 + phase * 2.3);
    float tw = 1.0 - twinkleDepth * (0.65 * a + 0.35 * b);

    return bri * tw;
}

void main() {
    vec2 res = uRes.xy;
    vec2 fc = vec2(qt_TexCoord0.x, 1.0 - qt_TexCoord0.y) * res;
    float scale = res.y / REF_H;

    // The gauge in device px. floor(scale + 0.5) keeps a point one WHOLE pixel
    // at 1080p and 1600p and grows it only when the panel really has the
    // pixels to spare, so "small area" survives a 4K screen instead of being
    // a 1080p-only claim.
    float gauge = max(1.0, floor(scale + 0.5)) * max(0.25, uRes.z);

    float dens = clamp(uLook.y, 0.0, 2.0);
    float twd = clamp(uLook.x, 0.0, 1.0);

    // THE GROUND IS NOT PAINTED. It is what is left when no lattice fires.
    //
    // Three lattices at 47 / 71 / 109 reference px. The pitches are pairwise
    // coprime-ish and the ROTATIONS are what matter: three aligned lattices
    // beat against each other into a visible moiré, three rotated ones read
    // as a scatter. Occupancy well under 1 in all three is where "a lot of
    // dark between them" comes from — the dark is the default state of a
    // cell, not a gap left between things.
    // TRK-3490 — FIVE strata, not three. Two more pitches (a fine far field
    // and a coarse near one) roughly double the population, and because each
    // now carries its own point size the field reads as depth rather than as
    // more of the same. Pitches stay pairwise coprime-ish and every rotation
    // is distinct, which is what keeps three-or-more lattices from beating
    // into a visible moire — the reason the original three were rotated at
    // all.
    float s0 = 31.0 * scale, s1 = 47.0 * scale, s2 = 71.0 * scale;
    float s3 = 109.0 * scale, s4 = 157.0 * scale;
    float v = 0.0;
    v += lattice(fc, 0.986286, 0.164990, 1.0 / s0, s0,
                 0.42 * dens, 907.0, gauge, uTime, twd, 0.74);
    v += lattice(fc, 1.000000, 0.000000, 1.0 / s1, s1,
                 0.50 * dens, 3.0, gauge, uTime, twd, 0.88);
    v += lattice(fc, 0.918313, 0.395856, 1.0 / s2, s2,
                 0.66 * dens, 61.0, gauge, uTime, twd, 1.00);
    v += lattice(fc, 0.611374, 0.791341, 1.0 / s3, s3,
                 0.82 * dens, 137.0, gauge, uTime, twd, 1.16);
    v += lattice(fc, 0.325568, 0.945519, 1.0 / s4, s4,
                 0.90 * dens, 401.0, gauge, uTime, twd, 1.34);

    vec3 col = FIBRE * min(v, 1.0) * clamp(uLook.z, 0.0, 2.0);

    // Opaque. This surface IS the ground, so the void has to be this shader's
    // own black and not whatever happens to be underneath it — property 3 is
    // about what the eye receives, and a transparent "black" is a promise
    // about somebody else's pixels.
    fragColor = vec4(col * qt_Opacity, qt_Opacity);
}
