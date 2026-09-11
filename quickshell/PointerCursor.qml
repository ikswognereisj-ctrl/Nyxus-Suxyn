pragma Singleton
// Nyxus Suxyn — global pointer sample for the optional trail.
//
// One long-lived `hyprctl` loop, parsed in-process. Not a Process per
// frame (hyprlock lesson). Runs only while Prefs.pointerTrailEnabled.
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: cur

    property real cx: 0
    property real cy: 0
    property var pts: []

    Process {
        running: Prefs.pointerTrailEnabled
        // Plain `cursorpos` is one line (`789, 904`). `-j` pretty-prints
        // across several lines, and SplitParser never reconstructs the
        // object — the Overlay mapped, pts stayed empty, the owner saw
        // nothing. Measured 2026-08-20 on wayland-1.
        command: ["sh", "-c",
                  "while :; do hyprctl cursorpos 2>/dev/null; sleep 0.016; done"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => cur._eat(line)
        }
        onRunningChanged: if (!running) cur.pts = []
    }

    function _eat(line) {
        var s = String(line).trim();
        if (s.length < 1)
            return;
        var x, y;
        if (s.charAt(0) === "{") {
            try {
                var o = JSON.parse(s);
                x = o.x;
                y = o.y;
            } catch (e) {
                return;
            }
        } else {
            var p = s.split(",");
            if (p.length < 2)
                return;
            x = parseFloat(p[0]);
            y = parseFloat(p[1]);
        }
        if (isNaN(x) || isNaN(y))
            return;
        cur.cx = x;
        cur.cy = y;
        var now = Date.now();
        var next = [];
        for (var i = 0; i < cur.pts.length; i++)
            if (now - cur.pts[i].t < 1400)
                next.push(cur.pts[i]);
        var last = next.length ? next[next.length - 1] : null;
        if (!last || Math.abs(last.x - x) + Math.abs(last.y - y) > 0.6)
            next.push({ x: x, y: y, t: now });
        if (next.length > 80)
            next.shift();
        cur.pts = next;
    }
}
