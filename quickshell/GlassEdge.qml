// Nyxus Suxyn — the glass edge. ONE definition of what makes a surface read
// as a pane of this build's glass.
//
// The owner's instruction is that the sharp clear-glass look the bottom bar
// has becomes the whole build's material: "it would look best throughout the
// build including all apps menus flyouts ETC so it can be the build theme."
// Before this file the recipe was copied by hand into `Bar.qml`, `Launcher.qml`
// and `Flyout.qml` and simply absent from the power menu, Task View and the
// toasts — which is how five surfaces end up each tuned until they looked all
// right on their own, and none of them looking like the same object.
//
// What a pane of glass actually shows you, top to bottom, and why each part
// is here:
//
//   the Crown   a 1 px specular line along the top face. Drawn by the host —
//               `Pane`'s shader for a Swell, three stacked hairlines of the
//               sweep for the bar — because it is light, and light is the
//               thing that differs between a resting surface and a raised one.
//   the Lip     a thin TINTED band immediately under it: the pane seen
//               edge-on. This is the single cue that makes a surface read as
//               a slab with thickness rather than as a sheet of cellophane.
//               It is tinted, not black — see `Theme.glassLipTint`; over a
//               near-black wallpaper a black band darkens nothing and the
//               Crown goes back to being a coloured line drawn on a
//               photograph.
//   the Sheen   a broad, very faint wash of light lying along the upper face.
//               Deliberately near the threshold of visible: the moment you
//               can point at it, it has become a gradient instead of a
//               highlight.
//   the Glaze   light IN the pane. A thick piece of glass is not a flat fill;
//               it is brighter where the light enters it and deepens as you
//               look through more of it. This is most of the difference
//               between a dark card and a slab, and it is why the bar reads
//               as glass at alpha 0.15 while a Swell at 0.66 read as a black
//               rectangle with a rim on it.
//
// Body and Glaze span the WHOLE host so their per-corner radii match the
// window — that fill is the pane, not a pie. Lip and Sheen used to do the
// same, and that WAS the pie: a 3 px Lip cannot carry a 22 px corner radius
// (Qt clamps it to half the height), so the band was a full-host rounded
// rect. Sheen H is 30 and r3 is 22, so the entire top-corner quarter-disk
// filled with ice. They are straights now, inset by the host radius.
//
// Drop it in as the first child of a `Pane`, after the material and before
// the content:
//
//     Pane {
//         radiusTL: Theme.r3
//         GlassEdge { anchors.fill: parent; radiusTL: Theme.r3 }
//         ...content...
//     }
import QtQuick

Item {
    id: edge

    // Match the host, or the glaze paints over its rounded corners.
    property int radiusTL: Theme.r0
    property int radiusTR: Theme.r0
    property int radiusBR: Theme.r0
    property int radiusBL: Theme.r0

    // 0 for a surface that already has a body of its own (the bar has the
    // Shelf), 1 for a Swell.
    property real glaze: 1.0

    // ── THE BODY · the second thickness (WIP-259) ────────────────────────
    // Opt-in, and OFF by default on purpose. A Swell floats over your
    // WINDOWS, not over the wallpaper, so at the bar's density you read the
    // window through it — measured at 1.3:1 for textDim over a light window,
    // which is invisible. See Theme § THE SWELL BODY for the numbers and for
    // why this is a second thickness of the same glass rather than a retreat
    // from the clear-glass mandate.
    //
    // Set `body: 1` on anything page-sized that floats: the Start menu, the
    // side panel, the power menu, Task View, toasts, context menus, the
    // desktop widgets. Do NOT set it on the bar (it has the Shelf) and do NOT
    // set it on an inline chip inside a Swell — two bodies stack into a dark
    // card on a dark card, which is the failure this build already had once.
    property real body: 0
    // Scales the Lip and the Sheen together, for a surface that wants the
    // edge quieter — an inline card inside a Swell is a chip of the same
    // glass, not another slab.
    property real edging: 1.0

    // ── THE TOP EDGE · 1 keeps the bevel, 0 removes it ───────────────────
    // Scales the Lip's tint and the Sheen's onset, and NOTHING else. 1.0 is
    // every surface in this build; the bar's top edge is the one caller that
    // sets 0, and it does so under an owner ruling of 2026-08-18.
    //
    // This is a property and not a fork because the two readings are worth
    // being able to hold in one file. The Lip is documented above as "the
    // single cue that makes a surface read as a slab with thickness rather
    // than as a sheet of cellophane" — that is exactly right, and it is
    // exactly why it comes off the bar. A surface whose top edge is meant
    // to be indistinguishable from the desktop above it must not be
    // announcing its own thickness there. Every OTHER surface in the build
    // still floats over your windows and still needs to say so.
    //
    // ⚠ It governs the Sheen too, not just the Lip, and that is not
    // over-reach. The Sheen's top stop sits 0.001 of the height after the
    // Lip's bottom stop — about a twelfth of a pixel on an 84 px host — so
    // it is not a soft wash at its onset, it is a second hard step. On the
    // bar that measured +7.96 L in one row, three rows below the Crown.
    // Removing the Lip and leaving the Sheen would leave half a bevel.
    property real topEdge: 1.0
    // Owner 10:17: the remaining whitish band on every plate is this
    // component's Theme.text sheen (30 px, glassSheenA). Lip stays.
    // Default 1 so the bar is unchanged (do not edit Bar.qml). Plates set 0.
    property real wash: 1.0

    // ── THE BLEED ────────────────────────────────────────────────────────
    // Strength of the mottling inside the pane. 0 disables it.
    //
    // The owner asked whether the glass still reads as glass "even on a black
    // background or dark background", and that question has a physical answer:
    // a pane reads as glass because you see something through it and because
    // light catches its edges. Over a near-black wallpaper there is nothing
    // behind to see, so the body carries no information and every surface
    // collapses to a flat dark fill with a nice rim. The edges hold — that is
    // §4's "edges do the work, not cloudiness" — but a body with zero internal
    // variation is a painted rectangle, and no rim fixes that.
    //
    // So the body gets three off-centre pools of colour, which is what real
    // glass does: thicker here, thinner there, no boundary you can point at.
    // They are the SAME three pools as gtk-4.0/gtk.css, deliberately, because
    // the whole claim is that a Quickshell surface and a GTK window are one
    // material — and that stops being true the moment the two are tuned apart.
    property real bleed: 1.0

    // The body, UNDER everything else so the Glaze's light still stands in
    // front of it and the Lip, Sheen, Bleed and the host's dispersive rim are
    // all unchanged. It is a gradient, never a flat fill — the surface this
    // replaced was rejected for being flat, not for being dense.
    Rectangle {
        anchors.fill: parent
        visible: edge.body > 0.005
        opacity: edge.body
        topLeftRadius: edge.radiusTL
        topRightRadius: edge.radiusTR
        bottomRightRadius: edge.radiusBR
        bottomLeftRadius: edge.radiusBL
        // WIP-265 — the ground tokens, not the old § THE SWELL BODY ones.
        // The owner, on the Start Menu and the flyout after the paint-order
        // fix: "do that same thing everywhere the glass is, that's a sharp
        // look I love it." This is where "everywhere" is spelled once —
        // every surface that draws a GlassEdge body reads these three stops,
        // so the deck, the menus, the toasts and the panels are the same
        // material at the same density instead of one sharp surface and five
        // washed-out ones. WIP-259's lighter numbers survive as the
        // measurement they were; they are not what this draws any more.
        gradient: Gradient {
            GradientStop { position: 0.00; color: Theme.swellGroundTop }
            GradientStop { position: 0.55; color: Theme.swellGroundMid }
            GradientStop { position: 1.00; color: Theme.swellGroundFoot }
        }
    }

    // Light standing in the pane. Nothing here is a hard stop and nothing is
    // grey: §3.5's rule is that a dark in this palette is a saturated colour,
    // so the foot of the glass deepens toward the body tint rather than
    // toward black.
    Rectangle {
        anchors.fill: parent
        visible: edge.glaze > 0.005
        opacity: edge.glaze
        topLeftRadius: edge.radiusTL
        topRightRadius: edge.radiusTR
        bottomRightRadius: edge.radiusBR
        bottomLeftRadius: edge.radiusBL
        gradient: Gradient {
            GradientStop { position: 0.00; color: Theme.glazeTop }
            GradientStop { position: 0.30; color: Theme.glazeMid }
            GradientStop { position: 1.00; color: Theme.glazeFoot }
        }
    }

    // The bleed sits ABOVE the Glaze and BELOW the Lip/Sheen band, so the edge
    // cues stay crisp and only the face of the pane mottles. Declared before
    // the band for exactly that reason — QML paints siblings in declaration
    // order, and a bleed over the Lip would soften the one cue that gives the
    // surface its thickness.
    //
    // A ShaderEffect rather than stacked Rectangles because Qt Quick's Gradient
    // is linear only: there is no way to express an off-centre elliptical pool
    // with the built-in types, and Qt5Compat's RadialGradient would add a
    // deprecated dependency this shell does not otherwise carry. The build
    // already compiles fragment shaders (pane.frag, the swirl solver), so this
    // is the house idiom, and the whole thing is three smoothsteps — cheaper
    // than the layered Rectangles it replaces would have been.
    ShaderEffect {
        anchors.fill: parent
        visible: edge.bleed > 0.005
        blending: true
        fragmentShader: Qt.resolvedUrl("shaders/bleed.frag.qsb")
        property vector4d geom: Qt.vector4d(width, height, edge.bleed, 0)
        property vector4d radii: Qt.vector4d(edge.radiusTL, edge.radiusTR,
                                             edge.radiusBR, edge.radiusBL)
        // ICE: plum / teal / plum. MAGMA: gold / pale glacier / black.
        property vector4d poolA: Theme.lookMagma
            ? Qt.vector4d(0.969, 0.659, 0.231, 0.100)
            : Qt.vector4d(0.682, 0.125, 0.424, 0.100)
        property vector4d poolB: Theme.lookMagma
            ? Qt.vector4d(Theme.lookSeam.r, Theme.lookSeam.g, Theme.lookSeam.b, 0.070)
            : Qt.vector4d(0.039, 0.635, 0.839, 0.070)
        property vector4d poolC: Theme.lookMagma
            ? Qt.vector4d(0.020, 0.008, 0.012, 0.085)
            : Qt.vector4d(0.537, 0.098, 0.333, 0.085)
    }

    // The Lip and the Sheen. Pixel heights, never a fraction of the host —
    // 3 px and 30 px on an 84 px bar and on an 840 px Swell. TRK-932 eighth
    // cut: these used to be ONE filled rounded rect at the host radius
    // (Start/flyout Theme.r3 = 22). Sheen H 30 > r 22, so each top corner
    // was a 22 px ice quarter-disk. Straights only, inset by the matching
    // top radius, so they never enter the bend. Body/Glaze stay rounded
    // (the window). topEdge 0 (the bar) still hides both. Theme.r3 and
    // Launcher radii untouched.
    // ⚠ TRK-3541 — ONE ShaderEffect, not two Rectangles, and the reason is the
    // corner. Anchored `leftMargin: radiusTL` / `rightMargin: radiusTR` made
    // both bands stop DEAD at the pixel the bend begins: square terminus, whole
    // quarter-turn unlit. pane.frag's `crown` meanwhile is an SDF band weighted
    // by `up * up`, so it wraps and fades. Two edge systems on one surface,
    // agreeing along the straight and disagreeing through every bend — which is
    // the seam the owner reported as "it almost looks as if we didnt connect
    // the edges", and he was right.
    //
    // A Rectangle's radius belongs to the RECTANGLE. What this needs is a band
    // of constant thickness measured from the OUTLINE, along a path that bends,
    // which is a signed distance field. lip.frag uses pane.frag's construction
    // verbatim — same sdRoundRect, same finite-difference normal, same `up*up`
    // — so the two edges cannot drift apart again. Retune one, retune both.
    //
    // On the straight top `up` is 1 and this draws EXACTLY what the Rectangles
    // drew, at the same pixel offsets; on the sides `up` is 0 and there is no
    // lip, also as before. Only the corner changes.
    ShaderEffect {
        id: lip
        anchors.fill: parent
        visible: edge.edging > 0.005 && edge.topEdge > 0.005
        blending: true
        fragmentShader: Qt.resolvedUrl("shaders/lip.frag.qsb")
        property vector4d geom: Qt.vector4d(width, height, edge.edging, edge.topEdge)
        property vector4d radii: Qt.vector4d(edge.radiusTL, edge.radiusTR,
                                             edge.radiusBR, edge.radiusBL)
        property vector4d lipTint: Qt.vector4d(Theme.glassLipTint.r, Theme.glassLipTint.g,
                                               Theme.glassLipTint.b, Theme.glassLipTint.a)
        // `wash` folds into the Sheen's alpha here rather than gating a second
        // item, because one shader now draws both bands.
        property vector4d sheenTint: Qt.vector4d(Theme.text.r, Theme.text.g, Theme.text.b,
                                                 Theme.glassSheenA * edge.wash)
        property vector4d band: Qt.vector4d(Theme.glassLipTop, Theme.glassLipH,
                                            Theme.glassSheenH, 0)
    }
}
