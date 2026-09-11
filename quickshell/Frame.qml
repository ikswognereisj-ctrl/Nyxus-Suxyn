// Nyxus Suxyn — the Frame. The focused window, held in a channel of the
// build's own living paint.
//
// ⛔ WHY THIS FILE EXISTS AT ALL, because the obvious answer does not work.
//
// Hyprland's `general:col.active_border` is a solid colour or a LINEAR
// GRADIENT — a list of stops and an angle. `animation = borderangle` rotates
// that angle, and that is the entire extent of what the compositor can put
// around a window. There is no hook for a shader, a texture or a simulation:
// the border is drawn by the compositor's own pass from those stops, and no
// amount of config makes it host a fluid. So "make Hyprland support it" is
// really "draw it ourselves, outside Hyprland", and this is that.
//
// The two halves ship TOGETHER and they are not alternatives:
//
//   · Hyprland's own animated multi-stop border stays, and stays visible as
//     the crisp inner rim right against the window (nyxus-hyprland-frame.conf
//     widens the stop list and speeds the `borderangle` loop). It costs
//     nothing, it works for EVERY window including XWayland, and it is what
//     you still get if the shell is not running.
//   · this file adds the channel just outside it: a thin band of glass with
//     the same Swirl fluid the horizon seam runs, flowing AROUND the window.
//
// ── HOW IT STAYS CHEAP, which is the whole engineering problem ────────────
//
// `WIP-14` measured the seam's solver at ~28–32 % of a core per live instance
// while awake, and drove idle to 0.1–0.2 %. A second always-live field would
// have thrown that away, so three things keep this one nearly free:
//
//   1. IT IS NOT ALWAYS ALIVE. There is no continuous animation. Focus
//      changing, moving, resizing or re-titling a window fires ONE orbit —
//      a stroke that travels the perimeter once and a bit — and then the
//      simulation settles and stops. Swirl holds its last frame at
//      `restOpacity` for free (the buffers are not `live`, `frames` is
//      stopped, nothing is stepped), so the resting frame is a still glass
//      rim at zero cost. `lingerMs` is short here for the same reason: this
//      is a decoration, not the horizon.
//   2. THE FIELD IS SMALL AND FIXED. Solver cost scales with the SIM grid,
//      not with the window. The seam is 1920 px wide so `_fit` gives it
//      1024×62 = 63 k cells; this field is declared at a fixed 520×324 and
//      STRETCHED to the window, which gives 154×96 = 15 k — about a quarter
//      of the seam's per-pass work, whatever size the window is.
//   3. A FIXED FIELD ALSO MEANS NO REALLOCATION. If the Swirl resized with
//      the window, every focus change between two differently-sized windows
//      would resize thirteen RGBA16F targets — and with `follow_mouse = 1`
//      that is several times a second while you sweep the mouse. Stretching
//      instead means the buffers never change shape, so the fluid also
//      CARRIES OVER from one window to the next: the same paint moves house
//      rather than being rebuilt, which is both cheaper and better.
//
// ── HOW IT KNOWS WHERE THE WINDOW IS ──────────────────────────────────────
//
// `Hyprland.activeToplevel.lastIpcObject` is the focused window's entry from
// Hyprland's own `clients` reply — `at`, `size`, `monitor`, `fullscreen`,
// `mapped`.
//
// ⚠ WIP-117. This comment used to claim "Quickshell keeps it fresh off the
// compositor's event socket". IT DOES NOT, and Quickshell's own documentation
// for `lastIpcObject` says so outright: *"this is not updated unless the
// toplevel object is fetched again from Hyprland… run
// `Hyprland.refreshToplevels()` and wait for this property to update."*
//
// So `at` and `size` were frozen at whatever they happened to be the last time
// something else caused a fetch. The band drew at that stale rect and STAYED
// THERE while the window moved out from under it — which is exactly what the
// owner reported seeing: "a grey thing the shape as my window, but it just
// would stay there, so if I move my windows it didn't move with me."
//
// The wrong comment is the reason nobody added the refresh: it described the
// problem as already solved, so every reader after it — including the one who
// wrote the geometry bindings below — had no reason to look. A confident
// sentence about someone else's API is a liability unless it carries the
// citation, so this one now does.
//
// `refreshToplevels()` is still EVENT-DRIVEN and nothing here polls. That is a
// hard rule in this repo, not a preference: two labels spawning subprocesses
// every 50 ms once starved the event loop badly enough that the lock screen
// could not be unlocked (HANDOFF § Rules learned the hard way). The refresh
// below hangs off `Hyprland.rawEvent` — the compositor's own socket — and the
// two timers that shape it are single-shot and self-terminating.
//
// ── WHAT STILL CANNOT FOLLOW LIVE, and why it is not a bug we can fix ──────
//
// Hyprland emits NO event while you drag or edge-resize a window with the
// mouse. That is upstream's position, not an omission: asked for exactly this,
// vaxry answered "wouldn't it be better to add this as a windowrule selector?"
// and no drag event was added. The community plugin `hyprdrag` exists solely
// to add the events Hyprland does not send. Keyboard dispatchers that only
// re-tile (`movewindow l`, `resizeactive`) are silent for the same reason.
//
// So during a mouse drag the band holds still and LANDS on the new rect at the
// end, on the first event that follows. Everything that does emit — focus,
// open, close, float toggle, fullscreen, workspace, monitor, group, title —
// moves the frame immediately. Stated plainly because it is visible, and
// because the honest limit is easier to live with than a mystery.
//
// ── HOVER ─────────────────────────────────────────────────────────────────
//
// The owner asked for it to "activate if your mouse hovers over it". It does,
// and by the honest route: `input:follow_mouse = 1`, so pointing at a window
// focuses it, which is an `activewindow` event, which is an orbit. Moving the
// pointer across two windows lights each one in turn.
//
// What this deliberately does NOT do is take input. The surface has an EMPTY
// input mask (`Region {}`, the same guarantee `Spill.qml` gave), so it cannot
// be clicked, hovered or focused, and it cannot swallow the drag on a window
// edge that `resize_on_border = true` depends on. A per-pixel hover of the
// band itself would need either input (breaks resize) or a pointer poll
// (breaks the rule above), so it is not attempted.
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

PanelWindow {
    id: win

    // ── the channel's geometry ───────────────────────────────────────
    // `reach` is how far the band stands off into the gap, `bite` how far it
    // laps back over the window's own edge. The bite is small on purpose: it
    // seals the join so no sliver of wallpaper shows between the two, and it
    // leaves Hyprland's own border — which `nyxus-tintd` tints per app —
    // reading as the bright inner line of the channel rather than as a
    // second, competing frame.
    property int reach: 13
    property int bite: 3
    readonly property int band: reach + bite
    // decoration:rounding in the shipped Hyprland config. The outer corner
    // has to be the window's corner plus the stand-off or the band pinches at
    // the corners.
    property int winRounding: 12
    readonly property int rOuter: winRounding + reach

    // ── the orbit ────────────────────────────────────────────────────
    property int lapMs: 1250
    property real laps: 1.4

    // ── the field ────────────────────────────────────────────────────
    // Declared, not derived — see note 2 in the header. 520×324 is 1.6:1,
    // close to the aspect of a normal window, so the stretch is mild for the
    // common case and the sim lands at 154×96.
    property int fieldW: 520
    property int fieldH: 324

    // ── what we are framing ──────────────────────────────────────────
    readonly property var mon: Hyprland.monitorFor(win.screen)
    readonly property var top: Hyprland.activeToplevel
    readonly property var ipc: (top && top.lastIpcObject) ? top.lastIpcObject : null

    // A shell surface being open is not a reason to keep decorating the window
    // behind it — the Swell is the thing you are looking at, and a lit rim
    // around a window you have just covered up reads as clutter.
    readonly property bool shellBusy: Bus.launcherOpen || Bus.flyoutOpen
                                      || Bus.powerOpen || Bus.taskViewOpen

    readonly property bool frameable: ipc !== null && mon !== null
        && ipc.monitor === mon.id
        && ipc.mapped === true && ipc.hidden === false
        // A fullscreen window is undecorated by definition, and a band over
        // the edges of a video is the one place this would be actively wrong.
        && ipc.fullscreen === 0
        && ipc.size[0] > 80 && ipc.size[1] > 60
        && !shellBusy
        && Prefs.swirlEnabled

    // Hyprland reports window positions in LAYOUT coordinates, which span
    // every monitor; this surface's origin is its own screen.
    readonly property real gx: frameable ? ipc.at[0] - mon.x : 0
    readonly property real gy: frameable ? ipc.at[1] - mon.y : 0
    readonly property real gw: frameable ? ipc.size[0] : 0
    readonly property real gh: frameable ? ipc.size[1] : 0

    // The paint is built once, the first time there is anything to frame, and
    // then kept — see note 3. `armed` is also what keeps the ShaderEffect
    // chain out of a surface that has not been exposed yet: Swirl.qml's header
    // records that a ShaderEffectSource in a never-exposed window takes the
    // scene graph down, and the first Hyprland focus event is long after this
    // layer is mapped.
    property bool armed: false
    onFrameableChanged: if (frameable) armed = true

    // ── the surface ──────────────────────────────────────────────────
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "nyxus-frame"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    visible: Prefs.swirlEnabled

    // Not a surface. It never takes a pointer event. (Spill.qml's precedent,
    // and here it is load-bearing rather than polite: the band sits exactly
    // where you grab a window to resize it.)
    mask: Region {}

    // Every one of these is a reason the light should travel: the window
    // changed, or which window we are looking at changed.
    onGxChanged: win.stir()
    onGyChanged: win.stir()
    onGwChanged: win.stir()
    onGhChanged: win.stir()
    Connections {
        target: Hyprland
        function onActiveToplevelChanged() { win.stir(); }
    }

    // ── keeping the geometry true (WIP-117) ──────────────────────────
    //
    // Refresh on EVERY socket2 event rather than on a list of the ones that
    // look geometric. Deliberate, and the asymmetry is the argument: a missed
    // event leaves the band parked at a stale rect — the whole defect this
    // fixes, and one that looks like a design decision rather than a fault —
    // while a surplus refresh costs one round-trip on a unix socket. An
    // allowlist would also have to be re-audited every time Hyprland adds an
    // event, and nobody would remember to. socket2 carries no high-frequency
    // event, so "all of them" has a real ceiling.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (win.visible)
                coalesce.restart();
        }
    }

    // Single-shot, so it stops on its own — a debounce, not a heartbeat. A
    // burst (open a window and the whole workspace re-tiles) becomes one
    // fetch instead of one per event.
    Timer {
        id: coalesce
        interval: 40
        repeat: false
        onTriggered: {
            Hyprland.refreshToplevels();
            settle.restart();
        }
    }

    // One more fetch after the compositor's own window animation has had time
    // to land. Hyprland reports a window's CURRENT rect, so a fetch made while
    // it is still sliding into place reads a position it is about to leave —
    // and since nothing further is emitted once the animation ends, that
    // half-way rect would be the last word. Also single-shot, and it does not
    // re-arm itself: two fetches per burst, then silence.
    Timer {
        id: settle
        interval: 320
        repeat: false
        onTriggered: Hyprland.refreshToplevels()
    }

    // A counter rather than a call through `ringPaint.item`. Two reasons, and
    // the second is the real one: a `Loader`'s `item` is typed `QObject`, so
    // calling a method on it is invisible to `qmllint` and it cannot tell a
    // typo from a valid call — and the paint may legitimately not be loaded
    // yet, which a bare call has to guard for by hand. Bumping a counter the
    // component BINDS to is checkable, and it cannot fire into nothing.
    property int stirNonce: 0
    function stir() {
        if (frameable)
            stirNonce = stirNonce + 1;
    }

    // ── the channel ──────────────────────────────────────────────────
    Item {
        id: ring
        x: win.gx - win.reach
        y: win.gy - win.reach
        width: win.gw + 2 * win.reach
        height: win.gh + 2 * win.reach

        // Geometry SNAPS and the light is what moves. Animating width and
        // height instead would resize the simulation every frame of the
        // transition, and the orbit already reads as the frame arriving.
        opacity: win.frameable ? 1 : 0
        visible: opacity > 0.004
        Behavior on opacity {
            NumberAnimation {
                duration: win.frameable ? Theme.durQuick : Theme.durSettle
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveMove
            }
        }

        // 1 · the glass, seen in section. A border is a pane viewed edge-on,
        // which is the one condition under which glass shows its own colour —
        // hence the tint rather than a neutral dark. `Rectangle`'s border is
        // drawn INSIDE the item's bounds, so a border-only rectangle over the
        // outer rect is exactly the channel, with the corners solved for free.
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: win.rOuter
            border.width: win.band
            border.color: Theme.glassLipTint
            antialiasing: true
        }

        // 2 · the living paint, clipped to the channel
        Loader {
            id: ringPaint
            anchors.fill: parent
            active: win.visible && win.armed
            sourceComponent: paintChannel
        }

        // 3 · the cut edge, against the window. A specular line desaturating
        // toward white is what a lit glass edge actually does (§3.5: only the
        // top band gives up chroma for luminance), and it is the cue that
        // makes the band read as a solid object rather than a painted stripe.
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 2 * (win.band - 1)
            height: parent.height - 2 * (win.band - 1)
            color: "transparent"
            radius: Math.max(0, win.rOuter - win.band + 1)
            border.width: 1
            border.color: Theme.soften(Theme.tealGlow, 0.30)
            antialiasing: true
        }

        // 4 · the outer edge, against the desktop. Much fainter: this is the
        // far face of the pane, and the light in the channel is between them.
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            radius: win.rOuter
            border.width: 1
            border.color: Theme.soften(Theme.teal, 0.14)
            antialiasing: true
        }
    }

    // ═════════════════════════════════════════════════════════════════
    //  The paint. Built once, kept for the session.
    // ═════════════════════════════════════════════════════════════════
    Component {
        id: paintChannel

        Item {
            id: channel

            // ── the orbit ────────────────────────────────────────────
            // 0..laps, in perimeter turns. `feedAt` takes a point and strokes
            // from wherever the last one was, so walking this value around the
            // rectangle IS a stroke travelling around the window — the fluid
            // is pushed along the channel rather than being drawn onto it.
            property real orbit: 0
            onOrbitChanged: channel.feed()

            // The window moved, resized, or focus landed somewhere new.
            property int nonce: win.stirNonce
            onNonceChanged: channel.swirlAround()

            NumberAnimation {
                id: lap
                target: channel
                property: "orbit"
                // Fast out of the gate and easing as it comes round, so it
                // reads as light being thrown around the frame rather than as
                // a marquee crawling at constant speed.
                easing.type: Easing.OutCubic
            }

            function swirlAround() {
                // `ignite()` is the only public way to clear Swirl's stroke
                // history, and it has to be cleared: without it the first feed
                // after the frame moves to another window strokes straight
                // across the field from wherever the last one ended.
                field.ignite();
                lap.stop();
                channel.orbit = 0;
                lap.from = 0;
                lap.to = win.laps;
                lap.duration = win.lapMs * win.laps;
                lap.start();
            }

            // Normalised half-thickness of the channel: the stroke runs down
            // the MIDDLE of the band, not along its edge, or half the dye
            // lands outside the mask and is thrown away.
            readonly property real mx: ring.width > 0
                                       ? (win.band * 0.5) / ring.width : 0
            readonly property real my: ring.height > 0
                                       ? (win.band * 0.5) / ring.height : 0

            // Perimeter in real pixels, so the light travels at one speed all
            // the way round instead of racing the short sides.
            readonly property real segW: Math.max(1, ring.width - win.band)
            readonly property real segH: Math.max(1, ring.height - win.band)

            function feed() {
                const u = channel.orbit - Math.floor(channel.orbit);
                const P = 2 * (channel.segW + channel.segH);
                let d = u * P;
                let nx, ny;
                // Starts at the bottom-left and climbs. Light rising out of
                // the corner nearest the horizon is the same gesture every
                // other transient surface in this shell makes.
                if (d < channel.segH) {
                    nx = channel.mx;
                    ny = 1 - channel.my - (d / channel.segH) * (1 - 2 * channel.my);
                } else if ((d -= channel.segH) < channel.segW) {
                    nx = channel.mx + (d / channel.segW) * (1 - 2 * channel.mx);
                    ny = channel.my;
                } else if ((d -= channel.segW) < channel.segH) {
                    nx = 1 - channel.mx;
                    ny = channel.my + (d / channel.segH) * (1 - 2 * channel.my);
                } else {
                    d -= channel.segH;
                    nx = 1 - channel.mx - (d / channel.segW) * (1 - 2 * channel.mx);
                    ny = 1 - channel.my;
                }
                field.feedAt(nx, ny);
            }

            // The shape of the channel, as a texture. A border-only rounded
            // rectangle IS the band — hole, corners and antialiasing all
            // solved by one primitive. Static, so hiding it costs nothing and
            // Bar.qml's reflection mask is the precedent.
            Item {
                id: bandMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    radius: win.rOuter
                    border.width: win.band
                    border.color: Theme.text
                    antialiasing: true
                }
            }

            // ── the field, the stretch, and the mask ─────────────────
            //
            // ⚠ `layer.effect`, and NOT a hidden `Item` handed to
            // `MultiEffect.source`. The first cut did the latter, copied
            // straight from Bar.qml's icon reflection — and the entire field
            // was DEAD. `visible` is EFFECTIVE visibility in Qt Quick, so
            // hiding the wrapper hides the Swirl inside it, and Swirl's
            // `running` is `visible && … ` — the solver never stepped once,
            // the dye buffers stayed empty and the display shader emitted its
            // base colour at zero alpha.
            //
            // What made that worth writing down is how it failed: the band
            // still drew its glass tint and both hairlines, so the frame
            // photographed as a clean, plausible dark border. A dead
            // simulation that looks like a design decision is the kind of
            // defect that ships. The reflection mask gets away with
            // `visible: false` because a mirrored Image does not care whether
            // it is being drawn; anything with a clock in it does.
            Item {
                id: paintHost
                anchors.fill: parent
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: bandMask
                }

                Swirl {
                    id: field
                    width: win.fieldW
                    height: win.fieldH
                    transform: Scale {
                        origin.x: 0
                        origin.y: 0
                        xScale: paintHost.width / win.fieldW
                        yScale: paintHost.height / win.fieldH
                    }

                    // The mask does the shaping; a second rounded clip inside
                    // it would only soften the band's own inner corner.
                    cornerRadius: 0
                    // The whole signature sweep wraps the window, so hue is
                    // still a function of horizontal position: teal down the
                    // left edge, plum down the right, exactly as everywhere
                    // else in this shell.
                    sweepLo: 0.0
                    sweepHi: 1.0

                    // A decoration sleeps sooner than the horizon does.
                    lingerMs: 2600
                    // Never plays its own intro: `swirlAround` is the intro,
                    // and it is fired by the same event that makes the frame
                    // appear.
                    playIntroOnLoad: false
                    // Circling emitters rather than the bar's left-to-right
                    // ribbons — the middle of this field is behind the window
                    // and never seen, so an intro that crosses it is wasted
                    // work. What it is really here for is the stroke reset and
                    // the guaranteed wake in `swirlAround`.
                    introMode: "loop"
                    introStrength: 0.45
                    // Its own HoverHandler would never fire — the surface has
                    // no input region at all — so the wake is driven entirely
                    // from `feedAt`, which restarts the linger itself.
                    interactive: false

                    intensity: Prefs.swirlIntensity
                    // A thin channel shows one slice of the field, so it needs
                    // more punch than a panel to read as light rather than as
                    // a tinted edge.
                    exposure: 2.35
                    bloom: 1.35
                    // The paint is upscaled ~2.5× onto a normal window, which
                    // is softness we want (Spill.qml did the same thing on
                    // purpose) but it also thins the filaments, so the fold is
                    // driven a little harder than the reference panel preset.
                    curlAmp: 1.0
                    impulseRadius: 0.30
                    decayRate: 0.32
                    // Held brighter at rest than the seam's 0.62: a frame that
                    // fades to a whisper stops being a frame, and this costs
                    // nothing — the simulation has already stopped and the
                    // buffers are holding a static image.
                    restOpacity: 0.78

                    audioBass: Beat.bass
                    audioMid: Beat.mid
                    audioHigh: Beat.high
                    audioPulse: Beat.pulse
                    musicActive: Beat.hot && Prefs.swirlMusic
                }
            }

            Component.onCompleted: channel.swirlAround()
        }
    }
}
