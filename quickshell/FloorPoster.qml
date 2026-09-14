pragma ComponentBehavior: Bound
import QtQuick

// Lightbox poster frame. Titles are placeholders — custom covers later.
Pane {
    id: poster
    property string title: "COMING SOON"
    property color neon: "#ff2bd6"
    width: 110
    height: 168
    radiusTL: 4; radiusTR: 4; radiusBR: 4; radiusBL: 4
    fill: Qt.rgba(0.08, 0.04, 0.06, 0.95)
    rim: 0.95
    crown: 0.5
    bloomAlpha: 0.4
    focusLevel: 0.6
    dispersion: 0.9
    Rectangle {
        anchors.fill: parent
        anchors.margins: 8
        color: Qt.rgba(neon.r, neon.g, neon.b, 0.18)
        border.color: neon
        border.width: 1
        Text {
            anchors.centerIn: parent
            text: poster.title
            color: poster.neon
            font.pixelSize: 11
            font.letterSpacing: 1.2
            width: parent.width - 8
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
