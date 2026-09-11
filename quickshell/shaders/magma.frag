#version 440
// Nyxus Suxyn — MAGMA. Molten rock, not orange fluid.
//
// The liquid-magma prototype (owner's brief, 2026-08-13). What separates
// magma from "generic orange swirl" is four specific things, and each one
// is a named block below:
//
//   1. DOMAIN-WARPED FLOW — the coordinates fed to the crust noise are
//      themselves displaced by two earlier fBm passes (iq's classic
//      p → fbm(p + fbm(p)) construction, two warp generations). This is
//      the single biggest quality jump over a sine swirl: turbulence with
//      eddies and tongues instead of a rotating pattern. Time enters as a
//      SCROLL through the noise field (the slab creeps and evolves), never
//      as a rotation — real flow does not visibly repeat.
//   2. TWO MATERIALS, NOT ONE GRADIENT — a dark solid CRUST (its own
//      high-frequency roughness fBm) and an emissive MELT underneath,
//      revealed only where the warped crust field thins past a threshold.
//      The cracks are smoothstepped on both sides of that threshold, so
//      they are soft-edged fissures, not vector lines, and the melt is
//      ADDED over the crust — emission, not paint.
//   3. INCANDESCENCE IS A TEMPERATURE RAMP — black-body-ish: deep coral
//      red where the melt is coolest, through gold, to white-hot only in
//      the widest fissure cores. Brightness also LEADS the flow (the melt
//      upstream of a crack mouth glows hotter), and the whole melt channel
//      breathes on a slow fBm flicker — molten rock pulses, it does not
//      strobe.
//   4. HEAT SHIMMER — a fast, low-amplitude noise displaces the SAMPLING
//      coordinates before anything is drawn, strongest over open melt and
//      near zero over thick crust (hot air refracts above the glow, not
//      above cold rock). It is the cheapest line in the file and it is
//      the one that sells "hot".
//
// LEGIBILITY AT BAR SCALE — this prototype must read at 30–50 px tall, so
// two "bold over busy" decisions are contrast-graded harder than a real
// lava photo: the crust is crushed darker than life, and the crack network
// is tuned to a few WIDE rivers with fine tributaries that fade out first
// at small scale (the primary channel is low-frequency; detail channels
// only modulate it). uScene.x scales the crack scale itself so a bar strip
// can run a coarser network than a full-screen surface.
//
// PALETTE — the owner left the call open between photo-real lava and a
// palette-locked hot take. Decision: the build's own measured ladder
// ALREADY CONTAINS true lava — coral (#a61e14→#cd5e56→#e0ada9) and gold
// (#50310b→#a66514→#d8a464) are the rose palette's warm rungs, measured
// off the owner's banners like every other rung. So the ramp below walks
// coral-deep → coral → gold-body → gold-glow → white-hot: unambiguous
// magma at a glance, and every stop is a ladder rung. White-hot cores are
// structure (the same standing 13pu gives black/white). The crust carries
// a breath of violet-haze in its shadows so the slab still sits in a NYXUS
// build rather than a geology documentary.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    float uTime;
    vec2  uRes;      // item px
    vec4  uLook;     // x flow speed · y crack width · z glow gain · w master (beat rides here)
    vec4  uScene;    // x crack scale (bar strips run coarser) · y shimmer amt · z crust darkness · w quality
    vec4  uFlags;    // reserved · reserved · reserved · demo (unused here, kept for the shared block shape)
};

// ── the measured ladder rungs this file is allowed to speak ──────────────
const vec3 CORAL_DEEP = vec3(0.220, 0.020, 0.012);   // #380603 coral haze rung
const vec3 CORAL_BODY = vec3(0.651, 0.118, 0.078);   // #a61e14
const vec3 CORAL      = vec3(0.804, 0.369, 0.337);   // #cd5e56
const vec3 GOLD_DEEP  = vec3(0.314, 0.192, 0.043);   // #50310b
const vec3 GOLD_BODY  = vec3(0.651, 0.396, 0.078);   // #a66514
const vec3 GOLD_GLOW  = vec3(0.847, 0.643, 0.392);   // #d8a464
const vec3 VIOLET_HAZE= vec3(0.141, 0.012, 0.220);   // #240338 — the crust's cold shadow

// ── hashes and noise — the no-trig family the other skies use ────────────
float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash12(i),              hash12(i + vec2(1, 0)), f.x),
               mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y);
}

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

// spray droplets, two cell scales — the same can texture the space scene
// and the style test carry; here it is the spark spray around open melt
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

// fBm with per-octave rotation. The magma needs more octaves than the sky
// nebula because the crust roughness IS the picture; quality sheds them.
float fbm(vec2 p, int oct) {
    float v = 0.0, a = 0.5;
    mat2 r = mat2(0.80, 0.60, -0.60, 0.80);
    for (int i = 0; i < 7; i++) {
        if (i >= oct) break;
        v += a * vnoise(p);
        p = r * p * 2.07 + 19.3;
        a *= 0.54;
    }
    return v;
}

// Ridged fBm for the crack network: 1−|2n−1| turns noise into creases, and
// squaring sharpens the crease floor — fissures are ridges in disguise.
float ridge(vec2 p, int oct) {
    float v = 0.0, a = 0.55;
    mat2 r = mat2(0.80, 0.60, -0.60, 0.80);
    for (int i = 0; i < 5; i++) {
        if (i >= oct) break;
        float n = 1.0 - abs(2.0 * vnoise(p) - 1.0);
        v += a * n * n;
        p = r * p * 2.13 + 7.7;
        a *= 0.52;
    }
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = uRes.x / max(uRes.y, 1.0);
    vec2 sp = uv * vec2(aspect, 1.0);

    float t     = uTime * uLook.x;                    // flow clock
    float scale = max(uScene.x, 0.2);                 // crack network scale
    int   octA  = uScene.w > 0.6 ? 5 : 3;             // warp octaves
    int   octB  = uScene.w > 0.6 ? 6 : 4;             // crust roughness octaves

    // ── 4 · HEAT SHIMMER (computed first, applied to everything) ─────────
    // Fast, tiny, and gated by last frame's own melt estimate: a single
    // cheap fBm probe stands in for "how much glow is under this pixel",
    // so the shimmer concentrates over open melt. At ±0.004 UV it never
    // smears the picture — it makes the air above it refract.
    float melt0   = fbm(sp * 2.0 * scale - vec2(t * 0.05, t * 0.02), 3);
    float shimGate = smoothstep(0.45, 0.75, melt0);
    vec2 shim = (vec2(vnoise(sp * 26.0 + vec2(0.0, t * 2.6)),
                      vnoise(sp * 26.0 + vec2(41.7, t * 2.9))) - 0.5)
              * 0.008 * uScene.y * (0.35 + 0.65 * shimGate);
    vec2 p = (sp + shim) * scale;

    // ── 1 · THE FLOW FIELD — two generations of domain warp ─────────────
    // Generation one drifts with the slab (slow lateral creep); generation
    // two evolves faster and carries most of the visible churn. The final
    // field `flow` is what both materials read their shape from.
    // the slab's creep WANDERS: the direction itself turns through ±6° on a
    // minutes-long period, because real flow follows terrain nobody can see
    // — a fixed drift vector is the one giveaway that a texture is scrolling
    float wob = 0.10 * (vnoise(vec2(t * 0.011, 2.2)) - 0.5) * 2.0;
    mat2 wrot = mat2(cos(wob), -sin(wob), sin(wob), cos(wob));
    vec2 drift = wrot * vec2(t * 0.045, t * 0.014);
    vec2 q = vec2(fbm(p * 1.1 + drift,                       octA),
                  fbm(p * 1.1 + drift + vec2(5.2, 1.3),      octA));
    vec2 r2 = vec2(fbm(p * 1.1 + 2.6 * q + vec2(1.7, 9.2) + vec2(t * 0.10, -t * 0.06), octA),
                   fbm(p * 1.1 + 2.6 * q + vec2(8.3, 2.8) - vec2(t * 0.07,  t * 0.05), octA));
    float flow = fbm(p * 1.1 + 2.4 * r2, octA + 1);

    // ── 2 · THE CRACK NETWORK ────────────────────────────────────────────
    // One low-frequency ridged channel routed through the SAME warp (so
    // rivers follow the flow), sharpened by a fine tributary channel that
    // is only allowed to MODULATE the primary — at bar scale the fine
    // channel fades below perception first and the rivers survive alone.
    float rivers = ridge(p * 1.15 + 2.2 * r2 + drift * 0.4, 3);
    float fine   = ridge(p * 3.1  + 3.0 * r2 - drift * 0.7, octA);
    float channel = rivers * (0.72 + 0.28 * fine);

    // crack width dial: moves the smoothstep window, so width is a real
    // physical opening, not a gain
    float wHalf = 0.10 * clamp(uLook.y, 0.3, 2.5);
    // centre 0.50: at 0.62 the network barely opened and the slab rendered
    // as a black screen with orphan drips (first magma capture)
    float crackLo = 0.50 - wHalf, crackHi = 0.50 + wHalf * 0.6;
    float melt = smoothstep(crackLo, crackHi, channel);

    // the melt LEADS the flow: probe the channel a step upstream — where a
    // fissure is about to open, the rock above it already glows through
    float ahead = smoothstep(crackLo, crackHi,
                             ridge(p * 1.15 + 2.2 * r2 + drift * 0.4 + vec2(0.09, 0.03), 3)
                             * (0.72 + 0.28 * fine));
    float underglow = max(melt, ahead * 0.55);

    // ── 2 · THE CRUST ────────────────────────────────────────────────────
    // Near-black rock with its own high-frequency roughness — crushed
    // darker than life (uScene.z) so the glow has something to punch
    // through at 36 px tall. Shadow crevices cool toward violet haze: the
    // one whisper of the build's palette in the solid material.
    float rough = fbm(p * 4.2 + r2 * 1.2, octB);
    float aoV   = fbm(p * 1.6 + q * 0.8, 3);          // large-scale light/shade
    vec3 crust = mix(vec3(0.020, 0.016, 0.026), vec3(0.130, 0.110, 0.135),
                     rough * rough);
    crust = mix(crust, VIOLET_HAZE * 0.35, smoothstep(0.6, 0.2, rough) * 0.6);
    crust *= mix(1.25, 0.55, aoV);                    // the slab is lit unevenly
    // the darkness dial — default keeps the rock READABLE: crushed to
    // near-black it stopped being a material at all (first magma capture)
    crust *= mix(1.0, 0.45, clamp(uScene.z, 0.0, 1.5) * 0.5);
    // heat discolours the rock around a fissure before it breaks: a rusty
    // scorch ring where underglow approaches but has not opened
    float scorch = smoothstep(0.15, 0.75, underglow) * (1.0 - melt);
    crust = mix(crust, GOLD_DEEP * 0.6, scorch * 0.55);

    // ── 3 · THE MELT — temperature ramp + emission ───────────────────────
    // Openness maps to temperature; the ramp walks the ladder's warm rungs.
    // Wide fissure cores overrun to white-hot. The whole channel breathes
    // on a slow fBm flicker — pulse, never strobe.
    float breath = 0.82 + 0.18 * fbm(vec2(t * 0.35, flow * 3.0), 3);
    float temp = pow(melt, 1.35) * breath;
    vec3 lava = CORAL_DEEP;
    lava = mix(lava, CORAL_BODY, smoothstep(0.02, 0.30, temp));
    lava = mix(lava, CORAL,      smoothstep(0.22, 0.52, temp));
    lava = mix(lava, GOLD_BODY,  smoothstep(0.42, 0.72, temp));
    lava = mix(lava, GOLD_GLOW,  smoothstep(0.62, 0.88, temp));
    lava = mix(lava, vec3(1.02, 0.98, 0.90), smoothstep(0.85, 1.0, temp));
    // fine convection inside the open melt — the liquid is itself moving
    lava *= 0.88 + 0.24 * fbm(p * 6.0 + r2 * 2.0 + vec2(t * 0.5, 0.0), 3);

    // assemble: crust, then the melt ADDED (emission), then the bloom the
    // emission throws over the neighbouring crust — two radii of soft glow
    // that make the cracks light their own banks
    vec3 col = crust;
    col += lava * melt * (1.4 * uLook.z);
    float bloomN = smoothstep(crackLo - 0.18, crackHi, channel);
    col += CORAL_BODY * bloomN * bloomN * (1.0 - melt) * 0.30 * uLook.z;
    col += GOLD_BODY  * pow(bloomN, 4.0) * (1.0 - melt) * 0.22 * uLook.z;
    // and the underglow: thin rock over rising melt transmits deep red
    col += CORAL_DEEP * underglow * (1.0 - melt) * 2.2 * uLook.z;

    // ── THE DRIPS — the owner's reference behaviour, molten paint ────────
    // Gravity runs of glowing melt falling from the cracks: per screen
    // column, a hashed source point; the run only exists if the crack
    // channel is actually HOT at that source (a one-point probe of the
    // same ridged field — a proxy, cheap, and close enough that runs hang
    // from real fissures). Length grows and shrinks slowly: paint keeps
    // running as long as the fissure feeds it.
    {
        float xf2 = 20.0 * scale;
        float xc  = floor(sp.x * xf2);
        vec2  hD  = hash22(vec2(xc, 7.7));
        if (hD.x < 0.55) {
            float srcY = 0.12 + hD.y * 0.55;
            vec2  srcP = (vec2((xc + 0.5) / xf2, srcY) + shim) * scale;
            float srcChan = ridge(srcP * 1.15 + drift * 0.4, 3);
            if (srcChan > 0.50) {
                float len = (0.05 + 0.20 * hD.y)
                          * (0.55 + 0.45 * fbm(vec2(t * 0.18, xc * 3.1), 2));
                float dy = sp.y - srcY;               // +y is DOWN in this file
                if (dy > -0.01 && dy < len + 0.03) {
                    float cx  = (xc + 0.25 + hD.y * 0.5) / xf2;
                    float wD  = 0.004 + 0.003 * hD.x;
                    float run = exp(-(sp.x - cx) * (sp.x - cx) / (wD * wD)) * step(dy, len);
                    vec2  bq  = vec2(sp.x - cx, dy - len);
                    run += exp(-dot(bq, bq) / (wD * wD * 5.0)) * 0.9;
                    float hot = 1.0 - dy / max(len, 1e-4);   // cools as it falls
                    vec3 dripC = mix(CORAL_BODY, GOLD_GLOW, hot * hot);
                    dripC = mix(dripC, vec3(1.0, 0.97, 0.88), smoothstep(0.75, 1.0, hot) * run * 0.6);
                    col += dripC * run * 1.5 * uLook.z;
                }
            }
        }
    }

    // spark spray — glowing droplets blown around the open melt, gold
    col += GOLD_GLOW * spatter(sp * 1.4 + 5.0, smoothstep(0.35, 0.85, underglow) * 0.8) * 0.7 * uLook.z;

    // ── master, beat, finish ─────────────────────────────────────────────
    col *= uLook.w;
    col = col / (1.0 + col * 0.30);                   // soft knee: cores keep hue
    col = pow(max(col, 0.0), vec3(0.94));             // slight lift, punchier mids

    // the neon punch, same law as the space scene: +25 % saturation after
    // the knee, so the white-hot cores stay white
    float lumc = dot(col, vec3(0.299, 0.587, 0.114));
    col = clamp(mix(vec3(lumc), col, 1.25), 0.0, 1.0);

    // banding insurance, same grain as the skies: ±1/512, invisible
    col += (hash12(uv * uRes + fract(uTime) * 61.7) - 0.5) / 256.0;

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
