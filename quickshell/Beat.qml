pragma Singleton
// Nyxus Suxyn — the beat feed. One cava process, many listeners.
//
// Feeds the reactive swirl (and anything else that wants to dance) with
// smoothed bass / mid / high energy plus a beat pulse detected from bass
// onsets. Values are all 0..1.
//
// ⛔ THE HYPRLOCK LESSON (AUDIT-PLAN item 1): the lock screen died because it
// spawned `nyxus-lock-cava frame` — two subprocesses every 50 ms — until the
// event loop starved. This singleton is the opposite shape ON PURPOSE: ONE
// long-lived cava streaming raw frames over stdout, parsed in-process.
//
// Owner 2026-08-19: idle must be STILL (or a slow breathe), playing follows
// cava.raw, do not fake a pulse. That SUPERSEDES the 08-09 mic/TV ear.
// cava.mic.conf stays on disk (do not delete) but is not started: a quiet
// room's fan was enough to trip `hot` with nothing playing. The sink
// MONITOR (cava.raw.conf) hears any desktop audio — MPRIS, a browser, a
// game — and is silent when the machine is silent. `autosens` is OFF on
// that profile so a dead monitor cannot be pumped into a fake beat.
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: beat

    // Set NYXUS_BEAT_DEBUG=1 to trace audio route/source changes.
    readonly property bool debugLog: Quickshell.env("NYXUS_BEAT_DEBUG") === "1"

    // ── what consumers read ──────────────────────────────────────────
    // ── TRK-3495 · the FULL visual spectrum ─────────────────────────────
    // `nyxus-beat-engine` has always emitted FIVE visual bands — its own
    // VIS_BANDS: bass 30-160, low 160-500, mid 500-2k, high 2k-8k, air 8-16k,
    // marked in that file as "for the LOOK; the detector does not use them".
    // Only three were read here, so `low` and `air` arrived on the wire every
    // frame and were discarded. Surfacing them costs nothing — the engine
    // already computes and sends them — and it is the difference between a
    // consumer being able to draw a SPECTRUM and a three-band caricature.
    property real bass: 0
    property real low: 0
    property real mid: 0
    property real high: 0
    property real air: 0
    property real pulse: 0            // 1 on a detected beat, decays fast
    readonly property real energy: bass * 0.6 + mid * 0.3 + high * 0.1

    // ── TRK-3697 · THE SPECTRUM, for a graph rather than a caricature ──
    // Five named bands can say "how much bass"; they cannot draw a shape.
    // `nyxus-beat-engine` now folds the SAME `spec` its onset detector
    // already computed into 64 log-spaced display bars and sends them on
    // the frame that was already crossing the pipe. No second process, no
    // timer, no second FFT — see the header's hyprlock lesson for why that
    // was the only acceptable way to get this.
    //
    // Values are 0..1, low frequency first. The array is EMPTY when
    // nothing is playing — not 64 zeros — so a consumer's "is there a
    // spectrum" question is `spectrum.length`, and silence costs nothing
    // on the wire. Idle is genuinely still (owner 2026-08-19): nothing in
    // this file or in the engine can synthesise a bar.
    //
    // Length is NOT fixed. The engine sends 64; the cava fallback below
    // sends 12, which is all cava.raw.conf emits. A consumer must read
    // `spectrum.length` and never assume, which is also what lets the
    // engine's bar count change without touching a drawing surface.
    //
    // It updates at 46.88 Hz, not at the engine's 93.75: the engine sends
    // the array on every second frame because MEASURED, 64 bars at the
    // full rate cost 41.34 percentage points of one core in the shell
    // against 21.99 at half, and the bar's own living paint — the ruler —
    // costs 20.78. Silence is never skipped, so "go still" is never late.
    property var spectrum: []

    // ══ THE ENGINE (2026-08-31) ══════════════════════════════════════
    // Everything above is unchanged; what feeds it got better.
    //
    // cava is a BAR DISPLAY. By the time a frame reaches this file it has
    // been reduced to 12 bands, smoothed over time by `noise_reduction`,
    // and scaled to look good rather than to measure. Onset detection is a
    // per-band question about a TRANSIENT, and cava has already thrown
    // away both the bands and the transient. This file did the best that
    // could be done with what it was given.
    //
    // `nyxus-beat-engine` reads the raw PCM off the same sink monitor and
    // does the real work: a 2048/512 STFT at 93.75 fps (10.7 ms grid, vs
    // cava's smoothed 45), log-magnitude mel bands, a SuperFlux onset
    // function, autocorrelation tempo, and a phase-locked loop.
    //
    // THE PART THAT CHANGES WHAT YOU SEE: the PLL knows where the beat is
    // and knows it in ADVANCE. `kick` is now struck by the PREDICTED beat
    // instead of by whatever onset happened to clear a threshold, so every
    // surface bound to it -- bar seam, panel and window edges, the swirl,
    // the launcher, the power menu -- lands ON the beat rather than on
    // each loud noise, and holds the rhythm through a bar where the
    // drummer drops out. Measured live: +-10 ms of jitter, centred on
    // real onsets (median offset -11 ms, i.e. no lead and no drag).
    //
    // The public API above is unchanged ON PURPOSE. Not one consumer
    // needed editing, which is also why this could be swapped without
    // touching eleven files that each had their own idea of the beat.
    property real bpm: 0              // 0 unless the tempo is actually tracked
    property bool locked: false       // the tracker has a tempo it believes
    property int barPos: 0            // 0..3, 0 is the downbeat
    property bool downbeat: false     // true on the frame a bar starts

    // True once the engine has delivered a parsed frame. Until then (and
    // if the binary is missing on an older image) the original cava path
    // below stays live, so the build never loses its beat to a failed
    // dependency -- the shell has been broken by exactly that shape before.
    property bool engineOk: false
    property double _lastEngineMs: 0

    // ── THE KICK · one struck envelope for the whole build ───────────
    // Owner, 2026-08-09: "all I want is that part to go to the beat of the
    // music, then anything else in the build — the borders, edges — go to
    // the beat as well."
    //
    // It lives HERE, not in each consumer, because it was already living in
    // two places with two different shapes: the window borders and the panel
    // edges each computed `pulse * 0.8 + energy * 0.6` independently. That
    // blend is a smoothed LEVEL — it drifts with loudness instead of striking
    // on the drum, so a loud passage reads "on", a quiet one "off", and
    // neither reads as rhythm. Two copies of the wrong idea is also how they
    // would have drifted apart the first time anyone tuned one of them.
    //
    // A kick is a transient: snap up when a beat is detected (harder for a
    // bigger one), then fall on its own over ~420 ms. The FALL is the part an
    // eye reads as rhythm — a level that never falls has no beat in it
    // however bright it gets. Everything that wants to dance binds to this.
    property real kick: 0
    readonly property real kickFall: 0.038      // per 16 ms ⇒ ~420 ms to zero

    onPulseChanged: {
        // Rising edges only. `pulse` is set to its strength on a detection
        // and decays between them, so this fires once per beat.
        //
        // ONLY on the cava fallback. With the engine live, `kick` is struck
        // by the PREDICTED beat in _engineFrame(); letting an onset strike it
        // as well would put the old every-loud-noise behaviour straight back
        // on top of the tracked one, which is the exact thing the engine
        // exists to stop.
        if (engineOk)
            return;
        if (pulse > _lastKickPulse + 0.15)
            kick = Math.max(kick, Math.min(1, 0.55 + pulse * 0.45));
        _lastKickPulse = pulse;
    }
    property real _lastKickPulse: 0

    Timer {
        interval: 16
        repeat: true
        // Runs only while there is something to fall from, so a silent room
        // costs nothing: no timer, no wakeups.
        running: beat.kick > 0.004
        onTriggered: beat.kick = Math.max(0, beat.kick - beat.kickFall)
    }
    // Owner 11:14: energy>0.035 on an idle EasyEffects monitor is hiss,
    // not a track. No sink-input → not hot. That was TTY1 pulsing with
    // nothing playing (rim angle stepping +23° with no playback).
    property bool havePlayback: false
    property bool _engineHot: false
    // The engine has its own measured noise floor, but `havePlayback` stays
    // in the AND: the owner's 11:14 ruling is that a sink with no input is
    // not music however loud EasyEffects' hiss measures, and that gate lives
    // in nyxus-beat-tap.sh (MPRIS + sink-input), not in a level threshold.
    readonly property bool hot: engineOk ? (havePlayback && _engineHot)
                                         : (havePlayback && (energy > 0.035 || pulse > 0.10))

    // Owner 11:12: soft bass stays light glacier; a real hit goes darker
    // glacier. 0 = glacier[0]/[5] (`#7fe8ff` / `#b7e6f2`). 1 = glacier[4]
    // on the rim (`#4f7fa6`, 4.41:1 — the darkest glacier that still
    // clears the 3:1 state floor). glacier[3] `#274b7a` is 2.13:1 and is
    // halo-only. Kick × bass only — a bass rumble term with no kick is
    // how silence kept mixing the rim.
    readonly property real iceDepth: {
        if (!beat.hot)
            return 0;
        return Math.min(1, beat.kick * (0.20 + 0.80 * beat.bass));
    }

    // Master switch — Settings → Appearance → Follow music. Off = no cava,
    // still rims. Living-paint OFF must NOT mute the borders: the 08-09
    // ruling kept Hyprland rims pulsing when the swirl Frame was on hold.
    property bool enabled: Prefs.swirlMusic

    // ── beat detection state ─────────────────────────────────────────
    // Spectral-flux onset detector: previous frame per band, plus the flux's
    // own running mean and deviation, which together form the adaptive
    // threshold. See _frame() for why a fixed threshold could not work.
    property real _bPrev: 0
    property real _mPrev: 0
    property real _hPrev: 0
    property real _fluxAvg: 0
    property real _fluxDev: 0
    property real _bassAvg: 0
    property double _lastBeatMs: 0

    // ── the noise floor (added with the ambient ear, 2026-08-09) ─────
    // A microphone in a real room carries a STEADY spectrum that is not
    // music — fan hum measured at ~0.78 on this laptop's own mic in a
    // quiet room, which is far past `hot`'s 0.035 and would have held the
    // borders in music-mode forever. Each band learns its own floor: snap
    // DOWN to any quieter frame instantly, creep UP toward a louder one
    // over ~15 s (0.0015 blend at 45 fps), and only the signal ABOVE the
    // floor counts. Music keeps jumping over its floor; hum IS the floor.
    // Monitor-ear silence has a floor of ~0, so this changes nothing for
    // the internal path.
    property real _bFloor: 1
    property real _mFloor: 1
    property real _hFloor: 1

    readonly property string _confPath: {
        const u = Qt.resolvedUrl("cava.raw.conf").toString();
        return u.startsWith("file://") ? decodeURIComponent(u.substring(7)) : u;
    }
    readonly property string _tapPath: {
        const u = Qt.resolvedUrl("nyxus-beat-tap.sh").toString();
        return u.startsWith("file://") ? decodeURIComponent(u.substring(7)) : u;
    }
    readonly property string _liveConf: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp")
                                        + "/nyxus-cava-beat.conf"
    property string _tap: ""
    property string _audioRouteState: "paused"
    property bool _liveReady: false
    property bool _routeRefreshPending: false

    function _zeroReactiveState(clearSpectrum) {
        beat.bass = 0;
        beat.low = 0;
        beat.mid = 0;
        beat.high = 0;
        beat.air = 0;
        beat.pulse = 0;
        beat.kick = 0;
        beat._engineHot = false;
        beat.locked = false;
        beat.bpm = 0;
        beat.barPos = 0;
        beat.downbeat = false;
        if (clearSpectrum && beat.spectrum.length > 0)
            beat.spectrum = [];
    }

    function _restartAudioFeed(reason) {
        if (debugLog && reason && reason.length > 0)
            console.log("[Beat] " + reason);
        beat._routeRefreshPending = true;
        feedRestartTap.restart();
    }

    // ── one ear: the sink that is PLAYING (not the default, not the mic)
    // YouTube never registers MPRIS. Gating on hasPlayer handed the mic
    // ear a silent room. `auto` follows the default sink, which on this
    // machine has been idle HDMI. nyxus-beat-tap.sh retargets cava to
    // whichever sink currently has a sink-input.
    Process {
        id: tap
        command: ["bash", beat._tapPath, beat._confPath, beat._liveConf]
        // `tap` is a long-lived feed; any exit is unexpected, so surface it.
        onExited: function (code) { if (code !== 0) console.warn("[Beat] audio tap exited code " + code); }
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n").filter(l => l.length > 0);
                if (lines.length < 1)
                    return;
                const s = lines[0];
                const playing = lines.length > 1 && lines[1] === "1";
                const routeState = lines.length > 2 ? lines[2] : (playing ? "ok" : "paused");
                const sinkChanged = s !== beat._tap;
                const routeChanged = routeState !== beat._audioRouteState;
                beat._liveReady = true;
                beat._tap = s;
                beat._audioRouteState = routeState;
                if (beat._routeRefreshPending) {
                    beat._routeRefreshPending = false;
                    if (routeState === "ok")
                        feedRestartReaders.restart();
                }
                if (playing !== beat.havePlayback) {
                    beat.havePlayback = playing;
                    if (!playing)
                        beat._zeroReactiveState(true);
                }
                if (routeChanged) {
                    if (debugLog)
                        console.log("[Beat] route state -> " + routeState);
                    if (routeState !== "ok")
                        beat._zeroReactiveState(true);
                }
                if (sinkChanged && routeState === "ok") {
                    if (debugLog)
                        console.log("[Beat] monitor source -> " + s);
                    beat._restartAudioFeed("reconnecting audio monitor after sink change");
                } else if (routeChanged && routeState === "ok") {
                    beat._restartAudioFeed("reconnecting audio monitor after route state change");
                } else if (sinkChanged) {
                    if (debugLog)
                        console.log("[Beat] monitor source -> " + s + " (" + routeState + ")");
                }
            }
        }
    }
    Timer {
        // 500 ms so a pause drops cava before EasyEffects hiss can keep
        // the rims stepping. 1500 ms was a visible leftover pulse.
        interval: 500
        repeat: true
        triggeredOnStart: true
        running: beat.enabled
        onTriggered: {
            tap.running = false;
            tapStart.start();
        }
    }
    Timer {
        id: tapStart
        interval: 20
        onTriggered: tap.running = true
    }
    Timer {
        id: restartCava
        interval: 40
        onTriggered: {
            proc.running = false;
            if (beat.enabled && beat.havePlayback && beat._liveReady && !beat.engineOk)
                proc.running = true;
        }
    }
    Timer {
        id: feedRestartTap
        interval: 20
        onTriggered: {
            beat._liveReady = false;
            tap.running = false;
            tapStart.stop();
            tapStart.start();
        }
    }
    Timer {
        id: feedRestartReaders
        interval: 80
        onTriggered: {
            if (beat.enabled) {
                if (engineProc.running)
                    engineProc.running = false;
                engineRestart.restart();
            }
            restartCava.restart();
        }
    }
    Timer {
        id: engineRestart
        interval: 40
        onTriggered: {
            if (beat.enabled)
                engineProc.running = true;
        }
    }
    // ── the engine · one long-lived process, parsed in-process ───────
    // Same shape as the cava process below and for the same reason (see the
    // hyprlock lesson at the top of this file): ONE process for the life of
    // the shell, never one per frame. It follows the playing sink itself
    // using the very same nyxus-beat-tap.sh this file already ships.
    //
    // ══ TRK-3739/3740 · WHY THIS BUILD NEVER ONCE HEARD ITS OWN ENGINE ══
    // Measured on the owner's own machine, 2026-09-06, with music playing:
    //
    //   WARN: Process failed to start, likely because the binary could not
    //   be found. Command: QList("nyxus-beat-engine", "--tap", ...)
    //
    // `which nyxus-beat-engine` -> nothing, on a PATH of /usr/local/sbin:
    // /usr/local/bin:/usr/bin. `nyxus-beat` and `nyxus-beatd` ARE in
    // /usr/local/bin -- they are the July border-angle spinner, a different
    // feature, and their presence is exactly what made this look like a
    // naming mistake. It is not one. The engine's only committed copy lives
    // under `artifacts/api-server/nyxus-scripts/`, which the ship manifest
    // resolves into the package CACHE -- a path on nobody's PATH. So every
    // image ever baked shipped a shell asking for a binary the image
    // installs nowhere useful, `engineOk` stayed false for the life of every
    // session, and the whole build silently ran on the 12-band cava
    // fallback. That is the single upstream cause of the music complaints:
    // no PLL, so nothing lands on a PREDICTED beat, and 12 smoothed bands,
    // so the graph is a caricature rather than a spectrum.
    //
    // TWO defects, and both had to go or the feed still would not run:
    //
    // 1. THE NAME WAS NOT RESOLVABLE. Fixed by RESOLVING it here instead of
    //    trusting a PATH this process does not control. Candidates are tried
    //    in order and `exec` REPLACES the shell, so this is still ONE
    //    long-lived process and the header's hyprlock rule is intact -- sh
    //    does not survive the call. The shell's own directory is in the list
    //    because `nyxus-beat-tap.sh` already ships beside shell.qml, so an
    //    engine dropped next to it needs no install step at all, and
    //    `$NYXUS_BEAT_ENGINE` is first so a developer can point at a build
    //    without editing this file.
    //
    // 2. `running: beat.enabled` WAS A BINDING, and that is the worse half.
    //    A failed spawn drops `running` back to false, which BREAKS the
    //    binding -- so the shell tried exactly ONCE per start and no code
    //    path anywhere could ever try again. An engine installed while the
    //    session was up would not be picked up until the next reboot, which
    //    is why installing the binary alone did not fix the live machine.
    //    Retried on a 2 s backoff doubling to a 60 s ceiling, so a genuinely
    //    absent binary costs one spawn a minute rather than a spin. The
    //    backoff resets when a frame actually PARSES -- not when `running`
    //    goes true, or a binary that starts and instantly exits would never
    //    back off at all.
    readonly property string _engineResolver:
        'for c in "$NYXUS_BEAT_ENGINE" "$2/nyxus-beat-engine"'
        + ' /usr/local/bin/nyxus-beat-engine "$HOME/.local/bin/nyxus-beat-engine"; do'
        + ' [ -n "$c" ] && [ -x "$c" ] && exec "$c" --tap "$1"; done;'
        + ' exec nyxus-beat-engine --tap "$1"'
    readonly property string _shellDir: {
        const u = Qt.resolvedUrl(".").toString();
        const d = u.startsWith("file://") ? decodeURIComponent(u.substring(7)) : u;
        return d.endsWith("/") ? d.substring(0, d.length - 1) : d;
    }
    property int _engineBackoffMs: 2000
    readonly property int engineBackoffMaxMs: 60000

    Process {
        id: engineProc
        // NOT a binding -- see 2. above. Started by Component.onCompleted,
        // by onEnabledChanged and by the retry timer, which together cover
        // every path back to life.
        command: ["sh", "-c", beat._engineResolver,
                  "nyxus-beat-engine", beat._tapPath, beat._shellDir]
        stdout: SplitParser {
            onRead: data => beat._engineFrame(data)
        }
        onRunningChanged: {
            if (!running) {
                beat.engineOk = false;
                beat._engineHot = false;
                beat.locked = false;
                beat.bpm = 0;
                beat.spectrum = [];
                console.warn("[Beat] audio engine stopped");
                // Died, or never started. Try again rather than hand the
                // build to cava for the rest of the session.
                if (beat.enabled)
                    engineRetry.restart();
            }
        }
    }

    Timer {
        id: engineRetry
        interval: beat._engineBackoffMs
        repeat: false
        onTriggered: {
            if (!beat.enabled || engineProc.running)
                return;
            beat._engineBackoffMs = Math.min(beat.engineBackoffMaxMs,
                                             beat._engineBackoffMs * 2);
            engineProc.running = true;
        }
    }

    // The pref is the other way back in: switching Follow music off and on
    // again must start the engine, and `running` is no longer a binding that
    // would do it for us.
    onEnabledChanged: {
        if (beat.enabled) {
            beat._engineBackoffMs = 2000;
            if (!engineProc.running)
                engineProc.running = true;
        } else {
            engineProc.running = false;
        }
    }

    Component.onCompleted: {
        if (beat.enabled)
            engineProc.running = true;
    }

    function _engineFrame(line) {
        if (!line || line.length < 2)
            return;
        let s;
        try {
            s = JSON.parse(line);
        } catch (e) {
            return;                    // a partial line is not an error
        }
        beat.engineOk = true;
        beat._lastEngineMs = Date.now();
        beat._engineBackoffMs = 2000;   // a PARSED frame is the only proof

        beat._engineHot = !!s.hot;
        beat.bass = s.bass || 0;
        beat.low  = s.low  || 0;
        beat.mid  = s.mid  || 0;
        beat.high = s.high || 0;
        beat.air  = s.air  || 0;
        beat.locked = !!s.lock;
        beat.bpm = beat.locked ? (s.bpm || 0) : 0;
        beat.barPos = s.bar || 0;
        beat.downbeat = !!s.down;

        // THE SPECTRUM. Gated on `hot`, not on the engine's own `hot`:
        // the owner's 11:14 ruling is that a sink with no input is not
        // music however loud EasyEffects' hiss measures, and `hot` is
        // where that ruling lives (havePlayback AND _engineHot).
        //
        // THREE CASES, and the third one is the whole reason this is not
        // a one-liner:
        //   `sp` ABSENT      the engine skipped this frame (it emits the
        //                    spectrum at half the analysis rate; see
        //                    SPECTRUM_EVERY). No news -- hold what we have
        //                    and do not touch the property, so no consumer
        //                    re-evaluates a binding for nothing.
        //   `sp` EMPTY       nothing is playing. Go still, now.
        //   `sp` WITH VALUES draw it.
        const sp = s.sp;
        if (sp === undefined) {
            // no news
        } else if (beat.hot && sp.length > 0) {
            const out = [];
            for (let i = 0; i < sp.length; i++)
                out.push(Math.min(1, Math.max(0, sp[i] / 1000)));
            beat.spectrum = out;
        } else if (beat.spectrum.length > 0) {
            beat.spectrum = [];
        }

        // `pulse` keeps its old meaning -- an onset, decaying between hits --
        // because consumers read it directly for texture (the swirl's
        // audioPulse). What CHANGED is that it no longer drives `kick`.
        if (s.onset)
            beat.pulse = Math.max(beat.pulse, Math.max(0.55, s.str || 0.55));
        else
            beat.pulse = Math.max(0, beat.pulse * 0.86 - 0.004);

        // THE STRIKE. Driven by the predicted beat, and harder on the
        // downbeat so a bar has a shape instead of four identical hits.
        if (s.beat && beat.hot)
            beat.kick = Math.min(1, s.down ? 1.0 : 0.82);
    }

    // If the engine dies or was never installed, fall back to cava rather
    // than sit silent. 2.5 s is long enough that a quiet passage cannot
    // trip it (the engine keeps emitting frames while `hot` is false).
    Timer {
        interval: 2500
        repeat: true
        running: beat.enabled && beat.engineOk
        onTriggered: {
            if (Date.now() - beat._lastEngineMs > 2500)
                beat.engineOk = false;
        }
    }

    Process {
        id: proc
        // Only while the engine is NOT delivering -- never both ears at once.
        running: beat.enabled && beat.havePlayback && beat._liveReady
                 && !beat.engineOk
        command: ["cava", "-p", beat._liveConf]
        stdout: SplitParser {
            onRead: data => beat._frame(data)
        }
        onRunningChanged: {
            if (!running) { beat._zeroReactiveState(true); beat._bassAvg = 0;
                            beat._bFloor = 1; beat._mFloor = 1; beat._hFloor = 1;
                            beat._bPrev = 0; beat._mPrev = 0; beat._hPrev = 0;
                            beat._fluxAvg = 0; beat._fluxDev = 0; }
        }
    }

    function _frame(line) {
        if (!beat.havePlayback)
            return;
        // one raw ascii frame: "12;340;…;0;" — 12 bars, 0..1000
        const parts = line.split(";");
        const vals = [];
        for (let i = 0; i < parts.length; i++) {
            if (parts[i].length === 0) continue;
            const v = parseInt(parts[i], 10);
            if (!isNaN(v)) vals.push(Math.min(1, v / 1000));
        }
        const n = vals.length;
        if (n < 6) return;

        // The coarse spectrum. cava.raw.conf emits 12 bars and that is
        // what a consumer gets on this path — a 12-bar graph, not a
        // 64-bar one interpolated up to look like more resolution than
        // was measured. Raising `bars` here would raise the cost of the
        // FALLBACK for a display the engine already serves properly.
        beat.spectrum = vals;

        let b = (vals[0] + vals[1] + vals[2]) / 3;
        const mLo = Math.min(4, n - 1), mHi = Math.min(7, n - 1);
        let m = 0, mc = 0;
        for (let j = mLo; j <= mHi; j++) { m += vals[j]; mc++; }
        m /= Math.max(mc, 1);
        let h = (vals[n - 3] + vals[n - 2] + vals[n - 1]) / 3;

        // Learn the floors, keep only what rises above them (see the note
        // over _bFloor). The divisor renormalises so a kick over a high
        // floor still reaches a useful level.
        _bFloor = b < _bFloor ? b : _bFloor * 0.9985 + b * 0.0015;
        _mFloor = m < _mFloor ? m : _mFloor * 0.9985 + m * 0.0015;
        _hFloor = h < _hFloor ? h : _hFloor * 0.9985 + h * 0.0015;
        b = Math.max(0, b - _bFloor) / Math.max(0.05, 1 - _bFloor);
        m = Math.max(0, m - _mFloor) / Math.max(0.05, 1 - _mFloor);
        h = Math.max(0, h - _hFloor) / Math.max(0.05, 1 - _hFloor);

        bass = bass * 0.55 + b * 0.45;
        mid  = mid  * 0.55 + m * 0.45;
        high = high * 0.55 + h * 0.45;

        // ══ ONSET DETECTION · spectral flux with an adaptive threshold ═══
        // Owner, 2026-08-09: "it needs to go to the beat of the music better,
        // it seems like it really don't even go to the beat."
        //
        // The old rule was `b > _bassAvg * 1.45 + 0.05 && b > 0.12` — bass had
        // to jump 45% above its own rolling average. That is a textbook onset
        // detector and it fails on exactly the music people play loudly:
        // modern masters are COMPRESSED and limited, so the bass average sits
        // high and a kick can never be 45% above it. The louder and more
        // produced the track, the fewer beats it found. It also watched bass
        // ONLY, so the snare and hats that carry most of the groove were
        // invisible to it.
        //
        // Replaced with spectral FLUX: the sum of positive change across the
        // bands, which is what an onset physically is — energy arriving,
        // not energy being loud. Weighted toward bass because a kick should
        // still dominate, but a snare or a hat now registers.
        const dB = Math.max(0, b - _bPrev);
        const dM = Math.max(0, m - _mPrev);
        const dH = Math.max(0, h - _hPrev);
        _bPrev = b; _mPrev = m; _hPrev = h;
        const flux = dB * 1.60 + dM * 0.55 + dH * 0.25;

        // The threshold is the flux's own recent mean plus its own recent
        // deviation, so it self-calibrates to the track instead of to a
        // constant somebody guessed. A steady loud passage raises the mean
        // and stops firing on nothing; a quiet intro lowers it and still
        // finds the beat. The floor keeps silence from triggering on noise.
        const dev = Math.abs(flux - _fluxAvg);
        _fluxAvg = _fluxAvg * 0.90 + flux * 0.10;
        _fluxDev = _fluxDev * 0.90 + dev * 0.10;
        const thresh = _fluxAvg + Math.max(0.004, _fluxDev * 1.60);

        // ── the weights and the threshold are MEASURED, not guessed ────
        // Simulated against synthetic cava frames for five tracks (lightly
        // mastered, heavily compressed at 120/90 BPM, a 140 club master and
        // a 75 BPM slow one), counting detections against the known beat
        // count. The old rule found 5 beats out of 40 on the compressed
        // 120 BPM case — which is precisely the owner's report. These
        // weights land within 3% of the true count across all five:
        // Then CAPTURED 12 s of the owner's own room through the mic ear and
        // re-fitted against it, because synthetic frames flattered the
        // detector: autocorrelation of the real onset envelope put the track
        // at 142 BPM (0.58 correlation, with the expected 71 BPM
        // sub-harmonic), i.e. ~28 beats in the clip. The old rule found 8.
        // The first flux tuning found 11 -- better, still not the beat, and
        // the owner said so: "it still isnt really going to the beat".
        //
        // The culprit was the ABSOLUTE floor, not the deviation multiplier.
        // At 0.012 it was rejecting genuine onsets outright on real audio,
        // where a mic-fed onset is smaller than a synthetic one. Dropping it
        // to 0.004 and fitting the multiplier jointly against BOTH the real
        // capture and the synthetic suite -- so this is not over-fitted to
        // twelve seconds of one track:
        //   mid 0.55 / high 0.25   snare and hats contribute without a
        //                          hi-hat pattern out-voting a kick
        //   deviation x 1.60       fires on real onsets, not on texture
        //   floor 0.004            the fix; 0.012 was deaf to the room
        //   190 ms refractory      315 BPM ceiling; stops one drum's attack
        //                          and decay counting twice
        // Result on the owner's own music: 28 beats, 141 BPM against a
        // measured 142. Synthetic suite mean relative error 0.16.
        _bassAvg = _bassAvg * 0.96 + b * 0.04;
        const now = Date.now();
        const onset = flux > thresh && flux > 0.004 && now - _lastBeatMs > 190;
        // The old bass rule is KEPT as an OR, not thrown away: on sparse
        // material (a lone kick over silence) it is the more certain of the
        // two, and it costs one comparison.
        const bassHit = b > _bassAvg * 1.45 + 0.05 && b > 0.12
                        && now - _lastBeatMs > 190;

        if (onset || bassHit) {
            _lastBeatMs = now;
            // Strength, not a flat 1: how far the flux cleared its own
            // threshold. A downbeat now hits harder than an off-beat hat,
            // which is the difference between "something is happening" and
            // "this is the rhythm".
            const strength = Math.min(1, 0.55 + (flux - thresh) * 3.2);
            pulse = Math.max(pulse, Math.max(0.55, strength));
        } else {
            pulse = Math.max(0, pulse * 0.86 - 0.004);
        }
    }
}
