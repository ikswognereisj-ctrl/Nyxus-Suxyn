pragma ComponentBehavior: Bound
import QtQuick

// Original 80s-style poster card. Not a studio one-sheet.
Rectangle {
    id: card
    property string title: "STARLIGHT"
    property color neon: "#ff2bd6"
    width: 320
    height: 480
    color: "#100814"
    border.color: card.neon
    border.width: 8

    Rectangle {
        anchors.fill: parent
        anchors.margins: 18
        color: Qt.rgba(card.neon.r, card.neon.g, card.neon.b, 0.18)
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1a0820" }
            GradientStop { position: 1.0; color: card.neon }
        }
        Column {
            anchors.centerIn: parent
            spacing: 14
            Text {
                text: card.title
                color: "#fff4ff"
                font.pixelSize: 28
                font.letterSpacing: 3
                font.bold: true
                width: 260
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            Rectangle {
                width: 80
                height: 80
                radius: 40
                color: "transparent"
                border.color: "#ffea00"
                border.width: 4
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}
