pragma ComponentBehavior: Bound
import QtQuick
import QtQuick3D

// Main counter island — BLAST FROM THE PAST, NOW PLAYING marquee,
// glass-block skirt on every side, neon inside the blocks, four TVs.
Node {
    id: island
    property real pulse: 1
    property real pulseB: 1
    property real t: 0
    property Item heroTex
    property Item marqueeTex
    property Item deskL
    property Item deskR
    property real faceYaw: 0

    // Dense 6x6-style cubes wrapping the whole footprint (front/back/sides).
    Repeater3D {
        model: 15 * 6 * 2
        Model {
            required property int index
            readonly property int ix: index % 15
            readonly property int iz: Math.floor(index / 15) % 6
            readonly property int iy: Math.floor(index / 90)
            readonly property int tint: index % 3
            source: "#Cube"
            position: Qt.vector3d(
                ix * 52 - 364,
                22 + iy * 46,
                iz * 48 - 120)
            scale: Qt.vector3d(0.48, 0.42, 0.44)
            materials: PrincipledMaterial {
                baseColor: tint === 0 ? "#e8f6ff" : (tint === 1 ? "#ffe6f6" : "#fff6d0")
                metalness: 0.0
                roughness: 0.04
                transmissionFactor: 0.9
                thicknessFactor: 22
                indexOfRefraction: 1.45
                emissiveFactor: tint === 0
                    ? Qt.vector3d(0.05, 0.16 * island.pulse, 0.32)
                    : (tint === 1
                       ? Qt.vector3d(0.32 * island.pulse, 0.05, 0.22)
                       : Qt.vector3d(0.28 * island.pulseB, 0.22, 0.04))
            }
        }
    }

    // Counter body
    Model {
        source: "#Cube"
        position: Qt.vector3d(0, 72, 0)
        scale: Qt.vector3d(4.2, 0.86, 1.9)
        materials: PrincipledMaterial {
            baseColor: "#241028"
            roughness: 0.22
            metalness: 0.15
            emissiveFactor: Qt.vector3d(0.35 * island.pulse, 0.06, 0.22)
        }
    }

    // Reception wing (left) — sits on the glass skirt
    Model {
        source: "#Cube"
        position: Qt.vector3d(-255, 64, 36)
        scale: Qt.vector3d(1.4, 0.72, 1.22)
        materials: PrincipledMaterial {
            baseColor: "#1a1230"
            roughness: 0.25
            emissiveFactor: Qt.vector3d(0.12, 0.18, 0.45 * island.pulse)
        }
    }
    Model {
        source: "#Rectangle"
        position: Qt.vector3d(-255, 64, 100)
        scale: Qt.vector3d(1.15, 0.42, 1)
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColorMap: Texture { sourceItem: island.deskL }
        }
    }

    // Member / games wing (right)
    Model {
        source: "#Cube"
        position: Qt.vector3d(255, 64, 36)
        scale: Qt.vector3d(1.4, 0.72, 1.22)
        materials: PrincipledMaterial {
            baseColor: "#1a1230"
            roughness: 0.25
            emissiveFactor: Qt.vector3d(0.4 * island.pulseB, 0.08, 0.18)
        }
    }
    Model {
        source: "#Rectangle"
        position: Qt.vector3d(255, 64, 100)
        scale: Qt.vector3d(1.15, 0.42, 1)
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColorMap: Texture { sourceItem: island.deskR }
        }
    }

    // Marquee body
    Model {
        source: "#Cube"
        position: Qt.vector3d(0, 168, -8)
        scale: Qt.vector3d(4.5, 1.18, 0.48)
        materials: PrincipledMaterial {
            baseColor: "#140814"
            roughness: 0.2
            emissiveFactor: Qt.vector3d(0.55 * island.pulse, 0.08, 0.32)
        }
    }
    Model {
        source: "#Rectangle"
        position: Qt.vector3d(0, 168, 18)
        scale: Qt.vector3d(4.15, 1.08, 1)
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColorMap: Texture { sourceItem: island.marqueeTex }
            emissiveFactor: Qt.vector3d(0.2 * island.pulse, 0.08, 0.18)
            cullMode: Material.NoCulling
        }
    }
    Model {
        source: "#Rectangle"
        position: Qt.vector3d(0, 168, -34)
        eulerRotation: Qt.vector3d(0, 180, 0)
        scale: Qt.vector3d(4.15, 1.08, 1)
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColorMap: Texture { sourceItem: island.marqueeTex }
            emissiveFactor: Qt.vector3d(0.2 * island.pulse, 0.08, 0.18)
        }
    }

    FloorNeonName {
        position: Qt.vector3d(0, 252, 28)
        t: island.t
        pulse: island.pulse
        pulseB: island.pulseB
    }

    // Four huge black-glass TVs above the island, tilted down toward +Z.
    component Tv: Node {
        property color rim: "#00e5ff"
        property real scan: 0
        eulerRotation: Qt.vector3d(-16, 0, 0)
        Model {
            source: "#Cube"
            scale: Qt.vector3d(1.92, 1.18, 0.07)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: rim
                emissiveFactor: Qt.vector3d(
                    rim.r * (1.3 + 0.5 * island.pulse),
                    rim.g * (1.3 + 0.5 * island.pulseB),
                    rim.b * (1.5 + 0.4 * island.pulse))
            }
        }
        Model {
            source: "#Rectangle"
            position: Qt.vector3d(0, 0, 5)
            scale: Qt.vector3d(1.78, 1.04, 1)
            materials: PrincipledMaterial {
                baseColor: "#07080c"
                roughness: 0.06
                metalness: 0.45
                emissiveFactor: Qt.vector3d(
                    rim.r * (0.08 + 0.10 * island.pulse),
                    rim.g * (0.08 + 0.10 * island.pulseB),
                    rim.b * 0.14)
            }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(0, Math.sin(island.t * 1.35 + scan) * 32, 6)
            scale: Qt.vector3d(1.72, 0.018, 0.012)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: rim
                emissiveFactor: Qt.vector3d(
                    rim.r * 0.55,
                    rim.g * 0.55,
                    rim.b * 0.7)
            }
        }
    }
    Tv { position: Qt.vector3d(-285, 388, -18); rim: "#ff2bd6"; scan: 0.0 }
    Tv { position: Qt.vector3d(-95, 388, -8); rim: "#00e5ff"; scan: 0.8 }
    Tv { position: Qt.vector3d(95, 388, -8); rim: "#ffea00"; scan: 1.6 }
    Tv { position: Qt.vector3d(285, 388, -18); rim: "#ff6b2b"; scan: 2.4 }

    // Neon trim
    Model {
        source: "#Cube"
        position: Qt.vector3d(0, 28, 96)
        scale: Qt.vector3d(4.4, 0.05, 0.05)
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: "#ffea00"
            emissiveFactor: Qt.vector3d(1.3 * island.pulse, 1.0, 0.15)
        }
    }
    Model {
        source: "#Cube"
        position: Qt.vector3d(0, 28, -96)
        scale: Qt.vector3d(4.4, 0.05, 0.05)
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: "#00e5ff"
            emissiveFactor: Qt.vector3d(0.12, 1.1 * island.pulseB, 1.3)
        }
    }
    Model {
        source: "#Cube"
        position: Qt.vector3d(-210, 102, 0)
        scale: Qt.vector3d(0.06, 1.9, 0.06)
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: "#ff2bd6"
            emissiveFactor: Qt.vector3d(1.6 * island.pulse, 0.12, 0.85)
        }
    }
    Model {
        source: "#Cube"
        position: Qt.vector3d(210, 102, 0)
        scale: Qt.vector3d(0.06, 1.9, 0.06)
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: "#00e5ff"
            emissiveFactor: Qt.vector3d(0.1, 1.1 * island.pulseB, 1.4)
        }
    }

    // Neon INSIDE the glass so it shows through the blocks.
    PointLight {
        position: Qt.vector3d(0, 30, 70)
        color: "#ff2bd6"
        brightness: 26 + 18 * island.pulse
        quadraticFade: 0.0007
    }
    PointLight {
        position: Qt.vector3d(0, 30, -70)
        color: "#00e5ff"
        brightness: 22 + 16 * island.pulseB
        quadraticFade: 0.00075
    }
    PointLight {
        position: Qt.vector3d(-220, 28, 10)
        color: "#ffea00"
        brightness: 20 + 14 * island.pulse
        quadraticFade: 0.0008
    }
    PointLight {
        position: Qt.vector3d(220, 28, 10)
        color: "#ff2bd6"
        brightness: 20 + 14 * island.pulseB
        quadraticFade: 0.0008
    }
    PointLight {
        position: Qt.vector3d(-90, 26, 40)
        color: "#00e5ff"
        brightness: 18 + 14 * island.pulseB
        quadraticFade: 0.00085
    }
    PointLight {
        position: Qt.vector3d(90, 26, 40)
        color: "#ffea00"
        brightness: 16 + 12 * island.pulse
        quadraticFade: 0.00085
    }
    Model {
        source: "#Cube"
        position: Qt.vector3d(0, 26, 0)
        scale: Qt.vector3d(3.4, 0.08, 1.4)
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: "#ff2bd6"
            emissiveFactor: Qt.vector3d(1.8 * island.pulse, 0.15, 1.0)
        }
    }
    Model {
        source: "#Cube"
        position: Qt.vector3d(-240, 26, 20)
        scale: Qt.vector3d(1.1, 0.07, 0.9)
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: "#ffea00"
            emissiveFactor: Qt.vector3d(1.4 * island.pulse, 1.1, 0.12)
        }
    }
    Model {
        source: "#Cube"
        position: Qt.vector3d(240, 26, 20)
        scale: Qt.vector3d(1.1, 0.07, 0.9)
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: "#00e5ff"
            emissiveFactor: Qt.vector3d(0.1, 1.2 * island.pulseB, 1.5)
        }
    }

    PointLight {
        position: Qt.vector3d(0, 210, 40)
        color: "#ff4ad8"
        brightness: 10 + 10 * island.pulse
        quadraticFade: 0.0004
    }
    PointLight {
        position: Qt.vector3d(0, 400, 20)
        color: "#00e5ff"
        brightness: 8 + 8 * island.pulseB
        quadraticFade: 0.00035
    }
}
