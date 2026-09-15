pragma Singleton
// Nyxus Suxyn — the one palette every shell surface reads.
//
// Mirrors theme/accent.json -- and gate 13pp PROVES it still does, because this
// file hardcodes the sweep and for one commit on 2026-08-06 accent.json was
// re-anchored to the rose while this file was not, which would have shipped a
// palette change that changed nothing on screen.
// Hue-pinned to suxyn-concrete-rose.png. Was sampled from the nebula references
// (2026-08-02) and rendered in design/palette-preview.png.
//
// ⛔ THREE RULES.
//
// 1. NOTHING in the shell may write a hex literal. Add a token here instead.
//    The alien build learned this the hard way: banned colours ended up baked
//    into shipped icons because there was no single source to check against.
//
// 2. NO FLAT FILLS. Every accent is a RAMP that bleeds across whatever it
//    fills, and the whole palette is a SWEEP from teal through indigo into
//    plum. A flat fill is what makes a theme look like construction paper.
//
// 3. EMISSION, NOT PIGMENT. ⟵ new 2026-08-03, and the one that changed every
//    number below. The owner sent four nebula banners and said: "i need the
//    colors to look how these do, how they almost glow, there not dull and
//    boring." Those images were measured (all four, 197k pixels):
//
//      · grounds sit at #000000–#000007. Literally black, faintly blue.
//      · saturation in the MIDS is 0.79–0.86 — and it STAYS above 0.85 all the
//        way down into the darks. There is no such thing in them as a dull
//        dark; a shadow is a deeply saturated violet, not a grey.
//      · 14–24% of every image is above 0.72 value. They are HOT.
//      · only the last 1–3% goes near-white, and it goes there by
//        desaturating (core mean #ed99f6 at S 0.38 over a body at S 0.85).
//
//    The palette this file shipped yesterday failed that test: `indigo`
//    #6b7bff was S 0.58 at V 1.00, `purple` #9b4dca S 0.62, `plum` #a63fa1
//    S 0.62 — high value, medium saturation, which is the textbook recipe for
//    PASTEL. That is why the sweep read as dusty lavender instead of nebula.
//
//    So each accent is now a five-band EMISSION LADDER measured off those
//    images — haze / deep / body / (the accent itself) / glow — where
//    saturation RISES as value falls, and only the top band gives up chroma
//    for luminance. Contrast is what makes saturation read: do not brighten a
//    dull surface, blacken the ground under it.
//
// The single-value tokens exist because some things genuinely cannot take a
// gradient (a one-pixel border, an icon tint).
import Quickshell
import QtQuick

Singleton {
    id: theme

    // ICE vs MAGMA: two house LAYERS. MAGMA replaces glacier FILLS (the
    // 7-stop, the plum/sweep widgets wear). Outlines stay pale glacier so
    // the look is ember + ice, not one colour.
    readonly property bool lookMagma: Prefs.lookSet === "magma"
    // ICE glacier, never remapped. paintLayers.glacier becomes magma when
    // MAGMA is on; hairlines still read this.
    readonly property var iceLayer: ["#7fe8ff", "#123a5e", "#0c1f66", "#274b7a", "#4f7fa6", "#b7e6f2", "#eefcff"]

    // ══ THE STATE LAYER ═══════════════════════════════════════ TRK-4139 ══
    // Owner, 2026-09-14: "i also feel like theres too much of the same color
    // in everything do you feel the same of is it just me".
    //
    // Not just him, and it measured worse than it looked. Bucketing the 39
    // colours on each side of every `lookMagma ?` in this file:
    //
    //   ICE     cyan 31 · blue 15 · magenta 15 · violet 13 · orange 13
    //           six families, widest bucket 31%
    //   MAGMA   red 59 · rose 21 · orange 8 · CYAN 3
    //           88% inside one red→rose arc, and ONE cool token out of 39
    //
    // On screen that came out as red+orange being 70–77% of every chromatic
    // pixel on the bar, the Start menu and Settings alike.
    //
    // The cause is one line: `paintLayers.glacier` is remapped wholesale to
    // magma (see paintLayers, below). That is correct for the PAINT — the
    // swirl should be molten. But 129 call sites across 25 files read
    // `paintLayers.glacier[n]`, and most of them are not paint. They are
    // focus rings, hover washes, active marks and peaks, and they are named
    // for what they were: `iceFocus`, `iceHover`, `icePeak`, `stateFocus`,
    // `iceInteractive`. Several still carry the ICE hex in a trailing
    // comment — SetSwitch.qml documents "focus #7fe8ff" two lines above a
    // binding that returns #ff7847 under MAGMA, and StateEdge.qml does the
    // same. A property called `iceFocus` that renders ember is not a design
    // decision, it is a remap that reached further than it was aimed.
    //
    // So state accents read THIS instead. Under ICE it is byte-identical to
    // `paintLayers.glacier` — glacier IS iceLayer when MAGMA is off — so the
    // ICE theme cannot move by even one pixel. Under MAGMA it gives back the
    // pale glacier those call sites were written against, which is also
    // already the established MAGMA counterpoint: `lookSeam` is iceLayer[5]
    // under MAGMA, and the dock shader got its glacier catch-light in
    // TRK-4127 for the same reason.
    //
    // ⚠ STATE ONLY. Body text, large fills and background washes deliberately
    // stay ember: the point is a second voice where the eye looks for "what
    // is live", not to repaint MAGMA in ICE's colours.
    readonly property var stateLayer: iceLayer
    // Floor hub wears BOTH layers at once (ice/plum + magma). Never remapped.
    readonly property color iceTeal: "#0aa2d6"
    readonly property color icePlum: "#ae206c"
    readonly property color icePlumGlow: "#d765a2"
    readonly property color iceCyan: "#7fe8ff"
    readonly property color magmaEmber: "#ff7847"
    readonly property color magmaGold: "#f7a83b"

    // ── the emission ladders ─────────────────────────────────────────
    // (V, S) per band, straight off the references:
    //   haze .22/.95 · deep .45/.92 · body .65/.88 · accent .90/.83 · glow .98/.42
    // Hue is ours; the ladder shape is measured. `teal` and `gold` keep their
    // exact shipped hexes so nothing in Agent A's half of the build desyncs
    // over a change too small to see.
    // TRK-4147 — the MAGMA column of this table used to hand back #ff7847 for
    // `teal`, for `azure`'s glow and for `plum`, and #f7a83b for `tealGlow`,
    // `plumGlow`, `goldGlow` and `gold`. Seven named accents, two actual
    // colours. ICE spends cyan, ice-blue, deep blue, blue, magenta, pink and
    // gold across those same seven names, so every surface that colour-codes
    // by accent carries seven readings under ICE and two under MAGMA. Fire is
    // not one hue: a volcano runs crimson through rust, copper, orange, amber
    // and gold, so the lanes below are separated by hue (crimson ~8°, the
    // signature orange ~18°, amber ~33°, gold ~46°) and by lightness, while
    // every one of them stays unmistakably ember. `plum` keeps #ff7847
    // because it is MAGMA's signature the way magenta is ICE's, and moving it
    // would move the look itself rather than restore what the look erased.
    //
    // Scope, honestly: these names are spent 69 times across the QML, but NOT
    // on the Start tiles. That was checked by pixel sample before and after
    // and the gems did not move one byte -- MAGMA app icons are etched inside
    // `hardened_magma.frag`, which ignores the per-app tint QML hands it, so
    // the "twenty identical orange squares" reading has a different cause and
    // is not repaired here. What is repaired is the collapse itself, which is
    // true whichever screen you find it on: seven names must not answer with
    // two colours.
    readonly property color tealHaze:   lookMagma ? "#2a0a18" : "#012c3b"
    readonly property color tealDeep:   lookMagma ? "#7a1e0c" : "#026282"
    readonly property color tealBody:   lookMagma ? "#a33214" : "#0582ad"
    readonly property color teal:       lookMagma ? "#ffa22b" : "#0aa2d6"
    readonly property color tealGlow:   lookMagma ? "#ffc85c" : "#5cc6ea"

    readonly property color azureHaze:  lookMagma ? "#3a0c22" : "#000f1c"
    readonly property color azureDeep:  lookMagma ? "#58100f" : "#01203e"
    readonly property color azureBody:  lookMagma ? "#6d1a30" : "#03386b"
    readonly property color azure:      lookMagma ? "#d0331f" : "#064f95"
    readonly property color azureGlow:  lookMagma ? "#ff5b3a" : "#52a0ea"

    readonly property color indigoHaze: lookMagma ? "#2a0a18" : "#060125"
    readonly property color indigoDeep: lookMagma ? "#58100f" : "#0e0153"
    readonly property color indigoBody: lookMagma ? "#6d1a30" : "#160280"
    readonly property color indigo:     lookMagma ? "#a33214" : "#1e03ad"
    readonly property color indigoGlow: lookMagma ? "#ff7847" : "#7a63f0"

    readonly property color violetHaze: lookMagma ? "#3a0c22" : "#0f0415"
    readonly property color violetDeep: lookMagma ? "#58100f" : "#280c3a"
    readonly property color violetBody: lookMagma ? "#6d1a30" : "#38134f"
    readonly property color violet:     lookMagma ? "#a33214" : "#521e72"
    readonly property color violetGlow: lookMagma ? "#ff7847" : "#aa6ece"

    readonly property color plumHaze:   lookMagma ? "#58100f" : "#2e051b"
    readonly property color plumDeep:   lookMagma ? "#7a1e0c" : "#630e3c"
    // #891955, not #891654 — corrected 2026-08-10. The 08-09 unification
    // (`accent.json._border_unified`) ruled that the resting solid and the
    // sweep's plum end were meant to be ONE colour and moved the app layer
    // onto #891955 in thirteen places; `gtk-4.0/gtk.css` now annotates that
    // hex with the words "plumBody" in its own header. This file was not
    // moved with it, so for a day the build had one NAME carrying two
    // VALUES — and since `glassBorder` is bound to it, the disagreement
    // landed on the one cue the comment below that binding says must never
    // disagree: a Quickshell panel edge against a GTK window edge. The
    // shift is 3/255 on green and 1/255 on blue; nobody would have caught
    // it by eye, which is exactly why it needed to be caught by a value.
    readonly property color plumBody:   lookMagma ? "#050203" : "#891955"
    readonly property color plum:       lookMagma ? "#ff7847" : "#ae206c"
    // TRK-4147 — was #f7a83b, the same value `tealGlow` and `goldGlow` both
    // returned. Peach keeps it in the signature lane while separating it.
    readonly property color plumGlow:   lookMagma ? "#ffa07a" : "#d765a2"

    readonly property color goldHaze:   lookMagma ? "#2a0a18" : "#251604"
    readonly property color goldDeep:   lookMagma ? "#7a1e0c" : "#50310b"
    readonly property color goldBody:   lookMagma ? "#a33214" : "#764a12"
    // TRK-4147 — gold answering #ff7847 meant the gold family was not gold at
    // all, it was the signature orange wearing gold's name. The gold lane is
    // the top of the ember range, so it gets to actually be yellow.
    readonly property color gold:       lookMagma ? "#e8a021" : "#9b621b"
    readonly property color goldGlow:   lookMagma ? "#f5d76e" : "#d8a464"

    // ── ramps · light → dark, for gradient bodies ────────────────────
    readonly property var tealRamp:   [tealGlow, teal, tealDeep]
    readonly property var azureRamp:  [azureGlow, azure, azureDeep]
    readonly property var indigoRamp: [indigoGlow, indigo, indigoDeep]
    readonly property var violetRamp: [violetGlow, violet, violetDeep]
    readonly property var plumRamp:   [plumGlow, plum, plumDeep]
    readonly property var goldRamp:   [goldDeep, gold, goldGlow]
    // `purpleRamp` was the old name for the violet→plum half of the sweep.
    readonly property var purpleRamp: [violet, violetBody, plum]

    // THE SIGNATURE, and it is NOT the named ladder above. These are the art's
    // exact colours: the sweep is decorative light over near-black, while the
    // named bands carry foreground and are held to a contrast floor.
    // THE SIGNATURE. Panel rims, glow edges, focus, active indicators, and the
    // hue axis of the living paint. Five stops at the accent band, so the
    // whole sweep is emissive rather than one bright end and one dusty one.
    // MAGMA sweep is the ember falloff (amber → rust → dark), matching
    // sweepStops below. The pale-glacier HAIRLINE rule (lookSeam) covers
    // thin outlines only — broad area light (dock pools, ticks, glows)
    // off an ice stop read as leftover ICE on the magma floor.
    readonly property color sweep0: lookMagma ? "#ff7847" : "#0aa2d6"
    readonly property color sweep1: lookMagma ? "#a33214" : "#064f95"
    readonly property color sweep2: lookMagma ? "#4a100c" : "#1e03ad"
    readonly property color sweep3: lookMagma ? "#1a0806" : "#521e72"
    readonly property color sweep4: lookMagma ? "#050203" : "#891955"
    readonly property var sweepColors: [sweep0, sweep1, sweep2, sweep3, sweep4]
    readonly property var sweepStops: lookMagma
        ? ["#ff7847", "#a33214", "#4a100c", "#1a0806", "#050203"]
        : ["#0aa2d6", "#064f95", "#1e03ad", "#521e72", "#891955"]

    // ══ THE DRIFT · the paint never wears the same colour twice ═════════
    // Owner ruling, 2026-08-09, watching the live shell:
    //   "I want the swirls to change through the theme colours, so as the
    //    swirls move the colours change — never the same when they change,
    //    always random at all times."
    //
    // Every painted surface used to hold a FIXED slice of the sweep: the
    // Start Menu the teal end, the Flyout the plum end, the bar the rose end.
    // That was HORIZON §2.2 — hue as a coordinate system, so you could tell
    // where a surface lived from the colour of its light. This ruling
    // supersedes the fixed part of that rule, and it is worth writing down
    // that it was a deliberate trade and not an oversight: the build gives up
    // "colour tells you WHERE" to get "colour is never twice the same".
    // §2.2's other half survives, because the surfaces still differ from each
    // OTHER at any instant — see `driftCenter`'s offset.
    //
    // One drift for the whole shell, in the palette's own file, because six
    // surfaces each running their own random walk is six things to get out of
    // step and no single place to tune it.
    readonly property real paintSpan: 0.30      // width of the slice, of the ramp
    property real paintCenter: 0.86
    property int  _driftMs: 15000

    // Rec.709 luma of paintGlacierHorizon, stop for stop, sRGB-linearised
    // (the same ruler as the 08-20 10:03 table). Ice bright/peak stay
    // 0.694 / 0.950 so drift cannot park a 0.30 window in the dusk trough
    // (TRK-914). Purple stops are one hue (H≈261) at rising Y.
    readonly property var _rampLight: [0.694, 0.017, 0.006, 0.022, 0.092, 0.119, 0.950]
    // Admits ice peak / ice bright. Refuses a window that only covers the
    // sampled dusk trough (lin Y 0.009–0.062).
    readonly property real paintLightFloor: 0.30

    function _lightAt(t) {
        var n = _rampLight.length - 1;
        var x = Math.max(0, Math.min(1, t)) * n;
        var i = Math.floor(x);
        if (i >= n)
            return _rampLight[n];
        return _rampLight[i] + (_rampLight[i + 1] - _rampLight[i]) * (x - i);
    }

    // The BRIGHTEST point in the window, not the mean: a filament needs one
    // lit stop to be drawn in, and averaging would let a window that is dark
    // everywhere except one bright edge score the same as a uniformly dim one.
    function _windowLight(centre) {
        var best = 0;
        for (var k = 0; k <= 6; k++) {
            var v = _lightAt(centre - paintSpan / 2 + paintSpan * k / 6);
            if (v > best)
                best = v;
        }
        return best;
    }

    // The window travels to a new random centre, takes the whole interval to
    // get there, and is retargeted the moment it arrives — so the colour is
    // ALWAYS in motion rather than changing in steps. The duration and the
    // interval are the same number for exactly that reason.
    //
    // TRK-2501 (CHIEF, 2026-08-22): this WAS a `Behavior on paintCenter` with a
    // NumberAnimation, and it was the single largest cost in the whole shell.
    // A QML animation that never finishes holds Qt's GLOBAL animation driver at
    // the display rate for the entire process lifetime, and every tick
    // re-evaluates everything downstream of `paintCenter` — driftCenter,
    // driftLo, driftHi, GlassMaterial.filamentColor — in every surface holding
    // one, mapped or not. Measured by the SHELLPERF lane: 103.3% of a core with
    // it running, 4.3% with this one value frozen and nothing else changed. The
    // owner's live shell had burned 4h25m of CPU in 4h09m of uptime, and it was
    // breaking up his audio.
    //
    // The motion is a colour wander across a 0.30-wide window over 11–24
    // SECONDS. Sampling that at the display rate buys nothing an eye can see,
    // so it is stepped instead — same curve, same duration, same endpoints,
    // computed rather than animated. `Easing.InOutSine` is exactly
    // -(cos(pi*t)-1)/2, so the shape is identical, not an approximation.
    //
    // A Timer does NOT hold the animation driver open; that is the whole point,
    // and it is why this is not simply a slower Behavior.
    readonly property int _driftStepMs: 250      // 4 Hz; ~0.005 of ramp per step. 2 Hz measured only 3.8 points cheaper — not worth the coarser motion.
    property real   _driftFrom:  paintCenter
    property real   _driftTo:    paintCenter
    property double _driftStart: 0

    Timer {
        id: driftStep
        interval: theme._driftStepMs
        running: theme._driftTo !== theme._driftFrom
        repeat: true
        onTriggered: {
            var span = Math.max(1, theme._driftMs);
            var t = Math.min(1.0, (Date.now() - theme._driftStart) / span);
            // Easing.InOutSine, written out
            var e = -(Math.cos(Math.PI * t) - 1) / 2;
            theme.paintCenter = theme._driftFrom + (theme._driftTo - theme._driftFrom) * e;
            if (t >= 1.0)
                theme._driftFrom = theme._driftTo;   // settles, and stops this Timer
        }
    }

    Timer {
        interval: theme._driftMs
        running: true
        repeat: true
        onTriggered: {
            // Re-rolled every hop, so the rhythm never becomes a pattern
            // either — a fixed period reads as a loop however random the hue.
            theme._driftMs = 11000 + Math.random() * 13000;
            var lo = theme.paintSpan / 2;
            var hi = 1.0 - theme.paintSpan / 2;
            var next = theme.paintCenter;
            // Two constraints, and the second one cost a live regression.
            //
            // "Never the same": reject a target close enough to where we
            // already are that the hop would not read as a colour change.
            //
            // "Never invisible": reject a target whose window has no light in
            // it. swirl_splat.frag's ramp is NOT uniform in lightness — its
            // own stop table says so in words: teal BRIGHT, azure dark,
            // indigo dark, violet dark, plum mid, rose bright, pale BRIGHT.
            // The first cut of this drift walked the window anywhere in
            // [0.15, 0.85], so sooner or later it parked across
            // azure→indigo→violet, every stop of which is dark, and the paint
            // went out. The owner, watching it happen: "swirls aren't working
            // in the start menu now." They were working perfectly; they were
            // being drawn in near-black. Bar.qml's own ramp note had already
            // written this down — "slicing the OLD five-stop ramp here would
            // have left nothing but darks" — and I walked into it anyway.
            //
            // Bounded tries rather than a bare do/while: a random walk that
            // cannot satisfy its own constraints must not spin the UI thread.
            for (var i = 0; i < 24; i++) {
                var c = lo + Math.random() * (hi - lo);
                if (Math.abs(c - theme.paintCenter) < 0.18)
                    continue;
                if (theme._windowLight(c) < theme.paintLightFloor)
                    continue;
                next = c;
                break;
            }
            // Hand the hop to the stepper rather than assigning through a
            // Behavior (TRK-2501). Endpoints and duration are unchanged; only
            // the sampling rate is.
            theme._driftFrom  = theme.paintCenter;
            theme._driftTo    = next;
            theme._driftStart = Date.now();
        }
    }

    // Each surface reads the drift through its own offset, so the Start Menu
    // and the Flyout are never showing the same colour as each other even
    // though both are always moving. Wrapped inside the legal range rather
    // than clamped: clamping would squash the window against the ends of the
    // ramp and park two surfaces on the same colour there.
    function driftCenter(off) {
        var lo = paintSpan / 2;
        var hi = 1.0 - paintSpan / 2;
        var span = hi - lo;
        var t = (paintCenter + off - lo) % span;
        if (t < 0)
            t += span;
        return lo + t;
    }
    function driftLo(off) { return driftCenter(off) - paintSpan / 2; }
    function driftHi(off) { return driftCenter(off) + paintSpan / 2; }

    // ══ THE COLOR LAYERS (WIP-619) · one identity, many colours ═════════
    // The owner ruled 2026-08-14: the bar keeps ONE identity — the liquid
    // swirls — and the variety ships as selectable LAYERS of the seven-stop
    // ramp. Every layer keeps the ramp's proven LIGHTNESS LADDER
    // (BRIGHT / dark / dark / dark / mid / bright / BRIGHT — "swirls come
    // from alternating lightness, not more hues", swirl_splat.frag's own
    // law) and re-hues the stops inside the build's family:
    //   rose    — the signature: teal→indigo→plum→rose (unchanged defaults)
    //   magma   — his "hot colors" ember sweep from the bar-scene sessions
    //   glacier — the blizzard FEELING as a layer: ice over dark steel
    //             (bright stops lean on the teal core token #d8fffb family)
    //   violet  — violet_glow + the plum tokens' orchid family
    //             (mid stop is the plum mid token #a63fa1; bright is its
    //             core #ed9bf7)
    // Selection is a Settings key (Prefs.swirlLayer); unknown values fall
    // back to glacier so a hand-edited settings.json cannot blank the paint.
    //
    // ⚠ SOURCE OF TRUTH MOVED, 2026-08-17 (WIP-744).
    //   `theme/accent.json` → `_paint_layers` now OWNS these stops. This block
    //   is a MIRROR of it, not the definition, and gate `13q42` fails the bake
    //   if the two disagree.
    //
    //   Why the values still sit here as literals: QML needs them at load and
    //   there is no generator yet. Task 0's `build-theme.sh` will emit this
    //   block from `accent.json`; until then the gate does by assertion what
    //   the generator will do by construction.
    //
    //   Why the move mattered at all: `13q11` validates every colour in the
    //   shipped tree against `accent.json` and CANNOT SEE `shell/`. So while
    //   these 28 stops lived only here, the palette document asserted
    //   authority over a palette it did not contain — and rose[6] `#ffb3d9`,
    //   the owner's own colour, scanned as unnamed residue.
    //
    //   ⛔ Editing a stop here recolours the paint. The owner's standing rule
    //   is that the swirls are never touched. Change `accent.json` if a stop
    //   ever legitimately moves, and expect the gate to make you do both.
    readonly property var paintLayers: {
        var ice = theme.iceLayer;
        // MAGMA house: magma in one corner, black in the other, they bleed.
        // Same BRIGHT/dark/dark/dark/mid/bright/BRIGHT ladder as glacier.
        //
        // ── TRK-4138 · why stop 6 is not #ffb080 any more ────────────────
        // Owner, 2026-09-14: "The swirls do you think thats the correcte
        // pallete for the swirls on this theme".
        //
        // Measured before answering, the same way the dock icons were:
        // sampled the brightest 8% of the Start menu's swirl core and got
        // RGB 135/100/64 — G/R 0.74, B/R 0.48. That is not the ember stop
        // (G/R 0.47) and it is not the gold stop (B/R 0.24). It is stop 6,
        // #ffb080, almost exactly (G/R 0.69, B/R 0.50), carried down to a
        // third of its brightness by the fluid.
        //
        // And that is the whole problem: #ffb080 is a PALE PEACH, and pale
        // peach dimmed is tan. The blue is what does it — at B/R 0.50 the
        // shadows lift toward grey, so the densest part of the paint, the
        // part the eye actually reads, came out dusty khaki on a theme
        // whose entire idea is molten rock.
        //
        // #ffa85e keeps stop 6 the brightest stop in the ladder (185 vs
        // gold's 179 and ember's 155, so BRIGHT/…/mid/bright/BRIGHT still
        // holds by construction) while dropping B/R to 0.37 and G/R to
        // 0.66. It cannot be made more orange AND stay as bright — red is
        // already at 255 — so the ~9 points of luminance are the price,
        // and the ladder is what says how much of that is affordable.
        var mag = ["#f7a83b", "#0a0404", "#050203", "#1a0806", "#58100f", "#ff7847", "#ffa85e"];
        return {
            "rose":    ["#0aa2d6", "#064f95", "#1e03ad", "#521e72", "#891955", "#d765a2", "#ffb3d9"],
            "magma":   mag,
            "glacier": theme.lookMagma ? mag : ice,
            "violet":  ["#b06cff", "#2a1157", "#3b0f6e", "#55127a", "#a63fa1", "#ed9bf7", "#f3d1ff"]
        };
    }

    // ── THE ANALYSER'S COLOUR — TRK-3717 ────────────────────────────────
    // ⚠ THIS BLOCK HELD A FULL 13-STOP RAINBOW AND THE OWNER WITHDREW IT.
    // He asked for it, saw it built at 384 columns, and moved off it
    // (2026-09-02):
    //
    //   "the one that worked can you make it that pal color and do the tips
    //    magna"
    //
    // The rainbow is NOT kept behind a setting. It was one instruction, it
    // was answered, and it was replaced by another — a switch would be this
    // file carrying a ruling that is no longer the ruling, which is the
    // shape that turns a token into a lock (AGENTS.md, `13vd`).
    //
    // ══ WHAT THIS IS, AND WHY IT IS THE BUILD'S OWN THESIS ══════════════
    // The rainbow was the exception. This is the rule: **glacier for what
    // things ARE, magma for what MATTERS**. On a spectrum the column is what
    // the music IS and the TIP is what matters — the reach of the hit — so
    // the thesis maps onto this surface with no interpretation needed.
    //
    // ⚠ AND IT IS A HUE AND TEMPERATURE CONTRAST, NOT A LUMINANCE ONE.
    // Said explicitly because the rainbow's first draft solved every hue for
    // the SAME luminance, measured 4.00–4.04:1 straight across, and looked
    // like mud. Do not equalise these: `#ff7847` is L 0.3515 against a body
    // at L 0.7307–0.9502, and that gap is the point. Ice reads cold and
    // recessive, the tip reads hot and forward, and neither is doing the
    // other's job.
    //
    // ══ THE BODY · PALE GLACIER ═════════════════════════════════════════
    // The light end of the ramp, and the same pale the showcase page and the
    // lock card use: `glacier[5]` → `glacier[6]`, interpolated across the
    // frequency axis so the field has depth without having a hue. The
    // deeper pale sits at the KICK and the near-white at the AIR — the low
    // columns are the tall ones, so this is also what gives the magma tip
    // its strongest ground.
    //
    // Measured on the bar's real bed (`shelfDeep` α0.34 over the darkest
    // 32×8 tile of the 38 shipped wallpapers, rgb(1,3,3), L 0.000782):
    //
    //   #b7e6f2  glacier[5]  L 0.7307  15.37:1   the kick
    //   #eefcff  glacier[6]  L 0.9502  19.70:1   the air
    //
    // ══ THE TIP · MAGMA ═════════════════════════════════════════════════
    // `magma[5]`, the hot rung. 7.91:1 on the same bed — but the bed is NOT
    // the composite that matters for this one, because a tip sits ON the
    // column rather than on the wallpaper. Against its own ground it is a
    // 1.94:1 luminance step at the kick and 2.53:1 at the air, which is
    // deliberately LOW: a tip that out-contrasted its body on luminance as
    // well as hue would read as a separate object floating over the field
    // instead of as the end of the column. The temperature does the work.
    //
    // ⚠ AND THE ACCENT RULE IS CHECKED, NOT ASSUMED. "The accent appears in
    // at most two places on a surface" is what this build runs on, and 384
    // tips is a lot of places. What stops it reading as a band is that a tip
    // is 2 px of a column whose mean drawn height is ~44 px: measured share
    // of lit area is in measure-spectrum-colour.py and reported in the
    // ledger. If that number ever climbs, the tip height is the lever.
    readonly property var spectrumBody: lookMagma ? [
        "#58100f",  // magma dark — the kick
        "#eefcff"   // ice peak — the air
    ] : [
        "#b7e6f2",  // glacier[5] ice PALE  — the kick
        "#eefcff"   // glacier[6] ice PEAK  — the air
    ]
    // ICE: magma tip on glacier body. MAGMA: ice tip on gold body, so the
    // analyser does not melt into the ember bar.
    readonly property color spectrumTip: lookMagma ? "#7fe8ff" : "#ff7847"

    // ── THE FREQUENCY RAMP — TRK-3778 ───────────────────────────────────
    // ⚠ THIS SUPERSEDES THE BODY GRADIENT ABOVE FOR THE FIELD'S HUE, and it
    // is the SECOND time the rainbow has come and gone, so the reasoning is
    // written out rather than assumed.
    //
    // Owner, 2026-09-06, with five reference images: a 31-band 3-D EQ, a
    // segmented LED meter, a perspective dot matrix, a thin-line field with
    // a floor reflection, and a mirrored waveform. EVERY ONE OF THEM ramps
    // its colour across the frequency axis. ⚠ He then said plainly how to
    // read them — *"i was sending those to try and give you a visual of what
    // i was thinking ... just to go off"* — so they are DIRECTION, not
    // specification, and the rainbow in them is direction too. What is
    // adopted is the QUALITY: a rich multi-coloured spread across the
    // frequency axis, in HIS palette, not a literal red-to-violet rainbow. The standing 2026-09-02 ruling
    // ("that pal color and do the tips magna") is NOT deleted and NOT
    // hidden behind a setting — it is SUPERSEDED at the body and KEPT at
    // the tip: the peak markers are still `spectrumTip`, magma, and the
    // pale glacier he approved is still what the top of this ramp is made
    // of (`teal_glow` → `glacier[0]`). What changed is that the other 70%
    // of the field now carries frequency instead of carrying nothing.
    //
    // ══ THE MEASUREMENT THAT DECIDES THE STOPS ══════════════════════════
    // The palette walks a near-continuous hue sweep and it is tempting to
    // ramp straight across it. IT IS NOT CONTINUOUS. Measured over every
    // saturated mid-lightness colour in `theme/accent.json`:
    //
    //   H 33 gold_glow · 16 magma[5] · 349 red_soft · 328 plum_glow ·
    //   293 plum core  · 277 violet_glow · 268 violet[0]
    //        ── 59° HOLE ──
    //   H 209 azure_glow · 195 teal_glow · 191 glacier[0]
    //
    // The only colours this build owns inside that hole are H 226 text_muted,
    // 227 rim_light, 233 bright.blue and 250 indigo_glow — and that interval
    // IS PERIWINKLE, which carries the owner's standing rejection ("yes no
    // purple", TRK-1750). So a full 200° sweep cannot be built from his
    // palette without shipping periwinkle. The sweep is therefore TWO ARCS
    // — 33°→268° warm-to-violet and 209°→191° azure-to-ice, 143° of hue in
    // total — joined by a HARD STEP with no blended stop between them.
    //
    // ⚠ THE HARD STEP IS THE WHOLE POINT AND IT IS MEASURED, NOT ASSERTED.
    // Interpolating azure→violet would put a column at H≈238 — periwinkle —
    // on the screen. With the step width at 0.0002 of the axis, NO column
    // centre can land inside it. And a hard colour boundary is not a defect
    // on this form: a segmented meter is the one instrument that has always
    // had them (the green/amber/red zones of every VU meter ever built), so
    // the step reads as a zone edge rather than as an artefact. Measured: checked at 128, 240, 300 and 384 columns,
    // periwinkle-band (H 222–262) column count is 0 in every case. The
    // checker is `scripts/measure-spectrum-ramp.py` and audit item 31 runs
    // it. If a future stop widens that step, the gate goes red.
    //
    // Every adjacent pair is also inside rule 8's 40° mixing limit
    // (DESIGN_DEPTH_2026-09-06 § 8) — max 34.4°, gold→magma 17.1°,
    // plum→plum-core 34.4° — so every blended column is a legal mix of two
    // neighbours rather than mud. No colour here is invented: all ten stops
    // are existing `accent.json` entries.
    //
    // LOW frequency is WARM and HIGH frequency is COLD, which is the
    // direction all five references use (17 and 20 most plainly), and it
    // puts the pale glacier he approved on the air where it always was.
    // ⚠ REBUILT ON THE GLACIER LADDER, 2026-09-07. The owner put the bar and a
    // widget side by side and said "they dont look anything alike", then chose
    // "match exactly". This ramp was the loudest half of that: a full rainbow
    // — gold, magma, red, plum, violet, azure, teal — painted across a strip
    // that sits directly under a column of near-black glacier widgets.
    //
    // It also carried #aa6ece and #b06cff, the VIOLET family, which is a
    // rejected colour everywhere else in this build (TRK-1750). The analyser
    // was the last place it survived.
    //
    // One family now, dark at the sub-bass and bright at the air, so the
    // spectrum reads as the same material as everything above it. The struck
    // beat is still `spectrumTip` = magma[5]: magma stays for what MATTERS,
    // which is exactly the one thing on this strip that does.
    //
    // ⚠ ONE REVERT AWAY. The old ten stops are quoted above in the history of
    // this file; nothing else reads this token (only BarSpectrum.qml), so
    // putting the sweep back is a single edit here.
    // ⚠ BRIGHTENED, 2026-09-07. Owner: "we need brighter colors on the
    // visulizer now so youy can see it better" — and he is right, this is a
    // consequence of two changes made minutes earlier. The first pass put the
    // ramp on the glacier ladder starting at glacier[2] #0c1f66, and the bar
    // then became genuinely see-through, so the bass end was dark paint on a
    // dark sky and simply vanished.
    //
    // Still one family — this stays glacier from end to end, so it reads as
    // the same material as the widgets above it. What changed is that the
    // floor of the ramp is lifted off the ground: the quietest column is now
    // a visible seam colour rather than near-void.
    readonly property var spectrumRamp: lookMagma ? [
        "#1a0806",  // sub-bass — magma dark
        "#58100f",  // magma[4]
        "#7a1e0c",
        "#a33214",
        "#ff7847",  // magma[5]
        "#f7a83b",  // gold
        "#ffb080",  // magma[6], last warm stop before the hard step
        "#7fe8ff",  // glacier[0] — pale glacier on the air
        "#b7e6f2",  // glacier[5]
        "#eefcff"   // glacier[6] catch-light
    ] : [
        "#3a6b95",  // the sub-bass — lifted clear of the ground
        "#4f7fa6",  // glacier[4]   accent-hairline · the seam
        "#5f9ec4",
        "#5cc6ea",  // teal_glow    brilliance
        "#6fd4f2",
        "#7fe8ff",  // glacier[0]   accent-interactive
        "#9aeeff",
        "#b7e6f2",  // glacier[5]   accent-primary
        "#d5f6ff",
        "#eefcff"   // glacier[6]   accent-peak, the catch-light · the air
    ]
    // Positions on the frequency axis, 0 = lowest band, 1 = highest. The
    // 0.7300 → 0.7302 pair IS the step; do not widen it (see above).
    readonly property var spectrumRampU: [
        0.0000, 0.1400, 0.2900, 0.4400, 0.5700,
        0.6900, 0.7300, 0.7302, 0.8700, 1.0000
    ]

    // ── THE LED CELL — TRK-3778, reference 18 ───────────────────────────
    // The segmented meter is the one reference form that survives an 84 px
    // bar (the 31-band plinth needs a label row, the dot matrix needs a
    // perspective floor, and both spend height this surface does not have).
    // Pitch and ink are PIXELS, not fractions, so the cell keeps its size
    // if `chromeH` ever moves: 6 px of pitch with 4.2 px lit leaves a 1.8 px
    // dark seam, which is the reference's own ~2:1 ink:gap at this scale,
    // and gives 7 cells above the spine and 6 below at chromeH 84.
    readonly property real spectrumCellPx: 6.0
    readonly property real spectrumCellInk: 0.70   // of the pitch
    // The lower half is a REFLECTION, not a second meter: dimmer, and it
    // fades with distance from the seam (references 18, 19 and 20 all do
    // this; 21 does not, and 21 is the one that reads as a graph).
    readonly property real spectrumReflect: 0.42

    // ── HOW MUCH OF THE COLUMN THE TIP OWNS — TRK-3717, round 2 ────────
    // ⚠ THIS WAS A FLAT 2 px AND THE OWNER OVERRULED IT LIVE, watching real
    // audio on his own machine (2026-09-02):
    //
    //   "add more orang at the tip and each pilliar different lengths or the
    //    orange or magma i mena"
    //
    // Two things, and the second is the one that matters: MORE magma, and a
    // DIFFERENT amount of it per column. A constant cap draws a uniform
    // stripe across the top of the field, which reads as printed rather than
    // as played.
    //
    // ⚠ AND IT OVERRULES THE ACCENT RULE FOR THIS COMPONENT. "At most two
    // places on a surface" is what this build runs on; he has seen the 4.54%
    // this produced at 2 px and asked for more. The share is still MEASURED
    // and reported (measure-spectrum-colour.py) — it is no longer a ceiling.
    //
    // The tip is a FRACTION OF THE COLUMN'S OWN HEIGHT, so a loud column
    // gets a long hot cap and a quiet one barely any. That is the variation
    // he asked for AND it encodes something true about the audio, which a
    // random length would not. A small deterministic per-column jitter sits
    // on top so no two neighbours land identical; it is computed ONCE when
    // the column count changes, never per frame.
    readonly property real spectrumTipFrac: 0.34   // of the column's height
    readonly property real spectrumTipJitter: 0.40 // ±, deterministic per column
    readonly property int spectrumTipMinH: 2       // a floor-height column still caps

    // The body of a column. ⚠ NOT a gradient. The first attempt gave every
    // bar a three-stop vertical glaze, which was the right call at a 20.4 px
    // bar and is invisible at 3 px — and a Gradient is a texture per
    // delegate, which is the single most expensive thing you can give 384 of
    // them. Flat fill, one magma cap. See BarSpectrum.qml § THE MATERIAL.
    readonly property real spectrumBaseAlpha: 1.0

    // ── THE CONTROL FAMILY'S SWIRL RAMP — ONE TOKEN, EVERY HOST ─────────
    // `SwirlChip` runs inside TogglePill, SetSwitch, SetChoice, SetButton and
    // SetIceFace. Every one of them binds THIS, and none of them names a ramp
    // of its own.
    //
    // ⚠ THE INDIRECTION IS THE POINT, and it is not ceremony. The drift this
    // project has already paid for is "the bar is rose and the flyout is
    // glacier" — five surfaces that each picked their own paint because each
    // binding named a layer directly. With one token, a control cannot drift
    // from its siblings by editing one file, and re-pointing the whole family
    // is one line rather than five.
    //
    // It also makes the palette decision REVERSIBLE AS A UNIT, which matters
    // while the galaxy-tp ruling is fresh: the swirl MECHANICS and the swirl
    // COLOUR are separate commits precisely so the colour can be backed out
    // without taking the paint out of the controls with it.
    // TRK-3380: repointed at `paintRamp`. It used to name `paintLayers.glacier`
    // directly, which was the exact drift this token was created to prevent —
    // a control binding it would have worn ice while the Line wore plum. No
    // host binds it today (SwirlChip defaults to PaintMood.ramp, TRK-2999), so
    // this is a live token with no live reader; it is kept, and made correct,
    // rather than deleted, because deleting it invites the next control author
    // to name a layer directly and reintroduce "the bar is rose and the flyout
    // is glacier" for the third time.
    readonly property var controlSwirlRamp: theme.paintRamp
    // ── TRK-960 · one ice hue + one purple hue (owner 11:24) ────────────
    // Chrome stays paintLayers.glacier [0]/[5] (`#7fe8ff` / `#b7e6f2`).
    // paintLayers itself is unmoved (13q42 / unread-DND / destroy).
    //
    // What they SEE on tty1 (sky_mode=headliner): Starlight /
    // headliner-still.png — 0% purple, 0% ice, 0% teal (mean Rec.709 0.0003).
    // Session wallpaper file (swaybg / preview wallpaper.json):
    // suxyn-glacier-altitude.png — ice H≈211, **0% purple**, 0% teal.
    // Ice-orchid-horizon is NOT the live wall and is NOT in preview
    // favorites. 11:18 mixed that PNG's orchid into glacier navy, so the
    // filament walked H 214→248→260→268 (stages of different purples).
    //
    // Purple that IS in this session's picker: suxyn-violet-twilight.png
    // (preview favorites, 63.1% purple, cluster H=260.4±8.5). Orchid-horizon
    // cluster mean is H=261.0 — same family, not on screen. Locked H=261
    // (±1° on the 8-bit snaps). Lightness stages only; navy #0c1930 /
    // #213754 no longer sit between purple stops. Teal not added.
    // Ice [0]/[6] kept (owner liked glacier brightness). [1] is glacier
    // ice (brightest-10% of the live wall's ice family), not a purple.
    //
    // Palette violet (H 294 magenta-pink) — retired:
    //   #7fe8ff #123a5e #2a1157 #55127a #a63fa1 #ed9bf7 #eefcff
    // 11:18 (navy mixed with orchid; H 214/248/260/268):
    //   #7fe8ff #0c1930 #213754 #0e0b21 #1d1233 #644982 #eefcff
    // 11:26 (ice + purple H=261 stages):
    //   #7fe8ff #14243c #160d26 #311e53 #624599 #6f50a8 #eefcff
    // Pale glacier for the bar / power seam. glacier[5] and [6] are the
    // bright anchors (the pale ice the owner named). glacier[0] teal is
    // not in this ramp — it stays hover light, never dye.
    readonly property var paintPaleGlacier: [
        paintLayers.glacier[5],  // #b7e6f2 pale BRIGHT
        paintLayers.glacier[1],  // dark
        paintLayers.glacier[2],  // dark
        paintLayers.glacier[3],  // dark
        paintLayers.glacier[4],  // mid steel seam
        paintLayers.glacier[5],  // pale filament
        paintLayers.glacier[6]   // #eefcff peak
    ]

    readonly property var paintGlacierHorizon: [
        paintLayers.glacier[0],  // #7fe8ff ice BRIGHT — TRK-914 floor, H 191
        "#14243c",               // glacier-altitude ice brightest-10% (H 216, lin 0.017)
        "#160d26",               // purple BODY, H 262, lin 0.006 (violet-twilight / orchid mean H 261)
        "#311e53",               // purple MID,  H 262, lin 0.022
        "#624599",               // purple HI,   H 261, lin 0.092
        "#6f50a8",               // purple HI+,  H 261, lin 0.119 (same hue, brighter filament)
        paintLayers.glacier[6]   // #eefcff ice peak, H 191
    ]
    // ── TRK-3380 · GLACIER + PLUM, the owner's ruling 2026-08-28 ────────
    // He pointed at the colour on his widget corners and asked for the bar to
    // wear it. It was already in this file: `plumBody` #891955 IS
    // `glassBorder`, the token that draws that corner. Nothing was invented —
    // this ramp is SEVEN SHIPPED TOKENS and not one new hex.
    //
    // WHY THE H 261 RAMP ABOVE COULD NEVER GET THERE, measured 2026-08-28
    // against six references he supplied (a plum swatch, a colour photo, a
    // fabric panel, matte nails, a carnation, plum silk):
    //   his references   H 306 – 337, clustering 312 – 328
    //   paintGlacierHorizon's purple stops   H 261 – 262, flat
    // A 61° miss at the far end. 261 is blue-violet — periwinkle — and no
    // exposure, bloom or opacity change moves a hue, which is why several
    // passes at "make the swirls plum" all came back reading blue or pink.
    //
    // ICE STAYS, and it works here in a way it did not before. At H 261 the
    // purple sat only 70° off glacier's H 191: too close to read as two
    // colours, so the field integrated toward one blue smear — the same
    // mechanism swirl_splat.frag documents for lightness, arriving through
    // hue. Plum at H 328 is 137° from ice: a genuine complement. Ice is the
    // highlight, plum is the body, and they separate instead of muddying.
    // It also matches this build's own division of labour — accent.json's
    // `_generated._authority` records the owner's 2026-08-19 ruling that
    // chrome is glacier, and plum is what the accent tokens already are
    // (`tokenAccentPinned`, `accentSolidHalo`).
    //
    // ⚠ ICE TAKES ONE BRIGHT ANCHOR, NOT BOTH, and that is the whole
    // correction. `paintGlacierHorizon` puts ice at [0] AND [6] — the two
    // top rungs of the ladder — so the brightest thing in the field was
    // always ice, and the brightest thing is what the eye names the whole
    // surface. That is why the bar read as ice-on-dark whatever the middle
    // stops did. Here [6] is `plumGlow`, so both colours own a bright rung.
    //
    // CANONICALITY, and this is strictly an improvement: every stop below is
    // a hex `theme/accent.json` already contains, so 13q11 sees no new
    // colour. The ramp it replaces carries FIVE Theme-only literals
    // (#14243c #160d26 #311e53 #624599 #6f50a8) that appear nowhere in the
    // palette document — the palette has been asserting authority over a
    // ramp it does not contain since 08-21.
    //
    // The ladder law holds — BRIGHT / dark / dark / dark / mid / bright /
    // BRIGHT — in LINEAR luminance:
    //   0.694 · 0.040 · 0.008 · 0.033 · 0.067 · 0.111 · 0.264
    //
    // `paintGlacierHorizon` is left defined directly above, untouched, so
    // this is one line to revert.
    // ── TRK-3397 · THE PURPLE JOINS THE PLUM · owner 2026-08-28 ─────────
    // He sent a purple-hair reference with "need to be what we got but with
    // this colour as well", plus a plum satin dress. Measured:
    //     satin dress   H 325  S 57%  L 14%   → already the plum family
    //     purple hair   H 293  S 35%  L 19%   → NOT in the plum family
    //
    // H 293 sits between this build's `violet` tokens (H 277) and its `plum`
    // tokens (H 328), and the honest reading of "as well" is that he wants
    // both present rather than a third hue splitting the difference. A ramp
    // is the one place where that is free: the fluid ADVECTS the stops into
    // each other, so violet folded through plum produces the intermediate
    // purples continuously — including his 293 — without any stop having to
    // BE 293. Picking a single midpoint hex would have given one flat purple
    // and lost both parents.
    //
    // So the two families INTERLEAVE through the dark rungs: violet, plum,
    // violet, then plum carries the mid and bright. That ordering is
    // deliberate — adjacent stops are what the sweep blends between, so
    // alternating them puts a violet↔plum transition at every segment
    // boundary rather than one seam in the middle.
    //
    // Still not one invented hex: `violetDeep` and `violet` are shipped
    // tokens, same as the plum family and the glacier anchor.
    //
    // Ladder in linear luminance — BRIGHT / dark / dark / dark / mid /
    // bright / BRIGHT still holds, and rungs 3→6 stay monotonic:
    //   0.694 · 0.010 · 0.008 · 0.039 · 0.067 · 0.111 · 0.264
    //
    // `glacier[1]` came out to make room. It was the second ice stop, and
    // with ice already holding [0] the field did not need a second cold rung
    // competing with the purples for the dark end.
    readonly property var paintPlumHorizon: [
        paintLayers.glacier[0],  // #7fe8ff ice BRIGHT  — H 191, lin 0.694
        violetDeep,              // #280c3a violet dark — H 277, lin 0.010
        plumHaze,                // #2e051b plum BODY   — H 328, lin 0.008
        violet,                  // #521e72 violet dark — H 277, lin 0.039
        plumBody,                // #891955 plum MID    — H 328, lin 0.067 · = glassBorder
        plum,                    // #ae206c plum brt    — H 328, lin 0.111 · = tokenAccentPinned
        plumGlow                 // #d765a2 plum BRIGHT — H 328, lin 0.264 · = accentSolidHalo
    ]
    // Magma analogue of paintPlumHorizon. Same 7-stop ladder: BRIGHT /
    // dark / dark / dark / mid / bright / BRIGHT. Warm end is magma[4]
    // #a33214 (lookWidgetBorder) then magma[5] #ff7847. No plum.
    readonly property var paintMagmaHorizon: [
        "#f7a83b",
        "#0a0404",
        "#050203",
        "#1a0806",
        "#58100f",
        "#ff7847",
        "#ffb080"
    ]
    // ── TWO VIOLET STOPS, AND THE TARGET IS MEASURED OFF THE BAR ────────
    // ⚠ THIS WAS CUT TO ONE VIOLET STOP AND PUT BACK. The reason is worth
    // recording, because the mistake was a judgement made without a number.
    //
    // The two-violet ramp rendered a field measuring H 293 with the hue
    // split 71% violet to 29% plum. That was read as "the purple has taken
    // over the surface it was meant to visit" and cut back to one stop — on
    // taste, against no target.
    //
    // Then the owner said the colour he wants is the one already in the
    // BOTTOM BAR'S CORNERS, visible where the paint fades out. Measured off
    // his live screen, 2026-08-28:
    //
    //     far left corner    H 287  S 35%  L 6%   ~#130a15
    //     far right corner   H 302  S 45%  L 7%   ~#190a19
    //     left 140 px        H 305  S 43%  L 5%
    //     → the chrome's own purple, H ~293, S ~40%, L ~6%
    //
    // Which is the same colour measured hours earlier off his widget
    // corners (H 290 S 37% L 7%) and the same as the purple-hair reference
    // (H 293). Three independent sources, one answer — and the ramp that
    // hit it was the two-violet one that got cut for looking wrong.
    //
    // So it is back, and the earlier reasoning is left below as the record
    // of why it was removed, because that reasoning is not wrong about the
    // MECHANISM — it is wrong about the target:
    //
    //   "Both violet stops (L 14% and L 28%) are LIGHTER than plumHaze
    //    (L 10%), so they carry more of the field's light, and light is
    //    what the eye counts. Two of them also put a violet on both sides
    //    of the plum body, so every blend runs through violet on the way in
    //    and on the way out."
    //
    // All true. It is exactly how the ramp reaches H 293 instead of H 321,
    // and H 293 is the colour his own chrome draws. The lesson is the one
    // this whole lane keeps re-learning: measure the thing being matched
    // before deciding the render is wrong.
    //
    // Owner 2026-09-10: "the swirls need to be pale glacier". PAINT dye
    // only — shadow modes still read Prefs.swirlMode. glacier[0] #7fe8ff
    // stays banned as dye; paintPaleGlacier already omits it.
    //
    // swirl_preview is a LOOK, not a shipped layer. paintLayers stays four
    // (13q37). Furniture (glass, glacier[0] caustic) does not follow this.
    function paleFromLayer(name) {
        var L = paintLayers[name];
        if (!L || L.length < 7)
            return paintPaleGlacier;
        return [L[5], L[1], L[2], L[3], L[4], L[5], L[6]];
    }
    readonly property var paintPaleWine: [
        "#e8b8c8",
        "#2a0a18",
        "#3a0c22",
        "#5c1838",
        "#8a3060",
        "#e8b8c8",
        "#fceef4"
    ]
    // lookMagma is declared at the top of this file. glacier IS the magma
    // 7-stop when MAGMA is on, so lookLayer is always paintLayers.glacier.
    readonly property var lookLayer: paintLayers.glacier
    // MAGMA hairline is pale glacier (#b7e6f2), not magma[4]. Fills stay ember.
    readonly property color lookSeam: lookMagma ? iceLayer[5] : lookLayer[4]
    // ICE stays 1 px. MAGMA needs 2 or the glacier line vanishes into ember.
    readonly property int lookOutlineW: lookMagma ? 2 : 1
    readonly property color lookPale: lookLayer[5]
    readonly property color lookPeak: lookLayer[6]
    readonly property color lookHot:  lookLayer[0]
    readonly property color lookDark: lookLayer[1]
    readonly property color lookWidgetBorder: lookMagma ? iceLayer[5] : plumBody
    readonly property color lookIce: lookHot
    readonly property var lookSweep: [sweep0, sweep1, sweep2, sweep3, sweep4]
    readonly property var lookRimSweep: lookMagma ? paintMagmaHorizon : paintPlumHorizon
    function lookStop(i) {
        var s = lookSweep[i];
        var c = (s && s.r !== undefined) ? s : Qt.color(s);
        return Qt.vector4d(c.r, c.g, c.b, 1.0);
    }
    readonly property var paintRamp: {
        if (lookMagma)
            return theme.lookLayer;
        var k = Prefs.swirlPreview;
        if (k === "wine")
            return theme.paintPaleWine;
        if (k === "rose" || k === "magma" || k === "violet")
            return theme.paleFromLayer(k);
        return theme.paintPaleGlacier;
    }

    // ══ THE EMBER ANCHOR (WIP-700) · what "warmer" means, once ══════════
    // The owner asked for a paint that runs "warmer under cpu load cooler
    // when idle". `PaintMood.qml` leans the selected layer toward THIS ramp
    // by up to 30% as the machine's load average climbs; at rest the layer
    // is untouched, so idle is simply the layer as shipped.
    //
    // It is NOT a fifth selectable layer and must never appear in
    // `paintLayers` — nothing offers it to the user and gate 13q37 checks
    // that the layer count stays four.
    //
    // Every hex here is already in this build: it is `BorderPulse.qml`'s
    // `heavyStops` — the owner-approved "this machine is working hard"
    // colour that his window borders and pane edges have worn since
    // 2026-08-09 — re-laid on the seven-stop LIGHTNESS LADDER this ramp's
    // law demands (BRIGHT / dark / dark / dark / mid / bright / BRIGHT).
    // Reusing the border's family rather than inventing a hot palette is
    // the point: under load the borders, the pane edges and the paint all
    // move toward the same colour, so the machine reads as one system
    // saying one thing.
    //
    // ⚠ Its shape is load-bearing. The blend is stop-for-stop, so this must
    // stay seven entries and must keep the ladder — a bright stop opposite
    // a dark one would drag the layer's contrast out from under it, which
    // is the "swirls come from alternating lightness" failure
    // swirl_splat.frag documents at length.
    readonly property var paintEmber: [
        "#ff9e6b",   // BRIGHT — heavy's lit coral
        "#5c2a0f",   // dark
        "#3d1608",   // dark
        "#2e0f08",   // dark — heavy's deepest stop
        "#894216",   // mid
        "#e6923f",   // bright — heavy's amber
        "#ffcf9e"    // BRIGHT — heavy's cream highlight
    ]

    // ══ THE SWIRL QUALITY LADDER (WIP-768) ══════════════════════════════
    // Degrade the material, never disable it: every rung still runs the
    // ported solver, the seven-stop ramp and the display pass, so every
    // rung reads as the SAME material.
    //
    // ⚠ SOURCE OF TRUTH is `theme/accent.json` → `_swirl_tiers`. This block
    //   is a MIRROR, exactly as `paintLayers` above is a mirror of
    //   `_paint_layers`, and for the same reason: QML needs the values at
    //   load and there is no generator yet. Gate `13q44` fails the bake if
    //   the two disagree — it does by assertion what task 0's
    //   `build-theme.sh` will later do by construction.
    //
    // Two things are deliberately NOT knobs here, and accent.json records
    // the measurements that ruled them out:
    //   · vorticity confinement and pressure_iterations — dropping them
    //     measured 1.10× cheaper and cost the ramp travel, i.e. the
    //     lightness ladder, i.e. the identity
    //   · a rim sample mask — measured 1.64× where the area said 10×,
    //     because a masked full quad still writes every interior pixel
    //
    // `full` is today's shipped behaviour exactly (60 Hz, dye 224/2304), so
    // installing the ladder changes no surface until something selects
    // another rung.
    readonly property var swirlTiers: ({
        "full":   ({ "step_hz": 60, "dye_short": 224, "dye_cap": 2304, "freeze": false }),
        "high":   ({ "step_hz": 30, "dye_short": 224, "dye_cap": 2304, "freeze": false }),
        "medium": ({ "step_hz": 30, "dye_short": 160, "dye_cap": 1536, "freeze": false }),
        "low":    ({ "step_hz": 15, "dye_short": 112, "dye_cap": 1024, "freeze": false }),
        "floor":  ({ "step_hz": 15, "dye_short": 112, "dye_cap": 1024, "freeze": true })
    })
    readonly property var swirlTierOrder: ["full", "high", "medium", "low", "floor"]
    readonly property string swirlTierDefault: "full"
    // On battery the ladder steps DOWN one rung — the same direction
    // Swirl.qml's `_saving` already moves `alwaysAlive`, not a second
    // policy — which lands on `high` at 30 Hz, COMPLETION_SPEC §3.3's
    // "30 on Saver profile" number exactly.
    readonly property int swirlTierBatteryStepDown: 1

    // ══ THE SURFACE-DENSITY LADDER (requirement 5, 2026-08-24) ══════════
    // How VISIBLE the paint is, graded by what sits on top of it.
    //
    // ⚠ THIS IS NOT `swirlTiers`, AND IT MUST NEVER BE FOLDED INTO IT.
    //   `swirlTiers` above is a COST ladder — step rate, dye resolution,
    //   freeze — and `theme/accent.json`'s `_swirl_tiers._levers_that_work`
    //   is explicit that it is built NOT to cost visibility: "a
    //   half-resolution dye field still renders the full ramp travel, the
    //   near-black ground and the filament silhouettes." A machine that is
    //   short of GPU and a panel that is dense with type are two different
    //   problems and they want two different knobs. Repurposing the cost
    //   ladder for visibility would make a slow laptop's Start menu dimmer,
    //   which is not a thing anybody asked for.
    //
    // ⚠ NOT A MIRROR. Unlike `paintLayers`, `swirlTiers` and `glassField`,
    //   this block has NO counterpart in `theme/accent.json` and must not
    //   grow one by accident — there is nothing for `13q42`/`13q44` to
    //   compare it against. Its source of truth is the four hand-tuned
    //   `Swirl` instances already shipping in this tree, named beside every
    //   rung below. That is deliberate: these are not palette tokens, they
    //   are the settled result of somebody sitting in front of the surface
    //   and turning the knob until it read right. If a rung ever needs a
    //   value that no shipped surface carries, it stops being derived and
    //   the number belongs in `accent.json` first.
    //
    // ⚠ THIS BLOCK DRAWS NOTHING TODAY. It is the definition; applying it
    //   to host surfaces is a separate pass and every existing instance is
    //   deliberately untouched. Every number below is COPIED OUT of a
    //   surface that already carries it, so adopting a rung on the surface
    //   it was derived from is a NUMERICAL no-op — every value it would
    //   assign is either the one that surface already assigns or the
    //   component default it already inherits. That is the check that the
    //   ladder describes this build rather than redesigning it.
    //
    // The axis is CONTENT DENSITY: how much readable material the eye has
    // to pull off the paint. It runs monotonically in `exposure`, which is
    // the gain term in the display pass (`1 - exp(-c * exposure)`), and the
    // shipped surfaces already sort themselves along it cleanly:
    //
    //   content 0.92 → panel 1.75 → channel 2.35 → shelf 4.35
    //
    //   · content — a grid or list of readable items sits ON the paint, so
    //     the paint is a ground and must not compete with type.
    //     Anchor: Launcher.qml's app-grid swirl.
    //   · panel   — large controls, little running text. The paint is a
    //     mood, read past rather than read through.
    //     Anchor: PowerMenu.qml's seam swirl.
    //   · channel — a thin decorative band with nothing on it. Only one
    //     slice of the field is visible, so it needs more punch to read as
    //     light rather than as a tinted edge.
    //     Anchor: Frame.qml's window channel.
    //   · shelf   — a near-transparent chrome surface where the paint IS
    //     the surface and there is no ground behind it at all.
    //     Anchor: Bar.qml's shelf swirl.
    //
    // A value marked "default" is one the anchor does NOT set. It is held
    // at `Swirl.qml`'s component default rather than interpolated, because
    // an invented number is exactly what this ladder exists to stop. Two
    // consequences worth stating so nobody "fixes" them:
    //   · `restOpacity` is NOT monotone. Only `channel` moves it, to 0.78,
    //     for the reason Frame.qml writes out at that line — "a frame that
    //     fades to a whisper stops being a frame" — and it is free, because
    //     the sim has already stopped and the buffers hold a static image.
    //   · `ambientDye` moves only at `shelf` (0.36, Bar.qml, owner 08-20).
    //     It is the resting glow the surface keeps with nothing behind it.
    //
    // DELIBERATELY NOT ON THIS LADDER:
    //   · `sweepLo`/`sweepHi` — the slice of the signature sweep a surface
    //     paints is a function of its SCREEN POSITION, not its density, and
    //     Launcher.qml's is a call to `driftLo()`/`driftHi()` rather than a
    //     constant. Wrong axis; stays per-host.
    //   · `intensity` — the user's Living-paint dial. A host binds it to
    //     `Prefs.swirlIntensity` and the ladder does not get a vote.
    //   · `saturation` and the hue stops — colour is the ramp's business.
    //     No rung here touches a hue. Chrome remains the single glacier
    //     ramp (standing rulings 1 and 2; `TRK-2818` disposition C).
    readonly property var swirlDensity: ({
        "content": ({ "opacity": 0.85, "exposure": 0.92, "bloom": 0.80,
                      "sheen": 0.35, "ambientDye": 0.14, "restOpacity": 0.62 }),
        "panel":   ({ "opacity": 0.90, "exposure": 1.75, "bloom": 1.00,
                      "sheen": 0.35, "ambientDye": 0.14, "restOpacity": 0.62 }),
        "channel": ({ "opacity": 1.00, "exposure": 2.35, "bloom": 1.35,
                      "sheen": 0.35, "ambientDye": 0.14, "restOpacity": 0.78 }),
        "shelf":   ({ "opacity": 1.00, "exposure": 4.35, "bloom": 1.50,
                      "sheen": 0.35, "ambientDye": 0.36, "restOpacity": 0.62 })
    })
    // Sparsest LAST, so the list reads the way the exposure ramp climbs.
    readonly property var swirlDensityOrder: ["content", "panel", "channel", "shelf"]
    // Which surface each rung was read off, so a reader can go and check.
    // A rung whose anchor stops carrying its numbers has stopped being
    // derived and is due a re-read.
    readonly property var swirlDensityAnchor: ({
        "content": "Launcher.qml", "panel":   "PowerMenu.qml",
        "channel": "Frame.qml",    "shelf":   "Bar.qml"
    })
    // A surface with no stated density is a `panel` — the middle rung, and
    // the one whose `bloom`, `sheen`, `ambientDye` and `restOpacity` are
    // all the component defaults, so naming it changes nothing.
    readonly property string swirlDensityDefault: "panel"
    // Look-up helper, so a host writes `Theme.swirlDense("channel").exposure`
    // rather than reaching into the map and getting `undefined` on a typo.
    // An unknown name falls back to the default rung rather than returning
    // nothing — a swirl that renders at the middle rung is a mistake you can
    // see and fix; one that renders with `undefined` gain is a black box.
    function swirlDense(role) {
        const r = swirlDensity[role];
        return r !== undefined ? r : swirlDensity[swirlDensityDefault];
    }

    // ══ THE GLASS MATERIAL — filament + focus sweep (2026-08-17) ═════════
    // The glass direction the owner approved, brought into the build as DATA:
    //   · layer 1, the FILAMENT material — grazing streak, ridge extraction
    //   · layer 2, the FOCUS SWEEP — an intensity-desaturated highlight,
    //     offset by the pane's screen position
    //   · the DECOUPLE — what an unfocused pane keeps
    //
    // ⚠ SOURCE OF TRUTH is `theme/accent.json` → `_glass_material`. This block
    //   is a MIRROR, exactly as `swirlTiers` above mirrors `_swirl_tiers` and
    //   `paintLayers` mirrors `_paint_layers`, and for the same reason: QML
    //   needs the values at load and there is no generator yet. Gate `13q45`
    //   fails the bake if the two disagree.
    //
    // ⚠ THIS BLOCK DRAWS NOTHING. It is the definition; the consuming
    //   surfaces — bar, flyouts, Start menu, buttons, toggles, scrollbars —
    //   are a separate pass and are deliberately untouched. Landing these
    //   numbers changes no pixel, and a reader who sets one and sees nothing
    //   move is seeing the intended behaviour. `Theme.qml` has nine confirmed
    //   instances of a value that was present in the file and had no effect at
    //   runtime, so being explicit about which of the two this is matters.
    //
    // ⚠ NOT ONE SWIRL VALUE MOVES FOR THIS. "SWIRLS DONT GET TOUCHED THEY
    //   ALWAYS STAY" — owner, verbatim, standing veto. `glassField` below does
    //   not redefine the paint; it records the settings at which the EXISTING
    //   field is EVALUATED by a second consumer, so the material and the
    //   wallpaper agree about where the light is. No `_paint_layers` stop, no
    //   `_swirl.mid`/`core` value and no `_swirl._emission` rung changes.
    //
    // The field is EVALUATED FROM SCREEN POSITION, never sampled: Quickshell
    // cannot read the pixels behind a window and every nyxus-* layer has blur
    // off by mandate, so anything needing what is underneath is dead on
    // arrival. Two levels of domain warp is what makes it read as liquid —
    // deleting the second level is what made it stop, once already.
    readonly property var glassField: ({
        "flow": 0.130, "activity": 0.55, "bias": 1.55,
        "crush_floor": 0.022, "crush_lo": 0.30, "crush_hi": 0.92,
        "warp_levels": 2
    })
    // Layer 1. The rim band is PIXELS, not a fraction of the pane — a rim is a
    // physical width, and a fractional band made the expensive call run over
    // the whole face while still being described as rim-only.
    //
    // `ridge` is the extraction and RIDGE ALWAYS, by owner ruling: filaments
    // are where the field CROSSES a level, not where it exceeds one. Plateau
    // fills with colour and buries text, so it is not an equal choice — if it
    // is ever exposed in Settings it sits behind an advanced disclosure. Note
    // the vocabulary trap: the level 0.56 is sometimes called the filament
    // FLOOR and `band_centre` IS that 0.56, but naming the level a floor does
    // not make the extraction one. A floor is the plateau failure; the ridge is
    // a band centred on the same number.
    //
    // THERE IS NO FILAMENT COLOUR HERE, ON PURPOSE. The filament's colour is
    // the field's colour at the sampled point — `rampAt()` of whichever paint
    // layer is active — so it follows rose, magma, glacier and violet with no
    // material edit. If an implementation finds itself picking a filament
    // colour, it has taken a wrong turn.
    readonly property var glassFilament: ({
        "rim_px": 46, "strength": 0.74, "falloff_pow": 2.4,
        "band_centre": 0.56, "band_sigma": 0.055,
        "shoulder_lo": 0.50, "shoulder_hi": 0.17,
        "tangent_compress": 0.34, "pointer_offset": 0.18,
        "early_out": 0.02, "extraction": "ridge"
    })
    // Layer 2. Oscillation, NOT a loop — a unidirectional repeating wipe is
    // the skeleton-loading idiom and would say "busy", not "focused". The
    // screen-position offset is what makes it one light source in the room
    // rather than a decal stamped on every pane: derived from local UV alone,
    // every window catches the highlight in the identical place.
    readonly property var glassSweep: ({
        "motion": "oscillation", "period_ms": 6200, "transition_ms": 150,
        "amp_focused": 0.46, "amp_unfocused": 0.17,
        "band_width": 0.21, "glint_frac": 0.26,
        "screen_offset_local": 0.62, "screen_offset_pane": 1.35,
        "desat_pow": 1.35, "desat_max": 0.78,
        "peak_luminance_clamp": 0.45, "modulates": "seam"
    })
    // THE SWEEP MAY BRIGHTEN A SEAM AND MAY NOT TOUCH A STATE RIM. Ladder A
    // (seams, alpha teal, 1.4.11-exempt) is in the sweep's reach — including
    // `seams.idle`, because a resting interactive control's edge is STILL a
    // seam. Ladder B (state: hover, active, focus-visible — solid, hue-coded,
    // 3:1 floor) is not, or "is this hovered?" becomes a question about the
    // wallpaper.
    readonly property string glassSweepModulates: "seam"

    // ── the highlight · the material's one colour, in one place ──────────
    // The sweep's highlight, as a SINGLE named constant: the highlight is the
    // only colour decision this material contains, so it gets exactly one seam
    // where it is defined rather than a hex repeated into a shader. Everything
    // else derives — the filament is the active swirl layer's own ramp, the
    // seam is the sweep's own value — and gate `13q45` asserts the material
    // declares exactly one colour and that it is this one.
    //
    // `tealGlow` #5cc6ea is the canonical highlight and what the approved
    // mockups render. Measured: 10.4398:1 over the ground #020506, HSV
    // saturation 0.6068 — which clears the 0.18 floor OUTRIGHT, so it needs no
    // exemption and no precedent argument, and there is nothing here for a
    // later reader to re-open.
    //
    // ⚠ ITS LUMINANCE IS THE REAL CONSTRAINT: 0.4860, which is 8.0% OVER
    //   `_tokens.ambient.peak_luminance_max` 0.45, and the intensity
    //   desaturation drives the rendered core further up toward white — so the
    //   rendered peak is far over even though the token is only a little over.
    //   Same class as the #ffb3d9 finding already on record: safe as a glyph or
    //   a 1 px core, unsafe as a bloom colour or any filled area. So the glint
    //   stays a narrow core inside a broad band, and THE CLAMP IS APPLIED IN
    //   THE MATERIAL'S OWN SHADER; the token is not trusted for it, because
    //   `_tokens.ambient._enforcement` records that this number is enforced
    //   nowhere in the tree.
    //
    // ⚠ THE CLAMP IS THIS MATERIAL'S, NOT THE SWIRLS'. The swirl rules require
    //   the field's top 1–3% to go near-white (~0.9), which collides with 0.45
    //   only if you read the clamp as covering the paint. It does not: it
    //   covers the material. The swirls stay untouched under the standing veto.
    //
    // A paler cool highlight was proposed as the study's option C, justified as
    // the colour the build already drew every Crown hairline in. It was not:
    // the Crown is `driftAt()` slices of the live sweep (`Bar.qml`, the
    // `crownLine` stops), so the Crown has no single colour, and the value was
    // in no file in this tree. It was ruled in and then revoked on exactly that
    // ground, so no stop was added — see the note in `accent.json`.
    readonly property color glassSweepHighlight: tealGlow

    // ── the decouple · what an unfocused pane keeps ──────────────────────
    // Unfocused is the MAJORITY state — one window is focused, everything else
    // is not — so it is tuned FIRST and judged ALONE, on its own merits, with
    // the sweep as what focus ADDS rather than what unfocus is missing.
    //
    // These are TWO NAMED STATES, not two points on one axis: `material_kept`
    // is how much of the filament material an unfocused pane retains, `smoke`
    // is the absorption laid over it. 0.78 / 0.84 is the owner's ruling and is
    // settled. (GLASS-SPEC §6 carried smoke at 0.90, having moved it off 0.84
    // once the field was corrected; the owner has since ruled 0.84, so §6 is
    // stale on that one figure. `material_kept` was never in dispute.)
    //
    // `smoke` is absorption by focus — the distinction Hyprland already draws
    // at active/inactive opacity. It is NOT a fourth fill rung.
    readonly property var glassDecouple: ({
        "material_kept": 0.78, "smoke": 0.84
    })

    // The drift as a COLOUR, for the things that cannot take a ramp slice —
    // the bar's Seam and Crown hairlines, which are one pixel of gradient and
    // have to be handed finished colours. Without this they stayed a frozen
    // teal→plum rainbow while every painted surface around them moved, and a
    // static stripe next to a drifting one does not read as restraint; it
    // reads as the thing the owner called "faint colours in the bars".
    function driftAt(off) { return sweepAt(driftCenter(off)); }

    // ── legacy names, repointed ──────────────────────────────────────
    // Kept so nothing breaks mid-refactor. Retire as files are converted.
    readonly property color purple:     violet
    readonly property color purpleGlow: violetGlow
    // ── KEY ACCENT · WITHDRAWN 2026-08-22 (TRK-1463) ────────────────────
    // THE HISTORY, KEPT BECAUSE AN UNEXPLAINED ABSENCE IS WORSE THAN A
    // SUPERSEDED RULE. On 2026-08-22 at 01:30 the owner ruled: "Add some of
    // that purple on key items throughout the build — not heavy, just enough
    // to complete it." Glacier stayed the base and purple marked STATE only —
    // switches/sliders/toggles ON, the chosen option, the checked ground —
    // through `keyAccent: violetGlow` and `keyAccentDeep: violetBody`, which
    // the 08-20 ISO overlay 50c78c60 implements and gate 13s90 asserted.
    //
    // SUPERSEDED THE SAME DAY. Asked directly whether to keep the 01:30
    // state-only key accent or ship the palette of the last baked ISO
    // (87da09fe), the owner answered: "yes no purple." The two tokens are
    // gone, the four ON/chosen sites are back on the bake's own glacier[5],
    // and 13s90 was re-cut in the same commit to assert their ABSENCE
    // instead of their presence. Do not re-add them without a NEWER ruling
    // than 2026-08-22 — and if one comes, migrate 13s90 and 13t80 with it.
    readonly property color amber:      gold
    readonly property color amberGlow:  goldGlow
    readonly property color amberDeep:  goldDeep

    // ── base · deep space ────────────────────────────────────────────
    // The references' ground is #000000–#000007. Ours is a hair off black so
    // the desktop is not a dead void, and no darker than it has to be —
    // every bit of black under an accent is what makes the accent read as
    // emitted rather than painted.
    // ONE GROUND STACK, 2026-08-09 (WIP-239). These three were the pre-rose
    // galaxy grounds (#03040c / #07091a / #0b102a, hue ~233) while every app
    // window sat on _palette_fixed's rose-pinned stack (hue ~197) — so the
    // Start menu and the window under it were two different near-blacks,
    // touching each other on screen all day. Measured CIE76: void ΔE 2.93,
    // surface 8.83, elevated **16.25** — the last is plainly a different
    // colour, and `elevated` is the hover state on BOTH sides, which is the
    // worst possible place for a mismatch.
    //
    // Cause is the one this whole session kept finding: _palette_fixed was
    // hue-pinned to the rose on 2026-08-06 and _swirl._emission.base was not.
    // `_swirl` is Agent B's block and is deliberately NOT edited here — the
    // emission model keeps its own record. What changed is which stack the
    // SHELL reads, and nothing else in shell/ spells these hexes out, so
    // these three lines are the whole fix.
    //
    // The old note on `elevated` still applies to why it is not grey: it was
    // #141a30, a blue-GREY at S 0.58 and the muddiest colour in the build,
    // sitting behind every hover state. Same darkness, real chroma — now the
    // same real chroma as the apps.
    // ══ WARM LIGHT, COOL SHADOW ═══════════════════════════════ TRK-4140 ══
    // Owner, 2026-09-15: "what do you think would make the theme better
    // looking using these layers".
    //
    // The elevation ladder was warm at every rung. Measured R:B under MAGMA:
    //
    //   void_     #0a0404   R10 B4    R/B 2.5   ← deepest
    //   surface   #120605   R18 B5    R/B 3.6
    //   elevated  #1a0806   R26 B6    R/B 4.3   ← raised
    //
    // The instinct was already right — warmth climbs with elevation — but it
    // climbs from warm to warmer, so the ember at the top has nothing to be
    // warm AGAINST. No painter puts a warm shadow under a warm light, and
    // fire in particular lights a cold room: the lava glows, the rock around
    // it stays blue-black night. Warm-on-warm is what integrates to the
    // "too much of the same color" the owner called out.
    //
    // So the bottom rung goes cold and the top two stay lit. void_ is 112
    // uses and elevated is 120, so this is a genuine two-pole system rather
    // than a tint: every recess now reads cool and every raised face reads
    // hot, and the ember gets hotter by simultaneous contrast WITHOUT one
    // more orange pixel on screen.
    //
    // Luminance is held so blacks do not lift: #0a0404 is lum 5.8, #05060b is
    // lum 6.3 — a rounding error to the eye, but B/R goes 0.4 → 2.2.
    //
    // ⚠ ICE is untouched. It is a cold theme end to end; its shadow is
    // already cool and giving it a second cool would flatten it the same way.
    readonly property color void_:     lookMagma ? "#05060b" : "#020506"
    readonly property color surface:   lookMagma ? "#120605" : "#040b0e"
    readonly property color elevated:  lookMagma ? "#1a0806" : "#071318"

    // ── text ─────────────────────────────────────────────────────────
    readonly property color text:      "#edf1ff"
    readonly property color textMuted: "#c9d0e8"
    readonly property color textDim:   "#a8aecc"

    // ── signal ───────────────────────────────────────────────────────
    readonly property color ok:        "#2cf597"
    readonly property color warn:      gold
    readonly property color danger:    "#ff2d55"   // errors ONLY, never focus
    // #ff4d6d was the first pick and is on nyxus_palette.FORBIDDEN — the alien
    // build banned it as an off-brand red. Suxyn will want its own palette
    // contract eventually; until then the sanctioned constant is the right
    // answer, and fighting a working drift-guard is not worth the churn.
    // ══ THE SUCCESS FAMILY (TRK-2930) · the build's fourth colour ═══════
    // Owner ruling 2026-08-24: he asked for "one other color as well to mix
    // up with the build" and chose a SUCCESS role — "connected, secure,
    // backed up, done" — FUNCTIONALLY SCOPED LIKE `danger`, not decorative.
    //
    // ⚠ SOURCE OF TRUTH is `theme/accent.json` → `_success`. This block is a
    //   MIRROR, exactly as `paintLayers` mirrors `_paint_layers` and
    //   `swirlTiers` mirrors `_swirl_tiers`, and for the same reason: QML
    //   needs the values at load and there is no generator yet. Keep the two
    //   byte-identical. The full derivation, the role text, the scope and
    //   every contrast ratio live in `accent.json`; they are not duplicated
    //   here, because a second copy of a rule is how rules drift.
    //
    // DERIVED, NOT PICKED. There is no green anywhere in `_paint_layers`, so
    // picking one would have been an invented hue. The build already owns
    // exactly one green and it is canonical, measured and hue-locked: the
    // `_terminal` green COLUMN (WIP-243, 2026-08-09). These three rungs ARE
    // that column, verbatim — `dim.green` / `normal.green` / `bright.green`.
    // No new hex exists anywhere in this change. Same move `paintEmber` made
    // when it took BorderPulse's heavyStops instead of inventing a hot
    // palette, and it means the terminal and the interface say "ok" in
    // literally the same colour. `ok` above is already `stops.body`.
    //
    // MEASURED against `elevated` #071318 (the plate a state mark sits on),
    // floor 3:1 for a non-text UI mark:
    //     dim    #09c36c   H 151.9    8.10:1
    //     body   #2cf597   H 151.9   13.10:1   ← THE MARK
    //     bright #77f9bc   H 151.8   14.40:1
    // Hue spread 0.1°. No collision: magma H 1–35 (gold H 29.8), glacier
    // H 191–227, violet H 261–303. H 152 is unoccupied in this palette.
    //
    // ⚠ A GREEN FILL TAKES DARK TEXT. `text` #edf1ff on `body` is 1.27:1 and
    //   unreadable; `void_` #020506 on `body` is 14.23:1. This is the trap
    //   #891955 fell into — a rung used in the one role it is wrong for.
    //
    // ⚠ NOT A FIFTH PAINT LAYER. It must never appear in `paintLayers`;
    //   gate 13q37 asserts the layer count stays four. The paint has no
    //   opinion about whether a backup finished.
    //
    // ⚠ THE ROLE IS DEFINED, NOT APPLIED. Nothing in the shell renders
    //   differently because this property exists. Wiring it into controls is
    //   a separate pass and a separate row.
    readonly property var success: ({
        "dim":    "#09c36c",   // resting confirmation — true, but not news
        "body":   "#2cf597",   // THE MARK — connected / secure / done
        "bright": "#77f9bc"    // momentary: the flash into success, and hover
    })


    // ── frosted glass / corner-bleed material ────────────────────────
    // Panel bodies are translucent so Hyprland's layer blur shows through.
    // The blur region itself is rectangular (a layer surface always is), so
    // rounded corners can leave a faint square of blurred wallpaper at each
    // corner. `ignore_alpha = 0.2` in the layerblur shard suppresses it —
    // docs/SHELL_FRAMEWORK_EVALUATION_2026-08-02.md §14.
    //
    // The fill stays dark on purpose. Colour lives in the border and the glow,
    // never behind text — that rule is what will let the reactive paint move
    // under a panel without making labels unreadable.
    // 2026-08-05: retinted to the same cool green-teal as the Shelf, and
    // lightened. A Swell stays MUCH more solid than the bar and that is
    // deliberate, not an inconsistency — the bar is a single thin pane of
    // clear glass, a Swell is a deep volume of it, and deep glass frosts.
    // (The layerblur shard says the same thing from the compositor's side:
    // blur on for the panels, off for `nyxus-bar`.) Both are the same
    // material seen at two thicknesses, which is why they read as related
    // without being the same colour.
    // Dropped again so the Swells read as the SAME material as the bar rather
    // than as dark cards near it — the owner's instruction was that the
    // flyout and the Start menu have to match the bottom bar. They stay a
    // little heavier than the bar's 0.34 for one honest reason: the bar is a
    // thin strip with six labels on it and a Swell is a page of dense text,
    // so the panel is a thicker piece of the same glass. Below about 0.5 with
    // the blur off, body text over a busy desktop stops being readable, which
    // is a worse failure than not matching exactly.
    // 0.44 was tried and reverted, with the screenshot to prove it: a
    // page-sized panel at that alpha with the blur off let you read the text
    // of the editor behind it through the app grid — WIP-19's exact defect,
    // reached from the other direction. These sit as light as they can go
    // while a Swell still covers what is under it.
    readonly property color glassFill:       lookMagma
        ? Qt.rgba(0.040, 0.012, 0.008, 0.46)
        : Qt.rgba(0.010, 0.026, 0.040, 0.46)
    readonly property color glassFillStrong: lookMagma
        ? Qt.rgba(0.040, 0.012, 0.008, 0.66)
        : Qt.rgba(0.010, 0.026, 0.040, 0.66)
    readonly property color glassScrim:      lookMagma
        ? Qt.rgba(0.035, 0.010, 0.008, 0.72)
        : Qt.rgba(0.006, 0.008, 0.035, 0.72)
    // ── THE BORDER IS SOLID, AND IT IS ROSE ──────────────────────────
    // Owner: "the border of whatever were solid then the inside were glass",
    // and separately, the standing rule in § THE RATION below: glass carries,
    // solid signals. A border is not a surface -- it is the line that says
    // where the surface stops -- so it is exactly the thing that should be
    // solid colour.
    //
    // This was `soften(indigo, 0.50)`: indigo at half alpha. Two problems, and
    // the second is the one that shows. It was TRANSLUCENT, so on a dark
    // wallpaper the border faded into whatever was behind it and the pane had
    // no defined edge at all -- the opposite of the reference he described.
    // And it was INDIGO, a generation behind the rose chrome that gtk.css now
    // carries, so a Quickshell panel and a GTK window disagreed about what
    // colour the build is on the one cue you look at first.
    //
    // #891955 is plumBody, the same hex gtk.css uses for `borders`,
    // `headerbar_border_color` and every divider in the app layer. One rule
    // colour across the whole build.
    //
    // (Said #891654 until 2026-08-12. That was the PRE-correction value; the
    // property at line 96 has read #891955 since 2026-08-10, and this comment
    // and the one on accentSolidLow were simply never moved with it. A stale
    // comment beside a correct value is how WIP-117 shipped — every later
    // reader had a written reason not to check the one thing that was wrong.)
    readonly property color glassBorder:     lookWidgetBorder
    readonly property color glassGlow:       soften(teal, 0.30)
    readonly property color glassGlowViolet: soften(violet, 0.28)

    readonly property int radius:      18
    readonly property int radiusSm:    12
    readonly property int glowBlur:     22

    // ═════════════════════════════════════════════════════════════════
    //  HORIZON — the design language.
    //  docs/DESIGN_LANGUAGE_HORIZON_2026-08-03.md is the reasoning; this
    //  block is the contract. Nothing in the shell writes its own duration,
    //  easing curve, font size, radius or spacing value. Add a token here.
    // ═════════════════════════════════════════════════════════════════

    // ── the shelf ────────────────────────────────────────────────────
    // The bottom of the screen darkens into this so unboxed content stays
    // legible over any wallpaper. It is a gradient, not a panel: no border,
    // no corners, nothing to see.
    // 2026-08-05 · GLASS. These were 0.97 and 0.74 — effectively opaque — and
    // that is the whole reason the bar never looked like glass. It was not a
    // blur problem: Hyprland's blur is on (size 14, passes 4), the layerblur
    // shard IS loaded, and the surface IS named `nyxus-bar` so the
    // `^(nyxus.*)$` rule matches it. The compositor was dutifully blurring the
    // wallpaper behind a black wall.
    //
    // Blur frosts a TRANSLUCENT surface. This is the same lesson `WIP-19`
    // learned from the opposite end, where the GTK apps set the root window to
    // `transparent` and got a hole instead of frost: alpha 0 is absent, alpha
    // 1 is a wall, and glass lives in between.
    //
    // Kept above the shard's `ignore_alpha 0.2` floor, or the compositor skips
    // the pixel and the frost stops exactly where the bar gets thin.
    //
    // ── revised the same day, to the owner's actual reference ────────────
    // "like looking inside an empty fish tank". That is CLEAR glass, not
    // frosted, and it is a different material: frost hides what is behind it
    // and announces itself by being milky, clear glass hides nothing and
    // announces itself entirely at its EDGES. So the body drops again, and
    // the work moves to the rim — see § GLASS EDGES below and the stack in
    // Bar.qml.
    //
    // The tint is cool and slightly green on purpose. Real glass is green in
    // section — it is why the cut edge of a fish tank, a mirror or a window
    // pane reads teal — and that happens to be where this palette starts, so
    // the material and the sweep agree without being made to.
    readonly property color shelfDeep: lookMagma
        ? Qt.rgba(0.050, 0.016, 0.010, 0.34)
        : Qt.rgba(0.012, 0.032, 0.040, 0.34)
    readonly property color shelfMid:  lookMagma
        ? Qt.rgba(0.042, 0.014, 0.008, 0.20)
        : Qt.rgba(0.010, 0.026, 0.034, 0.20)
    readonly property color shelfNone: lookMagma
        ? Qt.rgba(0.035, 0.010, 0.008, 0.0)
        : Qt.rgba(0.006, 0.008, 0.028, 0.0)
    // The top of the pane, and the reason it needed a token of its own: with
    // the old top-heavy veil removed, the Shelf's own top stop was
    // `shelfNone` — alpha 0 — so the upper third of the bar had NO BODY AT
    // ALL and the wallpaper ran through it at full contrast. Photographed,
    // that does not read as clear glass; it reads as a coloured line drawn on
    // a photograph, which is the exact failure the Lip exists to prevent.
    // A pane of glass is glass all the way up. It is nearly the same tint as
    // `shelfMid`, so the body is close to uniform and the gradient only leans
    // very slightly heavier where it meets the floor.
    // ── THE PAINT GROUND ─────────────────────────────────────────────
    // Added 2026-08-10 (WIP-265), and it exists because of a backdrop, not
    // because of the paint.
    //
    // The bar's Swirl is tuned on the stated principle in Bar.qml's own
    // brightness note: *"opacity lets the dark glass show through between
    // the strands, so the structure has a ground … a uniformly lit field
    // has no filaments however bright it is; contrast is the whole
    // mechanism."* That ground used to be a dark wallpaper seen through
    // clear glass. `LiveWall` put a BRIGHT galaxy there instead, and the
    // paint — unchanged, still running, still at opacity 0.85 — lost the
    // dark it was being bright against. Proved by toggling
    // `livingWallpaper` off for six seconds: the ribbons come straight
    // back, full width, with not one swirl value touched.
    //
    // So the fix is the ground, not the paint. This is a bar-local darkener
    // UNDER the Swirl and OVER the wallpaper. It is deliberately NOT the
    // shared `shelf*` ladder — those are read by six files, and darkening
    // them to solve a bar problem would dim every panel in the build to fix
    // one strip. Transparent at the top so nothing above the paint band
    // changes; it only deepens where the ribbons actually live.
    //
    // ⚠ If `LiveWall` is ever turned off again, this can come back down —
    // it is compensation for a specific backdrop, and it says so here so
    // that the next person does not read it as a taste decision.
    // ── THE SWELL GROUND ─────────────────────────────────────────────
    // The panel-sized twin of the paint ground below, and the reason it has
    // its own numbers rather than reusing § THE SWELL BODY: once the
    // darkening moved UNDER the living paint (WIP-265), it stopped sharing
    // the job with anything. WIP-259's 0.68/0.76/0.82 were measured as a
    // veil lying OVER the paint, where the paint's own dye added to the
    // cover; underneath, it is the only thing between you and the window,
    // so at those values a browser's text still read straight through — I
    // watched it do exactly that, in the flyout, after the move.
    //
    // Denser, and deliberately still short of a wall: the standing rule is
    // that alpha 1 is a wall and a glass value at either end is a bug on
    // sight. These sit where the window is gone but the surface is still
    // something light passes into.
    readonly property color swellGroundTop:  lookMagma
        ? Qt.rgba(0.055, 0.016, 0.010, 0.84)
        : Qt.rgba(0.006, 0.014, 0.020, 0.84)
    readonly property color swellGroundMid:  lookMagma
        ? Qt.rgba(0.045, 0.012, 0.008, 0.89)
        : Qt.rgba(0.005, 0.011, 0.017, 0.89)
    readonly property color swellGroundFoot: lookMagma
        ? Qt.rgba(0.035, 0.010, 0.006, 0.93)
        : Qt.rgba(0.004, 0.008, 0.014, 0.93)

    readonly property color paintGroundTop:  lookMagma
        ? Qt.rgba(0.040, 0.012, 0.008, 0.00)
        : Qt.rgba(0.004, 0.010, 0.016, 0.00)
    readonly property color paintGroundMid:  lookMagma
        ? Qt.rgba(0.040, 0.012, 0.008, 0.78)
        : Qt.rgba(0.004, 0.010, 0.016, 0.78)
    readonly property color paintGroundFoot: lookMagma
        ? Qt.rgba(0.030, 0.008, 0.006, 0.93)
        : Qt.rgba(0.003, 0.006, 0.012, 0.93)

    readonly property color shelfTop:  lookMagma
        ? Qt.rgba(0.050, 0.016, 0.010, 0.15)
        : Qt.rgba(0.012, 0.032, 0.040, 0.15)

    // ══ THE MATERIAL FORMULA (2026-08-08, owner-directed) ═══════════════
    // The owner, after the first full hardware boot of the rose build:
    //   "I can't have all these different styles going on all at once, it
    //    looks like shit... the glass for the theme needs to mimic the glass
    //    on the bottom bar."
    //
    // He was diagnosing something real and specific. The bar is a GRADIENT
    // running 0.15 → 0.20 → 0.34. The start menu and the side panel were a
    // FLAT 0.66 — double the density and no depth at all. `GlassEdge.qml`
    // already wrote down why that fails, three files away from the surfaces
    // still doing it: "the bar reads as glass at alpha 0.15 while a Swell at
    // 0.66 read as a black rectangle with a rim on it." The recipe was right
    // and the surfaces were never moved onto it. The widgets were worse — a
    // flat fill with no GlassEdge at all, which is why they photographed as
    // plain dark boxes.
    //
    // So there is now ONE body for every floating surface in the build, and
    // it is the bar's. Anything that hovers over the wallpaper — bar, start
    // menu, side panel, widgets, launcher, power menu, toasts, task view,
    // context menus, and the GTK apps' own chrome — uses `surfaceTop/Mid/Deep`
    // in a vertical gradient plus a `GlassEdge`. Nothing gets its own tuning.
    // A surface that looks wrong is fixed HERE, so it stays one object.
    //
    // These are deliberately aliases of the shelf tokens rather than copies.
    // A second copy of a value is how the styles drifted apart in the first
    // place, and the bar must never be able to disagree with the build.
    readonly property color surfaceTop:  shelfTop    // 0.15 — the upper face
    readonly property color surfaceMid:  shelfMid    // 0.20 — through the body
    readonly property color surfaceDeep: shelfDeep   // 0.34 — where it meets its floor

    // ── TRK-1812 · the PANEL glass, darker than the shelf ────────────────
    // Owner 2026-08-22: "we need to darken the see through glass a little".
    //
    // He means the panels — Start menu, side panel, Lintel. It could NOT be
    // done by darkening surfaceTop/Mid/Deep, because those are ALIASES of
    // shelfTop/Mid/Deep and Bar.qml draws its own glass with the same tokens.
    // The bottom bar is explicitly not being touched (owner, same day), so
    // changing them would have altered the one surface he ruled out.
    //
    // These are therefore NEW stops rather than edits: identical hue, higher
    // alpha. 0.15 → 0.27, 0.20 → 0.34, 0.34 → 0.48. Used by the three panels
    // and by nothing else, so the bar cannot move when these do.
    readonly property color panelTop:  lookMagma
        ? Qt.rgba(0.050, 0.016, 0.010, 0.27)
        : Qt.rgba(0.012, 0.032, 0.040, 0.27)
    readonly property color panelMid:  lookMagma
        ? Qt.rgba(0.042, 0.014, 0.008, 0.34)
        : Qt.rgba(0.010, 0.026, 0.034, 0.34)
    readonly property color panelDeep: lookMagma
        ? Qt.rgba(0.050, 0.016, 0.010, 0.48)
        : Qt.rgba(0.012, 0.032, 0.040, 0.48)

    // ── TRK-1784 · tokenAccentGround — the SELECTED ground ───────────────
    // ICEPLATE measured the selected fill at 2.10:1 against the ice plate,
    // under the 3:1 floor that COMPLETION_SPEC sets for UI components, and the
    // next stop up (glacier[4]) is reserved by Theme's own rule for 1 px
    // dividers and may not be taken. SUP authorised exactly one new stop
    // between them.
    //
    // MEASURED here rather than asserted, against Theme.elevated #071318 which
    // is the plate body a selected fill actually sits on:
    //
    //     glacier[3]  #274b7a   2.13:1   today, under the floor
    //     THIS STOP   #3b6590   3.09:1   clears it, L = 0.1225
    //     glacier[4]  #4f7fa6   4.41:1   reserved, not available
    //
    // It is mix(glacier[3], glacier[4], 0.50) — a stop BETWEEN two existing
    // stops rather than a new colour, and the first such mix that clears 3:1.
    // ICEPLATE proposed L ~ 0.117; this lands at 0.1225. It stays 1.43:1 away
    // from glacier[4], so a selected ground and a divider are still telling
    // apart.
    // DERIVED, not pinned. Gate 13x80 requires the ground to come off
    // `Theme.paintLayers`, and it is right to: a hand-written hex is exactly
    // how a second hue arrives, which is the door the purple came through.
    // Pinning #3b6590 passed my own measurement and still failed that gate,
    // correctly — the number was right and the PROVENANCE was not.
    //
    // ⚠ `paintLayers.glacier[n]` entries are hex STRINGS. Reading `.r` off one
    // yields NaN and paints BLACK; that bug once hid a palette cut for an hour.
    // Qt.color() first, always.
    function groundFrom(layer) {
        var a = Qt.color(layer[3]);   // glacier[3] #274b7a — 2.13:1, too dark
        var b = Qt.color(layer[4]);   // glacier[4] #4f7fa6 — reserved, dividers
        return Qt.rgba((a.r + b.r) / 2, (a.g + b.g) / 2, (a.b + b.b) / 2, 1.0);
    }
    readonly property color tokenAccentGround: groundFrom(paintLayers.glacier)

    // ── THE RATION: how much glass, how much solid ──────────────────
    // The other half of the owner's brief: "so much solid, so much glass, we
    // need to mix it all and get the correct formula", and the colour must
    // "actually show" — "don't do glass or transparent, nothing, just the
    // colour".
    //
    // The rule this build now follows, and the reason it is a rule and not a
    // taste: **glass carries, solid signals.** A surface is glass. Anything
    // that reports STATE or invites an ACTION is solid, opaque colour with no
    // alpha and no gradient — meter fills, the active/selected row, a toggle
    // that is on, an active icon, a badge, the focused window's border.
    //
    // Roughly nine parts glass to one part solid. The ration is the point: at
    // 50/50 the accent stops meaning anything and the build looks like a toy.
    // Rose is scarce here so that when it appears, it reads as the system
    // telling you something — which is also why the accent must never be used
    // for decoration on a resting surface.
    //
    // Solid, in this palette, means the BODY rung — not the haze (invisible on
    // dark) and not the glow (which is the light coming off it, used for the
    // halo around a solid mark, never as the mark itself).
    readonly property color accentSolid:     plum        // #ae206c — the mark
    readonly property color accentSolidLow:  plumBody    // #891955 — its resting state
    readonly property color accentSolidHalo: plumGlow    // #d765a2 — light off it
    // Full-strength, no alpha. If you find yourself reaching for `soften()` on
    // one of these, you want a glass surface instead — that is the whole tell.
    readonly property color accentInk:       "#ffffff"   // type ON a solid accent

    // ── GLASS EDGES ──────────────────────────────────────────────────
    // What actually says "this is a thick pane" in a flat interface:
    //   · a bright specular line along the top face          (crown, above)
    //   · a thin DARK band immediately under it — the pane seen edge-on,
    //     which is the single cue that gives it thickness rather than
    //     making it a sheet of cellophane
    //   · a broad, very faint sheen on the top third, light lying on glass
    //   · light collecting at the base, which the Line already does
    readonly property int   glassLipH:    3
    readonly property real  glassLipA:    0.30
    // ⟵ and the Lip is TINTED, not black. Photographed at 5× over the owner's
    // wallpaper, a band of `void_` at 0.30 was invisible: the wallpaper under
    // the bar is already near-black, so darkening it darkens nothing, and the
    // Crown read as a coloured hairline drawn on a photograph with no slab
    // under it. §3.5's rule says the same thing from the palette's side —
    // there is no such thing here as a dull dark; a shadow is a deeply
    // saturated colour, never a grey.
    //
    // Physically it is also the truer answer. A cut glass edge reads teal
    // BECAUSE you are looking through more glass, so the pane seen in section
    // is simply the body tint at several times the concentration. Same hue as
    // `shelfTop`, roughly four times the density: it darkens a bright backdrop
    // and tints a dark one, so the edge exists over any wallpaper.
    readonly property color glassLipTint: lookMagma
        ? Qt.rgba(0.048, 0.016, 0.010, 0.52)
        : Qt.rgba(0.010, 0.040, 0.048, 0.52)

    // ── the Glaze · light standing INSIDE the pane ───────────────────
    // The bar reads as glass at a body alpha of 0.15 and a Swell read as a
    // black rectangle with a rim at 0.66, and the difference is not the
    // number — it is that the Swell's body was a FLAT fill. Real glass is
    // brighter where the light enters it, near the top, and it deepens as you
    // look through more of it toward the foot. That gradient is most of what
    // says "slab" rather than "card", and it costs one rectangle.
    //
    // The foot deepens toward the body's own green-teal rather than toward
    // black, because §3.5's rule is that this palette has no dull darks: a
    // shadow here is a saturated colour. `GlassEdge.qml` draws all three.
    readonly property color glazeTop:  lookMagma
        ? Qt.rgba(0.97, 0.66, 0.23, 0.050)
        : Qt.rgba(0.60, 0.86, 0.92, 0.050)
    readonly property color glazeMid:  lookMagma
        ? Qt.rgba(0.63, 0.29, 0.16, 0.012)
        : Qt.rgba(0.30, 0.55, 0.60, 0.012)
    readonly property color glazeFoot: lookMagma
        ? Qt.rgba(0.039, 0.016, 0.016, 0.130)
        : Qt.rgba(0.010, 0.048, 0.056, 0.130)

    // ══ THE SWELL BODY — the second thickness (WIP-259, 2026-08-10) ═════
    // The owner has reported the Start menu's labels as too dim THREE times.
    // WIP-232 and WIP-250 both answered by lifting the text ladder, and both
    // measured the lift against `void_`. That was the wrong backdrop, and it
    // is why neither fix held:
    //
    //   · blur is OFF for every nyxus-* layer, by mandate
    //     (`nyxus-hyprland-layerblur.conf:33`, the clear-glass rule), and
    //   · a Swell is a layer ABOVE WINDOWS, so what is actually behind those
    //     labels is not the wallpaper and never was — it is whatever window
    //     you had open.
    //
    // Measured on the live screen, in the Launcher's own rectangle
    // (`hyprctl layers` → nyxus-launcher 0 236 1064 784), against the real
    // backdrop rather than the void, with the body at `surfaceMid` (0.20):
    //
    //     backdrop            text    textMuted   textDim
    //     median (dark wall)  17.6:1    12.9:1      9.1:1   ← fine, always was
    //     bright decile        9.6:1     7.1:1      5.0:1
    //     brightest 1%         2.5:1     1.9:1      1.3:1   ← INVISIBLE
    //
    // At 1.3:1 there is no text colour that works, which is the whole reason
    // two lifts of the ladder changed nothing he could see. The screenshot
    // that settles it: with a terminal behind it you can read the terminal's
    // diff — "Added 5 lines, removed 1 line", the red and green rows — THROUGH
    // the Start menu, competing with the app labels. That is `WIP-19`'s
    // window-shaped hole at panel size.
    //
    // ── why this is not a retreat from the clear-glass mandate ──────────
    // The 2026-08-09 mandate collapsed the bar and the Swells onto ONE
    // thickness. The mandate's own file anticipated this exact moment and
    // wrote down the remedy: legibility comes from "the panels' own darkening
    // falloffs and local shading UNDER the type (they all still carry them)",
    // and "if read-through turns out to bother the owner on hardware, that is
    // his call to make looking at a screen". He has now made that call three
    // times — and the parenthesis was simply not true: `Bar.qml` carries a
    // content scrim and its Hazes, and NO other surface carries anything.
    // Grep `scrim` across shell/: one file.
    //
    // So the Swells get their body back — as a GRADIENT, never a flat fill.
    // That distinction is the whole of the original complaint, which was not
    // that the old Swell was dense but that it was FLAT: "the bar reads as
    // glass at alpha 0.15 while a Swell at 0.66 read as a black rectangle
    // with a rim on it" — 0.66, no depth, and that is what he photographed
    // and rejected. Here the tint is the bar's own, it runs top-to-foot, the
    // Crown, Lip, Sheen, Bleed and dispersive rim all still sit on top of it,
    // and the wallpaper still comes through. It is the SAME material seen
    // through more glass, which is exactly what `Theme § GLASS` said a Swell
    // was before the two thicknesses were collapsed into one.
    //
    // Composited over `surfaceMid`, these give 0.54 → 0.63 → 0.70 coverage,
    // which puts textDim at 7.7:1 over the bright decile and 4.7:1 over a
    // white window — above the WCAG AA floor in the worst case this desktop
    // can produce, instead of a third of it.
    //
    // The bar does NOT get this (it has the Shelf, and `body: 0` is the
    // default). Inline chips do not get it either — a chip is a chip of the
    // same glass, not another slab, and stacking a second body inside a Swell
    // is how you get a black card on a grey card.
    readonly property color swellTop:  lookMagma
        ? Qt.rgba(0.040, 0.016, 0.010, 0.68)
        : Qt.rgba(0.010, 0.030, 0.040, 0.68)
    readonly property color swellMid:  lookMagma
        ? Qt.rgba(0.030, 0.012, 0.008, 0.76)
        : Qt.rgba(0.008, 0.022, 0.030, 0.76)
    readonly property color swellFoot: lookMagma
        ? Qt.rgba(0.024, 0.008, 0.006, 0.82)
        : Qt.rgba(0.006, 0.016, 0.024, 0.82)

    // There is deliberately no inline-card body token. The cards inside a
    // Swell (the vitals block, Now Playing, Quick) already carry their own
    // `soften(void_, 0.46)` fill, which on top of the body above lands near
    // 0.89 — measured on screen, they are the most covered thing in the
    // panel. A second token here would be a knob nothing turns.
    readonly property int   glassSheenH: 30
    readonly property real  glassSheenA:  0.055
    // How far below the specular line the Lip starts. One pixel, everywhere:
    // the dark band has to touch the highlight or the two read as two separate
    // decorations instead of as one edge seen in section. `Bar.qml` asked for
    // a `crownH` that was never defined, so its Lip and Sheen were anchored to
    // `undefined` and both collapsed to the top of the pane — the panels were
    // already using a literal 1 for the same thing. One token, one number.
    readonly property int   glassLipTop:  1
    // The Crown's whole height: the specular line plus its falloff. A token
    // because the Lip, the Sheen and the Crown itself all have to agree about
    // where the top edge stops being an edge and starts being a face.
    readonly property int   crownH:      16

    // ── chrome metrics ───────────────────────────────────────────────
    // 84, was 72. Every consumer derives from this token — the Launcher, the
    // Flyout, Toasts and TaskView all sit at `chromeH - bloomPad` and the bar
    // takes it as both its height and its exclusive zone — so the whole
    // horizon moves together and nothing needed a second edit. The extra
    // 12 px is what buys the Row a reflection and the hover caption a line to
    // live on; at 72 the dock had to choose between them, which is why the
    // icons were 24 px dots.
    readonly property int chromeH:     84   // the whole horizon zone, and the
                                            // exclusive zone: windows stop here
    readonly property int seamH:        3   // the resting hairline at the edge
    // 168, was 116. The owner: "it doesn't go all the way to the top either."
    // It did not: at 116 with half the item hanging off the bottom edge, the
    // paint occupied the lower 58 px of an 84 px bar and the top third was
    // always dead glass. Now the visible half is exactly `chromeH`, so the
    // seam fills the pane it lives in. The vignette still puts the brightest
    // part at the screen edge — that is the half hanging below, and it is
    // unchanged.
    readonly property int paintH:     168   // the Swirl item; half hangs below
                                            // the screen so the paint is
                                            // brightest AT the edge and only
                                            // fades upward

    // ── spacing · a 4px grid ─────────────────────────────────────────
    readonly property int s1:   2
    readonly property int s2:   4
    readonly property int s3:   6
    readonly property int s4:   8
    readonly property int s5:  12
    readonly property int s6:  16
    readonly property int s7:  20
    readonly property int s8:  24
    readonly property int s9:  32
    readonly property int s10: 40

    // ── radii ────────────────────────────────────────────────────────
    // A surface is rounded only where it is FREE. Where it meets the
    // horizon (or a screen edge) it is flush: r0.
    readonly property int r0:   0
    readonly property int r1:   8
    readonly property int r2:  14
    readonly property int r3:  22
    readonly property int rFull: 999

    // The chamfer is NOT a Theme token. It is a setting, and it lives in
    // Prefs.panelChamfer — Prefs reads Theme, so a Theme that read Prefs
    // back would close a singleton cycle. Surfaces take it from there.

    // ── type ─────────────────────────────────────────────────────────
    // Seven sizes. Not eight. The old shell had twelve, most of them one
    // pixel apart, none of them chosen.
    //
    // SIX FACES, and the shell may not invent a seventh. The app layer has
    // carried six since the graffiti set landed (`nyxus_palette.py`:
    // FONT_GRAFFITI / FONT_SCRIPT / FONT_TECH alongside Inter, Inter Display
    // and JetBrainsMono) while this file knew only four — and of those four it
    // used two: measured 2026-08-10, `fUi` 129 sites to `fUiTitle` 10, against
    // an app layer that runs Inter Display 59 to Inter 14. Same palette, and
    // the shell still did not sound like the apps, because a build's voice is
    // its type as much as its colour. These are the SAME six the apps use, in
    // the same roles, so a headerbar and a bar label are one system.
    //
    // ⛔ Every family below is RESOLVED against what is actually installed.
    // A family Qt cannot find is not an error — it silently falls back to
    // whatever the platform picks, which is how a display face becomes
    // DejaVu on one machine and nobody notices until a photograph. `fIcon`
    // has been resolved since the Font Awesome major moved under it and
    // turned every status glyph into an empty box; the other five now get
    // the same treatment, each with a sibling to degrade to rather than a
    // guess. `fam()` returns the first installed candidate, and the last
    // candidate in every list is a face the base system is certain to have.
    function fam(want) {
        const have = Qt.fontFamilies();
        for (let i = 0; i < want.length; ++i)
            if (have.indexOf(want[i]) >= 0) return want[i];
        return want[want.length - 1];
    }

    // The workhorse. Every label, every menu row, every body string.
    readonly property string fUi:      fam(["Inter", "Inter Variable",
                                            "Adwaita Sans", "Cantarell", "sans-serif"])
    // Titles, headers and anything the eye lands on FIRST. Inter Display is
    // Inter's tight-tracked optical sibling — at 20px and up it is visibly
    // less loose, which is the whole reason the apps lead with it.
    readonly property string fUiTitle: fam(["Inter Display", "Inter",
                                            "Adwaita Sans", "sans-serif"])
    // Numerals and anything that must not reflow as its value changes:
    // clocks, meters, percentages, byte counts. Tabular by construction.
    readonly property string fNum:     fam(["JetBrainsMono Nerd Font", "JetBrainsMono NF",
                                            "JetBrainsMono Nerd Font Mono", "Adwaita Mono",
                                            "monospace"])
    // Status glyphs. The ISO and the machine you preview on do not always
    // carry the same Font Awesome major, and a family that is not there
    // renders EVERY status glyph as an empty box — a bar that looks broken
    // for a packaging reason.
    //
    // ⛔ THE FACE, NOT JUST THE FAMILY (TRK-2823, measured 2026-08-24).
    //   Font Awesome Free ships its regular and its solid weights as TWO
    //   SEPARATE FILES, and fontconfig gives the solid file TWO family
    //   names. On this host and on the ISO (`otf-font-awesome`, currently
    //   the 7 series) `fc-list` reports exactly:
    //       fa-regular-400.woff2: Font Awesome 7 Free:style=Regular
    //       fa-solid-900.woff2:   Font Awesome 7 Free,
    //                             Font Awesome 7 Free Solid:style=Solid,Regular
    //   So "Font Awesome 7 Free" is ONE family holding TWO FACES, and a
    //   `Text` at DEFAULT WEIGHT resolves the REGULAR one — 362 glyphs
    //   against solid's 2009. It is a STYLE miss, not a missing family,
    //   which is why it was invisible to every check: the family really was
    //   installed and really did resolve.
    //   Every solid-only code point then falls through Qt's per-glyph
    //   fallback and lands on JetBrainsMono Nerd Font, whose PUA blocks are
    //   (derived here with fontTools `getBestCmap()`, not quoted):
    //       fa      ed00–f2ff   1475 glyphs   (U+F2FF = fa-magento)
    //       linux   f300–f381    130 glyphs
    //       oct     f400–f533    308 glyphs   (U+F533 = oct-bookmark_slash)
    //     and NOTHING above U+F533.
    //   That map predicts the two different symptoms exactly, and the
    //   render before this change matched it:
    //     · `f519` is inside the OCTICON block — `oct-sort_asc` — so it
    //       drew a confident WRONG MARK, an ascending-sort glyph where a
    //       Font Awesome mark belonged. A wrong mark, not a box, is the
    //       dangerous half: nothing looks broken.
    //     · `e06c` `f8cc` `f7c2` `f53f` `f3ed` `f625` `f390` are absent
    //       from that font at any code point, so they drew TOFU.
    //   Meanwhile `fc-query` reported every one of them present in
    //   fa-solid-900. **fontconfig said yes and the screen said no**,
    //   because fontconfig was answering about the FILE and Qt was
    //   answering about the FACE it picked out of the family.
    //   The unambiguous "… Free Solid" name — the second family fontconfig
    //   puts on the solid file, and the one that selects that face with no
    //   weight involved — was already in the list, dead last, where it
    //   could never be reached.
    //
    //   So: SOLID NAMES FIRST, newest major first (the ISO tracks Arch's
    //   `otf-font-awesome`, which is the 7 series today). The bare family
    //   names are kept BELOW them as a degrade path for a host that ships
    //   only the regular file; drawing the regular face is still better
    //   than drawing nothing. `FontAwesome` is the FA4 single-file name,
    //   which is solid by construction and needs no suffix.
    //
    //   ⚠ A FAMILY NAME, NOT A WEIGHT TOKEN, AND THAT WAS MEASURED.
    //   The obvious alternative fix is to pair `fIcon` with a weight, since
    //   the call sites that already set `font.weight: Font.Black`
    //   (TogglePill.qml, SliderRow.qml) were never broken. That is NOT
    //   needed and would be worse — it would put the burden on ~30 call
    //   sites and break the next one that forgets. Measured instead:
    //   `Qt.fontFamilies()` on this host returns "Font Awesome 7 Free
    //   Solid" as its OWN entry among 564 families, and a `Text` in that
    //   family at DEFAULT WEIGHT — no `font.weight` set at all — draws all
    //   eight of the code points above as their correct marks, where the
    //   bare family at the same default weight draws one wrong mark and
    //   six boxes. The family name alone selects the face, so no call site
    //   has to know anything.
    //   Proof: docs/proof/theme-tokens-0824/ — `family-glyph-ab.png` is
    //   that side-by-side, and `look-row-before-after.png` is the live
    //   Settings › About "Look" row (`f53f`, palette) going from a crossed
    //   box to a palette with nothing changed but this list.
    readonly property string fIcon:    fam(["Font Awesome 7 Free Solid",
                                            "Font Awesome 6 Free Solid",
                                            "Font Awesome 5 Free Solid",
                                            "Font Awesome 7 Free",
                                            "Font Awesome 6 Free",
                                            "Font Awesome 5 Free",
                                            "FontAwesome"])
    // ── the three character faces ────────────────────────────────────
    // These ship in the profile at usr/share/fonts/nyxus/ and are the
    // build's accent voices. They are RARE BY RULE: a character face used
    // twice on one surface stops being character and becomes noise. One per
    // surface, maximum, and never on anything the user has to read at speed.
    //
    // Spray-paint wordmark. The product's own name and nothing else —
    // this is a signature, not a heading style.
    readonly property string fMark:    fam(["Permanent Marker", "Inter Display",
                                            "Inter", "sans-serif"])
    // Handwriting. Greetings and human flourishes — a welcome line, a
    // sticky note. Never a control, never a value, never a system string.
    readonly property string fScript:  fam(["Caveat", "Inter Display",
                                            "Inter", "sans-serif"])
    // Chunky techno numerals. The BIG readouts only — a lock-screen clock,
    // a gauge centre. Its lowercase is weak and its digits are wide, so it
    // earns its place at display size and nowhere below it.
    // The colour-emoji face. A TOKEN and not a literal, because 13q21's rule
    // is that nothing in the shell writes a font family — the first cut of
    // EmojiPicker.qml did, twice, and the gate caught it. `noto-fonts-emoji`
    // is in BOTH package tiers, so the first name always resolves on a real
    // install; the fallbacks are for a dev host that has a different emoji
    // font, and the last resort is fUi, which will draw the code point in
    // whatever monochrome face covers it rather than drawing tofu.
    readonly property string fEmoji:   fam(["Noto Color Emoji", "Noto Emoji",
                                            "Apple Color Emoji", "Segoe UI Emoji",
                                            "sans-serif"])

    readonly property string fTech:    fam(["Orbitron", "JetBrainsMono Nerd Font",
                                            "Adwaita Mono", "monospace"])

    // What actually resolved, for the gate and for anyone reading a log.
    // A missing face is a packaging bug that is invisible on screen — it
    // just looks slightly wrong — so it gets printed rather than guessed at.
    readonly property var fResolved: ({
        ui: fUi, title: fUiTitle, num: fNum, icon: fIcon,
        mark: fMark, script: fScript, tech: fTech
    })

    // One rung ABOVE display, and it has exactly one tenant: the desk
    // clock chip, which is read across a room rather than at the screen.
    // It was a bare `64` in Widgets.qml — the only size in the shell that
    // had escaped this ladder, which is how a ladder quietly stops being
    // one. Nothing else may take it without a reason written here.
    readonly property int tJumbo:   64
    readonly property int tDisplay: 30
    readonly property int tTitle:   20
    readonly property int tHead:    15
    readonly property int tBody:    13
    readonly property int tLabel:   12
    readonly property int tCaption: 10
    readonly property int tMicro:    9
    // 1× panel: FreeType native glyphs, not Qt's distance-field raster.
    // Fractional scale would prefer QtRendering; this machine is scale 1.
    readonly property int textRender: Text.NativeRendering
    readonly property int textHint: Font.PreferFullHinting

    // ── weight ───────────────────────────────────────────────────────
    // Four weights, named by their job rather than their number, because
    // "600" at the call site tells you nothing about why. Inter ships the
    // whole range; the fallbacks synthesise, which is another reason the
    // resolution above matters.
    readonly property int wBody:   Font.Normal     // 400 — running text
    readonly property int wLabel:  Font.Medium     // 500 — labels, menu rows
    readonly property int wStrong: Font.DemiBold   // 600 — headers, active tab
    readonly property int wTitle:  Font.Bold       // 700 — titles, wordmarks

    // The system's own voice: uppercase, wide-tracked, quiet. Used for
    // anything the system says ABOUT ITSELF, never for user content.
    readonly property real trackMicro:  1.4
    readonly property real trackTitle: -0.4
    // Display type is set LOOSER than title type on purpose: at 30px the
    // negative tracking that tightens a 20px title starts closing counters.
    readonly property real trackDisplay: -0.2
    // The character faces are drawn, not fitted, and tracking them like a
    // UI face is what makes a display font look like a mistake. Marker and
    // script want air; Orbitron is already wide and wants none.
    readonly property real trackMark:    0.6
    readonly property real trackTech:    0.0
    // A script face must NEVER take the negative tracking that tightens a
    // UI title — the letters are joined, and pulling them together closes
    // the joins into a smear.
    readonly property real trackScript:  0.0

    // Caveat's x-height is roughly three-quarters of Inter's at the same
    // pixel size, so a greeting set at `tDisplay` next to a clock set at
    // `tDisplay` reads a size and a half smaller than it measures. Script
    // sites multiply by this instead of hardcoding a bigger number, so the
    // relationship survives a change to the size ladder.
    readonly property real scriptScale: 1.34

    // ── motion ───────────────────────────────────────────────────────
    // One physical system. Exits are faster than entrances on purpose:
    // an entrance is information being delivered, an exit is latency.
    readonly property int durInstant:   90
    readonly property int durQuick:    150
    readonly property int durBase:     260
    readonly property int durRise:     340
    readonly property int durSink:     200
    readonly property int durSettle:   640
    readonly property int durCeremony: 900

    // Cubic-bézier control points for `easing.bezierCurve`.
    readonly property var curveRise: [0.16, 1.00, 0.30, 1.00, 1, 1]
    readonly property var curveSink: [0.55, 0.00, 0.85, 0.15, 1, 1]
    readonly property var curveMove: [0.62, 0.00, 0.20, 1.00, 1, 1]
    // 4% overshoot. CONFIRMATIONS ONLY — a toggle committing, a value
    // landing. Never on anything the user did not just cause.
    readonly property var curveSnap: [0.30, 1.42, 0.55, 1.00, 1, 1]

    readonly property int riseDist: 14   // how far small things travel up

    // ── elevation · light, never shadow ──────────────────────────────
    // On a near-black desktop a drop shadow is invisible, and faking one
    // gives a dirty smudge. Things nearer to you EMIT MORE LIGHT.
    // Read by Pane.qml as (rim intensity, bloom radius in px).
    readonly property real e0Rim: 0.38;  readonly property real e0Bloom:  0
    readonly property real e1Rim: 0.58;  readonly property real e1Bloom:  0
    readonly property real e2Rim: 0.88;  readonly property real e2Bloom: 20
    readonly property real e3Rim: 1.10;  readonly property real e3Bloom: 34

    // ── the rim as a STATE CUE · dispersion gain (TRK-3546) ──────────
    // The elevation ladder above says how BRIGHT a surface's rim is. This
    // says how WIDELY that surface splits the one sweep — its refractive
    // index, not its colour. See shaders/pane.frag's header for why the
    // gain and never a hue bias: a bias gives every pane its own lamp and
    // breaks MirrorEdge.qml's one-light rule; a gain keeps one lamp and
    // changes only how good a prism each surface is.
    //
    // rimDisp0 is 1.0 and must stay 1.0 — it IS the shipped rim, and every
    // resting surface in the build sits exactly there. Only the two deltas
    // are the owner's dial:
    //
    //   rimDispGain  how far attention (focus, or a `live` surface) pushes
    //                the spread toward the sweep's ends.
    //   rimDispDrop  how far dormancy pulls the spread toward the middle.
    //                Held smaller than the gain on purpose: a sleeping
    //                surface should recede, and a receding cue that shouts
    //                is a contradiction.
    //
    // ⚠ BOTH SHIP AT ZERO, AND THAT IS DELIBERATE. The owner rules on look,
    // so this lands as a mechanism and a comparison, not as a change to his
    // desktop. At 0.00 / 0.00 the rim is byte-identical to before TRK-3546 —
    // measured, not assumed: docs/proof/rim-0831 frame A has LIVE and DORMANT
    // differing from RESTING by max 0 of 255 across the whole card.
    //
    // docs/proof/rim-0831/SHEET-rim-states.png is the ruling sheet. Measured
    // on its bare row, LIVE against RESTING (the pure cue — `live` moves only
    // the spread, where focus also moves brightness):
    //
    //     0.00 / 0.00   max delta   0 of 255      the shipped rim
    //     0.30 / 0.18   max delta  12 of 255      RIM's recommendation
    //     0.75 / 0.45   max delta  30 of 255      pushed
    //
    // Reach at 0.30 (left edge, n = (-1, 0)): resting sweep position 0.146
    // (teal into azure), attended 0.079, dormant 0.221. None of the three
    // leaves the five shipped stops, at any setting, because the gain only
    // ever samples the sweep.
    readonly property real rimDisp0:    1.00
    readonly property real rimDispGain: 0.00
    readonly property real rimDispDrop: 0.00

    // A Pane's bloom is drawn OUTSIDE its rectangle, so every window that
    // hosts a blooming surface has to be bigger than the surface or the glow
    // gets sliced off at the window edge — which is what made the flyout look
    // like it was tucked under the taskbar. Windows pad by this on every free
    // side and mask their input back to the surface.
    readonly property int bloomPad: 24

    // ── THE OSD'S GAP FROM THE SCREEN EDGE ──────────────────── TRK-4133 ──
    // The volume/brightness card now pins to a screen edge instead of dead
    // centre. This is the gap from that edge to the CARD, not to the window:
    // the window is the card plus `bloomPad` on every free side, so the
    // margin below is measured on top of that padding and the card's own
    // glass lands `osdEdgeGap` in from the bezel.
    //
    // 20 rather than a token like s6 because this is a bezel offset, not
    // layout rhythm — it wants to read as "just off the edge", close enough
    // to feel anchored to the side of the screen rather than floating in the
    // left third of it.
    readonly property int osdEdgeGap: 20

    // ── reactive swirl (AUDIT-PLAN item 5's living light) ────────────
    // The liquid paint inside panels is Swirl.qml; its user-facing knobs
    // (enable / intensity / music pulse) are REAL settings in the control
    // center, bridged live through Prefs.qml — not theme tokens, so they
    // deliberately do not live here.

    // ── metrics ──────────────────────────────────────────────────────
    readonly property int barHeight:    52
    readonly property int barMargin:    10
    readonly property int iconSize:     26
    readonly property int gap:          10

    // ═════════════════════════════════════════════════════════════════
    //  THE DECK — added 2026-08-05, appended rather than woven in so the
    //  block above stays diffable while other agents are in this file.
    //
    //  The owner's report was that the chrome reads "too plain, too bla,
    //  like there's not a lot happening". Photographed at 2× against a
    //  wallpaper, the reason is specific and it is not the colour: the
    //  horizon zone had no TOP. The Shelf fades from transparent to black
    //  with nothing marking where it begins, the icons are 24 px at 0.70
    //  opacity, and the only chroma in 72 px of screen is a 3 px hairline at
    //  the very bottom. There is no surface — which is why it reads as an
    //  unfinished area of desktop rather than as a designed object.
    //
    //  The Deck is the answer, and it is still not a panel: no rectangle, no
    //  border, no corners. It is a top EDGE made of light (the Crown), a
    //  little more body under it, and enough room for the Row to have
    //  presence. HORIZON §2's "objects resting on a shelf" only works if you
    //  can tell there is a shelf.
    // ═════════════════════════════════════════════════════════════════

    // The Crown: the chrome's top edge. One hairline of the sweep plus a
    // short falloff under it. This is the single change that turns the zone
    // from a fade into a surface, and it costs two rectangles.
    // Built the same way the seam is — stacked hairlines of the sweep, each
    // wider and fainter than the last — so the zone is bracketed top and
    // bottom by the same construction. The first attempt put a DARK band
    // under the crown instead, on the theory that the edge needed body; over
    // a wallpaper that read as a hard grey step across the screen, which is
    // the one thing §2 says this chrome does not have. Elevation is light:
    // the lip glows, it does not darken.
    readonly property real crownRest:    0.30   // idle
    readonly property real crownLive:    0.62   // pointer in the zone

    // ── the Row · the Prism Dock ─────────────────────────────────────
    // Icons were 24 px and dimmed to 0.70 when idle, which is what "dots"
    // meant. A dock icon is the thing you aim at; it is allowed to be the
    // biggest thing in the chrome after the clock.
    readonly property int  dockIcon:      30
    // TRK-3557 — 54 -> 48. The SLOT tightens; `dockIcon` stays 30 on purpose.
    // Theme.qml § THE DECK records 24 px icons being called "dots" and "too
    // plain, too bla" (owner, 08-05), so shrinking the icon is a road already
    // walked and rejected. Closing the gap around it groups the dock without
    // making anything smaller.
    readonly property int  dockSlot:      64
    readonly property real dockIdle:      0.86
    // The Reflection: each icon's own light falling into the seam below it.
    // Kept well under half the icon's height — a full mirror reads as a
    // gimmick, a third of one reads as a lit floor.
    readonly property real reflectH:      0.46
    readonly property real reflectAlpha:  0.30
    // Magnification, the one piece of vocabulary borrowed outright from the
    // macOS dock, because it is the correct solution to "which one am I
    // about to hit" and nobody has beaten it in twenty five years. Restrained
    // on purpose: the reference bounces to 2×, which on a 30 px icon in a
    // 72 px zone would have nowhere to go.
    readonly property real magHover:      1.26
    readonly property real magNeighbour:  1.10
    readonly property int  dockLift:      5

    // ── motion · legacy names ────────────────────────────────────────
    // Kept so nothing breaks mid-refactor; they now point at the Horizon
    // scale. Use dur* in new code and retire these as files are converted.
    readonly property int animFast:    durQuick
    readonly property int animMed:     durBase
    readonly property int animSlow:    durRise

    // ══ NYXUS-THEME-GENERATED-BEGIN ══ scripts/build-theme.sh ══════════
    // GENERATED by scripts/build-theme.sh from theme/accent.json `_tokens`.
    // DO NOT HAND-EDIT between the markers — the next run overwrites it. Edit
    // `_tokens` (or the `_paint_layers` stops it derives from) and re-run.
    //
    // SCOPE OF THE BYTE-IDENTITY CLAIM. The generator owns the theme VALUES in
    // its own target list and NOTHING ELSE. It writes both trees for every
    // twinned target and asserts they match. It does not read, write or verify
    // the other ~328 hand-maintained files under
    // artifacts/api-server/nyxus-scripts/. A green build-theme.sh means the
    // GENERATOR'S OWN outputs agree — it does NOT mean the two trees agree, and
    // it does not lift the two-copy rule.
    //
    // NOT EMITTED, deliberately, so that no surface is silently skipped:
    // AGS/Astal SCSS (no such surface — the bar is Quickshell) · a Kvantum theme
    // (packaged, but a 9-patch SVG cannot be authored blind — OWED) ·
    // shell/shaders/*.frag (they take uniforms from Theme.qml).
    // Names are `token*` on purpose: the hand-written accent
    // properties above (accentSolid, glassBorder, …) still carry
    // HORIZON reasoning and their retrofit onto these tokens is
    // task 11, not task 0.

    // accent roles — glacier[i], rev 3 §1.2
    readonly property color tokenAccentInteractive:  lookLayer[0]
    readonly property color tokenAccentDeep:         lookLayer[3]
    readonly property color tokenAccentHairline:     lookLayer[4]
    readonly property color tokenAccentPrimary:      lookLayer[5]
    readonly property color tokenAccentPeak:         lookLayer[6]
    readonly property color tokenAccentPinned:       plum

    // ambient clamp — COMPLETION_SPEC §3, owner Ruling 2. NOT void.
    // peak_luminance_max is enforced NOWHERE today: swirl_view.frag
    // clamps saturation and alpha but not luminance. Carrying the
    // number is not enforcing it.
    readonly property color tokenAmbientScrim:       Qt.rgba(0.0196, 0.0235, 0.0392, 0.55)   // rgba(5, 6, 10, 0.55)
    readonly property real  tokenPeakLuminanceMax:   0.45
    readonly property real  tokenSaturationMax:      0.7
    readonly property real  tokenFocusDeferOpacity:  0.4

    // the follow hook — PRESENT, NOT WIRED. Reading it changes
    // nothing today; it exists so enabling follow later is a switch
    // and not a rewrite. Owner 2026-08-19: the interface derives from
    // glacier and is LOCKED; selecting a layer repaints the PAINT only.
    readonly property bool  tokenFollowEnabled:      false
    readonly property string tokenFollowSource:      "static"
    readonly property string tokenFollowLayer:       "glacier"
    readonly property int   tokenFollowDebounceMs:   400
    // ══ NYXUS-THEME-GENERATED-END ══

    // ── helpers ──────────────────────────────────────────────────────
    // `sweep(item)` and `rampOf(stops, item)` return a Gradient suitable for
    // a Rectangle's `gradient` property. Use these instead of a flat `color`
    // anywhere the shape is bigger than a few pixels.
    function gradientStops(stops) {
        var out = [];
        for (var i = 0; i < stops.length; ++i)
            out.push({ position: i / (stops.length - 1), color: stops[i] });
        return out;
    }

    // Fade a ramp toward transparent — for glows and corner-bleed.
    function soften(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    // Blend two colours, `t` 0 → a, 1 → b. Alpha travels with them, so this
    // is safe on softened values. Added for `Pool.coreTone`, where a pool's
    // broad wash and its hot core can be two different hues and the bands
    // between them have to be the mixture rather than a hard step. With the
    // two arguments equal it is the identity, which is what keeps every
    // existing Pool caller byte-for-byte what it was.
    function mix(a, b, t) {
        var u = Math.max(0, Math.min(1, t));
        return Qt.rgba(a.r + (b.r - a.r) * u,
                       a.g + (b.g - a.g) * u,
                       a.b + (b.b - a.b) * u,
                       a.a + (b.a - a.a) * u);
    }

    // HORIZON's coordinate system: hue is a function of HORIZONTAL POSITION.
    // The paint shader already works this way (swirl_paint.frag: hue = x/aspect
    // + jitter), so anything drawn in the chrome that wants to agree with the
    // light under it asks here. Left of screen is teal, right is plum, at every
    // scale, on every surface — which is why you can tell where something
    // happened from its colour.
    function sweepAt(f) {
        var stops = lookSweep;
        var n = stops.length - 1;
        var x = Math.max(0, Math.min(1, f)) * n;
        var i = Math.floor(x);
        if (i >= n) return stops[n];
        var t = x - i;
        var a = (stops[i].r !== undefined) ? stops[i] : Qt.color(stops[i]);
        var b = (stops[i + 1].r !== undefined) ? stops[i + 1] : Qt.color(stops[i + 1]);
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, 1.0);
    }
}
