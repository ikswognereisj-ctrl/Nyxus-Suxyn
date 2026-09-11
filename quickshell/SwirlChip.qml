// Nyxus Suxyn — the living paint, at chip scale.
//
// Owner brief, 2026-08-23: "take the swirls that i have in my bottom bar and
// see if theres a way to implant them inside toggle or button something small
// like that so when you press it the swirls activate — has to be the same
// swirls same color just on a scale a lot smaller."
//
// ── WHY THIS IS A HOST AND NOT A PORT ────────────────────────────────────
// "The same swirls" is the load-bearing half of that sentence, so the one
// thing this file must never do is re-derive the paint at a smaller size. It
// does not: the child below is `Swirl`, the same ported Navier–Stokes chain
// the bar runs, and every knob that decides what the paint LOOKS like is
// either inherited or copied from `Bar.qml` with its provenance kept. A
// second implementation tuned to look similar is precisely how the bar and
// the flyout ended up as "rose and glacier" once already.
//
// ── AND WHY IT IS ACTUALLY SMALL, WHICH IS NOT OBVIOUS ───────────────────
// The scale question has a real answer in `Swirl.qml`'s `_fit`, and it is
// worth stating because the intuition runs the wrong way. `_fit` sizes both
// grids from the item's ASPECT and a fixed short side — never from its pixel
// size. So a 44 px chip and a 2304 px bar at the same aspect would get the
// SAME simulation, and what changes is only how many screen pixels it is
// drawn across. That is the owner's ask read literally: the same field, the
// same solver, the same dye, the same colours, displayed a lot smaller.
//
// TRK-2999: that "cheap because square" paragraph was the lag. `_fit`
// sizes from ASPECT and a FIXED short side (96 / 224), so a 44×19 switch
// is ~184×96 sim and ~430×224 dye — bar-class texels. A Settings page
// of those, `alwaysAlive`, is N bars. Grids now follow the chip's pixels.
//
// ── STRAND WIDTH IS IN PIXELS, NOT A COPIED FRACTION ─────────────────────
// `impulseRadius` is in units of THIS item's HEIGHT. The Line is 168 px
// tall at 0.12 → σ ≈ 14.3 px. A 24 px switch at the same 0.12 is σ ≈ 2 px
// — dust, not the bar. Owner on TTY1 2026-08-25: they do not look like the
// bottom ones. The box is real: you cannot fit 14 px filaments with voids
// in a 24 px track. Chips therefore use the Line's PIXEL sigma, capped at
// 0.35 of local height so the field still has dark between the folds.
//
// Usage:
//     SwirlChip {
//         icon: ""
//         active: Prefs.something
//         onToggled: Prefs.something = !Prefs.something
//     }
pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: chip

    // ── the control ──────────────────────────────────────────────────
    property string icon: ""
    // Latched state. `active` holds the paint up; releasing it lets the
    // field decay and the sim fall asleep on its own schedule rather than
    // being cut, so turning a chip off is the light going down and not the
    // picture being removed. HORIZON §4.3, at chip scale.
    property bool active: false
    // How much of the held frame a LATCHED-ON chip shows while nothing is
    // touching it. See the 2026-08-24 narrowing on the paint's `alwaysAlive`
    // note below for why a resting latched chip shows anything at all.
    //
    // Owner 2026-08-25 10:18 (TRK-3061): latch at 1.0 so ON does not read
    // as a dimmer cousin of the bar. 15:46: 1.0 was the wash. 15:53: 0.78
    // with hover still at 1.0 was STILL too bright — buttons only paint
    // on hover, so `_want` 1.0 was the whole complaint. Latch 0.52; hover
    // is 0.62 in `_want`, not 1.0. Dark between folds (WIP-218).
    property real latchedRestOpacity: 0.52
    property bool interactive: true
    signal toggled

    // ── BARE · this chip as a PAINT LAYER inside somebody else's control ──
    // Owner, 2026-08-23: "thats why we built the mock up swirl button so why
    // didnt we use it and apply it to this build."
    //
    // He is right, and the fix is reuse rather than a third implementation.
    // `TogglePill` and `SetSwitch` already own a Pane, a glyph, a Pool and
    // their own hit handling — everything this file has except the tuned
    // Swirl. Copying that Swirl block into both of them would put the same
    // twelve constants in three files, which is the drift `13pu` and the
    // shared-ramp rule exist to stop; the bar and the flyout have already
    // been "rose and glacier" once.
    //
    // So `bare` stands the chrome down and leaves only the paint. The host
    // fills this over its own body and drives `active` / `hostHovered` /
    // `hostPressed`. Default false, so the standalone chip on the preview
    // board is byte-for-byte the object it was.
    property bool bare: false
    // Hover and press belong to the HOST's handlers in bare mode — this
    // item's own are off, so `tap.pressed` and `hov.hovered` can never go
    // true and the paint would sit at its resting opacity forever.
    property bool hostHovered: false
    property bool hostPressed: false
    // Same binding as Bar.qml's Swirl (unset → PaintMood.ramp). Hosts that
    // passed Theme.controlSwirlRamp (paintLayers.glacier) were a second
    // dye: the Line takes its ramp through PaintMood. TRK-2999.
    // Child Swirl binds `chip.ramp`.
    //
    // TRK-3360 (2026-08-28): that ramp is now `paintPlumHorizon` — ice at the
    // bright end, plum through the body — so a control wears the same paint
    // the bar does with nothing to change here. The note this replaced said
    // the dye stays ice because "widget plum is sky through the glass"; the
    // owner corrected that on 08-28. The widget plum is not the sky, it is
    // `glassBorder` (`plumBody` #891955), a token this build already draws
    // on every widget corner — which is why the two never matched.
    property var ramp: PaintMood.ramp
    // The host's own corner. A SetSwitch track is a capsule (radius =
    // height/2), not a Theme.r2 card, and the display pass's rounded-rect SDF
    // has to agree with the body it is painting inside or the paint squares
    // off exactly the corners the host rounded.
    property real cornerRadius: Theme.r2

    readonly property bool _hot: (tap.pressed || chip.hostPressed)
    readonly property bool _warm: (hov.hovered || chip.hostHovered)

    // ── TRK-3362 · ONE GATE, and it is two switches ─────────────────────
    // `swirl_enabled` is the master and keeps its meaning: off means no
    // living paint anywhere. `swirl_controls` is new and scopes ONLY this
    // component — the Line, the seam and the power menu are untouched by it.
    //
    // It exists because the honest answer to "do these belong in buttons and
    // toggles" is "on the big ones, yes; on a 21 px switch track, no", and a
    // ruling like that is better offered than argued. Anyone who wants the
    // bar's horizon without thirty solvers on a Settings page now has one
    // switch instead of a rebuild.
    //
    // Every path that could start a solver or show a frame reads THIS, not
    // `Prefs.swirlEnabled` directly, so there is no route left that paints a
    // chip while the setting says not to.
    readonly property bool _paintOn: Prefs.swirlEnabled && Prefs.swirlControls

    implicitWidth: 44
    implicitHeight: 44
    opacity: chip.enabled ? 1.0 : 0.4

    // ── TRK-3361 · CONTROL PAINT MOVES SLOWER, and the reason is geometry ──
    // Owner, 2026-08-28: "do you think the one in the toggle and buttons
    // should be slower moving?" Yes, and it is not a taste call — the same
    // velocity is a different SPEED on a different surface.
    //
    // `force` is an impulse into a velocity field whose coordinates are the
    // item's own UV, so a strand crosses the item in a time set by the item's
    // width. The Line is 2304 px; a TogglePill is 132. Identical numbers
    // therefore cross a pill about SEVENTEEN TIMES faster in surface-widths
    // per second — which is why the bar reads as weather and a chip reads as
    // a fidget. Compounding it: the bar is peripheral and glanced at, while a
    // control is looked at directly, up close, for as long as a hand rests on
    // it, and fast motion under a label is where "distracting" comes from.
    //
    // The knob is `force` and `ambientAmp`, NOT `maxStepHz`. Dropping the
    // step rate makes the same motion CHOPPY rather than slower — TRK-3074
    // is the owner reporting exactly that about the 30 Hz chips. Fewer
    // steps per second is not slower paint, it is worse paint.
    property real speed: Prefs.swirlControlSpeed

    // How hard a press hits the field. A press is a DROP, not a stroke —
    // the same `dropAt` call `Bar.qml`'s Tell uses for "one drop of paint at
    // the x where an event belongs". At chip scale there is nowhere for a
    // stroke to travel, so the drop is the whole gesture and it is centred.
    property real pressStrength: 1.0
    // Owner 10:18: latched toggles did not look like they were changing.
    // Freeze-after-linger is still the default (SetIceFace × N). Pills and
    // switches set this so the solver stays up while ON.
    property bool liveWhileLatched: false

    Pane {
        anchors.fill: parent
        // Bare mode: the host already drew this. See the `bare` note above.
        visible: !chip.bare
        elevation: 1
        radius: Theme.r2
        fill: Theme.soften(Theme.void_, chip.active ? 0.34 : 0.50)
        focusLevel: !chip.enabled ? 0
                  : (chip._hot ? 0.70
                  : (chip.active ? 1.0 : (chip._warm ? 0.35 : 0.0)))
    }

    // ── the paint ────────────────────────────────────────────────────
    // Masked by the display pass's own rounded-rect SDF at the host
    // `cornerRadius`, NOT by `clip: true` and NOT by a MultiEffect layer.
    // `clip` is a scissor rect (squares the pill). A layer FBO turned
    // additive dye into a grey plate on a 21 px track (measured
    // docs/proof/control-swirl-0826/after-layer-fail-usb-sw1.png).
    Swirl {
        id: paint
        anchors.fill: parent
        z: 1
        cornerRadius: chip.cornerRadius
        visible: chip._paintOn
        intensity: Prefs.swirlIntensity

        // Bar stays opaque (Bar.qml). Chips cannot: `base.w > 0.5` in
        // swirl_view.frag returns BEFORE the rounded-rect mask, so an
        // opaque chip paints a SQUARE inside a rounded toggle. Additive
        // here is the mask path, not a second dye. Do not edit the frag
        // (Agent B).
        opaque: false

        // The pointer feeds the field directly, so a hand resting on the
        // chip keeps it awake through `_stimulus`. The bar sets this false
        // and hand-rolls a Wake only because its pointer zone is the whole
        // 84 px chrome while its paint band is the bottom 28; a chip has no
        // such split — the whole surface is both.
        // In bare mode the pointer is over the HOST, not over this item, so
        // its own `_stimulus` would never fire. The host wakes it instead —
        // exactly the split `Bar.qml` uses for its Wake.
        interactive: chip.interactive && chip.enabled && !chip.bare

        // TRK-2999 · LAG. `alwaysAlive` on every chip × N hosts is N full
        // Navier–Stokes chains on the global FrameAnimation. The Line is
        // the one surface allowed to do that. A chip steps while the hand
        // is on it, plus linger after seed/press; then freeze a FULL field
        // (restOpacity 1). OFF is frozen, not empty — rest `_want` shows
        // that held frame. Beat.hot is NOT bound — it is `_stimulus`, so
        // music would keep every mapped chip solving.
        alwaysAlive: ((chip.liveWhileLatched && chip.active)
                      || chip._hot || chip._warm) && chip.enabled && chip._paintOn
        batterySaver: true
        // Dye size stays medium (160/1536) — TRK-3002: pixel-fit dye was
        // 88×38 on a 44×19 track and read grey. 30 Hz is why the owner
        // said they do not run smooth (TRK-3074). The SOLVER cost is sim
        // size (16–40 here), not step rate; the bar's 30 Hz was for a
        // 2304-wide field. Pin 60 Hz on this small sim. Do not switch
        // qualityTier to "full" — that also raises dye to 224 and is the
        // N-bar lag TRK-2999 measured.
        qualityTier: "medium"
        maxStepHz: 60
        playIntroOnLoad: false
        // TRK-3077 — do not wait 400 ms with t<0 (blank slots). The bar
        // keeps Swirl's 0.4 default; chips ignite the frame they can paint.
        introDelay: 0
        // `bar` intro is crossing ribbons written for a ~14:1 horizon.
        // Running it in a 2:1 pill is the postage-stamp smear. `loop` is
        // Swirl's own small-shape fill of the SAME dye and solver.
        introMode: "loop"
        // TRK-2989 · THE 2-SECOND DEATH WAS LINGER, NOT A MISSING RULING.
        // `latch()` ignites, the loop intro fills the field (~1.7 s with
        // the 0.4 s delay), stimulus falls, linger runs. At 2600 ms the
        // solver kept dissipating (`decayRate` 0.44, `ambientDye` 0.09)
        // until freeze captured a near-empty buffer, and THEN the display
        // pass faded that buffer to `restOpacity` 0.62 over 1.5 s. Owner:
        // paint runs ~2 seconds then turns right off. The ruling is seed
        // once then freeze a FULL field, not a decayed blank. 400 ms is
        // one last splat settling, not a second dissipation cycle. The
        // bar's 12 s linger is untouched — this is a chip-side prop.
        lingerMs: 4000
        // Frozen texture at full dye. Chip `opacity` (latched / hover /
        // press) is the only attenuator; a second dump on the display pass
        // was how a latched chip went blank while the bar, `alwaysAlive`,
        // never hit this path.
        restOpacity: 1.0

        // ── the look · THE LINE'S NUMBERS, not a chip retune ──────────
        // Owner 2026-08-25: "exact as the bottom bar and real not how they
        // are right now." The 08-23 "butter" block (impulse 0.30, exposure
        // 2.70, curl 0.70, force 2200, sheen 0.10) invented a second paint.
        // Bar.qml is not edited. Solver knobs the Line does not set stay
        // at Swirl.qml defaults (curlAmp 1.0, force 5200, velocityDecay
        // 0.16). Display gain is NOT copied: 3.15 + sheen 0.35 on a
        // 24–56 px opaque body rails cores to white when dye piles. That
        // white is clipping, not hue. 2.45/0.70/0.12 still railed on F1
        // after the 03:39 hot-load; chip-only pull 1.80/0.45/0.06. Glacier.
        ramp: chip.ramp
        sweepLo: 0
        sweepHi: 1.0
        // Line sets 1.0 (Bar.qml). Chip had 1.35 — splat mapSweep is
        // pow(x, gamma), so 1.35 pulls dye toward sweepLo (darker orchid)
        // and starves the ice peak the owner named on the bar.
        sweepGamma: 1.0
        // Sim stays chip-sized (lag, TRK-2999). Dye does NOT: pixel dyeCap
        // crushed medium's 160 short to 88×38. Unset dyeShort/dyeCap so
        // qualityTier medium wins (160 / 1536). Floor after max(side,1)
        // so a 0-wide first frame cannot hand _fit a 0 short-side (TRK-2937).
        simShort: Math.max(16, Math.min(40, Math.round(Math.min(Math.max(width, 1), Math.max(height, 1)))))
        simCap: Math.max(32, Math.round(Math.max(width, height, 1) * 2))
        // Bar.qml impulseRadius 0.12 on Theme.paintH (168). Same σ in px
        // unless this item is shorter than ~41 px, then 0.35·height.
        impulseRadius: {
            const h = Math.max(height, 1);
            const barSigma = 0.12 / Math.sqrt(2) * Theme.paintH;
            const cap = 0.35 * h;
            return Math.min(barSigma, cap) * Math.sqrt(2) / h;
        }
        // TRK-3074 · THE BAR'S DENSITY PASS, AT CHIP SCALE.
        // 2.20/0.50/0.10 + latch 0.78 still washed on F1 (owner 15:53).
        // Buttons hover at `_want`; that was 1.0, so display 2.20 was a
        // white plate. 1.70 / 0.28 / 0.06 with inject 0.72 and dye 0.10
        // is the Line's own deposit (Bar once used inject 0.72) on a
        // body that is 7× shorter. Hover `_want` is 0.62, not 1.0.
        exposure: 1.70
        bloom: 0.28
        sheen: 0.06
        injectGain: 0.72
        ambientDye: 0.10
        // TRK-3361 · both motion terms scale together, so `speed` changes how
        // FAST the field moves and not how much paint is in it. `force` is the
        // pointer/press impulse and `ambientAmp` is the idle stirrers' — leave
        // either one unscaled and a slowed chip still snaps when touched.
        // `injectGain`, `ambientDye`, `exposure` and `decayRate` are all
        // deliberately NOT scaled: those set how much dye there is and how
        // bright it reads, and dimming a control was never the ask.
        force: 5200 * chip.speed
        ambientAmp: 0.36 * chip.speed
        decayRate: 0.55
        introStrength: 0.55

        // The whole surface is the control, so the paint runs UNDER the
        // glyph and the glyph has to stay readable over it. The bar solves
        // that with a content scrim; at 44 px a scrim would be most of the
        // chip, so the paint is held down at rest and comes up with state
        // instead. One object, light turned up or down — not two designs.
        // ⚠ REST PAINT IS ON EVERY CHIP, NOT ONLY THE LATCHED-ON ONES.
        // Owner 20:30: flyout ON pills are the recipe, and "it's still only
        // a few toggles/buttons when its suppose to be alot more". `_want`
        // used to be 0 unless `active`, so a grid of eight pills showed
        // paint on Wi-Fi/Bluetooth and looked empty everywhere else. Same
        // on Settings: only the switches that were already ON had a field.
        // Rest is `latchedRestOpacity` (0.52) on every enabled chip; hover
        // still steps to 0.62. Solver cost is unchanged: OFF still freezes
        // after linger. ON with `liveWhileLatched` still moves.
        //
        // Colour never goes behind text (accent.json _swirl rule 5). Hover
        // used to go to 1.0 and washed the label; 0.62 stays.
        readonly property real _want: !chip._paintOn ? 0
               : (chip._hot || chip._warm
                  ? 0.62
                  : chip.latchedRestOpacity)
        opacity: _want
        Behavior on opacity {
            enabled: paint._want < paint.opacity
            NumberAnimation { duration: 1500; easing.type: Easing.OutCubic }
        }

        audioBass: 0
        audioMid: 0
        audioHigh: 0
        audioPulse: 0
        musicActive: false
    }

    Text {
        anchors.centerIn: parent
        z: 2
        visible: !chip.bare && chip.icon !== ""
        text: chip.icon
        font.family: Theme.fIcon
        font.pixelSize: Math.round(chip.height * 0.42)
        color: chip.active ? Theme.text : Theme.textMuted
        Behavior on color { ColorAnimation { duration: 180 } }
    }

    HoverHandler { id: hov; enabled: chip.enabled && !chip.bare }

    TapHandler {
        id: tap
        enabled: chip.enabled && !chip.bare
        onTapped: {
            chip.active = !chip.active;
            chip.toggled();
            chip.ignite();
        }
    }

    // ── activation ───────────────────────────────────────────────────
    // Public, because "when you press it or something the swirls activate"
    // is a behaviour a host may want to trigger from an event that is not a
    // tap on this chip — the same way `Bar.tell()` drops paint for something
    // that happened elsewhere.
    //
    // Two calls, and they do different jobs. `ignite()` replays the intro,
    // which is what FILLS AN EMPTY FIELD: a chip that has been asleep has
    // nothing in it for a drop to fold against, and a lone drop into a dead
    // field reads as a dot rather than as a swirl. `dropAt` then puts the
    // press itself in with an upward kick, so the light rises out of the
    // chip instead of just appearing in it.
    // Hover wakes the field the same way a press does — "press them or
    // hoover over them" — but softly: a hover is a WAKE, not a drop, so it
    // stirs what is there rather than throwing new paint in.
    // ONE handler, not two. `_warm` already folds this item's own
    // HoverHandler together with the host's, so watching `hostHovered`
    // separately would fire the wake twice for a single hover in bare mode.
    on_WarmChanged: if (chip._warm) chip.wake()

    // ── the seed · every visible chip, not only ON ───────────────────
    // A held frame can only hold what was put there. `playIntroOnLoad` is
    // false and a bare chip's own `_stimulus` can never fire, so a chip that
    // has never been touched has EMPTY buffers — raising `_want` over it
    // shows nothing, which is how OFF pills and SetButtons read as "no
    // swirl". Seed any chip that can actually paint, not only `active`.
    //
    // Every conjunct here is load-bearing, and `paint.windowExposed` is the
    // one that is easy to miss: `running` requires it, so igniting before the
    // window is mapped starts a linger that expires against a solver which
    // never stepped. Collapsed flyout / unmapped Settings fail this and do
    // not seed. Size is the same: `running` wants width/height > 8.
    readonly property bool _seedable: chip.enabled && chip.visible
                                     && paint.windowExposed && chip._paintOn
                                     && chip.width > 8 && chip.height > 8
    on_SeedableChanged: if (chip._seedable) chip.latch()
    Component.onCompleted: if (chip._seedable) chip.latch()

    // ── AND A RE-SEED WHEN THE CHIP IS RESIZED ───────────────────────
    // The held frame lives in buffers whose dimensions come from `_fit`, so a
    // size change re-creates them and the picture in them is gone. While the
    // sim is awake that is invisible - the next step refills them - but a
    // seeded chip's sim is asleep by design, so a layout pass landing after
    // it settles would blank the chip until something touched it.
    //
    // Debounced, because a resize arrives as a burst and each seed is a whole
    // ~6 s solve; one restarted timer means a run of size changes costs one
    // re-seed after the layout settles.
    //
    // ⚠ HONESTY, because this was written while chasing a defect it did NOT
    // fix: see the open row in CHECKLIST for the intermittent blank latched
    // SetSwitch. Buffers following `_fit` is read out of `Swirl.qml`, not
    // inferred - but it is not the cause of that defect, which survived this
    // line unchanged. Kept because it is correct on its own terms, not
    // because it is proven to fix anything.
    onWidthChanged: if (chip._seedable) reseed.restart()
    onHeightChanged: if (chip._seedable) reseed.restart()
    Timer { id: reseed; interval: 220; onTriggered: if (chip._seedable) chip.latch() }

    function wake(): void {
        if (!chip._paintOn)
            return;
        paint.ignite();
        // One splat the same frame, so hover is not an empty 400 ms then
        // a circling wisp. Rest look is still `_want` / exposure.
        paint.dropAt(0.46, 0.50, 0.80, 0.25, -0.9);
    }

    // A press is a drop (`ignite`), a hover is a stir (`wake`), and a latch
    // used to be intro-only. TRK-3077: latch also drops once so ON chips
    // that you watch ignite are not a 400 ms blank then a blur.
    function latch(): void {
        if (!chip._paintOn)
            return;
        paint.ignite();
        paint.dropAt(0.50, 0.48, 0.80, 0, -0.7);
    }

    function ignite(): void {
        if (!chip._paintOn)
            return;
        paint.ignite();
        paint.dropAt(0.5, 0.62, chip.pressStrength, 0, -1.6);
    }
}
