pragma ComponentBehavior: Bound
import QtQuick

// NOW PLAYING board: movies left, games right, clock in the middle.
Rectangle {
    id: board
    width: 1024
    height: 220
    color: "#0a0610"
    border.width: 6
    border.color: "#ff2bd6"

    Row {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        Rectangle {
            width: 380
            height: parent.height
            color: "#140814"
            border.color: "#ff2bd6"
            border.width: 3
            Column {
                anchors.centerIn: parent
                spacing: 6
                Text {
                    text: "LEFT SIDE"
                    color: "#ff2bd6"
                    font.pixelSize: 22
                    font.letterSpacing: 3
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "FOR MOVIES"
                    color: "#ffe8f4"
                    font.pixelSize: 28
                    font.bold: true
                    font.letterSpacing: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }

        Rectangle {
            width: 196
            height: parent.height
            color: "#101018"
            border.color: "#00e5ff"
            border.width: 3
            radius: 8
            Column {
                anchors.centerIn: parent
                spacing: 4
                Text {
                    id: clk
                    text: Qt.formatTime(new Date(), "hh:mm")
                    color: "#00e5ff"
                    font.pixelSize: 44
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "NOW"
                    color: "#ffea00"
                    font.pixelSize: 16
                    font.letterSpacing: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
            Timer {
                interval: 15000
                running: true
                repeat: true
                onTriggered: clk.text = Qt.formatTime(new Date(), "hh:mm")
            }
        }

        Rectangle {
            width: 380
            height: parent.height
            color: "#081018"
            border.color: "#00e5ff"
            border.width: 3
            Column {
                anchors.centerIn: parent
                spacing: 6
                Text {
                    text: "RIGHT SIDE"
                    color: "#00e5ff"
                    font.pixelSize: 22
                    font.letterSpacing: 3
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Text {
                    text: "FOR ARCADE GAMES"
                    color: "#e8ffff"
                    font.pixelSize: 26
                    font.bold: true
                    font.letterSpacing: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
