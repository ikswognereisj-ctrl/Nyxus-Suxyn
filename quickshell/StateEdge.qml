// Nyxus Suxyn — THE STATE EDGE. Five states, two ladders, one definition.
//
// `_tokens.edges` in `theme/accent.json` is an owner ruling with a shape people
// keep collapsing: **THERE ARE TWO LADDERS, NOT ONE.**
//
//   LADDER A · SEAMS   alpha teal, decorative, WCAG 1.4.11-EXEMPT. A seam
//                      divides surfaces, carries no state, and is not what
//                      identifies a control — fill, label and position do that.
//                      1.0–1.4:1 is CORRECT here, not a failure, and raising it
//                      to 3:1 needs alpha ≥ 0.593, which is a bright teal line
//                      drawn around everything in the build. That change has
//                      been costed and REJECTED.
//   LADDER B · STATE   solid palette stops, hue-coded, 3:1 floor, NO exemption.
//                      Hue-coded and not alpha-coded is the accessibility
//                      requirement: an alpha ladder can only make focus a
//                      BRIGHTER hover, never a DIFFERENT one, and rev 3 §3
//                      requires focus-visible be distinguishable from hover for
//                      someone who cannot compare two intensities of one colour.
//
// **THE RESTING EDGE OF AN INTERACTIVE CONTROL IS STILL A SEAM.**
// `seams.idle._role`, in as many words: "a switch, check, radio, entry or button
// that is doing nothing. Still a seam: it says 'here is the boundary of a
// thing', not 'this thing is in a state'." A brief that says otherwise is
// starting from a hypothesis; this file follows the ruling.
//
// ── WHICH RUNGS, AND MEASURED AGAINST WHAT ────────────────────────────────
// The ruler, stated because a metric without its ruler is not a measurement:
// WCAG 2.x relative luminance, ratio (Lhi+0.05)/(Llo+0.05); component/border
// floor 3.00:1 (rev 3 §1.3, and `_findings.teal_alpha_bisection.crosses`); text
// floor 4.5:1; SEAM rungs 1.4.11-exempt but MEASURED ANYWAY and labelled with
// the floor they would otherwise have faced.
//
// The beds are THIS BUILD'S OWN, read off GPU frames of the two surfaces under a
// nested Hyprland (`scripts/suxyn-preview.sh` + `suxyn-session --nested`, grim
// from inside), not assumed against the void — because the void is not what is
// behind these controls. Glass over the living paint over the wallpaper:
//
//   flyout panel face      p05 L 0.00838 · MEDIAN L 0.02260 · p95 L 0.04995
//   Start Menu card face   p05 L 0.00133 · MEDIAN L 0.00378 · p95 L 0.01049
//
//   rung        value      flyout p05/med/p95     menu p05/med/p95      verdict
//   hover       #d765a2    5.37 / 4.32 / 3.14     6.11 / 5.83 / 5.18    PASS
//   focus       #0aa2d6    6.13 / 4.93 / 3.58     6.97 / 6.65 / 5.91    PASS
//   (rejected)  #ae206c    2.76 / 2.22 / 1.61     3.14 / 3.00 / 2.66    FAIL
//   (retired)   #891955    2.00 / 1.61 / 1.17     2.27 / 2.17 / 1.93    FAIL
//   pressed fill#521e72    1.53 / 1.23 / 1.12     1.74 / 1.66 / 1.48    GROUND
//   seam idle   teal@0.22  1.38 / 1.35 / 1.29     1.32 / 1.36 / 1.39    EXEMPT
//   seam struct teal@0.07  1.09 / 1.09 / 1.08     1.06 / 1.07 / 1.09    EXEMPT
//
// So `#ae206c` — which `_tokens.edges.state.hover` ships as the hover rung —
// FAILS the 3:1 floor on both of these surfaces' real beds, at the MEDIAN and
// not merely in a bright corner. That is not a new finding; it is the third
// independent measurement of it, and `_measured_beds
// .hover_fails_on_this_material_and_the_ruling_applies` records the owner's
// ruling for exactly this case: **where that happens, hover moves to `#d765a2`
// and focus stays `#0aa2d6`** — two hues, so rev 3 §3's requirement survives
// structurally. NOTE WHAT IS *NOT* DONE: the ground was not darkened and the
// material was not weakened to rescue the pinned stop. The bed was measured and
// the rung was moved.
//
// ── SO WHERE DOES PRESSED / CHECKED GO? ───────────────────────────────────
// With hover on `#d765a2` there are TWO usable solid rungs on these beds, not
// three, and five states to tell apart. The rulings already answer it and
// nothing has to be invented:
//
//   · THE EDGE'S HUE ENCODES ONE BIT — is this focused? Teal `#0aa2d6` means
//     keyboard focus; the plum-rose `#d765a2` means "the pointer is doing
//     something here". That is the requirement rev 3 §3 actually makes.
//   · THE FILL ENCODES THE REST. rev 3 §4.9 for rows: "no border, no glow —
//     rows are quiet; only the fill moves", and `hover_is_a_delta` makes hover
//     an OPERATION on the three fill levels rather than a fourth level: it
//     LIFTS HALFWAY TOWARD THE NEXT FILL LEVEL, so it is always ordered and can
//     never collide with the level above. Pressed/checked is
//     `glass-control-active`: accent-tinted, low alpha, a tint and never an
//     opaque fill — and `accent-deep #521e72` is the ruled "pressed / selected
//     ground", which is exactly why it is a GROUND here and never an edge
//     (measured above: 1.12–1.74:1 as an edge, nowhere near the floor).
//   · DISABLED DROPS TO `seams.structural` AND NEVER GLOWS. Not a fourth state
//     colour: a control that cannot be operated has no state to report, so it
//     falls back to being a mere boundary.
//   · AN IDLE CONTROL NEVER GLOWS (`_hard_rules.glow_is_state`). The filament
//     material is identical across idle, hover and active precisely so it cannot
//     be read as state — which is why glow here is state and the material is
//     not.
//
// ── AND ONE CONSTRAINT FROM THE MATERIAL ──────────────────────────────────
// `_measured_beds.the_residual_that_is_not_resolved`: on a FOCUSED pane's bright
// tail no rung in the ladder clears 3:1, and until that is re-measured against
// the shipped solver **a state edge should not be placed inside the 46 px rim
// band of a focused pane.** Satisfied structurally in these two surfaces — every
// control sits inside the panel's padding, well clear of the rim — and asserted
// by `insetFromRim` below so the next caller cannot quietly break it.
import QtQuick

Item {
    id: se
    anchors.fill: parent

    // ── the five states ──────────────────────────────────────────────────
    // Named for what they ARE, not for the handler that happens to feed them,
    // so a caller cannot accidentally wire hover to focus.
    property bool hovered: false
    property bool focusRing: false      // focus-VISIBLE, i.e. keyboard focus
    property bool pressed: false
    property bool checked: false
    property bool controlEnabled: true

    // ── shape ────────────────────────────────────────────────────────────
    property int radius: Theme.r1
    property int radiusTL: radius
    property int radiusTR: radius
    property int radiusBR: radius
    property int radiusBL: radius
    property int borderWidth: 1

    // How far this control sits inside its surface's rim band, in pixels. The
    // caller knows; this component only has to be able to SAY the constraint out
    // loud so it is not lost. Anything at or under the material's own rim width
    // is inside the focused pane's bright tail, where no rung clears 3:1.
    property int insetFromRim: Theme.glassFilament.rim_px + 1
    readonly property bool insideFocusedRimTail: insetFromRim <= Theme.glassFilament.rim_px

    // ══ LADDER A · SEAMS · alpha teal, 1.4.11-exempt ══════════════════════
    // `_deleted_vocabulary`: white-at-low-alpha is DELETED from the edge
    // vocabulary — white at 1–10% over a dark ground IS a grey, and HORIZON §3.5
    // bans a neutral dark outright. Seams are teal AT THE SAME ALPHA. Both
    // spellings of the old vocabulary fail the 0.18 saturation floor (white
    // 0.00, `#edf1ff` 0.07) against teal's 0.95.
    readonly property color seamStructural: Theme.soften(Theme.paintLayers.glacier[0], 0.07)
    readonly property color seamIdle:       Theme.soften(Theme.paintLayers.glacier[0], 0.22)

    // ══ LADDER B · STATE · solid, hue-coded, 3:1 floor ════════════════════
    // Owner 2026-08-19: kit chrome is glacier/ice, rose dropped. Magenta
    // rose[5] + teal rose[0] mixed muddy olive on black glass. Equivalent
    // rungs: glacier[5] hover/on, glacier[0] focus, glacier[3] pressed ground.
    // Swirls / Bar / shaders untouched.
    readonly property color stateHover: Theme.paintLayers.glacier[5]   // #b7e6f2
    readonly property color stateFocus: Theme.paintLayers.glacier[0]   // #7fe8ff
    // TRK-1784: was glacier[3] #274b7a, measured 2.13:1 on the plate — under
    // the 3:1 component floor. tokenAccentGround is 3.09:1.
    readonly property color activeGround: Theme.tokenAccentGround // #3b6590, 3.09:1

    // ── the edge, by state ───────────────────────────────────────────────
    // Precedence is ruled, not stylistic: DISABLED first, because a control that
    // cannot be operated reports nothing; then FOCUS, because a focus ring
    // nobody can see is worse than an ugly one and it must survive being hovered
    // at the same time; then pressed and hover, which share the pointer hue; then
    // checked; then rest, which is a SEAM.
    readonly property color edgeColor:
          !controlEnabled ? seamStructural
        : focusRing       ? stateFocus
        : pressed         ? stateHover
        : hovered         ? stateHover
        : checked         ? stateHover
        :                   seamIdle

    // ── the fill, by state · the three levels plus the delta ─────────────
    // `fillTint` is what the CALLER lays over its own body, so the level ladder
    // stays the caller's (a tile, a row and a chip do not have one shared base
    // fill) while the DELTA is computed once here. Hover lifts HALFWAY toward
    // the active tint — an operation on the levels, never a fourth level.
    property real activeFillAlpha: 0.22
    readonly property real fillAlpha:
          !controlEnabled ? 0.0
        : (pressed || checked) ? activeFillAlpha
        : hovered              ? activeFillAlpha / 2
        :                        0.0
    readonly property color fillTint: Theme.soften(activeGround, fillAlpha)

    // ── glow is STATE, and an idle control never glows ───────────────────
    // Disabled never glows either — that is the same rule seen from the other
    // end: no state to report, so nothing to announce.
    readonly property bool glowing: controlEnabled && (focusRing || pressed || checked)

    // The ring itself. One rectangle, transparent body: the caller owns the fill
    // so that a Pane's shader material, a gradient body and this edge can all
    // coexist without three of them fighting over one background.
    Rectangle {
        anchors.fill: parent
        color: se.fillTint
        antialiasing: true
        border.width: se.borderWidth
        border.color: se.edgeColor
        topLeftRadius: se.radiusTL
        topRightRadius: se.radiusTR
        bottomRightRadius: se.radiusBR
        bottomLeftRadius: se.radiusBL

        // `transition_ms` / `curveMove` — the same 150 ms the material uses for
        // its focus crossfade, and for the same stated reason: the change should
        // feel CAUSED BY THE INPUT rather than noticed afterwards.
        Behavior on border.color {
            ColorAnimation { duration: Theme.glassSweep.transition_ms }
        }
        Behavior on color {
            ColorAnimation { duration: Theme.glassSweep.transition_ms }
        }
    }

    // The focus ring's second line. rev 3 §3 wants focus-visible to be
    // unmistakable, and one hairline at 1 px on a busy bed is not: this is the
    // OUTER contour, one pixel out, at the same hue. It is a contour and not a
    // bloom on purpose — `accent-peak`'s luminance finding applies to anything
    // with AREA, and a 1 px line has none.
    Rectangle {
        anchors.fill: parent
        anchors.margins: -1
        color: "transparent"
        antialiasing: true
        visible: se.controlEnabled && se.focusRing
        border.width: 1
        border.color: Theme.soften(se.stateFocus, 0.55)
        topLeftRadius: se.radiusTL + 1
        topRightRadius: se.radiusTR + 1
        bottomRightRadius: se.radiusBR + 1
        bottomLeftRadius: se.radiusBL + 1
    }
}
