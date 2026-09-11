pragma ComponentBehavior: Bound
// Nyxus Suxyn — THE OCULAR. The third lock scene: his mark, as a constellation.
//
// Owner ruling 2026-09-05: "yes get both over to it and make sure the earth is
// saved as well i diont want it delterd."
//
// ── WHY THIS IS A SCENE AND NOT A REPLACEMENT ────────────────────────────
// That ruling has two halves and the second one is the load-bearing one. The
// lock already had a scene system — Prefs.lockScene, an enum, driven by a real
// Settings page — so this arrives as a THIRD value beside "sky" and
// "earthrise". Nothing about the Earth is deleted, disabled, moved behind a
// developer flag, or made harder to reach: LockEarth, LockGround, LockMoon,
// lockearth.frag and the NASA textures are all untouched, and "On the Moon" is
// still one tap away in Settings. His instruction is satisfied by the
// STRUCTURE rather than by anyone remembering to honour it later.
//
// ── AND IT IS WHY THE 08-12 STILLNESS RULING SURVIVES ────────────────────
// The lock has a standing ruling: no live shader, no frame clock, "a PNG cannot
// twinkle" — because TWO full-screen shaders at once lagged. This scene is
// live. That is not a reversal, because scenes are MUTUALLY EXCLUSIVE: when the
// Ocular is up, LockEarth is not drawn at all, so the two full-screen shaders
// the ruling was about can never be on screen together. The cost here is one
// full-res star field plus a quarter-res aurora — about 1.06 full-screen
// passes, against the 2.0 that caused the original complaint.
//
// ── THE THREE LAYERS, AND WHY EACH IS BUILT THE WAY IT IS ────────────────
//
// 1. THE SKY IS NOT NEW CODE. starlight.frag already does everything the brief
//    asks a star field for — power-law magnitudes, Pogson brightness, a milky
//    way band, per-star twinkle phase, spectral colour — and it is the live
//    form of the wallpaper he already runs. Writing a second, worse star field
//    next to it would have been the easy thing and the wrong one.
//
// 2. THE AURORA IS DRAWN SMALL ON PURPOSE. It renders into a quarter-size FBO
//    and is scaled up. That is a sixteenth of the fill, and the upscale's
//    bilinear filter IS the softening — a curtain wants to be soft, so the
//    cheap path and the correct path are the same path here. See aurora.frag.
//
// 3. THE CONSTELLATION IS 22 QUADS, NOT 22 EFFECTS. Each star is one baked
//    sprite (star-glow.png), tinted and scaled. A MultiEffect per star would be
//    22 offscreen passes on a surface that is already carrying a full-screen
//    shader. The positions are GENERATED from the mark's own outline —
//    ConstellationData.qml, baked by arc-length sampling off the same SVG the
//    logo is drawn from — so the figure IS the mark rather than an artist's
//    impression of it.
//
// ── THE LINES ARE MEANT TO BE ALMOST INVISIBLE ───────────────────────────
// A real constellation has no lines; they are a chart convention. They sit at
// alpha 0.055 so the figure is something you FIND in the field rather than
// something you are shown. If they read as a drawn logo, they are too bright —
// that is the failure mode, not too faint.
import QtQuick

Item {
    id: root

    // Master clock for both shaders. One timer, not two, so the aurora and the
    // sky can never drift into a beat against each other.
    property real t: 0

    // Off when the lock is down: a stopped clock is the difference between
    // costing nothing and costing a frame every 40 ms forever.
    property bool active: true

    property real auroraIntensity: 1.0

    // ── THE FRAME CLOCK ──────────────────────────────────────────────────
    // A Timer, not a FrameAnimation, and deliberately at 25 fps rather than the
    // panel's 144. Nothing in this scene moves fast: the curtains sway over
    // seconds and the stars scintillate. Driving it per-frame would cost nearly
    // six times as much to render motion nobody can distinguish. Starlight.qml
    // reached the same 40 ms for the same reason, and matching it means the two
    // surfaces cannot beat against each other.
    //
    // `% 3600` keeps uTime small. A float that has been counting since boot
    // loses the precision sin() needs and the twinkle visibly coarsens after a
    // few hours — the kind of defect that only ever appears on a machine left
    // locked overnight, which is exactly what a lock screen is.
    Timer {
        interval: 40
        repeat: true
        running: root.active && root.visible
        onTriggered: root.t = (root.t + 0.040) % 3600
    }

    // ── 0 · the ground ───────────────────────────────────────────────────
    // ⚠ THIS IS NOT DECORATION AND IT IS NOT REDUNDANT. starlight.frag is an
    // OVERLAY: it was written to hang over a wallpaper, so it writes alpha and
    // leaves genuinely transparent pixels everywhere there is no star. Without
    // an opaque floor of its own this whole scene is a transparent sheet, and
    // what shows through is whatever happens to be under it.
    //
    // That is exactly how it was found. The first two headless renders came
    // back looking like two completely different bugs — one a blizzard on
    // black, one a pale wash on white — and neither was a bug in the sky at
    // all. Both were the same transparency, composited onto whatever the viewer
    // put behind it. The scene now carries its own night.
    Rectangle {
        anchors.fill: parent
        color: "#010306"
    }

    // ── 1 · the sky ──────────────────────────────────────────────────────
    ShaderEffect {
        id: sky
        anchors.fill: parent
        // Blending ON: it composites over the ground above rather than
        // replacing it. With blending off the shader's transparent regions
        // would be written as transparent-black and punch holes in the night.
        blending: true

        property real uTime: root.t
        // ⚠ NOT 1.0. The shipped default is tuned for a HEADLINER — a ceiling
        // you look up into, where a carpet of points IS the product. Behind a
        // constellation it is a blizzard: the first render buried the Ocular
        // completely, because a figure can only read against a field sparse
        // enough to have gaps in it. This is the single most important number
        // in this file and it is a composition decision, not a performance one.
        property real uDensity: 0.42

        // z = shooting stars · w = celestial artwork.
        // ⚠ ARTWORK IS OFF, and this cost a render to learn. That gate draws
        // large amber nebula swirls, and at full strength they took over the
        // frame — warm orange ribbons across a scene whose whole palette is ice
        // and aurora, competing with the curtains for exactly the same job.
        // Shooting stars stay on: they are occasional, they are the one thing
        // that makes a still-looking sky obviously live, and they cost nothing
        // when they are not on screen.
        property vector4d uRes: Qt.vector4d(width, height, 1, 0)

        // x twinkleSpeed · y sparkle · z warmth · w master.
        // Warmth at the shipped 0.22: the field is icy white and the colour in
        // this scene comes from the aurora, not from the stars.
        // Master pulled to 0.80 so the constellation above sits clearly on top
        // of the field rather than competing with it at equal brightness.
        property vector4d uLook: Qt.vector4d(0.55, 0.75, 0.22, 0.80)

        fragmentShader: Qt.resolvedUrl("shaders/starlight.frag.qsb")
        // ⚠ Qt.resolvedUrl, never a "qrc:" literal. A qrc path resolves to
        // nothing outside a compiled resource bundle, a missing shader is NOT a
        // QML error, and the load check stays green while the item draws
        // NOTHING. That combination already cost this build the crystal mark
        // once; it is not allowed to cost it a whole sky.
    }

    // ── 2 · the aurora, rendered at a quarter and blown up ───────────────
    // The ShaderEffect itself is never displayed — it exists only to be the
    // source item. `hideSource` keeps it off screen; the ShaderEffectSource
    // below is the thing you actually see.
    Item {
        id: auroraBuf
        anchors.fill: parent
        visible: false

        ShaderEffect {
            anchors.fill: parent
            property real uTime: root.t
            property real uIntensity: root.auroraIntensity
            property real uPad: 0
            property vector4d uRes: Qt.vector4d(width, height, 0, 0)
            fragmentShader: Qt.resolvedUrl("shaders/aurora.frag.qsb")
        }
    }

    ShaderEffectSource {
        anchors.fill: parent
        sourceItem: auroraBuf
        hideSource: true
        // THE QUARTER. The FBO is a quarter on each axis, so the fragment
        // shader runs on one sixteenth of the pixels; drawing the result at
        // full size is what smooths it.
        textureSize: Qt.size(Math.max(2, Math.round(root.width / 4)),
                             Math.max(2, Math.round(root.height / 4)))
        smooth: true                          // bilinear on the way up — the blur
        live: root.active
        opacity: 0.92
    }

    // ── 3 · the Ocular ───────────────────────────────────────────────────
    // Placed in a square box so the figure keeps its proportions on any panel;
    // a constellation stretched to the aspect ratio is a squashed head.
    Item {
        id: figure
        readonly property real box: Math.min(root.width, root.height) * 0.52
        width: box
        height: box
        x: (root.width - box) / 2
        y: root.height * 0.43 - box / 2

        // the chart lines
        Repeater {
            model: ConstellationData.links
            delegate: Rectangle {
                required property var modelData
                readonly property var a: ConstellationData.stars[modelData[0]]
                readonly property var b: ConstellationData.stars[modelData[1]]
                readonly property real ax: a.x * figure.box
                readonly property real ay: a.y * figure.box
                readonly property real bx: b.x * figure.box
                readonly property real by: b.y * figure.box

                x: ax
                y: ay
                width: Math.hypot(bx - ax, by - ay)
                height: 1
                transformOrigin: Item.TopLeft
                rotation: Math.atan2(by - ay, bx - ax) * 180 / Math.PI
                color: "#96c4e0"
                opacity: 0.055                // see the header: too bright is the bug
                antialiasing: true
            }
        }

        // the stars
        Repeater {
            model: ConstellationData.stars
            delegate: Image {
                id: star
                required property var modelData
                required property int index

                readonly property bool isEye: modelData.kind === "eye"
                // The eyes are the brightest things in the figure, the way the
                // named stars of a real constellation are the ones you find it
                // by. Everything else is a little above the field.
                readonly property real px: isEye ? figure.box * 0.115
                                                 : figure.box * 0.075

                source: Qt.resolvedUrl("star-glow.png")
                sourceSize.width: 128
                sourceSize.height: 128
                width: px
                height: px
                x: modelData.x * figure.box - px / 2
                y: modelData.y * figure.box - px / 2
                smooth: true
                // Tint: the eyes ice, the outline a cooler white, matching the
                // mark's own two-tone rather than inventing a third colour.
                // Set on the Image so one baked sprite serves every star.
                property color tint: isEye ? "#eaf7ff" : "#cfe4f2"

                opacity: isEye ? 0.98 : 0.78

                // Twinkle. Each star gets its own period from its index, so
                // nothing pulses in unison — a synchronised field reads as a
                // blinking string of lights within about two seconds.
                SequentialAnimation on opacity {
                    running: root.active
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: star.isEye ? 0.86 : 0.52
                        duration: 1400 + (star.index * 337) % 2600
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: star.isEye ? 0.98 : 0.78
                        duration: 1700 + (star.index * 521) % 2900
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }

    // The chart caption. A constellation has a name, and naming it is what
    // turns a scatter of stars into a thing you recognise.
    Text {
        anchors.horizontalCenter: figure.horizontalCenter
        anchors.top: figure.bottom
        // ⚠ Positive, and it was negative. The figure's box is a SQUARE that
        // circumscribes the head, and the head's chin reaches nearly to the
        // bottom of it — so pulling the caption UP by 6% of the box put the
        // words across the chin. A chart caption sits below the figure it
        // names, and here "below the box" and "below the head" are the same
        // place only if the margin is positive.
        anchors.topMargin: figure.box * 0.04
        text: qsTr("The Ocular")
        color: "#96c4e0"
        opacity: 0.30
        font.family: Theme.fontDisplay !== undefined ? Theme.fontDisplay : "sans-serif"
        font.pixelSize: Math.max(11, figure.box * 0.035)
        font.letterSpacing: 3.2
    }
}
