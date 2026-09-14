pragma ComponentBehavior: Bound
import QtQuick

// One slider card: Games / Movies / Music.
Pane {
    id: door

    property string title: ""
    property string kicker: ""
    property string liveLine: ""
    property url art: ""
    property bool lit: false
    property color wash: Theme.magmaEmber
    property color accent: Theme.magmaGold

    elevation: door.lit ? 3 : 1
    radiusTL: Theme.r3
    radiusTR: Theme.r3
    radiusBR: Theme.r3
    radiusBL: Theme.r3
    fill: Theme.glassFill
    rim: door.lit ? 1.18 : 0.70
    crown: door.lit ? 0.92 : 0.40
    bloomAlpha: door.lit ? 0.40 : 0.08
    bloomAtRest: false
    focusLevel: door.lit ? 1 : 0.10
    clip: true

    Image {
        anchors.fill: parent
        source: door.art
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        smooth: true
        visible: status === Image.Ready
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.40; color: Qt.rgba(0, 0, 0, 0) }
            GradientStop { position: 1.00; color: Qt.rgba(door.wash.r, door.wash.g, door.wash.b, door.lit ? 0.78 : 0.64) }
        }
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.s8
        spacing: Theme.s3
        Text {
            text: door.kicker
            color: Theme.iceCyan
            font.family: Theme.fUi
            font.pixelSize: Theme.tHead
            font.weight: Theme.wStrong
            font.letterSpacing: 5
        }
        Text {
            width: parent.width
            text: door.title
            color: door.accent
            font.family: Theme.fUiTitle
            font.pixelSize: 56
            font.weight: Theme.wTitle
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            visible: door.liveLine.length > 0
            text: door.liveLine
            color: Theme.textMuted
            font.family: Theme.fUi
            font.pixelSize: Theme.tTitle
            elide: Text.ElideRight
        }
    }

    GlassEdge {
        anchors.fill: parent
        radiusTL: Theme.r3
        radiusTR: Theme.r3
        radiusBR: Theme.r3
        radiusBL: Theme.r3
        body: 0
        wash: 0
        edging: door.lit ? 0.90 : 0.48
    }
    CutRect {
        anchors.fill: parent
        radius: Theme.r3
        color: "transparent"
        borderWidth: door.lit ? Theme.s2 : Theme.lookOutlineW
        borderColor: door.lit
                     ? Theme.soften(Theme.iceCyan, 0.95)
                     : Theme.soften(Theme.lookSeam, 0.45)
    }

    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
