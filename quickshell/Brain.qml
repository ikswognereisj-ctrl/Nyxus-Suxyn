pragma ComponentBehavior: Bound
// Nyxus Suxyn — BRAIN. GTK chat that knows this machine, widget glass.
// You = coral. Machine = ice. Nothing leaves the laptop.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

AppWindow {
    id: win

    titleText: qsTr("Brain")
    iconName: "nyxus-brain"
    subtitleText: win.status
    open: Bus.brainOpen
    onDismissed: Bus.brainOpen = false
    implicitWidth: 920
    implicitHeight: 680
    minimumSize: Qt.size(640, 480)

    property var messages: []
    property string draft: ""
    property bool busy: false
    property string status: qsTr("Ask this machine.")
    readonly property color ice: Theme.tokenAccentPrimary
    readonly property color iceHair: Theme.tokenAccentHairline
    readonly property color magma: Theme.paintLayers.magma[5]
    readonly property color coral: "#e07a5f"

    function io() { return (Quickshell.env("HOME") || "") + "/.config/quickshell/brain-io.py"; }
    function send() {
        var q = win.draft.trim();
        if (!q.length || win.busy) return;
        win.messages = win.messages.concat([{ who: "you", text: q }]);
        win.draft = "";
        askField.text = "";
        win.busy = true;
        win.status = qsTr("Thinking…");
        askProc.command = ["python3", win.io(), "ask", q];
        askProc.running = false;
        askProc.running = true;
    }

    onOpenChanged: if (open && win.messages.length === 0)
        win.status = qsTr("Ask this machine.")

    IpcHandler {
        target: "brain"
        function ready(): string { return "ready"; }
        function engage(): string { Bus.brainOpen = true; return "brain"; }
        function dismiss(): string { Bus.brainOpen = false; return "hidden"; }
    }

    Process {
        id: askProc
        running: false
        command: ["python3", win.io(), "ask", "ping"]
        stdout: StdioCollector {
            onStreamFinished: {
                win.busy = false;
                try {
                    var j = JSON.parse(String(this.text));
                    win.messages = win.messages.concat([{ who: "brain", text: j.text || "No answer." }]);
                    win.status = j.ok ? qsTr("Ready.") : qsTr("Could not answer.");
                } catch (e) {
                    win.messages = win.messages.concat([{ who: "brain", text: String(this.text).trim() || "No answer." }]);
                    win.status = qsTr("Ready.");
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.s3
        RowLayout {
            Layout.fillWidth: true
            Row {
                spacing: Theme.s3
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7; height: 7; radius: 3.5
                    color: win.coral
                }
                Text {
                    text: qsTr("BRAIN")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    font.weight: Theme.wStrong
                    font.letterSpacing: Theme.trackMicro
                }
            }
            Item { Layout.fillWidth: true }
            Text {
                text: qsTr("New topic")
                color: Theme.textMuted
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: { win.messages = []; win.status = qsTr("New topic."); } }
            }
        }
        Text {
            text: qsTr("Ask")
            color: Theme.text
            font.family: Theme.fUiTitle
            font.pixelSize: Theme.tDisplay
            font.weight: Font.DemiBold
        }
        Flickable {
            id: chatFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: chatCol.height
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: chatCol
                width: parent.width
                spacing: Theme.s3
                Repeater {
                    model: win.messages
                    Rectangle {
                        required property var modelData
                        width: Math.min(chatCol.width - 8, 640)
                        height: msg.implicitHeight + 20
                        radius: Theme.r1
                        color: Theme.elevated
                        border.width: 1
                        border.color: Theme.soften(modelData.who === "you" ? win.coral : win.iceHair, 0.70)
                        x: modelData.who === "you" ? Math.max(0, chatCol.width - width) : 0
                        Text {
                            id: msg
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.margins: 10
                            text: modelData.text
                            color: Theme.text
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tBody
                            wrapMode: Text.WordWrap
                        }
                    }
                }
                Text {
                    visible: win.messages.length === 0
                    text: qsTr("Nothing leaves this laptop. Ask about disk, heat, Hyprland, or the build.")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tBody
                    width: parent.width
                    wrapMode: Text.WordWrap
                }
            }
            onContentHeightChanged: contentY = Math.max(0, contentHeight - height)
        }
        RowLayout {
            Layout.fillWidth: true
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: Theme.r1
                color: Theme.soften(Theme.void_, 0.62)
                border.width: 1
                border.color: Theme.soften(win.iceHair, 0.45)
                TextInput {
                    id: askField
                    anchors.fill: parent
                    anchors.margins: 10
                    color: Theme.text
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tBody
                    onTextChanged: win.draft = text
                    Keys.onReturnPressed: win.send()
                }
                Text {
                    anchors.fill: askField
                    visible: askField.text.length === 0 && !askField.activeFocus
                    text: qsTr("Ask this machine…")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tBody
                    enabled: false
                }
            }
            Item {
                width: 72; height: 36
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.r1
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.soften(win.iceHair, 0.85)
                }
                Text {
                    anchors.centerIn: parent
                    text: win.busy ? qsTr("…") : qsTr("Ask")
                    color: Theme.text
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tBody
                    font.weight: Theme.wStrong
                }
                TapHandler { enabled: !win.busy; onTapped: win.send() }
            }
        }
        Text {
            text: win.status
            color: Theme.textDim
            font.family: Theme.fUi
            font.pixelSize: Theme.tCaption
        }
    }
}
