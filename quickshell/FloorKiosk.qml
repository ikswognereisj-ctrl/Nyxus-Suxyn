pragma ComponentBehavior: Bound
import QtQuick

// Multiplex island: NOW PLAYING (theatres) left-up, GAMES right-up,
// THE FLOOR in the middle. Mix of both in one court.
Item {
    id: kiosk
    property real yaw: 0
    property int face: 1

    width: 1100
    height: 640

    // NOW PLAYING — theatres, above-left
    Pane {
        id: nowPlay
        width: 340
        height: 150
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 40
        radiusTL: 6; radiusTR: 6; radiusBR: 6; radiusBL: 6
        fill: Qt.rgba(0.05, 0.02, 0.04, 0.92)
        rim: 1.1
        crown: 0.7
        bloomAlpha: 0.6
        focusLevel: 1
        dispersion: 1.2
        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 6
            Text {
                text: "NOW PLAYING"
                color: "#ff2bd6"
                font.pixelSize: 22
                font.letterSpacing: 3.0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                text: "Continue watching  ·  Posters"
                color: "#e8e4dc"
                font.pixelSize: 14
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // GAMES — arcade, above-right
    Pane {
        id: nowGames
        width: 340
        height: 150
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 40
        radiusTL: 6; radiusTR: 6; radiusBR: 6; radiusBL: 6
        fill: Qt.rgba(0.02, 0.04, 0.08, 0.92)
        rim: 1.1
        crown: 0.7
        bloomAlpha: 0.6
        focusLevel: 1
        dispersion: 1.2
        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 6
            Text {
                text: "INSERT COIN"
                color: "#00e5ff"
                font.pixelSize: 22
                font.letterSpacing: 3.0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                text: "Continue playing  ·  Scores"
                color: "#e8e4dc"
                font.pixelSize: 14
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    Rectangle {
        id: col
        width: 48
        height: 140
        radius: 8
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        color: "#120814"
        border.width: 2
        border.color: "#ff2bd6"
    }

    Pane {
        width: 320
        height: 220
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: col.top
        anchors.bottomMargin: 6
        radiusTL: 12; radiusTR: 12; radiusBR: 8; radiusBL: 8
        fill: Qt.rgba(0.04, 0.02, 0.05, 0.94)
        rim: 1.0
        crown: 0.8
        bloomAlpha: 0.55
        focusLevel: 1
        dispersion: 1.15
        Column {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 8
            Text {
                text: "THE FLOOR"
                color: "#ffea00"
                font.pixelSize: 26
                font.letterSpacing: 3.0
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }
            Rectangle {
                width: parent.width
                height: 2
                color: "#ff2bd6"
            }
            Text {
                text: "Pins  ·  Continue  ·  Mix"
                color: "#c8c4cc"
                font.pixelSize: 15
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
