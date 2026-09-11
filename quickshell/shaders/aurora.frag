#version 440
// Nyxus Suxyn — THE AURORA. Curtains for the Ocular Constellation lock scene.
//
// ── WHY THE PALETTE IS NOT BORROWED ──────────────────────────────────────
// The build's own tokens already ARE an aurora, which is the whole reason this
// layer belongs here rather than being a green stolen from a photograph. A real
// curtain is oxygen at 557.7 nm low down — green — running up into violet-red
// where nitrogen takes over. NYXUS ships ok #2cf597 and violet #521e72. Those
// are the same two ends of the same physical ramp. Nothing in the gradient
// below was picked to look like an aurora; it is the palette doing the thing it
// physically describes, with the build's glacier #5cc6ea sitting where the two
// meet because that is where it already sits in every other surface.
//
// ── THE TWO THINGS THAT SEPARATE A CURTAIN FROM A BARCODE ────────────────
// The reference implementation's first attempt was a barcode, and the two fixes
// are the entire reason this file looks like anything:
//
//   1. THE RAYS MUST BE SOFT. This is rendered at QUARTER RESOLUTION and scaled
//      up by the host — a sixteenth of the fill, and the upscale's bilinear
//      filter is a free, correctly-weighted blur. Rendering it at full res and
//      blurring afterwards costs 16x more to arrive somewhere worse. The host
//      owns that (see LockOcular.qml); this shader just draws small.
//
//   2. EVERY STRIP NEEDS ITS OWN TOP AND BOTTOM. A flat hem is exactly what
//      reads as a barcode. `crown` and `hem` below are independent layered
//      waves, so the curtain has a shaped silhouette — an arched crown and a
//      ragged lower edge — rather than a rectangle full of stripes.
//
// ── WHY THE RAY NOISE IS THREE SINES AND NOT ONE ─────────────────────────
// One sine is a picket fence: the eye finds the period in about a second. Three
// at incommensurate frequencies (9.0, 4.1, 23.0) multiplied together never
// repeat within a curtain's width. The 23.0 term is deliberately just above
// what the quarter-res buffer can resolve, so it survives the upscale as
// texture rather than as countable lines.
//
// ── BLENDING, AND AN HONEST APPROXIMATION ────────────────────────────────
// The reference composites these with `mix-blend-mode: screen`. QML gives a
// ShaderEffect no access to the backdrop and no blend-func control, so this
// composites src-over instead. That is NOT a cheat here: this scene's sky is
// #010306, and over a ground that dark screen and over are within a couple of
// levels of each other everywhere the curtain is actually visible. It would be
// a real difference over a bright backdrop, so if this layer is ever reused
// over anything but the void, that assumption has to be revisited.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float uTime;
    float uIntensity;   // 0..1 master, so Settings can dial the curtains down
    float uPad;         // keeps uRes on a 16-byte boundary — see below
    vec4 uRes;          // x,y = buffer px (already quarter-size) · z,w spare
};
// ⚠ THE PAD IS LOAD-BEARING. std140 aligns a vec4 to 16 bytes. Without uPad the
// vec4 would start at offset 76, the compiler would silently insert the hole
// itself, and every float written after it would be read from the wrong place.
// This is the exact defect that made the crystal mark's eye uniforms read
// garbage. The pad is here so the layout is stated rather than inferred.

const float PI = 3.14159265;

// The vertical ramp, as colour-with-alpha stops. Alpha reaching 0 at BOTH ends
// matters: a curtain that is opaque at its top edge has a visible cut there.
vec4 rampAt(float y)
{
    // stops: pos, rgb, a  — violet -> deep blue -> glacier -> ok green
    const vec3 violet  = vec3(0.322, 0.118, 0.447);   // #521e72
    const vec3 deep    = vec3(0.118, 0.012, 0.678);   // #1e03ad
    const vec3 glacier = vec3(0.361, 0.776, 0.918);   // #5cc6ea
    const vec3 okGreen = vec3(0.173, 0.961, 0.592);   // #2cf597

    if (y < 0.18) {
        float t = y / 0.18;
        return vec4(violet, mix(0.0, 0.34, t));
    } else if (y < 0.40) {
        float t = (y - 0.18) / 0.22;
        return vec4(mix(violet, deep, t), mix(0.34, 0.30, t));
    } else if (y < 0.63) {
        float t = (y - 0.40) / 0.23;
        return vec4(mix(deep, glacier, t), mix(0.30, 0.52, t));
    } else if (y < 0.86) {
        float t = (y - 0.63) / 0.23;
        return vec4(mix(glacier, okGreen, t), mix(0.52, 0.66, t));
    }
    float t = (y - 0.86) / 0.14;
    return vec4(okGreen, mix(0.66, 0.0, t));
}

// One curtain. Returns premultiplied-ish rgb and its coverage in .a.
vec4 curtain(vec2 uv, float cx, float cw, float amp, float sp, float aa,
             float ph, float top, float bot, float t)
{
    // Sway shifts the curtain bodily; sampling in swayed space keeps the rays
    // attached to the curtain instead of sliding through it, which is what
    // makes it read as fabric moving rather than as a scrolling texture.
    float sway = sin(uv.x * 3.0 + t * sp * 2.4 + ph) * amp;
    float u = (uv.x - sway - cx) / cw;
    if (u < 0.0 || u > 1.0) return vec4(0.0);

    // Rays: three incommensurate frequencies, multiplied.
    //
    // ⚠ THE FLOORS ARE RAISED FROM THE REFERENCE (0.50/0.55/0.58) AND THAT IS
    // DELIBERATE. Three terms multiplied together collapse fast: with the
    // reference's floors the typical product is about a quarter, and after the
    // vertical ramp and the soft hem the curtain arrived at roughly a tenth of
    // an already-low alpha — the render showed dark blue smudges you had to
    // look for. The reference gets away with it because a canvas composites
    // these with `screen` onto a page that is not this dark. Higher floors keep
    // the ray STRUCTURE (the variation is what makes rays) while stopping the
    // product from vanishing.
    float v = 0.62 + 0.38 * sin(u * 9.0  + t * sp * 6.0 + ph);
    v *= 0.68 + 0.32 * sin(u * 4.1  - t * sp * 3.2 + ph * 1.6);
    // The fine term keeps its full swing while the two broad ones are floored.
    // Raising ALL THREE floors made the curtains bright and turned them into
    // coloured fog — the rays are the only thing that says "curtain" rather
    // than "smudge", and they live almost entirely in this term. Contrast here,
    // brightness from the floors above: they are separate jobs.
    v *= 0.52 + 0.48 * sin(u * 23.0 + t * sp * 2.0);
    v *= pow(max(sin(PI * u), 0.0), 0.7);      // die at both edges, never a hard cut
    // ⚠ NO `if (v < x) return 0` HERE. A threshold on brightness is a hard
    // contour at the level you picked, and after the 4x upscale that contour is
    // a visible outline around every ray. The first render of this shader had
    // one and the curtains came out as cut-paper shapes with lit edges. It
    // costs nothing to let v run to zero on its own.

    // The silhouette: an arched crown and a ragged hem, each its own wave.
    float hem   = bot + 0.055 * sin(u * 7.0  + t * sp * 4.0 + ph)
                      + 0.030 * sin(u * 13.0 - t * sp * 2.0);
    float crown = top + 0.045 * sin(u * 5.0  - t * sp * 3.0 + ph * 0.8);

    // ⚠ AND NO HARD `if (uv.y < crown) return 0` EITHER — same defect, in the
    // other axis. The silhouette is expressed ENTIRELY as a soft ramp, and the
    // ramps are wide: a real curtain fades out over a good fraction of its own
    // height, it does not stop. 0.22 up from the crown and 0.30 down to the hem
    // read as light dying out; the 0.05/0.07 the first version used read as a
    // wavy cut edge, which is the barcode failure wearing a different hat.
    float edge = smoothstep(crown, crown + 0.22, uv.y)
               * (1.0 - smoothstep(hem - 0.30, hem, uv.y));
    if (edge <= 0.0) return vec4(0.0);          // outside entirely — free to skip

    vec4 c = rampAt(uv.y);
    return vec4(c.rgb, c.a * v * aa * edge);
}

void main()
{
    vec2 uv = qt_TexCoord0;
    float t = uTime;

    // Three curtains at different widths, speeds and phases. Nothing here is
    // evenly spaced on purpose — three equal curtains read as a pattern.
    // Taller than the reference's (0.06..0.72 / 0.14..0.66 / 0.10..0.70). A
    // curtain that occupies two thirds of the frame height reads as a horizontal
    // smear; the vertical rays need vertical room before the eye accepts them as
    // rays at all. These run nearly the full height and the soft hem does the
    // work of ending them.
    vec4 a = curtain(uv, 0.10, 0.42, 0.030, 0.10, 0.85, 0.0, 0.02, 0.86, t);
    vec4 b = curtain(uv, 0.38, 0.46, 0.024, 0.07, 0.62, 2.1, 0.09, 0.80, t);
    vec4 c = curtain(uv, 0.66, 0.38, 0.034, 0.12, 0.50, 3.9, 0.05, 0.88, t);

    // Accumulate as light. Curtains overlap in the real sky and where they do
    // it gets brighter, so this ADDS. Each term is already premultiplied by its
    // own coverage, so the sum is a premultiplied colour and stays one.
    vec3 pre = a.rgb * a.a + b.rgb * b.a + c.rgb * c.a;
    float cov = 1.0 - (1.0 - a.a) * (1.0 - b.a) * (1.0 - c.a);
    if (cov <= 0.0) { fragColor = vec4(0.0); return; }

    // ⚠ DO NOT UN-PREMULTIPLY HERE. The first version did `pre /= cov` to get a
    // straight colour, brightened it, and clamped. That is a colour explosion
    // wearing a reasonable-looking line of maths: wherever a curtain is FAINT,
    // cov is near zero, the divide multiplies the colour by a huge number, and
    // the clamp pins it to fully-saturated primary. The render came back as
    // solid magenta and cyan slabs with lit edges — the faintest parts of the
    // curtain became the most violent pixels on screen, which is precisely
    // backwards. Brightness and saturation are LINEAR operations, so they can
    // be done on the premultiplied value directly and the divide is not needed
    // for anything.
    pre *= 1.18;                                 // brightness lift

    // Saturation against luma. Safe on a premultiplied value because it is a
    // linear blend between the value and its own grey.
    float luma = dot(pre, vec3(0.2126, 0.7152, 0.0722));
    pre = max(mix(vec3(luma), pre, 1.25), vec3(0.0));

    // Overall gain. The ramp tops out at 0.66 alpha and the ray/hem terms take
    // a large bite out of that, so without a lift the curtains are technically
    // present and practically invisible over #010306. Measured on the headless
    // render, not guessed: at gain 1.0 the brightest curtain pixel reached
    // about a tenth of full scale.
    const float GAIN = 2.15;

    float k = 0.92 * uIntensity * qt_Opacity * GAIN;
    float alpha = clamp(cov * k, 0.0, 1.0);
    // Premultiplied output must never exceed its own alpha per channel, or the
    // compositor produces colour brighter than the coverage that carries it and
    // every edge picks up a bright fringe.
    fragColor = vec4(min(pre * k, vec3(alpha)), alpha);
}
