pragma ComponentBehavior: Bound
// Nyxus Suxyn — a TASK VIEW ICE OBJECT. One numbered desktop, not a fill chip.
//
// Tasks.qml is the dock model (Bar paints those pins — not this file).
// This is the equivalent surface: Super+Tab desks as ice stones.
// Opaque elevated body, seam, hover, selected glacier[0] lens.
// Magma is not this object — switching a desktop does not destroy.
import QtQuick
import QtQuick.Layouts

Item {
    id: face

    property string reading: ""
    property string caption: ""
    property bool selected: false

    signal activated()

    implicitWidth: 88
    implicitHeight: 120
    activeFocusOnTab: true
    Accessible.role: Accessible.Button
    Accessible.name: {
        var bits = [face.reading, face.caption].filter(function (s) {
            return s && s !== "";
        });
        return bits.join(" · ");
    }

    readonly property color iceElevated: Theme.elevated
    readonly property color iceSeam:     Theme.paintLayers.glacier[4]
    readonly property color icePeak:     Theme.paintLayers.glacier[6]
    readonly property color iceHover:    Theme.paintLayers.glacier[5]
    readonly property color iceFocus:    Theme.paintLayers.glacier[0]

    readonly property bool lit: face.selected || face.activeFocus
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

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.s4
        anchors.rightMargin: Theme.s4
        anchors.topMargin: Theme.s4
        anchors.bottomMargin: Theme.s4
        spacing: Theme.s3

        Item { Layout.fillHeight: true }

        Item {
            visible: face.reading !== ""
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: lensBox.implicitWidth
            Layout.preferredHeight: lensBox.implicitHeight

            Rectangle {
                id: lensBox
                anchors.centerIn: parent
                implicitHeight: Math.max(36, lensTxt.implicitHeight + 12)
                implicitWidth: Math.max(implicitHeight, lensTxt.implicitWidth + 24)
                radius: height / 2
                color: Theme.soften(face.iceFocus, face.lit ? 0.22 : 0.14)
                border.width: 1.6
                border.color: face.iceFocus

                Text {
                    id: lensTxt
                    anchors.centerIn: parent
                    text: face.reading
                    color: face.icePeak
                    font.family: Theme.fUiTitle
                    font.pixelSize: Theme.tTitle
                    font.weight: Font.DemiBold
                }
            }
        }

        Text {
            visible: face.caption !== ""
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            text: face.caption
            color: face.lit ? Theme.text : Theme.textMuted
            font.family: Theme.fUi
            font.pixelSize: Theme.tMicro
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }

        Item { Layout.fillHeight: true }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: {
            face.hovered = hovered;
            plate.requestPaint();
        }
    }

    TapHandler {
        onTapped: {
            face.forceActiveFocus();
            face.activated();
        }
    }

    Keys.onReturnPressed: function (e) {
        face.activated();
        e.accepted = true;
    }
    Keys.onSpacePressed: function (e) {
        face.activated();
        e.accepted = true;
    }

    onLitChanged: plate.requestPaint()
    onHoveredChanged: plate.requestPaint()
    onWidthChanged: plate.requestPaint()
    onHeightChanged: plate.requestPaint()
    Component.onCompleted: plate.requestPaint()
}
