pragma ComponentBehavior: Bound
// Nyxus Suxyn — pointer trail. Overlay, never a click, never Spill.
//
// Owner 2026-08-20: the MicroPulse-style hill — a dense VOLUME of fine
// teal dust, Gaussian off the path, hot at the spine, not a ribbon and
// not four-ray sparkles. Colour follows the swirl layer.
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    // TRK-1221: reduced motion = no trail. The Overlay stays mapped but paints
    // nothing and its repaint Timer is stopped.
    visible: !Prefs.reducedMotion
    id: root
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nyxus-trail"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    mask: Region {}
    anchors { left: true; right: true; top: true; bottom: true }

    readonly property string layerKey: {
        var k = Prefs.pointerTrailLayer;
        if (k === "match")
            k = Prefs.swirlLayer;
        return Theme.paintLayers[k] !== undefined ? k : "glacier";
    }
    // Typed as color so hex strings from paintLayers become r/g/b.
    // Reading ramp[i].r off a string was NaN → rgba(0,0,0) — black dust
    // on a black wallpaper, which is why the trail vanished.
    readonly property color dye: Theme.paintLayers[root.layerKey][0]
    readonly property color ice: Theme.paintLayers[root.layerKey][5]
    readonly property color peak: Theme.paintLayers[root.layerKey][6]
    readonly property real fadeMs: 1200

    function _catmull(p0, p1, p2, p3, t) {
        var t2 = t * t, t3 = t2 * t;
        return 0.5 * ((2 * p1)
            + (-p0 + p2) * t
            + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
            + (-p0 + 3 * p1 - 3 * p2 + p3) * t3);
    }

    function _rand(a, b) {
        var s = Math.sin(a * 12.9898 + b * 78.233) * 43758.5453;
        return s - Math.floor(s);
    }

    function _gauss(a, b) {
        var u = Math.max(0.0001, root._rand(a, b));
        var v = root._rand(b, a + 1.7);
        return Math.sqrt(-2.0 * Math.log(u)) * Math.cos(6.2831853 * v);
    }

    function _rgba(c, a) {
        return "rgba(" + Math.round(c.r * 255) + ","
            + Math.round(c.g * 255) + ","
            + Math.round(c.b * 255) + "," + a.toFixed(3) + ")";
    }

    Canvas {
        id: trail
        anchors.fill: parent
        renderStrategy: Canvas.Immediate
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var ox = root.screen ? root.screen.x : 0;
            var oy = root.screen ? root.screen.y : 0;
            var raw = PointerCursor.pts;
            var now = Date.now();
            var fade = root.fadeMs;
            var src = [];
            var i;
            for (i = 0; i < raw.length; i++) {
                if ((now - raw[i].t) / fade < 1)
                    src.push(raw[i]);
            }
            var n = src.length;
            if (n < 2)
                return;

            var mid = root.dye;
            var ice = root.ice;
            var peak = root.peak;

            var xs = [], ys = [], along = [], ageA = [];
            var steps = 3;
            for (i = 0; i < n - 1; i++) {
                var p0 = src[Math.max(0, i - 1)];
                var p1 = src[i];
                var p2 = src[i + 1];
                var p3 = src[Math.min(n - 1, i + 2)];
                var s;
                for (s = 0; s < steps; s++) {
                    var t = s / steps;
                    xs.push(root._catmull(p0.x, p1.x, p2.x, p3.x, t) - ox);
                    ys.push(root._catmull(p0.y, p1.y, p2.y, p3.y, t) - oy);
                    along.push((i + t) / (n - 1));
                    ageA.push((now - (p1.t + (p2.t - p1.t) * t)) / fade);
                }
            }
            xs.push(src[n - 1].x - ox);
            ys.push(src[n - 1].y - oy);
            along.push(1);
            ageA.push((now - src[n - 1].t) / fade);

            var m = xs.length;
            ctx.globalCompositeOperation = "lighter";

            for (i = 0; i < m; i++) {
                var u = along[i];
                var age = Math.max(0, Math.min(1, ageA[i]));
                var live = 1 - age;
                if (live <= 0.04)
                    continue;

                var dx, dy, len;
                if (i === 0) {
                    dx = xs[1] - xs[0];
                    dy = ys[1] - ys[0];
                } else if (i === m - 1) {
                    dx = xs[i] - xs[i - 1];
                    dy = ys[i] - ys[i - 1];
                } else {
                    dx = xs[i + 1] - xs[i - 1];
                    dy = ys[i + 1] - ys[i - 1];
                }
                len = Math.sqrt(dx * dx + dy * dy);
                if (len < 0.001)
                    len = 1;
                var tx = dx / len, ty = dy / len;
                var nx = -ty, ny = tx;

                // Hill of dust: Gaussian off the spine. Tight + bright at
                // the cursor, a little wider and dimmer behind.
                var sigma = 5.5 + 9.0 * (1 - u);
                var count = 18 + Math.floor(16 * u);
                var k;
                for (k = 0; k < count; k++) {
                    var gp = root._gauss(i + 0.13, k + 2.4);
                    var gt = root._gauss(k + 7.1, i + 4.8) * 0.35;
                    var px = xs[i] + nx * gp * sigma + tx * gt * sigma;
                    var py = ys[i] + ny * gp * sigma + ty * gt * sigma;

                    var r3 = root._rand(i * 0.41, k * 2.17);
                    var dist = Math.abs(gp);
                    var core = dist < 0.55;
                    var col = core ? (r3 > 0.55 ? peak : ice) : mid;
                    var rad = core ? (0.7 + r3 * 1.1) : (0.35 + r3 * 0.7);
                    var a = live * (0.28 + 0.62 * u) * (core ? 0.95 : 0.45)
                            * Math.exp(-dist * dist * 0.45);
                    if (a < 0.03)
                        continue;

                    ctx.fillStyle = root._rgba(col, a);
                    ctx.fillRect(px - rad, py - rad, rad * 2, rad * 2);
                }
            }
        }
    }

    // ── the repaint clock · runs only while there is dust to draw ────────
    // TRK-2500. It used to be `running: Prefs.pointerTrailEnabled &&
    // !Prefs.reducedMotion` — two settings and nothing else. Both are true
    // for as long as the feature is switched on, so the clock ran for the
    // life of the session: 31 full-screen `Canvas` repaints a second with a
    // stationary pointer and an empty trail, each one a `ctx.reset()` over
    // the whole output plus a texture upload, on the GUI thread, forever.
    // `Canvas.Immediate` means that work is done by the thread that must also
    // service every other surface in the shell.
    //
    // Nothing was gained by any of it. `onPaint` drops out at `n < 2` once
    // the last sample is older than `fadeMs`, so every one of those repaints
    // after the pointer stopped cleared the canvas and drew NOTHING.
    //
    // The clock is now armed by movement and disarms itself one tick after
    // the last point goes stale. That final tick is deliberate and it is the
    // only reason `stop()` is not called before `requestPaint()`: it is the
    // repaint that CLEARS the last of the dust off the screen. Stopping first
    // would freeze the trail's dying frame on an Overlay surface until the
    // pointer moved again.
    //
    // `_live()` is `onPaint`'s OWN precondition, restated: the same list, the
    // same `fadeMs`, and the same `n < 2` — two live samples, because one
    // point is not a path and the painter returns without drawing on it. The
    // clock therefore cannot stop while `onPaint` would still have drawn, and
    // cannot run while it would not: they are one predicate, not two that
    // have to be kept in step.
    //
    // The TWO is load-bearing and it was measured. `PointerCursor` drops
    // samples older than 1400 ms, and when that empties the list it appends
    // the next sample unconditionally (`!last ||`) — so a pointer that has
    // not moved in an hour still produces one fresh point every ~1.4 s. A
    // one-live-point test reads that as motion and the clock runs ~86% of the
    // time: measured 271 repaints per 10 s on a stationary pointer. Requiring
    // two matches the painter and reads it, correctly, as stillness.
    //
    // Measured at idle, nested Hyprland, pointer untouched, repaints per 10 s
    // (docs/proof/shellperf-0822/paint-counts.txt):
    //   origin/main            746 · 577 · 401 · 396
    //   one live point         274 · 271 · 262 · 264
    //   two live points (this)   1 ·   0 ·   0 ·   0
    // And it still PAINTS on movement, which is the half a repaint count on
    // its own cannot tell you — a fix that stopped the trail working would
    // score zero too. Same harness, cursor driven with `hyprctl dispatch
    // movecursor` (verified in `method-cursor-probe.sh` to actually move what
    // `hyprctl cursorpos` reports): 156 repaints per 5 s = 31/s, the Timer's
    // own rate, with 54–65 live points and the clock reading `running: true`.
    function _live(): bool {
        var raw = PointerCursor.pts;
        var now = Date.now();
        var n = 0;
        for (var i = 0; i < raw.length; i++)
            if (now - raw[i].t < root.fadeMs && ++n > 1)
                return true;
        return false;
    }

    readonly property bool trailWanted: root.visible && Prefs.pointerTrailEnabled
                                        && !Prefs.reducedMotion

    Connections {
        target: PointerCursor
        // Arming, NOT painting. Repainting straight off this signal was a
        // second, faster clock: `PointerCursor` publishes ~60 samples a
        // second, so the canvas was being redrawn at roughly twice the rate
        // the Timer below asks for and the Timer's interval described
        // nothing. One clock now owns the frame rate.
        //
        // `if (!running)` and not `restart()`: restarting a repeating Timer
        // on every sample resets its countdown, and at 60 samples a second
        // against a 32 ms interval it would never have reached a trigger.
        //
        // `_live()` is checked HERE as well as in the trigger, and it is not
        // belt-and-braces. `PointerCursor` rebuilds and reassigns `pts` on
        // EVERY sample — it only appends a point when the pointer actually
        // moved, but the assignment (and therefore this signal) happens ~60
        // times a second regardless. Arming on the signal alone re-armed the
        // clock immediately after each self-stop and left it painting an
        // empty canvas at ~20 Hz: a slower version of the same defect.
        function onPtsChanged() {
            if (root.trailWanted && !repaint.running && root._live())
                repaint.running = true;
        }
    }
    Timer {
        id: repaint
        interval: 32
        repeat: true
        running: false
        onTriggered: {
            trail.requestPaint();
            if (!root.trailWanted || !root._live())
                repaint.running = false;
        }
    }
    // Switching the feature off (or turning reduced motion on) stops the
    // clock in the same breath rather than at the next stale tick, and the
    // Overlay is left clear rather than holding a frame of dust.
    onTrailWantedChanged: if (!trailWanted) { repaint.running = false; trail.requestPaint(); }
}
