#version 440
// Nyxus Suxyn — swirl sim, SPLAT pass (stimulus in).
//
// Port of design/swirl-live.html FRAG.splat plus the JS that drives it:
// `_stroke` (line-subdivided so a fast swipe paints a continuous ribbon),
// `_dollop` (a click), `_mapSweep` (the signature colour ramp) and the ambient
// dye pulse.
//
// The reference issues one DRAW CALL per sub-splat — a 12-segment stroke is 12
// velocity blits and ~18 dye blits, all of them `target + gaussian*colour`.
// Addition is associative, so summing the same gaussians inside one fragment
// shader is not an approximation, it is the identical result in one pass. That
// is the only structural liberty this port takes with the splat stage, and it
// is why the stroke subdivision could be ported literally instead of being
// replaced by a 4-slot impulse ring.
//
// One instance of this shader runs on velocity (mode 0), one on dye (mode 1).
// Six stroke slots: 0 = pointer, 1–3 = ambient stirrers, 4–5 = intro emitters.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float mode;          // 0 = velocity, 1 = dye
    float aspect;        // item width / height
    float time;          // seconds

    vec4 sweep;          // x lo · y hi · z gamma

    vec4 sA0;            // stroke endpoints: x0, y0, x1, y1  (0..1 UV)
    vec4 sA1;
    vec4 sA2;
    vec4 sA3;
    vec4 sA4;
    vec4 sA5;

    vec4 sB0;            // x subdivisions n (0 = slot idle) · y radius
    vec4 sB1;            // z,w velocity amplitude (force*forceMul/sqrt(n))
    vec4 sB2;
    vec4 sB3;
    vec4 sB4;
    vec4 sB5;

    vec4 sC0;            // x dye strength ds · y colour-jitter seed
    vec4 sC1;
    vec4 sC2;
    vec4 sC3;
    vec4 sC4;
    vec4 sC5;

    vec4 dolA;           // click dollop: x, y, strength (0 = idle), seed
    vec4 dolB;           // x radius · y,z direction · w dye gain
    vec4 pls;            // ambient dye pulse: x, y, gain (0 = idle), radius

    // ── the ramp stops, now UNIFORMS (WIP-619, 2026-08-15) ──────────────
    // The seven stops used to be consts below. The owner ruled the bar keeps
    // ONE identity — the swirls — with selectable COLOR LAYERS, so the stops
    // arrive from Swirl.qml, which defaults them from Theme.paintRamp. The
    // LIGHTNESS LADDER is the law and it is the layer author's to keep:
    // BRIGHT / dark / dark / dark / mid / bright / BRIGHT — swirls come from
    // alternating lightness, not more hues (see the ramp history above).
    vec4 r0; vec4 r1; vec4 r2; vec4 r3; vec4 r4; vec4 r5; vec4 r6;
};
layout(binding = 1) uniform sampler2D uTarget;

// ── the signature sweep, byte-identical to swirl-live.html's SWEEP ────────
// ── THE RAMP, EXTENDED AT THE ROSE END (2026-08-08) ─────────────────────────
// The owner asked for the bar's swirl to be rose. The naive change is to slice
// off the teal with sweepLo -- and it produces mud, for a reason worth writing
// down because the border hit the identical wall:
//
//   S0 teal is the ONLY bright stop in the original five. S1 azure, S2 indigo
//   and S3 violet sit within a few percent of each other in lightness, and S4
//   plum is only mid. Cut the teal and every remaining stop is dark, so the
//   fluid's ribbons have no lightness to separate them and the whole band
//   integrates to its own mean -- grey. That is exactly the failure
//   nyxus-cometfire.conf documents for col.active_border, and its rule applies
//   here unchanged: SWIRLS COME FROM ALTERNATING LIGHTNESS, NOT MORE HUES.
//
// So the ramp is not replaced, it is EXTENDED: two bright rose stops on the far
// end, taken from the border's proven family, so a rose slice has the same
// dark->bright travel the teal end has always had. Seven stops, six segments.
//
// The teal end is untouched on purpose -- Launcher.qml slices it deliberately
// ("this end of the screen is the teal end") and Spill/Frame/PowerMenu ride the
// full range. Extending rather than replacing is what lets the bar go rose
// without repainting every other surface.
//
// CONSUMER WARNING: sweepLo/sweepHi are fractions of the WHOLE ramp, so adding
// segments rescales them. Any existing slice must be re-derived: a value of
// 0.62 over four segments is position 2.48, which over six segments is
// 2.48/6 = 0.413, NOT 0.62. Launcher.qml is corrected in the same commit.
// The historical Nyx Rose values, kept here as the reference the layers are
// measured against (they are now the DEFAULTS in Swirl.qml, not consts):
//   #0aa2d6 teal BRIGHT · #064f95 azure dark · #1e03ad indigo dark ·
//   #521e72 violet dark · #891955 plum mid · #d765a2 rose bright ·
//   #ffb3d9 pale BRIGHT
vec3 sweepColor(float t) {
    t = clamp(t, 0.0, 1.0) * 6.0;
    if (t < 1.0) return mix(r0.rgb, r1.rgb, t);
    if (t < 2.0) return mix(r1.rgb, r2.rgb, t - 1.0);
    if (t < 3.0) return mix(r2.rgb, r3.rgb, t - 2.0);
    if (t < 4.0) return mix(r3.rgb, r4.rgb, t - 3.0);
    if (t < 5.0) return mix(r4.rgb, r5.rgb, t - 4.0);
    return mix(r5.rgb, r6.rgb, t - 4.0 - 1.0);
}

// swirl-live.html `_mapSweep`: gamma-shaped position through the panel's slice
// of the sweep, a slow global drift, and a small per-splat jitter so
// neighbouring sub-splats differ and the flow folds them together.
vec3 mapSweep(float x, float jitter) {
    float xg = pow(clamp(x, 0.0, 1.0), sweep.z);
    float drift = 0.03 * sin(time * 0.13 + x * 3.0);
    return sweepColor(sweep.x + (sweep.y - sweep.x) * xg + drift + jitter * 0.025);
}

float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    return fract(p * (p + p));
}

// FRAG.splat, unchanged: a gaussian in aspect-corrected UV space. Note the
// reference divides by `radius`, not radius² — splatRadius 0.060 is therefore
// a σ of ~0.17 of the panel height, not 0.06.
float gauss(vec2 uv, vec2 point, float radius) {
    vec2 p = uv - point;
    p.x *= aspect;
    return exp(-dot(p, p) / radius);
}

// swirl-live.html `_stroke`, with n / radius / amplitude precomputed in QML so
// the arithmetic is the reference's own.
vec3 stroke(vec2 uv, vec4 A, vec4 B, vec4 C) {
    vec3 acc = vec3(0.0);
    float n = B.x;
    if (n < 0.5) return acc;
    float radius = B.y;
    float ds = C.x;
    if (mode > 0.5 && ds <= 0.002) return acc;   // reference gates dye on this

    int N = int(n);
    for (int i = 1; i <= N; i++) {
        float t = float(i) / n;
        vec2 pi = mix(A.xy, A.zw, t);
        float g = gauss(uv, pi, radius);
        if (mode < 0.5) {
            acc += g * vec3(B.zw, 0.0);
        } else {
            float jit = hash11(C.y + float(i) * 7.13) - 0.5;
            vec3 col = mapSweep(pi.x, jit);
            acc += g * col * ds;
            // hot core → toward white, at 20% of the stroke radius
            if (i - (i / 2) * 2 == 0 || N == 1) {
                acc += gauss(uv, pi, radius * 0.20) * (col * 0.5 + 0.5) * (ds * 0.22);
            }
        }
    }
    return acc;
}

// swirl-live.html `_dollop`
vec3 dollop(vec2 uv) {
    vec3 acc = vec3(0.0);
    float S = dolA.z;
    if (S <= 0.001) return acc;
    float R = dolB.x;
    float x = dolA.x, y = dolA.y;

    if (mode < 0.5) {
        // the caller's own direction, so `dropAt` can throw the paint
        acc += gauss(uv, vec2(x, y), R) * vec3(dolB.yz * 5200.0 * S, 0.0);
    } else {
        vec3 col = mapSweep(x, hash11(dolA.w) - 0.5);
        acc += gauss(uv, vec2(x, y), R * 2.6) * col * 0.7 * dolB.w;
        acc += gauss(uv, vec2(x, y), R * 0.35) * vec3(0.45, 0.47, 0.5) * dolB.w;
    }

    for (int i = 0; i < 9; i++) {
        float fi = float(i);
        float a = (fi / 9.0) * 6.28318531 + hash11(dolA.w + fi) * 0.5;
        if (mode < 0.5) {
            float k = 1100.0 + hash11(dolA.w + fi + 31.0) * 800.0;
            acc += gauss(uv, vec2(x, y), R * 1.9) * vec3(cos(a) * k * S, sin(a) * k * S, 0.0);
        } else {
            vec3 cc = mapSweep(x + (fi / 9.0 - 0.5) * 0.3, hash11(dolA.w + fi + 7.0) - 0.5);
            acc += gauss(uv, vec2(x + cos(a) * 0.02, y + sin(a) * 0.08), R * 0.9)
                 * cc * 0.3 * dolB.w;
        }
    }
    return acc;
}

// swirl-live.html `_ambient`'s rare dye pulse, so the paint never fully dies
vec3 pulse(vec2 uv) {
    if (mode < 0.5 || pls.z <= 0.001) return vec3(0.0);
    vec3 col = mapSweep(pls.x, 0.0);
    return gauss(uv, pls.xy, pls.w * 1.6) * col * 0.35 * pls.z
         + gauss(uv, pls.xy, pls.w * 0.3) * vec3(0.12, 0.13, 0.14) * pls.z;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec3 acc = vec3(0.0);
    acc += stroke(uv, sA0, sB0, sC0);
    acc += stroke(uv, sA1, sB1, sC1);
    acc += stroke(uv, sA2, sB2, sC2);
    acc += stroke(uv, sA3, sB3, sC3);
    acc += stroke(uv, sA4, sB4, sC4);
    acc += stroke(uv, sA5, sB5, sC5);
    acc += dollop(uv);
    acc += pulse(uv);
    fragColor = vec4(texture(uTarget, uv).xyz + acc, 1.0);
}
