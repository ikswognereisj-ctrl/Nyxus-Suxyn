pragma ComponentBehavior: Bound
// Nyxus Suxyn — ARCHIVE. GTK layout (crate slats on a bench), widget
// glass. bsdtar, same extract-to-named-folder rule. Magma pip on
// ARCHIVE only — Extract is not halt. Tape/Media untouched.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

AppWindow {
    id: win

    titleText: qsTr("Archive")
    iconName: "nyxus-archive"
    subtitleText: win.archName.length ? win.archName : qsTr("No archive on the bench")
    open: Bus.archiveOpen
    onDismissed: Bus.archiveOpen = false
    implicitWidth: 880
    implicitHeight: 620
    minimumSize: Qt.size(640, 420)

    property string archPath: ""
    property string archName: ""
    property string cwd: ""
    property string filter: ""
    property string sort: "name"
    property var entries: []
    property int packed: 0
    property int total: 0
    property string status: qsTr("Open an archive to see what is inside it.")
    property string busy: ""

    readonly property color ice: Theme.tokenAccentPrimary
    readonly property color iceHair: Theme.tokenAccentHairline
    readonly property color magma: Theme.paintLayers.magma[5]
    readonly property string crumb: win.cwd.length ? ("/" + win.cwd) : "/"

    function io() { return (Quickshell.env("HOME") || "") + "/.config/quickshell/archive-io.py"; }
    function load(p, dir) {
        if (!p || !p.length) return;
        listProc.command = ["python3", win.io(), "list", p, dir || "", win.filter, win.sort];
        listProc.running = false;
        listProc.running = true;
    }
    function pick() {
        pickProc.running = false;
        pickProc.running = true;
    }
    function goUp() {
        if (!win.cwd.length) return;
        var i = win.cwd.lastIndexOf("/");
        win.cwd = i <= 0 ? "" : win.cwd.substring(0, i);
        win.load(win.archPath, win.cwd);
    }
    function openEntry(ent) {
        if (!ent) return;
        if (ent.dir) {
            win.cwd = ent.member;
            win.load(win.archPath, win.cwd);
        }
    }
    function extractHere() {
        if (!win.archPath.length) return;
        win.busy = qsTr("Extracting…");
        exProc.command = ["python3", win.io(), "extract", win.archPath];
        exProc.running = false;
        exProc.running = true;
    }
    function sizeText(n) {
        if (!n) return "—";
        if (n < 1024) return n + " B";
        if (n < 1024 * 1024) return Math.round(n / 1024) + " KiB";
        return (n / (1024 * 1024)).toFixed(1) + " MiB";
    }

    onOpenChanged: if (open && win.archPath.length === 0)
        win.status = qsTr("Open an archive to see what is inside it.")

    IpcHandler {
        target: "archive"
        function ready(): string { return "ready"; }
        function engage(): string { Bus.archiveOpen = true; return "archive"; }
        function at(path: string): string {
            Bus.archiveOpen = true;
            win.cwd = "";
            win.load(path, "");
            return path;
        }
        function dismiss(): string { Bus.archiveOpen = false; return "hidden"; }
    }

    Process {
        id: listProc
        running: false
        command: ["python3", win.io(), "pick"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    if (!j.ok) {
                        win.status = j.error || qsTr("Not an archive I can read.");
                        return;
                    }
                    win.archPath = j.path;
                    win.archName = j.name;
                    win.packed = j.bytes || 0;
                    win.total = j.count || 0;
                    win.cwd = j.cwd || "";
                    win.entries = j.entries || [];
                    win.status = win.archName + "  ·  " + win.sizeText(win.packed)
                                 + "  ·  " + win.total + " members";
                } catch (e) { win.status = qsTr("Could not read it."); }
            }
        }
    }
    Process {
        id: pickProc
        running: false
        command: ["python3", win.io(), "pick"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    if (j.ok) {
                        win.archPath = j.path;
                        win.archName = j.name;
                        win.packed = j.bytes || 0;
                        win.total = j.count || 0;
                        win.cwd = "";
                        win.entries = j.entries || [];
                        win.status = win.archName + "  ·  " + win.sizeText(win.packed);
                    }
                } catch (e) { }
            }
        }
    }
    Process {
        id: exProc
        running: false
        command: ["python3", win.io(), "pick"]
        stdout: StdioCollector {
            onStreamFinished: {
                win.busy = "";
                try {
                    var j = JSON.parse(String(this.text));
                    win.status = j.ok ? qsTr("Extracted to %1").arg(j.dest)
                                      : (j.error || qsTr("Extract did not finish."));
                } catch (e) { win.status = qsTr("Extract did not finish."); }
            }
        }
    }

    component Ghost: Item {
        id: g
        property string mark: ""
        property bool on: false
        property bool enabled: true
        signal tapped()
        implicitWidth: Math.max(36, lab.implicitWidth + 18)
        implicitHeight: 32
        width: implicitWidth; height: 32
        opacity: g.enabled ? 1 : 0.35
        Rectangle {
            anchors.fill: parent
            radius: Theme.r1
            color: g.on ? Theme.elevated : "transparent"
            border.width: 1
            border.color: Theme.soften(win.iceHair, g.on || gh.hovered ? 0.85 : 0.45)
        }
        Text {
            id: lab
            anchors.centerIn: parent
            text: g.mark
            color: Theme.text
            font.family: Theme.fUi
            font.pixelSize: Theme.tBody
            font.weight: Theme.wStrong
        }
        HoverHandler { id: gh; cursorShape: g.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { enabled: g.enabled; onTapped: g.tapped() }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.s3

        Row {
            spacing: Theme.s3
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 7; height: 7; radius: 3.5
                color: win.magma
            }
            Text {
                text: qsTr("ARCHIVE")
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                font.weight: Theme.wStrong
                font.letterSpacing: Theme.trackMicro
            }
        }
        Text {
            text: qsTr("Crate")
            color: Theme.text
            font.family: Theme.fUiTitle
            font.pixelSize: Theme.tDisplay
            font.weight: Font.DemiBold
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s3
            Text {
                Layout.fillWidth: true
                text: win.archName
                color: Theme.text
                font.family: Theme.fUi
                font.pixelSize: Theme.tBody
                font.weight: Theme.wStrong
                elide: Text.ElideMiddle
            }
            Ghost { mark: qsTr("Open"); onTapped: win.pick() }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s3
            Ghost { mark: "↑"; enabled: win.cwd.length > 0; onTapped: win.goUp() }
            Text {
                Layout.preferredWidth: 140
                text: win.crumb
                color: Theme.text
                font.family: Theme.fUi
                font.pixelSize: Theme.tBody
                elide: Text.ElideLeft
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: Theme.r1
                color: Theme.soften(Theme.void_, 0.62)
                border.width: 1
                border.color: Theme.soften(win.iceHair, 0.45)
                TextInput {
                    id: filt
                    anchors.fill: parent
                    anchors.margins: 8
                    color: Theme.text
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    clip: true
                    onTextChanged: {
                        win.filter = text;
                        if (win.archPath.length) win.load(win.archPath, win.cwd);
                    }
                }
                Text {
                    anchors.fill: filt
                    visible: filt.text.length === 0 && !filt.activeFocus
                    text: qsTr("Filter this archive")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    enabled: false
                }
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: slatCol.height
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: slatCol
                width: parent.width
                spacing: 3
                Column {
                    visible: win.archPath.length === 0
                    width: parent.width
                    spacing: Theme.s5
                    topPadding: 48
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTr("BENCH")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        font.weight: Theme.wStrong
                        font.letterSpacing: Theme.trackMicro
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTr("No archive on the bench.")
                        color: Theme.text
                        font.family: Theme.fUiTitle
                        font.pixelSize: Theme.tTitle
                        font.weight: Font.DemiBold
                    }
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 120; height: 36
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.r1
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.soften(win.iceHair, 0.85)
                        }
                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Open")
                            color: Theme.text
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tBody
                            font.weight: Theme.wStrong
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: win.pick() }
                    }
                }
                Repeater {
                    model: win.entries
                    delegate: Item {
                        required property var modelData
                        width: slatCol.width
                        height: 40
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
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                radius: 11
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
                                text: win.sizeText(modelData.size)
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

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s3
            Ghost {
                mark: qsTr("Extract here")
                on: true
                enabled: win.archPath.length > 0 && win.busy.length === 0
                onTapped: win.extractHere()
            }
            Ghost {
                mark: win.busy.length ? win.busy : qsTr("Extract to…")
                enabled: win.archPath.length > 0 && win.busy.length === 0
                onTapped: win.extractHere()
            }
            Item { Layout.fillWidth: true }
        }

        Text {
            Layout.fillWidth: true
            text: win.status
            color: Theme.textDim
            font.family: Theme.fUi
            font.pixelSize: Theme.tCaption
            elide: Text.ElideMiddle
        }
    }
}
