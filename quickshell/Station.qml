pragma ComponentBehavior: Bound
// Nyxus Suxyn — THE ROOMS HUD (TRK-1702): the little map, the arrival
// nameplate, and the `house` IPC fast path.
//
// Three surfaces and no more:
//   the MAP     a small card in a corner (bottom-right by default). It shows
//               the grid, which room you are in, which rooms hold windows and
//               how many, the room's name, and the carry strip while you are
//               carrying. It is a SPATIAL ANCHOR: it appears when you move and
//               fades when you stop, so it tells you where you are at exactly
//               the moment you asked and is not on screen the rest of the time.
//               Clicking a cell goes to that room, every time, through the one
//               formula in Rooms.qml — and it is INERT unless the map is fully
//               up, so a click cannot land on something that is fading away.
//   the PLATE   the room's name, once, on arrival, then gone. Orientation
//               without clutter. Debounced, so walking three rooms fast reads
//               out the room you ended in rather than flickering through three.
//   the BUMP    walk into an edge with wrap off and the map leans that way and
//               comes back. You feel the wall instead of wondering if the key
//               registered.
//
// THE FAST PATH. Every walking bind asks this handler first (`qs ipc call
// house walk left`); it answers "ok" after ONE batched hyprctl. `qs ipc call`
// exits 0 even when the target is missing, so the shard matches the OUTPUT and
// falls back to the nyxus-house script when the shell is not up.
//
// COSTS NOTHING WHEN IDLE. No repeating timer exists in this file. The fade is
// a Behavior (runs only during the transition), the auto-hide is a single-shot
// Timer started by movement, and the window counts are fetched on show and on
// arrival rather than polled.
//
// COSTS NOTHING WHEN OFF. shell.qml builds this only inside
// LazyLoader { active: Prefs.stationEnabled }, so with the Rooms switched off
// there is no HUD, no map window and no `house` IPC target at all.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Scope {
    id: hud

    readonly property bool enabled: Prefs.stationEnabled
    readonly property string mapMode: Prefs.stationMap          // off | auto | pinned
    readonly property string corner: Prefs.stationMapCorner
    readonly property int fadeAfter: Prefs.stationMapFade
    readonly property bool plateOn: Prefs.stationPlate

    property bool pinned: false                 // SUPER+ALT+M, for this session
    property bool showing: false                // the auto-fade window is open
    property string bumpDir: ""
    property string plateText: ""

    readonly property bool mapUp: enabled && mapMode !== "off"
                                 && (pinned || mapMode === "pinned" || showing)

    function reveal() {
        if (mapMode === "off") return;
        Rooms.refresh();
        showing = true;
        if (mapMode === "auto" && !pinned) hideTimer.restart();
        else hideTimer.stop();
    }
    // single-shot: it stops itself, and nothing re-arms it while you are still
    Timer { id: hideTimer; interval: hud.fadeAfter; repeat: false; onTriggered: hud.showing = false }
    // one plate for a burst of moves, not one per move
    Timer { id: plateTimer; interval: 90; repeat: false; onTriggered: hud.plateText = Rooms.roomLabel }
    // ~700 ms of dwell after the 90 ms debounce. 700 ms is this build's
    // settled duration for a brief identifying whisper — the app-name
    // whisper on window open uses it — so this is that one convention for
    // "a label that names a thing and then goes away", not a second one
    // invented here.
    Timer { id: plateClear; interval: 790; repeat: false; onTriggered: hud.plateText = "" }
    Timer { id: bumpClear; interval: 260; repeat: false; onTriggered: hud.bumpDir = "" }

    Connections {
        target: Rooms
        function onArrived(name, dir) {
            hud.reveal();
            if (hud.plateOn && name !== "") { plateTimer.restart(); plateClear.restart(); }
        }
        function onBumped(dir) {
            hud.bumpDir = dir;
            bumpClear.restart();
            hud.reveal();
        }
        function onCarryingChanged() { hud.reveal(); }
    }

    // ── the map ──────────────────────────────────────────────────────────
    PanelWindow {
        id: mapWin
        // Pinned to the internal panel. An explicit screen stops Quickshell
        // reassigning `screen` on map/unmap — the old HDMI guard read
        // mapWin.screen from this window's own `visible` binding and looped.
        // An HDMI-only machine falls back to its first screen rather than
        // losing the map.
        screen: {
            const ss = Quickshell.screens;
            for (let i = 0; i < ss.length; i++)
                if (String(ss[i].name || "").indexOf("HDMI") !== 0) return ss[i];
            return ss.length > 0 ? ss[0] : null;
        }
        visible: hud.enabled && (mapWin.v > 0.001)
                 && !Prefs.arcadeMode
        anchors {
            right: hud.corner.indexOf("right") >= 0
            left: hud.corner.indexOf("left") >= 0
            bottom: hud.corner.indexOf("bottom") >= 0
            top: hud.corner.indexOf("top") >= 0
        }
        // clear of the bar. The bar is a layer-shell surface of its own and
        // this one has exclusiveZone 0, so neither can push the other around.
        margins {
            right: Theme.s7
            left: Theme.s7
            bottom: hud.corner.indexOf("bottom") >= 0 ? Theme.chromeH + Theme.s6 : Theme.s6
            top: Theme.s6
        }
        implicitWidth: card.implicitWidth
        implicitHeight: card.implicitHeight
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "nyxus-rooms-map"
        // never takes the keyboard: the map is something you glance at while
        // your hands are on the arrows
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        property real v: hud.mapUp ? 1 : 0
        Behavior on v { NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutCubic } }
        // fully up, and only then, may a click land
        readonly property bool live: hud.mapUp && v > 0.995

        Rectangle {
            id: card
            width: parent.width
            height: parent.height
            implicitWidth: Math.round(roomGrid.implicitWidth + 2 * Theme.s6)
            implicitHeight: Math.round(roomGrid.implicitHeight + head.height + 3 * Theme.s5)
            radius: Theme.r3
            // TRK-3370 — the ground and seam come from SetSlab below (the
            // widgets' stack: floor + panelMid + swellGround + glacier[4]
            // seam), replacing the glassFillStrong wash and the teal border.
            color: "transparent"

            SetSlab {
                anchors.fill: parent
                cornerRadius: Theme.r3
            }
            opacity: mapWin.v
            scale: 0.97 + 0.03 * mapWin.v
            transformOrigin: hud.corner === "bottom-right" ? Item.BottomRight
                           : hud.corner === "bottom-left" ? Item.BottomLeft
                           : hud.corner === "top-right" ? Item.TopRight : Item.TopLeft

            // the wall you walked into: the card leans that way and comes back
            transform: Translate { id: lean; x: 0; y: 0 }
            SequentialAnimation {
                running: hud.bumpDir !== ""
                NumberAnimation {
                    target: lean
                    property: (hud.bumpDir === "up" || hud.bumpDir === "down") ? "y" : "x"
                    to: hud.bumpDir === "left" ? -7 : hud.bumpDir === "right" ? 7
                      : hud.bumpDir === "up" ? -7 : 7
                    duration: 90
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: lean
                    property: (hud.bumpDir === "up" || hud.bumpDir === "down") ? "y" : "x"
                    to: 0
                    duration: 170
                    easing.type: Easing.OutBack
                }
            }

            GlassEdge {
                anchors.fill: parent
                radiusTL: card.radius
                radiusTR: card.radius
                radiusBR: card.radius
                radiusBL: card.radius
                edging: 0.35
                body: 0
                wash: 0
                glaze: 0
            }

            Item {
                id: head
                x: Theme.s6
                y: Theme.s5
                width: card.width - 2 * Theme.s6
                height: 16
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("ROOMS")
                    color: Theme.textDim
                    font.family: Theme.fUiTitle
                    font.pixelSize: Theme.tMicro
                    font.letterSpacing: 3
                    font.weight: Font.DemiBold
                    renderType: Text.NativeRendering
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Rooms.degraded ? qsTr("default grid")
                        : Rooms.outside ? qsTr("outside")
                        : Rooms.roomLabel
                    color: Theme.textMuted
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    renderType: Text.NativeRendering
                    elide: Text.ElideRight
                    clip: true
                    width: Math.max(0, parent.width - 70)
                    horizontalAlignment: Text.AlignRight
                }
            }

            RoomGrid {
                id: roomGrid
                x: Theme.s6
                y: Math.round(head.y + head.height + Theme.s5)
                // ONE code path to a room: the click calls Rooms.jumpTo with
                // the workspace the cell computed from Rooms.wsOf — the same
                // number the arrow keys reach. And it is dead until the map
                // has finished coming up.
                interactive: mapWin.live
                onJump: function (ws) { Rooms.jumpTo(ws); hud.reveal(); }
            }
        }
    }

    // ── the arrival nameplate ────────────────────────────────────────────
    PanelWindow {
        id: plateWin
        // The fade lives on the window, not on the child Text: reading
        // plate.opacity back into `visible` looped (the child re-evaluates
        // when the window maps/unmaps). plateV animates 1→0 after the text
        // clears and only then does the window unmap — same fade as before.
        property real plateV: hud.plateText !== "" ? 1 : 0
        Behavior on plateV { NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutCubic } }
        visible: hud.enabled && hud.plateOn && (plateV > 0.001)
        // NOT the top edge — that edge is spoken for, and both top corners
        // are already taken (the recording card top-right, widgets
        // top-left). With left+right anchored and neither top nor bottom,
        // the strip sits at the screen's vertical centre: clear of every
        // other surface, clear of the bar, and gone again in under a second.
        anchors { left: true; right: true }
        implicitHeight: 54
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "nyxus-rooms-plate"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}                      // never takes a click

        Text {
            id: plate
            anchors.centerIn: parent
            text: hud.plateText.toUpperCase()
            color: Theme.text
            font.family: Theme.fUiTitle
            font.pixelSize: Theme.tHead
            font.letterSpacing: 8
            font.weight: Font.DemiBold
            renderType: Text.NativeRendering
            opacity: plateWin.plateV
            scale: hud.plateText !== "" ? 1 : 0.96
            Behavior on scale { NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutCubic } }
        }
    }

    // ── the binds land here ──────────────────────────────────────────────
    IpcHandler {
        target: "house"
        // Every function returns a STRING on purpose: `qs ipc call` exits 0
        // even when the target does not exist, so the shard matches the OUTPUT
        // and only then trusts that the HUD handled the key.
        function walk(dir: string): string { return Rooms.walk(dir); }
        function carry(): string { return Rooms.carry(); }
        function jump(ws: int): string { return Rooms.jumpTo(ws); }
        function go(room: string): string { return Rooms.jumpRoom(room); }
        function shelf(n: int): string { return Rooms.launchShelf(Rooms.room, n); }
        function shelfIn(room: string, n: int): string { return Rooms.launchShelf(room, n); }
        function carrystate(addr: string): string { Rooms.setCarry(addr); return "ok"; }
        function arrive(room: string, label: string, dir: string): string {
            Rooms.lastDir = dir; hud.reveal(); return "ok";
        }
        function bump(dir: string): string { hud.bumpDir = dir; bumpClear.restart(); hud.reveal(); return "ok"; }
        function map(action: string): string {
            // `show` collides with qs's own verb on some builds; open/close are
            // the spoken forms and show/hide still answer.
            if (action === "toggle") hud.pinned = !hud.pinned;
            else if (action === "show" || action === "open" || action === "on") hud.pinned = true;
            else hud.pinned = false;
            if (hud.pinned) { Rooms.refresh(); hideTimer.stop(); } else hud.reveal();
            return hud.pinned ? "shown" : "hidden";
        }
        function reload(): string { Rooms.reloadMap(); return "ok"; }
        function where(): string {
            return Rooms.room + " ws=" + Rooms.liveWs + (Rooms.carrying !== "" ? " carrying" : "");
        }
        function ready(): string { return "ready"; }
    }
}
