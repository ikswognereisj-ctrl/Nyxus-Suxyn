// NYXUS Suxyn — the ocular mark as a live surface.
// Drop-in for the Quickshell greeter, or any QML host that wants the mark
// alive rather than as a PNG. For a still mark set `drift: 0`.
import QtQuick

Item {
    id: root
    implicitWidth: 320
    implicitHeight: 320

    // 0 holds the pose (login screen); 1 lets it turn on its own.
    property real drift: 0.0
    // view angle, -1..1 each. Wire to a MouseArea if you want it to follow.
    property vector2d viewAngle: Qt.vector2d(0.0, -0.12)
    property bool running: true
    // relative to THIS file. Override if the .qsb lands elsewhere in the bundle.
    property string shaderPath: "shaders/ocular_crystal.frag.qsb"

    // eye colour + gain, so the mark can carry auth state
    property color eyeColor: Qt.rgba(0, 0, 0, 1)   // black = use the shader default
    property real  eyeBoost: 1.0

    Image {
        id: sdf
        source: "nyxus-mark-sdf.png"   // R=distance G=height-hi B=height-lo A=255
        visible: false
        // ⚠ MUST NOT be filtered to a different size or the distance field
        // stops being metric. Keep it 1:1 and let the shader do the scaling.
        smooth: true
        mipmap: false
    }

    Image {
        id: eyeMask
        source: "nyxus-mark-eyes.png"
        visible: false
        smooth: true
        mipmap: false
    }

    ShaderEffect {
        anchors.fill: parent
        blending: true
        // qsb-compiled; see shell/shaders/build.sh
        //
        // ⚠ NOT qrc:. A qrc: path resolves ONLY when the shader has been
        // compiled into a Qt resource bundle. Quickshell loads a config from a
        // plain DIRECTORY (`qs -p <dir>/shell.qml`), where qrc: resolves to
        // nothing — and a missing shader is not a type, property or binding
        // error, so ShaderEffect renders NOTHING, silently. No warning, and a
        // static load check stays green while the mark is simply absent.
        // Qt.resolvedUrl works in both cases, so there is never a reason to
        // prefer qrc: here. (Found by the pre-release audit seat, the only way
        // it can be found: by screenshotting the result.)
        fragmentShader: Qt.resolvedUrl(root.shaderPath)

        property variant uSdf: sdf
        property variant uEyes: eyeMask
        // FrameAnimation.elapsed is undefined while stopped, and with drift 0
        // it never starts — binding it raw assigns undefined to a double every
        // frame. Guarded.
        property real uT: anim.running ? anim.elapsed : 0
        property vector2d uPtr: root.viewAngle
        property vector2d uRes: Qt.vector2d(width, height)
        property real uDrift: root.drift
        property real uEyeBoost: root.eyeBoost
        property vector3d uEyeCol: Qt.vector3d(root.eyeColor.r, root.eyeColor.g, root.eyeColor.b)
    }

    FrameAnimation {
        id: anim
        running: root.running && root.drift > 0.0
    }
}
