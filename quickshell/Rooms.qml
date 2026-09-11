pragma Singleton
// Nyxus Suxyn — THE ROOMS: the one source of truth (TRK-1700).
//
// WHY A SINGLETON. Four things need to know which workspace a room sits on:
// the arrow keys, the map's click, the carry move and the shelf launch. Two
// implementations of that answer is how a navigation feature drifts and stops
// being trustworthy, so there is exactly ONE — `wsOf(row, col)` below — and
// every one of those four call sites goes through it. Gate 13x10 computes
// that this file contains the formula once and that no other QML file
// contains it at all.
//
//     ws = row * cols + col + 1
//
// `grid` is row-major, so the shipped 3x3 is workspaces 1..9 with HOME in the
// centre cell (ws 5): every room is at most two moves away, and SUPER+1..9
// still land you exactly where the map says.
//
// WHAT ELSE LIVES HERE
//   · the map file (~/.config/nyxus/station.json, else the shipped default),
//     live-reloaded; a missing or corrupt file falls back and SAYS so
//     (`degraded` / `note`) rather than leaving a broken desktop
//   · the INTENT model that keeps mashing an arrow key from desyncing: the
//     key updates where we intend to be immediately and the compositor is
//     driven towards it, so five fast presses land five rooms over with no
//     dropped and no doubled moves (see `walk` / `pump`)
//   · the carry state machine, with every transition enumerated at `carry()`
//   · the per-room wallpaper override (global by default: while no room
//     overrides, nothing about the wallpaper ever runs as you walk)
//
// COST WHEN OFF. Nothing constructs this file unless something references it,
// and the only references are Station.qml (built by shell.qml's LazyLoader,
// which is inactive when `station_enabled` is false) and the Settings page
// (built when you open it). The FileView's path is empty while off, so not
// even the map file is read.
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Singleton {
    id: rooms

    // ── the map file ─────────────────────────────────────────────────────
    // NYXUS_STATION_MAP overrides both, exactly as it does for nyxus-house —
    // one env var, so a check can point the shell and the script at the same
    // test map without touching anybody's HOME
    readonly property string envMap: Quickshell.env("NYXUS_STATION_MAP") || ""
    readonly property string userMap: envMap !== "" ? envMap
                                    : (Quickshell.env("HOME") + "/.config/nyxus/station.json")
    readonly property string systemMap: envMap !== "" ? envMap : "/usr/share/nyxus/station.json"
    property string mapPath: userMap
    readonly property bool enabled: Prefs.stationEnabled
    property var map: ({})
    // a map that would not parse, or that has no grid: say so out loud and
    // come up on a sane default rather than showing a broken desktop
    property bool degraded: false
    property string note: ""

    readonly property var grid: (map.grid && map.grid.length) ? map.grid : [["HOME"]]
    readonly property int rows: grid.length
    readonly property int cols: grid[0] ? grid[0].length : 1
    readonly property bool wrap: map.wrap === true
    readonly property string homeRoom: map.home || "HOME"

    // ══ THE FORMULA — the only one, in the only place ═════════════════════
    function wsOf(row, col) { return row * cols + col + 1; }
    // ══════════════════════════════════════════════════════════════════════
    function rowOf(ws) { return Math.floor((ws - 1) / cols); }
    function colOf(ws) { return (ws - 1) % cols; }
    function inGrid(ws) { return ws >= 1 && ws <= rows * cols; }
    function roomAt(row, col) {
        var r = grid[row];
        return (r && r[col]) ? r[col] : "";
    }
    function roomOfWs(ws) { return inGrid(ws) ? roomAt(rowOf(ws), colOf(ws)) : ""; }
    function wsOfRoom(name) {
        for (var r = 0; r < rows; ++r)
            for (var c = 0; c < cols; ++c)
                if (grid[r][c] === name) return wsOf(r, c);
        return 0;
    }
    function labelOf(name) {
        var l = map.labels || {};
        return l[name] ? l[name] : name;
    }
    function tint(name) {
        var key = (map.colors && map.colors[name]) ? map.colors[name] : "";
        var v = key !== "" ? Theme[key] : undefined;
        return (v !== undefined && v !== null) ? v : Theme.tealGlow;
    }
    function shelfOf(name) {
        var s = (map.shelves || {})[name];
        return (s && s.length) ? s : [];
    }
    function wallpaperOf(name) {
        var w = (map.wallpapers || {})[name];
        return (typeof w === "string" && w !== "") ? w : "";
    }
    // how many windows sit in a room. `lastIpcObject` does not stream (WIP-117),
    // so callers refresh before they show — `refresh()` is the one place that
    // asks, and nothing here polls.
    function countOf(ws) {
        var list = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        for (var i = 0; i < list.length; ++i)
            if (list[i].id === ws)
                return (list[i].lastIpcObject && list[i].lastIpcObject.windows) || 0;
        return 0;
    }
    function refresh() { Hyprland.refreshWorkspaces(); Hyprland.refreshToplevels(); }

    // the home cell — the centre by definition, wherever the room called
    // `home` actually sits (a resize always puts it back in the middle)
    readonly property int homeWs: {
        var w = wsOfRoom(homeRoom);
        return w > 0 ? w : wsOf(Math.floor(rows / 2), Math.floor(cols / 2));
    }

    // ── where we are, and where we INTEND to be ──────────────────────────
    // `focusedWs` is what the compositor reports and always lags a dispatch.
    // `intentWs` is what the person has asked for and never lags — every
    // decision below reads intent, so mashing an arrow cannot desync.
    readonly property int focusedWs: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
    property int intentWs: 0
    property int dispatchedWs: 0
    property int queuedWs: 0
    property string queuedAxis: "horizontal"
    property string lastDir: ""
    readonly property int liveWs: intentWs > 0 ? intentWs : focusedWs
    readonly property string room: roomOfWs(liveWs)
    readonly property string roomLabel: room !== "" ? labelOf(room) : ""
    readonly property bool outside: room === ""

    signal arrived(string name, string dir)
    signal bumped(string dir)

    // ── walking ──────────────────────────────────────────────────────────
    function neighbourWs(ws, dir) {
        var r, c;
        if (!inGrid(ws)) { r = rowOf(homeWs); c = colOf(homeWs); return wsOf(r, c); }
        r = rowOf(ws); c = colOf(ws);
        if (dir === "up") r -= 1;
        else if (dir === "down") r += 1;
        else if (dir === "left") c -= 1;
        else if (dir === "right") c += 1;
        if (r < 0 || r >= rows || c < 0 || c >= cols) {
            if (!wrap) return 0;
            r = ((r % rows) + rows) % rows;
            c = ((c % cols) + cols) % cols;
        }
        return wsOf(r, c);
    }
    function axisOf(dir) { return (dir === "up" || dir === "down") ? "vertical" : "horizontal"; }

    function walk(dir) {
        if (!enabled) return "off";
        syncIntent();
        var target = neighbourWs(intentWs, dir);
        if (target === 0) { bumped(dir); return "ok"; }   // an edge, and wrap is off
        lastDir = dir;
        travel(target, axisOf(dir));
        return "ok";
    }
    // the map's click and `goto` land here too — same target, same formula,
    // and the axis is derived from the cell delta so a jump across the grid
    // still slides the way you travelled instead of a generic fade
    function jumpTo(target) {
        if (!enabled || !inGrid(target)) return "off";
        syncIntent();
        if (target === intentWs) return "ok";
        var dr = rowOf(target) - rowOf(intentWs);
        var dc = colOf(target) - colOf(intentWs);
        if (!inGrid(intentWs)) { dr = 0; dc = 1; }
        lastDir = dr !== 0 ? (dr > 0 ? "down" : "up") : (dc > 0 ? "right" : "left");
        travel(target, Math.abs(dr) >= Math.abs(dc) && dr !== 0 ? "vertical" : "horizontal");
        return "ok";
    }
    function jumpRoom(name) {
        var w = wsOfRoom(name);
        return w > 0 ? jumpTo(w) : "no such room";
    }

    // intent follows the compositor whenever nothing of ours is in flight —
    // SUPER+digit, a click on the bar, another tool: all of them resync here
    function syncIntent() {
        if (intentWs === 0 || (!stepProc.running && queuedWs === 0 && focusedWs > 0 && focusedWs !== intentWs))
            intentWs = focusedWs > 0 ? focusedWs : homeWs;
    }
    function travel(target, axis) {
        intentWs = target;
        queuedWs = target;
        queuedAxis = axis;
        pump();
    }
    // ONE hyprctl at a time, always aimed at the LATEST intent. A press during
    // a switch is not swallowed — it moves the intent, and the next pump goes
    // straight there. Five fast presses = the right room, two slides, no flicker.
    function pump() {
        if (stepProc.running || queuedWs === 0 || queuedWs === dispatchedWs) return;
        var target = queuedWs;
        queuedWs = 0;
        dispatchedWs = target;
        var batch = "keyword animation " + animFor(queuedAxis);
        // the carried window goes to the destination FIRST and silently, so it
        // never paints on a room it is only passing through
        if (carrying !== "") batch += " ; dispatch movetoworkspacesilent " + target + ",address:" + carrying;
        batch += " ; dispatch workspace " + target;
        stepProc.command = ["hyprctl", "--batch", batch];
        stepProc.running = true;
    }
    function animFor(kind) {
        var a = map.animations || {};
        return a[kind] || "workspaces, 1, 2, nyx-glass, slidefade 15%";
    }
    Process {
        id: stepProc
        running: false
        onExited: {
            // cleared so a later walk BACK to this room is never mistaken for
            // a redundant dispatch and silently skipped
            rooms.dispatchedWs = 0;
            rooms.applyWallpaper();
            restoreTimer.restart();
            rooms.pump();               // whatever arrived while we were busy
        }
    }
    Process { id: restoreProc; running: false; command: ["hyprctl", "keyword", "animation", rooms.animFor("rest")] }
    // one shot, 600 ms after the last step — no timer runs while you are still
    Timer { id: restoreTimer; interval: 600; repeat: false; onTriggered: restoreProc.running = true }

    // ── carry: pick a window up, walk, put it down ───────────────────────
    // THE STATE MACHINE. Two states, and every transition is handled:
    //   idle      + SUPER+G, a window focused   -> carrying(address)
    //   idle      + SUPER+G, nothing focused    -> idle   (a note, never an error)
    //   carrying  + SUPER+G                     -> idle   (dropped where you stand)
    //   carrying  + that window closes          -> idle   (watchdog below; no stuck chip)
    //   carrying  + a move                      -> the window goes first, silently
    //   carrying  + already on the destination   -> movetoworkspacesilent is a no-op
    //   carrying  + a second grab                -> the toggle drops; grab again to pick up
    //   carrying  + the shell reloads            -> recovered from the state file, or
    //                                              cleared if the window is gone
    // The state FILE is the contract with nyxus-house (the fallback path when
    // the shell is not up), so the two can never disagree about what travels.
    readonly property string carryDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/nyxus-rooms"
    readonly property string carryFile: carryDir + "/carry"
    Process {
        running: rooms.enabled
        command: ["mkdir", "-p", rooms.carryDir]
    }
    property string carrying: ""
    property string carriedTitle: ""

    function carry() {
        if (!enabled) return "off";
        carryProc.command = ["sh", "-c",
            "export PATH=\"$HOME/.local/bin:/usr/local/bin:$PATH\"; exec nyxus-house carry"];
        carryProc.running = true;
        return "ok";
    }
    Process { id: carryProc; running: false }
    // nyxus-house is the single writer of carry state and calls this back
    function setCarry(addr) {
        if (addr === carrying) return;
        if (carrying !== "") markCarried(carrying, false);
        carrying = addr;
        carriedTitle = addr !== "" ? titleOf(addr) : "";
        if (addr !== "") markCarried(addr, true);
    }
    function titleOf(addr) {
        var list = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        for (var i = 0; i < list.length; ++i) {
            var o = list[i].lastIpcObject;
            if (o && o.address === addr) return o.title || o.class || "";
        }
        return "";
    }
    // The border treatment. A carried window wears a THICKER border in the
    // glacier tint — the thickness is the cue that survives a colour-blind
    // eye and a screenshot, and the map's carry chip carries the words. The
    // hex is computed from the Theme token, never written here.
    function markCarried(addr, on) {
        var col = String(Theme.tealGlow).replace("#", "");
        markProc.command = ["hyprctl", "--batch", on
            ? "setprop address:" + addr + " bordersize 4 ; setprop address:" + addr + " bordercolor rgb(" + col + ")"
            : "setprop address:" + addr + " bordersize unset ; setprop address:" + addr + " bordercolor unset"];
        markProc.running = true;
    }
    Process { id: markProc; running: false }
    FileView {
        // the contract with nyxus-house; also how a carry survives a reload
        id: carryView
        path: rooms.enabled ? rooms.carryFile : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: rooms.setCarry(text().trim())
        onLoadFailed: rooms.setCarry("")  // idle: no carry file yet
    }
    // the watchdog: the moment the carried window stops existing, the state
    // clears through the same single writer, so nothing is left stuck
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            rooms.syncIntent();
            if (!stepProc.running && rooms.queuedWs === 0) rooms.arrived(rooms.room, rooms.lastDir);
            rooms.lastDir = "";
        }
        function onRawEvent(event) {
            if (!rooms.enabled) return;
            var gone = String(event.data || "").trim();
            if (event.name === "closewindow" && rooms.carrying !== "" && gone !== ""
                && rooms.carrying.indexOf(gone) >= 0) {
                dropProc.command = ["sh", "-c",
                    "export PATH=\"$HOME/.local/bin:/usr/local/bin:$PATH\"; exec nyxus-house carry --drop"];
                dropProc.running = true;
            }
        }
    }
    Process { id: dropProc; running: false }

    // ── wallpaper: global unless a room says otherwise ───────────────────
    // While `wallpapers` is empty — the shipped state — `anyOverride` is false
    // and not one process ever runs on a room change. That is the zero-config
    // path, and it is why walking does not touch the wallpaper by default.
    readonly property bool anyOverride: {
        var w = map.wallpapers || {};
        for (var k in w) if (k.charAt(0) !== "_" && typeof w[k] === "string" && w[k] !== "") return true;
        return false;
    }
    function applyWallpaper() {
        if (!anyOverride) return;
        wallProc.command = ["sh", "-c",
            "export PATH=\"$HOME/.local/bin:/usr/local/bin:$PATH\"; exec nyxus-house wallsync"];
        wallProc.running = true;
    }
    Process { id: wallProc; running: false }

    // ── the shelf ────────────────────────────────────────────────────────
    // One launcher, and it is the one the build already has: nyxus-house
    // resolves a .desktop through `gio launch` exactly as
    // nyxus-context-menu.sh does, and opens it IN the room by workspace id —
    // through wsOf(), the same formula the keys use.
    function launchShelf(name, n) {
        if (!enabled) return "off";
        if (wsOfRoom(name) === 0) return "no such room";
        shelfProc.command = ["sh", "-c",
            "export PATH=\"$HOME/.local/bin:/usr/local/bin:$PATH\"; exec nyxus-house shelf \"$1\" \"$2\"",
            "rooms", name, String(n)];
        shelfProc.running = true;
        return "ok";
    }
    Process { id: shelfProc; running: false }

    // ── the map file, live ───────────────────────────────────────────────
    FileView {
        id: mapFile
        path: rooms.enabled ? rooms.mapPath : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                var m = JSON.parse(text());
                if (!m.grid || !m.grid.length || !m.grid[0].length) throw new Error("no grid");
                rooms.map = m;
                rooms.degraded = false;
                rooms.note = "";
            } catch (e) {
                rooms.map = {};
                rooms.degraded = true;
                rooms.note = qsTr("station.json could not be read (%1) — showing a single HOME room until it is fixed").arg(String(e));
                console.warn("Rooms: station.json:", e);
            }
        }
        onLoadFailed: {
            if (rooms.mapPath !== rooms.systemMap) {
                rooms.mapPath = rooms.systemMap;          // your copy is missing: the shipped default
            } else {
                rooms.map = {};
                rooms.degraded = true;
                rooms.note = qsTr("no station.json on this system — showing a single HOME room");
            }
        }
    }
    function reloadMap() {
        if (mapPath !== userMap) mapPath = userMap;
        else mapFile.reload();
    }
}
