pragma ComponentBehavior: Bound
import QtQuick

// Kid-pack glow stickers. Vinyl pale green, the ones that go on a bedroom ceiling.
Rectangle {
    id: g
    property string kind: "star"
    width: 256
    height: 256
    color: "#00000000"

    Text {
        anchors.centerIn: parent
        text: g.kind === "moon" ? "☽"
            : (g.kind === "planet" ? "●"
            : (g.kind === "shoot" ? "✦" : "★"))
        color: "#c8ff6a"
        font.pixelSize: g.kind === "planet" ? 160 : 200
        style: Text.Outline
        styleColor: "#4a7a18"
    }
    Text {
        visible: g.kind === "planet"
        anchors.centerIn: parent
        text: "○"
        color: "#d0ff90"
        font.pixelSize: 230
        opacity: 0.7
    }
    Text {
        visible: g.kind === "shoot"
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 28
        text: "—"
        color: "#c8ff6a"
        font.pixelSize: 90
        rotation: -28
    }
}
