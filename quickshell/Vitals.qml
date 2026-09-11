// Nyxus Suxyn — the Gauge's vitals, drawn rather than borrowed.
//
// These were Font Awesome codepoints. Two of the three rendered as empty
// boxes the moment the preview machine had a different Font Awesome major
// than the ISO, which is a broken-looking taskbar caused by a packaging
// detail — exactly the class of defect this build keeps paying for. So the
// three indicators that are always on screen are ours: vector shapes on the
// Theme's colours, with no font dependency at all.
//
// They also say more than a glyph can. The battery is a real gauge: the fill
// IS the charge. The Wi-Fi arcs light up to signal strength. A glyph can only
// pick from five states somebody else drew.
import QtQuick
import QtQuick.Shapes

Row {
    id: vitals

    property real iconSize: 16
    property color tone: Theme.textMuted
    property color toneDim: Theme.textDim

    spacing: Theme.s5

    // ── Wi-Fi ────────────────────────────────────────────────────────
    Item {
        id: wifi
        width: vitals.iconSize
        height: vitals.iconSize
        readonly property color c: Sys.wifiOn ? vitals.tone : vitals.toneDim

        Shape {
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            // three arcs over a dot, centred on the bottom of the box
            ShapePath {
                strokeColor: wifi.c
                strokeWidth: 1.6
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                PathAngleArc {
                    centerX: vitals.iconSize / 2
                    centerY: vitals.iconSize - 2
                    radiusX: 7
                    radiusY: 7
                    startAngle: -145
                    sweepAngle: 110
                }
            }
            ShapePath {
                strokeColor: wifi.c
                strokeWidth: 1.6
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                PathAngleArc {
                    centerX: vitals.iconSize / 2
                    centerY: vitals.iconSize - 2
                    radiusX: 4.2
                    radiusY: 4.2
                    startAngle: -140
                    sweepAngle: 100
                }
            }
        }
        Rectangle {
            width: 2.6
            height: 2.6
            radius: 1.3
            color: wifi.c
            x: (parent.width - width) / 2
            y: parent.height - 3.2
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: Bus.openFlyoutAt("wifi") }

        // Off is a slash, not a different picture: the same shape, struck out.
        Rectangle {
            visible: !Sys.wifiOn
            width: parent.width * 1.15
            height: 1.4
            radius: 0.7
            color: Theme.textDim
            x: -1
            y: parent.height / 2
            transformOrigin: Item.Center
            rotation: -38
        }
    }

    // ── Bluetooth ────────────────────────────────────────────────────
    Item {
        id: bt
        visible: Sys.btAdapter !== null
        width: visible ? vitals.iconSize : 0
        height: vitals.iconSize
        readonly property color c: Sys.btOn ? vitals.tone : vitals.toneDim

        Shape {
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: bt.c
                strokeWidth: 1.5
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                fillColor: "transparent"
                startX: 8; startY: 1.8
                PathLine { x: 12.4; y: 5.4 }
                PathLine { x: 8; y: 8 }
                PathLine { x: 12.4; y: 10.6 }
                PathLine { x: 8; y: 14.2 }
                PathMove { x: 8; y: 1.8 }
                PathLine { x: 8; y: 14.2 }
                PathMove { x: 3.8; y: 5.4 }
                PathLine { x: 8; y: 8 }
                PathLine { x: 3.8; y: 10.6 }
            }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: Bus.openFlyoutAt("bluetooth") }
        Rectangle {
            visible: !Sys.btOn
            width: parent.width * 1.15
            height: 1.4
            radius: 0.7
            color: Theme.textDim
            x: -1
            y: parent.height / 2
            transformOrigin: Item.Center
            rotation: -38
        }
    }

    // ── volume ───────────────────────────────────────────────────────
    Item {
        id: vol
        width: vitals.iconSize
        height: vitals.iconSize
        readonly property color c: Sys.muted ? vitals.toneDim : vitals.tone

        Shape {
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer

            // the cone
            ShapePath {
                fillColor: vol.c
                strokeColor: "transparent"
                startX: 2; startY: 6
                PathLine { x: 5;  y: 6 }
                PathLine { x: 9;  y: 2.5 }
                PathLine { x: 9;  y: 13.5 }
                PathLine { x: 5;  y: 10 }
                PathLine { x: 2;  y: 10 }
                PathLine { x: 2;  y: 6 }
            }
            // one wave per half of the level, so the icon is a readout
            ShapePath {
                strokeColor: vol.c
                strokeWidth: 1.5
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                PathAngleArc {
                    centerX: 9
                    centerY: 8
                    radiusX: 3.4
                    radiusY: 3.4
                    startAngle: -52
                    sweepAngle: 104
                }
            }
            ShapePath {
                strokeColor: Sys.volume > 0.5 ? vol.c : "transparent"
                strokeWidth: 1.5
                capStyle: ShapePath.RoundCap
                fillColor: "transparent"
                PathAngleArc {
                    centerX: 9
                    centerY: 8
                    radiusX: 6
                    radiusY: 6
                    startAngle: -48
                    sweepAngle: 96
                }
            }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: Bus.openFlyoutAt("sound") }

        Rectangle {
            visible: Sys.muted
            width: parent.width * 1.15
            height: 1.4
            radius: 0.7
            color: Theme.danger
            x: -1
            y: parent.height / 2
            transformOrigin: Item.Center
            rotation: -38
        }
    }

    // ── battery · a real gauge, not a picture of one ─────────────────
    Item {
        id: batt
        visible: Sys.hasBattery
        width: 25
        height: vitals.iconSize
        readonly property bool low: Sys.batteryPercent <= 15 && !Sys.batteryCharging
        readonly property color c: low ? Theme.danger
                                 : (Sys.batteryCharging ? Theme.ok : vitals.tone)

        Rectangle {
            id: shell_
            width: 21
            height: 11
            radius: 3.5
            y: (batt.height - height) / 2
            color: "transparent"
            border.width: 1.2
            border.color: Theme.soften(batt.c, 0.55)

            Rectangle {
                x: 2
                y: 2
                height: parent.height - 4
                width: Math.max(1.5, (parent.width - 4) * Math.min(1, Sys.batteryPercent / 100))
                radius: 1.8
                color: batt.c
                Behavior on width {
                    NumberAnimation {
                        duration: Theme.durBase
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveMove
                    }
                }
            }
        }
        Rectangle {
            x: shell_.width + 1
            y: (batt.height - height) / 2
            width: 2
            height: 4.5
            radius: 1
            color: Theme.soften(batt.c, 0.55)
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: Bus.openFlyoutAt("battery") }

        // Charging is a bolt over the gauge, so charge level stays readable.
        Shape {
            visible: Sys.batteryCharging
            anchors.fill: parent
            antialiasing: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: Theme.void_
                strokeColor: Theme.ok
                strokeWidth: 0.8
                startX: 11.5; startY: 2.5
                PathLine { x: 8.0;  y: 8.4 }
                PathLine { x: 10.4; y: 8.4 }
                PathLine { x: 9.2;  y: 13.5 }
                PathLine { x: 13.0; y: 7.2 }
                PathLine { x: 10.6; y: 7.2 }
                PathLine { x: 11.5; y: 2.5 }
            }
        }
    }

    // The number only when the number matters. A percentage on screen all day
    // is noise; a percentage under 30 is information.
    Text {
        visible: Sys.hasBattery && Sys.batteryPercent <= 30 && !Sys.batteryCharging
        text: Sys.batteryPercent + "%"
        height: vitals.iconSize
        verticalAlignment: Text.AlignVCenter
        font.family: Theme.fUi
        font.pixelSize: Theme.tMicro
        font.weight: Font.Medium
        color: Sys.batteryPercent <= 15 ? Theme.danger : vitals.tone
    }
}
