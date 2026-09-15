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
    // TRK-4170. An explicit one-line summary. Cards that want to choose their
    // own opening line set this; everything else gets `firstSentence(note)`,
    // which is why 103 existing cards needed no edit to calm down.
    property string brief: ""
    // Is this card's full note pulled open by hand? Per-card and not sticky:
    // the `?` answers one question and the page is quiet again next visit.
    property bool noteOpen: false

    // The short form. Sentences are taken until there are at least 60
    // characters, so a card whose note opens "Two complete themes." keeps the
    // sentence that actually says what they ARE instead of stopping on a
    // fragment.
    readonly property string noteBrief: {
        if (card.brief !== "")
            return card.brief;
        var t = card.note;
        if (t === "")
            return "";
        var cut = -1;
        for (var i = 0; i < t.length - 1; ++i) {
            if (t.charAt(i) !== "." || t.charAt(i + 1) !== " ")
                continue;
            // Don't break on "e.g." / "i.e." / an initial: a period whose
            // preceding run of letters is one or two long is an abbreviation,
            // not the end of a sentence.
            var j = i - 1;
            while (j >= 0 && /[A-Za-z]/.test(t.charAt(j)))
                --j;
            if (i - j <= 2)
                continue;
            // Adding this sentence would overshoot into a paragraph again.
            // Keep what we have — the `?` is right there for the rest.
            if (cut >= 0 && i + 1 > 120)
                break;
            cut = i;
            if (cut + 1 >= 60)
                break;
        }
        if (cut < 0)
            return t;
        return t.substring(0, cut + 1);
    }
    // Only offer the `?` when it would actually reveal something.
    readonly property bool noteHasMore: card.note !== "" && card.note !== card.noteBrief
    readonly property bool noteFull: Prefs.settingsHelp || card.noteOpen

    property real tone: 0.35
    // Kept so pages can still pass `tone: page.tone`. The card body is
    // uncoloured glass — key-place colour lives on the controls, not a
    // per-card wash. Row seams are glacier[4], never rose glassBorder.
    readonly property color iceHairline: Theme.lookSeam

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
        //
        // TRK-4170 put a `?` on the end of this line. It sits with the
        // heading rather than with the note because at rest there may be no
        // note on screen to hang it off, and a reveal you can only find by
        // already seeing the thing it reveals is not a reveal.
        RowLayout {
            visible: card.heading !== ""
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s2
            spacing: Theme.s2

            Text {
                text: card.heading.toUpperCase()
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tMicro
                font.weight: Font.DemiBold
                font.letterSpacing: Theme.trackMicro
            }

            Rectangle {
                id: moreDot
                visible: card.noteHasMore && !Prefs.settingsHelp
                implicitWidth: Theme.tMicro + 7
                implicitHeight: Theme.tMicro + 7
                radius: width / 2
                color: card.noteOpen ? Theme.soften(Theme.accent, 0.22)
                                     : (moreTap.containsMouse ? Theme.soften(Theme.accent, 0.13)
                                                              : "transparent")
                border.width: 1
                border.color: card.noteOpen || moreTap.containsMouse
                              ? Theme.soften(Theme.accent, 0.75)
                              : Theme.soften(card.iceHairline, 0.9)

                Behavior on color {
                    ColorAnimation { duration: 110 }
                }

                Text {
                    anchors.centerIn: parent
                    // The glyph turns into a minus once the note is open, so
                    // the control says what the NEXT tap does, not what the
                    // last one did.
                    text: card.noteOpen ? "\u2212" : "?"
                    color: card.noteOpen || moreTap.containsMouse ? Theme.text : Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: moreTap
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.noteOpen = !card.noteOpen
                }
            }

            Item { Layout.fillWidth: true }
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
        //
        // TRK-4170 — ONE sentence of it at rest. See `noteBrief` above, and
        // the `settings_help` note in `Prefs.qml` for why the default moved.
        Text {
            visible: card.note !== ""
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s2
            Layout.rightMargin: Theme.s2
            text: card.noteFull ? card.note : card.noteBrief
            color: Theme.textDim
            font.family: Theme.fUi
            font.pixelSize: Theme.tCaption
            wrapMode: Text.WordWrap
        }
    }
}
