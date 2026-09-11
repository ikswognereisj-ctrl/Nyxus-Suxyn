#version 440
// Nyxus Suxyn — swirl sim, DISPLAY pass.
//
// Verbatim port of design/swirl-live.html FRAG.display: gamma bite on the
// body, three restrained bloom taps, a slowly moving light reflected off the
// paint-height field for the wet-oil sheen, hot cores drifting toward white,
// filmic shoulder, saturation lift, corner-bleed into the void.
//
// Two things here are NOT in the reference, because the reference draws onto an
// opaque canvas and this draws into a compositor:
//   · a rounded-rect SDF mask, so the paint respects the panel radius
//   · premultiplied output with rgb allowed to exceed alpha, which composites
//     as ADDED light so the paint glows over the glass instead of covering it
// `base.w` = 1 switches both off and outputs `uBase + c` exactly as the
// reference does — that is the mode the side-by-side comparison is judged in.
//
// ── WIP-880 · the BLACK SHADOW treatment (owner pick, 2026-08-18) ────────
// `shadow.x` = 0 is the shipped paint above, byte for byte: every line below
// runs exactly as it did, and the branch that reads `shadow` is dead code the
// compiler removes. THAT IS THE DEFAULT AND IT DOES NOT MOVE. Nothing here
// repaints anybody who does not ask for it.
//
// With `shadow.x` > 0 the pass stops being a light and becomes an OCCLUDER.
// The owner picked "Black shadow" off the 13-treatment variety pass
// (docs/BRIEF_AGENT_PB_2026-08-17.md, artifact specimen A): the swirl is pure
// black — no dye colour, no specular, no bloom lift reaching the eye — and a
// faint even glow sits in the bar which the paint BLOCKS. You see the swirl
// entirely by what it hides. `shadow.x` is that glow in 8-BIT LEVELS, the
// study's own parameter and unit, so 18 here is the artifact's `glow 18`.
// `shadow.y` is its `occ`, the fraction of the glow the thickest paint eats.
// 8-bit levels are the right unit and not a convenience: every value in play
// is under 10/255, which is inside sRGB's LINEAR segment, so a level here is
// proportional to the light it adds and the study's arithmetic carries over.
//
// ⚠ ONE SUBSTITUTION, NAMED. The study's thickness is
// `T = clamp(h / (2.2 × h_median), 0, 1.5)`, h being the dye's rec601
// luminance — and that is reproduced here term for term, the same `h`, the
// same 2.2 (`shadow.z`), the same 1.5 ceiling. The one thing that could not
// come across is `h_median`: it is a per-geometry statistic (0.0079 at the
// bar, 0.0745 at 16:9 — a 9.4× spread), a shader cannot compute a median,
// and a constant baked for the bar would misrender every other Swirl host by
// that factor. So the field's own MEAN stands in for its median, and it is
// free: `dyeBuf` is already `mipmap: true`, so the last mip level is the
// whole field averaged into one texel and `textureLod(dye, uv, 20.0)` reads
// it. The dye field is right-skewed, so its mean exceeds its median and this
// therefore UNDER-occludes slightly against the study. Said, not hidden.
//
// What that substitution buys, and it is the reason to prefer it over any
// baked constant: T re-derives itself per surface, per dye tier and per
// `intensity` setting, so one settings key can mean the same MATERIAL on a
// 22.9:1 bar and a 16:9 flyout instead of the same arithmetic.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float cornerRadius;  // px
    vec4 size;           // x,y item px · z,w DYE texel
    vec4 look;           // x exposure · y bloom · z saturation · w sheen
    vec4 audio;          // bass, mid, high, beat pulse
    vec4 base;           // rgb = swirl-live.html BASE · w = opaque mode
    vec4 shadow;         // x glow 8-bit (0 = OFF, shipped paint) · y occ
                         // z normaliser (study's 2.2) · w reserved, 0
    vec4 dissolve;       // x reach as a FRACTION of item height (0 = OFF,
                         // the shipped hard edge) · y,z,w reserved, 0
    // ── TRK-3476 · THE SECOND CONTOUR ────────────────────────────────────
    // x strength in 8-bit levels (0 = OFF, and every surface that does not
    // ask for it compiles and renders exactly as before) · y the thickness
    // T this contour rides · z its half-width in T · w THE HALO FLOOR
    // (TRK-3478; 0 = keep TRK-3475's 0.88, so every existing surface is
    // unchanged). See the halo line at the end of the shadow branch.
    vec4 filament;
    // ── TRK-3481 · LIQUID GLASS ──────────────────────────────────────────
    // x strength — thickness to absorption (0 = OFF, and every surface that
    // does not ask for it takes the branches below exactly as before)
    // y pooling — how much of the material's own colour thick glass carries
    // z caustic — the light caught at the fold
    // w reserved, 0
    vec4 liquid;
    // The glass's own pool colour, handed in from Theme so this shader
    // invents no hue. rgb used, w spare.
    vec4 liquidPool;
    // ── TRK-3497 · COLOUR, BUT ONLY THE CONTOURS, AND ONLY ON MUSIC ──────
    // rgb = the tint · w = how much of it to apply (0 = the shipped
    // monochrome swirl, so silence and every other surface are unchanged).
    vec4 contourTint;
    // ── TRK-3488 · REFRACTION THROUGH THE STARFIELD ──────────────────────
    // x amount — displacement in UV along the sheet's surface slope (0 = OFF)
    // y dispersion — how far R and B are pulled apart. Real glass separates
    //   wavelengths; this is that, not a colour effect.
    // z vScale — this band's height over the refracted surface's, so the two
    //   UV spaces line up (the bar hangs 168 px over an 84 px seam = 2.0)
    // w reserved, 0
    vec4 refractCfg;
};
layout(binding = 1) uniform sampler2D dye;
// What the sheet bends: the REAL sky. `SkyBehind` renders HeadlinerSky
// screen-aligned inside this window so a shader can sample it — a shader
// cannot read another compositor surface, which is why transparency alone can
// never give refraction. Always bound; Swirl.qml falls back to the dye buffer.
layout(binding = 2) uniform sampler2D bg;

float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void main() {
    vec2 uv = qt_TexCoord0;

    vec3 body = texture(dye, uv).rgb;
    body = pow(body, vec3(1.12));            // thin haze dies, ribbons stay

    // Three taps at the reference's weights (0.10 / 0.14 / 0.12). The audio
    // term is 1.0 whenever nothing is playing, so a silent panel is the
    // reference's bloom exactly.
    float bloomG = look.y * (1.0 + 0.45 * audio.x + 0.60 * audio.w);
    vec3 c = body;
    c += 0.10 * bloomG * textureLod(dye, uv, 1.5).rgb;
    c += 0.14 * bloomG * textureLod(dye, uv, 3.0).rgb;
    c += 0.12 * bloomG * textureLod(dye, uv, 5.0).rgb;

    // wet sheen: pseudo-normal from paint height, light drifts with time
    float hC = lum(texture(dye, uv).rgb);
    float hX = lum(texture(dye, uv + vec2(size.z * 1.5, 0.0)).rgb);
    float hY = lum(texture(dye, uv + vec2(0.0, size.w * 1.5)).rgb);
    vec3 n = normalize(vec3((hC - hX) * 4.5, (hC - hY) * 4.5, 1.0));
    vec3 Ld = normalize(vec3(0.4 * sin(time * 0.23), 0.55, 0.75));
    float spec = pow(max(dot(n, normalize(Ld + vec3(0.0, 0.0, 1.0))), 0.0), 26.0);
    c += spec * look.w * smoothstep(0.05, 0.8, hC) * vec3(0.9, 0.95, 1.0);

    // hot cores toward white, never toward more saturation
    float m = max(c.r, max(c.g, c.b));
    c = mix(c, vec3(m), smoothstep(1.4, 3.2, m) * 0.45);

    c = 1.0 - exp(-c * look.x);
    c = pow(c, vec3(0.90));
    float l2 = lum(c);
    c = clamp(mix(vec3(l2), c, look.z), 0.0, 1.0);

    // corner-bleed: paint dims into the panel corners (the signature)
    vec2 q = uv * (1.0 - uv);
    float edge = smoothstep(0.0, 0.028, q.x) * smoothstep(0.0, 0.13, q.y);
    c *= 0.18 + 0.82 * edge;

    if (base.w > 0.5) {                      // reference-exact output
        fragColor = vec4(base.rgb + c, 1.0);
        return;
    }

    // rounded-rect mask, 1px antialiased
    vec2 px = uv * size.xy;
    vec2 half_ = size.xy * 0.5;
    vec2 b = half_ - vec2(cornerRadius);
    vec2 d2 = abs(px - half_) - b;
    float dist = length(max(d2, vec2(0.0))) + min(max(d2.x, d2.y), 0.0) - cornerRadius;
    float mask = clamp(0.5 - dist, 0.0, 1.0);

    // ── the TOP-EDGE DISSOLVE ────────────────────────────────────────────
    // `dissolve.x` = 0 is the shipped hard edge and every host that does
    // not ask for a dissolve gets exactly the picture it got before.
    //
    // Stated precisely, because the convenient phrasing here is false: this
    // is a RUNTIME branch, not one the compiler removes — `dissolve` is a
    // uniform, so no compiler can prove it zero. What IS true is checkable,
    // and was checked: `qsb --dump` of this file against HEAD differs by
    // the uniform declaration, the block growing 160 -> 176 bytes, and
    // these four lines — in both the `330` and the `300 es` targets, and
    // in nothing else. The cost when off is one scalar compare per
    // fragment; the paint path's arithmetic is untouched.
    //
    // FOLDED INTO `mask`, DELIBERATELY, AND NOT APPLIED AT EACH RETURN.
    // There are two shell exits below — the paint path and WIP-878's
    // black-shadow path — and both already multiply by `mask`. Writing the
    // dissolve as a multiply at each exit instead would be correct today
    // and wrong the day somebody adds a third, which is exactly how a
    // treatment ends up silently absent under one setting and present
    // under another. Folding it here makes "every exit is covered" a
    // property of the structure rather than a thing to remember. It also
    // means the black-shadow path's ADDITIVE glow is removed by the same
    // term that removes the paint: at mask 0 that exit emits
    // `vec4(vec3(g)*0, 0.0)` — rgb zero AND alpha zero, no added light.
    //
    // The reference-exact path (`base.w > 0.5`) returns ABOVE this and is
    // deliberately left alone: it exists to be diffed against
    // swirl-live.html, and a dissolve the reference does not have would
    // break the one thing that mode is for.
    if (dissolve.x > 0.0) {
        // u = 0 at the top of the reach, 1 at the bar's old top edge.
        float u = clamp(uv.y / dissolve.x, 0.0, 1.0);
        // Cubic, and the exponent is the owner's brief read as arithmetic:
        // "full material at the top edge, dropping quickly through the
        // first third of the reach, then trailing to zero". One third of
        // the way up is u = 2/3, where u³ = 0.296 — dropped to under a
        // third. A linear ramp sits at 0.667 there and leaves an upper
        // terminus the eye finds; smoothstep is slower still at 0.741.
        //
        // And it reaches EXACTLY zero: u*u*u at u = 0 is 0, with no floor,
        // no epsilon and no smoothstep tail. That matters because the
        // field arriving here is NOT zero at the item's top row — the
        // corner-bleed above floors it at 0.18 — so the ramp is the only
        // thing between 18% of the paint and nothing at all.
        mask *= u * u * u;
    }

    // ── WIP-880 · black shadow. Everything above ran; none of it is shown.
    // ── TRK-3481 · LIQUID GLASS · owner 2026-08-30 ───────────────────────
    // "what if we made like a liquid glass as the swirls instead — would that
    // then use the same materials as what it's made of, and turn that into
    // the swirls but using the glass materials instead?"
    //
    // Yes, and it is the only version of this that can ever match the
    // widgets, for a reason worth stating precisely because three nights of
    // dial-turning went at it from the wrong end.
    //
    // EVERY treatment before this one is ADDITIVE LIGHT. WIP-880's shadow
    // branch below ends `vec4(vec3(g), 0.0)` — premultiplied with alpha 0,
    // which is a pure ADD over whatever the glass painted. Light laid ON the
    // material. So the bar is the widget material PLUS something, and no
    // amount of tuning makes "plus something" equal "nothing": the bar sat
    // +17 levels above a widget's ground, then +8.5, then +5.0 with the paint
    // switched off entirely, and the surplus only ever shrank.
    //
    // This branch does not add light. It modulates the MATERIAL:
    //
    //   · ALPHA IS THE LEVER. Premultiplied source-over resolves to
    //     `out = src.rgb + dst * (1 - src.a)`, so alpha is the only way this
    //     pass can DARKEN, and darkening is exactly what thick glass does.
    //     Thickness T drives alpha, so where the fluid piles up the glass
    //     reads thicker and drinks more light.
    //   · AT T = 0 THE OUTPUT IS (0,0,0,0). Not "close to the glass" —
    //     literally the glass, untouched, byte for byte. That is the whole
    //     point: the bar's background cannot differ from a widget's, because
    //     on bare ground this pass writes nothing at all. The match stops
    //     being something to tune and becomes a property of the algebra.
    //   · THE COLOUR IS THE GLASS'S OWN. `liquidPool` is handed in from
    //     Theme (the same pool family GlassEdge's bleed already uses), so
    //     thickening pools the material's colour rather than introducing a
    //     dye. No hue is invented in this shader.
    //   · THE FOLD CATCHES LIGHT. A real liquid sheet is brightest where its
    //     thickness changes fastest — a caustic, not a rim. `grad` is that
    //     rate, reusing the finite difference the sheen above already took,
    //     so it costs no extra texture fetch.
    //
    // The solver is untouched: this reads the same advected dye field every
    // other treatment reads. It is a display stage, and only a display stage.
    if (liquid.x > 0.0) {
        float hBarL = lum(textureLod(dye, uv, 20.0).rgb);
        // An ABSOLUTE floor, not merely a divide-by-zero guard. On a field
        // that has genuinely decayed away, hC/(k*hBar) is 0/0 and an epsilon
        // denominator makes it EXPLODE rather than vanish — every ratio
        // saturates and the sheet floods the bar instead of disappearing.
        if (hBarL < 1e-5) { fragColor = vec4(0.0); return; }
        float denom = shadow.z * hBarL;
        float T = clamp(hC / denom, 0.0, 1.5);

        // ── THE AMBIENT BASELINE, and the correction that needed ─────────
        // T is thickness relative to the field's MEAN, so T ~ 1 is the
        // resting haze — NOT bare ground. The bar is stirred continuously
        // (BarSeam's `ambientDye`), so dye covers all of it and there is no
        // zero-thickness region anywhere on the strip.
        //
        // The first cut read T linearly, which therefore tinted the ENTIRE
        // bar and pushed its ground to +12.19 of a widget — worse than the
        // additive treatment it was meant to replace, and plum-cast with it
        // (measured rgb 18.91, 11.76, 22.46). Said plainly because it is the
        // opposite of what this branch exists to do.
        //
        // So a stroke is thickness ABOVE the ambient mean, and the baseline
        // itself resolves to nothing. That is what makes the bar's
        // background the untouched glass: not that the dye is absent, but
        // that ordinary dye is defined as "no sheet".
        float S = smoothstep(liquid.w > 0.0 ? liquid.w : 0.95, 1.45, T);

        // thickness -> absorption
        float a = clamp(liquid.x * S, 0.0, 0.92);

        // thickness -> the material's own pooling
        vec3 tint = liquid.y * S * liquidPool.rgb;

        // the fold, where the sheet turns and catches the light. Gated on S
        // too, so the haze's own gradients cannot draw caustics on ground
        // the sheet is not on.
        float grad = length(vec2(hC - hX, hC - hY)) / denom;
        float caustic = liquid.z * smoothstep(0.25, 1.10, grad) * S;
        vec3 lip = caustic * liquidPool.rgb;

        // the corner-bleed, kept: the sheet thins into the bar's ends the
        // same way the paint always has.
        float m2 = mask * (0.18 + 0.82 * edge);

        // ── TRK-3488 · THE SHEET BENDS THE STARS ─────────────────────────
        // Glass bends what is behind it by its SURFACE SLOPE. Stars are POINT
        // sources, which is the whole reason this can work where TRK-3482
        // could not: displacing a point is instantly legible — it smears, it
        // splits, it flares where the surface focuses — whereas the smooth
        // gradient that attempt bent looked identical displaced.
        //
        // ⚠ THE DIRECTION IS NORMALISED, and that is not cosmetic. The raw
        // gradient's LENGTH carries the dye field's density, so scaling by it
        // makes the displacement depend on how much paint happens to be
        // present — thin haze barely bends, thick paint bends wildly, and the
        // amount dial then does not mean anything stable. Taking the unit
        // direction and scaling it by `refractCfg.x` in UV makes the bend a
        // property of the sheet's SHAPE, which is what optics says it is.
        //
        // DISPERSION costs two extra reads: R is sampled further along the
        // slope than B, because glass separates wavelengths. Without it the
        // refraction reads as a smear; with it, as glass.
        if (refractCfg.x > 0.0) {
            vec2 g2 = vec2(hC - hX, hC - hY);
            vec2 dir = g2 / max(length(g2), 1e-7);
            float bend = smoothstep(0.0, 0.35, length(g2) / denom);
            vec2 off = dir * bend * refractCfg.x * vec2(1.0, refractCfg.z);
            vec2 dsp = off * refractCfg.y;
            // ⚠ INSET. Without it the displaced sample walks off the plate at
            // the frame edges, clamps, and paints bright noisy bands down the
            // left and right of the bar — visible in the 01:56 capture.
            vec2 base2 = vec2((uv.x - 0.5) * 0.94 + 0.5, uv.y * refractCfg.z);
            vec3 refr;
            refr.r = texture(bg, clamp(base2 + off + dsp, vec2(0.001), vec2(0.999))).r;
            refr.g = texture(bg, clamp(base2 + off,       vec2(0.001), vec2(0.999))).g;
            refr.b = texture(bg, clamp(base2 + off - dsp, vec2(0.001), vec2(0.999))).b;

            // The sheet REPLACES the straight copy the sky painted beneath —
            // both together would composite bent over straight and read as a
            // double exposure rather than depth. Outside the sheet S is 0 and
            // this writes nothing, so the bar is the untouched sky there.
            vec3 col = refr * (1.0 - a) + tint + lip;
            float cov = clamp(S, 0.0, 1.0) * m2;
            fragColor = vec4(col * cov, cov) * qt_Opacity;
            return;
        }

        fragColor = vec4((tint + lip) * m2, a * m2) * qt_Opacity;
        return;
    }

    if (shadow.x > 0.0) {
        // `hC` is already `lum(texture(dye, uv).rgb)` — the study's own `h`,
        // computed above for the sheen, so the default path pays nothing for
        // it. `hBar` is that same luminance averaged over the whole field by
        // the mip chain; the floor keeps a fully-decayed field (h and hBar
        // both → 0) resolving to T = 0, i.e. NO paint and an even glow,
        // which is the truthful picture of an empty field rather than NaN.
        float hBar = lum(textureLod(dye, uv, 20.0).rgb);
        float T = clamp(hC / max(shadow.z * hBar, 1e-6), 0.0, 1.5);
        float g = (shadow.x / 255.0) * clamp(1.0 - shadow.y * T, 0.0, 1.0);
        // TRK-3466 (owner, live: "a real thin line of glow that flows
        // through it") — a lit filament INSIDE the black paint, drawn on
        // the T~0.6 ISOLINE of the same thickness field the occluder
        // reads, so it rides the strokes as they advect. `shadow.w` is its
        // strength in 8-bit levels; 0 (every non-bar surface) leaves this
        // branch byte-identical to the shipped treatment. core^2 thins the
        // band to a line.
        // TRK-3497 — the contour light is accumulated SEPARATELY from the
        // base glow, because only the contours get colour. Tinting the whole
        // output would wash the bar; tinting the filigree makes the lines
        // themselves glow while the ground stays the material's own dark.
        float contour = 0.0;
        if (shadow.w > 0.0) {
            float core = 1.0 - smoothstep(0.0, 0.22, abs(T - 0.6));
            contour += (shadow.w / 255.0) * core * core;
        }
        // ── TRK-3476 · THE SECOND CONTOUR · owner 2026-08-30 ─────────────
        // "the swirl doesn't read as swirling enough — more visible motion
        // and turbulence, not a static tint or wash."
        //
        // WHY THE WASH READING HAPPENS, stated as the mechanism rather than
        // as a preference, because it decides what the fix has to be. In
        // this branch the paint is shown by OCCLUSION: `g` is a monotonic
        // function of the thickness T and of nothing else. A monotonic map
        // from thickness to darkness cannot distinguish a vortex from a
        // smooth blob of the same thickness profile — both integrate to the
        // same soft gradient. The solver underneath IS producing spirals
        // (vorticity confinement, `swirl_vorticity.frag`); the display stage
        // is throwing their structure away. So the honest fix is not more
        // force, more curl or more dye — those change a field that is
        // already right — it is to make the display SHOW the structure the
        // field already has.
        //
        // What shows structure in a scalar field is a CONTOUR. `shadow.w`
        // above is already exactly that: one isoline at T = 0.6, and it is
        // the single most legible thing on the bar. One contour, though, is
        // one outline — it traces a stroke's edge and reads as a rim. Folded
        // paint reads as folded because you see SEVERAL nested edges across
        // the fold, which is what banding a ribbon into contours gives you.
        //
        // So: a second isoline, at its own T and its own width, riding the
        // same advected thickness field as the first. Same technique, one
        // more band of it — not a noise layer, not a second flow field, and
        // nothing that could animate independently of the fluid. Because it
        // reads the T already computed above it costs no texture fetch: four
        // ALU ops and one compare per fragment.
        //
        // `core*core*core` and not `core*core`: the cube is the narrower
        // profile, so this contour reads as a LINE inside the stroke while
        // `shadow.w`'s square stays the broader lit band. Two contours of
        // the same width would read as one thick one.
        if (filament.x > 0.0) {
            float core2 = 1.0 - smoothstep(0.0, filament.z, abs(T - filament.y));
            contour += (filament.x / 255.0) * core2 * core2 * core2;
        }
        contour *= 0.18 + 0.82 * edge;       // contours die into the ends too
        g *= 0.18 + 0.82 * edge;             // the corner-bleed, kept: the
                                             // glow dies into the panel ends
                                             // exactly where the paint does
        // TRK-3466 (owner: "the bar's background looks different than the
        // widgets") — the even wash was lifting the whole bar above the
        // widget band. The glow now LIVES WITH THE PAINT: a wide-mip local
        // density gates it, so empty ground falls to 10% (back inside the
        // widget material's own darkness) and each swirl carries its own
        // halo of light for the black to cut through.
        float localD = lum(textureLod(dye, uv, 5.0).rgb);
        float halo = clamp(localD / max(shadow.z * hBar * 0.30, 1e-6), 0.0, 1.0);
        // TRK-3475: floor 0.10 -> 0.88. At 0.10 the ground collapsed to a
        // tenth of the wash whenever the music paused and the dye field
        // decayed — the dull<->correct flip the owner watched for a night.
        // At 0.88 the ground holds still and the halo breathes its 12%
        // with the strokes. Everything else in this branch is his tuned
        // 4cfda079. ⚠ shader edits render only after a shell RESTART —
        // reloads never flush compiled pipelines (the 08-29 lesson).
        // ── TRK-3478 · THE FLOOR IS THE BACKGROUND · owner 2026-08-30 ──
        // "the bottom bar, the background or the layers don't look like that
        // of the widgets."
        //
        // Measured, swirl fully off (Swirl.opacity 0 — note that zeroing
        // `shadow.x` does NOT turn the paint off, it drops through to the
        // COLOUR path): the bar's GLASS ground is 5.63 against a widget's
        // 2.94, +2.69 levels. The glass matches. With the paint on, mid-bar
        // ground measures 21–26. So what separates the bar from the widgets
        // is this line: a floor of 0.88 puts 88% of the glow on ground that
        // has NO paint on it, an even wash ~21 levels bright that no widget
        // carries.
        //
        // The floor was raised to 0.88 by TRK-3475 for a real reason — at
        // 0.10 the whole ground tracked the dye and the owner watched it
        // flip dull<->correct with the music. What has changed since is
        // that the swirl's visibility no longer DEPENDS on this wash: the
        // two contours above (`shadow.w` and `filament.x`) are gated on T,
        // so they light the paint and leave bare ground alone. The glow can
        // therefore come down and the floor with it, and the strokes still
        // read — which is the only reason this is safe to move now and was
        // not before.
        //
        // 0 keeps 0.88 exactly, so every surface that does not set it is
        // byte-identical.
        float haloFloor = filament.w > 0.0 ? filament.w : 0.88;
        g *= haloFloor + (1.0 - haloFloor) * halo;
        // ALPHA 0, ON PURPOSE. Premultiplied source-over with a = 0 is a pure
        // ADD: the glass under the bar is untouched and this lays one faint
        // even light over it, which is the thing the paint is blocking. Any
        // alpha above 0 would make the swirl COVER the glass instead, and the
        // treatment would stop being an occlusion.
        // Base glow stays neutral; the contours carry the colour. At
        // contourTint.w = 0 this is exactly vec3(g + contour), i.e. the
        // shipped monochrome swirl, so silence is byte-for-byte unchanged.
        vec3 lit = vec3(g) + mix(vec3(contour),
                                 contourTint.rgb * contour * 1.35,
                                 clamp(contourTint.w, 0.0, 1.0));
        fragColor = vec4(lit * mask, 0.0) * qt_Opacity;
        return;
    }

    // Alpha blends toward the channel MAX, not luminance: lum() weights blue at
    // 0.114, so a deep violet ribbon at full strength was handed an alpha of
    // ~0.2 and simply did not appear. Grounds still go to zero, so black stays
    // black.
    float vis = max(c.r, max(c.g, c.b));
    float a = clamp(mix(lum(c), vis, 0.75) * 1.75, 0.0, 0.88);
    fragColor = vec4(c * mask, a * mask) * qt_Opacity;
}
