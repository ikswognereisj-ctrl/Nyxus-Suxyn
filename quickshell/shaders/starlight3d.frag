#version 440
// Nyxus Suxyn — STARLIGHT VOYAGE. The windshield, not the ceiling.
//
// `starlight.frag` is the Rolls-Royce headliner: a FLAT field of fibre points
// on a plane you look up at. This is its 3D successor — you are not looking at
// a ceiling, you are looking THROUGH a windshield into a volume you are moving
// through. Everything that follows exists to make that one difference true.
//
// WHAT IS ACTUALLY 3D HERE, AND WHAT IS NOT — read this before tuning:
//
//   · STARS are real points in a 3D lattice. Each is hashed from its integer
//     cell, given a world position, and projected by exact perspective: the
//     angular radius is radius/distance and the apparent brightness is
//     luminosity/distance². That is why the parallax is correct rather than
//     approximated — near stars sweep past because they genuinely ARE near,
//     not because a near layer was given a bigger scroll multiplier. Four
//     depth bands (foreground/mid/deep/infinite) are four calls with different
//     cell sizes and t-ranges, not four different techniques.
//   · THE GALAXY is a genuine volumetric integral: fBm sampled along the ray,
//     front-to-back, with transmittance. The dust occludes what is behind it
//     because it is actually integrated, not alpha-blended as a flat sheet.
//   · THE GALAXY IS ALSO A LIQUID, and it is the one thing here that moves
//     under its own power rather than because the camera does. Three terms —
//     a rigid stream, a bounded field of eddies, and a boiling domain warp —
//     are described where they are built, above `galaxyMedium`. The swirl is
//     bound to the band by a single scalar, `galaxyMask`, which is exactly 0
//     in empty space, so the fluid cannot paint one pixel the band does not
//     already own. The black between the stars stays #000000 by arithmetic,
//     not by tuning.
//   · THE STARS ARE BEHIND THE DUST, per channel and per depth. The band does
//     not merely dim what is behind it, it REDDENS it (λ⁻¹ extinction), and
//     each star band is attenuated by the transmittance at its own distance —
//     so a foreground star stays ice-white while the deep field goes amber
//     where a dust lane crosses it. That, and not the dust's own brightness,
//     is what makes the two layers read as one photograph.
//   · THE BODIES are sphere-traced SDFs with analytic ring shadowing both
//     ways — rings onto the planet, planet across the back of the rings.
//   · THE RELIEF IS NOT IN THE SDF, ON PURPOSE. The urban plating is a
//     voronoi bump evaluated ONCE at the hit point, not a displacement inside
//     `map()`. A 27-cell voronoi inside a 48-step march is ~1300 voronoi
//     evaluations per pixel for relief you cannot see at this scale; as a
//     bump it is 27, it never breaks the Lipschitz bound the sphere tracer
//     depends on, and the silhouette of a planet this size is a circle either
//     way. This is the single biggest performance decision in the file.
//
// STEP BUDGET (the ceiling the owner asked for — 40–50, and it is honoured):
//   SDF march 48 · galaxy 14 · rings 10 · stars 8/8/7/0.
// Only the SDF march is allowed the high count, and it breaks early on both
// ends (surface hit, and t past the far plane). The galaxy and the rings are
// deliberately coarse because dust has no edges to alias. `u_scene.w` is a
// quality lever the QML drops on battery — it scales every loop except the
// SDF, whose precision is the thing you would actually notice.
//
// Uniform names are `u_time` / `u_resolution` / `u_mouse` rather than this
// repo's usual `uTime` / `uRes`. That is deliberate and it is the one place
// this file breaks house style: the same body is tuned in
// `design/starlight3d-live.html` as plain WebGL2, and a uniform that has to be
// renamed between the tuning harness and the shipped shader is a uniform that
// eventually gets renamed wrong. Qt maps block members to QML properties by
// name, so `Starlight3D.qml` declares these spellings verbatim.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float u_time;
    vec2  u_resolution;   // item px
    vec2  u_mouse;        // smoothed, −1..1, (0,0) = centre. QML does the easing
    vec4  u_look;         // x twinkleSpeed · y sparkle · z warmth · w master
    vec4  u_scene;        // x density · y driftSpeed · z galaxyGain · w quality
    vec4  u_flags;        // x bodies on · y galaxy on · z dust-immersion · w reserved
    // WIP-553 — the owner's approved dark-glass ground, carried in from
    // Theme.qml rather than hardcoded here (rgb only; .w unused, padding).
    // Two surfaces he approved in writing — the desktop widgets and the
    // shelf right-click menu — are the reference: Theme.surfaceTop/Mid/Deep
    // for the vertical body gradient, Theme.glassBorder for the accent
    // that leans into the brightest specular peaks.
    vec4  u_groundTop;    // Theme.surfaceTop.rgb
    vec4  u_groundMid;    // Theme.surfaceMid.rgb
    vec4  u_groundDeep;   // Theme.surfaceDeep.rgb
    vec4  u_groundEdge;   // Theme.glassBorder.rgb
};

// ─────────────────────── PORTABLE BODY BELOW ───────────────────────────
// Everything past this marker is plain GLSL and depends on nothing Qt-shaped.
// `mkwebgl.py` copies it verbatim under a WebGL2 header to build the tuning
// harness, so this file stays the ONE copy of the shader body. Do not put a
// Qt-only construct below this line, and do not reference qt_TexCoord0 outside
// main() — the harness defines it as a macro.

// ── step budget ──────────────────────────────────────────────────────────
const int  SDF_STEPS   = 48;
// Raised now that the default scene carries no bodies: the 48-step SDF
// march was the single most expensive loop in the file, and dropping it frees
// more than enough to run the dust and the stars at their full detail instead.
const int  GAL_STEPS   = 18;
const int  RING_STEPS  = 10;
const float SDF_FAR    = 140.0;
const float SDF_EPS    = 0.0016;   // ×t — angular, so distant hits cost less

// ── the measured theme stops (accent.json _palette_fixed) ────────────────
// The build's palette is a RAMP, never a flat colour (HANDOFF, "Palette").
// These are the same five the 2D headliner paints its band with, so the two
// skies are recognisably the same sky.
// Read from theme/accent.json, key by key, not copied from a comment.
//
// ⚠ CORRECTION to what an earlier revision of this header claimed. It said
// `#ae206c` was "not in this build's palette at all". That was half right and
// therefore wrong: it is absent from `_palette_fixed`, but it IS
// `_swirl._emission.ladders.plum.accent` and the fifth stop of the swirl
// SWEEP — which is the ladder the taskbar's own paint runs on. So plum is not
// an invention, it is the bar's colour, and the owner pointing at the bar and
// saying "use these exact colours" is pointing at this ladder.
//
// Two palettes live in accent.json and they are not interchangeable:
//   · `_palette_fixed` — the app/theme layer's flat stops.
//   · `_swirl._emission.ladders` — the MEASURED emission ladder (Agent B's
//     block), taken from the owner's four nebula banners at 197k pixels, five
//     rungs per hue: haze → deep → body → accent → glow. It exists precisely
//     because he said the colours had to "almost glow … not dull and boring".
// A sky is emission, so the sky is built on the second one.
const vec3 P_AZURE       = vec3(0.024, 0.310, 0.584);  // #064f95 azure accent
const vec3 P_AZURE_BODY  = vec3(0.078, 0.369, 0.651);  // #145ea6 azure body
const vec3 P_AZURE_GLOW  = vec3(0.322, 0.627, 0.918);  // #52a0ea azure glow
const vec3 P_INDIGO_BODY = vec3(0.169, 0.078, 0.651);  // #2b14a6 indigo body
const vec3 P_VIOLET_BODY = vec3(0.431, 0.078, 0.651);  // #6e14a6 violet body
const vec3 P_PLUM        = vec3(0.682, 0.125, 0.424);  // #ae206c plum accent
const vec3 P_PLUM_BODY   = vec3(0.651, 0.078, 0.384);  // #a61462 plum body
const vec3 P_PLUM_GLOW   = vec3(0.843, 0.396, 0.635);  // #d765a2 plum glow
const vec3 P_GOLD_BODY   = vec3(0.651, 0.396, 0.078);  // #a66514 gold body
const vec3 P_TEAL        = vec3(0.039, 0.635, 0.839);  // #0aa2d6 teal
const vec3 P_TEAL_GLOW   = vec3(0.361, 0.776, 0.918);  // #5cc6ea teal_glow
const vec3 P_TEAL_DEEP   = vec3(0.008, 0.384, 0.510);  // #026282 teal_deep
const vec3 P_INDIGO      = vec3(0.118, 0.012, 0.678);  // #1e03ad indigo
const vec3 P_INDIGO_GLOW = vec3(0.478, 0.388, 0.941);  // #7a63f0 indigo_glow
const vec3 P_VIOLET      = vec3(0.322, 0.118, 0.447);  // #521e72 violet
const vec3 P_VIOLET_GLOW = vec3(0.667, 0.431, 0.808);  // #aa6ece violet_glow
const vec3 P_GOLD        = vec3(0.608, 0.384, 0.106);  // #9b621b gold
const vec3 P_GOLD_GLOW   = vec3(0.847, 0.643, 0.392);  // #d8a464 gold_glow

// The camera basis, and the eye. Globals because every star layer needs the
// screen axes to orient its diffraction spikes, and threading four more
// parameters through five call sites buys nothing.
vec3 gRight, gUp, gFwd, gRo;
vec3 gLight;          // the system's star, off frame left
vec3 gPlanetC;        // world centre of the planet — the moons and rings hang off it
vec3 gRingN;          // ring plane normal
vec3 gRingU, gRingV;  // an orthonormal basis IN the ring plane, built once in main
float gPlanetR;

// ── hashes ───────────────────────────────────────────────────────────────
// Explicitly no trig. A sin()-based hash is the classic starfield mistake:
// it is precision-dependent (the same shader banding differently on Intel and
// NVIDIA is almost always this), and it is genuinely slower than the integer
// -ish float mixes below on every GPU made in the last decade.
float hash11(float p) { p = fract(p * 0.1031); p *= p + 33.33; p *= p + p; return fract(p); }
float hash13(vec3 p3) {
    p3 = fract(p3 * 0.1031);
    p3 += dot(p3, p3.zyx + 31.32);
    return fract((p3.x + p3.y) * p3.z);
}
vec3 hash33(vec3 p3) {
    p3 = fract(p3 * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yxx) * p3.zyx);
}

float noise1D(float x) {
    float i = floor(x), f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(hash11(i), hash11(i + 1.0), f);
}

float vnoise3(vec3 p) {
    vec3 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float n000 = hash13(i + vec3(0.0, 0.0, 0.0)), n100 = hash13(i + vec3(1.0, 0.0, 0.0));
    float n010 = hash13(i + vec3(0.0, 1.0, 0.0)), n110 = hash13(i + vec3(1.0, 1.0, 0.0));
    float n001 = hash13(i + vec3(0.0, 0.0, 1.0)), n101 = hash13(i + vec3(1.0, 0.0, 1.0));
    float n011 = hash13(i + vec3(0.0, 1.0, 1.0)), n111 = hash13(i + vec3(1.0, 1.0, 1.0));
    return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
               mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

// iq's orthonormal shuffle — rotating between octaves is what stops fBm
// laying its lattice axes bare as a visible grid in the dust.
const mat3 M3 = mat3( 0.00,  0.80,  0.60,
                     -0.80,  0.36, -0.48,
                     -0.60, -0.48,  0.64);

float fbm3(vec3 p, int oct) {
    float a = 0.5, s = 0.0;
    for (int i = 0; i < 5; i++) {
        if (i >= oct) break;
        s += a * vnoise3(p);
        p = M3 * p * 2.02;
        a *= 0.5;
    }
    return s * 1.0667;   // ≈ /0.9375, the 5-octave sum, so oct changes brightness ~not at all
}

// A ridge, for filaments. Cheap: one fBm, folded.
float ridge3(vec3 p, int oct, float sharp) {
    float n = fbm3(p, oct);
    return pow(1.0 - abs(2.0 * n - 1.0), sharp);
}

mat2 rot2(float a) { float s = sin(a), c = cos(a); return mat2(c, -s, s, c); }

// ── the galaxy, as a place ───────────────────────────────────────────────
// A slab whose normal lies in the screen plane at 45°, so it reads as a band
// running corner to corner. The normal contains the view axis, which is what
// makes the band a BAND rather than a disc you fly into.
const vec3 GAL_N = vec3(-0.7071, 0.7071, 0.0);
// The band's long axis on screen — perpendicular to the normal, in the screen
// plane. The dust is stretched along this so the streams run corner to corner.
const vec3 GAL_T = vec3(0.7071, 0.7071, 0.0);
const float GAL_HALFWIDTH = 22.0;
// The galaxy is marched MUCH further than the bodies and on its own far plane.
// This is what makes it a band rather than fog, and it is worth stating why:
// the band in a real sky is not a dense object, it is a LONG PATH. A ray along
// the galactic plane stays inside the slab for ≈W/sin(θ) and piles up emission;
// a ray across it leaves almost at once. So the profile falls as 1/sin(θ) all
// by itself — provided the density per unit length is low enough that the
// integral never saturates. The first cut used a high density over a short
// march and got exactly what that predicts: a uniform lavender fog with the
// black crushed out of it, which is the one thing the brief will not allow.
const float GAL_FAR  = 700.0;
const float GAL_NEAR = 12.0;

// ── THE LIQUID ───────────────────────────────────────────────────────────
// The dust FLOWS. Until this change the band was a static field that the
// camera drifted through: the parallax was real, but nothing in the volume
// ever moved on its own, and a still field of noise reads as a photograph
// however well it is lit. This is the live swirl.
//
// It is bound to the band by construction rather than by tuning — see
// `galaxyMask` in `galaxyMedium` below. The flow only ever decides WHERE the
// dust's own structure sits; the mask decides whether there is any dust there
// at all, and it is exactly zero everywhere the band is not. So no amount of
// swirl can put a colour into empty space.
//
// THE ONE RULE THAT DECIDES EVERY CONSTANT HERE: a wallpaper runs for HOURS.
// Any time-dependent DISTORTION of the sample coordinate ACCUMULATES — if the
// warp's Jacobian grows with t, the noise is sheared into ever-finer streaks
// until it aliases into crawling sparkle, and it does that so slowly that
// watching it for two minutes proves nothing. The first sketch of this used a
// vortex whose angle grew linearly with time; it is beautiful for ninety
// seconds and it is a wind-up spiral by the ten-minute mark. So:
//
//   · RIGID translation MAY be secular (grow without bound with t). It moves
//     the field without deforming it, so it is safe for ever. That is STREAM.
//   · Every other term MUST be BOUNDED — its amplitude may wander, it may not
//     grow. That is SWIRL and BOIL.
//
// Three terms, each doing a job the other two cannot:
//   1. STREAM — rigid drift along the band's own long axis. The river moves.
//   2. SWIRL  — a continuous field of eddies: the sample coordinate is ROTATED
//      about the view axis by an angle drawn from a coarse fBm. Bounded angle
//      ⇒ bounded distortion ⇒ safe for ever. This is the term that makes it
//      read as fluid rather than as scrolling smoke: a translation field alone
//      never curls, and curl is the entire visual signature of a liquid.
//   3. BOIL   — the existing domain warp's own input is translated, so the
//      field that decides where the streams BEND is itself in motion. The
//      streams writhe and reform instead of sliding past rigid.
// The three run at incommensurate rates, so the combination never repeats.
const float FLOW_STREAM = 0.00046;  // q-units/s along GAL_T — rigid, so secular
const float FLOW_SWIRL  = 0.0165;   // how fast the eddy field turns over
const float FLOW_BOIL   = 0.0091;   // how fast the warp field morphs
const float SWIRL_AMP   = 1.15;     // radians, peak. Past ~1.6 the ribbons tear
const float SWIRL_SCALE = 0.62;     // eddies COARSER than the cloud on purpose,
                                    // so they turn whole streams rather than
                                    // fraying them into noise

// Rotate `q` about the VIEW axis — the axis you are looking down — so an eddy
// turns in the plane of the screen and you can actually see it spin. GAL_T and
// GAL_N are orthonormal and both lie in that plane, so together they ARE the
// band's screen basis; the remaining component (along their cross product,
// which is the view axis) is left untouched. That makes each eddy a COLUMN of
// rotating material rather than a ball, which is why it survives the
// volumetric integral: every sample along a ray agrees about which way the
// material there is turning, so the swirl reads crisply instead of averaging
// itself into mush.
vec3 liquidSwirl(vec3 q, float ang) {
    float a = dot(q, GAL_T);
    float b = dot(q, GAL_N);
    vec3 depth = q - GAL_T * a - GAL_N * b;
    vec2 r = rot2(ang) * vec2(a, b);
    return depth + GAL_T * r.x + GAL_N * r.y;
}

// Density of the dust at a world point, ALREADY MASKED — so it can only
// occlude what is behind it where the band actually exists.
//
// `liquidColor` is the swirl's own emission, unmasked: the colour the fluid
// would have if the band went on for ever. `galaxyMask` is the band's shape.
// The caller multiplies them — `liquidColor * galaxyMask` — which is the one
// line that guarantees the fluid is strictly bound to the band's geometry.
// They are returned separately, rather than pre-multiplied here, precisely so
// that guarantee is visible at the call site instead of buried in this
// function where the next person tuning the palette could quietly lose it.
float galaxyMedium(vec3 p, float t, int oct, out vec3 liquidColor, out float galaxyMask) {
    liquidColor = vec3(0.0);
    galaxyMask  = 0.0;
    // DUST-IMMERSION MODE. Instead of looking ACROSS at a band from outside
    // it, you are inside the cloud: the slab is opened up ~3× and the
    // near-fade is pulled in, so the dust wraps the whole frame and the stars
    // shine through it. Same medium, same integral — the only thing that
    // changes is where the camera is standing relative to it, which is the
    // honest way to get "just star dust" rather than painting a second effect.
    float dustMode = u_flags.z;
    float halfW = GAL_HALFWIDTH * mix(1.0, 3.1, dustMode);
    float h = dot(p, GAL_N) - 1.5;
    float band = exp(-h * h / (2.0 * halfW * halfW));
    if (band < 0.004) return 0.0;
    // Nothing dense sits against the windshield. Without this the first few
    // samples of every ray — which are the ones nearest the camera and so the
    // ones with the largest solid angle — smear dust over the whole frame.
    band *= smoothstep(GAL_NEAR * mix(1.0, 0.35, dustMode), GAL_NEAR * mix(6.0, 2.2, dustMode), t);
    if (band < 0.004) return 0.0;

    // Stretch the sampling ALONG the band axis so the clouds stream instead of
    // puddling. Same trick the 2D band uses, in 3D: squash the coordinate the
    // slab is thin in, leave the two it is long in.
    // ELONGATION IS WHAT MAKES A RIBBON. The reference sky's arcs sweep most
    // of the way across the frame; isotropic fBm cannot produce that, it makes
    // turbulent wisps of roughly equal length in every direction. Compressing
    // the sample coordinate ALONG the band axis makes the noise vary slowly
    // that way, so every feature is stretched into a long stroke — keeping 28%
    // of the along-band coordinate stretches them ≈3.5×.
    vec3 q = p * 0.021;
    q -= GAL_T * dot(q, GAL_T) * 0.72;
    q -= GAL_N * dot(q, GAL_N) * 0.30;

    // ── THE LIQUID, term 1 · STREAM ──────────────────────────────────────
    // A rigid translation along the band's own long axis: the whole river
    // moves down its length. Rigid means the Jacobian is the identity for ever,
    // which is why this one term is allowed to grow with time without ever
    // shearing the noise into streaks. Slow on purpose — one cloud feature
    // crosses its own width in about half an hour, which is motion you notice
    // having happened rather than motion you catch yourself watching.
    q += GAL_T * (u_time * FLOW_STREAM);

    // ── term 2 · SWIRL ───────────────────────────────────────────────────
    // The eddies. A coarse fBm gives a smooth signed field over the volume;
    // that field is read as an ANGLE and the sample coordinate is rotated by
    // it about the view axis. Where the field is positive the material turns
    // one way, where it is negative the other, and between them it shears —
    // which is a curl field, built out of one noise lookup instead of the six
    // that finite-difference curl noise would cost.
    // The angle is BOUNDED by SWIRL_AMP, so however long this runs the warp
    // can never accumulate: it is the eddy PATTERN that evolves, not a total
    // rotation that keeps climbing. That is the whole reason this is safe to
    // leave on a desktop all day.
    // fbm3 at two octaves lands in ≈[0, 0.8] with a mean near 0.40; the
    // −0.40 ×2.5 puts it on ≈[−1, 1] so SWIRL_AMP means radians of peak twist.
    // The time offset is deliberately NOT along the view axis: the camera is
    // already drifting that way, and a swirl field scrolling with it would
    // partly cancel and read as static.
    float eddy = (fbm3(q * SWIRL_SCALE + vec3(0.37, -0.52, 0.31) * (u_time * FLOW_SWIRL)
                       + 51.9, 2) - 0.40) * 2.5;
    q = liquidSwirl(q, eddy * SWIRL_AMP);

    // One domain warp. Two looked no better and cost a second fBm.
    // THE WARP IS TWO OCTAVES AND ALWAYS WILL BE. A domain warp is a
    // low-frequency displacement — it decides where the streams bend, not what
    // they are made of — so octaves above the second are sampled, summed, and
    // then almost entirely erased by the fBm they are fed into. At `oct`=5
    // these three calls alone were 120 of the ~200 hash lookups per galaxy
    // sample, and the galaxy is 14 samples deep: they were the single largest
    // cost in the shader, spent on detail that never reached the screen.
    // Measured on the target machine (Iris Xe, 1750×800, WebGL): 15 fps before
    // this and the two changes below it, 55–60 after, with no visible
    // difference in the dust.
    // ── term 3 · BOIL ────────────────────────────────────────────────────
    // The warp is the field that decides where the streams bend. Translating
    // ITS input — not the cloud's — means the bends themselves travel, so a
    // stream visibly reforms rather than sliding past as a rigid shape. Each
    // component gets a different direction (the swizzles) so the three do not
    // move as one block, which would just be a fourth translation.
    // Bounded for ever by construction: `w` is an fBm, so it lives in [0, 1]
    // no matter what its input does, and `q + 1.7 * w` therefore has a bounded
    // Jacobian for all time. Cost: nothing. These three fBm calls were already
    // being made; only their sample point moved.
    vec3 e = vec3(0.61, -0.43, 0.29) * (u_time * FLOW_BOIL);
    vec3 w = vec3(fbm3(q + 11.3 + e, 2), fbm3(q + 41.7 - e.yzx, 2), fbm3(q + 73.1 + e.zxy, 2));
    float n = fbm3(q + 1.7 * w, oct);

    // ── THE GALAXY MASK ──────────────────────────────────────────────────
    // ONE scalar decides where the band exists, and nothing below is allowed
    // to paint outside it.
    //
    //   · `band` is the slab's GEOMETRY — a gaussian across the galactic
    //     plane, already faded in past the windshield. It is where the band
    //     could be.
    //   · `n` is the fBm DENSITY — it is where the band actually is. Folding
    //     it in is what gives the edge its ragged, cloudy silhouette instead
    //     of the smooth airbrushed ellipse a geometric mask alone produces.
    //
    // THE LOW STOP IS ABOVE ZERO AND THAT IS THE ENTIRE TRICK. smoothstep
    // clamps, so every sample under 0.06 comes out EXACTLY 0.0 — not 1e-6, not
    // a wash, not a tint one stop of exposure could lift back into view. An
    // asymptotic falloff would leave a real value everywhere in the frame, and
    // the tonemap and the saturation push downstream would find it. Exact zero
    // is what keeps deep space #000000 and leaves the pinpricks the sharpest
    // thing on the screen.
    //
    // THE DENSITY TERM IS WEIGHTED FAR ABOVE THE GEOMETRY, and that is what
    // the sweep that chose these four numbers was actually measuring. The
    // constant 0.12 is BELOW the low stop, so a sample whose density sits under
    // the smoothstep's floor contributes nothing at all no matter where in the
    // slab it is — the voids are cut, not dimmed. That is this file's own
    // standing rule ("the dust has to EARN every pixel it lights") turned into
    // the one place that can enforce it.
    //
    // Where it reaches each end, in half-widths off the plane (h/halfW):
    //   n high  : 1.0 out to 1.31, first exact 0.0 at 1.92
    //   n middle: 1.0 out to 0.71, first exact 0.0 at 1.58
    //   n low   : 0.0 everywhere — a void is a void at any height
    // So the band's own structure carves its own outline, and the widest the
    // dust can EVER reach is 1.92 half-widths, along its densest filaments
    // only. The build this replaces let the filaments trail to 3.3 half-widths
    // as a brown haze over the whole frame; measured on a 1600×900 render, the
    // dust altered 99.98% of the frame by at least 1/255 and only 2.3% of it
    // was darker than 4/255. Both numbers, and the four constants here, are in
    // the brief.
    galaxyMask = smoothstep(0.20, 0.54,
                            band * (0.12 + 1.15 * smoothstep(0.26, 0.76, n)));
    // Nothing beyond this point runs in empty space — which is a real saving,
    // not only a guarantee: the five ridge fBms and the two grain lookups below
    // are over half this function's cost and the outskirts of every ray used to
    // pay them to produce a value that was then multiplied by almost nothing.
    if (galaxyMask <= 0.0) return 0.0;

    // RIBBONS, NOT FOG — this is the whole look, and it is the 2D headliner's
    // own finding ported into the volume. A soft cloud mask alone reads as
    // smoke however you colour it (proved there on render 6, and again here).
    // What the reference sky actually is: thin bright STROKES with cloud
    // hugging them, over black. So the cloud is held down to a dim wash and
    // the ridged braids carry the image.
    // NO FLOOR. A constant term across the band is a grey wash over half the
    // frame — it is exactly what stops the background being #000000. The dust
    // now has to EARN every pixel it lights: a threshold, then a power curve,
    // so it exists only in the core of the band and falls to true zero
    // everywhere else.
    float cloud = pow(band, 2.0) * pow(smoothstep(0.46, 0.88, n), 2.2);
    float fil   = ridge3(q * 2.3 + w, max(oct - 1, 2), 6.0) * band * smoothstep(0.28, 0.60, n);
    float fil2  = ridge3(q * 4.1 + w * 0.7 + 7.7, 2, 5.0) * band * smoothstep(0.34, 0.66, n);
    float fil3 = ridge3(q * 7.6 + w * 0.5 + 3.3, 2, 4.0) * band * smoothstep(0.36, 0.70, n);
    fil = fil * 0.80 + fil2 * 0.55 + fil3 * 0.34;

    // THE GOLD RIVER. The sweeping amber arcs are the signature of this
    // build's sky and they are not a tint — they are a ROPE of tangled ridge
    // strands held near the band's core, exactly as `nebula()` builds it in
    // starlight.frag. Two scales, both high-power ridges so each strand stays
    // a thin line rather than a smear, and confined to a narrower band than
    // the blue so it runs THROUGH the streams instead of alongside them.
    float riverBand = exp(-h * h / (2.0 * (halfW * 0.58) * (halfW * 0.58)));
    float s1 = ridge3(q * 1.35 + w * 1.2 + 31.7, 2, 11.0);
    float s2 = ridge3(q * 2.30 + w * 0.9 + 57.3, 2, 9.0);
    float river = smoothstep(0.22, 0.76, clamp(s1 * 0.95 + s2 * 0.60, 0.0, 1.0)) * riverBand;

    // The palette as a depth ramp through the cloud, gold only on the crests —
    // "gold as sparks only" is a standing rule, not a preference.
    // Blue-dominant on purpose. Integrating a full ramp along a long ray
    // averages toward its MIDDLE, so a ramp spread evenly across n comes out
    // uniformly lavender however saturated the individual stops are. Holding
    // teal→indigo across most of the range and keeping violet/plum as
    // late-threshold accents is what puts the blue back.
    // A wider swing through the ramp: deep indigo in the body, violet_glow
    // on the shoulders, and the crests washing to near-white. Contrast inside
    // the band is what makes it look lit from within rather than tinted.
    // THE BAR'S OWN SWEEP, in order: teal → azure → indigo → violet → plum.
    // This is `_swirl._emission.sweep` walked across the noise range, using the
    // body/accent/glow rungs rather than flat hues so the dust glows the way
    // the taskbar's paint does instead of sitting there as a tint. The owner
    // pointed at the bar and asked for these exact colours; this is them.
    vec3 col = mix(P_AZURE, P_INDIGO_BODY,  smoothstep(0.14, 0.30, n));
    col = mix(col, P_VIOLET_BODY, smoothstep(0.30, 0.46, n));
    col = mix(col, P_VIOLET_GLOW, smoothstep(0.46, 0.60, n));
    col = mix(col, P_PLUM,        smoothstep(0.58, 0.74, n));
    col = mix(col, P_PLUM_GLOW,   smoothstep(0.74, 0.92, n));
    // the cool end, held to the mid range so it reads as the sweep's start
    col = mix(col, P_AZURE_GLOW,
              smoothstep(0.18, 0.34, n) * (1.0 - smoothstep(0.42, 0.60, n)) * 0.60);
    // The braids wash toward white at their crests — a bright stroke is a
    // bright stroke, not a saturated one.
    col = mix(col, mix(P_AZURE_GLOW, vec3(1.0), 0.45), fil * 0.22);

    // Amber pushed to its saturated end so the integral cannot grey it to tan,
    // with the hottest strands going warm-white.
    // The gold river up the ladder's own rungs: body → accent → glow, with the
    // hottest strands going warm-white. Widened and strengthened on the
    // owner's call — the amber arcs are the thing he recognises this sky by.
    vec3 gold = mix(P_GOLD_BODY, P_GOLD, river * 0.55);
    gold = mix(gold, P_GOLD_GLOW, pow(river, 1.6) * 0.75);
    gold = mix(gold, vec3(1.0, 0.90, 0.62), pow(river, 3.0) * 0.55);

    // The Milky Way is not a glowing gradient — it is millions of stars too
    // small to resolve. Granulating the emission at a frequency well above the
    // cloud's own is what makes it read as packed starlight instead of smoke,
    // and it costs one noise lookup.
    float grain = 0.45 + 1.15 * vnoise3(p * 2.6);
    float grain2 = 0.55 + 0.90 * vnoise3(p * 7.5 + 19.0);

    float dens = cloud * 0.70 + fil * 0.55 + river * 0.80;

    // THE LIQUID'S OWN COLOUR, UNMASKED. Every term above still carries the
    // `band` factor it was tuned with — those are the SHAPE (the cloud is
    // tighter than the filaments, the gold river tighter than either), and a
    // shape term is always allowed to be NARROWER than the mask. What none of
    // them may be is wider, and the mask is what enforces that. Leaving the
    // tuned constants exactly as they were and adding the mask as a pure gate
    // is deliberate: it can only ever remove, so it cannot silently rebalance
    // a palette that took several passes to settle.
    liquidColor = (col * (cloud * 0.52 + fil * 3.10)) * grain * grain2
                + gold * river * 2.35 * (0.55 + 0.75 * grain);

    // The DENSITY is masked here rather than at the call site, because density
    // is what occludes: unmasked, the dust would dim stars in places it does
    // not light, and a starfield that goes quietly grey where nothing is
    // visibly in front of it is the subtlest way to lose the contrast.
    return dens * galaxyMask;
}

// ── the star lattice ─────────────────────────────────────────────────────
// Density modulation shared by every layer, sampled in WORLD space, so a
// cluster is a place in the volume that all four depth bands agree on. The
// galaxy backbone feeds it, so the stars crowd into the dust the way they do
// in the real thing.
// Deliberately only TWO octaves. This is the hottest function in the file —
// it runs once per march step per band, so ~30 times per pixel — and a third
// octave costs another eight hash lookups each time for structure that the
// occupancy roll quantises away anyway.
float clusterAt(vec3 wp) {
    float f = fbm3(wp * 0.012, 2);
    float pockets = pow(smoothstep(0.42, 0.74, f), 1.7);
    float h = dot(wp, GAL_N) - 1.5;
    float backbone = exp(-h * h / (2.0 * 30.0 * 30.0));
    // Floor low and peak moderate: the sky has to have genuine VOIDS in it.
    // The first cut floored at 0.34 and peaked near 3, which multiplied
    // through the occupancy roll to "every cell is occupied" and produced a
    // solid carpet of stars with no black left anywhere.
    return 0.16 + pockets * 1.30 + backbone * 0.85;
}

// ~24% ice-blue / ~65% white / ~11% amber at warmth 0.22 — the population the
// 2D headliner settled on after shipping a field that read entirely amber.
// warmth slides the BOUNDARIES, never the hues, so no single point can wear a
// wrong colour however far the slider goes.
vec3 spectral(float t, float warmth) {
    float wb = clamp(warmth, 0.0, 1.0);
    float bBlue  = 0.28 - wb * 0.18;
    float bAmber = 0.93 - wb * 0.20;
    if (t < bBlue)  return vec3(0.784, 0.875, 1.000);
    if (t < bAmber) return vec3(1.000, 1.000, 1.000);
    return vec3(1.000, 0.820, 0.702);
}

// One depth band of real 3D stars.
//
// Marched with EXPONENTIAL steps (t *= growth) rather than linear, because a
// linear march through a perspective volume spends most of its samples in the
// far half where the cells are sub-pixel, and starves the near half where a
// missed star is a visible hole. Exponential stepping keeps the angular volume
// per step roughly constant, which is the thing the eye actually samples.
//
// One candidate star per cell visited. The ray threads many cells, so the
// field fills; and because the star is placed in WORLD space and projected by
// exact perspective, moving the camera cannot make it swim.
vec3 starBand(mat3 lat, float cellSize, float tNear, float tFar, int steps,
              float occupancy, float angRad, float lum,
              float twinkleGate, float spikeAmt, float seed) {
    vec3 acc = vec3(0.0);
    float growth = pow(tFar / tNear, 1.0 / float(steps));
    float t = tNear;
    float density = clamp(u_scene.x, 0.0, 2.0);

    // Everything happens in the band's own LATTICE SPACE. `lat` is orthonormal,
    // so distances and angles are untouched — but the cell grid is no longer
    // aligned with the world axes, and therefore no longer aligned with the
    // screen axes. Without this every band lays its cell sheets down parallel
    // to the frame and the field reads as visible rectangular tiling.
    mat3 latT = transpose(lat);
    vec3 roL = lat * gRo, rdL = lat * gFwd;
    vec3 rightL = lat * gRight, upL = lat * gUp;

    for (int i = 0; i < 14; i++) {
        if (i >= steps) break;
        vec3 pL = roL + rdL * t;
        vec3 cell = floor(pL / cellSize);
        vec3 h = hash33(cell + seed);

        // The occupancy roll is what makes clusters and voids: the same cell
        // is always the same roll, so structure is stable under motion. The
        // cluster field is sampled back in WORLD space so a dense pocket is a
        // place every band agrees on rather than a per-band texture.
        if (h.x < occupancy * clusterAt(latT * (cell * cellSize)) * density) {
            vec3 sp = (cell + vec3(0.25) + h * 0.5) * cellSize;
            vec3 v  = sp - roL;
            float tc = dot(v, rdL);                  // depth along the view axis
            if (tc > 0.35) {
                // Perpendicular miss distance, squared, without a cross product.
                vec3 perp   = v - rdL * tc;
                float tan2  = dot(perp, perp) / (tc * tc);

                // Fade the wide terms out before the CELL EDGE. A halo is
                // wider than the cell that owns it, and the ray only ever
                // samples one cell per step, so an unwindowed halo is cut dead
                // straight at the cell boundary — which is exactly the
                // rectangular tiling the first dense cut showed. The core is
                // left unwindowed: it is far smaller than a cell and sits near
                // its centre, so it never reaches an edge to be clipped at.
                vec3 lp = fract(pL / cellSize) - 0.5;
                vec3 eg = vec3(0.5) - abs(lp);
                float win = smoothstep(0.0, 0.17, min(min(eg.x, eg.y), eg.z));

                // Per-star identity from its own cell hash.
                float sizeSeed = h.y;
                float curve = sizeSeed * sizeSeed * sizeSeed * sizeSeed;  // ^4 power law
                // THE 75/25 LAY-UP. A real headliner is not one gauge of
                // fibre: three quarters of the field is microscopic dust that
                // only registers as texture, and the last quarter is the thick
                // cable that actually reads as a star. An unbroken power law
                // gives a smooth continuum instead, which averages out to
                // "uniformly bright" at a glance — it is the GAP between the
                // tiers that the eye reads as depth, so the split is explicit.
                float tierRoll = hash11(h.y * 37.0 + seed);
                float bigTier  = step(0.75, tierRoll);
                float L  = lum * mix(0.22, 1.10, curve) * mix(0.40, 3.60, bigTier);

                // A STAR IS A POINT SOURCE. Its apparent size is set by the
                // aperture you are looking through, not by how far away it is —
                // only its BRIGHTNESS falls with range. Sizing it as
                // radius/distance instead (the obvious thing, and what the
                // first cut did) collapses every distant band to sub-pixel, so
                // the deep field silently renders nothing and the sky comes out
                // sparse no matter how high the occupancy is set. This is the
                // same class of units bug the 2D headliner inherited from its
                // own reference and had to be dug out of it.
                float ar = angRad * mix(0.62, 1.10, curve) * mix(0.78, 1.75, bigTier);

                // Scintillation: two octaves of value noise, never a sine. A
                // sine reads as clockwork inside ten seconds — this is the one
                // finding from the 2D shader that transfers unchanged.
                float tSeed = h.z * 133.7;
                float sp1 = mix(0.05, 0.17, h.z) * u_look.x * mix(1.0, 2.2, clamp(L, 0.0, 1.0));
                float n1 = noise1D(u_time * sp1 * 2.3 + tSeed);
                float n2 = noise1D(u_time * sp1 * 5.9 + tSeed * 1.7 + 31.0);
                float tw = mix(1.0, clamp(n1 * 0.65 + n2 * 0.35, 0.0, 1.0), twinkleGate);

                // Inverse-square, normalised to the band's near plane so each
                // band arrives pre-balanced and the tonemap is not asked to
                // reconcile a 10⁴ range.
                float falloff = (tNear * tNear) / (tc * tc);
                float amp = L * falloff * mix(0.30, 1.0, tw);

                float sig = max(ar, 0.00035);
                // CRYSTAL, NOT BLOB. A gaussian has no hard edge — its skirt
                // is what reads as a soft anti-aliased circle no matter how
                // small sigma gets. A steep power falloff dies to nothing
                // within ~2.5 sigma, so the core saturates to a blinding point
                // and the edge is instant. `dn` is the miss distance measured
                // in sigmas, which keeps this resolution-independent.
                float dn = sqrt(tan2) / sig;
                float core = pow(max(1.0 - dn * 0.40, 0.0), 6.0) * 5.4;
                // Halo held down to 0.09: the reference sky's points are CRISP
                // — a bright pinprick with almost no skirt. A generous halo is
                // what turns a starfield soft and grey at density.
                float halo = exp(-tan2 / (2.0 * (sig * 2.6) * (sig * 2.6)))
                             * 0.055 * clamp(L, 0.0, 1.0) * win;

                // BLOOM, and it is the thing that was missing. Real optics
                // scatter bright light across the field — without it a sky can
                // be perfectly sharp and still read flat, because nothing in it
                // behaves like it is actually BRIGHT. Gated hard on luminosity
                // so only the rare beacons bloom: applied to every star it
                // would just be the soft grey skirt we spent two passes
                // removing. σ×7 is ≈8 px at 1080p, far inside the cell, so the
                // existing window never clips it.
                float bloomAmt = smoothstep(0.85, 2.4, L);
                // CAP THE BLOOM TO ITS OWN CELL. A gaussian only looks like a
                // glow while it is allowed to finish; the ray samples exactly
                // one cell per step, so any lobe still carrying energy at the
                // cell boundary gets cut there by the window — and because the
                // boundary of a 3D cell is a box, what you see is bloom
                // clipped into hard SQUARES and TRIANGLES. (Visible instantly
                // in stars-only mode, which is why that variant found it and
                // the full scene never did — the dust was covering it.)
                // Capping each radius to a fraction of the cell's angular size
                // guarantees the lobe has died before it reaches an edge.
                float cellAng = cellSize / tc;
                float bR  = min(sig *  7.0, cellAng * 0.13);
                float bR2 = min(sig * 18.0, cellAng * 0.26);
                float bloom = exp(-tan2 / (2.0 * bR * bR))
                              * 0.22 * bloomAmt * win;
                float bloomWide = exp(-tan2 / (2.0 * bR2 * bR2))
                              * 0.075 * bloomAmt * win;

                vec3 col = spectral(hash11(h.x * 77.7), u_look.z);
                col = mix(col, vec3(1.0), tw * 0.35);

                float total = core + halo + bloom + bloomWide;

                // Diffraction spikes, oriented in SCREEN space — they are an
                // artefact of the aperture you are looking through, so they do
                // not rotate with the star, they rotate with the windshield.
                if (spikeAmt > 0.0 && L > 0.42) {
                    float sx = dot(perp, rightL) / tc;
                    float sy = dot(perp, upL) / tc;
                    float sw = max(sig * 0.16, 0.00012);
                    float sl = sig * 16.0;
                    float sh = exp(-abs(sy) / sw) * exp(-abs(sx) / sl);
                    float sv = exp(-abs(sx) / sw) * exp(-abs(sy) / sl);
                    total += (sh + sv) * spikeAmt * 0.52 * win;
                    // A second, longer and finer pair at 45° on the very
                    // brightest — four points is a flare, eight is a starburst.
                    if (L > 1.15) {
                        float dx = (sx + sy) * 0.7071, dy = (sy - sx) * 0.7071;
                        float dh = exp(-abs(dy) / (sw * 0.8)) * exp(-abs(dx) / (sl * 1.7));
                        float dv = exp(-abs(dx) / (sw * 0.8)) * exp(-abs(dy) / (sl * 1.7));
                        total += (dh + dv) * spikeAmt * 0.30 * win;
                    }
                    // One-texel chromatic split at the spike tips: a real
                    // aperture disperses, and the eye reads that as glass.
                    acc += (vec3(1.10, 0.98, 0.88) * sh + vec3(0.86, 0.96, 1.14) * sv)
                           * spikeAmt * 0.10 * win * L;
                }
                acc += col * total * amp;
            }
        }
        t *= growth;
    }
    return acc;
}

// The fourth layer: infinite-distance background radiation. It has NO
// parallax by construction — it is sampled on direction alone, which is what
// "infinitely far" means. Getting this wrong (giving it a large but finite
// depth) is what makes a starfield feel like a box you are inside.
vec3 cosmicBackground(vec3 rd) {
    // A POINT INSIDE THE CELL, not the whole cell. Hashing a direction cell
    // and returning one value for all of it paints a solid SQUARE the size of
    // the cell — which at 420 cells across is a visible grid of little grey
    // boxes over the whole sky. Placing a jittered point and falling off from
    // it gives a round sub-pixel star, which is what this layer is meant to be.
    vec3 sc = rd * 1100.0;
    vec3 c = floor(sc);
    vec3 h = hash33(c + 7.0);
    vec3 rel = fract(sc) - 0.5 - (h - 0.5) * 0.66;
    float grain = smoothstep(0.972, 1.0, h.x) * exp(-dot(rel, rel) * 26.0);
    vec3 col = spectral(h.y, u_look.z);
    // a faint, cold wash that thickens toward the galaxy plane
    float hgt = dot(rd, GAL_N);
    // The wash used to be a flat 0.02 everywhere the band was — a grey veil
    // over the whole diagonal. Powered hard so it is a hint at the core only.
    // AND IT REACHES EXACT ZERO. An exponential never does: however hard this
    // is powered it leaves a real, non-zero value in EVERY pixel of the frame,
    // and this shader's last three stages — an exposure curve, a 1.42×
    // saturation push and a toe — are all lifts applied to exactly that kind of
    // residue. It was measurably the reason no pixel in the old frame was
    // #000000. Subtracting the floor and renormalising costs one op and makes
    // the claim true: past ≈0.44 off the plane in direction-space, this is 0.0
    // and the background is the black the pinpricks are measured against.
    float washProf = pow(exp(-hgt * hgt * 5.0), 4.0);
    float wash = max(washProf - 0.02, 0.0) * (1.0 / 0.98)
                 * 0.010 * step(0.5, u_flags.y);
    return col * grain * 0.13 + mix(P_TEAL_DEEP, P_INDIGO, h.z) * wash;
}

// ── voronoi, for the urban plating ───────────────────────────────────────
// F1, F2 and the winning cell's hash. F2−F1 is the plate seam; the cell hash
// picks which colour off the ramp that plate was sprayed.
// `toF1` is the vector from the sample to the winning feature point. Craters
// need it: the rim of a bowl tilts AWAY from its centre, so a crater normal
// has to know which way the centre is. Without it the only honest options are
// a random per-cell tilt (reads as noise) or a flat plate (reads as a facet),
// and the plates are exactly what made the first moons look like cut gems.
vec3 voronoi3(vec3 p, out vec3 toF1) {
    vec3 ip = floor(p), fp = fract(p);
    float f1 = 8.0, f2 = 8.0, id = 0.0;
    toF1 = vec3(0.0);
    for (int k = -1; k <= 1; k++)
    for (int j = -1; j <= 1; j++)
    for (int i = -1; i <= 1; i++) {
        vec3 g = vec3(float(i), float(j), float(k));
        vec3 o = hash33(ip + g);
        vec3 r = g + o - fp;
        float d = dot(r, r);
        if (d < f1) { f2 = f1; f1 = d; id = hash13(ip + g); toF1 = r; }
        else if (d < f2) { f2 = d; }
    }
    return vec3(sqrt(f1), sqrt(f2), id);
}

// ── the bodies ───────────────────────────────────────────────────────────
// Three exact spheres. `min` of exact distance fields is a conservative
// distance field, so sphere tracing over it is safe at full step length.
float sdSphere(vec3 p, vec3 c, float r) { return length(p - c) - r; }

// Moon radii as fractions of the planet, named once so `mapScene` (which
// decides the silhouette) and `shadeBody` (which decides the texture scale)
// can never disagree about how big a moon is.
// Small, because they are FAR. `moonCentre` sets them well behind the planet
// (+16 and +30 in z against its 17), so they read as distant companions rather
// than two more objects sharing the planet's depth — which is what made the
// first cut feel flat despite being genuinely 3D.
const float MOON_A_R = 0.36;
const float MOON_B_R = 0.27;

vec3 moonCentre(int which) {
    // Slow, non-commensurate orbits — two moons on periods with an irrational
    // -ish ratio never fall into a repeating pattern the eye can learn.
    float t = u_time * 0.05;
    if (which == 0) {
        float a = t * 0.62 + 0.9;
        return gPlanetC + vec3(cos(a) * 9.0, sin(a) * 2.2 + 3.6, sin(a) * 4.0 + 16.0);
    }
    float b = -t * 0.41 + 3.1;
    return gPlanetC + vec3(cos(b) * 14.0, sin(b) * 3.0 - 3.2, sin(b) * 6.0 + 30.0);
}

// id: 1 planet · 2 moon A · 3 moon B
float mapScene(vec3 p, out int id) {
    float d = sdSphere(p, gPlanetC, gPlanetR);
    id = 1;
    float m0 = sdSphere(p, moonCentre(0), gPlanetR * MOON_A_R);
    if (m0 < d) { d = m0; id = 2; }
    float m1 = sdSphere(p, moonCentre(1), gPlanetR * MOON_B_R);
    if (m1 < d) { d = m1; id = 3; }
    return d;
}

vec3 sceneNormal(vec3 p) {
    // Tetrahedral offsets: four map() calls instead of the naive six.
    const vec2 e = vec2(1.0, -1.0) * 0.0015;
    int t;
    return normalize(e.xyy * mapScene(p + e.xyy, t) + e.yyx * mapScene(p + e.yyx, t) +
                     e.yxy * mapScene(p + e.yxy, t) + e.xxx * mapScene(p + e.xxx, t));
}

// Soft analytic shadow of a sphere on a light ray. No marching: the closest
// approach of the ray to the centre is a dot product, and the penumbra is a
// smoothstep across the limb.
float sphereShadow(vec3 q, vec3 L, vec3 c, float r) {
    vec3 oc = c - q;
    float tc = dot(oc, L);
    if (tc < 0.0) return 1.0;                       // the body is behind us
    float d = sqrt(max(dot(oc, oc) - tc * tc, 0.0));
    return smoothstep(r * 0.88, r * 1.22, d);
}

// ── the rings ────────────────────────────────────────────────────────────
// Density at a point already known to be in the ring plane's neighbourhood.
// Keplerian shear: the inner bands orbit faster than the outer ones, by
// ω ∝ r^-3/2. This is the real law and it costs one divide — and it is the
// whole reason the rings read as orbiting matter rather than a spinning
// texture. A rigid rotation looks like a painted disc within a few seconds.
float ringDensity(vec3 q, float rIn, float rOut) {
    vec3 rel = q - gPlanetC;
    vec3 inPlane = rel - gRingN * dot(rel, gRingN);
    float r = length(inPlane);
    if (r < rIn || r > rOut) return 0.0;

    float u = (r - rIn) / (rOut - rIn);

    // Concentric band structure — depends on r ALONE, so it needs no angle
    // and therefore no trig at all. This carries most of the look.
    // Narrower thresholds and a third, finer octave: ring structure is
    // hard-edged in reality (shepherd moons cut it), and a wide smoothstep is
    // what made the first rings read as smooth cream rather than metal.
    float bands = fbm3(vec3(u * 34.0, 0.0, 0.0), 4);
    float fine  = fbm3(vec3(u * 96.0, 7.3, 0.0), 3);
    float ultra = fbm3(vec3(u * 240.0, 3.1, 0.0), 2);
    float dens = smoothstep(0.42, 0.60, bands * 0.62 + fine * 0.26 + ultra * 0.12);

    // Carve a Cassini-style division and hard-taper both limbs.
    dens *= 1.0 - 0.92 * exp(-pow((u - 0.44) * 26.0, 2.0));
    dens *= smoothstep(0.0, 0.07, u) * (1.0 - smoothstep(0.86, 1.0, u));

    // Azimuthal clumping, sheared. One sin/cos pair per sample, and only here —
    // the in-plane basis itself is built once in main(), not per sample.
    float shear = u_time * 0.55 / (r * sqrt(r) * 0.06);
    vec2 pl = rot2(shear) * vec2(dot(inPlane, gRingU), dot(inPlane, gRingV));
    dens *= 0.72 + 0.55 * fbm3(vec3(pl * 0.20, u * 6.0), 3);

    return clamp(dens, 0.0, 1.0);
}

// The rings' shadow ON the planet: from a surface point, walk to the light,
// find where that path crosses the ring plane, and ask the rings how opaque
// they are there. Exactly one ring sample — analytic, not marched.
float ringShadowOnBody(vec3 P, float rIn, float rOut) {
    float denom = dot(gLight, gRingN);
    if (abs(denom) < 1e-4) return 1.0;
    float tp = dot(gPlanetC - P, gRingN) / denom;
    if (tp <= 0.0) return 1.0;                      // the plane is behind the light
    vec3 X = P + gLight * tp;
    return 1.0 - 0.80 * ringDensity(X, rIn, rOut);
}

// ── shading the bodies ───────────────────────────────────────────────────
// "Urban / synth-graffiti" against a photoreal sky: the plates are flat-filled
// off the theme ramp with lit seams, but they are lit by the SCENE — the same
// lambert, the same terminator, the same ring shadow as any other surface. The
// contrast the owner asked for comes from the texture being stylised, not from
// the object ignoring its own light.
vec3 shadeBody(vec3 P, vec3 N, int id, float rIn, float rOut) {
    // WHY THIS IS NOT A GRID OF COLOURED PLATES ANY MORE.
    //
    // The first cut tiled the whole globe in voronoi plates and filled each one
    // from the palette. On screen that is a cut gem, not a world — because
    // every cue that says "sphere with a surface" was being overwritten by a
    // texture of uniform scale and uniform contrast. Three things carry a
    // planet, and none of them is the texture:
    //
    //   1. AN ATMOSPHERE AT THE LIMB. A lit rim of scattered light around the
    //      edge is the single strongest cue there is, and no amount of surface
    //      detail substitutes for it.
    //   2. LARGE-SCALE FEATURES. Continents an order of magnitude bigger than
    //      the detail. Uniform cell size is what reads as "faceted".
    //   3. DETAIL SUBORDINATE TO THE SPHERE. The lighting has to win; the
    //      texture modulates it.
    //
    // The urban idea survives, and reads better for being literal: cities are
    // SMALL, they cluster on landmasses, and at night their grids glow. That
    // is genuinely a city seen from orbit rather than a ball wrapped in neon.
    bool isPlanet = (id == 1);
    float bodyR = gPlanetR * (isPlanet ? 1.0 : (id == 2 ? MOON_A_R : MOON_B_R));
    vec3 rel = P - (isPlanet ? gPlanetC : moonCentre(id - 2));
    float spin = u_time * (isPlanet ? 0.035 : 0.09);
    vec3 tp = rel;
    tp.xz = rot2(spin) * tp.xz;
    vec3 unit = tp / bodyR;

    float ndlGeo = dot(N, gLight);
    float shadow = isPlanet ? ringShadowOnBody(P, rIn, rOut)
                            : sphereShadow(P, gLight, gPlanetC, gPlanetR);
    float night = smoothstep(0.10, -0.28, ndlGeo);

    vec3 albedo;
    vec3 emissive = vec3(0.0);
    vec3 Nb = N;

    if (isPlanet) {
        // ── A GAS GIANT, not a world with coastlines ─────────────────────
        // Continents plus night-side city lights is a picture of Earth, and
        // Earth is the one thing this was asked not to be. A banded giant is
        // alien, it is what a ring system belongs to anyway, and it keeps the
        // part that was working: real structure with something lit under it.
        //
        // Bands are LATITUDE displaced by turbulence. Straight latitude lines
        // read as a beach ball and plain 3D noise reads as marble; a
        // turbulence-warped latitude is what gives the sheared, flowing look
        // that says "atmosphere in motion".
        float turb  = fbm3(unit * 2.6 + 7.0, 4);
        float lat   = unit.y * 4.2 + (turb - 0.5) * 1.55;
        float bandV = fbm3(vec3(lat * 2.3, 3.7, 1.3), 4);
        float fine  = fbm3(unit * 9.5 + turb * 1.6, 3);

        // The build's own ramp: deep rungs for the belts, glow rungs for the
        // zones, so the planet is one sweep of the palette rather than a set
        // of unrelated colours that merely came from it.
        vec3 belt = mix(P_INDIGO * 0.11, P_TEAL_DEEP * 0.42, smoothstep(0.28, 0.52, bandV));
        belt = mix(belt, P_TEAL * 0.30, smoothstep(0.50, 0.70, bandV));
        belt = mix(belt, P_VIOLET_GLOW * 0.30, smoothstep(0.70, 0.88, bandV));
        albedo = belt * (0.80 + 0.55 * fine);

        // ── the street-art layer ─────────────────────────────────────────
        // The stylisation the brief actually asked for, and the reason it can
        // sit on a gas giant without turning it back into a disco ball: the
        // cells are QUANTISED (five palette steps, hard edges) and they are
        // masked by the band flow, so they read as sharp vector shapes painted
        // ALONG the atmosphere rather than a skin wrapped over the whole
        // sphere. The bands still carry the form; this carries the attitude.
        vec3 toC;
        vec3 gv = voronoi3(unit * 5.2, toC);
        float quant = floor(hash11(gv.z * 7.0) * 5.0) * 0.25;      // 5 hard steps
        float painted = step(0.38, hash11(gv.z * 3.1)) * smoothstep(0.30, 0.62, bandV);
        vec3 spray = mix(P_INDIGO * 0.30, P_TEAL * 0.55, quant);
        spray = mix(spray, P_VIOLET_GLOW * 0.62, smoothstep(0.55, 1.0, quant));
        // NOTE: `unit` is the surface point in BODY space, spun about the
        // planet's own axis, so this voronoi is a genuine 3D SOLID texture —
        // it wraps the sphere with no seam and no pole pinching, and it holds
        // its shape when the camera tilts because it is anchored to the body
        // rather than to the screen. Nothing here is a flat overlay.
        albedo = mix(albedo, spray, painted * 0.42);
        // hard vector edge — a single smoothstep wide, so it stays a LINE
        float gEdge = 1.0 - smoothstep(0.0, 0.022, gv.y - gv.x);
        emissive += P_GOLD_GLOW * gEdge * painted * (0.16 + 0.75 * night) * 0.55;

        // Storms: discrete ovals riding the bands, warm and bright.
        float storm = smoothstep(0.74, 0.93,
                                 fbm3(unit * 3.4 + vec3(0.0, lat * 0.2, 0.0) + 21.0, 4));
        albedo = mix(albedo, P_GOLD_GLOW * 0.42, storm * 0.60);

        // ── the something on the inside ──────────────────────────────────
        // Hot interior showing through where the cloud deck thins. Keyed to
        // the DARK side of the band field so it glows OUT OF THE GAPS between
        // the belts rather than sitting on top of them — that reading is the
        // whole difference between "lit from within" and "painted on".
        float gaps = pow(1.0 - smoothstep(0.10, 0.46, bandV), 2.2);
        float veins = ridge3(vec3(lat * 3.2, unit.x * 1.3, unit.z * 1.3), 3, 5.5);
        emissive += mix(P_GOLD, P_GOLD_GLOW, veins) * gaps * (0.55 + 1.05 * veins) * 0.90;
        emissive += P_VIOLET_GLOW * storm * (0.20 + 0.55 * night) * 0.55;
        emissive += P_GOLD * gaps * night * 0.35;

        // Cloud relief along the flow, gentle — the lighting stays in charge.
        Nb = normalize(N + (fine - 0.5) * 0.22
                           * normalize(cross(N, vec3(0.0, 1.0, 0.11))));
    } else {
        // ── craters ──────────────────────────────────────────────────────
        // A bowl with a raised rim, built from the distance to the cell's
        // feature point. `toC` points at the centre, so the surface tilts away
        // from it on the way down and back toward it on the rim — which is
        // what a crater IS, and why voronoi3 now returns that vector.
        // TWO CRATER SCALES. One scale of anything reads as a pattern; a real
        // cratered body is a few big basins with a fine pox of small strikes
        // over and INSIDE them, and it is that scale mixture the eye reads as
        // "surface" rather than "texture". The small pass is half-weight so it
        // detailing the big one instead of competing with it.
        vec3 toC, toC2;
        vec3 vor  = voronoi3(unit * 7.0, toC);
        vec3 vor2 = voronoi3(unit * 19.0, toC2);
        float d = vor.x;
        float bowl = smoothstep(0.34, 0.0, d);            // 1 at centre
        float rimBand = exp(-pow((d - 0.28) * 10.0, 2.0));
        float bowl2 = smoothstep(0.30, 0.0, vor2.x);
        float rim2  = exp(-pow((vor2.x - 0.26) * 11.0, 2.0));

        // steepest where the wall is, flat at the floor and outside
        float slope  = bowl  * (1.0 - bowl)  * 4.0;
        float slope2 = bowl2 * (1.0 - bowl2) * 4.0;
        vec3 outward  = normalize(-toC  - N * dot(-toC,  N) + 1e-5);
        vec3 outward2 = normalize(-toC2 - N * dot(-toC2, N) + 1e-5);
        Nb = normalize(N + outward * slope * 0.80 + outward2 * slope2 * 0.38
                         - N * rimBand * 0.05);

        // Lifted well off black: these are backlit, so without a real albedo
        // there is nothing for the fill light to find and they render as two
        // holes in the starfield. Cool grey with the build's teal in the
        // shadow side, so they still belong to this sky.
        vec3 regolith = mix(vec3(0.150, 0.156, 0.180), vec3(0.265, 0.252, 0.268),
                            fbm3(unit * 4.0 + 9.0, 3));
        regolith = mix(regolith, P_TEAL_DEEP * 0.55, 0.20);
        albedo = regolith * (0.80 + 0.50 * rimBand + 0.22 * rim2
                             - 0.32 * bowl - 0.16 * bowl2);
        // dust rays thrown out of the freshest craters
        float rays = pow(max(1.0 - vor.x * 2.2, 0.0), 3.0)
                     * step(0.86, hash11(vor.z * 17.0));
        albedo += vec3(0.10, 0.104, 0.115) * rays;

        // A handful of lit outposts, so the moons belong to the same world as
        // the planet without being wrapped in neon.
        float outpost = step(0.955, hash11(vor.z * 29.0));
        emissive += mix(P_TEAL_GLOW, vec3(0.85, 0.96, 1.0), 0.35)
                    * outpost * (1.0 - bowl) * (0.10 + 1.5 * night) * 0.55;
    }

    float ndl = dot(Nb, gLight);
    float lam = max(ndl, 0.0);
    float wrap = max(ndl * 0.5 + 0.5, 0.0);               // soft terminator

    // A little galaxy-coloured fill so an unlit limb is dark, not a hole cut
    // in the sky — the band behind these bodies is a real light source.
    vec3 ambient = mix(P_INDIGO_GLOW, P_TEAL, 0.55) * (isPlanet ? 0.055 : 0.115);
    // A touch of contrast on the key: pow() on lambert steepens the
    // terminator, which is what makes a crescent read as a cut edge rather
    // than a gradient — the difference between dramatic and merely dark.
    vec3 lit = albedo * (pow(lam, 0.78) * 1.85 * shadow + wrap * 0.05)
             + albedo * ambient * 2.2;
    lit += emissive * mix(1.0, shadow, 0.5);

    // ── the limb ─────────────────────────────────────────────────────────
    float fres = 1.0 - max(dot(N, -gFwd), 0.0);
    if (isPlanet) {
        // Atmosphere. Brightest where the air is lit, so it wraps the day side
        // and thins into the night — cue 1, and the reason this reads as a
        // planet at all.
        // WRAP, not lambert. Air scatters light round the limb, so it is still
        // glowing well past the terminator — keying the rim on `lam` (which is
        // zero across the whole visible disc when the star is behind) is what
        // left the planet a flat black cut-out on the first backlit render.
        float atmoWrap = max(ndlGeo * 0.45 + 0.55, 0.0);
        vec3 sky = mix(P_TEAL, P_INDIGO_GLOW, 0.42);
        lit += sky * pow(fres, 4.0) * (0.06 + 1.55 * atmoWrap * shadow);
        // The star is behind the planet, so the limb is lit THROUGH the air —
        // the sunrise-from-orbit ring. Forward scatter, so it is warm and it
        // is brightest exactly at the edge.
        lit += mix(vec3(1.0, 0.86, 0.62), P_GOLD_GLOW, 0.55) * pow(fres, 9.0)
               * (0.20 + 1.7 * atmoWrap) * 0.95;
    } else {
        // Airless, so no glow — but a backlit moon still catches a hard bright
        // CRESCENT on the limb that faces the star, and that thin line is the
        // only thing separating "a moon" from "a hole in the starfield".
        float crescent = pow(max(ndlGeo * 0.5 + 0.5, 0.0), 3.0) * pow(fres, 2.2);
        lit += mix(vec3(1.0, 0.94, 0.86), P_GOLD_GLOW, 0.30) * crescent * 1.30;
        lit += mix(P_INDIGO_GLOW, P_TEAL, 0.5) * pow(fres, 4.0) * 0.30;
    }

    return lit;
}

void main() {
    vec2 res = max(u_resolution, vec2(1.0));
    vec2 uv = (qt_TexCoord0 - 0.5) * vec2(res.x / res.y, 1.0);
    uv.y = -uv.y;                       // +y up; the band and the light need real "down"

    float quality = clamp(u_scene.w, 0.35, 1.0);
    int galSteps  = int(mix(8.0,  float(GAL_STEPS),  quality));
    int ringSteps = int(mix(5.0,  float(RING_STEPS), quality));
    // 4, not 5. The fifth octave of the cloud field lands well under a pixel
    // at every distance the band is actually integrated over, so it costs a
    // full eight-corner lookup per sample to modulate nothing you can see.
    int galOct    = int(mix(3.0,  5.0,               quality));
    int starSteps = int(mix(6.0,  12.0,              quality));

    // ── the camera ───────────────────────────────────────────────────────
    // A slow forward drift with a lateral sway. The eye is the drift; the
    // mouse is a HEAD TILT on top of it, and it moves both the origin and the
    // direction — direction alone is a pan (the scene rotates rigidly and
    // reads as a skybox), origin alone is a dolly (the near stars slide but
    // you are not looking anywhere new). Doing both is what makes it feel like
    // leaning toward the glass.
    // SLOW. A wallpaper is looked at for hours, not seconds — motion you can
    // catch yourself watching is motion that is too fast. The forward rate is
    // a third of the first cut's and the sway is gentler with it, so the
    // parallax still reads on the near stars without the frame ever feeling
    // like it is going anywhere in a hurry.
    float t = u_time * clamp(u_scene.y, 0.0, 4.0);
    vec3 drift = vec3(sin(t * 0.026) * 2.2, cos(t * 0.019) * 1.3, t * 1.10);
    // MOUSE TILT REMOVED on the owner's call. `u_mouse` is still plumbed all
    // the way through (QML property → uniform → here) so re-enabling it is one
    // line rather than a rebuild of the camera, but it contributes nothing:
    // the drift alone is the motion now. The QML also stops claiming an input
    // region when the tilt is off, which restores `mask: Region {}` and with it
    // the guarantee that the wallpaper can never take a click.
    vec2 m = vec2(0.0);

    gRo = drift + vec3(m.x * 1.30, m.y * 0.85, 0.0);

    vec3 fwd = normalize(vec3(sin(t * 0.019) * 0.05 + m.x * 0.10,
                              sin(t * 0.014) * 0.035 + m.y * 0.075,
                              1.0));
    gRight = normalize(cross(vec3(0.0, 1.0, 0.0), fwd));
    gUp    = cross(fwd, gRight);
    gFwd   = fwd;

    const float FOCAL = 1.35;
    vec3 rd = normalize(uv.x * gRight + uv.y * gUp + FOCAL * gFwd);
    // Every star band measures depth along gFwd; using the per-pixel ray as
    // that axis is what keeps the projection exact, so swap it in now.
    vec3 axis = gFwd;
    gFwd = rd;

    // BACKLIT, and this is the composition decision the whole scene turns on.
    // Lighting the bodies from the camera's side flattens them: the full disc
    // is day, there is no terminator, the city lights never show and the rings
    // are just pale. Putting the star BEHIND the scene (+z, away from the eye)
    // buys all of it at once — a crescent on the limb, a night side with its
    // cities lit, a blazing atmospheric rim, and rings that glow because you
    // are now looking THROUGH them at their own light source.
    gLight = normalize(vec3(-0.70, 0.32, 0.60));

    // Placed off the galaxy's diagonal on purpose: the band runs lower-left to
    // upper-right, so the planet sits low-right and the moons swing above it.
    gPlanetR = 3.0;
    gPlanetC = drift + vec3(5.4, -2.6, 23.5);   // further out, on the owner's call
    gRingN   = normalize(vec3(0.26, 0.90, 0.35));
    gRingU   = normalize(cross(gRingN, vec3(0.0, 0.0, 1.0)));
    gRingV   = cross(gRingN, gRingU);
    float rIn  = gPlanetR * 1.38;
    float rOut = gPlanetR * 2.45;

    // ── 1 · the SDF march ────────────────────────────────────────────────
    // The only loop given the full step count, and it breaks on both ends.
    // SCENE MODES. `u_flags.x` drops the planet, its rings and both moons;
    // `u_flags.y` drops the dust. Stars-only is not merely the same picture
    // with things hidden — it skips the SDF march AND the volumetric march
    // entirely, which is most of the shader's cost, so the lock screen gets a
    // sky that is both simpler and several times cheaper than the desktop's.
    bool wantBodies = u_flags.x > 0.5;
    bool wantGalaxy = u_flags.y > 0.5;

    float tHit = -1.0;
    int hitId = 0;
    if (wantBodies) {
        float tt = 0.4;
        for (int i = 0; i < SDF_STEPS; i++) {
            int id;
            vec3 p = gRo + rd * tt;
            float d = mapScene(p, id);
            if (d < SDF_EPS * tt) { tHit = tt; hitId = id; break; }
            tt += d;
            if (tt > SDF_FAR) break;
        }
    }
    float tMax = (tHit > 0.0) ? tHit : SDF_FAR;

    // ── 2 · the galaxy, integrated front to back ─────────────────────────
    // MARCHED BEFORE THE STARS, and the order is the point. The dust is in
    // FRONT of most of the star field, so it has to be integrated first for
    // the stars to be able to shine THROUGH it — see the extinction note
    // below. Nothing here reads the stars, so moving it costs nothing.
    vec3 galC = vec3(0.0);
    float galA = 0.0;
    // EXTINCTION, PER CHANNEL AND PER DEPTH. This is the thing that stops the
    // stars and the swirls looking like two effects on one screen, and it is
    // physics rather than a filter: interstellar dust does not merely dim what
    // is behind it, it REDDENS it, because a grain scatters blue light far
    // more readily than red. The coefficients are the λ⁻¹ reddening law
    // normalised at green — a star seen through the band loses ~1.9× as much
    // blue as red — which is why a real Milky Way photograph has amber stars
    // banked along the dust lanes and icy ones out in the clear.
    //
    // And PER DEPTH, which the single (1 − galA) this replaces could not do:
    // a foreground star at t = 8 is in front of nearly all the dust and must
    // punch through clean, while the deep field at t = 300 sits behind the
    // whole band. One transmittance for all of them dimmed the near stars with
    // dust that is physically behind them. The three snapshots are taken at
    // each star band's geometric-mean depth, √(near·far).
    const vec3  EXT_RGB    = vec3(0.72, 1.00, 1.34);
    const float STAR_MID_1 =   9.5;   // √(3 · 30)
    const float STAR_MID_2 =  62.0;   // √(30 · 130)
    const float STAR_MID_3 = 270.0;   // √(130 · 560)
    vec3 starTrans = vec3(1.0);                       // to the far plane
    vec3 tS1 = vec3(1.0), tS2 = vec3(1.0), tS3 = vec3(1.0);
    {
        float trans = 1.0;
        float t0 = 4.0;
        // The dust runs to ITS OWN far plane, not the bodies' — clipped only
        // where a body actually blocks it.
        float galFar = (tHit > 0.0) ? min(tHit, GAL_FAR) : GAL_FAR;
        float gain = clamp(u_scene.z, 0.0, 3.0);
        if (wantGalaxy && galFar > t0 * 1.2) {
            float growth = pow(galFar / t0, 1.0 / float(galSteps));
            float tt = t0;
            for (int i = 0; i < GAL_STEPS; i++) {
                if (i >= galSteps) break;
                float next = tt * growth;
                float seg = next - tt;
                vec3 liquidColor;
                float galaxyMask;
                float dens = galaxyMedium(gRo + rd * (tt + seg * 0.5), tt, galOct,
                                          liquidColor, galaxyMask);
                if (dens > 0.001) {
                    // 0.0035 is an OPTICAL DEPTH per unit length, and it is the
                    // number that decides whether the sky stays black. Along the
                    // band a ray accumulates ≈0.3 × 700 × 0.0035 ≈ 0.8 — bright
                    // and structured; across it, a twentieth of that. Raise this
                    // and the band stops being a band.
                    float a = clamp(dens * seg * 0.0035, 0.0, 1.0);

                    // ── THE BLEND ────────────────────────────────────────
                    // The whole contract of this file's galaxy, on one line.
                    // `liquidColor` is the swirl's emission as if it went on
                    // for ever; `galaxyMask` is 1 in the band's core, tapers
                    // at its edge and is EXACTLY 0 in empty space. Their
                    // product cannot be non-zero where the band is not, so the
                    // fluid is bound to the band's geometry by arithmetic
                    // rather than by a tuned threshold that a later palette
                    // pass could walk back out of range.
                    vec3 maskedGalaxy = liquidColor * galaxyMask;

                    galC += maskedGalaxy * a * trans * gain;
                    galA += a * trans * 0.35;   // the dust only partly occludes
                    // The same 0.35 coverage, split across the three channels.
                    // At the green coefficient of 1.0 this is arithmetically
                    // the (1 − galA) it replaces, so the neutral brightness of
                    // the field is unchanged and only its COLOUR through the
                    // dust moves.
                    starTrans *= 1.0 - clamp(a * trans * 0.35 * EXT_RGB, 0.0, 1.0);
                    trans *= 1.0 - a;
                    // Front-to-back and monotone, so "the last value written
                    // before crossing" is the transmittance at that depth.
                    if (next <= STAR_MID_1) tS1 = starTrans;
                    if (next <= STAR_MID_2) tS2 = starTrans;
                    if (next <= STAR_MID_3) tS3 = starTrans;
                    if (trans < 0.02) break;    // early out
                }
                tt = next;
            }
        }
        galA = clamp(galA, 0.0, 1.0);
    }

    // ── 3 · what is behind the dust ──────────────────────────────────────
    vec4 behind;
    if (tHit > 0.0) {
        vec3 P = gRo + rd * tHit;
        // The march above was clipped at tHit, so every gram of dust it
        // accumulated is genuinely in front of this surface.
        behind = vec4(shadeBody(P, sceneNormal(P), hitId, rIn, rOut) * starTrans, 1.0);
    } else {
        // Four depth bands. Foreground is sparse, near, large and fully
        // twinkling with spikes; each band out is denser, smaller and calmer,
        // until the infinite one has no parallax at all.
        // Angular radii are in RADIANS and are tuned against a 1080p-or-better
        // panel: at focal 1.35 a screen half-height is 0.638 rad, so on a 1080p
        // display one pixel is ≈0.00118 rad and these land at ≈2.2 / 1.4 / 1.0
        // px of gaussian sigma. Anything much under a pixel shimmers under
        // motion instead of twinkling, which is the failure this scale avoids.
        //
        // Cell sizes set the DENSITY, and they are what "millions of stars"
        // actually means here: at t≈80 the mid band fits ≈60 cells across the
        // view, so one sheet alone is ~3600 candidate stars, and each band
        // lays down `starSteps` sheets at different depths.
        // Three lattices, each rotated differently, so no two bands' cell
        // grids ever line up with each other or with the frame.
        mat3 L1 = M3;
        mat3 L2 = M3 * L1;
        mat3 L3 = M3 * L2;
        // EACH BAND THROUGH ITS OWN COLUMN OF DUST. `tS1` is the transmittance
        // at 9.5 units, which is in front of the band's near fade, so the
        // foreground stars come through at full strength and stay ice-white —
        // they are between you and the galaxy, and that is exactly how a
        // foreground star behaves. `tS3` is the transmittance at 270, deep
        // inside the band, so the far field is dimmed AND warmed where the
        // dust lanes cross it. That difference — clean near, reddened far,
        // across the same frame — is what makes the dust read as something the
        // stars are genuinely BEHIND rather than a sheet laid over them.
        vec3 s = vec3(0.0);
        s += starBand(L1, 1.20,   3.0,   30.0, starSteps,             0.17, 0.00105, 1.35, 1.00, u_look.y,        3.0) * tS1;
        s += starBand(L2, 1.85,  30.0,  130.0, starSteps,             0.31, 0.00082, 0.76, 0.60, u_look.y * 0.45, 17.0) * tS2;
        s += starBand(L3, 3.10, 130.0,  560.0, max(starSteps - 2, 5), 0.44, 0.00068, 0.46, 0.18, 0.0,             41.0) * tS3;
        // Infinitely far by construction, so it is behind ALL of the dust.
        s += cosmicBackground(rd) * starTrans;
        behind = vec4(s, 0.0);          // stars are pure added light — alpha 0
    }

    // ── 4 · the rings, marched through their own slab ────────────────────
    vec3 ringC = vec3(0.0);
    float ringA = 0.0;
    {
        float denom = dot(rd, gRingN);
        if (wantBodies && abs(denom) > 1e-4) {
            float tPlane = dot(gPlanetC - gRo, gRingN) / denom;
            if (tPlane > 0.0) {
                // The slab has real thickness, so the ray crosses it over a
                // span that grows as the view grazes the plane — which is
                // exactly when rings look thick, and it comes out for free.
                float thick = gPlanetR * 0.055;
                float span = min(thick / max(abs(denom), 0.02), gPlanetR * 3.0);
                float t0 = max(tPlane - span, 0.05);
                float t1 = tPlane + span;
                float dt = (t1 - t0) / float(ringSteps);
                for (int i = 0; i < RING_STEPS; i++) {
                    if (i >= ringSteps) break;
                    float tt = t0 + dt * (float(i) + 0.5);
                    if (tHit > 0.0 && tt > tHit) break;   // occluded by the body
                    vec3 q = gRo + rd * tt;
                    float dens = ringDensity(q, rIn, rOut);
                    if (dens > 0.002) {
                        // The planet's own shadow, thrown across the back of
                        // the rings. Analytic, and the half that matters.
                        float sh = sphereShadow(q, gLight, gPlanetC, gPlanetR);
                        vec3 rel = q - gPlanetC;
                        float u = clamp((length(rel - gRingN * dot(rel, gRingN)) - rIn) / (rOut - rIn), 0.0, 1.0);
                        vec3 rc = mix(P_GOLD_GLOW, P_VIOLET_GLOW, u);
                        rc = mix(rc, P_TEAL, smoothstep(0.6, 1.0, u) * 0.55);
                        // OPACITY IS NOT BRIGHTNESS. Dense ring material
                        // occludes whatever is behind it even when it is dark
                        // — a shadowed band is still solid dust. The first cut
                        // integrated alpha at a coefficient low enough that
                        // even the brightest bands only reached ~0.8, so 20% of
                        // the planet's atmospheric limb — which is the single
                        // brightest thing on the body — shone straight through
                        // and the rings read as translucent where they cross
                        // it. At 7.0 a dense band saturates to 1.0 and the
                        // occlusion is total, while the true GAPS still
                        // integrate to near zero and stay honestly see-through.
                        float a = clamp(dens * dt * 7.0, 0.0, 1.0) * (1.0 - ringA);
                        // FORWARD SCATTER, and the sign here was wrong first
                        // time. A photon reaches the eye travelling along −rd,
                        // and it arrived at the dust travelling along −gLight;
                        // scattering is forward when those align, i.e. when
                        // gLight·rd → 1. Written against −gLight it rewarded
                        // BACK-scatter instead, so the rings went flattest
                        // exactly where a real dust ring blazes.
                        float fs = 0.45 + 1.35 * pow(max(dot(rd, gLight), 0.0), 3.0);
                        // Metallic sheen: a narrow specular lobe about the
                        // forward-scatter peak, on top of the broad one. Ice
                        // and metal dust glint rather than merely glowing.
                        float sheen = pow(max(dot(rd, gLight), 0.0), 22.0)
                                    + pow(max(dot(rd, gLight), 0.0), 90.0) * 2.2;
                        ringC += rc * a * (0.18 + 1.15 * sh * fs)
                               + mix(P_GOLD_GLOW, vec3(1.0), 0.55) * a * sh * sheen * 1.5;
                        ringA += a;
                        if (ringA > 0.985) break;
                    }
                }
                ringA = clamp(ringA, 0.0, 1.0);
            }
        }
    }

    // ── 5 · composite, premultiplied, front to back ──────────────────────
    // `behind.rgb` has ALREADY been carried through the dust — per channel and
    // at its own depth — by the extinction in §2, so the only work left for
    // the composite is the coverage on the ALPHA channel. Multiplying the
    // colour by (1 − galA) here as well would attenuate it a second time and
    // quietly grey the whole star field behind the band.
    vec4 C = vec4(galC + behind.rgb, galA + (1.0 - galA) * behind.a);
    C = vec4(ringC, ringA) + (1.0 - ringA) * C;

    // No bloom chain here, so bound the radiance and roll it over a soft
    // exposure shoulder: bright cores go white-hot instead of clipping to a
    // flat disc, and the dust stays linear where it is faint.
    vec3 col = min(C.rgb, vec3(9.0));
    col = 1.0 - exp(-col * 1.55);

    // VIVID. An exposure curve is a per-channel compressor: the brightest
    // channel saturates first, so every colour drifts toward white on its way
    // up and the whole frame comes out pastel. Pushing saturation back after
    // the curve is the correction for that, not a stylistic filter — the hues
    // are the build's palette either way, this just stops the tonemap
    // bleaching them.
    float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(vec3(lum), col, 1.42);

    // A gentle shoulder-and-toe. Deepens the black between the stars without
    // touching the highlights, which is most of what "clean" reads as.
    col = clamp(col, 0.0, 1.0);
    col = col * col * (3.0 - 2.0 * col) * 0.34 + col * 0.66;

    // ── WIP-553: wear the owner's approved dark-glass material ───────────
    // Owner, on the earlier flat-blue sky: "the background it is now i
    // wanted a darker background this one is super light almost like a
    // baby blue." A same-night VM audit read this exact volume through the
    // bar at blue/green 5.2-6.2 with red-over-green +6..+14, against his
    // approved blue/green 1.3-1.4 (green fractionally ahead of red) in the
    // body and 1.6-1.7 (red leading) at an edge — this sky, not a
    // wallpaper, was what was bleeding that far off the approved numbers.
    //
    // GROUND, not a filter over the picture: everywhere above insisted the
    // void reach exact #000000, which was correct for a black sky but
    // #000000 is not a colour in this build's palette (a dark here is a
    // saturated colour, never grey or true black). This vertical gradient
    // of `u_groundTop → u_groundMid → u_groundDeep` — Theme.surfaceTop/
    // Mid/Deep, read in from QML, never a hex literal in this file —
    // replaces that void. The existing picture (stars, dust, rings) keeps
    // riding on top as additive light, scaled well down so the detail
    // survives at a fraction of its old brightness instead of being erased
    // by a flat tint.
    vec3 ground = mix(mix(u_groundDeep.rgb, u_groundMid.rgb,
                           smoothstep(0.0, 0.6, qt_TexCoord0.y)),
                       u_groundTop.rgb,
                       smoothstep(0.6, 1.0, qt_TexCoord0.y));
    col = ground + col * 0.34;
    // The brightest specular peaks — ring sheen, diffraction spikes, the
    // planet's limb — lean toward `u_groundEdge` (Theme.glassBorder), the
    // same accent every other glass edge in the build wears, instead of
    // staying pure white-hot and colour-blind to the rest of the system.
    float peak = smoothstep(0.55, 1.05, dot(col, vec3(0.2126, 0.7152, 0.0722)));
    col = mix(col, mix(col, u_groundEdge.rgb, 0.35), peak);
    col = clamp(col, 0.0, 1.0);

    // A whisper of a vignette. Not a mood filter — it is 8% at the extreme
    // corners, below the threshold you would notice as an effect, and it
    // exists because the eye goes to the brightest region and this keeps that
    // region the subject rather than whichever corner the band happens to
    // exit through. Squared distance so the falloff never forms a visible ring.
    float vig = 1.0 - 0.08 * pow(clamp(dot(uv, uv) / 1.85, 0.0, 1.0), 1.6);
    col *= vig;

    col *= clamp(u_look.w, 0.0, 3.0);

    // Premultiplied, exactly as the 2D headliner: the stars ADD light to the
    // wallpaper beneath, while the bodies and the ring dust carry real
    // coverage and are allowed to hide it.
    fragColor = vec4(col * qt_Opacity, clamp(C.a, 0.0, 1.0) * qt_Opacity);
}
