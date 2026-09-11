pragma ComponentBehavior: Bound
// Nyxus Suxyn — MONITOR. Four AppCard instruments, history, cores, process table.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

AppWindow {
    id: win

    titleText: qsTr("Monitor")
    iconName: "nyxus-sysmon-gtk"
    subtitleText: win.host
    open: Bus.sysmonOpen
    onDismissed: Bus.sysmonOpen = false
    implicitWidth: 1100
    implicitHeight: 720
    minimumSize: Qt.size(860, 560)

    property string host: ""
    property string uptime: ""
    property real cpu: 0
    property var mem: ({})
    property var net: ({})
    property var disk: ({})
    property var procs: []
    property var cores: []
    property var load: []
    property int ncpu: 0
    property int nproc: 0
    property bool live: false
    property var cpuHist: []
    property var memHist: []
    property var diskHist: []
    property var netHist: []
    property int armedPid: -1

    readonly property color ice: Theme.tokenAccentPrimary
    readonly property color iceHair: Theme.tokenAccentHairline
    readonly property color magma: Theme.paintLayers.magma[5]
    readonly property int refreshSecs: Math.max(1, SettingsStore.numberValue("app_mon_refresh_secs", 2))
    readonly property int graphSpan: Math.max(1, SettingsStore.numberValue("app_mon_graph_span", 60))
    readonly property int histCap: Math.max(2, Math.round(win.graphSpan / win.refreshSecs))
    readonly property bool wantCores: SettingsStore.boolValue("app_mon_per_core", true)
    readonly property bool showCores: win.wantCores && win.cores.length > 0
    readonly property bool netBits: SettingsStore.stringValue("app_mon_net_unit", "byte/s") === "bit/s"
    readonly property bool fresh: win.live

    function io() { return (Quickshell.env("HOME") || "") + "/.config/quickshell/sysmon-io.py"; }
    function refresh() { snap.running = false; snap.running = true; }

    function kb(n) {
        n = Number(n) || 0;
        if (n >= 1024 * 1024) return (n / (1024 * 1024)).toFixed(1) + " GiB";
        if (n >= 1024) return Math.round(n / 1024) + " MiB";
        return Math.round(n) + " KiB";
    }

    function bytes(n) {
        n = Number(n) || 0;
        if (n >= 1024 * 1024 * 1024) return (n / (1024 * 1024 * 1024)).toFixed(1) + " GiB";
        if (n >= 1024 * 1024) return (n / (1024 * 1024)).toFixed(1) + " MiB";
        if (n >= 1024) return Math.round(n / 1024) + " KiB";
        return Math.round(n) + " B";
    }

    function rateParts(bps) {
        var n = Number(bps) || 0;
        if (win.netBits)
            n *= 8;
        var sfx = win.netBits ? "b/s" : "B/s";
        if (n >= 1024 * 1024 * 1024)
            return { v: (n / (1024 * 1024 * 1024)).toFixed(1), u: "Gi" + sfx };
        if (n >= 1024 * 1024)
            return { v: (n / (1024 * 1024)).toFixed(1), u: "Mi" + sfx };
        if (n >= 1024)
            return { v: String(Math.round(n / 1024)), u: "Ki" + sfx };
        return { v: String(Math.round(n)), u: sfx };
    }

    function pushHist(arr, v) {
        var next = arr.slice();
        next.push(Number(v) || 0);
        var cap = win.histCap;
        if (next.length > cap)
            next.splice(0, next.length - cap);
        return next;
    }

    function tapKill(pid) {
        pid = Number(pid) || 0;
        if (pid <= 1)
            return;
        if (win.armedPid === pid) {
            win.armedPid = -1;
            disarm.stop();
            killProc.command = ["python3", win.io(), "kill", String(pid)];
            killProc.running = false;
            killProc.running = true;
            return;
        }
        win.armedPid = pid;
        disarm.restart();
    }

    onOpenChanged: if (open) win.refresh()
    function trimHist(arr) {
        if (arr.length > win.histCap)
            return arr.slice(arr.length - win.histCap);
        return arr;
    }
    onHistCapChanged: {
        win.cpuHist = win.trimHist(win.cpuHist);
        win.memHist = win.trimHist(win.memHist);
        win.diskHist = win.trimHist(win.diskHist);
        win.netHist = win.trimHist(win.netHist);
    }

    Timer {
        interval: win.refreshSecs * 1000
        running: win.open
        repeat: true
        onTriggered: win.refresh()
    }
    Timer {
        id: disarm
        interval: 4000
        onTriggered: win.armedPid = -1
    }

    IpcHandler {
        target: "sysmon"
        function ready(): string { return "ready"; }
        function engage(): string { Bus.sysmonOpen = true; win.refresh(); return "sysmon"; }
        function dismiss(): string { Bus.sysmonOpen = false; return "hidden"; }
    }

    Process {
        id: snap
        running: false
        command: ["python3", win.io()]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    if (!j || j.ok === false)
                        return;
                    win.host = j.host || "";
                    win.uptime = j.uptime || "";
                    win.cpu = j.cpu || 0;
                    win.mem = j.mem || {};
                    win.net = j.net || {};
                    win.disk = j.disk || {};
                    win.procs = j.procs || [];
                    win.cores = Array.isArray(j.cores) ? j.cores : [];
                    win.load = j.load || [];
                    win.ncpu = j.ncpu || 0;
                    win.nproc = j.nproc || 0;
                    win.live = true;
                    win.cpuHist = win.pushHist(win.cpuHist, win.cpu);
                    win.memHist = win.pushHist(win.memHist, win.mem.pct || 0);
                    win.diskHist = win.pushHist(win.diskHist, win.disk.pct || 0);
                    win.netHist = win.pushHist(win.netHist, Math.min(100,
                        ((win.net.rxBps || 0) + (win.net.txBps || 0)) / (8 * 1024 * 1024) * 100));
                } catch (e) { }
            }
        }
    }
    Process {
        id: killProc
        running: false
        command: ["python3", win.io(), "kill", "0"]
        stdout: StdioCollector {
            onStreamFinished: win.refresh()
        }
    }

    component SparkStrip: Item {
        id: spark
        property var samples: []
        property real maxValue: 100
        Layout.fillWidth: true
        implicitHeight: 22
        clip: true

        readonly property int n: (spark.samples && spark.samples.length) ? spark.samples.length : 0
        readonly property real step: spark.n > 0 ? Math.max(3, width / spark.n) : 3

        Repeater {
            model: spark.samples
            delegate: Rectangle {
                required property int index
                required property var modelData
                readonly property real raw: Number(modelData) || 0
                width: 2
                height: Math.max(1, spark.height * Math.max(0, Math.min(1,
                         raw / Math.max(1, spark.maxValue))))
                x: index * spark.step + Math.max(0, (spark.step - 2) / 2)
                y: spark.height - height
                radius: 1
                color: raw < 60 ? Theme.paintLayers.glacier[5]
                     : (raw < 85 ? Theme.goldGlow : Theme.paintLayers.magma[5])
            }
        }
    }

    component KillBtn: Item {
        id: kb
        property int pid: 0
        readonly property bool armed: win.armedPid === kb.pid
        implicitWidth: Math.max(44, lab.implicitWidth + 14)
        implicitHeight: 22
        width: implicitWidth
        height: implicitHeight
        clip: true
        scale: (kh.hovered || kb.armed) ? 1.04 : 1.0
        Behavior on scale {
            NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutQuint }
        }
        Rectangle {
            anchors.fill: parent
            radius: Theme.r1
            color: Theme.soften(win.magma, kb.armed ? 0.34 : (kh.hovered ? 0.20 : 0.11))
            border.width: 1
            border.color: Theme.soften(win.magma, kb.armed ? 0.95 : (kh.hovered ? 0.80 : 0.60))
            Behavior on color {
                ColorAnimation { duration: Theme.durQuick; easing.type: Easing.OutQuint }
            }
            Behavior on border.color {
                ColorAnimation { duration: Theme.durQuick; easing.type: Easing.OutQuint }
            }
        }
        Text {
            id: lab
            anchors.centerIn: parent
            width: parent.width - 6
            text: kb.armed ? qsTr("TERM") : qsTr("Kill")
            color: win.magma
            font.family: Theme.fUi
            font.pixelSize: Theme.tMicro
            font.weight: Theme.wStrong
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            clip: true
        }
        HoverHandler { id: kh; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: win.tapKill(kb.pid) }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.s4

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s3
            StatusPip { kind: "magma" }
            Text {
                text: qsTr("MONITOR")
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                font.weight: Theme.wStrong
                font.letterSpacing: Theme.trackMicro
                elide: Text.ElideRight
                clip: true
            }
            Item { Layout.fillWidth: true }
            Text {
                Layout.maximumWidth: parent.width * 0.62
                text: win.host
                      + (win.uptime.length ? ("  ·  " + win.uptime) : "")
                      + (win.nproc ? ("  ·  " + win.nproc + " procs") : "")
                color: Theme.textMuted
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                elide: Text.ElideRight
                clip: true
                horizontalAlignment: Text.AlignRight
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s4

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                AppCard {
                    Layout.fillWidth: true
                    kicker: qsTr("CPU")
                    value: win.cpu.toFixed(1)
                    unit: "%"
                    telemetry: (win.load.length ? Number(win.load[0]).toFixed(2) : "—")
                               + (win.ncpu ? (" · " + win.ncpu) : "")
                    fill: win.cpu / 100
                    pipKind: win.fresh ? "ice" : "off"
                    live: win.fresh
                }
                SparkStrip { samples: win.cpuHist }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                AppCard {
                    Layout.fillWidth: true
                    kicker: qsTr("MEM")
                    value: String(win.mem.pct || 0)
                    unit: "%"
                    telemetry: win.kb(win.mem.usedKb || 0) + " / " + win.kb(win.mem.totalKb || 0)
                    fill: (win.mem.pct || 0) / 100
                    pipKind: win.fresh ? "ice" : "off"
                    live: win.fresh
                }
                SparkStrip { samples: win.memHist }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                AppCard {
                    Layout.fillWidth: true
                    kicker: qsTr("DISK")
                    value: String(win.disk.pct || 0)
                    unit: "%"
                    telemetry: win.bytes(win.disk.used || 0) + " / " + win.bytes(win.disk.total || 0)
                    fill: (win.disk.pct || 0) / 100
                    pipKind: win.fresh ? "ice" : "off"
                    live: win.fresh
                }
                SparkStrip { samples: win.diskHist }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                AppCard {
                    Layout.fillWidth: true
                    kicker: qsTr("NET")
                    value: win.rateParts(win.net.rxBps || 0).v
                    unit: win.rateParts(win.net.rxBps || 0).u
                    telemetry: "↑ " + win.rateParts(win.net.txBps || 0).v
                               + " " + win.rateParts(win.net.txBps || 0).u
                    fill: Math.min(1, ((win.net.rxBps || 0) + (win.net.txBps || 0)) / (8 * 1024 * 1024))
                    pipKind: win.fresh ? "ice" : "off"
                    live: win.fresh
                }
                SparkStrip { samples: win.netHist }
            }
        }

        Item {
            id: coreBox
            visible: win.showCores
            Layout.fillWidth: true
            Layout.preferredHeight: win.showCores ? 36 : 0
            clip: true
            Column {
                anchors.fill: parent
                spacing: 4
                Text {
                    width: parent.width
                    text: qsTr("CORES")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    font.weight: Theme.wStrong
                    font.letterSpacing: Theme.trackMicro
                    elide: Text.ElideRight
                    clip: true
                }
                Row {
                    id: coreRow
                    width: parent.width
                    height: 18
                    spacing: 2
                    Repeater {
                        model: win.cores
                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: Math.max(3, (coreRow.width - Math.max(0, win.cores.length - 1) * 2)
                                             / Math.max(1, win.cores.length))
                            height: coreRow.height
                            CellMeter {
                                anchors.fill: parent
                                value: (Number(modelData) || 0) / 100
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: qsTr("PROCESSES")
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                font.weight: Theme.wStrong
                font.letterSpacing: Theme.trackMicro
                elide: Text.ElideRight
                clip: true
            }
            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s3
            Text {
                Layout.preferredWidth: 64
                text: qsTr("PID")
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tMicro
                font.weight: Theme.wStrong
                font.letterSpacing: Theme.trackMicro
                elide: Text.ElideRight
                clip: true
            }
            Text {
                Layout.fillWidth: true
                text: qsTr("NAME")
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tMicro
                font.weight: Theme.wStrong
                font.letterSpacing: Theme.trackMicro
                elide: Text.ElideRight
                clip: true
            }
            Text {
                Layout.preferredWidth: 52
                text: qsTr("CPU")
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tMicro
                font.weight: Theme.wStrong
                font.letterSpacing: Theme.trackMicro
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                clip: true
            }
            Text {
                Layout.preferredWidth: 72
                text: qsTr("RSS")
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tMicro
                font.weight: Theme.wStrong
                font.letterSpacing: Theme.trackMicro
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                clip: true
            }
            Item { Layout.preferredWidth: 52 }
        }

        Flickable {
            id: procFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: pcol.height
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: pcol
                width: procFlick.width
                spacing: 2
                Repeater {
                    model: win.procs
                    delegate: Item {
                        id: row
                        required property var modelData
                        width: pcol.width
                        height: 28
                        clip: true
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.r1
                            color: rowHov.hovered ? Theme.elevated : "transparent"
                            border.width: 1
                            border.color: Theme.soften(win.iceHair, rowHov.hovered ? 0.55 : 0.18)
                            Behavior on color {
                                ColorAnimation { duration: Theme.durQuick; easing.type: Easing.OutQuint }
                            }
                            Behavior on border.color {
                                ColorAnimation { duration: Theme.durQuick; easing.type: Easing.OutQuint }
                            }
                        }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.s3
                            anchors.rightMargin: Theme.s3
                            spacing: Theme.s3
                            Text {
                                Layout.preferredWidth: 64
                                text: String(row.modelData.pid)
                                color: Theme.textDim
                                font.family: Theme.fNum
                                font.pixelSize: Theme.tCaption
                                font.features: ({ "tnum": 1 })
                                elide: Text.ElideRight
                                clip: true
                            }
                            Text {
                                Layout.fillWidth: true
                                text: String(row.modelData.name || "")
                                color: Theme.text
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                                elide: Text.ElideRight
                                clip: true
                            }
                            Text {
                                Layout.preferredWidth: 52
                                text: (row.modelData.cpu !== undefined)
                                      ? Number(row.modelData.cpu).toFixed(1)
                                      : "—"
                                color: Theme.textMuted
                                font.family: Theme.fNum
                                font.pixelSize: Theme.tCaption
                                font.features: ({ "tnum": 1 })
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                                clip: true
                            }
                            Text {
                                Layout.preferredWidth: 72
                                text: win.kb(row.modelData.rssKb)
                                color: Theme.textMuted
                                font.family: Theme.fNum
                                font.pixelSize: Theme.tCaption
                                font.features: ({ "tnum": 1 })
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                                clip: true
                            }
                            KillBtn {
                                Layout.preferredWidth: 52
                                pid: Number(row.modelData.pid) || 0
                            }
                        }
                        HoverHandler { id: rowHov }
                    }
                }
            }
        }
    }
}
