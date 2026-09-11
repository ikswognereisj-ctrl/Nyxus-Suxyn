pragma ComponentBehavior: Bound
// Nyxus Suxyn — MEDIA app window.
// Same layout as GTK nyxus_media.py (rail, shelf, now-bar). Widget glass.
// MediaCrest.qml (bar popup) is not this file and is not edited here.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

AppWindow {
    id: win

    titleText: qsTr("Media")
    iconName: "nyxus-media"
    subtitleText: win.trackCount
                  ? qsTr("%1 songs").arg(win.trackCount)
                  : qsTr("Library")
    open: Bus.mediaOpen
    onDismissed: Bus.mediaOpen = false
    implicitWidth: 1180
    implicitHeight: 760
    minimumSize: Qt.size(960, 640)

    property string page: "home"
    property var tracks: []
    property var albums: []
    property var kept: []
    property var genres: []
    property var mixes: []
    property int albumCount: 0
    property int trackCount: 0
    property int genreCount: 0
    property string query: ""
    property real progress: 0
    property bool lyricsOpen: false
    property bool eqEnabled: true
    property string eqPreset: "Flat"
    property var eqBands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property var eqPresets: ["Flat", "Bass Boost", "Bass Cut", "Treble Boost", "Vocal", "Acoustic", "Rock", "Pop", "Jazz", "Classical", "Electronic", "Dance", "Hip-Hop", "Loudness", "Night"]
    property bool eqApplied: false
    property bool autoMixes: SettingsStore.boolValue("app_media_auto_mixes", true)
    property bool shuffle: SettingsStore.boolValue("app_media_shuffle", false)
    property var queue: []
    property var care: ({ total: 0, kept: 0, missingCount: 0, dupGroups: 0, missing: [], dups: [] })

    readonly property color ice: Theme.tokenAccentPrimary
    readonly property color iceHair: Theme.tokenAccentHairline
    readonly property int railW: 268

    readonly property var nav: [
        { id: "now",    group: qsTr("Playing"), label: qsTr("Now Playing") },
        { id: "home",   group: qsTr("Playing"), label: qsTr("Home") },
        { id: "songs",  group: qsTr("Library"), label: qsTr("Songs") },
        { id: "albums", group: qsTr("Library"), label: qsTr("Albums") },
        { id: "kept",   group: qsTr("Library"), label: qsTr("Kept") },
        { id: "genres", group: qsTr("Library"), label: qsTr("Genres") },
        { id: "mixes",  group: qsTr("Library"), label: qsTr("Mixes") },
        { id: "queue",  group: qsTr("Library"), label: qsTr("Queue") },
        { id: "tone",   group: qsTr("Sound"),   label: qsTr("Tone") },
        { id: "care",   group: qsTr("Sound"),   label: qsTr("Care") }
    ]

    readonly property var eqLabels: ["30", "60", "120", "240", "470", "950", "1.9k", "3.8k", "7.5k", "15k"]

    readonly property var shownTracks: {
        var src = (win.page === "kept") ? win.kept : win.tracks;
        var q = win.query.trim().toLowerCase();
        if (!q.length) return src;
        var out = [];
        for (var i = 0; i < src.length; i++) {
            var t = src[i];
            if ((t.title + " " + t.artist + " " + t.album).toLowerCase().indexOf(q) >= 0)
                out.push(t);
        }
        return out;
    }
    readonly property var shownAlbums: {
        var q = win.query.trim().toLowerCase();
        if (!q.length) return win.albums;
        var out = [];
        for (var i = 0; i < win.albums.length; i++) {
            var a = win.albums[i];
            if ((a.title + " " + a.artist).toLowerCase().indexOf(q) >= 0)
                out.push(a);
        }
        return out;
    }

    function io() { return (Quickshell.env("HOME") || "") + "/.config/quickshell/media-io.py"; }
    function refresh() { listProc.running = false; listProc.running = true; win.refreshCare(); }
    function refreshCare() { careProc.running = false; careProc.running = true; }
    function loadEq() { eqGet.running = false; eqGet.running = true; }
    function writeEq(applyPreset) {
        var payload = JSON.stringify({
            enabled: win.eqEnabled,
            preset: win.eqPreset,
            bands: win.eqBands,
            applyPreset: !!applyPreset
        });
        eqSet.command = ["python3", win.io(), "eq-set", payload];
        eqSet.running = false;
        eqSet.running = true;
    }
    function playList(list, start) {
        var paths = [];
        var rows = [];
        for (var i = 0; i < list.length; i++) {
            var p = list[i].path || list[i];
            paths.push(p);
            rows.push({
                path: p,
                title: list[i].title || "",
                artist: list[i].artist || ""
            });
        }
        if (!paths.length) return;
        win.queue = rows;
        playProc.command = ["python3", win.io(), "play", JSON.stringify({
            paths: paths, start: start || 0, shuffle: win.shuffle
        })];
        playProc.running = false;
        playProc.running = true;
    }
    function playTracksFrom(i) {
        win.playList(win.shownTracks, i);
    }
    function setAutoMixes(on) {
        win.autoMixes = on;
        SettingsStore.setValue("app_media_auto_mixes", on);
        autoProc.command = ["python3", win.io(), "auto", on ? "on" : "off"];
        autoProc.running = false;
        autoProc.running = true;
    }
    function applyPreset(name) {
        win.eqPreset = name;
        writeEq(true);
    }
    function setBand(i, db) {
        var next = win.eqBands.slice();
        next[i] = Math.max(-12, Math.min(12, db));
        win.eqBands = next;
        win.eqPreset = "Custom";
        eqDebounce.restart();
    }
    function toggle() {
        if (MediaSource.canTogglePlaying && MediaSource.player)
            MediaSource.player.togglePlaying();
    }
    function next() {
        if (MediaSource.canGoNext && MediaSource.player) MediaSource.player.next();
    }
    function prev() {
        if (MediaSource.canGoPrevious && MediaSource.player) MediaSource.player.previous();
    }
    function fmtTime(sec) {
        var s = Math.max(0, Math.floor(Number(sec) || 0));
        var m = Math.floor(s / 60);
        var r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }
    function artUrl(p) {
        if (!p || p.length === 0) return "";
        if (p.indexOf("file:") === 0 || p.indexOf("http") === 0) return p;
        return "file://" + p;
    }

    onOpenChanged: if (open) { refresh(); loadEq(); }
    onVisibleChanged: if (visible) { refresh(); loadEq(); }

    Timer {
        running: win.visible && MediaSource.lengthSec > 0
        interval: 500; repeat: true
        onTriggered: {
            var L = MediaSource.lengthSec;
            win.progress = L > 0 ? Math.max(0, Math.min(1, MediaSource.positionSec() / L)) : 0;
        }
    }

    IpcHandler {
        target: "media"
        function ready(): string { return "ready"; }
        function engage(): string { Bus.mediaOpen = true; win.refresh(); win.loadEq(); return "media"; }
        function at(key: string): string {
            Bus.mediaOpen = true;
            if (key && key.length)
                win.page = key;
            win.refresh();
            win.loadEq();
            return key || "media";
        }
        function dismiss(): string { Bus.mediaOpen = false; return "hidden"; }
    }

    Process {
        id: listProc
        running: false
        command: ["python3", win.io()]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.tracks = j.tracks || [];
                    win.albums = j.albums || [];
                    win.kept = j.kept || [];
                    win.genres = j.genres || [];
                    win.mixes = j.mixes || [];
                    win.albumCount = j.albumCount || 0;
                    win.trackCount = j.trackCount || win.tracks.length;
                    win.genreCount = j.genreCount || win.genres.length;
                    if (j.autoMixes !== undefined)
                        win.autoMixes = !!j.autoMixes;
                } catch (e) { }
            }
        }
    }

    Process {
        id: eqGet
        running: false
        command: ["python3", win.io(), "eq-get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.eqEnabled = j.enabled !== false;
                    win.eqPreset = j.preset || "Flat";
                    if (j.bands && j.bands.length === 10)
                        win.eqBands = j.bands;
                    if (j.presets && j.presets.length)
                        win.eqPresets = j.presets;
                } catch (e) { }
            }
        }
    }

    Process {
        id: eqSet
        running: false
        command: ["python3", win.io(), "eq-get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.eqApplied = j.applied === true;
                    if (j.bands && j.bands.length === 10)
                        win.eqBands = j.bands;
                    if (j.preset)
                        win.eqPreset = j.preset;
                } catch (e) { }
            }
        }
    }

    Timer {
        id: eqDebounce
        interval: 220
        onTriggered: win.writeEq(false)
    }

    Process {
        id: playProc
        running: false
        command: ["python3", win.io(), "play", "{}"]
    }
    Process {
        id: careProc
        running: false
        command: ["python3", win.io(), "care"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { win.care = JSON.parse(String(this.text)); } catch (e) { }
            }
        }
    }
    Process {
        id: autoProc
        running: false
        command: ["python3", win.io(), "auto", "on"]
        stdout: StdioCollector {
            onStreamFinished: win.refresh()
        }
    }

    component NavRow: Item {
        id: nr
        property string nid: ""
        property string label: ""
        Layout.fillWidth: true
        Layout.preferredHeight: 42
        height: 42
        CutRect {
            visible: win.page === nr.nid
            anchors.fill: parent
            radius: Theme.r1
            color: Theme.elevated
            borderWidth: 1
            borderColor: Theme.soften(Theme.paintLayers.glacier[4], 0.85)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.s5
            text: nr.label
            color: win.page === nr.nid ? Theme.text : Theme.textMuted
            font.family: Theme.fUi
            font.pixelSize: 17
            font.weight: win.page === nr.nid ? Theme.wStrong : Font.Normal
            elide: Text.ElideRight
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: win.page = nr.nid }
    }

    component CoverTile: Item {
        id: tile
        property string art: ""
        property string title: ""
        property string sub: ""
        property var paths: []
        width: 168
        height: 214
        scale: covHov.hovered ? 1.03 : 1.0
        Behavior on scale { NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutQuint } }
        Column {
            anchors.fill: parent
            spacing: 6
            Item {
                width: 168; height: 168
                clip: true
                Image {
                    anchors.fill: parent
                    source: win.artUrl(tile.art)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 168
                    sourceSize.height: 168
                    visible: tile.art.length > 0
                }
                Rectangle {
                    anchors.fill: parent
                    color: tile.art.length ? "transparent" : Theme.elevated
                    radius: Theme.r2
                    border.width: 1
                    border.color: Theme.soften(Theme.paintLayers.glacier[4], 0.45)
                }
            }
            Text {
                width: 168
                text: tile.title
                color: Theme.text
                font.family: Theme.fUi
                font.pixelSize: Theme.tBody
                font.weight: Theme.wStrong
                elide: Text.ElideRight
            }
            Text {
                width: 168
                text: tile.sub
                color: Theme.textMuted
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                elide: Text.ElideRight
                clip: true
            }
        }
        HoverHandler { id: covHov; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: {
                if (tile.paths && tile.paths.length)
                    win.playList(tile.paths, 0);
            }
        }
    }

    component GhostBtn: Item {
        id: gb
        property string label: ""
        signal tapped()
        implicitWidth: lab.implicitWidth + Theme.s8
        implicitHeight: 40
        width: implicitWidth; height: 40
        Rectangle {
            anchors.fill: parent
            radius: Theme.r1
            color: "transparent"
            border.width: 1
            border.color: Theme.soften(Theme.paintLayers.glacier[4], 0.55)
        }
        Text {
            id: lab
            anchors.centerIn: parent
            text: gb.label
            color: Theme.text
            font.family: Theme.fUi
            font.pixelSize: Theme.tBody
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: gb.tapped() }
    }

    component EqBand: Item {
        id: band
        property int bandIndex: 0
        property string hz: ""
        property real db: 0
        width: 56
        height: 168
        function fromY(py) {
            var t = 1 - Math.max(0, Math.min(1, py / Math.max(1, lane.height)));
            win.setBand(band.bandIndex, t * 24 - 12);
        }
        Column {
            anchors.fill: parent
            spacing: 4
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Math.abs(band.db) < 0.25 ? "0" : ((band.db > 0 ? "+" : "") + Math.round(band.db))
                color: Theme.text
                font.family: Theme.fNum
                font.pixelSize: Theme.tCaption
                font.features: ({ "tnum": 1 })
            }
            Item {
                id: lane
                width: parent.width
                height: 120
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 10
                    height: parent.height
                    radius: 5
                    color: Theme.shelfDeep
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 10
                        radius: 5
                        color: Theme.tokenAccentPrimary
                        height: Math.max(6, Math.abs(band.db) / 12 * parent.height / 2)
                        y: band.db >= 0
                           ? parent.height / 2 - height
                           : parent.height / 2
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height / 2 - 1
                        width: 10
                        height: 2
                        color: Theme.soften(Theme.paintLayers.glacier[4], 0.7)
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    onPressed: function (m) { band.fromY(m.y); }
                    onPositionChanged: function (m) { if (pressed) band.fromY(m.y); }
                }
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: band.hz
                color: Theme.textMuted
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.preferredWidth: win.railW
            Layout.maximumWidth: win.railW
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.s5
                spacing: Theme.s2
                Text {
                    text: qsTr("MEDIA")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    font.weight: Theme.wStrong
                    font.letterSpacing: Theme.trackMicro
                }
                Text {
                    Layout.fillWidth: true
                    text: win.trackCount ? qsTr("%1 songs").arg(win.trackCount) : qsTr("Library")
                    color: Theme.text
                    font.family: Theme.fUiTitle
                    font.pixelSize: Theme.tDisplay
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    clip: true
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: Theme.r1
                    color: Theme.soften(Theme.void_, 0.62)
                    border.width: 1
                    border.color: Theme.soften(win.iceHair, 0.45)
                    TextInput {
                        id: qField
                        anchors.fill: parent
                        anchors.margins: 10
                        color: Theme.text
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tBody
                        clip: true
                        onTextChanged: win.query = text
                    }
                    Text {
                        anchors.fill: qField
                        visible: qField.text.length === 0 && !qField.activeFocus
                        text: qsTr("Search")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tBody
                        enabled: false
                    }
                }
                Repeater {
                    model: win.nav
                    delegate: ColumnLayout {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            visible: index === 0 || win.nav[index].group !== win.nav[index - 1].group
                            Layout.fillWidth: true
                            text: modelData.group
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            font.weight: Theme.wStrong
                            font.letterSpacing: Theme.trackMicro
                            topPadding: Theme.s4
                        }
                        NavRow { nid: modelData.id; label: modelData.label }
                    }
                }
                Item { Layout.fillHeight: true }
                Text {
                    Layout.fillWidth: true
                    text: TapeState.armed ? qsTr("On — starts with the next song")
                                          : qsTr("Tape is off")
                    color: TapeState.armed ? Theme.text : Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tBody
                    wrapMode: Text.WordWrap
                }
                GhostBtn {
                    Layout.fillWidth: true
                    label: qsTr("Folders…")
                    onTapped: Quickshell.execDetached(["xdg-open", (Quickshell.env("HOME") || "") + "/Music"])
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Theme.soften(win.iceHair, 0.45)
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Flickable {
                id: pageFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: pageBox.height
                boundsBehavior: Flickable.StopAtBounds

                Item {
                    id: pageBox
                    width: pageFlick.width
                    height: pageInner.height + Theme.s8
                    Column {
                        id: pageInner
                        x: Theme.s7
                        y: Theme.s6
                        width: pageBox.width - Theme.s7 * 2
                        spacing: Theme.s6

                        // HOME / NOW HERO
                        Row {
                            visible: win.page === "home" || win.page === "now"
                            width: parent.width
                            spacing: Theme.s7
                            Item {
                                width: 280; height: 280
                                Image {
                                    anchors.fill: parent
                                    source: MediaSource.artUrl
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize.width: 280
                                    sourceSize.height: 280
                                    visible: MediaSource.artUrl.length > 0
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    radius: Theme.r2
                                    border.width: 1
                                    border.color: Theme.soften(win.iceHair, 0.45)
                                }
                            }
                            Column {
                                width: Math.max(240, parent.width - 280 - Theme.s7)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.s3
                                Text {
                                    text: qsTr("NOW PLAYING")
                                    color: Theme.gold
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tMicro
                                    font.weight: Theme.wStrong
                                    font.letterSpacing: Theme.trackMicro
                                }
                                Text {
                                    width: parent.width
                                    text: MediaSource.displayTitle.length ? MediaSource.displayTitle : qsTr("Nothing playing")
                                    color: Theme.text
                                    font.family: Theme.fUiTitle
                                    font.pixelSize: 28
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: MediaSource.displaySubtitle
                                    color: Theme.textMuted
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tHead
                                    elide: Text.ElideRight
                                }
                                Text {
                                    visible: MediaSource.album.length > 0
                                    width: parent.width
                                    text: MediaSource.album
                                    color: Theme.textDim
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tBody
                                    elide: Text.ElideRight
                                }
                                Row {
                                    spacing: Theme.s3
                                    topPadding: Theme.s3
                                    GhostBtn { label: MediaSource.playing ? qsTr("Pause") : qsTr("Play"); onTapped: win.toggle() }
                                    GhostBtn { label: qsTr("Next"); onTapped: win.next() }
                                    GhostBtn { label: qsTr("Open album"); onTapped: win.page = "albums" }
                                }
                                Column {
                                    visible: win.page === "now" && MediaSource.lyricLines && MediaSource.lyricLines.length
                                    width: parent.width
                                    topPadding: Theme.s5
                                    spacing: Theme.s2
                                    Repeater {
                                        model: MediaSource.lyricLines
                                        Text {
                                            required property var modelData
                                            required property int index
                                            width: parent.width
                                            text: String(modelData[2] || "")
                                            color: index === MediaSource.lyricLineIdx ? Theme.text : Theme.textDim
                                            font.family: Theme.fUi
                                            font.pixelSize: Theme.tBody
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            visible: (win.page === "home" || win.page === "kept") && win.kept.length > 0
                            width: parent.width
                            spacing: Theme.s3
                            Text {
                                text: qsTr("FROM THE TAPE")
                                color: Theme.textDim
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tMicro
                                font.weight: Theme.wStrong
                                font.letterSpacing: Theme.trackMicro
                            }
                            Text {
                                text: qsTr("Fresh Keeps")
                                color: Theme.text
                                font.family: Theme.fScript
                                font.pixelSize: Theme.tTitle
                            }
                            Flow {
                                width: parent.width
                                spacing: Theme.s5
                                Repeater {
                                    model: win.page === "home" ? win.kept.slice(0, 8) : win.kept
                                    CoverTile {
                                        required property var modelData
                                        art: modelData.art
                                        title: modelData.title
                                        sub: modelData.artist
                                        paths: modelData.paths || [modelData.path]
                                    }
                                }
                            }
                        }

                        Column {
                            visible: win.page === "home" || win.page === "albums"
                            width: parent.width
                            spacing: Theme.s3
                            Row {
                                width: parent.width
                                Text {
                                    text: qsTr("ALBUMS")
                                    color: Theme.textDim
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tMicro
                                    font.weight: Theme.wStrong
                                    font.letterSpacing: Theme.trackMicro
                                }
                            }
                            Row {
                                width: parent.width
                                Text {
                                    text: qsTr("The Shelf")
                                    color: Theme.text
                                    font.family: Theme.fScript
                                    font.pixelSize: Theme.tTitle
                                }
                                Item { width: 24; height: 1 }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: qsTr("%1 ALBUMS").arg(win.albumCount)
                                    color: Theme.textDim
                                    font.family: Theme.fNum
                                    font.pixelSize: Theme.tMicro
                                }
                            }
                            Flow {
                                width: parent.width
                                spacing: Theme.s5
                                Repeater {
                                    model: win.page === "home" ? win.albums.slice(0, 8) : win.shownAlbums
                                    CoverTile {
                                        required property var modelData
                                        art: modelData.art
                                        title: modelData.title
                                        sub: modelData.artist
                                        paths: modelData.paths || [modelData.path]
                                    }
                                }
                            }
                        }

                        Column {
                            visible: win.page === "songs"
                            width: parent.width
                            spacing: Theme.s2
                            Text {
                                text: qsTr("All Songs")
                                color: Theme.text
                                font.family: Theme.fScript
                                font.pixelSize: Theme.tTitle
                            }
                            Text {
                                text: qsTr("%1 · A–Z").arg(win.shownTracks.length)
                                color: Theme.textDim
                                font.family: Theme.fNum
                                font.pixelSize: Theme.tCaption
                                font.features: ({ "tnum": 1 })
                            }
                            Repeater {
                                model: win.shownTracks
                                Item {
                                    required property var modelData
                                    required property int index
                                    width: pageInner.width
                                    height: 44
                                    Row {
                                        anchors.fill: parent
                                        spacing: Theme.s4
                                        Image {
                                            width: 40; height: 40
                                            source: win.artUrl(modelData.art)
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            sourceSize.width: 40
                                            sourceSize.height: 40
                                        }
                                        Text {
                                            width: parent.width - 280
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.title
                                            color: Theme.text
                                            font.family: Theme.fUi
                                            font.pixelSize: Theme.tBody
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            width: 160
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.artist
                                            color: Theme.textMuted
                                            font.family: Theme.fUi
                                            font.pixelSize: Theme.tCaption
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: win.fmtTime(modelData.duration)
                                            color: Theme.textDim
                                            font.family: Theme.fNum
                                            font.pixelSize: Theme.tCaption
                                        }
                                    }
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: win.playTracksFrom(index) }
                                }
                            }
                        }

                        Column {
                            visible: win.page === "tone"
                            width: parent.width
                            spacing: Theme.s5
                            Text {
                                text: qsTr("Tone")
                                color: Theme.text
                                font.family: Theme.fScript
                                font.pixelSize: Theme.tTitle
                            }
                            Row {
                                spacing: Theme.s4
                                GhostBtn {
                                    label: win.eqEnabled ? qsTr("EQ on") : qsTr("EQ off")
                                    onTapped: { win.eqEnabled = !win.eqEnabled; win.writeEq(false); }
                                }
                                GhostBtn {
                                    label: qsTr("Reset")
                                    onTapped: win.applyPreset("Flat")
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: win.eqApplied ? qsTr("Live on this output") : qsTr("Saved — loading onto the output…")
                                    color: win.eqApplied ? Theme.textMuted : Theme.textDim
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tCaption
                                }
                            }
                            Text {
                                text: qsTr("Presets")
                                color: Theme.textDim
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                                font.weight: Theme.wStrong
                                font.letterSpacing: Theme.trackMicro
                            }
                            Flow {
                                width: parent.width
                                spacing: Theme.s3
                                Repeater {
                                    model: win.eqPresets
                                    GhostBtn {
                                        required property string modelData
                                        label: modelData
                                        onTapped: win.applyPreset(modelData)
                                    }
                                }
                            }
                            Text {
                                visible: win.eqPreset.length > 0
                                text: qsTr("Active · %1").arg(win.eqPreset)
                                color: Theme.textMuted
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                            }
                            Text {
                                text: qsTr("Manual — drag a band. Pale glacier fill, same as the widget meters.")
                                color: Theme.textMuted
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tBody
                            }
                            Row {
                                spacing: 8
                                Repeater {
                                    model: win.eqLabels
                                    EqBand {
                                        required property string modelData
                                        required property int index
                                        bandIndex: index
                                        hz: modelData
                                        db: Number(win.eqBands[index])
                                    }
                                }
                            }
                        }

                        Column {
                            visible: win.page === "genres"
                            width: parent.width
                            spacing: Theme.s4
                            Text {
                                text: qsTr("Genres")
                                color: Theme.text
                                font.family: Theme.fScript
                                font.pixelSize: Theme.tTitle
                            }
                            Text {
                                width: parent.width
                                text: qsTr("%1 groups · A–Z. Files without a genre tag sit in Untagged.").arg(win.genreCount)
                                color: Theme.textDim
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                                wrapMode: Text.WordWrap
                            }
                            Repeater {
                                model: win.genres
                                Column {
                                    required property var modelData
                                    width: pageInner.width
                                    spacing: Theme.s2
                                    Row {
                                        spacing: Theme.s4
                                        Text {
                                            text: modelData.name
                                            color: Theme.text
                                            font.family: Theme.fUi
                                            font.pixelSize: Theme.tHead
                                            font.weight: Theme.wStrong
                                            elide: Text.ElideRight
                                            width: Math.min(360, pageInner.width - 160)
                                            clip: true
                                        }
                                        Text {
                                            text: qsTr("%1 songs").arg(modelData.count)
                                            color: Theme.textDim
                                            font.family: Theme.fNum
                                            font.pixelSize: Theme.tCaption
                                            font.features: ({ "tnum": 1 })
                                        }
                                        GhostBtn {
                                            label: qsTr("Play")
                                            onTapped: win.playList(modelData.tracks, 0)
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            visible: win.page === "mixes"
                            width: parent.width
                            spacing: Theme.s4
                            Text {
                                text: qsTr("Mixes")
                                color: Theme.text
                                font.family: Theme.fScript
                                font.pixelSize: Theme.tTitle
                            }
                            Row {
                                spacing: Theme.s4
                                GhostBtn {
                                    label: win.autoMixes ? qsTr("Auto mixes on") : qsTr("Auto mixes off")
                                    onTapped: win.setAutoMixes(!win.autoMixes)
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: win.autoMixes
                                          ? qsTr("Builds Recently Added, Kept, A–Z, and genre mixes from this library.")
                                          : qsTr("Only mixes you saved.")
                                    color: Theme.textMuted
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tCaption
                                    width: 420
                                    wrapMode: Text.WordWrap
                                }
                            }
                            Repeater {
                                model: win.mixes
                                Item {
                                    required property var modelData
                                    width: pageInner.width
                                    height: 48
                                    Row {
                                        anchors.fill: parent
                                        spacing: Theme.s4
                                        Text {
                                            width: Math.min(420, parent.width - 180)
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.name
                                            color: Theme.text
                                            font.family: Theme.fUi
                                            font.pixelSize: Theme.tBody
                                            elide: Text.ElideRight
                                            clip: true
                                        }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: qsTr("%1 songs").arg(modelData.count)
                                            color: Theme.textDim
                                            font.family: Theme.fNum
                                            font.pixelSize: Theme.tCaption
                                            font.features: ({ "tnum": 1 })
                                        }
                                        GhostBtn {
                                            label: qsTr("Play")
                                            onTapped: win.playList(modelData.paths, 0)
                                        }
                                    }
                                }
                            }
                        }

                        Column {
                            visible: win.page === "queue"
                            width: parent.width
                            spacing: Theme.s3
                            Text {
                                width: parent.width
                                text: win.queue.length
                                      ? qsTr("%1 in the queue").arg(win.queue.length)
                                      : qsTr("Play a song, album, genre, or mix and it lands here.")
                                color: Theme.textMuted
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                            }
                            Repeater {
                                model: win.queue
                                delegate: Item {
                                    required property var modelData
                                    required property int index
                                    width: parent.width
                                    height: 36
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 80
                                        text: (modelData.title || modelData.path) + (modelData.artist ? " — " + modelData.artist : "")
                                        color: Theme.text
                                        font.family: Theme.fUi
                                        font.pixelSize: Theme.tBody
                                        elide: Text.ElideRight
                                    }
                                    GhostBtn {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        label: qsTr("Play")
                                        onTapped: win.playList(win.queue, index)
                                    }
                                }
                            }
                        }
                        Column {
                            visible: win.page === "care"
                            width: parent.width
                            spacing: Theme.s4
                            Text {
                                width: parent.width
                                text: qsTr("%1 songs · %2 kept · %3 missing files · %4 duplicate titles")
                                      .arg(win.care.total || 0)
                                      .arg(win.care.kept || 0)
                                      .arg(win.care.missingCount || 0)
                                      .arg(win.care.dupGroups || 0)
                                color: Theme.text
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tBody
                                wrapMode: Text.WordWrap
                            }
                            GhostBtn { label: qsTr("Scan again"); onTapped: win.refreshCare() }
                            Repeater {
                                model: win.care.missing || []
                                delegate: Text {
                                    required property var modelData
                                    width: parent.width
                                    text: qsTr("Missing · %1").arg(modelData.title || modelData.path)
                                    color: Theme.paintLayers.magma[5]
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tCaption
                                    elide: Text.ElideRight
                                }
                            }
                            Repeater {
                                model: win.care.dups || []
                                delegate: Text {
                                    required property var modelData
                                    width: parent.width
                                    text: qsTr("%1 × %2 — %3").arg(modelData.n).arg(modelData.title).arg(modelData.artist)
                                    color: Theme.textMuted
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tCaption
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 118
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.soften(win.iceHair, 0.45)
                }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.s4
                    spacing: Theme.s2
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.s4
                        Image {
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 44
                            source: MediaSource.artUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 44
                            sourceSize.height: 44
                            visible: MediaSource.artUrl.length > 0
                        }
                        ColumnLayout {
                            Layout.preferredWidth: 200
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: MediaSource.displayTitle.length ? MediaSource.displayTitle : qsTr("Nothing playing")
                                color: Theme.text
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tBody
                                font.weight: Theme.wStrong
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: MediaSource.displaySubtitle + (MediaSource.album.length ? " — " + MediaSource.album : "")
                                color: Theme.textMuted
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                                elide: Text.ElideRight
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Item {
                            implicitWidth: 22; implicitHeight: 22
                            MediaGlyph { anchors.centerIn: parent; name: "prev"; size: 16; color: Theme.text }
                            TapHandler { onTapped: win.prev() }
                        }
                        Item {
                            implicitWidth: 32; implicitHeight: 32
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Theme.soften(win.ice, MediaSource.playing ? 0.82 : 0.22)
                            }
                            MediaGlyph {
                                anchors.centerIn: parent
                                name: MediaSource.playing ? "pause" : "play"
                                size: 16
                                color: MediaSource.playing ? Theme.void_ : Theme.text
                            }
                            TapHandler { onTapped: win.toggle() }
                        }
                        Item {
                            implicitWidth: 22; implicitHeight: 22
                            MediaGlyph { anchors.centerIn: parent; name: "next"; size: 16; color: Theme.text }
                            TapHandler { onTapped: win.next() }
                        }
                        GhostBtn {
                            label: win.shuffle ? qsTr("Shuffle on") : qsTr("Shuffle")
                            onTapped: {
                                win.shuffle = !win.shuffle;
                                SettingsStore.setValue("app_media_shuffle", win.shuffle);
                            }
                        }
                        GhostBtn { label: qsTr("Lyrics"); onTapped: win.page = "now" }
                        Text {
                            text: win.fmtTime(MediaSource.positionSec())
                            color: Theme.textDim
                            font.family: Theme.fNum
                            font.pixelSize: Theme.tMicro
                        }
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 12
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 8
                                radius: 4
                                color: Theme.shelfDeep
                                Rectangle {
                                    width: parent.width * win.progress
                                    height: parent.height
                                    radius: 4
                                    color: win.ice
                                }
                            }
                        }
                        Text {
                            text: win.fmtTime(MediaSource.lengthSec)
                            color: Theme.textDim
                            font.family: Theme.fNum
                            font.pixelSize: Theme.tMicro
                        }
                    }
                }
            }
        }
    }
}
