// Nyxus Suxyn — THE STARLIGHT, AS AN ITEM. 2026-08-17.
//
// ── WHY THIS FILE EXISTS ─────────────────────────────────────────────────────
// `Headliner.qml` is a `PanelWindow`. A PanelWindow is a top-level wlr-layer-
// shell WINDOW: it cannot be a child of a `WlSessionLockSurface`, and it cannot
// be a child of another PanelWindow. So when the owner asked for the same sky
// behind the lock screen and behind the screensaver, `Headliner {}` could not
// simply be typed into either of them — not for a style reason, but because Qt
// refuses to parent a window into an item tree.
//
// The choice was: duplicate the shader wiring three times, or lift it out once.
// This is the lift. It holds EVERYTHING that draws — the ShaderEffect, the
// uniforms, the quality ladder and the twinkle clock — and nothing that is
// about being a window. `Headliner.qml` keeps the window, its layer, its
// namespace, its mask and its two-stage exposure gate, and fills itself with
// one of these.
//
// `shaders/headliner.frag` is UNTOUCHED and there is still exactly one copy of
// it. Three surfaces, one shader, one set of uniforms — which is the property
// that makes "the star" mean the same picture on the desktop, on the lock and
// on the screensaver rather than three drifting near-copies.
//
// ⚠ THE VOID IS NOT PAINTED HERE. `Headliner.qml` sets `color: "black"` on its
// window because it owns the ground there. This Item is TRANSPARENT where the
// shader writes nothing, so a host that already has an opaque floor (the lock
// surface's `Theme.void_`, the screensaver's own black) is not double-painted
// and can decide its own ground. Hosts that need the true-black gap must say so
// themselves; every one of them currently does.
//
// ── THE GATES ARE STILL STARLIGHT.QML'S, JUST HOSTED ─────────────────────────
// `_saving` and the tier ladder are unchanged in meaning and in name from
// `Headliner.qml`, so one habit still covers all of them. What moved out is the
// WINDOW half of the gate (`backingWindowVisible` + the 250 ms settle), because
// an Item has no backing window to read. The host supplies its own liveness on
// `active`: Headliner passes its exposure gate, the lock passes `lock.locked`,
// the screensaver passes its own `shown`. In every case the meaning is the
// same — "this sky is really on a screen right now" — and with it false the
// Timer stops, `uTime` freezes and the surface costs zero scheduled frames.
import QtQuick

Item {
    id: sky

    // Does the host consider this sky live? See the note above: this is the
    // half of the gate an Item cannot compute for itself.
    property bool active: true

    // ── ON BATTERY (Swirl.qml's rule, extended not replaced) ─────────────────
    // Identical to `Headliner.qml`'s, including the property name, because the
    // consequence is identical: the field is still there, every point still at
    // its own brightness, and what stops is the TWINKLE. A wallpaper that goes
    // black on battery is a bug report; a wallpaper that stops breathing is a
    // battery saving.
    property bool batterySaver: true
    readonly property bool _saving: batterySaver
                                    && Sys.hasBattery && !Sys.batteryCharging

    // ── the quality ladder, READ from Theme, never mirrored here ─────────────
    // `Theme.swirlTiers` is the house shape for quality data and `accent.json`
    // is read-only to this lane, so this consumes the ladder that exists rather
    // than declaring a second one to drift from it. Only the STEP RATE is
    // taken; capped at 25 Hz because the twinkle's fastest point has a 1.16 s
    // period and twinkle cannot use 165 Hz.
    property string qualityTier: "auto"
    readonly property string _tier: {
        if (qualityTier !== "auto") return qualityTier;
        const order = Theme.swirlTierOrder;
        const base = order.indexOf(Theme.swirlTierDefault);
        if (base < 0) return "full";
        const step = _saving ? Theme.swirlTierBatteryStepDown : 0;
        return order[Math.max(0, Math.min(order.length - 1, base + step))];
    }
    readonly property var _tierCfg: Theme.swirlTiers[_tier] !== undefined
                                    ? Theme.swirlTiers[_tier]
                                    : Theme.swirlTiers[Theme.swirlTierDefault]
    readonly property int _hz: Math.max(1, Math.min(25,
        sky._tierCfg !== undefined ? sky._tierCfg.step_hz : 25))

    // ── STILL, ON HOSTS WHERE STILLNESS IS RULED ─────────────────────────────
    // Owner ruling 2026-08-12, about the LOCK surface specifically and measured
    // on his own hardware: "it's a live image and it's too much, it lags my
    // system." Gate `13uv` enforces it, and it is still the current ruling —
    // nothing about this commission changed what he asked for there.
    //
    // So this is a real switch and not a formality. With it false the Timer
    // never runs, `uTime` stays at 0, and the ShaderEffect renders exactly one
    // frame of the identical art forever, for one draw. That is `stillTime`'s
    // logic with the constant at 0 instead of 137, and it is the same escape
    // `Swirl.qml`'s `floor` tier gives: "a still frame, not a paused animation
    // mid-motion."
    //
    // ⚠ The twinkle was measured at 0.0000 ms by `WIP-859` — 0.2038 ms with the
    // sines and 0.2038 ms with them replaced by constants, because they sit
    // below the shader's `hit` early-out. That is a good argument and it is NOT
    // a reason to switch this on for the lock. His ruling was about that
    // surface, he has not revisited it, and a measurement is not a licence to
    // overturn a ruling on the one screen that has to accept a password.
    property bool twinkling: true

    // Is the twinkle stepping? Same conjunction as Headliner's `running`, with
    // the window half supplied by the host through `active`.
    readonly property bool running: visible && active && twinkling
                                    && width > 8 && height > 8
                                    && !_saving

    // ── the look, exposed so a host can tune it WITHOUT a second shader ───────
    // The desktop wants the picture as commissioned. The lock and the
    // screensaver want the same picture and may want it quieter behind a
    // password field. These three numbers are the whole knob, and they are the
    // uniforms the shader already reads — no branch, no second .frag, no
    // preprocessor.
    property real twinkleDepth: 0.45
    property real density: 1.0
    property real master: 1.0

    ShaderEffect {
        id: fx
        anchors.fill: parent
        // TRANSPARENT, unlike Headliner.qml's window. The host owns its floor;
        // see the note at the top of this file. The shader writes true black in
        // the gaps either way — what blending buys is that a host with its own
        // opaque ground is not painted over twice for the same pixel.
        blending: true

        fragmentShader: Qt.resolvedUrl("shaders/headliner.frag.qsb")

        property real uTime: 0
        // x,y in DEVICE pixels — the lattice is laid out in reference px and
        // the point radius is in device px, which is what makes the field
        // resolution-free (same ~880 fibres at 1080p, 1600p and 4K, measured).
        // z is the gauge multiplier: 1.0 is one whole device pixel per point at
        // 1080p/1600p and two at 4K, which is where "small area" comes from.
        //
        // `Screen.devicePixelRatio` and not `root.screen.devicePixelRatio`: an
        // Item has no `screen` property of its own, and `Screen` is the
        // attached type that reports the window this item is actually on. On
        // the lock surface and the screensaver that is the same panel the
        // desktop is on, so the field is the same field.
        readonly property real _dpr: Screen.devicePixelRatio
        property vector4d uRes: Qt.vector4d(width * _dpr, height * _dpr, 1.0, 0)
        // x twinkleDepth · y density · z master · w reserved.
        // The depth is CONSTANT and does not fall to 0 when the clock stops:
        // stopping the Timer freezes `uTime`, so the field holds whatever
        // brightnesses it had in its last frame. Zeroing the depth as well would
        // make every point jump to full brightness at the moment the machine was
        // unplugged, which is a visible event where the intent is a silent one.
        property vector4d uLook: Qt.vector4d(sky.twinkleDepth, sky.density,
                                             sky.master, 0)

        // A Timer, not a NumberAnimation, for Starlight.qml's reason. It stops
        // with `running`, so an unmapped host, an 8 px surface or a machine on
        // battery costs zero scheduled frames — and the last frame stays on
        // screen because the buffers are not cleared, they are simply not
        // redrawn.
        Timer {
            running: sky.running
            repeat: true
            interval: Math.round(1000 / sky._hz)
            // Wrap at 3600 s so uTime stays small for the shader's sin()
            // precision — the same wrap Starlight.qml uses.
            onTriggered: fx.uTime = (fx.uTime + interval / 1000) % 3600
        }
    }
}
