pragma ComponentBehavior: Bound
// Nyxus Suxyn — a REMINDER ICE OBJECT. One coming-up plate, not a text row.
//
// The store is a singleton of facts (epoch ms, text, done). This is the
// face a reminder is: opaque elevated body, seam, hover, glacier[0]
// time lens. Magma only the delete mark — toggling
// done is ice.
import QtQuick
import QtQuick.Layouts

Item {
    id: face

    property string when: ""
    property string caption: ""
    property bool done: false
    property bool canRemove: true

    signal toggled()
    signal removed()

    Layout.fillWidth: true
    implicitWidth: 240
    implicitHeight: 44
    Layout.preferredHeight: 44
    activeFocusOnTab: true
    Accessible.role: Accessible.ListItem
    Accessible.name: {
        var bits = [face.when, face.caption];
        if (face.done)
            bits.push("done");
        return bits.filter(function (s) { return s && s !== ""; }).join(" · ");
    }

    readonly property color iceElevated: Theme.elevated
    readonly property color iceSeam:     Theme.lookSeam
    readonly property color icePeak:     Theme.paintLayers.glacier[6]
    readonly property color iceHover:    Theme.paintLayers.glacier[5]
    readonly property color iceFocus:    Theme.paintLayers.glacier[0]
    readonly property color magmaMark:   Theme.paintLayers.magma[5]

    readonly property bool lit: face.activeFocus
    property bool hovered: false

    function _rr(ctx, x, y, w, h, r) {
        r = Math.max(0, Math.min(r, w / 2, h / 2));
        ctx.beginPath();
        ctx.moveTo(x + r, y);
        ctx.arcTo(x + w, y, x + w, y + h, r);
        ctx.arcTo(x + w, y + h, x, y + h, r);
        ctx.arcTo(x, y + h, x, y, r);
        ctx.arcTo(x, y, x + w, y, r);
        ctx.closePath();
    }

    // TRK-3370 — the ground is the widgets' own stack (SetSlab: floor +
    // panelMid paint + swellGround ramp), not a flat iceElevated fill. The
    // Canvas keeps only STATE. seam false: the Canvas draws its own ladder.
    SetSlab {
        anchors.fill: parent
        anchors.margins: 1.5
        cornerRadius: 16
        lifted: face.hovered
        seam: false
    }

    Canvas {
        id: plate
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            var w = plate.width, h = plate.height;
            ctx.reset();
            if (w < 8 || h < 8)
                return;
            var pad = 1.5;
            var cw = w - 2 * pad;
            var ch = h - 2 * pad;
            var rad = 16;
            if (face.hovered && !face.lit) {
                face._rr(ctx, pad, pad, cw, ch, rad);
                ctx.fillStyle = String(Theme.soften(face.iceHover, 0.10));
                ctx.fill();
            }
            var edge = face.lit ? face.iceFocus
                     : (face.hovered ? face.iceHover : face.iceSeam);
            var lw = face.lit ? 1.8 : (face.hovered ? 1.4 : 1.2);
            face._rr(ctx, pad, pad, cw, ch, rad);
            ctx.lineWidth = lw;
            ctx.strokeStyle = String(edge);
            ctx.stroke();
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.s4
        anchors.rightMargin: Theme.s4
        spacing: Theme.s3

        Rectangle {
            id: tick
            Layout.preferredWidth: 12
            Layout.preferredHeight: 12
            Layout.alignment: Qt.AlignVCenter
            radius: 6
            color: face.done ? face.iceFocus : "transparent"
            border.width: face.done ? 0 : 1.2
            border.color: face.hovered ? face.iceHover : face.iceSeam
            Accessible.role: Accessible.CheckBox
            Accessible.name: face.done ? qsTr("Mark not done") : qsTr("Mark done")
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: face.toggled() }
        }

        Rectangle {
            visible: face.when !== ""
            Layout.preferredHeight: Math.max(28, whenTxt.implicitHeight + 8)
            Layout.preferredWidth: Math.max(implicitHeight, whenTxt.implicitWidth + 20)
            Layout.alignment: Qt.AlignVCenter
            radius: height / 2
            color: Theme.soften(face.iceFocus, 0.16)
            border.width: 1.6
            border.color: face.iceFocus

            Text {
                id: whenTxt
                anchors.centerIn: parent
                text: face.when
                color: face.icePeak
                font.family: Theme.fUiTitle
                font.pixelSize: Theme.tCaption
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: face.caption
            color: face.done ? Theme.textDim : Theme.text
            font.family: Theme.fUi
            font.pixelSize: Theme.tCaption
            font.strikeout: face.done
            elide: Text.ElideRight
        }

        Text {
            visible: face.canRemove
            Layout.alignment: Qt.AlignVCenter
            text: "×"
            color: delHov.hovered ? face.magmaMark : Theme.soften(face.magmaMark, 0.72)
            font.pixelSize: Theme.tHead
            font.weight: Font.DemiBold
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Delete reminder")
            HoverHandler {
                id: delHov
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler { onTapped: face.removed() }
        }
    }

    HoverHandler {
        onHoveredChanged: {
            face.hovered = hovered;
            plate.requestPaint();
        }
    }

    TapHandler {
        onTapped: face.forceActiveFocus()
    }

    Keys.onReturnPressed: function (e) {
        face.toggled();
        e.accepted = true;
    }
    Keys.onDeletePressed: function (e) {
        if (face.canRemove) {
            face.removed();
            e.accepted = true;
        }
    }

    onLitChanged: plate.requestPaint()
    onHoveredChanged: plate.requestPaint()
    onWidthChanged: plate.requestPaint()
    onHeightChanged: plate.requestPaint()
    Component.onCompleted: plate.requestPaint()
}
