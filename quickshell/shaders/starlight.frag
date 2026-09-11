#version 440
// Nyxus Suxyn — STARLIGHT. The Rolls-Royce Starlight Headliner, as a layer.
//
// v2 — the owner's verdict on v1: "push it more to the limits… a ton more
// stars like in the RR clusters… the colors i dont think are correct."
// He is right on all three, and the causes were findable:
//
//   · v1 kept only ~a third of design/starlight-live.html: one dust tier
//     instead of four, jitter instead of the cluster/void noise, a sine
//     twinkle instead of the two-octave value noise, no power-law sizes,
//     no Pogson brightness. The reference's density machinery WAS the look.
//   · v1 shipped warmth 0.55 where the reference demo defaults to 0.22 —
//     the whole field read amber. A real headliner is icy white: fibre
//     points fed by a white source, blue-white in every RR cabin photo,
//     with only the odd warmer point where a fibre run attenuates.
//   · The reference itself carries a units bug this port inherits nowhere:
//     its starLayer measures distance in CELL units but sizes stars in
//     SCREEN units, so its four dust tiers are sub-texel and invisible
//     without the HTML's bloom chain. Here rel is converted to screen
//     units (relUv) before any size math, so every tier lands on screen.
//
// What makes the REAL ceiling read real, all of it kept or restored:
//   · SIX layers — four static dust beds under a midground under rare
//     beacons; fibre bundles come in gauges, and the thin ones are legion.
//   · THE LAY-UP: a shared cluster field — dense hand-laid pockets that
//     saturate to a carpet of points, real voids of empty leather, and the
//     signature milky-way swoosh band running the diagonal. Shared across
//     all six layers so a cluster is a PLACE, not per-layer texture.
//   · Spectral population, not a tint: ~24% ice-blue, ~65% pure white,
//     ~11% soft amber at the default warmth. White dominates; colour is
//     the exception, exactly like looking up at the one.
//   · Per-star identity from its cell hash: size on a ^4 power law (the
//     80/15/5 rule — most points are fine dust, the big fibre is rare),
//     brightness through Pogson's exponential (a beacon is DRAMATICALLY
//     brighter, not just bigger), its own twinkle phase and speed.
//   · Scintillation is TWO OCTAVES OF VALUE NOISE over time, never a sine
//     — a sine reads as clockwork within seconds. Bright stars flicker
//     faster (×2.2); the dust beds never twinkle at all.
//   · A star is a tight gaussian CORE + a wider dim HALO windowed to its
//     cell, faint capped diffraction spikes (+ diagonals on the top 2%),
//     a one-texel chromatic fringe at the spike tips, and a rare burst.
//   · Extinction: points near the bottom of the frame dim and warm.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float uTime;
    float uDensity;      // 0..2 — 1.0 is the shipped default look
    vec4 uRes;           // x,y item px · z shooting-star gate · w celestial-artwork gate
    vec4 uLook;          // x twinkleSpeed · y sparkle · z warmth · w master
};

float hash11(float p){ p=fract(p*0.1031); p*=p+33.33; p*=p+p; return fract(p); }
float hash21(vec2 p){ vec3 p3=fract(vec3(p.xyx)*0.1031); p3+=dot(p3,p3.yzx+33.33); return fract((p3.x+p3.y)*p3.z); }
vec2 hash22(vec2 p){ vec3 p3=fract(vec3(p.xyx)*vec3(0.1031,0.1030,0.0973)); p3+=dot(p3,p3.yzx+33.33); return fract((p3.xx+p3.yz)*p3.zy); }
float noise1D(float x){ float i=floor(x), f=fract(x); f=f*f*(3.0-2.0*f); return mix(hash11(i), hash11(i+1.0), f); }
float valueNoise(vec2 p){
    vec2 i=floor(p), f=fract(p);
    float a=hash21(i), b=hash21(i+vec2(1.0,0.0)), c=hash21(i+vec2(0.0,1.0)), d=hash21(i+vec2(1.0,1.0));
    vec2 u=f*f*(3.0-2.0*f);
    return mix(mix(a,b,u.x), mix(c,d,u.x), u.y);
}
mat2 rot(float a){ float s=sin(a), c=cos(a); return mat2(c,-s,s,c); }
float fbm(vec2 p){
    float a = 0.5, s = 0.0;
    for (int i = 0; i < 3; i++) { s += a * valueNoise(p); p = rot(0.6) * p * 2.02 + 17.3; a *= 0.55; }
    return s / 0.926;
}

// THE CELESTIAL ARTWORK (owner's photo, 2026-08-09): the RR Bespoke
// headliner paints a galaxy behind the fibres — flowing blue streams with a
// gold river through them. Ours wears the MEASURED theme stops, not guessed
// hues (accent.json _palette_fixed): teal_deep #026282 → indigo_glow
// #7a63f0 → violet_glow #aa6ece → plum #ae206c, gold_glow #d8a464 for the
// river. Domain-warped fbm stretched along the band axis so the clouds
// STREAM instead of puddle. Returns added light; backbone feeds the cluster
// field so the fibres congregate along the painted streams, exactly like
// the photo.
// Returns the artwork's LIGHT; artAlpha is its PAINT — the real bespoke
// ceiling is painted onto the leather, so where the artwork lives it may
// darken the wallpaper behind it (premultiplied alpha), which is the only
// way saturated blue can read over a pale backdrop. Stars stay pure added
// light. Proved necessary on render 8: additive-only blue over the mauve
// rose can never be anything but lavender-grey.
vec3 nebula(vec2 uv, out float backbone, out float artAlpha) {
    vec2 p = rot(-0.42) * (uv - vec2(0.06, 0.02));
    p = vec2(p.x * 0.50, p.y * 1.40);
    float band = exp(-p.y * p.y / (2.0 * 0.18 * 0.18));
    // THE SWIRL (owner's second photo: "it swirls and stuff") — two vortex
    // warps along the band, opposite spins, before any noise is sampled,
    // so every stream, strand and cloud wraps around them
    vec2 v1 = p - vec2(-0.30, 0.02);
    p = vec2(-0.30, 0.02) + rot(2.1 * exp(-dot(v1, v1) / (2.0 * 0.20 * 0.20))) * v1;
    vec2 v2 = p - vec2(0.38, -0.05);
    p = vec2(0.38, -0.05) + rot(-1.7 * exp(-dot(v2, v2) / (2.0 * 0.17 * 0.17))) * v2;
    // domain warp for the flow, then RIDGED noise for the braids — a soft
    // cloud mask alone reads as fog (proved on render 6); the photo's
    // streams are thin bright lines with clouds hugging them
    vec2 q = vec2(fbm(p * 1.7), fbm(p * 1.7 + vec2(5.2, 1.3)));
    vec2 r = vec2(fbm(p * 1.7 + 2.4 * q + vec2(1.7, 9.2)),
                  fbm(p * 1.7 + 2.4 * q + vec2(8.3, 2.8)));
    float n = fbm(p * 1.7 + 2.2 * r);
    // two braid scales: the veil is FIBROUS in the photo, coarse strands
    // interwoven with fine ones
    float f1 = fbm(p * 2.6 + 3.0 * r);
    float braid = pow(1.0 - abs(2.0 * f1 - 1.0), 6.0);
    float f2 = fbm(p * 4.6 + 2.2 * r + 7.7);
    float braid2 = pow(1.0 - abs(2.0 * f2 - 1.0), 5.0);
    float filaments = (braid * 0.72 + braid2 * 0.55) * band * smoothstep(0.34, 0.60, n);
    // crisp-edged strokes, textured inside — not smoke (renders 7–10)
    float cloud = smoothstep(0.55, 0.80, n) * band * (0.70 + 0.60 * f1);
    // the gold river as the photo actually paints it: a ROPE of tangled
    // strands at three scales, each a thin ridge, summed into one thick
    // fibrous braid held near the band's core
    float riverBand = exp(-p.y * p.y / (2.0 * 0.14 * 0.14));
    float g1 = fbm(p * 1.3 + 2.0 * q + 31.7);
    float g2 = fbm(p * 2.1 + 1.6 * q + 57.3);
    float g3 = fbm(p * 3.4 + 1.2 * q + 83.1);
    float s1 = pow(1.0 - abs(2.0 * g1 - 1.0), 12.0);
    float s2 = pow(1.0 - abs(2.0 * g2 - 1.0), 10.0);
    float s3 = pow(1.0 - abs(2.0 * g3 - 1.0), 9.0);
    float river = clamp(s1 * 0.9 + s2 * 0.6 + s3 * 0.4, 0.0, 1.0) * riverBand;
    river = smoothstep(0.30, 0.85, river);
    // measured stops, saturated on purpose — additive light desaturates.
    // The photo's dominant hue is BLUE: the streams run teal→indigo and
    // only their bright crests wash toward white
    vec3 cloudCol = mix(vec3(0.039, 0.635, 0.839), vec3(0.478, 0.388, 0.941), smoothstep(0.30, 0.62, n));
    cloudCol = mix(cloudCol, vec3(0.667, 0.431, 0.808), smoothstep(0.62, 0.82, n));
    cloudCol = mix(cloudCol, vec3(0.682, 0.125, 0.424), smoothstep(0.82, 0.97, n));
    vec3 filCol = mix(vec3(0.039, 0.635, 0.839), vec3(0.478, 0.388, 0.941), smoothstep(0.3, 0.7, n));
    filCol = mix(filCol, vec3(0.81, 0.89, 1.00), braid * 0.55);
    // luminous amber-orange, the photo's river — gold ladder pushed toward
    // its saturated end so the paint's own dimming can't grey it to tan
    vec3 gold = mix(vec3(0.78, 0.40, 0.05), vec3(0.93, 0.64, 0.22), river * 0.7);
    backbone = clamp(filaments * 1.3 + river * 1.2 + cloud * 0.4, 0.0, 1.0);
    // the UNDERPAINT — what the photo actually does: the whole band region
    // is painted deep blue-black first, and the streams live on that dark
    // ground. Without it, blue light over a pale wallpaper is grey forever.
    vec3 deep = mix(vec3(0.055, 0.004, 0.325), vec3(0.008, 0.384, 0.510), smoothstep(0.25, 0.75, n));
    // paint coverage: the underpaint claims the band, the streams claim
    // their lines outright, nothing outside the artwork is touched
    artAlpha = clamp(band * 0.48 + cloud * 0.30 + filaments * 0.65 + river * 0.80, 0.0, 0.78);
    return deep * band * 0.10
         + cloudCol * cloud * 0.14
         + filCol * filaments * 0.42
         + gold * river * 0.62
         + vec3(1.0, 0.75, 0.35) * pow(river, 3.0) * 0.12;  // the rope's hot strands, still GOLD
}

// ~24% ice-blue / ~65% white / ~11% amber at warmth 0.22. warmth slides the
// population's boundaries, never the hues — more of the field reads warm
// without any point wearing a wrong colour.
vec3 spectralColor(float t, float warmth) {
    float wb = clamp(warmth, 0.0, 1.0);
    vec3 iceBlue   = vec3(0.784, 0.875, 1.000);
    vec3 pureWhite = vec3(1.0, 1.0, 1.0);
    vec3 amber     = vec3(1.000, 0.820, 0.702);
    float bBlue  = 0.28 - wb * 0.18;
    float bAmber = 0.93 - wb * 0.20;
    if (t < bBlue) return iceBlue;
    if (t < bAmber) return pureWhite;
    return amber;
}

// The lay-up. One field for all six layers, so a dense pocket is a place
// every gauge of fibre agrees on. Pockets saturate cell occupancy to 100%
// — a carpet of points, the RR cluster — the band sweeps the diagonal with
// its own ripple so it reads as laid fibre rather than an airbrush stroke,
// and the void term opens real stretches of empty leather between them.
// v3, after the owner's "the cluster is all centered… I want the ENTIRE sky
// filled with stars": the old void noise at scale 0.9 put ~1.5 structures
// across the whole frame — one continent of density, centred. Now the base
// floor is high (the sky is FULL everywhere), the pockets are smaller and
// legion (finer noise, more of them, spread edge to edge), the voids are
// shallow breathing room rather than empty leather, and the fibres also
// congregate along the painted streams (backbone), like the photo.
float clusterField(vec2 uv, float backbone) {
    float fine = valueNoise(uv * 3.2 + 13.0) * 0.55
               + valueNoise(uv * 6.4 + 57.0) * 0.45;
    float pockets = smoothstep(0.50, 0.82, fine);
    float ripple = 0.65 + 0.35 * valueNoise(uv * 3.1 + 91.0);
    float voids = smoothstep(0.20, 0.55, valueNoise(uv * 1.6 + 50.0));
    return (0.42 + pockets * 2.4 + backbone * ripple * 2.0) * mix(0.55, 1.0, voids);
}

// One gauge of fibre: a jittered, rotated grid of candidates. Single-cell
// occupancy (the halo is windowed to the cell, so nothing clips hard).
// cellSize/sizes are in uv units (fractions of screen height) — a beacon is
// the same physical size wherever it lands.
vec3 starLayer(vec2 uvIn, float clus, float cellSize, float layerAngle, float seed,
               float sizeMin, float sizeMax, float speedMin, float speedMax,
               float density, float spikeAmt, float briLo, float briHi,
               float twinkleGate) {
    vec2 uv = rot(layerAngle) * uvIn;
    vec2 cell = floor(uv / cellSize);
    vec2 local = fract(uv / cellSize) - 0.5;

    float occ = hash21(cell + seed);
    vec3 result = vec3(0.0);
    if (occ < density * clus) {
        // 0.55 jitter: enough to kill the grid, not enough for two adjacent
        // stars' glows to sum into one asymmetric blob (the reference's own
        // isolated-pair finding).
        vec2 jitter = (hash22(cell + seed + 11.0) - 0.5) * 0.55;
        vec2 rel = local - jitter;          // cell units — for the window
        vec2 relUv = rel * cellSize;        // SCREEN units — for all size math
        float d = length(relUv);

        // extinction is a screen-space fact, not a per-layer one
        float extinction = smoothstep(-0.12, -0.55, uvIn.y) * 0.6;

        // ^4 size law + Pogson-style brightness BOUNDED per tier: within a
        // gauge, brightness interpolates exponentially (each step up is a
        // multiplicative jump, so the tier's rare big fibre is dramatically
        // brighter, not just bigger) — but the tier's floor keeps its dust
        // visible, which the reference's unbounded exp() never did.
        float sizeSeed = hash21(cell + seed + 3.0);
        float sizeCurve = sizeSeed * sizeSeed * sizeSeed * sizeSeed;
        float baseSize = mix(sizeMin, sizeMax, sizeCurve);
        float bright = briLo * pow(briHi / briLo, sizeCurve);

        // two octaves of value noise — erratic, never clockwork
        float tSeed = hash21(cell + seed + 41.0) * 133.7;
        float speedBoost = mix(1.0, 2.2, clamp(bright, 0.0, 1.0));
        float speed = mix(speedMin, speedMax, hash21(cell + seed + 9.0)) * uLook.x * speedBoost;
        float n1 = noise1D(uTime * speed * 2.3 + tSeed);
        float n2 = noise1D(uTime * speed * 5.9 + tSeed * 1.7 + 31.0);
        float tw = clamp(n1 * 0.65 + n2 * 0.35, 0.0, 1.0);
        tw = mix(1.0, tw, twinkleGate);
        float twinkleFactor = mix(0.30, 1.0, tw);
        float size = baseSize * mix(0.88, 1.12, tw) * mix(1.0, 0.62, extinction);

        // a rare, brief flare — discrete per-star events, never synchronized
        float bucket = floor(uTime * 0.12 + hash21(cell + seed + 13.0) * 60.0);
        float burstRoll = hash21(cell + seed + bucket * 0.017 + 21.0);
        float burstEnv = smoothstep(0.90, 1.0, burstRoll) * twinkleGate;
        float burstPhase = fract(uTime * 0.12 + hash21(cell + seed + 13.0) * 60.0);
        float burst = burstEnv * exp(-pow((burstPhase - 0.5) * 9.0, 2.0));

        // Airy-ish profile: intense POINT core, wider dim bloom. The halo
        // carries an EXTRA bright factor (∝ bright² overall) so only a
        // genuinely bright fibre blooms — a dim point stays a point, never
        // a grey blob. The window fades the wide terms out before the cell
        // edge — the clip the reference left for its bloom chain to hide.
        // ×2.2 on the core so a beacon's centre saturates the exposure
        // shoulder to genuinely WHITE-HOT — a lit fibre end, not a grey dot
        float coreR = size * 0.5;
        float core = exp(-(d * d) / (2.0 * coreR * coreR)) * 2.2;
        // halo σ capped to 13% of the cell so the gaussian genuinely dies
        // before the border — uncapped, a midground halo plateaus across
        // its whole cell and the window only rounds the square's corners
        float haloR = min(size * 2.0, cellSize * 0.13);
        float halo = exp(-(d * d) / (2.0 * haloR * haloR)) * 0.25 * clamp(bright, 0.0, 1.0);
        // the window fades at the CELL EDGE (local), not around the star —
        // a jittered star can sit 0.22 from its border, and a radial window
        // around the star leaves the halo hard-cut there as a soft square
        vec2 edge = vec2(0.5) - abs(local);
        float win = smoothstep(0.0, 0.18, min(edge.x, edge.y));

        // faint capped spikes; diagonals only past the top-2% threshold
        float spikeLen = min(size * 8.5, 0.030);
        float spikeW = clamp(size * 0.16, 0.0004, 0.0016);
        float sh = exp(-abs(relUv.y) / spikeW) * exp(-abs(relUv.x) / spikeLen);
        float sv = exp(-abs(relUv.x) / spikeW) * exp(-abs(relUv.y) / spikeLen);
        float spikes = (sh + sv) * spikeAmt * bright * 0.18;
        if (bright > 1.05) {
            vec2 diagRel = rot(0.7854) * relUv;
            float dLen = spikeLen * 0.62, dW = spikeW * 1.3;
            float dh = exp(-abs(diagRel.y) / dW) * exp(-abs(diagRel.x) / dLen);
            float dv = exp(-abs(diagRel.x) / dW) * exp(-abs(diagRel.y) / dLen);
            spikes += (dh + dv) * spikeAmt * bright * 0.10;
        }

        float extinctionDim = mix(1.0, 0.22, extinction);
        float amp = (1.0 + burst * 2.6) * bright * twinkleFactor * extinctionDim;
        float glowIntensity = (halo + spikes) * win * amp;
        float coreIntensity = core * amp;

        // a star washes toward white as it flares, and warms as it dims —
        // extinction pulls it toward dusty amber like any low light
        float tempSeed = hash21(cell + seed + 17.0);
        vec3 col = mix(spectralColor(tempSeed, uLook.z), vec3(1.0), tw * 0.35 + burst * 0.5);
        col = mix(col, vec3(1.0, 0.62, 0.36), extinction * 0.55);

        // one-texel chromatic fringe at the spike tips
        vec3 fringe = (vec3(1.05, 1.0, 0.92) * sh + vec3(0.92, 0.98, 1.08) * sv)
                      * win * spikeAmt * bright * 0.05;
        // the point itself carries a subtle spectral cast — a fibre end is
        // near-white but never colourless
        result = mix(vec3(1.0), col, 0.35) * coreIntensity + col * glowIntensity + fringe;
    }
    return result;
}

void main() {
    // centred, aspect-true, +y up — extinction and the band need real "down"
    vec2 uv = (qt_TexCoord0 - 0.5) * uRes.xy / uRes.y;
    uv.y = -uv.y;
    float den = clamp(uDensity, 0.0, 2.0);
    // celestial artwork first (uRes.w gates it): its backbone pulls the
    // fibres into the painted streams. Off, the sky is stars alone and the
    // cluster field carries the whole structure.
    float backbone = 0.0;
    float artAlpha = 0.0;
    vec3 art = vec3(0.0);
    if (uRes.w > 0.5) art = nebula(uv, backbone, artAlpha);
    float clus = clusterField(uv, backbone);
    vec3 col = art;

    // The 80/15/5 rule, six gauges of fibre. Four static dust beds carry the
    // texture; the midground is where the eye picks out points; the beacons
    // are the rare fully-bright, fully-spiked fibres. Irrational-ish angles
    // so no two grids ever align.
    col += starLayer(uv, clus, 0.0105, 0.00, 1.0, 0.0009, 0.0018, 0.04, 0.16, den * 1.00, 0.0,             0.08, 0.30, 0.0); // dust 1 — static
    col += starLayer(uv, clus, 0.0145, 0.19, 1.5, 0.0010, 0.0020, 0.04, 0.16, den * 0.95, 0.0,             0.09, 0.34, 0.0); // dust 2 — static
    col += starLayer(uv, clus, 0.0190, 0.37, 2.0, 0.0011, 0.0022, 0.04, 0.15, den * 0.90, 0.0,             0.10, 0.40, 0.0); // dust 3 — static
    col += starLayer(uv, clus, 0.0250, 0.58, 2.5, 0.0012, 0.0026, 0.04, 0.15, den * 0.80, uLook.y * 0.05,  0.11, 0.50, 0.0); // dust 4 — static
    col += starLayer(uv, clus, 0.0480, 0.91, 4.0, 0.0022, 0.0060, 0.035, 0.13, den * 0.50, uLook.y * 0.45, 0.24, 1.15, 0.65); // midground — slow pulse
    col += starLayer(uv, clus, 0.1150, 1.34, 6.0, 0.0045, 0.0110, 0.03, 0.10, den * 0.12, uLook.y,         0.60, 2.00, 1.0); // beacons — rapid twinkle

    // SHOOTING STAR v3 — the owner: "doesn't really look like a shooting
    // star". It didn't: it crawled for ~5 s. A real meteor lives about a
    // second. Now: ~1.1 s streak, a genuinely BRIGHT head point that leads,
    // a tapering tail that cools blue behind it, direction hashed per event
    // with a downward bias. Still rare — the real ceiling never rains.
    if (uRes.z > 0.5) {
        float cyc = 12.0;
        float seedT = floor(uTime / cyc);
        float roll = hash11(seedT * 13.7 + 5.0);
        float t = fract(uTime / cyc) * cyc;
        float run = 1.1;
        if (roll > 0.55 && t < run) {
            float prog = t / run;
            vec2 start = (hash22(vec2(seedT, 4.0)) - 0.5) * vec2(1.5, 0.8);
            float ang = -0.2 - hash11(seedT * 7.9 + 2.0) * 2.7;   // always downward-ish
            vec2 dir = vec2(cos(ang), sin(ang));
            float envelope = smoothstep(0.0, 0.06, prog) * (1.0 - smoothstep(0.60, 1.0, prog));
            vec2 head = start + dir * prog * 0.85;
            float trailLen = 0.16 + 0.12 * prog;
            vec2 tail = head - dir * trailLen;
            float along = clamp(dot(uv - tail, dir), 0.0, trailLen);
            vec2 closest = tail + dir * along;
            float perp = length(uv - closest);
            float af = along / trailLen;                            // 0 tail → 1 head
            // a HAIRLINE, not a beam — the first cut's width read as a
            // flashlight cone on render (proved); a real trail is a thin
            // scratch of light barely wider at the head than the tip
            float width = mix(120000.0, 38000.0, af);
            float streak = exp(-perp * perp * width) * pow(af, 1.7);
            vec3 tailCol = mix(vec3(0.55, 0.70, 1.00), vec3(1.0, 0.98, 0.92), af);
            col += tailCol * streak * envelope * 1.4;
            // the head: a white-hot point, halo kept tight
            float hd = length(uv - head);
            col += vec3(1.0, 0.99, 0.95) * exp(-hd * hd * 90000.0) * envelope * 2.6;
            col += vec3(0.80, 0.88, 1.00) * exp(-hd * hd * 16000.0) * envelope * 0.30;
        }
    }

    // no bloom chain here, so: bound the radiance, then a soft exposure
    // shoulder in place of the HTML's tonemap — beacons roll to white-hot
    // instead of clipping to a flat disc, dust stays linear.
    col = min(col, vec3(9.0));
    col = 1.0 - exp(-col * 1.25);
    col *= uLook.w;
    // premultiplied: the stars are pure added light (alpha 0); the painted
    // artwork carries real coverage, dimming the wallpaper behind it the
    // way paint on leather does, so its blues and golds stay saturated
    fragColor = vec4(col * qt_Opacity, artAlpha * qt_Opacity);
}
