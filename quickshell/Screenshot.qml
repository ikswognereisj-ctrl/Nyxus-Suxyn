pragma ComponentBehavior: Bound
// Nyxus Suxyn — SCREENSHOT. GTK shutter (region / window / full), widget
// glass. grim + slurp. Magma is REC STOP only. Tape/Media untouched.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

AppWindow {
    id: win

    titleText: qsTr("Screenshot")
    iconName: "nyxus-screenshot"
    subtitleText: qsTr("Capture")
    open: Bus.screenshotOpen
    onDismissed: Bus.screenshotOpen = false
    implicitWidth: 560
    implicitHeight: 480
    minimumSize: Qt.size(480, 400)

    property var shots: []
    property string status: qsTr("esc cancel · pictures saved to Pictures/Screenshots")
    property string pending: ""
    property bool copyOnly: false

    readonly property color ice: Theme.tokenAccentPrimary
    readonly property color iceHair: Theme.tokenAccentHairline
    readonly property color magma: Theme.paintLayers.magma[5]

    function io() { return (Quickshell.env("HOME") || "") + "/.config/quickshell/screenshot-io.py"; }
    function refresh() {
        recProc.running = false;
        recProc.running = true;
    }
    function shoot(mode) {
        win.pending = mode;
        Bus.screenshotOpen = false;
        hideTimer.restart();
    }
    function eyedrop() {
        win.pending = "eyedrop";
        Bus.screenshotOpen = false;
        hideTimer.restart();
    }
    function rec(kind) {
        recCmd.command = ["python3", win.io(), "record", kind];
        recCmd.running = false;
        recCmd.running = true;
        if (kind === "stop")
            win.status = qsTr("Recording stop sent.");
        else {
            Bus.screenshotOpen = false;
            win.status = qsTr("Recording…");
        }
    }

    onOpenChanged: if (open) win.refresh()

    Timer {
        id: hideTimer
        interval: 180
        onTriggered: {
            if (win.pending === "eyedrop")
                capProc.command = ["python3", win.io(), "eyedrop"];
            else
                capProc.command = ["python3", win.io(), win.pending];
            capProc.running = false;
            capProc.running = true;
        }
    }

    IpcHandler {
        target: "screenshot"
        function ready(): string { return "ready"; }
        function engage(): string { Bus.screenshotOpen = true; win.refresh(); return "screenshot"; }
        function region(): string { win.shoot("region"); return "region"; }
        function dismiss(): string { Bus.screenshotOpen = false; return "hidden"; }
    }

    Process {
        id: recProc
        running: false
        command: ["python3", win.io(), "recents"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.shots = j.shots || [];
                } catch (e) { }
            }
        }
    }
    Process {
        id: capProc
        running: false
        command: ["python3", win.io(), "recents"]
        stdout: StdioCollector {
            onStreamFinished: {
                Bus.screenshotOpen = true;
                try {
                    var j = JSON.parse(String(this.text));
                    if (j.ok && j.path)
                        win.status = qsTr("Saved %1").arg(j.path);
                    else if (j.ok && j.color)
                        win.status = qsTr("Colour %1").arg(j.color);
                    else if (j.error === "cancelled")
                        win.status = qsTr("Cancelled.");
                    else
                        win.status = j.error || qsTr("Capture did not finish.");
                } catch (e) { win.status = qsTr("Capture did not finish."); }
                win.refresh();
            }
        }
    }
    Process { id: recCmd; running: false; command: ["true"] }

    component Face: Item {
        id: f
        property string kicker: ""
        property string mode: ""
        width: 148; height: 88
        Rectangle {
            anchors.fill: parent
            radius: Theme.r2
            color: Theme.elevated
            border.width: 1
            border.color: Theme.soften(win.iceHair, fh.hovered ? 0.90 : 0.50)
        }
        Text {
            anchors.centerIn: parent
            text: f.kicker
            color: Theme.text
            font.family: Theme.fUi
            font.pixelSize: Theme.tCaption
            font.weight: Theme.wStrong
            font.letterSpacing: Theme.trackMicro
        }
        HoverHandler { id: fh; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: win.shoot(f.mode) }
    }

    component Ghost: Item {
        id: g
        property string mark: ""
        property bool danger: false
        signal tapped()
        implicitWidth: Math.max(36, lab.implicitWidth + 18)
        implicitHeight: 32
        width: implicitWidth; height: 32
        Rectangle {
            anchors.fill: parent
            radius: Theme.r1
            color: "transparent"
            border.width: 1
            border.color: Theme.soften(g.danger ? win.magma : win.iceHair, gh.hovered ? 0.90 : 0.50)
        }
        Text {
            id: lab
            anchors.centerIn: parent
            text: g.mark
            color: g.danger ? win.magma : Theme.text
            font.family: Theme.fUi
            font.pixelSize: Theme.tCaption
            font.weight: Theme.wStrong
        }
        HoverHandler { id: gh; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: g.tapped() }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.s4

        Row {
            spacing: Theme.s3
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 7; height: 7; radius: 3.5
                color: win.magma
            }
            Text {
                text: qsTr("SCREENSHOT")
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                font.weight: Theme.wStrong
                font.letterSpacing: Theme.trackMicro
            }
        }
        Text {
            text: qsTr("Shutter")
            color: Theme.text
            font.family: Theme.fUiTitle
            font.pixelSize: Theme.tDisplay
            font.weight: Font.DemiBold
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.s4
            Face { kicker: qsTr("REGION"); mode: "region" }
            Face { kicker: qsTr("WINDOW"); mode: "window" }
            Face { kicker: qsTr("FULL SCREEN"); mode: "fullscreen" }
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.s4
            Ghost { mark: qsTr("Eyedropper"); onTapped: win.eyedrop() }
        }

        Text {
            text: qsTr("RECORD")
            color: Theme.textDim
            font.family: Theme.fUi
            font.pixelSize: Theme.tCaption
            font.weight: Theme.wStrong
            font.letterSpacing: Theme.trackMicro
        }
        Row {
            spacing: Theme.s3
            Ghost { mark: qsTr("REC REGION"); onTapped: win.rec("region") }
            Ghost { mark: qsTr("REC TOGGLE"); onTapped: win.rec("toggle") }
            Ghost { mark: qsTr("REC STOP"); danger: true; onTapped: win.rec("stop") }
        }

        Text {
            text: qsTr("RECENTS")
            color: Theme.textDim
            font.family: Theme.fUi
            font.pixelSize: Theme.tCaption
            font.weight: Theme.wStrong
            font.letterSpacing: Theme.trackMicro
        }
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: recCol.height
            Column {
                id: recCol
                width: parent.width
                spacing: 4
                Repeater {
                    model: win.shots
                    delegate: Item {
                        id: rec
                        required property var modelData
                        width: recCol.width
                        height: 56
                        Row {
                            anchors.fill: parent
                            spacing: Theme.s3
                            Image {
                                width: 72; height: 48
                                anchors.verticalCenter: parent.verticalCenter
                                source: "file://" + rec.modelData.path
                                sourceSize.width: 144
                                sourceSize.height: 96
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                smooth: true
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: recCol.width - 84
                                text: rec.modelData.name
                                color: Theme.textMuted
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                                elide: Text.ElideMiddle
                            }
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: Quickshell.execDetached(["xdg-open", rec.modelData.path])
                        }
                    }
                }
                Text {
                    visible: win.shots.length === 0
                    text: qsTr("No shots today.")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tBody
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: win.status
            color: Theme.textDim
            font.family: Theme.fUi
            font.pixelSize: Theme.tCaption
            wrapMode: Text.WordWrap
        }
    }
}
