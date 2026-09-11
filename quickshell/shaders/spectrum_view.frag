#version 440
// Nyxus Suxyn — THE ANALYSER, drawn in one pass.        TRK-3718
//
// ── WHY A SHADER, WITH THE ARITHMETIC ────────────────────────────────────
// The references are a DENSE FIELD of thin columns — hundreds of 2–3 px
// lines across the full 1920 px bar — and the verdict on the delegate build
// was "to stiff" three times. BarSpectrum's own measured cost fit for
// Rectangle delegates is 5.8 + 0.254 × bars percentage points of a core at
// 46.88 fps: 64 delegates ≈ 22 pp (1.06× the living paint), and the 384
// columns the engine now sends extrapolate past a FULL CORE on the CPU.
// The same field drawn here costs the GPU one 1920×84 fill — the delegate
// build's own fill-rate test measured under one point for a 2× fill change,
// so the raster is effectively free — and the CPU exactly one 384×1
// texture upload per engine frame.
//
// The geometry lives here: display columns are cut in the fragment stage
// out of ONE quad, and the spectrum arrives as a texture whose LINEAR
// FILTER does band→column interpolation for nothing. The cava fallback's
// 12 bands land in the same texture and interpolate the same way, which
// closes TRK-3716 for good: twelve 160 px blocks cannot exist when the
// display never quantises to the feed.
//
// ── THE MOTION (owner: "i want that thing going crazy to the beat") ─────
//   · every column carries its own phase-jittered wobble, scaled by ITS
//     OWN level — silence is genuinely still (wobble is × level and the
//     whole field is × live), loud is alive everywhere;
//   · the KICK — Beat.kick, struck by the engine's PLL on the PREDICTED
//     beat — surges the field, each column by a different amount, so a hit
//     reads as the crowd jumping, not the floor rising;
//   · the DOWNBEAT launches a ripple that travels outward from centre and
//     dies in about a bar — the bar has a shape, not four identical hits;
//   · past each column's tip the light continues as an exponential halo,
//     so peaks BLOOM instead of ending at a pixel row.
//
// ── THE SHAPE: MIRRORED ABOUT THE CENTRE SPINE ──────────────────────────
// Rounds 1 and 2 both grew from the bottom and both were rejected. The
// references' strongest common shape is the waveform: columns growing BOTH
// WAYS off a centre spine ("the whole bar shooting up and down"). Twice
// the apparent motion for the same data, and the 84 px zone reads as full
// without any column parked against an edge.
//
// ── ROUND 4 · THE SEGMENTED METER AND THE FREQUENCY RAMP ── TRK-3778 ────
// Owner, 2026-09-06, five reference images plus: "this is how i want the
// visulizer to be with out the swirls behond it its suppose to flip over to
// this when music plays then backnormal when no music playing", and on how
// to read the images: "i was sending those ... just to give you a visual of
// what i was thinking ... just to go off". DIRECTION, not specification.
//
// Three things changed here and each is argued at its own site below:
//   1. THE CELL. The envelope is cut into LED segments (Theme.spectrumCellPx
//      / spectrumCellInk). Of the five references this is the only form that
//      spends no height on furniture, which is the whole constraint at 84 px.
//   2. THE RAMP. Body hue comes from the column's own place on the frequency
//      axis (Theme.spectrumRamp). Two arcs of his palette and one hard step,
//      so no column can land in the rejected periwinkle interval — measured,
//      not asserted (scripts/measure-spectrum-ramp.py).
//   3. THE REFLECTION. The lower half is dimmed and faded from the seam, and
//      the seam itself carries a floor glow, so the mirror reads as light on
//      a floor rather than as a second meter pointing down.
//
// ── WHAT SURVIVES OF TRK-3717'S RULING, AND WHAT DOES NOT ───────────────
// "the one that worked can you make it that pal color and do the tips magna"
// (2026-09-02). SUPERSEDED at the body: one pale glacier field cannot carry
// a spectrum spread, and every new reference has one. KEPT at the tip, in
// its role rather than its geometry: `cTip` is still magma[5] and it is now
// the PEAK-HOLD MARKER — the single cell that says this band just reached.
// The approved pale glacier is still what the top of the ramp is made of.
// The resting state is FLAT ("graph have to start flat"): a quiet column
// collapses into the spine, never a stub. This file never names a colour.
//
// ── THE RIBBONS · BUILT, SHIPPED, AND REJECTED ─ REJECTION 4 ────────
//                                              TRK-3741, removed TRK-3809
// A stack of five flowing neon curves used to be composited UNDER the field
// here, off references 8 and 9. The argument was good and it is kept because
// the argument is still true: a field of vertical columns cannot answer
// "flow waves ups and downs there to stiff", because a column has no
// horizontal dimension to flow along. The ribbons were the horizontal
// dimension.
//
// The owner saw them running, 2026-09-06:
//
//   "also the music visulizer there like lines riuning through the
//    bootom/middle of it and the record get rid of"
//
// ⚠ THE MEASUREMENT THAT MISSED THEM, AND WHY ──────────────────────
// TRK-3778's proof measured this face by COLUMN MINIMUM and reported a
// p10–p90 spread of 0.00 across all 1920 columns, concluding "a wash cannot
// be flat". That was wrong twice over and both mistakes are worth keeping:
//
//   1. It was taken with the field SILENT. Every ribbon term is × live.
//   2. A column-minimum metric is BLIND TO HORIZONTAL STRUCTURE BY
//      CONSTRUCTION — collapsing each column to one number turns a
//      full-width band into a uniform offset. The one shape it cannot see
//      is the one that was there.
//
// scripts/measure-bar-rows.py measures along ROWS instead, and is the
// companion metric this file now has.
//
// ⚠ AND WHAT THE STREAKS ACTUALLY WERE, WHICH IS NOT WHAT IT LOOKS LIKE ─
// The ribbons did not read as five lines. Their CORE is a thin filament,
// but each one also carried `bloom = exp(-dpx / (wpx * 3.2))` — an
// exponential with NO CUTOFF, decay constant 4.5–9.6 px — and the five of
// them rest spread across ±0.36 of the item height. Five unbounded
// exponentials 12 px apart do not sum to five lines; they sum to a
// CONTINUOUS WASH over the whole zone. On top of that each ribbon's alpha
// had a hard floor, `(0.45 + 0.55*dk) * (0.35 + 0.65*env)`, which is never
// below 0.157 while anything is playing — so the wash could not go away on
// a quiet passage either. And because the lines UNDULATE in y across x, no
// single scanline carries one everywhere, which is why even the row-floor
// metric sees a smooth hump rather than lines.
//
// Measured on his live bar, 2026-09-06, with the same track playing:
// scanlines lifted above 2× the bar's own edge floor, 56 of 84 with the
// ribbons on, 29 of 84 with the ceiling alone set to zero. Two thirds of
// the bar's height was a soft glow that belonged to nothing.
//
// The lesson, not the code, is what is worth keeping: A SOFT FALLOFF WITH
// NO CUTOFF IS A FULL-SURFACE ELEMENT. Every term in this shader that
// decays exponentially is one of these, and the only reason the spine's
// `floorGlow` is not the same defect is that it is now clamped (see below).
//
// Rebuild with shell/shaders/build.sh.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 size;    // x,y = item px · z = time s · w = live fade 0..1
    vec4 music;   // x = kick · y = pulse · z = downbeat ripple age s · w = energy
    vec4 cfg;     // x = display columns · y = centre y frac · z = gap frac · w = halo drive
    vec4 tipCfg;  // x = tip frac · y = tip jitter · z = tip min px · w = wobble drive
    vec4 cBodyA;  // Theme.spectrumBody[0] — pale glacier, the halo's cool end
    vec4 cBodyB;  // Theme.spectrumBody[1] — near-white glacier, the hot cap
    vec4 cTip;    // Theme.spectrumTip    — magma[5]: THE PEAK MARKERS
    vec4 cSpine;  // glacier[4] — hairline only, NEVER a fill; this is a hairline
    vec4 segCfg;  // x = LED pitch px · y = ink frac of pitch · z = reflect gain · w = peak decay guard
    // THE FREQUENCY RAMP · Theme.spectrumRamp, ten stops, positions below.
    // Ten uniforms and not a lookup texture ON PURPOSE: a 1-D ramp texture
    // is LINEARLY FILTERED, and a filtered texel straddling the hard step
    // is exactly the one periwinkle column the whole design exists to
    // avoid. Uniforms + clamped mixes reproduce the ramp EXACTLY, which is
    // what makes scripts/measure-spectrum-ramp.py a real check on what the
    // GPU draws rather than a check on a parallel model of it.
    vec4 cR0; vec4 cR1; vec4 cR2; vec4 cR3; vec4 cR4;
    vec4 cR5; vec4 cR6; vec4 cR7; vec4 cR8; vec4 cR9;
    vec4 rU0;     // stop positions 0..3
    vec4 rU1;     // stop positions 4..7
    vec4 rU2;     // x,y = stop positions 8,9 · z,w spare
};
layout(binding = 1) uniform sampler2D spec;

float hash1(float n) { return fract(sin(n * 127.1) * 43758.5453); }

// The ramp, as a chain of CLAMPED mixes. Each term is fully 0 below its own
// segment and fully 1 above it, so the chain is exactly piecewise-linear
// between the stops — not an eased approximation of it. `s0` is the width
// guard: a zero-width segment (the hard step is 0.0002 wide) must not
// divide by zero, and must not be widened to avoid doing so.
float _seg(float u, float a, float b) {
    return clamp((u - a) / max(b - a, 1e-6), 0.0, 1.0);
}
vec3 rampAt(float u) {
    vec3 c = cR0.rgb;
    c = mix(c, cR1.rgb, _seg(u, rU0.x, rU0.y));
    c = mix(c, cR2.rgb, _seg(u, rU0.y, rU0.z));
    c = mix(c, cR3.rgb, _seg(u, rU0.z, rU0.w));
    c = mix(c, cR4.rgb, _seg(u, rU0.w, rU1.x));
    c = mix(c, cR5.rgb, _seg(u, rU1.x, rU1.y));
    c = mix(c, cR6.rgb, _seg(u, rU1.y, rU1.z));
    c = mix(c, cR7.rgb, _seg(u, rU1.z, rU1.w));
    c = mix(c, cR8.rgb, _seg(u, rU1.w, rU2.x));
    c = mix(c, cR9.rgb, _seg(u, rU2.x, rU2.y));
    return c;
}

// The level shaping, lifted out of main() because the PEAK-HOLD row has to
// travel through exactly the same curve as the level or the marker would
// sit at a height the column can never reach. Floor first (the bottom 0.14
// of the range is texture, not music), then the measured smoothstep, then
// the gamma that spends the mirror's doubled height on RANGE.
float shape(float v) {
    v = max(0.0, v - 0.14) / 0.86;
    v = v * v * (3.0 - 2.0 * v);
    return pow(v, 1.85);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float t    = size.z;
    float kick = music.x;
    float live = size.w;

    float NC  = max(cfg.x, 8.0);
    float col = floor(uv.x * NC);
    float cc  = (col + 0.5) / NC;

    // The level: one texel fetch; the filter interpolates bands → columns.
    // ROW 0 of a 2-row texture is the level, ROW 1 is the CPU-decayed peak
    // hold. Texel centres of a 2-row texture are v = 0.25 and v = 0.75, so
    // sampling exactly there returns each row unmixed under linear
    // filtering — which is why the peak row does not bleed into the level.
    float lv = texture(spec, vec2(cc, 0.25)).r;
    float pk = texture(spec, vec2(cc, 0.75)).r;
    // Smoothstep shaping — the measured winner (+29.4% frame travel,
    // +39.3% neighbour contrast against identity, for +2.8% height) —
    // then a gamma ON TOP. The smoothstep measurement was made on a
    // bottom-anchored 64 px field; MIRRORING doubles every pixel of
    // height, and the first capture came back a white wall — every column
    // near full reach. The gamma spends that doubling on RANGE. 1.45
    // shipped first; the owner's verdict on it live ("what i wanted was …
    // them peaking out … match my theme black") moved it to 1.85: the
    // mids sit low in the black and only the real hits stand up, which is
    // what makes a peak a PEAK instead of a taller neighbour.
    // A floor comes off FIRST (TRK-3722): the bottom 0.14 of the range is
    // texture, not music, and drawing it is what filled the bar wall to
    // wall. Below the floor a column is simply black bar — the peaks then
    // stand in whatever area of the spectrum the track is actually
    // working, which is the owner's "in different areas, peaking out".
    lv = shape(lv);
    pk = shape(pk);

    float h = hash1(col);

    // The surge: PLL-struck. TRK-3722 calmed the per-column spread
    // (0.34 → 0.14): the owner asked for cleaner and smoother, and the
    // wide spread read as chaos — the field still jumps on the beat, it
    // just jumps as a field.
    lv *= 1.0 + kick * (0.16 + 0.14 * h);

    // The wobble: × level and × live, so stillness stays a property of the
    // data, never a code path (round 2's structural rule, kept).
    lv += tipCfg.w * (1.0 + 1.4 * kick) * lv
          * sin(t * (2.6 + 4.4 * h) + h * 39.0);

    // The downbeat ripple, outward from centre, dead in ~a bar. Halved
    // with the rest of the chaos terms (TRK-3722) — an accent, not a wave
    // machine.
    float d = abs(uv.x - 0.5);
    lv += 0.06 * exp(-music.z * 4.0) * cos(d * 30.0 - music.z * 22.0)
          * (0.35 + 0.65 * lv);

    lv = clamp(lv, 0.0, 1.0) * live;
    pk = clamp(max(pk, lv), 0.0, 1.0) * live;

    // ── geometry · a SEGMENTED LED METER, mirrored off the centre spine ─
    //                                                          TRK-3778
    // NO resting floor: a quiet column collapses to the spine ("graph have
    // to start flat" — the 2 px stub row was overruled live, 2026-09-02).
    //
    // ⚠ THE CELL IS WHY THIS FORM WAS CHOSEN AND IT IS AN ARGUMENT ABOUT
    // HEIGHT, NOT TASTE. Of the five references the owner sent, three spend
    // vertical room this surface does not have: the 31-band plinth needs a
    // legible Hz label row (~11 px) plus a perspective slab (~20 px) out of
    // 84, leaving bars 62 px WIDE at 31 bands across 1920 — the exact "way
    // to big" of round 1; the dot matrix needs ≥8 rows of dots plus its own
    // floor, which lands at ~3 px dots inside a plate that FlipPlate is
    // ALREADY applying a perspective matrix to. The segmented meter spends
    // NO height on furniture: it is the same envelope, cut into cells.
    //
    // A cell is lit or not lit — its CENTRE against the envelope, never a
    // partial fill — because a half-lit cell is what makes an LED meter
    // look like a bar chart with lines drawn on it. That crispness is also
    // what the reference's glow is FOR: the bloom below is the soft part.
    float cy = cfg.y;
    float dy = abs(uv.y - cy) / max(cy, 1.0 - cy);   // 0 spine → 1 edge
    float bh = 0.92 * lv;                             // envelope half-height
    float bp = 0.92 * pk;                             // peak-hold half-height

    float fx  = fract(uv.x * NC);
    float g0  = cfg.z;
    float body = smoothstep(g0, g0 + 0.12, fx)
               * smoothstep(g0, g0 + 0.12, 1.0 - fx);

    // Everything cell-related is in PIXELS, so the cell keeps its physical
    // size if the bar height ever moves. `denom` converts the normalised
    // `dy`/`bh` axis back to pixels and is the only bridge between them.
    float denom  = max(cy, 1.0 - cy) * size.y;
    float dyPx   = dy * denom;
    float bhPx   = bh * denom;
    float bpPx   = bp * denom;
    float pitch  = max(segCfg.x, 2.0);
    float cellI  = floor(dyPx / pitch);
    float cellC  = (cellI + 0.5) * pitch;             // this cell's centre px
    float cf     = fract(dyPx / pitch);
    float ink    = clamp(segCfg.y, 0.2, 1.0);
    // The dark seam between cells. Soft by ~0.09 of a pitch (≈0.5 px at 6),
    // which is antialiasing, not a gradient.
    float segK   = smoothstep(-0.02, 0.09, cf)
                 * (1.0 - smoothstep(ink - 0.09, ink, cf));
    // Lit iff the cell centre is inside the envelope. Half-pixel soft edge.
    float inBar  = 1.0 - smoothstep(bhPx - 0.5, bhPx + 0.5, cellC);

    // The REFLECTION. Below the spine the same field is dimmer and fades
    // with distance from the seam — references 18, 19 and 20 all show the
    // lower half as a reflection off a floor rather than as a second meter,
    // and it is what stops the mirrored shape reading as a graph.
    float below  = step(cy, uv.y);
    float refl   = mix(1.0,
                       segCfg.z * (1.0 - 0.45 * clamp(dy, 0.0, 1.0)),
                       below);

    // ── colour · THE FREQUENCY RAMP, plus a hot cap and a magma peak ────
    //                                                          TRK-3778
    // The body's hue now comes from WHERE the column sits on the frequency
    // axis, off Theme.spectrumRamp — ten palette stops, two arcs and one
    // deliberate hard step so nothing lands in periwinkle. See the token's
    // own block in Theme.qml for the measurement that fixes the stops.
    //
    // ⚠ THIS SUPERSEDES THE 2026-09-02 "pal color / tips magna" RULING AT
    // THE BODY AND KEEPS IT AT THE TIP, and both halves of that are
    // deliberate. Superseded: the field was ONE pale glacier and every one
    // of the owner's five new references spreads colour across frequency.
    // Kept: `cTip` is still magma[5] and it still marks what MATTERS — it
    // is now the PEAK-HOLD marker, the one thing on this surface that says
    // "this band just did something". A per-column ember tip could not
    // survive the ramp (it would drop orange into the cyan end and read as
    // a fault), but the ROLE survives intact, which is the part of the
    // ruling that was ever load-bearing.
    vec3 bodyCol = rampAt(cc);

    // THE HOT CAP: the topmost lit cell of a column burns toward white.
    // This is the old tip's job — "the reach of the hit" — done as HEAT
    // rather than as hue, so it works identically at both ends of the ramp
    // (a mix toward white is a tint, never a cross-wheel mix; rule 8 is
    // about hue and this changes none). Jittered per column off the same
    // hash as before, so no two neighbours cap identically.
    float capCell = floor(max(bhPx, 0.0) / pitch);
    float isCap   = step(abs(cellI - capCell), 0.5) * step(0.004, bh);
    float capJ    = 0.42 + tipCfg.y * 0.35 * h;
    vec3 colr = mix(bodyCol, mix(bodyCol, cBodyB.rgb, capJ), isCap);

    // THE PEAK MARKER: one cell, magma, floating at the level this band
    // reached and falling back on the CPU's decay. Drawn only ABOVE the
    // current cap — a marker sitting on the column is a marker saying
    // nothing. Reference 18's magenta caps over cyan bars are this idiom;
    // here it is the build's own accent doing it, which also keeps magma
    // on a surface the ramp would otherwise have taken it off entirely.
    float pkCell = floor(max(bpPx, 0.0) / pitch);
    float isPk   = step(abs(cellI - pkCell), 0.5)
                 * step(capCell + 0.5, pkCell)
                 * step(0.004, bp);
    colr = mix(colr, mix(cTip.rgb, vec3(1.0), 0.22), isPk);

    // Presence is EARNED by level ("them peaking out"), the cell seam cuts
    // the segments, and the reflection dims the lower half. The resting
    // floor is 0.30 rather than 0.22 because this face now has its own
    // OPAQUE ground under it (BarSpectrum § THE GROUND) instead of the
    // wallpaper — there is nothing left to lose a dim column into.
    float a = body * segK * max(inBar, isPk) * (0.30 + 0.70 * lv) * refl;

    // ── the halo · light continuing past the tip ───────────────────────
    // Tight (-20) and mostly glacier — the warm halo follows only the
    // ember columns. At -9 it filled the gaps and read as an orange wash,
    // the exact defect TRK-3478 spent a night removing from this bar.
    float over = max(0.0, dy - bh);
    float halo = exp(-over * 20.0) * lv * cfg.w * (1.0 + 2.2 * kick)
               * (0.55 + 0.45 * body) * step(0.004, bh) * refl;
    // The halo is the COLUMN'S OWN colour lifted toward the pale, so the
    // bloom belongs to the band that made it. It deliberately ignores the
    // cell seam: the segments are the instrument, the glow is the light
    // coming off it, and light does not have gaps in it.
    vec3 haloCol = mix(bodyCol, cBodyB.rgb, 0.45);
    colr = colr * a + haloCol * halo;
    a += halo;

    // ── the spine · the flat line the field rests on ────────────────────
    // glacier[4] in its one legal role, breathing faintly with the pulse.
    // The FLOOR the reflection comes off. References 18 and 20 both put
    // their brightest light exactly on the seam — that is the line the
    // lower half is reflecting in, and without it the mirror reads as a
    // second meter pointing down. Two terms: the 1 px hairline itself, and
    // a wide soft glow that carries the loud end of the field.
    float spinePx = abs(uv.y - cy) * size.y;

    // ══ THE AXIS GATE · TRK-3816 ═══════════════════════════════════════
    // Owner, 2026-09-07, unprompted: "there like a line that goes from one
    // side all the way to the other side directly in the middle of it what
    // is that". ⚠ HE ASKED WHAT IT WAS, WHICH IS THE TELL — a structural
    // element a user has to ask about is reading as an artefact, not as
    // design.
    //
    // It was the spine, and it was drawn EXACTLY as written: every term
    // above depends on `spinePx`, `music.y` and `live`, and NOT ONE OF THEM
    // DEPENDS ON THE COLUMN'S OWN LEVEL. So it painted at full strength
    // across all 1920 columns whether or not a column had any signal, and
    // the single pixels joined into an unbroken rule. Measured on his live
    // bar with music playing, before this gate: the lit fraction at the
    // spine row was 0.986 and the longest unbroken run 1691 px, 0.881 of
    // the width — and IDENTICAL ON ALL SIX FRAMES, which is the proof that
    // it was not tracking the music at all (scripts/measure-spine.py).
    //
    // ⚠ AND IT IS NOT THE TRK-3809 WASH COMING BACK. That was the ribbons'
    // unbounded bloom summing across ±0.36 of the height, and it is gone.
    // This is a single hard 1 px line at one y from an unrelated cause.
    //
    // ══ WHY GATING IT COMPLETES "no floor, no stubs" RATHER THAN BREAKING IT
    // The file header says a quiet column "collapses into the 1 px spine",
    // and that ruling was about not drawing STUBS standing above the axis.
    // But a 1 px line under every silent column IS a floor — a floor lying
    // down instead of standing up, drawn the full width of the bar. Letting
    // a silent column reach actual zero is the same ruling carried to its
    // end, not a reversal of it.
    //
    // What the spine is FOR survives intact: it is the floor the reflection
    // comes off, the thing that stops the mirrored lower half reading as a
    // second meter pointing down. That job only exists where there is a
    // field to mirror. Where there is nothing to mirror there is no axis to
    // draw.
    //
    // ⚠ THE NEIGHBOUR TAPS ARE WHAT STOP IT BECOMING A DASHED LINE, and a
    // dashed rule would be worse than a solid one — it would read as a
    // fault rather than as an artefact. Gating strictly per column would
    // break the spine wherever one quiet band sat between two loud ones. So
    // the gate reads the PEAK-HOLD row (which the CPU already decays over
    // ~0.9 s, giving temporal smoothing for free and no new state) at this
    // column and at ±2.5 columns, and takes the max: single-column gaps are
    // bridged, and only genuinely dead stretches of the spectrum go dark.
    // Two extra texture fetches, on a surface whose fill-rate test moved
    // under one point for a 2x change.
    float pkL = texture(spec, vec2(clamp(cc - 1.5 / NC, 0.0, 1.0), 0.75)).r;
    float pkR = texture(spec, vec2(clamp(cc + 1.5 / NC, 0.0, 1.0), 0.75)).r;
    // ⚠ THE FIRST CUT OF THIS GATE DID NOTHING, AND THE NUMBER IS WHY IT IS
    // WRITTEN DOWN. It read the peak-hold row alone through
    // `smoothstep(0.0, 0.04, …)`, on the reasoning that the axis should be
    // present wherever a band is doing ANYTHING. But the peak row is CPU-
    // decayed over ~0.9 s, so on a dense track essentially every band clears
    // 0.04 at some point inside that window: the gate evaluated to ~1
    // everywhere and the rule stayed. Measured on his live bar before and
    // after, lit fraction at the spine row 0.913 → 0.913, median excess over
    // the ground 69.0 → 70.2. A gate that runs and changes nothing.
    //
    // So it leans on the INSTANTANEOUS level and uses the peak only as a
    // smoother, at 55%, to stop a column blinking between frames. The knee
    // is a real threshold rather than a floor-guard: a band must be audibly
    // doing something to earn an axis under it.
    float axisRaw = max(lv, 0.55 * max(pk, shape(max(pkL, pkR)) * live));
    float axis = smoothstep(0.03, 0.28, axisRaw);

    float spine = (1.0 - smoothstep(0.5, 1.6, spinePx))
                * (0.34 + 0.30 * music.y) * live * axis;
    // ⚠ THE GLOW IS CUT OFF, AND THAT IS THE POINT ───────── TRK-3809
    // This was `exp(-spinePx / 7.0)` and nothing else: an exponential with
    // no cutoff, which is the same shape as the ribbon bloom removed above
    // and therefore the same class of defect — a soft falloff with no end
    // is a FULL-SURFACE element, however faint any one row of it is. It
    // lifted the whole middle of the face rather than lighting the spine.
    // Now: a tighter decay (4.5 px, so the visible glow is half as tall)
    // multiplied by a smoothstep that reaches EXACTLY zero at 14 px. Past
    // 14 px of the spine this term contributes literally nothing, which is
    // a property that can be asserted rather than a number that is small.
    float floorGlow = exp(-spinePx / 4.5)
                    * (1.0 - smoothstep(9.0, 14.0, spinePx))
                    * (0.10 + 0.26 * music.w)
                    * (0.5 + 0.5 * kick) * live * axis;   // TRK-3816
    colr += cSpine.rgb * spine + mix(bodyCol, cBodyB.rgb, 0.3) * floorGlow;
    a += spine + floorGlow;

    a = clamp(a, 0.0, 1.0);
    fragColor = vec4(colr, a) * qt_Opacity;
}
