pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "floor-systems.js" as FloorSystems

// Games world. The door interior stays the room; cabinets sit on it.
Item {
    id: page
    focus: visible

    property var mountedDirs: []
    property bool scanned: false
    property int rowIndex: 0
    property int colIndex: 0

    readonly property var rows: page.buildRows(page.scanned, page.mountedDirs)
    readonly property int stripH: 300 + Theme.s4 + Theme.tDisplay + Theme.tHead + Theme.s2

    signal backRequested()

    function buildRows(scanned, dirs) {
        var src = FloorSystems.rows()
        var out = []
        for (var i = 0; i < src.length; i++) {
            var items = []
            var list = src[i].systems || []
            for (var k = 0; k < list.length; k++) {
                var s = list[k]
                var on = scanned && FloorSystems.folderHit(s, dirs)
                items.push({
                    title: s.name,
                    sub: on ? qsTr("Mounted") : src[i].name,
                    art: Qt.resolvedUrl(s.logo),
                    id: s.id,
                    sys: s,
                    on: on
                })
            }
            out.push({ heading: src[i].name, items: items })
        }
        return out
    }

    function scanIo() {
        var u = String(Qt.resolvedUrl("floor-scan.py"))
        if (u.indexOf("file://") === 0)
            return u.slice(7)
        return u
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

    function openCabinet() {
        Quickshell.execDetached(["blast-from-the-past"])
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

    Process {
        id: scanProc
        running: page.visible
        command: ["timeout", "--kill-after=1s", "2", "python3", page.scanIo()]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text))
                    page.mountedDirs = j.dirs || []
                } catch (e) {
                    page.mountedDirs = []
                }
                page.scanned = true
            }
        }
        onExited: function () {
            if (!page.scanned)
                page.scanned = true
        }
    }

    readonly property var featured: page.current()

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
                    text: qsTr("Games")
                    color: Theme.magmaGold
                    font.family: Theme.fUiTitle
                    font.pixelSize: Theme.tJumbo
                    font.weight: Theme.wTitle
                }
                Text {
                    text: page.featured
                         ? (page.featured.title + "  ·  " + page.featured.sub)
                         : qsTr("Mounted library  ·  Return opens the cabinet")
                    color: Theme.textMuted
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tTitle
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
                    borderColor: Theme.soften(Theme.iceCyan, backHov.hovered ? 0.90 : 0.45)
                }
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Esc  ·  home")
                    color: Theme.iceCyan
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tTitle
                    font.weight: Theme.wStrong
                }
            }
        }

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            contentWidth: width
            contentHeight: col.height
            flickableDirection: Flickable.VerticalFlick

            Column {
                id: col
                width: flick.width
                spacing: Theme.s8

                Repeater {
                    id: shelves
                    model: page.rows
                    delegate: Column {
                        id: shelf
                        required property var modelData
                        required property int index
                        width: col.width
                        spacing: Theme.s3

                        Text {
                            text: String(shelf.modelData.heading || "")
                            color: Theme.iceCyan
                            font.family: Theme.fUiTitle
                            font.pixelSize: Theme.tDisplay
                            font.weight: Theme.wStrong
                            font.letterSpacing: Theme.trackMicro
                        }

                        ListView {
                            width: parent.width
                            height: page.stripH
                            orientation: ListView.Horizontal
                            spacing: Theme.s8
                            clip: false
                            boundsBehavior: Flickable.StopAtBounds
                            model: shelf.modelData.items || []
                            currentIndex: page.rowIndex === shelf.index ? page.colIndex : -1
                            highlightFollowsCurrentItem: true
                            highlightRangeMode: ListView.ApplyRange
                            preferredHighlightBegin: 0
                            preferredHighlightEnd: width - 220
                            onCurrentIndexChanged: {
                                if (currentIndex >= 0)
                                    positionViewAtIndex(currentIndex, ListView.Contain)
                            }
                            delegate: FloorCover {
                                required property int index
                                required property var modelData
                                title: String(modelData.title || "")
                                subtitle: String(modelData.sub || "")
                                art: modelData.art || ""
                                fillMode: Image.PreserveAspectFit
                                selected: page.rowIndex === shelf.index && page.colIndex === index
                                onActivated: {
                                    page.select(shelf.index, index)
                                    page.openCabinet()
                                }
                                HoverHandler {
                                    onHoveredChanged: if (hovered) page.select(shelf.index, index)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
