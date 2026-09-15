// Nyxus Suxyn — MASTER SETTINGS. The control center, in the shell's own glass.
//
// ══ what this is, and what it is not ═══════════════════════════════════════
// This is THE Settings: one FloatingWindow, one catalog, one control kit.
// LEVEL 1 is still the hub (six directory tiles). LEVEL 2/3 is a three-pane
// hardware diagnostic calibration rack — node tree, live SetPage loader,
// diagnostic bus — not a second Settings app and not GTK nyxus-settings.
// SetPagePending.qml is a last-resort fallback for a catalog gap, not a
// dump door.
//
// ══ the shape ══════════════════════════════════════════════════════════════
//   LEVEL 1  HOME       category hub, filling the window.
//   LEVEL 2/3 RACK      25% schematic node tree (catalog pages) ·
//                       45% control kit (existing SetPage Loader) ·
//                       30% live diagnostic bus (DiagnosticBus).
//
// Levels 2 and 3 share one window. Picking a category selects its first
// page; picking a node swaps the Loader. There is no third window.
//
// ══ leftover GTK nyxus_settings.py ═════════════════════════════════════════
// Letter C. Same settings.json keys, same deep-link ids. It is not launched
// from this window. PATH `nyxus-settings` on this host is NYXUS Panel.
//
// ══ a real window, not a flyout ════════════════════════════════════════════
// `FloatingWindow`, not `PanelWindow`. HORIZON's "transient surfaces rise out
// of the Line" is about transient surfaces; a control center is an application
// you leave open on one monitor while you change something and watch another.
// It must be movable, resizable, and present in the taskbar — which a
// layer-shell surface is none of.
//
// ══ writing ════════════════════════════════════════════════════════════════
// Everything saves through `SettingsStore`, which does a whole-document
// read-modify-write. That is what makes a second writer on `settings.json`
// safe; `Prefs.qml`'s single-writer warning is about schema-shaped writes, and
// this is not one. Read that file's header before adding a writer anywhere.
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

FloatingWindow {
    id: win

    // ── window ──────────────────────────────────────────────────────────
    title: win.currentPage ? qsTr("Settings — ") + win.currentPage.title : qsTr("Settings")
    visible: Bus.settingsOpen
    // Opaque void, not transparent: a see-through window on tty1 is the
    // voyage sky (stars + planet) and reads as "Settings opened a wallpaper".
    color: Theme.void_

    // 1366×768 is the viewport the settings design contract names. Default
    // used to be 1080×700; that left a 766 px control column after the 250 px
    // rail and SetPage's own 32 px gutters, so rows stretched across the
    // window. 960×640 still clears the taskbar; pageMax keeps the page column
    // from growing with the window on an ultrawide. The HUB does grow with it:
    // it is a 1fr grid, not a fixed block (TRK-2301).
    // TRK-3215. The three-mockup rebuild asks for a MULTI-COLUMN card grid,
    // a category rail with labels, and a status strip — none of which fit the
    // old 960x640. 1180x760 is the smallest size at which SetPage's grid takes
    // two 480-wide cards (SetCard.implicitWidth) inside pageMax with the rail
    // and the frame still paid for: 236 rail + 2x20 frame + 2x480 + 16 gap
    // = 1212 at the cap, 1180 at the default with the cards sharing 1040.
    // minimumSize stays clear of the taskbar and is the width at which the
    // grid drops to one column rather than crushing two.
    implicitWidth: 1280
    implicitHeight: 760
    minimumSize: Qt.size(960, 600)

    // Readable column, not a sheet. railW matches a flyout-dense list.
    //
    // TRK-2911. pageMax was 640, and the comment here still described
    // SetPage's retired s9 gutters. At the default window that column was
    // CENTRED in what the rail leaves: 960 − 216 = 744 available, 640 taken,
    // so **52 px of nothing down each side — 104 px, 14% of the body** —
    // while every frame it touches (this window's hub, SetPage's own heading)
    // is s7 = 20. A 52 px void beside a 20 px frame is the "massive empty
    // spaces … to the sides" the brief names, and it was not a readability
    // margin: it was the remainder of a cap chosen for a wider window.
    // 704 = 744 − 2 × s7, so at 960 the page column's side gutters ARE the
    // system frame, and the cap still holds on an ultrawide. SetPage applies
    // s7 inside, so a SetRow is 704 − 40 = 664 (was 600, +10.7%). The 766 the
    // window note above rejects as rows "stretched across the window" stays
    // rejected — this is short of it by 102.
    readonly property int pageMax: 1320
    // MEASURED off `01-apps-notifications-page.png` (TRK-3225): its window is
    // 966 px wide and its rail is 255 — 26.4%. At this window's 1180 that is
    // 311, which is more rail than this build's page lists need, so the rail
    // is set at the mockup's own ROW geometry instead of its ratio: a 20 px
    // icon, a 14 px label, and the 20/16 frame either side of them, which
    // lands at 260. It was 236 and elided "Devices & network" on the rail
    // while the mockup shows every label whole.
    readonly property int railW: 260
    // Do not save this file incomplete: qs hot-reloads and `Expected token
    // '}'` at EOF takes the whole shell down.
    //
    // TRK-1803: six categories, 3 x 2. Eight 80 px tiles in a 720 column left
    // two of them (Network, Time) opening onto a SINGLE page each, and the
    // block floated in the middle of a 960x640 window.
    // TRK-2301: `homeMax` (880) and a FIXED `hubTileH` (150) are gone. Between
    // them they were the dead air -- an 880-wide, 312-tall block centred in a
    // 960x640 body leaves ~120 px above it and ~120 px below, which is what
    // `docs/proof/settings-0822/before-settings-hub.png` photographs. The
    // mockup's grid is `1fr x 1fr` and stretches; the only height left here is
    // the FLOOR below which the hub scrolls rather than crushing its own page
    // lists to nothing.
    readonly property int hubTileMinH: 160
    readonly property int hubCols: 3
    // was `/ 2` -- a literal that silently disagreed with hubCols the moment
    // either changed.
    readonly property int hubRows: Math.ceil(SettingsCatalog.categories.length / win.hubCols)

    // ── navigation state ────────────────────────────────────────────────
    // "" is LEVEL 1. A category id is levels 2 and 3.
    property string currentCategory: ""
    property string currentKey: ""
    property string query: ""

    readonly property var currentPage: win.currentKey === "" ? null
                                       : SettingsCatalog.find(win.currentKey)

    // Schematic tree: hub categories plus the reachable-but-not-browsable
    // Condition nodes, so a deep link still has a seat on the rack.
    readonly property var treeCats: {
        var a = [];
        var c = SettingsCatalog.categories;
        for (var i = 0; i < c.length; i++)
            a.push(c[i]);
        var d = SettingsCatalog.consoleCategories;
        for (var j = 0; j < d.length; j++)
            a.push(d[j]);
        return a;
    }

    // ══ THE DRAWERS (TRK-3224) ══════════════════════════════════════════
    // "" · "hub" · "notify". ONE string, and that is the whole enforcement of
    // the owner's TRK-1811 ruling — *one section at a time, the rail is the
    // switcher*. Two drawers open at once would leave 1180 px of window with
    // no page visible in it.
    //
    // Both panels used to be layer-shell surfaces on `WlrLayer.Overlay`,
    // mapped for as long as Settings was open. Owner 2026-08-28: they sat on
    // top of every window he put beside Settings and nothing closed them. An
    // Overlay surface outranks every toplevel by protocol, so that was not a
    // stacking bug — it was the wrong kind of surface. They are Items inside
    // this window now, which means the compositor treats them as part of
    // Settings and anything that can cover Settings covers them.
    property string drawer: ""
    function toggleDrawer(which) {
        win.drawer = (win.drawer === which) ? "" : which;
    }

    readonly property bool searching: win.query.trim().length > 0
    readonly property var results: win.searching
                                   ? SettingsCatalog.search(win.query) : []

    // Each category owns a position on the sweep, spread across the whole
    // range. HORIZON's rule is hue as a function of horizontal position; a
    // settings window is one place, so the axis becomes "which room you are
    // in" instead. Teal at the top of the list, plum at the bottom, always the
    // same way round — which is what lets you know where you are from the
    // colour of the page before you have read its heading.
    function toneFor(catId) {
        for (var i = 0; i < SettingsCatalog.categories.length; ++i)
            if (SettingsCatalog.categories[i].id === catId)
                return SettingsCatalog.categories.length < 2 ? 0.35
                       : i / (SettingsCatalog.categories.length - 1);
        return 0.35;
    }

    readonly property real tone: win.toneFor(win.currentCategory)
    // `tone` is still passed into pages so Set* keep their API. It does not
    // paint chrome.
    //
    // Ice chrome — Theme.paintLayers.glacier, the kit's ice ramp. Same two
    // rungs the kit uses for interactive / on (index 0 and 5); mid (4) is
    // the 1 px seam, never a fill. tokenAccent* is now glacier too
    // (owner 2026-08-19 ~20:42). Hub LAYOUT is unchanged.
    readonly property color iceInteractive: Theme.stateLayer[0]
    readonly property color icePrimary:     Theme.paintLayers.glacier[5]
    readonly property color iceHairline:    Theme.lookSeam
    readonly property color icePeak:        Theme.tokenAccentPeak
    readonly property color magmaMark:      Theme.paintLayers.magma[5]
    readonly property color glacierText:    Theme.paintLayers.glacier[5]

    // How many notifications are actually waiting. `Sys.notifications` is the
    // tracked model of the NotificationServer this shell IS; there is no
    // second source and nothing here counts anything it invented.
    readonly property int waitingCount: {
        var model = Sys.notifications;
        if (!model)
            return 0;
        if (model.values !== undefined && model.values !== null)
            return model.values.length;
        return model.length === undefined ? 0 : model.length;
    }

    // ══ REAL MACHINE FACTS — the header chip and the status strip ═══════
    // TRK-3215. Nothing on the strip is typed: `os`, `host` and `model` come
    // out of one `sh -c` the way SetPageAbout's collector does (ONE Process,
    // not five — the hyprlock lesson in HANDOFF.md), and the update stamp
    // comes off the file `nyxus-update-check` actually writes. A field that
    // the machine cannot answer is absent, never invented.
    property var machine: ({})
    function machineFact(k) {
        var v = win.machine[k];
        return (v === undefined || v === null || v === "") ? "" : String(v);
    }

    Process {
        id: machineFacts
        running: true
        command: ["sh", "-c", `
            emit() { printf '%s\t%s\n' "$1" "$2"; }
            if [ -r /etc/os-release ]; then
              . /etc/os-release 2>/dev/null
              emit os "\${PRETTY_NAME:-\$NAME}"
            fi
            emit user "$(id -un 2>/dev/null)"
            emit host "$(uname -n 2>/dev/null)"
            if command -v hostnamectl >/dev/null 2>&1; then
              emit model "$(hostnamectl --json=short 2>/dev/null \\
                            | sed -n 's/.*"HardwareModel":"\\([^"]*\\)".*/\\1/p')"
            fi
            for f in "$HOME/.face" "$HOME/.face.icon"; do
              [ -r "$f" ] && { emit avatar "$f"; break; }
            done
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                var next = {};
                var lines = String(this.text).split("\n");
                for (var i = 0; i < lines.length; ++i) {
                    var tab = lines[i].indexOf("\t");
                    if (tab <= 0)
                        continue;
                    var v = lines[i].substring(tab + 1).trim();
                    if (v !== "")
                        next[lines[i].substring(0, tab)] = v;
                }
                win.machine = next;
            }
        }
    }

    // Initials for the user chip when the account has no avatar file. Not a
    // placeholder: it is the real login name, reduced. `.charAt(0)` rather
    // than a string index — qmllint reads `s[0].toUpperCase()` as a call on
    // a missing property and fails audit item 2.
    function initialsOf(name) {
        var t = String(name || "").trim();
        if (t === "")
            return "?";
        var parts = t.split(/[\s._-]+/);
        if (parts.length >= 2 && parts[0].length > 0 && parts[1].length > 0)
            return String(parts[0].charAt(0) + parts[1].charAt(0)).toUpperCase();
        return String(t.charAt(0)).toUpperCase();
    }

    // ── navigation ──────────────────────────────────────────────────────
    // Every one of the three navigations puts an open drawer away. A page
    // loaded behind an open drawer is a page the person cannot see, and the
    // control they used looks like it did nothing.
    function goHome() {
        win.drawer = "";
        win.currentCategory = "";
        win.currentKey = "";
        win.query = "";
    }

    function openCategory(catId) {
        win.drawer = "";
        win.currentCategory = catId;
        var pages = SettingsCatalog.inCategory(catId);
        // First page in the category. TRK-2300: the console categories
        // resolve here too -- a Condition deep link lands on one.
        win.currentKey = pages.length > 0 ? pages[0].key : "";
        win.query = "";
        if (win.currentKey !== "")
            DiagnosticBus.append("open: " + win.currentKey);
    }

    // The one entry point for every deep link, from the bar's context menus to
    // the clock's "Time settings ›". Keys stay the ids the shell already used
    // (`datetime`, `dock`, `network`, `compositor`, …).
    function openKey(key) {
        if (key === "media")
            key = "app-media";
        if (key === "control" || key === "monitor")
            key = (key === "monitor") ? "app-monitor" : "app-control";
        var p = SettingsCatalog.find(key);
        if (!p) {
            // An unknown key is a caller bug, not a user error, and it must not
            // strand them on a blank window — Home is always a correct answer.
            console.warn("Settings: no page for key '" + key
                         + "' — opening Home. Valid keys are in "
                         + "SettingsCatalog.pages.");
            win.goHome();
            return;
        }
        win.drawer = "";
        win.currentCategory = p.cat;
        win.currentKey = p.key;
        win.query = "";
        DiagnosticBus.append("open: " + p.key);
    }

    // Do not assign `win.visible` here. It is bound to `Bus.settingsOpen`;
    // a write would break that binding and dismiss() would leave the window
    // mapped. Do not call `requestActivate` either — qmllint does not know
    // that member on this type (audit item 2, the 2026.08.07 class).
    // Hyprland.dispatch focuses the already-mapped window; the org.quickshell
    // float rule in nyxus-hyprland-rules.conf is what stops dwindle from
    // tiling it into a sliver (owner live ISO: every Settings button
    // appeared to do nothing).
    //
    // Mapping is this function's job, not Bus.openSettings. Callers used
    // to set settingsOpen true and then emit settingsRequested, which ran
    // the old "already open → unmap this frame" cycle on EVERY Start click.
    // USB 08-26 shell.log: `focuswindow title:^(Settings)` failed with
    // "No such window found" on every attempt. Cycle only when Hyprland
    // already has other toplevels and Settings is not one of them (the
    // TTY1 03:02 zombie flag). An empty toplevel list is unknown, not
    // "unmapped" — hyprctl from SSH also sees 0 clients while layers live.
    // Do not assign `win.visible` (breaks the binding). Do not call
    // `requestActivate` (audit item 2).
    function settingsToplevelVisible() {
        // lastIpcObject is a snapshot (WIP-117 / 13pu3). Ask Hyprland
        // again before we treat the list as live. Empty list stays
        // unknown, not "unmapped" — that is the TTY1 03:02 / SSH
        // hyprctl-sees-0-clients case, not a reason to unmap.
        Hyprland.refreshToplevels();
        var all = (Hyprland.toplevels && Hyprland.toplevels.values)
                  ? Hyprland.toplevels.values : [];
        if (!all || all.length === 0)
            return -1;
        for (var i = 0; i < all.length; i++) {
            var ipc = all[i].lastIpcObject || {};
            var title = String(all[i].title || ipc.title || "");
            if (title.indexOf("Settings") === 0)
                return 1;
        }
        return 0;
    }

    function raiseWindow() {
        var mapped = win.settingsToplevelVisible();
        if (Bus.settingsOpen && mapped === 0) {
            Bus.settingsOpen = false;
            remapSoon.restart();
            return;
        }
        if (!Bus.settingsOpen)
            Bus.settingsOpen = true;
        win.focusRetry();
    }

    Timer {
        id: remapSoon
        interval: 50
        repeat: false
        onTriggered: {
            Bus.settingsOpen = true;
            win.focusRetry();
        }
    }
    // ── audit-0908 · TRK-3964 · the dispatch that raced the compositor ──
    //
    // This was a one-shot 80 ms timer that dispatched
    // `focuswindow title:^(Settings)` and hoped. On the FIRST open the
    // toplevel is not mapped 80 ms after the request, so Hyprland answers
    // "No such window found" and the dispatch does nothing — exactly once per
    // open, reproduced deliberately on 2026-09-08 and recorded in the 08-26
    // shell.log before that. The comment above records the string as a bug
    // that was addressed; it was not. The window still ended up focused,
    // because the float/focus rule in nyxus-hyprland-rules.conf does it, so
    // the only symptom was a warning per open — but a code path that has
    // never once succeeded is not a fix, it is a spare part.
    //
    // The stopwatch is the defect. 80 ms is a guess about how fast a
    // compositor maps a window, and no constant can be right on every
    // machine: too small and it always misses, too large and every open feels
    // slow. So this now waits for the CONDITION instead of the clock — it
    // polls `settingsToplevelVisible()`, which is the same live
    // `refreshToplevels()` read `raiseWindow` already trusts, and dispatches
    // on the tick where the window actually exists.
    //
    // Bounded, because an unbounded poll on a window that never maps is a
    // timer that runs forever: FOCUS_TRIES × interval ≈ 780 ms, after which
    // it gives up SILENTLY. Silence is right — the float rule has focused the
    // window by then, and replacing a Hyprland warning with a Quickshell
    // warning would keep the noise and lose the fix.
    readonly property int focusTries: 13
    property int focusTry: 0

    function focusRetry() {
        win.focusTry = 0;
        focusSoon.restart();
    }

    Timer {
        id: focusSoon
        interval: 60
        repeat: true
        onTriggered: {
            // -1 is "cannot tell" (no toplevels reported at all — the SSH /
            // TTY1 case `settingsToplevelVisible` documents). Keep waiting on
            // it rather than dispatching into the dark or giving up early.
            if (win.settingsToplevelVisible() === 1) {
                focusSoon.stop();
                Hyprland.dispatch("focuswindow title:^(Settings)");
                return;
            }
            win.focusTry += 1;
            if (win.focusTry >= win.focusTries)
                focusSoon.stop();
        }
    }

    // The Bus carries which subject was asked for; consume it so that the next
    // plain "open Settings" does not reopen the last deep link.
    Connections {
        target: Bus
        function onSettingsRequested(key) {
            win.raiseWindow();
            if (key === "")
                win.goHome();
            else
                win.openKey(key);
        }
    }

    // Click door is `Bus.openSettings` (flyout gear, `qs ipc call nyxus
    // settings`). This handler is the stills / preview door. Verb is
    // `engage`, not `show` — `qs ipc` eats `show` (see Screensaver.qml).
    IpcHandler {
        target: "qmlsettings"
        function ready(): string { return "ready"; }
        function engage(): string {
            win.goHome();
            win.raiseWindow();
            return "home";
        }
        function at(key: string): string {
            win.openKey(key);
            win.raiseWindow();
            return key;
        }
        function dismiss(): string {
            Bus.settingsOpen = false;
            return "hidden";
        }
    }

    onVisibleChanged: {
        if (win.visible) {
            surface.forceActiveFocus();
            DiagnosticBus.append("rack: window mapped");
        } else {
            // A drawer is transient. Leaving one out across an unmap means
            // the next "open Settings" comes up showing a drawer nobody
            // asked for, over the page they deep-linked to.
            win.drawer = "";
            SettingsStore.flush();
        }
    }

    // ══ the surface ════════════════════════════════════════════════════
    Item {
        id: surface
        anchors.fill: parent

        // TRK-3050 — window onto the 09:40 lock (widgets + flyout).
        // fill panelMid + swellGround under GlassEdge + body 0.
        // WIP-259 body:1 was the mismatch vs
        // Start/flyout/widgets. The bar does not get this; this does.
        //
        // TRK-3310 — AND AN OPAQUE FLOOR UNDER ALL OF IT. `panelMid` (α 0.34)
        // under the swell (α 0.84…0.93) passes 0.66 × 0.16 ≈ 10.6% of the
        // backdrop. On a black wallpaper that shows nothing; over a terminal
        // it is what the owner photographed on 2026-08-28 — his terminal text
        // and his clock reading straight through the window. The two-layer
        // recipe is KEPT (a flat fill of the composite cannot blend, which the
        // app lane just proved on the GTK side); what is new is the
        // `Theme.elevated` Rectangle beneath it. Arithmetic in `SetSlab.qml`.
        // CutRect, not Rectangle: this floor is opaque and sits UNDER the
        // Pane, so a rounded corner here would show through a cut one. Same
        // reasoning and the same component as SetSlab.qml's floor — which is
        // the point, since this window hand-rolls that recipe.
        // ── TRK-3745 · THREE GROUNDS, NOT TWO ────────────────────────────
        // `Theme.surface`, not `Theme.elevated`. Owner, 2026-09-06: *"i dont
        // want it looking like one solid colors it needs deffition"*.
        //
        // MEASURED, on the tree rather than on a screenshot: this window body's
        // floor was `elevated` #071318 and every `SetCard`'s floor is also
        // `elevated`, so a card and the panel it sits on differed by
        // **ΔRGB (0,0,0)** — the flat-sheet defect
        // `docs/DESIGN_DEPTH_2026-09-06.md` rule 1 diagnoses, in the shared
        // material, on every one of the 38 pages at once.
        //
        // The build ships three rungs for exactly this and Settings was using
        // two of them. Now: the window is `Theme.void_` (line ~59), the page
        // body is `surface` #040b0e, a card on it is `elevated` #071318. Depth
        // is the SEQUENCE, and this is the minimum that reads.
        //
        // BEFORE / AFTER for the property the claim names (the value step
        // between a Settings card and the panel it sits on):
        //   **ΔRGB (0,0,0) → (3,8,10)**.
        //
        // Not a new colour: `Theme.surface` is a shipped rung and the two
        // layers above are untouched, so the 0.0% backdrop transmittance
        // SetSlab measures is unchanged — the floor is still opaque, it is just
        // a different rung of the same ladder.
        CutRect {
            anchors.fill: parent
            radius: Theme.r3
            color: Theme.surface
        }

        Pane {
            anchors.fill: parent
            elevation: 2
            radius: Theme.r3
            fill: Theme.panelMid

            // ABOVE the Pane, so this is the layer that would erase the cut
            // rather than merely miss it.
            CutRect {
                anchors.fill: parent
                radius: Theme.r3
                gradTop:  Theme.swellGroundTop
                gradMid:  Theme.swellGroundMid
                gradFoot: Theme.swellGroundFoot
            }

            GlassEdge {
                anchors.fill: parent
                radiusTL: Theme.r3; radiusTR: Theme.r3
                radiusBR: Theme.r3; radiusBL: Theme.r3
                body: 0
                wash: 0
                glaze: 1.0
                edging: 1.0
                bleed: 1.0
            }

            ReactiveEdge {
                radiusTL: Theme.r3; radiusTR: Theme.r3
                radiusBR: Theme.r3; radiusBL: Theme.r3
            }

            MirrorEdge {
                radiusTL: Theme.r3; radiusTR: Theme.r3
                radiusBR: Theme.r3; radiusBL: Theme.r3
                depth: 20
                strength: 1.0
            }

            Rectangle {
                anchors.fill: parent
                radius: Theme.r3
                color: "transparent"
                antialiasing: true
                border.width: 1
                border.color: Theme.soften(win.iceHairline, 0.45)
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 1
            spacing: 0

            // ══ THE HEAD ═══════════════════════════════════════════════
            // Title, breadcrumb, search, close. One strip, always present, so
            // the way back is never more than one glance away — which is most
            // of what "easy to get around in" means in the owner's sentence.
            Item {
                id: headStrip
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                // The live search dropdown hangs out of this strip and must
                // paint over the body beneath it. An Item does not clip, so
                // the only thing needed is that the head wins the z order.
                z: 10

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.s6
                    anchors.rightMargin: Theme.s5
                    spacing: Theme.s4

                    // ── the utility-hub handle ──────────────────────────
                    // The drawer's one control. Same button opens and closes
                    // it, which is what a person expects of a handle, and it
                    // reads as ON — a filled ground — while the drawer is
                    // out, because that is this build's state language.
                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        Layout.alignment: Qt.AlignVCenter
                        radius: Theme.r1
                        color: win.drawer === "hub"
                               ? Theme.soften(Theme.plumBody, 0.50)
                               : "transparent"
                        border.width: 1
                        border.color: hubHov.hovered || win.drawer === "hub"
                                      ? Theme.tokenAccentInteractive
                                      : Theme.tokenAccentHairline
                        Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                        Behavior on border.color { ColorAnimation { duration: Theme.durQuick } }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf0c9"            // bars
                            font.family: Theme.fIcon
                            font.pixelSize: Theme.tBody
                            color: win.drawer === "hub" ? Theme.text
                                 : hubHov.hovered ? Theme.text : Theme.textMuted
                        }

                        HoverHandler { id: hubHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: win.toggleDrawer("hub") }
                    }

                    // ── back ────────────────────────────────────────────
                    // Only where there is somewhere to go back TO. A disabled
                    // arrow sitting permanently in a corner teaches people to
                    // stop looking at that corner.
                    Item {
                        Layout.preferredWidth: back.visible ? 28 : 0
                        Layout.preferredHeight: 28
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            id: back
                            anchors.fill: parent
                            radius: Theme.r1
                            visible: win.currentCategory !== "" || win.searching
                            color: "transparent"
                            border.width: 1
                            border.color: backHov.hovered
                                          ? Theme.tokenAccentInteractive
                                          : Theme.tokenAccentHairline
                            Behavior on border.color { ColorAnimation { duration: Theme.durQuick } }

                            Text {
                                anchors.centerIn: parent
                                text: "\uf053"            // chevron-left
                                font.family: Theme.fIcon
                                font.pixelSize: Theme.tBody
                                color: backHov.hovered ? Theme.text : Theme.textMuted
                            }

                            HoverHandler { id: backHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: win.goHome() }
                        }
                    }

                    // ── the breadcrumb ──────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0

                        // THE BREADCRUMB. "Nyxus Settings › <Section>", so
                        // the product name is on screen and the section is
                        // beside it rather than replacing it. Home has no
                        // second crumb; a search says so as its own section.
                        Text {
                            Layout.fillWidth: true
                            text: {
                                var root = "NYXUS RACK";
                                if (win.searching)
                                    return root + "  //  FIND";
                                if (win.currentCategory === "")
                                    return root + "  //  HUB";
                                var node = String(win.currentCategory).toUpperCase();
                                if (win.currentKey !== "")
                                    node += " / " + String(win.currentKey).toUpperCase();
                                return root + "  //  " + node;
                            }
                            color: Theme.text
                            font.family: Theme.fTech
                            font.pixelSize: Theme.tHead
                            font.weight: Font.DemiBold
                            font.letterSpacing: Theme.trackTitle
                            elide: Text.ElideRight
                            clip: true
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            // TRK-3567: the count has to say what was
                            // actually searched. It used to say "pages
                            // match" while searching page metadata only,
                            // which was true and useless; the controls are
                            // in the search now, so they are in the line.
                            text: win.searching
                                  ? qsTr("%1 of %2 nodes · %3 controls")
                                    .arg(win.results.length)
                                    .arg(SettingsCatalog.totalCount)
                                    .arg(SettingsIndex.controlCount)
                                  : win.currentCategory === ""
                                    ? "SELECT A NODE"
                                    : SettingsCatalog.category(win.currentCategory).blurb
                            color: Theme.textDim
                            font.family: Theme.fNum
                            font.pixelSize: Theme.tCaption
                            elide: Text.ElideRight
                            clip: true
                        }
                    }

                    // ── search ──────────────────────────────────────────
                    // Same family as Start: a Pane, not a QtQuick.Controls
                    // field. Ice[0] hairline on focus is the key-place colour;
                    // Pane focusLevel raises the glass rim.
                    Pane {
                        id: searchBox
                        Layout.preferredWidth: 300
                        Layout.preferredHeight: 30
                        Layout.alignment: Qt.AlignVCenter
                        elevation: 1
                        radius: Theme.r1
                        // Opaque groove, the value the reference capture
                        // measures inside a widget's meter track (#04090a).
                        // A softened `void_` here was a hole in the head
                        // strip the moment a window sat behind it.
                        fill: Theme.surface
                        focusLevel: search.activeFocus ? 1.0 : 0.0

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.r1
                            color: "transparent"
                            border.width: 1
                            border.color: search.activeFocus
                                          ? win.iceInteractive
                                          : Theme.soften(Theme.text, 0.14)
                            Behavior on border.color { ColorAnimation { duration: Theme.durQuick } }
                        }

                        // The mockup's count badge. It is `win.results.length`
                        // — the same number the breadcrumb's "N of M pages
                        // match" line states — so the badge and the sentence
                        // under the title can never disagree.
                        Rectangle {
                            visible: win.searching && win.results.length > 0
                            anchors.right: parent.right
                            anchors.rightMargin: -7
                            anchors.top: parent.top
                            anchors.topMargin: -7
                            width: Math.max(16, badgeText.implicitWidth + 8)
                            height: 16
                            radius: 8
                            color: Theme.paintLayers.glacier[5]

                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: win.results.length
                                color: Theme.void_
                                font.family: Theme.fNum
                                font.pixelSize: Theme.tMicro
                                font.weight: Font.DemiBold
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.s4
                            anchors.rightMargin: Theme.s4
                            spacing: Theme.s3

                            Text {
                                text: "\uf002"        // magnifier
                                font.family: Theme.fIcon
                                font.pixelSize: Theme.tCaption
                                color: search.activeFocus
                                       ? win.iceInteractive
                                       : Theme.textDim
                            }

                            TextInput {
                                id: search
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                text: win.query
                                onTextChanged: win.query = text
                                color: Theme.text
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tLabel
                                selectByMouse: true
                                selectionColor: Theme.soften(win.iceInteractive, 0.45)
                                clip: true
                                // Escape in the field clears it before it
                                // closes the window: the first Escape should
                                // undo the search you are looking at, not
                                // throw away the whole window because of it.
                                Keys.onEscapePressed: function (e) {
                                    if (search.text !== "") {
                                        search.text = "";
                                        e.accepted = true;
                                    } else {
                                        e.accepted = false;
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: search.text === "" && !search.activeFocus
                                    text: qsTr("Find a setting")
                                    color: Theme.textDim
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tLabel
                                }
                            }

                            Text {
                                visible: search.text !== ""
                                text: "\uf00d"        // times
                                font.family: Theme.fIcon
                                font.pixelSize: Theme.tCaption
                                color: clearHov.hovered ? Theme.text : Theme.textDim
                                HoverHandler { id: clearHov; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: { search.text = ""; search.forceActiveFocus(); } }
                            }
                        }
                    }

                    // ── the notifications handle ────────────────────────
                    // The pip is the real count of what is waiting —
                    // `Sys.notifications`, the model this shell's own
                    // notification daemon fills — so an empty inbox draws no
                    // pip at all rather than a zero.
                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        Layout.alignment: Qt.AlignVCenter
                        radius: Theme.r1
                        color: win.drawer === "notify"
                               ? Theme.soften(Theme.plumBody, 0.50)
                               : "transparent"
                        border.width: 1
                        border.color: bellHov.hovered || win.drawer === "notify"
                                      ? Theme.tokenAccentInteractive
                                      : Theme.tokenAccentHairline
                        Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                        Behavior on border.color { ColorAnimation { duration: Theme.durQuick } }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf0f3"            // bell
                            font.family: Theme.fIcon
                            font.pixelSize: Theme.tBody
                            color: win.drawer === "notify" ? Theme.text
                                 : bellHov.hovered ? Theme.text : Theme.textMuted
                        }

                        Rectangle {
                            visible: win.waitingCount > 0
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.rightMargin: 3
                            anchors.topMargin: 3
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.paintLayers.glacier[5]
                        }

                        HoverHandler { id: bellHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: win.toggleDrawer("notify") }
                    }

                    // ── close ───────────────────────────────────────────
                    // Drawn client-side because a Wayland toplevel on Hyprland
                    // gets a border and no buttons, and a window with no
                    // visible way to close it is a window people force-quit.
                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        Layout.alignment: Qt.AlignVCenter
                        radius: Theme.r1
                        color: closeHov.hovered
                               ? Theme.soften(win.magmaMark, 0.30)
                               : "transparent"
                        border.width: 1
                        border.color: closeHov.hovered
                                      ? win.magmaMark
                                      : Theme.tokenAccentHairline
                        Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                        Behavior on border.color { ColorAnimation { duration: Theme.durQuick } }

                        Text {
                            anchors.centerIn: parent
                            text: "\uf00d"            // times
                            font.family: Theme.fIcon
                            font.pixelSize: Theme.tBody
                            color: closeHov.hovered ? Theme.text : Theme.textMuted
                        }

                        HoverHandler { id: closeHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: Bus.settingsOpen = false }
                    }
                }

                // ── the live results dropdown ───────────────────────────
                // TRK-3215. The mockup's search has results UNDER the field,
                // as you type, without leaving the page you are on. It is the
                // same `SettingsCatalog.search()` the full-page result list
                // uses — one search, two surfaces, so a hit here and a hit
                // there can never disagree. Eight rows: past that the list
                // stops being a glance and the full result page behind it —
                // which is already on screen — is the right answer; the last
                // line says how many more are down there.
                Rectangle {
                    id: searchDrop
                    visible: win.searching && search.activeFocus
                             && win.results.length > 0
                    anchors.top: parent.bottom
                    anchors.topMargin: 2
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.s5 + 28 + Theme.s4
                    width: 360
                    height: dropCol.implicitHeight + 2 * Theme.s3
                    radius: Theme.r2
                    // TRK-3370 — the dropdown wears the widgets' stack via
                    // SetSlab (its glacier[4] seam replaces the hairline
                    // border), not a flat elevated fill.
                    color: "transparent"

                    SetSlab {
                        anchors.fill: parent
                        cornerRadius: Theme.r2
                    }

                    ColumnLayout {
                        id: dropCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: Theme.s3
                        spacing: 0

                        Repeater {
                            model: win.results.slice(0, 8)

                            delegate: Rectangle {
                                id: dropRow
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                color: dropHov.hovered
                                       ? Theme.soften(win.iceInteractive, 0.18)
                                       : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.s4
                                    anchors.rightMargin: Theme.s4
                                    spacing: Theme.s3

                                    Text {
                                        text: dropRow.modelData.glyph
                                        font.family: Theme.fIcon
                                        font.pixelSize: Theme.tCaption
                                        color: Theme.paintLayers.glacier[5]
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: dropRow.modelData.title
                                        color: Theme.text
                                        font.family: Theme.fUi
                                        font.pixelSize: Theme.tLabel
                                        elide: Text.ElideRight
                                    }
                                    // TRK-3567. When the match came from a
                                    // ROW on the page rather than the page
                                    // itself, that row's name takes this
                                    // slot — it is the answer, and the
                                    // category is about to be on screen
                                    // anyway. No second colour, no badge:
                                    // the same dim micro text either way.
                                    Text {
                                        text: {
                                            if (dropRow.modelData.hit)
                                                return "› " + dropRow.modelData.hit.label;
                                            var c = SettingsCatalog.category(dropRow.modelData.cat);
                                            return c ? c.title : "";
                                        }
                                        color: Theme.textDim
                                        font.family: Theme.fUi
                                        font.pixelSize: Theme.tMicro
                                        elide: Text.ElideRight
                                        Layout.maximumWidth: 120
                                    }
                                }

                                HoverHandler { id: dropHov; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    onTapped: {
                                        win.openKey(dropRow.modelData.key);
                                        search.text = "";
                                    }
                                }
                            }
                        }

                        Text {
                            visible: win.results.length > 8
                            Layout.fillWidth: true
                            Layout.leftMargin: Theme.s4
                            Layout.topMargin: Theme.s2
                            Layout.bottomMargin: Theme.s2
                            text: (win.results.length - 8)
                                  + qsTr(" more in the full list below")
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                        }
                    }
                }

                // 1 px seam — glacier[4] in its allowed role, never a fill.
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    anchors.leftMargin: Theme.s6
                    anchors.rightMargin: Theme.s6
                    height: 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: win.iceHairline }
                        GradientStop { position: 0.5; color: Theme.soften(win.iceHairline, 0.35) }
                        GradientStop { position: 1.0; color: Theme.shelfNone }
                    }
                }
            }

            // ══ THE BODY ═══════════════════════════════════════════════
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // ── LEVEL 1 · the hub ──────────────────────────────────
                // TRK-2301. `design/mockups-0822/suxyn-settings-0822.html`,
                // tab "The window", section "Level 1 — the hub".
                //
                // THE TILE IS A DIRECTORY. It was a title and an elided blurb
                // on a 150 px strip, six of them centred in a fixed frame with
                // roughly 120 px of dead air above and below (see
                // `docs/proof/settings-0822/before-settings-hub.png`). The
                // mockup's `.hub` is `flex:1` with a 16/20 frame and its
                // `.hubgrid` is `repeat(3,1fr) x repeat(2,1fr)` at gap 12, so
                // the tiles STRETCH to the body instead of floating in it, and
                // every page the tile holds is listed on its face and
                // clickable. A tile that only said "Devices & network" could
                // not tell you it held six pages; this one names all six and
                // gets you to any of them in one hop instead of two.
                Flickable {
                    ScrollRail { flick: homeView }   // WIP-332
                    id: homeView
                    anchors.fill: parent
                    // Level 1 fills the body. The 25% node tree is LEVEL 2/3.
                    anchors.leftMargin: 0
                    visible: win.currentCategory === "" && !win.searching
                    clip: true
                    contentWidth: width
                    // The grid FILLS. It does not overflow, so this never
                    // scrolls -- the Flickable stays because minimumSize is
                    // not a guarantee on a rotated or scaled panel and a hub
                    // that cannot be reached is worse than one that scrolls.
                    contentHeight: Math.max(height, hubFrame.implicitH)
                    boundsBehavior: Flickable.StopAtBounds

                    Item {
                        id: hubFrame
                        width: homeView.width
                        height: Math.max(homeView.height, hubFrame.implicitH)
                        // TRK-3363 — the 08-28 mockup's hub: a welcome
                        // heading above the grid, a live System Insights
                        // strip below it. Both heights are named once here
                        // and the grid derives its own frame from them.
                        readonly property int welcomeH: 64
                        readonly property int insightsH: 116
                        // Six tiles at the mockup's own minimum readable
                        // height, plus the frame. Below this the hub scrolls
                        // rather than crushing the page lists to nothing.
                        readonly property int implicitH:
                            win.hubRows * win.hubTileMinH
                            + Math.max(0, win.hubRows - 1) * Theme.s5
                            + 2 * Theme.s6
                            + hubFrame.welcomeH
                            + hubFrame.insightsH + Theme.s5

                        // ── the welcome heading (TRK-3363) ──────────────
                        ColumnLayout {
                            anchors { top: parent.top; left: parent.left; right: parent.right }
                            anchors.topMargin: Theme.s6
                            anchors.leftMargin: Theme.s7
                            anchors.rightMargin: Theme.s7
                            spacing: Theme.s2

                            Text {
                                Layout.fillWidth: true
                                text: win.machineFact("user") !== ""
                                      ? "OPERATOR  " + win.machineFact("user")
                                      : "OPERATOR"
                                color: Theme.text
                                font.family: Theme.fTech
                                font.pixelSize: Theme.tDisplay
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                                clip: true
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "SELECT A NODE TO OPEN THE RACK"
                                color: Theme.textDim
                                font.family: Theme.fNum
                                font.pixelSize: Theme.tCaption
                                elide: Text.ElideRight
                                clip: true
                            }
                        }

                        // ── SYSTEM INSIGHTS (TRK-3363) ──────────────────
                        // The 08-28 mockup's hub floor: one live strip on
                        // the widgets' own instrument. Four MeterRows off
                        // `Sys` — the same published properties the SYSTEM
                        // desktop widget reads, at zero added cost — inside
                        // one SetSlab, so the strip and a hub tile and a
                        // desktop widget are the same object.
                        SetSlab {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                            anchors.leftMargin: Theme.s7
                            anchors.rightMargin: Theme.s7
                            anchors.bottomMargin: Theme.s6
                            height: hubFrame.insightsH
                            cornerRadius: Theme.r2
                            level: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.s5
                                spacing: Theme.s3

                                Text {
                                    Layout.fillWidth: true
                                    text: qsTr("SYSTEM INSIGHTS")
                                    color: Theme.textDim
                                    font.family: Theme.fTech
                                    font.pixelSize: Theme.tMicro
                                    font.letterSpacing: Theme.trackMicro
                                    elide: Text.ElideRight
                                    clip: true
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: Theme.s7

                                    MeterRow {
                                        Layout.fillWidth: true
                                        label: qsTr("Processor")
                                        value: Sys.cpuPercent / 100
                                        readout: Sys.cpuPercent + "%"
                                    }
                                    MeterRow {
                                        Layout.fillWidth: true
                                        label: qsTr("Memory")
                                        value: Sys.memPercent / 100
                                        readout: Sys.memText
                                    }
                                    MeterRow {
                                        Layout.fillWidth: true
                                        label: qsTr("Storage")
                                        value: Sys.diskPercent / 100
                                        readout: Sys.diskText
                                    }
                                    MeterRow {
                                        Layout.fillWidth: true
                                        label: qsTr("Network")
                                        value: Sys.netPercent / 100
                                        readout: Sys.netText
                                    }
                                }
                            }
                        }

                        GridLayout {
                            id: homeGrid
                            anchors.fill: parent
                            // The mockup's `.hub{padding:16px 20px}`: 16 top
                            // and bottom, 20 either side. One frame, stated
                            // once, not four margins that drift apart.
                            // TRK-3363: the welcome heading sits inside the
                            // top frame and the insights strip inside the
                            // bottom one — both derived from hubFrame's own
                            // named heights, never re-typed.
                            anchors.topMargin: Theme.s6 + hubFrame.welcomeH
                            anchors.bottomMargin: Theme.s6 + hubFrame.insightsH + Theme.s5
                            anchors.leftMargin: Theme.s7
                            anchors.rightMargin: Theme.s7
                            columns: win.hubCols
                            // `.hubgrid{gap:12px}` -- 12 inside a section, the
                            // one grid's third rung.
                            columnSpacing: Theme.s5
                            rowSpacing: Theme.s5

                            Repeater {
                                model: SettingsCatalog.categories

                                delegate: Item {
                                    id: tile
                                    required property var modelData

                                    // 1fr x 1fr. A fixed height is what left
                                    // the air; filling is what removes it.
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    readonly property var tilePages:
                                        SettingsCatalog.inCategory(tile.modelData.id)

                                    // TRK-3223 — the tile wears the one
                                    // Settings material, opaque, so a hub
                                    // tile and a page card and one of his
                                    // desktop widgets are the same object.
                                    // Idle/hover is now the SAME face under
                                    // more light (Pane focusLevel + the
                                    // GlassEdge glaze inside SetSlab), which
                                    // is what `Pane.qml` §4.4 asks for —
                                    // never a second fill colour.
                                    SetSlab {
                                        anchors.fill: parent
                                        cornerRadius: Theme.r2
                                        level: tileHov.hovered ? 2 : 1
                                        lifted: tileHov.hovered

                                        // `.htile:hover{transform:translateY(-2px)}`
                                        transform: Translate {
                                            y: tileHov.hovered ? -2 : 0
                                            Behavior on y {
                                                NumberAnimation {
                                                    duration: Theme.durQuick
                                                    easing.type: Easing.Bezier
                                                    easing.bezierCurve: Theme.curveRise
                                                }
                                            }
                                        }

                                        // Ice[5] at the light corner, hover
                                        // only. Not a per-tile sweep.
                                        // The tile is a SetSlab — a CARD — so
                                        // this wash has to cut with it. A
                                        // rounded highlight over a cut card
                                        // shows a corner that is not there,
                                        // and it shows it on HOVER, which is
                                        // when the eye is already on the tile.
                                        // Two stops expressed as three: the
                                        // knee at 0.75 then held to the foot,
                                        // which is what the Gradient did.
                                        CutRect {
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            radius: Theme.r2
                                            visible: tileHov.hovered
                                            gradTop: Theme.soften(win.icePrimary, 0.16)
                                            gradMidPos: 0.75
                                            gradMid: Theme.shelfNone
                                            gradFoot: Theme.shelfNone
                                        }
                                    }

                                    // ── the face ────────────────────────
                                    ColumnLayout {
                                        anchors.fill: parent
                                        // `.htile{padding:12px 14px}`
                                        anchors.topMargin: Theme.s5
                                        anchors.bottomMargin: Theme.s5
                                        anchors.leftMargin: Theme.s5 + 2
                                        anchors.rightMargin: Theme.s5 + 2
                                        spacing: Theme.s3

                                        // ── head: chip, name, count ─────
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: Theme.s4

                                            // `.htile .ic` -- 28 square, r1,
                                            // ice ground and a hairline ring.
                                            // Not a bare glyph on the void:
                                            // the chip is what makes six
                                            // different marks read as one set.
                                            Item {
                                                Layout.preferredWidth: 28
                                                Layout.preferredHeight: 28
                                                Layout.alignment: Qt.AlignVCenter

                                                CrystalGem {
                                                    anchors.fill: parent
                                                    hot: tileHov.hovered
                                                    on: tileHov.hovered
                                                    tint: win.iceHairline
                                                }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: tile.modelData.glyph
                                                    font.family: Theme.fIcon
                                                    font.pixelSize: Theme.tBody
                                                    color: tileHov.hovered
                                                           ? win.iceInteractive
                                                           : win.icePrimary
                                                    Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                                                }
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                text: tile.modelData.title
                                                color: Theme.text
                                                font.family: Theme.fUiTitle
                                                font.pixelSize: Theme.tHead
                                                font.weight: Font.DemiBold
                                                elide: Text.ElideRight
                                                clip: true
                                            }

                                            // `.htile .ct` -- how many pages
                                            // this tile holds. COUNTED off the
                                            // same list the face draws below,
                                            // never typed: a tile that says 6
                                            // and lists 5 is the defect the
                                            // count exists to prevent.
                                            Rectangle {
                                                Layout.alignment: Qt.AlignVCenter
                                                Layout.preferredWidth: hubCt.implicitWidth + 2 * Theme.s3
                                                Layout.preferredHeight: 16
                                                radius: Theme.rFull
                                                color: "transparent"
                                                border.width: 1
                                                border.color: Theme.soften(win.iceHairline, 0.45)

                                                Text {
                                                    id: hubCt
                                                    anchors.centerIn: parent
                                                    text: tile.tilePages.length
                                                    color: Theme.textDim
                                                    font.family: Theme.fNum
                                                    font.pixelSize: Theme.tMicro
                                                }
                                            }
                                        }

                                        // ── the blurb ───────────────────
                                        Text {
                                            Layout.fillWidth: true
                                            text: tile.modelData.blurb
                                            color: Theme.textDim
                                            font.family: Theme.fUi
                                            font.pixelSize: Theme.tCaption
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                            clip: true
                                        }

                                        // ── the directory ───────────────
                                        // Every page, named and clickable.
                                        // This is the whole point of the
                                        // tile: the hub is one hop from any
                                        // page instead of two.
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            Layout.topMargin: Theme.s1
                                            spacing: 1

                                            Repeater {
                                                model: tile.tilePages

                                                delegate: Rectangle {
                                                    id: hubItem
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 17
                                                    radius: 5
                                                    color: hubItemHov.hovered
                                                           ? Theme.soften(win.icePrimary, 0.10)
                                                           : "transparent"
                                                    Behavior on color { ColorAnimation { duration: Theme.durInstant } }

                                                    Text {
                                                        anchors.left: parent.left
                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        anchors.leftMargin: Theme.s3
                                                        anchors.rightMargin: Theme.s3
                                                        text: hubItem.modelData.title
                                                        color: hubItemHov.hovered ? Theme.text : Theme.textDim
                                                        font.family: Theme.fUi
                                                        font.pixelSize: Theme.tCaption
                                                        elide: Text.ElideRight
                                                        Behavior on color { ColorAnimation { duration: Theme.durInstant } }
                                                    }

                                                    HoverHandler { id: hubItemHov; cursorShape: Qt.PointingHandCursor }
                                                    TapHandler { onTapped: win.openKey(hubItem.modelData.key) }
                                                }
                                            }

                                            Item { Layout.fillHeight: true }
                                        }
                                    }

                                    Pool {
                                        anchors.bottom: parent.bottom
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: parent.width * 0.9
                                        height: 16
                                        tone: win.icePrimary
                                        focusRatio: 0.5
                                        strength: tileHov.hovered ? 0.75 : 0
                                    }

                                    // Whole-tile hover and tap sit UNDER the
                                    // per-page rows, which take the tap first
                                    // when the pointer is on one of them.
                                    HoverHandler { id: tileHov; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: win.openCategory(tile.modelData.id) }
                                }
                            }
                        }
                    }
                }


                // ── SEARCH RESULTS ─────────────────────────────────────
                // A flat list across every category, because that is the point
                // of searching: you do not know which room it is in. Each row
                // says which one it IS in, so the next time you do.
                ListView {
                    ScrollRail { flick: resultView }   // WIP-332
                    id: resultView
                    // TRK-2911: the same rule the page column uses, so the
                    // result list and the page it opens are the same column
                    // in the same place. It was s5 here and 0 there — two
                    // expressions for one measurement, which is how they drift.
                    width: Math.min(parent.width - 2 * Theme.s7, win.pageMax)
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.topMargin: Theme.s4
                    visible: win.searching
                    clip: true
                    model: win.results
                    spacing: 1
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        required property var modelData
                        width: resultView.width
                        height: hit.implicitHeight

                        SetRow {
                            id: hit
                            width: parent.width
                            glyph: modelData.glyph
                            title: modelData.title
                            // TRK-3567 — a control match replaces the page
                            // blurb with the row that matched, because the
                            // blurb is what the page always says and the
                            // row is why you are looking at it. The chevron
                            // is the breadcrumb's own separator: this is
                            // one level INSIDE the page named above it.
                            sub: modelData.hit
                                 ? ("› " + modelData.hit.label
                                    + (modelData.hit.sub
                                       ? " — " + modelData.hit.sub : ""))
                                 : modelData.blurb
                            valueText: {
                                var c = SettingsCatalog.category(modelData.cat);
                                return c ? c.title : "";
                            }
                            navigates: true
                            onActivated: win.openKey(modelData.key)
                        }
                    }
                }

                // Search that found nothing says so, and says what it looked
                // through. An empty list with no message is the "waiting for
                // weather" failure this build has already learned once.
                ColumnLayout {
                    anchors.centerIn: parent
                    width: Math.min(parent.width * 0.7, win.pageMax)
                    visible: win.searching && win.results.length === 0
                    spacing: Theme.s4

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "\uf002"
                        font.family: Theme.fIcon
                        font.pixelSize: Theme.tTitle
                        color: Theme.textDim
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Nothing matches “" + win.query + "”"
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.textMuted
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tBody
                    }
                    Text {
                        Layout.fillWidth: true
                        // ONE literal — qsTr's argument must be a single
                        // string or the extractor takes the first fragment
                        // and the entry is a lie (scripts/i18n-extract.py).
                        text: qsTr("Searched the titles, descriptions and keywords of all %1 pages, and the %2 controls on them. Try a plainer word — “printer” rather than “CUPS”.")
                              .arg(SettingsCatalog.totalCount)
                              .arg(SettingsIndex.controlCount)
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                    }
                }

                // ── LEVEL 2/3 · the calibration rack ──────────────────
                // 25% schematic node tree · 45% control kit Loader ·
                // 30% live diagnostic bus. Hub (level 1) stays above.
                RowLayout {
                    anchors.fill: parent
                    visible: !win.searching && win.currentCategory !== ""
                    spacing: 0

                    // ── Panel 1 · NODE TREE ───────────────────────────
                    // The percentages used to read 25 / 45 / 30 and sum to a
                    // hundred. With the bus gone they would have summed to 70,
                    // and because these are PROPORTIONS the tree would have
                    // quietly grown from a quarter of the window to over a
                    // third -- removing a panel would have made the navigation
                    // WIDER, which is the opposite of the point.
                    //
                    // So the pair is restated as 22 / 78, and the tree gains a
                    // ceiling it never had. A settings sidebar is a list of
                    // short words; past about 300 px it stops being a column
                    // and becomes an empty field with text down one edge, and
                    // this window is resizable, so on a maximised 1920 screen
                    // the old proportional rule would have drawn a 420 px one.
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 22
                        Layout.minimumWidth: 180
                        Layout.maximumWidth: 300

                        Pane {
                            id: treePane
                            anchors.fill: parent
                            anchors.margins: Theme.s3
                            anchors.leftMargin: Theme.s4
                            elevation: 1
                            radius: Theme.r2
                            fill: Theme.panelMid
                            bloomAtRest: false

                            GlassEdge {
                                anchors.fill: parent
                                radiusTL: Theme.r2; radiusTR: Theme.r2
                                radiusBR: Theme.r2; radiusBL: Theme.r2
                                body: 0
                                wash: 0
                                glaze: 0.55
                                edging: 0.70
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.s4
                                spacing: Theme.s2

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.s3

                                    Text {
                                        Layout.fillWidth: true
                                        text: "NODE TREE"
                                        color: Theme.text
                                        font.family: Theme.fTech
                                        font.pixelSize: Theme.tCaption
                                        elide: Text.ElideRight
                                        clip: true
                                    }
                                    Text {
                                        text: String(SettingsCatalog.builtCount)
                                        color: win.glacierText
                                        font.family: Theme.fNum
                                        font.pixelSize: Theme.tMicro
                                        elide: Text.ElideRight
                                        clip: true
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 1
                                    color: Theme.tokenAccentHairline
                                }

                                Item {
                                    id: hubNode
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 24
                                    clip: true

                                    Rectangle {
                                        anchors.fill: parent
                                        visible: hubNodeHov.hovered
                                        color: "transparent"
                                        border.width: 1
                                        border.color: Theme.tokenAccentInteractive
                                        radius: Theme.r1
                                    }
                                    Text {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: Theme.s2
                                        anchors.rightMargin: Theme.s2
                                        text: "⌂  HUB"
                                        color: Theme.textMuted
                                        font.family: Theme.fTech
                                        font.pixelSize: Theme.tCaption
                                        elide: Text.ElideRight
                                        clip: true
                                    }
                                    HoverHandler { id: hubNodeHov; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: win.goHome() }
                                }

                                Flickable {
                                    ScrollRail { flick: nodeFlick }
                                    id: nodeFlick
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    contentWidth: width
                                    contentHeight: nodeCol.implicitHeight
                                    boundsBehavior: Flickable.StopAtBounds
                                    flickDeceleration: 3500

                                    Column {
                                        id: nodeCol
                                        width: nodeFlick.width
                                        spacing: 0

                                        Repeater {
                                            model: win.treeCats

                                            delegate: Column {
                                                id: catNode
                                                required property var modelData
                                                width: nodeCol.width
                                                readonly property bool on:
                                                    catNode.modelData.id === win.currentCategory
                                                readonly property var pages:
                                                    SettingsCatalog.railInCategory(catNode.modelData.id)

                                                Item {
                                                    width: parent.width
                                                    height: 26
                                                    clip: true

                                                    Rectangle {
                                                        anchors.fill: parent
                                                        visible: catNodeHov.hovered
                                                        color: "transparent"
                                                        border.width: 1
                                                        border.color: Theme.tokenAccentInteractive
                                                        radius: Theme.r1
                                                    }
                                                    Rectangle {
                                                        visible: catNode.on
                                                        anchors.left: parent.left
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: 4
                                                        height: 10
                                                        radius: 1
                                                        color: Theme.tokenAccentInteractive
                                                    }
                                                    Text {
                                                        anchors.left: parent.left
                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        anchors.leftMargin: Theme.s5
                                                        anchors.rightMargin: Theme.s2
                                                        text: (catNode.on ? "▾  " : "▸  ")
                                                              + String(catNode.modelData.id).toUpperCase()
                                                        color: catNode.on ? Theme.text : Theme.textMuted
                                                        font.family: Theme.fTech
                                                        font.pixelSize: Theme.tCaption
                                                        elide: Text.ElideRight
                                                        clip: true
                                                    }
                                                    HoverHandler { id: catNodeHov; cursorShape: Qt.PointingHandCursor }
                                                    TapHandler { onTapped: win.openCategory(catNode.modelData.id) }
                                                }

                                                Repeater {
                                                    model: catNode.on ? catNode.pages : []

                                                    delegate: Item {
                                                        id: pageNode
                                                        required property var modelData
                                                        required property int index
                                                        width: catNode.width
                                                        readonly property bool sep: pageNode.modelData._sep === true
                                                        readonly property bool on: !pageNode.sep
                                                                                   && pageNode.modelData.key === win.currentKey
                                                        readonly property bool last: pageNode.index === catNode.pages.length - 1
                                                        height: pageNode.sep ? 16 : 22
                                                        clip: true

                                                        Rectangle {
                                                            anchors.fill: parent
                                                            visible: !pageNode.sep && pageNodeHov.hovered
                                                            color: "transparent"
                                                            border.width: 1
                                                            border.color: Theme.tokenAccentInteractive
                                                            radius: Theme.r1
                                                        }
                                                        Rectangle {
                                                            visible: pageNode.on
                                                            anchors.left: parent.left
                                                            anchors.leftMargin: Theme.s5
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            width: 5
                                                            height: 5
                                                            radius: 1
                                                            color: Theme.tokenAccentInteractive
                                                        }
                                                        Text {
                                                            anchors.left: parent.left
                                                            anchors.right: parent.right
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            anchors.leftMargin: Theme.s6
                                                            anchors.rightMargin: Theme.s2
                                                            text: pageNode.sep
                                                                  ? String(pageNode.modelData.title).toUpperCase()
                                                                  : ((pageNode.last ? "└─ " : "├─ ")
                                                                     + String(pageNode.modelData.title
                                                                              || pageNode.modelData.key).toUpperCase())
                                                            color: pageNode.sep ? Theme.textDim
                                                                 : pageNode.on ? Theme.text : Theme.textMuted
                                                            font.family: Theme.fNum
                                                            font.pixelSize: Theme.tCaption
                                                            elide: Text.ElideRight
                                                            clip: true
                                                        }
                                                        HoverHandler {
                                                            id: pageNodeHov
                                                            enabled: !pageNode.sep
                                                            cursorShape: Qt.PointingHandCursor
                                                        }
                                                        TapHandler {
                                                            enabled: !pageNode.sep && !!pageNode.modelData.key
                                                            onTapped: win.openKey(pageNode.modelData.key)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 1
                                    color: Theme.tokenAccentHairline
                                }

                                Item {
                                    id: userChip
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: visible ? 22 : 0
                                    visible: win.machineFact("user") !== ""
                                    clip: true

                                    Rectangle {
                                        anchors.fill: parent
                                        visible: chipHov.hovered
                                        color: "transparent"
                                        border.width: 1
                                        border.color: Theme.tokenAccentInteractive
                                        radius: Theme.r1
                                    }
                                    Text {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.leftMargin: Theme.s2
                                        anchors.rightMargin: Theme.s2
                                        text: "OP  " + win.machineFact("user")
                                        color: Theme.textMuted
                                        font.family: Theme.fNum
                                        font.pixelSize: Theme.tCaption
                                        elide: Text.ElideRight
                                        clip: true
                                    }
                                    HoverHandler { id: chipHov; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: win.openKey("account") }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        Layout.topMargin: Theme.s5
                        Layout.bottomMargin: Theme.s5
                        color: Theme.tokenAccentHairline
                    }

                    // ── Panel 2 · CONTROL KIT ─────────────────────────
                    // Takes the whole remainder now (see Panel 1 for why the
                    // proportions were restated). The settings themselves are
                    // the reason the window exists; they get the width.
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 78
                        Layout.minimumWidth: 280

                        Pane {
                            anchors.fill: parent
                            anchors.margins: Theme.s3
                            elevation: 1
                            radius: Theme.r2
                            fill: Theme.panelMid
                            bloomAtRest: false

                            GlassEdge {
                                anchors.fill: parent
                                radiusTL: Theme.r2; radiusTR: Theme.r2
                                radiusBR: Theme.r2; radiusBL: Theme.r2
                                body: 0
                                wash: 0
                                glaze: 0.45
                                edging: 0.65
                            }

                            Item {
                                id: pageSlot
                                anchors.fill: parent
                                anchors.margins: 1
                                clip: true

                                Loader {
                                    id: pageLoader
                                    anchors.fill: parent
                                    asynchronous: false

                                    // Pages are loaded BY URL, not as registered types.
                                    // `qmldir` disables implicit same-directory type
                                    // registration (see the warning at the top of it),
                                    // so a type would need a qmldir line as well and a
                                    // module that forgot one would fail at the use
                                    // site. A URL in this directory needs nothing, and
                                    // the singletons still resolve because it is the
                                    // same directory and therefore the same module.
                                    function load() {
                                        var p = win.currentPage;
                                        if (!p) {
                                            pageLoader.setSource("", {});
                                            return;
                                        }
                                        var file = p.page !== "" ? p.page : "SetPagePending.qml";
                                        pageLoader.setSource(Qt.resolvedUrl(file), {
                                            "entry": p,
                                            "tone": win.toneFor(p.cat)
                                        });
                                    }

                                    Component.onCompleted: pageLoader.load()

                                    Connections {
                                        target: win
                                        function onCurrentKeyChanged() { pageLoader.load(); }
                                    }

                                    onStatusChanged: {
                                        if (pageLoader.status === Loader.Error)
                                            console.warn("Settings: page failed to load for key '"
                                                         + win.currentKey + "' ("
                                                         + pageLoader.source + ")");
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: pageLoader.status === Loader.Error
                                    width: parent.width * 0.7
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    text: qsTr("This page could not be loaded.\n")
                                          + pageLoader.source
                                          + "\n\nThe rest of Settings is unaffected."
                                    color: Theme.warn
                                    font.family: Theme.fNum
                                    font.pixelSize: Theme.tLabel
                                    elide: Text.ElideRight
                                    clip: true
                                }

                                opacity: 1
                                NumberAnimation on opacity {
                                    id: pageFade
                                    running: false
                                    from: 0; to: 1
                                    duration: Theme.durQuick
                                }
                                Connections {
                                    target: win
                                    function onCurrentKeyChanged() {
                                        if (win.visible)
                                            pageFade.restart();
                                    }
                                }
                            }
                        }
                    }

                    // ── Panel 3 was the LIVE DIAGNOSTIC BUS ── TRK-4153 ──
                    // Owner, 2026-09-15: "the live bus section that was
                    // suppose to be gone and just keep the two".
                    //
                    // It was a developer's scrolling log of every control the
                    // window touched, and it was taking 30% of the width of
                    // the settings surface on every machine that will ever run
                    // this build. Nobody who is changing their wallpaper needs
                    // to watch the bus, and a stranger reading it learns only
                    // that something in here is still being debugged -- the
                    // same reason THE FLOOR stopped claiming HDMI screens.
                    //
                    // `DiagnosticBus` itself is deliberately LEFT IN PLACE.
                    // SetButton, SetChoice, SetSlider, SetSwitch and
                    // SetPageSound all still write to it; this panel was its
                    // only reader. So the instrumentation survives for anyone
                    // who wants to put a view back behind a developer flag,
                    // and nothing had to be unpicked from five call sites to
                    // reclaim the third of the window.
                }
            }

            // ══ THE FOOT · the action bar ══════════════════════════════
            // TRK-3215. Three buttons, and all three DO something:
            //   Restore Defaults  opens the Reset page, where the per-section
            //                     restores live (one per page, each with its
            //                     own consequence written beside it).
            //   Reset to Defaults calls SettingsStore.resetAll() — the real
            //                     whole-document reset, behind SetButton's
            //                     two-tap arm, which backs the file up first
            //                     and refuses to proceed if that backup did
            //                     not land.
            //   Save Changes      flushes the pending write. Enabled only
            //                     while there IS a pending write; every
            //                     control in this window already saves on
            //                     change, so a permanently-live Save button
            //                     would be a lie about what it does.
            Item {
                Layout.fillWidth: true
                // The mockup's action row measures 32 px of button in a 56 px
                // band (buttons y=638..670 inside a footer that starts at
                // 622). It was 28 in 46 (TRK-3225).
                Layout.preferredHeight: 56

                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    anchors.leftMargin: Theme.s6
                    anchors.rightMargin: Theme.s6
                    height: 1
                    color: Theme.soften(Theme.text, 0.06)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.s6
                    anchors.rightMargin: Theme.s6
                    spacing: Theme.s4

                    Text {
                        text: SettingsStore.parseError !== ""
                              ? "settings.json is unreadable — showing defaults, nothing overwritten"
                              : "~/.config/nyxus/settings.json"
                        color: SettingsStore.parseError !== "" ? Theme.warn : Theme.textDim
                        font.family: Theme.fNum
                        font.pixelSize: Theme.tMicro
                        elide: Text.ElideRight
                        clip: true
                        Layout.fillWidth: true
                    }

                    Text {
                        text: SettingsStore.status
                        visible: text !== ""
                        color: SettingsStore.dirty ? Theme.textMuted : Theme.ok
                        font.family: Theme.fNum
                        font.pixelSize: Theme.tMicro
                        font.letterSpacing: Theme.trackMicro
                        elide: Text.ElideRight
                        clip: true
                    }

                    SetButton {
                        text: qsTr("Restore Defaults")
                        implicitHeight: 32
                        glyph: "\uf0e2"
                        tone: win.tone
                        enabled: SettingsCatalog.find("reset") !== null
                        onClicked: win.openKey("reset")
                    }

                    SetButton {
                        text: qsTr("Reset to Defaults")
                        implicitHeight: 32
                        glyph: "\uf2ea"
                        danger: true
                        confirmText: qsTr("Reset every setting")
                        tone: win.tone
                        onClicked: SettingsStore.resetAll()
                    }

                    SetButton {
                        text: qsTr("Save Changes")
                        implicitHeight: 32
                        glyph: "\uf0c7"
                        tone: win.tone
                        enabled: SettingsStore.dirty
                        onClicked: SettingsStore.flush()
                    }
                }
            }

            // ══ THE STATUS STRIP ═══════════════════════════════════════
            // What machine this is, and what it is running. Every field is
            // read, not written: `os` is /etc/os-release's PRETTY_NAME, the
            // update stamp is the `checked` epoch inside the file
            // `nyxus-update-check` writes, and the device is the real
            // hostname with the firmware's own model beside it when the
            // firmware reports one. A field with no answer is not drawn.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 24

                Rectangle {
                    anchors { left: parent.left; right: parent.right; top: parent.top }
                    anchors.leftMargin: Theme.s6
                    anchors.rightMargin: Theme.s6
                    height: 1
                    color: Theme.soften(Theme.text, 0.06)
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.s6
                    anchors.rightMargin: Theme.s6
                    spacing: Theme.s4

                    Text {
                        visible: win.machineFact("os") !== ""
                        text: win.machineFact("os")
                        color: Theme.textDim
                        font.family: Theme.fNum
                        font.pixelSize: Theme.tMicro
                        elide: Text.ElideRight
                        clip: true
                        Layout.maximumWidth: 320
                    }

                    Text {
                        visible: win.machineFact("os") !== ""
                        text: "·"
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                    }

                    Text {
                        // TRK-3538 — the never-case is its own SENTENCE, not the
                        // prefix with a fragment stuck on the end. `checkedLabel`
                        // is a bare fragment for every other branch ("just now",
                        // "5 min ago", a date), and those all read correctly after
                        // "Updates checked ". "never" does not — it lands as
                        // "Updates checked never", which is the first thing a new
                        // user reads on a freshly booted image, because
                        // update-check.json does not exist until the first check
                        // runs. Whole phrase for that branch, prefix for the rest.
                        text: (UpdateWatch.checkedAt <= 0
                               ? qsTr("Updates never checked")
                               : qsTr("Updates checked ") + UpdateWatch.checkedLabel)
                              + (UpdateWatch.count > 0
                                 ? "  (" + UpdateWatch.label + ")" : "")
                        color: Theme.textDim
                        font.family: Theme.fNum
                        font.pixelSize: Theme.tMicro
                        elide: Text.ElideRight
                        clip: true

                        HoverHandler { id: upHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: win.openKey("updates") }
                    }

                    Text {
                        visible: win.machineFact("host") !== ""
                        text: "·"
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                    }

                    Text {
                        visible: win.machineFact("host") !== ""
                        text: win.machineFact("host")
                              + (win.machineFact("model") !== ""
                                 ? "  (" + win.machineFact("model") + ")" : "")
                        color: Theme.textDim
                        font.family: Theme.fNum
                        font.pixelSize: Theme.tMicro
                        elide: Text.ElideRight
                        clip: true
                        Layout.fillWidth: true
                    }

                    // TRK-2300 — the mockup's `.wfoot`: what the hub holds,
                    // stated where the hub is. Both numbers are COUNTED off
                    // the catalog arrays the grid above draws from (see
                    // `SettingsCatalog.hubPageCount`), so this line cannot
                    // drift from the tiles the way a typed "30 pages" would
                    // the first time a page moved.
                    Text {
                        text: SettingsCatalog.hubPageCount + " pages · "
                              + SettingsCatalog.hubCategoryCount + " categories"
                        color: Theme.textDim
                        font.family: Theme.fNum
                        font.pixelSize: Theme.tMicro
                        font.letterSpacing: Theme.trackMicro
                        elide: Text.ElideRight
                        clip: true
                    }

                    Text {
                        text: SettingsCatalog.builtCount + " / "
                              + SettingsCatalog.totalCount + " pages in glass"
                        color: Theme.textDim
                        font.family: Theme.fNum
                        font.pixelSize: Theme.tMicro
                        font.letterSpacing: Theme.trackMicro
                        elide: Text.ElideRight
                        clip: true
                    }
                }
            }
        }

        // ══ THE DRAWERS ════════════════════════════════════════════════
        // Children of this window's surface, so the compositor stacks them
        // WITH Settings and not above the desktop. They start below the head
        // strip — the breadcrumb, the search and the two handles stay
        // reachable while a drawer is out, which is what makes the handle a
        // toggle rather than a trapdoor.

        // The scrim. It is what makes "click away to close" work, and it is
        // also the legibility answer: a drawer with a page showing at full
        // strength one pixel to its right is two things competing. Black at
        // 0.45, no hue — HORIZON's rule that a dark here is a saturated
        // colour is about SURFACES, and this is a shadow.
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: headStrip.height
            id: drawerScrim
            color: Qt.rgba(0, 0, 0, 0.45)
            opacity: win.drawer !== "" ? 1 : 0
            visible: drawerScrim.opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Theme.durQuick } }

            TapHandler { onTapped: win.drawer = "" }
        }

        SetHubDock {
            id: hubDrawer
            y: headStrip.height
            height: surface.height - headStrip.height
            open: win.drawer === "hub"
            onCloseRequested: win.drawer = ""
        }

        SetNotifyFlyout {
            id: notifyDrawer
            y: headStrip.height
            height: surface.height - headStrip.height
            open: win.drawer === "notify"
            onCloseRequested: win.drawer = ""
        }

        // ══ keyboard ═══════════════════════════════════════════════════
        // Escape closes, unless the search field is dealing with it first.
        // Ctrl+F puts the caret in search from anywhere. Alt+Left and
        // Backspace go back a level, the way a browser does.
        focus: true
        // A drawer is the innermost thing on screen, so it is the first thing
        // Escape takes away — the same rule the search field already follows
        // one level in. Escape with nothing open closes the window.
        Keys.onEscapePressed: function (e) {
            if (win.drawer !== "") {
                win.drawer = "";
                e.accepted = true;
                return;
            }
            Bus.settingsOpen = false;
        }
        Keys.onPressed: function (e) {
            if (e.key === Qt.Key_F && (e.modifiers & Qt.ControlModifier)) {
                search.forceActiveFocus();
                search.selectAll();
                e.accepted = true;
            } else if ((e.key === Qt.Key_Left && (e.modifiers & Qt.AltModifier))
                       || (e.key === Qt.Key_Backspace && !search.activeFocus)) {
                if (win.currentCategory !== "" || win.searching) {
                    win.goHome();
                    e.accepted = true;
                }
            }
        }
    }
}
