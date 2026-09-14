pragma ComponentBehavior: Bound
import QtQuick
import QtQuick3D
import QtQuick3D.Helpers

// Arcade wing, right court. Original Nyxus cabinets — not licensed clones.
Node {
    id: arcade
    property real t: 0
    property real pulse: 1
    property real pulseB: 1
    position: Qt.vector3d(1000, 0, 0)

    function emitOf(c, k) {
        const col = (c && c.r !== undefined) ? c : Qt.color(c)
        return Qt.vector3d(col.r * k, col.g * k, col.b * k)
    }

    component NeonBar: Model {
        id: nbar
        source: "#Cube"
        property color glow: "#ff2bd6"
        property real heat: 1
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: nbar.glow
            emissiveFactor: arcade.emitOf(nbar.glow, (1.7 + 1.3 * arcade.pulse) * nbar.heat)
        }
    }

    component NeonTube: Model {
        id: ntube
        source: "#Cylinder"
        property color glow: "#ff2bd6"
        property real heat: 1
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: ntube.glow
            emissiveFactor: arcade.emitOf(ntube.glow, (1.8 + 1.3 * arcade.pulse) * ntube.heat)
        }
    }

    component NeonWord: Model {
        id: nword
        property string word: "ARCADE"
        property real depth: 12
        property int px: 48
        property color ink: "#ff2bd6"
        property real heat: 1
        scale: Qt.vector3d(-1, 1, 1)
        geometry: ExtrudedTextGeometry {
            text: nword.word
            depth: nword.depth
            font.pixelSize: nword.px
            font.bold: true
            font.family: "Noto Sans"
        }
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: nword.ink
            metalness: 0.05
            roughness: 0.12
            emissiveFactor: Qt.vector3d(
                nword.ink.r * (2.2 + 2.0 * arcade.pulse) * nword.heat,
                nword.ink.g * (2.2 + 2.0 * arcade.pulseB) * nword.heat,
                nword.ink.b * (2.2 + 2.0 * arcade.pulse) * nword.heat)
        }
    }

    // Upright cab. Local +Z is the player face.
    component Cab: Node {
        id: cab
        property int index: 0
        property string title: "NYX"
        property color body: "#c41870"
        property color accent: "#ff4ad8"
        property color crt: "#ff9ad8"
        property color rail: "#ff2a4a"
        property real cabH: 1
        property real yaw: -62
        property int kind: 0
        eulerRotation: Qt.vector3d(0, yaw, 0)

        readonly property real p: 0.52 + 0.48 * Math.sin(arcade.t * 2.35 + index * 0.85)
        readonly property real pb: 0.52 + 0.48 * Math.sin(arcade.t * 1.62 + index * 1.2 + 2.0)
        readonly property color vinyl: "#141018"
        readonly property color chrome: "#c8d4e0"

        // Kick plate
        Model {
            source: "#Cube"
            position: Qt.vector3d(0, 10, 8)
            scale: Qt.vector3d(0.78, 0.20, 0.74)
            materials: PrincipledMaterial {
                baseColor: cab.vinyl
                roughness: 0.38
                metalness: 0.1
            }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(0, 3, 8)
            scale: Qt.vector3d(0.80, 0.05, 0.76)
            materials: PrincipledMaterial {
                baseColor: cab.chrome
                roughness: 0.18
                metalness: 0.55
            }
        }

        // Lower body + coin door
        Model {
            source: "#Cube"
            position: Qt.vector3d(0, 48, -2)
            scale: Qt.vector3d(0.70, 0.58 * cab.cabH, 0.58)
            materials: PrincipledMaterial {
                baseColor: cab.body
                roughness: 0.24
                metalness: 0.12
                emissiveFactor: arcade.emitOf(cab.body, 0.16 * cab.p)
            }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(0, 38, 28)
            scale: Qt.vector3d(0.38, 0.28, 0.04)
            materials: PrincipledMaterial {
                baseColor: "#0c0c10"
                roughness: 0.32
                metalness: 0.2
            }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(0, 42, 31)
            scale: Qt.vector3d(0.22, 0.02, 0.02)
            materials: PrincipledMaterial {
                baseColor: "#050508"
                roughness: 0.4
            }
        }
        Model {
            source: "#Cylinder"
            position: Qt.vector3d(-10, 30, 31)
            scale: Qt.vector3d(0.05, 0.03, 0.05)
            materials: PrincipledMaterial {
                baseColor: cab.chrome
                roughness: 0.2
                metalness: 0.6
            }
        }
        Model {
            source: "#Cylinder"
            position: Qt.vector3d(10, 30, 31)
            scale: Qt.vector3d(0.05, 0.03, 0.05)
            materials: PrincipledMaterial {
                baseColor: cab.accent
                roughness: 0.15
                metalness: 0.35
                emissiveFactor: arcade.emitOf(cab.accent, 0.8 + 0.6 * cab.p)
            }
        }

        // Upper CRT housing
        Model {
            source: "#Cube"
            position: Qt.vector3d(0, 118 * cab.cabH, -6)
            scale: Qt.vector3d(0.70, 0.78 * cab.cabH, 0.52)
            materials: PrincipledMaterial {
                baseColor: cab.body
                roughness: 0.22
                metalness: 0.12
                emissiveFactor: arcade.emitOf(cab.body, 0.12 * cab.pb)
            }
        }
        // Recessed bezel
        Model {
            source: "#Cube"
            position: Qt.vector3d(0, 122 * cab.cabH, 18)
            scale: Qt.vector3d(0.56, 0.50 * cab.cabH, 0.10)
            materials: PrincipledMaterial {
                baseColor: "#0a0a0e"
                roughness: 0.16
                metalness: 0.28
            }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(0, 122 * cab.cabH, 24)
            scale: Qt.vector3d(0.50, 0.44 * cab.cabH, 0.03)
            materials: PrincipledMaterial {
                baseColor: "#050506"
                roughness: 0.1
                metalness: 0.15
            }
        }
        // CRT glass
        Model {
            source: "#Rectangle"
            position: Qt.vector3d(0, 122 * cab.cabH, 27)
            scale: Qt.vector3d(0.46, 0.40 * cab.cabH, 1)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: cab.crt
                emissiveFactor: Qt.vector3d(
                    cab.crt.r * (1.1 + 1.3 * cab.p),
                    cab.crt.g * (1.1 + 1.1 * cab.pb),
                    cab.crt.b * (1.2 + 1.2 * cab.p))
                cullMode: Material.NoCulling
            }
        }
        // Bloom plate
        Model {
            source: "#Rectangle"
            position: Qt.vector3d(0, 122 * cab.cabH, 26.2)
            scale: Qt.vector3d(0.52, 0.46 * cab.cabH, 1)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: cab.crt
                opacity: 0.28
                emissiveFactor: arcade.emitOf(cab.crt, 0.45 * cab.p)
                cullMode: Material.NoCulling
            }
        }
        // Scanlines
        Repeater3D {
            model: 6
            Model {
                required property int index
                source: "#Cube"
                position: Qt.vector3d(0, (122 * cab.cabH - 18) + index * 7.2, 27.4)
                scale: Qt.vector3d(0.45, 0.01, 0.008)
                materials: PrincipledMaterial {
                    lighting: PrincipledMaterial.NoLighting
                    baseColor: "#000000"
                    opacity: 0.32
                }
            }
        }
        // CRT highlight
        Model {
            source: "#Cube"
            position: Qt.vector3d(-6, 136 * cab.cabH, 27.6)
            scale: Qt.vector3d(0.28, 0.02, 0.006)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ffffff"
                opacity: 0.35
                emissiveFactor: Qt.vector3d(0.5, 0.55, 0.6)
            }
        }
        // Attract sprite — original geometry, not a licensed character
        Model {
            source: cab.kind === 2 ? "#Sphere" : (cab.kind === 4 ? "#Cone" : "#Cube")
            position: Qt.vector3d(
                Math.sin(arcade.t * (1.4 + cab.index * 0.17) + cab.index) * 12,
                122 * cab.cabH + Math.cos(arcade.t * (1.7 + cab.index * 0.11)) * 10,
                28.2)
            scale: cab.kind === 2 ? Qt.vector3d(0.08, 0.08, 0.04)
                 : (cab.kind === 4 ? Qt.vector3d(0.07, 0.12, 0.07)
                                   : Qt.vector3d(0.07, 0.07, 0.03))
            eulerRotation: Qt.vector3d(arcade.t * 40 + cab.index * 25, arcade.t * 28, 0)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: cab.index % 2 === 0 ? "#ffea00" : "#ffffff"
                emissiveFactor: Qt.vector3d(1.4, 1.2, 0.6 + 0.6 * cab.pb)
            }
        }
        Model {
            visible: cab.kind === 1 || cab.kind === 3
            source: "#Sphere"
            position: Qt.vector3d(
                Math.cos(arcade.t * 2.1 + cab.index) * 14,
                122 * cab.cabH + Math.sin(arcade.t * 1.9) * 8,
                28.2)
            scale: Qt.vector3d(0.045, 0.045, 0.03)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ffffff"
                emissiveFactor: Qt.vector3d(0.6, 1.3, 1.5)
            }
        }

        // Control shelf
        Model {
            source: "#Cube"
            position: Qt.vector3d(0, 82 * cab.cabH, 28)
            eulerRotation: Qt.vector3d(-16, 0, 0)
            scale: Qt.vector3d(0.72, 0.08, 0.42)
            materials: PrincipledMaterial {
                baseColor: "#1a1420"
                roughness: 0.2
                metalness: 0.22
            }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(0, 80 * cab.cabH, 46)
            eulerRotation: Qt.vector3d(-16, 0, 0)
            scale: Qt.vector3d(0.72, 0.03, 0.05)
            materials: PrincipledMaterial {
                baseColor: cab.chrome
                roughness: 0.14
                metalness: 0.62
            }
        }
        // Shelf neon lip
        NeonBar {
            position: Qt.vector3d(0, 78 * cab.cabH, 48)
            eulerRotation: Qt.vector3d(-16, 0, 0)
            scale: Qt.vector3d(0.70, 0.025, 0.025)
            glow: cab.rail
            heat: 0.85 + 0.2 * cab.p
        }

        // Stick
        Model {
            visible: cab.kind !== 2 && cab.kind !== 4
            source: "#Cylinder"
            position: Qt.vector3d(-16, 92 * cab.cabH, 30)
            scale: Qt.vector3d(0.035, 0.14, 0.035)
            materials: PrincipledMaterial {
                baseColor: "#2a2a30"
                roughness: 0.28
                metalness: 0.4
            }
        }
        Model {
            visible: cab.kind !== 2 && cab.kind !== 4
            source: "#Sphere"
            position: Qt.vector3d(-16, 102 * cab.cabH, 30)
            scale: Qt.vector3d(0.09, 0.09, 0.09)
            materials: PrincipledMaterial {
                baseColor: cab.accent
                roughness: 0.12
                metalness: 0.2
                emissiveFactor: arcade.emitOf(cab.accent, 0.7 + 0.5 * cab.p)
            }
        }
        // Second stick (co-op)
        Model {
            visible: cab.kind === 1
            source: "#Cylinder"
            position: Qt.vector3d(4, 92 * cab.cabH, 30)
            scale: Qt.vector3d(0.035, 0.14, 0.035)
            materials: PrincipledMaterial {
                baseColor: "#2a2a30"
                roughness: 0.28
                metalness: 0.4
            }
        }
        Model {
            visible: cab.kind === 1
            source: "#Sphere"
            position: Qt.vector3d(4, 102 * cab.cabH, 30)
            scale: Qt.vector3d(0.09, 0.09, 0.09)
            materials: PrincipledMaterial {
                baseColor: "#ffea00"
                roughness: 0.12
                emissiveFactor: Qt.vector3d(1.1, 0.9, 0.2)
            }
        }
        // Trackball
        Model {
            visible: cab.kind === 2
            source: "#Sphere"
            position: Qt.vector3d(-10, 90 * cab.cabH, 32)
            scale: Qt.vector3d(0.14, 0.14, 0.14)
            materials: PrincipledMaterial {
                baseColor: "#d8e8f0"
                roughness: 0.08
                metalness: 0.15
                emissiveFactor: Qt.vector3d(0.15, 0.2, 0.25)
            }
        }
        // Spinner
        Model {
            visible: cab.kind === 4
            source: "#Cylinder"
            position: Qt.vector3d(-12, 90 * cab.cabH, 32)
            eulerRotation: Qt.vector3d(90, arcade.t * 80, 0)
            scale: Qt.vector3d(0.16, 0.04, 0.16)
            materials: PrincipledMaterial {
                baseColor: cab.chrome
                roughness: 0.12
                metalness: 0.7
            }
        }

        // Buttons — cluster changes with kind
        Repeater3D {
            model: cab.kind === 3 ? 6 : (cab.kind === 5 ? 4 : 3)
            Model {
                required property int index
                source: "#Cylinder"
                position: Qt.vector3d(
                    (cab.kind === 1 ? 18 : 12) + (index % 3) * 8,
                    88 * cab.cabH,
                    32 - Math.floor(index / 3) * 8)
                scale: Qt.vector3d(0.055, 0.03, 0.055)
                materials: PrincipledMaterial {
                    baseColor: index % 2 === 0 ? cab.accent : "#ffea00"
                    roughness: 0.18
                    metalness: 0.15
                    emissiveFactor: arcade.emitOf(index % 2 === 0 ? cab.accent : "#ffea00",
                                                  0.55 + 0.55 * cab.pb)
                }
            }
        }

        // Marquee box
        Model {
            source: "#Cube"
            position: Qt.vector3d(0, 172 * cab.cabH, 4)
            eulerRotation: Qt.vector3d(-10, 0, 0)
            scale: Qt.vector3d(0.74, 0.30, 0.36)
            materials: PrincipledMaterial {
                baseColor: "#100814"
                roughness: 0.2
                metalness: 0.18
                emissiveFactor: arcade.emitOf(cab.accent, 0.22 * cab.p)
            }
        }
        Model {
            source: "#Rectangle"
            position: Qt.vector3d(0, 174 * cab.cabH, 22)
            eulerRotation: Qt.vector3d(-10, 0, 0)
            scale: Qt.vector3d(0.66, 0.24, 1)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: cab.accent
                emissiveFactor: arcade.emitOf(cab.accent, 0.85 + 0.7 * cab.p)
                cullMode: Material.NoCulling
            }
        }
        NeonWord {
            word: cab.title
            px: 20
            depth: 8
            ink: "#fff4ff"
            heat: 0.7 + 0.25 * cab.p
            position: Qt.vector3d(cab.title.length * 6.4, 170 * cab.cabH, 24)
            eulerRotation: Qt.vector3d(-10, 0, 0)
        }
        // Marquee bulbs
        Repeater3D {
            model: 7
            Model {
                required property int index
                source: "#Sphere"
                position: Qt.vector3d(-24 + index * 8, 186 * cab.cabH, 18)
                scale: Qt.vector3d(0.045, 0.045, 0.045)
                materials: PrincipledMaterial {
                    lighting: PrincipledMaterial.NoLighting
                    baseColor: index % 2 === 0 ? "#ffea00" : cab.accent
                    emissiveFactor: arcade.emitOf(index % 2 === 0 ? "#ffea00" : cab.accent,
                                                  1.1 + ((index + cab.index) % 2) * 0.8 * cab.p)
                }
            }
        }
        // Speaker grille between CRT and marquee
        Repeater3D {
            model: 8
            Model {
                required property int index
                source: "#Cylinder"
                position: Qt.vector3d(-12 + (index % 4) * 8, 154 * cab.cabH, 22)
                eulerRotation: Qt.vector3d(90, 0, 0)
                scale: Qt.vector3d(0.028, 0.018, 0.028)
                materials: PrincipledMaterial {
                    baseColor: "#0a0a0c"
                    roughness: 0.42
                    metalness: 0.28
                }
            }
        }

        // Side art panels
        Model {
            source: "#Rectangle"
            position: Qt.vector3d(-35.5, 100 * cab.cabH, 0)
            eulerRotation: Qt.vector3d(0, -90, 0)
            scale: Qt.vector3d(0.58, 1.15 * cab.cabH, 1)
            materials: PrincipledMaterial {
                baseColor: cab.accent
                roughness: 0.28
                emissiveFactor: arcade.emitOf(cab.accent, 0.28 + 0.22 * cab.pb)
                cullMode: Material.NoCulling
            }
        }
        Model {
            source: "#Rectangle"
            position: Qt.vector3d(35.5, 100 * cab.cabH, 0)
            eulerRotation: Qt.vector3d(0, 90, 0)
            scale: Qt.vector3d(0.58, 1.15 * cab.cabH, 1)
            materials: PrincipledMaterial {
                baseColor: cab.body
                roughness: 0.28
                emissiveFactor: arcade.emitOf(cab.body, 0.22 + 0.18 * cab.p)
                cullMode: Material.NoCulling
            }
        }
        // Side memphis: bolt / stripes / chevron
        NeonBar {
            visible: cab.kind === 0 || cab.kind === 3
            position: Qt.vector3d(-36.2, 118 * cab.cabH, 4)
            eulerRotation: Qt.vector3d(0, 0, 38)
            scale: Qt.vector3d(0.04, 0.04, 0.42)
            glow: "#ffea00"
            heat: 0.9
        }
        NeonBar {
            visible: cab.kind === 0 || cab.kind === 3
            position: Qt.vector3d(-36.2, 96 * cab.cabH, -6)
            eulerRotation: Qt.vector3d(0, 0, -42)
            scale: Qt.vector3d(0.04, 0.04, 0.32)
            glow: "#ffea00"
            heat: 0.8
        }
        Repeater3D {
            model: 4
            NeonBar {
                required property int index
                visible: cab.kind === 1 || cab.kind === 5
                position: Qt.vector3d(-36.2, (70 + index * 18) * cab.cabH, 0)
                scale: Qt.vector3d(0.03, 0.035, 0.50)
                glow: index % 2 === 0 ? cab.accent : "#ffea00"
                heat: 0.7
            }
        }
        NeonBar {
            visible: cab.kind === 2 || cab.kind === 4
            position: Qt.vector3d(-36.2, 108 * cab.cabH, 0)
            eulerRotation: Qt.vector3d(0, 0, 28)
            scale: Qt.vector3d(0.04, 0.04, 0.48)
            glow: cab.crt
            heat: 0.85
        }
        NeonBar {
            visible: cab.kind === 2 || cab.kind === 4
            position: Qt.vector3d(-36.2, 92 * cab.cabH, 0)
            eulerRotation: Qt.vector3d(0, 0, -28)
            scale: Qt.vector3d(0.04, 0.04, 0.48)
            glow: cab.crt
            heat: 0.85
        }

        // Front-corner neon rails (ref 13)
        NeonTube {
            position: Qt.vector3d(-34, 96 * cab.cabH, 28)
            scale: Qt.vector3d(0.045, 1.72 * cab.cabH, 0.045)
            glow: cab.rail
            heat: 1
        }
        NeonTube {
            position: Qt.vector3d(34, 96 * cab.cabH, 28)
            scale: Qt.vector3d(0.045, 1.72 * cab.cabH, 0.045)
            glow: cab.index % 2 === 0 ? "#00e5ff" : cab.rail
            heat: 0.9 + 0.15 * cab.pb
        }
        NeonTube {
            position: Qt.vector3d(0, 188 * cab.cabH, 16)
            eulerRotation: Qt.vector3d(0, 0, 90)
            scale: Qt.vector3d(0.04, 0.74, 0.04)
            glow: cab.accent
            heat: 0.95
        }

        // Floor bounce
        Model {
            source: "#Rectangle"
            position: Qt.vector3d(0, 1.2, 8)
            eulerRotation: Qt.vector3d(-90, 0, 0)
            scale: Qt.vector3d(0.9, 0.85, 1)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: cab.accent
                opacity: 0.22
                emissiveFactor: arcade.emitOf(cab.accent, 0.35 * cab.p)
            }
        }

        PointLight {
            visible: cab.index % 2 === 0
            position: Qt.vector3d(0, 122 * cab.cabH, 48)
            color: cab.crt
            brightness: 10 + 10 * cab.p
            quadraticFade: 0.0011
        }
    }

    component NeonRing: Node {
        id: nring
        property color glow: "#00e5ff"
        property real rad: 28
        Repeater3D {
            model: 14
            NeonBar {
                required property int index
                position: Qt.vector3d(
                    Math.cos(index * Math.PI / 7) * nring.rad,
                    Math.sin(index * Math.PI / 7) * nring.rad,
                    0)
                scale: Qt.vector3d(0.055, 0.055, 0.05)
                eulerRotation: Qt.vector3d(0, 0, index * (180 / 7) + 90)
                glow: nring.glow
                heat: 0.85 + 0.2 * arcade.pulse
            }
        }
    }

    // ── Cabinets, receding +X / −Z ──────────────────────────────────────
    Cab {
        index: 0; title: "NYX"; kind: 0; cabH: 1.04; yaw: -56
        body: "#c41870"; accent: "#ff4ad8"; crt: "#ff9ad8"; rail: "#ff2a4a"
        position: Qt.vector3d(-20, 0, 200)
    }
    Cab {
        index: 1; title: "BLAST"; kind: 1; cabH: 1.0; yaw: -60
        body: "#0e2030"; accent: "#00e5ff"; crt: "#7af6ff"; rail: "#00e5ff"
        position: Qt.vector3d(14, 0, 95)
    }
    Cab {
        index: 2; title: "PULSE"; kind: 2; cabH: 0.96; yaw: -64
        body: "#d4b018"; accent: "#ffea00"; crt: "#fff38a"; rail: "#ff2a4a"
        position: Qt.vector3d(-18, 0, -10)
    }
    Cab {
        index: 3; title: "COMET"; kind: 3; cabH: 1.08; yaw: -68
        body: "#1a0e30"; accent: "#b44aff"; crt: "#e0a8ff"; rail: "#00e5ff"
        position: Qt.vector3d(20, 0, -115)
    }
    Cab {
        index: 4; title: "RIFT"; kind: 4; cabH: 1.0; yaw: -72
        body: "#4a1038"; accent: "#ff2bd6"; crt: "#ff6bd8"; rail: "#ff2a4a"
        position: Qt.vector3d(-8, 0, -220)
    }
    Cab {
        index: 5; title: "EMBER"; kind: 5; cabH: 1.06; yaw: -76
        body: "#0a3a42"; accent: "#2effd0"; crt: "#8affe8"; rail: "#00e5ff"
        position: Qt.vector3d(24, 0, -325)
    }

    // ── Signs ───────────────────────────────────────────────────────────
    Node {
        position: Qt.vector3d(55, 278, 36)
        eulerRotation: Qt.vector3d(0, -16, 0)
        Model {
            source: "#Cube"
            position: Qt.vector3d(-92, 8, -10)
            scale: Qt.vector3d(2.15, 0.55, 0.08)
            materials: PrincipledMaterial {
                baseColor: "#120814"
                roughness: 0.22
                metalness: 0.2
                emissiveFactor: Qt.vector3d(0.35 * arcade.pulse, 0.05, 0.16)
            }
        }
        NeonWord {
            word: "ARCADE"
            px: 58
            depth: 16
            ink: "#ff4ad8"
            position: Qt.vector3d(0, 0, 0)
        }
        NeonBar {
            position: Qt.vector3d(-92, -28, 4)
            scale: Qt.vector3d(1.95, 0.04, 0.04)
            glow: "#00e5ff"
            heat: 1.1
        }
    }
    Node {
        position: Qt.vector3d(-28, 236, 158)
        eulerRotation: Qt.vector3d(0, -28, 0)
        Model {
            source: "#Cube"
            position: Qt.vector3d(-70, 4, -8)
            scale: Qt.vector3d(1.55, 0.38, 0.06)
            materials: PrincipledMaterial {
                baseColor: "#081018"
                roughness: 0.2
                emissiveFactor: Qt.vector3d(0.05, 0.22 * arcade.pulseB, 0.28)
            }
        }
        NeonWord {
            word: "GAME ON"
            px: 34
            depth: 12
            ink: "#00e5ff"
            position: Qt.vector3d(0, 0, 0)
        }
        NeonBar {
            position: Qt.vector3d(-70, -20, 3)
            scale: Qt.vector3d(1.4, 0.035, 0.035)
            glow: "#ffea00"
            heat: 0.95
        }
    }
    Node {
        position: Qt.vector3d(8, 214, -72)
        eulerRotation: Qt.vector3d(0, -12, 0)
        Model {
            source: "#Cube"
            position: Qt.vector3d(-78, 2, -8)
            scale: Qt.vector3d(1.72, 0.32, 0.06)
            materials: PrincipledMaterial {
                baseColor: "#141008"
                roughness: 0.22
                emissiveFactor: Qt.vector3d(0.28 * arcade.pulse, 0.18, 0.04)
            }
        }
        NeonWord {
            word: "INSERT COIN"
            px: 22
            depth: 10
            ink: "#ffea00"
            heat: 0.85 + 0.2 * arcade.pulseB
            position: Qt.vector3d(0, 0, 0)
        }
        NeonBar {
            position: Qt.vector3d(-78, -16, 3)
            scale: Qt.vector3d(1.55, 0.03, 0.03)
            glow: "#ff2bd6"
            heat: 1
        }
    }

    // ── Ceiling rails (ref 13) ──────────────────────────────────────────
    NeonTube {
        position: Qt.vector3d(-70, 318, -40)
        eulerRotation: Qt.vector3d(90, 0, 0)
        scale: Qt.vector3d(0.07, 5.6, 0.07)
        glow: "#ff2a4a"
        heat: 1.05
    }
    NeonTube {
        position: Qt.vector3d(48, 312, -40)
        eulerRotation: Qt.vector3d(90, 0, 0)
        scale: Qt.vector3d(0.07, 5.6, 0.07)
        glow: "#00e5ff"
        heat: 1.0 + 0.1 * arcade.pulseB
    }

    // Squiggle tubes over the bay (ref 01)
    Repeater3D {
        model: 18
        NeonTube {
            required property int index
            position: Qt.vector3d(
                -30 + Math.sin(index * 0.52 + arcade.t * 0.15) * 48,
                348,
                210 - index * 30)
            scale: Qt.vector3d(0.06, 0.24, 0.06)
            eulerRotation: Qt.vector3d(90, Math.cos(index * 0.52) * 32, 0)
            glow: index % 3 === 0 ? "#ff2bd6" : (index % 3 === 1 ? "#7a3dff" : "#00e5ff")
            heat: 0.8 + 0.25 * arcade.pulse
        }
    }
    Repeater3D {
        model: 16
        NeonTube {
            required property int index
            position: Qt.vector3d(
                36 + Math.sin(index * 0.58 + 1.2) * 40,
                338,
                180 - index * 32)
            scale: Qt.vector3d(0.055, 0.22, 0.055)
            eulerRotation: Qt.vector3d(90, Math.cos(index * 0.58) * 30, 0)
            glow: index % 2 === 0 ? "#00e5ff" : "#ffea00"
            heat: 0.75 + 0.2 * arcade.pulseB
        }
    }

    // Receding pink arches (ref 14)
    Repeater3D {
        model: 6
        Node {
            required property int index
            position: Qt.vector3d(-118, 0, 190 - index * 100)
            Repeater3D {
                model: 9
                NeonTube {
                    required property int index
                    property real a: index * Math.PI / 8
                    position: Qt.vector3d(0, 18 + Math.sin(a) * 205, Math.cos(a) * 72)
                    scale: Qt.vector3d(0.055, 0.22, 0.055)
                    eulerRotation: Qt.vector3d((index - 4) * 22.5, 0, 0)
                    glow: index % 2 === 0 ? "#ff2bd6" : "#ff6ad8"
                    heat: 0.9 + 0.15 * arcade.pulse
                }
            }
        }
    }

    // Wall wash tubes
    Repeater3D {
        model: 5
        NeonTube {
            required property int index
            position: Qt.vector3d(88, 40 + index * 48, -20)
            eulerRotation: Qt.vector3d(90, 0, 0)
            scale: Qt.vector3d(0.05, 4.8, 0.05)
            glow: index % 2 === 0 ? "#ff2bd6" : "#00e5ff"
            heat: 0.55 + 0.25 * (index % 2 === 0 ? arcade.pulse : arcade.pulseB)
        }
    }

    // ── Neon silhouettes (original, not licensed marks) ─────────────────
    Node {
        position: Qt.vector3d(72, 318, 88)
        eulerRotation: Qt.vector3d(0, -18, 12)
        Model {
            source: "#Cone"
            position: Qt.vector3d(0, 38, 0)
            scale: Qt.vector3d(0.26, 0.52, 0.26)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ff2bd6"
                emissiveFactor: arcade.emitOf("#ff2bd6", 1.8 + 1.2 * arcade.pulse)
            }
        }
        Model {
            source: "#Cylinder"
            position: Qt.vector3d(0, 8, 0)
            scale: Qt.vector3d(0.20, 0.28, 0.20)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ff2bd6"
                emissiveFactor: arcade.emitOf("#ff2bd6", 1.6 + arcade.pulse)
            }
        }
        Model {
            source: "#Sphere"
            position: Qt.vector3d(0, 22, 12)
            scale: Qt.vector3d(0.12, 0.12, 0.12)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#00e5ff"
                emissiveFactor: arcade.emitOf("#00e5ff", 2.0 + 1.2 * arcade.pulseB)
            }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(-20, 4, 0)
            eulerRotation: Qt.vector3d(0, 0, 32)
            scale: Qt.vector3d(0.22, 0.07, 0.04)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ffea00"
                emissiveFactor: arcade.emitOf("#ffea00", 1.7)
            }
        }
        Model {
            source: "#Cube"
            position: Qt.vector3d(20, 4, 0)
            eulerRotation: Qt.vector3d(0, 0, -32)
            scale: Qt.vector3d(0.22, 0.07, 0.04)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ffea00"
                emissiveFactor: arcade.emitOf("#ffea00", 1.7)
            }
        }
        Model {
            source: "#Cone"
            position: Qt.vector3d(0, -22, 0)
            eulerRotation: Qt.vector3d(180, 0, 0)
            scale: Qt.vector3d(0.16, 0.26, 0.16)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ffea00"
                emissiveFactor: Qt.vector3d(1.8 + 0.8 * arcade.pulse, 1.1, 0.2)
            }
        }
    }

    Node {
        position: Qt.vector3d(64, 336, -40)
        eulerRotation: Qt.vector3d(0, -14, 0)
        Model {
            source: "#Sphere"
            scale: Qt.vector3d(0.16, 0.16, 0.10)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ffea00"
                emissiveFactor: arcade.emitOf("#ffea00", 1.8 + 1.1 * arcade.pulseB)
            }
        }
        Repeater3D {
            model: 5
            Model {
                required property int index
                source: "#Cone"
                position: Qt.vector3d(
                    Math.cos(index * 1.2566) * 22,
                    Math.sin(index * 1.2566) * 22,
                    0)
                eulerRotation: Qt.vector3d(0, 0, index * 72 - 90)
                scale: Qt.vector3d(0.12, 0.28, 0.08)
                materials: PrincipledMaterial {
                    lighting: PrincipledMaterial.NoLighting
                    baseColor: "#ffea00"
                    emissiveFactor: arcade.emitOf("#ffea00", 1.6 + 0.9 * arcade.pulse)
                }
            }
        }
    }

    // Magma wisp — teardrop + crest + spark. Not a licensed ghost.
    Node {
        position: Qt.vector3d(70, 292, -168)
        eulerRotation: Qt.vector3d(0, -20, 8)
        Model {
            source: "#Sphere"
            scale: Qt.vector3d(0.42, 0.50, 0.30)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#b44aff"
                emissiveFactor: arcade.emitOf("#b44aff", 1.6 + 1.1 * arcade.pulse)
            }
        }
        Model {
            source: "#Sphere"
            position: Qt.vector3d(16, 12, 6)
            scale: Qt.vector3d(0.22, 0.22, 0.18)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ff2bd6"
                emissiveFactor: arcade.emitOf("#ff2bd6", 1.5 + arcade.pulseB)
            }
        }
        Model {
            source: "#Sphere"
            position: Qt.vector3d(-12, -16, 4)
            scale: Qt.vector3d(0.18, 0.16, 0.14)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#7a3dff"
                emissiveFactor: arcade.emitOf("#7a3dff", 1.4)
            }
        }
        Model {
            source: "#Cone"
            position: Qt.vector3d(0, 36, 0)
            scale: Qt.vector3d(0.10, 0.18, 0.10)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#00e5ff"
                emissiveFactor: arcade.emitOf("#00e5ff", 1.8 + arcade.pulseB)
            }
        }
        Model {
            source: "#Sphere"
            position: Qt.vector3d(24, 20, 10)
            scale: Qt.vector3d(0.08, 0.08, 0.08)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColor: "#ffea00"
                emissiveFactor: Qt.vector3d(1.8, 1.4, 0.3)
            }
        }
    }

    NeonRing {
        position: Qt.vector3d(58, 248, 150)
        eulerRotation: Qt.vector3d(0, -26, 0)
        glow: "#00e5ff"
        rad: 26
    }
    NeonRing {
        position: Qt.vector3d(58, 248, 148)
        eulerRotation: Qt.vector3d(0, -26, 0)
        glow: "#ff2bd6"
        rad: 16
    }

    // Entrance column
    Model {
        source: "#Cylinder"
        position: Qt.vector3d(-92, 96, 248)
        scale: Qt.vector3d(0.30, 1.92, 0.30)
        materials: PrincipledMaterial {
            baseColor: "#2a1040"
            roughness: 0.26
            metalness: 0.12
            emissiveFactor: Qt.vector3d(0.28 * arcade.pulse, 0.05, 0.18)
        }
    }
    Repeater3D {
        model: 4
        NeonBar {
            required property int index
            position: Qt.vector3d(-92, 36 + index * 42, 248)
            scale: Qt.vector3d(0.38, 0.04, 0.38)
            glow: index % 2 === 0 ? "#ff2bd6" : "#00e5ff"
            heat: 0.9
        }
    }

    PointLight {
        position: Qt.vector3d(20, 250, 40)
        color: "#ff2bd6"
        brightness: 14 + 12 * arcade.pulse
        quadraticFade: 0.00045
    }
    PointLight {
        position: Qt.vector3d(-40, 220, 160)
        color: "#00e5ff"
        brightness: 12 + 10 * arcade.pulseB
        quadraticFade: 0.0005
    }
    PointLight {
        position: Qt.vector3d(10, 200, -80)
        color: "#ffea00"
        brightness: 9 + 8 * arcade.pulse
        quadraticFade: 0.00055
    }
}
