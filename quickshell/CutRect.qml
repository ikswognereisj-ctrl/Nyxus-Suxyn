// Nyxus Suxyn — a fill that can be CUT.
//
// ── the defect this exists for ──────────────────────────────────────────
// The chamfer (Prefs.panelChamfer) reaches corner SHAPE through four shaders,
// so anything drawn by Pane / GlassEdge / MirrorEdge follows it. But a card in
// this build is not one surface — SetSlab.qml stacks THREE layers at one
// radius: an opaque `Rectangle` floor, a `Pane` in the middle, and a gradient
// `Rectangle` swell on top. Only the middle one can cut.
//
// The swell is ABOVE the Pane, so a rounded gradient would paint straight over
// the cut corner and hide it; the opaque floor is BELOW, so it would poke out
// into the triangle the cut removes. The result is not "a card that missed the
// chamfer" — it is a visibly broken corner, on every surface built from that
// recipe: every SetCard, the Settings window body, the utility hub, the
// notifications flyout, the Rooms map card, the LOCK SCREEN'S LOGIN CARD, and
// all six desktop widgets. This is the component that closes that gap.
//
// It is deliberately NOT a general shape library. It draws exactly what the
// layered-card recipe needs and nothing else.
//
// ── why one code path, and not "Rectangle when round, Shape when cut" ──
// A branch would mean the default look was drawn by different code from the
// cut look, so the shipped rendering would be untested every time the chamfer
// was worked on. Instead the Shape draws BOTH: arcs at cut 0, straight lines
// above it. That makes the default path the one that is exercised constantly.
//
// ⚠ The safety that buys is only worth anything if cut 0 really is today's
// look, so that is MEASURED, not asserted: `scripts/verify-cutrect.py` renders
// this at cut 0 beside a plain `Rectangle` with the same radius and requires
// them to agree. Run it after touching this file.
//
// ── the gradient is deliberately three fixed stops ──────────────────────
// Not a general gradient API: this build has exactly one gradient of this
// kind, the swell (Theme.swellGroundTop / Mid / Foot), vertical, three stops.
// Exposing `Gradient` generically would mean converting QtQuick's `Gradient`
// into a `ShapeGradient` at runtime, which is dynamic object creation for no
// benefit. A fourth stop means editing this file, on purpose.
import QtQuick
import QtQuick.Shapes

Item {
    id: cut

    // Corner radius when NOT chamfered — the same token the host passes its
    // Pane, so the layers of one card cannot disagree about their corner.
    property int radius: Theme.r2

    // The cut, in px along each edge. Defaults to the live setting; a host can
    // override it, and 0 means the rounded look.
    property int chamfer: Prefs.panelChamfer

    // Solid fill. Ignored when `gradTop` is opaque.
    property color color: "transparent"

    // The swell. Leave gradTop transparent to use the solid `color` instead.
    property color gradTop:  "transparent"
    property color gradMid:  "transparent"
    property color gradFoot: "transparent"
    // Where the middle stop sits. 0.5 is the swell; the Settings tile's hover
    // wash puts its knee at 0.75 and then holds the same colour to the foot,
    // which is how a TWO-stop gradient is expressed here without adding a
    // second gradient API. Default leaves every existing caller unmoved.
    property real gradMidPos: 0.5
    readonly property bool _grad: gradTop.a > 0

    // The seam. A card's 1 px outline is its own layer in this build, and it
    // is a Rectangle too — so it needs cutting for exactly the same reason the
    // fills do: a rounded hairline tracing a cut corner is the "dark spur"
    // failure DESIGN_LANGUAGE_NYXUS_GLASS rule 3 warns about, drawn in the one
    // place the eye is guaranteed to look.
    property int   borderWidth: 0
    property color borderColor: "transparent"
    readonly property bool _stroked: borderWidth > 0 && borderColor.a > 0

    // ⚠ Qt draws a Rectangle's border INSIDE its bounds; a Shape's stroke
    // STRADDLES the path. Insetting by half the width makes the two land in
    // the same place — without it every seam would sit half a pixel proud of
    // the card it outlines, which on a 1 px hairline is half the hairline.
    readonly property real _i: _stroked ? borderWidth / 2 : 0

    // Both are clamped to half the smaller side: past that a "corner" has
    // eaten the whole edge and the shape stops being a rectangle at all. The
    // shaders clamp the same way, which is what keeps a Pane and this in step
    // on a small surface.
    readonly property real _half: Math.min(width - 2 * _i, height - 2 * _i) / 2
    readonly property real _r: Math.max(0, Math.min(radius, _half))
    readonly property real _c: Math.max(0, Math.min(chamfer, _half))
    readonly property bool _isCut: _c > 0

    // The corner inset actually drawn — the cut when chamfered, else the arc.
    readonly property real _k: _isCut ? _c : _r

    Shape {
        anchors.fill: parent
        antialiasing: true
        // Curves is the default renderer in Qt 6.11 for some paths and it
        // resolves arcs differently at small radii; GeometryRenderer is what
        // the equivalence proof was measured against.
        preferredRendererType: Shape.GeometryRenderer

        ShapePath {
            strokeWidth: cut._stroked ? cut.borderWidth : -1
            strokeColor: cut._stroked ? cut.borderColor : "transparent"
            fillColor: cut._grad ? "white" : cut.color
            fillGradient: cut._grad ? swell : null

            // Clockwise from just after the top-left corner. Each corner is
            // either a straight line (cut) or a quarter arc (round) — the
            // only difference between the two looks.
            startX: cut._i + cut._k
            startY: cut._i

            PathLine { x: cut.width - cut._i - cut._k; y: cut._i }
            PathArc {
                x: cut.width - cut._i; y: cut._i + cut._k
                radiusX: cut._isCut ? 0 : cut._r
                radiusY: cut._isCut ? 0 : cut._r
                direction: PathArc.Clockwise
            }
            PathLine { x: cut.width - cut._i; y: cut.height - cut._i - cut._k }
            PathArc {
                x: cut.width - cut._i - cut._k; y: cut.height - cut._i
                radiusX: cut._isCut ? 0 : cut._r
                radiusY: cut._isCut ? 0 : cut._r
                direction: PathArc.Clockwise
            }
            PathLine { x: cut._i + cut._k; y: cut.height - cut._i }
            PathArc {
                x: cut._i; y: cut.height - cut._i - cut._k
                radiusX: cut._isCut ? 0 : cut._r
                radiusY: cut._isCut ? 0 : cut._r
                direction: PathArc.Clockwise
            }
            PathLine { x: cut._i; y: cut._i + cut._k }
            PathArc {
                x: cut._i + cut._k; y: cut._i
                radiusX: cut._isCut ? 0 : cut._r
                radiusY: cut._isCut ? 0 : cut._r
                direction: PathArc.Clockwise
            }
        }
    }

    // Vertical, top to bottom, in the item's own coordinates.
    LinearGradient {
        id: swell
        x1: 0; y1: cut._i
        x2: 0; y2: cut.height - cut._i
        GradientStop { position: 0.00; color: cut.gradTop }
        GradientStop { position: cut.gradMidPos; color: cut.gradMid }
        GradientStop { position: 1.00; color: cut.gradFoot }
    }
}
