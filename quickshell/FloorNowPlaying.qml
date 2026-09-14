pragma ComponentBehavior: Bound
import QtQuick

// Nyxus Media now-playing card — texture for the lobby screens.
Rectangle {
    id: card
    width: 640
    height: 360
    color: "#0a0610"

    Image {
        anchors.fill: parent
        source: MediaSource.artUrl
        fillMode: Image.PreserveAspectCrop
        opacity: MediaSource.artUrl.length > 0 ? 0.55 : 0
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#aa12081c" }
            GradientStop { position: 1.0; color: "#ee0a0610" }
        }
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 28
        spacing: 8
        Text {
            text: "NYXUS MEDIA"
            color: "#00e5ff"
            font.pixelSize: 18
            font.letterSpacing: 4
        }
        Text {
            text: MediaSource.displayTitle.length ? MediaSource.displayTitle : "Library"
            color: "#ffea00"
            font.pixelSize: 32
            font.bold: true
            width: parent.width
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
        }
        Text {
            text: MediaSource.displaySubtitle
            color: "#e8e4dc"
            font.pixelSize: 18
            width: parent.width
            elide: Text.ElideRight
        }
    }
}
