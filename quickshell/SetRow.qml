// Nyxus Suxyn — a settings ROW. One fact about the machine, and the control
// that changes it.
//
// The unit of the whole application. A row is: an optional glyph, a title, an
// optional second line, and a control on the right. Nothing else goes in a
// row, and in particular a row never contains another row — a setting that
// needs sub-settings is a `SetRow` with `expands: true` and its own card
// underneath, so the list stays a list.
//
//     SetRow {
//         title: "Pointer speed"
//         sub: "How far the pointer travels for the same hand movement"
//         SetSlider { from: 0.2; to: 2.0; key: "mouse_speed" }
//     }
//
// The control slot is the default property, so a row reads as its control.
// A row with NO control is legal and useful — it is how a read-only fact
// ("Firmware reports Secure Boot is off") is stated, and stating facts in the
// same shape as settings is what stops a page from turning into prose.
import QtQuick
import QtQuick.Layouts

Item {
    id: row

    property string glyph: ""
    property string title: ""
    property string sub: ""

    // A row that leads somewhere rather than changing something. Draws the
    // chevron and reports taps through `activated`. Windows 10 uses the same
    // two shapes in one list and it never confuses anyone, because the chevron
    // is on one and not the other.
    property bool navigates: false

    // Greyed and inert, with the reason shown in place of `sub`. A control
    // that cannot work right now (no printer attached, Bluetooth radio off)
    // must say WHY — a disabled switch with no explanation is the single most
    // common way a settings app makes someone think it is broken.
    property bool available: true
    property string unavailableReason: ""

    // Value shown on the right when there is no control widget — the "Wi-Fi ·
    // Connected to Barn" of a navigating row.
    property string valueText: ""

    signal activated()

    default property alias control: controlSlot.data

    // paintLayers entries are hex strings; Theme.soften / Theme.mix read .r
    // and paint black if they stay strings (PQ 08-21). Qt.color() first.
    readonly property color iceWash: Theme.paintLayers.glacier[3]
    // TRK-3047 — swirl teal in the 4 px pip only. glacier[0] is a string;
    // mix(string, …) is NaN-black. tealGlow is already a color. t=0.30.
    readonly property color icePip: Theme.mix(Qt.color(Theme.stateLayer[0]), Theme.tealGlow, 0.30)
    readonly property color iceSeam: Theme.lookSeam

    Layout.fillWidth: true
    implicitWidth: 480

    // ── two heights, and why ────────────────────────────────────────────
    // A row carrying a control needs the room: 56 px is what a 28 px control
    // plus a title and a description sit in without touching. A row that is
    // ONLY a line of text — the "what this page will control" lists, a stated
    // fact with no value — does not, and giving it 56 turns a six-item list
    // into a third of a metre of scroll. Measured on the printers page: eight
    // items at 56 px overran the window; at 40 they read as a list.
    //
    // The test is what the row actually contains, not a flag the caller sets,
    // because a flag is one more thing to get wrong per row.
    readonly property bool dense: row.sub === "" && row.valueText === ""
                                  && !row.navigates
                                  && controlSlot.children.length === 0
    implicitHeight: Math.max(row.dense ? 40 : 56,
                             line.implicitHeight + 2 * Theme.s5)
    opacity: row.available ? 1.0 : 0.45
    // A row greying out / coming back is a state change, so it eases
    // rather than snaps — the same durQuick the controls inside it use.
    Behavior on opacity { NumberAnimation { duration: Theme.durQuick } }

    // Hover is a wash across every available row, brightest at the left
    // where the label is, gone by the right edge. Not a filled bar: a filled
    // hover on a glass list makes every row you pass over look selected.
    // TRK-3024 — lists of switches/sliders felt empty while only navigates
    // washed; strength 0.11 → 0.28. Pressed 0.20 → 0.38 so a tap still
    // reads louder than rest-hover.
    Rectangle {
        anchors.fill: parent
        // TRK-3730 polish · the wash FADES in and out. It was a hard
        // `visible` toggle, so every row you passed snapped on and off;
        // an opacity Behavior is what makes a hover feel like the
        // pointer is moving over a surface, not flicking a light.
        // Keyboard focus reveals the SAME wash: a navigated-to row must
        // read as engaged the way a hovered one does, or the focus ring
        // below is the only cue and the row still looks asleep.
        opacity: ((hov.hovered || tap.pressed || row.activeFocus) && row.available) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durQuick } }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: Theme.soften(row.iceWash, tap.pressed ? 0.38 : 0.28)
            }
            GradientStop { position: 1.0; color: Theme.shelfNone }
        }
    }

    // 4 px pip — glacier[0] mixed with swirl tealGlow at 0.30. Key-place
    // accent on the left, not a fill of the row. Height minus 8 px inset.
    Rectangle {
        opacity: ((hov.hovered || tap.pressed || row.activeFocus) && row.available) ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durQuick } }
        width: 4
        height: Math.max(0, parent.height - 8)
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        color: row.icePip
    }

    RowLayout {
        id: line
        anchors.fill: parent
        anchors.leftMargin: Theme.s6
        anchors.rightMargin: Theme.s6
        spacing: Theme.s5

        Text {
            visible: row.glyph !== ""
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 20
            text: row.glyph
            font.family: Theme.fIcon
            font.pixelSize: Theme.tHead
            font.weight: Font.Black
            color: hov.hovered || tap.pressed || row.activeFocus ? Theme.text : Theme.textMuted
            horizontalAlignment: Text.AlignHCenter
            Behavior on color { ColorAnimation { duration: Theme.durQuick } }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: row.title
                color: Theme.text
                font.family: Theme.fUi
                font.pixelSize: Theme.tBody
                font.weight: Font.Medium
                elide: Text.ElideRight
                clip: true
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                // The reason a control is unavailable REPLACES the description
                // rather than joining it. Two lines of small text under a
                // greyed switch is how the reason gets missed.
                text: row.available ? row.sub : row.unavailableReason
                color: row.available ? Theme.textDim : Theme.warn
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                clip: true
            }
        }

        Text {
            visible: row.valueText !== ""
            text: row.valueText
            color: Theme.tokenAccentInteractive
            font.family: Theme.fUi
            font.pixelSize: Theme.tLabel
            elide: Text.ElideRight
            clip: true
            Layout.maximumWidth: 220
            Layout.alignment: Qt.AlignVCenter
        }

        // The control. `Item` rather than a layout so a control keeps whatever
        // implicit size it declared — a switch is 44 px wide and a slider wants
        // everything it can get, and forcing both into one policy is how a
        // settings app ends up with 44 px sliders.
        Item {
            id: controlSlot
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
            enabled: row.available
        }

        Text {
            visible: row.navigates
            text: ""                       // chevron-right
            font.family: Theme.fIcon
            font.pixelSize: Theme.tBody
            font.weight: Font.Black
            color: hov.hovered || tap.pressed || row.activeFocus ? Theme.text : Theme.textDim
            Layout.alignment: Qt.AlignVCenter
            Behavior on color { ColorAnimation { duration: Theme.durQuick } }
        }
    }

    // ── TRK-3645 · THE SEAM MOVED OUT, IT DID NOT MOVE HOUSE ────────────
    // A 1 px full-bleed `iceSeam` rectangle used to hang here, anchored to
    // this row's bottom, UNCONDITIONALLY. SetCard.qml's Repeater draws one
    // too, inset by s6, at every boundary where `index > 0`. Neither knew
    // about the other, so measured off docs/proof/settings-redesign-0901/
    // 01-baseline.png the shipped Settings drew:
    //
    //   y=133 full-bleed x160..631  +  y=134 inset x176..615   <- boundary 1
    //   y=189 full-bleed            +  y=190 inset             <- boundary 2
    //   y=245 full-bleed (dimmed)   +  y=246 inset             <- boundary 3
    //   y=301 full-bleed            +  NOTHING                 <- under the LAST row
    //
    // Two rules one pixel apart on every interior boundary, and a third with
    // no partner sitting on top of the card's own bottom rim.
    //
    // A BOUNDARY BELONGS TO THE CARD. The card is the only object that knows
    // whether a row has a neighbour; a row cannot know it is last, which is
    // why the unconditional version could never have been correct — not a
    // tuning error, a bookkeeping one. `SetCard.qml` is now the single owner.
    //
    // `iceSeam` stays declared above: it is public on this type, a page may
    // read it, and deleting a property to tidy up is how the next defect
    // arrives. It is simply no longer painted here.

    HoverHandler {
        id: hov
        enabled: row.available
        cursorShape: row.navigates ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    TapHandler {
        id: tap
        enabled: row.navigates && row.available
        onTapped: row.activated()
    }

    // ── TRK-3730 · A NAVIGATING ROW IS A TARGET, SO IT TAKES THE KEYBOARD ─
    // A `navigates` row opens its own screen — it is every bit a control —
    // but it shipped with only the TapHandler above: no Tab stop, no keys,
    // no focus ring. So the entire Settings tree (Wallpaper, Arrange
    // displays, every disclosure row) was pointer-only, which is the one
    // thing the app's own Ease of Access page forbids. Same contract as
    // SetSwitch: focusable ONLY where the row actually does something, and
    // Return / Space fire the exact `activated()` the tap does. A row that
    // merely states a fact stays inert and out of the tab order.
    activeFocusOnTab: row.navigates && row.available
    Keys.onReturnPressed: if (row.navigates && row.available) row.activated()
    Keys.onSpacePressed:  if (row.navigates && row.available) row.activated()

    // Focus-visible contour. 1 px, the interactive rung (glacier[0]), inset
    // so it reads as a ring around the row rather than a bleed off its edge.
    // Never a filled glacier[4]: that is a SEAM (a boundary), not a STATE —
    // the same line SetSwitch's ring holds, and the StateEdge ladder's whole
    // premise. Colour lives on the contour; the wash/pip above carry the body.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        color: "transparent"
        antialiasing: true
        visible: row.navigates && row.available && row.activeFocus
        border.width: 1
        border.color: Theme.soften(Theme.tokenAccentInteractive, 0.55)
        radius: Theme.r1
    }
}
