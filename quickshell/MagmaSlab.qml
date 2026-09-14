pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: slab
    property bool barScale: false

    FrameAnimation {
        running: slab.visible && Prefs.swirlEnabled
        onTriggered: fx.uTime += 0.016
    }

    ShaderEffect {
        id: fx
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("shaders/magma.frag.qsb")
        property real uTime: 0
        property vector2d uRes: Qt.vector2d(Math.max(1, width), Math.max(1, height))
        // x flow · y crack width · z glow · w master (beat rides w, as designed)
        property vector4d uLook: Qt.vector4d(
            0.55 + 0.12 * Beat.pulse,
            1.15,
            1.0 + 0.45 * Beat.kick,
            1.0 + 0.28 * Beat.kick)
        // x crack scale (higher = coarser, for bar) · y shimmer · z crust dark · w quality
        property vector4d uScene: slab.barScale
            ? Qt.vector4d(2.4, 0.85, 0.55, 0.75)
            : Qt.vector4d(1.15, 1.0, 0.45, 0.85)
        property vector4d uFlags: Qt.vector4d(0, 0, 0, 0)
    }
}
