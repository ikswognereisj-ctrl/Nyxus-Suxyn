pragma ComponentBehavior: Bound
import QtQuick

// 2D marquee / neon sign, used as a 3D texture.
Rectangle {
    id: sign
    property string title: "NOW PLAYING"
    property string sub: ""
    property color neon: "#ff2bd6"
    width: 512
    height: 160
    color: "#120814"
    border.color: sign.neon
    border.width: 4
    Column {
        anchors.centerIn: parent
        spacing: 8
        Text {
            text: sign.title
            color: sign.neon
            font.pixelSize: 42
            font.letterSpacing: 4
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            visible: sign.sub !== ""
            text: sign.sub
            color: "#e8e4dc"
            font.pixelSize: 22
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
