pragma Singleton
// Nyxus Suxyn — PaintMood. What the living paint KNOWS about the machine.
//
// The owner's ask, verbatim (2026-08-15): "do a living paint reacting to
// system state warmer under cpu load cooler when idle slow pulse when scan is
// done ECT".
//
// The paint already lives (`Swirl.qml`). This singleton is the one place that
// turns real machine state into the two numbers the paint wears:
//
//   `warmth`  0..1 — a slow drift from the machine's own load average. At 0
//                    the ramp is EXACTLY the layer the owner picked; at 1 it
//                    has leaned 30% of the way toward the ember anchor.
//   `pulse`   0..1 — ONE swell, ~7 s, when a Hemera scan finishes. It ends by
//                    itself and it never repeats. There is no permanent
//                    animation anywhere in this file.
//
// ══ THE LAWS THIS FILE IS WRITTEN AGAINST ═══════════════════════════════════
// Every one of these has been violated in this repo before and every one of
// them is checked by gate `13q37`.
//
//  1. WIP-648 — DYE IS INJECTED PER UNIT TIME, NEVER PER FRAME OR PER EVENT.
//     Nothing here injects dye at all. `warmth` re-colours the ramp the
//     splat pass already samples, and `pulse` lifts the DISPLAY pass's bloom.
//     Neither adds a deposit, so a machine under sustained load cannot become
//     a dye firehose the way the collide playground did on the owner's GPU.
//
//  2. ONE TIMER, AND ITS INTERVAL IS ARGUED FOR IN WRITING (below).
//
//  3. TIMERS ONLY WHILE MAPPED. The timer runs only while at least one Swirl
//     is actually stepping its solver (`Swirl.running` — window mapped, past
//     the map/configure settle, not battery-parked, not slept out its
//     linger). Every Swirl attaches on `running` and detaches when it falls,
//     and `Component.onDestruction` detaches too, so a Loader tearing a panel
//     down cannot leak a watcher. Zero watchers = zero timers.
//
//  4. MISSING OR UNREADABLE STATE IS THE PAINT'S NORMAL APPEARANCE WITH ZERO
//     TIMERS — never a fake reading. If the CPU count cannot be read the
//     timer never starts; if the load read FAILS the timer STOPS
//     (`_readDead`). Either way `active` is false, `ramp` is the same array
//     as `Theme.paintRamp`, and `warmth` is 0. There is no "assume 4 cores"
//     anywhere in this file: an invented denominator is an invented reading.
//
//     ⚠ The second half of that sentence was MISSING until break-proof 14
//     found it. With `/proc/loadavg` unreadable the CPU count still resolved,
//     so the timer went on ticking every 30 s for a reading that would never
//     arrive — the paint correctly showing its normal appearance and paying
//     for a clock to do it. "Normal appearance AND zero timers" is one law,
//     not two, and half of it is not a pass.
//
//  5. THE USER CAN TURN THE WHOLE THING OFF, AND OFF MEANS ZERO TIMERS.
//     `swirl_reactive` in settings.json (Prefs.swirlReactive). With it false
//     the timer's `running` binding is false, the Hemera watch has no path,
//     `warmth` is 0 and `ramp === Theme.paintRamp` — the paint is exactly
//     what it was before this file existed.
//
//  6. THE MOTION PREFERENCE GOVERNS, exactly as the Settings chips and the
//     `SwirlStrip` bar preview do (`WIP-646`/BP's addendum). Colour is not
//     motion, so the warmth tint applies in both modes; the scan PULSE is
//     movement, so it fires only in `ambient` mode. The Hemera notification
//     is the load-bearing channel either way — the paint is the grace note,
//     never the alarm.
//
// ══ WHY 30 SECONDS, AND WHY THE LOAD AVERAGE ════════════════════════════════
// The floor in this repo is 1000 ms and it was written in blood: two hyprlock
// labels spawning subprocesses every 50 ms starved the event loop until the
// password field stopped accepting keystrokes (AUDIT-PLAN item 1). This timer
// is 30,000 ms — thirty times the floor — and it does not spawn anything at
// all: it is one `read()` of a procfs file that the kernel materialises on
// demand, no fork, no `sh -c`, no awk. Measured on this developer host the
// whole tick is a sub-millisecond read of 30-odd bytes.
//
// 30 s is not a compromise between responsiveness and cost, it is the RIGHT
// number for the thing being shown. A paint that lurches every second is
// worse than one that drifts: the owner asked for "warmer under cpu load
// cooler when idle", which is a mood, and a mood that tracks a compile's
// individual gcc invocations reads as a fault light. Two further filters sit
// on top of the interval so the number the paint wears can never step
// visibly:
//
//   · `/proc/loadavg`'s FIRST field is already a 1-minute exponentially
//     damped average. That is why this reads loadavg rather than taking
//     `/proc/stat` deltas: the kernel has done the smoothing, for free, with
//     a time constant that suits a mood. `Sys.cpuPercent` (which DOES take
//     /proc/stat deltas) stays what it has always been — the number the
//     vitals surfaces and the workload BANDS in `BorderPulse`/`ReactiveEdge`
//     read. See § WHY NOT Sys.cpuPercent below.
//
//   · this file then runs its own exponential moving average at α = 0.2, so
//     a machine going from idle to pegged expresses about a fifth of the
//     change every 30 s and needs roughly two and a half minutes to arrive.
//     One tick can therefore move the ramp by at most 20% of a 30% blend =
//     6% of the distance to the ember anchor, which is below the threshold
//     at which a colour step is visible on a moving fluid.
//
//   · and the fluid itself is the last low-pass. A ramp change only reaches
//     the screen through NEWLY INJECTED dye; the dye already in the field
//     keeps its old colour until it dissipates. So even an instantaneous
//     ramp change arrives as a drift, which is the whole reason this can be
//     a step function at all.
//
// The FIRST successful reading seeds `warmth` directly instead of easing into
// it from zero. Starting cold and climbing for two minutes would be the shell
// showing a number it knows to be wrong; the first reading is the truth.
//
// ══ WHY NOT Sys.cpuPercent ══════════════════════════════════════════════════
// It was the obvious reuse and it is the wrong one, for a reason that is
// exactly this repo's recorded failure mode. `Sys`'s vitals reader runs only
// while `vitalsActive || ambientVitals` is true, and both of those are
// LATCHED TRUE BY OTHER COMPONENTS — `BorderPulse.qml` sets `ambientVitals`
// in `Component.onCompleted` and nothing ever sets it back. So:
//
//   · if this file simply READ `Sys.cpuPercent`, the paint's mood would
//     silently freeze at 0% on any build where BorderPulse is not
//     instantiated (it is one commented-out line in `shell.qml` away, and
//     `Frame` is already commented out up there) — a fake reading, law 4;
//   · and if this file LATCHED `ambientVitals` itself, turning the reactive
//     paint off could never stop the timer, because the flag is shared and
//     un-unlatchable — law 5 broken by construction.
//
// One 30 s procfs read that this file owns end to end is cheaper than the 5 s
// `sh -c` + three awks Sys already runs, and it is the only shape in which
// "off means zero timers" is a fact rather than a hope.
//
// ══ THE SIGNAL FOR "A SCAN FINISHED" ════════════════════════════════════════
// `nyxus-hemera` (WIP-654, agent BX) writes `save_state({...})` at the end of
// every scan to `$XDG_CACHE_HOME/nyxus/hemera-state.json` (default
// `~/.cache/nyxus/hemera-state.json`), carrying `scan_id`, `finished` (unix
// seconds) and `result`. That file is the signal. It is WATCHED, not polled —
// a `FileView` with `watchChanges` costs an inotify descriptor and zero
// timers — so nothing here wakes the machine to ask whether a scan happened.
//
// Two things this deliberately does NOT do:
//   · it does not pulse on the state that is already on disk when the shell
//     starts. The first read SEEDS the baseline silently; a scan from
//     yesterday is not news. Only a `finished` strictly newer than the
//     baseline fires.
//   · it does not read the protection HISTORY (`history.jsonl`). The state
//     file is one small object rewritten in place; the history is
//     append-only and unbounded, and re-parsing it on every change would be
//     a growing cost for a boolean.
//
// The paint says a scan LANDED. It deliberately does not say what it found —
// `result` is read only to keep the swell honest in length (a run that ended
// in findings settles the same way a clean one does). Hemera's own
// three-volume notification is what tells a person what happened, and a
// second channel that could disagree with it is exactly the drift this repo
// keeps writing rules about.
//
// ══ WHAT WAS DELIBERATELY NOT ADDED ═════════════════════════════════════════
// The brief allowed "other honest states … only if the signal already
// exists". Two were considered and refused:
//   · battery — `Sys.hasBattery`/`batteryCharging` already govern the paint,
//     but they STOP it (`Swirl._saving`, WIP-339). A colour that also said
//     "on battery" would be a second, quieter statement of the same fact,
//     and the loud one is that the paint has come to rest.
//   · network throughput — `Sys.netPercent` exists but is a ratio against a
//     ROLLING PEAK it invents, by its own admission ("a link's ceiling is
//     unknowable from /proc"). Painting the machine's mood from a number
//     that redefines its own scale is a fake reading wearing a real one's
//     clothes.
// Nothing here starts a daemon, and nothing here is the first reader of any
// file this build did not already write.
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: mood

    // ── the master switches ──────────────────────────────────────────────
    // `swirlEnabled` is the paint itself; `swirlReactive` is this behaviour.
    // Both must be on. Off is not "the tint sits at zero while the machinery
    // keeps running" — see `wanted` below, which is the timer's whole gate.
    readonly property bool enabled: Prefs.swirlEnabled && Prefs.swirlReactive

    // ── the mapped-surface census (law 3) ────────────────────────────────
    // Swirl calls these off its own `running`, which is already the honest
    // "this solver is stepping in a mapped, exposed window" predicate the
    // WIP-245 segfault taught this shell to compute. A count, not a boolean:
    // the bar, the Start menu and the panel are separate Swirls with
    // independent lifetimes, and a boolean would be cleared by whichever one
    // went away first.
    property int watchers: 0
    function attach(): void { mood.watchers = mood.watchers + 1; }
    function detach(): void { if (mood.watchers > 0) mood.watchers = mood.watchers - 1; }

    // The single gate. Everything with a cost hangs off this one expression
    // so that "off means zero" is one line to read and one line to prove.
    readonly property bool wanted: mood.enabled && mood.watchers > 0

    // ── honest unknown (law 4) ───────────────────────────────────────────
    property bool haveCores: false
    property int  cores: 0
    property bool haveLoad: false
    // Set when a load read the TIMER asked for fails or parses to nonsense.
    // It stops the timer — see the note on `loadTick.running`.
    property bool _readDead: false
    // ⚠ AND THIS IS WHY `_readDead` IS NOT SET FROM EVERY FAILURE. While
    // nothing is mapped this file's FileViews carry an EMPTY path, and a
    // FileView pointed at "" reports a load FAILURE — asynchronously, so it
    // can and does arrive after `wanted` has already gone true. Marking the
    // reading dead on that failure killed the healthy path outright: the
    // `on` case went 21/21 → 17/20 with timers=0, and guarding on `wanted`
    // did not fix it because the stale failure lands when `wanted` is
    // already true. `_asked` is set by the TIMER and by nothing else, so
    // only a read this file actually requested can mark the reading dead.
    property bool _asked: false
    // `active` is the public "the paint may say something about this machine"
    // predicate. Everything downstream — warmth, the ramp, the pulse — is
    // false/zero/identity without it.
    readonly property bool active: mood.enabled && mood.haveCores && mood.haveLoad

    // The raw normalised reading (run-queue length per core, clamped), and
    // the smoothed value the paint actually wears.
    property real load: 0
    property real _ema: 0
    readonly property real warmth: mood.active ? mood._ema : 0

    // α for the exponential moving average. 0.2 = one tick moves a fifth of
    // the remaining distance; see § WHY 30 SECONDS for the arithmetic.
    readonly property real emaAlpha: 0.2
    // How far toward the ember anchor a fully-loaded machine leans. 0.30 was
    // chosen against the ramp itself, not by eye: at 0.30 no stop of any of
    // the four shipped layers crosses into the olive band that HANDOFF.md's
    // "blurred gold over purple turns olive" rule exists to keep out of this
    // palette, and every layer's BRIGHT/dark lightness ladder survives.
    // Gate 13q37 computes all 28 blended stops and fails if either is untrue,
    // which turns a rule that was previously only prose into a check.
    readonly property real maxLean: 0.30

    // ══ THE ONE TIMER ════════════════════════════════════════════════════
    // 30,000 ms. Thirty times the 1000 ms floor. The interval is argued for
    // at length in this file's header; do not lower it without replacing
    // that argument. `triggeredOnStart` so attaching a surface reads at once
    // rather than after half a minute of the last value.
    readonly property int loadIntervalMs: 30000
    Timer {
        id: loadTick
        interval: mood.loadIntervalMs
        repeat: true
        triggeredOnStart: true
        // The whole of laws 3, 4 and 5, in one binding.
        //
        // ⚠ `!_readDead` IS LAW 4, AND IT WAS MISSING. Break-proof 14 caught
        // it: with `/proc/loadavg` made unreadable, the CPU count still read
        // fine, so `haveCores` stayed true and this timer went on ticking
        // every 30 s for a reading that was never going to arrive. The paint
        // was correctly showing its normal appearance — and paying for a
        // clock to do it, which is exactly the half-kept promise the law is
        // written against. A procfs file that cannot be read once will not
        // become readable in thirty seconds; re-attaching a surface is what
        // retries it (see `onWantedChanged`).
        running: mood.wanted && mood.haveCores && !mood._readDead
        onTriggered: { mood._asked = true; loadFile.reload(); }
    }

    // ── how the timer laws are PROVED, not asserted ──────────────────────
    // Aliases to the real Timer's own properties. Deliberately aliases and
    // not re-derivations: `running: mood.wanted && mood.haveCores` written
    // out a second time here would be a copy that can drift from the timer
    // it claims to describe, and this repo has a rule about the second copy
    // of anything. An alias cannot disagree with its target.
    //
    // Gate 13q37 reads these live (`docs/proof/wip700-cf-2026-08-16/`) AND
    // separately scans this file for the number of `Timer {` declarations in
    // it, because an alias only tells the truth about the ONE timer it
    // points at — a second, unaliased timer would be invisible to it.
    // Together the two checks are the whole of "off means zero timers".
    readonly property alias loadTimerRunning: loadTick.running
    readonly property alias loadTimerInterval: loadTick.interval

    // Same shape for the Hemera watch: `path` empty and `watchChanges` false
    // is what "off holds no file watch" means, and this is the watch's own
    // state rather than a claim about it.
    readonly property alias hemeraWatchPath: hemeraState.path
    readonly property alias hemeraWatching: hemeraState.watchChanges

    // ── how many cores, read ONCE, with no timer and no guess ────────────
    // `/sys/devices/system/cpu/present` is "0-19" on a 20-thread machine and
    // "0" on a single-core one. Read when the first surface attaches, never
    // again — the count does not change on a running desktop, and CPU
    // hotplug is not a thing this build's target hardware does. If it cannot
    // be read there is no denominator, and law 4 says the paint stays normal
    // rather than inventing one.
    // ⚠ THE PATHS ARE GATED, NOT JUST THE TIMER. Caught by this file's own
    // harness on its first run: a `FileView` with a literal `path` PRELOADS
    // at construction, so both procfs reads happened the moment the singleton
    // came into existence — before a single surface was mapped — and the
    // harness duly found `warmth` at 0.38 with zero watchers. One read is not
    // a timer, but "nothing happens until something is on screen" is law 3
    // and it does not have an exception for the first one. Binding the path
    // to `wanted` makes attaching the thing that starts the reading and
    // detaching the thing that stops it, with no `reload()` call needed for
    // the first read.
    onWantedChanged: {
        // A fresh attach retries a reading that was declared dead, and
        // forgets that anything was ever asked for.
        mood._readDead = false;
        mood._asked = false;
        if (!mood.wanted) {
            // Nothing is mapped: forget the reading rather than hold a stale
            // one behind a dark screen. The next attach re-seeds from the
            // truth, and nothing is visible in between for the seed to jump.
            mood.haveLoad = false;
            mood.haveCores = false;
        }
    }

    FileView {
        id: coreFile
        path: mood.wanted ? "/sys/devices/system/cpu/present" : ""
        blockLoading: true
        // A missing file is a fact to record, not an error to shout about:
        // this shell has to run on whatever the person booted.
        printErrors: false
        onLoaded: {
            // "0-19" | "0" | "0-3,8-11". The last number present is the
            // highest CPU id, so +1 is the count. Parsed rather than
            // split-on-dash so a discontiguous set still gives a sane answer.
            const ids = coreFile.text().trim().match(/[0-9]+/g);
            if (!ids || ids.length === 0) { mood.haveCores = false; return; }
            const top = parseInt(ids[ids.length - 1], 10);
            if (!isFinite(top) || top < 0) { mood.haveCores = false; return; }
            mood.cores = top + 1;
            mood.haveCores = true;
        }
        onLoadFailed: mood.haveCores = false
    }

    // ── the load itself ──────────────────────────────────────────────────
    FileView {
        id: loadFile
        // Gated for the same reason `coreFile` is — see the note above it.
        path: mood.wanted ? "/proc/loadavg" : ""
        blockLoading: true
        printErrors: false
        onLoaded: {
            // "9.61 9.40 6.91 13/1128 174366" — field 1 is the 1-minute
            // average. Anything else in that file is somebody else's number.
            const one = parseFloat(loadFile.text().trim().split(/\s+/)[0]);
            if (!isFinite(one) || one < 0 || mood.cores <= 0) {
                // A procfs file that parses to nonsense is unreadable state,
                // and unreadable state is the normal appearance (law 4) — not
                // the last good value held forever, which would be the shell
                // asserting something it no longer knows. It also stops the
                // timer: a clock ticking for a number that will never arrive
                // is the law half-kept.
                mood.haveLoad = false;
                if (mood._asked) mood._readDead = true;
                return;
            }
            const norm = Math.max(0, Math.min(1, one / mood.cores));
            mood.load = norm;
            if (!mood.haveLoad) {
                // First reading: seed, do not ease. See the header.
                mood._ema = norm;
                mood.haveLoad = true;
            } else {
                mood._ema = mood._ema + (norm - mood._ema) * mood.emaAlpha;
            }
        }
        // ⚠ ONLY MARK DEAD IF WE ACTUALLY ASKED FOR A FILE. While `wanted` is
        // false this FileView's path is the empty string, and a FileView
        // pointed at "" reports a load FAILURE — so an unguarded assignment
        // here marks the singleton dead before any surface has ever mapped,
        // and the timer can then never start. That is exactly what happened:
        // the healthy `on` case dropped from 21/21 to 17/20 with timers=0 the
        // moment `_readDead` existed, and clearing the flag in
        // `onWantedChanged` did NOT fix it, because the ""-failure can arrive
        // after the transition. The condition, not the ordering, is the fix.
        onLoadFailed: {
            mood.haveLoad = false;
            if (mood._asked) mood._readDead = true;
        }
    }

    // Turning the behaviour off must put the paint back where it was, at
    // once and visibly — not merely stop updating it. Turning it back on
    // re-probes from scratch, which is also what makes the off→on round trip
    // provable: `haveLoad` false means the next reading seeds rather than
    // eases, so nothing survives the switch.
    onEnabledChanged: {
        if (!mood.enabled) {
            mood.haveLoad = false;
            mood.haveCores = false;
            mood._readDead = false;
            mood._asked = false;
            mood._ema = 0;
            mood.load = 0;
            mood.pulse = 0;
            scanSwell.stop();
            // Forget the baseline too, so switching back on re-seeds from
            // whatever is on disk rather than firing for a scan that landed
            // while the behaviour was off.
            mood._lastFinished = -1;
        }
    }

    // ══ THE RAMP ═════════════════════════════════════════════════════════
    // `Theme.paintRamp` is and stays the single source of what colour the
    // paint is; this leans it. At warmth 0 the returned array is the layer's
    // own stops UNCHANGED — not "very nearly unchanged", the same strings —
    // which is what makes "off", "unknown" and "idle" all look identical and
    // means a person can never tell a broken reader from a quiet machine by
    // the paint suddenly looking wrong.
    readonly property var ramp: (mood.active && mood.warmth > 0.001)
        ? mood.leanRamp(Theme.paintRamp, Theme.paintEmber, mood.warmth * mood.maxLean)
        : Theme.paintRamp

    // ── the blend, and the two rules it is shaped by ─────────────────────
    // Lean `from` toward `to`, stop for stop, by `t`.
    //
    // (1) TEMPERATURE CHANGES HUE, NEVER LIGHTNESS. Each warm target is
    //     re-lit to the SOURCE stop's own lightness before the mix, so the
    //     BRIGHT/dark/dark/dark/mid/bright/BRIGHT ladder comes out the other
    //     side by construction rather than by luck. swirl_splat.frag's law is
    //     that swirls come from alternating lightness and not more hues; a
    //     ramp whose ladder has been flattened integrates to its own mean,
    //     which is grey, and that is the exact failure the file documents at
    //     length. This is not decoration — see (2).
    //
    // (2) AND IT IS ALSO WHAT KEEPS THE OLIVE OUT. HANDOFF.md's rule is
    //     "blurred gold over purple turns olive"; the version of this
    //     function that mixed straight to the ember hex — no re-lighting —
    //     put glacier's bright stop `#b7e6f2` at hue 0.244, a pale green,
    //     and gate 13q37 caught it on its first run. The cause is arithmetic:
    //     mixing a LIGHT cyan with a MID amber leaves the green channel high
    //     while red climbs and blue falls, so the result lands on green.
    //     Matching the lightness first removes the imbalance and the mix
    //     travels through the desaturated centre instead of around it.
    //     Measured over all 28 stops after the fix: clean at 0.30 and 0.35,
    //     first olive stop at 0.40. The 0.30 ceiling is that margin, not a
    //     round number.
    //
    // HONEST ABOUT WHAT THIS LOOKS LIKE: on the palette's COLD rungs the
    // effect reads as the ice going out of them (rose's teal desaturates
    // toward a grey-teal) rather than as amber arriving, because a cool stop
    // cannot travel to amber without crossing the green this palette forbids.
    // On the mid and bright rungs — the ones that carry the paint's identity
    // — it reads as real heat: rose's `#d765a2` becomes `#dc758a`, its pale
    // `#ffb3d9` becomes `#ffbecd`. That asymmetry is the design, not a
    // shortfall: a machine under load loses its cool highlights and gains
    // its hot ones, which is what "warmer" means on a fluid.
    function leanRamp(from, to, t) {
        if (!from || !to || from.length !== to.length) return from;
        const k = Math.max(0, Math.min(1, t));
        var out = [];
        for (var i = 0; i < from.length; i++) {
            const a = Qt.color(from[i]);
            const b = Qt.color(to[i]);
            // The warm target: the ember anchor's hue and saturation, worn at
            // this stop's own lightness. Rule (1).
            const w = Qt.hsla(b.hslHue, b.hslSaturation, a.hslLightness, 1);
            out.push(Qt.rgba(a.r + (w.r - a.r) * k,
                             a.g + (w.g - a.g) * k,
                             a.b + (w.b - a.b) * k,
                             a.a));
        }
        return out;
    }

    // ══ THE SCAN PULSE ═══════════════════════════════════════════════════
    // One swell and out. `pulse` is read by Swirl's DISPLAY pass as a bloom
    // lift — no dye, no velocity, nothing injected, so WIP-648 has nothing
    // to catch here even if a hundred scans finished in a row.
    property real pulse: 0
    readonly property int pulseRiseMs: 2200
    readonly property int pulseFallMs: 4800

    // Motion preference governs movement (law 6). `ambient` is the shipped
    // default and the owner's own setting; `interactive` means the field
    // only answers the hand, and a scan is not the hand.
    readonly property bool _motionAmbient: Prefs.swirlMotion !== "interactive"

    SequentialAnimation {
        id: scanSwell
        // No `loops`, no `running: true`. It is started by one call and it
        // finishes. A permanent animation in a singleton would drive the
        // global animation timer forever whether or not anything is on
        // screen, which is the WIP-245 shape with a different name.
        NumberAnimation {
            target: mood; property: "pulse"; to: 1
            duration: mood.pulseRiseMs; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: mood; property: "pulse"; to: 0
            duration: mood.pulseFallMs; easing.type: Easing.InOutSine
        }
    }

    // Fired for anything that wants to know a scan landed. Emitted once per
    // finish, whether or not the paint chose to swell.
    signal scanFinished(string result)

    function _swell(result): void {
        mood.scanFinished(result);
        // Every reason not to move, stated as one gate rather than scattered:
        //   · the behaviour is off, or nothing is mapped  → law 3/5
        //   · the reading is not honest                   → law 4
        //   · the user asked for interactive motion       → law 6
        if (!mood.wanted || !mood.active || !mood._motionAmbient) return;
        scanSwell.restart();
    }

    // ── the watch (no timer) ─────────────────────────────────────────────
    readonly property string _cacheHome:
        Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")
    readonly property string hemeraStatePath: mood._cacheHome + "/nyxus/hemera-state.json"

    // -1 = nothing seeded yet, so the first read is a baseline and not news.
    property real _lastFinished: -1

    FileView {
        id: hemeraState
        // An empty path when the behaviour is off: no descriptor, no watch,
        // nothing to clean up. Turning it back on re-seeds a fresh baseline,
        // so flipping the switch cannot make an old scan pulse.
        path: mood.enabled ? mood.hemeraStatePath : ""
        watchChanges: mood.enabled
        blockLoading: false
        // A fresh install has never run a scan and has no such file. That is
        // the normal case, not an error.
        printErrors: false
        onFileChanged: hemeraState.reload()
        onLoaded: {
            var st = null;
            try { st = JSON.parse(hemeraState.text()); } catch (e) { st = null; }
            if (!st || typeof st.finished !== "number") return;
            if (mood._lastFinished < 0) { mood._lastFinished = st.finished; return; }
            if (st.finished <= mood._lastFinished) return;
            mood._lastFinished = st.finished;
            mood._swell(typeof st.result === "string" ? st.result : "");
        }
        onLoadFailed: { /* no scan has ever run here; law 4 — say nothing */ }
    }
}
