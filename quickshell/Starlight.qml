// Nyxus Suxyn — STARLIGHT. The Rolls-Royce Starlight Headliner over the desk.
//
// The owner's ask (2026-08-09): "as real as looking at the one, literally" —
// the fibre-optic ceiling, ported from design/starlight-live.html the same
// way the Swirl was ported from swirl-live.html. The realism itself lives in
// shaders/starlight.frag (tiers, per-star scintillation, halo + diffraction
// spikes, temperature, bursts); this file is only the surface:
//
//   · BOTTOM layer, full screen: it lights the wallpaper and nothing else —
//     windows, bar and panels all stack over it. The desktop is the ceiling.
//   · EMPTY input mask: it can never take a click (the whispers lesson).
//   · Premultiplied additive: the stars are ADDED light over the wallpaper's
//     night, not a black sheet painted across it.
//   · 25 fps drive, and ONLY while enabled — twinkle is slow by nature and
//     the shader is one procedural pass; there is nothing to pay at rest.
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

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
    WlrLayershell.namespace: "nyxus-starlight"
    color: "transparent"
    visible: Prefs.starlightEnabled

    // Not a surface. It never takes a pointer event.
    mask: Region {}

    // ── the window gate (WIP-245/249) ────────────────────────────────────
    // The Timer at the bottom already stops with `root.visible`, so uTime
    // freezes when the headliner is switched off. `beatLift` did not: it is
    // wired to Beat, which advances at cava's frame rate for as long as
    // music is audible, and it feeds uLook on an item that goes on existing
    // after this window unmaps. Switching the sky off in Settings mid-track
    // therefore left a per-frame binding marking a shader dirty inside an
    // unmapped window — the WIP-245/249 fault, the one that has segfaulted
    // this shell in QQuickItemPrivate::addToDirtyList().
    //
    // Two-stage like Swirl.qml:195-199: the window's real visibility, THEN a
    // 250 ms settle. A window's visibility goes true at show(), before the
    // compositor has completed the Wayland configure round-trip, and the map
    // handshake is exactly when the scene graph is least able to survive a
    // dirty item.
    //
    // ⚠ `backingWindowVisible`, NOT `visible`. On a Quickshell PanelWindow
    // those are two different things and only one of them is what the
    // canonical gate reads. `visible` is the REQUESTED state — writable, and
    // set here by a binding on Prefs — whereas `backingWindowVisible` is the
    // backer's own, read-only and reported by the window itself.
    // WindowInterface declares both (`visible` → isVisible/setVisible;
    // `backingWindowVisible` → isBackingWindowVisible, readonly), and
    // PanelWindow inherits them. Swirl.qml:196-197 gates on the BACKING
    // window — `Window.window` is a QQuickWindow, so `_win.visible` is the
    // backer — so arming this off `visible` would start the settle a beat
    // early, before the backer is up, and rise slightly ahead of the gate it
    // is supposed to match. `Window.window` is how Swirl and ReactiveEdge
    // find a host they cannot know; this file IS the window, so it asks the
    // window directly, the way LiveWall.qml:141-151 arms the same gate.
    //
    // The `Component.onCompleted` line is not decoration: LiveWall.qml:121-140
    // is the write-up of a gate that only ever armed from a CHANGE handler and
    // so never rose at all in a window that was already up.
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
        anchors.fill: parent
        blending: true

        property real uTime: 0
        property real uDensity: Prefs.starlightDensity
        // uRes.z = shooting-star gate · uRes.w = celestial-artwork gate (the
        // RR Bespoke painted galaxy, in the theme's measured stops — WIP-206)
        property vector4d uRes: Qt.vector4d(width, height, Prefs.starlightShooting ? 1 : 0,
                                            Prefs.starlightNebula ? 1 : 0)
        // The sky breathes with the music (owner 2026-08-09: "my whole
        // system just goes to the beat"). uLook.w is the master intensity
        // the shader already multiplies every star and every stroke of
        // artwork by (frag line `col *= uLook.w`), so the beat rides a
        // uniform that exists — no shader change, no qsb rebuild. Beat's
        // pulse decays smoothly on its own (0.86/frame), which is the
        // flare-and-settle shape; zero when no music is audible, so the
        // resting sky is numerically identical to before.
        // Gate first, exactly as ReactiveEdge.qml:101 does it: with
        // `windowExposed` false the `&&` short-circuits, Beat is never read,
        // and the binding keeps no dependency that the beat could fire. The
        // comment above already says the resting value is zero, so an
        // unmapped sky rests where a silent one does — numerically identical
        // to before, and untouched while the window is on screen.
        readonly property real beatLift: root.windowExposed && Beat.hot
            ? Math.min(0.7, Beat.pulse * 0.45 + Beat.energy * 0.25) : 0

        // x twinkleSpeed · y sparkle(spikes) · z warmth · w master intensity.
        // THE REFERENCE DEMO'S OWN DEFAULTS — v1 shipped warmth 0.55 against
        // the demo's 0.22 and the whole field read amber; a real headliner
        // is icy white with warm points as the exception (WIP-205).
        property vector4d uLook: Qt.vector4d(0.55, 0.90, 0.22, 1.0 + beatLift)

        fragmentShader: Qt.resolvedUrl("shaders/starlight.frag.qsb")

        // A Timer, NOT a NumberAnimation: an animation redraws at the display's
        // full frame rate, and twinkle cannot use 165 Hz. 25 fps is invisible
        // for motion this slow and pays a fraction of the GPU. Wraps at 3600 s
        // so uTime stays small for the shader's sin() precision.
        Timer {
            running: root.visible
            repeat: true
            interval: 40
            onTriggered: parent.uTime = (parent.uTime + 0.040) % 3600
        }
    }
}
