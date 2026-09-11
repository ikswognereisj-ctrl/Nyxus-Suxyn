pragma ComponentBehavior: Bound
// Nyxus Suxyn — a settings CARD. The grouped list of rows.
//
// This is the "then each category has a list" part of the owner's sentence
// (`docs/PLAN_SETTINGS_WINDOWS10_LAYOUT.md` §1). A card is one subject —
// "Pointer speed", "Queue", "Plug-in notifications" — holding the rows that
// belong to it, drawn as one slab of the build's glass rather than as a box
// with a border round it.
//
//     SetCard {
//         heading: "Pointer"
//         SetRow { title: "Pointer speed"; SetSlider { ... } }
//         SetRow { title: "Precision";     SetSwitch { ... } }
//     }
//
// Material notes, so nobody re-tunes this per module:
//   · The face is `SetSlab` (TRK-3310) — the ONE Settings material, and the
//     only place its recipe is written down. Do not re-roll a card face here:
//     four files each having their own is exactly what made the window
//     see-through over a terminal on 2026-08-28.
//   · `body: 0` on the GlassEdge, inside SetSlab. The card floats inside a
//     page that already carries a body; `GlassEdge`'s own header says two
//     bodies stack into a dark card on a dark card, and that failure is
//     already in this build's history once.
//   · The separators
//     between rows are hairlines drawn by the card, not by the rows, so a card
//     never ends with a dangling line under its last row.
import QtQuick
import QtQuick.Layouts

Item {
    id: card

    property string heading: ""
    property string note: ""
    property real tone: 0.35
    // Kept so pages can still pass `tone: page.tone`. The card body is
    // uncoloured glass — key-place colour lives on the controls, not a
    // per-card wash. Row seams are glacier[4], never rose glassBorder.
    readonly property color iceHairline: Theme.paintLayers.glacier[4]

    // Rows go here. Dedicated container, nothing else declared into it — the
    // `Pane.qml` self-parenting crash note applies to every default alias in
    // this build.
    default property alias rows: rowColumn.data

    Layout.fillWidth: true
    // TRK-3312 — the page body is a GridLayout now. Without this a card in a
    // short column is stretched to the height of the tallest card in its row
    // and its slab floats in the middle of the cell; AlignTop is what makes
    // the columns line up at the top the way the single column did.
    Layout.alignment: Qt.AlignTop
    implicitHeight: shell.implicitHeight
    implicitWidth: 480

    ColumnLayout {
        id: shell
        width: card.width
        spacing: Theme.s3

        // ── the heading ─────────────────────────────────────────────────
        // The system's own voice: uppercase, wide-tracked, quiet — Theme's
        // `trackMicro` exists for exactly this and nothing else.
        Text {
            visible: card.heading !== ""
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s2
            text: card.heading.toUpperCase()
            color: Theme.textDim
            font.family: Theme.fUi
            font.pixelSize: Theme.tMicro
            font.weight: Font.DemiBold
            font.letterSpacing: Theme.trackMicro
        }

        // ── the slab ────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            implicitHeight: rowColumn.implicitHeight

            // TRK-3310 — the one Settings material, and it is OPAQUE. This
            // was `Theme.glassFillStrong` (α 0.66) with no floor under it,
            // so a card passed roughly a third of whatever was behind the
            // window. `SetSlab` keeps the identical two-layer recipe and puts
            // `Theme.elevated` beneath it; the arithmetic and the before /
            // after transmittance are in that file's header.
            SetSlab {
                id: slab
                anchors.fill: parent
                cornerRadius: Theme.r2
                level: 1
            }

            ColumnLayout {
                id: rowColumn
                width: parent.width
                spacing: 0
            }

            // ── the separators ──────────────────────────────────────────
            // Drawn by the card, between rows, from the rows' own geometry —
            // so the last row never has a line under it and a row that hides
            // itself does not leave its separator behind. A `Repeater` over
            // the row list rather than a line inside each row, because "each
            // row draws its own top border except the first" is the rule that
            // every module would eventually get wrong once.
            Repeater {
                model: rowColumn.children.length
                delegate: Rectangle {
                    required property int index
                    readonly property var row: rowColumn.children[index]
                    // `height > 0` is not belt-and-braces. A `Repeater` placed
                    // in a card's rows is itself a zero-sized QQuickItem in
                    // `children`, so a card whose rows are generated rather
                    // than written out would otherwise draw one stray hairline
                    // at the top of the group — which is exactly the shape of
                    // "a border appeared and nobody knows where from".
                    visible: index > 0 && row !== undefined
                             && row.visible && row.height > 0
                    x: Theme.s6
                    y: row !== undefined ? row.y : 0
                    width: rowColumn.width - 2 * Theme.s6
                    height: 1
                    // ── TRK-3645 · STRUCTURE MUST NOT OUTSHOUT STATE ─────
                    // This is now the ONLY divider in a Settings card
                    // (SetRow.qml's full-bleed twin is gone — see its note).
                    //
                    // It was `card.iceHairline`, i.e. glacier[4] at FULL
                    // strength. Measured against the card ground (5,5,8) off
                    // 01-baseline.png that is 4.77:1, where this build's own
                    // resting-seam contract — StateEdge.seamIdle, which is
                    // soften(glacier[0], 0.22) — is 1.63:1. Structure was
                    // running at 2.9x every STATE rung in the app, twice per
                    // boundary, which is what made a Settings list read as
                    // ruled paper instead of as a surface.
                    //
                    // @0.55 = 2.14:1: unmistakably visible, and deliberately
                    // BELOW the 3:1 component floor so that a divider can
                    // never be mistaken for a state. `iceHairline` stays as
                    // the token; only the alpha comes down.
                    color: Theme.soften(card.iceHairline, 0.55)
                }
            }
        }

        // ── the note ────────────────────────────────────────────────────
        // Under the card, not inside it: this is the sentence that explains a
        // consequence ("changing this signs you out"), and a consequence
        // belongs after the control, where a person reads it before acting.
        Text {
            visible: card.note !== ""
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s2
            Layout.rightMargin: Theme.s2
            text: card.note
            color: Theme.textDim
            font.family: Theme.fUi
            font.pixelSize: Theme.tCaption
            wrapMode: Text.WordWrap
        }
    }
}
