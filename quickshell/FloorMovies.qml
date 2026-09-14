pragma ComponentBehavior: Bound
import QtQuick
import QtQuick3D
import QtQuick3D.Helpers

// Left movies wing — lightbox row against the far wall, glass-block court,
// magenta cove, neon arch. Original Nyxus 80s art only (no licensed posters).
Node {
    id: movies
    property real t: 0
    property real pulse: 1
    property real pulseB: 1

    component NeonBar: Model {
        source: "#Cube"
        property color glow: "#ff2bd6"
        property real heat: 1.7
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: glow
            emissiveFactor: Qt.vector3d(
                glow.r * (heat + 1.1 * movies.pulse),
                glow.g * (heat + 1.1 * movies.pulseB),
                glow.b * (heat + 1.1 * movies.pulse))
        }
    }

    component NeonTube: Model {
        source: "#Cylinder"
        property color glow: "#ff2bd6"
        property real heat: 1.8
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: glow
            emissiveFactor: Qt.vector3d(
                glow.r * (heat + 1.2 * movies.pulse),
                glow.g * (heat + 1.2 * movies.pulseB),
                glow.b * (heat + 1.2 * movies.pulse))
        }
    }

    component GlassBrick: Model {
        source: "#Cube"
        property int index: 0
        materials: PrincipledMaterial {
            baseColor: index % 3 === 0 ? "#d8f4ff" : (index % 3 === 1 ? "#f4d8ff" : "#e8eeff")
            metalness: 0.0
            roughness: 0.04
            transmissionFactor: 0.90
            thicknessFactor: 20
            indexOfRefraction: 1.46
            emissiveFactor: Qt.vector3d(
                0.12 + 0.28 * movies.pulse * (index % 3 === 1 ? 1.0 : 0.25),
                0.18 + 0.22 * movies.pulseB,
                0.42 + 0.32 * movies.pulse * (index % 3 === 0 ? 1.0 : 0.4))
        }
    }

    component LightBox: Node {
        id: box
        property color rim: "#ff2bd6"
        property color paper: "#120814"
        property string plate: "NOW"
        property real plateShift: 52

        function dotPos(i) {
            const w = 58
            const h = 96
            if (i < 5)
                return Qt.vector3d(14, h, -w + i * (2 * w / 4))
            if (i < 9)
                return Qt.vector3d(14, h - (i - 4) * (2 * h / 4), w)
            if (i < 13)
                return Qt.vector3d(14, -h, w - (i - 8) * (2 * w / 4))
            return Qt.vector3d(14, -h + (i - 12) * (2 * h / 4), -w)
        }

        // Can / back housing
        Model {
            source: "#Cube"
            position: Qt.vector3d(-8, 0, 0)
            scale: Qt.vector3d(0.18, 2.28, 1.42)
            materials: PrincipledMaterial {
                baseColor: "#0a0a0c"
                metalness: 0.55
                roughness: 0.28
            }
        }

        // Inner art paper
        Model {
            source: "#Cube"
            position: Qt.vector3d(2, 6, 0)
            scale: Qt.vector3d(0.02, 1.92, 1.16)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: box.paper
                emissiveFactor: Qt.vector3d(box.paper.r * 0.45, box.paper.g * 0.45, box.paper.b * 0.55)
            }
        }

        // Black frame lips
        Model {
            source: "#Cube"
            position: Qt.vector3d(6, 108, 0)
            scale: Qt.vector3d(0.16, 0.12, 1.42)
            materials: PrincipledMaterial { baseColor: "#111114"; metalness: 0.7; roughness: 0.22 }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(6, -108, 0)
            scale: Qt.vector3d(0.16, 0.12, 1.42)
            materials: PrincipledMaterial { baseColor: "#111114"; metalness: 0.7; roughness: 0.22 }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(6, 0, 66)
            scale: Qt.vector3d(0.16, 2.28, 0.12)
            materials: PrincipledMaterial { baseColor: "#111114"; metalness: 0.7; roughness: 0.22 }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(6, 0, -66)
            scale: Qt.vector3d(0.16, 2.28, 0.12)
            materials: PrincipledMaterial { baseColor: "#111114"; metalness: 0.7; roughness: 0.22 }
        }

        // Neon rim
        NeonBar {
            position: Qt.vector3d(14, 114, 0)
            scale: Qt.vector3d(0.045, 0.04, 1.48)
            glow: box.rim
            heat: 2.1
        }
        NeonBar {
            position: Qt.vector3d(14, -114, 0)
            scale: Qt.vector3d(0.045, 0.04, 1.48)
            glow: box.rim
            heat: 2.1
        }
        NeonBar {
            position: Qt.vector3d(14, 0, 72)
            scale: Qt.vector3d(0.045, 2.32, 0.04)
            glow: box.rim
            heat: 2.1
        }
        NeonBar {
            position: Qt.vector3d(14, 0, -72)
            scale: Qt.vector3d(0.045, 2.32, 0.04)
            glow: box.rim
            heat: 2.1
        }

        // Inner hairline
        NeonBar {
            position: Qt.vector3d(12, 100, 0)
            scale: Qt.vector3d(0.02, 0.018, 1.20)
            glow: box.rim
            heat: 1.2
        }
        NeonBar {
            position: Qt.vector3d(12, -88, 0)
            scale: Qt.vector3d(0.02, 0.018, 1.20)
            glow: box.rim
            heat: 1.2
        }

        // Marquee chase dots
        Repeater3D {
            model: 16
            Model {
                required property int index
                source: "#Sphere"
                position: box.dotPos(index)
                scale: Qt.vector3d(0.045, 0.045, 0.045)
                materials: PrincipledMaterial {
                    lighting: PrincipledMaterial.NoLighting
                    baseColor: box.rim
                    emissiveFactor: Qt.vector3d(
                        box.rim.r * (0.8 + 1.8 * (0.5 + 0.5 * Math.sin(movies.t * 7.2 + index * 0.55))),
                        box.rim.g * (0.8 + 1.8 * (0.5 + 0.5 * Math.sin(movies.t * 7.2 + index * 0.55))),
                        box.rim.b * (0.8 + 1.8 * (0.5 + 0.5 * Math.sin(movies.t * 7.2 + index * 0.55))))
                }
            }
        }

        // Glass shine band
        Model {
            source: "#Rectangle"
            position: Qt.vector3d(15, 62, 0)
            eulerRotation: Qt.vector3d(0, 90, 0)
            scale: Qt.vector3d(1.10, 0.42, 1)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ffffff"
                alphaMode: PrincipledMaterial.Blend
                opacity: 0.10 + 0.06 * movies.pulse
                emissiveFactor: Qt.vector3d(0.18, 0.18, 0.22)
                cullMode: Material.NoCulling
            }
        }

        // Title plaque
        Model {
            source: "#Cube"
            position: Qt.vector3d(8, -128, 0)
            scale: Qt.vector3d(0.12, 0.18, 1.28)
            materials: PrincipledMaterial {
                baseColor: "#0c0c10"
                metalness: 0.4
                roughness: 0.3
                emissiveFactor: Qt.vector3d(box.rim.r * 0.15, box.rim.g * 0.12, box.rim.b * 0.15)
            }
        }
        Node {
            position: Qt.vector3d(16, -132, 0)
            eulerRotation: Qt.vector3d(0, -90, 0)
            Model {
                scale: Qt.vector3d(-0.26, 0.26, 0.26)
                position: Qt.vector3d(box.plateShift, 0, 0)
                geometry: ExtrudedTextGeometry {
                    text: box.plate
                    depth: 14
                    font.pixelSize: 34
                    font.bold: true
                    font.family: "Noto Sans"
                }
                materials: PrincipledMaterial {
                    baseColor: box.rim
                    metalness: 0.04
                    roughness: 0.12
                    emissiveFactor: Qt.vector3d(
                        box.rim.r * (2.2 + 1.6 * movies.pulse),
                        box.rim.g * (2.2 + 1.6 * movies.pulseB),
                        box.rim.b * (2.2 + 1.6 * movies.pulse))
                }
            }
        }
    }

    // ── End wall (teal court, far from the island) ─────────────────────
    Model {
        source: "#Rectangle"
        position: Qt.vector3d(-1110, 200, -40)
        eulerRotation: Qt.vector3d(0, 90, 0)
        scale: Qt.vector3d(11.6, 4.6, 1)
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: "#0a2832"
            emissiveFactor: Qt.vector3d(0.03, 0.10 + 0.04 * movies.pulseB, 0.14)
        }
    }

    // Star wall (teal court)
    Repeater3D {
        model: 22
        Model {
            required property int index
            source: "#Sphere"
            position: Qt.vector3d(
                -1102,
                210 + (index % 4) * 42 + (index * 7 % 11),
                440 - index * 42 + (index % 3) * 10)
            scale: Qt.vector3d(0.07 + (index % 3) * 0.02, 0.07 + (index % 3) * 0.02, 0.07)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ffea00"
                emissiveFactor: Qt.vector3d(
                    1.4 + 0.8 * movies.pulse,
                    1.1 + 0.4 * movies.pulseB,
                    0.2)
            }
        }
    }

    // ── Glass-block feature wall ───────────────────────────────────────
    Repeater3D {
        model: 70
        GlassBrick {
            required property int index
            position: Qt.vector3d(
                -1086 + (index % 5) * 3,
                24 + (index % 7) * 36,
                430 - Math.floor(index / 7) * 100)
            scale: Qt.vector3d(0.20, 0.32, 0.88)
        }
    }

    // Neon inside the glass so transmission reads
    PointLight {
        position: Qt.vector3d(-1070, 90, 80)
        color: "#00e5ff"
        brightness: 14 + 12 * movies.pulseB
        quadraticFade: 0.00055
    }
    PointLight {
        position: Qt.vector3d(-1070, 110, -200)
        color: "#ff2bd6"
        brightness: 12 + 12 * movies.pulse
        quadraticFade: 0.00055
    }

    // ── Checker wainscot ───────────────────────────────────────────────
    Repeater3D {
        model: 48
        Model {
            required property int index
            source: "#Cube"
            position: Qt.vector3d(
                -1028,
                10 + (index % 2) * 18,
                450 - Math.floor(index / 2) * 38)
            scale: Qt.vector3d(0.10, 0.16, 0.30)
            materials: PrincipledMaterial {
                baseColor: ((index + Math.floor(index / 2)) % 2 === 0) ? "#f2f2f6" : "#0c0c10"
                roughness: 0.18
                metalness: 0.08
                emissiveFactor: ((index + Math.floor(index / 2)) % 2 === 0)
                    ? Qt.vector3d(0.08, 0.08, 0.10)
                    : Qt.vector3d(0.02, 0.01, 0.02)
            }
        }
    }

    // ── Cove neon along the poster wall ────────────────────────────────
    NeonBar {
        position: Qt.vector3d(-1022, 268, -40)
        scale: Qt.vector3d(0.06, 0.055, 9.6)
        glow: "#ff2bd6"
        heat: 2.0
    }
    NeonBar {
        position: Qt.vector3d(-1016, 258, -40)
        scale: Qt.vector3d(0.04, 0.035, 9.4)
        glow: "#ff6ad8"
        heat: 1.5
    }
    NeonBar {
        position: Qt.vector3d(-1022, 38, -40)
        scale: Qt.vector3d(0.05, 0.04, 9.6)
        glow: "#ff2bd6"
        heat: 1.6
    }
    NeonBar {
        position: Qt.vector3d(-1008, 4, -40)
        scale: Qt.vector3d(0.55, 0.02, 9.4)
        glow: "#ff2bd6"
        heat: 0.7
    }

    // Verticals between frames
    Repeater3D {
        model: 7
        NeonBar {
            required property int index
            position: Qt.vector3d(-1024, 150, 430 - index * 170)
            scale: Qt.vector3d(0.04, 2.2, 0.04)
            glow: index % 2 === 0 ? "#ff2bd6" : "#00e5ff"
            heat: 1.5
        }
    }

    // ── Lightbox 0 — synth sun / NOW SHOWING ───────────────────────────
    LightBox {
        position: Qt.vector3d(-1035, 150, 380)
        rim: "#ff2bd6"
        paper: "#1a0830"
        plate: "NOW SHOWING"
        plateShift: 92

        Model {
            source: "#Sphere"
            position: Qt.vector3d(8, 38, 0)
            scale: Qt.vector3d(0.52, 0.52, 0.52)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ff6b2b"
                emissiveFactor: Qt.vector3d(2.4 + 1.2 * movies.pulse, 0.7, 0.25)
            }
        }
        Model {
            source: "#Sphere"
            position: Qt.vector3d(6, 38, 0)
            scale: Qt.vector3d(0.78, 0.78, 0.78)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ff2bd6"
                emissiveFactor: Qt.vector3d(0.9 * movies.pulse, 0.08, 0.45)
                opacity: 0.35
            }
        }
        NeonBar {
            position: Qt.vector3d(8, -6, 0)
            scale: Qt.vector3d(0.03, 0.02, 1.05)
            glow: "#ff2bd6"
            heat: 1.8
        }
        Repeater3D {
            model: 6
            NeonBar {
                required property int index
                position: Qt.vector3d(8, -18 - index * 12, 0)
                scale: Qt.vector3d(0.018, 0.012, 1.02 - index * 0.06)
                glow: index % 2 === 0 ? "#ff2bd6" : "#00e5ff"
                heat: 1.3
            }
        }
        Repeater3D {
            model: 7
            NeonBar {
                required property int index
                position: Qt.vector3d(8, -48, -42 + index * 14)
                scale: Qt.vector3d(0.018, 0.62, 0.012)
                glow: "#5a20a0"
                heat: 1.1
            }
        }
    }

    // ── Lightbox 1 — neon grid / FEATURE ───────────────────────────────
    LightBox {
        position: Qt.vector3d(-1035, 150, 210)
        rim: "#00e5ff"
        paper: "#061018"
        plate: "FEATURE"
        plateShift: 48

        Model {
            source: "#Sphere"
            position: Qt.vector3d(8, 44, 0)
            scale: Qt.vector3d(0.22, 0.22, 0.22)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ffea00"
                emissiveFactor: Qt.vector3d(2.0, 1.6 + 0.8 * movies.pulse, 0.2)
            }
        }
        Repeater3D {
            model: 8
            NeonBar {
                required property int index
                position: Qt.vector3d(8, 20 - index * 14, 0)
                scale: Qt.vector3d(0.016, 0.012, 0.28 + index * 0.10)
                glow: "#00e5ff"
                heat: 1.4
            }
        }
        Repeater3D {
            model: 9
            NeonBar {
                required property int index
                position: Qt.vector3d(8, -22, -48 + index * 12)
                eulerRotation: Qt.vector3d(0, 0, (index - 4) * 9)
                scale: Qt.vector3d(0.016, 0.95, 0.012)
                glow: "#ff2bd6"
                heat: 1.15
            }
        }
        NeonBar {
            position: Qt.vector3d(8, 28, 0)
            scale: Qt.vector3d(0.02, 0.018, 0.55)
            glow: "#ff2bd6"
            heat: 1.7
        }
    }

    // ── Lightbox 2 — rocket / COMING SOON ──────────────────────────────
    LightBox {
        position: Qt.vector3d(-1035, 150, 40)
        rim: "#ffea00"
        paper: "#140820"
        plate: "COMING SOON"
        plateShift: 86

        Model {
            source: "#Cone"
            position: Qt.vector3d(8, 58, 0)
            scale: Qt.vector3d(0.22, 0.32, 0.22)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ff2bd6"
                emissiveFactor: Qt.vector3d(1.8 * movies.pulse, 0.15, 1.1)
            }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(8, 18, 0)
            scale: Qt.vector3d(0.20, 0.52, 0.20)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ff2bd6"
                emissiveFactor: Qt.vector3d(1.5, 0.12, 0.9)
            }
        }
        Model {
            source: "#Sphere"
            position: Qt.vector3d(14, 28, 0)
            scale: Qt.vector3d(0.10, 0.10, 0.10)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#00e5ff"
                emissiveFactor: Qt.vector3d(0.2, 1.6 * movies.pulseB, 2.0)
            }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(8, 2, 22)
            eulerRotation: Qt.vector3d(0, 0, 28)
            scale: Qt.vector3d(0.06, 0.28, 0.16)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ffea00"
                emissiveFactor: Qt.vector3d(1.8, 1.4, 0.15)
            }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(8, 2, -22)
            eulerRotation: Qt.vector3d(0, 0, -28)
            scale: Qt.vector3d(0.06, 0.28, 0.16)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ffea00"
                emissiveFactor: Qt.vector3d(1.8, 1.4, 0.15)
            }
        }
        Model {
            source: "#Cone"
            position: Qt.vector3d(8, -28, 0)
            eulerRotation: Qt.vector3d(180, 0, 0)
            scale: Qt.vector3d(0.16, 0.28, 0.16)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ff6b2b"
                emissiveFactor: Qt.vector3d(2.2 + 1.2 * movies.pulse, 1.0, 0.15)
            }
        }
        Model {
            source: "#Cone"
            position: Qt.vector3d(8, -42, 0)
            eulerRotation: Qt.vector3d(180, 0, 0)
            scale: Qt.vector3d(0.10, 0.22, 0.10)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ffea00"
                emissiveFactor: Qt.vector3d(2.4, 2.0 + 0.8 * movies.pulseB, 0.2)
            }
        }
    }

    // ── Lightbox 3 — magma planet / MIDNIGHT ───────────────────────────
    LightBox {
        position: Qt.vector3d(-1035, 150, -130)
        rim: "#ff6b2b"
        paper: "#18060a"
        plate: "MIDNIGHT"
        plateShift: 58

        Model {
            source: "#Sphere"
            position: Qt.vector3d(8, 8, 0)
            scale: Qt.vector3d(0.62, 0.62, 0.62)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ff4a18"
                emissiveFactor: Qt.vector3d(1.8 + 0.8 * movies.pulse, 0.35, 0.08)
            }
        }
        Model {
            source: "#Sphere"
            position: Qt.vector3d(10, 4, 8)
            scale: Qt.vector3d(0.28, 0.22, 0.34)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#4a1020"
                emissiveFactor: Qt.vector3d(0.25, 0.04, 0.06)
            }
        }
        Model {
            source: "#Cylinder"
            position: Qt.vector3d(8, 8, 0)
            eulerRotation: Qt.vector3d(72, 0, 18)
            scale: Qt.vector3d(0.92, 0.03, 0.92)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ffea00"
                emissiveFactor: Qt.vector3d(1.6, 1.1 * movies.pulseB, 0.15)
            }
        }
        Model {
            source: "#Sphere"
            position: Qt.vector3d(10, 48, -28)
            scale: Qt.vector3d(0.12, 0.12, 0.12)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ffb070"
                emissiveFactor: Qt.vector3d(1.2, 0.6, 0.3)
            }
        }
        Repeater3D {
            model: 8
            Model {
                required property int index
                source: "#Sphere"
                position: Qt.vector3d(10, 70 - (index % 4) * 18, -50 + Math.floor(index / 4) * 96)
                scale: Qt.vector3d(0.03, 0.03, 0.03)
                materials: PrincipledMaterial {
                    lighting: PrincipledMaterial.NoLighting
                    baseColor: "#ffe8c0"
                    emissiveFactor: Qt.vector3d(1.4, 1.2, 0.8)
                }
            }
        }
    }

    // ── Lightbox 4 — cassette / DOUBLE FEATURE ─────────────────────────
    LightBox {
        position: Qt.vector3d(-1035, 150, -300)
        rim: "#ff2bd6"
        paper: "#101018"
        plate: "DOUBLE FEATURE"
        plateShift: 108

        Model {
            source: "#Cube"
            position: Qt.vector3d(8, 4, 0)
            scale: Qt.vector3d(0.16, 0.72, 1.05)
            materials: PrincipledMaterial {
                baseColor: "#1a1a22"
                roughness: 0.35
                metalness: 0.15
                emissiveFactor: Qt.vector3d(0.12, 0.06, 0.14)
            }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(16, 22, 0)
            scale: Qt.vector3d(0.03, 0.22, 0.88)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ff2bd6"
                emissiveFactor: Qt.vector3d(1.5 * movies.pulse, 0.12, 0.9)
            }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(16, -10, 0)
            scale: Qt.vector3d(0.03, 0.28, 0.72)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#0a0a10"
                emissiveFactor: Qt.vector3d(0.05, 0.08, 0.12)
            }
        }
        Model {
            source: "#Cylinder"
            position: Qt.vector3d(16, -10, 22)
            eulerRotation: Qt.vector3d(0, 0, 90)
            scale: Qt.vector3d(0.22, 0.05, 0.22)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#c8c0d0"
                emissiveFactor: Qt.vector3d(0.5, 0.45, 0.6)
            }
        }
        Model {
            source: "#Cylinder"
            position: Qt.vector3d(16, -10, -22)
            eulerRotation: Qt.vector3d(0, 0, 90)
            scale: Qt.vector3d(0.22, 0.05, 0.22)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#c8c0d0"
                emissiveFactor: Qt.vector3d(0.5, 0.45, 0.6)
            }
        }
        Model {
            source: "#Cylinder"
            position: Qt.vector3d(18, -10, 22)
            eulerRotation: Qt.vector3d(0, 0, 90)
            scale: Qt.vector3d(0.08, 0.04, 0.08)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ffea00"
                emissiveFactor: Qt.vector3d(1.6, 1.3 * movies.pulseB, 0.2)
            }
        }
        Model {
            source: "#Cylinder"
            position: Qt.vector3d(18, -10, -22)
            eulerRotation: Qt.vector3d(0, 0, 90)
            scale: Qt.vector3d(0.08, 0.04, 0.08)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ffea00"
                emissiveFactor: Qt.vector3d(1.6, 1.3 * movies.pulseB, 0.2)
            }
        }
        NeonBar {
            position: Qt.vector3d(16, 48, 0)
            scale: Qt.vector3d(0.03, 0.04, 0.92)
            glow: "#00e5ff"
            heat: 1.5
        }
    }

    // ── Lightbox 5 — arcade cabinet / NYXUS ────────────────────────────
    LightBox {
        position: Qt.vector3d(-1035, 150, -470)
        rim: "#00e5ff"
        paper: "#0a1020"
        plate: "NYXUS"
        plateShift: 42

        Model {
            source: "#Cube"
            position: Qt.vector3d(6, -8, 0)
            scale: Qt.vector3d(0.28, 1.05, 0.52)
            materials: PrincipledMaterial {
                baseColor: "#1a1040"
                roughness: 0.3
                emissiveFactor: Qt.vector3d(0.25, 0.08, 0.45)
            }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(6, 62, 0)
            scale: Qt.vector3d(0.26, 0.18, 0.58)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ff2bd6"
                emissiveFactor: Qt.vector3d(1.7 * movies.pulse, 0.12, 1.0)
            }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(18, 18, 0)
            scale: Qt.vector3d(0.03, 0.42, 0.38)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#00e5ff"
                emissiveFactor: Qt.vector3d(0.15, 1.3 + 0.9 * movies.pulseB, 1.7)
            }
        }
        Repeater3D {
            model: 12
            NeonBar {
                required property int index
                position: Qt.vector3d(20, 6 + (index % 4) * 8, -12 + Math.floor(index / 4) * 12)
                scale: Qt.vector3d(0.012, 0.012, 0.08)
                glow: index % 2 === 0 ? "#ffea00" : "#ff2bd6"
                heat: 1.2
            }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(16, -22, 0)
            eulerRotation: Qt.vector3d(0, 0, -22)
            scale: Qt.vector3d(0.18, 0.10, 0.48)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#2a2048"
                emissiveFactor: Qt.vector3d(0.3, 0.15, 0.5)
            }
        }
        Model {
            source: "#Sphere"
            position: Qt.vector3d(22, -20, 10)
            scale: Qt.vector3d(0.055, 0.055, 0.055)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ff2bd6"
                emissiveFactor: Qt.vector3d(1.8, 0.2, 1.1)
            }
        }
        Model {
            source: "#Sphere"
            position: Qt.vector3d(22, -20, -10)
            scale: Qt.vector3d(0.055, 0.055, 0.055)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#00e5ff"
                emissiveFactor: Qt.vector3d(0.2, 1.5, 1.8)
            }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(6, -72, 0)
            scale: Qt.vector3d(0.36, 0.22, 0.58)
            materials: PrincipledMaterial {
                baseColor: "#12101a"
                roughness: 0.4
                emissiveFactor: Qt.vector3d(0.08, 0.06, 0.12)
            }
        }
    }

    // ── MOVIES neon ────────────────────────────────────────────────────
    Node {
        position: Qt.vector3d(-930, 318, 20)
        eulerRotation: Qt.vector3d(0, -90, 0)

        Model {
            scale: Qt.vector3d(-1, 1, 1)
            position: Qt.vector3d(168, 0, 0)
            geometry: ExtrudedTextGeometry {
                text: "MOVIES"
                depth: 36
                font.pixelSize: 88
                font.bold: true
                font.family: "Noto Sans"
            }
            materials: PrincipledMaterial {
                baseColor: "#ffea00"
                metalness: 0.05
                roughness: 0.10
                emissiveFactor: Qt.vector3d(
                    2.4 + 1.6 * movies.pulse,
                    2.0 + 1.2 * movies.pulseB,
                    0.2)
            }
        }
        NeonBar {
            position: Qt.vector3d(0, -52, 8)
            scale: Qt.vector3d(3.4, 0.05, 0.05)
            glow: "#ffea00"
            heat: 2.2
        }
        NeonBar {
            position: Qt.vector3d(0, 48, 8)
            scale: Qt.vector3d(3.2, 0.04, 0.04)
            glow: "#ff2bd6"
            heat: 1.6
        }
    }

    PointLight {
        position: Qt.vector3d(-900, 310, 40)
        color: "#ffea00"
        brightness: 16 + 14 * movies.pulse
        quadraticFade: 0.0004
    }

    // ── NOW SHOWING hall plate ─────────────────────────────────────────
    Node {
        position: Qt.vector3d(-800, 250, 210)
        eulerRotation: Qt.vector3d(0, -72, 0)
        Model {
            scale: Qt.vector3d(-0.42, 0.42, 0.42)
            position: Qt.vector3d(118, 0, 0)
            geometry: ExtrudedTextGeometry {
                text: "NOW SHOWING"
                depth: 18
                font.pixelSize: 40
                font.bold: true
                font.family: "Noto Sans"
            }
            materials: PrincipledMaterial {
                baseColor: "#7cff6a"
                metalness: 0.04
                roughness: 0.12
                emissiveFactor: Qt.vector3d(
                    0.4,
                    2.2 + 1.4 * movies.pulseB,
                    0.35)
            }
        }
    }

    // ── Neon arch into the hall ────────────────────────────────────────
    Repeater3D {
        model: 15
        NeonTube {
            required property int index
            position: Qt.vector3d(
                -778,
                32 + Math.sin(index * Math.PI / 14) * 252,
                50 + Math.cos(index * Math.PI / 14) * 168)
            eulerRotation: Qt.vector3d(-index * (180 / 14), 0, 0)
            scale: Qt.vector3d(0.07, 0.48, 0.07)
            glow: "#ff2bd6"
            heat: 2.0
        }
    }
    Repeater3D {
        model: 15
        NeonTube {
            required property int index
            position: Qt.vector3d(
                -792,
                28 + Math.sin(index * Math.PI / 14) * 268,
                50 + Math.cos(index * Math.PI / 14) * 182)
            eulerRotation: Qt.vector3d(-index * (180 / 14), 0, 0)
            scale: Qt.vector3d(0.055, 0.50, 0.055)
            glow: "#00e5ff"
            heat: 1.8
        }
    }
    NeonTube {
        position: Qt.vector3d(-778, 128, 218)
        scale: Qt.vector3d(0.08, 2.4, 0.08)
        glow: "#ff2bd6"
        heat: 1.7
    }
    NeonTube {
        position: Qt.vector3d(-778, 128, -118)
        scale: Qt.vector3d(0.08, 2.4, 0.08)
        glow: "#00e5ff"
        heat: 1.7
    }

    PointLight {
        position: Qt.vector3d(-770, 200, 50)
        color: "#ff4ad8"
        brightness: 18 + 14 * movies.pulse
        quadraticFade: 0.00035
    }
    PointLight {
        position: Qt.vector3d(-790, 80, 50)
        color: "#00e5ff"
        brightness: 12 + 10 * movies.pulseB
        quadraticFade: 0.0004
    }

    // ── Teal court columns ─────────────────────────────────────────────
    Model {
        source: "#Cylinder"
        position: Qt.vector3d(-820, 150, 240)
        scale: Qt.vector3d(0.38, 3.0, 0.38)
        materials: PrincipledMaterial {
            baseColor: "#1a3aaa"
            roughness: 0.32
            metalness: 0.08
            emissiveFactor: Qt.vector3d(0.06, 0.10, 0.42 + 0.18 * movies.pulseB)
        }
    }
    Model {
        source: "#Cylinder"
        position: Qt.vector3d(-820, 150, -140)
        scale: Qt.vector3d(0.38, 3.0, 0.38)
        materials: PrincipledMaterial {
            baseColor: "#1a3aaa"
            roughness: 0.32
            metalness: 0.08
            emissiveFactor: Qt.vector3d(0.06, 0.10, 0.42 + 0.18 * movies.pulse)
        }
    }
    NeonBar {
        position: Qt.vector3d(-820, 302, 240)
        scale: Qt.vector3d(0.46, 0.05, 0.46)
        glow: "#00e5ff"
        heat: 1.6
    }
    NeonBar {
        position: Qt.vector3d(-820, 302, -140)
        scale: Qt.vector3d(0.46, 0.05, 0.46)
        glow: "#ff2bd6"
        heat: 1.6
    }

    // Poster wash lights
    PointLight {
        position: Qt.vector3d(-980, 160, 280)
        color: "#ff2bd6"
        brightness: 10 + 8 * movies.pulse
        quadraticFade: 0.0005
    }
    PointLight {
        position: Qt.vector3d(-980, 160, -220)
        color: "#00e5ff"
        brightness: 9 + 8 * movies.pulseB
        quadraticFade: 0.0005
    }
}
