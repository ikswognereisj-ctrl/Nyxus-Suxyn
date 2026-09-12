pragma ComponentBehavior: Bound
// Nyxus Suxyn — THE ANALYSER. The back face of the bar.
//                                        TRK-3697 / TRK-3713 / TRK-3718
//
// ══ THE RECORD · THREE ROUNDS, THREE REJECTIONS, ALL KEPT ═══════════════
// Round 1 (64 columns, 30 px pitch, glass rungs): "thats not correct the
// bars are to big way to big i wanted thin like the ones i seen". Round 2
// (384 flat delegates): "music grapgh need to move more and flow waves ups
// and downs there to stiff" — answered three times inside one session (the
// smoothstep→gamma→smoothstep reversal is recorded in the ledger and in
// docs/proof/barspectrum-0901/); the colour went rainbow on his
// instruction and came back off it on his instruction ("the one that
// worked can you make it that pal color and do the tips magna" — the
// rainbow is GONE, not hidden behind a setting; a token naming a
// superseded ruling is how a gate turns into a lock, AGENTS.md `13vd`).
// And after all of it, 2026-09-02: "it was working out at all looked like
// shit and it took way to long for what i got ... i want alot of motion
// so i want that thing going crazy to the beat".
//
// ══ ROUND 3 · WHAT CHANGED AND WHY IT IS A SHADER NOW ═══════════════════
// The delegate build's own measured cost fit — 5.8 + 0.254 × bars pp of a
// core at 46.88 fps — prices the 384-column field the engine now sends at
// roughly a FULL CORE of QML binding work. That is unshippable next to a
// living paint that costs ~20 pp, and it is also why round 2 could not
// afford any motion beyond the data itself. So the field is drawn by ONE
// ShaderEffect (shaders/spectrum_view.frag): columns are cut per-fragment
// out of one quad, the spectrum crosses as a 384×1 texture whose linear
// filter does band→column interpolation for nothing, and the CPU's whole
// per-frame job is one ImageData upload. The motion — per-column wobble,
// the PLL kick surge, the downbeat ripple, the tip halo — costs fragment
// ALU, which the delegate build's own fill-rate test showed is not the
// binding constraint on this surface (a 2× fill change moved it under one
// point).
//
// The shape is MIRRORED off a centre spine — the references' strongest
// common shape ("the whole bar shooting up and down"), twice the apparent
// motion for the same data. Rest is FLAT ("graph have to start flat"): no
// floor, no stubs — a quiet column collapses into the 1 px spine, and
// silence upstream is an EMPTY array, so stillness is still the absence of
// a code path, not one.
//
// ══ ROUND 4 · AN OPAQUE FACE, A SEGMENTED FIELD, A SPECTRUM ═ TRK-3778 ══
// Owner, 2026-09-06, with five new references: "this is how i want the
// visulizer to be with out the swirls behond it its suppose to flip over to
// this when music plays then backnormal when no music playing" — and, on
// how to read the images, "i was sending those ... just to give you a visual
// of what i was thinking ... just to go off". They are DIRECTION.
//
// Four things, each argued at its own site below:
//   · THE GROUND — an opaque `void_` face, so no living paint reads through
//     it. This is the ruling, and the block below records the misreading it
//     corrects (a previous round moved this plate DOWN a z level to make
//     MORE swirl visible, on the same sentence read backwards).
//   · THE CELL — the envelope is cut into LED segments. It is the one
//     reference form that spends no height on furniture, which is the
//     binding constraint at `chromeH` 84.
//   · THE RAMP — body hue by frequency, `Theme.spectrumRamp`. Two arcs of
//     his own palette, one hard step, zero periwinkle columns (measured).
//   · THE PEAK HOLD — the one piece of STATE a fragment shader cannot own,
//     carried in a second row of the texture the CPU already writes, and
//     the surviving role of the magma tip ruling.
//
// ══ ROUND 5 · TWO REJECTIONS ON ONE SCREENSHOT ═══ TRK-3809 / TRK-3810 ══
// He saw round 4 running and answered it in one sentence, 2026-09-06:
//
//   "also the music visulizer there like lines riuning through the
//    bootom/middle of it and the record get rid of"
//
// REJECTION 4 · THE RIBBONS (TRK-3741, removed TRK-3809). The "lines
// running through the bottom/middle" were the five flowing neon curves
// composited under the field. What is worth keeping is not the code but
// WHY THE MEASUREMENT SAID THEY WERE NOT THERE: TRK-3778's proof measured
// this face by COLUMN MINIMUM, with the field SILENT, and reported a
// p10–p90 spread of 0.00 — from which it concluded "a wash cannot be flat".
// Every ribbon term is × live, so the silent measurement could not see
// them; and a column-minimum metric is BLIND TO HORIZONTAL STRUCTURE BY
// CONSTRUCTION, so even a loud one could not. The full argument, and what
// the streaks actually turned out to be, is in the shader's own header —
// short version: a soft falloff with NO CUTOFF is a full-surface element,
// and five of them summed to a continuous wash over two thirds of the
// bar's height. scripts/measure-bar-rows.py is the metric that can see it.
//
// REJECTION 4b · THE RECORD (TRK-3741, deleted TRK-3810). Built as a
// tempo-locked turntable at the left, approved from a still the morning it
// shipped, rejected the same evening once he watched it move, briefly
// reprieved as a right-hand DJ scratcher, then deleted outright — "and get
// rid of the record sorry". Nothing of the scratcher ever reached his
// machine. The full arc and the rule it produced (on this surface nothing
// is approved until he has seen it MOVING on his own screen — a still is
// not evidence here) are at § THE RECORD below, where the code used to be.
//
// ══ WHAT THIS FILE STILL IS NOT ═════════════════════════════════════════
//  · NOT a Swirl and it does not touch one — `Swirl`/`SwirlChip` stay
//    frozen. Its one shader is its own, in its own file.
//  · It spawns NO process and holds NO per-column animators. The one
//    FrameAnimation runs only while the graph is up (or fading) and stops
//    dead on silence; the note glyphs are a fixed pool, not a particle
//    system, and the scratcher's platter is integrated on that same tick
//    rather than by an animator of its own. Its only inputs are `Beat.spectrum` and the beat singleton's
//    own struck values (`kick`, `pulse`, `downbeat`), which arrive on
//    frames the ONE long-lived nyxus-beat-engine was already sending.
//  · THE NOTES are the one thing here that is drawn rather than measured —
//    the owner asked for them by reference ("the omnes with the music
//    notes inside of them"). They are honest about WHEN (spawned only by
//    the PLL's struck kick, magma on the downbeat) and WHERE (launched
//    from a band chosen in proportion to its own level), and they are
//    capped at 26 on screen, two per 110 ms strike — one sixteenth note
//    at his library's measured tempo — so they read as punctuation, not
//    weather. TRK-3811 raised that from 6 and 260 ms on his instruction.
import Quickshell
import QtQuick
import "LyricPhrase.js" as LyricPhrase

Item {
    id: root

    // The engine's spectrum, straight through. Empty when nothing plays.
    property var levels: Beat.spectrum
    property bool live: Beat.hot && root.levels.length > 0

    // Kept for the Bar.qml call site; the mirrored envelope fills the item
    // and this now only steers the spine's resting position.
    property int peakH: Math.round(root.height * 0.76)
    readonly property var _win: Window.window
    readonly property real _screenW: _win && _win.screen ? _win.screen.width : Screen.width
    readonly property real _screenH: _win && _win.screen ? _win.screen.height : Screen.height
    readonly property real _screenScaleX: root._screenW > 0 ? root._screenW / 1920 : 1
    readonly property real _screenScaleY: root._screenH > 0 ? root._screenH / 1200 : 1
    readonly property real _screenScale: Math.max(0.80, Math.min(1.35,
        Math.min(root._screenScaleX, root._screenScaleY)))
    readonly property int _edgePad: Math.max(10, Math.round(12 * root._screenScale))
    readonly property int _wordGap: Math.max(8, Math.round(10 * root._screenScale))
    readonly property real centreFrac: Math.max(0.63, Math.min(0.68,
        0.655 + (1.0 - root._screenScaleY) * 0.025))
    readonly property real _columnPitch: Math.max(4, 5 * root._screenScaleX)

    // Fade the whole instrument in/out with the flip rather than popping.
    property real liveT: root.live ? 1 : 0
    Behavior on liveT {
        NumberAnimation {
            duration: Theme.durBase
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveMove
        }
    }

    // The spine sits below centre: the envelope's upper half gets the extra
    // pixels so a full-transient spike reaches for the horizon, and the
    // lower half lands at the seam earlier — the reflection is the shorter
    // of the two, as reflections are.
    //
    // ⚠ 0.54 -> 0.655, AND HE PICKED IT FROM PICTURES ─────── TRK-3828 ──
    // Owner, 2026-09-07: "slightly move the whole mirrior feature down a
    // about a quarter more ways and let me see what that looks like i think
    // that will look better". "A quarter more" is not a number and he said
    // so himself — the useful reading is a quarter of the room that is left
    // below the axis, 0.54 + 0.25 * (1 - 0.54) = 0.655, and four positions
    // were built and photographed on his own bar rather than argued about:
    // `docs/proof/bar-mirror-0907/06-axis-four-positions.png`.
    //
    // ⚠ THIS IS NOT ONLY THE REFLECTION'S AXIS, which is why it was
    // captured rather than reasoned. It is the shader's mirror line
    // (`cfg.y`), the ground gradient's middle stop, AND the y the notes and
    // the lyric phrases launch from. Moving it down moves the words down
    // with it — checked at all four positions, and 0.70 is where a phrase's
    // own reflection starts running off the bottom edge of an 84 px bar.
    // 0.655 has room; it is also the last position where the returned half
    // of the field still reads as a field rather than as a strip.
    // ── the clock · one FrameAnimation, alive only while the graph is ───
    property real time: 0
    property real _downAt: -100
    FrameAnimation {
        running: root.liveT > 0.004
        onTriggered: root.time += frameTime
    }
    Connections {
        target: Beat
        function onDownbeatChanged() {
            if (Beat.downbeat)
                root._downAt = root.time;
        }
    }

    // ── the spectrum texture · the CPU's whole per-frame job ────────────
    // levels → one row of grey pixels. The shader's linear filter turns
    // 384 texels (or the cava fallback's 12 — TRK-3716 closes here) into
    // however many columns the width affords, with no second constant.
    // ⚠ THREE TRAPS LIVE IN THIS ONE CANVAS, ALL MEASURED IN THE NESTED
    // HARNESS (dbg probes, 2026-09-02), so the next lane does not re-run
    // the hour:
    //   1. `putImageData` paints NOTHING in this Canvas implementation —
    //      its own on-screen strip rendered empty while the identical
    //      levels drawn with fillRect rendered fine. fillRect only.
    //   2. A hidden Canvas (`visible: false`, and `opacity: 0` too) never
    //      RASTERIZES — the paint pipeline is gated on visibility,
    //      separately from scene-graph rendering — so any sampler over it
    //      reads all zero. It must stay `visible: true`, parked OUTSIDE
    //      the item so the surface clips it away; an off-window item
    //      still rasterizes (proven in the same probe).
    //   3. The texture crosses via an explicit ShaderEffectSource. (A
    //      `layer.enabled` canvas also worked on-screen, but the SES is
    //      the arrangement proven off-screen.)
    // The 256 grey fill styles, built once — Qt.rgba per column per frame
    // was 384 QColor allocations 47 times a second, and the canvas raster
    // is CPU work (measured: the display path, canvas included, was the
    // bulk of the feature's cost; the engine feed itself is 5.7 pp).
    readonly property var _greys: {
        const out = new Array(256);
        for (let i = 0; i < 256; i++) {
            const h = i.toString(16).padStart(2, "0");
            out[i] = "#" + h + h + h;
        }
        return out;
    }

    // ── THE PEAK HOLD · one extra row, and it is the CPU's only new job ──
    //                                                          TRK-3778
    // Reference 18's signature is the bright cap floating above each bar and
    // falling back — a peak-hold marker, which every hardware meter has and
    // no fragment shader can have on its own, because a peak is STATE and a
    // fragment shader is pure. It cannot be faked from the level: a marker
    // derived from the current frame is just a taller drawing of the column.
    //
    // So the state lives here, in the one array the CPU already touches, and
    // travels in a SECOND ROW of the same texture. Cost: one extra fillRect
    // per band per paint, on a canvas that is already being painted — no
    // second upload, no second sampler, no timer.
    //
    // DECAY: multiplicative per level update, plus a small linear term so a
    // marker actually reaches zero rather than asymptoting at a visible
    // height. The engine sends ~47 updates/s, so 0.965^n puts a full-scale
    // marker back on the floor in about 0.9 s — slow enough to read as a
    // held peak, fast enough that it is never stale by the next chorus.
    property var _peaks: []
    readonly property real _pkDecay: 0.965
    readonly property real _pkFloor: 0.004

    Canvas {
        id: specTex
        x: -width - 16
        y: 0
        width: Math.max(1, root.levels.length)
        // TWO rows: 0 = level, 1 = peak hold. Texel centres of a 2-row
        // texture are v = 0.25 / 0.75, and the shader samples exactly there,
        // so linear filtering returns each row unmixed — the rows cannot
        // bleed into each other however the sampler is configured.
        height: 2
        visible: true
        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const n = root.levels.length;
            const g = root._greys;
            const pk = root._peaks;
            for (let i = 0; i < n; i++) {
                const v = Math.min(1, Math.max(0, root.levels[i]));
                ctx.fillStyle = g[Math.round(v * 255)];
                ctx.fillRect(i, 0, 1, 1);
                const p = i < pk.length ? pk[i] : 0;
                ctx.fillStyle = g[Math.round(Math.min(1, Math.max(0, p)) * 255)];
                ctx.fillRect(i, 1, 1, 1);
            }
        }
    }
    // Every SECOND wire frame (23.4 Hz level updates). The wire is already
    // half the analysis rate for the same reason (TRK-3697's measured
    // 41→22 pp); the eye's sense of rate comes from the shader's own 60 fps
    // wobble and kick, which never miss a frame — the LEVELS moving at
    // 23 Hz under them is the same compromise every desktop visualiser
    // ships, and it halves the raster again.
    property int _paintGate: 0
    onLevelsChanged: {
        // The peaks decay on EVERY update even though the canvas repaints on
        // every second one: the decay is the state, the paint is the display,
        // and halving the display rate must not halve the fall time.
        const n = root.levels.length;
        let pk = root._peaks;
        if (pk.length !== n) {
            pk = new Array(n);
            for (let i = 0; i < n; i++)
                pk[i] = 0;
        }
        for (let i = 0; i < n; i++) {
            const v = root.levels[i];
            const d = pk[i] * root._pkDecay - root._pkFloor;
            pk[i] = v > d ? v : (d > 0 ? d : 0);
        }
        root._peaks = pk;
        if (n === 0 || (root._paintGate++ & 1) === 0)
            specTex.requestPaint();
    }

    ShaderEffectSource {
        id: specSrc
        sourceItem: specTex
        live: true
        smooth: true
        visible: false
    }

    // Tokens cross to the GPU as vec4s, the same shape GlassEdge uses.
    function _v4(c) {
        const q = Qt.color(c);
        return Qt.vector4d(q.r, q.g, q.b, q.a);
    }


    // ══ THE GROUND · IT IS THE BAR'S OWN MATERIAL ══════════ TRK-3814 ══
    // ⚠ THIS IS THE THIRD POSITION ON ONE AXIS AND ALL THREE ARE HIS. The
    // axis is narrow enough that it has been misread twice, so the arc is
    // written out rather than summarised:
    //
    //   1. The analyser sat at zChrome over everything: "theres a music
    //      graph that shows up and take over the bottom bar".
    //   2. It was dropped to zPaint so the living paint composited through:
    //      "the swirls are still behind the graph ... WITH OUT THE SWIRLS
    //      BEHOND IT". He meant they were SHOWING and he did not want them.
    //   3. TRK-3778 answered (2) with a FULLY OPAQUE `void_` slab. That does
    //      remove the swirls — and removes the bar with them:
    //      "the back gtround is just pure black behind it instead of the
    //       backgrounf".
    //
    // Read together those three are one consistent request that no single
    // one of them states: NOT the living paint, NOT dead black, THE BAR.
    // Its glass, its ladder, its backdrop — the thing the resting bar is
    // made of, minus the animation running on it.
    //
    // ══ SO THE GROUND IS THE SHELF, AND IT IS THE SAME TOKENS ═══════════
    // Bar.qml § the Shelf draws `shelfTop → shelfMid → shelfDeep` at 0.15 /
    // 0.20 / 0.34 — Theme's one MATERIAL FORMULA, the same ladder every
    // glass surface in this build is cut from. This is that gradient, at
    // those stops, from those tokens. Not a colour picked to look like the
    // bar: the bar's own three tokens, so when the formula moves this moves
    // with it and cannot drift into a fourth material (`13pu`'s whole
    // subject).
    //
    // ⚠ AND IT IS TRANSLUCENT AGAIN ON PURPOSE. Opacity was never what
    // satisfied ruling (2) — standing the SWIRL down is (Bar.qml § TRK-3814),
    // and that is a separate item with a separate switch. Keeping the slab
    // as well would be belt-and-braces that costs the exact thing he just
    // asked for back. The face now shows what the resting bar shows: the
    // wallpaper, through this build's glass, with no paint moving on it.
    //
    // ⚠ WHAT THIS GIVES UP, STATED PLAINLY. An opaque face could be proven
    // clean by counting swirl-hued pixels on it (the TRK-3778 gate). A
    // translucent one cannot: it is CORRECT for the wallpaper to read
    // through it. The property that replaces it is upstream and stronger —
    // the Swirl item is not rendering at all past 90°, which is a `visible`
    // binding rather than a pixel census, and a thing that is not drawn
    // cannot leak. Any future gate here must assert THAT, not a hue count.
    // ══ ⚠ HOW BRIGHT, AND A RETRACTION ══════════════════════════════════
    // AN EARLIER CUT OF THIS COMMENT CARRIED THREE MEASURED-SOUNDING
    // NUMBERS AND ALL THREE WERE JUNK. It reported that swapping the opaque
    // slab for the Shelf's own tokens moved the face's mean row floor from
    // 16.4 to 16.5 out of 255, and concluded from that the Shelf "is not
    // what makes the bar look like the bar — most of that light is the
    // SWIRL". Every one of those captures was taken while the shell was
    // SILENTLY REJECTING the reload: a duplicate `visible` in Bar.qml made
    // the whole configuration unloadable, `qs ipc call nyxus reload`
    // answered "reloading" and then failed, and the running shell kept the
    // previous config in memory. So three "before/after" runs all
    // photographed the SAME unchanged face, and the differences between
    // them were noise being read as signal.
    //
    // The retraction is left in rather than the numbers quietly replaced,
    // because the shape of the mistake is the useful part: A DEPLOY THAT
    // REPORTS SUCCESS IS NOT A DEPLOY THAT TOOK. `~/.cache/nyxus/shell.log`
    // is the authority ("Configuration Loaded" vs "Failed to load
    // configuration") and it is one ssh away. It is the same class as the
    // .qsb trap recorded in the shader's header, twice in one session.
    //
    // ══ WHAT IT ACTUALLY MEASURES, ON A CONFIG THAT LOADED ══════════════
    // Mean 10th-percentile row luminance, columns 600–900 of his live bar,
    // y 4..80 (docs/proof/musicgraph-fix-0906/cmp-ground.py):
    //
    //   resting bar, the thing being matched .................. 35.1
    //   this ground, translucent Shelf + lift ................. 36.6
    //   this ground, FLATTENED opaque (what ships) ............ 35.6
    //   the opaque void_ slab he rejected ..................... 16.4
    //
    // So the material ladder DOES get there — it lands within half a unit
    // of the resting bar — and the earlier claim that it could not was an
    // artefact of the failed reload.
    //
    // ⚠ AND THE TRANSLUCENT ONE HAD TO GO, WHICH IS THE REAL CONSTRAINT.
    // At 36.6 it matched the bar exactly and let the BarSeam swirl read
    // straight through it — visibly, in the capture — which is the one
    // thing he has ruled on twice. Opacity is what keeps the paint out; the
    // LADDER is what stops the result being a hole. The two previous rounds
    // each picked one and lost the other. `_t()` below composes the lifted
    // material and then flattens it onto `void_`, so this ground is fully
    // opaque AND measures 35.6 against the bar's 35.1.
    //
    // `lift` is the one number between the Shelf as-is and the bar's own
    // brightness. It lifts toward `glacier[1]`, a palette rung, so nothing
    // off the ramp is invented (rule 8; periwinkle stays out, TRK-1750).
    property real lift: 1.0
    Rectangle {
        id: ground
        anchors.fill: parent
        // The lift is strongest at the SEAM and dies at the top edge,
        // because that is the resting bar's own shape — its floor runs
        // 9 → 57 → 117 → 34 from top to bottom. A flat lift would brighten
        // the top of the face, where the resting bar has almost nothing, and
        // that reads as fog rather than as glass.
        readonly property color _up: Theme.paintLayers.glacier[1]
        // ⚠ FLATTENED ONTO `void_` AND RETURNED FULLY OPAQUE, and that is
        // the whole synthesis. A TRANSLUCENT ground was deployed first and
        // measured on his live bar at a mean row floor of 36.6 against the
        // resting bar's 35.1 — it matched the material exactly, and it let
        // the BarSeam swirl read straight through it, which is the one
        // thing he has ruled on twice ("WITH OUT THE SWIRLS BEHOND IT").
        // Opacity is what keeps the paint out; the LADDER is what stops the
        // result being a black hole. Doing both means composing the bar's
        // own lifted material and then flattening it, rather than choosing
        // between them — which is what the previous two rounds each did.
        // ⚠ THIS RETURNED alpha 1.0 — AN OPAQUE FLOOR. Owner 2026-09-07:
        // "what if we made the background of the bar see through or pure
        // glass so its the background then with the music visulizer".
        //
        // The bar was never see-through. `barFloor` is false and the glass
        // above is translucent, but THIS gradient flattened its tint onto
        // Theme.void_ and returned a solid colour, so it painted over the sky
        // the bar had gone to the trouble of drawing behind it (SkyBehind).
        // That is why the ground measured #0c2336 while the wallpaper 40px
        // higher measured pure #000000, and why dropping the glass and the
        // swirl barely moved it — they were underneath this.
        //
        // Now it keeps the tint but hands back an ALPHA, so the sky reads
        // through and the bar is the edge, the light and the spectrum. The
        // ceiling is deliberately well under 1: `amt` reaches 0.72 at the
        // centre, and the point is that it is glass there too.
        function _t(base, amt) {
            const c = Qt.tint(base, Qt.rgba(ground._up.r, ground._up.g,
                                            ground._up.b, amt * root.lift));
            return Qt.rgba(c.r, c.g, c.b, Math.min(0.13, 0.04 + amt * 0.10));
        }
        gradient: Gradient {
            GradientStop { position: 0.00; color: ground._t(Theme.shelfTop, 0.18) }
            GradientStop { position: 0.42; color: ground._t(Theme.shelfMid, 0.42) }
            GradientStop { position: root.centreFrac; color: ground._t(Theme.shelfDeep, 0.72) }
            GradientStop { position: 1.00; color: ground._t(Theme.shelfDeep, 0.26) }
        }
    }

    // ── the border pulse · "a border pulse on the real beat" ────────────
    // The top edge of the panel, and it is the ONLY edge that gets one: the
    // bar's bottom is the screen edge and its sides are the screen sides, so
    // a full border would be three lines nobody can see and one they can.
    // Driven by `Beat.kick`, which is the PLL's STRUCK beat — the predicted
    // one, not an amplitude threshold — so it lands on the beat the tracker
    // believes in rather than on whatever was loudest 40 ms ago. Colour is
    // ⚠ TWO STACKED RECTANGLES, NOT ONE COLOUR LERPED BY THE KICK. Lerping
    // glacier[0] (H 191) toward magma[5] (H 16) is a 175° cross-wheel mix —
    // the literal mud case in DESIGN_DEPTH_2026-09-06 § 8 — and "it only
    // passes through the middle for 120 ms" is an excuse, not an exemption.
    // Cross-FADING two legal colours composites them instead of averaging
    // them: the intermediate frames are glacier with magma laid over it,
    // which is what a hot edge actually looks like, and no frame contains a
    // derived hue at all.
    Item {
        id: rim
        // ⚠ OFF, owner 2026-09-07: "theres still a line on the top edge i see
        // it pulsating to the mussiv". He asked for the top of the bar to fade
        // into the desktop, and this is a 2px line drawn along exactly that
        // edge — a black scrim underneath cannot hide something painted above
        // it in the same layer, so it is switched off at the source instead of
        // covered.
        //
        // NOT DELETED. The border pulse is a real feature and its reasoning is
        // documented above (two stacked rectangles rather than a cross-wheel
        // lerp, driven by the PLL's struck beat). `visible: true` brings it
        // straight back if he ever wants the edge to answer the beat again.
        visible: false
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 2
        Rectangle {
            anchors.fill: parent
            color: Theme.spectrumRamp[9]        // glacier[0], the resting edge
            opacity: root.liveT * 0.05
        }
        Rectangle {
            anchors.fill: parent
            color: Theme.spectrumTip            // magma[5], the struck beat
            opacity: root.liveT * 0.16 * Math.min(1, Beat.kick)
        }
    }

    // ══ THE RECORD · BUILT, APPROVED, REJECTED, DELETED ═ REJECTION 4 ═══
    //                                      TRK-3741, deleted TRK-3810
    // There is no record here any more, and there is not going to be one.
    // What stood here was a vinyl disc at the LEFT of the face, drawn behind
    // the field, turning one revolution per bar off the tracked tempo. The
    // full arc, in one day, because the arc IS the lesson:
    //
    //   built  — off his own reference image, a record with notes streaming
    //            off it, tempo-locked so it was honest rather than decorative
    //   liked  — "well the record is in the bar i never had that before"
    //   cut    — "also the music visulizer there like lines riuning through
    //            the bootom/middle of it and the record get rid of"
    //   moved  — a minute later: "or with the record on the right side we
    //            could make it some it could be like a dj scrather or
    //            whatever just for fun". A right-hand scratcher was designed
    //            and started against this.
    //   gone   — "and get rid of the record sorry". Last word, and it wins.
    //            The scratcher was withdrawn before it shipped; nothing of it
    //            reached his machine.
    //
    // ⚠ THE LESSON, WHICH IS NOT "HE CHANGED HIS MIND". Every one of those
    // verdicts was consistent with the one before it. He approved the record
    // FROM A DESCRIPTION AND A STILL, and rejected it the moment he watched
    // it MOVE at 84 px. That is the trap this file keeps getting caught in:
    // an ornament that is charming in a screenshot and wrong in motion at
    // this size, because at 84 px a rotating disc is a small grey circle
    // that wobbles, and the eye reads it as something faintly wrong with the
    // bar rather than as a record. Rounds 1 and 2 died the same way. The
    // rule that comes out of it, and it is worth more than the code that was
    // deleted: ON THIS SURFACE, NOTHING IS APPROVED UNTIL HE HAS SEEN IT
    // MOVING ON HIS OWN SCREEN. A still capture is not evidence here.
    //
    // ⚠ AND THE NOTES NEVER CAME OFF IT. The old header claimed the notes
    // "stream off" the disc — the reference image does, but the code never
    // did: every note has always launched from a band's own x anywhere in
    // the field. So deleting the record costs the notes nothing and they
    // needed no new emitter. The prose was describing the reference rather
    // than the build, which is the ordinary way a comment becomes false.

    // ── the field ───────────────────────────────────────────────────────
    ShaderEffect {
        id: fx
        anchors.fill: parent
        visible: root.liveT > 0.004
        fragmentShader: Qt.resolvedUrl("shaders/spectrum_view.frag.qsb")

        property variant spec: specSrc

        property vector4d size: Qt.vector4d(fx.width, fx.height,
                                            root.time, root.liveT)
        property vector4d music: Qt.vector4d(Beat.kick, Beat.pulse,
                                             root.time - root._downAt,
                                             Beat.energy)
        // 2–3 px of ink with a ~2 px gap — the references' density. The
        // ratio is the constant, so the look survives any screen width.
        property vector4d cfg: Qt.vector4d(
            Math.max(64, Math.round(fx.width / root._columnPitch)),
            root.centreFrac,
            0.26,     // gap half-width, as a fraction of one column pitch
            0.10)     // halo drive — how far light continues past a tip
        // TipFrac × 0.55: the token was measured on a bottom-anchored
        // field; the mirror doubles every tip, so the magma share doubles
        // with it unless the fraction halves. This keeps the measured
        // "under a third of the lit area" property on the new geometry.
        property vector4d tipCfg: Qt.vector4d(
            Theme.spectrumTipFrac * 0.55,
            Theme.spectrumTipJitter,
            Theme.spectrumTipMinH,
            0.05)     // wobble drive — calmed for TRK-3722's "smoother"

        property vector4d cBodyA: root._v4(Theme.spectrumBody[0])
        property vector4d cBodyB: root._v4(Theme.spectrumBody[1])
        property vector4d cTip: root._v4(Theme.spectrumTip)
        property vector4d cSpine: root._v4(Theme.paintLayers.glacier[4])

        // ── the LED cell and the reflection · TRK-3778 ──────────────────
        //   x  PITCH    px between cell centres — 6 gives 7 cells above the
        //               spine and 6 below at chromeH 84
        //   y  INK      lit fraction of the pitch; 1 - ink is the dark seam
        //   z  REFLECT  the lower half's gain. Not 0.5: a mathematically
        //               exact mirror reads as a second meter, and every
        //               reference's reflection is materially dimmer than
        //               what casts it
        //   w  spare
        property vector4d segCfg: Qt.vector4d(Theme.spectrumCellPx,
                                              Theme.spectrumCellInk,
                                              Theme.spectrumReflect, 0)

        // ── THE FREQUENCY RAMP · ten stops, COMPUTED ONCE ──────────────
        // ⚠ EACH OF THESE IS A BINDING ON A `readonly` THEME ARRAY, so it
        // is evaluated once at load and never again — the same discipline
        // the `_greys` table above exists to enforce. A per-frame colour
        // derivation on this surface is 384 QColor allocations 47 times a
        // second; that trap is documented three screens up and this is the
        // second place it could have been walked into.
        property vector4d cR0: root._v4(Theme.spectrumRamp[0])
        property vector4d cR1: root._v4(Theme.spectrumRamp[1])
        property vector4d cR2: root._v4(Theme.spectrumRamp[2])
        property vector4d cR3: root._v4(Theme.spectrumRamp[3])
        property vector4d cR4: root._v4(Theme.spectrumRamp[4])
        property vector4d cR5: root._v4(Theme.spectrumRamp[5])
        property vector4d cR6: root._v4(Theme.spectrumRamp[6])
        property vector4d cR7: root._v4(Theme.spectrumRamp[7])
        property vector4d cR8: root._v4(Theme.spectrumRamp[8])
        property vector4d cR9: root._v4(Theme.spectrumRamp[9])
        property vector4d rU0: Qt.vector4d(Theme.spectrumRampU[0],
                                           Theme.spectrumRampU[1],
                                           Theme.spectrumRampU[2],
                                           Theme.spectrumRampU[3])
        property vector4d rU1: Qt.vector4d(Theme.spectrumRampU[4],
                                           Theme.spectrumRampU[5],
                                           Theme.spectrumRampU[6],
                                           Theme.spectrumRampU[7])
        property vector4d rU2: Qt.vector4d(Theme.spectrumRampU[8],
                                           Theme.spectrumRampU[9], 0, 0)

    }

    // ── the notes · "the ones with the music notes inside of them" ──────
    //                                      TRK-3741, made denser TRK-3811
    // A note launches off the PLL's struck kick, rises through the field and
    // dies inside the zone. Glacier for the beats, magma for the downbeats —
    // the same two families as the field, in the same roles.
    //
    // ══ MORE OF THEM · WHAT THE NUMBER IS AND WHY IT IS THAT NUMBER ═════
    // Owner, 2026-09-06: "add more musicnotes … i like them but is there
    // anything better or cooler … and there needs to be more".
    //
    // ⚠ FIRST, THE THING WORTH KNOWING: THE NOTES NEVER CAME OFF THE RECORD.
    // The old header for the disc said the notes "stream off it", and the
    // reference image does show exactly that, but the code never did: every
    // note has always been launched from THE LOUDEST BAND'S OWN x, anywhere
    // in the field. So moving the record to the right corner and turning it
    // into a scratcher (TRK-3810) costs the notes nothing and they needed no
    // new emitter. The prose was describing the reference, not the build —
    // which is the ordinary way a comment becomes false.
    //
    // THREE NUMBERS CHANGED, AND ONLY THREE:
    //   POOL   6 → 14. The pool is the ceiling on how many can be in the air
    //          at once; a note lives 1150 ms and the refractory below admits
    //          one every 110 ms, so the steady-state population on a
    //          four-on-the-floor track is ~10 and 14 is headroom, not a
    //          target. Raising the pool alone would have changed nothing —
    //          the old build never came close to filling six.
    //   GATE   Beat.kick 0.8 → 0.62. This is the change that actually adds
    //          notes: at 0.8 only the hardest transients qualified, so a
    //          track with a soft kick produced almost none. 0.62 still
    //          rejects the noise floor (the PLL's struck kick sits near 1.0
    //          on a real beat and decays) but admits the off-beats.
    //   REFR   260 ms → 110 ms. At 136.6 BPM a beat is 439 ms and a
    //          sixteenth is 110 ms, so this is exactly one sixteenth: the
    //          fastest subdivision anything in this music lands on, and
    //          therefore the point past which more notes would be showing
    //          events the track does not have.
    //
    // ⚠ WHY NOT MORE THAN THIS. He asked for "more", not "a blizzard", and
    // the taste ceiling here is lower than the cost ceiling: the notes are
    // punctuation over an instrument, and punctuation that arrives faster
    // than the beat stops reading as punctuation. Measured cost is in the
    // ledger; the reason to stop is not the cost.
    //
    // ══ AND THEY SPREAD ACROSS THE BAR NOW ══════════════════════════════
    // Every note used to launch from the single loudest band, so a track
    // with a dominant kick drum put every note in the same two inches of
    // bass. `_spawnNote` now picks from among the loud bands weighted by
    // level, which puts them where the music is WITHOUT stacking them — the
    // owner's "throughout" is a distribution, not a count.
    readonly property var _glyphs: ["♪", "♫", "♩", "♬", "𝄞", "♭"]
    readonly property int _notePool: 26
    // ⚠ TWO PER STRIKE, NOT A FASTER STRIKE ─────────────────── TRK-3811
    // He asked for more a second time, having closed the alternatives
    // question himself ("add more music notes since we didnt find nay thing
    // else"). The obvious lever is the refractory, and it is the wrong one:
    // 110 ms IS one sixteenth note at the 136.6 BPM measured on his own
    // library, so anything shorter emits notes faster than the music has
    // events and the field stops agreeing with what is being played. The
    // notes would arrive on a grid of their own.
    // So the STRIKE stays on the sixteenth and each strike sends TWO,
    // drawn from two independent weighted picks — different bands,
    // therefore different places along the bar. Density doubles, the timing
    // is still the track's.
    property int _noteIdx: 0
    property double _noteAtMs: 0

    // ⚠ THE NOTES ARE NEVER HELD BACK FOR A WORD, and the retired mechanism
    // is worth one line so nobody re-adds it. A `notesHold` flag used to
    // stop the emitter while a lyric was on screen, on the theory that the
    // two compete for the same 84 px. On this owner's music words arrive
    // several times a second, so that flag would have been true almost
    // continuously — silently deleting the notes he has twice asked to see
    // MORE of, for as long as a song had lyrics. The word wins on size,
    // weight and outline instead. See § THE WORD.

    Connections {
        target: Beat
        function onKickChanged() {
            if (!root.live || Beat.kick < 0.62)
                return;
            const now = Date.now();
            if (now - root._noteAtMs < 110)
                return;
            root._noteAtMs = now;
            root._spawnNote(Beat.downbeat);
            root._spawnNote(Beat.downbeat);
        }
    }

    function _spawnNote(down) {
        const n = root.levels.length;
        if (n === 0 || root.width <= 0)
            return;
        // WEIGHTED PICK, not argmax. One pass sums the levels above a floor,
        // a second walks to a random point in that sum — so a band is chosen
        // in proportion to how loud it is, and the bass end stops being the
        // only place a note can appear. The floor is the same 0.14 the
        // shader takes off before it draws anything (§ shape()), so the
        // notes and the field agree on what counts as silence; without it
        // the sum is dominated by 384 bands of nothing.
        let tot = 0;
        for (let i = 0; i < n; i++) {
            const v = root.levels[i] - 0.14;
            if (v > 0)
                tot += v;
        }
        let bi = 0, bv = 0;
        if (tot <= 0) {
            for (let i = 0; i < n; i++) {
                if (root.levels[i] > bv) { bv = root.levels[i]; bi = i; }
            }
        } else {
            let want = Math.random() * tot, acc = 0;
            for (let i = 0; i < n; i++) {
                const v = root.levels[i] - 0.14;
                if (v <= 0)
                    continue;
                acc += v;
                if (acc >= want) { bi = i; bv = root.levels[i]; break; }
            }
        }
        const slot = root._noteIdx % root._notePool;
        root._noteIdx++;
        const cx = ((bi + 0.5) / n) * root.width
                   + (Math.random() - 0.5) * root.width * 0.04;
        // A SIGNAL, not notePool.itemAt(slot).fly(...): itemAt() types as a
        // bare QQuickItem, so the member call is a missing-property warning
        // to qmllint — the exact class audit item 1 counts, and the one
        // whitelisted instance (Swirl's `.out`) is documented as a
        // never-again. Each delegate filters the signal on its own index.
        root.noteFly(slot,
                     Math.max(root._edgePad,
                              Math.min(root.width - root._edgePad, cx)),
                     root._glyphs[Math.floor(Math.random() * root._glyphs.length)],
                     down ? Theme.spectrumTip : Theme.paintLayers.glacier[5],
                     down ? 20 : 14 + Math.round(6 * bv),
                     (Math.random() - 0.5) * 26,
                     false);
    }
    // `word` is the only branch in the delegate: same pop, same fade, but
    // a word holds still and is not rotated, because it has to be READ.
    signal noteFly(int slot, real px, string glyph, color tint, int sz, real drift, bool word)

    // ══ THE KEEP-OUT · THE BAR HAS CONTROLS ON IT ════════════ TRK-3817 ══
    // Owner, 2026-09-07, once the lyrics were on his own screen:
    //
    //   "i see it now"        (the word landing on the clock)
    //   "and where the apps are byt the sigil"
    //   "and the right side tray icons"
    //
    // A NOTE landing on the clock is decoration brushing past a readout and
    // nobody minds. A WORD on the clock is TEXT OVER TEXT and it destroys
    // both — the capture that opened this row has "flocks" and "1:40 AM"
    // sharing the same pixels, and neither can be read.
    //
    // ⚠ THIS IS THE SAME CLASS AS TRK-3813, WHICH THIS LANE ALSO CAUSED.
    // There the instrument covered Start and the bar kept every pixel and
    // lost every control. Here the instrument covers a readout. The rule
    // both of them are instances of: THE BAR'S FUNCTIONAL ELEMENTS OUTRANK
    // THE INSTRUMENT, always, and an instrument that has to be given room
    // is given it by moving, not by dimming what it landed on.
    //
    // ⚠ THE ZONE LIST IS NOT WRITTEN HERE. `keepOut` is handed in by
    // Bar.qml, computed from THE SAME ITEMS `openZoneMenu` hit-tests
    // through `inZone()`. Two reasons, and the second is the recorded
    // failure class in this repository: the zones MOVE (the Meridian is a
    // clock at rest and a two-line NOW PLAYING notice while music is up —
    // which is exactly when lyrics exist — the tray collapses to zero width
    // when nothing is registered, and the dock grows with every open
    // window), and a second hardcoded copy of the bar's layout is a copy
    // that drifts from the first. A pixel range measured off a screenshot
    // would have been wrong before this file was saved.
    //
    // ⚠ WHAT IS DELIBERATELY NOT IN IT. The three Rails — `implicitWidth: 1`
    // when vertical (Rail.qml) — are chrome and are excluded on purpose: a
    // phrase crossing a one-pixel divider loses nothing, while including
    // them would CUT each free span in two and there are only two wide
    // spans on the whole bar. The dock's hover `caption` is excluded for a
    // different reason: it exists only while his pointer is on an icon, and
    // a keep-out that appears under the pointer would make the lyrics jump
    // whenever he moves the mouse. Everything else on the plate is in.
    //
    // ⚠ A SPAN IS IN SCENE x, NOT IN THIS ITEM'S x, and that is deliberate.
    // BarSpectrum fills the bar's width so the two coincide TODAY, and
    // "they coincide today" is how the next layout change becomes a silent
    // defect. Scene coordinates also break what would otherwise be a
    // binding loop: Bar.qml's list would have to map INTO this item, while
    // this item's `keepOut` binds to that list. Neither end mentions the
    // other now — Bar.qml maps out to the scene, `_freeSpans` maps in.
    property var keepOut: []

    // ⚠ THE GEOMETRY IS IN `LyricPhrase.js`, NOT HERE, so verify-profile
    // gate 14g1 can EXECUTE it — over the bar's real zone widths — and
    // assert that a placed phrase intersects no keep-out span. A gate that
    // greps for `keepOut` proves nothing.
    function _freeSpans() {
        const pad = root._edgePad;
        const cuts = [];
        for (let i = 0; i < root.keepOut.length; i++) {
            const k = root.keepOut[i];
            if (!k || k.length < 2)
                continue;
            // Scene x in, this item's x out. See the note on `keepOut`.
            cuts.push([root.mapFromItem(null, k[0], 0).x,
                       root.mapFromItem(null, k[1], 0).x]);
        }
        return LyricPhrase.freeSpans(cuts, root.width, pad, root._wordGap);
    }

    // The clearance a phrase keeps from a control it is standing next to.
    // Zero would be legal and would still read as crowding.
    // The widest run of free bar there is, in px. The phrase shrinks to fit
    // this rather than being clipped or running under a control.
    function _widestFree() {
        const f = root._freeSpans();
        return f.length > 0 ? f[0][1] - f[0][0] : Math.max(0, root.width - 24);
    }

    // Where a phrase `w` px wide goes, given the position the spread wanted.
    function _placeWord(cx, w) {
        return LyricPhrase.place(root._freeSpans(), cx, w);
    }

    // ══ THE WORD · IT IS A NOTE THAT SAYS SOMETHING ══════════ TRK-3815 ══
    // Owner, 2026-09-07, pointing at his own running bar:
    //
    //   "do you see how the music note pop up and fade away thats how i
    //    wanted the lyrics that same way"
    //
    // That is not "similar to the notes". It IS the notes, with words in
    // them — so this rides `noteFly` and the same delegate pool rather than
    // being a second pop-and-fade system on the same 84 px. A first cut of
    // this was a separate Text with its own animation graph and it is
    // deleted: TRK-3275/3371 is this build's recorded cost for one effect
    // implemented twice and the copies drifting apart, and two independent
    // fade curves on one bar is exactly that shape.
    //
    // ══ THE ONE REAL DIFFERENCE, AND THE POOL ENFORCES IT ═══════════════
    // Notes are decorative and independent: one can be dropped, doubled or
    // land anywhere and nothing is lost. WORDS ARE A SEQUENCE WITH MEANING.
    // If two overlap, or one is still fading when the next pops, the line
    // cannot be read.
    //
    // So words get ONE RESERVED SLOT — the last in the pool, which the note
    // emitter's `% _notePool` can never reach. That single constraint buys
    // both properties at once: only one word can be on screen because there
    // is only one slot to be on, and each word's lifetime is bounded by the
    // gap to the next because the next word RESTARTS the same delegate and
    // cancels it. The sequence's own timing becomes the animation's timing,
    // with no duration to tune and no second clock to drift against.
    //
    // ══ IT IS A PHRASE NOW, AND THE ONE SLOT STILL HOLDS ═════ TRK-3817 ══
    // Owner, 2026-09-07: "more words at once in a sence instead of one or
    // two then it looks like it goes by to fast", and "the words needs to
    // stay a little longer so the eye ca[n] catch it and read it ... not
    // even a second probaly".
    //
    // ⚠ THE DWELL WAS NOT BOUGHT WITH A LONGER ANIMATION. It could not be:
    // the paragraph above is the reason — a unit's life ends when the next
    // one arrives, so raising a duration would have either overlapped two
    // phrases in one slot or pushed the display behind the music. The unit
    // got BIGGER instead. MediaSource groups four words into one phrase and
    // the dwell goes 240 ms → 857 ms median on his own test track WITH NO
    // ADDED LAG, because nothing about the timing moved. The numbers and
    // the reasoning are in MediaSource.qml § THE PHRASE.
    //
    // ⚠ WHAT THE ONE-SLOT DESIGN COST WHEN THE UNIT GREW, AND HOW IT IS
    // PAID. One slot still guarantees the two things it was bought for —
    // never two phrases at once, and the sequence's timing IS the
    // animation's. What it never guaranteed is that the unit FITS. A word
    // is ~60 px; a 24-character phrase at 26 px is ~330 px, and there are
    // exactly two free runs on this bar wide enough to hold one. So the
    // placement is no longer a hash into 10%–90% of the width: the phrase
    // is measured, shrunk if the widest free run is narrower than it is,
    // and dropped into a run that FITS. § THE KEEP-OUT owns that geometry.
    // The spread survives as the PREFERENCE, not the answer — the hash
    // still says where the phrase would like to be and the free spans
    // decide where it can be, so the line still walks the bar instead of
    // parking in one gap.
    //
    // ⚠ AND THE NOTES ARE NOT SUPPRESSED. An earlier cut held them back
    // while a word was up, on legibility grounds. That was wrong for this
    // owner: words arrive several times a second on the rap he listens to,
    // so holding the notes would have silently deleted the feature he has
    // twice asked to see MORE of, for as long as a song had lyrics.
    // Legibility is bought with size, weight and an outline instead — the
    // word is simply the loudest thing on the surface.
    // ══ WHY THERE ARE TWO WORD SLOTS AND NOT ONE ════════════ TRK-3825 ══
    // Owner, 2026-09-07, with the phrasing already approved
    // ("word in the music visionizer are perfect now thank you"):
    //
    //   "remeber there suppose to fade away somewhat slowly they dont
    //    fasde away"
    //
    // ⚠ THE FADE WAS ALWAYS WRITTEN AND ALMOST NEVER RAN, and the reason is
    // the one-slot design directly above. `flight.restart()` on the arriving
    // phrase CANCELS the outgoing phrase's opacity animation and drives the
    // same delegate's opacity from 0 again — so mid-line every phrase is
    // REPLACED, not faded. The 2090 ms tail only ever played at the END of a
    // line, where no next phrase came to cut it. That is exactly what he can
    // see: the notes have 26 delegates and nothing ever steals one back, so
    // a note ALWAYS finishes its fade. He is comparing a fade that runs
    // against a fade that is cancelled.
    //
    // ⚠ THE FIX MAY NOT COST THE DWELL. He complained two rounds ago that
    // the line "goes by to fast", and the dwell he now calls perfect is the
    // whole gap between phrases. So the fade is NOT carved out of that gap.
    // The phrase keeps every millisecond of its readable life and the fade
    // is spent AFTER it, overlapping the next phrase's 110 ms entrance —
    // which needs a second delegate, because the arriving phrase is already
    // using the first one.
    //
    // ⚠ AND IT MAY NOT REINTRODUCE OVERLAP, which is what the single slot
    // was bought for. Two slots do not mean two phrases: only ONE is ever
    // legible. The outgoing one is released the instant the next arrives and
    // is on a fast-falling curve (§ `ghost`) — about half its opacity by
    // ~110 ms and a third by ~170 ms — so it is unmistakably ghosting
    // away while the incoming phrase is still popping in. It never competes
    // for the eye, and it is never the thing being read.
    //
    // ⚠ TWO IS ENOUGH AT HIS SPEED, and that is arithmetic rather than
    // hope. A slot is only reclaimed every SECOND phrase, so a ghost gets
    // twice the inter-phrase gap to finish in. Measured on his own test
    // track (MediaSource § THE PHRASE) the phrase gap is median 857 ms and
    // p10 574 ms, so the ghost has 1714 ms / 1148 ms against a 560 ms fade.
    // Even a pathological 280 ms gap leaves 560 ms — exactly enough. A
    // third slot would buy nothing and would put a second stale phrase on
    // the bar.
    readonly property int _wordSlot: root._notePool
    readonly property int _wordSlotB: root._notePool + 1
    property int _wordTick: 0

    // Hand a delegate's phrase over to its fade. Emitted for the slot the
    // PREVIOUS phrase is on, immediately before the new one flies.
    signal noteRelease(int slot)

    Connections {
        target: MediaSource
        // ⚠ DRIVEN OFF `lyricSeq`, NOT THE STRING. Comparing text cannot
        // see a repeat, and "no no no" has to fire three times. That is the
        // whole reason the other lane exposed a counter.
        function onLyricSeqChanged() {
            if (!root.live || !Prefs.lyricsOnline)
                return;
            const w = MediaSource.lyricText;
            if (w === "")
                return;
            // ══ LEFT TO RIGHT, AND WHY IT IS NOT A "DIRECTION" ═ TRK-3833 ══
            // Owner, 2026-09-07: "the lyrics start right and go left they
            // should go left to right just an fyi".
            //
            // ⚠ A PHRASE DOES NOT TRAVEL. It is emitted with `drift: 0` and
            // holds still while it is read (see the emit below) — so there
            // was no direction to reverse, and reversing a drift would have
            // been a fix to a mechanism that is not running. What he is
            // reading as direction is the ORDER OF PLACEMENTS: successive
            // phrases used to land at a HASH of the sequence number, which
            // is spread but unordered, so the line jumps around the bar and
            // an eye that reads left-to-right sees the jumps that go
            // backwards. Ordering the placements is what answers him.
            //
            // So the wanted centre now MARCHES: each phrase lands one step
            // right of the last and wraps to the left edge. Still keyed to
            // `lyricSeq` rather than to a counter, which preserves the
            // property the hash was bought for — the value is a pure
            // function of the phrase's own sequence number, so a phrase
            // cannot jitter during its own life.
            //
            // ⚠ FOUR STEPS, NOT A SMOOTH SWEEP, AND THE STEP SIZE IS THE
            // WHOLE CONSTRAINT. Consecutive phrases overlap in time — the
            // outgoing one is still fading (§ `ghost`, 560 ms) while the
            // incoming pops in. A small step would put the newcomer
            // directly on top of the ghost, which is EXACTLY the defect
            // `03-rejected-outquad-overlap.png` records and the reserved
            // slots were bought to prevent. Four steps put consecutive
            // phrases 0.267 x width apart = 512 px at 1920, wider than the
            // widest phrase measured on his bar (369 px), so the ghost and
            // its successor never share a column.
            //
            // ⚠ THE KEEP-OUT IS UNAFFECTED and is not re-derived here: this
            // is only the WANTED centre. The delegate still measures the
            // phrase and `_placeWord` still snaps it into a free run, so a
            // phrase entering at the left meets the sigil and the app icons
            // and is pushed off them by the same mechanism that pushed it
            // off the tray. Nothing about dwell, phrase length, size, the
            // fade or the spans moved.
            const _steps = 4;
            const h = (MediaSource.lyricSeq % _steps) / (_steps - 1);
            // Alternate the two word slots so the outgoing phrase can
            // finish its fade on the delegate it is already on, instead of
            // being overwritten by the arriving one. See § WHY THERE ARE
            // TWO WORD SLOTS.
            const slot = (root._wordTick % 2 === 0) ? root._wordSlot
                                                    : root._wordSlotB;
            const prev = (slot === root._wordSlot) ? root._wordSlotB
                                                   : root._wordSlot;
            root._wordTick++;
            root.noteRelease(prev);
            root.noteFly(slot,
                         (0.10 + 0.80 * h) * root.width,
                         w,
                         Theme.spectrumBody[1],
                         // 30 → 26. A single word at 30 px never came near a
                         // free run's width; four words do, and every pixel
                         // of size is ~13 px of phrase. 26 keeps the phrase
                         // the loudest thing on the surface (§ THE WORD's
                         // legibility argument is size + weight + outline)
                         // while fitting a 24-character line into the
                         // narrower of the two runs without shrinking.
                         26,
                         0,          // no drift: a phrase being read holds still
                         true);
        }
    }

    Repeater {
        id: notePool
        // +2: the last TWO slots are the WORD's, and the note emitter's
        // `% _notePool` can never reach either. One holds the phrase being
        // read, the other the one fading out behind it. See § THE WORD and
        // § WHY THERE ARE TWO WORD SLOTS.
        model: root._notePool + 2
        delegate: Text {
            id: note
            required property int index
            property bool isWord: false
            opacity: 0
            visible: opacity > 0.01 && root.liveT > 0.004
            font.family: Theme.fUi
            font.pixelSize: 16
            // ⚠ OUTLINE FOR A WORD, RAISED FOR A NOTE, and it is the one
            // legibility decision that matters. A raised glyph reads fine
            // because a glyph is a shape; a WORD sits across a lit LED field
            // and needs its own edge everywhere, not a shadow on one side.
            // An outline hugs each letter, so the cells still show through
            // the gaps between them and nothing is boxed.
            style: note.isWord ? Text.Outline : Text.Raised
            font.bold: note.isWord
            styleColor: Theme.soften(Theme.void_, 0.55)

            property real x0: 0
            property real x1: 0
            property real y0: 0
            property real y1: 0

            // ══ THE WORD'S REFLECTION ═════════════════════ TRK-3828 ══
            // Owner, 2026-09-07, after the rest of the bar got its mirror:
            // "is there anyway to also do a reflection when the lyrics pop
            // up on the musoc bar or no?"
            //
            // ⚠ THAT IS A QUESTION, AND IT WAS ANSWERED BY MEASUREMENT, not
            // by doing as told. A phrase on this bar is the one element that
            // exists to be READ, and its legibility comes from an outline
            // hugging each letter (§ THE WORD). A mirrored copy directly
            // beneath meets that outline from below, which is the one place
            // a reflection can cost something real. It is shipped because
            // the capture says it does not — see the row's proof — and if it
            // had, the honest answer to his question was "no, and here is
            // the frame that shows why".
            //
            // ⚠ NOTHING ABOUT THE PHRASE MOVED. He ruled the words perfect
            // two rounds ago; phrasing, dwell, the TRK-3825 fade, the
            // placement hash and the keep-out spans are untouched. This
            // hangs off the delegate and reads it.
            //
            // ⚠ NO `strength`, DELIBERATELY. This is a CHILD of the `Text`,
            // so the delegate's own opacity already multiplies it — the
            // reflection pops in and fades out with the phrase for free, on
            // the one animation graph, and passing `strength: note.opacity`
            // would apply that fade a second time and leave the mirror
            // invisible for most of a phrase's life.
            //
            // Words keep a copy under the phrase (TRK-3828). Notes only
            // bounce off the SPECTRUM FLOOR — the lower half below the
            // centre spine, the same mirrored band the dock stands on.
            // Child y is `spine - note.y` so the fall stays ON the spine
            // as the glyph flies up; once the note has left the floor
            // there is nothing to reflect.
            readonly property real spineY: root.height * root.centreFrac
            readonly property real aboveFloor: note.spineY - (note.y + note.height)
            readonly property bool onFloor: !note.isWord
                                            && note.opacity > 0.01
                                            && note.aboveFloor < 12
            Reflection {
                visible: note.isWord || note.onFloor
                y: note.isWord ? note.height : (note.spineY - note.y)
                anchors.horizontalCenter: parent.horizontalCenter
                width: note.width
                height: note.isWord ? note.height
                                    : Math.min(note.height,
                                               Math.max(8, root.height - note.spineY))
                clip: !note.isWord
                Text {
                    anchors.fill: parent
                    text: note.text
                    font: note.font
                    color: note.color
                    style: note.style
                    styleColor: note.styleColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Connections {
                target: root
                function onNoteFly(slot, px, glyph, tint, sz, drift, word) {
                    if (slot !== note.index)
                        return;
                    flight.stop();
                    glow.stop();
                    ghost.stop();
                    note.isWord = word;
                    note.text = glyph;
                    note.color = tint;
                    note.font.pixelSize = sz;
                    if (word) {
                        // ⚠ SHRINK BEFORE PLACING, AND MEASURE BOTH TIMES.
                        // `implicitWidth` is only valid once text and size
                        // are set, which is why this is here and not in the
                        // emitter. If the widest free run cannot hold the
                        // phrase, the SIZE gives way — never the keep-out,
                        // and never the phrase by being clipped. 15 px is
                        // the floor: below it the outline stops separating
                        // the letters from the lit field behind them and
                        // the phrase is unreadable anyway, at which point
                        // the honest outcome is a phrase overhanging its
                        // run rather than a smear.
                        const room = root._widestFree();
                        if (note.implicitWidth > room && room > 0) {
                            const shrunk = Math.max(
                                15, Math.floor(sz * room / note.implicitWidth));
                            if (shrunk < sz)
                                note.font.pixelSize = shrunk;
                        }
                        note.x0 = root._placeWord(px, note.implicitWidth);
                    } else {
                        note.x0 = px;
                    }
                    note.x1 = note.x0 + drift;
                    note.y0 = root.height * root.centreFrac
                              - note.font.pixelSize * 0.6;
                    // A word rises a fraction as far as a note: it is twice
                    // the size and has to stay legible for its whole life,
                    // where a note is punctuation and may leave the zone.
                    note.y1 = word ? note.y0 - root.height * 0.16
                                   : root.height * 0.06;
                    note.rotation = word ? 0 : (Math.random() - 0.5) * 24;
                    flight.restart();
                    glow.restart();
                }
                // The outgoing phrase's hand-off. The delegate keeps its
                // `flight` running — it goes on drifting upward while it
                // dims, because a phrase that freezes and then dims reads as
                // a bug, and a phrase that keeps moving reads as leaving.
                function onNoteRelease(slot) {
                    if (slot !== note.index || note.opacity <= 0.01)
                        return;
                    glow.stop();
                    ghost.restart();
                }
            }

            ParallelAnimation {
                id: flight
                NumberAnimation {
                    target: note; property: "y"
                    from: note.y0; to: note.y1
                    duration: note.isWord ? 2200 : 1150
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: note; property: "x"
                    from: note.x0; to: note.x1
                    duration: note.isWord ? 2200 : 1150
                    easing.type: Easing.InOutSine
                }
            }

            // ⚠ THE OPACITY IS ITS OWN ANIMATION AND NOT PART OF `flight`,
            // and that separation is the fix. `ghost` has to be able to take
            // the opacity over from `glow` WITHOUT stopping the motion, and
            // two animations cannot both drive one property. While these
            // lived inside `flight` there was no way to release the fade
            // without freezing the phrase in place.
            SequentialAnimation {
                id: glow
                NumberAnimation {
                    target: note; property: "opacity"
                    from: 0
                    to: note.isWord ? 1.0 : 0.92
                    duration: 110
                }
                // The UNINTERRUPTED tail: what a note always gets, and what
                // a phrase gets at the END of a line where nothing follows
                // it. `Easing.InQuad` holds it near full for most of that
                // span — a phrase is still ~0.91 at 627 ms — so the dwell is
                // spent at reading brightness and the fade is the tail of
                // it, not a dimming that starts on arrival.
                NumberAnimation {
                    target: note; property: "opacity"
                    to: 0
                    duration: note.isWord ? 2090 : 1040
                    easing.type: Easing.InQuad
                }
            }

            // ══ THE HAND-OFF FADE ═══════════════════════════════════════
            // What runs when the NEXT phrase arrives. It starts from
            // wherever `glow` had got to — no `from`, deliberately, so a
            // phrase released early is not brightened back up first — and
            // falls to nothing in 480 ms.
            //
            // ⚠ `Easing.OutCubic`, NOT the InQuad above, and the two curves
            // are answering different questions. `glow`'s tail owns a
            // phrase's whole remaining life and must not dim what is being
            // read, so it holds. `ghost` runs UNDER an incoming phrase and
            // has to stop being a thing to read almost at once while still
            // taking visible time to go: (1−t/T)³ is 0.72 at 60 ms, 0.51 at
            // 110 ms, 0.32 at 170 ms, 0.13 at 280 ms, gone at 560.
            //
            // ⚠ THE CURVE WAS MEASURED ON HIS BAR, NOT CHOSEN, and BOTH
            // ends of the range were rejected by measurement — the numbers
            // are in `docs/proof/lyric-fade-0907/`.
            //   * OutQuad/480 faded beautifully and FAILED the overlap
            //     rule: `LyricPhrase.place` had dropped the incoming phrase
            //     into the free run NEXT TO the outgoing one, and 62 ms and
            //     124 ms later both lines were still plainly legible side
            //     by side — the exact thing the single slot was bought to
            //     prevent.
            //   * OutQuart/520 fixed that and overcorrected into the
            //     original defect: the ghost held above the lit LED field
            //     for only ~110 ms (1624 → 127 → 2 near-white px across two
            //     33 ms frames). That is not a fade, it is a fast vanish.
            //   * OutCubic/560 is the middle that was actually captured
            //     working: ~200 ms of visibly fading phrase, and the
            //     outgoing at roughly half brightness on the frame where
            //     the incoming reaches full.
            //
            // ⚠ THIS COSTS THE DWELL NOTHING. It begins where the phrase's
            // readable life ENDS — at the moment the next one is emitted —
            // and overlaps the newcomer's 110 ms entrance rather than being
            // subtracted from the outgoing phrase's hold.
            NumberAnimation {
                id: ghost
                target: note; property: "opacity"
                to: 0
                duration: 560
                easing.type: Easing.OutCubic
            }
        }
    }
}
