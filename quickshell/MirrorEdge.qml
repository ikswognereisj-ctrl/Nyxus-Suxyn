// Nyxus Suxyn — the MIRROR EDGE.
//
// Owner, 2026-08-09: "any way we can do the edges like a mirror, exactly like
// a real mirror?" — and then, looking at the first cut: "needs to look more
// like how the bottom bar, where the icons have that mirror look underneath
// them."
//
// That second sentence threw the first version away, and it was right to.
// The first cut was a BEVEL: a bright hairline, a chamfer face, a dark
// terminator closing it. Optically defensible and wrong for this build,
// because it read as a frame — a hard line drawn around the pane — and the
// thing the owner was pointing at is the opposite of a line. The dock icons
// carry a soft mirrored fall of light UNDER them: brightest where it meets
// the object, gone a moment later, never with an edge of its own.
//
// So this file now builds the edge out of the build's OWN reflection recipe,
// the one Bar.qml uses for the dock icons, rather than a second idea about
// what glass does:
//
//   · brightest exactly AT the rim, where the reflection meets its object
//   · falling to nothing over `Theme.reflectH` of the band — the same 0.46
//     the icons use, so the fall-off has one length everywhere in the build
//   · at `Theme.reflectAlpha` strength, the same 0.30
//   · and no terminator, no closing line, nothing to point at. A reflection
//     that ends in an edge is not a reflection; it is a rectangle.
//
// Light still comes from ABOVE, once, for the whole build — the top rim
// returns the most, the bottom returns a weak bounce, the sides fall between.
// That is what makes a set of these read as one object under one lamp.
//
// Cheap on purpose: hairline + four fall strips, no ShaderEffectSource, no layer, no
// offscreen texture, no scheduled frames. A live mirror of the panel's real
// content would need a texture of a surface that already contains a fluid
// simulation, every frame, and would buy less than this costs.
//
// Composes OVER GlassEdge rather than replacing it: GlassEdge gives the pane
// its body and thickness, this gives its rim the reflection.
import QtQuick

Item {
    id: edge
    anchors.fill: parent

    // Per-corner, to match the host exactly. A Swell is square where it meets
    // the screen edges and round only where it faces open space, and a rim
    // that rounds a corner its host does not is worse than no rim at all.
    property int radiusTL: Theme.r0
    property int radiusTR: Theme.r0
    property int radiusBR: Theme.r0
    property int radiusBL: Theme.r0

    // How deep the reflection reaches into the pane. This is the band the
    // fall-off happens across, not a border width — there is no border.
    property real depth: 18

    // One dial for the whole effect, so a surface can carry a quieter rim
    // without four values drifting out of agreement with each other.
    property real strength: 1.0

    readonly property real _s: Math.max(0, Math.min(1.5, strength))
    readonly property int  _maxR: Math.max(radiusTL, Math.max(radiusTR,
                                  Math.max(radiusBR, radiusBL)))

    // ── the rim itself ──────────────────────────────────────────────
    // TRK-932 ninth: 1 px hairline follows the rounded outline so the
    // four sides meet at the bend. Seventh cut's inset straights left a
    // 22 px hole (on the 46 px flyout rail that hole is the whole top).
    // Transparent fill — a filled quarter-disk was the pie, not this.
    // Fall strips below stay inset so they do not square the corner.
    readonly property color _rim: Theme.soften(Theme.text, 0.16 * edge._s)
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: edge._rim
        topLeftRadius: edge.radiusTL
        topRightRadius: edge.radiusTR
        bottomRightRadius: edge.radiusBR
        bottomLeftRadius: edge.radiusBL
        antialiasing: true
    }

    // ── the fall · corners ──────────────────────────────────────────
    // Sixth cut removed the Canvas quarter-arc. Seventh cut flattened the
    // 1 px outline above. Fall strips still stop at the radius — a gap,
    // not a pie. No Canvas. No ctx.fill. No ctx.arc.

    // ── the fall, all of it, in one band ────────────────────────────
    // ⚠ TRK-3543 — this WAS four axis-aligned Rectangles (top, bottom, left,
    // right), each inset by the corner radius so a straight strip could not
    // overhang a bend. The comment above still records the consequence: "Fall
    // strips still stop at the radius — a gap, not a pie." That gap is real.
    // It leaves every corner carrying the 1 px hairline and NO fall, while
    // every straight carries both — the seam the owner reported twice, and it
    // is on every card in the build.
    //
    // The four strips were never four effects. They are ONE effect sampled at
    // four right angles: a reflection whose strength depends on which way the
    // surface faces. This file's own header says so — "the top rim returns the
    // most, the bottom returns a weak bounce, the sides fall between". Written
    // as a function of the normal, the corner stops being a special case and
    // simply interpolates, which is what a reflection does anyway.
    //
    // The three strengths are carried over EXACTLY (top 1.00, sides 0.52,
    // bottom 0.34 x reflectAlpha), so no straight edge changes. Only the
    // corners, which is where it was wrong. Construction is pane.frag's and
    // lip.frag's, verbatim: three files, one idea of where an edge is.
    ShaderEffect {
        anchors.fill: parent
        visible: edge._s > 0.005
        blending: true
        fragmentShader: Qt.resolvedUrl("shaders/mirror.frag.qsb")
        property vector4d geom: Qt.vector4d(width, height, edge.depth, edge._s)
        property vector4d radii: Qt.vector4d(edge.radiusTL, edge.radiusTR,
                                             edge.radiusBR, edge.radiusBL)
        property vector4d tint: Qt.vector4d(Theme.text.r, Theme.text.g,
                                            Theme.text.b, Theme.reflectAlpha)
        property vector4d fall: Qt.vector4d(Theme.reflectH, 0, 0, 0)
    }
}
