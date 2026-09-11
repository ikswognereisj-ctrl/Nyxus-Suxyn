#version 440
// LiveWall, pass 1 of 2 — EVERYTHING THAT DEPENDS ONLY ON THE WALLPAPER.
//
// This runs ONCE, when the picture loads, and never again. What it bakes:
//
//   .rgb  the picture blurred at the detail radius — the "dust", the
//         low-frequency part that the fluid is allowed to push around.
//   .a    the galaxy mask — where the band is, found in the image itself.
//
// WHY THIS PASS EXISTS AT ALL, and it is the whole reason the effect is
// affordable. The first cut computed both of these in the composite, per
// pixel, every frame: a 25-tap ring for the mask and two more for the dust
// split, ~82 texture reads per pixel at 1920×1080×60 Hz. Measured on the
// owner's live shell that cost about +70 points of CPU AT REST, and he had
// just told me a shader was costing him too much.
//
// Neither term is a function of time. Neither is a function of the fluid.
// Both are functions of the WALLPAPER ALONE — a file that does not change
// while it is on screen. So they are computed once into this texture and the
// composite reads them with two fetches. That is the entire optimisation, and
// it is not a trick: it is noticing that most of the work was constant.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec2  u_resolution;
    vec4  u_mask;   // x low stop · y high stop · z mask radius px · w detail radius px
};
layout(binding = 1) uniform sampler2D src;

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

const vec2 RING[12] = vec2[12](
    vec2( 1.000,  0.000), vec2( 0.866,  0.500), vec2( 0.500,  0.866),
    vec2( 0.000,  1.000), vec2(-0.500,  0.866), vec2(-0.866,  0.500),
    vec2(-1.000,  0.000), vec2(-0.866, -0.500), vec2(-0.500, -0.866),
    vec2( 0.000, -1.000), vec2( 0.500, -0.866), vec2( 0.866, -0.500)
);

// Two sub-rings offset against each other, so the sampling pattern does not
// lay a visible 12-fold star down on a smooth gradient.
vec3 blurAt(vec2 uv, vec2 r) {
    vec3 s = texture(src, uv).rgb * 1.4;
    float w = 1.4;
    for (int i = 0; i < 12; i++) {
        s += texture(src, uv + RING[i] * r).rgb;
        s += texture(src, uv + RING[i] * r * 0.55).rgb * 0.9;
        w += 1.9;
    }
    return s / w;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = 1.0 / max(u_resolution, vec2(1.0));

    // ── THE GALAXY MASK, read off the picture ────────────────────────────
    // Nothing here knows where the band is in advance. A wide blur of the
    // picture's own luminance finds it: the band is broad and survives, a star
    // is a pinprick and averages away to nothing at this radius. That is
    // exactly why the mask lands on the dust and never on the starfield — and
    // why it will find the band in a DIFFERENT wallpaper without being retuned.
    //
    // Saturation counts alongside brightness, because the band is not merely
    // bright, it is COLOURED. That is what keeps the mask off the warm grey
    // haze in the corners of this picture, which is bright-ish and must stay
    // perfectly still.
    //
    // The low stop is above zero so the empty sky comes out EXACTLY 0.0.
    // smoothstep clamps; an asymptotic falloff would leave a real displacement
    // in every pixel of the frame, and "everything else just stays put" would
    // quietly not be true.
    vec3 wide = blurAt(uv, px * u_mask.z);
    float mx = max(max(wide.r, wide.g), wide.b);
    float mn = min(min(wide.r, wide.g), wide.b);
    float sat = (mx - mn) / max(mx, 1e-4);
    float galaxyMask = smoothstep(u_mask.x, u_mask.y, lum(wide) * (0.55 + 0.85 * sat));
    galaxyMask = galaxyMask * galaxyMask * (3.0 - 2.0 * galaxyMask);

    // ── THE DUST ─────────────────────────────────────────────────────────
    // The picture at the detail radius. The composite subtracts this from the
    // sharp original to recover the stars, moves this, and adds the stars back
    // where they were — which is what keeps the pinpricks pin-sharp while the
    // cloud flows.
    vec3 dust = blurAt(uv, px * u_mask.w);

    fragColor = vec4(dust, galaxyMask);
}
