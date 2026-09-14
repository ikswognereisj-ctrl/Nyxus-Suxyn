pragma ComponentBehavior: Bound
import QtQuick
import QtQuick3D

// Rocket Lobby 3D. Far cinematic view, 360 orbit until you walk.
// WASD move, arrows look. Neon tubes + signs — nothing flat.
Item {
    id: root
    property real orbit: 0
    property bool driving: false
    property real camX: 0
    property real camY: 200
    property real camZ: 1280
    property real lookYaw: 0
    property real lookPitch: -12
    readonly property real sway: 0
    property int held: 0
    property real t: 0
    readonly property real pulse: 1
    readonly property real pulseB: 1
    // bit0 W, 1 S, 2 A, 3 D, 4 left, 5 right

    function bitOn(b) { held |= (1 << b) }
    function bitOff(b) { held &= ~(1 << b) }

    Keys.onPressed: function (e) {
        root.driving = true
        if (e.key === Qt.Key_W || e.key === Qt.Key_Up) bitOn(0)
        else if (e.key === Qt.Key_S || e.key === Qt.Key_Down) bitOn(1)
        else if (e.key === Qt.Key_A) bitOn(2)
        else if (e.key === Qt.Key_D) bitOn(3)
        else if (e.key === Qt.Key_Left) bitOn(4)
        else if (e.key === Qt.Key_Right) bitOn(5)
        else if (e.key === Qt.Key_R) {
            driving = false
        } else if (e.key === Qt.Key_M) {
            Bus.openMedia()
        }
        e.accepted = true
    }
    Keys.onReleased: function (e) {
        if (e.key === Qt.Key_W || e.key === Qt.Key_Up) bitOff(0)
        else if (e.key === Qt.Key_S || e.key === Qt.Key_Down) bitOff(1)
        else if (e.key === Qt.Key_A) bitOff(2)
        else if (e.key === Qt.Key_D) bitOff(3)
        else if (e.key === Qt.Key_Left) bitOff(4)
        else if (e.key === Qt.Key_Right) bitOff(5)
        e.accepted = true
    }

    FrameAnimation {
        running: root.visible
        onTriggered: {
            if (!root.driving)
                return
            const rad = root.lookYaw * Math.PI / 180
            const sp = 7.5
            if (root.held & 1) {
                root.camX += Math.sin(rad) * sp
                root.camZ += Math.cos(rad) * sp
            }
            if (root.held & 2) {
                root.camX -= Math.sin(rad) * sp
                root.camZ -= Math.cos(rad) * sp
            }
            if (root.held & 4) {
                root.camX -= Math.cos(rad) * sp
                root.camZ += Math.sin(rad) * sp
            }
            if (root.held & 8) {
                root.camX += Math.cos(rad) * sp
                root.camZ -= Math.sin(rad) * sp
            }
            if (root.held & 16)
                root.lookYaw -= 1.6
            if (root.held & 32)
                root.lookYaw += 1.6
            root.camX = Math.max(-320, Math.min(320, root.camX))
            root.camZ = Math.max(-280, Math.min(820, root.camZ))
        }
    }

    ShaderEffect {
        id: texClock
        width: 1024
        height: 1024
        visible: false
        fragmentShader: Qt.resolvedUrl("shaders/floor_tex.frag.qsb")
        property vector2d uRes: Qt.vector2d(1024, 1024)
        property real uTime: 0
    }

    FloorSign { id: signMovies; title: "MOVIES"; sub: "THIS WAY"; neon: "#ffea00"; visible: false }
    FloorSign { id: signArcade; title: "ARCADE GAMES"; sub: "INSERT COIN"; neon: "#00e5ff"; visible: false }
    FloorSign { id: signGameOn; title: "GAME ON"; sub: ""; neon: "#00e5ff"; visible: false }
    FloorSign { id: signRecept; title: "RECEPT. DESK"; sub: "CONTINUE WATCHING"; neon: "#00e5ff"; visible: false }
    FloorSign { id: signMember; title: "MEMBER SERV."; sub: "CONTINUE PLAYING"; neon: "#ff2bd6"; visible: false }
    FloorHero { id: signHero; visible: false }
    FloorMarquee { id: signMarquee; visible: false }
    FloorNowPlaying { id: nowPlay; x: -8000; visible: true }
    FloorRocket { id: rocketArt; x: -3600; y: 0; visible: true }
    FloorGlow { id: glowStar; kind: "star"; x: -3900; visible: true }
    FloorGlow { id: glowMoon; kind: "moon"; x: -4200; visible: true }
    FloorGlow { id: glowPlanet; kind: "planet"; x: -4500; visible: true }
    FloorGlow { id: glowShoot; kind: "shoot"; x: -4800; visible: true }
    HeadlinerSky {
        id: ceilSky
        width: 1920
        height: 1080
        x: -4200
        y: 0
        visible: true
        active: true
        density: 1.25
        master: 1.15
        twinkleDepth: 0.55
    }
    Image { id: artNes; visible: false; source: Qt.resolvedUrl("floor-art/nes.png") }
    Image { id: artSnes; visible: false; source: Qt.resolvedUrl("floor-art/snes.png") }
    Image { id: artGen; visible: false; source: Qt.resolvedUrl("floor-art/megadrive.png") }
    Image { id: artN64; visible: false; source: Qt.resolvedUrl("floor-art/n64.png") }
    Image { id: artPsx; visible: false; source: Qt.resolvedUrl("floor-art/psx.png") }
    Image { id: artMame; visible: false; source: Qt.resolvedUrl("floor-art/mame.png") }
    Image { id: artGba; visible: false; source: Qt.resolvedUrl("floor-art/gba.png") }
    Image { id: artA26; visible: false; source: Qt.resolvedUrl("floor-art/atari2600.png") }
    FloorPosterArt { id: post0; title: "STARLIGHT"; neon: "#ff2bd6"; x: -5200; visible: true }
    FloorPosterArt { id: post1; title: "MAGMA"; neon: "#ff6b2b"; x: -5600; visible: true }
    FloorPosterArt { id: post2; title: "MIDNIGHT"; neon: "#00e5ff"; x: -6000; visible: true }
    FloorPosterArt { id: post3; title: "SHOWS"; neon: "#ffea00"; x: -6400; visible: true }
    FloorPosterArt { id: post4; title: "CONTINUE"; neon: "#9b5cff"; x: -6800; visible: true }
    FloorPosterArt { id: post5; title: "FEATURE"; neon: "#ff2bd6"; x: -7200; visible: true }
    Image { id: showGoose; visible: false; source: "file:///home/gowski/ToonCabinet/posters/goosebumps.jpg" }
    Image { id: showDino; visible: false; source: "file:///home/gowski/ToonCabinet/posters/dinosaurs.jpg" }
    Image { id: showSonic; visible: false; source: "file:///home/gowski/ToonCabinet/posters/sonic.jpg" }

    component Tube: Model {
        source: "#Cube"
        property int index: 0
        property color glow: "#ff2bd6"
        property vector3d emit: Qt.vector3d(1.4, 0.15, 0.8)
        materials: PrincipledMaterial {
            lighting: PrincipledMaterial.NoLighting
            baseColor: glow
            emissiveFactor: Qt.vector3d(emit.x * root.pulse, emit.y * root.pulseB, emit.z * root.pulse)
        }
    }

    View3D {
        id: view
        anchors.fill: parent
        camera: cam
        environment: SceneEnvironment {
            clearColor: "#140818"
            backgroundMode: SceneEnvironment.Color
            antialiasingMode: SceneEnvironment.MSAA
            antialiasingQuality: SceneEnvironment.Medium
            probeExposure: 1.2
        }

        PerspectiveCamera {
            id: cam
            position: root.driving
                      ? Qt.vector3d(root.camX, root.camY, root.camZ)
                      : Qt.vector3d(0, 215, 1180)
            eulerRotation: root.driving
                           ? Qt.vector3d(root.lookPitch, root.lookYaw, 0)
                           : Qt.vector3d(-7, 0, 0)
            clipNear: 8
            clipFar: 8000
            fieldOfView: 70
        }

        DirectionalLight {
            eulerRotation.x: -55
            eulerRotation.y: 20
            brightness: 0.35
            color: "#ffb0ff"
        }
        PointLight { position: Qt.vector3d(0, 300, 40); color: "#ff2bd6"; brightness: 18; quadraticFade: 0.00022 }
        PointLight { position: Qt.vector3d(260, 220, -40); color: "#00e5ff"; brightness: 14; quadraticFade: 0.00028 }
        PointLight { position: Qt.vector3d(-260, 220, -40); color: "#ffea00"; brightness: 10; quadraticFade: 0.0003 }

        // Carpet — locked diamond checker
        Model {
            source: "#Rectangle"
            position: Qt.vector3d(0, 0, 0)
            eulerRotation: Qt.vector3d(-90, 0, 0)
            scale: Qt.vector3d(28, 22, 1)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColorMap: Texture { sourceItem: texClock }
            }
        }

        FloorIsland {
            position: Qt.vector3d(0, 0, 30)
            pulse: root.pulse
            pulseB: root.pulseB
            t: root.t
            heroTex: signHero
            marqueeTex: signMarquee
            deskL: signRecept
            deskR: signMember
        }
        FloorScreens {
            position: Qt.vector3d(0, 390, 20)
            t: root.t
            pulse: root.pulse
            pulseB: root.pulseB
            nowTex: nowPlay
        }
        FloorMusic {
            position: Qt.vector3d(0, 0, 280)
            t: root.t
            pulse: root.pulse
            pulseB: root.pulseB
            nowTex: nowPlay
        }
        FloorMovies {
            t: root.t
            pulse: root.pulse
            pulseB: root.pulseB
        }
        FloorArcade {
            t: root.t
            pulse: root.pulse
            pulseB: root.pulseB
        }
        FloorCeiling {
            t: root.t
            pulse: root.pulse
            pulseB: root.pulseB
            starTex: glowStar
            moonTex: glowMoon
            planetTex: glowPlanet
            shootTex: glowShoot
            rocketTex: rocketArt
        }

        // Ceiling — our Headliner stars, then kid glow-stickers on top.
        Model {
            source: "#Rectangle"
            position: Qt.vector3d(0, 560, 0)
            eulerRotation: Qt.vector3d(90, 0, 0)
            scale: Qt.vector3d(28, 22, 1)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColorMap: Texture { sourceItem: ceilSky }
            }
        }

        // Wall rocket (mockup)
        Model {
            source: "#Rectangle"
            position: Qt.vector3d(-820, 280, -120)
            eulerRotation: Qt.vector3d(0, 18, -12)
            scale: Qt.vector3d(3.4, 4.2, 1)
            materials: PrincipledMaterial {
                lighting: PrincipledMaterial.NoLighting
                baseColorMap: Texture { sourceItem: rocketArt }
                emissiveFactor: Qt.vector3d(0.9 * root.pulse, 0.25, 0.7 * root.pulseB)
            }
        }

    }
}
