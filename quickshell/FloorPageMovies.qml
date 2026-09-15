pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import QtQuick.Layouts

// Movies world. Official Midnight Society stills only. Never yt-dlp.
Item {
    id: page
    focus: visible

    readonly property string cabinetRoot: (Quickshell.env("HOME") || "") + "/ToonCabinet"
    readonly property string kioskPath: page.cabinetRoot + "/index.html"
    readonly property string stillRoot: "file://" + page.cabinetRoot + "/posters/"
    readonly property int posterW: 200
    readonly property int posterH: 300
    readonly property int railH: page.posterH + Theme.s4 + Theme.tDisplay + Theme.tHead + Theme.s2

    property int rowIndex: 0
    property int colIndex: 0

    signal backRequested()

    readonly property var rows: [
        {
            "name": "Continue watching",
            "items": [
                { "file": "dinosaurs.jpg",  "title": "Dinosaurs",                       "sub": "S2 · E3",  "watched": 0.62 },
                { "file": "goosebumps.jpg", "title": "Goosebumps",                      "sub": "S1 · E4",  "watched": 0.38 },
                { "file": "sonic.jpg",      "title": "Adventures of Sonic the Hedgehog","sub": "S1 · E12", "watched": 0.81 },
                { "file": "temple.jpg",     "title": "Legends of the Hidden Temple",    "sub": "S1 · E6",  "watched": 0.24 },
                { "file": "dark.jpg",       "title": "Are You Afraid of the Dark?",     "sub": "S1 · E2",  "watched": 0.55 }
            ]
        },
        {
            "name": "Shows",
            "items": [
                { "file": "goosebumps.jpg",  "title": "Goosebumps",                       "sub": "Scholastic · full episodes" },
                { "file": "dark.jpg",        "title": "Are You Afraid of the Dark?",      "sub": "WildBrain · seven seasons" },
                { "file": "cryptkeeper.jpg", "title": "Tales from the Cryptkeeper",       "sub": "Nelvana · Retro Rerun" },
                { "file": "dinosaurs.jpg",   "title": "Dinosaurs",                        "sub": "Disney+ · four seasons" },
                { "file": "sonic.jpg",       "title": "Adventures of Sonic the Hedgehog", "sub": "WildBrain · full series" },
                { "file": "stickin.jpg",     "title": "Stickin' Around",                   "sub": "Nelvana · full series" },
                { "file": "sixteen.jpg",     "title": "6Teen",                            "sub": "Nelvana · full series" },
                { "file": "petmonster.jpg",  "title": "My Pet Monster",                   "sub": "Nelvana · full series" },
                { "file": "mythic.jpg",      "title": "Mythic Warriors",                  "sub": "Nelvana · Greek myths" }
            ]
        },
        {
            "name": "Midnight Society",
            "items": [
                { "file": "cadillacs.jpg",   "title": "Cadillacs and Dinosaurs",      "sub": "Nelvana · 13 episodes" },
                { "file": "dkc.jpg",         "title": "Donkey Kong Country",          "sub": "Nelvana · cartoon" },
                { "file": "temple.jpg",      "title": "Legends of the Hidden Temple", "sub": "Paramount+ · full run" },
                { "file": "degrassi.jpg",    "title": "Degrassi High: School's Out",  "sub": "WildBrain · 1992" },
                { "file": "cryptkeeper.jpg", "title": "Tales from the Cryptkeeper",   "sub": "Watch in the kiosk" }
            ]
        }
    ]

    function still(fileName) { return page.stillRoot + fileName }

    function openCabinet() {
        Quickshell.execDetached(["xdg-open", page.kioskPath])
    }

    function itemCount(i) {
        var r = page.rows[i]
        return (r && r.items) ? r.items.length : 0
    }

    function current() {
        var r = page.rows[page.rowIndex]
        if (!r || !r.items)
            return null
        return r.items[page.colIndex] || null
    }

    function move(dRow, dCol) {
        var n = page.rows.length
        if (n <= 0)
            return
        var nr = Math.max(0, Math.min(n - 1, page.rowIndex + dRow))
        var count = page.itemCount(nr)
        var nc = page.colIndex
        if (dCol !== 0 && count > 0) {
            nc = page.colIndex + dCol
            if (nc < 0) {
                if (nr > 0) {
                    page.rowIndex = nr - 1
                    page.colIndex = Math.max(0, page.itemCount(page.rowIndex) - 1)
                    return
                }
                nc = 0
            } else if (nc >= count) {
                if (nr < n - 1) {
                    page.rowIndex = nr + 1
                    page.colIndex = 0
                    return
                }
                nc = count - 1
            }
        } else if (nc >= count)
            nc = Math.max(0, count - 1)
        page.rowIndex = nr
        page.colIndex = Math.max(0, nc)
    }

    function select(r, c) {
        page.rowIndex = r
        page.colIndex = c
    }

    Keys.onPressed: function (e) {
        var k = e.key
        if (k === Qt.Key_Escape || k === Qt.Key_Backspace) {
            page.backRequested()
            e.accepted = true
        } else if (k === Qt.Key_Left) {
            page.move(0, -1)
            e.accepted = true
        } else if (k === Qt.Key_Right) {
            page.move(0, 1)
            e.accepted = true
        } else if (k === Qt.Key_Up) {
            page.move(-1, 0)
            e.accepted = true
        } else if (k === Qt.Key_Down) {
            page.move(1, 0)
            e.accepted = true
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            page.openCabinet()
            e.accepted = true
        }
    }

    readonly property var featured: page.current()

    component Poster: Item {
        id: card
        property var show: ({})
        property bool hot: false
        readonly property real watched: (card.show && card.show.watched !== undefined)
                                        ? Number(card.show.watched) : -1
        width: page.posterW
        height: page.railH

        Pane {
            id: plate
            width: page.posterW
            height: page.posterH
            elevation: 1
            bloomAtRest: false
            fill: Theme.surface
            radius: Theme.r2
            focusLevel: card.hot ? 1 : 0.12
            crown: card.hot ? 0.90 : 0.48

            Image {
                id: art
                anchors.fill: parent
                anchors.margins: Theme.s2
                source: page.still(String(card.show.file || ""))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                smooth: true
                visible: status === Image.Ready
            }
            Rectangle {
                visible: card.watched >= 0
                anchors.left: art.left
                anchors.right: art.right
                anchors.bottom: art.bottom
                height: Theme.s3
                color: Theme.elevated
                Rectangle {
                    width: Math.round(parent.width * Math.max(0, Math.min(1, card.watched)))
                    height: parent.height
                    color: Theme.icePlumGlow
                }
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
                borderWidth: card.hot ? Theme.s2 : Theme.lookOutlineW
                borderColor: card.hot ? Theme.icePlumGlow : Theme.soften(Theme.lookSeam, 0.45)
            }
        }
        Column {
            anchors.top: plate.bottom
            anchors.topMargin: Theme.s4
            width: page.posterW
            spacing: Theme.s2
            Text {
                width: parent.width
                text: String(card.show.title || "")
                color: card.hot ? Theme.icePlumGlow : Theme.textMuted
                font.family: Theme.fUi
                font.pixelSize: Theme.tTitle
                font.weight: card.hot ? Theme.wStrong : Theme.wBody
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: String(card.show.sub || "").length > 0
                text: String(card.show.sub || "")
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tHead
                elide: Text.ElideRight
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.s6

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s8

            Column {
                Layout.fillWidth: true
                spacing: Theme.s2
                Text {
                    text: qsTr("Movies")
                    color: Theme.icePlumGlow
                    font.family: Theme.fUiTitle
                    font.pixelSize: Theme.tJumbo
                    font.weight: Theme.wTitle
                }
                Text {
                    width: parent.width
                    text: page.featured
                          ? (page.featured.title + "  ·  " + page.featured.sub)
                          : qsTr("Midnight Society  ·  Return watches in the kiosk")
                    color: Theme.textMuted
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tTitle
                    elide: Text.ElideRight
                }
            }
            Item {
                Layout.preferredWidth: 200
                Layout.preferredHeight: Theme.s10 * 2
                HoverHandler { id: backHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: page.backRequested() }
                CutRect {
                    anchors.fill: parent
                    radius: Theme.r2
                    color: Theme.elevated
                    borderWidth: Theme.lookOutlineW
                    borderColor: Theme.soften(Theme.icePlumGlow, backHov.hovered ? 0.90 : 0.45)
                }
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Esc  ·  home")
                    color: Theme.icePlumGlow
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tTitle
                    font.weight: Theme.wStrong
                }
            }
        }

        ListView {
            id: rowList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Theme.s8
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: page.rowIndex
            model: page.rows
            delegate: Item {
                id: shelf
                required property var modelData
                required property int index
                readonly property var items: shelf.modelData.items
                readonly property bool on: page.rowIndex === shelf.index
                width: ListView.view ? ListView.view.width : page.width
                height: Theme.tDisplay + Theme.s4 + page.railH

                Column {
                    anchors.fill: parent
                    spacing: Theme.s4
                    Text {
                        text: String(shelf.modelData.name || "")
                        color: Theme.icePlumGlow
                        font.family: Theme.fUiTitle
                        font.pixelSize: Theme.tDisplay
                        font.weight: Theme.wTitle
                        font.letterSpacing: Theme.trackDisplay
                    }
                    ListView {
                        id: rail
                        width: parent.width
                        height: page.railH
                        orientation: ListView.Horizontal
                        clip: true
                        spacing: Theme.s6
                        boundsBehavior: Flickable.StopAtBounds
                        currentIndex: shelf.on ? page.colIndex : -1
                        model: shelf.items
                        onCurrentIndexChanged: {
                            if (shelf.on && rail.currentIndex >= 0)
                                rail.positionViewAtIndex(rail.currentIndex, ListView.Contain)
                        }
                        delegate: Poster {
                            required property var modelData
                            required property int index
                            show: modelData
                            hot: shelf.on && page.colIndex === index
                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                                onHoveredChanged: if (hovered) page.select(shelf.index, index)
                            }
                            TapHandler {
                                onTapped: {
                                    page.select(shelf.index, index)
                                    page.openCabinet()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
