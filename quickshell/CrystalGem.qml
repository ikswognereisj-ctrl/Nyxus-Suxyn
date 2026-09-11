pragma ComponentBehavior: Bound
// One stone: ocular crystal TILE with the app mark laser-etched in the
// face (not a theme icon sitting on top of a well).
import Quickshell
import QtQuick

Item {
    id: gem

    property bool hot: false
    property bool on: false
    property bool danger: false
    property color tint: Theme.plumGlow
    property real lookX: 0
    property real lookY: 0
    property string iconName: ""
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
        source: gem.iconName.length
                ? Quickshell.iconPath(gem.iconName, "application-x-executable")
                : Qt.resolvedUrl("textures/ocular-tile-eyes.png")
        sourceSize.width: 128
        sourceSize.height: 128
        mipmap: false
        cache: true
        asynchronous: true
    }

    ShaderEffect {
        id: fx
        anchors.fill: parent
        blending: true
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
}
