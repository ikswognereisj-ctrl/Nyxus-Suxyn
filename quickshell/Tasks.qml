pragma Singleton
// Nyxus Suxyn — the Row's model: pinned apps merged with real open windows.
//
// The shell had no window list at all. You could launch things from the bar
// and then had no way to see what was open or switch to it without Alt+Tab —
// which is the one thing every Windows and macOS user does with the taskbar a
// hundred times a day. This is that, built on the wlr foreign-toplevel
// protocol through Quickshell's ToplevelManager, so it is real window state
// and not a guess.
//
// Shape of an entry (HORIZON §2, "the Row"):
//   key      stable id — the pin id, or the appId for an unpinned window
//   name     what the user calls it
//   icon     icon-theme name
//   exec     what to run when it is not running (empty for unpinned)
//   windows  the live Toplevel objects, in the order the compositor gave them
//   running  windows.length > 0
//   focused  one of its windows is the active toplevel
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Singleton {
    id: tasks

    // The pins. Deliberately short: five things you actually open, all of
    // which ship on the ISO. A Start menu full of dead icons is the defect
    // docs/SYSTEM_QUALITY_FINDINGS_2026-08-03.md P1 records; a taskbar full
    // of them would be worse, because the taskbar is always on screen.
    readonly property var pinned: [
        { key: "browser",  name: qsTr("Web"),      icon: "chromium",                exec: "chromium",
          match: ["chromium", "chrome", "google-chrome", "firefox"] },
        { key: "files",    name: qsTr("Files"),    icon: "nyxus-files",             exec: "nyxus-files",
          match: ["nautilus", "org.gnome.nautilus", "nemo", "thunar", "nyxus-files"] },
        { key: "terminal", name: qsTr("Terminal"), icon: "nyxus-terminal",          exec: "ghostty",
          match: ["com.mitchellh.ghostty", "ghostty", "kitty", "alacritty", "foot"] },
        // ONE player: nyxus-media (TRK-931). key is "media" so the
        // appId-substring fallback matches io.nyxus.media. Do not pin
        // audacious — Start no longer has a Music→audacious tile, and lean
        // never packaged it.
        { key: "media",    name: qsTr("Media"),    icon: "nyxus-media",             exec: "nyxus-media",
          match: ["io.nyxus.media", "nyxus-media"] },
        // QML Settings.qml is a FloatingWindow with appId `org.quickshell`.
        // PATH `nyxus-settings` is NYXUS Panel (`io.nyxus.settings`) — stars
        // + orbs, the other product. Matching that id made the pin think
        // Settings was not running, so a click EXECd the panel on top of
        // the window that was already open (owner 2026-08-19).
        { key: "settings", name: qsTr("Settings"), icon: "nyxus-settings",          exec: "@settings",
          match: ["org.quickshell"] }
        // match is exact appId only. Do NOT use the key-substring fallback
        // for this pin: p.key "settings" is inside `io.nyxus.settings`
        // (NYXUS Panel). That is what made a Settings click raise stars+orbs
        // even after exec was already `@settings`.
    ]

    readonly property var _live: ToplevelManager.toplevels
                                 ? ToplevelManager.toplevels.values : []
    readonly property var active: ToplevelManager.activeToplevel
    // Hyprland 0.55 + qs 0.3: foreign-toplevel can be empty while
    // `hyprctl clients` is not. The Row then never gains an icon when you
    // open something. Count forces _assemble to re-run as clients come and go.
    readonly property int _hyprN: (Hyprland.toplevels && Hyprland.toplevels.values)
                                  ? Hyprland.toplevels.values.length : 0

    readonly property var entries: _assemble(_live, active, tasks._hyprN)

    // lastIpcObject is stale until Hyprland.refreshToplevels() (13pu3 / Frame
    // WIP-117). Event-driven debounce, not a heartbeat: one fetch per burst.
    Timer {
        id: ipcCoalesce
        interval: 40
        repeat: false
        onTriggered: Hyprland.refreshToplevels()
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) { ipcCoalesce.restart(); }
    }
    Component.onCompleted: Hyprland.refreshToplevels()

    // Rebuilt whenever the window set or the focus changes. The list is short
    // (a desktop with 40 windows is a rare day) so a plain rebuild is cheaper
    // and far easier to reason about than an incrementally patched model.
    function _assemble(live, act, hyprN) {
        var out = [];
        var taken = {};

        for (var i = 0; i < pinned.length; i++) {
            var p = pinned[i];
            var wins = [];
            for (var j = 0; j < live.length; j++) {
                var id = (live[j].appId || "").toLowerCase();
                if (!id || taken[j]) continue;
                if (p.key === "settings") {
                    if (tasks.isQmlSettingsWindow(live[j])) {
                        wins.push(live[j]);
                        taken[j] = true;
                    }
                    continue;
                }
                if (p.match.indexOf(id) >= 0 || id.indexOf(p.key) >= 0) {
                    wins.push(live[j]);
                    taken[j] = true;
                }
            }
            out.push({
                key: p.key, name: p.name, icon: p.icon, exec: p.exec,
                windows: wins, pinned: true,
                running: wins.length > 0,
                focused: act !== null && wins.indexOf(act) >= 0
            });
        }

        // Anything open that is not pinned still gets a place. A window you
        // cannot see in the taskbar is a window you cannot get back to.
        var extra = {};
        for (var k = 0; k < live.length; k++) {
            if (taken[k]) continue;
            var aid = (live[k].appId || "window").toLowerCase();
            if (!extra[aid]) {
                var de = DesktopEntries.heuristicLookup(aid);
                extra[aid] = {
                    key: "w:" + aid,
                    name: (de && de.name) ? de.name : _titleCase(aid),
                    icon: tasks.iconForToplevel(live[k], de),
                    exec: "", windows: [], pinned: false,
                    running: true, focused: false
                };
                out.push(extra[aid]);
            }
            extra[aid].windows.push(live[k]);
            if (act === live[k]) extra[aid].focused = true;
        }

        // Hyprland 0.55: foreign-toplevel can be empty while clients exist.
        // hyprN is only a rebuild trigger; the live list is Hyprland.toplevels.
        var hypr = (Hyprland.toplevels && Hyprland.toplevels.values)
                   ? Hyprland.toplevels.values : [];
        hyprN = hypr.length;
        for (var hi = 0; hi < hypr.length; hi++) {
            var ht = hypr[hi];
            var ipc = ht.lastIpcObject || {};
            var cls = String(ipc["class"] || "").toLowerCase();
            if (!cls)
                continue;
            var wsObj = ipc.workspace;
            var wsName = (wsObj && typeof wsObj === "object")
                         ? String(wsObj.name || "") : String(wsObj || "");
            var wobj = ht.wayland ? ht.wayland : {
                appId: cls,
                title: String(ipc.title || ""),
                minimized: wsName.indexOf("special") >= 0,
                hyprAddress: ht.address,
                activate: function () {}
            };
            var pinKey = tasks.pinKeyForClass(cls);
            var target = null;
            var ei, wi, wins;
            if (pinKey) {
                for (ei = 0; ei < out.length; ei++) {
                    if (out[ei].key === pinKey) {
                        target = out[ei];
                        break;
                    }
                }
            }
            if (!target) {
                for (ei = 0; ei < out.length; ei++) {
                    if (out[ei].key === "w:" + cls) {
                        target = out[ei];
                        break;
                    }
                    wins = out[ei].windows || [];
                    for (wi = 0; wi < wins.length; wi++) {
                        if (ht.wayland && wins[wi] === ht.wayland)
                            target = out[ei];
                        if (wins[wi].hyprAddress && wins[wi].hyprAddress === ht.address)
                            target = out[ei];
                    }
                    if (target)
                        break;
                }
            }
            if (!target) {
                var de2 = DesktopEntries.heuristicLookup(cls);
                target = {
                    key: "w:" + cls,
                    name: (de2 && de2.name) ? de2.name : tasks._titleCase(cls),
                    icon: tasks.iconForToplevel(wobj, de2),
                    exec: "", windows: [], pinned: false,
                    running: true, focused: false
                };
                out.push(target);
            }
            var already = false;
            for (wi = 0; wi < target.windows.length; wi++) {
                if (target.windows[wi] === wobj)
                    already = true;
                if (ht.wayland && target.windows[wi] === ht.wayland)
                    already = true;
                if (target.windows[wi].hyprAddress
                        && target.windows[wi].hyprAddress === ht.address)
                    already = true;
            }
            if (!already)
                target.windows.push(wobj);
            target.running = target.windows.length > 0;
            if (Hyprland.activeToplevel === ht)
                target.focused = true;
        }
        return out;
    }

    function pinKeyForClass(cls) {
        cls = String(cls || "").toLowerCase();
        if (!cls)
            return "";
        for (var i = 0; i < pinned.length; i++) {
            var p = pinned[i];
            if (p.key === "settings") {
                if (cls === "org.quickshell")
                    return "settings";
                continue;
            }
            if (p.match.indexOf(cls) >= 0)
                return p.key;
            if (cls.indexOf(p.key) >= 0)
                return p.key;
        }
        return "";
    }

    // Theme files are `io.nyxus.notes.svg`. Compositor appIds are sometimes
    // just `Notes` or `nyxus-notes`. Prefer the .desktop icon, then the
    // io.nyxus.* name the ice glyphs actually ship under.
    function iconForToplevel(tl, de) {
        if (de && de.icon)
            return de.icon;
        var aid = String((tl && tl.appId) || "").toLowerCase();
        if (!aid)
            return "application-x-executable";
        if (aid.indexOf("io.nyxus.") === 0 || aid.indexOf("com.nyxus.") === 0)
            return aid;
        var tail = aid.split(".").pop();
        if (tail && tail !== aid)
            return "io.nyxus." + tail;
        return aid;
    }

    function _titleCase(s) {
        if (!s.length) return s;
        var base = s.split(".").pop().replace(/[-_]/g, " ");
        return base.charAt(0).toUpperCase() + base.slice(1);
    }

    function isQmlSettingsWindow(tl) {
        if (!tl) return false;
        var id = String(tl.appId || "").toLowerCase();
        if (id === "io.nyxus.settings")
            return false;
        if (id !== "org.quickshell")
            return false;
        var t = String(tl.title || "");
        return t === "" || t === "Settings"
            || t.indexOf("Settings — ") === 0
            || t.indexOf("Settings - ") === 0;
    }

    function isQmlSettings(entry) {
        if (!entry) return false;
        if (entry.key === "settings") return true;
        var x = String(entry.exec || "");
        if (x === "@settings" || x.indexOf("@settings") === 0)
            return true;
        // Leftover PATH names: still OPEN the QML window, never exec.
        return x.indexOf("nyxus-settings") !== -1
            || x.indexOf("nyxus_settings") !== -1
            || x.indexOf("io.nyxus.settings") !== -1;
    }

    // OPEN, never PATH `nyxus-settings`, never toggle, never minimise.
    function openQmlSettings() {
        Bus.openSettings("");
    }

    // Super+M: put the focused window away. No title-bar minimize button
    // (Hyprland has none). The window stays on the Row; click its icon to
    // raise it. Super+Shift+M is already logout — do not reuse that chord.
    //
    // Foreign-toplevel `minimized = true` is a no-op on this compositor
    // (probed 08-20: chromium stayed mapped on workspace 1). Hyprland's
    // `special:minimized` is the hide that actually works.
    function hyprForWindow(w) {
        if (!w)
            return null;
        var all = (Hyprland.toplevels && Hyprland.toplevels.values)
                  ? Hyprland.toplevels.values : [];
        var i;
        if (w.hyprAddress) {
            for (i = 0; i < all.length; i++)
                if (all[i].address === w.hyprAddress)
                    return all[i];
        }
        for (i = 0; i < all.length; i++) {
            if (all[i].wayland && all[i].wayland === w)
                return all[i];
        }
        var want = String(w.appId || "").toLowerCase();
        if (want) {
            for (i = 0; i < all.length; i++) {
                var ipc = all[i].lastIpcObject || {};
                if (String(ipc["class"] || "").toLowerCase() === want)
                    return all[i];
            }
        }
        return null;
    }

    // Quickshell's HyprlandToplevel.address carries no "0x"; Hyprland's
    // `address:` window matcher compares the literal "0x..." string.
    // Probed 08-22 on 0.55.4: "focuswindow address:55d7..." -> "No such
    // window found", "movetoworkspacesilent +0,address:55d7..." -> "ok"
    // but the window did not move. Every dispatch goes through here.
    function hyprAddr(a) {
        a = String(a || "");
        if (a && a.indexOf("0x") !== 0)
            a = "0x" + a;
        return a;
    }

    // Is this window put away on special:minimized? Live `workspace`
    // first (lastIpcObject does not stream, WIP-117), IPC snapshot second,
    // the Row's own flag last. Hyprland keeps a silently-moved window as
    // activewindow (probed 08-22), so "focused" does NOT mean "visible".
    function isMinimized(w) {
        if (!w)
            return false;
        var h = tasks.hyprForWindow(w);
        var name = "";
        if (h && h.workspace)
            name = String(h.workspace.name || "");
        if (!name && h && h.lastIpcObject && h.lastIpcObject.workspace) {
            var wo = h.lastIpcObject.workspace;
            name = (wo && typeof wo === "object") ? String(wo.name || "")
                                                   : String(wo || "");
        }
        if (name.indexOf("special:minimized") === 0)
            return true;
        return w.minimized === true;
    }

    function minimizeToplevel(w) {
        var h = tasks.hyprForWindow(w);
        var addr = tasks.hyprAddr(h ? h.address
                                    : (w && w.hyprAddress ? w.hyprAddress : ""));
        if (addr)
            Hyprland.dispatch("movetoworkspacesilent special:minimized,address:" + addr);
        if (w && w.minimized !== undefined)
            w.minimized = true;
    }

    function raiseToplevel(w) {
        if (!w)
            return;
        if (w.minimized !== undefined)
            w.minimized = false;
        var h = tasks.hyprForWindow(w);
        var addr = tasks.hyprAddr((h && h.address) ? h.address
                                                   : String(w.hyprAddress || ""));
        if (addr) {
            Hyprland.dispatch("movetoworkspacesilent +0,address:" + addr);
            Hyprland.dispatch("focuswindow address:" + addr);
        }
        if (typeof w.activate === "function")
            w.activate();
    }

    // Super+M. Never dispatch without address: — that is a no-op when the
    // focused client is mapped but visible:0 under layers (TRK-972).
    // hyprctl activewindow is the same source that worked on tty1.
    Process {
        id: minActiveProc
        running: false
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            id: minActiveOut
            onStreamFinished: tasks._minimizeByAddress(minActiveOut.text)
        }
    }

    function _minimizeByAddress(raw) {
        var addr = "";
        try {
            var j = JSON.parse(String(raw || ""));
            addr = String(j.address || "");
        } catch (e) {
            addr = "";
        }
        if (!addr) {
            var h = Hyprland.activeToplevel;
            addr = h ? String(h.address || "") : "";
        }
        if (!addr) {
            var all = (Hyprland.toplevels && Hyprland.toplevels.values)
                      ? Hyprland.toplevels.values : [];
            var bestId = 1e9;
            var i, ipc, fid;
            for (i = 0; i < all.length; i++) {
                ipc = all[i].lastIpcObject || {};
                fid = ipc.focusHistoryID;
                if (typeof fid !== "number")
                    continue;
                if (fid < bestId) {
                    bestId = fid;
                    addr = String(all[i].address || "");
                }
            }
        }
        addr = tasks.hyprAddr(addr);
        if (addr)
            Hyprland.dispatch("movetoworkspacesilent special:minimized,address:" + addr);
        if (tasks.active && tasks.active.minimized !== undefined)
            tasks.active.minimized = true;
    }

    function minimizeActive() {
        minActiveProc.running = false;
        minActiveProc.running = true;
    }

    // One click, the three behaviours everybody already expects:
    //   not running        → launch it
    //   running, not yours → bring it to you
    //   running and yours  → put it away (or step to its next window)
    function activate(entry) {
        if (isQmlSettings(entry)) {
            openQmlSettings();
            if (entry.running && entry.windows && entry.windows.length) {
                var w = entry.windows[0];
                for (var n = 0; n < entry.windows.length; n++)
                    if (!entry.windows[n].minimized) { w = entry.windows[n]; break; }
                tasks.raiseToplevel(w);
            }
            return;
        }
        if (!entry.running) {
            if (entry.exec) Quickshell.execDetached(["sh", "-c", entry.exec]);
            return;
        }
        if (entry.focused) {
            if (entry.windows.length > 1) {
                var i = entry.windows.indexOf(active);
                tasks.raiseToplevel(entry.windows[(i + 1) % entry.windows.length]);
            } else if (tasks.isMinimized(entry.windows[0])) {
                // Super+M left it focused-but-hidden: the click must
                // bring it back, not put it away a second time.
                tasks.raiseToplevel(entry.windows[0]);
            } else {
                tasks.minimizeToplevel(entry.windows[0]);
            }
            return;
        }
        var w = entry.windows[0];
        for (var n = 0; n < entry.windows.length; n++)
            if (!entry.windows[n].minimized) { w = entry.windows[n]; break; }
        tasks.raiseToplevel(w);
    }

    // Middle-click: a new window, even when the app is already running. Both
    // Windows and macOS do this and people reach for it; it is also the only
    // safe extra action for a taskbar button, because nothing is destroyed.
    function launchNew(entry) {
        if (isQmlSettings(entry)) {
            openQmlSettings();
            return;
        }
        if (entry.exec)
            Quickshell.execDetached(["sh", "-c", entry.exec]);
    }

    // What the Row shows under the pointer: the window's own title when there
    // is one, the app's name otherwise.
    function labelFor(entry) {
        if (entry.focused && active && active.title) return active.title;
        if (entry.windows.length === 1 && entry.windows[0].title)
            return entry.windows[0].title;
        if (entry.windows.length > 1)
            return entry.name + " · " + entry.windows.length + " windows";
        return entry.name;
    }
}
