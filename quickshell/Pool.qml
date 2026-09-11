// Nyxus Suxyn — the Pool. Light standing on a baseline.
//
// HORIZON §4.3 says elevation is LIGHT, never shadow: a thing that is nearer
// to you emits more. `Pane` expresses that for a surface, as a rim and an
// outer bloom. The Pool is the same rule for something that is not a surface
// at all — a dock icon, a tile, a lit toggle — where the light does not
// surround the object, it stands underneath it and spreads on the floor.
//
// This is the primitive that lets the Row show state without drawing a chip
// behind an icon (§2, "the Row"), and it is what makes hover read as physical
// rather than as a colour change.
//
// Three stacked domes rather than one blurred sprite: the falloff is a
// gradient the scene graph draws directly, so a Pool costs no offscreen
// texture, no layer, and no frames — it can sit under every dock icon and the
// horizon still sleeps.
//
// Cheap enough to leave mounted and drive `strength` from 0; at 0 the whole
// item is invisible and free.
import QtQuick

Item {
    id: pool

    // Where on the sweep this light belongs. Callers pass `Theme.sweepAt(x)`
    // so a pool is automatically the right hue for where it is on screen.
    property color tone: Theme.sweep2
    // The hue at the HOTTEST point of the pool. Defaults to `tone`, so every
    // caller that does not set it gets exactly the light it got before this
    // property existed — the three bands all resolve to one colour and the
    // mix below is the identity. Only set it when the core is a different
    // hue from the wash: the galaxy-tp toggle glows purple and burns magenta
    // at its centre, which is one pool with two hues, not two pools stacked.
    property color coreTone: pool.tone
    // 0 = dark, 1 = full. Animated by the caller's state, not by a timer.
    property real strength: 0
    // Splits the light between a broad wash and a tight core. 0 is all wash
    // (an ambient glow), 1 is all core (a spotlight).
    property real focusRatio: 0.5

    visible: strength > 0.005
    opacity: Math.max(0, Math.min(1, strength))

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.durBase
            easing.type: Easing.Bezier
            easing.bezierCurve: Theme.curveMove
        }
    }

    Repeater {
        model: [
            { w: 1.00, h: 1.00, a: 0.13, core: 0.0 },
            { w: 0.58, h: 0.72, a: 0.17, core: 0.5 },
            { w: 0.26, h: 0.44, a: 0.30, core: 1.0 }
        ]
        // Positioned against `pool` explicitly rather than with
        // `anchors.*: parent.*`. A Repeater delegate has a null `parent` for
        // the instant between construction and insertion, and anchoring to it
        // throws "Cannot read property 'bottom' of null" on every single
        // delegate, every time one is built — which, with a Pool under every
        // dock icon and every tile, is thousands of lines of log noise that
        // would bury the next real error. Caught by running the shell, not by
        // the linter.
        delegate: Rectangle {
            id: dome
            required property var modelData
            x: (pool.width - width) / 2
            y: pool.height - height
            width: Math.max(2, pool.width * dome.modelData.w)
            height: Math.max(2, pool.height * dome.modelData.h)
            radius: width / 2
            // A tight band contributes more when the caller wants a spotlight,
            // the broad wash more when it wants ambience.
            readonly property real weight:
                1.0 + (dome.modelData.core - 0.5) * 2.0 * (pool.focusRatio - 0.5)
            // The band's hue: the broad wash is `tone`, the tight core is
            // `coreTone`, and the middle band is genuinely the mixture rather
            // than one or the other — three stacked domes with a hard hue
            // step between them would read as a ring, not as a hot centre.
            // `modelData.core` is already 0 / 0.5 / 1 across the bands, so it
            // is the mix parameter with no second table to keep in sync.
            // With `coreTone` unset this is `mix(tone, tone, …)` = `tone`,
            // i.e. the identity, so nothing that existed before moves.
            readonly property color bandTone:
                Theme.mix(pool.tone, pool.coreTone, dome.modelData.core)
            gradient: Gradient {
                GradientStop { position: 0.00; color: Theme.soften(dome.bandTone, 0.0) }
                GradientStop {
                    position: 1.00
                    color: Theme.soften(dome.bandTone,
                                        dome.modelData.a * Math.max(0.0, dome.weight))
                }
            }
        }
    }
}
