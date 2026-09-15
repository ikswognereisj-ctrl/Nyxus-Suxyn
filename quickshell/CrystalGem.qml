pragma ComponentBehavior: Bound
// One stone: ocular crystal on ICE, hardened magma on MAGMA.
// Same TILE SDF. App mark laser-etched in the face.
import Quickshell
import QtQuick

Item {
    id: gem

    property bool hot: false
    property bool on: false
    property bool danger: false
    property color tint: Theme.lookPale
    property real lookX: 0
    property real lookY: 0
    property string iconName: ""
    property url markUrl: ""
    property int iconPx: 0

    property real t: 0
    Timer {
        interval: 40
        repeat: true
        running: gem.visible && gem.hot
        onTriggered: gem.t = (gem.t + 0.040) % 3600
    }

    Image {
        id: sdfImg
        visible: false
        source: Qt.resolvedUrl("textures/ocular-tile-sdf.png")
        mipmap: false
        cache: true
    }
    Image {
        id: markImg
        visible: false
        source: gem.markUrl != ""
                ? gem.markUrl
                : (gem.iconName.length
                   ? Quickshell.iconPath(gem.iconName, "application-x-executable")
                   : Qt.resolvedUrl("textures/ocular-tile-eyes.png"))
        sourceSize.width: 128
        sourceSize.height: 128
        // Mipmaps for BRAND ART ONLY: the sigil's hairline crescent/stars
        // fall between texel fetches without mip levels — but app glyph
        // strokes average against transparent black and wash to gray.
        mipmap: gem.markUrl != ""
        cache: true
        asynchronous: true
    }

    ShaderEffect {
        id: fxIce
        anchors.fill: parent
        blending: true
        visible: !Theme.lookMagma
        fragmentShader: Qt.resolvedUrl("shaders/ocular_crystal.frag.qsb")
        property real uT: gem.t
        property vector2d uPtr: Qt.vector2d(gem.lookX, gem.lookY)
        property vector2d uRes: Qt.vector2d(Math.max(1, width), Math.max(1, height))
        property real uDrift: gem.hot ? 0.18 : 0.0
        property real uEyeBoost: gem.hot ? 1.85 : (gem.on ? 1.45 : 1.20)
        property vector3d uEyeCol: gem.danger
            ? Qt.vector3d(1.00, 0.47, 0.28)
            : (gem.on || gem.hot
               ? Qt.vector3d(gem.tint.r, gem.tint.g, gem.tint.b)
               : Qt.vector3d(0.72, 0.93, 1.00))
        property var uSdf: sdfImg
        property var uEyes: markImg
        Behavior on uDrift    { NumberAnimation { duration: Theme.durBase } }
        Behavior on uEyeBoost { NumberAnimation { duration: Theme.durQuick } }
    }

    ShaderEffect {
        id: fxMagma
        anchors.fill: parent
        blending: true
        visible: Theme.lookMagma
        fragmentShader: Qt.resolvedUrl("shaders/hardened_magma.frag.qsb")
        property real uT: gem.t
        property vector2d uPtr: Qt.vector2d(gem.lookX, gem.lookY)
        property vector2d uRes: Qt.vector2d(Math.max(1, width), Math.max(1, height))
        property real uDrift: gem.hot ? 0.18 : 0.0
        property real uEyeBoost: gem.hot ? 1.85 : (gem.on ? 1.45 : 1.20)
        // TRK-4148 — the resting arm of this was `Theme.magmaEmber`, one
        // constant for every gem in the build, so a tile only ever showed its
        // own colour while the pointer sat on it. `GlassTile` has always
        // passed the per-app colour down (`tint: tile.coreTint`) and
        // `tileCore()` has always handed out a different one per app, so the
        // identity was computed, delivered, and then dropped for every tile
        // that was not being hovered. Hover is the wrong moment to tell
        // someone which app they are looking at -- by then they have found it.
        // On its own this line changes nothing visible, and was measured
        // doing exactly that: the tint reached `hardened_magma.frag` and died
        // on a hardcoded ladder top. It only means anything paired with the
        // TRK-4148 change in that shader, and the two ship together.
        // `on`/`hot` keep their real job, the brightness lift through
        // `uEyeBoost` directly above. `tint` already defaults to
        // `Theme.lookPale`, so a tile naming no colour still lands inside the
        // look rather than on a hardcoded hex. ICE is untouched: its resting
        // pale IS the glacier read, and its glyph keeps its own colour
        // through, so ICE never lost the distinction in the first place.
        property vector3d uEyeCol: gem.danger
            ? Qt.vector3d(1.00, 0.47, 0.28)
            : Qt.vector3d(gem.tint.r, gem.tint.g, gem.tint.b)
        // An explicit markUrl is brand art (the sigil): verbatim, never
        // plate-gated. App icons stay etched — plate dropped, glyph kept.
        property real uMarkMode: gem.markUrl != "" ? 1.0 : 0.0
        property var uSdf: sdfImg
        property var uEyes: markImg
        Behavior on uDrift    { NumberAnimation { duration: Theme.durBase } }
        Behavior on uEyeBoost { NumberAnimation { duration: Theme.durQuick } }
    }
}
