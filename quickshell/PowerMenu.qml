// Nyxus Suxyn — power. THE SUBMERSION.
//
// WHY THIS EXISTS. The Start menu already had a power button, and it ran:
//
//     nyxus-power || wlogout || hyprctl dispatch exit
//
// `nyxus-power` does not exist. `wlogout` is not packaged. So it always fell
// through to the third option, which kills the session instantly — no
// confirmation, no shut down, no restart, no sleep. The owner logged into the
// preview, could not find any way out, and had to hard-reset the machine.
//
// A button that always destroys your session is worse than no button, so this
// is a real menu with a confirm step on anything that loses work. Every action
// goes through systemd/loginctl rather than a helper script, so there is no
// binary to be missing. That contract is unchanged.
//
// WHAT CHANGED (HORIZON §5.5). This is the one ceremony in the system, and the
// only place `durCeremony` is allowed. The desktop darkens and the horizon
// RISES to the middle of the screen — the same seam, the same living paint,
// the same "objects resting on a line" language as the taskbar Row, just
// brought up to eye level. Confirming a destructive action turns the seam gold
// under that action alone.
//
// The point is not decoration. The actions that end your session should feel
// different from every other click in the desktop, which is exactly what a
// confirm step is for; a moment of ceremony is a moment to change your mind.
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root
    visible: Bus.powerOpen || dim.running

    anchors { top: true; bottom: true; left: true; right: true }
    // Owner 2026-08-19: optical air above the bar, same s5 as Start. The
    // ceremony still fills the desktop; the bar stays visible underneath.
    margins.bottom: Theme.chromeH + Theme.s5
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // Needs the keyboard so Escape closes it and so a stray click cannot land
    // on the desktop behind a destructive confirm.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "nyxus-power"

    // Actions. `confirm` is true for anything that loses unsaved work.
    readonly property var actions: [
        // ONE LOCK, and it is the Earth one. Owner ruling, 2026-08-31.
        //
        // This tile used to run `sh -c "loginctl lock-session || hyprlock"`,
        // and that `|| hyprlock` was the ONLY route left in the build that can
        // start a bare hyprlock without `nyxus-lock-guard` choosing it \u2014
        // measured: it is the single executable `hyprlock` invocation outside
        // the guard in `shell/`, `etc/skel/` and `nyxus-scripts/` (every other
        // occurrence is a comment, a `neverFrost` pattern or a search keyword).
        //
        // Three things came back with it, and none of them are cosmetic:
        //
        //   1. THE ENGINE. `loginctl lock-session` is what BOTH keybinds run
        //      (`hyprland.conf:639` Super+L and `:776` Super+Ctrl+Alt+L, and
        //      the two committed twins of that file are byte-identical, so
        //      there is no shipped-copy ambiguity here). It reaches hypridle's
        //      `lock_cmd`, which calls `nyxus-lock-guard`, which PREFERS
        //      `shell/Lock.qml` \u2014 the Earth surface \u2014 and falls back to
        //      hyprlock only when the shell fails a live pre-flight. Bare
        //      hyprlock skipped that choice entirely and always drew the wrong
        //      lock, which is exactly the complaint.
        //
        //   2. THE WIP-114 REFUSAL. `nyxus-lock-guard` checks FIRST that the
        //      account can be unlocked and explains instead of locking when it
        //      cannot. Bare hyprlock has no such check, so this tile could
        //      lock a passwordless account into a state whose only exit is a
        //      hard reset \u2014 the owner met that once and photographed it.
        //
        //   3. THE CHIME AND THE WEATHER. `hypridle.conf:69` runs
        //      `nyxus-sound lock` and refreshes `nyxus-lock-weather` on the way
        //      in. The bypass silently dropped both.
        //
        // And TRK-3470 is the reason the removed branch is worth naming: a
        // bare hyprlock that outlived its unlock, with stderr on /dev/null,
        // blocked correct locking for 18+ minutes and cost three rounds of
        // diagnosis. This was a route that could produce one.
        //
        // NOT sh -c. A plain argv needs no shell, and `||` was the only reason
        // one was ever spawned here.
        { id: "lock",     label: qsTr("Lock"),      glyph: "\uf023", confirm: false,
          cmd: ["loginctl", "lock-session"] },
        { id: "sleep",    label: qsTr("Sleep"),     glyph: "\uf186", confirm: false,
          cmd: ["systemctl", "suspend"] },
        // TRK-1301 / TRK-1600. The tile is ALWAYS here. When hibernate is not
        // possible on this box it is shown disabled with the reason under the
        // deck — the TRK-1305 ruling is "no silent impossibility", so a
        // missing swapfile must read as a sentence a person can act on, never
        // as a tile that quietly is not there. `now` re-checks and refuses on
        // stderr, so a race between the probe and the click cannot black-screen.
        // Glyph was `\uf0f3` (fa-bell); `\uf2dc` is the snowflake / freeze mark.
        { id: "hibernate", label: qsTr("Hibernate"), glyph: "\uf2dc", confirm: false,
          cmd: ["nyxus-hibernate", "now"] },
        { id: "logout",   label: qsTr("Log out"),   glyph: "\uf2f5", confirm: true,
          cmd: ["hyprctl", "dispatch", "exit"] },
        { id: "restart",  label: qsTr("Restart"),   glyph: "\uf2f1", confirm: true,
          cmd: ["systemctl", "reboot"] },
        { id: "shutdown", label: qsTr("Shut down"), glyph: "\uf011", confirm: true,
          cmd: ["systemctl", "poweroff"] }
    ]

    property int pending: -1        // index awaiting confirmation, -1 = none

    // -- hibernate availability (TRK-1301) ----------------------------
    // `nyxus-hibernate --check --json` is the ONE place this question is
    // answered: kernel support, a disk-backed swap >= RAM, resume= on the
    // running command line, logind's own verdict, and the installer's
    // recorded `install_reason` when --setup could not wire it. Re-probed on
    // every open rather than once per session: a swapfile can be laid down,
    // or a kernel updated, while this session is still running.
    property bool hibAvailable: false
    property string hibReason: ""
    property bool hibProbed: false

    Process {
        id: hibProbe
        running: false
        command: ["sh", "-c",
            'if command -v nyxus-hibernate >/dev/null 2>&1; then '
          + '  nyxus-hibernate --check --json 2>/dev/null; '
          + 'else echo __NOHIB__; fi']
        onExited: function (code) { if (code !== 0) console.warn("[PowerMenu] hibernate probe exited code " + code); }
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = String(this.text).trim();
                root.hibProbed = true;
                if (raw === "" || raw === "__NOHIB__") {
                    root.hibAvailable = false;
                    root.hibReason = qsTr("nyxus-hibernate is not installed on this system.");
                    return;
                }
                var v = null;
                try {
                    v = JSON.parse(raw);
                } catch (e) {
                    root.hibAvailable = false;
                    root.hibReason = qsTr("hibernate could not be checked — the check returned something unreadable.");
                    return;
                }
                root.hibAvailable = v.available === true;
                // install_reason is the installer's own sentence and is the
                // more actionable of the two; the live reason is the fallback.
                var why = String(v.install_reason || "").trim();
                if (why === "")
                    why = String(v.reason || "").trim();
                root.hibReason = root.hibAvailable ? "" : why;
            }
        }
    }

    // Ice for rest chrome (Lock / Sleep / Hibernate). Magma only once a
    // confirm action is armed (Logout / Restart / Shut down). glacier[0]
    // is the hover rim, never a fill. Bar swirls stay the user's pick.
    readonly property color iceInteractive: Theme.paintLayers.glacier[0]
    readonly property color icePrimary:     Theme.paintLayers.glacier[5]
    readonly property color iceHairline:    Theme.paintLayers.glacier[4]
    readonly property color magmaInteractive: Theme.paintLayers.magma[0]
    readonly property color magmaPrimary:     Theme.paintLayers.magma[5]

    function run(i) {
        var a = actions[i];
        // A disabled tile is inert. The CLI would refuse anyway (`now`
        // re-checks), but a click that silently does nothing is worse than a
        // tile that cannot be clicked.
        if (a.id === "hibernate" && !root.hibAvailable)
            return;
        if (a.confirm && pending !== i) {
            pending = i;
            return;
        }
        pending = -1;
        Bus.powerOpen = false;
        Quickshell.execDetached(a.cmd);
    }

    onVisibleChanged: {
        if (!visible) {
            pending = -1;
            return;
        }
        if (!hibProbe.running)
            hibProbe.running = true;
    }

    // ── the submersion ───────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Theme.soften(Theme.void_, 0.90)
        opacity: Bus.powerOpen ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                id: dim
                duration: Bus.powerOpen ? Theme.durRise : Theme.durSink
                easing.type: Easing.Bezier
                easing.bezierCurve: Bus.powerOpen ? Theme.curveRise : Theme.curveSink
            }
        }
    }

    // Click-off and Escape both cancel. A power menu you cannot back out of is
    // the same trap in a different shape.
    MouseArea {
        anchors.fill: parent
        onClicked: Bus.powerOpen = false
    }
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Bus.powerOpen = false
    }

    // The horizon, raised. Everything below is positioned against `sea`, so
    // the whole ceremony is literally the taskbar's seam brought up to eye
    // level and the actions resting on it.
    Item {
        id: sea
        anchors { left: parent.left; right: parent.right }
        y: parent.height * (Bus.powerOpen ? 0.52 : 1.0)
        height: 1
        opacity: Bus.powerOpen ? 1 : 0

        Behavior on y {
            NumberAnimation {
                duration: Bus.powerOpen ? Theme.durCeremony : Theme.durSink
                easing.type: Easing.Bezier
                easing.bezierCurve: Bus.powerOpen ? Theme.curveRise : Theme.curveSink
            }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.durBase } }

        // The living paint, in the risen seam. Same component, same rules:
        // brightest at the line, dying out above and below it. Loaded on
        // demand — see Flyout.qml: a ShaderEffectSource in a never-exposed
        // window segfaults the scene graph.
        Loader {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            height: 150
            active: Prefs.swirlEnabled && Bus.powerOpen
            sourceComponent: Swirl {
                // ── TRK-3720 · MATCH THE BOTTOM BAR ──────────────────────
                // Owner: "swirl color needs to match the bottom bar swirls".
                //
                // The ramp was NEVER the difference — this Swirl inherits the
                // same `PaintMood.ramp` array BarSeam passes explicitly. What
                // differed is the branch of `swirl_view.frag` the display pass
                // returns from, chosen by `paintMode`:
                //
                //   "shadow-bar" -> OCCLUDER branch. Pure black paint read by
                //                   what it HIDES of a faint neutral glow, two
                //                   thin lit contours, alpha 0 (added light).
                //   "paint"      -> COLOUR branch. Bloom, wet sheen, filmic
                //                   shoulder, saturation lift, alpha to 0.88
                //                   (it covers).
                //
                // The display constants below fork on the same switch because
                // BarSeam forks its own on `occluder` — putting both surfaces
                // on one branch with different calibration would look no more
                // matched than before. Values are BarSeam's occluder column.
                //
                // ONE WORD TO REVERSE. This surface has been reversed three
                // times; the fourth should cost `matchBar: false`, which
                // restores exactly the colour treatment he praised.
                property bool matchBar: true

                paintMode: matchBar ? "shadow-bar" : Prefs.swirlMode
                contourColor: Theme.tokenAccentPrimary
                contourTintAmount: 0.85
                intensity: Prefs.swirlIntensity
                cornerRadius: Theme.r0
                interactive: false
                playIntroOnLoad: true
                introStrength: 0.75
                // swirl-live.html's `pill` preset, same reasoning as Flyout.qml.
                // The sweep stays full here — the power menu is centred, so
                // there is no "this end of the screen" to slice it to.
                curlAmp: 0.64
                force: 4400
                decayRate: 0.30
                simShort: 80
                // TRK-3669 · 1.75 -> 1.15. The owner's note on the first ice
                // render was that it read NEON rather than matte, and the ramp
                // was not the cause: swapping the bright stop for its
                // half-saturation twin moved rendered saturation 0.62 -> 0.63,
                // i.e. not at all. The DISPLAY stage was amplifying it. This
                // surface sat at 1.75 while Launcher runs 0.92 with the note
                // "headroom, so cores hold structure", Spill 1.06 and BarSeam
                // 1.30 — the power menu was the loudest paint-mode surface in
                // the build by a wide margin. 1.15 puts it between Spill and
                // BarSeam and leaves the solver's structure intact.
                exposure: matchBar ? 1.30 : 1.15
                // TRK-3669 · 0.9 -> 0.62. Exposure fixed the STRUCTURE (the
                // solver's turbulence is visible again instead of a blown white
                // band) but the sweep's ends still read hot. Opacity is the
                // right lever for that and exposure is not: dropping exposure
                // again would flatten the detail that was just recovered,
                // whereas opacity sits the whole sweep BACK behind the tiles
                // without touching what it is made of.
                opacity: 0.62
                audioBass: Beat.bass
                audioMid: Beat.mid
                audioHigh: Beat.high
                audioPulse: Beat.pulse
                musicActive: Beat.hot
            }
        }

        // The resting hairline, so the ceremony reads even with paint off.
        Repeater {
            model: [
                { h: 2,  a: 0.80 },
                { h: 7,  a: 0.14 }
            ]
            delegate: Rectangle {
                id: hair
                required property var modelData
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                height: hair.modelData.h
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.00; color: "transparent" }
                    GradientStop { position: 0.18; color: Theme.soften(root.iceHairline, hair.modelData.a) }
                    GradientStop { position: 0.50; color: Theme.soften(root.icePrimary, hair.modelData.a) }
                    GradientStop { position: 0.82; color: Theme.soften(root.iceHairline, hair.modelData.a) }
                    GradientStop { position: 1.00; color: "transparent" }
                }
            }
        }
    }

    // ── the question, above the line ─────────────────────────────────
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: deck.top
        anchors.bottomMargin: Theme.s10
        spacing: Theme.s5
        opacity: Bus.powerOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durBase } }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.pending >= 0 ? root.actions[root.pending].label.toUpperCase() : qsTr("POWER")
            font.family: Theme.fUi
            font.pixelSize: Theme.tMicro
            font.weight: Font.Medium
            font.letterSpacing: Theme.trackMicro * 2
            color: root.pending >= 0 ? root.magmaInteractive : Theme.textDim
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 520
            text: root.pending >= 0
                  ? "Unsaved work will be lost.\nChoose it again to confirm."
                  : "What would you like to do?"
            font.family: Theme.fUiTitle
            font.pixelSize: Theme.tTitle
            font.weight: Font.Light
            font.letterSpacing: Theme.trackTitle
            color: Theme.text
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }

    // ── the actions, resting on the line ─────────────────────────────
    Row {
        id: deck
        anchors.horizontalCenter: parent.horizontalCenter
        y: sea.y - height + Theme.s2
        spacing: Theme.s6
        opacity: Bus.powerOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durBase } }

        Repeater {
            model: root.actions
            delegate: Item {
                id: act
                required property var modelData
                required property int index
                width: 116
                height: 116
                clip: true
                transformOrigin: Item.Center
                scale: act.disabled ? 1.0
                     : (tap.pressed ? 0.97
                        : (act.armed ? 1.06
                           : (hov.hovered ? 1.04 : 1.0)))
                Behavior on scale {
                    NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutQuint }
                }

                readonly property bool armed: root.pending === act.index
                // TRK-1301: an unavailable hibernate is DISABLED, never hidden.
                readonly property bool disabled:
                    act.modelData.id === "hibernate" && !root.hibAvailable
                readonly property bool dimmed:
                    act.disabled || (root.pending >= 0 && !act.armed)
                // confirm:true = loses work. Magma only once that confirm is armed.
                readonly property bool hot: act.modelData.confirm === true
                readonly property bool restIce:
                    act.modelData.id === "lock" || act.modelData.id === "sleep"
                readonly property color tone: (act.hot && act.armed) ? root.magmaPrimary
                    : root.icePrimary
                // Dim the glass, not the tooltip — a 0.34 Item would hide
                // the reason the tile exists to show (TRK-2995).
                readonly property real fade: act.disabled ? 0.55 : (act.dimmed ? 0.30 : 1.0)
                readonly property string pipKind: act.disabled ? "off"
                    : ((act.hot && act.armed) ? "magma"
                       : (act.restIce && hov.hovered ? "ice" : "off"))

                Pane {
                    anchors.fill: parent
                    anchors.bottomMargin: Theme.s5
                    elevation: 3
                    radius: Theme.r2
                    opacity: act.fade
                    Behavior on opacity { NumberAnimation { duration: Theme.durBase } }
                    // TRK-3370 — the widgets' stack (opaque elevated floor as
                    // the Pane fill, panelMid + swellGround below), replacing
                    // the glassFill wash: the tiles now stand on the same
                    // slab as every widget. Hover is a wash OVER the stack.
                    fill: Theme.elevated
                    focusLevel: tap.pressed ? 1.0 : (hov.hovered || act.armed ? 1.0 : 0.35)

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.r2
                        color: Theme.panelMid
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.r2
                        gradient: Gradient {
                            GradientStop { position: 0.00; color: Theme.swellGroundTop }
                            GradientStop { position: 0.50; color: Theme.swellGroundMid }
                            GradientStop { position: 1.00; color: Theme.swellGroundFoot }
                        }
                    }
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.r2
                        color: Theme.soften(Theme.paintLayers.glacier[5], 0.10)
                        visible: hov.hovered || tap.pressed
                    }

                    GlassEdge {
                        anchors.fill: parent
                        radiusTL: Theme.r2
                        radiusTR: Theme.r2
                        radiusBR: Theme.r2
                        radiusBL: Theme.r2
                        // TRK-3629 · quieted with the Start menu and the side panel.
                        // `edging` scales the Lip and the Sheen — the layers the owner
                        // saw stacked on the Start menu's edge on 2026-09-01. This
                        // surface had never set it either, so it took the 1.0 default
                        // while SidePanel ran 0.85, the widget chips 0.70/0.85, SetSlab
                        // 0.46/0.66 and Toasts 0.35. 0.85 is SidePanel's value: the same
                        // rung every other floating pane that was actually tuned uses.
                        // Nothing else moves — body stays 0, the swell, ReactiveEdge and
                        // the seam are untouched.
                        edging: 0.85
                        // Deliberately NO body (WIP-259). These five tiles are
                        // the one floating surface whose backdrop this shell
                        // controls: the power menu dims the entire screen
                        // behind itself first, so there is no window left to
                        // read through — the condition every other Swell has
                        // to solve does not exist here. They already carry
                        // glassFill / glassFillStrong, which on a 90%-dimmed
                        // screen is a slab. Adding a body would make them the
                        // black rectangles the comment above says they must
                        // not be.
                        body: 0
                        wash: 0
                    }
                    // The mirror rim — Launcher.qml § the mirror rim carries
                    // the ruling (2026-08-14, "complete … system wide").
                    // Card weight, SetCard's own numbers.
                    MirrorEdge {
                        radiusTL: Theme.r2; radiusTR: Theme.r2
                        radiusBR: Theme.r2; radiusBL: Theme.r2
                        depth: 12
                        strength: 0.62
                    }
                    // 1 px glacier[4] seam (widget chips). glacier[0] is the
                    // hover rim, never a fill. Magma only while confirm-armed.
                    CutRect {
                        anchors.fill: parent
                        radius: Theme.r2
                        color: "transparent"
                        borderWidth: 1
                        borderColor: (act.hot && act.armed)
                            ? Theme.soften(root.magmaPrimary, 0.95)
                            : Theme.soften(hov.hovered || tap.pressed
                                           ? root.iceInteractive
                                           : root.iceHairline,
                                           hov.hovered || tap.pressed ? 0.85 : 0.45)
                        Behavior on borderColor { ColorAnimation { duration: Theme.durQuick } }
                    }

                    StatusPip {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: Theme.s3
                        anchors.topMargin: Theme.s3
                        kind: act.pipKind
                        pulse: act.hot && act.armed
                        z: 8
                    }

                    Column {
                        anchors.centerIn: parent
                        width: parent.width - Theme.s5 * 2
                        spacing: act.disabled ? Theme.s2 : Theme.s4

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: act.modelData.glyph
                            font.family: Theme.fIcon
                            font.pixelSize: Theme.tTitle
                            color: (act.hot && act.armed) ? root.magmaInteractive
                                 : (hov.hovered || tap.pressed
                                    ? root.icePrimary
                                    : Theme.textMuted)
                            Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            text: act.modelData.label
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tLabel
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            clip: true
                            color: hov.hovered || tap.pressed || act.armed ? Theme.text : Theme.textMuted
                            Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                        }
                        // On the tile itself, not only under the deck. A grey
                        // tile with no word on it is the same as a hidden one.
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width
                            visible: act.disabled
                            text: qsTr("Unavailable")
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                            font.letterSpacing: Theme.trackMicro
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            clip: true
                            color: Theme.text
                        }
                    }
                }

                // Its root in the risen seam — the same language as an app's
                // root in the Row. Gold when the action is armed.
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: act.height - 3
                    height: 3
                    radius: 1.5
                    width: act.armed ? 74 : (hov.hovered || tap.pressed ? 46 : 0)
                    color: act.tone
                    opacity: act.fade
                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.durBase
                            easing.type: Easing.Bezier
                            easing.bezierCurve: Theme.curveMove
                        }
                    }
                }

                HoverHandler {
                    id: hov
                    // Hover stays on so the disabled tile can show its reason.
                    // Tap stays inert — `enabled: !act.disabled` is what 13z10
                    // asserts, and what keeps a grey click from firing `now`.
                    cursorShape: act.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                }
                TapHandler {
                    id: tap
                    enabled: !act.disabled
                    onTapped: root.run(act.index)
                }

                // Tooltip: the full sentence, at full opacity, only while
                // the pointer is on the grey tile. Not QtQuick.Controls —
                // this shell does not import that module.
                Rectangle {
                    id: hibTip
                    visible: act.disabled && hov.hovered
                    parent: deck
                    z: 40
                    width: 320
                    implicitHeight: tipCol.implicitHeight + Theme.s6
                    x: act.x + Math.round((act.width - width) / 2)
                    y: act.y - height - Theme.s3
                    radius: Theme.r1
                    color: Theme.soften(Theme.void_, 0.92)
                    border.color: root.iceHairline
                    border.width: 1

                    Column {
                        id: tipCol
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: Theme.s4
                        }
                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: root.hibReason !== ""
                                  ? qsTr("Hibernate is unavailable — %1").arg(root.hibReason)
                                  : qsTr("Hibernate is unavailable on this machine.")
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            color: Theme.text
                        }
                    }
                }
            }
        }
    }

    // The sentence behind a disabled Hibernate (TRK-1301 / TRK-1308 / TRK-2995).
    // Always on screen while the tile is disabled. The tile also carries
    // "Unavailable" and a hover tooltip; a grey tile with no words is the
    // same as a hidden one.
    Text {
        id: hibWhy
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: sea.bottom
        anchors.topMargin: Theme.s8
        width: 640
        visible: Bus.powerOpen && root.hibProbed && !root.hibAvailable
        text: root.hibReason !== ""
              ? qsTr("Hibernate is unavailable — %1").arg(root.hibReason)
              : qsTr("Hibernate is unavailable on this machine, and nothing recorded why.")
        font.family: Theme.fUi
        font.pixelSize: Theme.tLabel
        color: Theme.text
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        opacity: Bus.powerOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durBase } }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: sea.bottom
        anchors.topMargin: 118
        text: root.pending >= 0 ? qsTr("ESC TO CANCEL") : qsTr("ESC OR CLICK ANYWHERE TO CLOSE")
        font.family: Theme.fUi
        font.pixelSize: Theme.tMicro
        font.weight: Font.Medium
        font.letterSpacing: Theme.trackMicro
        color: Theme.textDim
        opacity: Bus.powerOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durBase } }
    }
}
