// Nyxus Suxyn — the Frost. Every window you are NOT looking at, blurred out
// so you cannot read it, while its shape stays perfectly legible.
//
// The owner asked for this months ago and got something else:
//
//   "blurred out so you couldn't read or see what was on a window … you see
//    the outlines of stuff but its blurred out"
//
// What was built instead was `~/.config/hypr/scripts/nyxus-idle-glass.sh`,
// which drops `decoration:active_opacity` / `inactive_opacity` to 0.22 / 0.12.
// That does not blur anything — it makes windows nearly INVISIBLE, which is
// how he described it when he saw it: "the windows after a mintue or so go
// like transparent … what i meant was like real blur so you couldnt read or
// see what was on a window." Transparency and blur are opposite answers:
// transparency removes the window and leaves the wallpaper, blur keeps the
// window and removes its detail. He asked for the second one.
//
// ⛔ WHY THE OBVIOUS ROUTE DOES NOT EXIST, so nobody spends another week on it.
//
// Hyprland's blur applies to what is BEHIND a surface, never to the surface's
// own content. There is no config value — none — that blurs a window's own
// pixels: not `blur:size`, not a windowrule, not `inactive_opacity`. So
// "blur the unfocused window" cannot be expressed as a setting, and every
// attempt to find one is looking for a knob that was never built.
//
// ── THE MECHANISM, MEASURED BEFORE THIS FILE WAS WRITTEN ──────────────────
//
// Put a layer-shell surface ON TOP of the window and let the compositor blur
// what is behind THAT surface — which IS the window's content. The build
// already owns the idiom (`nyxus-hyprland-layerblur.conf` does exactly this
// pair for `notifications` and `rofi`), and it needs three things together:
//
//   layerrule = blur on,          match:namespace nyxus-frost
//   layerrule = ignore_alpha 0.05, match:namespace nyxus-frost
//   layerrule = xray off,         match:namespace nyxus-frost
//
// `ignore_alpha` is not a detail, it is the SHAPE of the effect. This surface
// covers the whole screen but paints only the rectangles of the unfocused
// windows; every other pixel is alpha 0. `ignore_alpha 0.05` tells the
// compositor to skip blur wherever alpha ≤ 0.05, so the blur is clipped to
// exactly the painted rectangles and nothing else on screen is touched. The
// panes ARE the mask.
//
// `xray off` is the trap that sends you back to the beginning. With
// `xray on`, blur samples the WALLPAPER ONLY — so the pane shows blurred
// wallpaper and the window under it vanishes entirely, which looks like the
// transparency defect this file exists to replace. Measured, in
// `docs/proof/frost-0831`: the pane's mean luminance is 43.4 with xray off
// (the window's own brightness, preserved — its shape reads) and 20.8 with
// xray on (collapsed to empty wallpaper — the window is gone). `hyprland.conf`
// still sets `xray = true` globally; `nyxus-hyprland-blur.conf` overrides it
// to false, and the layerrule above pins it for this namespace regardless of
// which of those two a future edit changes.
//
// ── ⚠ IT DEPENDS ON A GLOBAL THE OWNER TURNED OFF, and that is a real cost ─
//
// `layerrule = blur on` is a NO-OP unless `decoration:blur:enabled = true`.
// Measured both ways with the layerrule installed and only the global moved
// (docs/proof/frost-0831, captures F and G): global off → under-pane edge
// energy 41.8, text fully legible, the pane does nothing at all; global on →
// 2.9, text destroyed. The owner turned that global OFF on 2026-08-12.
//
// It is turned back on, and the reason it is safe is measured rather than
// argued. His complaint was that every window read as frosted — "if we could
// take off the thing that makes all the tabs open blurred too" — and the
// cause of that was `ignore_opacity = true`, which blurs behind a window no
// matter how opaque it is. Every window in this build is ruled
// `opacity 1.0 1.0` by `nyxus-hyprland-opacity.conf`, so with
// `ignore_opacity = false` there is nothing translucent for the global blur
// to act on and no window can frost. Captures J and K are that control: the
// same two opaque windows with global blur off and on measure 52.195 and
// 52.195 — identical to three decimals. Turning the pass back on changes
// nothing he can see.
//
// What it does cost is GPU: the blur pass exists again. That is why this
// ships OFF and why the cost is on the row rather than in a footnote.
//
// ── nyxus-idle-glass.sh: NOT DELETED, and NOT SAFE TO RUN WITH THIS ───────
//
// `~/.config/hypr/scripts/nyxus-idle-glass.sh` is the script that answered
// this ask with transparency. It is deliberately LEFT ON DISK and left wired:
// it is referenced from `hypridle.conf` (the 45 s stage) in both trees and
// from `nyxus_settings.py`, and it is not the same feature as this one — it
// fires on an IDLE TIMER and covers every window including the focused one,
// where this fires on FOCUS and never touches the window you are using. One is
// "I walked away", the other is "I am working in this window". Deleting a
// behaviour the owner can see is his call, not this lane's, and the Spill/Frame
// precedent in `shell.qml` is that such files stay on disk.
//
// ⚠ BUT THEY MUST NOT BOTH BE ON, and this is a real interaction, not a
// tidiness note. idle-glass drops `decoration:active_opacity` /
// `inactive_opacity` to 0.22 / 0.12 — it makes every window TRANSLUCENT. This
// feature turns the global blur pass on. A translucent window with the blur
// pass live is precisely the state the owner rejected on 2026-08-12 ("if we
// could take off the thing that makes all the tabs open blurred too"): at 45 s
// idle, every window would go see-through AND frost behind itself, which is
// both of the things he complained about at once.
//
// What keeps that from shipping today is that this feature is OFF by default,
// so the pass does not exist and idle-glass behaves exactly as it does now.
// The moment the owner switches the frost ON, the 45 s stage should come out.
// That is an OWNER RULING OWED and it is recorded on the ledger row rather
// than pre-empted here.
//
// ── WHAT IT MUST NEVER COVER ──────────────────────────────────────────────
//
//   · the lock screen and the screensaver. The lock is an ext-session-lock
//     surface, which the protocol renders ABOVE every layer surface, so this
//     one structurally cannot reach it — but the SCREENSAVER is an ordinary
//     toplevel (`app.nyxus.Screensaver`) and would frost like any other
//     window, so it is excluded by class below. Both are pinned opaque on
//     purpose and blurring either of them is a standing DO-NOT.
//   · fullscreen windows. You are watching that.
//   · the shell's own `nyxus-*` surfaces — free, and worth stating: those are
//     LAYER surfaces, not toplevels, so they never appear in the list this
//     iterates. The bar cannot be frosted by this file even by mistake.
//
// ── INPUT: NONE, and here that is load-bearing ────────────────────────────
//
// `mask: Region {}` — the same guarantee `Frame.qml` and `Spill.qml` give.
// A pane sitting over an unfocused window that ATE the click meant to focus
// that window would be far worse than the bug it fixes: you could never
// focus anything again by clicking it. With an empty input region the pane
// is not a surface at all to the pointer — the click lands on the window
// underneath, focuses it, and the pane fades off it.
//
// ── GEOMETRY: the trap Frame.qml paid for ─────────────────────────────────
//
// `lastIpcObject` is NOT live. Quickshell's own docs: "this is not updated
// unless the toplevel object is fetched again from Hyprland." Frame.qml drew
// at a stale rect for weeks because a confident comment said otherwise, and
// the owner saw it as "a grey thing the shape as my window, but it just would
// stay there". So the refresh below hangs off `Hyprland.rawEvent` and fires
// on EVERY socket2 event rather than a chosen subset — the asymmetry is the
// argument: a missed event leaves a frost pane parked over a window that has
// moved out from under it, while a surplus refresh costs one round-trip on a
// unix socket. Gate 13pu3 holds this file to it.
//
// Nothing polls. Two single-shot timers shape each burst — a 40 ms coalesce
// so a re-tile is one fetch instead of twelve, and a 320 ms settle so the
// rect is re-read after Hyprland's own window animation has landed (it
// reports a window's CURRENT position, so a fetch mid-slide reads a place the
// window is about to leave, and nothing further is emitted once it stops).
//
// Same honest limit as Frame: Hyprland emits no event during a mouse drag or
// edge-resize, so a pane holds still during the drag and lands on the new
// rect on the first event after it.
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: win

    // ── what we are painting ─────────────────────────────────────────
    readonly property var mon: Hyprland.monitorFor(win.screen)
    readonly property var activeTop: Hyprland.activeToplevel
    readonly property string activeAddr: (activeTop && activeTop.lastIpcObject
                                          && activeTop.lastIpcObject.address)
                                         ? String(activeTop.lastIpcObject.address) : ""

    // The screensaver and any lock/greeter surface are pinned opaque on
    // purpose. Matched on `class`, which is what Hyprland reports for both
    // Wayland app_ids and XWayland classes.
    readonly property var neverFrost: /^(app\.nyxus\.Screensaver|nyxus\.screensaver|hyprlock|swaylock|sddm-greeter|nyxus-lock.*)$/i

    // ── the setting ──────────────────────────────────────────────────
    // Off means this window is not even mapped: `visible` is false, no layer
    // surface exists, and the compositor has no blurred region to composite.
    // Turning it off costs exactly nothing rather than hiding an armed effect.
    readonly property bool on: Prefs.frostEnabled
    // 0..1, the pane's own tint on top of the blur. The compositor's blur
    // RADIUS is a global (`decoration:blur:size`) and cannot be varied per
    // layer, so strength is the one thing this surface can actually control:
    // how much of its own darkening it lays over the blurred content. Light
    // is blur alone; strong is blur plus a veil that takes the last of the
    // contrast out.
    readonly property real strength: Prefs.frostStrength

    // The floor is what makes the blur happen at all: `ignore_alpha 0.05` in
    // the layerrule means a pane at alpha ≤ 0.05 is SKIPPED by the blur pass.
    // A strength of 0 must therefore still paint above that threshold or the
    // feature silently does nothing at its lowest setting — the "dead
    // simulation that looks like a design decision" failure Frame.qml records.
    readonly property real paneAlpha: 0.10 + 0.34 * Math.max(0, Math.min(1, strength))

    // ── the surface ──────────────────────────────────────────────────
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    // ⚠ THIS STRING IS THE FEATURE. It is what the three layerrules in
    // `nyxus-hyprland-layerblur.conf` match on; rename it here and the panes
    // keep drawing while the blur silently stops, which photographs as a
    // tinted rectangle and reads as a deliberate look. Grep before touching.
    WlrLayershell.namespace: "nyxus-frost"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"
    visible: win.on

    // Never takes a pointer event — see the header. Without this the pane
    // would swallow the click that focuses the window it is sitting on.
    mask: Region {}

    // ── keeping the rects true ───────────────────────────────────────
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (win.visible)
                coalesce.restart();
        }
    }

    Timer {
        id: coalesce
        interval: 40
        repeat: false
        onTriggered: {
            Hyprland.refreshToplevels();
            win.rebuild();
            settle.restart();
        }
    }

    Timer {
        id: settle
        interval: 320
        repeat: false
        onTriggered: {
            Hyprland.refreshToplevels();
            win.rebuild();
        }
    }

    // Focus changing must not wait on the 40 ms coalesce: the pane coming off
    // the window you just clicked is the one moment of this effect a person
    // actually watches, and it should be immediate.
    Connections {
        target: Hyprland
        function onActiveToplevelChanged() { win.rebuild(); }
    }

    // ── the model ────────────────────────────────────────────────────
    // A plain array rebuilt on demand rather than a live filter over
    // `Hyprland.toplevels.values`. The list object is replaced wholesale by a
    // refresh, so a binding over it re-evaluates every element on every fetch
    // whether or not anything moved; building once per event and assigning
    // keeps the Repeater's delegates stable when nothing changed.
    property var panes: []

    function rebuild() {
        if (!win.on || win.mon === null) {
            if (win.panes.length > 0)
                win.panes = [];
            return;
        }

        const all = (Hyprland.toplevels && Hyprland.toplevels.values)
                    ? Hyprland.toplevels.values : [];
        const out = [];

        for (let i = 0; i < all.length; i++) {
            const t = all[i];
            const o = t ? t.lastIpcObject : null;
            if (!o)
                continue;
            // Not this monitor, not on screen, or not a window we may cover.
            if (o.monitor !== win.mon.id)
                continue;
            if (o.mapped !== true || o.hidden === true)
                continue;
            if (o.fullscreen !== 0)
                continue;
            if (!o.at || !o.size || o.size[0] < 40 || o.size[1] < 30)
                continue;
            if (o.address && String(o.address) === win.activeAddr)
                continue;
            if (o.class && win.neverFrost.test(String(o.class)))
                continue;

            out.push({
                // Hyprland reports LAYOUT coordinates, which span every
                // monitor; this surface's origin is its own screen.
                px: o.at[0] - win.mon.x,
                py: o.at[1] - win.mon.y,
                pw: o.size[0],
                ph: o.size[1],
                key: String(o.address || (i + ":" + o.at[0] + "," + o.at[1]))
            });
        }
        win.panes = out;
    }

    onOnChanged: win.rebuild()
    Component.onCompleted: win.rebuild()

    // ── the panes ────────────────────────────────────────────────────
    Repeater {
        model: win.panes

        delegate: Rectangle {
            id: pane
            required property var modelData

            x: pane.modelData.px
            y: pane.modelData.py
            width: pane.modelData.pw
            height: pane.modelData.ph

            // `decoration:rounding` in the shipped Hyprland config. A square
            // pane over a rounded window leaves four lit corners of sharp
            // content — small, and exactly the kind of thing that reads as
            // broken rather than as a style.
            radius: 12
            antialiasing: true

            // The tint is the STRENGTH; the blur underneath is the compositor's.
            // Deep and cool rather than neutral grey — HORIZON §3.5: a dark in
            // this palette is a saturated colour, and there is no grey anywhere
            // in this build.
            color: Qt.rgba(0.043, 0.075, 0.098, win.paneAlpha)

            // Appears at the build's settle rate and leaves at its quickest.
            // The asymmetry is the brief: a pane must be GONE the instant a
            // window takes focus, so the fade off is 150 ms and the fade on is
            // unhurried enough that clicking between two windows does not
            // strobe.
            opacity: 0
            Component.onCompleted: pane.opacity = 1
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durQuick
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveMove
                }
            }
        }
    }
}
