pragma ComponentBehavior: Bound
import QtQuick
import QtQuick3D

// WAVE RADIO — Nyxus Media booth in the lobby.
Node {
    id: booth
    property real t: 0
    property real pulse: 1
    property real pulseB: 1
    property Item nowTex

    Model {
        source: "#Cube"
        position: Qt.vector3d(0, 55, 0)
        scale: Qt.vector3d(1.8, 1.1, 0.9)
        materials: PrincipledMaterial {
            baseColor: "#1a1030"
            roughness: 0.25
            emissiveFactor: Qt.vector3d(0.15, 0.08, 0.35 * booth.pulse)
        }
    }
    Model {
        source: "#Rectangle"
        position: Qt.vector3d(0, 58, 48)
        scale: Qt.vector3d(1.5, 0.85, 1)
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColorMap: Texture { sourceItem: booth.nowTex }
        }
    }
    Model {
        source: "#Rectangle"
        position: Qt.vector3d(0, 160, 10)
        scale: Qt.vector3d(2.2, 0.55, 1)
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: "#00e5ff"
            emissiveFactor: Qt.vector3d(0.1, 0.9 * booth.pulse, 1.2)
        }
    }
    PointLight {
        position: Qt.vector3d(0, 140, 60)
        color: "#00e5ff"
        brightness: 10 + 12 * booth.pulse
        quadraticFade: 0.0005
    }
}
