pragma ComponentBehavior: Bound
import QtQuick

// BLAST FROM THE PAST — hero marquee over the island.
Rectangle {
    id: hero
    width: 1024
    height: 280
    color: "#0a0610"
    border.width: 8
    border.color: "#ff2bd6"

    Rectangle {
        anchors.fill: parent
        anchors.margins: 10
        color: "transparent"
        border.width: 3
        border.color: "#00e5ff"
    }

    Column {
        anchors.centerIn: parent
        spacing: 6
        Text {
            text: "BLAST"
            color: "#ff2bd6"
            font.pixelSize: 92
            font.letterSpacing: 18
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
            style: Text.Outline
            styleColor: "#4a0028"
        }
        Text {
            text: "FROM THE PAST"
            color: "#ffea00"
            font.pixelSize: 48
            font.letterSpacing: 10
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
            style: Text.Outline
            styleColor: "#3a2800"
        }
    }
}
