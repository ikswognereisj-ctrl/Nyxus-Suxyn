// Nyxus Suxyn — the Rail. One place to change things.
//
// WIP-127. Spec and reasoning: docs/PLAN_SIDE_PANEL.md.
//
// ── WHY IT IS A RAIL AND NOT A HIDDEN DRAWER ──────────────────────────────
//
// The owner asked for a panel that "hides when you aren't using it at all"
// and opens on a click. Those two cannot both be true — if it is fully hidden
// there is nothing to click, and the usual substitutes are both wrong here:
//
//   · a screen-edge hover trigger fires every time the pointer is thrown at a
//     scrollbar, and WIP-88 is an OPEN bug about edge input not reaching a
//     surface on this compositor. Resting a primary surface on edge detection
//     means resting it on the one mechanism known to be broken.
//   · a keybind is invisible to anyone who was not told it exists.
//
// All five reference images he sent answer it the same way, and not one of
// them is actually hidden: each shows a narrow icon rail beside its expanded
// state. That is not "hidden", it is "narrow" — always visible, always
// clickable, and it shows you what is inside before you open it.
//
// So the rail is permanent and the PANEL is what hides. Clicking the icon you
// are already on collapses it again, which is the "same click opens and
// closes" he described.
//
// ── THE RULE THIS SURFACE EXISTS TO ENFORCE ───────────────────────────────
//
// He asked for no duplication — "I don't want double of the setting, like the
// same one there but then have it on the taskbar too". Stated flatly that
// would delete the bar, so the rule is three tiers:
//
//     the BAR shows STATE · this panel is where you CHANGE it ·
//     Settings is where you CONFIGURE it
//
// A bar glyph is a readout. The slider lives here. The device list, the EQ and
// the per-app volume live in Settings. Nothing appears twice at the same tier.
//
// ── PHASE 2 · THE FLYOUT'S SECTIONS LIVE HERE NOW ─────────────────────────
//
// WIP-127 phase 2, per the spec's §3.1: every section the bottom-right Flyout
// held has moved into this panel — the toggles, the sliders, the output
// picker, the Wi-Fi and Bluetooth lists, now-playing, the notification stack,
// the calendar with its day reminders, and the machine vitals. Nothing was
// dropped; this is a move, so no capability is lost on the day it lands.
//
// The routing is the part that makes it invisible to the rest of the shell:
// Bus.openFlyoutAt() / Bus.toggleFlyout() keep their names and their callers
// (the Gauge, the Crest, the Launcher's @flyout: entries, the IPC keybind) and
// this panel now ANSWERS them — the alias map below translates the section
// names the bar has always sent into rail sections. Bus.flyoutOpen still
// means "the quick panel is open", so every glyph that lights up with it
// still lights up.
//
// The one thing that did NOT move is the power row. The header's ⏻ opens the
// real PowerMenu, which already holds Lock and Sleep — that surface is the
// one ceremony in this system and there must not be a second, quieter copy.
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

PanelWindow {
    id: root

    // ── geometry ─────────────────────────────────────────────────────
    // TRK-1801: none of 46 / 6 / 340 sat on the 4 px grid. 48 + 8 + 344 = 400.
    // The rail also now matches the 48 px tile the Start menu's rail uses, so
    // the two vertical strips in the build are the same width.
    readonly property int railW: 48
    readonly property int panelW: 344
    readonly property int gap: Theme.s4

    // ── TRK-2901 · THE PANEL IS AS TALL AS ITS SECTION, AND NO TALLER ──
    //
    // The window used to be anchored top AND bottom so a width animation
    // would not re-negotiate the layer every frame. That left `nyxus-side`
    // at exclusive-zone height (400×996 on 1080p) with a compact card
    // floating in a full-height invisible hit layer — the remaining
    // TRK-2987 defect after the card itself learned `panelH`. Width is a
    // constant 400; height is the one axis that must change, and it is
    // derived from the SCREEN, never from `root.height` (that would be
    // the y=-59 loop: implicitHeight → height → cap → implicitHeight).
    //
    // On the owner's 1920x1080 panel the ZONE is still:
    //
    //     zone     1080 - 84 (the bar's exclusive zone)          =  996
    //
    // but the mapped layer is `winH`, not the zone. Empty Clipboard is
    // chrome + one line, then the window floors at the packed rail so
    // ten 40 px icons still fit. A long Quick/Sound list still stops at
    // `panelCap`. Sound, Media, Calendar, System and Quick overflow a
    // short card and scroll.
    //
    // THE ARITHMETIC NEVER READS `panel.height` or `root.height`. Every
    // term below is the panel's WIDTH (a constant 344), the SCREEN minus
    // the bar, or a Flickable's column implicitHeight at that fixed width:
    //
    //   * a Flickable section publishes `contentHeight`, which is its column's
    //     implicitHeight at a width the panel fixes. Never its own height.
    //   * a ColumnLayout section publishes NO `contentHeight` -- that is the
    //     signal that it holds a fillHeight child and wants the whole body.
    //     MAX_VALUE clamps to `panelCap`, i.e. a long list still stops at
    //     the derived ceiling rather than eating the desktop.
    //   * `sideHeaderRow` / `sideSectionTitle` report implicit heights, which
    //     a Layout computes from its children, not from the space it is given.
    //
    // `zoneH` in `panelCap` is the screen minus the bar, not this window.
    // Nothing in the chain reads `panel.height` or `root.height`.
    readonly property int panelChrome:
        Theme.s6 * 2                       // the column's own margins
        + sideHeaderRow.implicitHeight     // avatar + name + power
        + 1                                // hairline under the header
        + sideSectionTitle.implicitHeight  // the section's name
        + 1                                // hairline above the footer
        + 32                               // the footer strip (TRK-1801)
        + Theme.s5 * 5                     // six children, five gaps
    // `as Flickable` and NOT `sideBody.item.contentHeight`: reading a member
    // off a bare `Loader.item` is exactly the shape gate `audit.sh` fails on
    // by name (missing-property — the warning that shipped the unusable
    // 2026.08.07 ISO), because qmllint sees a QObject and cannot know what is
    // on it. The cast is also the DISCRIMINATOR this needs for free: it
    // resolves to the section itself when the section is a Flickable and to
    // null when it is a ColumnLayout, which is precisely the two cases.
    //
    // Launcher.qml § the Wake records a typed cast off `Loader.item`
    // resolving to null at runtime and silently killing a feature, so the
    // failure direction is chosen deliberately: null means MAX_VALUE means
    // `panelCap`, never a collapsed stub. A cast that misfires costs the
    // compact empty-state, never the panel.
    readonly property Flickable sideSection: sideBody.item as Flickable
    readonly property real bodyNatural:
        !root.sideSection || root.sideSection.contentHeight <= 0
        ? Number.MAX_VALUE : root.sideSection.contentHeight
    readonly property int zoneH:
        Math.max(1, (screen ? screen.height : 1080) - Theme.chromeH)
    readonly property int panelAvail: root.zoneH - Theme.s5 * 2
    // panelFloor is the cap's lower bound on a short window, NOT a min-height
    // for empty cards. TRK-2901 used panelW so a stub still read as a square
    // card; on the ISO that left empty Clipboard / Notifications as a 344 px
    // hollow with one line of type. TRK-2988: empty is chrome + contentHeight.
    // Capture is already 177 + 172 = 349 and is unchanged. Lists grow to
    // panelCap. Nothing here reads panel.height — same y=-59 discipline.
    readonly property int panelFloor: root.panelW
    // TRK-2987 · THE CEILING IS NO LONGER THE ZONE, AND THE WINDOW
    // FOLLOWS THE CARD. `panelAvail` is 996 − 2×s5 = 972 on 1080p. Owner
    // 2026-08-24: "Right side Bar/Flyout the length is too long." Cap is
    // zone minus one panel-width: 996 − 344 = 652. Empty clipboard is
    // chrome + the empty-state line, not the 344 floor. The mapped layer
    // is `winH`, not 996 — dropping top+bottom anchors so Hyprland does
    // not keep a 400×996 hit plate.
    readonly property int panelCap: Math.min(root.panelAvail,
                                             Math.max(root.panelFloor,
                                                      root.zoneH - root.panelW))
    readonly property int panelH:
        Math.min(root.panelCap, root.panelChrome + root.bodyNatural)
    // Ten 40 px rail tiles, s2 between, s6 column pad, s5 rail air.
    // A 188 px empty card cannot host that column, so the window floors
    // here; the card stays `panelH` and the mask does not claim the
    // slack in the 344-wide column.
    readonly property int railPacked:
        Theme.s5 * 2 + Theme.s6 * 2
        + root.sections.length * 40
        + Math.max(0, root.sections.length - 1) * Theme.s2
    readonly property int winH: root.expanded
        ? Math.max(root.panelH, root.railPacked) : root.railPacked

    // Which section is showing. -1 is collapsed: the rail alone.
    property int active: -1
    readonly property bool expanded: root.active >= 0

    // ── HIDDEN UNTIL ASKED FOR (owner, 2026-08-08) ───────────────────
    // The header above argues the rail should be permanent, and it argues it
    // well. The owner has now decided otherwise — "the slide out, that too is
    // suppose to be hidden then when i hoover over it or whatever then it
    // appers" — and chose edge-hover AND hotkey together when asked. His call;
    // the reasoning above is kept rather than deleted because the two risks it
    // names are real and this is where they will show up.
    //
    // The mitigations for those two risks:
    //   · accidental triggers — the trigger strip is `edgeW` px, the pointer
    //     must REST there for `revealDelay` before anything moves, and a
    //     scrollbar flick does not survive that. Retraction has its own grace
    //     period so crossing a gap does not slam it shut.
    //   · discoverability — Super+A already exists and already works
    //     (hyprland.conf: `qs ipc call nyxus flyout`), so the keybind half of
    //     his answer needed no new code, only this comment so the next reader
    //     knows it is deliberate.
    readonly property int  edgeW:        4     // the invisible hover strip
    readonly property int  revealDelay:  180   // rest this long before it opens
    readonly property int  retractDelay: 420   // grace before it hides again
    property bool revealed: false
    // Opening a section by any route must also bring the rail out, or the
    // hotkey would expand a panel hanging off an invisible handle.
    onExpandedChanged: if (root.expanded) root.revealed = true
    readonly property string activeKey: root.active >= 0
                                        ? root.sections[root.active].key : ""

    // `Sys.notifications` is Quickshell's ObjectModel, whose array lives on
    // `.values` — reading `.length` off the model itself returns undefined,
    // and `undefined > 0` is false, so the badge would never appear and
    // nothing would say why. Both shapes are accepted because a binding that
    // throws takes the ENTIRE surface down in QML, not just the one property;
    // the same reasoning Sys.btDevices records for the Bluetooth list.
    readonly property int notifCount: {
        const n = Sys.notifications;
        if (!n) return 0;
        if (n.values !== undefined && n.values !== null) return n.values.length;
        if (n.length !== undefined) return n.length;
        return 0;
    }

    // The two most recent notifications, for Quick's glance. Reads through
    // the same two shapes `notifCount` accepts and for the same reason: a
    // binding that throws takes the ENTIRE surface down in QML.
    readonly property var recentNotifs: {
        const n = Sys.notifications;
        if (!n) return [];
        const a = (n.values !== undefined && n.values !== null) ? n.values : n;
        if (!a || a.length === undefined) return [];
        return Array.prototype.slice.call(a, 0, 2);
    }

    // ── BRIGHTNESS · ONE WRITER, TWO SLIDERS (TRK-2403) ──────────────
    // The mockup's overview pane carries Volume and Brightness, and the
    // Sound section keeps them too. TRK-980's rule is that there is exactly
    // ONE writer to the backlight for the whole build — so the writer, the
    // value and the probe live HERE, at panel scope, and both sliders bind
    // to them. Two sliders each owning a coalescing Process would be two
    // writers racing, which is the defect TRK-980 was opened to remove.
    property real brightness: 0.7
    property bool hasBacklight: false
    function setBrightness(v) {
        root.brightness = v;
        brightSet.want(Math.round(v * 100));
    }
    Process {
        id: brightSet
        running: false
        property int pending: -1
        function want(pct) {
            pending = pct;
            if (!running)
                kick();
        }
        function kick() {
            if (pending < 0)
                return;
            // TRK-980: `nyxus-brightness` picks the backlight-class device
            // with the largest max_brightness (never brightnessctl's own
            // first-found pick, which on the 08-20 Alienware boot drove the
            // panel dark at 100%), clamps to a floor, and logs
            // device/max/requested/applied to stderr.
            command = ["nyxus-brightness", "set", String(pending)];
            pending = -1;
            running = true;
        }
        stderr: StdioCollector {
            onStreamFinished: {
                var m = String(this.text).trim();
                if (m !== "")
                    console.warn("SidePanel: brightness — " + m);
            }
        }
        // `running` flips false when the helper exits — that is the "done,
        // run the newest value" signal. Not onExited: qmllint cannot resolve
        // its ExitStatus parameter here and this file must not gain a
        // warning (TRK-980 acceptance 4).
        onRunningChanged: {
            if (!running)
                brightSet.kick();
        }
    }
    // Read the real backlight when the panel is brought out — event-driven,
    // never a poll. `get` prints the percent of the SAME device the writer
    // uses; with no backlight it prints nothing, and `hasBacklight` stays
    // false so neither slider offers a control that does nothing.
    Process {
        id: brightGet
        command: ["nyxus-brightness", "get"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var n = parseInt(this.text.trim());
                if (!isNaN(n)) {
                    root.brightness = n / 100;
                    root.hasBacklight = true;
                }
            }
        }
    }
    onRevealedChanged: if (root.revealed) brightGet.running = true

    // 2026-08-19 · owner: glacier/ice chrome only, drop rose.
    readonly property color iceInteractive: Theme.paintLayers.glacier[0]
    readonly property color icePrimary:     Theme.paintLayers.glacier[5]
    readonly property color iceHairline:    Theme.lookSeam
    // Owner 2026-08-19 palette map: magma = record / destructive;
    // violet = notifications / unread. Ice stays on rest / hover / Settings.
    readonly property color magmaInteractive: Theme.paintLayers.magma[0]
    // TRK-2935 · the RESTING danger rung, the pair to magmaInteractive above.
    // `SetButton` names these `markDanger` / `markDangerCap` and orders them
    // rest -> hover; the flyout's destructive text links now use the same two
    // so a magma control reads the same wherever it sits.
    //
    // ONLY magma[5] AND magma[0] MAY BE A MARK. magma[1]-[4] are GROUND
    // stops: measured against this panel's real composite bed (rgb 57,40,78,
    // sampled from the render, brighter than a card body because the panel
    // is translucent over the wallpaper) magma[4] `#a33214` is 1.90:1 and
    // magma[1] `#7a1e0c` is 1.27:1, against a 3:1 mark floor. magma[5] is
    // 5.06:1 and magma[0] is 6.69:1. Putting a ground rung on a mark is the
    // `#891955` failure AGENTS.md records.
    readonly property color magmaPrimary:     Theme.paintLayers.magma[5]
    // ── TRK-2406 · UNREAD LEAVES VIOLET ──────────────────────────────
    // SUPERSEDED, and by a later ruling from the same person. The 08-19 map
    // put notifications on violet; the 2026-08-22 redesign rules are "ONE
    // ladder — glacier does all of it" and "NO PURPLE, per the owner ruling
    // to ship the 87da09fe bake palette", and the mockup draws the unread
    // bar in `--gl-0` with amber and crimson reserved for warn and critical.
    //
    // The two names stay, pointed at glacier, rather than being deleted at
    // seven call sites: the SEMANTIC ("this is the unread rung") is still
    // real and still wanted, it is only the hue that the newer ruling
    // changed. Critical is untouched — it was magma on 08-19 and it is
    // crimson in the mockup, which is the same thing said twice.
    readonly property color unreadInteractive: Theme.paintLayers.glacier[0]
    readonly property color unreadPrimary:     Theme.paintLayers.glacier[5]

    // Sections, in rail order. `key` is what a bar glyph asks for through
    // Bus.openFlyoutAt — see the alias map beside the Connections below.
    readonly property var sections: [
        { key: "quick",         icon: "", title: qsTr("Quick")         },
        { key: "sound",         icon: "", title: qsTr("Sound")         },
        { key: "network",       icon: "", title: "Wi-Fi"         },
        { key: "bluetooth",     icon: "", title: "Bluetooth"     },
        { key: "notifications", icon: "", title: qsTr("Notifications") },
        { key: "clipboard",     icon: "", title: qsTr("Clipboard")     },
        { key: "capture",       icon: "", title: qsTr("Capture")       },
        { key: "system",        icon: "", title: qsTr("Power")          }
    ]

    // The names the rest of the shell has sent since WIP-101, mapped to rail
    // sections. The FLYOUT owned this mapping when it owned the layout; the
    // layout lives here now, so the map does too. An unknown name opens the
    // panel at Quick rather than guessing — an unknown section is a wiring
    // bug, and opening somewhere arbitrary would hide it.
    readonly property var sectionAliases: ({
        "quick":         "quick",
        "controls":      "quick",
        "volume":        "sound",
        "output":        "sound",
        "sound":         "sound",
        "brightness":    "sound",
        "wifi":          "network",
        "network":       "network",
        "bluetooth":     "bluetooth",
        "media":         "media",
        "notifications": "notifications",
        "calendar":      "calendar",
        "day":           "calendar",
        "clipboard":     "clipboard",
        "capture":       "capture",
        "battery":       "system",
        "machine":       "system",
        "system":        "system"
    })

    function show(i) {
        // Same icon twice collapses. One control, both directions.
        root.active = (root.active === i) ? -1 : i;
        // WIP-640(d): re-ask whether ~/.face exists as the panel opens, so
        // the header avatar keeps the "changed in Settings, shown next open"
        // behaviour its `cache: false` was written for.
        if (root.active >= 0)
            Sys.refreshFace();
        // Reflect into the Bus so every glyph bound to flyoutOpen still
        // lights, and so Bus.openFlyoutAt's same-section-closes logic keeps
        // working. Writing the value the Bus already holds does not re-emit
        // changed, so this cannot loop through the Connections below.
        Bus.flyoutSection = root.expanded ? root.activeKey : "";
        Bus.flyoutOpen = root.expanded;
    }
    function openKey(k) {
        const raw = String(k || "");
        // Those subjects already have a real window. Opening them here
        // was a second copy of Media / Calendar.
        if (raw === "media") {
            root.collapse();
            Bus.openMedia();
            return;
        }
        if (raw === "calendar" || raw === "day") {
            root.collapse();
            Bus.openCalendar();
            return;
        }
        const key = root.sectionAliases[k] || "quick";
        for (let i = 0; i < root.sections.length; i++) {
            if (root.sections[i].key === key) {
                root.active = i;
                Bus.flyoutSection = key;
                Bus.flyoutOpen = true;
                root.revealed = true;
                return;
            }
        }
    }
    function collapse() {
        root.active = -1;
        Bus.flyoutSection = "";
        Bus.flyoutOpen = false;
    }

    // Glass Settings via Bus.openSettings (emit-only, TRK-3090). Never exec
    // PATH `nyxus-settings` — on this host that is NYXUS Panel (stars + orbs).
    function openQmlSettings(key) {
        root.collapse();
        Bus.openSettings(key || "");
    }

    // The panel answers the same Bus traffic the Flyout answered, so nothing
    // that opens quick settings had to learn a new name. Guarded on the
    // CURRENT state so the write-backs in show()/collapse() are no-ops when
    // they arrive back here.
    Connections {
        target: Bus
        function onFlyoutOpenChanged() {
            if (Bus.flyoutOpen && !root.expanded)
                root.openKey(Bus.flyoutSection || "quick");
            else if (!Bus.flyoutOpen && root.expanded)
                root.active = -1;
        }
        // Re-aiming an already-open panel: Wi-Fi then Bluetooth without a
        // close in between. onFlyoutOpenChanged does not fire for that.
        function onFlyoutRetarget(section) {
            if (Bus.flyoutOpen)
                root.openKey(section);
        }
    }

    // Nothing polls /proc unless somebody is looking at the numbers. Same
    // Binding the Launcher carries for its own vitals readouts.
    Binding {
        target: Sys
        property: "vitalsActive"
        value: true
        // TRK-2202: Quick now carries a THIS MACHINE meter block, so the
        // probe has to be live for Quick as well or those two meters would
        // sit at zero — a dead readout is worse than no readout.
        when: root.expanded && root.activeKey === "system"
    }

    Connections {
        target: root
        function onActiveKeyChanged() {
            if (root.activeKey === "network")
                Sys.wifiScan();
            if (root.activeKey === "bluetooth")
                Sys.btSetScanning(true);
            else
                Sys.btSetScanning(false);
        }
    }
    Connections {
        target: Sys
        function onWifiOnChanged() {
            if (root.activeKey === "network" && Sys.wifiOn)
                Sys.wifiScan();
        }
        function onBtOnChanged() {
            if (root.activeKey === "bluetooth")
                Sys.btSetScanning(Sys.btOn);
        }
    }

    property string wifiJoinSsid: ""
    property string wifiJoinPass: ""
    property string wifiJoinErr: ""
    function wifiJoin() {
        if (!root.wifiJoinSsid.length)
            return;
        root.wifiJoinErr = "";
        if (root.wifiJoinPass.length)
            wifiJoinProc.command = ["nmcli", "-w", "20", "device", "wifi",
                                    "connect", root.wifiJoinSsid,
                                    "password", root.wifiJoinPass];
        else
            wifiJoinProc.command = ["nmcli", "-w", "20", "device", "wifi",
                                    "connect", root.wifiJoinSsid];
        wifiJoinProc.running = false;
        wifiJoinProc.running = true;
    }
    Process {
        id: wifiJoinProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var t = String(this.text).trim();
                if (t.length && t.toLowerCase().indexOf("error") >= 0)
                    root.wifiJoinErr = t;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                var t = String(this.text).trim();
                if (t.length)
                    root.wifiJoinErr = t;
            }
        }
        onRunningChanged: {
            if (!running && root.wifiJoinErr.length === 0)
                root.wifiJoinSsid = "";
        }
    }

    // Click on anything that is not this surface collapses the panel — the
    // same grab the Flyout used. The rail is part of this window, so rail
    // clicks are inside the grab and unaffected.
    HyprlandFocusGrab {
        windows: [root]
        active: root.expanded
        onCleared: root.collapse()
    }

    // ── the surface ──────────────────────────────────────────────────
    // Right edge only. Width is a constant 400, so dropping top+bottom does
    // not re-negotiate width. An unanchored vertical axis is centred by the
    // compositor (same rule Clock.qml uses on the horizontal). Height is
    // `winH` — the card, floored at the packed rail — not the 996 zone.
    anchors { right: true }
    implicitWidth: root.railW + root.panelW + root.gap
    implicitHeight: root.winH
    // The rail reserves its own strip so a maximised window stops beside it
    // rather than under it. The PANEL does not — it is transient, and pushing
    // every window sideways each time it opens would be unusable.
    // Nothing is reserved while it is hidden — a maximised window gets the
    // whole screen, which is the point of hiding it. It reclaims its strip only
    // while it is actually out.
    exclusiveZone: root.revealed ? root.railW : 0
    // Live 08-20 15:38: window was y=0 h=912, bar at y=996. `margins.bottom:
    // chromeH` (84) stacked on the bar's exclusive zone (also 84), so the
    // pane sat 12 px from the top and 96 px from the bar. exclusiveZone 0
    // still *considers* other zones (wlr: only -1 ignores them), and
    // ExclusionMode.Ignore lost to the 0/46 binding. Take chromeH from the
    // bar once; panel/rail Theme.s5 is the equal 12 px air, same as Start.
    margins.bottom: 0
    color: "transparent"
    visible: !Prefs.arcadeMode
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "nyxus-side"
    WlrLayershell.keyboardFocus: root.expanded ? WlrKeyboardFocus.OnDemand
                                               : WlrKeyboardFocus.None

    // Right-anchored, vertically centred. SkyBehind uses this so the
    // Headliner lattice matches the chips on the same screen.
    readonly property int winScreenX: (screen ? screen.width : 1920) - implicitWidth
    readonly property int winScreenY: {
        var sh = screen ? screen.height : 1080
        return Math.round((sh - implicitHeight) / 2)
    }

    // Only the rail takes input while collapsed. Without this the invisible
    // 340px of panel would eat every click down the right side of the screen —
    // the same class of bug Frame.qml's empty mask exists to avoid.
    // Expanded: union of the card and the rail, never the slack above/below
    // a short card in the 344-wide column (that slack was the 400×996 hit
    // plate). Hidden: the `edgeW` strip on this short window, not the zone.
    mask: Region {
        Region { item: root.expanded ? panel : null }
        Region { item: root.revealed ? rail : null }
        Region {
            x: root.width - root.edgeW
            y: 0
            width: root.revealed ? 0 : root.edgeW
            height: root.height
        }
    }

    // ── the edge trigger ─────────────────────────────────────────────
    // Sits inside the masked strip while hidden. A HoverHandler rather than a
    // MouseArea so it never swallows a click that was meant for the window
    // underneath.
    Item {
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        width: root.edgeW
        HoverHandler {
            id: edgeHover
            enabled: !root.revealed
            onHoveredChanged: if (hovered) revealTimer.restart(); else revealTimer.stop()
        }
    }
    Timer {
        id: revealTimer
        interval: root.revealDelay
        onTriggered: root.revealed = true
    }

    // While it is out, keep it out as long as the pointer is anywhere on the
    // rail or the panel; retract on a grace period once it leaves.
    HoverHandler {
        id: surfaceHover
        enabled: root.revealed
        onHoveredChanged: {
            if (hovered) retractTimer.stop();
            else if (!root.expanded) retractTimer.restart();
        }
    }
    Timer {
        id: retractTimer
        interval: root.retractDelay
        // An expanded panel is a deliberate act and outlives the pointer; it
        // closes by click-away or by the same control that opened it.
        onTriggered: if (!root.expanded) root.revealed = false
    }
    // (The retract-on-collapse hook lives in the existing onActiveChanged
    // handler further down — QML allows only one handler per signal, and a
    // second declaration takes the whole config down with "Property value set
    // multiple times".)

    // Click anywhere outside to collapse.
    MouseArea {
        anchors.fill: parent
        enabled: root.expanded
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.collapse()
    }
    Item {
        anchors.fill: parent
        focus: root.expanded
        Keys.onEscapePressed: root.collapse()
    }

    // ══════════════════════════════════════════════════════════════════
    //  THE PANEL
    // ══════════════════════════════════════════════════════════════════
    Item {
        id: panel
        // Centred, not top-anchored: the rail's own icons were centred on the
        // owner's 2026-08-15 ruling ("centre all of these so the gap's evenly
        // through the top and bottom"), and a panel that grows out of the
        // rail's middle is the same ruling applied to the thing the rail
        // opens. A short section is now a card beside the switcher instead of
        // a column of air.
        anchors.verticalCenter: parent.verticalCenter
        width: root.panelW
        height: root.panelH
        // Snaps while hidden (so opening never plays a resize), animates while
        // out (so switching sections reads as one surface changing shape).
        Behavior on height {
            enabled: panel.visible
            NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutCubic }
        }
        // Slides out from behind the rail rather than fading in place: the
        // panel should read as coming OUT OF the rail, which is what makes the
        // rail read as its handle.
        x: root.expanded ? 0 : root.panelW * 0.35
        opacity: root.expanded ? 1 : 0
        visible: opacity > 0.004
        Behavior on x { NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.durQuick } }

        // TRK-3082: overlay plates sit on WINDOWS. Widget chips sit on
        // the sky, so panelMid+swell reads solid there and see-through
        // here. Opaque elevated `#071318` was the first cut and made a
        // dark teal box. SkyBehind is the chip's actual backdrop, cropped
        // into this pane; the glass above it stays WidgetChip's recipe.
        SkyBehind {
            anchors.fill: parent
            live: panel.visible
            paneScreenX: root.winScreenX + panel.x
            paneScreenY: root.winScreenY + panel.y
            screenW: root.screen ? root.screen.width : 1920
            screenH: root.screen ? root.screen.height : 1080
            radius: Theme.r3
        }
        Pane {
            anchors.fill: parent
            elevation: 2
            fill: Theme.panelMid
            radiusTL: Theme.r3
            radiusTR: Theme.r3
            radiusBR: Theme.r3
            radiusBL: Theme.r3
        }
        // ── the living paint (Launcher.qml § the living paint is the twin) ──
        // The Flyout had NO paint at all — which is why it opened as an empty
        // transparent rectangle you could read the desktop through, while the
        // bar six inches below it was alive. The owner's 2026-08-09 ruling for
        // the Start Menu ("anywhere you move your mouse the swirls activate")
        // is a ruling about the build's surfaces, not about one file, so the
        // Flyout gets the same treatment and the same levels.
        //
        // Under the GlassEdge and the ReactiveEdge on purpose: the paint is
        // this surface's BODY, and the edges are what say it is a pane. Paint
        // over the rim would drown both.
        //
        // ── the Swell body, MOVED UNDER THE PAINT (WIP-265) ──────────
        // WIP-259 gave `GlassEdge` an opt-in `body` and set it to 1 here to
        // stop windows reading through the pane. The density was right and
        // it stays exactly as it was — but `GlassEdge` draws ABOVE this
        // Loader, so the darkening landed on top of the living paint and
        // dimmed the thing it was never aimed at. The owner's report was
        // "the side flyout the swirls are very faint … put it back to
        // exactly how they were".
        //
        // The three lines directly above this block already state the rule
        // that resolves it: the paint is this surface's BODY and the edges
        // are what say it is a pane. A legibility darkener is not an edge —
        // it is ground — so it belongs UNDER the paint, blocking the window
        // while the paint plays over it. Same tokens, same three stops,
        // same composited density as WIP-259 measured; only the depth
        // changed, and `GlassEdge.body` drops to 0 so the density is not
        // applied twice.
        CutRect {
            anchors.fill: parent
            radius: Theme.r3
            gradTop:  Theme.swellGroundTop
            gradMid:  Theme.swellGroundMid
            gradFoot: Theme.swellGroundFoot
        }

        // ⚠ Loaded ON DEMAND — a ShaderEffectSource in a never-exposed window
        // segfaults the scene graph.
        // ── OWNER RULING 2026-08-24 · the panel's paint is OFF ───────────
        // He asked whether the swirls belong in the side panel and the flyout
        // or only in the bottom bar and the toggles/buttons, and approved the
        // second. The reasons were already written down in this tree:
        //   · `theme/accent.json` `_swirl` RULE 5 — "colour never goes behind
        //     text". SetIceFace.qml, SetButton.qml and SetChoice.qml each cite
        //     that rule as the reason their own swirl is masked away from the
        //     label. This one sat behind a whole panel of text and was the one
        //     place the rule was not honoured.
        //   · `SwirlChip.qml` — "the bar is THE one lit thing there (Bar.qml,
        //     WIP-265) and a wall of chips independently breathing would take
        //     that status away from it." Written about chips; it applies harder
        //     to a full page.
        //   · In a toggle the paint says THIS IS ON. On a panel it says nothing,
        //     which is the decorative-colour case his 08-23 ruling killed.
        //   · Cost: this is a full fluid solver per open panel.
        // MEASURED, this session (docs/proof/falloff-0824/): the flyout body is
        // 88-96% opaque to the wallpaper — `panelTop/Mid/Deep` 0.27/0.34/0.48
        // under `swellGround*` 0.84/0.89/0.93 gives a backdrop transmittance of
        // 11.7% / 7.3% / 3.6% top to foot. So the saturated plum he read as
        // "seeing the true design, the colours" behind the panel was never the
        // picture behind it: it was THIS, the drift slice at offset 0.45, drawn
        // ABOVE the ground with only the Glaze (alpha 0.05/0.012/0.13) over it.
        // The darkening falloff was never the thing that was missing.
        //
        // `active: false` rather than a deletion, which is the house form for
        // exactly this ruling — Launcher.qml's `cardSwirl` has carried the
        // owner's 08-20 "Start swirl stays off" the same way, and the baked ISO
        // ships that line. The numbers below stay as the measurement record for
        // the narrow-panel correction and the drift slice, and one line turns it
        // back on. `Prefs.swirlEnabled` is deliberately NOT repurposed: it still
        // gates the bar and the chips and SetPageAppearance.qml still writes it.
        Loader {
            id: sideSwirl
            anchors.fill: parent
            active: false   // owner 2026-08-24 — see the ruling above
            sourceComponent: Swirl {
                intensity: Prefs.swirlIntensity
                cornerRadius: Theme.r3
                // interactive TRUE, and this is what fixes the paint
                // vanishing on its own. Swirl's `_stimulus` is
                // `interactive && hover.hovered`, so with it false the field
                // was awake ONLY for lingerMs (12 s) after the last feedAt().
                // Open the menu, rest your hand, and twelve seconds later the
                // paint had decayed to nothing -- which is exactly what the
                // owner kept reporting: "working now", then "swirls are gone
                // again in the start menu". It was never the drift the second
                // time; it was the linger running out.
                // The Swirl fills the card exactly here (unlike the bar, whose
                // paint band is smaller than its chrome zone -- the reason
                // Bar.qml passes false), so its own HoverHandler covers the
                // right area. HoverHandler is passive and does not block, so
                // every tile, row and field keeps its own hover. The Wake
                // below still feeds position; both write the same _pxCur, so
                // there is no double dye -- one stroke per frame either way.
                interactive: true
                playIntroOnLoad: true
                // Launcher.qml § the levels carries the full reasoning and the
                // measurements. Same numbers, because this is the same
                // material at the same scale — a page, not the bar's clipped
                // strip — and a second set of tuning knobs is how the surfaces
                // drifted apart in the first place.
                introStrength: 0.22
                opacity: 0.85
                exposure: 0.85
                // See Launcher.qml: a parked pointer injects nothing, so the
                // ambient stirrers have to hold the field up between gestures.
                decayRate: 0.38
                ambientAmp: 0.95
                curlAmp: 0.64
                force: 4400
                simShort: 128
                bloom: 0.80
                // ── the narrow-panel correction ──────────────────────
                // The Start Menu's levels applied here verbatim still came out
                // a pink slab (measured: mean luminance 114.5 against the Start
                // Menu's 34.6 on the same numbers). The levels were not the
                // fault — the GEOMETRY is.
                //
                // `impulseRadius` is in NORMALISED units, so the same 0.245
                // that is a modest dab across a 1040 px page is half the width
                // of a 430 px column. Every splat, every ambient stirrer and
                // the intro dollop were each covering most of the panel, so the
                // dye had nowhere to be thin and the field went uniform — the
                // same "no dark to be bright against" failure the Start Menu
                // hit from the other direction.
                //
                // Scaled to the panel rather than guessed: 0.245 × (430/1040)
                // ≈ 0.10, rounded to 0.11 so a stroke still reads as a ribbon
                // and not a thread. Injection drops with it, because a smaller
                // splat repeated along a stroke still accumulates.
                // Owner, 2026-08-09: "flyout needs the swirls smaller though."
                // 0.11 was scaled off the panel's WIDTH, which was the wrong
                // axis — swirl_splat.frag's gauss() aspect-corrects x only, so
                // a splat is measured in units of HEIGHT. Sigma is roughly
                // impulseRadius/√2 × height, so 0.11 on this 890 px column was
                // ~69 px against the Start Menu's ~40 px: bigger than the
                // surface he was comparing it to, not smaller.
                // 0.065 × 890 / √2 ≈ 41 px — the Start Menu's strand, matched
                // on the axis that actually governs it.
                impulseRadius: 0.065
                injectGain: 0.20
                // HORIZON §2.2: hue is a function of horizontal position. The
                // Flyout lives at the RIGHT edge of the screen, where the sweep
                // is plum — the opposite end from the Start Menu on the left.
                // That is the coordinate system doing its job: you can tell
                // where a surface came from by the colour of its light.
                // First cut used sweepLo 0.62 with no upper bound and the panel
                // came out a milky pink slab at levels that were CORRECT on the
                // Start Menu. Not a brightness fault — a slice fault.
                // swirl_splat.frag's ramp ends "...plum -> rose -> pale rose";
                // starting at 0.62 and running to 1.0 spends the whole panel in
                // the top two stops, which are the palest in the palette, so
                // every filament was drawn in near-white and there was nothing
                // dark left for it to be a filament against.
                // 0.52 → 0.88 keeps the plum identity this end of the screen
                // owns and stops before the pale end.
                // ── the Drift (Theme.qml § THE DRIFT) ────────────────
                // Was the fixed 0.52 → 0.88 plum slice reasoned about just
                // above. The owner has since asked for the colour to keep
                // moving through the theme, so the slice is the shell-wide
                // drift read at THIS surface's offset. 0.45 is nearly half the
                // ramp away from the Start Menu's 0.0, which is what keeps the
                // two panels different colours from each other at every
                // instant while both are always changing — the half of
                // HORIZON §2.2 that survives the ruling.
                sweepLo: Theme.lookMagma ? 0.0 : Theme.driftLo(0.45)
                sweepHi: Theme.lookMagma ? 1.0 : Theme.driftHi(0.45)
                sweepGamma: 1.0
                audioBass: Beat.bass
                audioMid: Beat.mid
                audioHigh: Beat.high
                audioPulse: Beat.pulse
                musicActive: Beat.hot
            }
        }

        GlassEdge {
            anchors.fill: parent
            radiusTL: Theme.r3; radiusTR: Theme.r3
            radiusBR: Theme.r3; radiusBL: Theme.r3
            body: 0                     // WIP-265 — the Swell body moved UNDER the paint; see the Rectangle above the swirl Loader
            wash: 0
            // WidgetChip loud rung (TRK-3081). Default edging 1.0 is the
            // full bar lip; chips sit at 0.85 so the plate stays laid back.
            edging: 0.85
        }

        // The living border (owner ruling 2026-08-09) — see ReactiveEdge.qml.
        ReactiveEdge {
            livingEdgeEnabled: false   // owner 2026-09-07: not the side bar
            radiusTL: Theme.r3; radiusTR: Theme.r3
            radiusBR: Theme.r3; radiusBL: Theme.r3
        }

        // The mirror rim. 08-14 "system wide" still holds — the WEIGHT is
        // WidgetChip's swell rung (TRK-3081), not the old page-scale 20/1.0
        // that made this plate shinier than the chips beside it.
        MirrorEdge {
            radiusTL: Theme.r3; radiusTR: Theme.r3
            radiusBR: Theme.r3; radiusBL: Theme.r3
            depth: 10
            strength: 0.58
        }

        // ── 4 · THE SEAM (TRK-3372) ──────────────────────────────────────
        // 1 px glacier[4]. The panel's five section cards went onto
        // `SetSlab` in TRK-3370 and each grew a seam; the panel they sit ON
        // did not, so the cards were edged and their host was not. Same
        // rung, SetSlab's resting alpha.
        CutRect {
            anchors.fill: parent
            radius: Theme.r3
            color: "transparent"
            borderWidth: Theme.lookOutlineW
            borderColor: Theme.soften(Theme.lookSeam, 0.45)
        }

        // Owner 2026-08-19: edge motion when the flyout OPENS — same
        // GlassMaterial as Start (`focused:` is the on-switch). On the
        // PANEL only, never the 46 px rail (a full rim there IS the face).
        // Recipe: shell/GlassMaterial.qml § USE. Bar is BQ; do not copy here.
        GlassMaterial {
            anchors.fill: parent
            focused: root.expanded
            driftOffset: 0.45
            paneScreenX: (root.screen ? root.screen.width : 1920)
                         - root.implicitWidth + panel.x
            paneScreenY: panel.y
            screenW: root.screen ? root.screen.width : 1920
            screenH: root.screen ? root.screen.height : 1080
            radiusTL: Theme.r3
            radiusTR: Theme.r3
            radiusBR: Theme.r3
            radiusBL: Theme.r3
        }

        // ── the Wake · the paint answers your hand anywhere on the panel ──
        // Bar.qml § the Wake, and the Start Menu's twin. Only feeds on REAL
        // movement: `pointChanged` also fires for velocity decay and frame
        // callbacks, and feeding a stationary pointer 60 times a second holds
        // the solver awake forever for nothing.
        property real _wakeX: -1
        property real _wakeY: -1
        // Typed for the same reason the Start Menu's is — see Launcher.qml
        // § the Wake. `Loader.item` is QObject, and an untyped feedAt() call
        // raises the exact warning class that cost the 2026.08.07 ISO.
        // A `var` for the reason Launcher.qml § the Wake now records: the
        // typed cast resolved to null at runtime and silently killed the Wake.
        property var paint: sideSwirl.item
        HoverHandler {
            onHoveredChanged: if (!hovered) { panel._wakeX = -1; panel._wakeY = -1; }
            onPointChanged: {
                if (!hovered || !Prefs.swirlEnabled || !panel.paint)
                    return;
                var px = point.position.x;
                var py = point.position.y;
                if (Math.abs(px - panel._wakeX) < 1.0 && Math.abs(py - panel._wakeY) < 1.0)
                    return;
                panel._wakeX = px;
                panel._wakeY = py;
                panel.paint.feedAt(px / Math.max(panel.width, 1),
                                   py / Math.max(panel.height, 1));
            }
        }

        // Swallow clicks so the collapse handler behind does not fire.
        MouseArea { anchors.fill: parent; onPressed: mouse => mouse.accepted = true }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.s6
            spacing: Theme.s5

            // ── header ───────────────────────────────────────────────
            RowLayout {
                id: sideHeaderRow
                Layout.fillWidth: true
                spacing: Theme.s4

                // The identity circle is a BUTTON, the same contract as the
                // Start menu's account tile (owner, 2026-08-14: clicking your
                // face anywhere takes you to the part of Settings where you
                // choose your name and photo): shows ~/.face when one is set,
                // rings on hover, and opens Settings ▸ Account through
                // Face opens QML Settings ▸ Account — same bind as Start.
                Item {
                    // TRK-2901: `width`/`height` on an item a layout manages is
                    // the undefined-behaviour case `scripts/audit.sh` greps the
                    // lint output for by name, and it costs a real number here:
                    // an item that sizes ITSELF contributes 0 to the RowLayout's
                    // implicitHeight, which is now the term `panelChrome` reads.
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34

                    CrystalGem {
                        anchors.fill: parent
                        visible: sideFace.status !== Image.Ready
                        hot: sideAvatarHover.hovered
                        on: false
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: sideFace.status === Image.Ready
                        radius: width / 2
                        color: "transparent"
                        border.width: sideAvatarHover.hovered ? 2 : 1
                        border.color: sideAvatarHover.hovered
                                      ? root.iceInteractive
                                      : root.iceHairline
                    }
                    // The account photo, cropped and masked to the circle —
                    // the Launcher's construction, at this header's size.
                    // cache:false so a picture changed in Settings shows on
                    // the next open, not a stale one.
                    Image {
                        id: sideFace
                        anchors.fill: parent
                        // WIP-640(d): asked only when the file is really
                        // there. Pointing an Image at a missing path is what
                        // logged an avatar warning on every shell start;
                        // Sys probes once and `Bus.flyoutOpen` re-probes, so
                        // a photo set in Settings still shows next open.
                        source: Sys.hasFace ? ("file://" + Sys.facePath) : ""
                        sourceSize.width: 68; sourceSize.height: 68
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        visible: false      // drawn masked below
                    }
                    MultiEffect {
                        anchors.fill: sideFace
                        source: sideFace
                        visible: sideFace.status === Image.Ready
                        maskEnabled: true
                        maskSource: sideFaceMask
                    }
                    Item {
                        id: sideFaceMask
                        anchors.fill: parent
                        layer.enabled: true
                        visible: false
                        Rectangle { anchors.fill: parent; radius: width / 2; color: "black" }
                    }
                    HoverHandler { id: sideAvatarHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: root.openQmlSettings("account")
                    }
                }
                Item {
                    Layout.fillWidth: true
                    implicitHeight: nameCol.implicitHeight
                    // TRK-2411 (same class as the Lintel's): the Item's height
                    // is bound to this column's, so this column may not be
                    // filled BY the Item — that is the child sizing the parent
                    // that sizes the child. Left / right / top only, and the
                    // intrinsic height stays intrinsic. Found by gate `13x3`
                    // reading the flyout for the shape it had just rejected in
                    // Lintel.qml, which is the point of computing a rule rather
                    // than checking one file.
                    ColumnLayout {
                        id: nameCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 0
                        Text {
                            text: userProc.name.length > 0 ? userProc.name : "…"
                            color: Theme.text
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tHead
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: userProc.host
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: root.openQmlSettings("account")
                    }
                }
                // Opens the real PowerMenu rather than reimplementing it —
                // that surface is the one ceremony in this system and there
                // must not be a second, quieter way to shut the machine down.
                Item {
                    // TRK-2901, the same correction as the avatar above.
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Text {
                        anchors.centerIn: parent
                        text: ""
                        color: powHov.hovered ? root.magmaInteractive : Theme.textMuted
                        font.family: Theme.fIcon
                        font.pixelSize: Theme.tHead
                        scale: powHov.hovered ? 1.14 : 1.0
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durQuick
                                easing.type: Easing.OutQuint
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.durQuick
                                easing.type: Easing.OutQuint
                            }
                        }
                    }
                    HoverHandler { id: powHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: { root.collapse(); Bus.togglePower(); } }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.iceHairline
            }

            Text {
                id: sideSectionTitle
                text: root.active >= 0 ? root.sections[root.active].title : ""
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                font.letterSpacing: Theme.trackMicro
                font.capitalization: Font.AllUppercase
            }

            // ── body ─────────────────────────────────────────────────
            Loader {
                id: sideBody
                Layout.fillWidth: true
                Layout.fillHeight: true
                active: root.expanded
                sourceComponent: {
                    switch (root.activeKey) {
                    case "quick":         return secQuick;
                    case "sound":         return secSound;
                    case "network":       return secNetwork;
                    case "bluetooth":     return secBt;
                    case "notifications": return secNotifs;
                    case "clipboard":     return secClip;
                    case "capture":       return secCapture;
                    case "system":        return secSystem;
                    default:              return null;
                    }
                }
            }

            // ── footer ───────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: root.iceHairline
            }
            Item {
                Layout.fillWidth: true
                // TRK-1801: `height` is not a layout hint. In a ColumnLayout this
                // row collapsed to 0 and its label rendered straddling the
                // hairline above it. Layout.preferredHeight is what the layout
                // actually reads.
                Layout.preferredHeight: 32
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("   Settings")
                    color: setHov.hovered ? Theme.text : Theme.textMuted
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tBody
                    scale: setHov.hovered ? 1.03 : 1.0
                    transformOrigin: Item.Left
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.durQuick
                            easing.type: Easing.OutQuint
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.durQuick
                            easing.type: Easing.OutQuint
                        }
                    }
                }
                HoverHandler { id: setHov; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        root.openQmlSettings("");
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════
    //  THE RAIL — 46px, the handle the panel comes out of
    // ══════════════════════════════════════════════════════════════════
    // ── IT HAS TO HIDE VISUALLY, NOT JUST STOP TAKING CLICKS ─────────────
    // `revealed` was wired into the input region, the exclusive zone and both
    // timers — and into nothing that PAINTS. `mask: Region` sets the input
    // region only; it does not clip what the surface draws. So the rail
    // rendered permanently while being clickable through a 4 px strip: you
    // could see ten icons and hit none of them, which is worse than either
    // state on its own and is exactly what the owner kept photographing after
    // asking for it to hide.
    //
    // Fixed by mirroring the panel's own pattern twelve lines up — slide plus
    // fade, driven off `revealed` the way the panel's is driven off
    // `expanded`. It travels its full width so it reads as leaving the screen
    // rather than dimming in place, and `visible` is gated on opacity so a
    // fully faded rail costs no compositing.
    Item {
        id: rail
        anchors { top: parent.top; bottom: parent.bottom }
        anchors.topMargin: Theme.s5
        anchors.bottomMargin: Theme.s5
        width: root.railW
        // Not anchored right: it has to be able to sit OFF the right edge.
        x: parent.width - root.railW + (root.revealed ? 0 : root.railW)
        opacity: root.revealed ? 1 : 0
        visible: opacity > 0.004
        Behavior on x { NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.durQuick } }

        // ── TRK-2404 · THE ONE THING THAT WELDS ──────────────────────────
        // The mockup's single geometric law: every surface floats clear and is
        // rounded on every FREE corner, and the one exception is this rail,
        // which meets the screen's own edge and squares off against it
        // (`.srail{border-radius:var(--r2) 0 0 var(--r2)}` — 14 on the left,
        // 0 on the right). It was r3 on all four, so it read as a floating
        // capsule parked NEAR the edge rather than as part of it, and the two
        // right-hand corners left a wedge of desktop showing through.
        //
        // A QML Rectangle carries ONE radius, so the right two corners are
        // squared by a filler strip `Theme.r2` wide carrying the identical
        // vertical gradient. Identical stops on the same axis means the seam
        // is invisible — this is not a patch over the gradient, it is the
        // same gradient continued.
        // TRK-3082: the PANEL crops the live sky. This 46 px handle is
        // too narrow for fibres to read, and it is mapped whenever the
        // rail is out — a second full-screen HeadlinerSky here would
        // run all session. True-black floor is the Headliner void.
        CutRect {
            anchors.fill: parent
            radius: Theme.r2
            color: "black"
        }
        Rectangle {
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: Theme.r2
            color: "black"
        }
        CutRect {
            anchors.fill: parent
            radius: Theme.r2
            color: Theme.panelMid
            borderWidth: 0
        }
        Rectangle {
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: Theme.r2
            color: Theme.panelMid
        }
        // The ground under the paint — the panel's own WIP-265 construction
        // at the rail's size, so the paint plays over density instead of
        // being dimmed by an edge drawn above it.
        CutRect {
            anchors.fill: parent
            radius: Theme.r2
            gradTop:  Theme.swellGroundTop
            gradMid:  Theme.swellGroundMid
            gradFoot: Theme.swellGroundFoot
        }
        Rectangle {
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: Theme.r2
            gradient: Gradient {
                GradientStop { position: 0.00; color: Theme.swellGroundTop }
                GradientStop { position: 0.50; color: Theme.swellGroundMid }
                GradientStop { position: 1.00; color: Theme.swellGroundFoot }
            }
        }
        // ── the living paint, ON THE RAIL (owner, 2026-08-15: "I also want
        // to add the swirls to the sidebar flyout — the bar before you click
        // on something to open it"). The panel's block above is the source;
        // only the geometry numbers differ, because a 46 px column is the
        // narrowest surface in the build and a splat is measured in units of
        // HEIGHT (see the panel's narrow-panel correction): the panel's 0.065
        // is a 41 px strand, wider than this whole rail, so the rail takes
        // 0.030 ≈ 19 px — a thread that fits the column it lives in.
        //
        // ⚠ Loaded ON DEMAND — a ShaderEffectSource in a never-exposed window
        // segfaults the scene graph (WIP-245); `rail.visible` is already
        // gated on the reveal fade, so a hidden rail costs nothing and the
        // loader tears down while the surface is still mapped.
        // OFF under the same 2026-08-24 ruling as the panel's paint — the full
        // reasoning sits above `sideSwirl`. The rail is the panel's own handle
        // and the two were deliberately given one drift offset (0.45) so they
        // read as one surface at two widths; leaving the 46 px column lit while
        // the page it summons is dark would break exactly that.
        Loader {
            id: railSwirl
            anchors.fill: parent
            active: false   // owner 2026-08-24 — see the ruling above sideSwirl
            sourceComponent: Swirl {
                intensity: Prefs.swirlIntensity
                cornerRadius: Theme.r2
                // interactive TRUE for the panel's reason: this paint fills
                // its surface exactly, so its own HoverHandler covers the
                // right area, and the handler is passive — every rail icon
                // keeps its own hover and tap.
                interactive: true
                playIntroOnLoad: true
                introStrength: 0.22
                opacity: 0.85
                exposure: 0.85
                decayRate: 0.38
                ambientAmp: 0.95
                curlAmp: 0.64
                force: 4400
                simShort: 64
                bloom: 0.80
                impulseRadius: 0.030
                injectGain: 0.20
                // Same drift offset as the panel it summons (0.45): the rail
                // and its panel are one surface at two widths, and HORIZON
                // §2.2 keys hue to HORIZONTAL position — both live on the
                // right edge, so they wear the same slice of the drift.
                sweepLo: Theme.lookMagma ? 0.0 : Theme.driftLo(0.45)
                sweepHi: Theme.lookMagma ? 1.0 : Theme.driftHi(0.45)
                sweepGamma: 1.0
                audioBass: Beat.bass
                audioMid: Beat.mid
                audioHigh: Beat.high
                audioPulse: Beat.pulse
                musicActive: Beat.hot
            }
        }
        // TRK-2404 — the free corners take r2; the two that meet the screen
        // edge take r0. Same law the Lintel obeys against the top edge.
        GlassEdge {
            anchors.fill: parent
            radiusTL: Theme.r2; radiusTR: Theme.r0
            radiusBR: Theme.r0; radiusBL: Theme.r2
            body: 0                     // WIP-265 — the Swell body moved UNDER the paint; see the Rectangle above the swirl Loader
            wash: 0
            edging: 0.85                // TRK-3081 WidgetChip loud rung
        }
        // The living border (owner ruling 2026-08-09) — see ReactiveEdge.qml.
        ReactiveEdge {
            livingEdgeEnabled: false   // owner 2026-09-07: not the side bar
            radiusTL: Theme.r2; radiusTR: Theme.r0
            radiusBR: Theme.r0; radiusBL: Theme.r2
        }

        // Small-card mirror: WidgetChip default zRole 1 (TRK-3081), not
        // SetCard 12/0.62. A 46 px column still cannot wear page-scale depth.
        MirrorEdge {
            radiusTL: Theme.r2; radiusTR: Theme.r0
            radiusBR: Theme.r0; radiusBL: Theme.r2
            depth: 10
            strength: 0.46
        }

        // ── 4 · THE SEAM (TRK-3372) ──────────────────────────────────────
        // 1 px glacier[4], on the rail's own mixed radii — rounded where it
        // is free, flush where it meets the panel — so the seam traces this
        // surface and not a different outline.
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            antialiasing: true
            topLeftRadius: Theme.r2
            topRightRadius: Theme.r0
            bottomRightRadius: Theme.r0
            bottomLeftRadius: Theme.r2
            border.width: 1
            border.color: Theme.soften(Theme.lookSeam, 0.45)
        }

        ColumnLayout {
            anchors.fill: parent
            // The mockup pads the rail 16 top and bottom and spaces its tiles
            // by 4: `.srail{padding:16 0; gap:4}`. It was 8 / 2.
            anchors.topMargin: Theme.s6
            anchors.bottomMargin: Theme.s6
            spacing: Theme.s2

            // Owner, 2026-08-15: the icons were "all pushed to the top and
            // there's a big gap below everything — center all of these so the
            // gap's evenly through the top and bottom." A filler above to
            // match the one below is what centers the group.
            Item { Layout.fillHeight: true }

            Repeater {
                model: root.sections
                delegate: Item {
                    id: railBtn
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    readonly property bool isOn: root.active === railBtn.index

                    // ── TRK-2405 · ON IS A GROUND, FOCUS IS A RING ────────
                    // ON fills glacier[3] at .34 and keeps the 2 px key bar.
                    // Hover is a glacier[0] rim only — not a pale fill.
                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.s2
                        anchors.rightMargin: Theme.s2
                        radius: Theme.r1
                        antialiasing: true
                        color: railBtn.isOn
                               ? Theme.soften(Theme.paintLayers.glacier[3], 0.34)
                               : "transparent"
                        border.width: btnHov.hovered && !railBtn.isOn ? 1 : 0
                        border.color: root.iceInteractive
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durQuick
                                easing.type: Easing.OutQuint
                            }
                        }
                        Behavior on border.width {
                            NumberAnimation {
                                duration: Theme.durQuick
                                easing.type: Easing.OutQuint
                            }
                        }
                    }

                    // The active mark is a bar of the sweep on the INNER edge.
                    // Position is carried by light at an edge, which is this
                    // build's whole premise; it now sits ON the ground rather
                    // than being asked to carry the state by itself.
                    Rectangle {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        width: 2
                        height: railBtn.isOn ? 22 : 0
                        radius: 1
                        color: root.icePrimary
                        Behavior on height {
                            NumberAnimation {
                                duration: Theme.durQuick
                                easing.type: Easing.OutQuint
                            }
                        }
                    }

                    Text {
                        id: railGlyph
                        anchors.centerIn: parent
                        text: railBtn.modelData.icon
                        color: railTap.pressed || railBtn.isOn ? root.iceInteractive
                               : (btnHov.hovered ? Theme.textMuted : Theme.textDim)
                        font.family: Theme.fIcon
                        font.pixelSize: Theme.tHead
                        scale: railTap.pressed ? 0.90
                             : (btnHov.hovered || railBtn.isOn ? 1.10 : 1.0)
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durQuick
                                easing.type: Easing.OutQuint
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.durQuick
                                easing.type: Easing.OutQuint
                            }
                        }
                    }
                    // The icons' mirrored fall (Reflection.qml) — the dock
                    // icons six inches away carry it; a rail is the same
                    // idea stood upright, and now it wears the same light.
                    Reflection {
                        anchors.top: railGlyph.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: railGlyph.width
                        height: railGlyph.height
                        Text {
                            anchors.fill: parent
                            text: railGlyph.text
                            font: railGlyph.font
                            color: railGlyph.color
                        }
                    }

                    // Unread badge. The cheapest way to make the COLLAPSED
                    // state carry information, which is what both IMG_0705 and
                    // IMG_0708 do and the reason a rail beats a hidden drawer.
                    // On the Notifications icon, now that it has its own
                    // section — it sat on Quick only while phase 1 had no
                    // notifications section to put it on.
                    Rectangle {
                        visible: railBtn.modelData.key === "notifications"
                                 && root.notifCount > 0
                        anchors { right: parent.right; top: parent.top }
                        anchors.rightMargin: Theme.s3
                        anchors.topMargin: Theme.s2
                        width: 6; height: 6; radius: 3
                        color: root.unreadPrimary
                    }

                    HoverHandler { id: btnHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: railTap; onTapped: root.show(railBtn.index) }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    // ══════════════════════════════════════════════════════════════════
    //  SECTIONS
    // ══════════════════════════════════════════════════════════════════

    // ── QUICK ────────────────────────────────────────────────────────
    // The Flyout's CONTROLS grid plus phase 1's own two. Airplane Mode reads
    // the real radios rather than a local boolean — the old version tracked
    // its own flag, so it showed Off after a shell restart with the radios
    // still down. Night Light is wlsunset, not gammastep: gammastep is not in
    // packages.x86_64 and never was, so that pill lit up and changed nothing;
    // wlsunset has no constant mode, so day and night are pinned one kelvin
    // apart. DND is handled in-process by Sys, because this shell IS the
    // notification daemon.
    Component {
        id: secQuick
        // ⚠ A GridLayout, and it MUST be a Layout — not the Flow this was.
        //
        // Every one of these pills was INVISIBLE on screen: the Quick section
        // drew its "QUICK" heading and then nothing at all, which is why the
        // Flyout opened as an empty transparent rectangle. TogglePill sizes
        // itself with `Layout.fillWidth` and `Layout.preferredHeight` (see
        // TogglePill.qml), and those are Layout ATTACHED PROPERTIES: they are
        // read by RowLayout/ColumnLayout/GridLayout and ignored by everything
        // else. `Flow` is a positioner, not a layout, so every pill fell back
        // to its implicit size — 0 × 0 — and the section rendered as air.
        //
        // ── TRK-2402 · WHAT QUICK IS, AND WHY IT IS NOW A COLUMN ──────────
        //
        // Photographed 2026-08-22 at 1920×1080 (docs/proof/flyout-0822/
        // before/before-flyout-quick-crop.png): seven pills occupied the top
        // 300 px of a 984 px panel and the remaining 610 px was EMPTY — a
        // measured 62% of the surface carrying nothing. That is what the
        // owner has been looking at, and no defect row named it, because
        // every individual control in it was correct.
        //
        // The mockup's Side-flyout tab draws the answer and states it twice
        // over: "It scrolls as one column", `.sp-body{gap:20}` with
        // `.grp{gap:12}` inside. Quick is the OVERVIEW pane — the eight
        // toggles, then sound and light, then now-playing, then the machine,
        // then what is waiting — and the rail still switches to a deeper,
        // single-subject section for each of those. The rail remains the
        // switcher (owner's standing ruling); what changed is that its first
        // stop is no longer three-fifths empty.
        //
        // The Loader resizes what it loads to its own (fill-height) size, so
        // a Flickable is what lets a column longer than the panel scroll
        // instead of being clipped — the same construction secCalendar uses,
        // and the fix for "Sound and System overflow silently" applied at the
        // one place every section now passes through.
        Flickable {
            id: quickRoot
            ScrollRail { flick: quickRoot }
            clip: true
            contentWidth: width
            contentHeight: quickCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: quickCol
                width: quickRoot.width
                // 20 BETWEEN sections; 12 inside each one. The mockup's
                // one grid, and the two numbers are not interchangeable:
                // equal gaps make five groups read as one list.
                spacing: Theme.s7

                // ── the eight toggles ────────────────────────────────
                // EIGHT, not seven. TRK-1801 closed the 151×62 hole by
                // giving Mute `columnSpan: 2` and wrote that inventing an
                // eighth toggle "would mean shipping a control with nothing
                // behind it". That was right about invention and wrong about
                // the inventory: `RecordWatch` is a shipped singleton with a
                // real `toggle()`, a real `active` read off
                // $XDG_RUNTIME_DIR/nyxus-record.pid, and its own HUD. The
                // mockup draws Record as a quick toggle for that reason. So
                // the eighth pill is not invented, it is the control this
                // build already has, and the grid closes on four full rows.
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: Theme.s4
                    rowSpacing: Theme.s4
                    TogglePill {
                        label: "Wi-Fi"; sub: Sys.wifiOn ? (Sys.wifiName || qsTr("Nearby")) : qsTr("Off")
                        icon: ""; active: Sys.wifiOn; tone: 0.0
                        onToggled: root.openKey("wifi")
                    }
                    TogglePill {
                        label: "Bluetooth"; sub: Sys.btOn ? qsTr("Nearby") : qsTr("Off")
                        icon: ""; active: Sys.btOn; tone: 0.15
                        onToggled: root.openKey("bluetooth")
                    }
                    TogglePill {
                        label: qsTr("Airplane"); sub: active ? qsTr("On") : qsTr("Off")
                        icon: ""; active: !Sys.wifiOn && !Sys.btOn; tone: 0.3
                        onToggled: {
                            // Going ON kills both radios; going OFF restores both.
                            var goingOn = !active;
                            Quickshell.execDetached(["sh", "-c",
                                "nmcli radio all " + (goingOn ? "off" : "on")]);
                            if (Sys.btAdapter)
                                Sys.btAdapter.enabled = !goingOn;
                        }
                    }
                    TogglePill {
                        // TRK-3154 — same Prefs key as SetPageDisplay. A local
                        // `property bool on` disagreed with Settings and did
                        // not survive a reload. Command matches applyNight().
                        label: qsTr("Night Light")
                        sub: SettingsStore.boolValue("display_nightlight", false)
                             ? qsTr("On") : qsTr("Off")
                        icon: ""
                        active: SettingsStore.boolValue("display_nightlight", false)
                        tone: 0.45
                        // audit-0908 / TRK-3966. This carried its own copy of
                        // the wlsunset command — the comment above says
                        // "Command matches applyNight()", which is the
                        // admission that there were two of them and nothing
                        // enforcing the match. There was a real difference,
                        // too: this copy swallowed the "wlsunset is not
                        // installed" message that the page's copy printed.
                        // Both now call the one applier, which reads the key
                        // this line has just written and is also what
                        // re-applies the warmth at login.
                        onToggled: {
                            SettingsStore.setValue("display_nightlight",
                                !SettingsStore.boolValue("display_nightlight", false));
                            HyprApply.applyNight();
                        }
                    }
                    TogglePill {
                        label: qsTr("Do Not Disturb"); sub: Sys.dnd ? qsTr("On") : qsTr("Off")
                        icon: ""; active: Sys.dnd; tone: 0.6
                        onToggled: Sys.dnd = !Sys.dnd
                    }
                    // Keep awake. hypridle will lock mid-film or mid-download and
                    // there has never been a switch for it. systemd-inhibit holds the
                    // lock for exactly as long as its CHILD lives, so `running` IS the
                    // state — there is no flag to fall out of sync with reality, and a
                    // crashed shell releases the lock instead of leaving the machine
                    // awake forever.
                    TogglePill {
                        label: qsTr("Keep Awake"); sub: idle.running ? qsTr("On") : qsTr("Off")
                        icon: ""; active: idle.running; tone: 0.75
                        // `running = false` and not `signal(15)`: setting running is
                        // the documented way to stop a Quickshell Process, it is what
                        // the reload() helpers below already use, and nothing else in
                        // this shell calls signal() — so this is one API rather than
                        // two doing the same job.
                        onToggled: idle.running = !idle.running
                    }
                    // TRK-2823a. The subtitle names the state of THE PILL, not
                    // the state of the audio, because `active: Sys.muted` is what
                    // paints it. It read `Muted / On`, so an unmuted machine drew
                    // a flat, unlit pill captioned "On" and the two disagreed on
                    // screen. Every sibling here says On/Off against its own
                    // `active:`; this one now does too. Do not "restore" Muted --
                    // NYXUS_GLASS_VOICE_AND_COPY rule 5 forbids restating the
                    // label in the value, and rule 6 forbids a second word for a
                    // concept the other six already spell On/Off.
                    TogglePill {
                        label: qsTr("Mute"); sub: Sys.muted ? qsTr("On") : qsTr("Off")
                        icon: Sys.muted ? "" : ""
                        active: Sys.muted; tone: 0.9
                        onToggled: Sys.toggleMute()
                    }
                    TogglePill {
                        label: qsTr("Mic")
                        sub: Sys.micMuted ? qsTr("Muted") : qsTr("On")
                        icon: ""
                        active: !Sys.micMuted
                        tone: 0.95
                        onToggled: Sys.toggleMic()
                    }
                }

                // ── SOUND & LIGHT ────────────────────────────────────
                // The two sliders you actually open a quick panel for. The
                // Sound section keeps the DEEP half — the output picker, the
                // headphone list, per-app volume — so this is the tier split
                // this file's header states (bar shows, panel changes,
                // Settings configures), not a second copy of it.
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.s5
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.s4
                        Text {
                            text: qsTr("SOUND & LIGHT")
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                            font.weight: Font.Medium
                            font.letterSpacing: Theme.trackMicro
                        }
                        Rail { Layout.fillWidth: true; tone: 0.3; strength: 0.22; waist: 0.9 }
                    }
                    SliderRow {
                        Layout.fillWidth: true
                        icon: Sys.muted ? "" : ""
                        label: qsTr("Volume"); showReadout: true
                        value: Sys.volume
                        onMoved: v => Sys.setVolume(v)
                    }
                    SliderRow {
                        Layout.fillWidth: true
                        icon: ""; label: "Brightness"; showReadout: true
                        visible: root.hasBacklight
                        value: root.brightness
                        onMoved: v => root.setBrightness(v)
                    }
                }

                // ── NOW PLAYING ──────────────────────────────────────
                // Present only when a player is registered AND has a track:
                // `hasPlayer` alone printed "Unknown track" at an idle
                // player (WIP-640(b)), and an empty card is the defect this
                // whole section exists to stop repeating.
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.s5
                    visible: false
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.s4
                        Text {
                            text: qsTr("NOW PLAYING")
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                            font.weight: Font.Medium
                            font.letterSpacing: Theme.trackMicro
                        }
                        Rail { Layout.fillWidth: true; tone: 0.3; strength: 0.22; waist: 0.9 }
                    }
                    // TRK-3370 — section card onto the widgets' stack.
                    SetSlab {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 82
                        level: 1
                        cornerRadius: Theme.r2
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.s5
                            spacing: Theme.s5
                            Rectangle {
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 50
                                radius: Theme.r1
                                clip: true
                                color: Theme.soften(Theme.void_, 0.34)
                                Text {
                                    anchors.centerIn: parent
                                    text: ""
                                    font.family: Theme.fIcon
                                    color: root.iceInteractive
                                    font.pixelSize: Theme.tHead
                                    visible: quickArt.status !== Image.Ready
                                }
                                Image {
                                    id: quickArt
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectCrop
                                    source: (Sys.hasPlayer && Sys.player.trackArtUrl)
                                            ? Sys.player.trackArtUrl : ""
                                    visible: status === Image.Ready
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Theme.s1
                                Text {
                                    Layout.fillWidth: true
                                    text: Sys.playerTitle
                                    color: Theme.text
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tLabel
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: Sys.playerArtist
                                    color: Theme.textDim
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tCaption
                                    elide: Text.ElideRight
                                }
                            }
                            Text {
                                text: Sys.playerPlaying ? "" : ""
                                font.family: Theme.fIcon
                                font.pixelSize: Theme.tHead
                                color: playHov.hovered ? root.iceInteractive : Theme.textMuted
                                HoverHandler { id: playHov; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: if (Sys.hasPlayer) Sys.player.togglePlaying() }
                            }
                        }
                    }
                }

                // ── THIS MACHINE ─────────────────────────────────────
                // MeterRow is a label and a readout on one line ABOVE a
                // full-width track (TRK-1808), which is the shape the mockup
                // draws and the reason these can live in the overview at all:
                // the old row form gave the track ~90 px of 284.
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.s5
                    visible: false
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.s4
                        Text {
                            text: qsTr("THIS MACHINE")
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                            font.weight: Font.Medium
                            font.letterSpacing: Theme.trackMicro
                        }
                        Rail { Layout.fillWidth: true; tone: 0.3; strength: 0.22; waist: 0.9 }
                    }
                    MeterRow {
                        Layout.fillWidth: true
                        label: qsTr("Processor")
                        value: Sys.cpuPercent / 100
                        readout: Sys.cpuPercent + "%"
                        hot: Sys.cpuPercent >= 90
                    }
                    MeterRow {
                        Layout.fillWidth: true
                        label: qsTr("Memory")
                        value: Sys.memPercent / 100
                        readout: Sys.memText
                        hot: Sys.memPercent >= 90
                    }
                    MeterRow {
                        Layout.fillWidth: true
                        visible: Sys.hasTemp
                        label: qsTr("Temperature")
                        value: Sys.tempPercent / 100
                        readout: Sys.tempText
                        hot: Sys.tempC >= 85
                    }
                }

                // ── NOTIFICATIONS ────────────────────────────────────
                // The two most recent, and a row that says how many more.
                // The full stack, with dismiss and clear-all, stays in the
                // Notifications section — this is a glance, not a second
                // inbox.
                //
                // TRK-2988: hide the whole group when the inbox is empty.
                // "Nothing waiting" under a NOTIFICATIONS heading was the
                // one little bar at the top of a tall Quick card. The
                // dedicated Notifications section still exists for the
                // empty inbox; this glance only earns its chrome when it
                // has something to say.
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.s5
                    visible: false
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.s4
                        Text {
                            text: qsTr("NOTIFICATIONS")
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                            font.weight: Font.Medium
                            font.letterSpacing: Theme.trackMicro
                        }
                        Rail { Layout.fillWidth: true; tone: 0.3; strength: 0.22; waist: 0.9 }
                    }
                    Text {
                        visible: root.notifCount === 0
                        text: Sys.dnd ? qsTr("Do Not Disturb — they wait here")
                                      : qsTr("Nothing waiting")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                    }
                    Repeater {
                        model: root.recentNotifs
                        delegate: Pane {
                            id: qNotif
                            required property var modelData
                            Layout.fillWidth: true
                            // The delegate reserves what its padding actually
                            // costs: the RowLayout insets Theme.s5 top AND
                            // bottom, so the reservation is s5*2 (TRK-1801).
                            Layout.preferredHeight: qNotifCol.implicitHeight + Theme.s5 * 2
                            elevation: 1
                            radius: Theme.r2
                            fill: Theme.soften(Theme.void_, 0.55)
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.s5
                                spacing: Theme.s5
                                Rectangle {
                                    Layout.alignment: Qt.AlignTop
                                    Layout.topMargin: Theme.s1
                                    Layout.preferredWidth: 4
                                    Layout.preferredHeight: qNotifCol.implicitHeight
                                    radius: 2
                                    color: qNotif.modelData.urgency === 2
                                           ? Theme.paintLayers.magma[5]
                                           : root.iceInteractive
                                }
                                ColumnLayout {
                                    id: qNotifCol
                                    Layout.fillWidth: true
                                    spacing: Theme.s1
                                    Text {
                                        Layout.fillWidth: true
                                        text: qNotif.modelData.summary
                                              || qNotif.modelData.appName || qsTr("Notification")
                                        color: Theme.text
                                        font.family: Theme.fUi
                                        font.pixelSize: Theme.tLabel
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: qNotif.modelData.body || ""
                                        visible: !!qNotif.modelData.body
                                        color: Theme.textMuted
                                        font.family: Theme.fUi
                                        font.pixelSize: Theme.tCaption
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                    Text {
                        visible: root.notifCount > root.recentNotifs.length
                        text: qsTr("%1 more waiting").arg(root.notifCount - root.recentNotifs.length)
                        color: root.iceInteractive
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.openKey("notifications") }
                    }
                }
            }
        }
    }
    // ── SOUND ────────────────────────────────────────────────────────
    // The two sliders you actually open a quick panel for, then the rest of
    // the volume control: every real Pipewire output device, the current one
    // lit, one tap to switch. Streams are excluded — those are apps playing
    // audio, not places to send it.
    Component {
        id: secSound
        // TRK-2402: the Sound section scrolls. It never did, and it is one of
        // the two sections the mockup's defect table names for overflowing
        // silently — the output picker, the headphone list and per-app volume
        // together are taller than the panel on any machine with more than
        // two sinks, and everything past the fold simply was not reachable.
        Flickable {
            id: soundRoot
            ScrollRail { flick: soundRoot }
            clip: true
            contentWidth: width
            contentHeight: soundCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: soundCol
            width: soundRoot.width
            spacing: Theme.s5
            SliderRow {
                Layout.fillWidth: true
                icon: Sys.muted ? "" : ""
                label: qsTr("Volume"); showReadout: true
                value: Sys.volume
                onMoved: v => Sys.setVolume(v)
            }
            SliderRow {
                Layout.fillWidth: true
                icon: ""; label: "Brightness"; showReadout: true
                // TRK-2403: the writer, the value and the probe moved to
                // panel scope so Quick's copy of this slider and this one are
                // the SAME control. See SidePanel.qml § BRIGHTNESS.
                visible: root.hasBacklight
                value: root.brightness
                onMoved: v => root.setBrightness(v)
            }

            // GAP-932 — connect headphones here, not only in the Bluetooth
            // section. A volume flyout that cannot reach the headset you
            // just put on is the missing half of WIP-102's output naming.
            // TRK-1808: the mockup's section head is a micro label followed
            // by a hairline that eats the rest of the row -- the same shape
            // Launcher.qml already uses. These were bare labels.
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s4
                visible: Sys.btOn && Sys.btAudioDevices.length > 0
                Text {
                    text: qsTr("HEADPHONES")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    font.weight: Font.Medium
                    font.letterSpacing: Theme.trackMicro
                }
                Rail { Layout.fillWidth: true; tone: 0.3; strength: 0.22; waist: 0.9 }
            }
            Repeater {
                model: Sys.btOn ? Sys.btAudioDevices : []
                delegate: Pane {
                    id: hpRow
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    elevation: 1
                    livingPaint: true
                    radius: Theme.r1
                    fill: Theme.soften(Theme.void_, hpRow.modelData.connected || hpTap.pressed ? 0.66 : 0.34)
                    focusLevel: hpTap.pressed ? 0.70
                              : (hpRow.modelData.connected ? 1.0 : (hpHov.hovered ? 0.45 : 0.0))
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.s5
                        anchors.rightMargin: Theme.s5
                        spacing: Theme.s4
                        Rectangle {
                            Layout.preferredWidth: 6
                            Layout.preferredHeight: 6
                            radius: 3
                            color: hpRow.modelData.connected ? root.iceInteractive : Theme.soften(Theme.text, 0.18)
                        }
                        Text {
                            Layout.fillWidth: true
                            text: Sys.btLabel(hpRow.modelData)
                            color: hpRow.modelData.connected ? Theme.text : Theme.textMuted
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            elide: Text.ElideRight
                        }
                        Text {
                            text: Sys.btState(hpRow.modelData)
                            color: hpRow.modelData.connected ? root.iceInteractive : Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                        }
                    }
                    HoverHandler { id: hpHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: hpTap; onTapped: Sys.btActivate(hpRow.modelData) }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: Sys.btOn && Sys.btAudioDevices.length === 0
                text: qsTr("No Bluetooth headphones in range")
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                elide: Text.ElideRight
            }

            // TRK-1808: the mockup's section head is a micro label followed
            // by a hairline that eats the rest of the row -- the same shape
            // Launcher.qml already uses. These were bare labels.
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s4
                visible: Sys.audioSinks.length > 0
                Text {
                    text: qsTr("OUTPUT")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    font.weight: Font.Medium
                    font.letterSpacing: Theme.trackMicro
                }
                Rail { Layout.fillWidth: true; tone: 0.3; strength: 0.22; waist: 0.9 }
            }
            Repeater {
                model: Sys.audioSinks
                delegate: Pane {
                    id: sinkRow
                    required property var modelData
                    readonly property bool current: Sys.sink === sinkRow.modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    elevation: 1
                    livingPaint: true
                    radius: Theme.r1
                    fill: Theme.soften(Theme.void_, sinkRow.current || sinkTap.pressed ? 0.66 : 0.34)
                    focusLevel: sinkTap.pressed ? 0.70
                              : (sinkRow.current ? 1.0 : (sinkHov.hovered ? 0.45 : 0.0))

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.s5
                        anchors.rightMargin: Theme.s5
                        spacing: Theme.s4

                        Rectangle {
                            Layout.preferredWidth: 6
                            Layout.preferredHeight: 6
                            radius: 3
                            color: sinkRow.current ? root.iceInteractive : Theme.soften(Theme.text, 0.18)
                        }
                        Text {
                            Layout.fillWidth: true
                            text: Sys.sinkLabel(sinkRow.modelData)
                            color: sinkRow.current ? Theme.text : Theme.textMuted
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            elide: Text.ElideRight
                        }
                    }
                    HoverHandler { id: sinkHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: sinkTap; onTapped: Sys.setSink(sinkRow.modelData) }
                }
            }

            // ── PER-APP VOLUME (WIP-702 · GAP-926) ───────────────────
            // The point is NOT to launch pavucontrol. It is a slider per
            // playing application in the panel the person already opened —
            // what Windows and macOS both give you, and what "turn the
            // video down without turning the music down" actually requires.
            // `pavucontrol` stays installed as the deep tool; it is a GTK2
            // window in nobody's theme and it is not the answer to a quick
            // panel.
            //
            // The model is `Sys.appStreams`, a live binding over
            // `Pipewire.nodes`. Apps come and go, and that is handled by
            // the model being a binding rather than a list somebody
            // maintains: a stream that vanishes re-evaluates the property,
            // the Repeater destroys its delegate, and `Sys`'s
            // `PwObjectTracker` untracks it in the same pass. NO TIMER
            // ANYWHERE — nothing here polls, and there is nothing left
            // behind to leak when the section closes.
            // TRK-1808: the mockup's section head is a micro label followed
            // by a hairline that eats the rest of the row -- the same shape
            // Launcher.qml already uses. These were bare labels.
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s4
                visible: Sys.appStreams.length > 0
                Text {
                    text: qsTr("APPS")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    font.weight: Font.Medium
                    font.letterSpacing: Theme.trackMicro
                }
                Rail { Layout.fillWidth: true; tone: 0.3; strength: 0.22; waist: 0.9 }
            }
            // An honest empty state rather than a heading over nothing.
            // "Nothing is playing" is a fact; a blank gap is a page that
            // looks broken.
            Text {
                Layout.fillWidth: true
                visible: Sys.appStreams.length === 0
                text: qsTr("Nothing is playing right now")
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                elide: Text.ElideRight
            }
            Repeater {
                model: Sys.appStreams
                delegate: ColumnLayout {
                    id: appRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Theme.s2

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.s4
                        Text {
                            Layout.fillWidth: true
                            text: Sys.streamLabel(appRow.modelData)
                            color: Theme.text
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            elide: Text.ElideRight
                        }
                        // What is playing, when the app told us something
                        // that is not just its own name back again.
                        Text {
                            Layout.maximumWidth: 150
                            text: Sys.streamDetail(appRow.modelData)
                            visible: text.length > 0
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                            elide: Text.ElideRight
                        }
                    }
                    SliderRow {
                        Layout.fillWidth: true
                        showReadout: true
                        // The glyph is the mute button, which is why it is
                        // wrapped rather than left as SliderRow's plain
                        // icon: a per-app row without a mute is the one
                        // control people actually want on a browser tab.
                        icon: (appRow.modelData.audio && appRow.modelData.audio.muted)
                              ? "" : ""
                        value: appRow.modelData.audio ? appRow.modelData.audio.volume : 0
                        onMoved: v => Sys.setStreamVolume(appRow.modelData, v)
                        TapHandler {
                            // Only the icon column, so a tap on the track
                            // still moves the slider. Theme.s7 is the exact
                            // width SliderRow gives its glyph.
                            onTapped: function (pt) {
                                if (pt.position.x <= Theme.s7)
                                    Sys.toggleStreamMute(appRow.modelData);
                            }
                        }
                    }
                }
            }
        }
        }
    }

    // ── NETWORK ──────────────────────────────────────────────────────
    // Real NetworkManager scan results, strongest first, the connected one
    // lit. Saved networks connect in one tap. A new one asks for a password
    // in this list (Join), and Manage still opens the full network page.
    Component {
        id: secNetwork
        // TRK-2988: a Flickable, not a fillHeight ListView. The empty
        // inbox ("Wi-Fi is off" / "Looking for networks…") is a compact
        // card; a real scan still grows to panelCap and scrolls. Same
        // discriminator TRK-2901 uses: contentHeight from the column, never
        // from the panel.
        Flickable {
            id: netRoot
            ScrollRail { flick: netRoot }
            clip: true
            contentWidth: width
            contentHeight: netCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: netCol
            width: netRoot.width
            spacing: Theme.s5

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s4
                Text {
                    text: qsTr("Wi-Fi")
                    color: Theme.text
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    font.weight: Font.Medium
                }
                SetSwitch {
                    checked: Sys.wifiOn
                    onToggled: function (v) {
                        if (v !== Sys.wifiOn)
                            Sys.toggleWifi();
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: qsTr("Rescan")
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    color: root.iceInteractive
                    TapHandler { onTapped: Sys.wifiScan() }
                }
                Text {
                    text: qsTr("Manage  ›")
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    color: root.iceInteractive
                    TapHandler {
                        onTapped: {
                            root.openQmlSettings("network");
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Looking for networks…")
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                visible: Sys.wifiOn && Sys.hasWifi && Sys.wifiNetworks.length === 0
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.s2
                Repeater {
                    model: Sys.wifiNetworks
                    delegate: Pane {
                        id: netRow
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                    elevation: 1
                    livingPaint: true
                    radius: Theme.r1
                    fill: Theme.soften(Theme.void_, netRow.modelData.connected || netTap.pressed ? 0.66 : 0.34)
                    focusLevel: netTap.pressed ? 0.70
                              : (netRow.modelData.connected ? 1.0 : (netHov.hovered ? 0.45 : 0.0))

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.s5
                        anchors.rightMargin: Theme.s5
                        spacing: Theme.s4

                        // Signal strength as three rising bars — drawn, not a
                        // glyph, for the same reason Vitals.qml is.
                        Row {
                            Layout.preferredWidth: 14
                            spacing: 2
                            Repeater {
                                model: 3
                                delegate: Rectangle {
                                    id: bar
                                    required property int index
                                    width: 3
                                    height: 4 + bar.index * 4
                                    y: 12 - height
                                    radius: 1
                                    color: (netRow.modelData.signalStrength || 0) >= (bar.index + 1) * 28
                                           ? (netRow.modelData.connected ? root.iceInteractive : Theme.textMuted)
                                           : Theme.soften(Theme.text, 0.14)
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: netRow.modelData.name
                            color: netRow.modelData.connected ? Theme.text : Theme.textMuted
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            elide: Text.ElideRight
                        }
                        Text {
                            text: netRow.modelData.connected ? qsTr("Connected")
                                : (netRow.modelData.known ? "Saved" : "")
                            color: netRow.modelData.connected ? root.iceInteractive : Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                        }
                    }
                    HoverHandler { id: netHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: netTap
                        onTapped: {
                            if (netRow.modelData.connected)
                                netRow.modelData.disconnect();
                            else if (netRow.modelData.known) {
                                root.wifiJoinSsid = "";
                                netRow.modelData.connect();
                            } else {
                                root.wifiJoinErr = "";
                                root.wifiJoinPass = "";
                                root.wifiJoinSsid = String(netRow.modelData.name || "");
                            }
                        }
                    }
                }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.s3
                visible: root.wifiJoinSsid.length > 0
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Password for %1").arg(root.wifiJoinSsid)
                    color: Theme.text
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    elide: Text.ElideRight
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.s3
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: Theme.r1
                        color: Theme.soften(Theme.void_, 0.50)
                        border.width: 1
                        border.color: Theme.soften(
                            wifiPass.activeFocus ? root.iceInteractive : root.iceHairline,
                            wifiPass.activeFocus ? 0.80 : 0.45)
                        TextInput {
                            id: wifiPass
                            anchors.fill: parent
                            anchors.leftMargin: Theme.s3
                            anchors.rightMargin: Theme.s3
                            color: Theme.text
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            echoMode: TextInput.Password
                            clip: true
                            onTextChanged: root.wifiJoinPass = text
                            onAccepted: root.wifiJoin()
                            onVisibleChanged: if (visible) wifiPass.forceActiveFocus()
                        }
                    }
                    Text {
                        text: qsTr("Join")
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        color: root.iceInteractive
                        TapHandler { onTapped: root.wifiJoin() }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.wifiJoinErr.length > 0
                    text: root.wifiJoinErr
                    color: root.magmaPrimary
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    wrapMode: Text.Wrap
                }
            }
        }
        }
    }

    // ── BLUETOOTH ────────────────────────────────────────────────────
    // WIP-101's list, moved whole. A toggle answers "is the radio on"; the
    // question a person actually has is "which of my things is connected, and
    // can I connect this one". One tap does the right thing per state
    // (Sys.btActivate): pair if unpaired, connect if paired, disconnect if
    // connected. The row never asks the user to know the difference.
    Component {
        id: secBt
        // TRK-2988: Flickable + contentHeight, not a fillHeight ListView.
        // "Bluetooth is off" / "No devices in range…" is a compact card.
        Flickable {
            id: btRoot
            ScrollRail { flick: btRoot }
            clip: true
            contentWidth: width
            contentHeight: btCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: btCol
            width: btRoot.width
            spacing: Theme.s5

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s4
                Text {
                    text: qsTr("Bluetooth")
                    color: Theme.text
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    font.weight: Font.Medium
                }
                SetSwitch {
                    checked: Sys.btOn
                    onToggled: function (v) {
                        if (v !== Sys.btOn)
                            Sys.toggleBt();
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: qsTr("Scan")
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    color: root.iceInteractive
                    visible: Sys.btOn
                    TapHandler { onTapped: Sys.btSetScanning(true) }
                }
            }
            Text {
                Layout.fillWidth: true
                text: !Sys.btOn ? qsTr("Bluetooth is off")
                    : (Sys.btDevices.length === 0 ? qsTr("No devices in range…") : "")
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                visible: text.length > 0
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.s2
                Repeater {
                    model: Sys.btDevices
                    delegate: Pane {
                        id: btRow
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                    elevation: 1
                    livingPaint: true
                    radius: Theme.r1
                    fill: Theme.soften(Theme.void_, btRow.modelData.connected || btTap.pressed ? 0.66 : 0.34)
                    focusLevel: btTap.pressed ? 0.70
                              : (btRow.modelData.connected ? 1.0 : (btHov.hovered ? 0.45 : 0.0))

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.s5
                        anchors.rightMargin: Theme.s5
                        spacing: Theme.s4

                        // A filled dot for connected, a ring for known,
                        // nothing for a stranger — drawn, like the Wi-Fi bars,
                        // rather than a glyph.
                        Rectangle {
                            Layout.preferredWidth: 8
                            Layout.preferredHeight: 8
                            radius: 4
                            color: btRow.modelData.connected ? root.iceInteractive : "transparent"
                            border.width: btRow.modelData.connected ? 0 : 1
                            border.color: btRow.modelData.paired ? Theme.textMuted
                                                                 : Theme.soften(Theme.text, 0.18)
                        }
                        Text {
                            Layout.fillWidth: true
                            text: Sys.btLabel(btRow.modelData)
                            color: btRow.modelData.connected ? Theme.text : Theme.textMuted
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            elide: Text.ElideRight
                        }
                        Text {
                            text: Sys.btState(btRow.modelData)
                            color: btRow.modelData.connected ? root.iceInteractive : Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                        }
                    }
                    HoverHandler { id: btHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: btTap; onTapped: Sys.btActivate(btRow.modelData) }
                }
                }
            }
        }
        }
    }

    // ── NOW PLAYING · first MPRIS player ─────────────────────────────
    Component {
        id: secMedia
        // TRK-2402: this section scrolls, for the reason Sound and System
        // now do. Gate 13x4 computes the rule over EVERY section instead of
        // checking the two the mockup's defect table happened to name.
        Flickable {
            id: medRoot
            ScrollRail { flick: medRoot }
            clip: true
            contentWidth: width
            contentHeight: mediaCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            spacing: Theme.s5

            function fmt(sec) {
                if (!sec || sec < 0)
                    return "0:00";
                var s = Math.floor(sec % 60);
                return Math.floor(sec / 60) + ":" + (s < 10 ? "0" + s : s);
            }
            id: mediaCol
            width: medRoot.width

            // TRK-3370 — section card onto the widgets' stack.
            SetSlab {
                Layout.fillWidth: true
                Layout.preferredHeight: 92
                level: 1
                cornerRadius: Theme.r2

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.s5
                    spacing: Theme.s5

                    Rectangle {
                        Layout.preferredWidth: 58
                        Layout.preferredHeight: 58
                        radius: Theme.r1
                        clip: true
                        color: Theme.soften(Theme.void_, 0.34)
                        opacity: Sys.hasPlayer ? 1 : 0.35

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            font.family: Theme.fIcon
                            color: root.iceInteractive
                            font.pixelSize: Theme.tHead
                            visible: albumArt.status !== Image.Ready
                        }
                        Image {
                            id: albumArt
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            source: (Sys.hasPlayer && Sys.player.trackArtUrl) ? Sys.player.trackArtUrl : ""
                            visible: status === Image.Ready
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.s1

                        Text {
                            Layout.fillWidth: true
                            // WIP-640(b): `hasPlayer` is "an app registered",
                            // not "there is a track" — an idle registered
                            // player printed "Unknown track" with nothing
                            // playing. Sys.playerHasTrack is the question.
                            text: Sys.playerHasTrack ? Sys.playerTitle : qsTr("Nothing playing")
                            color: Theme.text
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tLabel
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: Sys.playerHasTrack ? Sys.playerArtist
                                                     : "Start something to see it here"
                            color: Theme.textMuted
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            elide: Text.ElideRight
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: Theme.s1
                            spacing: Theme.s3
                            visible: Sys.hasPlayer

                            Text {
                                text: mediaCol.fmt(Sys.hasPlayer ? Sys.player.position : 0)
                                color: Theme.textDim
                                font.family: Theme.fNum
                                font.pixelSize: Theme.tMicro
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 2
                                radius: 1
                                color: Theme.soften(Theme.text, 0.12)

                                Rectangle {
                                    width: parent.width * ((Sys.hasPlayer && Sys.player.length > 0)
                                                           ? Math.min(1, Sys.player.position / Sys.player.length) : 0)
                                    height: parent.height
                                    radius: 1
                                    color: root.icePrimary
                                }
                            }
                            Text {
                                text: mediaCol.fmt(Sys.hasPlayer ? Sys.player.length : 0)
                                color: Theme.textDim
                                font.family: Theme.fNum
                                font.pixelSize: Theme.tMicro
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                // TRK-1808: media transport was the only 20 px gap in the file; the mockup's transport row is 16
                spacing: Theme.s6
                opacity: Sys.hasPlayer ? 1 : 0.35

                Item {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.family: Theme.fIcon
                        color: prevHov.hovered || prevTap.pressed
                               ? root.iceInteractive : Theme.textMuted
                        font.pixelSize: Theme.tBody
                        scale: prevTap.pressed ? 0.90 : (prevHov.hovered ? 1.12 : 1.0)
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durQuick
                                easing.type: Easing.OutQuint
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.durQuick
                                easing.type: Easing.OutQuint
                            }
                        }
                    }
                    HoverHandler { id: prevHov; enabled: Sys.hasPlayer; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: prevTap; enabled: Sys.hasPlayer; onTapped: Sys.player.previous() }
                }
                Item {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40
                    Text {
                        anchors.centerIn: parent
                        text: (Sys.hasPlayer && Sys.player.isPlaying) ? "" : ""
                        font.family: Theme.fIcon
                        color: playTap.pressed ? root.icePrimary : root.iceInteractive
                        font.pixelSize: Theme.tHead
                        scale: playTap.pressed ? 0.92 : (playHov.hovered ? 1.10 : 1.0)
                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.durQuick
                                easing.type: Easing.OutQuint
                            }
                        }
                    }
                    HoverHandler { id: playHov; enabled: Sys.hasPlayer; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: playTap; enabled: Sys.hasPlayer; onTapped: Sys.player.togglePlaying() }
                }
                Item {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.family: Theme.fIcon
                        color: nextHov.hovered || nextTap.pressed
                               ? root.iceInteractive : Theme.textMuted
                        font.pixelSize: Theme.tBody
                        scale: nextTap.pressed ? 0.90 : (nextHov.hovered ? 1.12 : 1.0)
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.durQuick
                                easing.type: Easing.OutQuint
                            }
                        }
                        Behavior on scale {
                            NumberAnimation {
                                duration: Theme.durQuick
                                easing.type: Easing.OutQuint
                            }
                        }
                    }
                    HoverHandler { id: nextHov; enabled: Sys.hasPlayer; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: nextTap; enabled: Sys.hasPlayer; onTapped: Sys.player.next() }
                }
            }
        }
        }
    }

    // ── NOTIFICATIONS ────────────────────────────────────────────────
    // The inbox. Toasts.qml is ephemeral; this list is `Sys.notifications`
    // (tracked). A toast that fades is still here. Do not scroll this list
    // inside Bar.qml — the bar is too thin and BQ owns it.
    Component {
        id: secNotifs
        // TRK-2988: empty inbox is a compact card ("Missed toasts wait
        // here"), not a 972 px hollow. A real queue still grows to panelCap.
        Flickable {
            id: notifRoot
            ScrollRail { flick: notifRoot }
            clip: true
            contentWidth: width
            contentHeight: notifBody.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: notifBody
            width: notifRoot.width
            spacing: Theme.s5

            RowLayout {
                Layout.fillWidth: true
                Text {
                    visible: root.notifCount === 0
                    text: Sys.dnd ? qsTr("Do Not Disturb — they wait here")
                                  : "Missed toasts wait here"
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                }
                Rectangle {
                    visible: root.notifCount > 0
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: 6
                    radius: 3
                    color: root.unreadPrimary
                }
                Text {
                    visible: root.notifCount > 0
                    text: root.notifCount === 1 ? qsTr("1 waiting")
                                                : (root.notifCount + " waiting")
                    color: root.unreadPrimary
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                }
                Item { Layout.fillWidth: true }
                // ── TRK-2935 · CLEAR ALL IS DESTRUCTIVE, SO IT IS MAGMA ──
                // This dropped a whole queue of missed toasts and painted
                // itself `unreadInteractive` — glacier, the SAFE interactive
                // rung this panel uses for every rest/hover affordance. It
                // therefore looked exactly like "Settings" at the bottom of
                // the same panel. Owner 2026-08-19 map: magma = destructive;
                // 2026-08-24: destructive carries magma AT REST.
                //
                // NO ARMING HERE, deliberately, and the distinction is the
                // amount of loss. `cliphist wipe` above destroys content the
                // user PUT somewhere — text they copied, gone. This drops
                // notices the system pushed at them and which they have by
                // definition already missed; nothing they authored is lost,
                // and the queue refills on the next event. Arming a chore
                // people do several times a day to clear noise is how a
                // confirm step gets trained into a reflex, which is what
                // makes confirms stop working on the wipe that matters. So:
                // the colour tells the truth, and the tap stays one tap.
                //
                // magma[5] at rest, magma[0] on hover — SetButton's own
                // rest -> hover rungs, not a third pairing.
                Text {
                    visible: root.notifCount > 0
                    text: qsTr("Clear all")
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    color: clrAllHov.hovered ? root.magmaInteractive
                                             : root.magmaPrimary
                    Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                    HoverHandler { id: clrAllHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: Sys.clearNotifications() }
                }
            }

            Repeater {
                model: Sys.notifications
                delegate: SetSlab {
                    id: notif
                    required property var modelData
                    Layout.fillWidth: true
                    // TRK-1801: the RowLayout below insets by Theme.s5 top AND
                    // bottom (24), but this reserved Theme.s7 (20), so every
                    // notification clipped by 4 px.
                    Layout.preferredHeight: notifCol.implicitHeight + Theme.s5 * 2
                    // TRK-3370 — section card onto the widgets' stack.
                    level: 1
                    cornerRadius: Theme.r2

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.s5
                        spacing: Theme.s5

                        Rectangle {
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: Theme.s1
                            Layout.preferredWidth: 4
                            Layout.preferredHeight: notifCol.implicitHeight
                            radius: 2
                            // Owner 2026-08-19: critical is magma, unread/
                            // routine is violet. Same map as Toasts.qml.
                            // One family on the bar — never ice+magma, never
                            // Theme.danger (rose-adjacent red).
                            color: notif.modelData.urgency === 2
                                   ? Theme.paintLayers.magma[5]
                                   : root.unreadInteractive
                        }
                        ColumnLayout {
                            id: notifCol
                            Layout.fillWidth: true
                            spacing: Theme.s1

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: notif.modelData.summary || notif.modelData.appName || qsTr("Notification")
                                    color: Theme.text
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tLabel
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: (notif.modelData.appName || "").toUpperCase()
                                    color: Theme.textDim
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tMicro
                                    font.letterSpacing: Theme.trackMicro
                                    elide: Text.ElideRight
                                    clip: true
                                    Layout.maximumWidth: 120
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: notif.modelData.body || ""
                                color: Theme.textMuted
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                                wrapMode: Text.WordWrap
                                visible: !!notif.modelData.body
                            }
                        }
                        Text {
                            Layout.alignment: Qt.AlignTop
                            text: ""
                            font.family: Theme.fIcon
                            color: Theme.textDim
                            font.pixelSize: Theme.tCaption
                            TapHandler { onTapped: notif.modelData.dismiss() }
                        }
                    }
                    TapHandler {
                        onTapped: notif.modelData.activate ? notif.modelData.activate() : null
                    }
                }
            }
        }
        }
    }

    // ── CALENDAR ─────────────────────────────────────────────────────
    // The month grid and its day reminders, moved whole from the Flyout —
    // this is the only surface in the shell that has the GRID; Clock.qml
    // carries the upcoming list, and both read and write `Reminders`, the
    // same singleton, so a reminder filed here appears there without either
    // knowing the other exists.
    Component {
        id: secCalendar
        Flickable {
            id: calRoot
            ScrollRail { flick: calRoot }
            clip: true
            contentWidth: width
            contentHeight: calCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            // Which day is open. -1 is none. Local to the section: the panel
            // is transient and always opens at its beginning, the same reason
            // the Flyout reset its scroll on open.
            property int selYear: 0
            property int selMonth: 0
            property int selDay: -1

            ColumnLayout {
                id: calCol
                width: calRoot.width
                // TRK-1808: calendar column: 12 is the in-section gap everywhere else now
                spacing: Theme.s5

                // TRK-3370 — section card onto the widgets' stack.
                SetSlab {
                    Layout.fillWidth: true
                    Layout.preferredHeight: cal.implicitHeight + Theme.s8
                    level: 1
                    cornerRadius: Theme.r2

                    // Left/right/top only. Anchoring the height as well while
                    // the Pane's height is bound to `cal.implicitHeight` is a
                    // binding loop: the child would size the parent that sizes
                    // the child.
                    MonthCalendar {
                        id: cal
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: Theme.s5
                        }
                        // WIP-103. The calendar reports the tap; this decides
                        // what happens, because a month grid is the wrong
                        // place to host an editor. Tapping the open day closes
                        // it, so a second tap is always "put that away".
                        onDaySelected: function (y, m, d) {
                            if (calRoot.selDay === d && calRoot.selMonth === m && calRoot.selYear === y) {
                                calRoot.selDay = -1;
                                return;
                            }
                            calRoot.selYear = y; calRoot.selMonth = m; calRoot.selDay = d;
                            addField.text = "";
                        }
                    }
                }

                // ── the selected day ─────────────────────────────────
                // Everything here reads and writes `Reminders`, the same
                // singleton the dots above read. No second copy of the truth.
                RowLayout {
                    Layout.fillWidth: true
                    visible: calRoot.selDay > 0
                    Text {
                        text: calRoot.selDay > 0
                              ? cal.monthNames[calRoot.selMonth].toUpperCase() + " " + calRoot.selDay
                              : ""
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                        font.weight: Font.Medium
                        font.letterSpacing: Theme.trackMicro
                        color: Theme.textDim
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: qsTr("Close")
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                        color: root.iceInteractive
                        TapHandler { onTapped: calRoot.selDay = -1 }
                    }
                }

                Repeater {
                    model: calRoot.selDay > 0
                           ? Reminders.forDay(calRoot.selYear, calRoot.selMonth, calRoot.selDay)
                           : []
                    delegate: Pane {
                        id: remRow
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        elevation: 1
                        livingPaint: true
                        radius: Theme.r1
                        fill: Theme.soften(Theme.void_, 0.34)
                        focusLevel: remHov.hovered ? 0.45 : 0.0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.s5
                            anchors.rightMargin: Theme.s5
                            spacing: Theme.s4

                            Rectangle {
                                Layout.preferredWidth: 8; Layout.preferredHeight: 8
                                radius: 4
                                color: remRow.modelData.done ? root.iceInteractive : "transparent"
                                border.width: remRow.modelData.done ? 0 : 1
                                border.color: Theme.textMuted
                                TapHandler { onTapped: Reminders.toggleDone(remRow.modelData.id) }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: remRow.modelData.text
                                color: remRow.modelData.done ? Theme.textDim : Theme.textMuted
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                                font.strikeout: remRow.modelData.done
                                elide: Text.ElideRight
                            }
                            Text {
                                text: "×"
                                color: Theme.textDim
                                font.pixelSize: Theme.tCaption
                                TapHandler { onTapped: Reminders.remove(remRow.modelData.id) }
                            }
                        }
                        HoverHandler { id: remHov }
                    }
                }

                Pane {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    visible: calRoot.selDay > 0
                    elevation: 1
                    radius: Theme.r1
                    fill: Theme.soften(Theme.void_, 0.34)
                    TextInput {
                        id: addField
                        anchors.fill: parent
                        anchors.leftMargin: Theme.s5
                        anchors.rightMargin: Theme.s5
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        clip: true
                        // Same class as the sticky note: the flyout already
                        // has OnDemand + a focus grab, but the composer is
                        // a late child and does not take Qt focus until
                        // something asks. A selected day with a dead field
                        // reads as "reminders do not work".
                        onVisibleChanged: if (visible) addField.forceActiveFocus()
                        // 09:00 on the chosen day. A reminder without a time
                        // is still a reminder, and demanding one before
                        // anything can be written is how a quick note stops
                        // being quick.
                        onAccepted: {
                            if (!text.trim() || calRoot.selDay <= 0) return;
                            var when = new Date(calRoot.selYear, calRoot.selMonth, calRoot.selDay, 9, 0, 0);
                            Reminders.add(when.getTime(), text);
                            text = "";
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Add a reminder…")
                            color: Theme.textDim
                            font: addField.font
                            visible: addField.text.length === 0 && !addField.activeFocus
                        }
                    }
                }
            }
        }
    }

    // ── CLIPBOARD ────────────────────────────────────────────────────
    //
    // The headline of phase 1. `cliphist` has been recording into a live
    // store since WIP-109 wired `wl-paste --watch` into the services shard,
    // Settings has had a Clipboard page over it for weeks — and NOTHING in
    // shell/ had ever read it. A history you cannot see is a history you do
    // not have.
    Component {
        id: secClip
        // TRK-2988: "Nothing copied yet." is a compact card, not a 972 px
        // hollow with one line of type at the foot of a fillHeight ListView.
        Flickable {
            id: clipRoot
            ScrollRail { flick: clipRoot }
            clip: true
            contentWidth: width
            contentHeight: clipCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: clipCol
            width: clipRoot.width
            spacing: Theme.s5

            Text {
                visible: clip.entries.length === 0
                Layout.fillWidth: true
                text: qsTr("Nothing copied yet.")
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tLabel
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.s2
                visible: clip.entries.length > 0
                Repeater {
                    model: clip.entries
                    delegate: Pane {
                        id: clipRow
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                    elevation: 1
                    livingPaint: true
                    radius: Theme.r1
                    fill: Theme.soften(Theme.void_, clipHov.hovered || clipTap.pressed ? 0.66 : 0.34)
                    focusLevel: clipTap.pressed ? 0.70 : (clipHov.hovered ? 0.45 : 0.0)
                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.s5
                        anchors.rightMargin: Theme.s5
                        text: clipRow.modelData.text
                        color: Theme.textMuted
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tLabel
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                    HoverHandler { id: clipHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: clipTap
                        onTapped: {
                            // Decode by the entry's cliphist id and put it back
                            // on the clipboard. `cliphist decode` takes the id
                            // on stdin, which is why this is a shell pipeline
                            // rather than an argv.
                            Quickshell.execDetached(["sh", "-c",
                                "printf '%s' " + JSON.stringify(clipRow.modelData.id)
                                + " | cliphist decode | wl-copy"]);
                            root.collapse();
                        }
                    }
                }
                }
            }

            // ── TRK-2935 · CLEAR HISTORY IS THE SAME WIPE PRIVACY ARMS ──
            // `cliphist wipe` is irreversible and it is the EXACT action
            // Settings > Privacy already marks `danger: true` and arms with
            // two taps. Here it was a bare text link: `Theme.textDim` at
            // rest — the same grey as "Nothing copied yet." two rows up —
            // with magma appearing only once the pointer was already on it,
            // and NO arming at all. One click wiped the history.
            //
            // That is the owner's 2026-08-24 complaint in its purest form:
            // the colour told you the truth only AFTER you had acted on it,
            // and here there was no second chance behind it.
            //
            // The fix is not a new interaction. `SetButton` already owns the
            // ruled two-tap pattern — magma at rest, arm, confirm label that
            // says what will happen, 4 s auto-disarm — so this becomes a
            // `SetButton` rather than a re-implementation of one. Nothing
            // about what the action DOES changed: same `cliphist wipe`, same
            // `clip.reload()`.
            //
            // TRK-2988: hidden when the list is empty — a wipe control with
            // nothing to wipe was the second bar in a hollow card.
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                visible: clip.entries.length > 0
                SetButton {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Clear history")
                    danger: true
                    // Say what will happen, never "Are you sure?" — the count
                    // is the honest thing to put in front of someone about to
                    // destroy it.
                    confirmText: clip.entries.length === 1
                                 ? qsTr("Wipe 1 entry")
                                 : qsTr("Wipe %1 entries").arg(clip.entries.length)
                    onClicked: {
                        Quickshell.execDetached(["sh", "-c", "cliphist wipe"]);
                        clip.reload();
                    }
                }
            }
        }
        }
    }

    // ── CAPTURE ──────────────────────────────────────────────────────
    // Four screenshot keybinds exist and always have. A person who does not
    // know the keybind has had no way in at all.
    Component {
        id: secCapture
        // TRK-2402: this section scrolls, for the reason Sound and System
        // now do. Gate 13x4 computes the rule over EVERY section instead of
        // checking the two the mockup's defect table happened to name.
        Flickable {
            id: capRoot
            ScrollRail { flick: capRoot }
            clip: true
            contentWidth: width
            contentHeight: capRootCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: capRootCol
            width: capRoot.width
            spacing: Theme.s5
            Repeater {
                model: [
                    { label: qsTr("Region"),      icon: "", cmd: ["nyxus-screenshot", "region"] },
                    { label: qsTr("Window"),      icon: "", cmd: ["nyxus-screenshot", "window"] },
                    { label: qsTr("Full screen"), icon: "", cmd: ["nyxus-screenshot", "fullscreen"] },
                    { label: qsTr("Eyedropper"),  icon: "", cmd: ["nyxus-screenshot", "eyedropper"] }
                ]
                delegate: Pane {
                    id: capRow
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    elevation: 1
                    livingPaint: true
                    radius: Theme.r1
                    fill: Theme.soften(Theme.void_, capHov.hovered || capTap.pressed ? 0.66 : 0.34)
                    focusLevel: capTap.pressed ? 0.70 : (capHov.hovered ? 0.45 : 0.0)
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.s5
                        anchors.rightMargin: Theme.s5
                        spacing: Theme.s4
                        Text {
                            text: capRow.modelData.icon
                            color: capHov.hovered || capTap.pressed
                                   ? root.iceInteractive
                                   : Theme.textDim
                            font.family: Theme.fIcon
                            font.pixelSize: Theme.tBody
                        }
                        Text {
                            Layout.fillWidth: true
                            text: capRow.modelData.label
                            color: capHov.hovered || capTap.pressed ? Theme.text : Theme.textMuted
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tBody
                        }
                    }
                    HoverHandler { id: capHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: capTap
                        onTapped: {
                            // Collapse FIRST — a region selector that opens
                            // under this panel is unusable.
                            root.collapse();
                            Quickshell.execDetached(capRow.modelData.cmd);
                        }
                    }
                }
            }
            Pane {
                id: recRow
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                elevation: 1
                livingPaint: true
                radius: Theme.r1
                fill: Theme.soften(Theme.void_, recHov.hovered || recTap.pressed ? 0.66 : 0.34)
                focusLevel: recTap.pressed ? 0.70 : (recHov.hovered ? 0.45 : 0.0)
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.s5
                    anchors.rightMargin: Theme.s5
                    spacing: Theme.s4
                    Text {
                        text: ""
                        color: recHov.hovered || recTap.pressed || RecordWatch.active
                               ? root.magmaInteractive : Theme.textDim
                        font.family: Theme.fIcon
                        font.pixelSize: Theme.tBody
                    }
                    Text {
                        Layout.fillWidth: true
                        text: RecordWatch.active ? qsTr("Stop recording") : qsTr("Record")
                        color: recHov.hovered || recTap.pressed ? Theme.text : Theme.textMuted
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tBody
                    }
                }
                HoverHandler { id: recHov; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    id: recTap
                    onTapped: {
                        root.collapse();
                        if (RecordWatch.active)
                            RecordWatch.stop();
                        else
                            RecordWatch.toggle();
                    }
                }
            }
        }
        }
    }

    // ── SYSTEM ───────────────────────────────────────────────────────
    // Phase 1's power profile and removable media, plus THIS MACHINE from the
    // Flyout — real numbers from /proc, polled only while this section is on
    // screen (the vitalsActive Binding above).
    Component {
        id: secSystem
        // TRK-2402: System scrolls. The mockup's defect table names it and
        // Sound as the two sections with no `ScrollRail` -- the vitals card,
        // the update row, the power profiles and removable media together
        // overrun the panel, and everything past the fold was unreachable.
        Flickable {
            id: sysRoot
            ScrollRail { flick: sysRoot }
            clip: true
            contentWidth: width
            contentHeight: sysCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: sysCol
            width: sysRoot.width
            spacing: Theme.s5

            // TRK-3370 — section card onto the widgets' stack.
            SetSlab {
                Layout.fillWidth: true
                implicitHeight: sysVitalsCol.implicitHeight + Theme.s5 * 2
                level: 1
                cornerRadius: Theme.r2

                ColumnLayout {
                    id: sysVitalsCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.s5
                    spacing: Theme.s4

                    MeterRow {
                        Layout.fillWidth: true
                        label: qsTr("Processor")
                        value: Sys.cpuPercent / 100
                        readout: Sys.cpuPercent + "%"
                        hot: Sys.cpuPercent >= 90
                    }
                    MeterRow {
                        Layout.fillWidth: true
                        visible: Sys.hasGpu
                        label: qsTr("Graphics")
                        value: Sys.gpuPercent / 100
                        readout: Sys.gpuText
                        hot: Sys.gpuPercent >= 90
                    }
                    MeterRow {
                        Layout.fillWidth: true
                        visible: Sys.hasTemp
                        label: qsTr("Temperature")
                        value: Sys.tempPercent / 100
                        readout: Sys.tempText
                        hot: Sys.tempC >= 85
                    }
                    MeterRow {
                        Layout.fillWidth: true
                        label: qsTr("Memory")
                        value: Sys.memPercent / 100
                        readout: Sys.memText
                        hot: Sys.memPercent >= 90
                    }
                    MeterRow {
                        Layout.fillWidth: true
                        visible: Sys.hasNet
                        label: qsTr("Network")
                        value: Sys.netPercent / 100
                        readout: Sys.netText
                    }
                    MeterRow {
                        Layout.fillWidth: true
                        visible: Sys.hasFans
                        label: qsTr("Fans")
                        value: Sys.fanPercent / 100
                        readout: Sys.fanText
                        hot: Sys.fanPercent >= 90
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Up " + Sys.uptimeText
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: Quickshell.env("USER") || ""
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s3
                Pane {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    elevation: 1
                    livingPaint: true
                    radius: Theme.r1
                    fill: Theme.soften(Theme.void_, updHov.hovered || updTap.pressed ? 0.66 : 0.40)
                    focusLevel: updTap.pressed ? 0.70 : (updHov.hovered ? 0.45 : 0.0)
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.s5
                        anchors.rightMargin: Theme.s5
                        Text {
                            Layout.fillWidth: true
                            text: UpdateWatch.label
                            color: UpdateWatch.hasUpdates ? Theme.ok : Theme.text
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tBody
                        }
                        Text {
                            visible: UpdateWatch.hasUpdates
                            text: qsTr("Install")
                            color: root.iceInteractive
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                        }
                    }
                    HoverHandler { id: updHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: updTap
                        onTapped: {
                            root.collapse();
                            if (UpdateWatch.hasUpdates)
                                UpdateWatch.openStore();
                            else
                                UpdateWatch.openSettings();
                        }
                    }
                }
                Pane {
                    Layout.preferredWidth: 88
                    Layout.preferredHeight: 40
                    elevation: 1
                    livingPaint: true
                    radius: Theme.r1
                    fill: Theme.soften(Theme.void_, rbHov.hovered || rbTap.pressed ? 0.66 : 0.40)
                    focusLevel: rbTap.pressed ? 0.70 : (rbHov.hovered ? 0.45 : 0.0)
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Rollback")
                        color: Theme.textMuted
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                    }
                    HoverHandler { id: rbHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: rbTap
                        onTapped: {
                            root.collapse();
                            UpdateWatch.openBackup();
                        }
                    }
                }
            }

            // TRK-1808: the mockup's section head is a micro label followed
            // by a hairline that eats the rest of the row -- the same shape
            // Launcher.qml already uses. These were bare labels.
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s4
                Text {
                    text: qsTr("POWER PROFILE")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    font.weight: Font.Medium
                    font.letterSpacing: Theme.trackMicro
                }
                Rail { Layout.fillWidth: true; tone: 0.3; strength: 0.22; waist: 0.9 }
            }
            // power-profiles-daemon has been installed and running with
            // nothing exposing it.
            // A Layout for the same reason secQuick is one: TogglePill sizes
            // itself with Layout attached properties, which a Flow does not
            // read, so these three profile pills were 0 × 0 too.
            GridLayout {
                Layout.fillWidth: true
                columns: 3
                columnSpacing: Theme.s3
                rowSpacing: Theme.s3
                Repeater {
                    model: [
                        { id: "power-saver", label: qsTr("Saver"),   icon: "", tone: 0.0 },
                        { id: "balanced",    label: qsTr("Balanced"), icon: "", tone: 0.4 },
                        { id: "performance", label: qsTr("Performance"), icon: "", tone: 0.85 }
                    ]
                    delegate: TogglePill {
                        required property var modelData
                        label: modelData.label
                        icon: modelData.icon
                        tone: modelData.tone
                        active: profile.current === modelData.id
                        onToggled: {
                            Quickshell.execDetached(
                                ["powerprofilesctl", "set", modelData.id]);
                            profile.reload();
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1
                        color: root.iceHairline }

            // TRK-1808: the mockup's section head is a micro label followed
            // by a hairline that eats the rest of the row -- the same shape
            // Launcher.qml already uses. These were bare labels.
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s4
                Text {
                    text: qsTr("REMOVABLE MEDIA")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    font.weight: Font.Medium
                    font.letterSpacing: Theme.trackMicro
                }
                Rail { Layout.fillWidth: true; tone: 0.3; strength: 0.22; waist: 0.9 }
            }
            Text {
                visible: disks.mounts.length === 0
                text: qsTr("Nothing plugged in.")
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tLabel
            }
            Repeater {
                model: disks.mounts
                delegate: Pane {
                    id: diskRow
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    elevation: 1
                    livingPaint: true
                    radius: Theme.r1
                    fill: Theme.soften(Theme.void_, diskHov.hovered || diskTap.pressed ? 0.66 : 0.34)
                    focusLevel: diskTap.pressed ? 0.70 : (diskHov.hovered ? 0.45 : 0.0)
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.s5
                        anchors.rightMargin: Theme.s5
                        spacing: Theme.s4
                        Text {
                            text: ""
                            color: Theme.textDim
                            font.family: Theme.fIcon
                            font.pixelSize: Theme.tLabel
                        }
                        Text {
                            Layout.fillWidth: true
                            text: diskRow.modelData.label
                            color: Theme.textMuted
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tLabel
                            elide: Text.ElideRight
                        }
                        // ── TRK-2935 · EJECT CARRIES MAGMA AT REST ──────
                        // Eject unmounts and then powers off the device.
                        // It interrupts something — a copy in flight is the
                        // case that costs — which is the `danger` definition
                        // `SetButton.qml`'s own header gives. It was
                        // `Theme.textDim` at rest, the same grey as the
                        // device label beside it, and only found its magma
                        // once the pointer was on it.
                        //
                        // Colour only, no arming: unlike a wipe this is
                        // undone by plugging the device back in, and the
                        // control is a caption inside a per-device row where
                        // a confirm label has nowhere to go. rest magma[5],
                        // hover magma[0] — the same two rungs as the row
                        // above.
                        Text {
                            text: qsTr("Eject")
                            color: ejHov.hovered ? root.magmaInteractive : root.magmaPrimary
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                            HoverHandler { id: ejHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    Quickshell.execDetached(["sh", "-c",
                                        "udisksctl unmount -b "
                                        + JSON.stringify(diskRow.modelData.dev)
                                        + " && udisksctl power-off -b "
                                        + JSON.stringify(diskRow.modelData.dev)]);
                                    disks.reload();
                                }
                            }
                        }
                    }
                    HoverHandler { id: diskHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        id: diskTap
                        onTapped: {
                            if (!diskRow.modelData.mount)
                                return;
                            root.collapse();
                            Quickshell.execDetached(["xdg-open", diskRow.modelData.mount]);
                        }
                    }
                }
            }
        }
        }
    }

    // ══════════════════════════════════════════════════════════════════
    //  DATA — every one of these is event- or open-driven. Nothing polls.
    // ══════════════════════════════════════════════════════════════════

    // Who is logged in. Read once; it cannot change within a session.
    QtObject {
        id: userProc
        property string name: ""
        property string host: ""
    }
    Process {
        running: true
        command: ["sh", "-c", "id -un; hostname 2>/dev/null || cat /etc/hostname"]
        stdout: StdioCollector {
            onStreamFinished: {
                const L = this.text.trim().split("\n");
                userProc.name = (L[0] || "").trim();
                userProc.host = (L[1] || "").trim();
            }
        }
    }

    // Idle inhibitor. `systemd-inhibit --what=idle sleep infinity` holds the
    // lock for exactly as long as this child lives, so `running` IS the state
    // — there is no flag to fall out of sync with reality, and a crashed shell
    // releases the lock rather than leaving the machine awake forever.
    Process { id: idle
        command: ["systemd-inhibit", "--what=idle:sleep",
                  "--who=Nyxus Suxyn", "--why=Keep awake",
                  "sleep", "infinity"] }

    // ── clipboard ────────────────────────────────────────────────────
    // Re-read when the section OPENS, not on a timer. A clipboard history is
    // only ever looked at at the moment it is opened, so anything else is a
    // wake for nothing — and this repo's hardest rule is that nothing polls.
    QtObject { id: clip; property var entries: []
               function reload() { clipProc.running = false; clipProc.running = true; } }
    Process {
        id: clipProc
        command: ["sh", "-c", "cliphist list 2>/dev/null | head -40"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of this.text.split("\n")) {
                    if (!line.trim())
                        continue;
                    // cliphist emits "<id>\t<preview>". Split on the FIRST tab
                    // only: a copied string can itself contain tabs, and
                    // splitting on all of them truncates the preview at the
                    // first one in the user's own text.
                    const t = line.indexOf("\t");
                    if (t < 0)
                        continue;
                    out.push({ id: line.slice(0, t),
                               text: line.slice(t + 1).trim() });
                }
                clip.entries = out;
            }
        }
    }

    // ── power profile ────────────────────────────────────────────────
    QtObject { id: profile; property string current: ""
               function reload() { profProc.running = false; profProc.running = true; } }
    Process {
        id: profProc
        command: ["sh", "-c", "powerprofilesctl get 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: profile.current = this.text.trim() }
    }

    // ── removable media ──────────────────────────────────────────────
    QtObject { id: disks; property var mounts: []
               function reload() { diskProc.running = false; diskProc.running = true; } }
    Process {
        id: diskProc
        // Removable, mounted, with a mountpoint. `lsblk -J` would be tidier
        // but its schema differs across versions; the -P form is stable.
        command: ["sh", "-c",
            "lsblk -P -o NAME,PATH,LABEL,MOUNTPOINT,RM,TYPE 2>/dev/null "
            + "| grep 'RM=\"1\"' | grep 'TYPE=\"part\"' | grep -v 'MOUNTPOINT=\"\"'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of this.text.split("\n")) {
                    if (!line.trim())
                        continue;
                    const f = {};
                    for (const m of line.matchAll(/([A-Z]+)="([^"]*)"/g))
                        f[m[1]] = m[2];
                    if (!f.PATH)
                        continue;
                    out.push({ dev: f.PATH,
                               mount: f.MOUNTPOINT,
                               label: f.LABEL || f.MOUNTPOINT || f.NAME });
                }
                disks.mounts = out;
            }
        }
    }

    // One place that refreshes whatever the newly-opened section needs. A
    // section that reads stale data on open is the whole reason this is here.
    onActiveChanged: {
        if (root.active < 0) {
            // Collapsing by any route hands the rail back to the pointer's
            // grace period rather than stranding it on screen.
            if (!surfaceHover.hovered)
                retractTimer.restart();
            return;
        }
        const k = root.activeKey;
        if (k === "clipboard") clip.reload();
        else if (k === "system") { profile.reload(); disks.reload(); }
    }
}
