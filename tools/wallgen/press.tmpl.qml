import QtQuick
import QtQuick.Window

// Nyxus Suxyn — offscreen material press.
//
// Renders a list of shader passes to PNG, one after another, inside a
// single GPU session. Driven by /tmp/wallgen/spec.json so the Python side
// owns the recipes and this file never needs editing per wall.
//
// Why a Window at all: QT_QPA_PLATFORM=offscreen has no RHI pipeline on
// this host and every ShaderEffect renders pure black (measured). A real
// GPU context is required, so this runs nested under `cage`. cage sizes
// the window to its own output, which is NOT the wallpaper size, so the
// canvas Item is pinned to the requested pixel size and given
// `layer.enabled` — that forces its own FBO at full item size and makes
// the grab independent of the window it happens to be clipped by.

Window {
    id: win
    visible: true
    width: 640
    height: 400
    color: "black"
    title: "nyxus-material-press"

    property var spec: SPEC_JSON_HERE
    property int idx: -1
    property int shots: 0

    Item {
        id: canvas
        width: win.spec.length > 0 ? (win.spec[Math.max(0, win.idx)].w || 1920) : 1920
        height: win.spec.length > 0 ? (win.spec[Math.max(0, win.idx)].h || 1200) : 1200
        layer.enabled: true
        layer.smooth: true

        Rectangle {
            anchors.fill: parent
            color: (win.idx >= 0 && win.spec[win.idx].bgcolor) ? win.spec[win.idx].bgcolor : "#000000"
        }

        Loader {
            id: passLoader
            anchors.fill: parent
            active: win.idx >= 0
            sourceComponent: (win.idx >= 0 && win.spec[win.idx].res4) ? shaderPass4 : shaderPass
        }
    }

    Component {
        id: shaderPass
        ShaderEffect {
            id: fx
            property var p: win.spec[win.idx]
            fragmentShader: Qt.resolvedUrl(p.shader)
            blending: false

            // Every shader in this build draws from a std140 block whose
            // members are a subset of these names. Declaring the union is
            // safe: Qt only binds the ones the compiled .qsb actually
            // declares, and ignores the rest.
            property real uTime: p.uTime !== undefined ? p.uTime : 0
            property vector2d uRes: Qt.vector2d(width, height)
            property vector4d uLook: p.uLook ? Qt.vector4d(p.uLook[0], p.uLook[1], p.uLook[2], p.uLook[3]) : Qt.vector4d(1, 1, 1, 1)
            property vector4d uScene: p.uScene ? Qt.vector4d(p.uScene[0], p.uScene[1], p.uScene[2], p.uScene[3]) : Qt.vector4d(1, 1, 1, 1)
            property vector4d uFlags: p.uFlags ? Qt.vector4d(p.uFlags[0], p.uFlags[1], p.uFlags[2], p.uFlags[3]) : Qt.vector4d(0, 0, 0, 0)

            property real u_time: p.uTime !== undefined ? p.uTime : 0
            property vector2d u_resolution: Qt.vector2d(width, height)
            property vector2d u_mouse: Qt.vector2d(0, 0)
            property vector4d u_look: p.uLook ? Qt.vector4d(p.uLook[0], p.uLook[1], p.uLook[2], p.uLook[3]) : Qt.vector4d(1, 1, 1, 1)
            property vector4d u_scene: p.uScene ? Qt.vector4d(p.uScene[0], p.uScene[1], p.uScene[2], p.uScene[3]) : Qt.vector4d(1, 1, 1, 1)
            property vector4d u_flags: p.uFlags ? Qt.vector4d(p.uFlags[0], p.uFlags[1], p.uFlags[2], p.uFlags[3]) : Qt.vector4d(0, 0, 0, 0)
            property vector4d u_groundTop: p.gTop ? Qt.vector4d(p.gTop[0], p.gTop[1], p.gTop[2], 1) : Qt.vector4d(0, 0, 0, 1)
            property vector4d u_groundMid: p.gMid ? Qt.vector4d(p.gMid[0], p.gMid[1], p.gMid[2], 1) : Qt.vector4d(0, 0, 0, 1)
            property vector4d u_groundDeep: p.gDeep ? Qt.vector4d(p.gDeep[0], p.gDeep[1], p.gDeep[2], 1) : Qt.vector4d(0, 0, 0, 1)
            property vector4d u_groundEdge: p.gEdge ? Qt.vector4d(p.gEdge[0], p.gEdge[1], p.gEdge[2], 1) : Qt.vector4d(0, 0, 0, 1)

            property real uIntensity: p.uIntensity !== undefined ? p.uIntensity : 1.0
            property real uPad: 0
        }
    }

    // headliner.frag declares `uRes` as a vec4 (x,y size · z point gauge in
    // device px). magma.frag declares it as a vec2. A QML property cannot
    // change type per instance, so the two shapes get two components and the
    // recipe picks with `res4`.
    Component {
        id: shaderPass4
        ShaderEffect {
            id: fx4
            property var p: win.spec[win.idx]
            fragmentShader: Qt.resolvedUrl(p.shader)
            blending: false
            property real uTime: p.uTime !== undefined ? p.uTime : 0
            property vector4d uRes: Qt.vector4d(width, height,
                                                p.gauge !== undefined ? p.gauge : 1.0, 0)
            property vector4d uLook: p.uLook ? Qt.vector4d(p.uLook[0], p.uLook[1], p.uLook[2], p.uLook[3]) : Qt.vector4d(1, 1, 1, 1)
        }
    }

    // One frame of settle per pass. The shaders are all pure functions of
    // uTime, so there is nothing to converge — but the Loader has to build
    // and the FBO has to be sized before the grab is meaningful.
    Timer {
        id: step
        interval: 260
        repeat: false
        onTriggered: {
            canvas.grabToImage(function (r) {
                var p = win.spec[win.idx];
                var ok = r.saveToFile(p.out);
                console.log("PRESS " + (ok ? "ok   " : "FAIL ") + p.out);
                if (ok)
                    win.shots++;
                win.next();
            }, Qt.size(canvas.width, canvas.height));
        }
    }

    function next() {
        if (win.idx + 1 >= win.spec.length) {
            console.log("PRESSED " + win.shots + "/" + win.spec.length);
            Qt.exit(win.shots === win.spec.length ? 0 : 3);
            return;
        }
        win.idx++;
        step.restart();
    }

    Component.onCompleted: win.next()
}
