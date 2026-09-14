pragma ComponentBehavior: Bound
import QtQuick

// 10-foot poster card. Pane glass over Headliner; Theme tokens only.
Item {
    id: cover

    property string title: ""
    property string subtitle: ""
    property url art: ""
    property bool selected: false
    property int fillMode: Image.PreserveAspectCrop
    signal activated()

    property int posterW: 200
    property int posterH: 300
    readonly property bool hot: cover.selected || hov.hovered

    width: posterW
    implicitWidth: posterW
    implicitHeight: posterH + Theme.s4 + titles.implicitHeight
    height: implicitHeight
    z: cover.selected ? 1 : 0
    scale: cover.selected ? 1.04 : (hov.hovered ? 1.02 : 1.0)
    transformOrigin: Item.Top

    Behavior on scale {
        NumberAnimation {
            duration: Theme.durQuick
            easing.type: Easing.OutQuint
        }
    }

    HoverHandler {
        id: hov
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        onTapped: cover.activated()
    }

    Pane {
        id: plate
        width: cover.posterW
        height: cover.posterH
        elevation: 1
        bloomAtRest: false
        fill: Theme.surface
        radius: Theme.r2
        focusLevel: cover.selected ? 1 : (hov.hovered ? 0.55 : 0.12)
        crown: cover.hot ? 0.90 : 0.48

        CutRect {
            anchors.fill: parent
            anchors.margins: Theme.s2
            radius: Theme.r1
            color: Theme.void_
            visible: img.status !== Image.Ready
        }

        Image {
            id: img
            anchors.fill: parent
            anchors.margins: Theme.s2
            source: cover.art
            fillMode: cover.fillMode
            asynchronous: true
            visible: status === Image.Ready
            sourceSize.width: cover.posterW * 2
            sourceSize.height: cover.posterH * 2
        }

        Text {
            visible: img.status !== Image.Ready
            anchors.centerIn: parent
            width: parent.width - Theme.s8
            text: cover.title.length ? cover.title.charAt(0) : ""
            color: Theme.teal
            font.family: Theme.fUiTitle
            font.pixelSize: Theme.tDisplay
            font.weight: Theme.wTitle
            horizontalAlignment: Text.AlignHCenter
        }

        GlassEdge {
            anchors.fill: parent
            radiusTL: Theme.r2
            radiusTR: Theme.r2
            radiusBR: Theme.r2
            radiusBL: Theme.r2
            body: 0
            wash: 0
            edging: 0.70
        }

        CutRect {
            anchors.fill: parent
            radius: Theme.r2
            color: "transparent"
            borderWidth: Theme.lookOutlineW
            borderColor: Theme.soften(Theme.lookSeam, cover.hot ? 0.95 : 0.45)
            Behavior on borderColor {
                ColorAnimation { duration: Theme.durQuick }
            }
        }
    }

    Column {
        id: titles
        anchors.top: plate.bottom
        anchors.topMargin: Theme.s4
        width: cover.posterW
        spacing: Theme.s1

        Text {
            width: parent.width
            text: cover.title
            color: cover.hot ? Theme.tealGlow : Theme.textMuted
            font.family: Theme.fUi
            font.pixelSize: 24
            font.weight: cover.selected ? Theme.wStrong : Theme.wBody
            elide: Text.ElideRight
        }
        Text {
            visible: cover.subtitle.length > 0
            width: parent.width
            text: cover.subtitle
            color: Theme.textDim
            font.family: Theme.fUi
            font.pixelSize: 18
            elide: Text.ElideRight
        }
    }
}
