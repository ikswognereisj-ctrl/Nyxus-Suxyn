// Nyxus Suxyn — Task View. Plain numbered virtual desktops, risen from the Line.
//
// AUDIT-PLAN item 7 / HORIZON Phase 2: stations are gone; Windows/macOS users
// expect a Task View that shows desktops as numbered surfaces, not a named
// "OPS/FORGE/GHOST" rail. This swell lists desktops 1–10 (Hyprland's numbered
// set), shows which is active, and switches on click / Enter / digit.
//
// Desktops are read via `hyprctl activeworkspace` + `hyprctl workspaces -j`
// on open — NEVER on a timer (hyprlock lesson: subprocesses on a short poll
// starve the event loop). Saving is switching; Escape closes.
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root
    visible: Bus.taskViewOpen
    color: "transparent"
    exclusiveZone: 0
    // See Bar.qml: the blur floor only matches ^(nyxus.*)$.
    WlrLayershell.namespace: "nyxus-taskview"

    anchors { left: true; right: true; bottom: true; top: true }

    // The dimmed field. The comment here has promised one since this surface
    // was written and there was never a rectangle to go with it — Task View
    // grabs the keyboard and swallows outside clicks, so it IS modal, and a
    // modal that does not dim reads as a card that has got stuck on top of
    // your desktop. Far lighter than the power menu's 0.90: this one is a
    // place you pass through, not a ceremony.
    Rectangle {
        anchors.fill: parent
        color: Theme.soften(Theme.void_, 0.52)
        opacity: Bus.taskViewOpen ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Bus.taskViewOpen ? Theme.durRise : Theme.durSink
                easing.type: Easing.Bezier
                easing.bezierCurve: Bus.taskViewOpen ? Theme.curveRise : Theme.curveSink
            }
        }
    }

    // Click the dimmed field to dismiss — same contract as the power menu.
    MouseArea {
        anchors.fill: parent
        onClicked: Bus.taskViewOpen = false
    }

    HyprlandFocusGrab {
        active: root.visible
        windows: [root]
        onCleared: Bus.taskViewOpen = false
    }

    // Refresh the list every time the surface opens — not while it sits idle.
    onVisibleChanged: if (visible) refresh()

    property int activeId: 1
    property var desks: []

    function refresh() {
        activeProc.running = false
        activeProc.running = true
        listProc.running = false
        listProc.running = true
    }

    function go(id) {
        Quickshell.execDetached(["hyprctl", "dispatch", "workspace", String(id)])
        Bus.taskViewOpen = false
    }

    Process {
        id: activeProc
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(text)
                    root.activeId = j.id || 1
                } catch (e) { /* keep last */ }
            }
        }
    }

    Process {
        id: listProc
        command: ["hyprctl", "workspaces", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var arr = JSON.parse(text)
                    // Numbered desktops only — named stations (HOME/START/…)
                    // are retired and must not reappear as tiles.
                    var nums = []
                    var seen = {}
                    for (var i = 0; i < arr.length; i++) {
                        var id = arr[i].id
                        if (typeof id !== "number" || id < 1 || id > 10) continue
                        if (seen[id]) continue
                        seen[id] = true
                        nums.push({
                            id: id,
                            windows: arr[i].windows || 0,
                            name: String(id)
                        })
                    }
                    // Always offer 1–4 even if empty, so a fresh session has
                    // somewhere to go without learning hyprctl.
                    for (var n = 1; n <= 4; n++) {
                        if (!seen[n]) nums.push({ id: n, windows: 0, name: String(n) })
                    }
                    nums.sort(function (a, b) { return a.id - b.id })
                    root.desks = nums
                } catch (e) {
                    root.desks = [
                        { id: 1, windows: 0, name: "1" },
                        { id: 2, windows: 0, name: "2" },
                        { id: 3, windows: 0, name: "3" },
                        { id: 4, windows: 0, name: "4" }
                    ]
                }
            }
        }
    }

    // The swell — rises from the horizon, flush bottom, no bottom corners.
    //
    // It did neither of those things. `bottomMargin` was `chromeH - bloomPad`,
    // which is the formula the Launcher and the Flyout apply to their WINDOW
    // (they then push the pane back up by `bloomPad`, so its foot lands
    // exactly on the horizon). Copied onto the pane itself inside a
    // full-screen window it put the card's foot 60 px up — 24 px INSIDE the
    // chrome zone, covering the top of the bar it is supposed to be standing
    // on. It also had `radius: r3` on all four corners and no rise, so it
    // appeared as a floating slab in the middle of the screen: the one shape
    // §2 says this desktop does not contain.
    //
    // Now it is a Swell like the other two — foot on the horizon, rounded only
    // on the corners that face open space, and it grows up out of the seam.
    //
    // The margin is ZERO, measured rather than reasoned: this window does not
    // set `exclusionMode: Ignore`, so the compositor has already shrunk it by
    // the bar's 84 px exclusive zone and `parent.bottom` IS the top of the
    // chrome. Any margin here is counted twice — with `chromeH` the card's
    // foot photographed at y 912, a clear 84 px short of the horizon.
    Pane {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 0
        width: Math.min(920, parent.width - Theme.s10 * 2)
        height: 220
        elevation: 2
        // TRK-3651 — no outer glow at rest; see Pane.qml.
        bloomAtRest: false
        // TRK-3370 — the widgets' stack, hand-carried because of the mixed
        // corner radii (SetSlab is uniform-radius): opaque elevated floor as
        // the Pane's own fill, panelMid paint + swellGround ramp as the two
        // Rectangles below. Arithmetic in SetSlab.qml.
        fill: Theme.elevated
        radiusTL: Theme.r3
        radiusTR: Theme.r3
        radiusBR: Theme.r0
        radiusBL: Theme.r0

        Rectangle {
            anchors.fill: parent
            topLeftRadius: Theme.r3; topRightRadius: Theme.r3
            bottomLeftRadius: Theme.r0; bottomRightRadius: Theme.r0
            color: Theme.panelMid
        }
        Rectangle {
            anchors.fill: parent
            topLeftRadius: Theme.r3; topRightRadius: Theme.r3
            bottomLeftRadius: Theme.r0; bottomRightRadius: Theme.r0
            gradient: Gradient {
                GradientStop { position: 0.00; color: Theme.swellGroundTop }
                GradientStop { position: 0.50; color: Theme.swellGroundMid }
                GradientStop { position: 1.00; color: Theme.swellGroundFoot }
            }
        }

        transform: Translate {
            y: Bus.taskViewOpen ? 0 : card.height
            Behavior on y {
                NumberAnimation {
                    duration: Bus.taskViewOpen ? Theme.durRise : Theme.durSink
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Bus.taskViewOpen ? Theme.curveRise : Theme.curveSink
                }
            }
        }
        opacity: Bus.taskViewOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durQuick } }

        // The same glass as the bar, the Start menu and the flyout.
        GlassEdge {
            // TRK-3653 - page-scale floating pane, SidePanel's rung.
            // It had no `edging`, so it took the component default while
            // the rest of the build had moved off it. Found by
            // docs/proof/audit-0901/glass-consistency.py, not by eye.
            edging: 0.85
            anchors.fill: parent
            radiusTL: Theme.r3
            radiusTR: Theme.r3
            // TRK-3370: body 0 — the slab stack above already carries the
            // ground; a GlassEdge body on top of it is the WIP-259 "dark
            // card on a dark card" failure.
            body: 0
            wash: 0
        }
        // The living border (owner ruling 2026-08-09) — see ReactiveEdge.qml.
        ReactiveEdge {
            // TRK-3649 - no resting outer halo. This pane floats over the
            // desktop, so the always-on 8 px band outside its edge read as a
            // second edge - the widgets never drew it. The beat bloom stays.
            haloAtRest: false
            radiusTL: Theme.r3
            radiusTR: Theme.r3
            radiusBR: Theme.r0
            radiusBL: Theme.r0
        }
        // The mirror rim — Launcher.qml § the mirror rim carries the ruling
        // (2026-08-14, "complete … system wide"). Page weight.
        MirrorEdge {
            radiusTL: Theme.r3; radiusTR: Theme.r3
            radiusBR: Theme.r0; radiusBL: Theme.r0
            depth: 20
            strength: 1.0
        }

        // ── 4 · THE SEAM (TRK-3372) ─────────────────────────────────
        // 1 px glacier[4], on the same mixed radii as the rest of the
        // stack so the seam traces the surface rather than a different
        // outline. Task View is flush with the horizon at the foot, which
        // is why the bottom pair is r0 here too.
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            antialiasing: true
            topLeftRadius: Theme.r3
            topRightRadius: Theme.r3
            bottomRightRadius: Theme.r0
            bottomLeftRadius: Theme.r0
            border.width: 1
            border.color: Theme.soften(Theme.paintLayers.glacier[4], 0.45)
        }

        // Swallow clicks so the dismiss MouseArea behind does not close us
        // when picking a desktop.
        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            anchors.fill: parent
            anchors.margins: Theme.s7
            spacing: Theme.s5

            Row {
                width: parent.width
                Text {
                    text: qsTr("TASK VIEW")
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    font.letterSpacing: Theme.trackMicro
                    font.weight: Font.DemiBold
                    color: Theme.textMuted
                }
                Item { width: parent.width - 200; height: 1 }
                Text {
                    text: qsTr("Esc to close · digit to jump")
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    color: Theme.textDim
                }
            }

            Row {
                id: deskRow
                spacing: Theme.s4
                width: parent.width
                height: parent.height - 40

                Repeater {
                    model: root.desks
                    delegate: TaskFace {
                        id: desk
                        required property var modelData
                        width: Math.max(72, (deskRow.width - (root.desks.length - 1) * Theme.s4) / Math.max(root.desks.length, 1))
                        height: deskRow.height
                        reading: desk.modelData.name
                        caption: desk.modelData.windows === 0
                                 ? "empty"
                                 : (desk.modelData.windows + (desk.modelData.windows === 1 ? " window" : " windows"))
                        selected: desk.modelData.id === root.activeId
                        onActivated: root.go(desk.modelData.id)
                    }
                }
            }
        }
    }

    // Digit keys jump; Escape closes (FocusGrab also clears on outside click).
    Shortcut {
        sequences: ["Escape"]
        enabled: root.visible
        onActivated: Bus.taskViewOpen = false
    }
    // ⚠ The delegate is an `Item` wrapping the Shortcut, not the Shortcut
    // itself. A `Repeater` can only instantiate Items — with a bare `Shortcut`
    // it logged "Delegate must be of Item type" and created NONE of them, so
    // the "digit to jump" the header advertises has never once worked. It is
    // the same class of defect as the `readonly property` that took `Bar.qml`
    // out entirely: a warning in a log nobody reads, and a feature that is
    // simply absent.
    Repeater {
        model: 10
        delegate: Item {
            id: jump
            required property int index
            Shortcut {
                sequences: [String((jump.index + 1) % 10)]
                enabled: root.visible
                onActivated: root.go(jump.index + 1)
            }
        }
    }
}
