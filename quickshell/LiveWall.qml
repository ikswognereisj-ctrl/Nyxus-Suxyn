// LiveWall — the owner's wallpaper, with the swirls inside the galaxy stirred
// by the cursor the way the taskbar's paint is.
//
// His words, and they are the whole specification:
//   "the swirls i want inside the galaxy so if i move over it it swirls like
//    the bottom bar does — everything else just stays put and doesn't move"
//
// ── WHAT THIS IS NOT ─────────────────────────────────────────────────────
// It is not a generated sky. `Starlight3D.qml` is that, and it was the wrong
// answer to this question twice: he has a picture he likes, and the job is to
// move part of it. Every pixel outside the galaxy here is his file, untouched.
//
// ── WHY IT IS CHEAP, WHICH IS NOT AN ACCIDENT ────────────────────────────
// He turned the 3D sky off within minutes — "i cant have that running on my
// machine its taking too much" — and he was right: that is a full raymarch
// (SDF + volumetric integral + four star lattices) at 60 fps across the whole
// screen. This is a different order of cost, for two structural reasons:
//
//   · `Swirl.qml` STOPS. With no stimulus it settles, and after `lingerMs`
//     its FrameAnimation stops and every buffer goes non-live — zero solver
//     passes on an idle desktop. The wallpaper only costs anything while the
//     cursor is actually stirring it.
//   · The solver runs at a FIXED small resolution (short side 96 for velocity,
//     224 for dye) whatever surface it is on, so full-screen costs the same as
//     the bar does. Only the final composite is at screen resolution, and it
//     early-outs on the empty sky, which is more than half the picture.
//
// ── THE ONE REAL TRADE, STATED PLAINLY ───────────────────────────────────
// To be stirred by the cursor this surface must CLAIM AN INPUT REGION, and
// that is a departure from `mask: Region {}` — the empty region every other
// wallpaper-class surface in this build uses so it can never take a click
// (WIP-7, where a stale mask ate every click meant for the Start menu).
// Hover events only arrive while the pointer is over bare desktop, which is
// exactly when the wallpaper is the thing you can see, so the cost is: a click
// on bare desktop lands here instead of falling through. Below the Background
// layer there is only the wallpaper itself, so nothing observable is stolen —
// but it IS a change, so `interactive` is a separate switch from `wallEnabled`
// and turning it off restores the empty mask exactly.
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    // ── the switches ─────────────────────────────────────────────────────
    // OFF by default, deliberately. The owner asked for this at the same time
    // as he asked for the 3D sky to stop costing him — so nothing here starts
    // running on his machine until he says so. One word.
    property bool wallEnabled: false
    // Cursor stirring. See "THE ONE REAL TRADE" above. With this false the
    // surface keeps the empty input region and the galaxy simply sits still.
    property bool interactive: true

    // His picture, at the path an INSTALLED system has it. TRK-3493: this
    // used to be the absolute repo path under /home/cosmic, which is a
    // developer machine's layout — on any installed system that file does not
    // exist and the surface would come up empty the moment `wallEnabled` was
    // turned on. The airootfs copy is staged to exactly this path by the bake,
    // and the preview session reads the same one, so this default is now
    // correct in both places instead of only in the tree it was written in.
    //
    // TRK-3607 (LIVEBIND): named `fallbackWallpaper` rather than left as a bare
    // literal on `wallpaper`, so the instantiation site (shell.qml) can bind
    // `wallpaper` to the user's ACTUAL selection and still fall back to this
    // exact known-good file — for "no wallpaper chosen yet" (empty string from
    // the parse) and, below, for "the chosen file is gone" (Image.Error) —
    // without a second literal drifting out of sync with this one.
    readonly property url fallbackWallpaper: "file:///usr/share/backgrounds/nyxus/suxyn-voyage-galaxy.png"
    property url wallpaper: root.fallbackWallpaper

    // ── the look ─────────────────────────────────────────────────────────
    // displacePx  how far the fluid may push the dust, in pixels at 1080p
    // paintBleed  how much of the liquid's own colour shows in the band
    // paintLift   how much the liquid brightens what it flows over
    // The furthest the fluid may push the dust, in pixels. This is now an
    // honest maximum: the shader takes only the DIRECTION from the fluid's
    // gradient and saturates the magnitude, because the raw gradient of a
    // smooth 480×270 field is ~0.02 and using it as a distance made a working
    // build look broken (2 px of movement at a nominal 90).
    property real displacePx: 45.0
    // How briskly a weak flow reaches that maximum. Higher = the faintest
    // eddy already pushes at full strength.
    property real flowGain: 70.0
    // BOTH ZERO, and that is the correction that made this look right. The
    // first cut bled the solver's own dye and its brightness into the band,
    // and on screen that is a big magenta cloud sitting ON the galaxy — you
    // see the fluid, not his picture moving. "Everything else just stays put"
    // has a corollary: the part that DOES move must still be his galaxy. So
    // the fluid is used purely as a force field and contributes no colour and
    // no light of its own. Raise these only if he asks to see the liquid
    // itself in there.
    property real paintBleed: 0.0
    property real paintLift: 0.0
    // maskLo/maskHi are on the picture's own blurred, saturation-weighted
    // luminance. maskLo is ABOVE ZERO on purpose: smoothstep clamps, so the
    // empty sky comes out exactly 0.0 and "everything else stays put" is true
    // by arithmetic rather than by being too small to notice.
    property real maskLo: 0.055
    property real maskHi: 0.30
    property real maskRadiusPx: 26.0     // wide: finds the band, ignores stars
    property real detailRadiusPx: 2.6    // tight: splits dust from stars

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "nyxus-livewall"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "black"

    visible: root.wallEnabled

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
    readonly property bool coveredByViewport: root._coversViewport(root.topIpc)
    Timer {
        id: livewallRefresh
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
                livewallRefresh.restart();
        }
    }

    // The empty region is the resting state and the safe one; it is only given
    // up while the stirring is actually wanted.
    property Region noInput: Region {}
    mask: root.interactive ? null : root.noInput

    // ── IS ANYTHING ACTUALLY MOVING? ─────────────────────────────────────
    // The single most important property in this file. While the fluid is
    // asleep the wallpaper is a STILL PICTURE, and a still picture must cost
    // what a still picture costs: the composite is not hidden-but-running, it
    // is not rendered at all, and the plain Image is shown instead.
    //
    // This is the fix for the measurement that kept the first version switched
    // off — ON 84.9/126.5/127.7 %CPU against OFF 51.4/49.3/49.1 on the owner's
    // own shell, with the fluid already asleep in both.
    //
    // `settle` holds the composite up for a beat after the solver stops,
    // because Swirl fades its field out over ~1.5 s rather than cutting it.
    // Swapping to the still image before that fade completes would snap the
    // last displacement away in one frame, which is exactly the "it stops and
    // disappears right away" the owner objected to in the bar.
    // ── WAKING THE SOLVER, AND WHY IT NEEDS DOING FROM OUT HERE ──────────
    // `Swirl.running` is gated on `windowExposed`, which `Swirl.qml` raises
    // from `on_WinVisibleChanged` — a handler that fires on a CHANGE. That is
    // correct for every surface it was written for: a panel is built while its
    // window is still unmapped, so the window goes false → true under it and
    // the handler runs. (The gate exists for a real crash: WIP-245/249, a sim
    // ticking inside a window the compositor has not finished mapping.)
    //
    // This window is different. It is created by a `Variants` model that only
    // populates once `livingWallpaper` is true, so the window is ALREADY
    // visible when the Swirl is constructed. `_winVisible` starts true, never
    // changes, the handler never fires, `windowExposed` stays false — and the
    // solver never runs at all. The owner moved his mouse over the galaxy and
    // reported "nothing happen", and he was exactly right: nothing was
    // running. No amount of tuning the displacement would have shown anything.
    //
    // Reproduced from outside rather than by editing Swirl.qml, which belongs
    // to the fluid lane: the same 250 ms settle, armed off THIS window's
    // visibility, which does have a defined initial state. Filed as WIP-264 —
    // any Swirl built inside an already-mapped window has this problem, not
    // just this one.
    Timer {
        id: expose
        interval: 400
        repeat: false
        onTriggered: fluid.windowExposed = true
    }
    onVisibleChanged: {
        if (visible) expose.restart();
        else { expose.stop(); fluid.windowExposed = false; }
    }
    Component.onCompleted: if (root.visible) expose.restart()

    readonly property bool stirring: fluid.running
    onStirringChanged: if (!stirring) settle.restart()
    Timer { id: settle; interval: 2600; repeat: false }
    readonly property bool composing: root.wallEnabled
                                      && !root.coveredByViewport
                                      && (fluid.running || settle.running)

    // The picture. An Image is a texture provider in its own right, so it can
    // be handed straight to a ShaderEffect without a ShaderEffectSource
    // blitting the whole screen every frame — and it is ALSO what is shown,
    // directly, whenever nothing is moving.
    // TRK-3607 (LIVEBIND): honest handling for "the chosen file is gone" — a
    // stale `wallpaper.conf` pointing at a deleted/renamed PNG. Without this,
    // `wall.source` resolves to `Image.Error`, the Image paints nothing, and
    // the PanelWindow's own `color: "black"` behind it shows through: a full
    // black screen, not a crash, but not honest either. `wallpaperBroken`
    // routes the Image at `root.fallbackWallpaper` instead — the one file this
    // build always ships — and clears the moment `root.wallpaper` changes, so
    // a fresh pick (or the same file reappearing) gets a real retry rather
    // than being stuck on the fallback forever.
    property bool wallpaperBroken: false
    onWallpaperChanged: root.wallpaperBroken = false

    Image {
        id: wall
        anchors.fill: parent
        source: root.wallpaperBroken ? root.fallbackWallpaper : root.wallpaper
        // Fit, not Crop: a 16:9 master fills a 16:9 screen. Crop on
        // 1920x1200 (hyprlock-eye) threw the scene away on 1920x1080.
        // 16:10 letterboxes until a 1920x1080 master lands.
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        smooth: true
        visible: !root.composing
        // BOTH of these, and the second one is not belt-and-braces — it is the
        // bug. `onStatusChanged` fires on a CHANGE; with `cache: true` and the
        // file already in Qt's image cache the status is `Ready` before this
        // handler exists, so it never fires, `bake()` is never called, and
        // `prepTex` stays a ShaderEffectSource that has never rendered.
        //
        // Qt then silently refuses to draw a ShaderEffect whose sampler does
        // not resolve to a valid texture — so the ENTIRE composite disappears.
        // Not a subtle artifact: nothing renders, the plain Image shows
        // through, and the wallpaper looks exactly like a wallpaper. That is
        // what the owner was looking at when he said "nothing happen", and it
        // survived a shader rewrite, a layer change and a solver-wake fix
        // because every one of those was downstream of a pass that was never
        // running. Proved by making the fragment shader output solid red:
        // 0.0% of the screen turned red.
        onStatusChanged: {
            if (status === Image.Ready) {
                root.bake();
            } else if (status === Image.Error && !root.wallpaperBroken
                       && String(root.wallpaper) !== String(root.fallbackWallpaper)) {
                root.wallpaperBroken = true;
            }
        }
        Component.onCompleted: if (status === Image.Ready) root.bake()
    }

    // ── THE BAKE, AND WHY IT HAS TO BE TORN DOWN AFTERWARDS ──────────────
    // `opacity: 0` does NOT stop Qt rendering an item — it renders it and then
    // composites it invisibly. Leaving the prep pass sitting there at zero
    // opacity meant its 25-tap ring still ran over every pixel of the screen
    // every frame, which is the exact cost the pass exists to remove. Measured:
    // it accounted for roughly half of the +70 points, and hiding it after the
    // bake is what closes the rest.
    //
    // `live: false` means the ShaderEffectSource keeps its last render for
    // ever, so once the texture exists the source item has no further job and
    // is taken out of the scene entirely.
    property bool baked: false
    function bake() { root.baked = false; prepTex.scheduleUpdate(); bakeDone.restart(); }
    Timer { id: bakeDone; interval: 350; repeat: false; onTriggered: root.baked = true }

    // ── PASS 1 · everything that depends only on the wallpaper ───────────
    // The galaxy mask and the blurred dust, baked ONCE. `live: false` means
    // this renders only when `scheduleUpdate()` is called — on image load, and
    // never again. It is the difference between ~82 texture reads per pixel
    // per frame and 8.
    ShaderEffect {
        id: prepFx
        anchors.fill: parent
        opacity: 0
        visible: !root.baked          // gone from the scene once its texture exists
        blending: false
        fragmentShader: Qt.resolvedUrl("shaders/livewall_prep.frag.qsb")
        property variant src: wall
        property vector2d u_resolution: Qt.vector2d(width, height)
        property vector4d u_mask: Qt.vector4d(root.maskLo, root.maskHi,
                                              root.maskRadiusPx, root.detailRadiusPx)
        onU_maskChanged: root.bake()
    }
    ShaderEffectSource {
        id: prepTex
        anchors.fill: parent
        sourceItem: prepFx
        hideSource: true
        live: false
        smooth: true
        wrapMode: ShaderEffectSource.ClampToEdge
        visible: false
    }

    // The taskbar's own fluid, unmodified. Passing it in rather than
    // re-deriving it is what keeps ONE solver in this build instead of two
    // that drift apart — and it is literally what he pointed at.
    // ── THE FLUID IS A TEXTURE, NOT A PICTURE ────────────────────────────
    // `layer.enabled` renders this item into its own framebuffer and makes the
    // item itself a texture provider — so the ShaderEffect below can read it
    // directly, and `opacity: 0` means the layer is composited invisibly. The
    // item is still laid out, still `visible`, and still `enabled`, so its
    // HoverHandler keeps receiving the cursor: opacity is a paint property,
    // not an input one.
    //
    // (This replaced a separate ShaderEffectSource with `hideSource: true`.
    // Both work; this one is simply less machinery. I first blamed that
    // ShaderEffectSource for a magenta plume on screen and I was WRONG — the
    // plume was the galaxy seen through a translucent window, and the real
    // defect was the units bug in livewall.frag. Recorded because a confident
    // wrong diagnosis in a comment is worse than no comment: the next person
    // would have avoided a construct that was never at fault.)
    //
    // layer.textureSize caps the capture: the solver's own field is 96–224 px
    // on its short side, so there is nothing above 480×270 to capture and
    // rendering it at screen resolution every frame is pure waste.
    Swirl {
        id: fluid
        anchors.fill: parent
        visible: root.wallEnabled
        opacity: 0
        // The layer FBO is a per-frame render of its own. It is only worth
        // paying for while something is actually being stirred; asleep, this
        // drops away with the composite.
        layer.enabled: root.composing
        layer.smooth: true
        layer.textureSize: Qt.size(480, 270)
        interactive: root.interactive
        pauseWhenCovered: true
        viewportCovered: root.coveredByViewport
        // A wallpaper is stirred, not painted on: the dye is held well down so
        // what you see is his galaxy moving, not a sheet of liquid over it.
        intensity: 0.55
        cornerRadius: 0
    }

    // ── PASS 2 · the composite, and ONLY while something is moving ───────
    ShaderEffect {
        anchors.fill: parent
        visible: root.composing
        blending: false
        fragmentShader: Qt.resolvedUrl("shaders/livewall.frag.qsb")

        // Names match the uniform block in livewall.frag member for member —
        // Qt binds them by name, and a typo here is a black screen, not an
        // error.
        property variant src: wall
        property variant prep: prepTex
        property variant paint: fluid
        property vector2d u_resolution: Qt.vector2d(width, height)
        property vector4d u_flow: Qt.vector4d(root.displacePx, root.paintBleed,
                                              root.paintLift, root.flowGain)
    }
}
