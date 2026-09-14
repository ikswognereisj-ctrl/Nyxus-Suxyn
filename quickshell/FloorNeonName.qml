pragma ComponentBehavior: Bound
import QtQuick
import QtQuick3D
import QtQuick3D.Helpers

// One copy. Geometry origin is rear-left of the baseline — offset to 0
// so parent yaw spins in place. No extra 180 on the parent.
Node {
    id: name
    property real t: 0
    property real pulse: 1
    property real pulseB: 1
    eulerRotation: Qt.vector3d(0, 0, 0)

    readonly property color hueA: "#ff2bd6"
    readonly property color hueB: "#ffea00"

    component NeonWord: Model {
        property string word: "BLAST"
        property real depth: 48
        property real px: 90
        property color ink: name.hueA
        geometry: ExtrudedTextGeometry {
            text: word
            depth: depth
            scale: px
            font.pointSize: 64
            font.bold: true
            font.family: "Noto Sans"
        }
        materials: PrincipledMaterial {
            baseColor: ink
            metalness: 0.04
            roughness: 0.10
            emissiveFactor: Qt.vector3d(ink.r * 2.4, ink.g * 2.4, ink.b * 2.4)
        }
    }

    // BLAST ~5 letters at scale 90 → width ~280. Glyphs go +X, so x ≈ -140.
    NeonWord {
        word: "BLAST"
        px: 90
        depth: 52
        ink: name.hueA
        position: Qt.vector3d(-140, 50, -26)
    }
    NeonWord {
        word: "FROM THE PAST"
        px: 36
        depth: 42
        ink: name.hueB
        position: Qt.vector3d(-148, -42, -21)
    }

    PointLight {
        position: Qt.vector3d(0, 20, 80)
        color: name.hueA
        brightness: 22
        quadraticFade: 0.0003
    }
    PointLight {
        position: Qt.vector3d(0, -20, -70)
        color: name.hueB
        brightness: 14
        quadraticFade: 0.0004
    }
}
