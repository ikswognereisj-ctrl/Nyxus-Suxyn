pragma ComponentBehavior: Bound
// Nyxus Suxyn — CALENDAR. GTK layout (month grid + day rail), widget
// glass. Same agenda.json as GTK, plus Reminders so the widget calendar
// stays tied. Magma is Delete only. Today is the widget stone (elevated
// + glacier[0] ring). Category colour is a spine/dot, never a fill.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

AppWindow {
    id: win

    titleText: qsTr("Calendar")
    iconName: "nyxus-calendar"
    subtitleText: win.rangeText
    open: Bus.calendarOpen
    onDismissed: Bus.calendarOpen = false
    implicitWidth: 1020
    implicitHeight: 640
    minimumSize: Qt.size(860, 520)

    property string view: "month"
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()
    property int selYear: new Date().getFullYear()
    property int selMonth: new Date().getMonth()
    property int selDay: new Date().getDate()
    property var events: []
    property string query: ""
    property string draft: ""

    readonly property color ice: Theme.tokenAccentPrimary
    readonly property color iceHair: Theme.tokenAccentHairline
    readonly property color iceFocus: Theme.paintLayers.glacier[0]
    readonly property color magma: Theme.paintLayers.magma[5]
    readonly property var monthNames: ["January", "February", "March", "April",
                                       "May", "June", "July", "August",
                                       "September", "October", "November", "December"]
    readonly property var cats: [
        { id: "General", colour: "#4f7fa6" },
        { id: "Work", colour: "#5b6cff" },
        { id: "Personal", colour: "#c45ad4" },
        { id: "Health", colour: "#3ecf8e" },
        { id: "Birthday", colour: "#ae206c" },
        { id: "Travel", colour: "#3d8fd6" },
        { id: "Urgent", colour: "#ff2d55" }
    ]
    readonly property string rangeText: win.monthNames[win.viewMonth] + " " + win.viewYear
    readonly property var now: new Date()

    function io() { return (Quickshell.env("HOME") || "") + "/.config/quickshell/calendar-io.py"; }
    function daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate(); }
    function firstOffset(y, m) { return (new Date(y, m, 1).getDay() + 6) % 7; }
    function iso(y, m, d) {
        var mm = (m + 1) < 10 ? "0" + (m + 1) : String(m + 1);
        var dd = d < 10 ? "0" + d : String(d);
        return y + "-" + mm + "-" + dd;
    }
    function padRange() {
        var off = win.firstOffset(win.viewYear, win.viewMonth);
        var start = new Date(win.viewYear, win.viewMonth, 1 - off);
        var end = new Date(start.getFullYear(), start.getMonth(), start.getDate() + 41);
        return [win.iso(start.getFullYear(), start.getMonth(), start.getDate()),
                win.iso(end.getFullYear(), end.getMonth(), end.getDate())];
    }
    function refresh() {
        var r = win.padRange();
        rangeProc.command = ["python3", win.io(), "range", r[0], r[1]];
        rangeProc.running = false;
        rangeProc.running = true;
    }
    function eventsOn(y, m, d) {
        var key = win.iso(y, m, d);
        var q = win.query.trim().toLowerCase();
        var out = [];
        for (var i = 0; i < win.events.length; i++) {
            if (win.events[i].iso !== key) continue;
            if (q.length && String(win.events[i].title).toLowerCase().indexOf(q) < 0)
                continue;
            out.push(win.events[i]);
        }
        var rem = Reminders.forDay(y, m, d);
        for (var j = 0; j < rem.length; j++) {
            var t = rem[j].text || "";
            if (q.length && t.toLowerCase().indexOf(q) < 0) continue;
            var dup = false;
            for (var k = 0; k < out.length; k++)
                if (out[k].title === t) { dup = true; break; }
            if (dup) continue;
            out.push({
                id: rem[j].id, title: t, category: "General",
                colour: "#4f7fa6", iso: key, allDay: true,
                done: !!rem[j].done, kind: rem[j].kind || "reminder",
                source: "reminders"
            });
        }
        return out;
    }
    function selEvents() { return win.eventsOn(win.selYear, win.selMonth, win.selDay); }
    function shift(dir) {
        var m = win.viewMonth + dir;
        var y = win.viewYear;
        if (m < 0) { m = 11; y--; }
        if (m > 11) { m = 0; y++; }
        win.viewMonth = m;
        win.viewYear = y;
        win.refresh();
    }
    function goToday() {
        var n = new Date();
        win.viewYear = n.getFullYear();
        win.viewMonth = n.getMonth();
        win.selYear = n.getFullYear();
        win.selMonth = n.getMonth();
        win.selDay = n.getDate();
        win.refresh();
    }
    function pickDay(y, m, d) {
        win.selYear = y; win.selMonth = m; win.selDay = d;
        if (m !== win.viewMonth || y !== win.viewYear) {
            win.viewYear = y; win.viewMonth = m;
            win.refresh();
        }
    }
    function addDraft() {
        var t = win.draft.trim();
        if (!t.length) return;
        var day = win.iso(win.selYear, win.selMonth, win.selDay);
        addProc.command = ["python3", win.io(), "add", t, day];
        addProc.running = false;
        addProc.running = true;
        var ts = new Date(win.selYear, win.selMonth, win.selDay, 9, 0).getTime();
        Reminders.add(ts, t, "event");
        win.draft = "";
        draftField.text = "";
    }
    function removeEvent(ev) {
        if (!ev || !ev.id) return;
        if (ev.source === "reminders")
            Reminders.remove(ev.id);
        else {
            delProc.command = ["python3", win.io(), "delete", ev.id];
            delProc.running = false;
            delProc.running = true;
        }
        win.refresh();
    }

    onOpenChanged: if (open) win.refresh()
    onVisibleChanged: if (visible) win.refresh()

    IpcHandler {
        target: "calendar"
        function ready(): string { return "ready"; }
        function engage(): string { Bus.calendarOpen = true; win.refresh(); return "calendar"; }
        function dismiss(): string { Bus.calendarOpen = false; return "hidden"; }
    }

    Process {
        id: rangeProc
        running: false
        command: ["python3", win.io(), "range", "2026-01-01", "2026-01-31"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.events = j.events || [];
                } catch (e) { }
            }
        }
    }
    Process { id: addProc; running: false; command: ["python3", win.io(), "range", "2026-01-01", "2026-01-31"]
        stdout: StdioCollector { onStreamFinished: win.refresh() } }
    Process { id: delProc; running: false; command: ["python3", win.io(), "range", "2026-01-01", "2026-01-31"]
        stdout: StdioCollector { onStreamFinished: win.refresh() } }

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

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s3
            Row {
                spacing: Theme.s3
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 7; height: 7; radius: 3.5
                    color: win.magma
                }
                Text {
                    text: qsTr("CALENDAR")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    font.weight: Theme.wStrong
                    font.letterSpacing: Theme.trackMicro
                }
            }
            Ghost { mark: "‹"; onTapped: win.shift(-1) }
            Ghost { mark: "›"; onTapped: win.shift(1) }
            Ghost { mark: qsTr("Today"); onTapped: win.goToday() }
            Text {
                Layout.fillWidth: true
                text: win.rangeText
                color: Theme.text
                font.family: Theme.fUiTitle
                font.pixelSize: Theme.tHead
                font.weight: Font.DemiBold
            }
            Ghost { mark: qsTr("Month"); on: win.view === "month"; onTapped: win.view = "month" }
            Ghost { mark: qsTr("Week"); on: win.view === "week"; onTapped: win.view = "week" }
            Ghost { mark: qsTr("Day"); on: win.view === "day"; onTapped: win.view = "day" }
            Ghost { mark: qsTr("Agenda"); on: win.view === "agenda"; onTapped: win.view = "agenda" }
            Rectangle {
                Layout.preferredWidth: 160
                Layout.preferredHeight: 32
                radius: Theme.r1
                color: Theme.soften(Theme.void_, 0.62)
                border.width: 1
                border.color: Theme.soften(win.iceHair, 0.45)
                TextInput {
                    id: searchField
                    anchors.fill: parent
                    anchors.margins: 8
                    color: Theme.text
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    clip: true
                    onTextChanged: win.query = text
                }
                Text {
                    anchors.fill: searchField
                    visible: searchField.text.length === 0 && !searchField.activeFocus
                    text: qsTr("Search events")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    enabled: false
                }
            }
            Ghost { mark: qsTr("＋ New event"); onTapped: win.addDraft() }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.s4

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4
                visible: win.view === "month"
                RowLayout {
                    Layout.fillWidth: true
                    Repeater {
                        model: ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
                        Text {
                            required property var modelData
                            Layout.fillWidth: true
                            text: modelData
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            font.weight: Theme.wStrong
                            font.letterSpacing: Theme.trackMicro
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 7
                    rowSpacing: 4
                    columnSpacing: 4
                    Repeater {
                        model: 42
                        delegate: Item {
                            id: cell
                            required property int index
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            readonly property int off: win.firstOffset(win.viewYear, win.viewMonth)
                            readonly property int cy: {
                                var s = new Date(win.viewYear, win.viewMonth, 1 - cell.off + cell.index);
                                return s.getFullYear();
                            }
                            readonly property int cm: {
                                var s = new Date(win.viewYear, win.viewMonth, 1 - cell.off + cell.index);
                                return s.getMonth();
                            }
                            readonly property int cd: {
                                var s = new Date(win.viewYear, win.viewMonth, 1 - cell.off + cell.index);
                                return s.getDate();
                            }
                            readonly property bool inMonth: cm === win.viewMonth && cy === win.viewYear
                            readonly property bool isToday: cy === win.now.getFullYear()
                                && cm === win.now.getMonth() && cd === win.now.getDate()
                            readonly property bool isSel: cy === win.selYear && cm === win.selMonth && cd === win.selDay
                            readonly property bool rest: {
                                var s = new Date(cell.cy, cell.cm, cell.cd);
                                return s.getDay() === 0 || s.getDay() === 6;
                            }
                            readonly property var dayEv: win.eventsOn(cy, cm, cd)
                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.r1
                                color: cell.isToday ? Theme.elevated
                                     : (cellHov.hovered ? Theme.soften(Theme.elevated, 0.55) : "transparent")
                                border.width: (cell.isToday || cell.isSel || cellHov.hovered) ? 1 : 0
                                border.color: cell.isToday ? win.iceFocus
                                              : (cell.isSel ? Theme.soften(win.iceHair, 0.85)
                                                 : Theme.soften(win.ice, 0.55))
                            }
                            Rectangle {
                                visible: cell.isToday
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 4
                                width: 8; height: 1; radius: 0.5
                                color: Theme.soften(Theme.teal, 0.38)
                            }
                            Text {
                                x: Theme.s3; y: 6
                                text: cell.cd
                                color: cell.isToday ? Theme.teal
                                     : (cell.inMonth ? (cell.rest ? Theme.textDim : Theme.text) : Theme.textDim)
                                opacity: cell.inMonth ? 1 : 0.4
                                font.family: Theme.fNum
                                font.pixelSize: Theme.tBody
                                font.weight: cell.isToday ? Font.DemiBold : Font.Normal
                                font.features: ({ "tnum": 1 })
                            }
                            Row {
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                anchors.margins: 6
                                spacing: 3
                                Repeater {
                                    model: Math.min(3, cell.dayEv.length)
                                    Rectangle {
                                        required property int index
                                        width: 6; height: 6; radius: 3
                                        color: cell.dayEv[index].colour || win.iceHair
                                    }
                                }
                            }
                            HoverHandler { id: cellHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: win.pickDay(cell.cy, cell.cm, cell.cd) }
                        }
                    }
                }
            }

            Flickable {
                visible: win.view !== "month"
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: listCol.height
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: listCol
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: {
                            if (win.view === "day") return win.selEvents();
                            var out = [];
                            var seen = {};
                            for (var i = 0; i < win.events.length; i++) {
                                var e = win.events[i];
                                if (win.query.trim().length
                                    && String(e.title).toLowerCase().indexOf(win.query.trim().toLowerCase()) < 0)
                                    continue;
                                if (win.view === "week") {
                                    var dt = new Date(win.selYear, win.selMonth, win.selDay);
                                    var ws = new Date(dt);
                                    ws.setDate(dt.getDate() - ((dt.getDay() + 6) % 7));
                                    var we = new Date(ws);
                                    we.setDate(ws.getDate() + 6);
                                    var ed = new Date(e.iso + "T00:00:00");
                                    if (ed < ws || ed > we) continue;
                                }
                                out.push(e);
                            }
                            return out;
                        }
                        delegate: Item {
                            required property var modelData
                            width: listCol.width
                            height: 44
                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.r1
                                color: Theme.elevated
                                border.width: 1
                                border.color: Theme.soften(win.iceHair, 0.45)
                            }
                            Rectangle {
                                width: 3; height: parent.height - 10
                                radius: 1
                                anchors.verticalCenter: parent.verticalCenter
                                x: 8
                                color: modelData.colour || win.iceHair
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 20
                                anchors.right: parent.right
                                text: modelData.title
                                color: Theme.text
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tBody
                                elide: Text.ElideRight
                            }
                        }
                    }
                    Text {
                        visible: listCol.children.length <= 1
                        text: qsTr("Nothing in this span.")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tBody
                        leftPadding: Theme.s4
                        topPadding: Theme.s5
                    }
                }
            }

            Item {
                Layout.preferredWidth: 258
                Layout.maximumWidth: 258
                Layout.fillHeight: true
                ColumnLayout {
                    anchors.fill: parent
                    spacing: Theme.s3
                    Text {
                        Layout.fillWidth: true
                        text: Qt.formatDate(new Date(win.selYear, win.selMonth, win.selDay), "dddd d MMMM")
                        color: Theme.text
                        font.family: Theme.fUiTitle
                        font.pixelSize: Theme.tHead
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.s2
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: Theme.r1
                            color: Theme.soften(Theme.void_, 0.62)
                            border.width: 1
                            border.color: Theme.soften(win.iceHair, 0.45)
                            TextInput {
                                id: draftField
                                anchors.fill: parent
                                anchors.margins: 8
                                color: Theme.text
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                                clip: true
                                onTextChanged: win.draft = text
                                Keys.onReturnPressed: win.addDraft()
                            }
                            Text {
                                anchors.fill: draftField
                                visible: draftField.text.length === 0 && !draftField.activeFocus
                                text: qsTr("Quick add an event…")
                                color: Theme.textDim
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                                enabled: false
                            }
                        }
                        Ghost { mark: qsTr("Add"); onTapped: win.addDraft() }
                    }
                    Flickable {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: evCol.height
                        Column {
                            id: evCol
                            width: parent.width
                            spacing: 4
                            Repeater {
                                model: win.selEvents()
                                delegate: Item {
                                    required property var modelData
                                    width: evCol.width
                                    height: 48
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Theme.r1
                                        color: Theme.elevated
                                        border.width: 1
                                        border.color: Theme.soften(win.iceHair, 0.45)
                                    }
                                    Rectangle {
                                        width: 3; height: parent.height - 12
                                        radius: 1
                                        x: 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: modelData.colour || win.iceHair
                                    }
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 18
                                        anchors.right: delMark.left
                                        spacing: 2
                                        Text {
                                            width: parent.width
                                            text: modelData.title
                                            color: Theme.text
                                            font.family: Theme.fUi
                                            font.pixelSize: Theme.tBody
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            text: modelData.category || qsTr("General")
                                            color: Theme.textDim
                                            font.family: Theme.fUi
                                            font.pixelSize: Theme.tCaption
                                        }
                                    }
                                    Text {
                                        id: delMark
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.right: parent.right
                                        anchors.rightMargin: Theme.s3
                                        text: qsTr("Delete")
                                        color: delHov.hovered ? Theme.paintLayers.magma[0] : win.magma
                                        font.family: Theme.fUi
                                        font.pixelSize: Theme.tCaption
                                        font.weight: Theme.wStrong
                                        HoverHandler { id: delHov; cursorShape: Qt.PointingHandCursor }
                                        TapHandler { onTapped: win.removeEvent(modelData) }
                                    }
                                }
                            }
                            Text {
                                visible: win.selEvents().length === 0
                                text: qsTr("Nothing on this day.")
                                color: Theme.textDim
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tBody
                                topPadding: Theme.s4
                            }
                        }
                    }
                    Text {
                        text: qsTr("CATEGORIES")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        font.weight: Theme.wStrong
                        font.letterSpacing: Theme.trackMicro
                    }
                    Repeater {
                        model: win.cats
                        Row {
                            required property var modelData
                            spacing: 8
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 8; height: 8; radius: 4
                                color: modelData.colour
                            }
                            Text {
                                text: modelData.id
                                color: Theme.textMuted
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                            }
                        }
                    }
                }
            }
        }
    }
}
