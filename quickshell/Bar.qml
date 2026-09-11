// Nyxus Suxyn — THE HORIZON. The only permanent chrome in the desktop.
//
// docs/DESIGN_LANGUAGE_HORIZON_2026-08-03.md is the reasoning. In short:
// there is no bar. The bottom edge of the screen is a lit seam made of the
// living paint, full width, flush, cornerless; above it the screen darkens
// into a soft shelf; the system's persistent content rests on that shelf
// unboxed. No panel rectangle exists, nothing floats, there is no container
// to see. Everything transient rises out of this line and sinks back into it.
//
// What lives here, left to right:
//   the Sigil   the aperture + wordmark. This is Start.
//   the Row     pinned apps merged with REAL open windows (Tasks.qml). State
//               is shown as light in the seam beneath an icon, never as a
//               chip behind it.
//   the Desks   the live workspace strip — segments OF the seam, not dots.
//   the Tray    StatusNotifier items, and the removable-drive chip when
//               UsbWatch has a stick or card (eject from the Line).
//   the Gauge   vitals, the Crest (one adaptive slot — §5.3), and the clock.
//
// And two behaviours that only make sense because the seam is alive:
//   the Wake    paint runs toward the pointer as it enters the chrome zone
//   the Tell    every meaningful event drops paint at the x where it belongs;
//               hue is a function of x inside the shader, so the colour is
//               right for free.
//
// ── 2026-08-05 · the Deck ───────────────────────────────────────────────
// The owner's report was "too plain, too bla, like there's not a lot
// happening". Photographed at 2× over a wallpaper, the cause was specific and
// it was not the colour:
//
//   1. The zone had NO TOP. The Shelf faded from transparent to black with
//      nothing marking where it began, so 84 px of screen read as an
//      unfinished area of desktop rather than as a surface things rest on.
//      §2 calls this "objects on a shelf" — which only works if you can tell
//      there is a shelf. That is the Crown.
//   2. The Row was five 24 px icons at 0.70 opacity. At arm's length those
//      are dots. They are now 30 px, near-opaque, they REFLECT into the seam
//      below them, and they magnify under the pointer.
//   3. The only chroma in the whole zone was a 3 px hairline at the very
//      bottom. Light now also comes from under whatever is running, focused
//      or hovered — the Pool — which is HORIZON's own "state lives in the
//      seam" rule finally drawn at a size you can see.
//   4. Two thirds of the bar was empty while the tray and the workspace
//      strip did not exist at all. Both are real data and both are here now.
//
// What did NOT change, deliberately: the Swirl block below, its solver
// tuning, and the resting seam hairlines. That is the reactive-paint lane
// (HANDOFF, agent B) and the owner's standing instruction is that the swirls
// inside the bar are finished. Nothing here writes to them; the Deck is drawn
// around them.
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Io
import QtQuick
import QtQuick.Effects

PanelWindow {
    id: bar

    // ── icon size, bar-local ────────────────────────────────────────────────
    // Owner 2026-09-07: "can we make all the icons on the left and right side
    // a little bigger".
    //
    // ⚠ NOT `Theme.dockIcon` ITSELF. That token is read 31 times by
    // Launcher.qml, so moving it would enlarge every icon in the Start menu to
    // fix the bar. These are derived FROM it so the bar still tracks the
    // theme's scale — one step up, not a new invented number.
    readonly property int barIconPx:  Math.round(Theme.dockIcon * 1.40)   // 30 -> 42
    readonly property int barTrayPx:  20                                   // was 17
    readonly property int barTrayCell: 23                                  // was 20

    // Flush to three edges. Not inset, not floating, no margins: the chrome
    // IS the screen edge. `exclusiveZone` covers the whole zone, so a
    // maximised window stops where the shelf begins and never sits under it.
    anchors { left: true; right: true; bottom: true }

    // ── THE TOP-EDGE DISSOLVE ────────────────────────────────────────
    // Height, in px, of the band ABOVE the old top edge over which the
    // material ramps out to nothing. The owner's brief: "roughly 20–30 px
    // above the bar's top edge and fully gone by then… if in doubt, go
    // shorter."
    //
    // ⚠ THE SURFACE GROWS BY THIS. THE EXCLUSIVE ZONE MUST NOT.
    // `implicitHeight` and `exclusiveZone` are independent properties, and
    // this window has always pinned the zone explicitly rather than letting
    // it be derived — which is the only reason growing the surface is free
    // here. If the zone were ever allowed to follow the height, every
    // window on the screen would be pushed down by the dissolve.
    //
    // Opaque navy cannot dissolve: alpha is 1, so a 24 px reach is just a
    // taller plate (108 vs 84) and Start's 12 px air sits inside it. This
    // compositor discards additive paint, so the bed stays opaque and the
    // reach stays 0. Additive + 24 is the other branch.
    //
    property bool paintOpaque: false
    property int dissolveH: 0
    // Owner 2026-09-10: the bar has to read as the same glass as the
    // widget chips. Lip on — the 08-18 exception (no top boundary) is
    // what made it a dark strip instead of a pane.
    property bool keepLip: true
    // Air above the chrome so the dock name can pop up like a lyric
    // and not sit inside the stone. Exclusive zone stays chromeH.
    readonly property int captionAir: 22
    // Same air between every icon and its fall. Sigil used 0 (touching);
    // dock used the gem box which looked gapped. One number.
    readonly property int reflectGap: Theme.s4
    implicitHeight: Theme.chromeH + bar.dissolveH + bar.captionAir
    exclusiveZone: Theme.chromeH
    exclusionMode: ExclusionMode.Normal
    color: "transparent"
    WlrLayershell.namespace: "nyxus-bar"
    property bool zoneLive: false
    readonly property int zPaint: 1
    readonly property int zChrome: 2

    // ══ THE FLIP · TRK-3698 ═════════════════════════════════════════════
    // Owner 2026-09-01: "the bar flip to the other said showing the graphgs
    // when music is playing then when it stops it flip back to the normal
    // side."
    //
    // 0 is the bar you know. 180 is the analyser. The bar's MATERIAL — the
    // Shelf, its dissolve, the Line's living paint, the GlassEdge and the
    // resting seam hairlines — is on neither face: it is the panel itself,
    // and it does not turn. That is his "those graphs inside the bar still".
    //
    // ⚠ REVERSIBILITY IS STRUCTURAL, NOT CAREFUL CODING. `flipAngle` is a
    // BINDING on `musicUp`, never an assignment. There is no state machine,
    // no latch and no completion callback that could be missed, so there is
    // no sequence of events that can strand the bar edge-on or leave the
    // back face up over silence: whatever happens, the moment `musicUp` is
    // false the binding's target is 0 and the Behavior walks it there from
    // wherever it actually is. A shell restarted mid-rotation comes up at 0
    // because that is what the binding evaluates to. The owner looks at
    // this surface all day; "it cannot get stuck" had to be a property of
    // the shape, not a promise.
    //
    // THE TRIGGER IS AUDIBLE AUDIO, NOT METADATA. `Beat.hot` is
    // `havePlayback && engine-hot` — a real sink-input AND a measured level
    // above the engine's own floor. A paused player still publishes MPRIS
    // metadata and `Sys.playerHasTrack` stays true for it; that is exactly
    // the trigger this must not use. `spectrum.length` is the second half:
    // the engine sends an EMPTY array when there is nothing to draw, so the
    // bar cannot turn over to show a flat line.
    // TRK-3711 — and `Prefs.barSpectrum` is FIRST in the AND on purpose:
    // with the visualiser switched off, this whole expression short-circuits
    // before it reads `Beat` at all, so nothing here can hold a binding on
    // the engine's output for a surface that is never going to turn over.
    readonly property bool _musicRaw: Prefs.barSpectrum
                                      && Beat.hot && Beat.spectrum.length > 0

    // ══ THE HYSTERESIS · TRK-3714 ═══════════════════════════════════════
    // Owner 2026-09-01, having lived with round 1: "the bar was doing some
    // weird stuff trying to flip on its own or something too".
    //
    // He is right and `_musicRaw` above is why. It is a three-term AND over
    // signals that are NOT stable on the timescale of a 700 ms rotation:
    //
    //   · `Beat.havePlayback` is re-polled every 500 ms out of
    //     nyxus-beat-tap.sh. ANY sink-input counts — a notification chime, a
    //     browser tab autoplaying two seconds of an advert, a video call
    //     opening the sink. One poll of it is enough to start the turn.
    //   · `Beat._engineHot` follows the engine's own HOT_HOLD (2.0 s), so it
    //     falls two seconds after real audio stops — but `havePlayback` can
    //     fall FIRST, and when it does `hot` and `spectrum.length` both go
    //     false in the same frame.
    //   · `Beat.spectrum` is emptied by Beat.qml the instant `hot` is false.
    //
    // So a single 500 ms poll that momentarily saw no sink-input — a track
    // change, a player re-opening the sink, a pause between two songs —
    // drove the raw value false, the Behavior started walking 180 → 0, and
    // the next poll drove it straight back. That is exactly "trying to flip
    // on its own": a panel caught mid-rotation, turning both ways.
    //
    // ⚠ THE SHAPE IS STILL STRUCTURAL, WHICH WAS THE WHOLE POINT OF THE
    // ORIGINAL BINDING. This is NOT a latch and NOT a state machine: there
    // is no completion callback, no flag, no sequence of events that can
    // strand the bar. The timer's `running` condition IS the disagreement
    // between what the audio says and what the bar is showing — so whenever
    // the two differ, a timer is by definition running that will reconcile
    // them, and whenever they agree there is no timer at all (idle costs
    // nothing, which is the other standing rule). If the raw signal flips
    // back before the timer fires, `running` goes false on its own and the
    // wait is discarded: the delay is therefore a requirement for SUSTAINED
    // audio, not a debounce that could accumulate.
    //
    // ⚠ AND THE PREF IS EXEMPT. Turning the visualiser off in Settings is a
    // DELIBERATE act, not a noisy measurement, so it turns the bar back at
    // once rather than after the fall delay. A user who unticks a box and
    // watches nothing happen for two seconds concludes the box is broken.
    //
    // The two delays are asymmetric on purpose:
    //   RISE 900 ms   — longer than one 500 ms tap poll, so a chime or a
    //                   two-second advert cannot turn the bar over at all.
    //   FALL 1800 ms  — on top of the engine's own 2.0 s HOT_HOLD, so the
    //                   bar tolerates ~3.8 s of silence before it turns
    //                   back. Measured inter-track gaps on his library sit
    //                   under 2 s; album gaps go to 3. This is the number
    //                   most likely to want tuning and it is one constant.
    readonly property int flipRiseMs: 900
    readonly property int flipFallMs: 1800

    property bool musicUp: false
    onMusicUpChanged: Bus.barMusicUp = musicUp
    Timer {
        // Runs ONLY while the audio and the bar disagree. See above.
        running: bar._musicRaw !== bar.musicUp
        interval: bar._musicRaw ? bar.flipRiseMs : bar.flipFallMs
        // ⚠ `repeat: true` IS LOAD-BEARING and is not a repeating timer in
        // any meaningful sense — it never gets a second tick, because its
        // own `onTriggered` makes `running` false. It is here because a
        // NON-repeating Timer ASSIGNS `running = false` when it fires, and
        // an assignment DESTROYS the binding above. The bar would have
        // turned over exactly once per shell lifetime and then never again,
        // with nothing in the file looking wrong. A repeating Timer never
        // touches `running`, so the binding survives.
        repeat: true
        onTriggered: bar.musicUp = bar._musicRaw
    }
    Connections {
        target: Prefs
        function onBarSpectrumChanged() {
            if (!Prefs.barSpectrum)
                bar.musicUp = false;
        }
    }

    property real flipAngle: bar.musicUp ? 180 : 0
    Behavior on flipAngle {
        NumberAnimation {
            // A panel with mass. `durCeremony` is the build's longest
            // token and this is the build's largest single gesture; at
            // `durSettle` the bar snapped over like a shutter.
            duration: Theme.durCeremony
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveMove
        }
    }

    // TRK-3085 · Owner 00:39: move on. Opaque Line + black wash was a
    // SOLID bar — no stars through it. Additive again so the Headliner
    // shows through the Shelf. Paint ground off. wash 0.
    readonly property color barBlack: Qt.rgba(0, 0, 0, 1)

    // ── the Shelf ────────────────────────────────────────────────────
    // Not a panel: a gradient. Transparent at the top, near-black at the
    // edge. This is the whole reason unboxed text stays legible over a
    // neon-noir photograph, and it costs one rectangle.
    // ⚠ THE LAST SIX ROWS OF THE SCREEN, CAPPED. Honest label: a cap, not a
    // diagnosis.
    //
    // Something paints a ~5px purple-indigo band across the very bottom
    // (measured #1e0981). It survives the seam's Swirl being set to 0 AND
    // hidden outright; it survives an opaque bar floor beneath it; and a cap
    // placed in BarSeam.qml did nothing at all — because `nyxus-bar` is a
    // SEPARATE layer-shell surface sitting ABOVE `nyxus-bar-seam`, so no z
    // value over there can reach these rows. That failure is what located it
    // to this file, and it is why the cap lives here.
    //
    // Covered at the widget's own measured body colour while the source stays
    // an open item. Whoever identifies it should delete this and fix that,
    // rather than leave two things painting the same rows.
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 6
        z: 999
        color: "#0d060d"
    }

    // ── THE TOP DISSOLVES ───────────────────────────────────────────────
    // Owner 2026-09-07: "you could start making it transpaerent the move
    // furture it goes out until thers nothing".
    //
    // ⚠ AND HIS EARLIER OBJECTION IS WHY THIS IS SHAPED THE WAY IT IS. A
    // first attempt faded the bar to black across most of its height and he
    // rejected it correctly: "i wanted it the same as the widgets not solide
    // black that beats the purpose". The bar's BODY must stay the widget
    // material. Only the top edge dissolves.
    //
    // Fading to black IS fading to nothing here, and that is measured rather
    // than assumed: the wallpaper directly above the bar reads pure #000000
    // for its whole height. So this is the desktop reaching down into the top
    // of the bar, not a coat of paint over it.
    //
    // Clear by 38%, so five sixths of the bar is untouched material. The
    // curve is front-loaded because a linear ramp on 84px reads as a grey
    // wash instead of an edge dissolving.
    //
    // ⚠ z:1 — the chrome sits at z:2, so the icons, clock and tray are not
    // dimmed by this. Raising it above 2 would grey out the dock.
    // The black fade that sat here painted the top of the bar as a slab.
    // Widget glass is panelMid + swell, not a coat of #000. Removed.

    Rectangle {
        id: shelf
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Theme.chromeH
        // Widget look on THIS window is GlassEdge + the glacier[4] seam.
        // The glass BODY and the living paint live on BarSeam underneath.
        // swellGround (α 0.84–0.93) plus panelMid (α 0.34) on this Top
        // surface blocks ~93% of that seam — TRK-3487. Shelf tokens
        // (α 0.15 / 0.20 / 0.34) let the swirls show through.
        gradient: Gradient {
            GradientStop { position: 0.00; color: Theme.shelfTop }
            GradientStop { position: 0.42; color: Theme.shelfMid }
            GradientStop { position: 1.00; color: Theme.shelfDeep }
        }
    }

    Rectangle {
        id: shelfDissolve
        anchors { left: parent.left; right: parent.right; bottom: shelf.top }
        height: bar.dissolveH
        visible: bar.dissolveH > 0
        readonly property real a: Theme.shelfTop.a
        gradient: Gradient {
            GradientStop { position: 0.0000; color: Theme.soften(Theme.shelfTop, 0) }
            GradientStop { position: 0.3333; color: Theme.soften(Theme.shelfTop, shelfDissolve.a * 0.037) }
            GradientStop { position: 0.6667; color: Theme.soften(Theme.shelfTop, shelfDissolve.a * 0.296) }
            GradientStop { position: 1.0000; color: Theme.shelfTop }
        }
    }

    // ── the paint's ground (WIP-265) ─────────────────────────────────
    // Sits between the Shelf and the Line, so the living paint has a dark
    // to be bright against again now that `LiveWall` puts a lit galaxy
    // behind the clear glass. Full reasoning at Theme § THE PAINT GROUND.
    // Height matches the visible half of the paint band, not the whole
    // Swirl item — the other half hangs off the bottom of the screen.
    Rectangle {
        visible: false
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Theme.paintH / 2
        gradient: Gradient {
            GradientStop { position: 0.00; color: Theme.paintGroundTop }
            GradientStop { position: 0.55; color: Theme.paintGroundMid }
            GradientStop { position: 1.00; color: Theme.paintGroundFoot }
        }
    }

    // ── the Line · the living paint, un-boxed ────────────────────────
    // The Swirl item is twice as tall as the visible band and hangs half off
    // the bottom of the screen. That is deliberate: the paint's own vignette
    // fades it at both ends, so hanging the lower half off-screen puts the
    // BRIGHTEST part of the field exactly at the screen edge and lets it die
    // going up. No shader change, no mask, no clip.
    Swirl {
        id: line
        // TRK-960 11:44 — dye was running UNDER the fills. Implicit z 0
        // put GlassEdge, the type scrim, the Hazes, the resting hairlines
        // and the open-menu Pools (0.85) on top of the Line. Chrome stays
        // z 2 so icons still take the click. Not a veil (WIP-783).
        // 13:35 z=3 + opaque:true covered the chrome — reverted 13:36.
        // 14:57: owner still sees no filaments. Additive (opaque false) is
        // invisible on this compositor; the navy plate at z=3 ate the icons.
        // Same opaque bed, UNDER chrome (zPaint 1 / zChrome 2). Icons stay
        // on top. If the bar goes solid navy with no icons, pull opaque off.
        z: bar.zPaint
        opaque: bar.paintOpaque
        clip: false
        // ⚠ TRK-3814 — THE PAINT IS NOT SUPPRESSED HERE, AND THE REASON IS
        // THE FINDING. A `visible: bar.flipAngle < 90` was added to this
        // Swirl to stand the living paint down behind the analyser, and it
        // was wrong twice over. It duplicated the `visible: false` fifteen
        // lines below — Qt rejects that outright with "Property value set
        // multiple times", so shell.qml could not load Bar at all and the
        // head booted to NO DESKTOP (audit item 28 caught it; `qmllint`
        // did not, because it is a parse-level error the linter reports as
        // a warning class this project's gate does not count).
        //
        // And it was aimed at the wrong object anyway. THIS Swirl has been
        // `visible: false` since TRK-3085: the comment below says it — the
        // paint the owner actually sees is drawn on **BarSeam**, its own
        // layer-shell surface under this glass, because additive blending
        // in THIS window is discarded by the compositor. Gating an item
        // that is already invisible suppresses nothing.
        //
        // So the swirl stands down behind the analyser in BarSeam.qml
        // (opacity follows Bus.barMusicUp). THIS item stays invisible.
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        // ⚠ TRANSLATED, NEVER RESIZED — and the difference is the whole
        // reason the dissolve reads as one surface thickening.
        //
        // `height` stays `Theme.paintH`. The sim and dye grids are fitted
        // from this item's ASPECT (Swirl.qml `_fit`), and the splat radius
        // is measured in units of its HEIGHT, so growing it by the reach
        // would re-grid the simulation (2304×202 → 2150×224 at 32 px) and
        // rescale every strand. The seam would not extend; it would become
        // a different field. That is exactly the "no reset, no independent
        // instance" the brief forbids, arriving through the back door.
        //
        // Moving it costs nothing. Half this item already hangs off the
        // bottom of the screen unseen, so shifting it up by the reach just
        // spends pixels that were being rendered and thrown away. Aspect,
        // both grids, the splat scale and the corner-bleed band are
        // bit-identical to what shipped. A filament crossing the old edge
        // is one filament because it is one texture read from one solver.
        anchors.bottomMargin: -(Theme.paintH / 2 - bar.dissolveH)
        height: Theme.paintH
        // The display pass ramps the top `dissolveH` px of THIS ITEM out to
        // nothing. Its top now sits exactly at the window's top, so the
        // band and the reach are the same band.
        dissolveH: bar.dissolveH
        // TRK-3085 · Owner 00:44: paint draws on BarSeam (under this glass).
        // Additive in THIS window is discarded; a second solver here is
        // cost for nothing. Wake/Tell still call feedAt/dropAt + Bus.paint;
        // the seam answers Bus.paint.
        visible: false
        intensity: Prefs.swirlIntensity
        cornerRadius: Theme.r0
        interactive: false          // the whole chrome zone feeds it — see Wake
        // THE HORIZON NEVER SLEEPS (WIP-265). With `interactive: false` the
        // Swirl's `_stimulus` can never go true, so `running` was held up
        // only by the 12 s linger — the seam painted for twelve seconds
        // after login and then stopped for good. This is the one surface in
        // the build that sets this, and Bar.qml's own note above says why:
        // it is the one lit thing on a resting desktop.
        alwaysAlive: true
        // TRK-3086 · Owner F1 23:16: bar swirls aren't there. Look-seat
        // sysfs is "Not charging". Default batterySaver then ignores
        // alwaysAlive, and interactive is false, so `_stimulus` never
        // fires and the seam dies after the 12 s linger (WIP-265 class).
        // Swirl.qml says this tenant may opt out. restOpacity 1 keeps
        // the last frame if the solver still stops (chips already do).
        batterySaver: false
        restOpacity: 1.0
        ramp: PaintMood.ramp
        sweepLo: 0
        sweepHi: 1.0
        sweepGamma: 1.0
        // ── strand size ─────────────────────────────────────────────
        // Owner, 2026-08-09: "bottom bar, can we do the same, make the swirls
        // a little smaller and not so bright when they activate."
        //
        // The knob is the same one the Start Menu and the Flyout got, but the
        // arithmetic is NOT the same, and reading the shader is what stops
        // this being a guess. swirl_splat.frag's `gauss` is
        // exp(-d² / R) with R = impulseRadius² (only x × aspect), so σ in
        // HEIGHT units is impulseRadius/√2. This item is Theme.paintH = 168 px:
        //   0.245 (ported default)  σ 29.1 px  FWHM 34.3 px
        //   0.15  (08-09 "a little smaller")  σ 17.8 px  FWHM 21.0 px
        // Owner 08-20 11:06: swirls are BACK (ambientDye 0.36) and wants them
        // "a little smaller like they were." Deposit 2.57× makes the same
        // gaussian's tails visible, so apparent width grows even at 0.15.
        // Compensating the kernel (not dropping dye to 0.14 — that emptied
        // the bar): 0.12 → σ 14.3 px, FWHM 16.8 px, _splatRadius 0.0225→0.0144.
        impulseRadius: 0.12
        // ── brightness ───────────────────────────────────────────────
        // The owner: "you really can't see the swirls" when it is lit. Exactly
        // right, and it is a CLIPPING problem, not a taste one. With the
        // full-width veil removed for the clear-glass pane, the paint arrives
        // at full exposure over a near-transparent shelf, and the filaments —
        // the entire point of the ported solver — clip to flat white. What
        // you see is a bright band where there should be structure.
        //
        // Dimming the *exposure* rather than laying a veil back over it is the
        // fix that keeps both things: the dye stops railing, so the fine
        // structure survives, and the pane stays clear. Nothing about the
        // solver, the curl, the dissipation or the presets changes — this is
        // the display stage's gain, which is what it is there for.
        // Three knobs, and they do different jobs — the first attempt moved
        // only `exposure` and barely helped, because gain is not what was
        // wrong. Dye was saturating the whole field, so there was no dark for
        // filaments to be bright AGAINST. Filaments are contrast; a uniformly
        // lit field has none, however bright it is.
        //   opacity  lets the dark glass show through between the strands, so
        //            the structure has a ground
        //   exposure stops the cores railing to white
        //   intro    the login ignition was dumping enough dye to flood the
        //            field before you ever touched it
        // Tuned against the DEFAULTS, which is the step I skipped first time
        // and paid for: `exposure` defaults to 2.05 (the reference's own
        // display exposure), not to 1.0. Setting it to 0.50 was four times
        // below the reference and the seam disappeared entirely; 0.72 still
        // looked blown only because the intro was flooding the field. Both
        // readings were mine, both were wrong, and both came from guessing at
        // a scale instead of reading it.
        //
        // 1.45 keeps the cores off the rail so the filaments survive, and
        // 0.85 opacity lets the dark glass show between the strands — which
        // is where the structure comes from. A uniformly lit field has no
        // filaments however bright it is; contrast is the whole mechanism.
        //
        // TRK-914 08-20 BV: those two numbers were tuned for ROSE filaments
        // (clipping to white on clear glass). The shipped dye is now
        // paintGlacierHorizon. CR already put sweep 0..1 in play (ice L
        // 0.694 / 0.950 plus wallpaper purple); owner on tty1 after qs
        // reload still saw no seam. qs path is repo shell, AC fully-charged
        // so `_saving` is false, alwaysAlive honoured — the solver is
        // running. What is invisible is DISPLAY: swirl_view.frag's
        // `1 - exp(-c * exposure)` then `* opacity`. Orchid-mid #a63fa1
        // (the purple that has to read on dark glass) at L 0.142:
        //   before  opacity 0.85 × exposure 1.70 → 0.182
        //   after   opacity 1.00 × exposure 2.45 → 0.294  (1.61×)
        // Ice bright #7fe8ff L 0.694: 0.589 → 0.817 (1.39×). Ice peak
        // 0.681 → 0.902 — below a white rail; rose clipping was a flooded
        // field, not one stop at 0.90. No veil; injectGain / solver untouched.
        opacity: 1.00
        // "not so bright when they activate" — the second half of the same
        // ruling. `exposure` is the display stage's gain, so it is the knob
        // that takes brightness OFF the cores without touching the solver,
        // the curl or the dissipation that give the seam its shape; and
        // `injectGain` is the one that stops a Wake stroke piling dye up
        // until the band goes uniform. Both move, for the reason Bar.qml's
        // own brightness note gives: gain alone was never what was wrong.
        // Left ABOVE the Start Menu's 0.92/0.38 on purpose — this is the
        // horizon, the one lit thing on a resting desktop, and the owner
        // asked for it dimmer, not dark.
        // 1.12 -> 1.70 (WIP-265, second pass). The first pass darkened the
        // ground under the paint and I called it fixed off a screenshot
        // taken six seconds after a hot reload — which is the middle of
        // `playIntroOnLoad`'s ignition. The intro is bright; the RESTING
        // field is not, and the owner's "gone again" came minutes later
        // when the dye had decayed to its ambient floor. The ground was
        // still worth doing, but it was never the whole answer.
        //
        // `exposure` is display gain: it brightens the dye that is there
        // without injecting more, so the ambient steady state becomes
        // visible while a Wake stroke still has headroom above it. That is
        // the knob that fixes a RESTING seam; `injectGain` would only have
        // made strokes hit harder and left the resting field exactly as dim.
        // 1.70 -> 2.45 (TRK-914, glacier ice+purple; numbers in the opacity
        // note above). 0.50 made the seam disappear (four times below the
        // reference 2.05). 2.45 is above the reference so orchid-mid reads
        // on the 0.93-alpha paint ground; not a full-surface veil.
        //
        // Owner 08-20 11:14: glacier looks better — go HARDER, not a 5%
        // nudge. Ruler `opacity × (1 − exp(−L × E))` Rec.709, opacity 1.00.
        // Field ice on glacier-altitude tops out at lin Y 0.037 — swapping
        // ice hexes onto that would DIM the glacier. Hexes stay
        // `#7fe8ff` / `#eefcff`. 2.90 → 4.35:
        //   ice #7fe8ff L 0.694  displayed 0.867 → 0.951  (L×E 2.014 → 3.021)
        //   ice #eefcff L 0.950  displayed 0.936 → 0.984  (L×E 2.755 → 4.133)
        // 2.45→2.90 was +0.049 displayed (the 5% he named). This is +0.084
        // on ice0 from 2.90, +0.133 from 2.45.
        // 4.35 -> 3.15 (0824 density, display stage, AFTER the fill knobs).
        exposure: 3.15
        // TRK-960 11:44 — next knob after exposure/ambientDye. Resting
        // deposit `ds = 0.75 * ambientDye * env * injectGain / n^0.3`.
        // Before 0.72 → ds 0.126 (env 0.65, n 1, dye 0.36). After 1.00
        // (Swirl default) → ds 0.175 (1.39×). Wake still below a 0.5 splat.
        injectGain: 1.00
        // TRK-914 08-20 CR: running is already true on tty1 (alwaysAlive,
        // AC fully-charged so `_saving` is false, swirl_enabled, qs on
        // repo shell). BV already raised display (opacity 1.00 / exposure
        // 2.45). Orchid-mid *display* curve is 0.294 at full field density
        // — that number does not move with this knob. The remaining miss
        // is RESTING DEPOSIT. Ambient stroke `ds = 0.75 * ambientDye * env
        // * injectGain / n^0.3`. Bar did not set ambientDye, so Swirl's
        // 0.14. At env 0.65 / n 1 / injectGain 0.72: ds **0.049**. After
        // 0.36: ds **0.126** (2.57×). Still below a Wake splat (~0.5).
        // `injectGain` left at 0.72 — that one also hits Wake and would
        // flood the field; Bar.qml's own note already said so.
        // 0824 DENSITY: the bar violated accent.json _swirl._technique
        // ("FILAMENTS, NOT CLOUDS ... a low-frequency density mask so most of
        // the surface stays empty"). Measured on the bottom 84 px: 7.8/9.6%
        // near-black vs the spec's 28-60%, 42.8/52.3% blazing vs 4-9%. The
        // field was being REFILLED faster than it drained, so there was no
        // dark left for light to work against. Fill knobs down, drain up.
        // 0.36 -> 0.22 (fill). Steady-state dye ~ deposit/decay.
        ambientDye: 0.36
        // The seam has to be ALIVE with no hand near it -- it is the one lit
        // thing on a resting desktop, and the owner reported it gone after
        // WIP-214 took the strands down and the injection with them. The bar
        // cannot buy this the way the panels do: its Swirl is deliberately
        // `interactive: false` because the pointer zone is the whole 72 px
        // chrome while the paint band is the bottom 28, so its `_stimulus` is
        // permanently false and only the ambient stirrers hold the field up
        // between Wake strokes. At the ported default of 0.42, with smaller
        // splats laying down less dye each, they could not.
        // 0.90 -> 1.20 (WIP-265): the bar is `interactive: false`, so its
        // `_stimulus` is permanently false and the ambient stirrers are the
        // ONLY thing holding the field up once the intro has decayed.
        // 1.20 -> 0.55 (fill): the stirrers were smearing dye over the
        // whole band; less force leaves empty ground between the strands.
        ambientAmp: 0.55
        // TRK density: the field was being refilled faster than it drains,
        // so most of the surface was never empty. decayRate is the drain.
        decayRate: 0.50
        // Ice-core lift without more dye (more dye reads as bigger). view
        // bloom taps are 0.10/0.14/0.12 × bloom; ice stops carry the mip
        // energy. 0.80 → 1.05 (11:13) → 1.50 (11:16, go harder).
        // 1.50 -> 0.90 (0824 density): the mip taps were the largest single
        // contributor to the blazing fraction once the field was emptied.
        bloom: 0.90
        // The login ignition, softened. `playIntroOnLoad` already defaults to
        // true, so the Line was ALWAYS igniting — an earlier comment here
        // claimed otherwise and that was simply false. What made the seam
        // look absent was the fade to zero opacity 12 s later (Swirl.qml
        // § restOpacity), not a missing intro. At full strength the ignition
        // also dumped enough dye to flood the field before you touched it.
        introStrength: 0.55
        // No solver overrides on purpose. The Line IS swirl-live.html's
        // `taskbar` preset — splatRadius 0.060 (impulseRadius 0.245), curl 50,
        // densityDissipation 0.34, ambient.force 0.42, sweepGamma 1.35 over the
        // whole sweep — and every one of those is already Swirl.qml's ported
        // default. The 0.30 / 0.88 / 0.58 that used to sit here were tuned
        // against the analytic-noise version that had no solver in it.
        audioBass: Beat.bass
        audioMid: Beat.mid
        audioHigh: Beat.high
        audioPulse: Beat.pulse
        musicActive: Beat.hot
    }

    // ── the glass edge ───────────────────────────────────────────────
    // The Lip and the Sheen — see GlassEdge.qml, which is now the one place
    // the recipe lives, so the bar and every Swell are the same material at
    // different thicknesses instead of three hand-copied blocks that drift.
    //
    // `glaze: 0` because the bar already has a body: the Shelf. A Swell has
    // no Shelf under it, so it takes the glaze instead.
    //
    // Declared AFTER the Line, not before it. The paint is the light INSIDE
    // the tank; the lip and the sheen are the front face of the glass, so the
    // edge has to be in front of the light or the pane reads as a sheet laid
    // behind the glow rather than as the thing containing it. Drawn under the
    // Line they were also being washed out by it at exactly the alpha where
    // the top edge is doing all the work.
    GlassEdge {
        // Pinned to the chrome, not filling the window. The Lip and Sheen
        // positions inside GlassEdge are pixel distances expressed as
        // fractions of the HOST's height, so letting this grow with the
        // dissolve would silently move the whole edge treatment down the
        // pane and thin it.
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Theme.chromeH
        glaze: 0
        body: 0
        wash: 0
        edging: 0.70
        // ── the bevel comes off the top edge ─────────────────────────
        // Owner ruling, 2026-08-18. This is a REVERSAL of a written rule,
        // not an application of one, and it is worth saying so here where
        // the change is: GlassEdge.qml states that the Lip is "the single
        // cue that makes a surface read as a slab with thickness rather
        // than as a sheet of cellophane", and DESIGN_LANGUAGE_HORIZON §4.1
        // defines the crown unconditionally as "what makes glass read as
        // glass at 1 px". Both are still true and both still apply to
        // every OTHER surface in the build. The bar is the exception
        // because its top has stopped being a boundary between two things.
        //
        // Measured, this is the larger half of the edge. The Crown was a
        // +18.81 L step in one row; the Lip below it is −12.52 and the
        // Sheen's onset another +7.96 three rows further down. Removing
        // the Crown alone would have traded a bright line for a dark one.
        topEdge: bar.keepLip ? 1.0 : 0.0
    }

    // 1 px glacier[4] seam — the same hairline the widget chips carry.
    Rectangle {
        anchors { left: parent.left; right: parent.right }
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.chromeH - 1
        height: 1
        z: bar.zChrome
        color: Theme.soften(Theme.paintLayers.glacier[4], 0.80)
    }

    // The content scrim (§4.2's layer stack: body → paint → SCRIM → content).
    // The paint is allowed to reach up behind the Sigil, the Row and the
    // Gauge, and this is the veil that keeps their labels readable while it
    // does. It is transparent at the very bottom — where the paint is
    // brightest and there is no text — and thickens upward through the type.
    // Colour may move; legibility may not.
    //
    // Lightened with the Shelf (Theme § GLASS). This scrim used to stack 0.55
    // of void on top of a 0.97 shelf, and the two together were an opaque
    // black bar that the compositor was blurring the wallpaper behind for
    // nothing. It still does its job — a heavily blurred backdrop (size 14,
    // 4 passes) is a far quieter thing to read text over than a sharp
    // photograph, so the veil can be much thinner than it was and the labels
    // stay legible while the swirl and the wallpaper both come through.
    // ══ FRONT FACE · plate 1 of 3 — THE TYPE SCRIM AND THE HAZES ════
    // These exist to make the front face's TYPE legible. With the chrome
    // turned away there is no type to shade, so they turn away with it —
    // otherwise the back face would carry five soft dark patches marking
    // where widgets are not.
    // TRK-3813 — stays flat, because the CHROME stays flat. Its own comment
    // above is still the argument: it turns with the type it exists to make
    // legible. The type no longer turns, so neither does this. And over a
    // lit LED field it is doing MORE work than it was over the swirl, not
    // less — a dark patch under the type is exactly how chrome stays
    // readable on top of an instrument.
    FlipPlate {
        anchors.fill: parent
        angle: 0
        Rectangle {
            // Pinned to the chrome. Its gradient's whole argument is about
            // where the type sits inside an 84 px zone, so it must keep
            // measuring against 84 px.
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: Theme.chromeH
            visible: Prefs.swirlEnabled
            // ⟵ A VERTICAL falloff, and the direction matters more than the
            // amount. The first cut of this was heaviest at the TOP on the
            // reasoning that "the type lives there". It does not: measured off
            // the layout rather than assumed, the Sigil, the Row's icons, the
            // Desks, the Tray and the Gauge all sit between y 22 and y 66 of an
            // 84 px zone. The top ~18 px is empty glass and the bottom ~18 px is
            // the seam and the reflections. So a top-heavy veil shaded the one
            // band where clear glass is judged — the crown, the lip and the
            // sheen — and left the type in the open.
            //
            // Inverted: zero at the top face so the edge reads as glass, heaviest
            // through the type band, and back to zero at the seam so the horizon
            // stays the brightest row on the screen. Nothing gets an edge; it is
            // one gradient across the whole pane, which is what keeps it from
            // being the full-width frost this material spent a morning removing.
            //
            // The shade follows the light, the same rule the Hazes obey: at rest
            // the field is a dim residue and the glass can be nearly clear, so
            // this eases back rather than sitting at full strength over a sleeping
            // seam.
            opacity: line.running ? 1.0 : 0.55
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durBase
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveMove
                }
            }
            gradient: Gradient {
                GradientStop { position: 0.00; color: Theme.soften(bar.barBlack, 0.00) }
                GradientStop { position: 0.17; color: Theme.soften(bar.barBlack, 0.05) }
                GradientStop { position: 0.45; color: Theme.soften(bar.barBlack, 0.30) }
                GradientStop { position: 0.74; color: Theme.soften(bar.barBlack, 0.18) }
                GradientStop { position: 1.00; color: Theme.soften(bar.barBlack, 0.00) }
            }
        }

        // ── the Hazes · local shade, only where there is text ────────────
        // The full-width veil is gone. A veil across the whole pane is what makes
        // glass look frosted, and frosted is not the material the owner asked
        // for — "like looking inside an empty fish tank" is CLEAR glass. But a
        // fish tank reads as glass because the room behind it is dim, and here
        // there is a light source blazing directly under the pane: the Line's own
        // paint. Clear glass over a bright backdrop is unreadable, which is
        // exactly what happened when the blur came off.
        //
        // So the pane stays clear and the shading is LOCAL: a soft pool of dark
        // under each group of type, fading out horizontally so it has no edge to
        // see. The swirl runs uninterrupted between and behind them, and the
        // labels sit in their own shade — glass with the lettering etched where
        // it needs to be legible, rather than a sheet of smoked perspex.
        Repeater {
            model: [
                { at: sigil,  pad: Theme.s9 },
                { at: row,    pad: Theme.s5 },
                { at: gauge,  pad: Theme.s9 },
                { at: desks,  pad: Theme.s7 },
                { at: tray,   pad: Theme.s7 }
            ]
            delegate: Rectangle {
                id: haze
                required property var modelData
                visible: haze.modelData.at.width > 0
                x: haze.modelData.at.x - haze.modelData.pad
                width: haze.modelData.at.width + haze.modelData.pad * 2
                // Pinned to the chrome, so the dissolve band above carries no
                // shade at all. The owner's constraint is explicit — "do not
                // weaken the ground under text to achieve the fade" — and its
                // mirror matters just as much: the fade must not drag the
                // ground up above the bar, where there is no text to protect
                // and a dark wash would read as the haze the brief rejects.
                anchors { bottom: parent.bottom }
                height: Theme.chromeH

                // ⟵ THE SHADE FOLLOWS THE LIGHT.
                // Measured rather than guessed: with the pane clear, the bar's
                // mean luminance is (25,30,47) with the paint asleep and
                // (99,119,141) with it awake. One fixed veil cannot serve both —
                // strong enough to keep labels legible under a blazing seam is
                // far too heavy over a resting one, and that is precisely the
                // frosted look we just spent the morning removing.
                //
                // So the haze is bound to the paint's own `running` flag. At rest
                // it is barely there and the glass is clear; the instant the seam
                // lights — your hand arriving, a Tell, the login ignition — the
                // shade deepens under the type and lifts again when the sim
                // sleeps. It is the same idea as a lamp casting a shadow: the
                // shadow exists because the light does.
                // The owner: "I don't think where it says NYXUS should have a
                // shadow or whatever." Correct — at 0.58 these read as dark
                // rectangles parked behind the type, which is a chip by another
                // name and §2 spends a page saying this chrome has none.
                //
                // They only needed to be that heavy because the paint was clipping
                // to white. With the exposure fixed above they can drop to a
                // quarter of that, and the falloff is stretched right across the
                // group so there is no edge anywhere to read as a box — it is a
                // gradient in the glass, not an object on it.
                opacity: line.running ? 1.0 : 0.0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.durBase
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveMove
                    }
                }

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.00; color: Theme.soften(bar.barBlack, 0.00) }
                    GradientStop { position: 0.50; color: Theme.soften(bar.barBlack, 0.16) }
                    GradientStop { position: 1.00; color: Theme.soften(bar.barBlack, 0.00) }
                }
            }
        }
    }

    // The resting seam. The paint sleeps and schedules zero frames when
    // nothing is happening, so the horizon has to exist without it: three
    // stacked hairlines running the signature sweep, brightest at the very
    // edge. This is what an idle desktop looks like, and it is still
    // unmistakably this build.
    Repeater {
        model: [
            { h: Theme.seamH, a: 0.72 },
            { h: 7,           a: 0.15 },
            { h: 20,          a: 0.055 }
        ]
        delegate: Rectangle {
            id: hairline
            required property var modelData
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: hairline.modelData.h
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.00; color: "transparent" }
                GradientStop { position: 0.06; color: Theme.soften(Theme.driftAt(0.22), hairline.modelData.a) }
                GradientStop { position: 0.32; color: Theme.soften(Theme.driftAt(0.28), hairline.modelData.a) }
                GradientStop { position: 0.58; color: Theme.soften(Theme.driftAt(0.34), hairline.modelData.a) }
                GradientStop { position: 0.80; color: Theme.soften(Theme.driftAt(0.40), hairline.modelData.a) }
                GradientStop { position: 0.96; color: Theme.soften(Theme.driftAt(0.46), hairline.modelData.a) }
                GradientStop { position: 1.00; color: "transparent" }
            }
        }
    }

    // ── the Crown · the top edge of the Deck ─────────────────────────
    // The seam says where the screen ends. The Crown says where the CHROME
    // begins, and until it existed the answer was "nowhere in particular".
    // Same sweep as the seam so the zone is bracketed by one light, but a
    // quarter of the strength: this is a lip catching light from below, not a
    // second horizon competing with the first.
    //
    // It brightens while the pointer is in the zone. That is a response, not
    // an idle animation (§3.3 rule 2) — with your hand elsewhere it is still.
    //
    // Three stacked hairlines, exactly the seam's own construction turned
    // upside down, so the horizon zone is bracketed top and bottom by the
    // same light. Nothing here is opaque and nothing is grey: the first cut
    // seated the crown on a dark band and it read as a hard step across the
    // screen — the one thing §2 promises this chrome does not have.
    // ── the Crown is GONE, and this note is the receipt ──────────────
    // Owner ruling, 2026-08-18: "No hairline on that edge. The dissolve
    // replaces it."
    //
    // What stood here was three stacked hairlines — 1 px at alpha 1.00,
    // 4 px at 0.26, 14 px at 0.09 — of the same sweep as the seam, at
    // `crownRest` 0.30 / `crownLive` 0.62. Photographed at the boundary it
    // was a +18.81 L step in a single pixel row, with blue going 15.95 to
    // 65.56. It was doing its job well; the job is what changed.
    //
    // ⚠ ONE BEHAVIOUR LEFT WITH IT, AND IT WAS NOT IN THE BRIEF. The
    // Crown's opacity was bound to `zoneLive`, and the note at the top of
    // this file calls that out as "the only thing in the chrome that
    // responds to mere presence". Deleting the Crown silently deleted
    // that response. It is carried instead by the dissolve: the reach
    // shortens slightly as your hand enters the zone, so the material
    // gathers toward the edge rather than a line brightening on it. Same
    // rule (§3.3 rule 2 — a response, not an idle animation), same
    // trigger, no light added anywhere.
    //
    // `Theme.crownH`, `crownRest` and `crownLive` are deliberately NOT
    // removed: `crownH` is read by GlassEdge's Lip/Sheen arithmetic and
    // the other two are read by surfaces that still draw a crown, which
    // is every floating surface in the build. The bar is the exception,
    // not the new rule.

    // ── the end pools ────────────────────────────────────────────────
    // Start and the Gauge each light the seam beneath themselves when they
    // are live. Declared HERE, as children of the bar rather than of the
    // things they belong to, for one reason: a Pool is light on the floor and
    // has to be UNDER the content. Reparenting one out of `sigil` at runtime
    // appends it to the end of the bar's child list, which puts it on top of
    // the very mark it is supposed to be lighting.
    //
    // The tone is not a choice. Hue is a function of horizontal position
    // everywhere in this build, so Start — the leftmost thing on screen —
    // pools teal, and the Gauge at the right pools plum, without either of
    // them being told.
    // ══ FRONT FACE · plate 2 of 3 — THE END POOLS ═══════════════════
    // Light under Start and under the Gauge. It belongs to the front face
    // for an obvious reason: a pool still lit under a Sigil that has
    // turned away is a glow with nothing above it.
    // TRK-3813 — stays flat for the reason its own comment gives: a pool is
    // "a glow with nothing above it" when the Sigil has turned away. The
    // Sigil no longer turns away, so the pool belongs under it again.
    FlipPlate {
        anchors.fill: parent
        angle: 0
        Pool {
            x: sigil.x - Theme.s6
            width: sigil.width + Theme.s6 * 2
            height: 34
            anchors.bottom: parent.bottom
            tone: Theme.sweep0
            focusRatio: 0.35
            strength: Bus.launcherOpen ? 0.85 : (sigil.lit ? 0.34 : 0)
        }
        Pool {
            x: gauge.x - Theme.s6
            width: gauge.width + Theme.s6 * 2
            height: 34
            anchors.bottom: parent.bottom
            tone: Theme.sweep4
            focusRatio: 0.35
            strength: Bus.flyoutOpen ? 0.85 : (gauge.lit ? 0.34 : 0)
        }
    }

    // ── the Wake ─────────────────────────────────────────────────────
    // The paint answers the pointer anywhere in the chrome zone, not only
    // where it is drawn — so light gathers under your hand as you come down
    // to the horizon, before you have clicked anything. `interactive: false`
    // on the Swirl hands the job here, because the paint band is the bottom
    // 28 px and the reach should be the whole zone.
    property real _wakeX: -1
    property real _wakeY: -1
    // The zone is the CHROME, not the window. Growing the surface for the
    // dissolve would otherwise have grown the wake zone with it and the bar
    // would start responding `dissolveH` px early — a behaviour change
    // nobody asked for, arriving as a side effect of a geometry change.
    Item {
        id: zone
        z: bar.zChrome
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Theme.chromeH

    HoverHandler {
        id: wake
        onHoveredChanged: {
            bar.zoneLive = hovered;
            if (!hovered) { bar._wakeX = -1; bar._wakeY = -1; }
        }
        onPointChanged: {
            if (!hovered || !Prefs.swirlEnabled)
                return;
            // Only on real movement. `pointChanged` also fires for velocity
            // decay and for frame callbacks, and feeding a stationary pointer
            // 60 times a second would hold the sim awake forever for nothing.
            var px = point.position.x;
            var py = point.position.y;
            if (Math.abs(px - bar._wakeX) < 1.0 && Math.abs(py - bar._wakeY) < 1.0)
                return;
            bar._wakeX = px;
            bar._wakeY = py;
            var f = px / Math.max(bar.width, 1);
            // The stroke used to be fed at a fixed y of 0.30, so every Wake was
            // the same flat horizontal ribbon no matter where the hand was —
            // and a stroke with dy = 0 gives the solver nothing to fold, which
            // is half of why the live seam never looked like the reference.
            // §"the Wake" says light gathers under your hand *as you come down
            // to the horizon*, so the hand's height in the chrome zone is the
            // height of the stroke. 0.14–0.46 keeps both ends inside the half
            // of the field that is actually on screen.
            // ── DERIVED, and it used to be two constants ─────────────
            // This was `0.14 + 0.32 * (py / bar.height)`, and the comment
            // above justified those two numbers by saying they "keep both
            // ends inside the half of the field that is actually on
            // screen". That was true while the window was exactly half the
            // field. The dissolve moves the field up, so the visible
            // fraction is no longer a half and the sentence would have
            // stayed readable while quietly ceasing to be true — which is
            // the failure this repo keeps finding in its own comments.
            //
            // So the fraction is computed. `vis` is how much of the field
            // is on screen; the 0.28/0.64 inset is the SAME inset the old
            // constants expressed, stated as a proportion of it rather
            // than as two pre-multiplied numbers. At `dissolveH` 0 this
            // evaluates to 0.14 + 0.32·f exactly, so nothing moves for a
            // host without a dissolve.
            var vis = (Theme.chromeH + bar.dissolveH) / Theme.paintH;
            var g = vis * (0.28 + 0.64 * Math.max(0, Math.min(1, py / Math.max(zone.height, 1))));
            line.feedAt(f, g);
            Bus.paint(f);          // the Spill answers the same impulse
        }
    }
    }

    // ── the Tell ─────────────────────────────────────────────────────
    // One drop of paint at the x where an event belongs.
    function tell(x) {
        if (!Prefs.swirlEnabled || width <= 0)
            return;
        var f = Math.max(0, Math.min(1, x / width));
        // A drop with a small upward kick, so the light rises out of the seam
        // instead of just appearing in it.
        line.dropAt(f, 0.32, 1.0, 0, -1.6);
        Bus.paint(f);
    }

    // Focus moving between apps is the event you watch most often, so it gets
    // the richest form: a stroke that TRAVELS along the seam from where you
    // were to where you are going.
    property real _lastFocusX: -1
    property real _travelP: 0
    function tellTravel(x) {
        if (!Prefs.swirlEnabled || width <= 0) return;
        if (_lastFocusX < 0) { _lastFocusX = x; tell(x); return; }
        // `Tasks.active` re-emits for focus moving through shell surfaces and
        // back, so the same window arrives here repeatedly. Each arrival used
        // to buy a fresh 12 s of full-rate simulation in BOTH the Line and the
        // Spill for a stroke that travels nowhere — measured at ~93 feedAt
        // calls per event and most of the idle-CPU regression.
        if (Math.abs(x - _lastFocusX) < 1.0) return;
        travel.fromX = _lastFocusX;
        travel.toX = x;
        _lastFocusX = x;
        travel.restart();
    }
    NumberAnimation {
        id: travel
        property real fromX: 0
        property real toX: 0
        target: bar
        property: "_travelP"
        from: 0
        to: 1
        duration: Theme.durSettle
        easing.type: Easing.Bezier
        easing.bezierCurve: Theme.curveMove
    }
    on_TravelPChanged: {
        if (!travel.running)
            return;
        var x = travel.fromX + (travel.toX - travel.fromX) * _travelP;
        var f = Math.max(0, Math.min(1, x / Math.max(width, 1)));
        line.feedAt(f, 0.30);
        Bus.paint(f);
    }

    Connections {
        target: Tasks
        function onActiveChanged() {
            var e = Tasks.entries;
            for (var i = 0; i < e.length; i++) {
                if (!e[i].focused)
                    continue;
                var it = row.itemAtKey(e[i].key);
                if (it)
                    bar.tellTravel(row.x + it.x + it.width / 2);
                return;
            }
        }
    }
    Connections {
        target: Sys
        function onNotified(summary, body, appName) {
            crest.announce(summary, appName);
            bar.tell(bar.width - Theme.s10);
        }
    }

    // A surface opening is an event, and events Tell. Driven off the shared
    // state rather than off the click, so the keybind (`qs ipc call nyxus
    // launcher`) produces exactly the same light as pressing the Sigil —
    // otherwise the desktop would behave differently depending on how you
    // asked, which is the kind of seam that makes software feel homemade.
    Connections {
        target: Bus
        function onLauncherOpenChanged() {
            if (Bus.launcherOpen)
                bar.tell(sigil.x + sigil.width / 2);
        }
        function onAppLaunched() {
            bar.tell(sigil.x + sigil.width / 2);
        }
        function onFlyoutOpenChanged() {
            if (Bus.flyoutOpen)
                bar.tell(gauge.x + gauge.width / 2);
        }
        function onPowerOpenChanged() {
            if (Bus.powerOpen)
                bar.tell(bar.width / 2);
        }
        function onTaskViewOpenChanged() {
            if (Bus.taskViewOpen)
                bar.tell(desks.x + desks.width / 2);
        }
    }
    // ══ FRONT FACE · plate 3 of 3 — THE CHROME (TRK-3698) ═══════════
    // Sigil, Row, Desks, Tray, Gauge, Meridian. `z: bar.zChrome` and
    // declared after `zone`, exactly where the chrome already sat, so the
    // stacking this bar has been tuned to is byte-for-byte unchanged when
    // the plate is flat. Every id inside is still resolvable from the rest
    // of the file (QML ids are component-scoped, not parent-scoped), and
    // every anchor still measures the same rectangle, because the plate
    // fills the window the chrome was anchored to.
    // ══ TRK-3813 · THE CHROME DOES NOT TURN AWAY ANY MORE ══════════════
    // ⚠ THIS IS A REGRESSION FIX AND THE REGRESSION WAS THIS LANE'S.
    // Owner, 2026-09-06, while music was playing:
    //
    //   "one issue i just realized because i went to hit my start but cant
    //    when the music is on so what do we do or just use the keys"
    //
    // He could not click Start. He found Start because it is what he reached
    // for first — it was NOT the only casualty. This plate carries the
    // Sigil (Start), the Row, the Desks, the Tray, the Gauge and the
    // Meridian, and `angle: bar.flipAngle` turned all six away together the
    // moment audio began. Plates 1 and 2 took the type shading and the end
    // pools with them, and `openZoneMenu` hit-tests through `inZone()`,
    // which returns false for an invisible item — so every zone's
    // right-click menu silently degraded to the bare-bar fallback as well.
    // The bar kept all of its pixels and lost every one of its controls.
    //
    // ⚠ HE OFFERED THE WORKAROUND HIMSELF — "or just use the keys" — AND IT
    // IS REFUSED. A keybind is a fine addition and a bad answer: the button
    // was there, it was clickable, and a fix that ends with the user
    // adapting is not a fix. The cause is one binding and it is removed.
    //
    // ══ AND THIS DOES NOT REOPEN "IT TAKES OVER THE BOTTOM BAR" ═════════
    // That complaint, and the "WITH OUT THE SWIRLS BEHOND IT" ruling behind
    // the flip, are both about what sits BEHIND the instrument: a graph
    // painted over the living paint, two things fighting for one surface.
    // Chrome over the instrument is the opposite relationship and is how
    // this bar has always worked — the instrument is now the bar's
    // BACKGROUND rather than its whole surface. The swirl is still not
    // behind it: that is done by BarSpectrum's opaque ground, not by the z,
    // which is the correction TRK-3809 had to make anyway (see the
    // visualizer plate's own block at the end of this file).
    //
    // ⚠ WHY NOT "FLIP BACK ON HOVER", WHICH IS THE PRETTIER ANSWER. It puts
    // an animation between his hand and a click. The bug being fixed here is
    // a control he could not reach; answering it with a control that arrives
    // 220 ms after he reaches for it is the same defect with better manners,
    // and it fires the whole flip on every accidental mouse pass along the
    // screen edge. A partial flip — middle span only — has the same problem
    // at its seams and adds two more.
    //
    // The plate is KEPT rather than unwrapped: it is the thing every anchor
    // and every id in the chrome measures against, and `angle: 0` is a
    // FlipPlate that does nothing, which is a smaller change than deleting
    // one and re-parenting six widgets.
    FlipPlate {
        anchors.fill: parent
        z: bar.zChrome
        angle: 0

        // ═════════════════════════════════════════════════════════════════
        //  the Sigil — bottom left. This is Start.
        // ═════════════════════════════════════════════════════════════════
        Item {
            id: sigil
            z: bar.zChrome
            anchors {
                left: parent.left
                leftMargin: Theme.s7
                bottom: parent.bottom
                bottomMargin: 16
            }
            // Rounded UP to a whole pixel, and it is not a cosmetic detail: the
            // Row is anchored to the rail that is anchored to this, so a
            // fractional width here — and `wordmark.width` is a text metric, so it
            // always is one — puts every dock icon on a fractional x. A 30 px
            // image drawn at x = 317.4 is resampled across the pixel grid, which
            // smears every vertical edge in it. That is the other half of "the
            // pixels in them look messed up".
            width: Math.ceil(mark.width + Theme.s5 + wordmark.width)
            // 34 px was the drawn row; the TapHandler lived on it, so the
            // Start hit target was shorter than Theme.barHeight (52). The
            // disc stays 28. Extra height is empty hit pad, not a bigger mark.
            height: Theme.barHeight

            readonly property bool lit: sigilHover.hovered || Bus.launcherOpen

            transform: Translate {
                y: sigil.lit ? -2 : 0
                Behavior on y {
                    NumberAnimation {
                        duration: Theme.durQuick
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveRise
                    }
                }
            }

            Sigil {
                id: mark
                anchors.verticalCenter: parent.verticalCenter
                lit: sigil.lit
                engaged: Bus.launcherOpen
            }

            Text {
                id: wordmark
                anchors {
                    left: mark.right
                    leftMargin: Theme.s5
                    bottom: mark.bottom
                }
                text: "NYXUS"
                // The product signature, and the one place `fMark` belongs.
                // Two things had to change with the face: a marker's letters
                // are irregular by design, so the 3.4px tracking that made the
                // Inter version read as a wordmark pulls them into loose debris
                // — `trackMark` is a tenth of it. And a drawn face carries less
                // ink than a fitted one at the same size, so it steps up one
                // rung of the ladder to hold the same visual weight beside the
                // sigil.
                font.family: Theme.fMark
                font.pixelSize: Theme.tTitle
                font.weight: Theme.wBody
                font.letterSpacing: Theme.trackMark
                color: sigil.lit ? Theme.text : Theme.textMuted
                Behavior on color { ColorAnimation { duration: Theme.durQuick } }
            }

            // ── Start's reflection ─────────────────────────── TRK-3826 ──
            // Owner, 2026-09-07: "the sigil and nyxys ... dont have the
            // mirrored imaige underneath it". They were the two loudest
            // things on the bar standing on nothing.
            //
            // ⚠ ONE MIRROR LINE FOR THE PAIR, NOT ONE EACH, and that is the
            // difference between a reflection and two decorations. The disc
            // and the wordmark are centred on the same line and have
            // different heights, so mirroring each about its OWN bottom
            // would put their reflections at two different depths — which
            // no surface does. The box is the DISC's height with its top at
            // the disc's base, so both are flipped about one plane. The
            // copies keep their original vertical centring inside it, which
            // (box height = disc height, both centred) lands each element's
            // mirror exactly as far below the line as the element is above.
            //
            // ⚠ A COPY, NOT A LIVE MIRROR OF THE SIBLINGS. Reflection.qml's
            // header carries the reason: a ShaderEffectSource of an item the
            // component does not own is the segfault class WIP-245 records.
            // A second Sigil is cheap — no timers, no shaders, four
            // Behaviors — and it is BOUND to the same `lit`, so the
            // reflection lights up with the real one instead of drifting.
            Reflection {
                x: mark.x
                anchors.top: mark.bottom
                anchors.topMargin: bar.reflectGap
                width: sigil.width
                height: mark.height
                Sigil {
                    id: markMirror
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    lit: sigil.lit
                    engaged: Bus.launcherOpen
                }
                Text {
                    anchors {
                        left: markMirror.right
                        leftMargin: Theme.s5
                        bottom: markMirror.bottom
                    }
                    // Bound to the wordmark, never retyped: the product
                    // signature exists once in this file.
                    text: wordmark.text
                    font: wordmark.font
                    color: wordmark.color
                }
            }

            HoverHandler { id: sigilHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: Bus.toggleLauncher() }
        }

        Rail {
            id: sigilRail
            z: bar.zChrome
            vertical: true
            // TRK-3557 — s7 -> s9. The left half of the bar was looser than the right:
            // measured separation-to-ink 1.82 on the left against 2.4-2.7 on the
            // right, so the eye read the launch group as one undifferentiated run.
            // Widening the two sigil rails and tightening dockSlot (Theme.qml) puts
            // the left half at 3.11 without touching an icon, the magnification or
            // the mirrored Reflection.
            anchors { left: sigil.right; leftMargin: Theme.s9; bottom: parent.bottom; bottomMargin: 24 }
            height: 26
            tone: 0.05
            strength: bar.zoneLive ? 0.30 : 0.16
            Behavior on strength { NumberAnimation { duration: Theme.durBase } }
        }

        // ═════════════════════════════════════════════════════════════════
        //  the Row — the Prism Dock.
        //
        //  Pinned apps merged with real open windows. Three things carry state,
        //  and none of them is a chip behind the icon:
        //    · the Root   a bar of light in the seam under the slot — short for
        //                 running, long and bright for focused, two ticks when
        //                 the app owns more than one window
        //    · the Pool   that light spreading on the floor around it
        //    · the Reflection  the icon's own image falling into the seam, which
        //                 is what makes the icons read as standing ON something
        // ═════════════════════════════════════════════════════════════════
        Row {
            id: row
            z: bar.zChrome
            anchors {
                left: sigilRail.right
                leftMargin: Theme.s9
                bottom: parent.bottom
            }
            height: Theme.chromeH - 26
            spacing: Theme.s1

            // Which slot the pointer is over, by index, or -1. The dock's
            // magnification wave is a function of distance from this, so it lives
            // on the Row rather than in each slot.
            property int hoverIndex: -1

            function itemAtKey(k) {
                for (var i = 0; i < children.length; i++)
                    if (children[i].entryKey === k)
                        return children[i];
                return null;
            }

            Repeater {
                model: Tasks.entries
                delegate: Item {
                    id: slot
                    required property var modelData
                    required property int index
                    readonly property string entryKey: modelData.key
                    width: Theme.dockSlot
                    height: row.height

                    // Where a slot sits across the screen decides its colour — the
                    // same rule the paint under it obeys.
                    readonly property color tone:
                        Theme.sweepAt((row.x + x + width / 2) / Math.max(bar.width, 1))

                    readonly property bool hovered: row.hoverIndex === slot.index
                    // The magnification wave. Borrowed from the macOS dock, at a
                    // quarter of its amplitude: the reference bounces to 2×, which
                    // on a 30 px icon inside an 84 px zone has nowhere to go. The
                    // neighbour term is what makes it read as one surface flexing
                    // rather than as one icon popping.
                    //
                    // NOT `readonly`, even though nothing assigns it: a Behavior
                    // cannot attach to a read-only property, and Qt only says so
                    // at load time — qmllint passes it and then the whole shell
                    // fails with "Type Bar unavailable". A plain property with a
                    // binding animates on every re-evaluation, which is what this
                    // wants anyway.
                    property real mag:
                          slot.hovered ? Theme.magHover
                        : (row.hoverIndex >= 0 && Math.abs(row.hoverIndex - slot.index) === 1)
                            ? Theme.magNeighbour : 1.0

                    Behavior on mag {
                        NumberAnimation {
                            duration: Theme.durQuick
                            easing.type: Easing.OutQuint
                        }
                    }

                    // The floor light. Focused is a real pool; running is a hint;
                    // hovering borrows a little of it so the pointer feels like it
                    // is pushing light around.
                    Pool {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width + Theme.s5
                        height: 36
                        tone: slot.tone
                        focusRatio: 0.62
                        strength: slot.modelData.focused ? 0.95
                                : (slot.hovered ? 0.42
                                : (slot.modelData.running ? 0.16 : 0))
                    }

                    property real lookX: 0
                    property real lookY: 0

                    // Crystal well, real icon in the middle — same stone as
                    // Start gems. Bar chrome / spectrum / MediaCrest untouched.
                    Item {
                        id: icon
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: slot.height - 22 - height - (slot.hovered ? Theme.dockLift : 0)
                        width: bar.barIconPx + 12
                        height: bar.barIconPx + 12
                        CrystalGem {
                            anchors.fill: parent
                            hot: slot.hovered
                            on: slot.modelData.focused || slot.modelData.running
                            tint: slot.tone
                            lookX: slot.lookX
                            lookY: slot.lookY
                            iconName: slot.modelData.icon
                            iconPx: Math.round(bar.barIconPx * 0.62)
                        }
                        opacity: (slot.modelData.running || slot.hovered) ? 1.0 : Theme.dockIdle
                        transform: Scale {
                            origin.x: icon.width / 2
                            origin.y: icon.height
                            xScale: slot.mag
                            yScale: slot.mag
                        }
                        Behavior on y {
                            NumberAnimation {
                                duration: Theme.durQuick
                                easing.type: Easing.OutQuint
                            }
                        }
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.durQuick
                                easing.type: Easing.OutQuint
                            }
                        }
                    }

                    // ── the Reflection ───────────────────────────────────
                    // The icon's own light falling into the seam. Drawn as the
                    // icon mirrored about its bottom edge and faded out with an
                    // alpha mask, NOT by painting a dark scrim over it: the
                    // living paint is directly behind this and a scrim would
                    // punch a dull rectangle through it.
                    //
                    // ⚠ THIS WAS AN INLINE COPY OF `Reflection.qml` ── TRK-3826
                    // Owner, 2026-09-07: "the sigil and nyxys the clock and date
                    // and also everything else on the right side ... dont have
                    // the mirrored imaige underneath it so we need that fixed as
                    // well so everything looks part of the same build".
                    //
                    // Answering that means giving the reflection to the rest of
                    // the bar, and it could not be done while the effect existed
                    // TWICE: `Reflection.qml` is the packaged recipe every other
                    // surface uses, and these forty lines were a byte-for-byte
                    // second implementation of it living here. Any change made
                    // to make the mirror read more like a mirror would have
                    // moved one and not the other — which is precisely the
                    // complaint he just made ("part of the same build"), moved
                    // to a new seam. TRK-3275/3371 is this build's recorded cost
                    // for one effect implemented twice.
                    //
                    // ⚠ THE DOCK'S LOOK IS THE REFERENCE AND DID NOT CHANGE.
                    // The construction was already identical — flip about the
                    // centre, the one alpha-mask gradient at `Theme.reflectH`,
                    // `Theme.reflectAlpha`, no scrim — so this is a swap, not a
                    // redesign. The magnification Scale that used to sit on the
                    // MultiEffect now sits on the Reflection, which is the same
                    // node in the same place. Proof it is unchanged:
                    // `docs/proof/bar-mirror-0907/`.
                    Reflection {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: icon.y + icon.height + bar.reflectGap
                        width: icon.width
                        height: icon.height
                        strength: icon.opacity
                        transform: Scale {
                            origin.x: icon.width / 2
                            origin.y: 0
                            xScale: slot.mag
                            yScale: slot.mag
                        }
                        // Same stone as the dock, not the flat theme plate.
                        // A second CrystalGem (not a ShaderEffectSource of
                        // `icon`) — Reflection.qml's WIP-245 rule.
                        CrystalGem {
                            anchors.fill: parent
                            hot: slot.hovered
                            on: slot.modelData.focused || slot.modelData.running
                            tint: slot.tone
                            lookX: slot.lookX
                            lookY: slot.lookY
                            iconName: slot.modelData.icon
                        }
                    }

                    // ── the Root · state in the seam ─────────────────────
                    // A second tick appears when the app owns more than one
                    // window, which is the one piece of information a taskbar can
                    // give you for free and both Windows and macOS throw away.
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: slot.height - 9
                        spacing: 3
                        Repeater {
                            model: (slot.modelData.windows && slot.modelData.windows.length > 1) ? 2 : 1
                            delegate: Rectangle {
                                id: rootMark
                                required property int index
                                height: 2
                                radius: 1
                                width: {
                                    var multi = slot.modelData.windows
                                                && slot.modelData.windows.length > 1;
                                    if (slot.modelData.focused) return multi ? 13 : 28;
                                    if (slot.modelData.running) return multi ? 7 : 14;
                                    return slot.hovered ? 8 : 0;
                                }
                                color: slot.tone
                                opacity: slot.modelData.focused ? 1.0 : 0.62
                                Behavior on width {
                                    NumberAnimation {
                                        duration: Theme.durBase
                                        easing.type: Easing.Bezier
                                        easing.bezierCurve: Theme.curveMove
                                    }
                                }
                                Behavior on opacity { NumberAnimation { duration: Theme.durQuick } }
                            }
                        }
                    }

                    HoverHandler {
                        id: slotHover
                        cursorShape: Qt.PointingHandCursor
                        onPointChanged: {
                            if (!hovered || slot.width < 1)
                                return;
                            slot.lookX = (point.position.x / slot.width) * 2 - 1;
                            slot.lookY = (point.position.y / slot.height) * 2 - 1;
                        }
                        onHoveredChanged: {
                            if (hovered) {
                                row.hoverIndex = slot.index;
                                caption.hold(slot.modelData.name,
                                             row.x + slot.x + slot.width / 2,
                                             slot.entryKey,
                                             row.y + icon.y);
                            } else {
                                if (row.hoverIndex === slot.index)
                                    row.hoverIndex = -1;
                                slot.lookX = 0;
                                slot.lookY = 0;
                            }
                        }
                    }
                    TapHandler {
                        onTapped: {
                            bar.tell(row.x + slot.x + slot.width / 2);
                            Tasks.activate(slot.modelData);
                        }
                    }
                    TapHandler {
                        acceptedButtons: Qt.MiddleButton
                        onTapped: {
                            bar.tell(row.x + slot.x + slot.width / 2);
                            Tasks.launchNew(slot.modelData);
                        }
                    }
                }
            }
        }

        // Hovered app NAME. Same motion as a lyric/note on the spectrum:
        // pop in in front of the stone, then drift up and fade. Not a
        // window title (Ghostty's title is the command line — that was
        // "the Terminal name is wrong"). Not parked on the shelf.
        Text {
            id: caption
            z: 20
            property string owner: ""
            property real anchorX: 0
            property real baseY: 0
            property real lift: 0

            function hold(t, x, key, startY) {
                text = t;
                anchorX = x;
                owner = key;
                baseY = (startY === undefined || startY === null || startY === "")
                        ? (bar.height - Theme.chromeH - 6) : startY;
                fly.stop();
                opacity = 0;
                lift = 0;
                fly.restart();
            }
            function release() {
                owner = "";
            }

            x: Math.max(Theme.s7, Math.min(bar.width - width - Theme.s7, anchorX - width / 2))
            y: caption.baseY - caption.lift - height
            font.family: Theme.fUi
            font.pixelSize: Theme.tCaption
            font.weight: Font.DemiBold
            font.letterSpacing: Theme.trackMicro * 0.5
            color: Theme.text
            opacity: 0
            visible: fly.running || opacity > 0.01
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 280)
            style: Text.Outline
            styleColor: Theme.soften(Theme.void_, 0.78)

            SequentialAnimation {
                id: fly
                NumberAnimation {
                    target: caption
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 110
                }
                ParallelAnimation {
                    NumberAnimation {
                        target: caption
                        property: "lift"
                        from: 0
                        to: 36
                        duration: 1600
                        easing.type: Easing.OutCubic
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: 280 }
                        NumberAnimation {
                            target: caption
                            property: "opacity"
                            to: 0
                            duration: 1320
                            easing.type: Easing.InQuad
                        }
                    }
                }
            }
        }

        // ═════════════════════════════════════════════════════════════════
        //  the Desks — virtual desktops as segments OF the seam.
        //
        //  HORIZON §8 Phase 2 asked for exactly this and it was never built; the
        //  bar has been showing three static lines that meant nothing since
        //  Task View shipped. These are the real workspaces from the compositor,
        //  the focused one lit and long, and clicking one goes there. Opening
        //  Task View is still here, on the whole strip.
        // ═════════════════════════════════════════════════════════════════
        Item {
            id: desks
            z: bar.zChrome
            anchors {
                right: trayRail.left
                rightMargin: Theme.s7
                bottom: parent.bottom
                bottomMargin: 24
            }
            width: deskRow.width
            height: 26

            // ══ THE STRIP'S MIRROR LINE ════════════════════════ TRK-3827 ══
            // Owner, 2026-09-07, after the rest of the bar was done: "the
            // refections on the right side the first three still dont have
            // them those are the only ones on the bar that dont have that
            // feature" — and then a crop of exactly these: a dim dash, the
            // blue rule, and the six-dot grid.
            //
            // ⚠ WHY THESE THREE WERE MISSED, stated plainly because it is
            // the useful part. Everything else that got the fall in TRK-3826
            // is an ICON or a piece of TEXT — an `Image`, a `Text`, a
            // `Vitals` — and each is a thing that can simply be
            // instantiated a second time inside a `Reflection`. The desk
            // pips and the Task View panes are DRAWN PRIMITIVES: bare
            // `Rectangle`s declared inline, four of them inside a
            // `Repeater`. There is nothing to instantiate, which is why the
            // sweep walked past them.
            //
            // ⚠ AND THEY ARE STILL ON THE ONE MECHANISM. They get
            // `Reflection.qml`, the same component as every other surface in
            // the build; what changed is that the numbers the primitives are
            // drawn FROM are now named once (`taskBtn.paneW` and friends,
            // `pip`'s own properties) and read by both the real object and
            // its mirror. A retyped copy would have been a second recipe
            // that drifts the first time anyone changes a radius.
            //
            // ⚠ ONE PLANE FOR THE CLUSTER, NOT ONE PER OBJECT — the same
            // rule as § Start's reflection, and here it actually shows: a
            // pip's ink is 3 px tall and the Task View's is 13, both centred
            // in the same 26 px row, so mirroring each about its own base
            // would stagger the strip's reflections by 5 px right beside a
            // dock whose reflections all share one line. The line is the
            // LOWEST ink in the cluster, which is the Task View's; a box of
            // that ink's height with its top on that line, holding a copy
            // centred, lands every element's mirror exactly as far below the
            // line as the element is above it. (Derivation: for ink at
            // absolute [a,b] and line L, the mirror is [L-b, L-a] in box
            // coords, so the pre-flip source sits at H-L+a — which for a
            // centred object in a box of the reference ink's height is
            // simply centred again.)
            readonly property int mirrorInk: taskBtn.inkH
            readonly property real mirrorY: (height + mirrorInk) / 2

            readonly property var list: Hyprland.workspaces ? Hyprland.workspaces.values : []
            readonly property int focusedId: Hyprland.focusedWorkspace
                                             ? Hyprland.focusedWorkspace.id : -1

            Row {
                id: deskRow
                anchors.centerIn: parent
                spacing: Theme.s3

                Repeater {
                    model: desks.list
                    delegate: Item {
                        id: desk
                        required property var modelData
                        readonly property bool here: desk.modelData.id === desks.focusedId
                        width: desk.here ? 22 : 10
                        height: 26

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.durBase
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveMove
                            }
                        }

                        Rectangle {
                            id: pip
                            anchors.centerIn: parent
                            width: parent.width
                            height: 3
                            radius: 1.5
                            color: desk.here ? Theme.sweep2 : Theme.textMuted
                            opacity: desk.here ? 1.0 : (deskHov.hovered ? 0.8 : 0.34)
                            Behavior on opacity { NumberAnimation { duration: Theme.durQuick } }
                            Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                        }
                        // The pip's fall. Every value is BOUND to the pip
                        // rather than retyped, so a change to the strip's
                        // shape or colour cannot leave its mirror behind —
                        // including the focused pip's 10 → 22 px widening,
                        // which the reflection now performs with it.
                        //
                        // ⚠ THE BLUE RULE IS THE ONE SATURATED THING IN THIS
                        // CLUSTER and its mirror must not read as a second
                        // live indicator. It does not get special handling;
                        // it gets the same `Theme.reflectAlpha` and the same
                        // bent fall-off as everything else, which is what
                        // makes a mirrored `sweep2` rule a dim trace under a
                        // bright one instead of a second bright one.
                        Reflection {
                            y: desks.mirrorY
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: desk.width
                            height: desks.mirrorInk
                            Rectangle {
                                anchors.centerIn: parent
                                width: pip.width
                                height: pip.height
                                radius: pip.radius
                                color: pip.color
                                opacity: pip.opacity
                            }
                        }
                        HoverHandler { id: deskHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                bar.tell(desks.x + desk.x + desk.width / 2);
                                Hyprland.dispatch("workspace " + desk.modelData.id);
                            }
                        }
                    }
                }

                // Task View lives at the end of the strip rather than as a
                // separate control: overview is what you want AFTER scanning the
                // desks, and putting it anywhere else meant two things that mean
                // "desktops" sitting apart from each other.
                Item {
                    id: taskBtn
                    width: 22
                    height: 26
                    readonly property bool lit: tvHov.hovered || Bus.taskViewOpen

                    // ⚠ THE PANE'S SHAPE IS NAMED ONCE ───────── TRK-3827 ──
                    // The glyph is drawn twice now — here and in its
                    // reflection — and four `Rectangle`s inside a `Repeater`
                    // cannot be bound to by id from outside. So the numbers
                    // and the two state expressions live here and BOTH grids
                    // read them. Retyping `width: 7` in the mirror is how a
                    // build ends up with two recipes for one object and no
                    // way to tell which one is stale. `inkH` is also what
                    // `desks.mirrorInk` uses to put the whole cluster's
                    // reflections on one plane — see § THE STRIP'S MIRROR
                    // LINE — so this glyph's height is load-bearing beyond
                    // itself and is derived rather than written down twice.
                    readonly property int paneW: 7
                    readonly property int paneH: 5
                    readonly property int paneGap: 3
                    readonly property int inkH: paneH * 2 + paneGap
                    readonly property color paneTone: taskBtn.lit ? Theme.sweep3
                                                                  : Theme.textMuted
                    readonly property real paneFade: taskBtn.lit ? 1.0 : 0.42

                    // A 2×2 of panes — the universal "show me everything" glyph,
                    // and deliberately NOT the same shape as the desk segments
                    // beside it, so "which desktop" and "show me all of them" do
                    // not read as the same control.
                    Grid {
                        anchors.centerIn: parent
                        columns: 2
                        spacing: taskBtn.paneGap
                        Repeater {
                            model: 4
                            delegate: Rectangle {
                                width: taskBtn.paneW
                                height: taskBtn.paneH
                                radius: 1.5
                                color: taskBtn.paneTone
                                opacity: taskBtn.paneFade
                                Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                                Behavior on opacity { NumberAnimation { duration: Theme.durQuick } }
                            }
                        }
                    }
                    // The Task View's fall. Its ink IS the cluster's mirror
                    // line, so this box's top sits exactly on its own base
                    // and its content fills the box — the reference case the
                    // pips' boxes are derived from.
                    Reflection {
                        y: desks.mirrorY
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: taskBtn.width
                        height: desks.mirrorInk
                        Grid {
                            anchors.centerIn: parent
                            columns: 2
                            spacing: taskBtn.paneGap
                            Repeater {
                                model: 4
                                delegate: Rectangle {
                                    width: taskBtn.paneW
                                    height: taskBtn.paneH
                                    radius: 1.5
                                    color: taskBtn.paneTone
                                    opacity: taskBtn.paneFade
                                }
                            }
                        }
                    }
                    HoverHandler { id: tvHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: Bus.toggleTaskView() }
                }
            }
        }

        Rail {
            id: trayRail
            z: bar.zChrome
            vertical: true
            anchors { right: tray.left; rightMargin: Theme.s6; bottom: parent.bottom; bottomMargin: 24 }
            height: 26
            tone: 0.72
            strength: bar.zoneLive ? 0.30 : 0.16
            visible: tray.width > 0
            Behavior on strength { NumberAnimation { duration: Theme.durBase } }
        }

        // ═════════════════════════════════════════════════════════════════
        //  the Tray — StatusNotifier items.
        //
        //  There was NO system tray anywhere in the shell. Every desktop this
        //  build asks to be compared with has one, and without it any third-party
        //  program that lives in the background — a VPN client, a sync agent, a
        //  chat app — has no way to be reachable at all. It collapses to zero
        //  width when nothing is registered, so an empty tray costs no space and
        //  draws no furniture.
        // ═════════════════════════════════════════════════════════════════
        Row {
            id: tray
            z: bar.zChrome
            anchors {
                right: gaugeRail.left
                rightMargin: Theme.s6
                bottom: parent.bottom
                bottomMargin: 24
            }
            height: 26
            spacing: Theme.s4
            visible: width > 0

            Item {
                id: usbChip
                visible: UsbWatch.devices.length > 0
                width: visible ? 22 : 0
                height: 26

                Text {
                    anchors.centerIn: parent
                    // MEASURED 2026-09-08: U+F287 (usb) is NOT in the font this
                    // renders with. `Theme.fIcon` resolves to Font Awesome 7
                    // Free *Solid*, and usb is a BRAND glyph — it lives only in
                    // Font Awesome Brands, which is a separate family. So this
                    // chip has been drawing a tofu box every time a drive was
                    // plugged in, for as long as the chip has existed.
                    //
                    // U+F0A0 (hard-drive) is in Solid, was verified present in
                    // the installed file rather than assumed, and says the same
                    // thing the caption already says: "Removable". Pulling in a
                    // second font family for one icon would be the worse fix.
                    text: "\uf0a0"
                    font.family: Theme.fIcon
                    font.pixelSize: 13
                    color: Theme.text
                    opacity: usbHov.hovered || Bus.usbDockOpen ? 1.0 : 0.78
                    Behavior on opacity { NumberAnimation { duration: Theme.durQuick } }
                }
                HoverHandler {
                    id: usbHov
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: {
                        if (hovered) {
                            var names = [];
                            var ds = UsbWatch.devices;
                            for (var i = 0; i < ds.length; i++)
                                names.push(ds[i].name);
                            caption.hold(names.join(", ") || qsTr("Removable"),
                                         tray.x + usbChip.x + usbChip.width / 2,
                                         "usbchip");
                        } else if (caption.owner === "usbchip") {
                            caption.release();
                        }
                    }
                }
                TapHandler {
                    onTapped: {
                        bar.tell(tray.x + usbChip.x + usbChip.width / 2);
                        Bus.toggleUsbDock();
                    }
                }
            }

            Repeater {
                model: SystemTray.items ? SystemTray.items.values : []
                delegate: Item {
                    id: trayItem
                    required property var modelData
                    required property int index
                    width: bar.barTrayCell
                    height: 26

                    Image {
                        id: trayIcon
                        anchors.centerIn: parent
                        width: bar.barTrayPx
                        height: bar.barTrayPx
                        // Rasterised at the size it is drawn — see the dock icon
                        // above for why 2× was making fine line art mushy.
                        sourceSize.width: bar.barTrayPx
                        sourceSize.height: bar.barTrayPx
                        smooth: true
                        fillMode: Image.PreserveAspectFit
                        source: trayItem.modelData.icon
                        opacity: trayHov.hovered ? 1.0 : 0.78
                        Behavior on opacity { NumberAnimation { duration: Theme.durQuick } }
                    }
                    // The dock icons' mirrored fall, on the tray too — these
                    // were the only icons standing on the Line without it
                    // (owner, 2026-08-14: the mirror "needs to also be
                    // complete"). Reflection.qml is the dock recipe packaged.
                    Reflection {
                        anchors.top: trayIcon.bottom
                        anchors.topMargin: bar.reflectGap
                        anchors.horizontalCenter: trayIcon.horizontalCenter
                        width: trayIcon.width
                        height: trayIcon.height
                        strength: trayIcon.opacity
                        Image {
                            anchors.fill: parent
                            sourceSize.width: 17
                            sourceSize.height: 17
                            smooth: true
                            fillMode: Image.PreserveAspectFit
                            source: trayIcon.source
                        }
                    }
                    HoverHandler {
                        id: trayHov
                        cursorShape: Qt.PointingHandCursor
                        onHoveredChanged: {
                            if (hovered) {
                                caption.hold(trayItem.modelData.tooltipTitle
                                             || trayItem.modelData.title || "",
                                             tray.x + trayItem.x + trayItem.width / 2,
                                             "tray:" + trayItem.index);
                            } else if (caption.owner === "tray:" + trayItem.index) {
                                caption.release();
                            }
                        }
                    }
                    TapHandler {
                        onTapped: {
                            bar.tell(tray.x + trayItem.x + trayItem.width / 2);
                            trayItem.modelData.activate();
                        }
                    }
                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: trayItem.modelData.secondaryActivate()
                    }
                }
            }
        }

        Rail {
            id: gaugeRail
            z: bar.zChrome
            vertical: true
            anchors { right: gauge.left; rightMargin: Theme.s6; bottom: parent.bottom; bottomMargin: 24 }
            height: 26
            tone: 0.88
            strength: bar.zoneLive ? 0.30 : 0.16
            Behavior on strength { NumberAnimation { duration: Theme.durBase } }
        }

        // ═════════════════════════════════════════════════════════════════
        //  the Gauge — bottom right. Vitals, the Crest, the clock.
        // ═════════════════════════════════════════════════════════════════
        Item {
            id: gauge
            z: bar.zChrome
            anchors {
                right: parent.right
                rightMargin: Theme.s7
                bottom: parent.bottom
                bottomMargin: 18
            }
            // Whole pixels, for the same reason as the Sigil above — the Gauge is
            // right-anchored, so a fractional width lands the tray icons, the
            // vitals and the clock's glyphs off the pixel grid.
            width: Math.ceil(gaugeRow.width)
            height: 44

            readonly property bool lit: gaugeHover.hovered || Bus.flyoutOpen

            Row {
                id: gaugeRow
                height: gauge.height
                spacing: Theme.s6

                // ── the Crest · one adaptive slot ────────────────────────
                // Not a tray that grows. One slot that always holds the single
                // most important live thing, so the clock never moves and a
                // finished download never covers your work with a card.
                Item {
                    id: crest
                    height: parent.height
                    width: crestText.text.length > 0 ? crestBody.width + Theme.s6 : 0
                    clip: true
                    opacity: crestText.text.length > 0 ? 1 : 0

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.durSettle
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveRise
                        }
                    }
                    Behavior on opacity { NumberAnimation { duration: Theme.durBase } }

                    property string noticeSummary: ""
                    property string noticeApp: ""
                    function announce(summary, appName) {
                        noticeSummary = summary;
                        noticeApp = appName;
                        noticeLife.restart();
                    }
                    Timer {
                        id: noticeLife
                        interval: 6000
                        onTriggered: {
                            crest.noticeSummary = "";
                            crest.noticeApp = "";
                        }
                    }

                    // Priority, highest first. Exactly one of these is on screen.
                    readonly property int mode:
                          (Sys.hasBattery && Sys.batteryPercent <= 15 && !Sys.batteryCharging) ? 1
                        : (noticeSummary.length > 0) ? 2
                        : 0

                    HoverHandler { id: crestHov; cursorShape: Qt.PointingHandCursor }
                    // The Crest is not just a readout — it answers, and WIP-101
                    // says it must answer about the thing it is currently showing.
                    // It already changes meaning by mode: low battery, a waiting
                    // notification, or what is playing. Sending all three to the
                    // same generic panel threw that away and made the owner hunt
                    // for his subject in a page of six sections.
                    //
                    // Mode 3 used to be NOW PLAYING here. Owner 2026-08-20:
                    // that line lives in the MIDDLE of the bar, same type as
                    // a notice, not a second copy in the Gauge.
                    TapHandler {
                        onTapped: {
                            if (crest.mode === 2)
                                Bus.openFlyoutAt("notifications");
                            else if (crest.mode === 1)
                                Bus.openFlyoutAt("battery");
                            else
                                Bus.toggleFlyout();
                        }
                    }

                    Column {
                        id: crestBody
                        opacity: crestHov.hovered ? 1.0 : 0.86
                        Behavior on opacity { NumberAnimation { duration: Theme.durQuick } }
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1

                        Text {
                            text: crest.mode === 1 ? qsTr("BATTERY LOW")
                                : crest.mode === 2 ? (crest.noticeApp || "NOTICE").toUpperCase()
                                : crest.mode === 3 ? "NOW PLAYING" : ""
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                            font.weight: Font.Medium
                            font.letterSpacing: Theme.trackMicro
                            color: crest.mode === 1 ? Theme.danger : Theme.textDim
                        }
                        Text {
                            id: crestText
                            width: Math.min(implicitWidth, 260)
                            text: crest.mode === 1 ? Sys.batteryPercent + "% remaining"
                                : crest.mode === 2 ? crest.noticeSummary
                                : crest.mode === 3 ? ((Sys.player.trackTitle || "Unknown track")
                                                      + (Sys.player.trackArtist ? "  ·  " + Sys.player.trackArtist : ""))
                                : ""
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            color: Theme.text
                            elide: Text.ElideRight
                        }
                    }
                }

                // ── vitals · drawn, not a borrowed icon font (Vitals.qml) ──
                Item {
                    height: parent.height
                    width: vitalsRow.width

                    Vitals {
                        id: vitalsRow
                        anchors.verticalCenter: parent.verticalCenter
                        tone: gauge.lit ? Theme.text : Theme.textMuted
                    }

                    // ── the vitals' reflection ─────────────── TRK-3826 ──
                    // Owner, 2026-09-07: "everything else on the right side
                    // ... dont have the mirrored imaige underneath it".
                    // These three were the last icons on the plate standing
                    // on nothing — the SystemTray items beside them have had
                    // the fall since 2026-08-14, which is what made the two
                    // halves of the tray read as different builds.
                    //
                    // ⚠ THE REFLECTION IS HERE AND NOT IN `Vitals.qml`,
                    // deliberately. Vitals is a `Row`, so a child added to
                    // it is LAID OUT BY IT — a reflection declared inside
                    // would take a fourth slot in the row and push the
                    // battery sideways. It belongs to the call site, which
                    // owns the box the row sits in.
                    //
                    // ⚠ AND IT IS A SECOND `Vitals`, NOT COPIED SHAPES. The
                    // three indicators are ~200 lines of `Shape`/`PathAngleArc`
                    // geometry, and hand-copying them here is the drift
                    // failure this whole row exists to fix. The instance is
                    // bound to the same `tone`, so it lights with the Gauge,
                    // and to the same `Sys` state, so the mirrored battery
                    // reads the real charge.
                    Reflection {
                        anchors.top: vitalsRow.bottom
                        anchors.topMargin: bar.reflectGap
                        anchors.left: vitalsRow.left
                        width: vitalsRow.width
                        height: vitalsRow.height
                        Vitals {
                            width: vitalsRow.width
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            tone: gauge.lit ? Theme.text : Theme.textMuted
                        }
                    }
                }

                // The clock used to close this Row. Owner ruling 2026-08-09:
                // the clock and date live at the CENTER of the bar — see the
                // midClock Item below the Gauge.
            }

            // Underlines the whole Gauge when it is live, at the plum end of the
            // sweep — the same language as an app's root in the Row.
            Rectangle {
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    bottomMargin: -Theme.s3
                }
                height: 2
                radius: 1
                width: gauge.lit ? gauge.width : 0
                color: Theme.sweep4
                opacity: Bus.flyoutOpen ? 1.0 : 0.55
                Behavior on width {
                    NumberAnimation {
                        duration: Theme.durBase
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveMove
                    }
                }
            }

            HoverHandler { id: gaugeHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: Bus.toggleFlyout() }
        }

        // ═════════════════════════════════════════════════════════════════
        //  the Meridian — the clock and date, dead centre of the bar.
        //  Owner ruling 2026-08-09: "the clock and date in the middle." It
        //  keeps the Gauge's type exactly (largest type in the chrome, tnum
        //  so the width never jitters) and WIP-103's tap-goes-to-the-Clock.
        //
        //  ── Agent AE · BRIEF_AGENT_AE_2026-08-12 — the Meridian flips to a
        //  music dial ────────────────────────────────────────────────────
        //  Owner: "when im playing music... it would flip into a music dial
        //  where it shows whats playing the artist back forward skip... and
        //  maybe... a little graph... that goes to the beat of the music."
        //  On the toggle: "only if music is playing it can do that" — the
        //  flip is DORMANT unless a player has a track.
        //
        //  THE STATE TABLE (the brief's acceptance test):
        //    no player, or no track   → clock+date; tap opens the Clock app
        //    player WITH a track      → dial (DEFAULT); tap flips to clock
        //    player, showing clock    → clock+date;   tap flips back to dial
        //    player/track goes away   → clock+date, AUTOMATICALLY
        //
        //  Gated on `Sys.playerHasTrack`, never on `Sys.playerPlaying` — a
        //  supervisor ruling: if the owner pauses, the dial must STAY so he
        //  can hit play from here. Paused is not gone.
        //
        //  WIDTH. The comment above already warns a differently-sized panel
        //  swapping in twitches the bar's centre. Track TITLES are not fixed
        //  length either, so tracking the dial's natural content would
        //  twitch on every SONG too, which is the same regression by a
        //  different door. Fix: `dialW` below is a CONSTANT the dial's text
        //  elides into, so nothing moves while a track — or the toggle — is
        //  showing. The one width change that legitimately happens (clock-
        //  sized ↔ dial-sized, at a real state change: a player appearing or
        //  the owner tapping) is ANIMATED with the same Behavior the Gauge's
        //  Crest slot already uses for its own adaptive width, a few dozen
        //  lines up, so it reads as a considered flip and not a snap.
        //
        //  CAVA. A THIRD, independent cava instance — NOT Beat.qml's (that
        //  one answers to the Living Paint toggle and must not vanish here
        //  if the owner has that off) and NOT ~/.config/nyxus/pulse-cava.conf
        //  (bars=2, drives the halo — untouched). Its own config,
        //  ~/.config/nyxus/bar-cava.conf, ships in skel. `running:` below is
        //  bound to `Sys.playerHasTrack` alone — that property flipping
        //  false is the only way the process stops, which is the entire
        //  "provably exits" proof.
        // ═════════════════════════════════════════════════════════════════
        Item {
            id: midClock
            z: bar.zChrome
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: 18
            }

            // Row 1 of the table covers a REGISTERED player with nothing
            // queued too ("no player, or no track loaded") — `hasPlayer`
            // alone is not that question, `playerHasTrack` is.
            readonly property bool dialEligible: Sys.playerHasTrack
            // Docked overlay (or no overlay in Appearance): the middle of
            // the bar reads like a notice — NOW PLAYING over the title —
            // the same two-line type as the Gauge Crest. Not a glass dial.
            readonly property bool showNotice: Sys.playerHasTrack
                && (!Prefs.mediaBarPop || Bus.mediaCrestDocked)
            property bool showDial: false
            onDialEligibleChanged: if (!dialEligible) showDial = false

            width: showNotice
                ? Math.ceil(midNotice.width) + Theme.s6
                : Math.ceil(midClockCol.width) + Theme.s6
            height: 44
            Behavior on width {
                NumberAnimation {
                    duration: Theme.durSettle
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveRise
                }
            }

            // ── the clock face (WIP-103, untouched) ─────────────────────
            Column {
                id: midClockCol
                anchors.centerIn: parent
                spacing: 0
                visible: !midClock.showNotice && !(midClock.dialEligible && midClock.showDial)

                Text {
                    id: midClockTime
                    anchors.horizontalCenter: parent.horizontalCenter
                    // WIP-103. The bar clock follows the user's format
                    // preference, which Settings owns and Prefs reads.
                    // ⚠ `Prefs.timeFmt`, NEVER A LOCAL BRANCH — TRK-3728, and this
                    // line is the survivor that proves why the rule exists. Qt
                    // reads `h` as 0-23 unless an AM/PM marker shares the format
                    // string, so the old `clock24h ? "HH:mm" : "h:mm"` drew a
                    // 24-hour clock on BOTH arms and the toggle's entire effect
                    // was stripping a leading zero. Measured on this Qt:
                    //   00:27  h:mm -> "0:27"   h:mm AP -> "12:27 AM"
                    //   13:47  h:mm -> "13:47"  h:mm AP -> "1:47 PM"
                    // He reported it once ("i cant even chage the 24hr to 12hr
                    // format ... i dont see the time change"), nine sites were
                    // migrated to `Prefs.timeFmt`, and this one was missed — so
                    // he reported the SAME defect again on 2026-09-07, reading
                    // "0:27" off his own bar. The fix was right; the migration
                    // was incomplete, which is its own failure class.
                    // scripts/verify-time-format.py greps for the FORMAT STRINGS
                    // rather than the branch, because two of the other survivors
                    // were bare literals with no branch for a search to find.
                    text: Qt.formatDateTime(clock.date, Prefs.timeFmt)
                    // The bar clock is the most-looked-at string in the build and
                    // it was set in the TITLE face at Light — a text weight, on a
                    // lit galaxy, with nothing behind it. At 20px Light over a
                    // starfield the strokes are thinner than the stars they cross,
                    // which is why it read as floating rather than as chrome.
                    // `fTech` is what the desk clock and the Clock panel already
                    // wear, so all three timepieces in the build now speak with
                    // one voice instead of three; the weight comes up because
                    // Orbitron is a display face and Light is not a weight it has.
                    font.family: Theme.fTech
                    font.pixelSize: Theme.tTitle
                    font.weight: Theme.wLabel
                    font.letterSpacing: Theme.trackTech
                    font.features: ({ "tnum": 1 })
                    color: Theme.text
                }
                Text {
                    id: midClockDate
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "ddd d MMM").toUpperCase()
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    font.weight: Font.Medium
                    font.letterSpacing: Theme.trackMicro
                    color: midClockHover.hovered ? Theme.textMuted : Theme.textDim
                    Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                }
            }

            // ── the Meridian's reflection ──────────────────── TRK-3826 ──
            // Owner, 2026-09-07: "the clock and date ... dont have the
            // mirrored imaige underneath it".
            //
            // ⚠ THE COLUMN IS MIRRORED, NOT THE TWO LINES SEPARATELY, and
            // that is forced rather than stylistic: the date sits directly
            // under the clock, so a reflection of the CLOCK alone would land
            // on top of the date and make two readouts illegible at once —
            // the same text-over-text defect TRK-3817 fixed for the lyrics.
            // Flipping the whole column about its base puts the date's
            // mirror nearest the glass and the clock's below it, which is
            // what the surface would actually return.
            //
            // ⚠ THE TIME STRING IS BOUND, NEVER RE-FORMATTED. `Prefs.timeFmt`
            // is written ONCE in this file (TRK-3728: nine sites were
            // migrated and one survivor drew "0:27" on his bar for weeks). A
            // mirror that formatted its own copy would be the tenth site,
            // and it would be invisible — nobody proof-reads a reflection.
            // `scripts/verify-time-format.py` greps for format strings, so a
            // second literal here is exactly what it exists to catch.
            Reflection {
                anchors.top: midClockCol.bottom
                anchors.topMargin: bar.reflectGap
                anchors.horizontalCenter: midClockCol.horizontalCenter
                visible: midClockCol.visible
                width: midClockCol.width
                height: midClockCol.height
                Column {
                    anchors.centerIn: parent
                    spacing: midClockCol.spacing
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: midClockTime.text
                        font: midClockTime.font
                        color: midClockTime.color
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: midClockDate.text
                        font: midClockDate.font
                        color: midClockDate.color
                    }
                }
            }

            // Same two-line type as the Gauge Crest's notice — NOW PLAYING
            // over the title · artist. Owner 2026-08-20: the docked player
            // lives here in the middle and must read like those notices,
            // not like a glass music dial.
            Column {
                id: midNotice
                anchors.centerIn: parent
                spacing: 1
                visible: midClock.showNotice
                opacity: midClockHover.hovered ? 1.0 : 0.86
                Behavior on opacity { NumberAnimation { duration: Theme.durQuick } }

                Text {
                    id: midNoticeLabel
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("NOW PLAYING")
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    font.weight: Font.Medium
                    font.letterSpacing: Theme.trackMicro
                    color: Theme.textDim
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.min(implicitWidth, 260)
                    text: (Sys.playerTitle || qsTr("Unknown track"))
                          + (Sys.playerArtist ? "  ·  " + Sys.playerArtist : "")
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    color: Theme.text
                    id: midNoticeLine
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // The notice takes the Meridian's place while music is up, which
            // is most of the time this bar is being looked at — so it needs
            // the fall too, or the middle of the plate loses its reflection
            // exactly when the owner is watching it. Same flip-the-column
            // rule as the clock above, for the same text-over-text reason.
            Reflection {
                anchors.top: midNotice.bottom
                anchors.topMargin: bar.reflectGap
                anchors.horizontalCenter: midNotice.horizontalCenter
                visible: midNotice.visible
                strength: midNotice.opacity
                width: midNotice.width
                height: midNotice.height
                Column {
                    anchors.centerIn: parent
                    spacing: midNotice.spacing
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: midNoticeLabel.text
                        font: midNoticeLabel.font
                        color: midNoticeLabel.color
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: midNoticeLine.width
                        text: midNoticeLine.text
                        font: midNoticeLine.font
                        color: midNoticeLine.color
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // ── the music dial ────────────────────────────────────────────
            // TRK-3370 — the dial plate wears the widgets' CURRENT stack
            // (SetSlab: floor + panelMid + swellGround + glacier[4] seam). The
            // surfaceTop/Mid/Deep + glassBorder gradient it carried was the
            // pre-slab material and no longer matched the widgets beside it.
            Item {
                id: dialPane
                anchors.fill: parent
                visible: midClock.dialEligible && midClock.showDial && !midClock.showNotice

                SetSlab {
                    anchors.fill: parent
                    cornerRadius: Theme.r1
                }

                Row {
                    id: dialRow
                    anchors.centerIn: parent
                    spacing: Theme.s3

                    // previous / skip-back
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""
                        font.family: Theme.fIcon
                        font.pixelSize: Theme.tBody
                        color: Sys.playerCanGoPrevious
                            ? (prevHover.hovered ? Theme.text : Theme.textMuted)
                            : Theme.textDim
                        opacity: Sys.playerCanGoPrevious ? 1.0 : 0.4
                        HoverHandler { id: prevHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: Sys.playerPrevious() }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0
                        Text {
                            width: 108
                            // The dial only exists while `dialEligible`, which IS
                            // `playerHasTrack` — so the old `|| "Unknown track"`
                            // here could never render, and reading it invited the
                            // WIP-640(b) mistake back in. Gone; the title is the
                            // title.
                            text: Sys.playerTitle
                            elide: Text.ElideRight
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            font.weight: Font.Medium
                            color: Theme.text
                        }
                        Text {
                            width: 108
                            text: Sys.playerArtist
                            elide: Text.ElideRight
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                            font.letterSpacing: Theme.trackMicro
                            color: Theme.textDim
                        }
                    }

                    // the spectrum analyser — cava-fed, plum family only.
                    // WIP-523 the same day put near-white/hot-pink on the
                    // window rim at red-green +76..+114 and the owner
                    // rejected it on sight; this stays on Theme.sweep3 /
                    // Theme.sweep4, the "plum end of the sweep" tokens the
                    // Gauge's own underline already uses a few dozen lines up
                    // this file — never a literal hex.
                    Row {
                        id: spectrumRow
                        anchors.verticalCenter: parent.verticalCenter
                        height: 20
                        spacing: 2
                        Repeater {
                            model: midClock.barsN
                            delegate: Rectangle {
                                required property int index
                                width: 3
                                radius: 1
                                anchors.bottom: parent.bottom
                                height: Math.max(2, midClock.cavaLevels[index] * 20)
                                color: (index % 2 === 0) ? Theme.sweep3 : Theme.sweep4
                                opacity: 0.4 + midClock.cavaLevels[index] * 0.6
                                Behavior on height {
                                    NumberAnimation {
                                        duration: Theme.durQuick
                                        easing.type: Easing.Bezier
                                        easing.bezierCurve: Theme.curveMove
                                    }
                                }
                            }
                        }
                    }

                    // play / pause — glacier[0] ice, same as Widgets now-playing
                    // (TRK-968). sweep0 `#0aa2d6` is leftover teal, not a button.
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Sys.playerPlaying ? "" : ""
                        font.family: Theme.fIcon
                        font.pixelSize: Theme.tHead
                        color: Theme.paintLayers.glacier[0]
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: Sys.playerTogglePlaying() }
                    }

                    // next / skip-forward
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""
                        font.family: Theme.fIcon
                        font.pixelSize: Theme.tBody
                        color: Sys.playerCanGoNext
                            ? (nextHover.hovered ? Theme.text : Theme.textMuted)
                            : Theme.textDim
                        opacity: Sys.playerCanGoNext ? 1.0 : 0.4
                        HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: Sys.playerNext() }
                    }
                }
            }

            // ── the dial's own cava — see the header comment above. A
            // SplitParser line is one raw ascii frame, "123;456;...;\n",
            // `barsN` values 0..1000 (bar-cava.conf's ascii_max_range). Each
            // frame is exponentially smoothed against the last so the bars
            // settle rather than flicker.
            readonly property int barsN: 14
            property var cavaLevels: {
                const z = []; for (let i = 0; i < barsN; i++) z.push(0); return z;
            }
            readonly property string cavaConfPath:
                Quickshell.env("HOME") + "/.config/nyxus/bar-cava.conf"

            function _onCavaFrame(line) {
                const parts = line.split(";");
                const out = [];
                for (let i = 0; i < parts.length; i++) {
                    if (parts[i].length === 0) continue;
                    const v = parseInt(parts[i], 10);
                    out.push(isNaN(v) ? 0 : Math.min(1, Math.max(0, v / 1000)));
                }
                if (out.length === 0) return;
                const prev = cavaLevels;
                const next = [];
                for (let j = 0; j < out.length; j++) {
                    const p = (prev.length === out.length) ? prev[j] : 0;
                    next.push(p * 0.55 + out[j] * 0.45);
                }
                cavaLevels = next;
            }

            Process {
                id: meridianCava
                // Only while the opt-in clock dial is showing. Beat.qml's
                // cava is a different process (living paint).
                running: Sys.playerHasTrack && midClock.showDial
                command: ["cava", "-p", midClock.cavaConfPath]
                stdout: SplitParser {
                    onRead: data => midClock._onCavaFrame(data)
                }
                onRunningChanged: {
                    if (!running) {
                        const z = [];
                        for (let i = 0; i < midClock.barsN; i++) z.push(0);
                        midClock.cavaLevels = z;
                    }
                }
            }

            HoverHandler { id: midClockHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    if (midClock.showNotice) {
                        if (Prefs.mediaBarPop)
                            Bus.mediaCrestDocked = false;
                        else if (Sys.hasPlayer)
                            Sys.player.togglePlaying();
                    } else {
                        Bus.toggleClock();
                    }
                }
            }
        }
    }

    // ══ BACK FACE · THE ANALYSER, INSIDE THE BAR ════════════════════════
    // The one thing on this side. No Sigil, no Row, no clock: the owner
    // asked for "those graphs ... on there own", and a back face carrying
    // half the front face's widgets would be a mode, not a side. That part
    // is unchanged.
    //
    // ══ TRK-3778 · THE z IS BACK AT zChrome, AND WHY IT SHOULD BE ═══════
    // ⚠ THIS BLOCK REPLACES A COMMENT THAT WAS CONFIDENTLY WRONG. The
    // superseded text is not preserved verbatim — a wrong explanation left
    // in a file is a wrong explanation that gets believed — but the MISTAKE
    // is preserved, because it is the interesting part.
    //
    // TRK-3741 read the owner's "the swirls are still behind the graph" as
    // the swirls being HIDDEN, and answered it by dropping this plate from
    // `zChrome` to `zPaint` so the living paint would composite up through
    // the field's gaps. The reasoning was internally consistent and it
    // pointed the wrong way: he meant the swirls were SHOWING THROUGH and he
    // did not want them there. The change made the defect worse and the
    // comment explaining it made the error durable. He then said it in
    // words that cannot be read twice, 2026-09-06:
    //
    //   "this is how i want the visulizer to be WITH OUT THE SWIRLS BEHOND
    //    IT its suppose to flip over to this when music plays then
    //    backnormal when no music playing"
    //
    // ══ AND IT DOES NOT REOPEN "TAKES OVER THE BOTTOM BAR" ══════════════
    // That complaint was about a sheet drawn ON a bar that was otherwise
    // still the bar — two things competing for one surface. What ships now
    // is a FLIP: the panel turns over, and the face you are looking at is
    // the only face there is. A panel's reverse side is opaque; that is what
    // makes it a side rather than a film. So this plate sits at `zChrome`
    // (it owns the surface while it is showing) AND carries its own opaque
    // ground (BarSpectrum § THE GROUND), and neither of those is a
    // regression because the flip is what changed underneath them.
    //
    // The z costs nothing when music is not playing: every front-face plate
    // is `visible: false` past 90° and so is this one below it — FlipPlate's
    // own `_cos >= 0` — so at rest this is an invisible item, not a
    // transparent one.
    // ⚠ TRK-3813 · AND NOW IT IS zPaint AFTER ALL — FOR A THIRD REASON ══
    // Read the block above before this one: it argues the z back UP to
    // zChrome, and it was right about the defect and wrong about the
    // mechanism, which is why this is the third time this one number has
    // moved. The history in one line each:
    //
    //   TRK-3741  zChrome → zPaint, to let the swirl show through the
    //             field's gaps. Read his sentence backwards; made it worse.
    //   TRK-3778  zPaint → zChrome, to stop the swirl showing through.
    //             Correct outcome, wrong lever.
    //   TRK-3813  zChrome → zPaint, because the CHROME has to be above it.
    //
    // ⚠ THE SWIRL IS NOT COMING BACK, AND THE Z IS NOT WHAT WAS HOLDING IT
    // OUT. TRK-3778 shipped the fix that actually works: BarSpectrum's own
    // FULLY OPAQUE ground (§ THE GROUND). An opaque ground blocks what is
    // beneath it at any z — that is what opaque means — so the z was never
    // load-bearing for that ruling and moving it costs nothing he asked
    // for. The gate for it is a pixel count on the face, not this number.
    //
    // What the z IS load-bearing for is the regression above: this plate is
    // declared AFTER the chrome plate, so at an equal z the later sibling
    // wins and an opaque instrument would paint straight over Start — the
    // exact bug being fixed, arriving by a different route. zPaint puts it
    // under every `zChrome` widget while leaving it above the living paint,
    // which is where a background belongs.
    FlipPlate {
        anchors.fill: parent
        z: bar.zPaint
        angle: bar.flipAngle
        face: 180

        BarSpectrum {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: Theme.chromeH
            // The bar's own controls, so a lyric phrase never lands on one.
            // See § THE NAMED ZONES above and BarSpectrum § THE KEEP-OUT.
            keepOut: bar.chromeKeepOut
            // TRK-3713 — 76 of the 84 px zone, was 64. Round 1 held back
            // 20 px on the argument that a full-height bar "turns the
            // horizon into a rectangle", which DESIGN_LANGUAGE_HORIZON does
            // forbid. That argument was about a 30 px-wide slab: sixty-four
            // of those at full height IS a rectangle. Round 2 draws 3 px
            // lines with a 2 px gap, so the field is 62% air at its very
            // tallest and reads as spikes however far they reach — and the
            // owner asked for "the whole bar shooting up and down". The
            // remaining 8 px is still the Shelf's own gradient.
            peakH: Theme.chromeH - 8
        }
    }

    // One clock for the whole bar, at MINUTE precision: the shell wakes 60×
    // less often than the old one-second Timer, and the display never showed
    // seconds anyway. Idle cost is the point of this build.
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ══════════════════════════════════════════════════════════════════
    //  RIGHT-CLICK · WIP-126
    //
    //  Kept as ONE contiguous block at the end of the file on purpose: a
    //  second session is working through this shell adding glass, and a
    //  feature scattered across eight call sites is a feature that conflicts
    //  in eight places. Everything the menu needs is here.
    //
    //  ── WHY ONE HANDLER AND NOT ONE PER WIDGET ───────────────────────
    //
    //  The obvious build is a TapHandler on each zone. It is wrong here for
    //  the same reason WIP-101 was wrong: the bar's widgets are laid out by
    //  anchors inside Rows inside Items, and a handler per widget means the
    //  gaps BETWEEN them have no handler at all — so right-clicking two
    //  pixels of background between the clock and the tray would do nothing,
    //  which is the exact failure this row exists to remove.
    //
    //  One handler on the bar, hit-testing the named zones, means every
    //  pixel of the bar answers. The bare-bar menu is the fallback, not the
    //  gap.
    // ══════════════════════════════════════════════════════════════════
    TapHandler {
        acceptedButtons: Qt.RightButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: (evt) => bar.openZoneMenu(evt.position.x, evt.position.y)
    }

    // ══ THE NAMED ZONES · ONE LIST, TWO READERS ═════════════ TRK-3817 ══
    //  These are the bar's functional elements. `openZoneMenu` hit-tests
    //  them to answer a right-click; `chromeKeepOut` inverts them so the
    //  analyser's lyric phrases land in the gaps instead of on top of a
    //  control. ⚠ THE TWO READERS SHARE THIS LIST ON PURPOSE. A phrase
    //  keep-out written as its own pixel ranges would be a second copy of
    //  the bar's layout, and the zones MOVE: the Meridian is a clock at
    //  rest and a two-line NOW PLAYING notice while music plays — which is
    //  exactly when lyrics exist — the Tray collapses to zero width with
    //  nothing registered, and the Row grows with every open window.
    //
    //  ⚠ WHAT IS NOT IN IT, AND WHY. `sigilRail`, `trayRail`, `gaugeRail`
    //  are Rails: `implicitWidth: 1` when vertical. They are chrome, and
    //  they are left out because a phrase crossing a one-pixel divider
    //  loses nothing while excluding them would SPLIT each free run in two,
    //  and there are only two runs wide enough for a phrase on the whole
    //  bar. The dock's `caption` is out for a different reason: it exists
    //  only while the pointer is on an icon, and a keep-out that follows
    //  his mouse would make the lyrics jump every time he moved it.
    //  `usbChip` is a child of `tray` and is covered by it.
    readonly property var chromeZones: [sigil, row, desks, tray, gauge, midClock]

    // The same zones as SCENE-x spans, for BarSpectrum.keepOut. Scene rather
    // than bar-local so that nothing here has to name the analyser, which is
    // what keeps this out of a binding loop with `keepOut` — see
    // BarSpectrum § THE KEEP-OUT. An invisible or zero-width zone
    // contributes nothing, exactly as `inZone` returns false for one.
    readonly property var chromeKeepOut: {
        const out = [];
        const zs = bar.chromeZones;
        for (let i = 0; i < zs.length; i++) {
            const it = zs[i];
            // ⚠ x/width/visible are read explicitly, not merely used inside
            // mapToItem: a QML binding captures the properties it READ, and
            // mapToItem is a function call that captures nothing. Without
            // these three reads the spans would be computed once at startup
            // and never again — a keep-out frozen to the layout the bar had
            // before the Meridian became a NOW PLAYING notice.
            if (!it || !it.visible || it.width <= 0 || it.height <= 0
                    || it.x < 0)
                continue;
            const p0 = it.mapToItem(null, 0, 0);
            if (!p0)
                continue;
            out.push([p0.x, p0.x + it.width]);
        }
        return out;
    }

    // True when (x,y) in bar coordinates falls inside `it`. mapToItem rather
    // than comparing raw x/y: these zones are nested at different depths and
    // their x is relative to their own parent, not to the bar.
    function inZone(it, x, y) {
        if (!it || !it.visible || it.width <= 0)
            return false;
        // Through contentItem, not the window. `bar` is a PanelWindow, and
        // mapToItem is a QQuickItem method -- on a Window it is undefined, so
        // this threw a TypeError on every call and inZone() never answered.
        // qmllint flagged it; nothing was reading that warning class until
        // WIP-130.
        const p = bar.contentItem.mapToItem(it, x, y);
        return p.x >= 0 && p.y >= 0 && p.x <= it.width && p.y <= it.height;
    }

    // TRK-3435 — shipped-first PATH through `env`, so argv never crosses a
    // shell. Same form as MediaSource.qml's lyric fetch and SetPage*'s
    // `execPath`; HardwareCaps.qml carries the ruling.
    readonly property string shippedPath: "PATH="
        + (Quickshell.env("NYXUS_BIN_DIR") || "/usr/local/bin")
        + ":" + Quickshell.env("PATH")

    function openZoneMenu(x, y) {
        let title = "Shelf";
        let entries = [];

        if (bar.inZone(midClock, x, y) && midClock.showNotice) {
            // ── TRK-3817 · THE TAPE ─────────────────────────────
            // The arm control lives HERE, in the menu the Meridian already
            // answers while a track is showing, and it costs the bar ZERO
            // pixels. That is not a stylistic preference: the bar's chrome was
            // eaten once already today by the visualiser flip, and a second
            // lane is carving keep-out spans (`bar.chromeZones` above) so the
            // lyrics stop landing on the clock and the tray. A new fixed-width
            // chip would have collided with both, and the owner would have
            // found it before we did.
            //
            // Left-click on this zone is already two-faced on `showNotice`
            // (play/pause vs the calendar); right-click now matches it, so the
            // zone answers about what it is currently SHOWING rather than
            // always about the clock.
            title = "Now playing";
            entries = [
                // ⚠ NOT A DEAD TOGGLE, and not a wish either: `check` is bound
                // to what the daemon PUBLISHES, so if the tape dies the tick
                // goes away by itself. The label says which way pressing goes.
                { label: TapeState.armed ? qsTr("Stop keeping songs")
                                         : qsTr("Keep the songs I play"),
                  check: TapeState.armed,
                  cmd: ["env", bar.shippedPath, "nyxus-tape", "--toggle"] },
                // The honest reading of the armed state. Arming mid-song does
                // not keep that song — see nyxus-tape's header — so the menu
                // says so out loud rather than letting him expect a file that
                // is never going to arrive.
                { label: TapeState.waitingForNextTrack
                         ? qsTr("Starts with the next song")
                         : TapeState.armed
                           ? qsTr("Keeping: %1").arg(TapeState.taping)
                           : qsTr("Not keeping anything"),
                  enabled: false },
                { separator: true },
                { label: qsTr("Open my kept songs…"), cmd: ["nyxus-media"] },
                { label: qsTr("Sound settings…"), cmd: ["nyxus-settings", "sound"] }
            ];
        } else if (bar.inZone(midClock, x, y)) {
            title = "Clock";
            entries = [
                { label: qsTr("24-hour time"), check: Prefs.clock24h,
                  cmd: ["nyxus-settings", "datetime"] },
                { label: qsTr("Show seconds"), check: Prefs.clockShowSeconds,
                  cmd: ["nyxus-settings", "datetime"] },
                { separator: true },
                { label: qsTr("Calendar…"), action: function () { Bus.toggleClock(); } },
                { label: qsTr("Date & time settings…"), cmd: ["nyxus-settings", "datetime"] }
            ];
        } else if (bar.inZone(gauge, x, y)) {
            // The Gauge kept the Clock menu after the clock moved to the
            // Meridian — right-clicking vitals answered about a readout
            // that was no longer there. It answers about status now.
            title = "Status";
            entries = [
                { label: qsTr("Quick settings"), action: function () { Bus.toggleFlyout(); } },
                { separator: true },
                { label: qsTr("Battery & power"), action: function () { Bus.openFlyoutAt("battery"); } },
                { label: qsTr("System monitor…"), action: function () { Bus.toggleSysmon(); } }
            ];
        } else if (bar.inZone(usbChip, x, y)) {
            title = "Removable";
            entries = [
                { label: qsTr("Eject…"), action: function () { Bus.toggleUsbDock(); } },
                { separator: true },
                { label: qsTr("USB settings…"), action: function () { Bus.openSettings("usb"); } }
            ];
        } else if (bar.inZone(tray, x, y)) {
            title = "Tray";
            entries = [
                { label: qsTr("Sound settings…"),     action: function () { Bus.openSettings("sound"); } },
                { label: qsTr("Network settings…"),   action: function () { Bus.openFlyoutAt("wifi"); } },
                { label: qsTr("Bluetooth settings…"), action: function () { Bus.openFlyoutAt("bluetooth"); } },
                { separator: true },
                { label: Sys.muted ? qsTr("Unmute") : qsTr("Mute"),
                  action: function () { Sys.toggleMute(); } }
            ];
        } else if (bar.inZone(desks, x, y)) {
            title = "Workspaces";
            entries = [
                { label: qsTr("Task view"), action: function () { Bus.toggleTaskView(); } },
                { separator: true },
                { label: qsTr("Workspace settings…"), action: function () { Bus.openSettings("compositor"); } }
            ];
        } else if (bar.inZone(sigil, x, y)) {
            title = "Start";
            entries = [
                { label: qsTr("Open Start menu"), action: function () { Bus.toggleLauncher(); } },
                { separator: true },
                { label: qsTr("Settings…"),  cmd: ["nyxus-settings"] },
                { label: qsTr("Task Manager"), cmd: ["nyxus-sysmon"] },
                { label: qsTr("Power…"), action: function () { Bus.togglePower(); } }
            ];
        } else if (bar.inZone(row, x, y)) {
            title = "Open windows";
            entries = [
                { label: qsTr("Task view"), action: function () { Bus.toggleTaskView(); } },
                { separator: true },
                { label: qsTr("Shelf settings…"), cmd: ["nyxus-settings", "dock"] }
            ];
        } else {
            // Bare shelf. Reached by the gaps between zones as well as the
            // ends, which is the whole point of hit-testing centrally.
            entries = [
                { label: qsTr("Shelf settings…"), cmd: ["nyxus-settings", "dock"] },
                { label: qsTr("Change wallpaper…"), cmd: ["nyxus-wallpaper-studio"] },
                { separator: true },
                { label: qsTr("Task view"), action: function () { Bus.toggleTaskView(); } },
                { label: qsTr("Settings…"), cmd: ["nyxus-settings"] },
                { separator: true },
                // Destructive: it takes down every shell surface for a moment.
                // Gold label, per the PowerMenu precedent.
                { label: qsTr("Restart shell"), danger: true,
                  cmd: ["sh", "-c", "pkill -x qs; sleep 1; exec qs"] }
            ];
        }

        // Screen coordinates, derived from the bar's own geometry rather than
        // mapToGlobal. On a layer-shell window mapToGlobal answers in the
        // window's OWN surface coordinates -- Wayland has no global position
        // to offer -- so y came back as the offset inside the 46px bar, the
        // menu surface (which spans the whole output) clamped that to its
        // top edge, and the shelf menu opened at the top of the screen
        // (WIP-135). The bar is anchored left+right+bottom with no margins,
        // so bar-local x IS screen x, and screen y is the click's offset up
        // from the bottom edge.
        Menu.openAt(x, bar.screen.height - bar.height + y, entries, bar.screen, title);
    }
}
