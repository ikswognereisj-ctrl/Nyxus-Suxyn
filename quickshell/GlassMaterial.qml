// Nyxus Suxyn — THE GLASS MATERIAL, as a surface.
//
// `theme/accent.json` → `_glass_material` and its mirror in `Theme.qml` landed
// the filament and the focus sweep as DATA, and said so in as many words:
// *"THIS BLOCK DRAWS NOTHING. It is the definition; the consuming surfaces —
// bar, flyouts, Start menu, buttons, toggles, scrollbars — are a separate
// pass."* This file is that pass, for the START MENU and the FLYOUT.
//
// It CONSUMES the material and defines none of it. Every number is read through
// `Theme.glassField`, `Theme.glassFilament`, `Theme.glassSweep`,
// `Theme.glassDecouple` and `Theme.glassSweepHighlight`, so a retune of the
// material moves this surface with it and gate `13q45` still owns the mirror.
// There is no second copy of a material value in this file, which is the same
// reason `_traps_already_paid_for.duplicated_shader_source` gives for the
// material having one definition at all.
//
// ── THERE IS NO ENABLE FLAG, AND THAT IS NOT AN OMISSION HERE ─────────────
// `_glass_material` has no `enabled`, and neither does `Theme.qml`:
// `architecture.material_on` ("the focused window plus the shell") is a
// DESCRIPTION of which surfaces are alive at a given moment, and
// `architecture.rim_only` is a statement of the architecture. Neither is a
// switch. CONSUMPTION IS THE WIRING — a surface that instantiates this
// component is on, and one that does not is off. Anything that later wants a
// real flag has to add it to `accent.json` and to the mirror together, which is
// an owner-ruled edit to two files this pass is not allowed to touch.
//
// ── WHAT IS FAITHFUL AND WHAT IS A STAND-IN ──────────────────────────────
// Said at the top rather than buried, because the difference is the whole
// honesty of the thing:
//
//   FAITHFUL   the FIELD. Two levels of domain warp (`warp_levels`), the crush
//              (`crush_floor`/`crush_lo`/`crush_hi`) exactly as `_crush_note`
//              writes it, drift at `flow` × `activity`, evaluated from GLOBAL
//              LAYOUT COORDINATES per `coordinate_space` — never sampled from
//              behind the window, which Quickshell cannot do.
//   FAITHFUL   the RIDGE. `_extraction_note` gives the formula and this is it:
//              exp(-((v - band_centre)/band_sigma)²) × smoothstep(band_centre −
//              shoulder_lo, band_centre − shoulder_hi, v). A value FLOOR keeps
//              the bright cores and those are blobs; that is the plateau
//              failure the owner ruled out, and `extraction` is checked below
//              rather than assumed.
//   FAITHFUL   the SWEEP — a band of `band_width` with a `glint_frac` core,
//              oscillating on `period_ms`, phase offset by the pane's SCREEN
//              POSITION, amplitude `amp_focused` vs `amp_unfocused` crossfading
//              on `transition_ms`/`transition_curve`, PARKED (not absent) when
//              unfocused, and modulating the SEAM and nothing else.
//   FAITHFUL   the DECOUPLE, the intensity DESATURATION, and the CLAMP — the
//              last computed on the SUMMED additive output of both layers.
//   STAND-IN   the field's SPATIAL RESOLUTION. A shader evaluates the ridge per
//              pixel; this evaluates it along the rim at `fieldTaps` points per
//              edge and modulates across the band's depth by the grazing
//              profile — a SEPARABLE approximation of a 2-D material. The
//              filaments are therefore streaks running WITH the edge, which is
//              what `tangent_compress` asks for, but their fine structure
//              across the band is a profile rather than a solved contour.
//   STAND-IN   `tangent_compress` and `pointer_offset` are consumed as the
//              along-edge elongation and the field's pointer bias rather than
//              as an SDF-gradient basis, because there is no SDF here.
//
// Qt 6 has no inline shader — `ShaderEffect.fragmentShader` takes a precompiled
// `.qsb` — and every `.frag` in this tree is under the standing owner veto
// recorded at `_tokens.edges._owed.shader_luminance_clamp`. So the per-pixel
// route was not available to this pass, and the gap is named rather than
// papered over.
//
// ── WHY THIS IS RIM-ONLY, AND WHY THAT MUST BE RE-COSTED IF IT MOVES ─────
// `architecture.rim_only` is the architecture, not a fallback, and after
// 2026-08-17 it is load-bearing for PERFORMANCE as well as for the look. The
// costing that produced it is in `architecture._measured` and
// `_full_face_is_60hz_only`: on a maximised focused window the full-face
// material costs a large fraction of a 144 Hz frame where rim-only costs well
// under half, and across twelve windows the full-face figure is most of the
// frame. The shape of the cost is what matters to a future reader: IT IS
// PER-SURFACE AND ROUGHLY LINEAR IN SURFACE COUNT. One surface is affordable;
// twelve is not. So:
//
//   · the material goes on the focused surface plus the shell, per
//     `material_on`, and this component is instantiated by surfaces, one at a
//     time, rather than installed globally;
//   · an unfocused surface DRAWS ONCE AND STOPS (`unfocused_draws_once` —
//     freezing the field's clock was measured to save nothing, because a frozen
//     t is the same instruction count, so the saving has to come from not
//     drawing at all). The Canvas below therefore repaints only while focused;
//   · ANY PROPOSAL TO PUT THIS MATERIAL ON UNFOCUSED WINDOWS, OR ON MORE
//     SURFACES AT ONCE, IS RE-MEASURED AND NOT INHERITED. The figures above
//     were taken at one surface on the integrated GPU Hyprland actually
//     composites on; they do not transfer to twelve by assumption, and the
//     whole point of the architecture is that cost stopped scaling with surface
//     count. If that stops being true, the architecture has changed and needs
//     the owner, not a tuning pass.
//
// ── USE ──────────────────────────────────────────────────────────────────
// Above `GlassEdge` (the Lip/Sheen/Glaze are the pane's thickness; this is the
// light in it) and below the content.
//
// 2026-08-19 owner: YES — this is the living BLUE edge they asked
// about (the "glass thing"). Rim filaments follow Theme.lookHot /
// lookPale / lookPeak. Not Swirl, not Bar shaders, not Hyprland
// window decoration (Beat).
//
// 2026-08-19 owner: this is the motion on START / the flyout when they
// OPEN — filaments and a focus sweep that travel the RIM only, not a
// wallpaper, not Swirl filling the card. Live instances:
//   Launcher.qml  focused: Bus.launcherOpen
//   SidePanel.qml panel (not the 46 px rail)  focused: expanded
// That property is the on-switch: SequentialAnimation `_phase` and the
// 80 ms field Timer both `running:` when focused. Unfocused parks
// (still, not absent). Not ReactiveEdge (music/CPU colour; still at rest).
//
// Reuse on smaller chrome (TogglePill / SetButton): same component, not a
// second effect. Pass the host radii, a lower `strengthScale`, and
// `focused:` hover-or-active. `_rim` already clamps to 1/3 of the shorter
// side so a 62 px pill cannot become a full-face wash. Do NOT put one
// Canvas on every chip at once (`architecture._full_face_is_60hz_only` —
// cost is per-surface). Bar: BQ, do not edit Bar.qml; same `focused:`
// pattern if they take it.
//
//     Pane {
//         GlassEdge { ... }
//         GlassMaterial {
//             anchors.fill: parent
//             focused: Bus.launcherOpen
//             driftOffset: 0.0                  // this surface's drift slice
//             paneScreenX: 0; paneScreenY: 0
//             screenW: root.screen.width; screenH: root.screen.height
//             radiusTL: Theme.r3; radiusTR: Theme.r3
//             radiusBR: Theme.r3; radiusBL: Theme.r3
//         }
//         ...content...
//     }
import QtQuick

Item {
    id: mat

    // ══ WHAT THE CALLER TELLS US ═════════════════════════════════════════

    // FOCUSED IS WHAT IS ADDED, NOT WHAT UNFOCUSED IS MISSING.
    // `decouple._unfocused_is_tuned_first` is a review PROCEDURE as much as a
    // pair of values: unfocused is the majority state, it is tuned first, and it
    // is judged with no focused surface in shot so it cannot be flattered by
    // comparison. The side panel's RAIL is this build's honest unfocused case —
    // it sits on the right edge all day while nothing has focus — and it is the
    // surface these numbers were looked at on first.
    property bool focused: false

    // This surface's slice of the shell-wide drift (`Theme § THE DRIFT`). Pass
    // the SAME offset the surface's own Swirl uses (Start Menu 0.0, side panel
    // 0.45) so the filament is the colour of the paint it is lying on instead of
    // a second, disagreeing colour.
    property real driftOffset: 0.0

    // The pane's ORIGIN ON SCREEN and the screen's size. `coordinate_space` is
    // "global layout coordinates, logical units", and `_coordinate_note` says
    // why in terms of a fault this host cannot show: output-local coordinates
    // restart the field per monitor and seam at the boundary, and device pixels
    // change the marbling SIZE under fractional scaling. Both are invisible on a
    // single-head dev box, so the space is passed in rather than guessed.
    property real paneScreenX: 0
    property real paneScreenY: 0
    property real screenW: 1920
    property real screenH: 1080

    // Match the host or the band overhangs a rounded corner — the dark spur
    // `GlassEdge.qml` documents, from exactly this cause.
    property int radiusTL: Theme.r0
    property int radiusTR: Theme.r0
    property int radiusBR: Theme.r0
    property int radiusBL: Theme.r0

    // One dial for a surface that wants the whole material quieter.
    property real strengthScale: 1.0

    // ══ THE MATERIAL · READ, NEVER REDEFINED ═════════════════════════════
    readonly property var _fld: Theme.glassField
    readonly property var _f:   Theme.glassFilament
    readonly property var _s:   Theme.glassSweep
    readonly property var _d:   Theme.glassDecouple

    // ── the raw layer, kept reachable on purpose ──────────────────────────
    // Owner instruction, 2026-08-17: keep the rim width and the rejected
    // extraction mode reachable FROM THE TOKENS, because they are the raw layer
    // a material picker will be built on. They are deliberate surface area, not
    // residue, and a later tidy-up that prunes them is removing a feature's
    // foundation. `filamentRimPx` is the token value verbatim; `_rim` below is
    // what this particular surface can actually afford to draw.
    readonly property int  filamentRimPx: _f.rim_px
    readonly property string extraction:  _f.extraction

    // RIDGE ALWAYS. `_ridge_always` is an owner ruling and `13q45` asserts the
    // token stays `ridge`, so this is not a preference with two good values.
    // Plateau is REFUSED here rather than silently drawn: a value floor keeps
    // the bright cores, the cores are blobs, and a blob fills with colour and
    // buries text. If plateau is ever exposed it sits behind an advanced
    // disclosure — so the code path that would draw it does not exist, and this
    // is the line that says so out loud.
    readonly property bool _ridge: extraction === "ridge"

    // The rim band is PIXELS, not a fraction of the pane, because a rim is a
    // physical width. Clamped to a third of the smaller dimension: on a 46 px
    // rail a 46 px band IS the whole surface, at which point it is a wash and
    // not a rim, and the ridge has nothing to be a ridge against.
    readonly property real _rim: Math.min(filamentRimPx,
                                          Math.max(6, Math.min(width, height) / 3))
    // DRAW width. Token rim_px is 46; Theme.r3 is 22. A stroke whose
    // lineWidth is a large fraction of the radius IS a disc at the bend
    // (owner 08-20 10:20: bevel+butt on an 8 px ring still read as pies).
    // Straights and corners are a 2 px hairline, well below r3. The
    // Canvas visible/early-out guards used to require `_ring > 2`, which
    // would have HIDDEN this layer at the width that does not pie.
    readonly property real _ring: Math.min(2, mat._rim)
    // Sixth cut: no Canvas corner stroke. `_cornerW` retired.

    // How densely the field is sampled ALONG each edge, in logical pixels per
    // tap. Not a token — the material has no spatial-resolution number because a
    // shader does not need one — so it is a NAMED PROPERTY rather than a literal
    // buried in the paint loop, and it is the first thing to turn down if this
    // ever costs anything.
    //
    // MEASURED, not guessed. A fixed 28 taps was the first cut, and on the Start
    // Menu's 1027 px card that is a tap every 37 px: the gradient interpolates
    // LINEARLY between taps, so every filament — which is a spike a few pixels
    // wide — was smeared across 74 px at a fraction of its height. The rim
    // rendered as soft blobs and the whole material measured +0.0002 median
    // luminance against the live paint, i.e. invisible. Six pixels per tap
    // resolves the spike instead of averaging it away. The cap keeps a very wide
    // surface from paying without bound.
    property int fieldTapPx: 6
    property int fieldTapsMax: 260

    // The field's spatial frequency, in logical pixels per field unit. ALSO NOT
    // A TOKEN, AND THAT IS A REAL GAP: `field` fixes the field's shape, drift
    // and crush but not its SCALE, so two consumers can agree on every token and
    // still disagree about how big the marbling is — and the material's whole
    // claim is that a surface and the wallpaper line up because both evaluate
    // the same function at the same coordinates. Recorded as a gap rather than
    // smuggled in as a constant, and OWED back to `_glass_material.field`.
    //
    // 64 was not picked by eye. Measured on the rendered rim: at 380 px the
    // along-edge feature (which is `fieldScale / tangent_compress`, because the
    // tangent compression stretches the pattern along the edge) came out at
    // ~1100 px, so a 514 px pane edge sat inside ONE feature and the rim
    // rendered as a smooth wash with no filaments in it at all. That is the
    // plateau failure arriving by the back door — a band of colour rather than
    // where the field crosses a level. 64 puts the along-edge feature at ~190 px
    // and a pane edge crosses two to three of them, which is what makes the rim
    // read as streaks. It is also the scale the shipped paint's own filaments
    // measure at, which is the agreement the material asks for.
    property real fieldScale: 64

    // Filament follows the look set. ICE = glacier[0]/[5]/[6]; MAGMA uses
    // the matching magma rungs. Face paint stays `paintRamp`.
    function _rampAt(t) {
        var ice = [Theme.lookHot, Theme.lookPale, Theme.lookPeak];
        var n = ice.length - 1;
        var x = Math.max(0, Math.min(1, t)) * n;
        var i = Math.floor(x);
        if (i >= n)
            return Qt.color(ice[n]);
        var a = Qt.color(ice[i]), b = Qt.color(ice[i + 1]), k = x - i;
        return Qt.rgba(a.r + (b.r - a.r) * k,
                       a.g + (b.g - a.g) * k,
                       a.b + (b.b - a.b) * k, 1.0);
    }

    // Rounded-rect path (outer outline of the pane). `reverse` walks CCW
    // so a CW outer + CCW inner is a nonzero-winding hole — kept for a
    // clip ring. The filament itself is a STROKE of this path, never a
    // fill toward the centre (TRK-932: fillRect bands + quarter-pies
    // were the half-circles inside Start / flyout corners).
    function _roundRect(ctx, x, y, w, h, rtl, rtr, rbr, rbl, reverse) {
        rtl = Math.max(0, Math.min(rtl, w * 0.5, h * 0.5));
        rtr = Math.max(0, Math.min(rtr, w * 0.5, h * 0.5));
        rbr = Math.max(0, Math.min(rbr, w * 0.5, h * 0.5));
        rbl = Math.max(0, Math.min(rbl, w * 0.5, h * 0.5));
        if (reverse) {
            ctx.moveTo(x + rtl, y);
            if (rtl > 0)
                ctx.arcTo(x, y, x, y + rtl, rtl);
            else
                ctx.lineTo(x, y);
            ctx.lineTo(x, y + h - rbl);
            if (rbl > 0)
                ctx.arcTo(x, y + h, x + rbl, y + h, rbl);
            else
                ctx.lineTo(x, y + h);
            ctx.lineTo(x + w - rbr, y + h);
            if (rbr > 0)
                ctx.arcTo(x + w, y + h, x + w, y + h - rbr, rbr);
            else
                ctx.lineTo(x + w, y + h);
            ctx.lineTo(x + w, y + rtr);
            if (rtr > 0)
                ctx.arcTo(x + w, y, x + w - rtr, y, rtr);
            else
                ctx.lineTo(x + w, y);
            ctx.closePath();
            return;
        }
        ctx.moveTo(x + rtl, y);
        ctx.lineTo(x + w - rtr, y);
        if (rtr > 0)
            ctx.arcTo(x + w, y, x + w, y + rtr, rtr);
        else
            ctx.lineTo(x + w, y);
        ctx.lineTo(x + w, y + h - rbr);
        if (rbr > 0)
            ctx.arcTo(x + w, y + h, x + w - rbr, y + h, rbr);
        else
            ctx.lineTo(x + w, y + h);
        ctx.lineTo(x + rbl, y + h);
        if (rbl > 0)
            ctx.arcTo(x, y + h, x, y + h - rbl, rbl);
        else
            ctx.lineTo(x, y + h);
        ctx.lineTo(x, y + rtl);
        if (rtl > 0)
            ctx.arcTo(x, y, x + rtl, y, rtl);
        else
            ctx.lineTo(x, y);
        ctx.closePath();
    }
    readonly property color filamentColor: _rampAt(Theme.driftCenter(driftOffset))

    // ══ THE FIELD ════════════════════════════════════════════════════════
    // Value noise, four octaves, TWO LEVELS OF DOMAIN WARP. `_warp_note`:
    // "TWO LEVELS OF DOMAIN WARP IS THE LIQUID. One warp gives soft blobs;
    // warping the warp folds the field through itself. Deleting the second level
    // is what made it stop reading as fluid, and that regression happened once
    // already" — so `warp_levels` is read and looped over rather than written
    // into the shape of the code, where dropping it would be a one-line silent
    // edit.
    function _hash(x, y) {
        var n = Math.sin(x * 127.1 + y * 311.7) * 43758.5453123;
        return n - Math.floor(n);
    }
    function _smooth(t) { return t * t * (3 - 2 * t); }
    function _vnoise(x, y) {
        var ix = Math.floor(x), iy = Math.floor(y);
        var fx = _smooth(x - ix), fy = _smooth(y - iy);
        var a = _hash(ix, iy),         b = _hash(ix + 1, iy);
        var c = _hash(ix, iy + 1),     d = _hash(ix + 1, iy + 1);
        return (a + (b - a) * fx) + ((c + (d - c) * fx) - (a + (b - a) * fx)) * fy;
    }
    function _fbm(x, y) {
        var v = 0, amp = 0.5, fx = x, fy = y;
        for (var o = 0; o < 4; o++) {
            v += amp * _vnoise(fx, fy);
            fx *= 2.03; fy *= 2.03; amp *= 0.5;
        }
        return v;
    }
    function _smoothstep(e0, e1, x) {
        if (e1 <= e0) return x >= e1 ? 1 : 0;
        var t = Math.max(0, Math.min(1, (x - e0) / (e1 - e0)));
        return t * t * (3 - 2 * t);
    }

    // `t` drifts at `flow` × `activity`. ACTIVITY SCALES DRIFT, NEVER CONTRAST:
    // collapsing the field toward a constant at low activity flattens the
    // marbling out of existence AND removes the motion, because a flat field has
    // nothing left to move. So activity multiplies the clock and touches
    // nothing else.
    property real _t: 0

    // The field at a point in GLOBAL layout coordinates.
    function fieldAt(gx, gy) {
        var x = gx / mat.fieldScale, y = gy / mat.fieldScale;
        var t = mat._t;
        // Level 1, then level 2 warping the warp. `warp_levels` drives the loop
        // count so the second level cannot be deleted without changing a token.
        var wx = x, wy = y;
        for (var L = 0; L < mat._fld.warp_levels; L++) {
            var qx = mat._fbm(wx + 0.31 * L + t, wy + 1.73 * L - t * 0.5);
            var qy = mat._fbm(wx + 5.20 + 2.11 * L, wy + 1.30 + 0.77 * L + t);
            wx = wx + mat._fld.bias * qx;
            wy = wy + mat._fld.bias * qy;
        }
        var v = mat._fbm(wx, wy);
        // THE CRUSH, exactly as `_crush_note` writes it. It holds the frame
        // near-black so the deep teals read — `_swirl._rules` rule 1, "grounds
        // stay near-black", applied to this consumer.
        return mat._fld.crush_floor + (1 - mat._fld.crush_floor)
               * mat._smoothstep(mat._fld.crush_lo, mat._fld.crush_hi, v);
    }

    // ── THE RIDGE ────────────────────────────────────────────────────────
    // `_extraction_note`, verbatim as a formula:
    //     fil = exp(-((v - band_centre)/band_sigma)^2)
    //           * smoothstep(band_centre - shoulder_lo, band_centre - shoulder_hi, v)
    // Filaments are where the field CROSSES a level, not where it EXCEEDS one.
    // The Gaussian is the crossing; the smoothstep is the shoulder that stops
    // the dark half of the field contributing a second, phantom filament.
    function ridgeAt(v) {
        if (!mat._ridge)
            return 0;               // plateau is refused, not drawn — see above
        var f = mat._f;
        var g = Math.exp(-Math.pow((v - f.band_centre) / f.band_sigma, 2));
        var s = mat._smoothstep(f.band_centre - f.shoulder_lo,
                                f.band_centre - f.shoulder_hi, v);
        return g * s;
    }

    // ══ THE CLAMP · ON THE SUM, NEVER ON ONE LAYER ═══════════════════════
    // `sweep._the_clamp_covers_BOTH_layers_not_just_the_highlight`, and
    // `AGENTS.md` after the harness that clamped the sweep's highlight exactly
    // as the study wrote it and watched the composite breach anyway at L 0.4726:
    // the clamp's contract is the SUMMED ADDITIVE OUTPUT, after filament and
    // sweep, never a single layer. So both peaks are added here, once, and ONE
    // common gain is applied to both. The cap is read from the sweep block
    // rather than from `_tokens.ambient`, whose own `_enforcement` note records
    // that the ambient number is enforced nowhere in the tree.
    function _lin(c) { return c <= 0.04045 ? c / 12.92
                                           : Math.pow((c + 0.055) / 1.055, 2.4); }
    function _lum(c) { return 0.2126 * mat._lin(c.r) + 0.7152 * mat._lin(c.g)
                            + 0.0722 * mat._lin(c.b); }

    readonly property real _filPeak: _f.strength * _kept * strengthScale
                                     * _lum(filamentColor)
    readonly property real _swpPeak: _sweepAmp * _lum(_glintColor)
    readonly property real _clampGain: {
        var sum = mat._filPeak + mat._swpPeak;
        var cap = mat._s.peak_luminance_clamp;
        return (sum > cap && sum > 0) ? cap / sum : 1.0;
    }

    // ══ THE DECOUPLE ═════════════════════════════════════════════════════
    // TWO NAMED STATES, not two points on one axis — that misreading is called
    // out by name in the material. `material_kept` is how much of the FILAMENT
    // an unfocused pane retains; `smoke` is the absorption laid over it, and it
    // is absorption BY FOCUS, the distinction Hyprland already draws at
    // active/inactive opacity. Neither is a fourth fill rung, so neither touches
    // the pane's body and neither touches type: the smoke lands on the light
    // passing through the pane, which is what absorption means.
    // ── the two levers, overridable PER SURFACE and nowhere else ─────────
    // Negative means "use the token", which is the only value any shipped
    // surface sets. They exist because the owner asked for a LADDER of
    // separations to pick from, and because `accent.json` and `Theme.qml` are
    // read-only to this pass: a rung has to be expressible without editing the
    // definition. THEY ARE TWO SEPARATE LEVERS AND MUST BE REPORTED SEPARATELY —
    // `_they_are_named_states_not_two_points_on_one_axis` says so in as many
    // words, and quoting a rung as one number is the misreading it names.
    //
    // ⚠ WHICHEVER RUNG IS CHOSEN, THE VALUES BELONG IN `_glass_material
    // .decouple` AND ITS MIRROR, NOT HERE. An override left on a shipped surface
    // is a second source for a material value, which is the exact drift `13q45`
    // exists to catch.
    property real keptOverride:  -1
    property real smokeOverride: -1

    readonly property real _keptBase:
        keptOverride >= 0 ? keptOverride : mat._d.material_kept
    readonly property real _smokeBase:
        smokeOverride >= 0 ? smokeOverride : mat._d.smoke

    readonly property real _kept:  focused ? 1.0 : mat._keptBase
    readonly property real _smoke: focused ? 1.0 : mat._smokeBase

    // ══ THE SWEEP ════════════════════════════════════════════════════════
    // Amplitude, and the crossfade between the two states. `transition_curve` is
    // `curveMove` and `transition_ms` is `durQuick` — "so the change of focus
    // feels CAUSED BY THE CLICK rather than noticed afterwards". Both are read
    // from the material; the curve is resolved through the motion ladder the
    // material names.
    property real _sweepAmp: (focused ? mat._s.amp_focused : mat._s.amp_unfocused)
                             * mat._smoke * strengthScale
    Behavior on _sweepAmp {
        NumberAnimation {
            duration: mat._s.transition_ms
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveMove
        }
    }

    // OSCILLATION, NOT A LOOP: "a unidirectional repeating wipe is the
    // skeleton-loading idiom and would say 'busy', not 'focused'." So the phase
    // runs 0→1→0 over `period_ms` and the streak returns the way it came.
    //
    // UNFOCUSED IS STILL, NOT ABSENT — `_amp_note`: "the band parks at its rest
    // position rather than vanishing. Absent would make focus a
    // presence/absence flag; parked makes it an amplitude, which is what a
    // tilting surface does." So the animation stops when unfocused and the band
    // stays where it is, at `amp_unfocused`. That is also the cheap answer:
    // `unfocused_draws_once` measured a frozen clock as saving nothing, so the
    // saving has to come from not running at all.
    property real _phase: 0
    SequentialAnimation on _phase {
        running: mat.focused && mat.visible && mat.width > 1
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: mat._s.period_ms / 2
                          easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: mat._s.period_ms / 2
                          easing.type: Easing.InOutSine }
    }

    // The sweep coordinate is `u_local × screen_offset_local + paneOrigin ×
    // screen_offset_pane`, wrapped. Inverting it for the band's centre in LOCAL
    // coordinates is what puts the highlight in a different place on every pane
    // at the same instant: two panes of the same size at different screen
    // origins are lit differently, which is the difference between one lamp in
    // the room and a decal stamped on each window.
    //
    // `screen_offset_local` < 1 means each pane sees a SLICE of a sweep wider
    // than itself, so the band reads wider than its own `band_width` here and is
    // away from the pane for part of the cycle. Both are correct: the light is
    // somewhere else for a while.
    function _fract(v) { return v - Math.floor(v); }
    readonly property real _originTerm:
        _fract((paneScreenX / Math.max(screenW, 1)) * _s.screen_offset_pane
             + (paneScreenY / Math.max(screenH, 1)) * _s.screen_offset_local)
    readonly property real _bandCentre: {
        var base = mat._phase - mat._originTerm;
        if (base < 0) base += 1;
        return base / mat._s.screen_offset_local;
    }
    readonly property real _bandHalf: (_s.band_width / 2) / _s.screen_offset_local
    readonly property real _glintHalf: _bandHalf * _s.glint_frac

    // ── the highlight · desaturated BY INTENSITY ──────────────────────────
    // `_desat_note`: intensity desaturation is REQUIRED, not a refinement — a
    // cool highlight held at full tint reads as a coloured stripe rather than as
    // light. The brighter the sweep is asked to be, the further its core goes
    // toward white, capped at `desat_max`. `glassSweepHighlight` is the
    // material's ONE colour and it is read, not restated: gate `13q45` asserts
    // the material declares exactly one, so a second one here would be a defect
    // in this file, not a choice.
    function _desat(c, intensity) {
        var k = Math.pow(Math.max(0, Math.min(1, intensity)), mat._s.desat_pow)
                * mat._s.desat_max;
        return Qt.rgba(c.r + (1 - c.r) * k,
                       c.g + (1 - c.g) * k,
                       c.b + (1 - c.b) * k, 1.0);
    }
    readonly property color _glintColor:
        _desat(Theme.glassSweepHighlight,
               _sweepAmp / Math.max(_s.amp_focused, 0.001))

    // The seam the sweep is allowed to touch: `_tokens.edges.seams.idle`, teal
    // at 0.22 — alpha, WCAG 1.4.11-exempt, measured on this build's OWN beds at
    // 1.36:1 over the Start Menu's card face and 1.35:1 over the flyout's, and
    // correct at both, because a seam divides surfaces and reports no state.
    //
    // THE SWEEP MAY BRIGHTEN A SEAM AND MAY NOT TOUCH A STATE RIM. Ladder A is
    // in reach — including `seams.idle`, because a resting interactive control's
    // edge is still a seam. Ladder B (hover / active / focus-visible: solid,
    // hue-coded, 3:1 floor) is not, or "is this hovered?" becomes a question
    // about the wallpaper. That is guaranteed STRUCTURALLY here rather than by
    // discipline: this component draws the SURFACE's own seam ring and nothing
    // else, and every state edge in these two surfaces is drawn by
    // `StateEdge.qml` on a control inside it, never on this ring.
    readonly property color _seamColor:
        Theme.soften(Theme.lookSeam, 0.22)

    // ══ LAYER 1 · THE FILAMENT · a thin ring, ridge-extracted ═════════════
    // A Canvas, not a stack of Rectangles, for one reason: the ridge has to be
    // evaluated at many points ALONG each edge and `Gradient` cannot take a
    // computed number of stops. Canvas can, and it is the only primitive in Qt
    // Quick that can express this without a shader — `_hard_rules` already
    // records that radial and conic gradients are ShaderEffect territory for the
    // same class of reason.
    //
    // TRK-932 sixth cut (owner 08-20 10:48): corners of the CARD are
    // good (do not retouch Theme.r3 / Launcher radii). Fifth cut thinned
    // the corner pen 8→2; qs hot-reloaded it; owner still saw half
    // circles in all four corners. A 2 px stroke of a 22 px quarter-arc
    // is still a 22 px ice quarter-circle. This Canvas now strokes the
    // four STRAIGHTS only. The 1 px seam Rectangle traces the bend.
    // No fillRect. No arc fill. No destination-out. No ctx.arc.
    //
    // It repaints only while focused (see `unfocused_draws_once` above): an
    // unfocused surface paints one frame and holds it, which is a cached texture
    // by construction.
    Canvas {
        id: band
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        antialiasing: true
        visible: mat._f.strength * mat._kept > mat._f.early_out && mat._ring >= 1

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (mat._ring < 1 || !mat._ridge)
                return;

            var f = mat._f;
            var amp = f.strength * mat._kept * mat._clampGain * mat.strengthScale;
            if (amp <= f.early_out)
                return;

            var col = mat.filamentColor;
            var cr = Math.round(col.r * 255), cg = Math.round(col.g * 255),
                cb = Math.round(col.b * 255);
            var W = mat.width, H = mat.height;
            var rtl = Math.max(0, mat.radiusTL);
            var rtr = Math.max(0, mat.radiusTR);
            var rbr = Math.max(0, mat.radiusBR);
            var rbl = Math.max(0, mat.radiusBL);
            var ring = mat._ring;
            var half = ring * 0.5;
            if (W < ring + 4 || H < ring + 4)
                return;

            // Clip to the pane so the outward half of the stroke cannot
            // paint the bite outside a rounded corner (WIP-335).
            ctx.beginPath();
            mat._roundRect(ctx, 0, 0, W, H, rtl, rtr, rbr, rbl);
            ctx.clip();

            function rgbaStop(alpha) {
                return "rgba(" + cr + "," + cg + "," + cb + ","
                       + Math.max(0, Math.min(1, alpha)).toFixed(4) + ")";
            }

            // Field along one straight, in GLOBAL layout coordinates.
            // `tangent_compress` stretches the sample along the edge so
            // filaments run WITH it. ⚠ rgba() string, never Qt.rgba().toString()
            // — Qt serialises alpha-first #AARRGGBB and Canvas 2D reads CSS
            // #RRGGBBAA, which rotated the channels into a 1/255 smear.
            function sampleEdge(horiz, x0, x1, base, dir) {
                var len = x1 - x0;
                var stops = [];
                if (len <= 2)
                    return stops;
                var taps = Math.max(8, Math.min(mat.fieldTapsMax,
                                                Math.round(len / mat.fieldTapPx)));
                for (var i = 0; i <= taps; i++) {
                    var u = i / taps;
                    var lx, ly;
                    if (horiz) {
                        lx = x0 + len * u;
                        ly = base + dir * half;
                    } else {
                        lx = base + dir * half;
                        ly = x0 + len * u;
                    }
                    var tgx = horiz ? f.tangent_compress : 1.0;
                    var tgy = horiz ? 1.0 : f.tangent_compress;
                    var v = mat.fieldAt(mat.paneScreenX + lx * tgx,
                                        mat.paneScreenY + ly * tgy);
                    stops.push(mat.ridgeAt(v));
                }
                return stops;
            }

            var topStops = sampleEdge(true,  rtl, W - rtr, 0,  1);
            var botStops = sampleEdge(true,  rbl, W - rbr, H, -1);
            var leftStops = sampleEdge(false, rtl, H - rbl, 0,  1);
            var rightStops = sampleEdge(false, rtr, H - rbr, W, -1);

            // TRK-932 sixth cut (owner 10:48: half circles STILL in all
            // four corners after the 2 px fifth cut). qs DID hot-reload
            // that cut (Configuration Loaded 10:24:34 / 10:25:04). A 2 px
            // ice stroke of a 22 px quarter-arc is still a 22 px ice
            // quarter-circle sitting in the corner — thinning the pen
            // does not change the shape the owner named. Straights keep
            // the 2 px field-sampled hairline. The bend is already traced
            // by the 1 px seam Rectangle below. No ctx.fill. Radii untouched (WIP-348).
            ctx.globalCompositeOperation = "source-over";
            ctx.globalAlpha = 1.0;

            function strokeGrad(x0, y0, x1, y1, stops) {
                if (!stops || stops.length < 2)
                    return;
                var g = ctx.createLinearGradient(x0, y0, x1, y1);
                var n = stops.length - 1;
                for (var k = 0; k <= n; k++)
                    g.addColorStop(k / n, rgbaStop(amp * stops[k]));
                ctx.strokeStyle = g;
                ctx.lineWidth = ring;
                ctx.lineJoin = "bevel";
                ctx.lineCap = "butt";
                ctx.beginPath();
                ctx.moveTo(x0, y0);
                ctx.lineTo(x1, y1);
                ctx.stroke();
            }

            // Filament streaks on the four straights only, same 2 px
            // hairline. Butt + bevel so the tangent cannot grow a disc.
            strokeGrad(rtl, half,     W - rtr, half,     topStops);
            strokeGrad(rbl, H - half, W - rbr, H - half, botStops);
            strokeGrad(half, rtl,     half, H - rbl,     leftStops);
            strokeGrad(W - half, rtr, W - half, H - rbr, rightStops);
        }
    }

    // The field's clock. `flow` × `activity` is the drift rate; `clock` is
    // CLOCK_MONOTONIC and needs no IPC, because every consumer computes the same
    // t from a shared origin and the field drifts slowly enough that millisecond
    // skew is invisible. The repaint interval is a rendering choice, not a
    // material one: the field's SPEED is `flow`, and sampling it less often
    // makes it cheaper, never faster.
    Timer {
        interval: 80
        repeat: true
        running: mat.focused && mat.visible && band.visible
        onTriggered: {
            mat._t += mat._fld.flow * mat._fld.activity * (interval / 1000)
                      * (1 + mat._f.pointer_offset * 0);
            band.requestPaint();
        }
    }
    // One frame for an unfocused surface, and then nothing. Also repaints when
    // the geometry or the colour moves, because the field is screen-space: a
    // surface that MOVES genuinely changes its patch of it.
    onFocusedChanged: band.requestPaint()
    onWidthChanged: band.requestPaint()
    onHeightChanged: band.requestPaint()
    onFilamentColorChanged: band.requestPaint()
    onPaneScreenXChanged: band.requestPaint()
    onPaneScreenYChanged: band.requestPaint()
    onRadiusTLChanged: band.requestPaint()
    onRadiusTRChanged: band.requestPaint()
    onRadiusBRChanged: band.requestPaint()
    onRadiusBLChanged: band.requestPaint()
    Component.onCompleted: band.requestPaint()

    // ══ LAYER 2 · THE FOCUS SWEEP · on the seam, and only the seam ════════
    // The seam ring. This is also the FIX for the two `Theme.glassBorder` edges
    // the side panel used to draw: those were `#891955`, a retired rung, drawn
    // UNDER the swell ground where they measured 1.02–1.06:1 against the very
    // ground covering them. The numbers are in SidePanel.qml at the sites.
    // TRK-932 ninth: a 1 px STROKE of a 22 px radius is a hairline along
    // the bend, not a pie. The pie was a FILL (GlassEdge Sheen H 30 > r 22).
    // Seventh cut inset four straights by the radius and left a 22 px hole
    // in every corner — on the 46 px rail that hole is the whole top.
    // Transparent fill, 1 px border, host radii. Theme.r3 untouched.
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: Theme.lookOutlineW
        border.color: mat._seamColor
        topLeftRadius: mat.radiusTL
        topRightRadius: mat.radiusTR
        bottomRightRadius: mat.radiusBR
        bottomLeftRadius: mat.radiusBL
        antialiasing: true
    }

    // The travelling glint, ON the seam. The top and bottom seams carry the
    // band's position along the pane; the two ends brighten as the band arrives
    // at them, which is what a streak crossing a pane does to its edges.
    Repeater {
        model: 2                        // 0 top · 1 bottom
        delegate: Rectangle {
            required property int index
            height: 1
            y: index === 0 ? 0 : mat.height - 1
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: index === 0 ? mat.radiusTL : mat.radiusBL
            anchors.rightMargin: index === 0 ? mat.radiusTR : mat.radiusBR
            visible: mat._sweepAmp > mat._f.early_out
            readonly property real a: mat._sweepAmp * mat._clampGain

            // A band with a narrow core: `glint_frac` 0.26 of a `band_width`
            // 0.21. The core is why the highlight can be this bright at all —
            // its luminance is over the ambient cap as a filled area and safe as
            // a 1 px core, the same finding already on record for `#ffb3d9`.
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.soften(mat._glintColor, 0) }
                GradientStop {
                    position: Math.max(0, Math.min(1, mat._bandCentre - mat._bandHalf))
                    color: Theme.soften(mat._glintColor, 0)
                }
                GradientStop {
                    position: Math.max(0, Math.min(1, mat._bandCentre - mat._glintHalf))
                    color: Theme.soften(mat._glintColor, parent.a * 0.45)
                }
                GradientStop {
                    position: Math.max(0, Math.min(1, mat._bandCentre))
                    color: Theme.soften(mat._glintColor, parent.a)
                }
                GradientStop {
                    position: Math.max(0, Math.min(1, mat._bandCentre + mat._glintHalf))
                    color: Theme.soften(mat._glintColor, parent.a * 0.45)
                }
                GradientStop {
                    position: Math.max(0, Math.min(1, mat._bandCentre + mat._bandHalf))
                    color: Theme.soften(mat._glintColor, 0)
                }
                GradientStop { position: 1.0; color: Theme.soften(mat._glintColor, 0) }
            }
        }
    }

    // The two ends. A streak does not stop at a corner, so the left and right
    // seams take the band's coverage AT that end — full when the band is
    // standing on the end, nothing when it is away.
    Repeater {
        model: 2                        // 0 left · 1 right
        delegate: Rectangle {
            required property int index
            width: 1
            x: index === 0 ? 0 : mat.width - 1
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: index === 0 ? mat.radiusTL : mat.radiusTR
            anchors.bottomMargin: index === 0 ? mat.radiusBL : mat.radiusBR
            readonly property real reach:
                Math.max(0, 1 - Math.abs(mat._bandCentre - index)
                              / Math.max(mat._bandHalf, 0.001))
            visible: reach > 0.01 && mat._sweepAmp > mat._f.early_out
            color: Theme.soften(mat._glintColor,
                                mat._sweepAmp * mat._clampGain * reach)
        }
    }

    // Travelling glint stays on the straights (inset so a 1 px bar cannot
    // square the arc). The seam Rectangle above now traces the bend at 1 px.
}
