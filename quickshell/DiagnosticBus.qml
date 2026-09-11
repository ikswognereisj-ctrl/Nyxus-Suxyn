pragma Singleton
// Nyxus Suxyn — the Settings LIVE DIAGNOSTIC BUS.
//
// The right pane of the calibration rack. Controls in the kit call
// `append` / `logSwitch` / `logSlider` / `logButton` / `logChoice`;
// Settings.qml paints `lines`. Cap is hard so a live slider cannot
// grow an unbounded model.
import Quickshell
import QtQuick

Singleton {
    id: bus

    readonly property int cap: 80
    property int count: 0
    property int seq: 0

    ListModel { id: lineModel }
    readonly property alias lines: lineModel

    function stamp() {
        var d = new Date();
        function p(n) { return (n < 10 ? "0" : "") + n; }
        return p(d.getHours()) + ":" + p(d.getMinutes()) + ":" + p(d.getSeconds());
    }

    function append(line) {
        var text = bus.stamp() + "  " + String(line || "");
        lineModel.append({ line: text });
        while (lineModel.count > bus.cap)
            lineModel.remove(0);
        bus.count = lineModel.count;
        bus.seq += 1;
    }

    function _shown(v) {
        var n = Number(v);
        if (!isFinite(n))
            return String(v);
        if (Math.abs(n) <= 2)
            return n.toFixed(2);
        if (Math.abs(n - Math.round(n)) < 1e-6)
            return String(Math.round(n));
        return (Math.round(n * 100) / 100).toString();
    }

    function logSwitch(key, value) {
        var k = String(key || "");
        var on = value ? "on" : "off";
        if (/wifi|network|nmcli/i.test(k))
            bus.append("nmcli: radio wifi " + on);
        else if (/bluetooth|bluez/i.test(k))
            bus.append("bluetoothctl: power " + on);
        else if (/mute/i.test(k))
            bus.append("wpctl: mute " + on);
        else
            bus.append("set: " + (k !== "" ? k : "switch") + " " + on);
    }

    function logSlider(key, value, from, to) {
        var k = String(key || "");
        var n = Number(value);
        var shown = bus._shown(n);
        var lo = Number(from);
        var hi = Number(to);
        var volRange = isFinite(lo) && isFinite(hi) && lo === 0 && hi >= 1 && hi <= 1.5;
        if (/volume|sound|sink|source/i.test(k) || (k === "" && volRange))
            bus.append("wpctl: volume set " + (isFinite(n) ? n.toFixed(2) : shown));
        else if (/bright/i.test(k))
            bus.append("brightnessctl: set " + shown);
        else
            bus.append("set: " + (k !== "" ? k : "slider") + " " + shown);
    }

    function logButton(label, danger) {
        var t = String(label || "action");
        bus.append((danger ? "exec!: " : "exec: ") + t);
    }

    function logChoice(key, value) {
        var k = String(key || "choice");
        bus.append("set: " + k + " " + String(value));
    }

    Component.onCompleted: {
        bus.append("rack: calibration bus online");
        bus.append("rack: waiting for node");
    }
}
