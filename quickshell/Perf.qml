// NYXUS — Perf.qml · the timing-budget watchdog (TRK-1273 / CS-1134)
//
// WHAT IT DOES
// ────────────
// Writes one line per budget miss to ~/.local/state/nyxus/perf.log:
//
//     2026-08-22T05:01:12.345Z stall 87ms
//     2026-08-22T05:01:40.010Z frame 41ms
//     2026-08-22T05:02:01.500Z ipc 63ms ping
//
//   · `stall` — the GUI thread was late: a 250 ms repeating Timer fired more
//     than 50 ms after it was due. A stalled GUI thread cannot hand the
//     renderer a new frame, so this is the cause of every dropped frame the
//     shell itself is responsible for, and it is measured continuously at
//     the cost of four wake-ups a second and nothing else.
//   · `frame` — a FrameAnimation tick longer than 33 ms (two vsyncs at 60 Hz)
//     during a SAMPLE WINDOW: 2 s of FrameAnimation every 30 s, never
//     continuous. A running FrameAnimation keeps the global animation timer
//     ticking and the scene re-rendering; left on it would cost the idle
//     desktop real power and — inside a panel window — it is WIP-245's
//     segfault (`ScrollRail.qml`, "the crash rule"). This lives at ShellRoot
//     scope, outside every window, and runs 6% of the time.
//   · `ipc` — anything wrapped in `Perf.time(label, fn)` that took over 50 ms.
//     The IpcHandler functions are void one-liners with no timing hook of
//     their own, so today only `ping` is wrapped; the helper is the hook.
//
// Lines are batched and flushed every 5 s through one `sh -c` (never a
// process per line), the file rotates to perf.log.1 at 256 KiB, and the
// batch is capped at 200 lines between flushes — a storm drops lines and
// says how many, it does not grow without bound. Nothing here reads the log;
// nyxus-smoke-probe (TRK-1270) and the Health page (TRK-1233, CR) do.
//
// NOT a profiler and not a claim: a budget miss logged here is a symptom with
// a timestamp, to be put beside the shell.log and the journal. The numbers
// are wall-clock milliseconds from Date.now() / FrameAnimation.frameTime.
import Quickshell
import QtQuick

Scope {
    id: perf

    readonly property string dir: (Quickshell.env("XDG_STATE_HOME")
                                   || (Quickshell.env("HOME") + "/.local/state")) + "/nyxus"
    readonly property string path: dir + "/perf.log"
    readonly property int frameBudgetMs: 33
    readonly property int stallBudgetMs: 50
    readonly property int rotateBytes: 262144
    readonly property int maxPending: 200

    property var pending: []
    property int dropped: 0
    property double lastTick: 0
    property bool sampling: false

    function note(kind: string, ms: real, detail: string): void {
        if (pending.length >= maxPending) { dropped += 1; return; }
        var line = new Date().toISOString() + " " + kind + " " + Math.round(ms) + "ms"
                 + (detail ? " " + detail : "");
        // the line travels through `printf '%s\n' "..."` — keep it printable
        // ASCII and strip anything the shell would read as syntax.
        pending.push(line.replace(/[^\x20-\x7e]/g, "?").replace(/["`$\\]/g, "'"));
    }

    // The hook: wrap a call, log it if it blew the IPC budget, return its value.
    function time(label: string, fn: var): var {
        var t0 = Date.now();
        var r = fn();
        var dt = Date.now() - t0;
        if (dt > stallBudgetMs) note("ipc", dt, label);
        return r;
    }

    function flush(): void {
        if (pending.length === 0 && dropped === 0) return;
        var lines = pending;
        pending = [];
        if (dropped > 0) {
            lines.push(new Date().toISOString() + " dropped " + dropped + "ms storm-cap");
            dropped = 0;
        }
        var quoted = lines.map(function (l) { return '"' + l + '"'; }).join(" ");
        var script = 'd="' + dir + '"; f="' + path + '"; mkdir -p "$d" || exit 0; '
                   + 'if [ -f "$f" ] && [ "$(stat -c %s "$f" 2>/dev/null || echo 0)" -gt '
                   + rotateBytes + ' ]; then mv -f "$f" "$f.1"; fi; '
                   + "printf '%s\\n' " + quoted + ' >> "$f"';
        Quickshell.execDetached(["sh", "-c", script]);
    }

    // ── the stall detector: continuous, four wake-ups a second ───────────
    Timer {
        id: tick
        interval: 250
        running: true
        repeat: true
        onTriggered: {
            var now = Date.now();
            if (perf.lastTick > 0) {
                var late = now - perf.lastTick - interval;
                if (late > perf.stallBudgetMs) perf.note("stall", late, "");
            }
            perf.lastTick = now;
        }
    }

    // ── the frame sampler: 2 s in every 30 s, never continuous ───────────
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { perf.sampling = true; sampleOff.restart(); }
    }
    Timer {
        id: sampleOff
        interval: 2000
        onTriggered: perf.sampling = false
    }
    FrameAnimation {
        running: perf.sampling
        onTriggered: {
            var dt = frameTime * 1000;
            if (dt > perf.frameBudgetMs) perf.note("frame", dt, "");
        }
    }

    // ── the writer ───────────────────────────────────────────────────────
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: perf.flush()
    }
    Component.onCompleted: {
        pending.push(new Date().toISOString() + " start 0ms shell-up");
    }
}
