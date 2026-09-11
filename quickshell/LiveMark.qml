pragma ComponentBehavior: Bound
// Ping-loop lamp for a live Settings control.
// pending: cyan pulse until the daemon matches `want`.
// failed:  amber until the next request. Never invents success.
import QtQuick

Item {
    id: mark

    // Strings, bools, or ids — compare with === against the daemon readout.
    property var actual
    property var want
    property bool armed: false
    property bool failed: false
    property int timeoutMs: 4000

    readonly property bool pending: mark.armed && !mark.failed && mark.want !== mark.actual
    readonly property string kind: mark.failed ? "amber" : (mark.pending ? "ice" : "off")

    width: pip.visible ? 7 : 0
    height: 7
    implicitWidth: mark.width
    implicitHeight: mark.height

    function request(v) {
        mark.want = v;
        mark.armed = true;
        mark.failed = false;
        if (mark.actual === mark.want) {
            mark.armed = false;
            gate.stop();
            return;
        }
        gate.restart();
    }

    function fail() {
        mark.armed = true;
        mark.failed = true;
        gate.stop();
    }

    function clear() {
        mark.armed = false;
        mark.failed = false;
        gate.stop();
    }

    onActualChanged: {
        if (!mark.armed)
            return;
        if (mark.actual === mark.want) {
            mark.armed = false;
            mark.failed = false;
            gate.stop();
        }
    }

    Timer {
        id: gate
        interval: mark.timeoutMs
        repeat: false
        onTriggered: {
            if (mark.armed && mark.actual !== mark.want)
                mark.failed = true;
        }
    }

    StatusPip {
        id: pip
        anchors.centerIn: parent
        kind: mark.kind
        pulse: mark.pending || mark.failed
    }
}
