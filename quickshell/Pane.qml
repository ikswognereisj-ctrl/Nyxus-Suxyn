// Nyxus Suxyn — the Pane. The one surface primitive.
//
// HORIZON §4 (docs/DESIGN_LANGUAGE_HORIZON_2026-08-03.md): every surface in
// the shell is one of these, so every surface catches light the same way.
// It draws body + dispersive rim + crown highlight + outer bloom in a single
// shader pass (shaders/pane.frag) and hosts its content above that.
//
//     Pane {
//         elevation: 2                 // 0 chrome · 1 inline · 2 swell · 3 modal
//         radiusTL: Theme.r3           // rounded where it is FREE …
//         radiusBL: Theme.r0           // … flush where it meets the horizon
//         Text { ... }                 // children go above the material
//     }
//
// Elevation is LIGHT, never shadow (§4.3): a higher pane has a brighter rim
// and a wider bloom. There are no drop shadows in this build — on a near-black
// desktop they are invisible, and faking one leaves a smudge.
import QtQuick

Item {
    id: pane

    // ── material ─────────────────────────────────────────────────────
    property color fill: Theme.glassFill

    // 0 resting chrome · 1 inline surface · 2 swell · 3 modal.
    // Sets rim and bloom from the Theme ladder; override either afterwards
    // for a one-off (a focus ring, a pressed state).
    property int elevation: 1
    property real rim: elevation === 0 ? Theme.e0Rim
                     : elevation === 1 ? Theme.e1Rim
                     : elevation === 2 ? Theme.e2Rim : Theme.e3Rim

    // ── THE OUTER BLOOM AT REST (TRK-3651) ───────────────────────────
    // Opt-OUT, defaulting to today's behaviour so no untouched surface
    // moves. Set false on a floating pane; leave it alone everywhere else.
    //
    // WHY IT EXISTS. The owner reported that the Start menu, the clock
    // popup and the side flyout draw "layers" on their edges that the
    // desktop widget chips do not. TRK-3629 (edging 0.85) and TRK-3649
    // (ReactiveEdge.haloAtRest) each took one band off and he still saw
    // one: "you see it less ... but its still there on all of them."
    //
    // This is the one he was still looking at, and it is MEASURED, not
    // reasoned. A probe scene drew the launcher's exact stack and the
    // chip's exact stack side by side on pure black and walked a scanline
    // from 30 px outside the edge to 30 px inside. Outside the LEFT edge,
    // luminance, d = px from the edge:
    //
    //     d      -20   -15   -10    -5    -1     0 (the rim)
    //     pane  3.29  5.80 10.95 19.47 32.00  47.54
    //     chip  0.00  0.00  0.00  0.00  0.00  25.12
    //
    // The chip has NOTHING outside its edge. The pane has a 20 px ramp —
    // and 34 px at elevation 3. Below the pane it peaks at 25.32 against a
    // ground of 0.00. That band is a layer by any reading, and it is on
    // every floating surface in the build because every one of them is
    // elevation 2 or 3 while every widget chip is elevation 1, where
    // Theme.e1Bloom is 0 and pane.frag's `bl` term never runs.
    //
    // Proven by toggle rather than inference. Re-rendering the launcher
    // stack with ONLY this zeroed — GlassEdge and MirrorEdge untouched —
    // made the outside profile 0.00 at every d, identical to the chip,
    // while d=0 stayed 47.54: the rim is not what goes away. Removing
    // MirrorEdge instead, or GlassEdge instead, left the 20 px ramp
    // exactly where it was, so neither of those owns it.
    //
    // ⚠ Elevation still reads as elevation. §4.3's "elevation is LIGHT,
    // never shadow" lives in the RIM ladder (e2Rim 0.88 vs e1Rim 0.58),
    // which this does not touch — measured above as the 47.54 vs 25.12 at
    // d=0. What comes off is only the glow spilling onto the desktop
    // OUTSIDE the surface, which is the part that reads as a second edge.
    //
    // A caller that assigns `bloomPx` directly overrides this, by the
    // ordinary QML rule that an assignment replaces a binding. That is
    // deliberate: MediaCrest.qml already sets `bloomPx: 0` for its own
    // reason and must keep meaning it.
    property bool bloomAtRest: true
    property real bloomPx: !pane.bloomAtRest ? 0
                         : elevation === 0 ? Theme.e0Bloom
                         : elevation === 1 ? Theme.e1Bloom
                         : elevation === 2 ? Theme.e2Bloom : Theme.e3Bloom
    property real bloomAlpha: 0.55
    property real crown: 0.42

    // 0..1. Raises the rim and widens it — this is how focus is expressed
    // everywhere in the shell (§4.4). Never a blue outline. Named
    // `focusLevel`, not `focus`: Item.focus already exists and means keyboard
    // focus, and shadowing it would silently break the real one.
    property real focusLevel: 0

    // ── the rim as a STATE CUE (TRK-3546) ────────────────────────────
    // §4.4 says focus is expressed as LIGHT, never as a second outline
    // colour, and these two keep that promise: neither adds a layer, a
    // border or a hue. They move the DISPERSION GAIN of the rim that is
    // already there — how widely this surface splits the one sweep. See
    // shaders/pane.frag's header for why a gain and never a bias.
    //
    // `live` is the signal this build did not have. Elevation already says
    // how near a surface is and `focusLevel` already says whether you are
    // pointed at it, but nothing said whether a surface is DOING anything:
    // a media chip with a track running, a recording HUD that is actually
    // recording, an update card mid-download. Those read identically to a
    // dead one, and the only fixes on offer were a badge, a label or a
    // coloured ring — all three of which this build has ruled out. A wider
    // spectrum on the rim it already draws costs no space and no new hue.
    //
    // It shares one channel with `focusLevel` deliberately (max, not sum).
    // A live surface you are also hovering is not twice as urgent, and a
    // sum would let two mild signals add up to a shout.
    property real live: 0

    // The other end: a surface that is asleep, disabled or stale collapses
    // toward the middle of the sweep and stops reading as spectral. Kept
    // separate from `enabled` because "off" and "idle" are not the same
    // claim, and a disabled control already loses its focus rim anyway.
    property real dormant: 0

    // 1.0 is the shipped rim exactly. Override for a one-off only if you
    // can say what state the number means — this is a cue, not a garnish.
    property real dispersion: Theme.rimDisp0
        + Theme.rimDispGain * Math.max(0, Math.min(1, Math.max(pane.focusLevel, pane.live)))
        - Theme.rimDispDrop * Math.max(0, Math.min(1, pane.dormant))

    // ── shape · rounded only where the surface is free ───────────────
    property int radius: Theme.r2
    property int radiusTL: radius
    property int radiusTR: radius
    property int radiusBR: radius
    property int radiusBL: radius

    // Living paint inside THIS pane, same SwirlChip the flyout pills use.
    // Default off: a Pane is also a card, a vitals block, a calendar — those
    // must not each host a solver. Row-sized buttons set this true. Rest
    // opacity and seed live in SwirlChip; this only hosts the layer.
    property bool livingPaint: false

    // Content is just a child of the Pane, declared after the material below
    // so it draws over it.
    //
    // ⚠ DO NOT reintroduce a `default property alias content: someItem.data`
    // here. A default-property alias also captures the children this file
    // declares itself, so the alias target ends up appended to its own `data`
    // list — the item becomes its own child, Qt logs "Cannot use same item on
    // different windows at the same time", and the scene graph segfaults in
    // QQuickItemPrivate::dirty() on the next sync. That crash was reproduced
    // and fixed 2026-08-03; the whole alias buys nothing here, because plain
    // children already stack above a first-declared ShaderEffect.
    ShaderEffect {
        id: material
        anchors.fill: parent
        anchors.margins: -pane.bloomPx
        fragmentShader: Qt.resolvedUrl("shaders/pane.frag.qsb")
        blending: true

        property vector4d geom: Qt.vector4d(width, height, pane.bloomPx, 0)
        property vector4d radii: Qt.vector4d(pane.radiusTL, pane.radiusTR,
                                             pane.radiusBR, pane.radiusBL)
        property vector4d body: Qt.vector4d(pane.fill.r, pane.fill.g,
                                            pane.fill.b, pane.fill.a)
        property vector4d look: Qt.vector4d(pane.rim, pane.crown,
                                            pane.bloomAlpha, pane.focusLevel)
        // yzw reserved; keep x > 0 or the shader reads the whole vector as
        // unset and falls back to the shipped gain.
        property vector4d state: Qt.vector4d(Math.max(0.02, pane.dispersion),
                                             0, 0, 0)

        Behavior on look {
            // vector4d interpolates componentwise, so rim / crown / bloom /
            // focus all ease on the one curve instead of four Behaviors.
            PropertyAnimation {
                duration: Theme.durQuick
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveMove
            }
        }

        // The spread eases on the SAME curve as the light it belongs to, so
        // a surface waking up does one thing rather than two things that
        // nearly agree. Separate Behavior only because `state` is a separate
        // uniform; the duration and curve are deliberately identical.
        Behavior on state {
            PropertyAnimation {
                duration: Theme.durQuick
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveMove
            }
        }
    }

    Loader {
        id: swirlFill
        anchors.fill: parent
        anchors.margins: 1
        z: 0
        active: pane.livingPaint && Prefs.swirlEnabled
        // URL, not `SwirlChip {}`. Naming the type here cycles with
        // SwirlChip.qml's inner Pane at load (TRK-3083) and the whole
        // shell fails to start. The chip is the same file; it is just
        // not a compile-time parent of this one.
        source: Qt.resolvedUrl("SwirlChip.qml")
        onLoaded: {
            swirlFill.item.bare = true
            swirlFill.item.cornerRadius = Math.max(0, pane.radius - 1)
        }
        Binding {
            target: swirlFill.item
            property: "width"
            value: swirlFill.width
            when: swirlFill.item
        }
        Binding {
            target: swirlFill.item
            property: "height"
            value: swirlFill.height
            when: swirlFill.item
        }
        Binding {
            target: swirlFill.item
            property: "hostHovered"
            value: swirlHov.hovered
            when: swirlFill.item
        }
        Binding {
            target: swirlFill.item
            property: "cornerRadius"
            value: Math.max(0, pane.radius - 1)
            when: swirlFill.item
        }
    }
    HoverHandler {
        id: swirlHov
        enabled: pane.livingPaint
    }
}
