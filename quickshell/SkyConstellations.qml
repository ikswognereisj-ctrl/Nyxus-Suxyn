// ╔══════════════════════════════════════════════════════════════════════╗
// ║  SkyConstellations — a few real constellations on the idle screen     ║
// ╚══════════════════════════════════════════════════════════════════════╝
//
// Owner, 2026-09-07: "when the screen goes idle and it shows that screen and
// the clock ... can we add in the stars on that screen a few constellations,
// simple yet nice looking".
//
// ── WHAT THIS IS AND WHAT IT DELIBERATELY IS NOT ────────────────────────
//
// `Screensaver.qml` argues, at length and correctly, that a saver carrying a
// weather cluster and a media widget "is a lock screen without the password,
// and this build already has a very good lock screen". Nothing here is a
// widget. These are figures IN THE SKY the saver already draws — the same
// class of thing as the twinkle, not a new surface sitting on top of it.
//
// ⚠ STATIC ON PURPOSE — NO ANIMATION, NO TIMER, NO BINDING THAT TICKS.
// The saver runs unattended for HOURS on a panel nobody is watching, which is
// why its own clock is `SystemClock.Minutes` (60 wakeups an hour instead of
// 3600). A twinkling constellation would undo that reasoning for decoration.
// `HeadlinerSky` already twinkles behind these and already stops under
// `Prefs.reducedMotion`; the figures simply sit in it. Zero scheduled frames.
//
// ── THE HOUSE STYLE, TAKEN FROM LockOcular RATHER THAN INVENTED ─────────
//
// `LockOcular.qml` draws the alien mark as a constellation and has already
// solved this: chart lines are thin rotated Rectangles in glacier[4]->glacier[5]
// at 0.68 (Theme.mix) at opacity 0.055, with the comment "see the header: too
// bright is the bug", and stars
// are one baked `star-glow.png` sprite tinted per role. Same sprite, same
// line colour, same restraint here. The lock's figure is the ALIEN MARK and
// stays the lock's alone — these are real sky, so the two screens never show
// the same picture.
//
// ⚠ THE FIGURES AVOID THE CENTRE. The saver's clock is 112 px of Orbitron
// dead centre, and a chart line crossing a numeral is the one way this reads
// as clutter rather than sky. Every placement below keeps its box out of the
// middle band; see `zones`.
import QtQuick
// No `import qs`: this draws with literals from LockOcular's own
// palette and reads no Prefs or Theme token, so it stays plain Qt
// Quick -- which also means it can be rendered outside Quickshell to
// check the figures, which is how the placements below were judged.

Item {
    id: root
    anchors.fill: parent

    // The saver may sit for hours; nothing here should paint while hidden.
    property bool active: true
    visible: active

    // ── the figures ─────────────────────────────────────────────────────
    //
    // Coordinates are normalised 0..1 INSIDE EACH FIGURE'S OWN BOX, the same
    // convention `ConstellationData.qml` uses, so a figure can be placed and
    // scaled without touching its shape. `links` index into `stars`.
    //
    // These are the real sky, not decoration invented to look like it: the
    // seven stars of the Plough, Orion's shoulders-belt-feet, and the five of
    // Cassiopeia's W. `bright` marks the stars you actually find the figure
    // by — Betelgeuse, Rigel, Dubhe, Schedar — which get the larger sprite,
    // exactly as LockOcular gives the mark's eyes the brighter one.
    readonly property var figures: [
        {
            "name": "Ursa Major",         // the Plough / Big Dipper
            "stars": [
                { "x": 0.90, "y": 0.16, "bright": true  },   // Dubhe
                { "x": 0.88, "y": 0.46, "bright": false },   // Merak
                { "x": 0.66, "y": 0.52, "bright": false },   // Phecda
                { "x": 0.68, "y": 0.26, "bright": false },   // Megrez
                { "x": 0.47, "y": 0.24, "bright": false },   // Alioth
                { "x": 0.28, "y": 0.30, "bright": false },   // Mizar
                { "x": 0.08, "y": 0.44, "bright": true  }    // Alkaid
            ],
            // bowl, then the handle out to Alkaid
            "links": [[0,1],[1,2],[2,3],[3,0],[3,4],[4,5],[5,6]]
        },
        {
            "name": "Orion",
            "stars": [
                { "x": 0.74, "y": 0.10, "bright": true  },   // Betelgeuse
                { "x": 0.26, "y": 0.16, "bright": false },   // Bellatrix
                { "x": 0.61, "y": 0.50, "bright": false },   // Alnitak
                { "x": 0.50, "y": 0.48, "bright": false },   // Alnilam
                { "x": 0.39, "y": 0.46, "bright": false },   // Mintaka
                { "x": 0.68, "y": 0.90, "bright": false },   // Saiph
                { "x": 0.22, "y": 0.94, "bright": true  }    // Rigel
            ],
            // shoulders, the belt, and down each leg
            "links": [[0,1],[4,3],[3,2],[0,2],[1,4],[2,5],[4,6]]
        },
        {
            "name": "Cassiopeia",
            "stars": [
                { "x": 0.06, "y": 0.28, "bright": false },   // Segin
                { "x": 0.30, "y": 0.66, "bright": false },   // Ruchbah
                { "x": 0.52, "y": 0.22, "bright": false },   // Gamma Cas
                { "x": 0.74, "y": 0.64, "bright": true  },   // Schedar
                { "x": 0.95, "y": 0.30, "bright": false }    // Caph
            ],
            "links": [[0,1],[1,2],[2,3],[3,4]]
        }
    ]

    // ── placement ───────────────────────────────────────────────────────
    //
    // x/y are the box's TOP-LEFT as a fraction of the screen, w is its width
    // as a fraction; height follows from the aspect so a figure is never
    // stretched. Kept clear of the centre band where the 112 px clock sits.
    readonly property var zones: [
        { "x": 0.045, "y": 0.085, "w": 0.30, "aspect": 0.52 },  // Plough, top left
        { "x": 0.700, "y": 0.560, "w": 0.24, "aspect": 1.05 },  // Orion, lower right
        { "x": 0.690, "y": 0.075, "w": 0.21, "aspect": 0.55 }   // Cassiopeia, top right
    ]

    Repeater {
        model: root.figures.length

        delegate: Item {
            id: figure
            required property int index

            // ⚠ NOT `data`. `data` is Item's own read-only default-children
            // property, so declaring it here does not shadow anything -- it
            // fails to compile, which fails Screensaver, which fails
            // shell.qml, which means THE WHOLE SHELL REFUSES TO LOAD: no
            // bar, no widgets, no desktop. qmllint passed it and so did I.
            readonly property var fig: root.figures[figure.index]
            readonly property var zone: root.zones[figure.index]

            x: zone.x * root.width
            y: zone.y * root.height
            width: zone.w * root.width
            height: width * zone.aspect

            // the chart lines
            Repeater {
                model: figure.fig.links
                delegate: Rectangle {
                    required property var modelData
                    readonly property var a: figure.fig.stars[modelData[0]]
                    readonly property var b: figure.fig.stars[modelData[1]]
                    readonly property real ax: a.x * figure.width
                    readonly property real ay: a.y * figure.height
                    readonly property real bx: b.x * figure.width
                    readonly property real by: b.y * figure.height

                    x: ax
                    y: ay
                    width: Math.hypot(bx - ax, by - ay)
                    height: 1
                    transformOrigin: Item.TopLeft
                    rotation: Math.atan2(by - ay, bx - ax) * 180 / Math.PI
                    // glacier[4] -> glacier[5] at 0.68 = #96c5da; the file
                    // used to spell #96c4e0, within 6/255 on one channel.
                    color: Theme.mix(Theme.paintLayers.glacier[4], Theme.paintLayers.glacier[5], 0.68)
                    // LockOcular's exact value. Its header earned it: brighter
                    // reads as a diagram drawn ON the sky instead of a figure
                    // found IN it.
                    opacity: 0.055
                    antialiasing: true
                }
            }

            // the stars
            Repeater {
                model: figure.fig.stars
                delegate: Image {
                    required property var modelData

                    readonly property real px: modelData.bright
                                               ? figure.width * 0.085
                                               : figure.width * 0.055

                    // The same baked sprite the lock's figure uses -- one
                    // texture for every star on either screen.
                    source: Qt.resolvedUrl("star-glow.png")
                    sourceSize.width: 128
                    sourceSize.height: 128
                    width: px
                    height: px
                    x: modelData.x * figure.width - px / 2
                    y: modelData.y * figure.height - px / 2
                    smooth: true
                    // Named stars ice, the rest a cooler white -- LockOcular's
                    // two-tone rather than a third colour invented here.
                    // glacier[6] ice PEAK / glacier[5] ice PALE, from the ramp
                    // rather than spelled here (was #eaf7ff / #cfe4f2).
                    property color tint: modelData.bright
                        ? Theme.paintLayers.glacier[6]
                        : Theme.paintLayers.glacier[5]
                    // Low enough to sit IN the shader sky rather than on it.
                    // The sky's own stars peak well under full brightness; a
                    // figure that outshines them stops being part of the field.
                    opacity: modelData.bright ? 0.42 : 0.30
                }
            }
        }
    }
}
