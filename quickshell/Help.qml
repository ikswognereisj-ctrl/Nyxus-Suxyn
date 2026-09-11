pragma ComponentBehavior: Bound
// Nyxus Suxyn — HELP. GTK open-book (contents + page), widget glass.
// Same nyxus_help_content.py. Magma pip on HELP. Tape untouched.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

AppWindow {
    id: win

    titleText: qsTr("Help")
    iconName: "nyxus-help"
    subtitleText: win.pageTitle.length ? win.pageTitle : qsTr("The book")
    open: Bus.helpOpen
    onDismissed: Bus.helpOpen = false
    implicitWidth: 1020
    implicitHeight: 720
    minimumSize: Qt.size(720, 480)

    property var categories: []
    property var topics: []
    property string query: ""
    property string slug: ""
    property string pageTitle: ""
    property string body: ""

    readonly property color ice: Theme.tokenAccentPrimary
    readonly property color iceHair: Theme.tokenAccentHairline
    readonly property color magma: Theme.paintLayers.magma[5]
    readonly property var shown: {
        var q = win.query.trim().toLowerCase();
        var out = [];
        for (var i = 0; i < win.topics.length; i++) {
            var t = win.topics[i];
            if (q.length) {
                var hay = (t.title + " " + t.summary + " " + t.slug).toLowerCase();
                if (hay.indexOf(q) < 0) continue;
            }
            out.push(t);
        }
        return out;
    }

    function io() { return (Quickshell.env("HOME") || "") + "/.config/quickshell/help-io.py"; }
    function refresh() {
        listProc.running = false;
        listProc.running = true;
    }
    function openSlug(s) {
        win.slug = s;
        pageProc.command = ["python3", win.io(), "page", s];
        pageProc.running = false;
        pageProc.running = true;
    }

    onOpenChanged: if (open) win.refresh()

    IpcHandler {
        target: "help"
        function ready(): string { return "ready"; }
        function engage(): string { Bus.helpOpen = true; win.refresh(); return "help"; }
        function at(slug: string): string {
            Bus.helpOpen = true;
            win.refresh();
            if (slug && slug.length) win.openSlug(slug);
            return slug || "help";
        }
        function dismiss(): string { Bus.helpOpen = false; return "hidden"; }
    }

    Process {
        id: listProc
        running: false
        command: ["python3", win.io(), "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.categories = j.categories || [];
                    win.topics = j.topics || [];
                    if (win.slug.length === 0 && win.topics.length)
                        win.openSlug(win.topics[0].slug);
                } catch (e) { }
            }
        }
    }
    Process {
        id: pageProc
        running: false
        command: ["python3", win.io(), "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.pageTitle = j.title || "";
                    win.body = j.body || "";
                } catch (e) { }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.preferredWidth: 280
            Layout.maximumWidth: 280
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.rightMargin: Theme.s4
                spacing: Theme.s3
                Row {
                    spacing: Theme.s3
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7; height: 7; radius: 3.5
                        color: win.magma
                    }
                    Text {
                        text: qsTr("HELP")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        font.weight: Theme.wStrong
                        font.letterSpacing: Theme.trackMicro
                    }
                }
                Text {
                    text: qsTr("Book")
                    color: Theme.text
                    font.family: Theme.fUiTitle
                    font.pixelSize: Theme.tDisplay
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: Theme.r1
                    color: Theme.soften(Theme.void_, 0.62)
                    border.width: 1
                    border.color: Theme.soften(win.iceHair, 0.45)
                    TextInput {
                        id: qField
                        anchors.fill: parent
                        anchors.margins: 8
                        color: Theme.text
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        onTextChanged: win.query = text
                    }
                    Text {
                        anchors.fill: qField
                        visible: qField.text.length === 0 && !qField.activeFocus
                        text: qsTr("Find a topic")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        enabled: false
                    }
                }
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: topCol.height
                    Column {
                        id: topCol
                        width: parent.width
                        spacing: 2
                        Repeater {
                            model: win.shown
                            delegate: Item {
                                required property var modelData
                                width: topCol.width
                                height: 36
                                readonly property bool current: modelData.slug === win.slug
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
                                    text: modelData.title
                                    color: current ? Theme.text : Theme.textMuted
                                    font.family: Theme.fUi
                                    font.pixelSize: 14
                                    elide: Text.ElideRight
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: win.openSlug(modelData.slug) }
                            }
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
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: pageCol.height
            Column {
                id: pageCol
                width: parent.width
                padding: Theme.s6
                spacing: Theme.s4
                Text {
                    width: parent.width - Theme.s6 * 2
                    x: Theme.s6
                    text: win.pageTitle
                    color: Theme.text
                    font.family: Theme.fUiTitle
                    font.pixelSize: Theme.tTitle
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                }
                Text {
                    width: parent.width - Theme.s6 * 2
                    x: Theme.s6
                    text: win.body
                    color: Theme.text
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tBody
                    wrapMode: Text.WordWrap
                    textFormat: Text.MarkdownText
                }
            }
        }
    }
}
