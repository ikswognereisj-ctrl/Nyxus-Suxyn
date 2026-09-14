pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// THE FLOOR — stars, then three words. Pick one, that page replaces the hub.
Item {
    id: hub

    property string page: "home"
    property int door: 0
    focus: true

    readonly property bool atHome: hub.page === "home"
    readonly property var worlds: [
        { id: "games",  title: qsTr("Games"),  ink: Theme.magmaGold },
        { id: "movies", title: qsTr("Movies"), ink: Theme.icePlumGlow },
        { id: "music",  title: qsTr("Music"),  ink: Theme.iceCyan }
    ]

    function goHome() {
        hub.page = "home"
        hub.forceActiveFocus()
    }

    function enter(name) {
        hub.page = name
    }

    function enterDoor() {
        var w = hub.worlds[hub.door]
        if (w)
            hub.enter(w.id)
    }

    function pickDoor(i) {
        hub.door = Math.max(0, Math.min(hub.worlds.length - 1, i))
    }

    Keys.onPressed: function (e) {
        var k = e.key
        if (k === Qt.Key_H) {
            hub.goHome()
            e.accepted = true
            return
        }
        if (k === Qt.Key_G) {
            hub.pickDoor(0)
            hub.enter("games")
            e.accepted = true
            return
        }
        if (k === Qt.Key_M || k === Qt.Key_V) {
            hub.pickDoor(1)
            hub.enter("movies")
            e.accepted = true
            return
        }
        if (k === Qt.Key_U) {
            hub.pickDoor(2)
            hub.enter("music")
            e.accepted = true
            return
        }
        if (k === Qt.Key_Escape || k === Qt.Key_Backspace) {
            hub.goHome()
            e.accepted = true
            return
        }
        if (hub.atHome) {
            if (k === Qt.Key_Left) {
                hub.pickDoor(hub.door - 1)
                e.accepted = true
            } else if (k === Qt.Key_Right) {
                hub.pickDoor(hub.door + 1)
                e.accepted = true
            } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                hub.enterDoor()
                e.accepted = true
            }
            return
        }
        if (hub.page === "games") {
            if (k === Qt.Key_Left) gamesView.move(0, -1)
            else if (k === Qt.Key_Right) gamesView.move(0, 1)
            else if (k === Qt.Key_Up) gamesView.move(-1, 0)
            else if (k === Qt.Key_Down) gamesView.move(1, 0)
            else if (k === Qt.Key_Return || k === Qt.Key_Enter) gamesView.openCabinet()
            else return
            e.accepted = true
            return
        }
        if (hub.page === "movies") {
            if (k === Qt.Key_Left) moviesView.move(0, -1)
            else if (k === Qt.Key_Right) moviesView.move(0, 1)
            else if (k === Qt.Key_Up) moviesView.move(-1, 0)
            else if (k === Qt.Key_Down) moviesView.move(1, 0)
            else if (k === Qt.Key_Return || k === Qt.Key_Enter) moviesView.openCabinet()
            else return
            e.accepted = true
            return
        }
        if (hub.page === "music") {
            if (k === Qt.Key_Left) musicView.move(-1)
            else if (k === Qt.Key_Right) musicView.move(1)
            else if (k === Qt.Key_Up) musicView.tabStep(-1)
            else if (k === Qt.Key_Down) musicView.tabStep(1)
            else if (k === Qt.Key_Space) MediaSource.togglePlaying()
            else if (k === Qt.Key_Return || k === Qt.Key_Enter) musicView.activate()
            else return
            e.accepted = true
        }
    }

    Item {
        id: homeLayer
        visible: hub.atHome
        enabled: hub.atHome
        z: 0
        anchors.fill: parent

        Row {
            anchors.centerIn: parent
            spacing: Math.round(hub.width * 0.08)

            Repeater {
                model: hub.worlds
                Text {
                    required property var modelData
                    required property int index
                    text: String(modelData.title)
                    color: modelData.ink
                    font.family: Theme.fUiTitle
                    font.pixelSize: 88
                    font.weight: Theme.wTitle
                    font.letterSpacing: 4
                    opacity: hub.door === index ? 1 : 0.42
                    scale: hub.door === index ? 1 : 0.92
                    transformOrigin: Item.Center
                    Behavior on opacity {
                        NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutCubic }
                    }
                    Behavior on scale {
                        NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutCubic }
                    }
                    Behavior on color {
                        ColorAnimation { duration: Theme.durQuick }
                    }
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: if (hovered) hub.pickDoor(index)
                    }
                    TapHandler {
                        onTapped: {
                            hub.pickDoor(index)
                            hub.enter(String(modelData.id))
                        }
                    }
                }
            }
        }
    }

    Item {
        visible: hub.page === "games"
        enabled: visible
        z: 2
        anchors.fill: parent
        FloorPageGames {
            id: gamesView
            anchors.fill: parent
            anchors.margins: Theme.s8
            onBackRequested: hub.goHome()
        }
    }
    Item {
        visible: hub.page === "movies"
        enabled: visible
        z: 2
        anchors.fill: parent
        FloorPageMovies {
            id: moviesView
            anchors.fill: parent
            anchors.margins: Theme.s8
            onBackRequested: hub.goHome()
        }
    }
    Item {
        visible: hub.page === "music"
        enabled: visible
        z: 2
        anchors.fill: parent
        FloorPageMusic {
            id: musicView
            anchors.fill: parent
            onBackRequested: hub.goHome()
        }
    }
}
