// Nyxus Suxyn — STARLIGHT HEADLINER. The owner's commission, 2026-08-17.
//
// His brief, in his own priority order (1 beats 2 beats 3 beats 4): tiny, very
// bright, very sparse points on true black, with NO halo and NO diffraction
// spikes — "a fibre tip is a hard point of light, not a photographed star."
// The picture itself is `shaders/headliner.frag`, and its header carries the
// four properties and how each one is satisfied by construction. This file is
// only the surface, the gates and the clock.
//
// ── WHY IT IS THE BACKGROUND AND NOT A LAYER OVER ONE ────────────────────────
// Property 3 is "truly black in the gaps, not near-black", and a TRANSPARENT
// black is a promise about somebody else's pixels. `Starlight.qml` is
// premultiplied-additive over the wallpaper on purpose — it lights a picture.
// This one IS the picture, so it is opaque, and the void in the gaps is this
// shader's own 0/0/0 rather than whatever the wallpaper happens to have there.
//
// It sits on the BOTTOM layer, which is where both existing skies sit and is
// the mechanism `Prefs.qml` already writes down: "a sky is a Bottom-layer
// surface, the wallpaper is Background, one layer further down, so a live sky
// always wins the pixel regardless of what wallpaper.conf names." That is the
// property that makes this work with NOTHING stopped — no daemon killed, no
// config rewritten, no race with `awww`. The still wallpaper carries on
// existing underneath, unwatched and unharmed, and flipping `sky_mode` back
// reveals it again in the same frame.
//
// ── AND NOTHING PAINTS OVER IT — ESTABLISHED, NOT ASSUMED ────────────────────
// `WIP-783` is the standing lesson: `nyxus_desktop.py` is a full-screen
// `bottom`-layer surface and it was silently painted over by `gtk.css`'s
// window glass, costing 96% of the wallpaper. So the stack was READ off the
// owner's running compositor rather than reasoned about — `hyprctl layers` on
// his session, recorded in the brief. Bottom holds, in stacking order: the
// three widget chips (small, and they are meant to be over the ground), then
// `nyxus-desktop` full-screen — which since commit 042f80da no longer wears
// the app-window glass and is transparent. This surface is declared BEFORE
// `Widgets{}` in shell.qml so qs creates it first and it lands beneath both.
// Above Bottom there is only the bar, the side panel and the overlays, all of
// which are supposed to be over the desktop.
//
// ── THE GATES ARE THE SHELL'S, EXTENDED, NOT REPLACED ────────────────────────
// `windowExposed` is `Starlight.qml`'s two-stage gate verbatim, off
// `backingWindowVisible` and not `visible` (they are different things on a
// Quickshell PanelWindow, and only the backer's is read-only and true), plus
// the 250 ms settle past the Wayland configure round-trip. `batterySaver` and
// `_saving` are `Swirl.qml`'s, with the same meaning and the same opt-out
// property name, and `running` is the same conjunction shape. The quality
// ladder is `Theme.swirlTiers` — READ, not copied, and not re-declared: this
// surface has no tier table of its own to drift from `accent.json`'s.
//
// ── WHAT MOVED OUT, 2026-08-17 (the lock + screensaver commission) ───────────
// The owner asked for this same sky behind the login screen and behind a real
// screensaver. `Headliner` is a PanelWindow and Qt will not parent a window
// into the lock surface's item tree, so the DRAWING half of this file — the
// ShaderEffect, its uniforms, the tier ladder and the twinkle clock — now lives
// in `HeadlinerSky.qml`, and all three surfaces instantiate that one Item.
//
// Nothing about the desktop's sky changed. This window keeps its layer, its
// namespace, its mask, its true-black ground and its two-stage exposure gate,
// and hands that gate to the Item as `active`. `batterySaver` and `qualityTier`
// are forwarded so the property names an operator would reach for are still on
// the type they have always been on. `shaders/headliner.frag` was not opened.
import Quickshell
import Quickshell.Hyprland
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
    WlrLayershell.namespace: "nyxus-headliner"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // THE VOID. Opaque, and it is exactly #000000 rather than the ground token
    // `_tokens.edges.ground` (#020506) — which is a deliberate, reported
    // departure and not an oversight. #020506 measures luminance 4 on the
    // 0-255 ruler; the owner's acceptance target for this surface is that the
    // gaps measure 0. This is the one place in the build where near-black is
    // not black enough, because it is the only surface whose subject IS the
    // contrast between a point and nothing. Owner ruling requested in the
    // brief; until he rules, the four properties win, because he ranked them.
    //
    // The KEYWORD and not the hex, and that is gate 13pu's rule rather than a
    // preference: "black / white / transparent are allowed anywhere: a
    // MultiEffect mask and a gradient terminator are structure, not colour",
    // while any `"#rrggbb"` outside Theme.qml is drift by definition. `black`
    // is the same pixel and it is not a colour choice — which is exactly the
    // claim being made here. `LiveWall.qml` writes it the same way for the
    // same reason.
    color: "black"

    // Not a surface. It never takes a pointer event. (`LiveWall.qml` gives up
    // its empty mask to be stirred by the cursor; there is nothing here to
    // stir, so it keeps it — the WIP-7 lesson, where a stale mask ate every
    // click meant for the Start menu.)
    mask: Region {}

    // ── the two-stage window gate (WIP-245/249), Starlight.qml's exactly ─────
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

    readonly property var hlMonitor: Hyprland.monitorFor(root.screen)
    readonly property var topIpc: {
        const t = Hyprland.activeToplevel;
        return (t && t.lastIpcObject) ? t.lastIpcObject : null;
    }
    function _coversViewport(o) {
        if (!o || !root.hlMonitor)
            return false;
        if (o.monitor !== root.hlMonitor.id)
            return false;
        if (o.fullscreen !== 0)
            return true;
        const at = o.at;
        const size = o.size;
        if (!at || !size || at.length < 2 || size.length < 2)
            return false;
        const pad = 6;
        return at[0] <= pad && at[1] <= pad
            && size[0] >= root.screen.width - pad * 2
            && size[1] >= root.screen.height - pad * 2;
    }
    readonly property bool coveredByViewport: {
        const o = root.topIpc;
        return root._coversViewport(o);
    }
    onCoveredByViewportChanged: console.log("[Headliner] "
                                            + (coveredByViewport
                                               ? "viewport covered — pausing twinkle"
                                               : "viewport exposed — resuming twinkle"))
    Timer {
        id: headlinerRefresh
        interval: 40
        repeat: false
        onTriggered: Hyprland.refreshToplevels()
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name;
            if (n === "fullscreen" || n === "openwindow" || n === "closewindow"
                || n === "activewindow" || n === "activewindowv2"
                || n === "workspace" || n === "workspacev2" || n === "monitorfocus")
                headlinerRefresh.restart();
        }
    }

    // ── ON BATTERY (Swirl.qml's rule, extended not replaced) ─────────────────
    // Swirl's `_saving` exists because half a core, continuously, is a real
    // bite out of an unplugged afternoon. The same argument applies here and
    // the same property name is kept so one habit covers both surfaces — but
    // the CONSEQUENCE is different, and deliberately gentler: the swirl stops
    // drifting, this one stops TWINKLING. The field is still there, every
    // point still at its own brightness, because the still is the picture and
    // the twinkle is what makes it alive. A wallpaper that goes black on
    // battery is a bug report; a wallpaper that stops breathing is a battery
    // saving. Costs nothing to prove: with `running` false the Timer stops,
    // `uTime` freezes, and the ShaderEffect renders the frozen frame the
    // scene graph is already compositing — which is exactly what the swirl's
    // `floor` tier does, "a still frame, not a paused animation mid-motion"
    // (COMPLETION_SPEC 3.6, NYXUS_GLASS 1.9).
    //
    // FORWARDED, not re-implemented: the behaviour lives in `HeadlinerSky.qml`
    // and this is the name an operator reaches for on the type they know.
    property bool batterySaver: true
    property string qualityTier: "auto"

    // Kept as the window's own read-outs so anything that watched them still
    // can, and so nothing has two definitions.
    readonly property bool _saving: skyItem._saving
    readonly property bool running: skyItem.running

    HeadlinerSky {
        id: skyItem
        anchors.fill: parent
        // The window half of the gate, which an Item cannot compute for itself.
        active: root.windowExposed && !root.coveredByViewport
        batterySaver: root.batterySaver
        qualityTier: root.qualityTier
        // The commissioned look, unchanged: 0.45 twinkle depth, full density,
        // full master. These are the three numbers `uLook` has always carried.
        // ── TRK-3491 · owner 2026-08-30: "intensify the stars even more" ──
        // ⚠ THESE ARE THE LIVE VALUES, and the defaults in HeadlinerSky.qml
        // are not. That file declares 0.45 / 1.0 / 1.0 too, so raising them
        // there looks like it should work and changes nothing — this
        // instance overrides them. One source of truth, and it is here.
        //
        // The shader clamps density to 0..2, so 1.0 sat at half the available
        // range. 1.65 with TRK-3490's five strata roughly doubles the
        // population again, and because it scales every lattice's occupancy
        // together the near/far size ladder survives instead of being
        // flattened into one stratum.
        twinkleDepth: 0.45
        density: 1.65
        // A modest lift only. The field is meant to be mostly dark — pushing
        // master hard turns a scatter of fibres into a grey haze.
        master: 1.18
    }
}
