pragma ComponentBehavior: Bound
// Nyxus Suxyn — READER. GTK layout (toolbar + page rail + paper on a
// void desk), widget glass. Renderer is still poppler CLI. Tape/Media
// untouched.
// Ice: glacier[4] 1 px seam, Theme.text. Magma pip on READER (what
// matters). Gold stays Notes/Calculator. Install-style outline on Open.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

AppWindow {
    id: win

    titleText: qsTr("Reader")
    iconName: "nyxus-reader"
    subtitleText: win.docTitle.length ? win.docTitle : qsTr("Open a PDF")
    open: Bus.readerOpen
    onDismissed: {
        win.persist();
        Bus.readerOpen = false;
    }
    implicitWidth: 1160
    implicitHeight: 760
    minimumSize: Qt.size(820, 520)

    property string docPath: ""
    property string docTitle: ""
    property string png: ""
    property int pages: 0
    property int page: 1
    property string zoom: "width"
    property int rot: 0
    property bool sidebar: false
    property string sidePage: "pages"
    property var toc: []
    property var marks: []
    property string status: qsTr("Open a PDF to begin.")
    property bool listing: false
    property real pageW: 612
    property real pageH: 792
    property bool findOn: false
    property string findQuery: ""
    property var findHits: []
    property int findAt: 0

    readonly property color ice: Theme.tokenAccentPrimary
    readonly property color iceHair: Theme.tokenAccentHairline
    readonly property color magma: Theme.paintLayers.magma[5]
    readonly property bool marked: win.marks.indexOf(win.page) >= 0
    readonly property int dpi: {
        var avail = Math.max(200, stage.width - 48);
        var hAvail = Math.max(200, stage.height - 48);
        var w = win.rot === 90 || win.rot === 270 ? win.pageH : win.pageW;
        var h = win.rot === 90 || win.rot === 270 ? win.pageW : win.pageH;
        if (w <= 0) w = 612;
        if (h <= 0) h = 792;
        var d;
        if (win.zoom === "page")
            d = Math.min(72 * avail / w, 72 * hAvail / h);
        else
            d = 72 * avail / w;
        return Math.max(48, Math.min(Math.round(d), 180));
    }

    function io() { return (Quickshell.env("HOME") || "") + "/.config/quickshell/reader-io.py"; }
    function fileUrl(p) {
        var s = String(p || "");
        if (!s.length) return "";
        if (s.indexOf("file:") === 0) return s;
        return "file://" + s;
    }
    function openPath(p) {
        if (!p || !p.length) return;
        win.listing = true;
        win.status = qsTr("Opening…");
        infoProc.command = ["python3", win.io(), "info", p];
        infoProc.running = false;
        infoProc.running = true;
    }
    function renderNow() {
        if (!win.docPath.length || win.pages <= 0) return;
        renderProc.command = ["python3", win.io(), "render", win.docPath,
                              String(win.page), String(win.dpi), String(win.rot)];
        renderProc.running = false;
        renderProc.running = true;
    }
    function goPage(n) {
        if (win.pages <= 0) return;
        var p = Math.max(1, Math.min(n, win.pages));
        if (p === win.page) { win.renderNow(); return; }
        win.page = p;
        win.renderNow();
        win.persist();
    }
    function persist() {
        if (!win.docPath.length) return;
        saveProc.command = ["python3", win.io(), "save", win.docPath,
                            String(win.page), String(win.zoom), String(win.rot),
                            win.sidebar ? "1" : "0", win.marks.join(",")];
        saveProc.running = false;
        saveProc.running = true;
    }
    function pick() {
        pickProc.running = false;
        pickProc.running = true;
    }
    function runFind() {
        if (!win.docPath.length || !win.findQuery.trim().length) return;
        findProc.command = ["python3", win.io(), "find", win.docPath, win.findQuery.trim()];
        findProc.running = false;
        findProc.running = true;
    }
    function jumpHit(dir) {
        if (!win.findHits.length) return;
        var n = win.findHits.length;
        win.findAt = (win.findAt + dir + n) % n;
        win.goPage(win.findHits[win.findAt].page);
        win.status = qsTr("Find %1 / %2 · p.%3").arg(win.findAt + 1).arg(n).arg(win.findHits[win.findAt].page);
    }
    function printDoc() {
        if (!win.docPath.length) return;
        printProc.command = ["python3", win.io(), "print", win.docPath];
        printProc.running = false;
        printProc.running = true;
        win.status = qsTr("Sending to printer…");
    }
    function toggleMark() {
        if (win.pages <= 0) return;
        var next = [];
        var found = false;
        for (var i = 0; i < win.marks.length; i++) {
            if (win.marks[i] === win.page) found = true;
            else next.push(win.marks[i]);
        }
        if (!found) next.push(win.page);
        next.sort(function (a, b) { return a - b; });
        win.marks = next;
        win.persist();
    }
    function loadLast() {
        lastProc.running = false;
        lastProc.running = true;
    }

    onOpenChanged: if (open && win.docPath.length === 0) win.loadLast()
    onDpiChanged: if (win.docPath.length) win.renderNow()

    IpcHandler {
        target: "reader"
        function ready(): string { return "ready"; }
        function engage(): string {
            Bus.readerOpen = true;
            if (win.docPath.length === 0) win.loadLast();
            return "reader";
        }
        function at(path: string): string {
            Bus.readerOpen = true;
            win.openPath(path);
            return path;
        }
        function dismiss(): string { Bus.readerOpen = false; return "hidden"; }
    }

    Process {
        id: lastProc
        running: false
        command: ["python3", win.io(), "last"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    if (j.path) win.openPath(j.path);
                    else win.status = qsTr("Open a PDF to begin.");
                } catch (e) { win.status = qsTr("Open a PDF to begin."); }
            }
        }
    }
    Process {
        id: infoProc
        running: false
        command: ["python3", win.io(), "last"]
        stdout: StdioCollector {
            onStreamFinished: {
                win.listing = false;
                try {
                    var j = JSON.parse(String(this.text));
                    if (!j.ok) {
                        win.status = j.error || qsTr("Could not open.");
                        return;
                    }
                    win.docPath = j.path;
                    win.docTitle = j.title || j.name;
                    win.pages = j.pages || 0;
                    win.page = j.page || 1;
                    win.zoom = j.zoom || "width";
                    win.rot = j.rot || 0;
                    win.sidebar = !!j.sidebar;
                    win.sidePage = j.sidePage || "pages";
                    win.marks = j.marks || [];
                    win.pageW = j.width || 612;
                    win.pageH = j.height || 792;
                    win.status = win.docTitle;
                    win.renderNow();
                    tocProc.command = ["python3", win.io(), "toc", win.docPath];
                    tocProc.running = false;
                    tocProc.running = true;
                } catch (e) { win.status = qsTr("Could not open."); }
            }
        }
    }
    Process {
        id: renderProc
        running: false
        command: ["python3", win.io(), "last"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    if (j.ok && j.png) win.png = j.png;
                    else win.status = j.error || win.status;
                } catch (e) { }
            }
        }
    }
    Process {
        id: tocProc
        running: false
        command: ["python3", win.io(), "last"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.toc = j.toc || [];
                } catch (e) { }
            }
        }
    }
    Process {
        id: saveProc
        running: false
        command: ["python3", win.io(), "last"]
    }
    Process {
        id: findProc
        running: false
        command: ["python3", win.io(), "last"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.findHits = j.hits || [];
                    win.findAt = 0;
                    if (!j.ok) win.status = j.error || qsTr("Find failed.");
                    else if (!win.findHits.length) win.status = qsTr("No matches.");
                    else {
                        win.goPage(win.findHits[0].page);
                        win.status = qsTr("%1 matches · p.%2").arg(win.findHits.length).arg(win.findHits[0].page);
                    }
                } catch (e) { win.status = qsTr("Find failed."); }
            }
        }
    }
    Process {
        id: printProc
        running: false
        command: ["python3", win.io(), "last"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.status = j.ok ? qsTr("Sent to printer.") : (j.error || qsTr("Print failed."));
                } catch (e) { win.status = qsTr("Print failed."); }
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
                    if (j.ok && j.path) win.openPath(j.path);
                } catch (e) { }
            }
        }
    }

    component Ghost: Item {
        id: g
        property string mark: ""
        property bool on: false
        property bool danger: false
        signal tapped()
        implicitWidth: Math.max(36, lab.implicitWidth + 20)
        implicitHeight: 32
        width: implicitWidth; height: 32
        Rectangle {
            anchors.fill: parent
            radius: Theme.r1
            color: g.on ? Theme.elevated : "transparent"
            border.width: 1
            border.color: Theme.soften(g.danger ? win.magma : win.iceHair,
                                       g.on || gh.hovered ? 0.85 : 0.45)
        }
        Text {
            id: lab
            anchors.centerIn: parent
            text: g.mark
            color: g.danger ? win.magma : Theme.text
            font.family: Theme.fUi
            font.pixelSize: Theme.tBody
            font.weight: Theme.wStrong
        }
        HoverHandler { id: gh; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: g.tapped() }
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
                text: qsTr("READER")
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                font.weight: Theme.wStrong
                font.letterSpacing: Theme.trackMicro
            }
        }
        Text {
            text: qsTr("Paper")
            color: Theme.text
            font.family: Theme.fUiTitle
            font.pixelSize: Theme.tDisplay
            font.weight: Font.DemiBold
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s3
            Ghost {
                mark: qsTr("Open")
                on: true
                onTapped: win.pick()
            }
            Ghost {
                mark: "☰"
                on: win.sidebar
                onTapped: { win.sidebar = !win.sidebar; win.persist(); }
            }
            Ghost { mark: "‹"; onTapped: win.goPage(win.page - 1) }
            Text {
                text: win.pages > 0 ? (win.page + " / " + win.pages) : "/ —"
                color: Theme.text
                font.family: Theme.fNum
                font.pixelSize: Theme.tBody
                font.features: ({ "tnum": 1 })
            }
            Ghost { mark: "›"; onTapped: win.goPage(win.page + 1) }
            Ghost { mark: "−"; onTapped: { win.zoom = "width"; win.renderNow(); } }
            Text {
                text: win.pages > 0 ? Math.round(win.dpi / 72 * 100) + "%" : "—"
                color: Theme.textDim
                font.family: Theme.fNum
                font.pixelSize: Theme.tCaption
                font.features: ({ "tnum": 1 })
            }
            Ghost { mark: "+"; onTapped: { win.zoom = "page"; win.renderNow(); } }
            Ghost {
                mark: qsTr("Fit width")
                on: win.zoom === "width"
                onTapped: { win.zoom = "width"; win.renderNow(); win.persist(); }
            }
            Ghost {
                mark: qsTr("Fit page")
                on: win.zoom === "page"
                onTapped: { win.zoom = "page"; win.renderNow(); win.persist(); }
            }
            Ghost {
                mark: "⟳"
                onTapped: {
                    win.rot = (win.rot + 90) % 360;
                    win.renderNow();
                    win.persist();
                }
            }
            Ghost {
                mark: win.marked ? "★" : "☆"
                danger: win.marked
                onTapped: win.toggleMark()
            }
            Ghost {
                mark: qsTr("Find")
                on: win.findOn
                onTapped: win.findOn = !win.findOn
            }
            Ghost {
                mark: qsTr("Print")
                onTapped: win.printDoc()
            }
            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: win.findOn
            spacing: Theme.s3
            TextInput {
                id: findField
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                color: Theme.text
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                clip: true
                onTextChanged: win.findQuery = text
                onAccepted: win.runFind()
            }
            Ghost { mark: qsTr("Go"); onTapped: win.runFind() }
            Ghost { mark: "‹"; onTapped: win.jumpHit(-1) }
            Ghost { mark: "›"; onTapped: win.jumpHit(1) }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Item {
                visible: win.sidebar
                Layout.preferredWidth: 196
                Layout.maximumWidth: 196
                Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent
                    anchors.rightMargin: Theme.s4
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Ghost {
                            mark: qsTr("Pages")
                            on: win.sidePage === "pages"
                            onTapped: win.sidePage = "pages"
                        }
                        Ghost {
                            mark: qsTr("Contents")
                            on: win.sidePage === "toc"
                            onTapped: win.sidePage = "toc"
                        }
                        Ghost {
                            mark: qsTr("Marks")
                            on: win.sidePage === "marks"
                            onTapped: win.sidePage = "marks"
                        }
                    }
                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: sideCol.height
                        boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: sideCol
                            width: parent.width
                            spacing: 2
                            Repeater {
                                model: win.sidePage === "toc" ? win.toc
                                     : win.sidePage === "marks" ? win.marks
                                     : win.pages
                                delegate: Item {
                                    required property var modelData
                                    required property int index
                                    width: sideCol.width
                                    height: 32
                                    readonly property int target: {
                                        if (win.sidePage === "toc") return modelData.page;
                                        if (win.sidePage === "marks") return modelData;
                                        return index + 1;
                                    }
                                    readonly property string label: {
                                        if (win.sidePage === "toc") return modelData.title;
                                        if (win.sidePage === "marks") return qsTr("Page %1").arg(modelData);
                                        return qsTr("Page %1").arg(index + 1);
                                    }
                                    readonly property bool current: target === win.page
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
                                        anchors.leftMargin: Theme.s4 + (win.sidePage === "toc" ? (modelData.depth || 0) * 10 : 0)
                                        anchors.right: parent.right
                                        text: label
                                        color: current ? Theme.text : Theme.textMuted
                                        font.family: Theme.fUi
                                        font.pixelSize: 14
                                        elide: Text.ElideRight
                                    }
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: win.goPage(target) }
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                visible: win.sidebar
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: Theme.soften(win.iceHair, 0.45)
            }

            Item {
                id: stage
                Layout.fillWidth: true
                Layout.fillHeight: true
                Rectangle {
                    anchors.fill: parent
                    color: Theme.soften(Theme.void_, 0.55)
                    radius: Theme.r2
                    border.width: 1
                    border.color: Theme.soften(win.iceHair, 0.35)
                }
                Flickable {
                    id: paperFlick
                    visible: win.png.length > 0
                    anchors.fill: parent
                    clip: true
                    contentWidth: Math.max(width, paperImg.width + 48)
                    contentHeight: Math.max(height, paperImg.height + 48)
                    boundsBehavior: Flickable.StopAtBounds
                    Image {
                        id: paperImg
                        x: Math.max(24, (paperFlick.width - width) / 2)
                        y: 24
                        source: win.fileUrl(win.png)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                        smooth: true
                    }
                }
                Column {
                    visible: win.docPath.length === 0
                    anchors.centerIn: parent
                    spacing: Theme.s5
                    width: Math.min(420, parent.width - 48)
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 160; height: 210; radius: Theme.r2
                        color: Theme.elevated
                        border.width: 1
                        border.color: Theme.soften(win.iceHair, 0.70)
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTr("Open a PDF")
                        color: Theme.text
                        font.family: Theme.fUiTitle
                        font.pixelSize: Theme.tTitle
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: qsTr("The paper sits on a void desk. Ice page rail, contents, bookmarks. It remembers where you stopped. Drop a file here, or Open.")
                        color: Theme.textMuted
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tBody
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
            }
        }

        Text {
            Layout.fillWidth: true
            text: win.status
            color: Theme.textDim
            font.family: Theme.fUi
            font.pixelSize: Theme.tCaption
            elide: Text.ElideRight
        }
    }
}
