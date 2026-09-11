// Nyxus Suxyn — the reactive panel swirl (AUDIT-PLAN item 5's living light).
//
// Liquid paint that lives INSIDE a panel, not a wallpaper. This is now a
// STRUCTURAL port of design/swirl-live.html rather than a re-derivation of it:
// the same Navier–Stokes chain the reference runs, pass for pass, constant for
// constant.
//
//   splat → curl → vorticity → divergence → clear → pressure ×22
//         → gradient subtract → advect velocity → advect dye → display
//
// The previous port replaced all of that with an analytic divergence-free
// curl-noise flow and one dye texture (the old accent.json _swirl._port rule,
// "do NOT port the pressure solver"). That decision is what made the panel read
// as broad smooth bands where the reference has filaments, spirals and dark
// voids between them — a stream-function flow has no vorticity confinement and
// nothing for the dye to pile up against, and no amount of constant-tuning
// recovers it. The old shader's own comments admit as much. So the solver is
// ported.
//
// It fits Qt Quick because a chain of ShaderEffectSource layers is updated in
// scene-graph order INSIDE one frame, with no lag — verified with an 8-deep
// copy chain carrying a per-frame counter, which arrived at the tail in the
// same frame it was written. Every layer here is therefore declared in
// dependency order, and the three feedback edges (velocity, dye, pressure) work
// by reading a layer earlier in that order than it is written.
//
// Behaviour contract (the idle-cost story) is unchanged:
//   · pointer strokes paint ribbons; hue = sweep position + per-splat jitter
//   · music (bind the Beat singleton) pumps the flow and drops paint on beats
//   · with no stimulus it settles, and after `lingerMs` the FrameAnimation
//     stops and every layer goes non-live — the sim is OFF, zero GPU
//   · hidden panels (visible: false) never run
//
// Drop it as the first child of a glass panel, under the content:
//
//     Swirl {
//         anchors.fill: parent
//         cornerRadius: Theme.radius
//         audioBass: Beat.bass; audioMid: Beat.mid
//         audioHigh: Beat.high; audioPulse: Beat.pulse
//         musicActive: Beat.hot
//     }
//
// design/swirl-live.html is the reference this file is judged against. Numbers
// marked "reference:" are its numbers and are not to be re-tuned here — change
// them there first. qsb shaders rebuild with shell/shaders/build.sh.
pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: root

    // ── look ─────────────────────────────────────────────────────────
    property real cornerRadius: 18
    property real sweepLo: 0.0          // slice of the signature sweep this
    property real sweepHi: 1.0          // panel paints with (bar uses all)
    property real sweepGamma: 1.35      // reference: sweepGamma 1.35
    // Stroke width. The reference's `splatRadius` divides d² directly, so it is
    // an area, not a length; this knob is its square root so that the values
    // the panels already pass (0.20–0.30) keep meaning roughly what they meant.
    // 0.245² = 0.060 = the reference taskbar exactly.
    property real impulseRadius: 0.245
    property real exposure: 2.05        // reference: display exposure 2.05
    property real bloom: 1.0
    property real saturation: 1.22      // reference: display saturation 1.22
    property real sheen: 0.35           // reference: display spec 0.35
    // Reference-exact output: `uBase + c`, opaque, no rounded mask. Only for
    // side-by-side comparison against design/swirl-live.html — the shell wants
    // the premultiplied add-light path.
    property bool opaque: false

    // ── motion. reference constants; the knobs scale them ────────────
    property real ambientAmp: 0.42      // reference: ambient.force 0.42

    // ── the color layer (WIP-619, owner ruling 2026-08-14) ───────────────
    // Seven ramp stops, defaulted from the shell-wide layer so every surface
    // follows a Settings change at once. A surface may still override for a
    // deliberate reason, but "the bar is rose and the flyout is glacier" is
    // not a state the product ships. Theme.paintRamp is the single source.
    //
    // ── WIP-700, the living paint says something about the machine ───────
    // Defaulted through `PaintMood` rather than straight off Theme. That
    // singleton hands back `Theme.paintRamp` UNCHANGED whenever the
    // behaviour is off, the reading is unknown, or the machine is idle — the
    // same array, not a re-derived copy — so this line is a no-op in every
    // one of those cases and the paint's normal appearance is literally the
    // normal appearance. Under load it leans the layer up to 30% toward the
    // ember anchor, slowly; `PaintMood.qml`'s header carries the laws and
    // the arithmetic. A tenant may still override `ramp:` for a deliberate
    // reason and thereby opt out of the whole behaviour.
    property var ramp: PaintMood.ramp

    // ── motion mode (WIP-621, the owner's spec verbatim) ─────────────────
    // "i personally like how my bottom bar does it by itself … but others
    // may not, so make that their own decision."  ambient = the field stirs
    // and re-dyes itself (the shipped default, and his setting);
    // interactive = still until the pointer or a beat feeds it — the intro
    // still plays on open, because opening a surface IS interaction. Off is
    // the master switch (swirl_enabled), not a third value here.
    readonly property bool _motionAmbient: Prefs.swirlMotion !== "interactive"

    // ── the material (WIP-880, owner pick 2026-08-18) ────────────────────
    // "black shadow to me is the closest to what i already have in the look
    // but with it being black … if it were dark a little better … plus i
    // have to see it live on my bar to really see what it looks like."
    //
    // Specimen A of the thirteen-treatment variety pass: the swirl goes pure
    // black and a faint even glow behind it is BLOCKED by the paint, so the
    // structure is read entirely as absence. `swirl_view.frag`'s header owns
    // the mechanism and the one substitution it makes.
    //
    // THE LADDER IS THE DELIVERABLE, not any single number. He asked for
    // "a little darker" than what he was shown, and that is a judgement only
    // his own bar can settle — so the step he was shown stays reachable as
    // the anchor and three darker rungs sit under it. Glow is in 8-bit
    // levels, the study's own unit.
    //
    // ⚠ THE RUNGS ARE NOT THE STUDY'S NUMBERS, AND THAT IS DELIBERATE. The
    // shader substitutes the dye field's MEAN for the study's MEDIAN (its
    // header argues why). A right-skewed field's mean sits above its median,
    // so the shipped pass under-occludes and errs BRIGHT — measured at
    // **1.17×** on a distribution fitted to the study's own three reported
    // bar quantiles (median 0.0079, p90 0.0138, p99 0.0746). A shipped glow
    // of 18 would therefore read like the study's 21, which is the wrong
    // direction from "a little darker". Every rung below is the study glow
    // divided by that 1.17.
    //
    // Predicted bar-height mean 8-bit, from the study's OWN three measured
    // rows (glow 10 → 6.0, 18 → 8.6, 28 → 11.8 over its modelled bed; those
    // three are linear to a max residual of 0.015 levels, at
    // mean = 2.787 + 0.3221 × study glow):
    //
    //   shadow-darkest    glow  6   ≈ study  7.0   predicted mean 5.05
    //   shadow-dim        glow  9   ≈ study 10.5   predicted mean 6.18
    //                                  — the study's own "dim glow" row
    //                                    measured 6.0 and its verdict was BLACK
    //   shadow            glow 12   ≈ study 14.1   predicted mean 7.31  ← start here
    //   shadow-rendered   glow 15   ≈ study 17.6   predicted mean 8.45
    //                                  — the specimen he chose measured 8.6
    //
    // Predictions, and labelled as such: they chain a fit of three measured
    // rows to a bias factor measured on a field FITTED to three quantiles of
    // a field whose generator was deleted. What IS measured on this machine's
    // GPU is that the rungs are linear in glow to within 8-bit quantisation
    // and that none of it depends on the dye's absolute level.
    //
    // Unknown strings — including "paint" — resolve to 0, which is the
    // shipped paint, byte for byte, in the shader. A typo cannot break the
    // bar; it can only leave it as it was.
    // ── the tenant pin (BARSWIRL, owner order 2026-08-29) ────────────────
    // "the bottom bar's swirls must be BLACK — just black." One surface is
    // ordered onto one rung while every other Swirl keeps following the
    // user's setting, so the mode is resolved through a property that
    // DEFAULTS to the pref binding. A tenant that never sets `paintMode`
    // is byte-for-byte the old behaviour — the binding below is the same
    // `Prefs.swirlMode` read that used to sit inside `_shadowGlow`.
    // BarSeam.qml (the bar's visible paint) pins "shadow", the WIP-880
    // ladder's anchor rung, which is the treatment the owner picked on
    // 08-18 as "black shadow ... but with it being black". Unknown strings
    // still resolve to 0 = the shipped paint, so a typo cannot break a bar.
    property string paintMode: Prefs.swirlMode
    // ── TRK-3478 · the glow, as a DIAL rather than a rung ────────────────
    // -1 (the default) means "use the ladder below", so every surface that
    // does not set this is byte-identical. The bar sets it, because the glow
    // is the one term that lifts the bar's RESTING GROUND above the widgets'
    // — the owner's 08-30 complaint, "the background or the layers don't look
    // like that of the widgets" — and the ladder's rungs are the Settings
    // vocabulary, not a place to put one surface's calibration.
    property real shadowGlow: -1
    readonly property real _shadowGlow: shadowGlow >= 0 ? shadowGlow
        : paintMode === "shadow"          ? 12
        : paintMode === "shadow-dim"      ?  9
        : paintMode === "shadow-darkest"  ?  6
        : paintMode === "shadow-rendered" ? 15
        // TRK-3466 (owner 08-29, live iteration: "add a slightly
        // stronger glow"): a BAR-ONLY rung, one step past the ladder's
        // top, between the WIP-880 study's glow-18 and glow-28 rows.
        // Never a Prefs.swirl_mode value — only BarSeam's pin reaches
        // it, so Settings and every other surface are untouched.
        : paintMode === "shadow-bar"      ? 27
        : 0
    // The study held `occ` at 0.85 across all three of its glow rows, so the
    // ladder above varies exactly one thing and this does not move with it.
    property real shadowOcclusion: 0.85
    // The study's own normaliser constant, unchanged: thickness is
    // `clamp(h / (2.2 × h̄), 0, 1.5)`. Only h̄ differs from the study — it
    // reads the dye's MEAN out of the mip chain rather than a per-geometry
    // median a shader cannot compute. `swirl_view.frag`'s header argues that
    // substitution and states which way it errs.
    property real shadowNorm: 2.2
    // TRK-3466 — the flowing glow-line inside shadow paint, 8-bit levels.
    // 0 = off (shipped); only BarSeam sets it.
    property real shadowFlowLine: 0
    // ── TRK-3476 · the SECOND contour · owner 2026-08-30 ─────────────────
    // A second isoline of the same advected thickness field `shadowFlowLine`
    // rides, so a stroke shows two nested edges across its fold instead of
    // one outline. `swirl_view.frag`'s own note argues why a contour — and
    // not more force, curl or dye — is what makes an occluder read as
    // swirling: the solver's spirals are already there and the display was
    // integrating them away.
    //
    // 0 = OFF and that is the default, so every surface except the one that
    // asks for it renders exactly as it did. Strength is in 8-bit levels,
    // the same unit as `shadowFlowLine` and the WIP-880 study.
    property real shadowFilament: 0
    // Where the second contour sits, in the same T the occluder reads
    // (0 = bare ground, 1.5 = the thickest paint the clamp allows). The
    // primary line is fixed at 0.6, so this wants to be clearly off it or
    // the two merge into one broad band.
    property real shadowFilamentT: 0.30
    // Its half-width in T. Narrower than the primary's 0.22 on purpose —
    // this is the line, that is the band.
    property real shadowFilamentW: 0.12
    // ── TRK-3478 · the halo floor ────────────────────────────────────────
    // How much of the glow sits on ground with NO paint on it. TRK-3475
    // pinned this at 0.88 to stop the ground flipping with the music; the
    // cost is an even wash the widgets do not carry, which is the owner's
    // 08-30 "the background doesn't look like the widgets". Now that the two
    // contours carry the swirl's visibility on their own, the floor can come
    // down without the strokes going with it. 0 = keep 0.88, so every
    // surface that does not set it is unchanged.
    property real shadowHaloFloor: 0
    // ── TRK-3481 · LIQUID GLASS · owner 2026-08-30 ───────────────────────
    // "what if we made like a liquid glass as the swirls instead ... using
    // the glass materials instead?"
    //
    // Every treatment before this is additive light ON the material, which is
    // why the bar could never equal a widget — it was the widget material
    // PLUS something. This one modulates the material itself: thickness
    // drives ALPHA (premultiplied source-over, so alpha is what darkens), and
    // at zero thickness the pass writes (0,0,0,0) — the glass, untouched.
    // The background match becomes algebra rather than tuning.
    //
    // 0 = OFF and that is the default, so no other surface moves. Setting it
    // takes priority over `paintMode`'s shadow branch.
    property real liquidStrength: 0
    // How much of the material's OWN colour thick glass pools. Not a dye.
    property real liquidPooling: 0.06
    // The light caught where the sheet folds — a caustic, not a rim.
    property real liquidCaustic: 0.5
    // Where a stroke starts. T is thickness relative to the field MEAN, so
    // ~1.0 is the resting ambient haze; only above that is a sheet.
    property real liquidThreshold: 0.95
    // The colour thick glass carries. NOT a dye and NOT `Theme.plum`: the
    // first cut used plum (#ae206c) and the bar grew a hot pink filigree,
    // because a saturated hue multiplied into an ADDITIVE term is a dye by
    // any other name. Real glass going thicker gets DARKER (that is the
    // alpha term) and catches a COOL specular at the fold — the same ice the
    // GlassEdge sheen already uses. So this is glacier, and it is spent
    // almost entirely on the caustic.
    property color liquidPoolColor: Theme.paintLayers.glacier[0]
    // ── TRK-3488 · refraction ────────────────────────────────────────────
    // The item the sheet bends — for the bar, `SkyBehind`: the real
    // HeadlinerSky rendered screen-aligned INSIDE this window so it can be
    // sampled. null = off; `bg` then falls back to the dye buffer so the
    // sampler is never unbound.
    property var refractSource: null
    property real refractAmount: 0
    property real refractDispersion: 0.45
    property real refractVScale: 1.0

    // WIP-338 — how much DYE the ambient stirrers lay down as they move. This
    // was effectively 0 (see _ambientStep), which is why the paint went
    // invisible at rest: the field was being stirred and never fed. Deliberately
    // an order below an interaction splat — this is the resting glow the card
    // keeps, not a stroke. Turn it to 0 to get the old behaviour back.
    property real ambientDye: 0.14
    // ── TRK-3484 · EVEN SWEEP · owner 2026-08-30 ─────────────────────────
    // The stirrers ride `Math.sin`, whose SPEED goes to zero at its turning
    // points. They therefore linger at the two ends of their travel and race
    // through the middle — and since dye is laid per unit TIME (WIP-648's
    // law), the field ends up pooled at both ends of the bar with a starved
    // centre. On a 22.9:1 strip that is unmistakable: the owner's 2026-08-30
    // screenshot shows two isolated patches at the ends and an empty middle.
    //
    // A triangle wave has CONSTANT speed, so the same three stirrers lay dye
    // uniformly across the width. false keeps the sine exactly, so every
    // other surface is unchanged — and on a squarer host the dwell is far
    // less visible, which is why this was never noticed anywhere else.
    property bool ambientEvenSweep: false
    // ── TRK-3493 · VORTEX INJECTION · owner 2026-08-31 ───────────────────
    // "is there a different motion it can do by itself?"
    //
    // The stirrers push dye ALONG their own travel, which makes ribbons that
    // happen to curl at the ends. Pushing PERPENDICULAR to travel instead
    // shears the fluid across the stroke, and shear is what actually rolls up
    // into a vortex — the solver's vorticity confinement then keeps the eddy
    // tight once it forms. Same stirrers, same dye, one rotated vector, and
    // the field stops drifting and starts spinning.
    //
    // 0 = the shipped along-path push, so every other surface is unchanged.
    // 1 = fully perpendicular. Between is a spiral, which is what a real
    // stirred fluid does: it is dragged AND sheared at once.
    property real ambientVortex: 0
    // ── the current ──────────────────────────────────────────────────────
    // A slow persistent drift added to every ambient push. Without one, dye
    // pools wherever the stirrers happen to spend time and the middle of a
    // wide surface starves — which is exactly what the owner photographed on
    // the bar. A current carries material through the whole field instead.
    // x,y in UV per unit of the stirrer's own strength; 0,0 = off.
    property real ambientCurrentX: 0
    property real ambientCurrentY: 0
    // ── TRK-3494 · DRIVE IT TO THE MUSIC · owner 2026-08-31 ──────────────
    // "i wanna drive it a lot harder so you can actually see it to the music."
    //
    // The shipped boost is `1 + 0.7*bass + 0.5*pulse` — a nudge, which is why
    // the field barely acknowledges a track. This scales the AC part of that,
    // so 1.0 is byte-identical to the shipped behaviour and every other
    // surface stays where it is, while the bar can be driven far harder.
    //
    // ⚠ Deliberately scales only the music-dependent term. The resting field
    // is untouched, so when the audio stops — bass, pulse and kick all decay
    // to 0 — the surface returns to exactly the calm it had before, with no
    // state to reset and no transition to write.
    property real audioDrive: 1.0
    // A beat also has to be SEEN, not just felt as speed. On a kick the
    // stirrers lay extra dye, so a transient puffs new material into the
    // field rather than merely pushing what is already there faster.
    property real audioDyeKick: 0
    property real audioKick: 0
    // ── TRK-3495 · A SPECTRUM MADE OF LIQUID · owner 2026-08-31 ──────────
    // "do per band spectrum ... i don't want lines, i want it to look like
    // waves or whatever ... something bad ass, not plain and basic."
    //
    // So this is not a graph drawn over the surface. The BANDS DRIVE THE
    // FLUID: each entry owns a slice of the width, and a stirrer passing
    // through that slice is pushed and fed in proportion to that band's
    // energy. Bass boils one end, air shimmers the other, and everything
    // between is the solver's own turbulence responding per frequency.
    //
    // The result is a spectrum you can only get this way — it churns, it
    // overshoots, it carries momentum between bands, and it never looks like
    // a bar chart because there are no bars anywhere in it.
    //
    // Empty (the default) = no spectrum term at all, so every other surface
    // is untouched.
    property var audioSpectrum: []
    property real spectrumDrive: 0
    // ── TRK-3497 · colour on the contours, only while music plays ────────
    // The swirl is a black occluder with near-white filigree, so a beat can
    // only ever make it BRIGHTER — never different. Hue is the strongest
    // signal of the three, and it is the one this treatment has never used.
    // Only the CONTOURS take the tint: colouring the base glow as well would
    // wash the whole bar, where colouring the filigree makes the lines
    // themselves burn while the ground stays the material's own dark.
    // 0 = the shipped monochrome swirl, so silence is byte-identical.
    property color contourColor: Theme.paintLayers.glacier[0]
    property real contourTintAmount: 0

    // Band energy at a normalised x, linearly interpolated so the slices
    // blend into one another rather than stepping — stepping is what would
    // make it read as bars.
    function _bandAt(x) {
        const n = audioSpectrum.length;
        if (n === 0 || spectrumDrive <= 0) return 0;
        if (n === 1) return audioSpectrum[0];
        const t = Math.max(0, Math.min(0.9999, x)) * (n - 1);
        const i = Math.floor(t), f = t - i;
        const a = audioSpectrum[i] || 0;
        const b = audioSpectrum[Math.min(n - 1, i + 1)] || 0;
        return a * (1 - f) + b * f;
    }
    property real curlAmp: 1.0          // × 50 = reference: curl 50 (bar)
    property real decayRate: 0.34       // reference: densityDissipation 0.34
    property real velocityDecay: 0.16   // reference: velocityDissipation 0.16
    property real force: 5200           // reference: force 5200
    // TRK-3474 — the pointer's own strength dial. `force` is shared by the
    // hand and the ambient stirrers, so a tenant tuning its drift slower
    // (the bar's 4300) also weakened the owner's strokes — his hand "feels
    // laggy". 1.0 is byte-neutral for every existing surface; a tenant sets
    // this to give the hand back its push without touching the drift.
    property real pointerForceMul: 1.0
    property real pressureScale: 0.8    // reference: pressure 0.8
    property int  pressureIterations: 22// reference: pressureIterations 22
    property real injectGain: 1.0
    property real intensity: 1.0        // user dial (Settings → Appearance →
                                        // Living paint); scales every deposit
    property real introStrength: 1.0    // big panels want a softer opening
    property string introMode: "bar"    // reference: 'bar' | 'loop'
    // Seconds after ignite() before `_introStep` deposits (t < 0 is a
    // blank). The live-html bar intro wants 0.4. Chips set 0: that wait
    // is why some buttons came up sharp (intro already finished off-
    // screen) and others faded in blurred (you watched t<0 then a 1.3 s
    // loop). Bar.qml does not set this — default stays 0.4.
    property real introDelay: 0.4
    property bool interactive: true
    property bool playIntroOnLoad: true
    property int  lingerMs: 12000       // reference: sleepMs 12000
    // What is left on screen once the sim has gone to sleep. The buffers keep
    // their last frame and nothing is being stepped, so this is a free static
    // image — see the long note on the display layer's `opacity` below.
    property real restOpacity: 0.62
    // The reference steps on requestAnimationFrame, i.e. 60 Hz. This build's
    // panel is 144 Hz, and a FrameAnimation follows the panel — so the ported
    // solver was stepping its 30 passes 2.4× more often than the thing it is a
    // port OF. That buys nothing (advection and vorticity are both dt-scaled,
    // so the field is the same) and costs 2.4× the CPU, which is most of the
    // idle-cost regression. Step at the reference's rate and let the display
    // pass run at panel rate off the frozen dye. 0 = follow the panel.
    // Defaulted from the quality ladder (`_tierCfg`, far below). At the default
    // tier this is 60 — exactly the value it has always carried — so the ladder
    // changes no surface until something selects another rung, and a tenant
    // that assigns this explicitly still wins.
    // ⚠ 0 means UNCAPPED here, not frozen. The floor tier freezes through
    // `_frozen`; zeroing this would mean the opposite of what it looks like.
    property int  maxStepHz: root._tierCfg !== undefined ? root._tierCfg.step_hz : 60

    // ── simulation resolution. reference: simShort/simCap, dyeShort/dyeCap ──
    // simShort/simCap are NOT tier levers. The measured per-pass breakdown puts
    // the whole sim-resolution chain at ~0.001 ms a link (22 pressure
    // iterations are 0.024 ms together) while the two DYE passes plus the
    // mipmap are 0.207 ms of the bar's 0.405 ms step — so the dye resolution is
    // where a tier can buy anything, and the pressure solve stays whole.
    property int simShort: 96
    property int simCap: 1024
    property int dyeShort: root._tierCfg !== undefined ? root._tierCfg.dye_short : 224
    property int dyeCap: root._tierCfg !== undefined ? root._tierCfg.dye_cap : 2304

    // ── music (bind from Beat; all 0..1) ─────────────────────────────
    property real audioBass: 0
    property real audioMid: 0
    property real audioHigh: 0
    property real audioPulse: 0
    property bool musicActive: false

    // ── the top-edge dissolve ────────────────────────────────────────
    // Height, IN PIXELS, of a band at the TOP of this item over which the
    // material ramps out to nothing. 0 is off and is the shipped edge.
    //
    // In pixels rather than as a fraction on purpose: the caller is placing
    // this against a screen edge and thinks in pixels, and the shader wants
    // a fraction of the item — doing that conversion here is the only place
    // that knows both numbers. `height` is the FULL item height, half of
    // which may be off-screen, which is exactly why a caller should not be
    // asked to work the fraction out itself.
    //
    // ⚠ This does NOT change the field. It scales the display pass's output
    // in a band; the solver, the grid, the splats and the dye are untouched.
    // A host wanting more field must MOVE this item, never resize it — the
    // sim grid is fitted from the aspect (see `_fit`), so a resize re-grids
    // the simulation and the seam becomes a different field.
    property real dissolveH: 0
    readonly property real _dissolveFrac:
        height > 0 ? Math.max(0, dissolveH) / height : 0

    // ── clock ────────────────────────────────────────────────────────
    property real time: 0
    property real dt: 1 / 60

    // ── derived ──────────────────────────────────────────────────────
    // TRK-2937: never 0, never negative, never non-finite. `_fit` turns this
    // into the width and height of eleven ShaderEffect items. Qt drops a
    // ShaderEffect's scene-graph node when either side is <= 0; when the node
    // comes back it is a NEW node and only uniforms that have CHANGED are
    // re-sent, so `mode` on the dye splat stays at the zero the buffer was
    // born with ("velocity") and the pass writes velocity where dye should
    // be — a field with no colour. A zero was reachable from ordinary
    // layout: width-first items sit at `width: 0` with a real height for a
    // frame (ratio 0; `_fit` divides by it → Infinity → NaN → `property int`
    // stores 0), and a 44×19 switch track inside a 1 px inset also passes
    // through width −2 (a negative aspect). 1 only while degenerate: the
    // moment both sides are real this is the ratio it always was, so no
    // laid-out surface (the 2304 px bar included) computes a different grid.
    readonly property real _asp: (width > 0 && height > 0)
                                 ? width / Math.max(height, 1)
                                 : 1
    readonly property real _splatRadius: impulseRadius * impulseRadius
    readonly property real _curl: 50.0 * curlAmp
    readonly property real _dyeMul: injectGain * intensity

    // swirl-live.html `_resize`'s fit(): the short side is fixed, the long side
    // follows the aspect, and the whole thing scales down under `cap`. dpr
    // cancels out of the aspect so logical pixels give the same answer.
    //
    // The guard on the way out is not redundant with the guard on `_asp`.
    // It makes "no ShaderEffect ever has a zero side" a property of the
    // function rather than of its caller, so a later lever on `shortSide`
    // or `cap` cannot reopen TRK-2937. `Math.max(8, NaN)` is NaN, and a
    // NaN in a `property int` is 0 — the value that costs the surface its
    // paint — so the finite test comes first and 8 is the floor for both.
    function _fit(shortSide, cap, wantW) {
        const a = (isFinite(_asp) && _asp > 0) ? _asp : 1;
        let rw, rh;
        if (a >= 1) { rh = shortSide; rw = shortSide * a; }
        else        { rw = shortSide; rh = shortSide / a; }
        const s = Math.min(1, cap / Math.max(rw, rh));
        const v = Math.round((wantW ? rw : rh) * s);
        return isFinite(v) ? Math.max(8, v) : 8;
    }
    readonly property int _simW: _fit(simShort, simCap, true)
    readonly property int _simH: _fit(simShort, simCap, false)
    readonly property int _dyeW: _fit(dyeShort, dyeCap, true)
    readonly property int _dyeH: _fit(dyeShort, dyeCap, false)
    readonly property vector4d _texel: Qt.vector4d(1 / _simW, 1 / _simH, 0, 0)

    // ── splat slots. 0 = pointer · 1–3 = ambient stirrers · 4–5 = intro ──
    // sA = x0,y0,x1,y1 · sB = n,radius,velX,velY · sC = dyeStrength,seed
    property vector4d sA0: Qt.vector4d(0, 0, 0, 0)
    property vector4d sA1: Qt.vector4d(0, 0, 0, 0)
    property vector4d sA2: Qt.vector4d(0, 0, 0, 0)
    property vector4d sA3: Qt.vector4d(0, 0, 0, 0)
    property vector4d sA4: Qt.vector4d(0, 0, 0, 0)
    property vector4d sA5: Qt.vector4d(0, 0, 0, 0)
    property vector4d sB0: Qt.vector4d(0, 0, 0, 0)
    property vector4d sB1: Qt.vector4d(0, 0, 0, 0)
    property vector4d sB2: Qt.vector4d(0, 0, 0, 0)
    property vector4d sB3: Qt.vector4d(0, 0, 0, 0)
    property vector4d sB4: Qt.vector4d(0, 0, 0, 0)
    property vector4d sB5: Qt.vector4d(0, 0, 0, 0)
    property vector4d sC0: Qt.vector4d(0, 0, 0, 0)
    property vector4d sC1: Qt.vector4d(0, 0, 0, 0)
    property vector4d sC2: Qt.vector4d(0, 0, 0, 0)
    property vector4d sC3: Qt.vector4d(0, 0, 0, 0)
    property vector4d sC4: Qt.vector4d(0, 0, 0, 0)
    property vector4d sC5: Qt.vector4d(0, 0, 0, 0)
    property vector4d dolA: Qt.vector4d(0, 0, 0, 0)
    property vector4d dolB: Qt.vector4d(0, 0, 0, 0)
    property vector4d pls: Qt.vector4d(0, 0, 0, 0)

    // ── wake policy ──────────────────────────────────────────────────
    // THE WINDOW GATE (WIP-245). `visible` on an ITEM does not follow the
    // WINDOW: when the Launcher sinks, its PanelWindow unmaps while every
    // item inside it stays `visible: true`. The FrameAnimation below is
    // driven by the global animation timer, not the window's render loop —
    // the old note here claiming "it stops with the window" was written
    // for a one-window app and is false in this shell — so with the 3.4 s
    // intro still live at close, the sim kept mutating uniforms and
    // marking items dirty in an unexposed window. That is
    // QQuickItemPrivate::addToDirtyList(), the exact WIP-230 segfault,
    // and it fired twice more (20:24, 20:26) from THIS component after
    // WIP-230 gated only the Launcher's reflections. Everything that
    // steps the sim derives from `running`, so the window's real
    // visibility gates it here, once, for every host of this component.
    // …and WIP-245's first cut still crashed ON OPEN (owner repro ×2,
    // 21:41–21:42, same addToDirtyList under a posted event): QWindow's
    // `visible` flips true at show(), a beat BEFORE the compositor has
    // mapped the layer surface — Wayland mapping needs a configure
    // round-trip — so gating on `visible` alone let the sim tick inside a
    // window whose scene graph was still being brought up. The gate is
    // now two-stage: window visible, THEN a settle delay before the sim
    // may run. 250 ms is invisible behind the menu's rise animation and
    // comfortably past the map/configure handshake.
    readonly property var _win: Window.window
    readonly property bool _winVisible: _win !== null && _win.visible
    property bool windowExposed: false
    on_WinVisibleChanged: {
        if (_winVisible) settle.restart();
        else { settle.stop(); windowExposed = false; }
    }
    Timer {
        id: settle
        interval: 250
        onTriggered: root.windowExposed = true
    }
    // ── never sleeps (WIP-265) ───────────────────────────────────────
    // Opt-in, default OFF, so every panel keeps the sleep behaviour that
    // WIP-14 measured at 0.1–0.2 % idle. Exactly one surface sets it.
    //
    // The bar needed it because of an interaction between two correct
    // decisions. Its Swirl is `interactive: false` — deliberately, because
    // the pointer zone is the whole 72 px chrome while the paint band is
    // the bottom 28 — and `_stimulus` is therefore PERMANENTLY false. That
    // leaves `linger.running` as the only term that can keep `running`
    // true, and the linger is a 12 s one-shot. So the horizon painted for
    // twelve seconds after load and then stopped for good, holding a frame
    // whose dye had already dissipated. That is the whole of "the swirls
    // aren't there": not the palette, not the ground, not the wallpaper.
    //
    // It is also why the report kept coming back after each "fix" — every
    // check, mine included, was a screenshot taken seconds after a hot
    // reload, which is inside `playIntroOnLoad`'s ignition. Measured at
    // rest (75 s, wallpaper off, black bar) the field was gone in every
    // configuration. Bar.qml's own note said the seam "has to be ALIVE
    // with no hand near it" and raised `ambientAmp` to buy it — but the
    // stirrers run off `_ambientStep`, which only ticks while the sim is
    // running, so there was nothing for them to hold up.
    property bool alwaysAlive: false

    readonly property bool _stimulus: (interactive && hover.hovered)
                                      || _introAt >= 0
                                      || musicActive
    on_StimulusChanged: _stimulus ? linger.stop() : linger.restart()
    // ── ON BATTERY, THE PAINT STOPS DRIFTING (WIP-339) ──────────────────────
    // Measured on the owner's machine, 2026-08-11 — the first real numbers this
    // project has had for the living paint, and PLAN-5 has been asking for them
    // since August:
    //
    //     Start menu closed   52.9% of one core     ← sustained, all the time
    //     Start menu open    123.5% of one core
    //
    // The ~70% the menu adds is transient: its Loader is destroyed on close and
    // the solver settles after `lingerMs` anyway. The ~53% floor is NOT — that
    // is the wallpaper and the bar seam, running whether or not anyone is
    // looking. Half a core, continuously, is a real bite out of an unplugged
    // afternoon.
    //
    // So: `alwaysAlive` is honoured on mains and IGNORED on battery. Touch it
    // and it still lights up — `_stimulus` and the 12 s linger are untouched on
    // either power source — but nothing drifts on its own while unplugged, and
    // the wallpaper (which has no hover to give it stimulus) simply comes to
    // rest. Costs nothing visually while plugged in, which is when the machine
    // is actually being looked at.
    //
    // `batterySaver: false` opts a tenant out. Do not reach for it lightly;
    // the point of this is that it is on by default.
    property bool batterySaver: true
    readonly property bool _saving: batterySaver
                                    && Sys.hasBattery && !Sys.batteryCharging

    // ── THE QUALITY LADDER (WIP-768) ────────────────────────────────────────
    // Measured on the owner's 3060 before any boundary was drawn, because a
    // boundary from a structural estimate is wrong in the way nobody notices
    // until weak hardware hits it. What the measurements changed:
    //
    //   · The SOLVER, not the display pass, is the cost. One step is 0.405 ms
    //     on the bar against 0.008 ms for its display pass, and it is per
    //     INSTANCE — this component is instantiated 8 times in this shell and
    //     8 concurrent solvers measured 3.16 ms/step, dead linear. The bar is
    //     the most expensive of them, because its extreme aspect drives the
    //     long edge of every buffer into simCap/dyeCap; it is also the one
    //     surface that sets `alwaysAlive`.
    //   · The dominant passes are the DYE-resolution ones — splat dye
    //     0.149 ms, mipmap 0.054 ms — not the 22-deep Jacobi chain, which is
    //     0.001 ms per link. So dye resolution degrades the material and the
    //     pressure solve does not.
    //   · Dropping vorticity confinement saves 9% and destroys the ramp
    //     travel. It is not a tier lever. See accent.json `_levers_rejected`.
    //
    // This EXTENDS the two gates above rather than replacing them: `_saving`
    // keeps its existing meaning and keeps switching `alwaysAlive` off, and
    // the ladder simply reads it as one more reason to step down. A tenant
    // that pins `qualityTier` opts out of the automatic choice only — the
    // battery rule for `alwaysAlive` is untouched either way.
    property string qualityTier: "auto"
    readonly property string _tier: {
        if (qualityTier !== "auto") return qualityTier;
        const order = Theme.swirlTierOrder;
        const base = order.indexOf(Theme.swirlTierDefault);
        if (base < 0) return "full";
        const step = _saving ? Theme.swirlTierBatteryStepDown : 0;
        return order[Math.max(0, Math.min(order.length - 1, base + step))];
    }
    readonly property var _tierCfg: Theme.swirlTiers[_tier] !== undefined
                                    ? Theme.swirlTiers[_tier]
                                    : Theme.swirlTiers[Theme.swirlTierDefault]

    // ── the floor: solve once, freeze, sample forever ───────────────────────
    // NOT a static gradient. A gradient loses the filaments and the lightness
    // ladder, and accent.json records four failed cloud-noise attempts before
    // ridged filaments worked — so a gradient is those failures with a nicer
    // palette. A frozen solve is the material with motion removed, which is
    // what COMPLETION_SPEC §3.6 and NYXUS_GLASS §1.9 require of reduced
    // motion: a still frame, not a paused animation mid-motion.
    //
    // It works by letting the intro play once and then never running again.
    // Everything that holds the picture afterwards already exists: the
    // buffers keep their last content when `live` goes false, and the display
    // layer settles to `restOpacity` instead of blinking out. So this costs
    // one added conjunct on `running` and no new machinery.
    readonly property bool _frozen: _tierCfg !== undefined && _tierCfg.freeze === true
    property bool _floorSpent: false
    on_IntroAtChanged: if (_frozen && _introAt < 0) _floorSpent = true

    readonly property bool running: visible && windowExposed
                                    && width > 8 && height > 8
                                    && !(_frozen && _floorSpent)
                                    && ((alwaysAlive && !_saving)
                                        || _stimulus || linger.running)

    Timer { id: linger; interval: root.lingerMs; repeat: false }

    // ── WIP-700 · the mapped-surface census PaintMood's timer hangs off ──
    // `running` is already this shell's honest "the solver is stepping in a
    // mapped, exposed window" predicate — it is what the WIP-245 segfault
    // taught this file to compute, and it is also false on battery
    // (`_saving`) and after the linger expires. PaintMood's 30 s load read
    // runs only while at least one Swirl is in that state, so an unmapped
    // shell reads nothing and a parked one costs nothing.
    //
    // Balanced by construction: `_moodHeld` makes attach/detach idempotent,
    // so a burst of `running` changes cannot inflate the count, and
    // `Component.onDestruction` releases the claim when a Loader tears a
    // panel down — which `onRunningChanged` alone would NOT do, because a
    // destroyed item's bindings do not fire on the way out.
    property bool _moodHeld: false
    function _moodSync(): void {
        const want = root.running;
        if (want === root._moodHeld) return;
        root._moodHeld = want;
        if (want) PaintMood.attach(); else PaintMood.detach();
    }
    onRunningChanged: root._moodSync()
    Component.onDestruction: {
        if (root._moodHeld) { root._moodHeld = false; PaintMood.detach(); }
    }

    // ── internal state ───────────────────────────────────────────────
    property real _introAt: -1          // seconds; -1 = not playing
    property real _lastPaint: -1e9
    property real _nextPulse: 0
    // One-shot splats (a click, an ambient dye pulse) are QUEUED here and
    // published by the frame clock, then retired one frame later. Publishing
    // them the moment they are requested double-draws them: a request that
    // arrives during onTriggered is already visible to that frame's render, and
    // a "clear it next frame" flag cannot tell that case apart from a request
    // that arrived between two frames.
    property var _dolPending: null
    property var _plsPending: null
    property bool _dolLive: false
    property bool _plsLive: false
    property real _pxCur: 0
    property real _pyCur: 0
    property bool _pHave: false
    property real _pxLast: 0
    property real _pyLast: 0
    property bool _pLast: false
    property var _stir: []
    property var _emitters: []
    property var _dollops: []
    // Frame budget for maxStepHz. `_stepNow` is what every layer's `live` reads:
    // on a skipped frame nothing in the chain re-renders and each buffer simply
    // holds the field from the last step.
    property real _acc: 0
    property bool _stepNow: false

    function ignite() {                 // replay the intro (launcher open, etc.)
        // On the floor tier each open earns ONE fresh solve and then freezes
        // again, so a surface that is opened twice does not come back holding
        // a field from a previous session.
        if (_frozen) _floorSpent = false;
        _introAt = time + introDelay;   // bar default 0.4; chips set 0
        _buildIntro();
        _pLast = false;
    }

    // Feed a stroke point in normalised (0..1) coordinates — for scripted
    // choreography and for test rigs that bypass compositor input.
    //
    // Feeding also WAKES the sim. The bar (HORIZON's Wake and Tell) drives the
    // paint from outside with `interactive: false`, because the reach of the
    // pointer response is the whole 72 px chrome zone while the paint itself
    // is only drawn in the bottom 28 — so the Swirl's own HoverHandler is the
    // wrong shape for it.
    function feedAt(nx, ny) {
        if (!_stimulus && !linger.running) linger.restart();
        _pxCur = nx; _pyCur = ny; _pHave = true;
    }

    // Drop a splat at a point, with no motion history — for EVENTS rather
    // than strokes (HORIZON's "Tell": an app launching, focus moving, a
    // notification arriving). This is swirl-live.html's `_dollop`, which the
    // reference fires on pointerdown.
    function dropAt(nx, ny, strength, dirX, dirY) {
        if (!_stimulus && !linger.running) linger.restart();
        const s = strength === undefined ? 0.9 : strength;
        _dolPending = { x: nx, y: ny, s: s, dx: dirX || 0, dy: dirY || 0 };
        _lastPaint = time;
    }

    Component.onCompleted: {
        _buildStirrers();
        if (playIntroOnLoad) ignite();
        if (_winVisible) settle.restart();   // WIP-249: arm the expose gate
        _moodSync();                         // WIP-700: claim only if running
    }

    // Re-enabling from Settings (or any hide→show) replays the intro, so
    // flipping the toggle answers immediately instead of staying dark until
    // the next hover or beat.
    onVisibleChanged: if (visible && playIntroOnLoad) ignite()

    // reference: WX/WY tables, random phases, three stirrers on the bar
    function _buildStirrers() {
        const WX = [0.110, 0.073, 0.051], WY = [0.083, 0.127, 0.061];
        const out = [];
        for (let i = 0; i < 3; i++)
            out.push({ wx: WX[i % 3], wy: WY[i % 3],
                       phi: Math.random() * 6.28, psi: Math.random() * 6.28,
                       env: Math.random() * 6.28, has: false, px: 0, py: 0 });
        _stir = out;
        _nextPulse = 1.6 + Math.random() * 2.4;
    }

    // reference `intro: 'bar'` — two crossing ribbons weaving the sweep, then a
    // fast lace pass — and `intro: 'loop'` for the small shapes.
    function _buildIntro() {
        const io = function (u) { return u < 0.5 ? 2 * u * u : 1 - Math.pow(-2 * u + 2, 2) / 2; };
        if (introMode === "loop") {
            const ph = Math.random() * 6.28;
            // 1.3 s of one weak emitter is the "starts slower and blurred"
            // chip. Three dollops on the first frames plus a short loop so
            // the field is filaments immediately, then the same rest look.
            _introT = 0.40;
            _emitters = [{ slot: 4, t0: 0, t1: 1, has: false, px: 0, py: 0,
                           f: function (e) { return { x: 0.5 + 0.30 * Math.cos(io(e) * 6.283 + ph),
                                                      y: 0.5 + 0.34 * Math.sin(io(e) * 6.283 + ph) }; } }];
            _dollops = [
                { t: 0.00, x: 0.32, y: 0.42, done: false },
                { t: 0.06, x: 0.64, y: 0.58, done: false },
                { t: 0.14, x: 0.48, y: 0.36, done: false }
            ];
        } else {
            _introT = 3.4;
            _emitters = [
                { slot: 4, t0: 0.00, t1: 0.55, has: false, px: 0, py: 0,
                  f: function (e) { return { x: 0.04 + 0.92 * io(e), y: 0.5 + 0.30 * Math.sin(e * 6.5) }; } },
                { slot: 5, t0: 0.06, t1: 0.62, has: false, px: 0, py: 0,
                  f: function (e) { return { x: 0.96 - 0.92 * io(e), y: 0.5 - 0.28 * Math.sin(e * 7.0 + 0.8) }; } },
                { slot: 4, t0: 0.58, t1: 1.00, has: false, px: 0, py: 0,
                  f: function (e) { return { x: 0.04 + 0.92 * e,
                                             y: 0.5 + 0.20 * Math.sin(e * 11.0) * (1.0 - 0.4 * e) }; } }
            ];
            _dollops = [ { t: 0.42, x: 0.22, y: 0.50, done: false },
                         { t: 0.62, x: 0.52, y: 0.45, done: false },
                         { t: 0.86, x: 0.78, y: 0.55, done: false } ];
        }
    }
    property real _introT: 3.4

    // ── slot plumbing ────────────────────────────────────────────────
    function _setSlot(i, A, B, C) {
        if (i === 0)      { sA0 = A; sB0 = B; sC0 = C; }
        else if (i === 1) { sA1 = A; sB1 = B; sC1 = C; }
        else if (i === 2) { sA2 = A; sB2 = B; sC2 = C; }
        else if (i === 3) { sA3 = A; sB3 = B; sC3 = C; }
        else if (i === 4) { sA4 = A; sB4 = B; sC4 = C; }
        else              { sA5 = A; sB5 = B; sC5 = C; }
    }
    readonly property vector4d _zero: Qt.vector4d(0, 0, 0, 0)
    function _clearSlot(i) { _setSlot(i, _zero, _zero, _zero); }

    // swirl-live.html `_stroke`, verbatim. The reference turns this into n
    // draw calls; shaders/swirl_splat.frag sums the same n gaussians in one
    // pass, which is the identical result because splats are additive.
    function _strokeSlot(slot, x0, y0, x1, y1, dx, dy, opt) {
        const strength = opt.strength !== undefined ? opt.strength : 1;
        const forceMul = opt.forceMul !== undefined ? opt.forceMul : 1;
        const dyeMul   = opt.dyeMul   !== undefined ? opt.dyeMul   : 1;
        const radius   = _splatRadius * (opt.radiusMul || 1);
        const A = _asp;

        const distH = Math.hypot((x1 - x0) * (A >= 1 ? A : 1),
                                 (y1 - y0) * (A < 1 ? 1 / A : 1));
        if (distH > 1.6) { _clearSlot(slot); return; }   // teleport guard
        const step = 0.42 * Math.sqrt(radius);
        const n = Math.max(1, Math.min(32, Math.ceil(distH / step)));

        let fx = dx, fy = dy;
        if (A < 1) fx *= A; else fy /= A;                // per-pixel-equal
        const vs = force * forceMul / Math.pow(n, 0.5);
        const ds = 0.75 * strength * dyeMul / Math.pow(n, 0.3);

        _setSlot(slot,
                 Qt.vector4d(x0, y0, x1, y1),
                 Qt.vector4d(n, radius, fx * vs, fy * vs),
                 Qt.vector4d(ds, Math.random() * 97.0, 0, 0));
        if (ds > 0.002) _lastPaint = time;
    }

    // ── the clock. One FrameAnimation, not a Timer: it hands us the real
    // frame delta. It does NOT stop with the window on its own — it runs
    // off the global animation timer, which is why `running` carries the
    // window gate above (WIP-245). Everything a frame splats is decided
    // here, so the uniforms the render then reads are exactly one frame's
    // worth of stimulus. ─────────────────────────────────────────────
    FrameAnimation {
        id: frames
        running: root.running
        onRunningChanged: if (!running) { root._acc = 0; root._stepNow = false; }
        onTriggered: {
            const ft = frameTime > 0 ? frameTime : 1 / 60;
            root._acc += ft;
            if (root.maxStepHz > 0) {
                // Step when the accumulator is within half a frame of the
                // budget, so 144 Hz alternates 2 and 3 frames per step (≈58 Hz)
                // instead of always waiting 3 (48 Hz).
                if (root._acc < 1 / root.maxStepHz - ft * 0.5) {
                    root._stepNow = false;
                    return;
                }
            }
            root._stepNow = true;
            // reference: dt = min(elapsed, 1/30)
            root.dt = Math.min(root._acc, 1 / 30);
            root._acc = 0;
            root.time += root.dt;

            // publish, then retire, the one-shot splats
            if (root._dolPending) {
                const d = root._dolPending;
                root.dolA = Qt.vector4d(d.x, d.y, d.s, Math.random() * 97.0);
                root.dolB = Qt.vector4d(root._splatRadius, d.dx, d.dy, root._dyeMul * d.s);
                root._dolPending = null;
                root._dolLive = true;
            } else if (root._dolLive) {
                root.dolA = root._zero;
                root._dolLive = false;
            }
            if (root._plsPending) {
                const p = root._plsPending;
                root.pls = Qt.vector4d(p.x, p.y, root._dyeMul, root._splatRadius);
                root._plsPending = null;
                root._plsLive = true;
            } else if (root._plsLive) {
                root.pls = root._zero;
                root._plsLive = false;
            }

            root._pointerStep();
            root._ambientStep();
            root._introStep();
        }
    }

    // ── pointer → strokes ────────────────────────────────────────────
    HoverHandler {
        id: hover
        enabled: root.interactive
        onPointChanged: {
            if (!hovered) return;
            root._pxCur = point.position.x / Math.max(root.width, 1);
            root._pyCur = point.position.y / Math.max(root.height, 1);
            root._pHave = true;
        }
        onHoveredChanged: if (!hovered) root._pLast = false
    }

    // The reference sampled its pointer once per event and splatted
    // immediately; Qt delivers points at device rate (100+ Hz) into a 60 Hz
    // render, so the motion since the last frame is integrated into one stroke.
    // Its dx/dy are the raw UV delta — NOT a velocity — because that is what
    // `_stroke` is handed in swirl-live.html's pointermove handler.
    function _pointerStep() {
        if (!_pHave) { _clearSlot(0); return; }
        if (!_pLast) { _pxLast = _pxCur; _pyLast = _pyCur; _pLast = true; _clearSlot(0); return; }
        const dx = _pxCur - _pxLast, dy = _pyCur - _pyLast;
        if (Math.abs(dx) + Math.abs(dy) > 0) {
            const speed = Math.hypot(dx * _asp, dy);
            _strokeSlot(0, _pxLast, _pyLast, _pxCur, _pyCur, dx, dy,
                        { strength: Math.min(1.3, 0.5 + speed * 5.0), dyeMul: _dyeMul,
                          forceMul: pointerForceMul });   // TRK-3474
        } else {
            _clearSlot(0);
        }
        _pxLast = _pxCur; _pyLast = _pyCur;
    }

    // swirl-live.html `_ambient`: invisible ghost pointers on slow Lissajous
    // paths, pure velocity so the paint keeps folding, plus a rare faint dye
    // pulse so it never fully dies. Music rides on top of the same stirrers.
    function _ambientStep() {
        // Motion mode gate (WIP-621): in interactive mode the field has no
        // life of its own — no stirrers, no replenishment pulse. The slots
        // are cleared so a mode flip mid-session cannot leave a stroke live.
        if (!_motionAmbient) {
            for (let i = 0; i < _stir.length; i++) _clearSlot(1 + i);
            return;
        }
        const ts = time;
        const damp = (ts - _lastPaint < 0.6) ? 0.35 : 1.0;   // pointer is the hero
        // TRK-3494 — the AC term is what the music moves; `audioDrive` scales
        // it and nothing else, so silence returns the field to its resting
        // behaviour exactly.
        const ac = 0.7 * audioBass + 0.5 * audioPulse + 0.9 * audioKick;
        const boost = 1.0 + ac * audioDrive;
        for (let i = 0; i < _stir.length; i++) {
            const s = _stir[i];
            const env = 0.3 + 0.7 * (0.5 + 0.5 * Math.sin(0.09 * ts + s.env));
            // TRK-3484 — (2/pi)*asin(sin(t)) is the triangle wave: same
            // period and range as the sine, constant speed instead of
            // dwelling at the turnarounds.
            const thx = s.wx * ts * 6.28 + s.phi;
            const sweepX = ambientEvenSweep
                ? (2 / Math.PI) * Math.asin(Math.sin(thx))
                : Math.sin(thx);
            const x = 0.5 + 0.46 * sweepX;
            const y = 0.5 + 0.32 * Math.sin(s.wy * ts * 6.28 + s.psi);
            if (s.has) {
                // ── AMBIENT MUST CARRY DYE (WIP-338) ────────────────────────
                // Owner, 2026-08-11: "the swirls aren't present either."
                //
                // This called _strokeSlot with `strength: 0, dyeMul: 0`, and
                // _strokeSlot computes its dye as
                //     ds = 0.75 * strength * dyeMul / n^0.3
                // so the ambient stirrers moved VELOCITY and added no colour at
                // all. The only dye in the resting field came from the single
                // random pulse every 2.2-5.8s, which then dissipated — so once
                // the intro faded there was nothing left to advect and the
                // paint went invisible. `ambientAmp` was buying motion in an
                // empty field.
                //
                // WIP-266 identified this and filed it unfixed. It is the same
                // fault behind the bar seam going empty 12s after login.
                //
                // The fix is a small CONTINUOUS replenishment, not a bright
                // one: enough that the field always has something to carry,
                // low enough that it never reads as a wash. It rides the
                // stirrer's own envelope, so it breathes with the motion that
                // is already there rather than adding a second rhythm, and it
                // scales with `intensity` through _dyeMul like every other
                // injector — turning the paint down still turns this down.
                // TRK-3493 — the injected velocity. `vx,vy` is the stroke's
                // own travel; rotating it 90 degrees (-dy, dx) shears instead
                // of drags, and the mix between them is a spiral. The current
                // is added afterwards so it biases every push the same way
                // rather than being rotated with them.
                const vx0 = x - s.px, vy0 = y - s.py;
                const vxr = -vy0, vyr = vx0;
                const vx = (vx0 * (1.0 - ambientVortex) + vxr * ambientVortex)
                         + ambientCurrentX;
                const vy = (vy0 * (1.0 - ambientVortex) + vyr * ambientVortex)
                         + ambientCurrentY;
                _strokeSlot(1 + i, s.px, s.py, x, y, vx, vy,
                            { strength: ambientDye * env,
                              dyeMul: _dyeMul,
                              radiusMul: 1.15,
                              // TRK-3495 — the spectrum term. Sampled at the
                              // stirrer's CURRENT x, so a stirrer crossing the
                              // bar is driven by each band in turn as it
                              // passes through that band's slice.
                              forceMul: ambientAmp * env * damp * boost
                                        * (1.0 + spectrumDrive * _bandAt(x)) });
            } else {
                _clearSlot(1 + i);
            }
            s.px = x; s.py = y; s.has = true;
        }
        // reference: nextPulse = now + 2200 + random*3600. Beats bring it forward.
        if (musicActive && audioPulse > 0.5 && ts > _nextPulse - 1.4) _nextPulse = ts;
        if (_stir.length > 0 && ts > _nextPulse) {
            _nextPulse = ts + 2.2 + Math.random() * 3.6;
            const s = _stir[Math.floor(Math.random() * _stir.length)];
            if (s.has) _plsPending = { x: s.px, y: s.py };
        }
    }

    // swirl-live.html `_intro`
    function _introStep() {
        if (_introAt < 0) { _clearSlot(4); _clearSlot(5); return; }
        const t = (time - _introAt) / _introT;
        if (t < 0) { _clearSlot(4); _clearSlot(5); return; }
        if (t >= 1) { _introAt = -1; _clearSlot(4); _clearSlot(5); return; }
        _clearSlot(4); _clearSlot(5);
        for (let i = 0; i < _emitters.length; i++) {
            const em = _emitters[i];
            if (t < em.t0 || t > em.t1) continue;
            const e = (t - em.t0) / (em.t1 - em.t0);
            const p = em.f(e);
            if (em.has)
                _strokeSlot(em.slot, em.px, em.py, p.x, p.y, p.x - em.px, p.y - em.py,
                            { strength: introStrength, radiusMul: 0.75, dyeMul: _dyeMul });
            em.px = p.x; em.py = p.y; em.has = true;
        }
        for (let j = 0; j < _dollops.length; j++) {
            const d = _dollops[j];
            if (!d.done && t >= d.t) { d.done = true; dropAt(d.x, d.y, introStrength); }
        }
    }

    // ═════════════════════════════════════════════════════════════════
    //  The pass chain. DECLARATION ORDER IS THE EXECUTION ORDER — Qt
    //  updates ShaderEffectSource layers during scene-graph preprocess,
    //  in child order, before the frame is drawn. Moving any block below
    //  changes the simulation.
    //
    //  Every layer is RGBA16F. That is load-bearing: velocity here reaches
    //  the thousands and pressure/divergence go negative, so an 8-bit
    //  target does not merely band, it destroys the field. Qt only offers
    //  RGBA16F/RGBA32F/RGBA8, so the reference's RG16F and R16F targets
    //  become RGBA16F with the extra channels unused.
    // ═════════════════════════════════════════════════════════════════

    // 1 ── splat into velocity (reads last frame's velocity)
    ShaderEffect {
        id: velSplat
        width: root._simW; height: root._simH
        blending: false
        fragmentShader: Qt.resolvedUrl("shaders/swirl_splat.frag.qsb")
        property variant uTarget: velBuf
        property real mode: 0
        property real aspect: root._asp
        property real time: root.time
        property vector4d sweep: Qt.vector4d(root.sweepLo, root.sweepHi, root.sweepGamma, 0)
        property color r0: root.ramp[0]
        property color r1: root.ramp[1]
        property color r2: root.ramp[2]
        property color r3: root.ramp[3]
        property color r4: root.ramp[4]
        property color r5: root.ramp[5]
        property color r6: root.ramp[6]
        property vector4d sA0: root.sA0
        property vector4d sA1: root.sA1
        property vector4d sA2: root.sA2
        property vector4d sA3: root.sA3
        property vector4d sA4: root.sA4
        property vector4d sA5: root.sA5
        property vector4d sB0: root.sB0
        property vector4d sB1: root.sB1
        property vector4d sB2: root.sB2
        property vector4d sB3: root.sB3
        property vector4d sB4: root.sB4
        property vector4d sB5: root.sB5
        property vector4d sC0: root.sC0
        property vector4d sC1: root.sC1
        property vector4d sC2: root.sC2
        property vector4d sC3: root.sC3
        property vector4d sC4: root.sC4
        property vector4d sC5: root.sC5
        property vector4d dolA: root.dolA
        property vector4d dolB: root.dolB
        property vector4d pls: root.pls
    }
    ShaderEffectSource {
        id: velSplatBuf
        sourceItem: velSplat; hideSource: true; live: frames.running && root._stepNow
        smooth: true; wrapMode: ShaderEffectSource.ClampToEdge
        textureSize: Qt.size(root._simW, root._simH)
        format: ShaderEffectSource.RGBA16F
    }

    // 2 ── curl
    ShaderEffect {
        id: curlFx
        width: root._simW; height: root._simH
        blending: false
        fragmentShader: Qt.resolvedUrl("shaders/swirl_curl.frag.qsb")
        property variant uVelocity: velSplatBuf
        property vector4d texel: root._texel
    }
    ShaderEffectSource {
        id: curlBuf
        sourceItem: curlFx; hideSource: true; live: frames.running && root._stepNow
        smooth: false; wrapMode: ShaderEffectSource.ClampToEdge
        textureSize: Qt.size(root._simW, root._simH)
        format: ShaderEffectSource.RGBA16F
    }

    // 3 ── vorticity confinement
    ShaderEffect {
        id: vortFx
        width: root._simW; height: root._simH
        blending: false
        fragmentShader: Qt.resolvedUrl("shaders/swirl_vorticity.frag.qsb")
        property variant uVelocity: velSplatBuf
        property variant uCurl: curlBuf
        property real curl: root._curl
        property real dt: root.dt
        property vector4d texel: root._texel
    }
    ShaderEffectSource {
        id: vortBuf
        sourceItem: vortFx; hideSource: true; live: frames.running && root._stepNow
        smooth: true; wrapMode: ShaderEffectSource.ClampToEdge
        textureSize: Qt.size(root._simW, root._simH)
        format: ShaderEffectSource.RGBA16F
    }

    // 4 ── divergence
    ShaderEffect {
        id: divFx
        width: root._simW; height: root._simH
        blending: false
        fragmentShader: Qt.resolvedUrl("shaders/swirl_divergence.frag.qsb")
        property variant uVelocity: vortBuf
        property vector4d texel: root._texel
    }
    ShaderEffectSource {
        id: divBuf
        sourceItem: divFx; hideSource: true; live: frames.running && root._stepNow
        smooth: false; wrapMode: ShaderEffectSource.ClampToEdge
        textureSize: Qt.size(root._simW, root._simH)
        format: ShaderEffectSource.RGBA16F
    }

    // 5 ── warm-start the pressure solve from 0.8 × last frame's answer.
    //      pTail is written at step 6 below, i.e. AFTER this reads it.
    ShaderEffect {
        id: pClearFx
        width: root._simW; height: root._simH
        blending: false
        fragmentShader: Qt.resolvedUrl("shaders/swirl_clear.frag.qsb")
        property variant uTexture: root._pTail ? root._pTail.out : divBuf
        property real value: root.pressureScale
    }
    ShaderEffectSource {
        id: pClearBuf
        sourceItem: pClearFx; hideSource: true; live: frames.running && root._stepNow
        smooth: false; wrapMode: ShaderEffectSource.ClampToEdge
        textureSize: Qt.size(root._simW, root._simH)
        format: ShaderEffectSource.RGBA16F
    }

    // 6 ── the Jacobi chain. 22 links, each one layer.
    Repeater {
        id: pChain
        model: root.pressureIterations
        delegate: Item {
            id: link
            required property int index
            readonly property ShaderEffectSource out: pBuf
            ShaderEffect {
                id: pFx
                width: root._simW; height: root._simH
                blending: false
                fragmentShader: Qt.resolvedUrl("shaders/swirl_pressure.frag.qsb")
                property variant uPressure: link.index === 0 ? pClearBuf
                                                             : pChain.itemAt(link.index - 1).out
                property variant uDivergence: divBuf
                property vector4d texel: root._texel
            }
            ShaderEffectSource {
                id: pBuf
                sourceItem: pFx; hideSource: true; live: frames.running && root._stepNow
                smooth: false; wrapMode: ShaderEffectSource.ClampToEdge
                textureSize: Qt.size(root._simW, root._simH)
                format: ShaderEffectSource.RGBA16F
            }
        }
    }
    readonly property var _pTail: pChain.count > 0 ? pChain.itemAt(pChain.count - 1) : null

    // 7 ── gradient subtract (the projection)
    ShaderEffect {
        id: gradFx
        width: root._simW; height: root._simH
        blending: false
        fragmentShader: Qt.resolvedUrl("shaders/swirl_gradient.frag.qsb")
        property variant uPressure: root._pTail ? root._pTail.out : pClearBuf
        property variant uVelocity: vortBuf
        property vector4d texel: root._texel
    }
    ShaderEffectSource {
        id: gradBuf
        sourceItem: gradFx; hideSource: true; live: frames.running && root._stepNow
        smooth: true; wrapMode: ShaderEffectSource.ClampToEdge
        textureSize: Qt.size(root._simW, root._simH)
        format: ShaderEffectSource.RGBA16F
    }

    // 8 ── advect velocity through itself. velBuf closes the loop back to 1.
    ShaderEffect {
        id: velAdvFx
        width: root._simW; height: root._simH
        blending: false
        fragmentShader: Qt.resolvedUrl("shaders/swirl_advect.frag.qsb")
        property variant uVelocity: gradBuf
        property variant uSource: gradBuf
        property real dt: root.dt
        property real dissipation: root.velocityDecay
        property vector4d texel: root._texel
    }
    ShaderEffectSource {
        id: velBuf
        sourceItem: velAdvFx; hideSource: true; live: frames.running && root._stepNow
        smooth: true; wrapMode: ShaderEffectSource.ClampToEdge
        textureSize: Qt.size(root._simW, root._simH)
        format: ShaderEffectSource.RGBA16F
    }

    // 9 ── splat into dye (reads last frame's dye)
    ShaderEffect {
        id: dyeSplat
        width: root._dyeW; height: root._dyeH
        blending: false
        fragmentShader: Qt.resolvedUrl("shaders/swirl_splat.frag.qsb")
        property variant uTarget: dyeBuf
        property real mode: 1
        property real aspect: root._asp
        property real time: root.time
        property vector4d sweep: Qt.vector4d(root.sweepLo, root.sweepHi, root.sweepGamma, 0)
        property color r0: root.ramp[0]
        property color r1: root.ramp[1]
        property color r2: root.ramp[2]
        property color r3: root.ramp[3]
        property color r4: root.ramp[4]
        property color r5: root.ramp[5]
        property color r6: root.ramp[6]
        property vector4d sA0: root.sA0
        property vector4d sA1: root.sA1
        property vector4d sA2: root.sA2
        property vector4d sA3: root.sA3
        property vector4d sA4: root.sA4
        property vector4d sA5: root.sA5
        property vector4d sB0: root.sB0
        property vector4d sB1: root.sB1
        property vector4d sB2: root.sB2
        property vector4d sB3: root.sB3
        property vector4d sB4: root.sB4
        property vector4d sB5: root.sB5
        property vector4d sC0: root.sC0
        property vector4d sC1: root.sC1
        property vector4d sC2: root.sC2
        property vector4d sC3: root.sC3
        property vector4d sC4: root.sC4
        property vector4d sC5: root.sC5
        property vector4d dolA: root.dolA
        property vector4d dolB: root.dolB
        property vector4d pls: root.pls
    }
    ShaderEffectSource {
        id: dyeSplatBuf
        sourceItem: dyeSplat; hideSource: true; live: frames.running && root._stepNow
        smooth: true; wrapMode: ShaderEffectSource.ClampToEdge
        textureSize: Qt.size(root._dyeW, root._dyeH)
        format: ShaderEffectSource.RGBA16F
    }

    // 10 ── advect dye through the new velocity. mipmap because the display
    //       pass bloom is three textureLod taps.
    ShaderEffect {
        id: dyeAdvFx
        width: root._dyeW; height: root._dyeH
        blending: false
        fragmentShader: Qt.resolvedUrl("shaders/swirl_advect.frag.qsb")
        property variant uVelocity: velBuf
        property variant uSource: dyeSplatBuf
        property real dt: root.dt
        property real dissipation: root.decayRate
        // ⚠ the VELOCITY texel, not the dye's — see shaders/swirl_advect.frag
        property vector4d texel: root._texel
    }
    ShaderEffectSource {
        id: dyeBuf
        sourceItem: dyeAdvFx; hideSource: true; live: frames.running && root._stepNow
        smooth: true; mipmap: true; wrapMode: ShaderEffectSource.ClampToEdge
        textureSize: Qt.size(root._dyeW, root._dyeH)
        format: ShaderEffectSource.RGBA16F
    }

    // 11 ── dye → light, masked to the panel radius
    ShaderEffect {
        id: view
        anchors.fill: parent

        // ── going to sleep is a FADE, not a cut ──────────────────────
        // This was `visible: root.running || linger.running`, a boolean, so
        // the instant the 12 s linger expired the whole field blinked out of
        // existence in one frame. The owner's words, watching it: "when it
        // stops it stops and disappears right away … I want it to feel real
        // when it's disappearing."
        //
        // The sim itself still stops dead at the same moment — `frames` is
        // driven off `root.running` and every buffer holds its last content
        // when it is not `live` — so this costs no solver passes at all. It
        // is the last computed frame dimming out over a second and a half.
        //
        // Asymmetric on purpose, the same rule as Theme's durations: waking
        // is information arriving and must be immediate, sleeping is the
        // system getting out of your way and should take its time.
        // ── …but it does NOT fade to nothing ─────────────────────────
        // This was `? 1 : 0`, and the owner's report was simply "the swirls
        // aren't there now when I try and test". They were not: 12 s after the
        // last stimulus the field went to zero opacity and the horizon was a
        // hairline over black. The most distinctive thing in the build was
        // invisible for all but a few seconds at a time, and only ever while
        // your hand was already on it.
        //
        // It now settles to `restOpacity` instead. This costs NOTHING: the
        // simulation still stops dead at the same instant — `frames` is
        // stopped and every layer's `live` is false — and the buffers hold
        // their last content, so what remains on screen is a static texture
        // the scene graph is already compositing. Zero solver passes, zero
        // scheduled frames, WIP-14's 0.1–0.2 % idle is unaffected, and the
        // seam is always alive to look at.
        //
        // ⚠ One line of agent B's file, changed on the owner's direct report.
        // Nothing about the solver, the tuning or the look is touched — this
        // is only what happens to the LAST FRAME once the sim has stopped.
        opacity: (root.running || linger.running) ? 1 : root.restOpacity
        visible: opacity > 0.004
        Behavior on opacity {
            // Disabled while the window is unmapped (WIP-245): a 1.5 s
            // NumberAnimation ticking opacity on an item in an unexposed
            // window is the same dirty-list walk the window gate exists
            // to stop — the fade is for eyes, and there are none.
            enabled: root.windowExposed
            NumberAnimation {
                duration: view.opacity < 0.5 ? 220 : 1500
                easing.type: Easing.InOutQuad
            }
        }

        fragmentShader: Qt.resolvedUrl("shaders/swirl_view.frag.qsb")

        property variant dye: dyeBuf
        property real time: root.time
        property real cornerRadius: root.cornerRadius
        property vector4d size: Qt.vector4d(root.width, root.height,
                                            1 / root._dyeW, 1 / root._dyeH)
        // ── WIP-700 · the scan swell ────────────────────────────────────
        // `look.y` is bloom. A finished Hemera scan lifts it by up to 40%
        // over ~2.2 s and lets it back down over ~4.8 s, once, and then the
        // animation is over — `PaintMood.pulse` returns to a hard 0 and this
        // expression is numerically the picture it was before.
        //
        // The DISPLAY pass and not the splat pass, deliberately. WIP-648's
        // law is that dye is injected per unit TIME, never per event, and a
        // scan finishing is an event; laying a dollop for it would be the
        // exact shape that flooded the collide playground. Bloom is a
        // property of how the dye already in the field is SHOWN, so a swell
        // costs no deposit, cannot accumulate, and is bounded by the field
        // that is there — a hundred scans in a row would look like one.
        //
        // Gated on `windowExposed` for the same reason its `audio` sibling
        // below is: an animating uniform marks this item dirty, and doing
        // that inside an unmapped window is the WIP-245 dirty-list walk.
        property real moodPulse: root.windowExposed ? PaintMood.pulse : 0
        property vector4d look: Qt.vector4d(root.exposure,
                                            root.bloom * (1 + view.moodPulse * 0.40),
                                            root.saturation, root.sheen)
        // ── the last ungated uniform on this pass (WIP-245 shape) ───
        // Its three siblings are already safe: `time` only ever advances
        // inside the gated FrameAnimation, and `look`/`size`/`cornerRadius`
        // are static. This one is not — every host wires it straight to
        // Beat (Spill.qml:103-106, Bar.qml), so it re-evaluated at cava's
        // frame rate and marked `view` dirty whether or not the window was
        // on screen. `view` is `visible: opacity > 0.004` and restOpacity
        // is 0.62, so it is a live, VISIBLE item inside an unmapped
        // window — the dirty-list walk this gate exists to stop.
        //
        // The reachable trigger is the Spill: its PanelWindow is
        // `visible: Prefs.swirlEnabled` and its Swirl is NOT behind a
        // Loader, so switching swirls off in Settings while music plays
        // left this binding churning in a window the compositor had
        // dropped. The four Loader-wrapped hosts were never exposed to
        // it — their item is destroyed, which is stronger than any gate.
        //
        // Gated on `windowExposed`, NOT on `running`: `running` also falls
        // when the 12 s linger expires, and the field is meant to keep
        // breathing on its last frame while the sim sleeps. So this
        // changes nothing whatsoever while the window is mapped —
        // including the bar's `alwaysAlive` seam, whose window never
        // unmaps by design and whose gate is armed once at startup.
        //
        // Zero is the resting value, not a stand-in: the shader reads
        // `bloomG = look.y * (1 + 0.45*audio.x + 0.60*audio.w)`, so an
        // all-zero vector is numerically the no-music picture.
        property vector4d audio: root.windowExposed
            ? Qt.vector4d(root.audioBass, root.audioMid,
                          root.audioHigh, root.audioPulse)
            : Qt.vector4d(0, 0, 0, 0)
        // reference: BASE = [0.014, 0.018, 0.048]
        property vector4d base: Qt.vector4d(0.014, 0.018, 0.048, root.opaque ? 1 : 0)
        // WIP-880 — x = 0 is the shipped paint and the shader's own default;
        // the compiled GLSL for that path is line-for-line what it was before
        // this uniform existed (`qsb --dump` diff, both 330 and 300 es).
        // Live with no restart: Prefs watches settings.json, this binding
        // re-evaluates, and a uniform change is one dirty frame.
        property vector4d shadow: Qt.vector4d(root._shadowGlow,
                                              root.shadowOcclusion,
                                              root.shadowNorm,
                                              root.shadowFlowLine)
        // x = 0 is the shipped hard edge. Static per host, so this costs
        // nothing per frame; it is not gated on `windowExposed` because it
        // never animates and so never marks `view` dirty (contrast `audio`
        // above, which does).
        property vector4d dissolve: Qt.vector4d(root._dissolveFrac, 0, 0, 0)
        // TRK-3476 — x = 0 is OFF and is the default on every surface, so
        // the compiled path for everybody who does not ask is what it was.
        // Static per host like `dissolve`, so it never marks `view` dirty.
        property vector4d liquid: Qt.vector4d(root.liquidStrength,
                                              root.liquidPooling,
                                              root.liquidCaustic,
                                              root.liquidThreshold)
        property variant bg: root.refractSource !== null ? root.refractSource
                                                        : dyeBuf
        property vector4d refractCfg: Qt.vector4d(root.refractAmount,
                                                  root.refractDispersion,
                                                  root.refractVScale, 0)
        property vector4d contourTint: Qt.vector4d(root.contourColor.r,
                                                   root.contourColor.g,
                                                   root.contourColor.b,
                                                   root.contourTintAmount)
        property vector4d liquidPool: Qt.vector4d(root.liquidPoolColor.r,
                                                  root.liquidPoolColor.g,
                                                  root.liquidPoolColor.b, 0)
        property vector4d filament: Qt.vector4d(root.shadowFilament,
                                                root.shadowFilamentT,
                                                root.shadowFilamentW,
                                                root.shadowHaloFloor)
    }
}
