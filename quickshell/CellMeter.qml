// Nyxus Suxyn — the segmented-cell instrument. ONE definition, QML side.
//
// The sibling of `nyxus_cells.py`. The owner sent two reference images on
// 2026-09-06 for "monitoring and graphs for that type of stuff", and then
// said how to read them: *"i was sending those to try and give you a visual
// of what i was thinking in a sense just to go off"*. They are DIRECTIONAL.
// What they show is a value COUNTED IN LIT CELLS — capsules with air between
// them on a near-black ground — rather than poured into a solid bar.
//
// ⚠ THIS IS THE ONLY PLACE THE CELL IS DEFINED IN QML. `nyxus_media.py`
// carried a second hand-rolled copy of the glass recipe and TRK-3275/TRK-3371
// deleted it because one material defined in two places becomes two materials
// that drift. A graph is a material. Instantiate this; never re-cut the
// geometry into a call site.
//
// ── WHY THE COLOUR COMES FROM THE VALUE AND NOT FROM THE POSITION ──────
// Measured out of the reference PNG per pixel rather than eyeballed: the hue
// is CONSTANT down each column (314/313/311 in one, 46/45/41/45/46 in
// another — that spread is antialiasing) and it ramps with HORIZONTAL
// POSITION, 314° through 61° across the field. It ramps with x because the
// image is a SPECTRUM analyser and its x axis is frequency. On a meter or a
// history, that axis is magnitude or time, and a hue ramp along it is
// decoration — precisely the failure `DESIGN_DEPTH_2026-09-06` rule 4 exists
// to prevent, and the one the owner named when he said the old Monitor drew
// 11% and 85% in the same colour.
//
// So the FORM is taken whole and the DRIVER is changed: one hue per meter,
// stepped from that meter's own value. The screen still fills with different
// colours — which is what he asked for — and every one of them is now
// information.
//
// ── IDLE COST, WHICH IS THE POINT OF THIS BUILD ───────────────────────
// `Bar.qml` states it: idle cost is the point. `BarSpectrum.qml` line ~124
// records the regression this file could easily have repeated — 384 QColor
// allocations 47 times a second.
//
// This costs NOTHING at idle, by construction and not by tuning:
//
//   · No Canvas, no paint(), no timer, no shader. The cells are retained
//     scene-graph Rectangles, so a frame in which nothing changed does no
//     work at all.
//   · The three band colours are `readonly property color` on THIS item —
//     evaluated once per meter, never per cell and never per frame. A cell's
//     colour expression only ever SELECTS one of them.
//   · A cell is lit or unlit by comparing two ints. There is no arithmetic
//     inside the delegate beyond that comparison.
//   · Every lit cell shares one colour, so the QtQuick batch renderer merges
//     them; a 20-cell meter is not 20 draw calls.
//
// The Repeater's model is `cells`, which changes only when the meter is
// RESIZED, so the delegates are created once for the life of the meter.
import QtQuick

Item {
    id: cellMeter

    // 0..1. The reading.
    property real value: 0
    // Force a band regardless of `value` — for the callers whose scale is not
    // a load percentage (battery is the standing example: 95% is good and 8%
    // is the emergency, so banding it by magnitude states rule 4 backwards).
    property color overrideColor: "transparent"
    property bool useOverride: false
    // A pair member (rule 6: down/up, read/write) keeps its DIRECTION colour
    // at every magnitude, because recolouring it by value would destroy the
    // distinction the pair exists to make.
    readonly property bool banded: !useOverride

    implicitHeight: 10

    // ── the bands, evaluated once ─────────────────────────────────────
    // Same three rungs, same two edges, as `nyxus_sysmon_gtk.load_hex`. If
    // these ever disagree the build has two answers to "is this hot", so they
    // are named here in the same order and with the same comment.
    readonly property color calmColor: Theme.paintLayers.glacier[5]   // 0-59
    readonly property color busyColor: Theme.goldGlow                 // 60-84
    readonly property color hotColor:  Theme.paintLayers.magma[5]     // 85-100
    readonly property real pct: Math.max(0, Math.min(1, value)) * 100

    readonly property color bandColor: !banded ? overrideColor
                                     : (pct < 60 ? calmColor
                                     : (pct < 85 ? busyColor : hotColor))
    // The catch-light rung for whichever band is live, so the lit cells carry
    // the same glass highlight the solid track used to.
    readonly property color bandPeak: !banded ? overrideColor
                                    : (pct < 60 ? Theme.paintLayers.glacier[6]
                                    : Qt.color(Theme.paintLayers.magma[0]))

    // ── geometry ──────────────────────────────────────────────────────
    // ⚠ THE DOT ZONE. The Cairo side learned this by rendering a sheet and
    // LOOKING at it: if the cell lands near square it stops reading as a
    // capsule and the field reads as a dot-matrix printout, which loses the
    // one property being copied from the reference. A cell here is always at
    // least 1.6x as long as the track is tall — the reference's own 1:5.4
    // capsule, lying down, at the proportion a 10px track can actually hold.
    readonly property real minCell: height * 1.6
    readonly property real duty: 0.63          // the reference measures 27/43
    readonly property int cells: Math.max(1, Math.floor(width / (minCell / duty)))
    readonly property real pitch: cells > 0 ? width / cells : width
    readonly property real cellW: pitch * duty
    // Below this a capsule is a smear and an honest solid bar is better than
    // a bad one. Matches `nyxus_cells.MIN_CELL`.
    readonly property bool segmented: cellW >= 2.4 && cells >= 2

    // Rounds UP off zero, so a live but tiny reading lights one cell instead
    // of none: an instrument reading nothing and one reading 2% must not look
    // identical. Same rule as `nyxus_cells._lit`.
    readonly property int lit: value <= 0 ? 0
                             : Math.max(1, Math.ceil(Math.min(1, value) * cells))

    // ── the solid fallback, for a track too small to segment ──────────
    Rectangle {
        visible: !cellMeter.segmented
        width: parent.width * Math.max(0, Math.min(1, cellMeter.value))
        height: parent.height
        radius: height / 2
        color: cellMeter.bandColor
        Behavior on width {
            NumberAnimation {
                duration: Theme.durBase
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveMove
            }
        }
    }

    // ── the cells ─────────────────────────────────────────────────────
    Repeater {
        model: cellMeter.segmented ? cellMeter.cells : 0
        delegate: Rectangle {
            required property int index
            x: index * cellMeter.pitch + (cellMeter.pitch - cellMeter.cellW) / 2
            width: cellMeter.cellW
            height: cellMeter.height
            radius: Math.min(width, height) / 2
            // Two ints compared. Nothing is allocated, and the colour is a
            // property of the parent evaluated once per meter.
            color: cellMeter.bandColor

            // The 4px catch-light of the old solid fill, kept per cell so a
            // cell is an OBJECT with a lit top edge rather than a chip of a
            // longer bar — rule 7 applied at the smallest scale in the build.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 0.5
                height: Math.max(1, parent.height * 0.34)
                radius: height / 2
                visible: parent.height >= 6
                color: Theme.soften(cellMeter.bandPeak, 0.72)
            }

            // A cell appearing is the reading moving, so it fades in rather
            // than popping. OPACITY ONLY, deliberately: animating x or width
            // would re-layout the whole row every frame of the transition,
            // which is the expensive kind of change and is what the old
            // solid fill did on every single update.
            opacity: index < cellMeter.lit ? 1.0 : 0.0
            Behavior on opacity {
                NumberAnimation { duration: Math.round(Theme.durBase * 0.45) }
            }
        }
    }
}
