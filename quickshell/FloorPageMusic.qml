pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// Apple Music / Melosik layout: rail, cover-flow, bottom transport.
Item {
    id: page

    property string tab: "albums"
    property int pick: 0
    property var albums: []
    property var tracks: []
    property var kept: []
    property var mixes: []
    property int albumCount: 0
    property int trackCount: 0
    property bool shuffle: false
    property real progress: 0
    property string eqPreset: "Flat"
    property var eqPresets: ["Flat", "Bass Boost", "Vocal", "Rock", "Pop", "Electronic", "Hip-Hop", "Night"]
    property bool scanned: false

    readonly property int coverPx: 280
    readonly property var tabs: [
        { id: "albums", label: qsTr("Albums") },
        { id: "songs",  label: qsTr("Songs") },
        { id: "mixes",  label: qsTr("Mixes") },
        { id: "kept",   label: qsTr("Kept") },
        { id: "tone",   label: qsTr("Tone") }
    ]
    readonly property var shown: {
        if (page.tab === "songs")
            return page.tracks
        if (page.tab === "kept")
            return page.kept
        if (page.tab === "mixes")
            return page.mixes
        return page.albums
    }
    readonly property var currentAlbum: {
        if (page.albums.length && page.pick >= 0 && page.pick < page.albums.length)
            return page.albums[page.pick]
        return null
    }

    signal backRequested()

    function io() {
        return (Quickshell.env("HOME") || "") + "/.config/quickshell/media-io.py"
    }
    function artUrl(p) {
        if (!p || p.length === 0)
            return ""
        if (p.indexOf("file:") === 0 || p.indexOf("http") === 0)
            return p
        return "file://" + p
    }
    function initial(t) {
        var s = String(t || "").replace(/^[^A-Za-z0-9]+/, "")
        return s.length ? s.charAt(0).toUpperCase() : "M"
    }
    function fmtTime(sec) {
        var s = Math.max(0, Math.floor(Number(sec) || 0))
        var m = Math.floor(s / 60)
        var r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }
    function refresh() {
        listProc.running = false
        listProc.running = true
    }
    function playList(list, start) {
        var paths = []
        for (var i = 0; i < list.length; i++) {
            if (typeof list[i] === "string")
                paths.push(list[i])
            else if (list[i] && list[i].path)
                paths.push(list[i].path)
        }
        if (!paths.length)
            return
        playProc.command = ["python3", page.io(), "play", JSON.stringify({
            paths: paths,
            start: start || 0,
            shuffle: page.shuffle
        })]
        playProc.running = false
        playProc.running = true
    }
    function activate() {
        if (page.tab === "tone") {
            page.applyPreset(String(page.eqPresets[page.pick] || page.eqPreset))
            return
        }
        var row = page.shown[page.pick]
        if (!row)
            return
        if (page.tab === "albums" && row.paths)
            page.playList(row.paths, 0)
        else if (page.tab === "mixes" && row.tracks)
            page.playList(row.tracks, 0)
        else
            page.playList(page.shown, page.pick)
    }
    function applyPreset(name) {
        page.eqPreset = name
        eqSet.command = ["python3", page.io(), "eq-set", JSON.stringify({
            enabled: true,
            preset: name,
            applyPreset: true
        })]
        eqSet.running = false
        eqSet.running = true
    }
    function move(d) {
        var n = page.tab === "tone" ? page.eqPresets.length : page.shown.length
        if (n <= 0)
            return
        page.pick = Math.max(0, Math.min(n - 1, page.pick + d))
        if (page.tab === "albums" && flow.currentIndex !== page.pick)
            flow.currentIndex = page.pick
    }
    function setTab(id) {
        page.tab = id
        page.pick = 0
    }
    function tabStep(d) {
        var i = 0
        for (var k = 0; k < page.tabs.length; k++) {
            if (page.tabs[k].id === page.tab)
                i = k
        }
        i = Math.max(0, Math.min(page.tabs.length - 1, i + d))
        page.setTab(page.tabs[i].id)
    }

    Component.onCompleted: page.refresh()
    onVisibleChanged: if (visible) page.refresh()
    onTabChanged: page.pick = 0

    Process {
        id: listProc
        running: false
        command: ["python3", page.io()]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text))
                    page.tracks = j.tracks || []
                    page.albums = j.albums || []
                    page.kept = j.kept || []
                    page.mixes = j.mixes || []
                    page.albumCount = j.albumCount || page.albums.length
                    page.trackCount = j.trackCount || page.tracks.length
                    page.scanned = true
                } catch (e) {
                    page.scanned = true
                }
            }
        }
    }
    Process {
        id: playProc
        running: false
        command: ["python3", page.io(), "play", "{}"]
    }
    Process {
        id: eqSet
        running: false
        command: ["python3", page.io(), "eq-set", "{}"]
    }
    Timer {
        running: page.visible && MediaSource.lengthSec > 0
        interval: 500
        repeat: true
        onTriggered: {
            var L = MediaSource.lengthSec
            page.progress = L > 0 ? Math.max(0, Math.min(1, MediaSource.positionSec() / L)) : 0
        }
    }

    Keys.onPressed: function (e) {
        var k = e.key
        if (k === Qt.Key_Escape || k === Qt.Key_Backspace) {
            page.backRequested()
            e.accepted = true
        } else if (k === Qt.Key_Left) {
            page.move(-1)
            e.accepted = true
        } else if (k === Qt.Key_Right) {
            page.move(1)
            e.accepted = true
        } else if (k === Qt.Key_Up) {
            page.tabStep(-1)
            e.accepted = true
        } else if (k === Qt.Key_Down) {
            page.tabStep(1)
            e.accepted = true
        } else if (k === Qt.Key_Space) {
            MediaSource.togglePlaying()
            e.accepted = true
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            page.activate()
            e.accepted = true
        }
    }

    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("floor-art/music-doodle.jpg")
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        opacity: 0.22
    }
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.void_.r, Theme.void_.g, Theme.void_.b, 0.82)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Rectangle {
                Layout.preferredWidth: 196
                Layout.fillHeight: true
                color: Qt.rgba(0, 0, 0, 0.35)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.s6
                    spacing: Theme.s5

                    Text {
                        text: qsTr("Music")
                        color: Theme.magmaGold
                        font.family: Theme.fUiTitle
                        font.pixelSize: 30
                        font.weight: Theme.wTitle
                    }
                    Text {
                        visible: page.albumCount > 0
                        text: qsTr("%1 albums").arg(page.albumCount)
                        color: Theme.textDim
                        font.family: Theme.fNum
                        font.pixelSize: Theme.tCaption
                        font.features: ({ "tnum": 1 })
                    }
                    Repeater {
                        model: page.tabs
                        Text {
                            required property var modelData
                            text: modelData.label
                            color: page.tab === modelData.id ? Theme.magmaGold : Theme.icePlumGlow
                            opacity: page.tab === modelData.id ? 1 : 0.7
                            font.family: Theme.fUiTitle
                            font.pixelSize: Theme.tTitle
                            font.weight: Theme.wStrong
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: page.setTab(modelData.id) }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Text {
                        text: qsTr("Esc  ·  home")
                        color: Theme.icePlumGlow
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tHead
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: page.backRequested() }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.s4

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: page.tab === "albums"
                    Layout.minimumHeight: page.tab === "albums" ? 360 : 0
                    visible: page.tab === "albums"

                    PathView {
                        id: flow
                        anchors.fill: parent
                        model: page.albumCount
                        pathItemCount: 7
                        preferredHighlightBegin: 0.5
                        preferredHighlightEnd: 0.5
                        highlightRangeMode: PathView.StrictlyEnforceRange
                        flickDeceleration: 200
                        currentIndex: page.pick
                        onCurrentIndexChanged: {
                            if (currentIndex >= 0 && currentIndex !== page.pick)
                                page.pick = currentIndex
                        }
                        path: Path {
                            startX: 40
                            startY: 300
                            PathAttribute { name: "itemScale"; value: 0.58 }
                            PathAttribute { name: "itemZ"; value: 0 }
                            PathLine { x: 700; y: 300 }
                            PathAttribute { name: "itemScale"; value: 1 }
                            PathAttribute { name: "itemZ"; value: 80 }
                            PathLine { x: 1360; y: 300 }
                            PathAttribute { name: "itemScale"; value: 0.58 }
                            PathAttribute { name: "itemZ"; value: 0 }
                        }
                        delegate: Item {
                            required property int index
                            readonly property var modelData: (page.albums && page.albums[index]) ? page.albums[index] : ({})
                            width: page.coverPx
                            height: page.coverPx + 72
                            scale: PathView.itemScale
                            z: PathView.itemZ
                            readonly property string cover: page.artUrl(modelData.art || "")
                            Column {
                                anchors.fill: parent
                                spacing: Theme.s3
                                Item {
                                    width: page.coverPx
                                    height: page.coverPx
                                    Image {
                                        anchors.fill: parent
                                        source: cover
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        visible: cover.length > 0 && status === Image.Ready
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.r2
                                        color: Theme.elevated
                                        visible: cover.length === 0 || parent.children[0].status !== Image.Ready
                                        Text {
                                            anchors.centerIn: parent
                                            text: page.initial(modelData.title)
                                            color: Theme.icePlumGlow
                                            font.family: Theme.fUiTitle
                                            font.pixelSize: 48
                                            font.weight: Theme.wTitle
                                        }
                                    }
                                    CutRect {
                                        anchors.fill: parent
                                        radius: Theme.r2
                                        color: "transparent"
                                        borderWidth: PathView.isCurrentItem ? Theme.s2 : Theme.lookOutlineW
                                        borderColor: Theme.soften(Theme.magmaGold, PathView.isCurrentItem ? 0.95 : 0.35)
                                    }
                                }
                                Text {
                                    width: page.coverPx
                                    horizontalAlignment: Text.AlignHCenter
                                    visible: PathView.isCurrentItem
                                    text: String(modelData.title || "")
                                    color: Theme.magmaGold
                                    font.family: Theme.fUiTitle
                                    font.pixelSize: Theme.tDisplay
                                    font.weight: Theme.wTitle
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: page.coverPx
                                    horizontalAlignment: Text.AlignHCenter
                                    visible: PathView.isCurrentItem
                                    text: String(modelData.artist || "")
                                    color: Theme.icePlumGlow
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tTitle
                                    elide: Text.ElideRight
                                }
                            }
                            TapHandler {
                                onTapped: {
                                    if (PathView.isCurrentItem)
                                        page.activate()
                                    else
                                        flow.currentIndex = index
                                }
                            }
                        }
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: page.tab === "songs" || page.tab === "kept"
                    Layout.minimumHeight: (page.tab === "songs" || page.tab === "kept") ? 200 : 0
                    visible: page.tab === "songs" || page.tab === "kept"
                    clip: true
                    model: page.tab === "kept" ? page.kept : page.tracks
                    currentIndex: page.pick
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: ListView.view ? ListView.view.width : 0
                        height: 44
                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                            onHoveredChanged: if (hovered) page.pick = index
                        }
                        TapHandler {
                            onTapped: {
                                page.pick = index
                                page.activate()
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.r1
                            color: page.pick === index ? Theme.elevated : "transparent"
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.s4
                            anchors.rightMargin: Theme.s8
                            Text {
                                text: String(index + 1)
                                color: Theme.textDim
                                font.family: Theme.fNum
                                font.pixelSize: Theme.tHead
                                font.features: ({ "tnum": 1 })
                                Layout.preferredWidth: 36
                            }
                            Text {
                                Layout.fillWidth: true
                                text: String(modelData.title || "")
                                color: page.pick === index ? Theme.magmaGold : Theme.text
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tTitle
                                elide: Text.ElideRight
                            }
                            Text {
                                text: String(modelData.artist || "")
                                color: Theme.icePlumGlow
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tHead
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: page.tab === "mixes"
                    Layout.minimumHeight: page.tab === "mixes" ? 200 : 0
                    visible: page.tab === "mixes"
                    orientation: ListView.Horizontal
                    spacing: Theme.s6
                    clip: true
                    model: page.mixes
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: 160
                        height: 220
                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                            onHoveredChanged: if (hovered) page.pick = index
                        }
                        TapHandler {
                            onTapped: {
                                page.pick = index
                                page.activate()
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.s3
                            Rectangle {
                                width: 160
                                height: 160
                                radius: Theme.r2
                                color: Theme.elevated
                                Text {
                                    anchors.centerIn: parent
                                    text: qsTr("Mix")
                                    color: Theme.icePlumGlow
                                    font.family: Theme.fUiTitle
                                    font.pixelSize: Theme.tTitle
                                }
                            }
                            Text {
                                width: 160
                                horizontalAlignment: Text.AlignHCenter
                                text: String(modelData.name || modelData.title || qsTr("Mix"))
                                color: page.pick === index ? Theme.magmaGold : Theme.text
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tTitle
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    Layout.fillHeight: page.tab === "tone"
                    visible: page.tab === "tone"
                    padding: Theme.s8
                    spacing: Theme.s6
                    Repeater {
                        model: page.eqPresets
                        Text {
                            required property var modelData
                            required property int index
                            text: String(modelData)
                            color: page.eqPreset === modelData ? Theme.magmaGold : Theme.icePlumGlow
                            font.family: Theme.fUiTitle
                            font.pixelSize: Theme.tDisplay
                            font.weight: Theme.wStrong
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    page.pick = index
                                    page.applyPreset(String(modelData))
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 88
            color: Qt.rgba(0, 0, 0, 0.55)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.s6
                anchors.rightMargin: Theme.s6
                spacing: Theme.s6

                Item {
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 56
                    Image {
                        anchors.fill: parent
                        source: MediaSource.artUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        visible: MediaSource.artUrl.length > 0
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: MediaSource.artUrl.length === 0
                        color: Theme.elevated
                        radius: Theme.r1
                    }
                }
                ColumnLayout {
                    Layout.preferredWidth: 220
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        text: MediaSource.displayTitle.length ? MediaSource.displayTitle : qsTr("Nothing playing")
                        color: Theme.magmaGold
                        font.family: Theme.fUiTitle
                        font.pixelSize: Theme.tTitle
                        font.weight: Theme.wStrong
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: MediaSource.displaySubtitle
                        color: Theme.icePlumGlow
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tHead
                        elide: Text.ElideRight
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    clip: true
                    Row {
                        id: specRow
                        anchors.fill: parent
                        spacing: 1
                        visible: Beat.spectrum.length > 0
                        Repeater {
                            model: Beat.spectrum.length
                            Item {
                                required property int index
                                width: Math.max(2, Math.floor((specRow.width - Math.max(0, Beat.spectrum.length - 1)) / Math.max(1, Beat.spectrum.length)))
                                height: specRow.height
                                readonly property real mag: {
                                    var s = Beat.spectrum
                                    var v = (s && s.length > index) ? Number(s[index]) : 0
                                    return Math.max(0, Math.min(1, v))
                                }
                                readonly property color ink: {
                                    var t = Beat.spectrum.length > 1 ? index / (Beat.spectrum.length - 1) : 0
                                    return Qt.rgba(
                                        Theme.magmaGold.r * (1 - t) + Theme.icePlumGlow.r * t,
                                        Theme.magmaGold.g * (1 - t) + Theme.icePlumGlow.g * t,
                                        Theme.magmaGold.b * (1 - t) + Theme.icePlumGlow.b * t,
                                        1
                                    )
                                }
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.verticalCenter
                                    width: Math.max(2, parent.width - 1)
                                    height: Math.round(parent.mag * parent.height * 0.48)
                                    radius: 1
                                    color: parent.ink
                                }
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.verticalCenter
                                    width: Math.max(2, parent.width - 1)
                                    height: Math.round(parent.mag * parent.height * 0.48)
                                    radius: 1
                                    color: parent.ink
                                    opacity: 0.55
                                }
                            }
                        }
                    }
                }

                Row {
                    spacing: Theme.s5
                    Item {
                        width: 36
                        height: 40
                        enabled: MediaSource.canGoPrevious
                        opacity: enabled ? 1 : 0.35
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: MediaSource.previous() }
                        MediaGlyph {
                            anchors.centerIn: parent
                            name: "prev"
                            size: 20
                            color: Theme.icePlumGlow
                        }
                    }
                    Item {
                        width: 52
                        height: 40
                        enabled: MediaSource.canTogglePlaying
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: MediaSource.togglePlaying() }
                        CutRect {
                            anchors.fill: parent
                            radius: Theme.r2
                            color: Theme.soften(Theme.magmaGold, 0.28)
                            borderWidth: Theme.lookOutlineW
                            borderColor: Theme.soften(Theme.magmaGold, 0.90)
                        }
                        MediaGlyph {
                            anchors.centerIn: parent
                            name: MediaSource.playing ? "pause" : "play"
                            size: 20
                            color: Theme.magmaGold
                        }
                    }
                    Item {
                        width: 36
                        height: 40
                        enabled: MediaSource.canGoNext
                        opacity: enabled ? 1 : 0.35
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: MediaSource.next() }
                        MediaGlyph {
                            anchors.centerIn: parent
                            name: "next"
                            size: 20
                            color: Theme.icePlumGlow
                        }
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 180
                    spacing: 4
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 4
                        enabled: MediaSource.canSeek
                        Rectangle {
                            anchors.fill: parent
                            radius: 2
                            color: Theme.elevated
                            Rectangle {
                                width: Math.round(parent.width * page.progress)
                                height: parent.height
                                radius: 2
                                color: Theme.magmaGold
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: MediaSource.canSeek
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function (mouse) {
                                MediaSource.seekFraction(mouse.x / Math.max(1, width))
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: page.fmtTime(MediaSource.positionSec())
                            color: Theme.textDim
                            font.family: Theme.fNum
                            font.pixelSize: Theme.tCaption
                            font.features: ({ "tnum": 1 })
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: page.fmtTime(MediaSource.lengthSec)
                            color: Theme.textDim
                            font.family: Theme.fNum
                            font.pixelSize: Theme.tCaption
                            font.features: ({ "tnum": 1 })
                        }
                    }
                }
            }
        }
    }
}
