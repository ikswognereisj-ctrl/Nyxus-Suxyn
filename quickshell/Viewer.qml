pragma ComponentBehavior: Bound
// Nyxus Suxyn — VIEWER. GTK layout (void stage + ice filmstrip), widget
// glass. Magma is Trash only. Picture fills the well. Tape/Media untouched.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

AppWindow {
    id: win

    titleText: qsTr("Viewer")
    iconName: "nyxus-viewer"
    subtitleText: win.currentName.length ? win.currentName : qsTr("Open a picture")
    open: Bus.viewerOpen
    onDismissed: {
        win.persist();
        Bus.viewerOpen = false;
    }
    implicitWidth: 1150
    implicitHeight: 760
    minimumSize: Qt.size(720, 480)

    property var files: []
    property int index: 0
    property string folder: ""
    property bool stripOn: true
    property bool infoOn: false
    property string zoom: "fit"
    property int interval: 4
    property int rot: 0
    property bool playing: false
    property string status: qsTr("Open a picture to begin.")
    property int bytes: 0
    property int imgW: 0
    property int imgH: 0
    property var exif: ({})

    readonly property color ice: Theme.tokenAccentPrimary
    readonly property color iceHair: Theme.tokenAccentHairline
    readonly property color magma: Theme.paintLayers.magma[5]
    readonly property string current: (win.files.length && win.index >= 0 && win.index < win.files.length)
                                      ? String(win.files[win.index]) : ""
    readonly property string currentName: {
        var p = win.current;
        if (!p.length) return "";
        var i = p.lastIndexOf("/");
        return i >= 0 ? p.substring(i + 1) : p;
    }

    function io() { return (Quickshell.env("HOME") || "") + "/.config/quickshell/viewer-io.py"; }
    function fileUrl(p) {
        var s = String(p || "");
        if (!s.length) return "";
        if (s.indexOf("file:") === 0) return s;
        return "file://" + s;
    }
    function applyList(j) {
        win.files = j.files || [];
        win.index = j.index || 0;
        win.folder = j.folder || "";
        if (j.strip !== undefined) win.stripOn = !!j.strip;
        if (j.info !== undefined) win.infoOn = !!j.info;
        if (j.zoom) win.zoom = j.zoom;
        if (j.interval) win.interval = j.interval;
        if (j.rot !== undefined) win.rot = j.rot;
        if (win.current.length) {
            win.status = (win.index + 1) + " / " + win.files.length + "  ·  " + win.folder;
            statProc.command = ["python3", win.io(), "stat", win.current];
            statProc.running = false;
            statProc.running = true;
        } else
            win.status = qsTr("Open a picture to begin.");
        win.persist();
    }
    function openPath(p) {
        if (!p || !p.length) return;
        openProc.command = ["python3", win.io(), "open", p];
        openProc.running = false;
        openProc.running = true;
    }
    function persist() {
        saveProc.command = ["python3", win.io(), "save",
                            win.current || "",
                            win.stripOn ? "1" : "0",
                            win.infoOn ? "1" : "0",
                            win.zoom,
                            String(win.interval),
                            String(win.rot)];
        saveProc.running = false;
        saveProc.running = true;
    }
    function step(d) {
        if (!win.files.length) return;
        win.index = (win.index + d + win.files.length) % win.files.length;
        win.rot = 0;
        win.status = (win.index + 1) + " / " + win.files.length + "  ·  " + win.folder;
        statProc.command = ["python3", win.io(), "stat", win.current];
        statProc.running = false;
        statProc.running = true;
        win.persist();
    }
    function pick() {
        pickProc.running = false;
        pickProc.running = true;
    }
    function trashCurrent() {
        if (!win.current.length) return;
        trashProc.command = ["python3", win.io(), "trash", win.current];
        trashProc.running = false;
        trashProc.running = true;
    }
    function wallCurrent() {
        if (!win.current.length) return;
        wallProc.command = ["python3", win.io(), "wallpaper", win.current];
        wallProc.running = false;
        wallProc.running = true;
    }
    function cycleRate() {
        var ladder = [2, 4, 8, 15, 30];
        var i = ladder.indexOf(win.interval);
        win.interval = ladder[(i + 1) % ladder.length];
        if (win.playing) { slideTimer.stop(); slideTimer.start(); }
        win.persist();
    }

    onOpenChanged: if (open && win.files.length === 0) {
        lastProc.running = false;
        lastProc.running = true;
    }

    IpcHandler {
        target: "viewer"
        function ready(): string { return "ready"; }
        function engage(): string {
            Bus.viewerOpen = true;
            if (win.files.length === 0) {
                lastProc.running = false;
                lastProc.running = true;
            }
            return "viewer";
        }
        function at(path: string): string {
            Bus.viewerOpen = true;
            win.openPath(path);
            return path;
        }
        function dismiss(): string { Bus.viewerOpen = false; return "hidden"; }
    }

    Timer {
        id: slideTimer
        interval: Math.max(2, win.interval) * 1000
        repeat: true
        running: win.playing && win.files.length > 1
        onTriggered: win.step(1)
    }

    Process {
        id: lastProc
        running: false
        command: ["python3", win.io(), "last"]
        onExited: function (code) { if (code !== 0) console.warn("[Viewer] last pictures read exited code " + code); }
        stdout: StdioCollector {
            onStreamFinished: {
                try { win.applyList(JSON.parse(String(this.text))); }
                catch (e) { win.status = qsTr("Open a picture to begin."); }
            }
        }
    }
    Process {
        id: openProc
        running: false
        command: ["python3", win.io(), "last"]
        onExited: function (code) { if (code !== 0) console.warn("[Viewer] picture list exited code " + code); }
        stdout: StdioCollector {
            onStreamFinished: {
                try { win.applyList(JSON.parse(String(this.text))); }
                catch (e) { }
            }
        }
    }
    Process {
        id: pickProc
        running: false
        command: ["python3", win.io(), "pick"]
        onExited: function (code) { if (code !== 0) console.warn("[Viewer] file pick exited code " + code); }
        stdout: StdioCollector {
            onStreamFinished: {
                try { win.applyList(JSON.parse(String(this.text))); }
                catch (e) { }
            }
        }
    }
    Process {
        id: statProc
        running: false
        command: ["python3", win.io(), "last"]
        onExited: function (code) { if (code !== 0) console.warn("[Viewer] picture info exited code " + code); }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.bytes = j.bytes || 0;
                    if (j.width) win.imgW = j.width;
                    if (j.height) win.imgH = j.height;
                    win.exif = j.exif || {};
                } catch (e) { }
            }
        }
    }
    Process { id: saveProc; running: false; command: ["python3", win.io(), "last"]; onExited: function (code) { if (code !== 0) console.warn("[Viewer] save exited code " + code); } }
    Process {
        id: trashProc
        running: false
        command: ["python3", win.io(), "last"]
        onExited: function (code) { if (code !== 0) console.warn("[Viewer] trash exited code " + code); }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    if (j.ok) {
                        win.files = j.files || [];
                        if (win.index >= win.files.length)
                            win.index = Math.max(0, win.files.length - 1);
                        win.status = win.files.length
                                     ? ((win.index + 1) + " / " + win.files.length)
                                     : qsTr("No pictures in that folder.");
                    }
                } catch (e) { }
            }
        }
    }
    Process {
        id: wallProc
        running: false
        command: ["python3", win.io(), "last"]
        onExited: function (code) { if (code !== 0) console.warn("[Viewer] wallpaper set exited code " + code); }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.status = j.ok ? qsTr("Wallpaper set.") : qsTr("Wallpaper did not apply.");
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
        implicitWidth: Math.max(36, lab.implicitWidth + 18)
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
            color: g.danger ? (gh.hovered ? Theme.paintLayers.magma[0] : win.magma) : Theme.text
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
                text: qsTr("VIEWER")
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                font.weight: Theme.wStrong
                font.letterSpacing: Theme.trackMicro
            }
        }
        Text {
            text: qsTr("Gallery")
            color: Theme.text
            font.family: Theme.fUiTitle
            font.pixelSize: Theme.tDisplay
            font.weight: Font.DemiBold
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s2
            Text {
                Layout.fillWidth: true
                text: win.currentName.length ? win.currentName : qsTr("No picture")
                color: Theme.text
                font.family: Theme.fUi
                font.pixelSize: Theme.tBody
                font.weight: Theme.wStrong
                elide: Text.ElideMiddle
            }
            Ghost { mark: "◀"; onTapped: win.step(-1) }
            Ghost { mark: "▶"; onTapped: win.step(1) }
            Ghost { mark: "−"; onTapped: win.zoom = "fit" }
            Ghost { mark: qsTr("Fit"); on: win.zoom === "fit"; onTapped: win.zoom = "fit" }
            Ghost { mark: qsTr("1:1"); on: win.zoom === "actual"; onTapped: win.zoom = "actual" }
            Ghost { mark: "+"; onTapped: win.zoom = "actual" }
            Ghost { mark: "⟳"; onTapped: { win.rot = (win.rot + 90) % 360; win.persist(); } }
            Ghost { mark: qsTr("Slideshow"); on: win.playing; onTapped: win.playing = !win.playing }
            Ghost { mark: win.interval + "s"; onTapped: win.cycleRate() }
            Ghost { mark: qsTr("Info"); on: win.infoOn; onTapped: { win.infoOn = !win.infoOn; win.persist(); } }
            Ghost { mark: qsTr("Strip"); on: win.stripOn; onTapped: { win.stripOn = !win.stripOn; win.persist(); } }
            Ghost { mark: qsTr("Open"); onTapped: win.pick() }
            Ghost { mark: qsTr("Wallpaper"); onTapped: win.wallCurrent() }
            Ghost { mark: qsTr("Trash"); danger: true; onTapped: win.trashCurrent() }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Item {
                id: stage
                Layout.fillWidth: true
                Layout.fillHeight: true
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.r2
                    color: Theme.soften(Theme.void_, 0.72)
                    border.width: 1
                    border.color: Theme.soften(win.iceHair, 0.30)
                }
                Flickable {
                    id: picFlick
                    visible: win.current.length > 0
                    anchors.fill: parent
                    clip: true
                    contentWidth: Math.max(width, pic.width)
                    contentHeight: Math.max(height, pic.height)
                    boundsBehavior: Flickable.StopAtBounds
                    Image {
                        id: pic
                        source: win.fileUrl(win.current)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                        smooth: true
                        rotation: win.rot
                        width: win.zoom === "actual" ? (pic.implicitWidth || stage.width)
                                                     : Math.min(stage.width, pic.implicitWidth || stage.width)
                        height: win.zoom === "actual" ? (pic.implicitHeight || stage.height)
                                                      : Math.min(stage.height, pic.implicitHeight || stage.height)
                        x: Math.max(0, (picFlick.width - width) / 2)
                        y: Math.max(0, (picFlick.height - height) / 2)
                        onStatusChanged: if (status === Image.Ready) {
                            win.imgW = implicitWidth;
                            win.imgH = implicitHeight;
                        }
                    }
                }
                Column {
                    visible: win.current.length === 0
                    anchors.centerIn: parent
                    spacing: Theme.s5
                    width: Math.min(420, parent.width - 48)
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTr("GALLERY")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        font.weight: Theme.wStrong
                        font.letterSpacing: Theme.trackMicro
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTr("Open a picture")
                        color: Theme.text
                        font.family: Theme.fUiTitle
                        font.pixelSize: Theme.tTitle
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: qsTr("The photograph fills the well. The folder rides an ice filmstrip. Arrows, slideshow, EXIF. Trash never unlinks.")
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

            Item {
                visible: win.infoOn && win.current.length > 0
                Layout.preferredWidth: 240
                Layout.maximumWidth: 240
                Layout.fillHeight: true
                Column {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.s4
                    spacing: Theme.s3
                    Text {
                        text: qsTr("INFO")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        font.weight: Theme.wStrong
                        font.letterSpacing: Theme.trackMicro
                    }
                    Text {
                        width: parent.width
                        text: win.currentName
                        color: Theme.text
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tBody
                        wrapMode: Text.WrapAnywhere
                    }
                    Text {
                        text: win.imgW && win.imgH ? (win.imgW + " × " + win.imgH) : "—"
                        color: Theme.textMuted
                        font.family: Theme.fNum
                        font.pixelSize: Theme.tCaption
                        font.features: ({ "tnum": 1 })
                    }
                    Text {
                        text: win.bytes ? (Math.round(win.bytes / 1024) + " KiB") : "—"
                        color: Theme.textDim
                        font.family: Theme.fNum
                        font.pixelSize: Theme.tCaption
                        font.features: ({ "tnum": 1 })
                    }
                    Text {
                        visible: !!(win.exif.Make || win.exif.Model)
                        width: parent.width
                        text: [win.exif.Make, win.exif.Model].filter(function (s) { return s; }).join(" ")
                        color: Theme.textMuted
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        visible: !!(win.exif.DateTimeOriginal || win.exif.DateTime)
                        width: parent.width
                        text: win.exif.DateTimeOriginal || win.exif.DateTime || ""
                        color: Theme.textDim
                        font.family: Theme.fNum
                        font.pixelSize: Theme.tCaption
                    }
                    Text {
                        visible: !!(win.exif.LensModel || win.exif.FocalLength || win.exif.FNumber)
                        width: parent.width
                        text: [win.exif.LensModel, win.exif.FocalLength, win.exif.FNumber ? ("f/" + win.exif.FNumber) : ""].filter(function (s) { return s; }).join(" · ")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        visible: win.exif.ISOSpeedRatings !== undefined && String(win.exif.ISOSpeedRatings).length > 0
                        text: "ISO " + win.exif.ISOSpeedRatings
                        color: Theme.textDim
                        font.family: Theme.fNum
                        font.pixelSize: Theme.tCaption
                    }
                }
            }
        }

        Flickable {
            visible: win.stripOn
            Layout.fillWidth: true
            Layout.preferredHeight: 78
            clip: true
            contentWidth: stripRow.width
            contentHeight: height
            boundsBehavior: Flickable.StopAtBounds
            Row {
                id: stripRow
                height: 70
                spacing: 6
                Repeater {
                    model: win.files
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: 64; height: 70
                        readonly property bool current: index === win.index
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.r1
                            color: Theme.elevated
                            border.width: 1
                            border.color: Theme.soften(win.iceHair, current ? 0.95 : 0.40)
                        }
                        Image {
                            anchors.fill: parent
                            anchors.margins: 4
                            source: win.fileUrl(modelData)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: true
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: { win.index = index; win.persist(); } }
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
            elide: Text.ElideMiddle
        }
    }
}
