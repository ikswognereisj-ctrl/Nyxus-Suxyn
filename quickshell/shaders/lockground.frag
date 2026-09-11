#version 440
// Nyxus Suxyn — EARTHRISE. The lunar surface you are standing on.
//
// Owner ask, 2026-08-24, with four reference photographs: "maybe something more
// like this because then we would be the moon and you be able to still see it
// and earth in our view still rotating as it does ... it really needs to look
// amazing and flawless".
//
// So the camera comes down onto the Moon. This shader draws the ground: a
// curved lunar horizon across the lower frame, regolith running away from the
// viewer, and the Earth left to hang in the black above it — LockEarth,
// unchanged, still turned to his own coordinates and still wearing live
// weather.
//
// ── WHY THIS IS NOT THE MOON SPHERE, SCALED UP ───────────────────────────
// The obvious implementation is `lockmoon.frag` with an enormous radius and
// its centre pushed below the screen. It gives a correct horizon and it looks
// terrible: a 2048x1024 map stretched across a few degrees of arc is a handful
// of texels per screen inch, so every crater in the reference photographs
// becomes a grey smear. The albedo map is a portrait of the whole Moon; it was
// never a close-up.
//
// This draws the ground in PERSPECTIVE instead, and generates the surface at
// the scale the camera is actually at. Distance per pixel is known, so detail
// can be added per octave until it stops mattering — craters at hundreds of
// metres, bowls at tens, then the regolith grain right under the viewer.
//
// ── THE HORIZON IS CURVED, AND BY THE RIGHT AMOUNT ───────────────────────
// The Moon's radius is 1737 km. From eye height the horizon is about 2.4 km
// away, which is close enough that the curve is visible — it is the reason the
// reference photographs read instantly as "not Earth". `uGeom.z` carries the
// sagitta so it stays a measurement rather than a taste.
//
// ── ONE SUN ──────────────────────────────────────────────────────────────
// Lit by the same sun vector that draws the Earth's terminator overhead, for
// the reason the owner found himself: "isnt the moon in the wrong place for it
// to be dark where its dark on earth?" Two lights in one frame is the error
// this whole scene was rebuilt to avoid.
//
// ⛔ Drawn on a timer, never per frame. The lock screen has one job.
//
// © 2026 JOSEPH A. SIERENGOWSKI · NYX-J5W-2026-SIERENGOWSKI-LOCKED

layout(location = 0) in  vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec4  uRes;      // xy = item size px      zw = unused
    vec4  uGeom;     // x = horizon y (0..1)   y = eye height (m)
                     // z = curve sagitta      w = detail gain
    vec4  uSun;      // xyz = sun direction, view space (same as the Earth's)
    vec4  uTone;     // rgb = surface tint     a = earthshine fill
};

const float PI = 3.14159265359;

// ── hashes ───────────────────────────────────────────────────────────────
float h21(vec2 p){
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}
vec2 h22(vec2 p){
    return vec2(h21(p), h21(p + 17.13));
}
float vnoise(vec2 p){
    vec2 i = floor(p), f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x),
               mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p){
    float a = 0.5, s = 0.0;
    for (int i = 0; i < 5; i++){ s += a * vnoise(p); p *= 2.07; a *= 0.5; }
    return s;
}

// ── a crater field ───────────────────────────────────────────────────────
// One crater per cell, jittered, with a raised rim and a bowl floor. Returns
// (height, rimness). This is what the LRO map cannot give at this scale, and
// it is the whole reason the ground reads as the Moon rather than as grey sand.
vec2 craters(vec2 p, float seed){
    vec2 id = floor(p);
    vec2 fp = fract(p);
    float hgt = 0.0, rim = 0.0;
    for (int y = -1; y <= 1; y++){
        for (int x = -1; x <= 1; x++){
            vec2 g = vec2(float(x), float(y));
            vec2 o = h22(id + g + seed);
            // not every cell gets one, and they vary a lot in size
            if (o.x < 0.34) continue;
            float rad = 0.16 + 0.30 * o.y;
            vec2  c   = g + 0.5 + (h22(id + g + seed + 7.7) - 0.5) * 0.7;
            float d   = length(fp - c) / rad;
            if (d > 1.25) continue;
            // bowl, then a rim that stands proud just outside it
            float bowl = -0.55 * (1.0 - smoothstep(0.0, 1.0, d)) * (1.0 - d * d);
            float ring = exp(-pow(abs(d - 0.92) * 6.5, 2.0)) * 0.42;
            hgt += bowl + ring;
            rim  = max(rim, ring);
        }
    }
    return vec2(hgt, rim);
}

// height of the ground at a world position, with distance-aware detail
float ground(vec2 w, float lod, float gain){
    float h = 0.0;
    h += craters(w * 0.020, 3.0).x * 1.30;              // the big ones
    h += craters(w * 0.075, 11.0).x * 0.55 * lod;       // medium bowls
    h += craters(w * 0.260, 29.0).x * 0.22 * lod;       // small pits
    h += (fbm(w * 0.6) - 0.5) * 0.30;                   // rolling ground
    h += (fbm(w * 4.0) - 0.5) * 0.12 * lod;             // regolith
    return h * gain;
}

void main(){
    vec2  uv   = qt_TexCoord0;
    vec2  frag = uv * uRes.xy;
    float aspect = uRes.x / max(uRes.y, 1.0);

    // ── the horizon, curved ──────────────────────────────────────────────
    // A shallow arc rather than a straight line: the Moon is small enough that
    // this is real, and it is what makes the frame read as another world.
    float cx  = uv.x - 0.5;
    float horizon = uGeom.x + uGeom.z * (cx * cx) * 4.0;

    if (uv.y < horizon){
        fragColor = vec4(0.0);       // sky: the starfield and the Earth own it
        return;
    }

    // ── inverse perspective ──────────────────────────────────────────────
    // Depth from how far below the horizon the pixel is. Near the horizon this
    // races away, which is exactly the foreshortening in the photographs.
    float below = max(uv.y - horizon, 1e-4);
    float dist  = uGeom.y / below;                     // metres to this point
    float side  = cx * dist * aspect * 1.6;            // metres across

    // Detail fades with distance so the far ground does not boil into noise.
    float lod  = clamp(1.0 - smoothstep(60.0, 900.0, dist), 0.06, 1.0);
    vec2  wpos = vec2(side, dist);

    float gain = uGeom.w;
    float h    = ground(wpos, lod, gain);

    // ── normal, by differencing the same field ───────────────────────────
    float e = max(0.6, dist * 0.010);
    float hx = ground(wpos + vec2(e, 0.0), lod, gain) - h;
    float hy = ground(wpos + vec2(0.0, e), lod, gain) - h;
    // y is depth here, so the surface normal leans with distance
    vec3  n = normalize(vec3(-hx / e, 1.0, -hy / e));

    // ── light ────────────────────────────────────────────────────────────
    // The same sun that lights the Earth overhead. Ground normals are
    // y-up in this little frame, so the sun's screen vector maps in directly.
    vec3  sd  = normalize(vec3(uSun.x, max(uSun.y, 0.12), -uSun.z));
    float ndl = max(dot(n, sd), 0.0);

    // Regolith is famously back-scattering and almost shadowless in the
    // direction of the sun; Lommel-Seeliger again, and a hard black shadow
    // where the rim cuts the light, because there is no air to fill it.
    float mu = max(n.y, 0.05);
    float ls = ndl / max(ndl + mu, 0.05);

    vec3 albedo = vec3(0.62, 0.60, 0.575) * (0.80 + 0.40 * fbm(wpos * 0.35));
    vec3 col = albedo * (0.10 + 1.55 * ls);

    // earthshine / sky fill, so the shadowed sides are not dead black
    col += albedo * uTone.a * (0.35 + 0.65 * n.y);

    // a whisper of haze at the horizon keeps the join from being a hard cut
    col = mix(col, col * 0.86, smoothstep(400.0, 2400.0, dist));

    col *= uTone.rgb;

    // dither: the ground is a wide smooth gradient and banding shows badly
    col += (h21(frag) - 0.5) / 255.0;

    fragColor = vec4(max(col, vec3(0.0)), 1.0) * qt_Opacity;
}
