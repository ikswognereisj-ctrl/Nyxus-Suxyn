// Nyxus Suxyn — the context menu's state, and nothing else.
//
// WHY THIS IS SEPARATE FROM ContextMenu.qml.
//
// The surface has to live somewhere in the scene graph; the *request* to open
// a menu comes from anywhere — the bar, the launcher, an app. A singleton for
// the state means a caller writes `Menu.openAt(x, y, items)` and never needs a
// reference to the surface, an id path, or a parent chain.
//
// It is deliberately NOT folded into Bus.qml, which is where every other
// cross-surface signal in this shell lives, for one practical reason: Bus is
// touched by nearly every piece of shell work, and a menu is a self-contained
// subsystem with its own vocabulary. Keeping it here means the two never
// collide in a merge, and Bus stays a list of toggles rather than growing an
// entry-model schema.
//
// ── THE ENTRY MODEL ───────────────────────────────────────────────────────
//
// An entry is a plain JS object. No component, no delegate, no type — because
// the callers are a QML bar, and (later) a shell script through IPC, and the
// only thing both can produce is data.
//
//   { label: "Copy",  glyph: "", action: function () { ... } }
//   { label: "Mute",  check: true,     action: ... }   // shows a tick
//   { separator: true }
//   { label: "Output device", items: [ ...more entries... ] }  // submenu
//   { label: "Delete", danger: true,   action: ... }   // magma, destructive
//   { label: "Paste",  enabled: false }                // shown, not clickable
//
// `enabled: false` is a first-class case on purpose. A context menu that hides
// what you cannot do right now teaches nothing; one that greys it out tells
// you the action exists and that this is the wrong moment. Paste with an empty
// clipboard is the canonical example.
pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    // ── what is open ─────────────────────────────────────────────────
    property bool open: false
    property var items: []
    // Where the click happened, in screen coordinates. The surface clamps.
    property real anchorX: 0
    property real anchorY: 0
    // Which screen the click was on. A menu opening on the wrong monitor is
    // the classic multi-head bug, and it cannot be fixed after the fact
    // because the surface has already been laid out.
    property var anchorScreen: null

    // A label for the menu as a whole. Not decoration: it is what tells the
    // user WHICH thing they right-clicked, which is the entire premise —
    // "Clock" over the clock menu, a filename over a file menu.
    property string title: ""

    // Bumped on every open. The surface binds to it so that opening a second
    // menu while one is up is a fresh layout rather than a mutation of the
    // old one — the same nonce device Frame.qml uses, and for the same reason:
    // a counter a component binds to cannot fire into nothing.
    property int nonce: 0

    // ── the API ──────────────────────────────────────────────────────
    function openAt(x, y, entries, screen, label) {
        if (!entries || entries.length === 0)
            return;
        root.items = entries;
        root.anchorX = x;
        root.anchorY = y;
        root.anchorScreen = screen || null;
        root.title = label || "";
        root.nonce = root.nonce + 1;
        root.open = true;
    }

    function close() {
        root.open = false;
        // The items are NOT cleared here. The close animation is still running
        // and a delegate mid-fade that suddenly has no model prints binding
        // errors and can flash empty. They are replaced on the next open,
        // which is the only moment it is safe.
    }

    // Convenience for the common shape: run a command and close.
    // PATH `nyxus-settings` is NYXUS Panel on this host (stars + orbs).
    // Raise QML Settings instead. ContextMenu.invoke is the live choke
    // (Bar menus go there); this covers the same argv if a caller uses run().
    function run(cmd) {
        var bin = (typeof cmd === "string") ? cmd : (cmd && cmd[0]);
        var s = String(bin || "");
        if (s === "@settings" || s.indexOf("nyxus-settings") !== -1
                || s.indexOf("nyxus_settings") !== -1
                || s.indexOf("io.nyxus.settings") !== -1) {
            var key = (typeof cmd === "string" || !cmd || cmd.length < 2)
                      ? "" : String(cmd[1]);
            Bus.openSettings(key);
            root.close();
            return;
        }
        Quickshell.execDetached(cmd);
        root.close();
    }
}
