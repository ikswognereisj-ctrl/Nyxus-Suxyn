// Nyxus Suxyn — STARLIGHT VOYAGE. The 3D sky, as a bottom layer.
//
// `Starlight.qml` hangs the Rolls-Royce headliner over the desktop. This is
// its 3D sibling: the same bottom-layer, never-clickable, premultiplied
// surface, but driving `shaders/starlight3d.frag` — a raymarched volume you
// drift through rather than a plane you look at.
//
// The realism lives in the shader. This file owns three things the shader
// cannot do for itself, and each of them has a trap in it:
//
//   1. THE CURSOR, and why this is not simply a MouseArea.
//   2. THE FRAME CLOCK, and why "lower the fps" is the second-best answer.
//   3. THE QUALITY LEVER, and what it is allowed to touch.
//
// ── 1 · the cursor ───────────────────────────────────────────────────────
// A wallpaper cannot read the global pointer. It is the BOTTOM layer-shell
// surface: the compositor routes pointer events to the topmost surface whose
// input region contains the cursor, so every window on screen gets them first
// and the wallpaper is told nothing. `Starlight.qml` leans into that with
// `mask: Region {}` — an empty input region, so it can never take a click
// (the whispers lesson, and WIP-7 where a stale mask ate every click meant
// for the Start menu).
//
// So the honest options are:
//   (a) hover events, which arrive ONLY while the pointer is over bare
//       desktop — which is exactly when the wallpaper is the thing you can
//       see. Costs nothing, needs no polling, and cannot lag.
//   (b) polling `hyprctl cursorpos`, which is genuinely global but spawns a
//       process per sample. This build already learned that lesson the
//       expensive way: two hyprlock labels spawning subprocesses every 50 ms
//       starved the event loop until the password field stopped accepting
//       input. A wallpaper is not worth that.
//
// This uses (a). The trade it makes is real and worth stating plainly: while
// `parallax` is true the wallpaper claims an input region, so a click on bare
// desktop lands on it instead of falling through. Below the bottom layer
// there is only the wallpaper itself, so nothing observable is stolen — but
// it IS a change from `mask: Region {}`, so it is a toggle, and turning it
// off restores the empty mask exactly.
//
// ── 2 · the frame clock ──────────────────────────────────────────────────
// The brief asked to drop the refresh rate when a window is fullscreened.
// Dropping it is the second-best answer: a fullscreen window covers this
// surface COMPLETELY, so every frame drawn underneath is 100% wasted, and 10
// fps of waste is still waste. The window is hidden outright instead, which
// releases the layer surface and takes the shader to zero. The rate ladder
// below is for the case that actually benefits from a rate: on battery, when
// the sky is visible and should simply cost less.
//
// ── 3 · the quality lever ────────────────────────────────────────────────
// `u_scene.w` scales the galaxy, ring and star loops in the shader. It
// deliberately does NOT scale the SDF march — dust has no edges to alias, so
// halving its samples is nearly invisible, whereas a coarser surface march
// puts stair-stepping on the planet's limb, which is the one thing in frame
// the eye is actually tracking.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    // ── the switches ─────────────────────────────────────────────────────
    // Local properties rather than Prefs entries: `Prefs.qml` is a shared
    // file and this is a new capability, not a change to a shipped one.
    // Wiring these into Settings > Appearance is a follow-up (see CHECKLIST).
    // OFF again 2026-08-10 03:06 — the owner ran it and it costs too much on
    // this machine: this is a full 3D raymarch (SDF + volumetric galaxy + four
    // star lattices) at 60 fps across the whole screen, which is a different
    // order of cost from a wallpaper. Do not switch this on again without a
    // frame-time measurement on the Iris Xe, not on a discrete card.
    property bool skyEnabled: false
    // OFF on the owner's call (2026-08-10). With the tilt off the surface keeps
    // `mask: Region {}` — the empty input region — so the wallpaper cannot take
    // a click at all, which is the safer state and the one Starlight.qml has
    // always been in. The plumbing below is intact; this is the only switch.
    property bool parallax: false
    property real density: 1.0            // 0..2
    property real driftSpeed: 1.0         // forward drift multiplier
    property real galaxyGain: 1.0
    property real parallaxAmount: 1.0     // 0 kills the tilt without dropping the input region

    // Frame ladder. `fpsAC` is the only number here anyone should need to
    // argue about; the shader is one pass and a 3060 does not notice it, but
    // the Iris Xe that actually scans out this laptop's panel does.
    property int fpsAC: 60
    property int fpsBattery: 24

    // ── scene mode ───────────────────────────────────────────────────────
    // "full"   — stars + galaxy + the ringed planet and its moons (desktop)
    // "galaxy" — stars + the dust band, no bodies (lock screen)
    // "stars"  — the field alone (login / greeter)
    //
    // These are not the same picture with parts hidden: dropping the bodies
    // skips the SDF march and dropping the dust skips the volumetric march,
    // which between them are most of the shader's cost. The cut-down modes are
    // genuinely cheaper, which is what makes them the right ones for a lock
    // screen that may sit on a dimmed panel for hours.
    // DEFAULT: "galaxy" — the owner's call 2026-08-10, "keep the moons and
    // planet out of it, keep everything else". The bodies stay in the shader
    // and one word here brings them back; nothing was deleted to satisfy this.
    property string sceneMode: "galaxy"

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    // TRK-3605 · THE SKY LIVES ON `Background`, NOT `Bottom`.
    //
    // The owner, 2026-09-01: "my background image goes over the widgets some
    // how". It does, and it is a stacking order rather than anything about the
    // material. `Widgets.qml` puts its chips on `WlrLayer.Bottom`, this surface
    // was on `WlrLayer.Bottom` too, and wlr-layer-shell stacks surfaces WITHIN
    // one layer by the order they map — so a full-screen opaque sky that maps
    // after the chips simply covers them. `Widgets.qml:483-492` had already
    // MEASURED this exact effect (card range 178.57 -> 128.96 with a sky on the
    // same level) and filed it as TRK-3605, concluding it "is NOT fixable in
    // this file" because `Bottom` is the highest rung the widgets can hold
    // without covering the owner's windows. That is true, and it points at the
    // other end of the problem: the fix is not to RAISE the widgets, it is to
    // LOWER the sky.
    //
    // `Background` is the layer below `Bottom`, which is where a wallpaper
    // belongs — `LiveWall.qml` has always used it, for this reason. Moving here
    // makes the sky-vs-widget order a LAYER fact instead of a map-order race,
    // so it cannot come back depending on which surface happened to map first.
    //
    // The sky surfaces keep their order relative to EACH OTHER: they are
    // mutually exclusive by gate anyway (`shell.qml:157/176/189` — Headliner
    // maps only when `skyWantsHeadliner`, Starlight only when it is neither
    // headliner nor plain wallpaper), and the two Starlight windows still stack
    // in instantiation order inside `Background` exactly as they did inside
    // `Bottom`. Nothing about what the sky LOOKS like changes; only what it is
    // allowed to cover.
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "nyxus-starlight3d"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"

    // Hidden outright under a fullscreen window — see note 2. This is the
    // single biggest power saving in the file and it is free.
    visible: root.skyEnabled && !root.coveredByFullscreen

    // The empty region is the resting state and the safe one; it is only
    // given up while the tilt is actually wanted.
    property Region noInput: Region {}
    mask: root.parallax ? null : root.noInput

    // ── is this screen covered? ──────────────────────────────────────────
    // `lastIpcObject` does not stream (WIP-117), so it is refreshed off
    // Hyprland's own socket rather than polled — same approach Frame.qml
    // settled on, and the reason there is no Timer in this section.
    readonly property var hlMonitor: Hyprland.monitorFor(root.screen)
    readonly property var topIpc: {
        const t = Hyprland.activeToplevel;
        return (t && t.lastIpcObject) ? t.lastIpcObject : null;
    }
    readonly property bool coveredByFullscreen: {
        const o = root.topIpc;
        if (!o || !root.hlMonitor) return false;
        // Only THIS screen. A film fullscreened on the external panel is no
        // reason to freeze the sky on the laptop's.
        return o.fullscreen !== 0 && o.monitor === root.hlMonitor.id;
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name;
            if (n === "fullscreen" || n === "activewindow" || n === "activewindowv2"
                || n === "openwindow" || n === "closewindow"
                || n === "workspace" || n === "workspacev2" || n === "monitorfocus")
                Hyprland.refreshToplevels();
        }
    }

    // ── the power state ──────────────────────────────────────────────────
    // Sys already wraps UPower's display device for the Vitals gauge; there is
    // no second battery reader in this build and this does not add one.
    readonly property bool onBattery: Sys.hasBattery && !Sys.batteryCharging
    readonly property int targetFps: root.onBattery ? root.fpsBattery : root.fpsAC
    readonly property real quality: root.onBattery ? 0.5 : 1.0

    // ── the window gate (WIP-245/249) ────────────────────────────────────
    // `clock` below stops with `root.visible`, so u_time freezes when this
    // surface is not on screen. `beatLift` did not: it is wired to Beat,
    // which advances at cava's frame rate for as long as music plays, and
    // it feeds u_look.w on an item that never stops existing. `skyEnabled`
    // ships false and `shell.qml:116-118` still instantiates the Variant for
    // every screen, so that binding was churning a uniform inside a window
    // the compositor has NEVER mapped — the WIP-245/249 fault exactly, and
    // the one shape that has segfaulted this shell twice.
    //
    // Two-stage, like Swirl.qml:195-199 and ReactiveEdge.qml:88-99: the
    // window's real visibility first, THEN a 250 ms settle, because that
    // visibility goes true at show() — a beat before the compositor has
    // finished the Wayland configure round-trip — and the map handshake is
    // precisely when the scene graph is least able to survive an item being
    // marked dirty.
    //
    // ⚠ `backingWindowVisible`, NOT `visible`. Quickshell distinguishes the
    // two and only one of them is what the canonical gate reads: `visible`
    // is the REQUESTED state (writable, and driven here by the binding on
    // `skyEnabled && !coveredByFullscreen`), while `backingWindowVisible` is
    // the backer's own, read-only. WindowInterface declares both — `visible`
    // → isVisible/setVisible, `backingWindowVisible` → isBackingWindowVisible,
    // isReadonly — and PanelWindow inherits them through
    // PanelWindowInterface. Swirl.qml:196-197 gates on the BACKING window,
    // because `Window.window` hands it a QQuickWindow and `_win.visible` is
    // therefore the backer's state, so arming this off `visible` would start
    // the settle before the backer was up and let the gate rise slightly
    // ahead of the one it exists to match.
    //
    // `Window.window` exists in Swirl/ReactiveEdge because those are
    // components that cannot know their host. This one IS the window, so it
    // asks the window directly — the way LiveWall.qml:141-151 arms the same
    // gate. The `Component.onCompleted` line is what covers a backer that is
    // already up at construction: LiveWall.qml:121-140 records what happens
    // without it — a gate armed only from a CHANGE handler never rises in a
    // window that was already up, and the thing it gates stays dead forever.
    property bool windowExposed: false
    onBackingWindowVisibleChanged: {
        if (backingWindowVisible) expose.restart();
        else { expose.stop(); windowExposed = false; }
    }
    Component.onCompleted: if (root.backingWindowVisible) expose.restart()
    Timer {
        id: expose
        interval: 250
        onTriggered: root.windowExposed = true
    }

    ShaderEffect {
        id: sky
        anchors.fill: parent
        blending: true

        // Names match `shaders/starlight3d.frag`'s uniform block member for
        // member — Qt binds them by name, and a typo here is a silently black
        // screen, not an error.
        property real u_time: 0
        property vector2d u_resolution: Qt.vector2d(width, height)
        property vector2d u_mouse: Qt.vector2d(mx, my)
        property vector4d u_look: Qt.vector4d(0.55, 0.90, 0.22, 1.0 + beatLift)
        property vector4d u_scene: Qt.vector4d(root.density, root.driftSpeed,
                                               root.galaxyGain, root.quality)
        // x bodies · y galaxy — see root.sceneMode
        property vector4d u_flags: Qt.vector4d(root.sceneMode === "full" ? 1 : 0,
                                               root.sceneMode === "stars" ? 0 : 1,
                                               0, 0)

        // WIP-553 — the owner's approved dark-glass ground, read live off
        // Theme.qml (never a hex literal here or in the shader). These are
        // the exact tokens the desktop widgets and the shelf right-click
        // menu wear, the two surfaces he approved in writing. `.w` is
        // unused padding; std140 wants vec4 alignment.
        property vector4d u_groundTop: Qt.vector4d(Theme.surfaceTop.r, Theme.surfaceTop.g, Theme.surfaceTop.b, 1.0)
        property vector4d u_groundMid: Qt.vector4d(Theme.surfaceMid.r, Theme.surfaceMid.g, Theme.surfaceMid.b, 1.0)
        property vector4d u_groundDeep: Qt.vector4d(Theme.surfaceDeep.r, Theme.surfaceDeep.g, Theme.surfaceDeep.b, 1.0)
        property vector4d u_groundEdge: Qt.vector4d(Theme.glassBorder.r, Theme.glassBorder.g, Theme.glassBorder.b, 1.0)

        // The sky breathes with the music, exactly as the 2D headliner does:
        // u_look.w is the master every star and every stroke is multiplied by,
        // so the beat rides a uniform that already exists.
        // Gate first, exactly as ReactiveEdge.qml:101 does it: with
        // `windowExposed` false the `&&` short-circuits and Beat is never
        // read, so the binding holds no dependency on it and cannot be
        // re-evaluated by the beat at all. 0 is already this expression's
        // no-music value, so an unmapped surface rests where a silent one
        // does and nothing about the picture changes while it is on screen.
        readonly property real beatLift: root.windowExposed && Beat.hot
            ? Math.min(0.7, Beat.pulse * 0.45 + Beat.energy * 0.25) : 0

        // Smoothed cursor, in −1..1, +y up. These are what the shader tilts by.
        property real mx: 0
        property real my: 0
        property real targetX: 0
        property real targetY: 0

        // Hover only. `HoverHandler` never accepts a button, so this reads the
        // pointer without pretending to be a click target.
        HoverHandler {
            id: hover
            enabled: root.parallax
            onPointChanged: {
                if (!hover.hovered) return;
                const p = hover.point.position;
                sky.targetX = (p.x / Math.max(sky.width, 1)) * 2.0 - 1.0;
                sky.targetY = -((p.y / Math.max(sky.height, 1)) * 2.0 - 1.0);
            }
            onHoveredChanged: {
                // Pointer gone (onto a window, or off the screen): ease the
                // tilt back to centre rather than freezing it at the edge.
                if (!hover.hovered) { sky.targetX = 0; sky.targetY = 0; }
            }
        }

        // One clock for the whole surface: it advances time AND eases the
        // cursor. A separate SpringAnimation would be a second animation
        // driver running at the display's full rate — which is precisely what
        // the frame ladder above exists to avoid, and it would keep the GPU
        // awake at 165 Hz while this timer ticked at 24.
        Timer {
            id: clock
            running: root.visible
            repeat: true
            interval: Math.max(8, Math.round(1000 / root.targetFps))
            onTriggered: {
                const dt = clock.interval / 1000.0;
                // Frame-rate-independent exponential smoothing. A plain
                // `v += (target - v) * 0.1` is not: it eases twice as fast at
                // 60 fps as at 30, so the tilt would visibly change character
                // the moment the laptop came off the charger.
                const k = 1.0 - Math.exp(-dt / 0.18);
                sky.mx += (sky.targetX * root.parallaxAmount - sky.mx) * k;
                sky.my += (sky.targetY * root.parallaxAmount - sky.my) * k;
                // Wrapped so u_time stays small — the shader's hashes are
                // fract()-based and lose their bit depth in the millions.
                sky.u_time = (sky.u_time + dt) % 3600;
            }
        }

        fragmentShader: Qt.resolvedUrl("shaders/starlight3d.frag.qsb")
    }
}
