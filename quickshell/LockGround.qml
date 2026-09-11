// Nyxus Suxyn — the lunar ground you are standing on. EARTHRISE.
//
// Owner ask, 2026-08-24, with reference photographs: put the camera on the
// Moon, keep the Earth in view above the horizon, still turning. This is the
// foreground. `shaders/lockground.frag` is the picture and its header explains
// why the surface is generated rather than sampled.
//
// It is deliberately a SEPARATE component from LockMoon. They answer different
// questions — "where is the moon tonight" and "what am I standing on" — and a
// single component doing both would carry two sets of unrelated state and a
// mode flag deciding which half is live.
//
// ⛔ One draw a minute, like everything else on this surface. The sun moves
// across the lunar sky at half a degree an hour; nothing here needs a frame
// clock, and the lock screen has one job.
//
// © 2026 JOSEPH A. SIERENGOWSKI · NYX-J5W-2026-SIERENGOWSKI-LOCKED

import QtQuick

Item {
    id: ground

    // Where the horizon sits, as a fraction of the surface height. Lower than
    // half: the reference photographs give the sky most of the frame, because
    // the Earth is the subject and the ground is what tells you where you are.
    property real horizon: 0.66

    // Eye height in metres, which is what sets how fast the ground rushes away.
    // ~1.6 m is a person standing; larger reads as a hillside seen from higher
    // up and flattens the foreshortening.
    property real eyeHeight: 1.6

    // Sagitta of the horizon arc. The Moon's radius is 1737 km and the horizon
    // from eye height is ~2.4 km, so the curve is genuinely visible. This is
    // the number to change if it ever reads as too much.
    property real curve: 0.045

    // How tall the terrain is. Turn it down for a flatter mare, up for
    // highlands.
    property real relief: 1.0

    // The sun, in the SAME view space the Earth is lit in — handed in by
    // Lock.qml from LockEarth.sunView, so one sun lights the whole frame.
    property vector3d sun: Qt.vector3d(0.4, 0.55, 0.7)

    // Fill light bounced off the Earth. On a real lunar surface with a big
    // Earth overhead this is the only thing keeping shadows off pure black.
    property real earthshine: 0.06

    property color tone: Qt.rgba(1.0, 0.99, 0.97, 1.0)
    property real master: 1.0

    opacity: ground.master
    visible: ground.master > 0.001

    ShaderEffect {
        anchors.fill: parent
        blending: true            // the sky above the horizon stays the wallpaper
        fragmentShader: Qt.resolvedUrl("shaders/lockground.frag.qsb")

        property vector4d uRes:  Qt.vector4d(width, height, 0, 0)
        property vector4d uGeom: Qt.vector4d(ground.horizon, ground.eyeHeight,
                                             ground.curve, ground.relief)
        property vector4d uSun:  Qt.vector4d(ground.sun.x, ground.sun.y, ground.sun.z, 0)
        property vector4d uTone: Qt.vector4d(ground.tone.r, ground.tone.g,
                                             ground.tone.b, ground.earthshine)
    }
}
