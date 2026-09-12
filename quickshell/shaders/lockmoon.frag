#version 440
// Nyxus Suxyn — THE MOON, as it actually is tonight.
//
// Owner ask, 2026-08-23/24: a moon in the lock screen's sky, "very very
// detailed ... down to the craters", carrying the real phase — "crescent or
// half ... exactly how it is in that exact night" — and, when it happens, the
// big orange one low in the sky.
//
// ── THE PHASE IS NOT A SHAPE ─────────────────────────────────────────────
// Nothing here draws a crescent. This lights a real sphere, wearing NASA's LRO
// albedo map and its LDEM elevation, from the direction the sun actually is
// relative to the Moon at this minute. Crescent, half, gibbous and full are
// what that LOOKS like — they are consequences, not cases. Which is why the
// terminator is ragged: it falls across real crater rims, catching the high
// ground and leaving the floors black, exactly as it does through binoculars.
// A drawn crescent cannot do that, and a drawn crescent is what every other
// desktop moon is.
//
// ── THE LIGHT IS LUNAR, NOT LAMBERTIAN ───────────────────────────────────
// A full moon looks like a flat disc, not a shaded ball. That is real: the
// regolith back-scatters, so the Moon does not darken toward its limb the way
// a diffuse sphere does. Lambert alone renders a full moon as a sphere with a
// dark rim and it reads instantly as wrong. This uses a Lommel-Seeliger term,
// mu0 / (mu0 + mu), which is the standard lunar photometric function and gets
// the flat disc for free.
//
// ── EARTHSHINE ───────────────────────────────────────────────────────────
// The dark limb of a thin crescent is faintly visible — "the old moon in the
// new moon's arms" — because the Earth is a bright light in the Moon's sky.
// It is brightest when the Moon is thinnest, so it rides (1 - illuminated).
//
// ── AND THE ORANGE ONE ───────────────────────────────────────────────────
// The huge orange moon is not a special event to be guessed at. It is
// atmospheric extinction: low in the sky you are looking through many times
// more air, which scatters the blue out and dims the whole disc. Airmass is a
// function of ALTITUDE, and altitude is something we know exactly for this
// person at this moment — so the reddening is computed, not faked, and it
// happens on precisely the nights it happens outside. `uTint` and the dimming
// in `uGeom.w` carry it in from LockMoon.qml.
//
// ⛔ Draws on a timer, never per frame. See LockMoon.qml.
//

layout(location = 0) in  vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec4  uRes;      // xy = item size px       zw = moon centre px
    vec4  uGeom;     // x = radius px  y = relief gain  z = earthshine  w = brightness
    vec4  uSun;      // xyz = unit vector to the sun, in view space   w = unused
    vec4  uTint;     // rgb = extinction tint            a = limb softness px
};

layout(binding = 1) uniform sampler2D moonTex;    // LRO colour
layout(binding = 2) uniform sampler2D moonHgt;    // LDEM elevation

const float PI = 3.14159265359;

void main(){
    vec2  frag = qt_TexCoord0 * uRes.xy;
    // Same Y flip as lockearth.frag, and for the same reason: qt_TexCoord0
    // counts downward, the sphere maths below treats +y as up.
    vec2  p    = vec2(frag.x - uRes.z, uRes.w - frag.y) / uGeom.x;
    float r2   = dot(p, p);

    vec3  col = vec3(0.0);
    float a   = 0.0;

    if (r2 < 1.0){
        float z = sqrt(max(0.0, 1.0 - r2));
        vec3  n = vec3(p, z);                 // the Moon keeps one face to us:
                                              // no rotation, the near side IS
                                              // the texture's centre.
        float lat = asin(clamp(n.y, -1.0, 1.0));
        float lon = atan(n.x, n.z);
        vec2  uv  = vec2(lon / (2.0 * PI) + 0.5, 0.5 - lat / PI);

        vec3  albedo = texture(moonTex, uv).rgb;

        // ── crater relief ────────────────────────────────────────────────
        // The elevation map's own gradient, turned into a surface normal. This
        // is what makes the terminator ragged and the crater walls catch light
        // instead of the whole disc fading smoothly.
        vec2  tx = 1.0 / vec2(textureSize(moonHgt, 0));
        float hL = texture(moonHgt, uv - vec2(tx.x, 0.0)).r;
        float hR = texture(moonHgt, uv + vec2(tx.x, 0.0)).r;
        float hD = texture(moonHgt, uv - vec2(0.0, tx.y)).r;
        float hU = texture(moonHgt, uv + vec2(0.0, tx.y)).r;
        vec3  east  = normalize(vec3(cos(lon), 0.0, -sin(lon)));
        vec3  north = cross(n, east);
        vec3  nrm   = normalize(n - (east * (hR - hL) + north * (hU - hD)) * uGeom.y);

        float mu0 = dot(nrm, uSun.xyz);          // cos incidence
        float mu  = max(dot(n, vec3(0.0, 0.0, 1.0)), 0.02);   // cos emission

        // Lommel-Seeliger: the flat-disc full moon, for free.
        float lit = max(mu0, 0.0);
        float ls  = lit / max(lit + mu, 0.03);

        // A softened terminator, but only a little: on the real Moon it is
        // sharp, because there is no air to scatter light past it.
        float term = smoothstep(-0.06, 0.10, mu0);

        vec3 surf = albedo * ls * term * 2.15;

        // earthshine on the unlit side, strongest when the crescent is thinnest
        surf += albedo * uGeom.z * (1.0 - term) * vec3(0.55, 0.62, 0.78);

        col = surf * uTint.rgb * uGeom.w;
        a   = 1.0;
    }

    // A one-pixel-ish soft edge so the disc does not alias into the starfield.
    float edge = 1.0 - smoothstep(1.0 - uTint.a, 1.0, sqrt(r2));
    a *= edge;

    fragColor = vec4(col * a, a) * qt_Opacity;
}
