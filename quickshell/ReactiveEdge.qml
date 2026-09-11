// Nyxus Suxyn — ReactiveEdge. A pane's edge, alive.
//
// Owner ruling 2026-08-09: "active borders on everything … activate to the
// sound of music … and react to how the computer is running." BorderPulse
// already drives the COMPOSITOR's border on every window; this is the same
// contract for the shell's own panes — widget chips, the Start Menu card,
// the side panel — so windows and glass agree about what the machine is
// feeling.
//
// One language, stated once:
//   · the MOOD is the colour — BorderPulse's three CPU bands. Calm is
//     glacier[0] (`tokenAccentInteractive`), busy violet, heavy ember.
//   · the BEAT is Beat.kick, copied only while the host window is exposed
//     (WIP-230: binding kick on unmapped panes crashed qs). Glow fades
//     outward; it is not a loudness wash.
//
// Cost: no Beat.kick binding on hidden windows. CPU is Sys.cpuPercent.
import QtQuick
import QtQuick.Window

Item {
    id: edge

    // ── ⚠ OWNER RULING 2026-09-07 · OFF ON THREE SURFACES ONLY ─────────
    //
    // He named three: the widget that pulses when music plays, the Start menu
    // ("only two sides pulsate"), and the side bar. I shipped a GLOBAL off
    // switch and he corrected it inside the minute -- "its only three areas i
    // wanted ... i still want when i have apps and whatever else open to
    // pulsate to the music."
    //
    // ⚠ SO THE DEFAULT STAYS ON, and exactly three call sites opt out.
    // Clock, ContextMenu and EmojiPicker keep it. And what makes his OPEN
    // WINDOWS pulse is `BorderPulse` -- a different component that rewrites
    // Hyprland's own `col.active_border` rather than drawing a surface --
    // which was never in scope and is untouched.
    //
    // ⚠ THE "TWO SIDES" HE SAW IS ALSO A REAL DEFECT, and it is worth
    // knowing before anyone turns this back on: the halo is four straight
    // rectangles inset by the corner radius, so on a card with a large radius
    // the corners are never covered and the pulse reads as two bands rather
    // than a border. Same shape of bug as GlassEdge's "pie". Fixing that is a
    // prerequisite for this ever looking right, not an afterthought.
    property bool livingEdgeEnabled: true
    visible: edge.livingEdgeEnabled
    enabled: edge.livingEdgeEnabled

    // Match the host pane's rounding; per-corner like GlassEdge.
    property int radius: Theme.r2
    property int radiusTL: radius
    property int radiusTR: radius
    property int radiusBR: radius
    property int radiusBL: radius

    // How present the edge is at rest, and how hard the beat can push it.
    property real baseStrength: 0.30
    property real gain: 0.60

    // TRK-3649 · Does the OUTER halo draw when nothing is happening?
    //
    // The four halo rectangles below sit OUTSIDE this item's bounds, and
    // `haloH` has a constant 8 in it, so at rest — no beat, no CPU band —
    // they still paint an 8 px glow band all the way round the pane. On a
    // floating pane over the desktop that band reads as a second edge
    // outside the real one: the owner called it "the layers on its edge"
    // and named the Start menu, the clock popup and the right-hand flyout
    // on 2026-09-01.
    //
    // The widget chips never showed it because their ReactiveEdge lives
    // inside `Loader { active: chip.living }` (Widgets.qml) — a chip that
    // is not living draws no halo at all. That is the thing that "got
    // taken off the widgets", and this property is how a pane that has no
    // `living` concept of its own gets the same result.
    //
    // Default TRUE, so every surface behaves exactly as it does today
    // unless it opts out. Opting out removes ONLY the resting band: the
    // halo still blooms on a beat, from 0 instead of from 8, so the living
    // border is intact and it is the rest state that goes quiet.
    property bool haloAtRest: true

    anchors.fill: parent

    // WIP-249: QWindow.visible is show(), not a mapped surface. Settle
    // before any kick copy so unmapped panes stay still.
    readonly property var _win: Window.window
    readonly property bool _winVisible: _win !== null && _win.visible
    property bool windowExposed: false
    on_WinVisibleChanged: {
        if (_winVisible && edge.livingEdgeEnabled) edgeSettle.restart();
        else { edgeSettle.stop(); windowExposed = false; }
    }
    Component.onCompleted: if (_winVisible && edge.livingEdgeEnabled) edgeSettle.restart()

    // ⚠ `visible: false` alone would stop it DRAWING and leave it WORKING.
    // `windowExposed` is what gates the Beat.kick copy and the CPU-band
    // recompute below, so switching the edge off has to hold it false —
    // otherwise every disabled edge in the shell still wakes on every beat
    // to update a colour nobody can see. Six surfaces draw this.
    onLivingEdgeEnabledChanged: {
        if (!edge.livingEdgeEnabled) { edgeSettle.stop(); edge.windowExposed = false; }
        else if (edge._winVisible) edgeSettle.restart();
    }
    Timer {
        id: edgeSettle
        interval: 250
        onTriggered: edge.windowExposed = true
    }

    // ── the workload mood — BorderPulse's bands, verbatim ───────────────
    property string band: "calm"
    readonly property int cpu: Sys.cpuPercent
    onCpuChanged: {
        let next = band;
        if (band === "calm"  && cpu >= 40) next = (cpu >= 80) ? "heavy" : "busy";
        else if (band === "busy"  && cpu >= 80) next = "heavy";
        else if (band === "busy"  && cpu <= 30) next = "calm";
        else if (band === "heavy" && cpu <= 70) next = (cpu <= 30) ? "calm" : "busy";
        if (next !== band) band = next;
    }
    readonly property color tone: band === "heavy" ? Theme.goldGlow
                                : band === "busy"  ? Theme.violetGlow
                                : Theme.tokenAccentInteractive

    // ── the beat strike ──────────────────────────────────────────────
    // Bind ONLY a local copy of Beat.kick, and only while this window is
    // exposed. Binding Beat.kick itself on unmapped panes crashed qs
    // (WIP-230). The smoothed pulse+energy blend is a loudness wash — it
    // is not a beat. Owner 10:30: real onsets, glow that fades out.
    property real _kick: 0
    property real _depth: 0
    Connections {
        target: Beat
        enabled: edge.windowExposed
        function onKickChanged() {
            edge._kick = Beat.kick;
            edge._depth = Beat.iceDepth;
        }
        function onBassChanged() { edge._depth = Beat.iceDepth; }
        function onHotChanged() {
            if (!Beat.hot) { edge._kick = 0; edge._depth = 0; }
        }
    }
    onWindowExposedChanged: {
        if (!windowExposed) { edge._kick = 0; edge._depth = 0; }
        else { edge._kick = Beat.kick; edge._depth = Beat.iceDepth; }
    }

    readonly property real strike: windowExposed ? Math.min(1, edge._kick) : 0
    readonly property real haloH: (edge.haloAtRest ? 8 : 0) + edge.strike * 16
    // Soft bass: glacier[0]. A real hit: glacier[4] (darkest legal state ice).
    readonly property color iceTone: Theme.mix(Theme.tokenAccentInteractive,
                                               Theme.tokenAccentHairline,
                                               edge._depth)
    readonly property color paint: (windowExposed && edge._depth > 0.004)
                                   || (windowExposed && edge.strike > 0.004)
                                   ? edge.iceTone : edge.tone

    property color _glow: Theme.soften(edge.paint,
                                   0.14 + edge.strike * edge.gain * 0.70)
    property color _line: Theme.soften(edge.paint,
                                   edge.baseStrength + edge.strike * edge.gain)

    // halo · STRAIGHTS that fade outward (TRK-932: a fat rounded fill pies
    // the bend). Inner stop is the rim colour; outer stop is empty, so the
    // glow dies off the pane instead of drawing a second hard edge.
    Rectangle {
        y: -edge.haloH
        height: edge.haloH
        anchors.left: parent.left; anchors.right: parent.right
        anchors.leftMargin: edge.radiusTL; anchors.rightMargin: edge.radiusTR
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.shelfNone }
            GradientStop { position: 1.0; color: edge._glow }
        }
    }
    Rectangle {
        y: parent.height
        height: edge.haloH
        anchors.left: parent.left; anchors.right: parent.right
        anchors.leftMargin: edge.radiusBL; anchors.rightMargin: edge.radiusBR
        gradient: Gradient {
            GradientStop { position: 0.0; color: edge._glow }
            GradientStop { position: 1.0; color: Theme.shelfNone }
        }
    }
    Rectangle {
        x: -edge.haloH
        width: edge.haloH
        anchors.top: parent.top; anchors.bottom: parent.bottom
        anchors.topMargin: edge.radiusTL; anchors.bottomMargin: edge.radiusBL
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.shelfNone }
            GradientStop { position: 1.0; color: edge._glow }
        }
    }
    Rectangle {
        x: parent.width
        width: edge.haloH
        anchors.top: parent.top; anchors.bottom: parent.bottom
        anchors.topMargin: edge.radiusTR; anchors.bottomMargin: edge.radiusBR
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: edge._glow }
            GradientStop { position: 1.0; color: Theme.shelfNone }
        }
    }

    // crisp · 1 px on the pane edge, follows the rounded outline
    // (TRK-932 ninth: inset straights left a 22 px hole at each bend;
    // a 1 px stroke is a hairline, not the filled pie Sheen was).
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: edge._line
        topLeftRadius: edge.radiusTL
        topRightRadius: edge.radiusTR
        bottomRightRadius: edge.radiusBR
        bottomLeftRadius: edge.radiusBL
        antialiasing: true
    }
}
