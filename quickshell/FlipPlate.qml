pragma ComponentBehavior: Bound
// Nyxus Suxyn — one face of a two-sided panel.               TRK-3698
//
// The owner, 2026-09-01, correcting the first reading of his brief:
//
//   "quick thing i need to say about the bottom bar when i said flip i
//    meant i want those grapghs inside the bar still but on there own when
//    the music plays so the bar flip to the other said showing the graphgs
//    when music is playing then when it stops it flip back to the normal
//    side"
//
// So the bar is a physical two-sided panel. FRONT is the bar as it has
// always been; BACK is the analyser on its own. Music rotates it over,
// silence rotates it back.
//
// ══ WHY A PLATE AND NOT `Flipable` ══════════════════════════════════════
// Qt has `Flipable`, and it is the right type when the front is ONE item.
// The bar's front face is not: it is three disjoint regions of Bar.qml
// (the type scrim + hazes at z 0, the end Pools above the resting
// hairlines, and the chrome at z 2) with the SHELF, the LINE and the
// resting seam interleaved between them — and those must not flip, because
// the owner's instruction is that the graphs are "inside the bar still".
// The bar's material stays; its CONTENT is what has two sides.
//
// Collapsing that into one `Flipable` would mean re-ordering five z levels
// of a surface the owner has tuned for a month. So instead: several plates,
// every one of them `anchors.fill: parent` on the same host, therefore all
// sharing one coordinate system, therefore all rotating in exact register
// off one shared `angle`. They behave as one panel because geometrically
// they ARE one panel, sliced by z rather than by position.
//
// ══ WHY A TRANSFORM AND NOT A SHADER ════════════════════════════════════
// Because a transform does it. `Rotation` with an `axis` is a real 4x4 in
// the scene graph, applied on the GPU with everything else, costing one
// matrix — no ShaderEffectSource, no render target, no texture, and no
// .qsb to rebuild. This surface has a live fluid simulation on it already;
// it does not need a second offscreen pass to turn a panel over.
//
// ══ THE PERSPECTIVE IS DELIBERATELY SHALLOW, AND HERE IS THE ARITHMETIC ═
// The bar is 1920 x 84. Rotating a strip that wide and that short about
// its horizontal centre line is mostly a vertical squash; perspective is
// what makes it read as an object turning rather than a blind closing.
//
// But a layer-shell surface CLIPS at its own bounds, and the surface is
// exactly `Theme.chromeH` tall. The near edge of a rotated plate is
// magnified by 1 / (1 - (h/2)·sin a / d), so with h = 84:
//
//     d =  400   near edge reaches 46.9 px  ->  4.9 px clipped
//     d =  700   ...                43.6 px  ->  1.6 px clipped
//     d = 1200   ...                42.7 px  ->  0.7 px clipped
//
// A clipped near edge is a straight cut across a turning panel, which
// reads as a bug, not as depth. 1200 keeps the worst case under a pixel.
// This is the constraint that decides the number; it is not taste.
import QtQuick

Item {
    id: plate

    // The shared rotation, 0..180. Both faces read the SAME property, so
    // they cannot desynchronise and there is no second animation to keep
    // in step.
    property real angle: 0

    // 0 for a front plate, 180 for the back one. The back plate is simply
    // the same plate already turned over, which is why its content needs
    // no mirroring: at angle 180 its total rotation is 360.
    property real face: 0

    property real depth: 1200

    readonly property real _total: plate.angle + plate.face
    readonly property real _cos: Math.cos(plate._total * Math.PI / 180)

    // A face pointing away is not drawn, and — because `visible: false`
    // also removes an item from input — a front-face button cannot be
    // clicked through the back of the panel. `>= 0` on both faces so the
    // exact 90 degree frame has no gap; at 90 degrees both are edge-on and
    // project to zero height, so nothing is doubled.
    visible: plate._cos >= 0

    // ⚠ ONE Matrix4x4, NOT a [Rotation, Matrix4x4] pair, and this cost a
    // render to learn. Qt applies a `transform` list by post-multiplying in
    // order, so a perspective divide listed after a rotation is applied
    // BEFORE it to the point — and, worse, a bare perspective matrix
    // projects toward the item's ORIGIN, not its centre. MEASURED: the
    // first capture came back with the plate sheared sideways, its bars
    // leaning like italics, converging on x = 0. That is not a subtle
    // artefact; it is the whole shape being wrong.
    //
    // So the whole thing is composed here, explicitly, in the order it has
    // to happen: move the centre to the origin, rotate, divide, move back.
    //
    //     M = T(+c) · P · R(a) · T(-c)
    //
    // One binding, re-evaluated only while the angle is actually moving —
    // i.e. for the ~900 ms of a flip and never again.
    transform: Matrix4x4 {
        matrix: {
            const w = plate.width;
            const h = plate.height;
            const a = plate._total * Math.PI / 180;
            const c = Math.cos(a);
            const s = Math.sin(a);
            const R = Qt.matrix4x4(1, 0, 0, 0,
                                   0, c, -s, 0,
                                   0, s, c, 0,
                                   0, 0, 0, 1);
            // +z is toward the viewer, so the near edge is magnified.
            const P = Qt.matrix4x4(1, 0, 0, 0,
                                   0, 1, 0, 0,
                                   0, 0, 1, 0,
                                   0, 0, -1 / plate.depth, 1);
            const T1 = Qt.matrix4x4(1, 0, 0, -w / 2,
                                    0, 1, 0, -h / 2,
                                    0, 0, 1, 0,
                                    0, 0, 0, 1);
            const T2 = Qt.matrix4x4(1, 0, 0, w / 2,
                                    0, 1, 0, h / 2,
                                    0, 0, 1, 0,
                                    0, 0, 0, 1);
            return T2.times(P.times(R.times(T1)));
        }
    }
}
