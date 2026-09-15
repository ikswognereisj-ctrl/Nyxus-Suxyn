pragma ComponentBehavior: Bound
// Nyxus Suxyn — CLOCK APP. GTK layout (World / Alarms / Stopwatch / Timer),
// widget glass. Bar clock overlay (Clock.qml) is untouched.
// Magma: firing alarm / Delete. Ice face for the time. Same clock.json.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

AppWindow {
    id: win

    titleText: qsTr("Clock")
    iconName: "nyxus-clock"
    subtitleText: win.localTime
    open: Bus.clockAppOpen
    onDismissed: Bus.clockAppOpen = false
    implicitWidth: 760
    implicitHeight: 600
    minimumSize: Qt.size(560, 480)

    property string page: "world"
    property var zones: ["UTC", "America/New_York", "Europe/London", "Asia/Tokyo"]
    property var zoneTimes: []
    property var alarms: []
    property string localTime: ""
    property string localDate: ""
    property string zoneDraft: ""
    property int alH: 7
    property int alM: 0
    property string alLabel: ""
    property var alDays: []
    property string banner: ""
    property var fired: ({})

    property bool swRun: false
    property double swBase: 0
    property double swAcc: 0
    property var laps: []

    property bool tmRun: false
    property double tmEnd: 0
    property int tmMin: 5
    property int tmSec: 0
    property int tmLeft: 0

    readonly property color ice: Theme.tokenAccentPrimary
    readonly property color iceHair: Theme.tokenAccentHairline
    readonly property color iceFocus: Theme.stateLayer[0]
    readonly property color magma: Theme.paintLayers.magma[5]
    readonly property var dayNames: ["M", "T", "W", "T", "F", "S", "S"]

    function io() { return (Quickshell.env("HOME") || "") + "/.config/quickshell/clock-io.py"; }
    function persist() {
        var doc = { zones: win.zones, alarms: win.alarms };
        saveProc.command = ["python3", win.io(), "save", JSON.stringify(doc)];
        saveProc.running = false;
        saveProc.running = true;
    }
    function load() {
        loadProc.running = false;
        loadProc.running = true;
        timesProc.running = false;
        timesProc.running = true;
    }
    function refreshTimes() {
        var cmd = ["python3", win.io(), "times"];
        for (var i = 0; i < win.zones.length; i++)
            cmd.push(win.zones[i]);
        timesProc.command = cmd;
        timesProc.running = false;
        timesProc.running = true;
    }
    function pad(n) { return (n < 10 ? "0" : "") + n; }
    function swMs() {
        var acc = win.swAcc;
        if (win.swRun) acc += Date.now() - win.swBase;
        return acc;
    }
    function swText() {
        var ms = win.swMs();
        var t = Math.floor(ms / 100);
        var tenths = t % 10;
        var secs = Math.floor(t / 10) % 60;
        var mins = Math.floor(t / 600);
        return win.pad(mins) + ":" + win.pad(secs) + "." + tenths;
    }
    function tmText() {
        var s = Math.max(0, win.tmLeft);
        return win.pad(Math.floor(s / 60)) + ":" + win.pad(s % 60);
    }
    function alarmKey(a) { return a.h + ":" + a.m + ":" + (a.label || ""); }
    function notify(title, body) {
        noteProc.command = ["notify-send", "-a", "Nyxus Clock", "-u", "critical", title, body];
        noteProc.running = false;
        noteProc.running = true;
        sndProc.running = false;
        sndProc.running = true;
    }
    function firesToday(a, weekday) {
        var days = a.days || [];
        if (!days.length) return true;
        return days.indexOf(weekday) >= 0;
    }
    function addAlarm() {
        var days = win.alDays.slice();
        win.alarms = win.alarms.concat([{
            h: win.alH, m: win.alM, label: win.alLabel, on: true, days: days
        }]);
        win.alLabel = "";
        alField.text = "";
        win.persist();
    }
    function removeAlarm(i) {
        var next = [];
        for (var n = 0; n < win.alarms.length; n++)
            if (n !== i) next.push(win.alarms[n]);
        win.alarms = next;
        win.persist();
    }
    function addZone() {
        var z = win.zoneDraft.trim();
        if (!z.length) return;
        var next = win.zones.slice();
        if (next.indexOf(z) < 0) next.push(z);
        win.zones = next;
        win.zoneDraft = "";
        zoneField.text = "";
        win.persist();
        win.refreshTimes();
    }
    function dropZone(z) {
        var next = [];
        for (var i = 0; i < win.zones.length; i++)
            if (win.zones[i] !== z) next.push(win.zones[i]);
        win.zones = next;
        win.persist();
        win.refreshTimes();
    }

    onOpenChanged: if (open) win.load()
    Component.onCompleted: win.load()

    IpcHandler {
        target: "clockapp"
        function ready(): string { return "ready"; }
        function engage(): string { Bus.clockAppOpen = true; win.load(); return "clock"; }
        function dismiss(): string { Bus.clockAppOpen = false; return "hidden"; }
    }

    Timer {
        interval: 200
        running: true
        repeat: true
        onTriggered: {
            var n = new Date();
            win.localTime = win.pad(n.getHours()) + ":" + win.pad(n.getMinutes()) + ":" + win.pad(n.getSeconds());
            win.localDate = Qt.formatDate(n, "dddd d MMMM");
            if (win.swRun)
                swLab.text = win.swText();
            if (win.tmRun) {
                win.tmLeft = Math.max(0, Math.ceil((win.tmEnd - Date.now()) / 1000));
                if (win.tmLeft <= 0) {
                    win.tmRun = false;
                    win.notify(qsTr("Timer"), qsTr("Time's up."));
                    win.banner = qsTr("Timer finished.");
                }
            }
            var wd = (n.getDay() + 6) % 7;
            var hh = n.getHours();
            var mm = n.getMinutes();
            if (n.getSeconds() === 0) {
                for (var i = 0; i < win.alarms.length; i++) {
                    var a = win.alarms[i];
                    if (!a.on) continue;
                    if (a.h !== hh || a.m !== mm) continue;
                    if (!win.firesToday(a, wd)) continue;
                    var k = win.alarmKey(a) + ":" + n.getDate();
                    if (win.fired[k]) continue;
                    var f = win.fired;
                    f[k] = true;
                    win.fired = f;
                    win.notify(qsTr("Alarm"), a.label || qsTr("Alarm"));
                    win.banner = a.label || qsTr("Alarm");
                }
            }
        }
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: win.refreshTimes()
    }

    Process {
        id: loadProc
        running: false
        command: ["python3", win.io(), "load"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    if (j.zones && j.zones.length) win.zones = j.zones;
                    win.alarms = j.alarms || [];
                    win.refreshTimes();
                } catch (e) { }
            }
        }
    }
    Process {
        id: timesProc
        running: false
        command: ["python3", win.io(), "times"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.zoneTimes = j.times || [];
                } catch (e) { }
            }
        }
    }
    Process { id: saveProc; running: false; command: ["python3", win.io(), "load"] }
    Process { id: noteProc; running: false; command: ["notify-send", "Nyxus Clock", ""] }
    Process {
        id: sndProc
        running: false
        command: ["sh", "-c", "nyxus-sound alert >/dev/null 2>&1 || nyxus-sfx alert >/dev/null 2>&1 || true"]
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
                text: qsTr("CLOCK")
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                font.weight: Theme.wStrong
                font.letterSpacing: Theme.trackMicro
            }
        }
        Text {
            visible: win.banner.length > 0
            text: win.banner
            color: win.magma
            font.family: Theme.fUi
            font.pixelSize: Theme.tBody
            font.weight: Theme.wStrong
        }

        Row {
            spacing: 6
            Ghost { mark: qsTr("World"); on: win.page === "world"; onTapped: win.page = "world" }
            Ghost { mark: qsTr("Alarms"); on: win.page === "alarms"; onTapped: win.page = "alarms" }
            Ghost { mark: qsTr("Stopwatch"); on: win.page === "stopwatch"; onTapped: win.page = "stopwatch" }
            Ghost { mark: qsTr("Timer"); on: win.page === "timer"; onTapped: win.page = "timer" }
        }

        // ── WORLD ──────────────────────────────────────────────────
        ColumnLayout {
            visible: win.page === "world"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.s4
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                radius: Theme.r2
                color: Theme.elevated
                border.width: 1
                border.color: Theme.soften(win.iceFocus, 0.75)
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 8
                    width: 10; height: 1
                    color: Theme.soften(Theme.teal, 0.38)
                }
                Column {
                    anchors.centerIn: parent
                    spacing: 2
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: win.localTime
                        color: Theme.text
                        font.family: Theme.fNum
                        font.pixelSize: 42
                        font.weight: Font.DemiBold
                        font.features: ({ "tnum": 1 })
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: win.localDate
                        color: Theme.textMuted
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tBody
                    }
                }
            }
            Flow {
                Layout.fillWidth: true
                spacing: Theme.s3
                Repeater {
                    model: win.zoneTimes
                    Rectangle {
                        required property var modelData
                        width: 220; height: 72
                        radius: Theme.r1
                        color: Theme.elevated
                        border.width: 1
                        border.color: Theme.soften(win.iceHair, 0.45)
                        Column {
                            anchors.fill: parent
                            anchors.margins: Theme.s4
                            spacing: 2
                            Text {
                                text: modelData.city
                                color: Theme.textMuted
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                            }
                            Text {
                                text: modelData.time
                                color: Theme.text
                                font.family: Theme.fNum
                                font.pixelSize: Theme.tHead
                                font.weight: Font.DemiBold
                                font.features: ({ "tnum": 1 })
                            }
                            Text {
                                text: modelData.band + "  ·  " + modelData.date
                                color: Theme.textDim
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                            }
                        }
                        Text {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            text: qsTr("×")
                            color: zHov.hovered ? win.magma : Theme.textDim
                            font.pixelSize: Theme.tCaption
                            HoverHandler { id: zHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: win.dropZone(modelData.zone) }
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: Theme.r1
                    color: Theme.soften(Theme.void_, 0.62)
                    border.width: 1
                    border.color: Theme.soften(win.iceHair, 0.45)
                    TextInput {
                        id: zoneField
                        anchors.fill: parent
                        anchors.margins: 8
                        color: Theme.text
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        onTextChanged: win.zoneDraft = text
                        Keys.onReturnPressed: win.addZone()
                    }
                    Text {
                        anchors.fill: zoneField
                        visible: zoneField.text.length === 0 && !zoneField.activeFocus
                        text: qsTr("Add a city, e.g. Europe/Berlin")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        enabled: false
                    }
                }
                Ghost { mark: qsTr("Add"); onTapped: win.addZone() }
            }
        }

        // ── ALARMS ─────────────────────────────────────────────────
        ColumnLayout {
            visible: win.page === "alarms"
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.s3
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s2
                Ghost { mark: "−"; onTapped: win.alH = (win.alH + 23) % 24 }
                Text {
                    text: win.pad(win.alH)
                    color: Theme.text
                    font.family: Theme.fNum
                    font.pixelSize: Theme.tHead
                    font.features: ({ "tnum": 1 })
                }
                Ghost { mark: "+"; onTapped: win.alH = (win.alH + 1) % 24 }
                Text { text: ":"; color: Theme.textDim; font.pixelSize: Theme.tHead }
                Ghost { mark: "−"; onTapped: win.alM = (win.alM + 59) % 60 }
                Text {
                    text: win.pad(win.alM)
                    color: Theme.text
                    font.family: Theme.fNum
                    font.pixelSize: Theme.tHead
                    font.features: ({ "tnum": 1 })
                }
                Ghost { mark: "+"; onTapped: win.alM = (win.alM + 1) % 60 }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: Theme.r1
                    color: Theme.soften(Theme.void_, 0.62)
                    border.width: 1
                    border.color: Theme.soften(win.iceHair, 0.45)
                    TextInput {
                        id: alField
                        anchors.fill: parent
                        anchors.margins: 8
                        color: Theme.text
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        onTextChanged: win.alLabel = text
                    }
                    Text {
                        anchors.fill: alField
                        visible: alField.text.length === 0 && !alField.activeFocus
                        text: qsTr("Label (optional)")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        enabled: false
                    }
                }
                Ghost { mark: qsTr("Add alarm"); onTapped: win.addAlarm() }
            }
            Row {
                spacing: 4
                Repeater {
                    model: 7
                    Ghost {
                        required property int index
                        mark: win.dayNames[index]
                        on: win.alDays.indexOf(index) >= 0
                        onTapped: {
                            var d = win.alDays.slice();
                            var i = d.indexOf(index);
                            if (i >= 0) d.splice(i, 1);
                            else d.push(index);
                            win.alDays = d;
                        }
                    }
                }
                Ghost { mark: qsTr("Weekdays"); onTapped: win.alDays = [0, 1, 2, 3, 4] }
                Ghost { mark: qsTr("Weekend"); onTapped: win.alDays = [5, 6] }
                Ghost { mark: qsTr("Every day"); onTapped: win.alDays = [] }
            }
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: alCol.height
                Column {
                    id: alCol
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: win.alarms
                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: alCol.width
                            height: 52
                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.r1
                                color: Theme.elevated
                                border.width: 1
                                border.color: Theme.soften(win.iceHair, 0.45)
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.s5
                                text: win.pad(modelData.h) + ":" + win.pad(modelData.m)
                                color: Theme.text
                                font.family: Theme.fNum
                                font.pixelSize: Theme.tHead
                                font.weight: Font.DemiBold
                                font.features: ({ "tnum": 1 })
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 88
                                text: (modelData.label || qsTr("Alarm"))
                                      + (modelData.on === false ? qsTr("  ·  off") : "")
                                color: Theme.textMuted
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tBody
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.s4
                                text: qsTr("Delete")
                                color: adHov.hovered ? Theme.paintLayers.magma[0] : win.magma
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                                font.weight: Theme.wStrong
                                HoverHandler { id: adHov; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: win.removeAlarm(index) }
                            }
                        }
                    }
                    Text {
                        visible: win.alarms.length === 0
                        text: qsTr("No alarms. Add one above.")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tBody
                        topPadding: Theme.s4
                    }
                }
            }
        }

        // ── STOPWATCH ──────────────────────────────────────────────
        ColumnLayout {
            visible: win.page === "stopwatch"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Item { Layout.fillHeight: true }
            Text {
                id: swLab
                Layout.alignment: Qt.AlignHCenter
                text: "00:00.0"
                color: Theme.text
                font.family: Theme.fNum
                font.pixelSize: 48
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
            }
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.s3
                Ghost {
                    mark: win.swRun ? qsTr("Stop") : qsTr("Start")
                    on: true
                    onTapped: {
                        if (win.swRun) {
                            win.swAcc += Date.now() - win.swBase;
                            win.swRun = false;
                            swLab.text = win.swText();
                        } else {
                            win.swBase = Date.now();
                            win.swRun = true;
                        }
                    }
                }
                Ghost {
                    mark: qsTr("Lap")
                    onTapped: {
                        var t = win.swText();
                        win.laps = [t].concat(win.laps);
                    }
                }
                Ghost {
                    mark: qsTr("Reset")
                    onTapped: {
                        win.swRun = false;
                        win.swAcc = 0;
                        win.laps = [];
                        swLab.text = "00:00.0";
                    }
                }
            }
            Repeater {
                model: win.laps
                Text {
                    required property var modelData
                    required property int index
                    Layout.alignment: Qt.AlignHCenter
                    text: (index + 1) + "  ·  " + modelData
                    color: Theme.textMuted
                    font.family: Theme.fNum
                    font.pixelSize: Theme.tBody
                    font.features: ({ "tnum": 1 })
                }
            }
            Item { Layout.fillHeight: true }
        }

        // ── TIMER ──────────────────────────────────────────────────
        ColumnLayout {
            visible: win.page === "timer"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Item { Layout.fillHeight: true }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: win.tmText()
                color: win.tmRun && win.tmLeft < 10 ? win.magma
                     : (win.tmRun && win.tmLeft < 60 ? Theme.gold : Theme.text)
                font.family: Theme.fNum
                font.pixelSize: 48
                font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 })
            }
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.s3
                Text { text: qsTr("min"); color: Theme.textDim; font.pixelSize: Theme.tCaption; anchors.verticalCenter: parent.verticalCenter }
                Ghost { mark: "−"; onTapped: win.tmMin = Math.max(0, win.tmMin - 1) }
                Text {
                    text: String(win.tmMin)
                    color: Theme.text
                    font.family: Theme.fNum
                    font.pixelSize: Theme.tHead
                    anchors.verticalCenter: parent.verticalCenter
                }
                Ghost { mark: "+"; onTapped: win.tmMin = Math.min(180, win.tmMin + 1) }
                Text { text: qsTr("sec"); color: Theme.textDim; font.pixelSize: Theme.tCaption; anchors.verticalCenter: parent.verticalCenter }
                Ghost { mark: "−"; onTapped: win.tmSec = Math.max(0, win.tmSec - 5) }
                Text {
                    text: String(win.tmSec)
                    color: Theme.text
                    font.family: Theme.fNum
                    font.pixelSize: Theme.tHead
                    anchors.verticalCenter: parent.verticalCenter
                }
                Ghost { mark: "+"; onTapped: win.tmSec = Math.min(55, win.tmSec + 5) }
            }
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.s3
                Ghost {
                    mark: win.tmRun ? qsTr("Stop") : qsTr("Start")
                    on: true
                    onTapped: {
                        if (win.tmRun) {
                            win.tmRun = false;
                        } else {
                            var sec = win.tmMin * 60 + win.tmSec;
                            if (sec <= 0) sec = 60;
                            win.tmEnd = Date.now() + sec * 1000;
                            win.tmLeft = sec;
                            win.tmRun = true;
                        }
                    }
                }
                Ghost { mark: "+1"; onTapped: win.tmMin += 1 }
                Ghost { mark: "+5"; onTapped: win.tmMin += 5 }
                Ghost { mark: "+10"; onTapped: win.tmMin += 10 }
            }
            Item { Layout.fillHeight: true }
        }
    }
}
