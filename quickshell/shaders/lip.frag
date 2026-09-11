#version 440
// Nyxus Suxyn — THE LIP AND THE SHEEN, following the bend.
//
// The owner, looking at any surface in the build: "the corner ... where its
// rounded its different there, its not the same edge as everything else, and
// thats everywhere ... it almost looks as if we didnt connect the edges."
//
// He was reading a real seam, and this file is the whole of it.
//
// ── WHAT WAS WRONG ───────────────────────────────────────────────────────
// The Lip (3 px) and the Sheen (30 px under it) were plain Rectangles anchored
// left and right with `leftMargin: radiusTL` / `rightMargin: radiusTR`. So the
// highlight ran across the flat top and STOPPED DEAD at the exact pixel the
// corner starts bending — square terminus, and the whole quarter-turn unlit.
// Meanwhile pane.frag's `crown` is an SDF band weighted by `up * up`, so it
// wraps the corner and fades out honestly. Two edge systems on one surface,
// agreeing along the straight and disagreeing through every bend.
//
// That mismatch is what the eye catches. Not the absence of a highlight in the
// corner — the fact that ONE of the two highlights is missing there.
//
// This was not carelessness. TRK-932: a 3 px Lip cannot carry a 22 px radius
// (Qt clamps corner radius to half the height), and the 30 px Sheen at r22
// filled each top corner with a solid ice quarter-disk. Replacing the pies with
// straights killed the ice blob, correctly. It just left the edge disconnected
// instead of making it turn.
//
// ── WHY A SHADER FIXES WHAT A RECTANGLE CANNOT ───────────────────────────
// A Rectangle's radius is a property of the RECTANGLE. What is wanted is a band
// measured from the OUTLINE — constant thickness along a path that bends. That
// is a signed distance field, and it is what pane.frag already uses next door.
//
// The construction here is deliberately IDENTICAL to pane.frag's crown:
//   · the same per-corner sdRoundRect,
//   · the same outward normal by finite difference,
//   · the same `up * up` weight.
// Not similar — identical, because the point is that the two edges cannot drift
// apart again. If one is retuned, retune both in the same commit.
//
// `up = clamp(-n.y, 0, 1)` is the physics: a lip is a specular highlight from
// light above, so it is brightest where the surface faces up and dies as the
// surface turns vertical. Squaring it tightens the falloff to match the crown.
// On the straight top n = (0,-1) so up = 1 and the band is EXACTLY what the
// Rectangles drew; on the sides up = 0 and there is no lip, exactly as before.
// Only the corner changes, which is the only place it was wrong.
//
// Rebuild with shell/shaders/build.sh.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 geom;      // x,y = item px size · z = edging · w = topEdge
    vec4 radii;     // px: top-left, top-right, bottom-right, bottom-left
    vec4 lipTint;   // rgb + a, Theme.glassLipTint
    vec4 sheenTint; // rgb = Theme.text · a = Theme.glassSheenA * wash
    vec4 band;      // x = lipTop · y = lipH · z = sheenH · w = unused
};

// Signed distance to a rounded rect with per-corner radii, in pixels.
// Negative inside. Same construction as pane.frag and bleed.frag, so every
// surface in the build agrees on where its edge is.
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

    // Outward normal, by finite difference — pane.frag's method, four extra
    // SDF evaluations. Analytic would be faster, and this is not the hot path;
    // matching the neighbour matters more than saving two taps.
    vec2 n = normalize(vec2(
        sdRoundRect(p + vec2(1.0, 0.0), half_, radii) - sdRoundRect(p - vec2(1.0, 0.0), half_, radii),
        sdRoundRect(p + vec2(0.0, 1.0), half_, radii) - sdRoundRect(p - vec2(0.0, 1.0), half_, radii)));

    // Light from above. This one line is what turns the corner.
    float up = clamp(-n.y, 0.0, 1.0);
    up *= up;

    // Depth INSIDE the outline, in pixels. On the straight top this is simply
    // the distance down from the top edge, so the numbers below are the same
    // pixel offsets the Rectangles used.
    float depth = -d;

    float lipTop = band.x;
    float lipH   = band.y;
    float sheenH = band.z;

    // The Lip: a hard band, feathered by half a pixel so it does not alias
    // along the bend the way a clipped Rectangle corner would.
    float lipIn  = smoothstep(lipTop - 0.5, lipTop + 0.5, depth);
    float lipOut = 1.0 - smoothstep(lipTop + lipH - 0.5, lipTop + lipH + 0.5, depth);
    float lipBand = lipIn * lipOut * up;

    // The Sheen: starts where the Lip ends and falls linearly to nothing — the
    // same ramp the Gradient expressed.
    float sheenStart = lipTop + lipH;
    float sheenT = clamp((depth - sheenStart) / max(sheenH, 1.0), 0.0, 1.0);
    float sheenBand = (1.0 - sheenT) * step(sheenStart, depth) * up;

    // Both are gated on being INSIDE the pane: a band measured from the outline
    // would otherwise paint just as happily outside it.
    float inside = 1.0 - smoothstep(-0.5, 0.5, d);
    lipBand   *= inside;
    sheenBand *= inside;

    float edging  = geom.z;
    float topEdge = geom.w;

    float aLip   = lipTint.a   * topEdge * lipBand;
    float aSheen = sheenTint.a * topEdge * sheenBand;

    // Ordinary source-over between the two, then premultiplied out. The Lip is
    // a DARK tint, not added light — it deepens the very top of the pane so the
    // Sheen below it reads as light entering the glass rather than as a stripe
    // painted on it.
    vec3  col = sheenTint.rgb * aSheen;
    float a   = aSheen;
    col = lipTint.rgb * aLip + col * (1.0 - aLip);
    a   = aLip + a * (1.0 - aLip);

    fragColor = vec4(col, a) * edging * qt_Opacity;
}
