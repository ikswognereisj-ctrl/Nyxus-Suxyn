#version 440
// Nyxus Suxyn — THE MIRROR EDGE's fall, as one band that turns the corners.
//
// The owner, after TRK-3541 fixed GlassEdge and the seam was still there:
// "the corners arent fixed just an FYI i still seen them and still see them
// now." He was right, and the reason is that the band he was looking at is
// not GlassEdge's. On a widget chip `GlassEdge.wash` is 0, so its Sheen never
// draws at all — the lit rim on those cards is THIS file.
//
// ── WHAT WAS WRONG ───────────────────────────────────────────────────────
// The fall was four axis-aligned Rectangles: top, bottom, left, right. A
// straight strip cannot follow a bend, so each one was inset by the corner
// radius to stop it overhanging — `leftMargin: radiusTL`, and so on. This
// file's own comment said so plainly: "Fall strips still stop at the radius —
// a gap, not a pie."
//
// A gap is right: that is exactly what it is. Four strips that stop short
// leave every corner with no reflection on it, while the 1 px hairline above
// them DOES follow the outline. So the corner has an outline and no fall, and
// the straight has both — which is the seam, and it is on every card in the
// build.
//
// Insetting was the correct repair for the bug it was fixing. TRK-932 records
// the earlier cuts: a filled quarter-disk read as a pie, and a Canvas arc was
// removed for cost. Straights were the cheap way to stop the pie. They just
// could not close the corner.
//
// ── WHY ONE SHADER IS SIMPLER THAN FOUR RECTANGLES, NOT MORE COMPLEX ─────
// The four strips are not four effects. They are ONE effect — a reflection
// whose strength depends on which way the surface faces — sampled at four
// right angles. The header says as much: "Light still comes from ABOVE, once,
// for the whole build — the top rim returns the most, the bottom returns a
// weak bounce, the sides fall between."
//
// That is a function of the surface normal. Written as one, the corners stop
// being a special case: between the top and the side the strength simply
// interpolates, which is what a real reflection does anyway.
//
// The three strengths are carried over EXACTLY from the Rectangles, so a
// straight edge is unchanged:
//     top   1.00 x reflectAlpha      (u = +1)
//     sides 0.52 x reflectAlpha      (u =  0)
//     bottom 0.34 x reflectAlpha     (u = -1)
// with u = -n.y. The piecewise slope below hits all three on the nose and
// interpolates between them around the bend.
//
// Construction is pane.frag's, verbatim, as lip.frag's is — same per-corner
// sdRoundRect, same finite-difference normal. Three files, one idea of where
// an edge is. Retune one, retune all three.
//
// Rebuild with shell/shaders/build.sh.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 geom;   // x,y = item px size · z = depth px · w = strength
    vec4 radii;  // px: top-left, top-right, bottom-right, bottom-left
    vec4 tint;   // rgb = Theme.text · a = Theme.reflectAlpha
    vec4 fall;   // x = Theme.reflectH · y,z,w unused
};

float sdRoundRect(vec2 p, vec2 half_, vec4 r) {
    float rx = (p.x > 0.0) ? ((p.y > 0.0) ? r.z : r.y)
                           : ((p.y > 0.0) ? r.w : r.x);
    vec2 q = abs(p) - half_ + rx;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - rx;
}

void main() {
    vec2 half_ = geom.xy * 0.5;
    vec2 p = qt_TexCoord0 * geom.xy - half_;

    float d = sdRoundRect(p, half_, radii);

    vec2 n = normalize(vec2(
        sdRoundRect(p + vec2(1.0, 0.0), half_, radii) - sdRoundRect(p - vec2(1.0, 0.0), half_, radii),
        sdRoundRect(p + vec2(0.0, 1.0), half_, radii) - sdRoundRect(p - vec2(0.0, 1.0), half_, radii)));

    // +1 facing up, 0 on the sides, -1 facing down.
    float u = -n.y;

    // The three carried-over strengths, and everything between them. Steeper
    // above the horizon than below it, because the top gains 0.48 over the
    // sides while the bottom only loses 0.18 — light from one lamp above.
    float w = 0.52 + (u > 0.0 ? 0.48 : 0.18) * u;

    // Depth into the pane, and the linear fall the Gradient expressed: full at
    // the rim, nothing by `reflectH` of the band. Brightest exactly AT the rim
    // where the reflection meets its object, gone a moment later — and with no
    // terminator, because a reflection that ends in an edge is a rectangle.
    float depth = -d;
    float span = max(geom.z * fall.x, 1.0);
    float t = clamp(depth / span, 0.0, 1.0);

    // Start 1 px in, matching the Rectangles' 1 px margin off the hairline, so
    // the fall sits UNDER the outline rather than fighting it.
    float begin = smoothstep(0.5, 1.5, depth);
    float inside = 1.0 - smoothstep(-0.5, 0.5, d);

    float a = tint.a * geom.w * w * (1.0 - t) * begin * inside;
    a = clamp(a, 0.0, 1.0);

    fragColor = vec4(tint.rgb * a, a) * qt_Opacity;
}
