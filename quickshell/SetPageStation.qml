pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ System ▸ Rooms (TRK-1703).
//
// EVERY CONTROL ON THIS PAGE IS WIRED END TO END. This repo has twice shipped
// a setting that recorded a preference nothing read, and that is exactly why
// "nothing changes" kept coming back. So: the five switches write Prefs keys
// that Rooms.qml and Station.qml read on the next binding evaluation, and
// everything that belongs to the MAP FILE — grid size, wrap, animation speed,
// a room's name, a room's wallpaper, a room's shelf — is written by
// `nyxus-house`, the single writer of ~/.config/nyxus/station.json, and read
// straight back by the same live FileView the HUD uses.
//
// THE ONE THING THIS PAGE DOES NOT OFFER is a carry-key picker. The carry key
// is a Hyprland bind; changing it means writing Hyprland config, and gate
// 16dup fails any chord bound twice and does not honour `unbind`. A picker
// here would be a control that records a value nothing acts on — the exact
// failure class above. Instead the page READS the chord out of the shard
// Hyprland actually sources and says where to change it. Refused on purpose;
// see docs/BRIEF_AGENT_ROOMS_2026-08-22.md.
//
// The grid you see here is RoomGrid.qml — the same component the HUD map
// draws, so the page and the map can never disagree about the layout.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    property var entry: null
    title: qsTr("Rooms")
    blurb: qsTr("Walk your workspaces as a grid — up, down and side to side.")

    readonly property bool roomsOn: SettingsStore.boolValue("station_enabled", true)
    readonly property bool plateOn: SettingsStore.boolValue("station_plate", true)
    readonly property string mapMode: SettingsStore.stringValue("station_map", "auto")
    readonly property string mapCorner: SettingsStore.stringValue("station_map_corner", "bottom-right")
    readonly property int mapFade: SettingsStore.numberValue("station_map_fade", 2200)

    // the rooms, in reading order, straight off the live map
    readonly property var roomList: {
        var out = [];
        for (var r = 0; r < Rooms.rows; ++r)
            for (var c = 0; c < Rooms.cols; ++c) {
                var n = Rooms.roomAt(r, c);
                if (n !== "") out.push(n);
            }
        return out;
    }
    property string pick: ""
    readonly property string room: (pick !== "" && roomList.indexOf(pick) >= 0)
                                   ? pick : (roomList.length ? roomList[0] : "")
    readonly property var shelf: room !== "" ? Rooms.shelfOf(room) : []
    readonly property string roomWall: room !== "" ? Rooms.wallpaperOf(room) : ""
    readonly property int gridSize: Rooms.cols === Rooms.rows ? Rooms.cols : 0
    readonly property int animMs: {
        var parts = String(Rooms.animFor("horizontal")).split(",");
        var ds = parts.length > 2 ? parseInt(parts[2], 10) : 2;
        return (isNaN(ds) ? 2 : ds) * 100;
    }

    // ── the single writer ────────────────────────────────────────────────
    property string lastResult: ""
    Process {
        id: houseProc
        running: false
        stdout: StdioCollector { onStreamFinished: page.lastResult = this.text.trim() }
        stderr: StdioCollector { onStreamFinished: if (this.text.trim() !== "") page.lastResult = this.text.trim() }
        onExited: function (code) {
            if (code !== 0 && page.lastResult === "") page.lastResult = qsTr("nyxus-house exited %1").arg(code);
            Rooms.reloadMap();
        }
    }
    function house(args) {
        // TRK-3435 RULING: this line used to put `~/.local/bin` FIRST on
        // purpose (the preview session's dev copy of nyxus-house). That is
        // the exact shape of the TRK-3367 trap — a stale preview copy
        // silently shadowing the shipped tool — so it is normalized to the
        // batch's shipped-first rule, argv through `env` and never a shell
        // (a room name is text a person typed). A dev session that wants
        // its checkout copy says so explicitly with NYXUS_BIN_DIR; nothing
        // prefers a shadow by default any more.
        var cmd = ["env", "PATH="
                   + (Quickshell.env("NYXUS_BIN_DIR") || "/usr/local/bin")
                   + ":" + Quickshell.env("PATH"), "nyxus-house"];
        houseProc.command = cmd.concat(args);
        page.lastResult = "";
        houseProc.running = true;
    }

    // ── the keys, read from the shard Hyprland actually sources ─────────
    readonly property string shardPath: Quickshell.env("HOME") + "/.config/hypr/conf.d/nyxus-station.conf"
    property var keyRows: []
    function chordOf(mods, key) {
        var m = mods.replace("$mod", "SUPER").trim().split(/\s+/).filter(function (s) { return s !== ""; });
        var k = key.trim();
        var arrows = { left: "←", right: "→", up: "↑", down: "↓" };
        if (arrows[k.toLowerCase()] !== undefined) k = arrows[k.toLowerCase()];
        else if (k.length === 1) k = k.toUpperCase();
        return (m.length ? m.join("+") + "+" : "") + k;
    }
    function parseShard(t) {
        var out = [], lines = t.split("\n");
        for (var i = 0; i < lines.length; ++i) {
            var ln = lines[i];
            if (/^\s*#/.test(ln)) continue;
            var m = ln.match(/^\s*bind[a-z]*\s*=\s*([^,]*),([^,]+),\s*exec\s*,(.*)$/);
            if (!m) continue;
            var cmd = m[3], what = "";
            var w = cmd.match(/house walk (\w+)/);
            if (w) what = qsTr("walk %1").arg(w[1]);
            else if (/nyxus-house carry/.test(cmd)) what = qsTr("carry — grab / drop the focused window");
            else if (/house map/.test(cmd)) what = qsTr("pin / unpin the map");
            else if (/house shelf|nyxus-house shelf/.test(cmd)) what = qsTr("launch the first item on this room's shelf");
            else what = cmd.trim();
            out.push({ chord: page.chordOf(m[1], m[2]), what: what });
        }
        return out;
    }
    readonly property string carryChord: {
        for (var i = 0; i < keyRows.length; ++i)
            if (String(keyRows[i].what).indexOf("carry") === 0) return keyRows[i].chord;
        return "";
    }
    FileView {
        id: shardFile
        path: page.shardPath
        watchChanges: true
        onFileChanged: reload()
        onLoaded: page.keyRows = page.parseShard(text())
        onLoadFailed: page.keyRows = []
    }

    // ═════════════════════════════════════════════════════════════════════
    SetCard {
        heading: qsTr("Rooms")
        tone: page.tone
        note: qsTr("Your workspaces laid out as a grid you walk through: HOME in the middle, every room at most two moves away. The bottom bar never moves, and the wallpaper stays put — you move, the world does not. Off leaves SUPER+1..9 and every other key exactly as they are.")

        SetIceFace {
            kicker: qsTr("WALKING")
            reading: page.roomsOn ? qsTr("ON") : qsTr("OFF")
            caption: page.roomsOn ? qsTr("The arrows walk the grid; the map and the carry key answer")
                                  : qsTr("The keys do nothing and no surface is built at all")
            selected: page.roomsOn
            interactive: true
            onActivated: SettingsStore.setValue("station_enabled", !page.roomsOn)
        }
        SetIceFace {
            kicker: qsTr("ROOM NAME ON ARRIVAL")
            reading: page.plateOn ? qsTr("ON") : qsTr("OFF")
            caption: page.plateOn ? qsTr("The room's name, once, as you arrive — then gone")
                                  : qsTr("Silent arrivals")
            selected: page.plateOn
            interactive: true
            onActivated: SettingsStore.setValue("station_plate", !page.plateOn)
        }
        SetIceFace {
            visible: Rooms.degraded
            kicker: qsTr("MAP FILE")
            reading: qsTr("DEFAULT")
            caption: Rooms.note
        }
    }

    SetCard {
        heading: qsTr("The grid")
        tone: page.tone
        note: qsTr("A room's workspace is fixed by ws = row × cols + col + 1, so the 3×3 grid is workspaces 1–9 and SUPER+1..9 land you exactly where the map says. HOME is always the centre cell. Editing %1 by hand works too — the map and this page re-read it as you save.").arg(Rooms.mapPath)

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: preview.implicitHeight + 2 * Theme.s5
            RoomGrid {
                id: preview
                anchors.centerIn: parent
                cellW: 84
                cellH: 48
                showCarry: false
                // the page's preview is a picture of the layout, not a second
                // way to move: clicking a cell selects it for the editor below
                interactive: true
                focusWs: page.room !== "" ? Rooms.wsOfRoom(page.room) : 0
                onJump: function (ws) { page.pick = Rooms.roomOfWs(ws); }
            }
        }

        SetChoice {
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            key: ""
            defaultValue: 3
            value: page.gridSize
            options: [
                { label: qsTr("2 × 2"), value: 2 },
                { label: qsTr("3 × 3"), value: 3 },
                { label: qsTr("4 × 4"), value: 4 }
            ]
            tone: page.tone
            onChosen: function (v) { page.house(["resize", String(v), String(v)]); }
        }
        SetIceFace {
            kicker: qsTr("GRID")
            reading: Rooms.cols + " × " + Rooms.rows
            caption: qsTr("%1 rooms on workspaces 1–%2; HOME is workspace %3")
                     .arg(Rooms.cols * Rooms.rows).arg(Rooms.cols * Rooms.rows).arg(Rooms.homeWs)
        }
        SetIceFace {
            kicker: qsTr("EDGES")
            reading: Rooms.wrap ? qsTr("WRAP") : qsTr("STOP")
            caption: Rooms.wrap ? qsTr("Walking off an edge comes round the other side")
                                : qsTr("Walking off an edge does nothing, so the edges stay findable")
            selected: Rooms.wrap
            interactive: true
            onActivated: page.house(["wrap", Rooms.wrap ? "off" : "on"])
        }
        SetChoice {
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            key: ""
            defaultValue: 200
            value: page.animMs
            options: [
                { label: qsTr("Quick · 120 ms"), value: 120 },
                { label: qsTr("Default · 200 ms"), value: 200 },
                { label: qsTr("Easy · 300 ms"), value: 300 },
                { label: qsTr("Slow · 450 ms"), value: 450 }
            ]
            tone: page.tone
            onChosen: function (v) { page.house(["speed", String(v)]); }
        }
        SetIceFace {
            kicker: qsTr("SWITCH")
            reading: page.animMs + " ms"
            caption: qsTr("Side to side slides sideways, up and down slides vertically — the motion always matches the way you travelled.")
        }
    }

    SetCard {
        heading: qsTr("The map")
        tone: page.tone
        note: qsTr("A small card in a corner that shows the grid, the room you are in, and which rooms hold windows. It is a place-marker, not a control panel — but clicking a room does go there.")

        SetChoice {
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            key: "station_map"
            defaultValue: "auto"
            options: [
                { label: qsTr("Off"), value: "off" },
                { label: qsTr("Auto-fade"), value: "auto" },
                { label: qsTr("Always on"), value: "pinned" }
            ]
            tone: page.tone
        }
        SetChoice {
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            key: "station_map_corner"
            defaultValue: "bottom-right"
            options: [
                { label: qsTr("Bottom right"), value: "bottom-right" },
                { label: qsTr("Bottom left"), value: "bottom-left" },
                { label: qsTr("Top right"), value: "top-right" },
                { label: qsTr("Top left"), value: "top-left" }
            ]
            tone: page.tone
        }
        SetChoice {
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            key: "station_map_fade"
            defaultValue: 2200
            options: [
                { label: qsTr("1.2 s"), value: 1200 },
                { label: qsTr("2.2 s"), value: 2200 },
                { label: qsTr("3.5 s"), value: 3500 },
                { label: qsTr("5 s"), value: 5000 }
            ]
            tone: page.tone
        }
        SetIceFace {
            kicker: qsTr("HOW IT BEHAVES")
            reading: page.mapMode === "off" ? qsTr("OFF") : page.mapMode === "pinned" ? qsTr("PINNED") : qsTr("AUTO")
            caption: page.mapMode === "off" ? qsTr("Never shown")
                   : page.mapMode === "pinned" ? qsTr("Always up, %1").arg(page.mapCorner)
                   : qsTr("Appears as you move, %1, and fades %2 s after you stop")
                     .arg(page.mapCorner).arg((page.mapFade / 1000).toFixed(1))
        }
    }

    SetCard {
        heading: qsTr("Keys")
        tone: page.tone
        note: qsTr("Read from %1. These are Hyprland binds: a switch here cannot move them without leaving a second copy of the chord behind (gate 16dup), so this page shows the real thing instead of a picker that would not take. Edit that file — both repo copies — to move them.").arg(page.shardPath)

        SetIceFace {
            kicker: qsTr("CARRY")
            reading: page.carryChord !== "" ? page.carryChord : qsTr("NOT INSTALLED")
            caption: page.carryChord !== ""
                     ? qsTr("Press it with a window focused to pick it up; it travels with you until you press it again. Nothing focused does nothing.")
                     : qsTr("The Rooms shard is not in this HOME, so no walking or carry key is installed here")
        }
        Repeater {
            model: page.keyRows
            SetIceFace {
                required property var modelData
                compact: true
                kicker: modelData.chord
                reading: ""
                caption: modelData.what
            }
        }
    }

    SetCard {
        heading: qsTr("Rooms and their shelves")
        tone: page.tone
        note: qsTr("Pick a room, give it a name, a wallpaper of its own if you want one, and pin the apps and folders that belong in it. Launching from a shelf opens the app IN that room, wherever you are standing.")

        SetChoice {
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            key: ""
            defaultValue: page.room
            value: page.room
            options: page.roomList
            segmentLimit: 0
            tone: page.tone
            onChosen: function (v) { page.pick = String(v); }
        }

        // ── the room's caption ──
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            spacing: Theme.s3
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                // TRK-3429 (all four wells): radius 16 was off the r-ladder
                // (r1 8 / r2 14 / r3 22), and the focus border rode tealGlow,
                // which the 08-19 ruling reserves for the TRK-3060 sheen mix
                // — focus is glacier[0].
                radius: Theme.r2
                color: Theme.soften(Theme.void_, 0.35)
                border.width: nameIn.activeFocus ? 2 : 1
                border.color: nameIn.activeFocus ? Theme.paintLayers.glacier[0] : Theme.lookSeam
                TextInput {
                    id: nameIn
                    anchors.fill: parent
                    anchors.margins: Theme.s3
                    color: Theme.text
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tLabel
                    verticalAlignment: TextInput.AlignVCenter
                    renderType: Text.NativeRendering
                    Text {
                        visible: nameIn.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("a name for %1 (now: %2)").arg(page.room).arg(Rooms.labelOf(page.room))
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tLabel
                        renderType: Text.NativeRendering
                    }
                }
            }
            SetButton {
                text: qsTr("Rename")
                tone: page.tone
                busy: houseProc.running
                onClicked: if (nameIn.text !== "") { page.house(["rename", page.room, nameIn.text]); nameIn.text = ""; }
            }
        }

        // ── the room's wallpaper ──
        SetIceFace {
            kicker: qsTr("WALLPAPER")
            reading: page.roomWall !== "" ? qsTr("OWN") : qsTr("MAIN")
            caption: page.roomWall !== ""
                     ? page.roomWall
                     : qsTr("This room shows the main wallpaper, like every other room. Give one room its own and the main one comes back the moment you leave it.")
            selected: page.roomWall !== ""
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            spacing: Theme.s3
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: Theme.r2
                color: Theme.soften(Theme.void_, 0.35)
                border.width: wallIn.activeFocus ? 2 : 1
                border.color: wallIn.activeFocus ? Theme.paintLayers.glacier[0] : Theme.lookSeam
                TextInput {
                    id: wallIn
                    anchors.fill: parent
                    anchors.margins: Theme.s3
                    color: Theme.text
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tLabel
                    verticalAlignment: TextInput.AlignVCenter
                    renderType: Text.NativeRendering
                    Text {
                        visible: wallIn.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("path to an image for %1").arg(page.room)
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tLabel
                        renderType: Text.NativeRendering
                    }
                }
            }
            SetButton {
                text: qsTr("Use it")
                tone: page.tone
                busy: houseProc.running
                onClicked: if (wallIn.text !== "") { page.house(["wallpaper", page.room, wallIn.text]); wallIn.text = ""; }
            }
            // ── TRK-2935 · "BACK TO MAIN" DISCARDS A CHOICE ─────────────
            // `house wallpaper <room> --clear` throws away the wallpaper the
            // user picked for this room and cannot put it back — the path
            // they typed is gone with it, and it sits directly beside "Use
            // it", the button that SET that path. A per-page Reset is the
            // shape `SetButton`'s header already calls destructive. Both
            // buttons painted identically before this.
            //
            // Armed, unlike the two flyout links: there is no undo, this is
            // a full-width settings button with room for a confirm label,
            // and it is the mis-click neighbour of the save button.
            SetButton {
                text: qsTr("Back to main")
                tone: page.tone
                danger: true
                confirmText: qsTr("Clear the %1 wallpaper").arg(page.room)
                onClicked: page.house(["wallpaper", page.room, "--clear"])
            }
        }

        // ── the shelf ──
        Repeater {
            model: page.shelf
            RowLayout {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.leftMargin: Theme.s4
                Layout.rightMargin: Theme.s4
                spacing: Theme.s3
                SetIceFace {
                    Layout.fillWidth: true
                    Layout.leftMargin: 0
                    Layout.rightMargin: 0
                    compact: true
                    kicker: String(parent.modelData.label || "")
                    reading: ""
                    caption: String(parent.modelData.folder || parent.modelData.desktop || parent.modelData.exec || "")
                }
                SetButton {
                    text: qsTr("Open here")
                    tone: page.tone
                    onClicked: Rooms.launchShelf(page.room, parent.index + 1)
                }
                SetButton {
                    text: qsTr("Unpin")
                    tone: page.tone
                    confirmText: qsTr("Click again to unpin")
                    onClicked: page.house(["shelf-del", page.room, String(parent.index + 1)])
                }
            }
        }
        SetIceFace {
            visible: page.shelf.length === 0
            kicker: qsTr("EMPTY SHELF")
            caption: qsTr("Nothing is pinned to %1 yet").arg(page.room)
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            spacing: Theme.s3
            Rectangle {
                Layout.preferredWidth: 130
                Layout.preferredHeight: 32
                radius: Theme.r2
                color: Theme.soften(Theme.void_, 0.35)
                border.width: labelIn.activeFocus ? 2 : 1
                border.color: labelIn.activeFocus ? Theme.paintLayers.glacier[0] : Theme.lookSeam
                TextInput {
                    id: labelIn
                    anchors.fill: parent
                    anchors.margins: Theme.s3
                    color: Theme.text
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tLabel
                    verticalAlignment: TextInput.AlignVCenter
                    renderType: Text.NativeRendering
                    Text {
                        visible: labelIn.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("label")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tLabel
                        renderType: Text.NativeRendering
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                radius: Theme.r2
                color: Theme.soften(Theme.void_, 0.35)
                border.width: whatIn.activeFocus ? 2 : 1
                border.color: whatIn.activeFocus ? Theme.paintLayers.glacier[0] : Theme.lookSeam
                TextInput {
                    id: whatIn
                    anchors.fill: parent
                    anchors.margins: Theme.s3
                    color: Theme.text
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tLabel
                    verticalAlignment: TextInput.AlignVCenter
                    renderType: Text.NativeRendering
                    Text {
                        visible: whatIn.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("a command, a folder such as ~/Documents, or an app id ending .desktop")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tLabel
                        elide: Text.ElideRight
                        width: parent.width
                        renderType: Text.NativeRendering
                    }
                }
            }
            SetButton {
                text: qsTr("Pin it")
                tone: page.tone
                busy: houseProc.running
                onClicked: {
                    if (labelIn.text === "" || whatIn.text === "") return;
                    var what = whatIn.text.trim();
                    var kind = /\.desktop$/.test(what) ? "desktop"
                             : (what.charAt(0) === "/" || what.charAt(0) === "~") ? "folder" : "exec";
                    var item = { label: labelIn.text };
                    item[kind] = what;
                    page.house(["shelf-add", page.room, JSON.stringify(item)]);
                    labelIn.text = "";
                    whatIn.text = "";
                }
            }
        }

        SetIceFace {
            visible: page.lastResult !== ""
            kicker: qsTr("NYXUS-HOUSE")
            caption: page.lastResult
        }
    }

    // ── audit-0908 · TRK-3970 ───────────────────────────────────────────
    // The five keys this page writes. The ROOMS are not among them and must
    // not be: the shelf lives in nyxus-house's own JSON and is edited through
    // `page.house(...)`, so a settings reset that took them would silently
    // delete the owner's rooms — a reset row clears settings, never data.
    // What this clears is how the map is shown.
    SetResetRow {
        what: qsTr("Rooms")
        keys: ["station_enabled", "station_plate", "station_map",
               "station_map_corner", "station_map_fade"]
    }
}
