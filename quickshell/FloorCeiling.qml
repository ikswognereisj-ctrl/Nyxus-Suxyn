pragma ComponentBehavior: Bound
import QtQuick
import QtQuick3D

// Glow stickers + ceiling flyers. HeadlinerSky plane stays in Floor3D.
Node {
    id: root
    property real t: 0
    property real pulse: 1
    property real pulseB: 1
    property Item starTex
    property Item moonTex
    property Item planetTex
    property Item shootTex
    property Item rocketTex

    // Stars — hash scatter, not a grid.
    Repeater3D {
        model: 128
        Model {
            required property int index
            readonly property real s: 0.35 + ((index * 31 + 5) % 31) / 100
            source: "#Rectangle"
            position: Qt.vector3d(
                -1300 + ((index * 73 + 19) % 2600),
                549,
                -1100 + ((index * 47 + 11) % 2200))
            eulerRotation: Qt.vector3d(90, (index * 37 + 8) % 360, 0)
            scale: Qt.vector3d(s, s, 1)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColorMap: Texture { sourceItem: root.starTex }
                emissiveFactor: Qt.vector3d(0.55 + 0.45 * root.pulse, 0.9, 0.35)
            }
        }
    }

    Repeater3D {
        model: 18
        Model {
            required property int index
            readonly property real s: 0.48 + ((index * 19 + 3) % 18) / 100
            source: "#Rectangle"
            position: Qt.vector3d(
                -1300 + ((index * 97 + 41) % 2600),
                547,
                -1100 + ((index * 61 + 23) % 2200))
            eulerRotation: Qt.vector3d(90, (index * 51 + 14) % 360, 0)
            scale: Qt.vector3d(s, s, 1)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColorMap: Texture { sourceItem: root.moonTex }
                emissiveFactor: Qt.vector3d(0.5, 0.95 * root.pulseB, 0.4)
            }
        }
    }

    Repeater3D {
        model: 14
        Model {
            required property int index
            readonly property real s: 0.52 + ((index * 23 + 9) % 14) / 100
            source: "#Rectangle"
            position: Qt.vector3d(
                -1300 + ((index * 113 + 7) % 2600),
                545,
                -1100 + ((index * 89 + 53) % 2200))
            eulerRotation: Qt.vector3d(90, (index * 29 + 21) % 360, 0)
            scale: Qt.vector3d(s, s, 1)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColorMap: Texture { sourceItem: root.planetTex }
                emissiveFactor: Qt.vector3d(0.45, 0.85, 0.5 * root.pulse)
            }
        }
    }

    // Pale-green vinyl rockets, different lanes and phases.
    Repeater3D {
        model: 0
        Model {
            required property int index
            readonly property real spd: 32 + index * 11
            readonly property real span: 2500
            readonly property real phase: (root.t * spd + index * 640) % span
            readonly property real x: (index % 2 === 0) ? (-1250 + phase) : (1250 - phase)
            readonly property real z: -780 + index * 280
                                      + Math.sin(root.t * (0.2 + index * 0.08) + index * 1.7) * (240 + index * 30)
            source: "#Rectangle"
            position: Qt.vector3d(x, 552, z)
            eulerRotation: Qt.vector3d(90, (index % 2 === 0) ? 0 : 180, -26 - index * 6)
            scale: Qt.vector3d(0.78, 0.98, 1)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColorMap: Texture { sourceItem: root.rocketTex }
                emissiveFactor: Qt.vector3d(0.42, 0.9, 0.36)
            }
        }
    }

    // Shooting stars — unique speed/seed/period/path; off for part of each cycle.
    Repeater3D {
        model: 0
        Model {
            required property int index
            readonly property real seed: index * 173 + 29
            readonly property real speed: 0.62 + index * 0.19
            readonly property real period: 8 + (index * 5) % 13
            readonly property real travel: 1.4 + (index % 4) * 0.45
            readonly property real u: (root.t * speed + seed) % period
            readonly property bool on: u < travel
            readonly property real frac: on ? u / travel : 0
            readonly property real x0: -1300 + ((index * 91 + 13) % 480)
            readonly property real z0: -1050 + ((index * 67 + 29) % 1900)
            readonly property real x1: 820 + ((index * 53 + 7) % 480)
            readonly property real z1: -850 + ((index * 79 + 41) % 1700)
            readonly property real dx: (index % 2 === 0) ? (x1 - x0) : (x0 - x1)
            readonly property real dz: (index % 3 === 0) ? (z0 - z1) : (z1 - z0)
            readonly property real sx: (index % 2 === 0) ? x0 : x1
            readonly property real sz: (index % 3 === 0) ? z1 : z0
            source: "#Rectangle"
            position: on
                      ? Qt.vector3d(sx + frac * dx, 554, sz + frac * dz)
                      : Qt.vector3d(0, -9000, 0)
            eulerRotation: Qt.vector3d(90, Math.atan2(dz, dx) * 180 / Math.PI, -34 - index * 7)
            scale: on ? Qt.vector3d(0.62 + (index % 3) * 0.08, 0.62 + (index % 3) * 0.08, 1)
                      : Qt.vector3d(0, 0, 1)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColorMap: Texture { sourceItem: root.shootTex }
                emissiveFactor: Qt.vector3d(0.6, 1.05, 0.42)
            }
        }
    }
}
