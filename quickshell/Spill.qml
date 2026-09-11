// Nyxus Suxyn — the Spill. The horizon casting its light onto the wallpaper.
//
// HORIZON §5: the seam is a light source, and light sources illuminate things.
// This is the glow the Line throws up onto the desktop behind it — bias
// lighting for an operating system. It is the difference between a coloured
// line drawn on a picture and a lit edge that the picture is standing in
// front of, and it is most of what the owner means by "how they almost glow".
//
// Three properties make it safe rather than a gimmick:
//
//   · It is on the BOTTOM layer, so it lights the wallpaper and nothing else.
//     The moment a window covers that part of the screen, the window covers
//     the spill too — light does not tint your documents.
//   · It has an EMPTY input mask. It cannot be clicked, hovered or focused;
//     right-clicking the desktop still reaches the desktop.
//   · It runs the same Swirl at HALF resolution scaled 2×, so its simulation
//     is smaller than the bar's (480×75 vs 960×52) and the upscale is exactly
//     the softness a cast glow wants. It sleeps with the bar.
//
// It cannot share the bar's dye texture — a ShaderEffectSource does not cross
// windows — so it shares the bar's INPUT instead, over Bus.paint().
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: spill

    anchors { left: true; right: true; bottom: true }
    implicitHeight: 200
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "nyxus-spill"
    color: "transparent"
    visible: Prefs.swirlEnabled

    // Not a surface. It never takes a pointer event.
    mask: Region {}

    // Half-resolution, drawn at 2×; the field's on-screen span is therefore
    // [y, y + 2·height].
    //
    // THE PEAK SITS ON THE SEAM. The first cut centred the field on the top
    // edge of the chrome instead, on the theory that everything below that is
    // behind the bar and wasted. Agent A measured the result against a live
    // screen (docs/REVIEW_SPILL_2026-08-03.md) and caught what that costs: the
    // brightest row ended up ~70 px ABOVE the actual seam, reading 126% of the
    // seam's own brightness. A light source cannot be out-shone by its own
    // glow — so the eye read the glow as a separate object floating under the
    // bar. He is right, and it is worth the wasted lower half: the light now
    // peaks exactly at the screen edge and only ever decreases going up, which
    // is the one thing that makes it read as light rather than as a shape.
    readonly property real fieldH: height + 10

    Swirl {
        id: field
        x: 0
        y: spill.height - spill.fieldH
        width: spill.width / 2
        height: spill.fieldH
        transformOrigin: Item.TopLeft
        scale: 2

        // A's second finding: ~15% of screen height is the top end of tasteful
        // and will smear on a bright wallpaper, and the default set includes
        // bright urban-neon art. Reach is down from ~300 px to 200, and with
        // the peak moved onto the seam the part you actually see on the
        // wallpaper — above the 72 px chrome zone — is ~128 px, under 12%.
        // Intensity comes down with it.
        opacity: 0.42
        visible: Prefs.swirlEnabled
        intensity: Prefs.swirlIntensity
        cornerRadius: 0
        interactive: false
        // The horizon ignites at login: the bar draws its sweep and the
        // wallpaper lights up with it. Softer than the bar's, because this
        // one is 200 px of wallpaper and not a 28 px seam.
        playIntroOnLoad: true
        introStrength: 0.30

        // A cast glow is haze, not ribbons: wide strokes, slow flow, low
        // exposure, heavy bloom. Everything the bar does tightly, this does
        // loosely, from the same impulses.
        // 0.55 was an analytic-noise-era number and it does not survive the
        // port: `_splatRadius` is impulseRadius², so 0.55 asks for a gaussian
        // of σ ≈ 0.55 of the field HEIGHT, and `dropAt` widens its main tap to
        // 2.6× that again — one splat wider than the whole field. Measured
        // live 2026-08-05: the Spill painted a flat milky slab over the bottom
        // 130 px of the wallpaper instead of a glow. 0.30² = 0.090 is
        // swirl-live.html's own class-default `splatRadius: 0.085` — the
        // reference's widest stroke, which is the right end of the range for
        // haze, and still 1.5× the bar's.
        impulseRadius: 0.30
        curlAmp: 0.30
        ambientAmp: 0.22
        decayRate: 0.30
        injectGain: 0.55
        exposure: 1.06
        bloom: 1.6
        saturation: 1.35
        sheen: 0.0

        audioBass: Beat.bass
        audioMid: Beat.mid
        audioHigh: Beat.high
        audioPulse: Beat.pulse
        musicActive: Beat.hot
    }

    // `Bus.paint` is emitted for every pointer step of the bar's Wake, not only
    // for discrete Tells, and `dropAt` is swirl-live.html's `_dollop` — a
    // pointer-DOWN event that lays down its main tap at 2.6× the splat radius
    // plus nine satellites, roughly ten times a stroke's dye. Answering one per
    // frame clipped this field to a flat white slab under any sustained sweep
    // (measured live 2026-08-05). The reference never fires two dollops closer
    // than a click apart, so neither do we.
    property double _lastDrop: 0

    Connections {
        target: Bus
        function onPaint(nx) {
            const now = Date.now();
            if (now - spill._lastDrop < 150)
                return;
            spill._lastDrop = now;
            // 0.47 of the field height is the seam itself — the field's
            // midpoint now sits on the screen edge, so this is where it is
            // brightest. A drop rather than a stroke: dropAt does not need
            // motion history, which the Spill has no way to reconstruct from
            // a bare x.
            field.dropAt(nx, 0.47, 0.85, 0, -0.7);
        }
    }
}
