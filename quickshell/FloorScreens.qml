pragma ComponentBehavior: Bound
import QtQuick
import QtQuick3D

// Four attract screens over the island.
Node {
    id: screens
    property real pulse: 1
    property real pulseB: 1
    property real t: 0
    property Item nowTex

    component Panel: Node {
        property string tag: "NOW"
        property color rim: "#00e5ff"
        property real ox: 0
        Model {
            source: "#Cube"
            position: Qt.vector3d(ox, 0, 0)
            scale: Qt.vector3d(1.55, 0.92, 0.08)
            materials: PrincipledMaterial {
                baseColor: "#0a0a0e"
                roughness: 0.08
                metalness: 0.4
            }
        }
        Model {
            source: "#Rectangle"
            position: Qt.vector3d(ox, 0, 5)
            eulerRotation: Qt.vector3d(-12, 0, 0)
            scale: Qt.vector3d(1.42, 0.80, 1)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: rim
                emissiveFactor: Qt.vector3d(
                    rim.r * (0.15 + 0.25 * screens.pulse),
                    rim.g * (0.15 + 0.25 * screens.pulseB),
                    rim.b * (0.2 + 0.2 * screens.pulse))
            }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(ox, 0, 4)
            scale: Qt.vector3d(1.48, 0.86, 0.03)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: rim
                emissiveFactor: Qt.vector3d(rim.r * 1.4, rim.g * 1.4, rim.b * 1.4)
            }
        }
    }

    Panel { tag: "NOW PLAYING"; rim: "#ff2bd6"; ox: -240 }
    Model {
        source: "#Rectangle"
        position: Qt.vector3d(-240, 0, 8)
        eulerRotation: Qt.vector3d(-12, 0, 0)
        scale: Qt.vector3d(1.38, 0.76, 1)
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColorMap: Texture { sourceItem: screens.nowTex }
        }
    }
    Panel { tag: "CONTINUE"; rim: "#00e5ff"; ox: -80 }
    Panel { tag: "SCORES"; rim: "#ffea00"; ox: 80 }
    Panel { tag: "ATTRACT"; rim: "#ff6b2b"; ox: 240 }
}
