pragma ComponentBehavior: Bound
// Nyxus Suxyn — FILES. GTK layout (Places + list), widget glass.
// Does not touch tape, Media, or the bar popup.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

AppWindow {
    id: win

    titleText: qsTr("Files")
    iconName: "nyxus-files"
    subtitleText: win.crumb
    open: Bus.filesOpen
    onDismissed: Bus.filesOpen = false
    implicitWidth: 1180
    implicitHeight: 760
    minimumSize: Qt.size(900, 560)

    property string currentPath: ""
    property string crumb: qsTr("Home")
    property var places: []
    property var entries: []
    property string filter: ""
    property var history: []
    property int histIndex: -1
    property int folderCount: 0
    property int fileCount: 0
    property string freeText: ""
    property bool listing: false

    readonly property color ice: Theme.tokenAccentPrimary
    readonly property color iceHair: Theme.tokenAccentHairline
    readonly property string homePath: Quickshell.env("HOME") || "/"

    readonly property var shown: {
        var q = win.filter.trim().toLowerCase();
        if (!q.length) return win.entries;
        var out = [];
        for (var i = 0; i < win.entries.length; i++) {
            if (String(win.entries[i].name).toLowerCase().indexOf(q) >= 0)
                out.push(win.entries[i]);
        }
        return out;
    }

    function io() { return (Quickshell.env("HOME") || "") + "/.config/quickshell/files-io.py"; }

    function go(path, record) {
        if (!path || path.length === 0)
            path = win.homePath;
        win.listing = true;
        listProc.command = ["python3", win.io(), "list", path];
        listProc.running = false;
        listProc.running = true;
        if (record !== false) {
            var h = win.history.slice(0, win.histIndex + 1);
            h.push(path);
            if (h.length > 40) h = h.slice(h.length - 40);
            win.history = h;
            win.histIndex = h.length - 1;
        }
    }

    function back() {
        if (win.histIndex <= 0) return;
        win.histIndex -= 1;
        win.go(win.history[win.histIndex], false);
    }
    function forward() {
        if (win.histIndex >= win.history.length - 1) return;
        win.histIndex += 1;
        win.go(win.history[win.histIndex], false);
    }
    function up() {
        if (win.currentPath === "trash:///") {
            win.go(win.homePath);
            return;
        }
        var p = win.currentPath;
        if (!p || p === "/") return;
        var i = p.lastIndexOf("/");
        win.go(i <= 0 ? "/" : p.substring(0, i));
    }
    function openEntry(ent) {
        if (!ent) return;
        if (ent.dir)
            win.go(ent.path);
        else {
            openProc.command = ["python3", win.io(), "open", ent.path];
            openProc.running = false;
            openProc.running = true;
        }
    }
    function loadPlaces() {
        placeProc.running = false;
        placeProc.running = true;
    }

    onOpenChanged: if (open) {
        loadPlaces();
        if (win.currentPath.length === 0)
            win.go(win.homePath);
    }
    onVisibleChanged: if (visible && win.currentPath.length === 0)
        win.go(win.homePath)

    IpcHandler {
        target: "files"
        function ready(): string { return "ready"; }
        function engage(): string {
            Bus.filesOpen = true;
            if (win.currentPath.length === 0)
                win.go(win.homePath);
            return "files";
        }
        function at(path: string): string {
            Bus.filesOpen = true;
            win.go(path);
            return path;
        }
        function dismiss(): string { Bus.filesOpen = false; return "hidden"; }
    }

    Process {
        id: placeProc
        running: false
        command: ["python3", win.io(), "places"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.places = j.places || [];
                } catch (e) { }
            }
        }
    }
    Process {
        id: listProc
        running: false
        command: ["python3", win.io(), "list", win.homePath]
        stdout: StdioCollector {
            onStreamFinished: {
                win.listing = false;
                try {
                    var j = JSON.parse(String(this.text));
                    win.currentPath = j.path || win.currentPath;
                    win.crumb = j.label || win.crumb;
                    win.entries = j.entries || [];
                    win.folderCount = j.folders || 0;
                    win.fileCount = j.files || 0;
                    win.freeText = j.free || "";
                } catch (e) { }
            }
        }
    }
    Process {
        id: openProc
        running: false
        command: ["python3", win.io(), "places"]
    }
    Process {
        id: mkdirProc
        running: false
        command: ["python3", win.io(), "places"]
        stdout: StdioCollector {
            onStreamFinished: win.go(win.currentPath, false)
        }
    }

    component ToolBtn: Item {
        id: tb
        property string mark: ""
        property bool on: false
        property bool enabled: true
        signal tapped()
        implicitWidth: 40
        implicitHeight: 36
        width: 40; height: 36
        Rectangle {
            anchors.fill: parent
            radius: Theme.r1
            color: tb.on ? Theme.elevated : "transparent"
            border.width: 1
            border.color: Theme.soften(win.iceHair, tb.on || tbHov.hovered ? 0.85 : 0.40)
            opacity: tb.enabled ? 1 : 0.35
        }
        Text {
            anchors.centerIn: parent
            text: tb.mark
            color: Theme.text
            font.family: Theme.fUi
            font.pixelSize: Theme.tHead
        }
        HoverHandler { id: tbHov; cursorShape: tb.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { enabled: tb.enabled; onTapped: tb.tapped() }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.preferredWidth: 220
            Layout.maximumWidth: 220
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.rightMargin: Theme.s4
                spacing: 2
                Text {
                    text: qsTr("PLACES")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    font.weight: Theme.wStrong
                    font.letterSpacing: Theme.trackMicro
                    topPadding: 2
                    bottomPadding: Theme.s2
                }
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: placeCol.height
                    Column {
                        id: placeCol
                        width: parent.width
                        spacing: 2
                        Repeater {
                            model: win.places
                            delegate: Item {
                                required property var modelData
                                width: placeCol.width
                                height: 34
                                readonly property bool current: modelData.path === win.currentPath
                                Rectangle {
                                    visible: current
                                    anchors.fill: parent
                                    radius: Theme.r1
                                    color: Theme.elevated
                                    border.width: 1
                                    border.color: Theme.soften(win.iceHair, 0.85)
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.s4
                                    anchors.right: parent.right
                                    text: modelData.label
                                    color: current ? Theme.text : Theme.textMuted
                                    font.family: Theme.fUi
                                    font.pixelSize: 15
                                    font.weight: current ? Theme.wStrong : Font.Normal
                                    elide: Text.ElideRight
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: win.go(modelData.path) }
                            }
                        }
                        Text {
                            topPadding: Theme.s5
                            text: qsTr("NETWORK")
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            font.weight: Theme.wStrong
                            font.letterSpacing: Theme.trackMicro
                        }
                        Text {
                            text: qsTr("Network")
                            color: Theme.textMuted
                            font.family: Theme.fUi
                            font.pixelSize: 15
                            leftPadding: Theme.s4
                            topPadding: Theme.s2
                        }
                    }
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
            spacing: Theme.s3

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s3
                ToolBtn { mark: "‹"; enabled: win.histIndex > 0; onTapped: win.back() }
                ToolBtn { mark: "›"; enabled: win.histIndex < win.history.length - 1; onTapped: win.forward() }
                ToolBtn { mark: "⌃"; onTapped: win.up() }
                Item {
                    Layout.preferredWidth: 140
                    Layout.preferredHeight: 36
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.r1
                        color: Theme.elevated
                        border.width: 1
                        border.color: Theme.soften(win.iceHair, 0.85)
                    }
                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        text: win.crumb
                        color: Theme.text
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tBody
                        font.weight: Theme.wStrong
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: Theme.r1
                    color: Theme.soften(Theme.void_, 0.62)
                    border.width: 1
                    border.color: Theme.soften(win.iceHair, 0.45)
                    TextInput {
                        id: filterField
                        anchors.fill: parent
                        anchors.leftMargin: Theme.s5
                        anchors.rightMargin: Theme.s5
                        color: Theme.text
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tBody
                        clip: true
                        onTextChanged: win.filter = text
                    }
                    Text {
                        anchors.fill: filterField
                        visible: filterField.text.length === 0 && !filterField.activeFocus
                        text: qsTr("Filter")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tBody
                        enabled: false
                    }
                }
                ToolBtn {
                    mark: "+"
                    onTapped: {
                        var p = win.currentPath;
                        if (!p || p.indexOf("trash") === 0) return;
                        mkdirProc.command = ["python3", win.io(), "mkdir", p + "/untitled"];
                        mkdirProc.running = false;
                        mkdirProc.running = true;
                    }
                }
            }

            Flickable {
                id: listFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: listCol.height
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: listCol
                    width: listFlick.width
                    spacing: 4
                    Repeater {
                        model: win.shown
                        delegate: Item {
                            required property var modelData
                            width: listCol.width
                            height: 44
                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.r1
                                color: rowHov.hovered ? Theme.elevated : "transparent"
                                border.width: 1
                                border.color: Theme.soften(win.iceHair, rowHov.hovered ? 0.55 : 0.22)
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.s4
                                anchors.rightMargin: Theme.s5
                                spacing: Theme.s4
                                Rectangle {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: 14
                                    color: Theme.elevated
                                    border.width: 1
                                    border.color: Theme.soften(win.ice, 0.70)
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.dir ? "▸" : "·"
                                        color: win.ice
                                        font.pixelSize: Theme.tCaption
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: Theme.text
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tBody
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: modelData.sizeText
                                    color: Theme.textDim
                                    font.family: Theme.fNum
                                    font.pixelSize: Theme.tCaption
                                    font.features: ({ "tnum": 1 })
                                }
                                Text {
                                    Layout.preferredWidth: 140
                                    horizontalAlignment: Text.AlignRight
                                    text: modelData.mtimeText
                                    color: Theme.textDim
                                    font.family: Theme.fNum
                                    font.pixelSize: Theme.tCaption
                                    font.features: ({ "tnum": 1 })
                                }
                            }
                            HoverHandler { id: rowHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: win.openEntry(modelData) }
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("%1 folders, %2 files").arg(win.folderCount).arg(win.fileCount)
                      + (win.freeText.length ? "  ·  " + win.freeText : "")
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
            }
        }
    }
}
