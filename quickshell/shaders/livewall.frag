#version 440
// Nyxus Suxyn — THE LIVING WALLPAPER, pass 2 of 2: the composite.
//
// The owner's own galaxy picture, with the swirls INSIDE the band stirred by
// the cursor exactly the way the taskbar's paint is. His words, and they are
// the whole specification:
//
//   "the swirls i want inside the galaxy so if i move over it it swirls like
//    the bottom bar does — everything else just stays put and doesn't move"
//
// Three rules, and the third is the one that is easy to get wrong:
//
//   1. IT IS HIS PICTURE. Not a generated sky. Every pixel outside the galaxy
//      is his file, bit for bit. This was built as a procedural galaxy twice
//      before the ask was read correctly — he has a picture he likes, and the
//      job is to move part of it, not to replace it.
//   2. THE STIRRING IS THE BAR'S OWN FLUID. `Swirl.qml` is a real solver and
//      it is what he pointed at. It is passed in as `paint` rather than
//      re-derived, so this build has one fluid and not two that drift apart.
//   3. THE STARS DO NOT MOVE AND DO NOT SMEAR. `prep.rgb` is the picture
//      blurred — the dust. `base - prep.rgb` is what is left — the stars and
//      the grain. Only the dust is displaced; the stars are added back at
//      their ORIGINAL coordinate. Warping the whole image is the obvious
//      thing and it is what makes this class of effect look cheap: the
//      pinpricks swim and the eye reads the whole frame as rubber.
//
// ── EIGHT TEXTURE READS, DOWN FROM EIGHTY-TWO ────────────────────────────
// Everything that depends only on the wallpaper — the mask and the blurred
// dust — is baked once by `livewall_prep.frag` and arrives here in one RGBA
// texture. The first cut recomputed all of it per pixel per frame and cost
// ~+70 points of CPU at rest on the owner's machine. Nothing about the look
// changed to fix that; the constant work simply stopped being redone.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec2  u_resolution;
    vec4  u_flow;   // x displace px · y paint bleed · z lift · w flow gain
};
layout(binding = 1) uniform sampler2D src;    // the wallpaper, sharp
layout(binding = 2) uniform sampler2D prep;   // rgb = dust · a = galaxy mask
layout(binding = 3) uniform sampler2D paint;  // Swirl's rendered fluid

float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = 1.0 / max(u_resolution, vec2(1.0));

    vec3 base = texture(src, uv).rgb;
    vec4 P = texture(prep, uv);
    float galaxyMask = P.a;

    // More than half this picture is empty sky and none of the work below
    // belongs there. This is also the guarantee itself: the mask is exactly
    // 0.0 out here, so the output is his file untouched.
    if (galaxyMask <= 0.0) {
        fragColor = vec4(base * qt_Opacity, qt_Opacity);
        return;
    }

    // ── THE FLUID DRIVES THE DISPLACEMENT ────────────────────────────────
    // `paint` is the taskbar's own solver output. Its GRADIENT is the
    // direction the liquid is locally flowing — and the PERPENDICULAR of that
    // gradient runs along the liquid's ridges. Pushing along the perpendicular
    // is what reads as a swirl; pushing along the gradient itself only makes
    // things bulge.
    //
    // Sampled at a wider radius than one pixel on purpose: the solver runs at
    // a fraction of screen resolution (short side 96–224 px, which is why it
    // costs the same full-screen as it does in the bar), so a one-texel
    // gradient would read its interpolation seams rather than its flow.
    vec2 g = px * 6.0;
    float pr = lum(texture(paint, uv + vec2(g.x, 0.0)).rgb);
    float pl = lum(texture(paint, uv - vec2(g.x, 0.0)).rgb);
    float pu = lum(texture(paint, uv + vec2(0.0, g.y)).rgb);
    float pd = lum(texture(paint, uv - vec2(0.0, g.y)).rgb);
    vec2 flow = vec2(-(pu - pd), (pr - pl));

    // ── DIRECTION FROM THE GRADIENT, MAGNITUDE FROM A SATURATING CURVE ───
    // The raw gradient cannot be used as a distance and this is the mistake
    // that made the first working build LOOK broken. The fluid field is smooth
    // and rendered at 480×270, so a luminance difference across six screen
    // pixels is on the order of 0.02 — multiply that by a `displacePx` of even
    // 90 and the picture moves by two pixels. Measured on screen: 4.67/255
    // mean change, which is a shimmer, not a swirl. The knob did not mean what
    // its name said.
    //
    // Splitting direction from magnitude fixes that and makes the knob honest:
    // the gradient decides WHICH WAY the dust goes, and an exponential
    // saturation decides HOW FAR as a fraction of `displacePx`. So displacePx
    // is now genuinely "the furthest this may push the dust, in pixels", and
    // `u_flow.w` is how briskly a weak flow reaches that maximum.
    float m = length(flow);
    vec2 dir = (m > 1e-6) ? flow / m : vec2(0.0);
    float amt = 1.0 - exp(-m * max(u_flow.w, 1.0));
    flow = dir * amt;

    // UNITS. `u_flow.x` is a distance in PIXELS and `px` converts pixels to
    // UV, so the product is the whole conversion and nothing else belongs in
    // it. The first cut also multiplied by u_resolution.y, which turned a
    // 30-pixel push into ~17 screen-widths: every sample landed on the far
    // side of the picture and the band came out as liquid marble. It looked
    // deliberate, which is the dangerous part — a units bug at that scale does
    // not read as a bug, it reads as a style.
    //
    // The mask gates the displacement itself, so the motion dies out smoothly
    // at the band's edge rather than tearing against the still sky.
    vec2 disp = flow * u_flow.x * px * galaxyMask;

    // ── DISPLACE THE DUST, HOLD THE STARS ────────────────────────────────
    vec3 dustWarp = texture(prep, uv + disp).rgb;   // the dust, moved
    vec3 detail   = base - P.rgb;                   // stars and grain, never moved
    vec3 lit = dustWarp + detail;

    // Optional: the liquid's own colour and light bleeding into the band.
    // Both default to zero — with them up you see the FLUID sitting on the
    // galaxy instead of the galaxy moving, which is not what was asked for.
    if (u_flow.y > 0.0 || u_flow.z > 0.0) {
        vec3 pc = texture(paint, uv).rgb;
        lit += pc * u_flow.y * galaxyMask;
        lit *= 1.0 + lum(pc) * u_flow.z * galaxyMask;
    }

    vec3 outc = mix(base, lit, galaxyMask);
    fragColor = vec4(max(outc, vec3(0.0)) * qt_Opacity, qt_Opacity);
}
