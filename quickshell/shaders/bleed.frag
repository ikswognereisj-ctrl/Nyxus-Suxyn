#version 440
// Nyxus Suxyn — THE BLEED. The part of the glass that survives a black wall.
//
// The owner, describing a reference: "the colors just a little bleed in to it,
// or there's just spots of a color." Then, later and more precisely: does the
// glass still read as glass "even on a black background or dark background".
//
// That second question is the real one, and it has a physical answer. A pane
// reads as glass because you see something through it and because light catches
// its edges. On a near-black wallpaper there is nothing behind to see, so the
// body carries no information at all — every surface collapses to a flat dark
// fill with a nice rim. The spec's answer is "edges do the work, not
// cloudiness" (DESIGN_LANGUAGE_NYXUS_GLASS §4), and the edges DO hold. But a
// body with literally zero internal variation is a painted rectangle, and no
// amount of rim fixes that.
//
// Real glass pools its colour: thicker here, thinner there, with no boundary
// you can point at. Three off-centre elliptical pools reproduce that, and they
// are deliberately at awkward sizes and positions so no two line up and the eye
// cannot find a repeat.
//
// THESE ARE THE SAME THREE POOLS AS gtk-4.0/gtk.css. Same centres, same radii,
// same alphas, same two-rose-one-teal split — because the point of this file is
// that a Quickshell surface and a GTK window are the same material, and that
// stops being true the moment the two are tuned separately. If one is retuned,
// retune both in the same commit.
//
// Why two rose and one teal: a single hue pooling on itself reads as uneven
// backlighting — a dirty pane, not a thick one. The second hue is what makes it
// read as depth rather than as a smudge.
//
// Alphas are 0.070–0.100: below where you would notice them as shapes, above
// where they do nothing. Tune the ALPHAS via `strength`. Do not move the
// centres — the irregularity is the feature.
//
// Rebuild with shell/shaders/build.sh.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 geom;   // x,y = item px size · z = strength (1.0 = the CSS alphas)
    vec4 radii;  // px, in order: top-left, top-right, bottom-right, bottom-left
};

// Signed distance to a rounded rect with per-corner radii, in pixels.
// Negative inside. Same construction Pane.qml's material uses, so a bleed and
// a pane clipped to the same geometry agree on where the edge is.
float sdRoundRect(vec2 p, vec2 half_, vec4 r) {
    // pick the radius for the quadrant this fragment is in
    float rx = (p.x > 0.0) ? ((p.y > 0.0) ? r.z : r.y)
                           : ((p.y > 0.0) ? r.w : r.x);
    vec2 q = abs(p) - half_ + rx;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - rx;
}

// One elliptical pool. `c` is the centre and `rad` the radii, both as a
// FRACTION of the item — so a pool keeps its proportions on a 90 px icon and on
// a 900 px panel instead of becoming a dot on one and a wash on the other.
// smoothstep from the centre out gives the soft, edgeless falloff; a linear
// falloff leaves a visible disc boundary at these alphas.
vec3 pool(vec2 uv, vec2 c, vec2 rad, vec3 col, float a, float strength) {
    vec2 d = (uv - c) / rad;
    float t = 1.0 - smoothstep(0.0, 1.0, length(d));
    return col * (a * strength * t);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * geom.xy;
    float strength = geom.z;

    // The three pools, matching gtk.css layer for layer:
    //   radial-gradient(ellipse 62% 48% at 17% 11%, rgba(174, 32,108,0.100) …)
    //   radial-gradient(ellipse 44% 58% at 83% 74%, rgba( 10,162,214,0.070) …)
    //   radial-gradient(ellipse 72% 38% at 52% 97%, rgba(137, 25, 85,0.085) …)
    // CSS gives ellipse EXTENT as a percentage of the box, which is a radius,
    // so the numbers transfer directly.
    vec3 c = vec3(0.0);
    c += pool(uv, vec2(0.17, 0.11), vec2(0.62, 0.48),
              vec3(0.68235, 0.12549, 0.42353), 0.100, strength);   // #ae206c
    c += pool(uv, vec2(0.83, 0.74), vec2(0.44, 0.58),
              vec3(0.03922, 0.63529, 0.83922), 0.070, strength);   // #0aa2d6
    c += pool(uv, vec2(0.52, 0.97), vec2(0.72, 0.38),
              vec3(0.53725, 0.09804, 0.33333), 0.085, strength);   // #891654

    // Clip to the host's rounded rect. 1 px of feather so the bleed does not
    // draw a hard edge of its own just inside the Lip — it is the inside of the
    // pane, and the pane's own edge stack owns the boundary.
    vec2 half_ = geom.xy * 0.5;
    float d = sdRoundRect(px - half_, half_, radii);
    float mask = 1.0 - smoothstep(-1.0, 0.0, d);

    // Additive over whatever the surface already painted: this is light INSIDE
    // the pane, not a coat on top of it, so it must not darken anything. rgb
    // may exceed alpha — premultiplied output composites that as added light,
    // the same convention pane.frag uses for its rim.
    float a = clamp(max(max(c.r, c.g), c.b), 0.0, 1.0) * mask * qt_Opacity;
    fragColor = vec4(c * mask * qt_Opacity, a);
}
