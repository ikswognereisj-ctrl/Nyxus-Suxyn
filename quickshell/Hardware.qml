pragma ComponentBehavior: Bound
// Nyxus Suxyn — HARDWARE. Full glass instrument. Tabs that exist on THIS
// machine only. Writes go through HardwareCaps.apply then a re-read.
// Magma is the kicker pip, Kill, Delete profile, warn-hot. Tape untouched.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

AppWindow {
    id: win

    titleText: qsTr("Hardware")
    iconName: "computer"
    subtitleText: win.boardLine
    open: Bus.hardwareOpen
    onDismissed: Bus.hardwareOpen = false
    implicitWidth: 1180
    implicitHeight: 740
    minimumSize: Qt.size(860, 560)

    property string tab: "Overview"
    property string host: ""
    property string boardLine: ""
    property var hot: null
    property var loud: null
    property var temps: []
    property var fans: []
    property var mem: ({})
    property var cpu: ({})
    property var batt: ({})
    property var gpu: ({})
    property var power: ({})
    property var uptime: ({})
    property var rgb: ({ backed: false, binary: false, devices: [], n: 0 })
    property var profiles: []
    property var procs: []
    property var boost: null
    property string profile: ""
    property string note: ""
    property int profIdx: 0
    property string editName: ""
    property string editDesc: ""
    property string editGov: ""
    property bool editBoost: true
    property string editFan: "auto"
    property int selPid: 0
    property string procFilter: ""
    property string procSort: "cpu"
    property string rgbName: "Ice"
    property string wantFan: ""
    property string wantGov: ""
    property string wantEpp: ""
    property string wantPlat: ""
    property bool wantBoost: false
    property var writeQ: []
    property bool landed: false

    readonly property color ice: Theme.tokenAccentPrimary
    readonly property color iceHair: Theme.tokenAccentHairline
    readonly property color iceFocus: Theme.tokenAccentInteractive
    readonly property color magma: Theme.paintLayers.magma[5]

    readonly property string tempUnit: SettingsStore.stringValue("app_hw_temp_unit", "Celsius")
    readonly property real warnTemp: SettingsStore.numberValue("app_hw_warn_temp", 85)
    readonly property int pollMs: Math.max(1000, Math.round(SettingsStore.numberValue("app_hw_poll_secs", 2) * 1000))
    readonly property bool fahrenheit: win.tempUnit === "Fahrenheit"
    readonly property bool hasFans: win.fans.length > 0 || (HardwareCaps.probed && HardwareCaps.hasFanReadings)
    readonly property bool hasTemps: win.temps.length > 0 || (HardwareCaps.probed && HardwareCaps.temps.length > 0)
    readonly property bool hasRgb: win.rgb.backed === true
    readonly property bool hasBoost: win.boost === true || win.boost === false
    readonly property bool hasPower: !!(win.power && win.power.backed)
    readonly property bool hotWarn: !!(win.hot && win.hot.c >= win.warnTemp)
    readonly property bool anyPending: fanMark.pending || govMark.pending || boostMark.pending
                                       || platMark.pending || eppMark.pending
    readonly property bool anyFailed: fanMark.failed || govMark.failed || boostMark.failed
                                      || platMark.failed || eppMark.failed

    readonly property var tabs: {
        var t = [{ id: "Overview", label: qsTr("Overview") }];
        if (win.hasFans)
            t.push({ id: "Fans", label: qsTr("Fans") });
        if (win.hasTemps)
            t.push({ id: "Thermal", label: qsTr("Thermal") });
        t.push({ id: "Profiles", label: qsTr("Profiles") });
        if (win.hasRgb)
            t.push({ id: "RGB", label: qsTr("RGB") });
        t.push({ id: "Power", label: qsTr("Power") });
        t.push({ id: "Processes", label: qsTr("Processes") });
        return t;
    }

    readonly property var missing: {
        var m = [];
        if (HardwareCaps.probed || win.host.length) {
            if (!win.hasFans)
                m.push(qsTr("No fan tachometers — Fans is hidden."));
            else if (!HardwareCaps.canSetFan)
                m.push(HardwareCaps.pwm.length > 0
                       ? qsTr("PWM is read-only. Firmware owns the fans.")
                       : qsTr("Fans report RPM only. No writable PWM."));
            if (!win.hasTemps)
                m.push(qsTr("No temperature sensors — Thermal is hidden."));
            if (!win.hasRgb)
                m.push(win.rgb.binary
                       ? qsTr("OpenRGB is here but found no devices — RGB is hidden.")
                       : qsTr("OpenRGB is not available — RGB is hidden."));
            if (!win.hasBoost)
                m.push(qsTr("No CPU boost knob on this kernel."));
            if (!win.hasPower && !HardwareCaps.hasProfile)
                m.push(qsTr("No power-profiles-daemon and no ACPI platform profile."));
            if (HardwareCaps.probed && !HardwareCaps.hasChargeLimit)
                m.push(qsTr("This battery exposes no charge threshold."));
        }
        return m;
    }

    readonly property var shownProcs: {
        var q = win.procFilter.trim().toLowerCase();
        var src = win.procs || [];
        var out = [];
        for (var i = 0; i < src.length; i++) {
            var p = src[i];
            if (q.length) {
                var hay = (String(p.name) + " " + String(p.pid)).toLowerCase();
                if (hay.indexOf(q) < 0)
                    continue;
            }
            out.push(p);
        }
        var key = win.procSort;
        out.sort(function (a, b) {
            if (key === "name") {
                var an = String(a.name).toLowerCase();
                var bn = String(b.name).toLowerCase();
                return an < bn ? -1 : (an > bn ? 1 : 0);
            }
            if (key === "pid")
                return (a.pid || 0) - (b.pid || 0);
            if (key === "rss")
                return (b.rss || 0) - (a.rss || 0);
            return (b.cpu || 0) - (a.cpu || 0);
        });
        return out;
    }

    function io() {
        return (Quickshell.env("HOME") || "") + "/.config/quickshell/hardware-io.py";
    }
    function kick(proc) {
        proc.running = false;
        proc.running = true;
    }
    function refresh() {
        win.kick(snap);
        if (win.tab === "Processes")
            win.kick(procSnap);
    }
    function land() {
        var want = SettingsStore.stringValue("app_hw_default_tab", "Overview");
        var ok = false;
        for (var i = 0; i < win.tabs.length; i++)
            if (win.tabs[i].id === want)
                ok = true;
        win.tab = ok ? want : "Overview";
        win.landed = true;
    }
    function n(v) {
        return (v === null || v === undefined || v === "") ? "—" : v;
    }
    function gib(b) {
        var x = Number(b) || 0;
        return (x / (1024 * 1024 * 1024)).toFixed(1) + " GiB";
    }
    function mib(b) {
        var x = Number(b) || 0;
        if (x > 1024 * 1024 * 1024)
            return (x / (1024 * 1024 * 1024)).toFixed(1) + " GiB";
        return Math.round(x / (1024 * 1024)) + " MiB";
    }
    function toDisplay(c) {
        c = Number(c);
        if (isNaN(c))
            return "—";
        if (win.fahrenheit)
            return Math.round(c * 9 / 5 + 32);
        return (Math.round(c * 10) / 10);
    }
    function degSuffix() {
        return win.fahrenheit ? "°F" : "°C";
    }
    function tempFill(c) {
        c = Number(c);
        if (isNaN(c))
            return 0;
        return Math.max(0, Math.min(1, c / Math.max(win.warnTemp, 1)));
    }
    function fanFill(row) {
        if (!row)
            return 0;
        var lo = Number(row.min) || 0;
        var hi = Number(row.max) || 0;
        if (hi <= lo)
            hi = Math.max(Number(row.rpm) || 0, 4500);
        var rpm = Number(row.rpm) || 0;
        return Math.max(0, Math.min(1, (rpm - lo) / Math.max(hi - lo, 1)));
    }
    function powerLabel(mode) {
        var k = String(mode || "").toLowerCase();
        if (k === "power-saver" || k === "power_saver")
            return qsTr("Saver");
        if (k === "balanced")
            return qsTr("Balanced");
        if (k === "performance")
            return qsTr("Performance");
        if (k === "low-power" || k === "low_power")
            return qsTr("Low power");
        if (k === "quiet")
            return qsTr("Quiet");
        return String(mode || "—");
    }
    function fanLabel(mode) {
        if (mode === "auto")
            return qsTr("Automatic");
        if (mode === "low")
            return qsTr("Low");
        if (mode === "high")
            return qsTr("High");
        if (mode === "max")
            return qsTr("Maximum");
        return String(mode || "—");
    }
    function govInList(g) {
        var ch = HardwareCaps.governor ? (HardwareCaps.governor.choices || []) : [];
        for (var i = 0; i < ch.length; i++)
            if (ch[i] === g)
                return true;
        return false;
    }
    function fanModeForPct(pct) {
        pct = Number(pct);
        if (isNaN(pct) || pct < 0)
            return "auto";
        var best = "auto";
        var bestD = 999;
        for (var i = 0; i < HardwareCaps.fanModes.length; i++) {
            var m = HardwareCaps.fanModes[i];
            if (!m || m.value === "auto" || m.duty === undefined || m.duty === null)
                continue;
            var p = Number(m.duty) / 255 * 100;
            var d = Math.abs(p - pct);
            if (d < bestD) {
                bestD = d;
                best = m.value;
            }
        }
        return best;
    }
    function capApply(target, value) {
        var q = win.writeQ.slice();
        q.push({ t: target, v: String(value) });
        win.writeQ = q;
        win.drainCap();
    }
    function drainCap() {
        if (HardwareCaps.busy || win.writeQ.length === 0)
            return;
        var q = win.writeQ.slice();
        var w = q.shift();
        win.writeQ = q;
        HardwareCaps.apply(w.t, w.v);
    }
    function setFan(mode) {
        win.wantFan = mode;
        fanMark.request(true);
        win.capApply("fan", mode);
        win.note = qsTr("Fans → %1").arg(win.fanLabel(mode));
    }
    function setGov(v) {
        win.wantGov = v;
        govMark.request(true);
        win.capApply("governor", v);
        win.note = qsTr("Governor → %1").arg(v);
    }
    function setEpp(v) {
        win.wantEpp = v;
        eppMark.request(true);
        win.capApply("epp", v);
        win.note = qsTr("Energy preference → %1").arg(v);
    }
    function setPlat(v) {
        win.wantPlat = v;
        platMark.request(true);
        win.capApply("platform-profile", v);
        win.note = qsTr("Firmware profile → %1").arg(v);
    }
    function setPower(mode) {
        powerSet.want = mode;
        win.kick(powerSet);
        win.note = qsTr("Power mode → %1").arg(win.powerLabel(mode));
    }
    function setBoost(on) {
        win.wantBoost = on;
        boostMark.request(on);
        boostSet.want = on ? "on" : "off";
        win.kick(boostSet);
        win.note = qsTr("Boost → %1").arg(on ? qsTr("on") : qsTr("off"));
    }
    function applyProfile(p) {
        if (!p)
            return;
        win.note = qsTr("Applying %1…").arg(p.name || qsTr("profile"));
        profAct.command = ["python3", win.io(), "profiles", "apply", String(p.name || "")];
        win.kick(profAct);
        if (HardwareCaps.canSetGovernor && p.governor && win.govInList(p.governor))
            win.setGov(p.governor);
        if (HardwareCaps.canSetFan) {
            var fm = p.fan_mode && String(p.fan_mode).length ? String(p.fan_mode) : win.fanModeForPct(p.fan_pwm_pct);
            if (fm)
                win.setFan(fm);
        }
    }
    function loadEditor(idx) {
        if (idx < 0 || idx >= win.profiles.length)
            return;
        win.profIdx = idx;
        var p = win.profiles[idx];
        win.editName = p.name || "";
        win.editDesc = p.description || "";
        win.editGov = p.governor || "";
        win.editBoost = p.boost !== false;
        win.editFan = p.fan_mode && String(p.fan_mode).length ? String(p.fan_mode) : win.fanModeForPct(p.fan_pwm_pct);
        if (nameField)
            nameField.text = win.editName;
        if (descField)
            descField.text = win.editDesc;
        if (editGovChoice)
            editGovChoice.value = win.editGov;
        if (editFanChoice)
            editFanChoice.value = win.editFan;
    }
    function saveEditor() {
        if (win.profIdx < 0 || win.profIdx >= win.profiles.length)
            return;
        var next = [];
        for (var i = 0; i < win.profiles.length; i++) {
            var row = {};
            var src = win.profiles[i];
            for (var k in src)
                row[k] = src[k];
            if (i === win.profIdx) {
                row.name = win.editName || qsTr("Profile");
                row.description = win.editDesc;
                row.governor = win.editGov;
                row.boost = win.editBoost;
                row.fan_mode = win.editFan;
                row.fan_pwm_pct = win.editFan === "max" ? 100 : (win.editFan === "low" ? 50 : (win.editFan === "auto" ? -1 : 50));
            }
            next.push(row);
        }
        profSave.payload = JSON.stringify(next);
        profSave.command = ["python3", win.io(), "profiles", "save", profSave.payload];
        win.kick(profSave);
    }
    function swatchColor(name) {
        if (name === "Ice")
            return Theme.tokenAccentInteractive;
        if (name === "Glacier")
            return Theme.tealGlow;
        if (name === "Magma")
            return win.magma;
        if (name === "Red")
            return Theme.danger;
        if (name === "Gold")
            return Theme.goldGlow;
        if (name === "Green")
            return Theme.ok;
        if (name === "Azure")
            return Theme.azureGlow;
        if (name === "Violet")
            return Theme.violetGlow;
        if (name === "Plum")
            return Theme.plumGlow;
        if (name === "White")
            return "#ffffff";
        return Theme.tokenAccentPrimary;
    }
    readonly property var rgbNames: ["Ice", "Glacier", "Magma", "Red", "Gold", "Green", "Azure", "Violet", "Plum", "White"]

    onOpenChanged: {
        if (open) {
            HardwareCaps.watch();
            win.refresh();
            win.kick(rgbList);
            win.kick(profList);
            win.kick(procSnap);
        } else {
            HardwareCaps.unwatch();
            win.landed = false;
        }
    }
    onTabsChanged: {
        if (!win.open)
            return;
        if (!win.landed) {
            win.land();
            return;
        }
        var ok = false;
        for (var i = 0; i < win.tabs.length; i++)
            if (win.tabs[i].id === win.tab)
                ok = true;
        if (!ok)
            win.tab = "Overview";
    }
    onTabChanged: {
        if (win.tab === "Processes")
            win.kick(procSnap);
        if (win.tab === "Profiles" && win.profiles.length === 0)
            win.kick(profList);
        if (win.tab === "RGB")
            win.kick(rgbList);
    }

    Timer {
        interval: win.pollMs
        running: win.open
        repeat: true
        onTriggered: win.refresh()
    }

    IpcHandler {
        target: "hardware"
        function ready(): string { return "ready"; }
        function engage(): string {
            Bus.hardwareOpen = true;
            win.refresh();
            return "hardware";
        }
        function dismiss(): string { Bus.hardwareOpen = false; return "hidden"; }
    }

    LiveMark {
        id: fanMark
        actual: HardwareCaps.fanMode === win.wantFan && win.wantFan.length > 0
        want: true
        visible: false
    }
    LiveMark {
        id: govMark
        actual: !!(HardwareCaps.governor && HardwareCaps.governor.value === win.wantGov && win.wantGov.length > 0)
        want: true
        visible: false
    }
    LiveMark {
        id: eppMark
        actual: !!(HardwareCaps.epp && HardwareCaps.epp.value === win.wantEpp && win.wantEpp.length > 0)
        want: true
        visible: false
    }
    LiveMark {
        id: platMark
        actual: !!(HardwareCaps.platformProfile && HardwareCaps.platformProfile.value === win.wantPlat && win.wantPlat.length > 0)
        want: true
        visible: false
    }
    LiveMark {
        id: boostMark
        actual: win.boost === true
        want: win.wantBoost
        visible: false
    }

    Connections {
        target: HardwareCaps
        function onBusyChanged() {
            if (!HardwareCaps.busy)
                win.drainCap();
        }
        function onDocChanged() {
            if (fanChoice.visible)
                fanChoice.value = HardwareCaps.fanMode;
            if (govChoice.visible)
                govChoice.value = HardwareCaps.governor ? HardwareCaps.governor.value : "";
            if (eppChoice.visible)
                eppChoice.value = HardwareCaps.epp ? HardwareCaps.epp.value : "";
            if (platChoice.visible)
                platChoice.value = HardwareCaps.platformProfile ? HardwareCaps.platformProfile.value : "";
        }
    }

    Process {
        id: snap
        running: false
        command: ["python3", win.io(), "snapshot"]
        onExited: function (code) { if (code !== 0) console.warn("[Hardware] snapshot io exited code " + code); }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    if (!j || j.ok === false)
                        return;
                    win.host = j.host || "";
                    win.hot = j.hot;
                    win.loud = j.loud;
                    win.temps = j.temps || [];
                    win.fans = j.fans || [];
                    win.mem = j.mem || {};
                    win.cpu = j.cpu || {};
                    win.batt = j.batt || {};
                    win.gpu = j.gpu || {};
                    win.power = j.power || {};
                    win.profile = j.profile || "";
                    win.boost = (j.boost === true || j.boost === false) ? j.boost : null;
                    win.uptime = j.uptime || {};
                    if (j.rgb_binary === true && !(win.rgb && win.rgb.binary))
                        win.rgb = ({
                            backed: !!(win.rgb && win.rgb.backed),
                            binary: true,
                            devices: (win.rgb && win.rgb.devices) ? win.rgb.devices : [],
                            n: (win.rgb && win.rgb.n) ? win.rgb.n : 0
                        });
                    var m = j.machine || {};
                    var product = String(m.product || "").trim();
                    var vendor = String(m.vendor || "").trim();
                    if (product.length && vendor.length
                            && product.toLowerCase().indexOf(vendor.toLowerCase()) === 0)
                        win.boardLine = product;
                    else
                        win.boardLine = (vendor + " " + product).trim();
                    if (!win.boardLine.length)
                        win.boardLine = win.host;
                    if (!win.landed)
                        win.land();
                } catch (e) { }
            }
        }
    }
    Process {
        id: procSnap
        running: false
        command: ["python3", win.io(), "procs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.procs = j.procs || [];
                } catch (e) { }
            }
        }
    }
    Process {
        id: killer
        running: false
        property int pid: 0
        command: ["python3", win.io(), "kill", String(killer.pid)]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.note = j.ok ? qsTr("SIGTERM → PID %1").arg(killer.pid)
                                    : (j.error || qsTr("Kill did not land."));
                } catch (e) {
                    win.note = qsTr("Kill did not land.");
                }
                win.selPid = 0;
                win.kick(procSnap);
            }
        }
    }
    Process {
        id: rgbList
        running: false
        command: ["python3", win.io(), "rgb", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.rgb = j;
                } catch (e) { }
            }
        }
    }
    Process {
        id: rgbSet
        running: false
        property string want: "Ice"
        command: ["python3", win.io(), "rgb", "set", rgbSet.want]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.note = j.ok ? qsTr("RGB → %1").arg(rgbSet.want)
                                    : (j.error || qsTr("RGB did not apply."));
                    if (j.rgb)
                        win.rgb = j.rgb;
                } catch (e) {
                    win.note = qsTr("RGB did not apply.");
                }
            }
        }
    }
    Process {
        id: rgbMode
        running: false
        property string want: "static"
        command: ["python3", win.io(), "rgb", "mode", rgbMode.want]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.note = j.ok ? qsTr("RGB mode → %1").arg(rgbMode.want)
                                    : (j.error || qsTr("RGB mode did not apply."));
                } catch (e) {
                    win.note = qsTr("RGB mode did not apply.");
                }
            }
        }
    }
    Process {
        id: powerSet
        running: false
        property string want: "balanced"
        command: ["python3", win.io(), "power", "set", powerSet.want]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    if (j.power)
                        win.power = j.power;
                    win.profile = (j.power && j.power.active) ? j.power.active : (j.active || win.profile);
                    win.note = j.ok ? qsTr("Power mode → %1").arg(win.powerLabel(win.profile))
                                    : (j.error || qsTr("Power mode did not apply."));
                    if (!j.ok && win.hasPower === false && HardwareCaps.canSetProfile)
                        win.setPlat(powerSet.want);
                } catch (e) {
                    win.note = qsTr("Power mode did not apply.");
                }
                win.kick(snap);
            }
        }
    }
    Process {
        id: boostSet
        running: false
        property string want: "on"
        command: ["python3", win.io(), "boost", "set", boostSet.want]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    if (j.boost === true || j.boost === false)
                        win.boost = j.boost;
                    if (!j.ok)
                        win.note = j.error || qsTr("Boost did not apply.");
                } catch (e) {
                    win.note = qsTr("Boost did not apply.");
                }
                win.kick(snap);
            }
        }
    }
    Process {
        id: profList
        running: false
        command: ["python3", win.io(), "profiles", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.profiles = j.profiles || [];
                    if (win.profIdx >= win.profiles.length)
                        win.profIdx = Math.max(0, win.profiles.length - 1);
                    if (win.profiles.length)
                        win.loadEditor(win.profIdx);
                } catch (e) { }
            }
        }
    }
    Process {
        id: profAct
        running: false
        command: ["python3", win.io(), "profiles", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    var bits = j.notes || [];
                    win.note = j.ok ? (qsTr("Applied %1").arg(j.applied || "") + (bits.length ? (" · " + bits.join(" · ")) : ""))
                                    : (j.error || qsTr("Profile did not apply."));
                    if (j.boost === true || j.boost === false)
                        win.boost = j.boost;
                } catch (e) {
                    win.note = qsTr("Profile did not apply.");
                }
                win.kick(snap);
            }
        }
    }
    Process {
        id: profNew
        running: false
        command: ["python3", win.io(), "profiles", "new"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.profiles = j.profiles || win.profiles;
                    if (j.index !== undefined)
                        win.loadEditor(j.index);
                    win.note = qsTr("New profile created");
                } catch (e) { }
            }
        }
    }
    Process {
        id: profDel
        running: false
        property string want: ""
        command: ["python3", win.io(), "profiles", "delete", profDel.want]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.profiles = j.profiles || win.profiles;
                    win.loadEditor(Math.max(0, Math.min(win.profIdx, win.profiles.length - 1)));
                    win.note = j.ok ? qsTr("Deleted: %1").arg(j.deleted || "")
                                    : (j.error || qsTr("Delete did not land."));
                } catch (e) { }
            }
        }
    }
    Process {
        id: profSave
        running: false
        property string payload: "[]"
        command: ["python3", win.io(), "profiles", "save", "[]"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.profiles = j.profiles || win.profiles;
                    win.note = j.ok ? qsTr("Saved: %1").arg(win.editName) : (j.error || qsTr("Save failed."));
                } catch (e) {
                    win.note = qsTr("Save failed.");
                }
            }
        }
    }

    component TabChip: Item {
        id: chip
        property string tid: ""
        property string label: ""
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        readonly property bool on: win.tab === chip.tid
        scale: tabTap.pressed ? 0.985 : (tabHov.hovered ? 1.012 : 1.0)
        Behavior on scale {
            NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutQuint }
        }
        CutRect {
            anchors.fill: parent
            radius: Theme.r1
            color: chip.on ? Theme.elevated : "transparent"
            borderWidth: (chip.on || tabHov.hovered) ? 1 : 0
            borderColor: tabHov.hovered ? win.iceFocus : Theme.soften(win.iceHair, 0.85)
        }
        Text {
            anchors.fill: parent
            anchors.leftMargin: Theme.s5
            anchors.rightMargin: Theme.s4
            text: chip.label
            color: chip.on ? Theme.text : Theme.textMuted
            font.family: Theme.fUi
            font.pixelSize: Theme.tLabel
            font.weight: chip.on ? Theme.wStrong : Font.Normal
            elide: Text.ElideRight
            clip: true
            verticalAlignment: Text.AlignVCenter
        }
        HoverHandler { id: tabHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: tabTap; onTapped: win.tab = chip.tid }
    }

    component IceBtn: Item {
        id: ib
        property string text: ""
        property bool primary: false
        signal tapped()
        implicitWidth: ibLab.implicitWidth + 2 * Theme.s5
        implicitHeight: 30
        scale: ibTap.pressed ? 0.985 : (ibHov.hovered ? 1.012 : 1.0)
        Behavior on scale {
            NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutQuint }
        }
        CutRect {
            anchors.fill: parent
            radius: Theme.r1
            color: ib.primary ? Theme.tokenAccentGround : Theme.soften(Theme.void_, 0.34)
            borderWidth: 1
            borderColor: ibHov.hovered ? win.iceFocus : Theme.soften(win.iceHair, ib.primary ? 0.85 : 0.50)
        }
        Text {
            id: ibLab
            anchors.centerIn: parent
            width: Math.min(implicitWidth, parent.width - 8)
            text: ib.text
            color: Theme.text
            font.family: Theme.fUi
            font.pixelSize: Theme.tCaption
            font.weight: Theme.wStrong
            elide: Text.ElideRight
            clip: true
        }
        HoverHandler { id: ibHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: ibTap; onTapped: ib.tapped() }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.preferredWidth: 188
            Layout.maximumWidth: 188
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.rightMargin: Theme.s5
                spacing: Theme.s2
                Row {
                    spacing: Theme.s3
                    StatusPip { kind: "magma" }
                    Text {
                        text: qsTr("HARDWARE")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        font.weight: Theme.wStrong
                        font.letterSpacing: Theme.trackMicro
                        elide: Text.ElideRight
                        clip: true
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: win.boardLine.length ? win.boardLine : qsTr("This machine")
                    color: Theme.text
                    font.family: Theme.fUiTitle
                    font.pixelSize: Theme.tHead
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    clip: true
                    wrapMode: Text.NoWrap
                }
                Row {
                    spacing: Theme.s3
                    StatusPip {
                        kind: win.anyFailed ? "amber" : ((win.anyPending || HardwareCaps.busy) ? "ice" : "off")
                        pulse: win.anyPending || win.anyFailed
                    }
                    Text {
                        text: win.anyFailed ? qsTr("write did not match")
                            : (win.anyPending || HardwareCaps.busy ? qsTr("pending") : qsTr("live"))
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                        elide: Text.ElideRight
                        clip: true
                    }
                }
                Repeater {
                    model: win.tabs
                    TabChip {
                        required property var modelData
                        tid: modelData.id
                        label: modelData.label
                    }
                }
                Item { Layout.fillHeight: true }
                Text {
                    Layout.fillWidth: true
                    visible: win.note.length > 0
                    text: win.note
                    color: Theme.textMuted
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                    clip: true
                    maximumLineCount: 4
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ── OVERVIEW ──────────────────────────────────────────────
            ColumnLayout {
                anchors.fill: parent
                visible: win.tab === "Overview"
                spacing: Theme.s4
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Overview")
                    color: Theme.text
                    font.family: Theme.fUiTitle
                    font.pixelSize: Theme.tDisplay
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    clip: true
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    rowSpacing: Theme.s4
                    columnSpacing: Theme.s4
                    AppCard {
                        kicker: qsTr("HOTTEST")
                        value: win.hot ? String(win.toDisplay(win.hot.c)) : "—"
                        unit: win.hot ? win.degSuffix() : ""
                        telemetry: win.hot ? String(win.hot.name) : qsTr("no sensors")
                        pipKind: win.hotWarn ? "magma" : (win.hot ? "ice" : "off")
                        live: win.hotWarn
                        fill: win.hot ? win.tempFill(win.hot.c) : -1
                    }
                    AppCard {
                        kicker: qsTr("LOUDEST FAN")
                        value: win.loud ? String(win.loud.rpm) : "—"
                        unit: win.loud ? qsTr("rpm") : ""
                        telemetry: win.loud ? String(win.loud.name) : qsTr("no fans")
                        pipKind: win.loud ? "ice" : "off"
                        fill: win.loud ? win.fanFill(win.loud) : -1
                    }
                    AppCard {
                        kicker: qsTr("CPU")
                        value: win.cpu.pct !== undefined ? Number(win.cpu.pct).toFixed(0) : (win.cpu.n ? String(win.cpu.n) : "—")
                        unit: win.cpu.pct !== undefined ? "%" : (win.cpu.n ? qsTr("threads") : "")
                        telemetry: (win.cpu.governor ? String(win.cpu.governor) : "")
                                   + (win.cpu.freq ? (" · " + win.cpu.freq.avg + " MHz") : "")
                                   + (win.hasBoost ? (win.boost ? qsTr(" · boost on") : qsTr(" · boost off")) : "")
                        pipKind: (Number(win.cpu.pct) >= 85) ? "magma" : "ice"
                        fill: (Number(win.cpu.pct) || 0) / 100
                    }
                    AppCard {
                        kicker: qsTr("GPU")
                        value: win.gpu && win.gpu.detected ? Number(win.gpu.util || 0).toFixed(0) : "—"
                        unit: win.gpu && win.gpu.detected ? "%" : ""
                        telemetry: win.gpu && win.gpu.name ? String(win.gpu.name)
                                 : qsTr("no discrete GPU telemetry")
                        pipKind: win.gpu && win.gpu.detected ? "ice" : "off"
                        fill: win.gpu && win.gpu.detected ? Math.max(0, Math.min(1, Number(win.gpu.util || 0) / 100)) : -1
                    }
                    AppCard {
                        kicker: qsTr("MEMORY")
                        value: win.mem.total ? win.gib(win.mem.used) : "—"
                        telemetry: win.mem.total ? (qsTr("of %1").arg(win.gib(win.mem.total))) : ""
                        pipKind: "ice"
                        fill: win.mem.total ? Math.max(0, Math.min(1, Number(win.mem.used) / Number(win.mem.total))) : -1
                    }
                    AppCard {
                        kicker: qsTr("BATTERY")
                        value: win.batt.present ? String(win.batt.pct) : "—"
                        unit: win.batt.present ? "%" : ""
                        telemetry: win.batt.present ? String(win.batt.status) : qsTr("no battery")
                        pipKind: (win.batt.present && win.batt.pct <= 15) ? "magma" : (win.batt.present ? "ice" : "off")
                        fill: win.batt.present ? Math.max(0, Math.min(1, Number(win.batt.pct) / 100)) : -1
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: qsTr("WHY A TAB IS MISSING")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    font.weight: Theme.wStrong
                    font.letterSpacing: Theme.trackMicro
                    visible: win.missing.length > 0
                    elide: Text.ElideRight
                    clip: true
                }
                Repeater {
                    model: win.missing
                    Text {
                        required property var modelData
                        Layout.fillWidth: true
                        text: String(modelData)
                        color: Theme.textMuted
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        elide: Text.ElideRight
                        clip: true
                    }
                }
                Item { Layout.fillHeight: true }
            }

            // ── FANS ──────────────────────────────────────────────────
            ColumnLayout {
                anchors.fill: parent
                visible: win.tab === "Fans"
                spacing: Theme.s4
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Fans")
                        color: Theme.text
                        font.family: Theme.fUiTitle
                        font.pixelSize: Theme.tDisplay
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        clip: true
                    }
                    LiveMark {
                        actual: HardwareCaps.fanMode === win.wantFan && win.wantFan.length > 0
                        want: true
                        armed: fanMark.armed
                        failed: fanMark.failed
                    }
                    SetChoice {
                        id: fanChoice
                        visible: HardwareCaps.canSetFan
                        value: HardwareCaps.fanMode
                        segmentLimit: 4
                        options: {
                            var out = [];
                            for (var i = 0; i < HardwareCaps.fanModes.length; i++) {
                                var m = HardwareCaps.fanModes[i];
                                out.push({ value: m.value, label: win.fanLabel(m.value) });
                            }
                            return out;
                        }
                        onChosen: function (v) { win.setFan(v); }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: win.hasFans && !HardwareCaps.canSetFan
                    text: HardwareCaps.pwm.length > 0
                          ? qsTr("This machine's PWM is read-only — the firmware owns the fans. Readings only.")
                          : qsTr("RPM only. This hardware does not expose fan control.")
                    color: Theme.textMuted
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                    clip: true
                }
                Text {
                    Layout.fillWidth: true
                    visible: HardwareCaps.canSetFan
                    text: qsTr("Automatic hands the fans back to the firmware. The other steps are the speeds this controller can actually tell apart — not a percentage dial.")
                    color: Theme.textMuted
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    wrapMode: Text.WordWrap
                    elide: Text.ElideRight
                    clip: true
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 160
                    spacing: Theme.s4
                    Repeater {
                        model: win.fans
                        AppCard {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            kicker: String(modelData.name || qsTr("Fan"))
                            value: String(modelData.rpm)
                            unit: qsTr("rpm")
                            telemetry: (modelData.min !== undefined && modelData.max !== undefined)
                                       ? (modelData.min + " – " + modelData.max)
                                       : ""
                            pipKind: win.fanFill(modelData) >= 0.85 ? "magma" : "ice"
                            fill: win.fanFill(modelData)
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }

            // ── THERMAL ───────────────────────────────────────────────
            ColumnLayout {
                anchors.fill: parent
                visible: win.tab === "Thermal"
                spacing: Theme.s4
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Thermal")
                    color: Theme.text
                    font.family: Theme.fUiTitle
                    font.pixelSize: Theme.tDisplay
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    clip: true
                }
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Warn above %1%2 · magma pip on the hottest if it crosses.")
                          .arg(win.toDisplay(win.warnTemp)).arg(win.degSuffix())
                    color: Theme.textMuted
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    elide: Text.ElideRight
                    clip: true
                }
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: thermGrid.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    GridLayout {
                        id: thermGrid
                        width: parent.width
                        columns: 3
                        rowSpacing: Theme.s4
                        columnSpacing: Theme.s4
                        Repeater {
                            model: win.temps
                            AppCard {
                                required property var modelData
                                Layout.fillWidth: true
                                kicker: String(modelData.name || qsTr("sensor"))
                                value: String(win.toDisplay(modelData.c))
                                unit: win.degSuffix()
                                telemetry: modelData.crit ? (qsTr("crit %1").arg(win.toDisplay(modelData.crit))) : ""
                                pipKind: Number(modelData.c) >= win.warnTemp ? "magma" : "ice"
                                live: Number(modelData.c) >= win.warnTemp
                                fill: win.tempFill(modelData.c)
                            }
                        }
                    }
                }
            }

            // ── PROFILES ──────────────────────────────────────────────
            ColumnLayout {
                anchors.fill: parent
                visible: win.tab === "Profiles"
                spacing: Theme.s4
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Profiles")
                    color: Theme.text
                    font.family: Theme.fUiTitle
                    font.pixelSize: Theme.tDisplay
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    clip: true
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 118
                    spacing: Theme.s4
                    Repeater {
                        model: win.profiles
                        AppCard {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            kicker: String(modelData.name || qsTr("Profile"))
                            value: String(modelData.governor || "—")
                            telemetry: (modelData.boost ? qsTr("boost on") : qsTr("boost off"))
                                       + (HardwareCaps.canSetFan && modelData.fan_mode ? (" · " + win.fanLabel(modelData.fan_mode)) : "")
                            pipKind: index === win.profIdx ? "ice" : "off"
                            selected: index === win.profIdx
                            onActivated: win.loadEditor(index)
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.s4
                    AppCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 118
                        kicker: win.editName.length ? win.editName.toUpperCase() : qsTr("PROFILE")
                        value: win.editGov.length ? win.editGov : "—"
                        telemetry: win.editDesc
                        pipKind: "ice"
                    }
                    ColumnLayout {
                        Layout.preferredWidth: 280
                        Layout.maximumWidth: 280
                        spacing: Theme.s3
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: Theme.r1
                            color: Theme.soften(Theme.void_, 0.62)
                            border.width: 1
                            border.color: Theme.soften(win.iceHair, nameHov.hovered ? 0.85 : 0.45)
                            TextInput {
                                id: nameField
                                anchors.fill: parent
                                anchors.margins: 8
                                color: Theme.text
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tBody
                                text: win.editName
                                clip: true
                                onTextChanged: win.editName = text
                            }
                            Text {
                                anchors.fill: nameField
                                visible: nameField.text.length === 0 && !nameField.activeFocus
                                text: qsTr("Name")
                                color: Theme.textDim
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tBody
                                enabled: false
                            }
                            HoverHandler { id: nameHov }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: Theme.r1
                            color: Theme.soften(Theme.void_, 0.62)
                            border.width: 1
                            border.color: Theme.soften(win.iceHair, descHov.hovered ? 0.85 : 0.45)
                            TextInput {
                                id: descField
                                anchors.fill: parent
                                anchors.margins: 8
                                color: Theme.text
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tBody
                                text: win.editDesc
                                clip: true
                                onTextChanged: win.editDesc = text
                            }
                            Text {
                                anchors.fill: descField
                                visible: descField.text.length === 0 && !descField.activeFocus
                                text: qsTr("Description")
                                color: Theme.textDim
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tBody
                                enabled: false
                            }
                            HoverHandler { id: descHov }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: qsTr("Governor")
                                color: Theme.textDim
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                                elide: Text.ElideRight
                                clip: true
                            }
                            Item { Layout.fillWidth: true }
                            SetChoice {
                                id: editGovChoice
                                visible: HardwareCaps.hasGovernor
                                value: win.editGov
                                options: {
                                    var out = [];
                                    var ch = HardwareCaps.governor ? (HardwareCaps.governor.choices || []) : [];
                                    for (var i = 0; i < ch.length; i++)
                                        out.push({ value: ch[i], label: ch[i] });
                                    return out;
                                }
                                onChosen: function (v) { win.editGov = v; }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            visible: HardwareCaps.canSetFan
                            Text {
                                text: qsTr("Fans")
                                color: Theme.textDim
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                                elide: Text.ElideRight
                                clip: true
                            }
                            Item { Layout.fillWidth: true }
                            SetChoice {
                                id: editFanChoice
                                value: win.editFan
                                options: {
                                    var out = [];
                                    for (var i = 0; i < HardwareCaps.fanModes.length; i++) {
                                        var m = HardwareCaps.fanModes[i];
                                        out.push({ value: m.value, label: win.fanLabel(m.value) });
                                    }
                                    return out;
                                }
                                onChosen: function (v) { win.editFan = v; }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: qsTr("CPU Boost")
                                color: Theme.textDim
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                                elide: Text.ElideRight
                                clip: true
                            }
                            Item { Layout.fillWidth: true }
                            SetSwitch {
                                checked: win.editBoost
                                enabled: win.hasBoost
                                onToggled: function (v) { win.editBoost = v; }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.s3
                            IceBtn {
                                text: qsTr("Save")
                                onTapped: win.saveEditor()
                            }
                            IceBtn {
                                text: qsTr("Apply now")
                                primary: true
                                onTapped: {
                                    if (win.profIdx >= 0 && win.profIdx < win.profiles.length)
                                        win.applyProfile(win.profiles[win.profIdx]);
                                }
                            }
                            IceBtn {
                                text: qsTr("New")
                                onTapped: win.kick(profNew)
                            }
                        }
                        SetButton {
                            text: qsTr("Delete profile")
                            danger: true
                            confirmText: qsTr("Delete %1").arg(win.editName || qsTr("profile"))
                            enabled: win.profiles.length > 1
                            onClicked: {
                                profDel.want = win.editName;
                                win.kick(profDel);
                            }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }

            // ── RGB ───────────────────────────────────────────────────
            ColumnLayout {
                anchors.fill: parent
                visible: win.tab === "RGB"
                spacing: Theme.s4
                Text {
                    Layout.fillWidth: true
                    text: qsTr("RGB")
                    color: Theme.text
                    font.family: Theme.fUiTitle
                    font.pixelSize: Theme.tDisplay
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    clip: true
                }
                Text {
                    Layout.fillWidth: true
                    text: win.rgb.n ? qsTr("OpenRGB — %1 device(s) ready").arg(win.rgb.n)
                                    : qsTr("OpenRGB — no devices reported")
                    color: Theme.textMuted
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    elide: Text.ElideRight
                    clip: true
                }
                Row {
                    Layout.fillWidth: true
                    spacing: Theme.s4
                    Repeater {
                        model: win.rgbNames
                        Item {
                            required property var modelData
                            width: 72
                            height: 96
                            scale: swTap.pressed ? 0.985 : (swHov.hovered ? 1.012 : 1.0)
                            Behavior on scale {
                                NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutQuint }
                            }
                            Rectangle {
                                id: well
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 8
                                width: 44
                                height: 44
                                radius: 22
                                color: Theme.soften(Theme.void_, 0.85)
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 36
                                    height: 36
                                    radius: 18
                                    color: win.swatchColor(String(modelData))
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 22
                                    color: "transparent"
                                    border.width: (win.rgbName === modelData || swHov.hovered) ? 1 : 0
                                    border.color: win.iceFocus
                                }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: well.bottom
                                anchors.topMargin: 6
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: String(modelData)
                                color: win.rgbName === modelData ? Theme.text : Theme.textDim
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tMicro
                                font.weight: win.rgbName === modelData ? Theme.wStrong : Font.Normal
                                elide: Text.ElideRight
                                clip: true
                            }
                            HoverHandler { id: swHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                id: swTap
                                onTapped: {
                                    win.rgbName = String(modelData);
                                    rgbSet.want = String(modelData);
                                    win.kick(rgbSet);
                                }
                            }
                        }
                    }
                }
                Row {
                    spacing: Theme.s3
                    Repeater {
                        model: [
                            { id: "static", label: qsTr("Static") },
                            { id: "rainbow", label: qsTr("Rainbow") },
                            { id: "breathing", label: qsTr("Breathing") },
                            { id: "off", label: qsTr("All off") }
                        ]
                        IceBtn {
                            required property var modelData
                            text: modelData.label
                            onTapped: {
                                if (modelData.id === "static") {
                                    rgbSet.want = win.rgbName;
                                    win.kick(rgbSet);
                                } else {
                                    rgbMode.want = modelData.id;
                                    win.kick(rgbMode);
                                }
                            }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }

            // ── POWER ─────────────────────────────────────────────────
            ColumnLayout {
                anchors.fill: parent
                visible: win.tab === "Power"
                spacing: Theme.s4
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Power")
                    color: Theme.text
                    font.family: Theme.fUiTitle
                    font.pixelSize: Theme.tDisplay
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    clip: true
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.s5
                    Text {
                        text: qsTr("Power mode")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        elide: Text.ElideRight
                        clip: true
                    }
                    SetChoice {
                        visible: win.hasPower
                        value: win.power.active || ""
                        options: {
                            var out = [];
                            var modes = win.power.modes || [];
                            for (var i = 0; i < modes.length; i++)
                                out.push({ value: modes[i], label: win.powerLabel(modes[i]) });
                            return out;
                        }
                        onChosen: function (v) { win.setPower(v); }
                    }
                    Text {
                        visible: !win.hasPower
                        text: qsTr("No power-profiles-daemon on this machine.")
                        color: Theme.textMuted
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        elide: Text.ElideRight
                        clip: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        visible: win.hasPower
                        text: qsTr("via %1").arg(win.power.via || "")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                        elide: Text.ElideRight
                        clip: true
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.s5
                    visible: HardwareCaps.canSetProfile && !win.hasPower
                    Text {
                        text: qsTr("Firmware profile")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        elide: Text.ElideRight
                        clip: true
                    }
                    LiveMark {
                        actual: !!(HardwareCaps.platformProfile && HardwareCaps.platformProfile.value === win.wantPlat)
                        want: true
                        armed: platMark.armed
                        failed: platMark.failed
                    }
                    SetChoice {
                        id: platChoice
                        value: HardwareCaps.platformProfile ? HardwareCaps.platformProfile.value : ""
                        options: {
                            var out = [];
                            var ch = HardwareCaps.platformProfile ? (HardwareCaps.platformProfile.choices || []) : [];
                            for (var i = 0; i < ch.length; i++)
                                out.push({ value: ch[i], label: win.powerLabel(ch[i]) });
                            return out;
                        }
                        onChosen: function (v) { win.setPlat(v); }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.s5
                    Text {
                        text: qsTr("CPU governor")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        elide: Text.ElideRight
                        clip: true
                    }
                    LiveMark {
                        actual: !!(HardwareCaps.governor && HardwareCaps.governor.value === win.wantGov)
                        want: true
                        armed: govMark.armed
                        failed: govMark.failed
                    }
                    SetChoice {
                        id: govChoice
                        visible: HardwareCaps.canSetGovernor
                        value: HardwareCaps.governor ? HardwareCaps.governor.value : ""
                        options: {
                            var out = [];
                            var ch = HardwareCaps.governor ? (HardwareCaps.governor.choices || []) : [];
                            for (var i = 0; i < ch.length; i++)
                                out.push({ value: ch[i], label: ch[i] });
                            return out;
                        }
                        onChosen: function (v) { win.setGov(v); }
                    }
                    Text {
                        visible: !HardwareCaps.canSetGovernor
                        text: HardwareCaps.hasGovernor
                              ? qsTr("Governor is exposed but nothing may write it.")
                              : qsTr("This machine has no cpufreq governor.")
                        color: Theme.textMuted
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        elide: Text.ElideRight
                        clip: true
                    }
                    Item { Layout.fillWidth: true }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.s5
                    visible: HardwareCaps.hasEpp
                    Text {
                        text: qsTr("Energy preference")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        elide: Text.ElideRight
                        clip: true
                    }
                    LiveMark {
                        actual: !!(HardwareCaps.epp && HardwareCaps.epp.value === win.wantEpp)
                        want: true
                        armed: eppMark.armed
                        failed: eppMark.failed
                    }
                    SetChoice {
                        id: eppChoice
                        visible: HardwareCaps.canSetEpp
                        segmentLimit: 2
                        value: HardwareCaps.epp ? HardwareCaps.epp.value : ""
                        options: {
                            var out = [];
                            var ch = HardwareCaps.epp ? (HardwareCaps.epp.choices || []) : [];
                            for (var i = 0; i < ch.length; i++)
                                out.push({ value: ch[i], label: String(ch[i]).replace(/_/g, " ") });
                            return out;
                        }
                        onChosen: function (v) { win.setEpp(v); }
                    }
                    Item { Layout.fillWidth: true }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.s5
                    Text {
                        text: qsTr("CPU Boost")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        elide: Text.ElideRight
                        clip: true
                    }
                    LiveMark {
                        actual: win.boost === true
                        want: win.wantBoost
                        armed: boostMark.armed
                        failed: boostMark.failed
                    }
                    SetSwitch {
                        checked: win.boost === true
                        enabled: win.hasBoost
                        pending: boostMark.pending
                        failed: boostMark.failed
                        onToggled: function (v) { win.setBoost(v); }
                    }
                    Text {
                        visible: !win.hasBoost
                        text: qsTr("No cpufreq/boost and no intel_pstate/no_turbo on this kernel.")
                        color: Theme.textMuted
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        elide: Text.ElideRight
                        clip: true
                    }
                    Item { Layout.fillWidth: true }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 3
                    rowSpacing: Theme.s4
                    columnSpacing: Theme.s4
                    AppCard {
                        kicker: qsTr("GOVERNOR")
                        value: (HardwareCaps.governor && HardwareCaps.governor.value)
                               ? String(HardwareCaps.governor.value) : (win.cpu.governor || "—")
                        telemetry: win.cpu.driver || ""
                        pipKind: "ice"
                    }
                    AppCard {
                        kicker: qsTr("BOOST")
                        value: win.hasBoost ? (win.boost ? qsTr("ON") : qsTr("OFF")) : "—"
                        telemetry: qsTr("turbo / precision boost")
                        pipKind: win.boost ? "ice" : "off"
                    }
                    AppCard {
                        kicker: qsTr("UPTIME")
                        value: (win.uptime && win.uptime.text) ? String(win.uptime.text) : "—"
                        pipKind: "off"
                    }
                    AppCard {
                        kicker: qsTr("PER-CORE FREQ")
                        value: win.cpu.freq ? String(win.cpu.freq.avg) : "—"
                        unit: win.cpu.freq ? qsTr("MHz") : ""
                        telemetry: win.cpu.freq ? (qsTr("min %1 · max %2").arg(win.cpu.freq.min).arg(win.cpu.freq.max)) : ""
                        pipKind: "ice"
                        fill: win.cpu.freq && win.cpu.freq.max ? Math.max(0, Math.min(1, Number(win.cpu.freq.avg) / Number(win.cpu.freq.max))) : -1
                    }
                    AppCard {
                        kicker: qsTr("BATTERY")
                        value: win.batt.present ? String(win.batt.pct) : "—"
                        unit: win.batt.present ? "%" : ""
                        telemetry: win.batt.present ? String(win.batt.status) : qsTr("desktop — no battery")
                        pipKind: (win.batt.present && win.batt.pct <= 15) ? "magma" : (win.batt.present ? "ice" : "off")
                        fill: win.batt.present ? Number(win.batt.pct) / 100 : -1
                    }
                    AppCard {
                        kicker: qsTr("POWER PROFILE")
                        value: win.powerLabel(win.profile)
                        telemetry: win.host
                        pipKind: win.profile.length ? "ice" : "off"
                    }
                }
                Item { Layout.fillHeight: true }
            }

            // ── PROCESSES ─────────────────────────────────────────────
            ColumnLayout {
                anchors.fill: parent
                visible: win.tab === "Processes"
                spacing: Theme.s3
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: qsTr("Processes")
                        color: Theme.text
                        font.family: Theme.fUiTitle
                        font.pixelSize: Theme.tDisplay
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        clip: true
                    }
                    Item { Layout.fillWidth: true }
                    SetButton {
                        text: qsTr("Kill process")
                        danger: true
                        confirmText: qsTr("SIGTERM PID %1").arg(win.selPid)
                        enabled: win.selPid > 1
                        onClicked: {
                            killer.pid = win.selPid;
                            win.kick(killer);
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.s3
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: Theme.r1
                        color: Theme.soften(Theme.void_, 0.62)
                        border.width: 1
                        border.color: Theme.soften(win.iceHair, filtHov.hovered ? 0.85 : 0.45)
                        TextInput {
                            id: filtField
                            anchors.fill: parent
                            anchors.margins: 8
                            color: Theme.text
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tBody
                            clip: true
                            onTextChanged: win.procFilter = text
                        }
                        Text {
                            anchors.fill: filtField
                            visible: filtField.text.length === 0 && !filtField.activeFocus
                            text: qsTr("Filter processes…")
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tBody
                            enabled: false
                        }
                        HoverHandler { id: filtHov }
                    }
                    Repeater {
                        model: [
                            { id: "cpu", label: qsTr("CPU%") },
                            { id: "rss", label: qsTr("MEM") },
                            { id: "pid", label: qsTr("PID") },
                            { id: "name", label: qsTr("Name") }
                        ]
                        IceBtn {
                            required property var modelData
                            text: modelData.label
                            primary: win.procSort === modelData.id
                            onTapped: win.procSort = modelData.id
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.preferredWidth: 64
                        text: qsTr("PID")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                        font.weight: Theme.wStrong
                        elide: Text.ElideRight
                        clip: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Name")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                        font.weight: Theme.wStrong
                        elide: Text.ElideRight
                        clip: true
                    }
                    Text {
                        Layout.preferredWidth: 64
                        text: qsTr("CPU%")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                        font.weight: Theme.wStrong
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
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideRight
                        clip: true
                    }
                }
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: procCol.height
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: procCol
                        width: parent.width
                        spacing: 2
                        Repeater {
                            model: win.shownProcs
                            Item {
                                id: prow
                                required property var modelData
                                width: procCol.width
                                height: 30
                                readonly property bool on: win.selPid === modelData.pid
                                scale: pTap.pressed ? 0.985 : (pHov.hovered ? 1.012 : 1.0)
                                Behavior on scale {
                                    NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutQuint }
                                }
                                CutRect {
                                    anchors.fill: parent
                                    radius: Theme.r1
                                    color: prow.on ? Theme.elevated : "transparent"
                                    borderWidth: (prow.on || pHov.hovered) ? 1 : 0
                                    borderColor: pHov.hovered ? win.iceFocus : Theme.soften(win.iceHair, 0.70)
                                }
                                Rectangle {
                                    width: 3
                                    height: parent.height - 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    radius: 1
                                    color: Theme.tokenAccentPrimary
                                    opacity: Math.max(0.15, Math.min(1, Number(modelData.cpu || 0) / 40))
                                }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.s4
                                    anchors.rightMargin: Theme.s3
                                    spacing: Theme.s3
                                    Text {
                                        Layout.preferredWidth: 56
                                        text: String(modelData.pid)
                                        color: Theme.textDim
                                        font.family: Theme.fNum
                                        font.pixelSize: Theme.tCaption
                                        font.features: ({ "tnum": 1 })
                                        elide: Text.ElideRight
                                        clip: true
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: String(modelData.name)
                                        color: Theme.text
                                        font.family: Theme.fUi
                                        font.pixelSize: Theme.tCaption
                                        elide: Text.ElideRight
                                        clip: true
                                    }
                                    Text {
                                        Layout.preferredWidth: 56
                                        text: Number(modelData.cpu || 0).toFixed(1)
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
                                        text: win.mib(modelData.rss)
                                        color: Theme.textMuted
                                        font.family: Theme.fNum
                                        font.pixelSize: Theme.tCaption
                                        font.features: ({ "tnum": 1 })
                                        horizontalAlignment: Text.AlignRight
                                        elide: Text.ElideRight
                                        clip: true
                                    }
                                }
                                HoverHandler { id: pHov; cursorShape: Qt.PointingHandCursor }
                                TapHandler { id: pTap; onTapped: win.selPid = modelData.pid }
                            }
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: qsTr("%1 shown").arg(win.shownProcs.length)
                          + (win.selPid ? qsTr(" · selected PID %1").arg(win.selPid) : "")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    elide: Text.ElideRight
                    clip: true
                }
            }
        }
    }
}
