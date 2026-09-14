#version 440
// Nyxus Suxyn — the Pane. One material, one pass.
//
// HORIZON's material primitive (docs/DESIGN_LANGUAGE_HORIZON_2026-08-03.md §4).
// Every surface in the shell is one of these. A rounded-rect SDF with
// PER-CORNER radii draws four things at once:
//
//   body   — the dark translucent fill. Colour never goes behind text.
//   rim    — a 1px DISPERSIVE edge. Not a border colour: Theme.lookSweep
//            distributed around the perimeter by the edge normal, so the
//            top-left of any surface catches the look's bright stop and the
//            bottom-right catches the look's rim (plum on ice, magma[5] on
//            magma) — as if the galaxy sweep were the light and the rim
//            were a prism. This is the detail that makes unrelated surfaces
//            look like one product.
//
//            TRK-3546 makes that prism a STATE CUE. `state.x` is the
//            dispersion gain: how strongly this surface splits the one
//            sweep, NOT where on the sweep it sits. That distinction is the
//            whole design. Biasing `t` per surface would hand each pane its
//            own lamp colour and break MirrorEdge.qml's standing rule that
//            light comes from above, ONCE, for the whole build. Changing the
//            gain instead changes the surface's refractive index: same lamp,
//            same five stops, a better or worse prism. A surface that is
//            being attended to spreads the sweep to its ends and reads
//            spectral; a dormant one collapses toward the middle and reads
//            as one quiet colour. No new hue can enter, because the gain
//            only ever samples `sweepColor` — and it can never become the
//            forbidden second outline (Pane.qml §4.4), because a gain change
//            leaves the perimeter varied rather than drawing a line.
//            1.0 is exactly the shipped look, and 0.0 is read AS 1.0 so an
//            unset uniform cannot silently flatten every rim in the build.
//   crown  — a hairline inner highlight along the top edge only. Light comes
//            from above; at 1px this is what makes glass read as glass.
//   bloom  — a soft outer glow, weighted downward. Elevation is expressed as
//            EMITTED LIGHT, never as a drop shadow (§4.3).
//
// Per-corner radii exist so a surface can be flush-square where it meets the
// horizon and generously round where it faces open space.
//
// Output is premultiplied; rgb may exceed alpha, which composites as added
// light so the rim glows over whatever is behind rather than covering it.
// Rebuild with shell/shaders/build.sh.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 geom;    // x,y = this item's px size (surface + 2*pad) · z = pad px
    vec4 radii;   // px, in order: top-left, top-right, bottom-right, bottom-left
    vec4 body;    // fill rgba, straight (premultiplied below)
    vec4 look;    // x rim · y crown · z bloom alpha · w focus (0..1)
    vec4 state;   // x dispersion gain (1.0 = shipped) · yzw reserved
    vec4 sweep0;  // Theme.lookSweep[0]  ice teal / magma bright
    vec4 sweep1;
    vec4 sweep2;
    vec4 sweep3;
    vec4 sweep4;  // ice plum #891955 / magma[5]  — the widget rim
};

// Live colour is Theme.lookSweep via uniforms. Do not fall back to the
// ice plum rim — that kept MAGMA widgets showing the first layer in the
// corners. Unset uniforms read as black, not #891955.
vec3 sweepColor(float t) {
    vec3 a = sweep0.rgb;
    vec3 b = sweep1.rgb;
    vec3 c = sweep2.rgb;
    vec3 d = sweep3.rgb;
    vec3 e = sweep4.rgb;
    t = clamp(t, 0.0, 1.0) * 4.0;
    if (t < 1.0) return mix(a, b, t);
    if (t < 2.0) return mix(b, c, t - 1.0);
    if (t < 3.0) return mix(c, d, t - 2.0);
    return mix(d, e, t - 3.0);
}

// p centred, y DOWN. b = half extent. r = TL, TR, BR, BL.
float sdPane(vec2 p, vec2 b, vec4 r) {
    float rr;
    if (p.x > 0.0) rr = (p.y > 0.0) ? r.z : r.y;
    else           rr = (p.y > 0.0) ? r.w : r.x;
    rr = min(rr, min(b.x, b.y));
    vec2 q = abs(p) - b + rr;
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - rr;
}

void main() {
    vec2 px  = qt_TexCoord0 * geom.xy;
    vec2 c   = geom.xy * 0.5;
    vec2 p   = px - c;
    vec2 b   = c - vec2(geom.z);          // the surface, inset by the bloom pad

    float d = sdPane(p, b, radii);

    // Outward normal, by finite difference. Two extra SDF evaluations on a
    // handful of pixels — cheaper than any way of faking it.
    vec2 n = normalize(vec2(sdPane(p + vec2(1.0, 0.0), b, radii) - sdPane(p - vec2(1.0, 0.0), b, radii),
                            sdPane(p + vec2(0.0, 1.0), b, radii) - sdPane(p - vec2(0.0, 1.0), b, radii))
                       + vec2(1e-6));

    // DISPERSION: where the edge faces decides which part of the sweep it
    // catches. axis is the palette's 45° (accent.json sweep_angle).
    const vec2 axis = vec2(0.70710678, 0.70710678);
    // The gain is the surface's refractive index (see the header). Two ALU
    // ops on the same handful of rim pixels the normal already cost.
    float dg = (state.x > 0.0) ? state.x : 1.0;
    float t = clamp(0.5 + 0.5 * dg * dot(n, axis), 0.0, 1.0);

    float inside = clamp(0.5 - d, 0.0, 1.0);

    // ── rim ──────────────────────────────────────────────────────────
    float focus = clamp(look.w, 0.0, 1.0);
    // state.y is extra rim width in px (MAGMA glacier outline). 0 = shipped.
    float rimW  = 1.15 + 0.55 * focus + max(state.y, 0.0);
    float rimBand = clamp(1.0 - abs(d + 0.75) / rimW, 0.0, 1.0);
    rimBand = rimBand * rimBand * (3.0 - 2.0 * rimBand);
    // light from above: the top edge of anything is its brightest edge
    float lift = 0.55 + 0.45 * (0.5 - 0.5 * n.y);
    float rimI = look.x * lift * (1.0 + 0.85 * focus);

    // ── crown: 2px inside the top edge only ──────────────────────────
    float crownBand = clamp(1.0 - abs(d + 2.0) / 1.30, 0.0, 1.0);
    float up = clamp(-n.y, 0.0, 1.0);
    crownBand *= up * up;

    // ── bloom: outside, stronger below (light falls) ─────────────────
    float bl = 0.0;
    if (look.z > 0.0 && geom.z > 0.5) {
        float outD = max(d, 0.0);
        bl = exp(-outD / max(geom.z * 0.42, 1.0)) * (1.0 - inside);
        bl *= 0.28 + 0.72 * clamp(n.y * 0.5 + 0.5, 0.0, 1.0);
    }

    vec3  col = body.rgb * body.a * inside;
    float a   = body.a * inside;

    vec3 rimCol = sweepColor(t);
    col += rimCol * rimI * rimBand;
    a = max(a, rimBand * clamp(rimI, 0.0, 1.0));

    col += vec3(0.82, 0.88, 1.00) * look.y * crownBand;
    a = max(a, look.y * crownBand * 0.9);

    col += rimCol * look.z * bl;
    a += look.z * 0.55 * bl;

    fragColor = vec4(col, clamp(a, 0.0, 1.0)) * qt_Opacity;
}
