// NYXUS Daily Driver — Start menu, as a Swell.
//
// HORIZON §5.4: it rises out of the horizon AT THE POINT YOU TOUCHED. You
// open it from the Sigil in the bottom-left, so it grows there — flush to the
// bottom and to the left edge, rounded on the one corner that faces open
// space, with the living paint at its base continuous with the Line.
//
// ── 2026-08-05 · the Atrium ─────────────────────────────────────────────
// The 08-05 rebuild fixed the CONTENT: no dead tiles, real recents, a search
// that searches, live vitals. All of that stands and none of it is touched
// here. What it did not fix, and what the owner still calls "too plain, too
// bla", is the SHAPE of the page — photographed at full size, the fault is
// that every element on it has the same weight:
//
//   · 31 identical 54 px plates in one undifferentiated grid. Nothing is
//     more important than anything else, so the eye has nowhere to land and
//     the whole page reads as a spreadsheet of software.
//   · The masthead was a name, a dot and two glyphs on flat black. The most
//     personal surface in the system opened with no colour on it at all.
//   · Sections were divided by `Rectangle { height: 1; color: grey }` — the
//     one material §3.5 says this palette does not contain.
//
// So the page now has three tiers instead of one:
//   the Masthead   who you are, on a band of the sweep. Lock and Power.
//   the Pinned     six large tiles for the things you actually open. This is
//                  the tier that was missing, and it is why a flat grid of
//                  31 could never look designed.
//   the Grid       everything else, still normalised to one visual set.
// and the glance column on the right keeps the machine's live state.
//
// ── the rules this file still obeys ─────────────────────────────────────
// · EVERY tile launches something that SHIPS. Checked against
//   iso-builder/nyx-profile/packages.x86_64 and airootfs/usr/local/bin.
//   The preview host has extra software installed, so a dead tile looks
//   fine here and is only dead on a real boot — the trap this list fell
//   into once already (docs/SYSTEM_QUALITY_FINDINGS_2026-08-03.md P1).
// · Nothing on this surface is invented. A section with no real data hides
//   or says so; it never shows a plausible placeholder. In particular
//   PINNED is a fixed curated six, NOT a "most used" list — this build has
//   no usage tracking and a made-up frecency order would be exactly the
//   kind of plausible lie the rest of this file exists to avoid.
// · ⛔ NO POLLING while the menu is shut (the hyprlock lesson, Sys.qml).
//   Recents read once per open. Vitals are bound to `Bus.launcherOpen`.
// · No hex literals — Theme.qml owns colour (Theme.qml rule 1).
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes

PanelWindow {
    id: root
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    // Held OnDemand. Binding Exclusive to launcherOpen remapped the
    // layer — nested grim of nyxus-launcher was wallpaper only.
    // forceActiveFocus on open still runs.
    // See Bar.qml: the blur floor only matches ^(nyxus.*)$.
    WlrLayershell.namespace: "nyxus-launcher"
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: !Prefs.arcadeMode

    // The real login name — the same call the Flyout's user card uses, so
    // the two surfaces cannot disagree about who is logged in.
    readonly property string userName: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "user"
    // The account picture lives at ~/.face — the same file Settings ▸ Account
    // writes and AccountsService reads, so the tile here, the greeter and the
    // Account page can never disagree about your photo.
    readonly property string homeDir: Quickshell.env("HOME") || ("/home/" + userName)

    // 2026-08-19 · owner palette map: ice rest/hover/Settings;
    // magma = power. Violet is notifications (Toasts / flyout), not here.
    readonly property color iceInteractive: Theme.stateLayer[0]
    readonly property color icePrimary:     Theme.paintLayers.glacier[5]
    readonly property color iceHairline:    Theme.lookSeam
    readonly property color magmaInteractive: Theme.paintLayers.magma[0]

    // ── the apps ─────────────────────────────────────────────────────────
    // `cat` drives the chips. Keep it to the five that exist; a category
    // with two things in it is a worse answer than no category.
    //
    // 2026-08-09: cut to the real 18-app nyxus_*.py roster the owner
    // confirmed, plus the handful of non-nyxus / OS-integration tiles that
    // were never part of that trim (Web Browser, Mail, Music, Video,
    // Account, the two @flyout: routes). Doctor retired into Settings.
    // Reminders/Clock/Tour were nyxus-prefixed apps outside the confirmed
    // 18 and are cut with them — this table must never list a tile the
    // build does not ship (see the rule two comments up).
    //
    // ⚠ THIS ARRAY IS HARDCODED AND NOTHING SCANS .desktop FILES. So the
    // Start Menu roster and the freedesktop roster are two separate lists
    // that must be changed TOGETHER — WIP-459. Gate 13q13 checks this array
    // against the same ROSTER set it checks usr/share/applications against,
    // but only for tiles whose exec begins with "nyxus-". Video is the
    // packaged-mpv extra (WIP-460 / TRK-3071): exec is `nyxus-video` so the
    // tile opens a window; 13q13 treats that wrapper as mpv, not a roster
    // Nyxus app (no AppSpec, no Settings sub-section). A bare `mpv` tile
    // prints usage and exits 0 — 13q13 now fails that.
    //
    // 2026-08-12, WIP-490 — THE OWNER APPROVED A ROSTER REDUCTION from 20
    // visible entries to roughly 12. Four tiles were FOLDED, meaning the
    // launcher entry is gone and the capability is not: Backup and Updater
    // (Settings' Backup and Updates pages own them, and each page's Tools
    // group has an "Open NYXUS <app>" row that execs the binary), Wallpaper
    // Studio (Settings' picker, and the desktop right-click "Change
    // wallpaper…" at Bar.qml:1599 which also execs the binary), and
    // Clipboard (SidePanel.qml's CLIPBOARD section is the summon surface,
    // Settings' Clipboard page the configuration). Weather was proposed for
    // the same treatment and DELIBERATELY KEPT — the desktop and lock
    // widgets are read-only views of nyxus-lock-weather's two-string cache
    // and Settings has no weather page, so the app is the only forecast on
    // the build. Reasoning in full in nyxus-weather.desktop's header.
    // TRK-4143 — the roster literal. Read `allApps` instead; it is this list
    // with unavailable entries removed. Splitting the two gives one place
    // where a tile can be withheld, so pins, search, categories and the
    // Daily/Classic rosters can never disagree about whether an app exists.
    readonly property var appRoster: [
        { name: qsTr("Files"),          icon: "nyxus-files"        ,      exec: "@files",                 cat: "apps"   },
        { name: qsTr("Web Browser"),    icon: "chromium",                 exec: "chromium",               cat: "apps"   },
        { name: qsTr("Mail"),           icon: "thunderbird",              exec: "thunderbird",            cat: "apps"   },
        // nyxus-notes, NOT nyxus-notepad. WIP-450 made nyxus-notes.desktop
        // the visible "Notes" and hid/renamed Notepad, but this array was
        // not moved with it — so the Start Menu tile called Notes went on
        // opening the 817-line editor that WIP-450 retired, while the
        // freedesktop layer opened the SPEC §2 workstation. Two rosters,
        // one name, two different apps: the exact WIP-459 hazard.
        { name: qsTr("Notes"),          icon: "nyxus-notes"            ,  exec: "@notes",                 cat: "apps"   },
        { name: qsTr("Calendar"),       icon: "nyxus-calendar" ,          exec: "@calendar",              cat: "apps"   },
        { name: qsTr("Weather"),        icon: "nyxus-weather"     ,       exec: "@weather",               cat: "apps"   },
        { name: qsTr("Store"),          icon: "nyxus-store"            ,  exec: "@store",                 cat: "apps"   },
        // TRK-3756/3757, 2026-09-06 -- the owner's two built apps ("i built a
        // couple apps i need to make sure those have app icons and that
        // they are real apps"). Both were sitting on his machine with no
        // .desktop, no icon and no roster tile -- invisible to Start and to
        // 13q37's roster check either way. Added here AND to 13q13's ROSTER
        // in verify-profile.sh, the same two-place addition WIP-306 (Media)
        // and WIP-461 (Help) made -- a tile here with no roster entry fails
        // 13q13 as "extra"; a roster entry with no tile here fails 13q37.
        //
        // THEY SIT HERE, INSIDE THE apps GROUP, AND NOT AT THE END OF THE
        // ARRAY. Appended after the tools group on 2026-09-07 they were
        // present, correct, and drew in the grid's LAST row -- below the
        // fold of a 240px-floored Flickable, so the first thing the owner
        // saw after the deploy was a Start menu that still did not show
        // his apps. Order in this array IS the visible order; a tile the
        // user has to scroll to find has not been added as far as he is
        // concerned.
        { name: qsTr("Helm"),           icon: "nyxus-helm",               exec: "nyxus-helm",             cat: "apps"   },
        { name: qsTr("Gen Studio"),     icon: "nyxus-gen-studio",         exec: "nyxus-gen-studio",       cat: "apps"   },

        // ONE player: nyxus-media (WIP-306 / TRK-931). Audacious is still
        // packaged (PKG-5, replaceable) but is not a Start tile — two tiles
        // (Media vs Music) is why the owner thought there was no player.
        // 13q13 pins the visible nyxus name as "Media"; do not rename here
        // without migrating that roster.
        { name: qsTr("Media"),          icon: "nyxus-media"      ,        exec: "@media",                 cat: "media"  },
        { name: qsTr("Video"),          icon: "mpv",                      exec: "nyxus-video",            cat: "media"  },
        { name: qsTr("Viewer"),         icon: "nyxus-viewer"   ,          exec: "@viewer",                cat: "media"  },
        { name: qsTr("Reader"),         icon: "nyxus-reader"   ,          exec: "@reader",                cat: "media"  },
        { name: qsTr("Screenshot"),     icon: "nyxus-screenshot"     ,    exec: "@screenshot",            cat: "media"  },
        // Wallpaper Studio folded 2026-08-12 (WIP-490) — Settings' picker
        // and the desktop right-click menu both exec the binary.

        { name: qsTr("Settings"),       icon: "nyxus-settings"    ,       exec: "@settings",              cat: "system" },
        // WIP-461/WIP-703 — Help. It shipped 2026-08-15 with 23 topics and a
        // `NoDisplay=false` .desktop, and 13q13's ROSTER already carried it,
        // and it appeared in NONE of this array's tiles — because that gate
        // only checks this list for nyxus apps OUTSIDE the roster and has no
        // check in the other direction. So the one app in the build whose
        // entire purpose is to be FINDABLE was reachable only from Settings ▸
        // Apps and Open-With. The owner approved this one addition, and this
        // wave has exactly one grant: do not add a second tile here.
        //
        // Gate 13q37 adds the missing direction — every nyxus app in 13q13's
        // ROSTER must have a tile here — so the next app cannot land the same
        // way this one did.
        { name: qsTr("Help"),           icon: "nyxus-help",               exec: "@help",                  cat: "system" },
        // TRK-3752 — Brain, the local assistant, commissioned by the owner
        // on 2026-09-06: "i was suppose to have an AI that knew my system
        // and i could ask it whatever with a chat box". Every piece of it
        // already existed on his machine (Ollama, three pulled models, and
        // ~/nyxus-brain-corpus) and none of it was reachable, so the tile
        // is the deliverable as much as the window is — the same reasoning
        // the Help row above records.
        //
        // `system`, not `tools`: it answers about THIS machine, so it sits
        // with Settings and Hardware rather than with the calculator. Its
        // accent is coral for exactly that reason — see APP_ACCENTS.
        { name: qsTr("Brain"),          icon: "nyxus-brain",              exec: "@brain",                 cat: "system", needs: "brain", keys: "ai assistant chat ask question llm ollama" },
        { name: qsTr("Hardware"),       icon: "nyxus-control",                      exec: "@hardware",              cat: "system" },
        // WIP-463 / GAP-945: gnome-disk-utility. Arch extra desktop id is
        // org.gnome.DiskUtility.desktop (Exec=gnome-disks). The GNOME extra
        // entries (image mounter/writer + that desktop) are NoDisplay'd in
        // customize_airootfs — this tile is the findable path.
        { name: qsTr("Disks"),          icon: "drive-harddisk",           exec: "gnome-disks",            cat: "system" },
        // WIP-495: Clock returns to the Start Menu. It is the only alarm,
        // timer, stopwatch and world clock on the build; the bar clock and
        // the desktop widget only print the time and cannot wake you up.
        { name: qsTr("Clock"),          icon: "nyxus-clock",                    exec: "@clockapp",              cat: "tools"  },
        { name: qsTr("System Monitor"), icon: "nyxus-sysmon-gtk"        , exec: "@sysmon",                cat: "system" },
        // Updater and Backup folded 2026-08-12 (WIP-490) — Settings ▸
        // Updates and Settings ▸ Backup own them, and each page's Tools
        // group opens the app by binary.
        // Account was cut 2026-08-10: it is a nyxus-prefixed app outside the
        // confirmed 18, the same reason Clock/Reminders/Tour went. Settings
        // owns the account page, and nyxus-account.desktop is NoDisplay now,
        // so leaving the tile here would have been the only surface in the
        // build still offering it.
        { name: "Bluetooth",      icon: "bluetooth",                exec: "@flyout:bluetooth",      cat: "system" },
        { name: "Wi-Fi",          icon: "network-wireless",         exec: "@flyout:wifi",           cat: "system" },

        // Ghostty is the Terminal (owner 2026-08-20). Super+Return, this
        // tile, the dock pin, and nyxus-terminal.desktop all exec ghostty.
        // Do not point this at nyxus_terminal.py.
        // Visible name stays "Terminal". keys exist because Start search
        // used to match only `name`, so typing "ghostty" found nothing.
        { name: qsTr("Terminal"),       icon: "nyxus-terminal"    ,       exec: "ghostty",                 cat: "tools", keys: "ghostty tty pty com.mitchellh.ghostty" },
        { name: qsTr("Calculator"),     icon: "nyxus-calculator"      ,   exec: "@calculator",            cat: "tools"  },
        { name: qsTr("Archive"),        icon: "nyxus-archive"    ,        exec: "@archive",               cat: "tools"  }
        // Clipboard folded 2026-08-12 (WIP-490) — a history you summon.
        // SidePanel.qml's CLIPBOARD section is the surface; Settings ▸
        // Clipboard is the configuration and can still open the picker.

    ]

    // TRK-4143 — the roster everything else reads. An entry may declare
    // `needs: "<capability>"`; if that capability is absent on this machine
    // the tile is not in the list at all, so it cannot be clicked, searched,
    // pinned or counted. Entries with no `needs` are always present, which
    // is all of them but Brain.
    //
    // Filtering here rather than at each call site is deliberate: the roster
    // is read by pinnedApps, rosterApps, filteredApps and the "N apps" count,
    // and a tile that is hidden in one and live in another is worse than one
    // that is simply live. See Bus.brainAvailable for why Brain is gated.
    readonly property var allApps: {
        var out = [];
        for (var i = 0; i < root.appRoster.length; i++) {
            var a = root.appRoster[i];
            if (a.needs === "brain" && !Bus.brainAvailable)
                continue;
            out.push(a);
        }
        return out;
    }

    // The six that get the big tiles. A curated constant, not a ranking:
    // see the header — there is no usage data in this build and inventing an
    // order would be the same class of defect as the invented "Recommended"
    // list that P2 removed. Matched against `allApps` so a tile here can
    // never point at something the grid does not also ship.
    //
    // TRK-1578, 2026-08-22 (I18N): the match is on `exec`, NOT on `name`.
    // `name` is now a qsTr() string, so under any translation the old
    // name-match found NOTHING — the pin deck would have come up empty and
    // every pinned app would have appeared twice in the roster, in every
    // language but English, with no error anywhere. `exec` is the identity
    // the shell already launches by and no translator can move it.
    function tileCore(exec) {
        var s = String(exec || "");
        if (s.indexOf("notes") >= 0) return Theme.plumGlow;
        if (s.indexOf("calculator") >= 0) return Theme.plum;
        if (s.indexOf("@media") >= 0 || s.indexOf("nyxus-media") >= 0) return Theme.tealGlow;
        if (s.indexOf("weather") >= 0) return Theme.azureGlow;
        if (s.indexOf("store") >= 0) return Theme.tokenAccentPrimary;
        if (s.indexOf("brain") >= 0) return Theme.plum;
        if (s.indexOf("files") >= 0) return Theme.goldGlow;
        if (s.indexOf("calendar") >= 0) return Theme.tokenAccentPrimary;
        if (s.indexOf("settings") >= 0) return Theme.azureGlow;
        if (s.indexOf("chromium") >= 0) return Theme.azure;
        if (s.indexOf("thunderbird") >= 0) return Theme.plumGlow;
        if (s.indexOf("ghostty") >= 0) return Theme.tokenAccentHairline;
        if (s.indexOf("helm") >= 0) return Theme.plum;
        if (s.indexOf("gen-studio") >= 0) return Theme.plumGlow;
        if (s.indexOf("hardware") >= 0 || s.indexOf("control") >= 0)
            return Theme.goldGlow;
        if (s.indexOf("sysmon") >= 0) return Theme.tokenAccentPrimary;
        if (s.indexOf("clock") >= 0) return Theme.tokenAccentPeak;
        if (s.indexOf("viewer") >= 0) return Theme.azureGlow;
        if (s.indexOf("video") >= 0 || s.indexOf("mpv") >= 0) return Theme.tealGlow;
        return Theme.plumGlow;
    }
    function tilePip(exec) {
        var s = String(exec || "");
        return s.indexOf("calculator") >= 0 || s.indexOf("notes") >= 0;
    }

    readonly property var pinnedExecs: [
        "@files", "chromium", "thunderbird", "@settings", "ghostty",
        "@store"
    ]
    readonly property var pinnedApps: {
        var out = [];
        for (var i = 0; i < root.pinnedExecs.length; i++)
            for (var j = 0; j < root.allApps.length; j++)
                if (root.allApps[j].exec === root.pinnedExecs[i]) {
                    out.push(root.allApps[j]);
                    break;
                }
        return out;
    }
    // Idle list = everything that is not already a PINNED tile, so Files
    // does not appear twice. Search still hits the full table. Category
    // chips hide the pin deck, so those views include pinned names again.
    readonly property var rosterApps: {
        var pin = {};
        for (var i = 0; i < root.pinnedExecs.length; i++)
            pin[root.pinnedExecs[i]] = true;
        if (root.searching)
            return root.filteredApps;
        var out = [];
        for (var j = 0; j < root.allApps.length; j++) {
            var a = root.allApps[j];
            if (pin[a.exec] && root.activeCat === "all")
                continue;
            if (root.activeCat === "all" || a.cat === root.activeCat)
                out.push(a);
        }
        return out;
    }

    // `glyph` is Daily's vertical rail; Classic's chips render the label and
    // ignore it. One model for both, so the two styles cannot disagree about
    // what the categories are.
    readonly property var categories: [
        { key: "all",    label: qsTr("ALL"),    glyph: "\uf00a" },
        { key: "apps",   label: qsTr("APPS"),   glyph: "\uf108" },
        { key: "media",  label: qsTr("MEDIA"),  glyph: "\uf001" },
        { key: "system", label: qsTr("SYSTEM"), glyph: "\uf013" },
        { key: "tools",  label: qsTr("TOOLS"),  glyph: "\uf0ad" }
    ]
    property string activeCat: "all"

    // ── the style switch (WIP-199) ───────────────────────────────────────
    // Settings ▸ Appearance ▸ Start Menu writes `launcher_style`; this is
    // the branch WIP-188's honest toast promised would come. "daily" is the
    // shipped default. "classic" keeps the Atrium below exactly as it was.
    // "orbit" has no QML port yet, so it renders as Daily — the nearest
    // implemented style, stated here rather than silently downgraded to the
    // one the user just chose to leave.
    readonly property bool daily: Prefs.launcherStyle !== "classic"

    function catLabel(k) {
        for (var i = 0; i < categories.length; i++)
            if (categories[i].key === k) return categories[i].label;
        return "APPS";
    }
    // The greeting names the time of day the way a person would say it.
    readonly property string dayPart: {
        var h = clock.date.getHours();
        if (h < 5)  return "Late night";
        if (h < 12) return "Morning";
        if (h < 17) return "Afternoon";
        if (h < 21) return "Evening";
        return "Night";
    }
    // One line, rotated through the hour so it is not always "Welcome back".
    readonly property string helloLine: {
        var n = root.userName;
        var h = clock.date.getHours();
        var i = Math.floor(clock.date.getMinutes() / 20) % 3;
        var pool;
        if (h < 5)
            pool = [qsTr("Still up, %1").arg(n),
                    qsTr("Late night, %1").arg(n),
                    qsTr("Quiet hours, %1").arg(n)];
        else if (h < 12)
            pool = [qsTr("Good morning, %1").arg(n),
                    qsTr("Morning, %1").arg(n),
                    qsTr("Welcome back, %1").arg(n)];
        else if (h < 17)
            pool = [qsTr("Good afternoon, %1").arg(n),
                    qsTr("Afternoon, %1").arg(n),
                    qsTr("Welcome back, %1").arg(n)];
        else if (h < 21)
            pool = [qsTr("Good evening, %1").arg(n),
                    qsTr("Evening, %1").arg(n),
                    qsTr("Welcome back, %1").arg(n)];
        else
            pool = [qsTr("Good night, %1").arg(n),
                    qsTr("Night, %1").arg(n),
                    qsTr("Welcome back, %1").arg(n)];
        return pool[i];
    }

    // A ring gauge for Daily's vitals rail: full-circle hairline track, the
    // value as an arc of its tone, the number in the middle. Drawn, not a
    // font glyph — Vitals.qml's rule, for Vitals.qml's reason.
    component RingGauge: ColumnLayout {
        id: gauge
        property real value: 0            // 0..1
        property color tone: root.icePrimary
        property string label: ""
        property string readout: ""
        spacing: Theme.s2

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 54
            Layout.preferredHeight: 54

            Shape {
                anchors.fill: parent
                antialiasing: true
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Theme.soften(Theme.text, 0.08)
                    strokeWidth: 4
                    fillColor: "transparent"
                    PathAngleArc { centerX: 27; centerY: 27; radiusX: 23; radiusY: 23; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    strokeColor: gauge.tone
                    strokeWidth: 4
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 27; centerY: 27; radiusX: 23; radiusY: 23
                        startAngle: -90
                        sweepAngle: 360 * Math.min(1, Math.max(0, gauge.value))
                        Behavior on sweepAngle {
                            NumberAnimation {
                                duration: Theme.durBase
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveMove
                            }
                        }
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                text: gauge.readout
                color: Theme.text
                font.family: Theme.fUi
                font.pixelSize: Theme.tMicro
                font.weight: Font.Medium
            }
        }
            Text {
            Layout.alignment: Qt.AlignHCenter
            text: gauge.label
            color: Theme.textDim
            font.family: Theme.fUi
            font.pixelSize: Theme.tMicro
            font.letterSpacing: Theme.trackMicro
        }
    }

    // Start SYSTEM rail: CPU / GPU / RAM / NET / FANS, each gated on
    // Sys.has* so a desktop without fans (or a VM without a util GPU)
    // does not draw empty junk. Ice fill; magma only at warn.
    component SystemMeters: ColumnLayout {
        id: meters
        property bool compact: false
        spacing: compact ? Theme.s3 : Theme.s5
        Layout.fillWidth: true

        MeterRow {
            Layout.fillWidth: true
            label: meters.compact ? qsTr("CPU") : qsTr("Processor")
            value: Sys.cpuPercent / 100
            readout: Sys.cpuPercent + "%"
            hot: Sys.cpuPercent >= 90
        }
        MeterRow {
            Layout.fillWidth: true
            visible: Sys.hasGpu
            label: meters.compact ? qsTr("GPU") : qsTr("Graphics")
            value: Sys.gpuPercent / 100
            readout: Sys.gpuText
            hot: Sys.gpuPercent >= 90
        }
        MeterRow {
            Layout.fillWidth: true
            visible: Sys.hasTemp
            label: meters.compact ? qsTr("TEMP") : qsTr("Temperature")
            value: Sys.tempPercent / 100
            readout: Sys.tempText
            hot: Sys.tempC >= 85
        }
        MeterRow {
            Layout.fillWidth: true
            label: meters.compact ? qsTr("RAM") : qsTr("Memory")
            value: Sys.memPercent / 100
            readout: Sys.memText || (Sys.memPercent + "%")
            hot: Sys.memPercent >= 90
        }
        MeterRow {
            Layout.fillWidth: true
            visible: Sys.hasNet
            label: meters.compact ? qsTr("NET") : qsTr("Network")
            value: Sys.netPercent / 100
            readout: Sys.netText
        }
        MeterRow {
            Layout.fillWidth: true
            visible: Sys.hasFans
            label: meters.compact ? qsTr("FANS") : qsTr("Fans")
            value: Sys.fanPercent / 100
            readout: Sys.fanText
            hot: Sys.fanPercent >= 90
        }
        MeterRow {
            Layout.fillWidth: true
            visible: Sys.hasBattery
            label: meters.compact ? (Sys.batteryCharging ? qsTr("CHG") : qsTr("BAT")) : qsTr("Battery")
            value: Sys.batteryPercent / 100
            // Battery is the one meter here whose scale is INVERTED:
            // 95% is good, 8% is the emergency. Banding by magnitude
            // would paint a full battery magma, so the load bands are
            // off and the `hot` predicate below owns the colour.
            banded: false
            readout: Sys.batteryPercent + "%" + (Sys.batteryCharging ? qsTr(" chg") : "")
            hot: !Sys.batteryCharging && Sys.batteryPercent <= 15
        }
    }

    // Same TogglePill as the flyout. Quiet is gone. Shared Sys-backed
    // pills: Wi-Fi, Bluetooth, Do Not Disturb, Mute. Settings is Start-only
    // (the flyout has its own footer). Airplane / Night Light / Keep Awake
    // stay flyout-only — Night Light and Keep Awake are local process state
    // in SidePanel and must not desync with a second copy here.
    // Start-only control chip. Same widget glass as the app tiles: Pane +
    // swell + GlassEdge body 0. Plum stain / hairline for on+hover; magma
    // only on power. Not a circle and not an ice cabochon — those ate the
    // suite's square icon language.
    function holdCaption(t, item, key) {
        // PanelWindow.contentItem is not a QQuickItem here (TypeError on
        // mapToItem). gemCap lives on `card`, so map into the card.
        if (!item || !card)
            return;
        var p = item.mapToItem(card, item.width / 2, 0);
        gemCap.hold(t, p.x, key, p.y);
    }
    function releaseCaption(key) {
        if (gemCap.owner === key)
            gemCap.release();
    }

    // Inline chip = WidgetChip's face (Widgets.qml): panelMid + swellGround
    // + GlassEdge body 0 / wash 0 + glacier[4] 1 px seam. No extra crown.
    // Density is the swell, never GlassEdge.body (WIP-259).
    component GlassChip: Pane {
        id: gchip
        elevation: 1
        bloomAtRest: false
        radius: Theme.r2
        fill: Theme.panelMid
        property real edging: 0.70
        readonly property real seamA: gchip.focusLevel > 0.3 ? 0.85 : 0.45

        CutRect {
            anchors.fill: parent
            radius: gchip.radius
            gradTop:  Theme.swellGroundTop
            gradMid:  Theme.swellGroundMid
            gradFoot: Theme.swellGroundFoot
        }
        GlassEdge {
            anchors.fill: parent
            radiusTL: gchip.radius; radiusTR: gchip.radius
            radiusBR: gchip.radius; radiusBL: gchip.radius
            body: 0
            wash: 0
            edging: gchip.edging
        }
        CutRect {
            anchors.fill: parent
            radius: gchip.radius
            color: "transparent"
            borderWidth: Theme.lookOutlineW
            borderColor: Theme.soften(Theme.lookSeam, gchip.seamA)
            Behavior on borderColor { ColorAnimation { duration: Theme.durQuick } }
        }
    }

    component CrystalChip: Item {
        id: chip
        property string glyph: ""
        property string label: ""
        property bool on: false
        property bool danger: false
        property bool floatName: false
        property int gemPx: 52
        signal tapped()

        implicitWidth: chip.label.length ? Math.max(chip.gemPx + 8, 56) : chip.gemPx
        implicitHeight: chip.label.length ? chip.gemPx + 22 : chip.gemPx
        Layout.fillWidth: true
        Layout.minimumWidth: chip.gemPx
        Layout.minimumHeight: implicitHeight

        readonly property bool hot: chipHov.hovered || chip.on
        readonly property color seam: chip.danger && chipHov.hovered
                                      ? root.magmaInteractive
                                      : (chip.hot ? Theme.plumGlow : root.iceHairline)
        property real lookX: 0
        property real lookY: 0
        HoverHandler {
            id: chipHov
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: {
                if (!chip.floatName || chip.label.length === 0)
                    return;
                if (hovered)
                    root.holdCaption(chip.label, cab, "chip:" + chip.label);
                else
                    root.releaseCaption("chip:" + chip.label);
            }
        }
        TapHandler { onTapped: chip.tapped() }
        Behavior on lookX { NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutQuint } }
        Behavior on lookY { NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutQuint } }

        Item {
            id: cab
            width: chip.gemPx
            height: chip.gemPx
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            scale: chipHov.hovered ? 1.06 : 1.0
            Behavior on scale {
                NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutQuint }
            }

            HoverHandler {
                onPointChanged: {
                    if (!hovered || cab.width < 1)
                        return;
                    chip.lookX = (point.position.x / cab.width) * 2 - 1;
                    chip.lookY = (point.position.y / cab.height) * 2 - 1;
                }
                onHoveredChanged: {
                    if (!hovered) {
                        chip.lookX = 0;
                        chip.lookY = 0;
                    }
                }
            }
            CrystalGem {
                anchors.fill: parent
                hot: chipHov.hovered
                on: chip.on
                danger: chip.danger && chipHov.hovered
                tint: chip.seam
                lookX: chip.lookX
                lookY: chip.lookY
            }
            Text {
                anchors.centerIn: parent
                text: chip.glyph
                font.family: Theme.fIcon
                font.pixelSize: Theme.tLabel
                color: chip.danger && chipHov.hovered ? root.magmaInteractive
                     : (chip.hot ? Theme.text : Theme.textMuted)
            }
        }
        Text {
            visible: chip.label.length > 0 && !chip.floatName
            anchors.top: cab.bottom
            anchors.topMargin: 4
            anchors.left: parent.left
            anchors.right: parent.right
            text: chip.label
            color: chip.hot ? Theme.text : Theme.textMuted
            font.family: Theme.fUi
            font.pixelSize: Theme.tMicro
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            clip: true
        }
    }

    component QuickToggles: GridLayout {
        columns: 2
        rowSpacing: Theme.s4
        columnSpacing: Theme.s3
        Layout.fillWidth: true

        CrystalChip {
            glyph: "\uf1eb"
            label: Sys.wifiOn ? (Sys.wifiName || qsTr("Wi-Fi")) : qsTr("Wi-Fi")
            on: Sys.wifiOn
            onTapped: Bus.openFlyoutAt("wifi")
        }
        CrystalChip {
            glyph: "\uf294"
            label: qsTr("Bluetooth")
            on: Sys.btOn
            onTapped: Bus.openFlyoutAt("bluetooth")
        }
        CrystalChip {
            glyph: "\uf0f3"
            label: qsTr("Quiet")
            on: Sys.dnd
            onTapped: Sys.dnd = !Sys.dnd
        }
        CrystalChip {
            glyph: Sys.muted ? "\uf6a9" : "\uf028"
            label: Sys.muted ? qsTr("Muted") : qsTr("Sound")
            on: !Sys.muted
            onTapped: Sys.toggleMute()
        }
        CrystalChip {
            Layout.columnSpan: 2
            glyph: "\uf013"
            label: qsTr("Settings")
            on: false
            onTapped: root.openQmlSettings("")
        }
    }

    // ── search ───────────────────────────────────────────────────────────
    // Owner 2026-08-19: the placeholder said apps, files AND settings, and
    // only the app-table names were searched — a lie. Hits are:
    //   apps     substring on `allApps` name + exec + optional keys
    //            (08-20: "ghostty" must hit the Terminal tile; Name= is
    //            Terminal, Exec=ghostty, desktop id com.mitchellh.ghostty)
    //   settings SettingsCatalog.search (title / keywords / blurb / key),
    //            QML Settings via `@settings:<key>`, never PATH
    //   files    Places + recents already on this surface, by name
    // Two-character floor on settings so a lone "a" does not dump 40 pages.
    // Cap of 8 settings hits: Start is not a second Settings sidebar.
    // Enter still hands an unmatched query to nyxus-launcher / rofi / wofi.
    property string query: ""
    readonly property bool searching: root.query.trim() !== ""
    function appMatchesQuery(a, q) {
        if (!q)
            return true;
        var hay = ((a.name || "") + " " + (a.exec || "") + " " + (a.keys || "")).toLowerCase();
        return hay.indexOf(q) !== -1;
    }
    readonly property var filteredApps: {
        var q = root.query.trim().toLowerCase();
        var out = [];
        for (var i = 0; i < root.allApps.length; i++) {
            var a = root.allApps[i];
            if (q !== "") {
                if (root.appMatchesQuery(a, q)) out.push(a);
            } else if (root.activeCat === "all" || a.cat === root.activeCat) {
                out.push(a);
            }
        }
        if (q.length >= 2) {
            var pages = SettingsCatalog.search(root.query.trim());
            var cap = Math.min(pages.length, 8);
            for (var j = 0; j < cap; j++) {
                var p = pages[j];
                out.push({
                    name: p.title,
                    icon: "preferences-system",
                    exec: "@settings:" + p.key,
                    cat: "system",
                    kind: "settings",
                    glyph: p.glyph
                });
            }
            for (var k = 0; k < root.places.length; k++) {
                if (root.places[k].name.toLowerCase().indexOf(q) !== -1)
                    out.push({
                        name: root.places[k].name,
                        icon: root.placeIcon(root.places[k].name),
                        exec: "@file:" + root.places[k].path,
                        cat: "apps",
                        kind: "file"
                    });
            }
            for (var r = 0; r < root.recentFiles.length; r++) {
                if (root.recentFiles[r].name.toLowerCase().indexOf(q) !== -1)
                    out.push({
                        name: root.recentFiles[r].name,
                        icon: "text-x-generic",
                        exec: "@file:" + root.recentFiles[r].path,
                        cat: "apps",
                        kind: "file"
                    });
            }
        }
        return out;
    }
    readonly property string searchCountLabel: {
        var n = root.filteredApps.length;
        if (root.searching)
            return n + (n === 1 ? " match" : " matches");
        return n + (n === 1 ? " app" : " apps");
    }
    // WIP-101. An app entry may name an INTERNAL surface instead of a binary,
    // as `@flyout:<section>`. Bluetooth and Wi-Fi used to launch
    // blueman-manager and nm-connection-editor — two stock GTK windows the
    // owner photographed and correctly called default — for the want of
    // anywhere else to send them. The flyout now carries both, so the Start
    // menu opens ours rather than shelling out of the build entirely.
    //
    // Checked BEFORE execDetached, so an internal name can never reach a
    // shell. `sh -c` is fine for the app list, which is a fixed table in this
    // file, but a scheme that falls through to it would be one refactor away
    // from being an injection point.
    // Raise the in-shell QML Settings window. Do NOT exec `nyxus-settings`:
    // on this host PATH finds ~/.local/bin/nyxus-settings (mtime 16:51),
    // which is NYXUS Panel Settings (`io.nyxus.settings`) — stars + orbs,
    // the other product. Owner 2026-08-19: the button opens QML Settings.
    function openQmlSettings(key) {
        Bus.launcherOpen = false;
        Bus.openSettings(key || "");
        Bus.appLaunched();
    }

    function isSettingsExec(cmd) {
        var s = String(cmd || "");
        if (s === "@settings" || s.indexOf("@settings") === 0)
            return true;
        if (s.indexOf("nyxus-settings") !== -1 || s.indexOf("nyxus_settings") !== -1)
            return true;
        if (s.indexOf("io.nyxus.settings") !== -1)
            return true;
        return false;
    }

    // Launch an app. The command is a string because the app table is data,
    // not components. `@settings` is the QML control center (see above);
    // `@flyout:` opens a SidePanel section. Everything else is argv through
    // sh -c so a .desktop Exec line still works, with the table's own rows
    // kept too dull to be an injection point.
    function launch(cmd) {
        if (cmd && cmd.indexOf("@flyout:") === 0) {
            Bus.launcherOpen = false;
            Bus.openFlyoutAt(cmd.substring(8));
            return;
        }
        if (cmd && cmd.indexOf("@file:") === 0) {
            root.openPath(cmd.substring(6));
            return;
        }
        if (cmd && cmd.indexOf("@settings:") === 0) {
            root.openQmlSettings(cmd.substring(10));
            return;
        }
        if (root.isSettingsExec(cmd)) {
            root.openQmlSettings("");
            return;
        }
        if (cmd === "@notes" || String(cmd || "").indexOf("nyxus-notes") !== -1
                || String(cmd || "").indexOf("nyxus_notes") !== -1) {
            Bus.launcherOpen = false;
            Bus.openNotes();
            Bus.appLaunched();
            return;
        }
        if (cmd === "@calculator" || String(cmd || "").indexOf("nyxus-calculator") !== -1
                || String(cmd || "").indexOf("nyxus_calculator") !== -1) {
            Bus.launcherOpen = false;
            Bus.openCalculator();
            Bus.appLaunched();
            return;
        }
        if (cmd === "@media" || String(cmd || "").indexOf("nyxus-media") !== -1
                || String(cmd || "").indexOf("nyxus_media") !== -1) {
            Bus.launcherOpen = false;
            Bus.openMedia();
            Bus.appLaunched();
            return;
        }
        if (cmd === "@files" || String(cmd || "").indexOf("nyxus-files") !== -1
                || String(cmd || "").indexOf("nyxus_files") !== -1) {
            Bus.launcherOpen = false;
            Bus.openFiles();
            Bus.appLaunched();
            return;
        }
        if (cmd === "@store" || String(cmd || "").indexOf("nyxus-store") !== -1
                || String(cmd || "").indexOf("nyxus_store") !== -1) {
            Bus.launcherOpen = false;
            Bus.openStore();
            Bus.appLaunched();
            return;
        }
        if (cmd === "@reader" || String(cmd || "").indexOf("nyxus-reader") !== -1
                || String(cmd || "").indexOf("nyxus_reader") !== -1) {
            Bus.launcherOpen = false;
            Bus.openReader();
            Bus.appLaunched();
            return;
        }
        if (cmd === "@calendar" || String(cmd || "").indexOf("nyxus-calendar") !== -1
                || String(cmd || "").indexOf("nyxus_calendar") !== -1) {
            Bus.launcherOpen = false;
            Bus.openCalendar();
            Bus.appLaunched();
            return;
        }
        if (cmd === "@viewer" || String(cmd || "").indexOf("nyxus-viewer") !== -1
                || String(cmd || "").indexOf("nyxus_viewer") !== -1) {
            Bus.launcherOpen = false;
            Bus.openViewer();
            Bus.appLaunched();
            return;
        }
        if (cmd === "@archive" || String(cmd || "").indexOf("nyxus-archive") !== -1
                || String(cmd || "").indexOf("nyxus_archive") !== -1) {
            Bus.launcherOpen = false;
            Bus.openArchive();
            Bus.appLaunched();
            return;
        }
        if (cmd === "@weather" || String(cmd || "").indexOf("nyxus-weather") !== -1
                || String(cmd || "").indexOf("nyxus_weather") !== -1) {
            Bus.launcherOpen = false;
            Bus.openWeather();
            Bus.appLaunched();
            return;
        }
        if (cmd === "@clockapp" || String(cmd || "").indexOf("nyxus-clock") !== -1
                || String(cmd || "").indexOf("nyxus_clock") !== -1) {
            Bus.launcherOpen = false;
            Bus.openClockApp();
            Bus.appLaunched();
            return;
        }
        if (cmd === "@screenshot" || String(cmd || "").indexOf("nyxus-screenshot") !== -1
                || String(cmd || "").indexOf("nyxus_screenshot") !== -1) {
            Bus.launcherOpen = false;
            Bus.openScreenshot();
            Bus.appLaunched();
            return;
        }
        if (cmd === "@help" || String(cmd || "").indexOf("nyxus-help") !== -1
                || String(cmd || "").indexOf("nyxus_help") !== -1) {
            Bus.launcherOpen = false;
            Bus.openHelp();
            Bus.appLaunched();
            return;
        }
        if (cmd === "@brain" || String(cmd || "").indexOf("nyxus-brain") !== -1
                || String(cmd || "").indexOf("nyxus_brain") !== -1) {
            Bus.launcherOpen = false;
            Bus.openBrain();
            Bus.appLaunched();
            return;
        }
        if (cmd === "@hardware" || String(cmd || "").indexOf("nyxus-control") !== -1
                || String(cmd || "").indexOf("nyxus_control") !== -1) {
            Bus.launcherOpen = false;
            Bus.openHardware();
            Bus.appLaunched();
            return;
        }
        if (cmd === "@sysmon" || String(cmd || "").indexOf("nyxus-sysmon") !== -1
                || String(cmd || "").indexOf("nyxus_sysmon") !== -1) {
            Bus.launcherOpen = false;
            Bus.openSysmon();
            Bus.appLaunched();
            return;
        }
        Quickshell.execDetached(["sh", "-c", cmd]);
        Bus.launcherOpen = false;
        Bus.appLaunched();
    }
    // argv directly, never `sh -c` — filenames contain spaces and quotes and
    // this must not be a shell injection point.
    function openPath(p) {
        Quickshell.execDetached(["xdg-open", p]);
        Bus.launcherOpen = false;
        Bus.appLaunched();
    }
    // POSIX single-quoting, so a query can never become shell syntax. The
    // handoff below is the one place in this file where USER INPUT reaches a
    // `sh -c`, and the app table's own comment (see `launch`) says that is
    // exactly the thing that must not happen by accident.
    function shq(s) {
        return "'" + String(s).split("'").join("'\\''") + "'";
    }
    function acceptSearch() {
        if (root.filteredApps.length > 0) {
            root.launch(root.filteredApps[0].exec);
            return;
        }
        // WIP-640(a). The grid is a substring match over a FIXED table of the
        // build's own 23 apps (see `allApps`), so anything else on the machine
        // — the live ISO's "Install NYXUS · Suxyn" being the one a first-boot
        // user actually needs — can only be found by the full launcher, which
        // reads the freedesktop entries and their Keywords. That handoff
        // existed, and THREW THE TYPED QUERY AWAY: you typed "install", got
        // "0 apps", pressed Enter as the empty state told you to, and were
        // handed an empty search field to type it into again.
        //
        // The query now travels. `nyxus-launcher` takes it as a positional
        // argument (its `Launcher.run` pops argv into the search entry);
        // rofi's `-filter` and wofi's `--search` are the same idea in the two
        // fallbacks, so all three doors open on the same word.
        const q = root.shq(root.query.trim());
        root.launch("nyxus-launcher " + q
                    + " || rofi -show drun -filter " + q
                    + " || wofi --show drun --search " + q);
    }

    // ── recents · real XDG entries ───────────────────────────────────────
    // Reads ~/.local/share/recently-used.xbel, the file GTK and our own apps
    // already write. Entries whose file no longer exists are dropped, so
    // this cannot list something that is not there.
    property var recentFiles: []
    Process {
        id: recentsProc
        command: ["python3", "-c",
            "import os,sys,urllib.parse\n"
            + "import xml.etree.ElementTree as ET\n"
            + "p=os.path.expanduser('~/.local/share/recently-used.xbel')\n"
            + "try: root=ET.parse(p).getroot()\n"
            + "except Exception: sys.exit(0)\n"
            + "out=[]\n"
            + "for b in root.iter('bookmark'):\n"
            + "    h=b.get('href') or ''\n"
            + "    if not h.startswith('file://'): continue\n"
            + "    f=urllib.parse.unquote(h[7:])\n"
            + "    if not os.path.isfile(f): continue\n"
            + "    out.append((b.get('visited') or b.get('modified') or '', f))\n"
            + "out.sort(reverse=True)\n"
            + "seen=set()\n"
            + "for _,f in out:\n"
            + "    if f in seen: continue\n"
            + "    seen.add(f)\n"
            + "    print('%s\\t%s\\t%d\\t%s' % (os.path.basename(f), os.path.basename(os.path.dirname(f)), os.path.getmtime(f), f))\n"
            + "    if len(seen)>=4: break\n"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i].trim()) continue;
                    var p = lines[i].split("\t");
                    if (p.length < 4) continue;
                    out.push({ name: p[0], sub: p[1] + " · " + root.ago(parseInt(p[2])), path: p[3] });
                }
                root.recentFiles = out;
            }
        }
    }
    // ── places · the folders that actually exist ─────────────────────────
    // The glance column used to end in a void whenever RECENT was empty —
    // which on a fresh machine is always, and "40% of the panel is a hole"
    // was most of what the owner meant by bla. This fills it with the one
    // thing every file manager on every platform puts in a sidebar, and it
    // is checked rather than assumed: the list is built from directories
    // that are on disk right now, so a machine without ~/Music does not get
    // a Music row that opens nothing.
    property var places: []
    Process {
        id: placesProc
        command: ["python3", "-c",
            "import os\n"
            + "want=[('Home',''),('Documents','Documents'),('Downloads','Downloads'),\n"
            + "      ('Pictures','Pictures'),('Music','Music'),('Videos','Videos')]\n"
            + "h=os.path.expanduser('~')\n"
            + "for label,sub in want:\n"
            + "    p=os.path.join(h,sub) if sub else h\n"
            + "    if os.path.isdir(p): print('%s\\t%s' % (label,p))\n"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    if (!lines[i].trim()) continue;
                    var p = lines[i].split("\t");
                    if (p.length < 2) continue;
                    out.push({ name: p[0], path: p[1] });
                }
                root.places = out;
            }
        }
    }
    function placeIcon(n) {
        if (n === "Home") return "user-home";
        if (n === "Documents") return "folder-documents";
        if (n === "Downloads") return "folder-download";
        if (n === "Pictures") return "folder-pictures";
        if (n === "Music") return "folder-music";
        if (n === "Videos") return "folder-videos";
        return "folder";
    }

    // Icon from the real filename, so the row cannot claim a type the file
    // is not. Anything unrecognised falls through to the generic document.
    function iconFor(name) {
        var n = name.toLowerCase();
        var i = n.lastIndexOf(".");
        var e = i < 0 ? "" : n.substring(i + 1);
        if (e === "pdf") return "application-pdf";
        if (["png", "jpg", "jpeg", "gif", "webp", "svg", "bmp"].indexOf(e) !== -1) return "image-x-generic";
        if (["mp3", "flac", "ogg", "wav", "m4a", "opus"].indexOf(e) !== -1) return "audio-x-generic";
        if (["mp4", "mkv", "webm", "avi", "mov"].indexOf(e) !== -1) return "video-x-generic";
        if (["zip", "tar", "gz", "xz", "zst", "7z", "rar", "bz2"].indexOf(e) !== -1) return "package-x-generic";
        if (["odt", "doc", "docx", "rtf"].indexOf(e) !== -1) return "x-office-document";
        if (["ods", "xls", "xlsx", "csv"].indexOf(e) !== -1) return "x-office-spreadsheet";
        return "text-x-generic";
    }
    function ago(mtime) {
        var s = Math.max(0, Math.floor(Date.now() / 1000) - mtime);
        if (s < 3600) return Math.max(1, Math.floor(s / 60)) + "m ago";
        if (s < 86400) return Math.floor(s / 3600) + "h ago";
        if (s < 172800) return "Yesterday";
        return Math.floor(s / 86400) + "d ago";
    }

    // Nothing reads /proc unless somebody is looking at the numbers. The
    // Flyout owns the same property; both are plain `Bus.*Open` bindings on
    // separate surfaces that can never be open at once (Bus.toggle* closes
    // the others), so they cannot fight over it.
    Binding {
        target: Sys
        property: "vitalsActive"
        value: true
        when: Bus.launcherOpen
    }

    Connections {
        target: Bus
        function onLauncherOpenChanged() {
            if (Bus.launcherOpen) {
                // `search.text` as well as `root.query`. Clearing only the
                // query left the previous search STILL IN THE FIELD while the
                // model thought it was empty, so the menu reopened showing a
                // stale term over an unfiltered grid — and the next keystroke
                // appended to it. Pre-existing; caught by opening the menu on
                // a live session rather than by reading the handler.
                root.query = "";
                search.text = "";
                dSearch.text = "";
                root.activeCat = "all";
                recentsProc.running = true;
                placesProc.running = true;
                // WIP-640(d). The avatars ask Sys whether ~/.face exists
                // rather than pointing an Image at a path that usually does
                // not; re-asking ON OPEN is what preserves the `cache:false`
                // contract these Images were written with — a photo set in
                // Settings shows the next time the menu opens.
                Sys.refreshFace();
                // HyprlandFocusGrab is active, but `focus: true` on the
                // TextInput does not become activeFocus until the grab
                // lands — nested stills showed the placeholder with no
                // caret and a 1 px rest ring, i.e. a field that does not
                // look focused. One tick later, after the grab, put the
                // caret in the field that is actually showing.
                searchFocusSoon.restart();
            }
        }
    }
    Timer {
        id: searchFocusSoon
        interval: 80
        onTriggered: {
            if (!Bus.launcherOpen)
                return;
            if (root.daily)
                dSearch.forceActiveFocus();
            else
                search.forceActiveFocus();
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // Bottom-LEFT, above the horizon zone: this surface belongs to the Sigil.
    // It stops at the top of the exclusive zone rather than covering it, so
    // the clock is never hidden by anything (HORIZON §5.3).
    //
    // Owner 2026-08-19: optical air above the bar — not flush, not floating.
    // `barGap` is that gap. Bloom pad still has to hang into the window so
    // the glow is not sliced at the edge (Flyout.qml).
    readonly property int barGap: Theme.s5
    anchors { bottom: true; left: true }
    // TRK-1800: the card's left edge lines up with the Sigil, which Bar.qml
    // puts at `Theme.s7`. It used to sit hard against x=0 while the wordmark
    // it grows out of started 20 px in, so the two never agreed.
    margins {
        bottom: Theme.chromeH - Theme.bloomPad + root.barGap
        left: Theme.s7
    }

    // ── the swell may never be taller than the screen it opens on (WIP-325) ──
    // These were flat 760 / 1040. 760 is fine on the owner's 1920×1080 panel
    // and is 44px too tall on a 1280×800 one: the surface is anchored to the
    // bottom above the bar, so the excess comes off the TOP, and `hyprctl
    // layers` on the booted 08-11 ISO read `nyxus-launcher xywh: 0 -44 1064
    // 784` — the "Afternoon, nyx" greeting and the clock were drawn above the
    // top edge of the display and simply never seen.
    //
    // Nothing about it looked broken, which is why it survived: the menu is
    // full of content, so a missing header reads as a design choice. GAP-2 is
    // "hardware other than this laptop", and this is what that gap looks like
    // in practice.
    //
    // Clamp instead of shrink: on a large panel these still resolve to the
    // designed 760/1040 and nothing moves. `screenGap` keeps the swell off the
    // very top edge so it still reads as a surface rather than a full screen.
    // Daily matches the Settings hub (960×640, homeMax 720): a scannable
    // card, not a second desktop. Classic keeps the Atrium size. GAP-2
    // clamp still applies — never taller/wider than the screen minus bar.
    readonly property int screenGap: 16
    readonly property int availH: (screen ? screen.height : 800) - Theme.chromeH - root.barGap - screenGap
    readonly property int availW: (screen ? screen.width  : 1280) - screenGap
    // TRK-1808: Daily is 560, the mockup's height. It was 600, and when the
    // pinned deck went from two rows of 112 to one row of 80 that freed ~150 px
    // which simply became empty card under the last app row -- I closed a gap in
    // the grid and opened a bigger one below it. Classic keeps 760; its Atrium
    // layout fills the height it asks for.
    // TRK-3364 — Daily grows a right-hand system panel (the owner's 08-28
    // mockup: quick-settings tiles + a live machine snapshot beside the
    // deck), so its width takes the panel's 264 + one s6 gutter on top of
    // the old 760. Height is unchanged; the availW/availH clamp still rules.
    readonly property int swellHeight: Math.min(root.daily ? 560 : 760, availH)
    readonly property int swellWidth: Math.min(
        (root.daily && !Theme.lookMagma) ? 1040 : 760, availW)
    readonly property int layerW: swellWidth + Theme.bloomPad
    readonly property int layerH: swellHeight + Theme.bloomPad

    // WIP-252 never-unmaps this layer. Hyprland kept the first-map size when
    // only implicit size changed (Daily 760×600 stayed Classic 1040×760:
    // `nyxus-launcher xywh 0 224 1064 784`). An explicit `width`/`height`
    // resized it on tty1 to **784×624** (21:35, qs 527361) — then qs warned
    // `Setting width/height is deprecated. Set implicitWidth instead` on
    // every reload. Bake first-map is Daily (`Prefs.launcherStyle`), so
    // implicit IS the first size. Do not set `width`/`height` (deprecated).
    // GAP-2 clamp still applies above.
    implicitWidth: layerW
    implicitHeight: layerH

    // The swell's own untransformed rect, NOT `item: card` — see the long
    // note in Flyout.qml. `item:` maps through the item's transform list, the
    // rise is a Translate, and the resulting mask sat a full swellHeight
    // below the panel, so every click inside the Start menu fell through and
    // dismissed it instead of launching anything.
    mask: Region {
        x: card.x
        y: card.y
        // WIP-252: the window never unmaps now, so the CLOSED state must be
        // expressed here — an empty region makes the mapped window fully
        // click-through, or the invisible surface would eat every click in
        // the card's corner (the 4c3661e lesson).
        width: root.contentShown ? card.width : 0
        height: root.contentShown ? card.height : 0
    }

    // THIS WINDOW NEVER UNMAPS (WIP-252). Every crash report in the cache
    // — WIP-230's six, the 20:2x pair, the 21:0x pair, tonight's, and the
    // four my own IPC stress rig produced — dies the same way: an update
    // posted by something inside this window is delivered while the
    // backing window is being hidden/destroyed, and addToDirtyList walks
    // freed memory. WIP-245 gated the sim, WIP-249 gated the map-side
    // race, a quiesce-then-unmap linger STILL lost the race under stress
    // (4 crashes in 60 toggle cycles). The only state that has never
    // crashed, all day, under every abuse, is a window that stays mapped —
    // the Bar. So the Launcher becomes one: `visible: true`, permanently;
    // CLOSED is expressed as an empty input mask (click-through, above)
    // plus hidden content (the card, below) once the sink animation and a
    // drain beat have passed. Unmapping is the murder weapon; we took it
    // away.
    readonly property bool contentShown: Bus.launcherOpen || unmapLinger.running
    Timer { id: unmapLinger; interval: 650 }
    Connections {
        target: Bus
        function onLauncherOpenChanged() {
            if (Bus.launcherOpen) unmapLinger.stop();
            else unmapLinger.restart();
        }
    }

    HyprlandFocusGrab {
        windows: [root]
        active: Bus.launcherOpen
        onCleared: Bus.launcherOpen = false
    }
    Shortcut {
        sequence: "Escape"
        enabled: Bus.launcherOpen
        onActivated: Bus.launcherOpen = false
    }

    // ── the Swell ────────────────────────────────────────────────────────
    Pane {
        id: card
        // WIP-252: the window stays mapped forever; the CARD is what goes
        // away. Item-level visibility inside a live window is ordinary QML —
        // no scene-graph teardown, no posted-event race. The linger keeps it
        // visible through the sink animation so the fade completes on screen.
        visible: root.contentShown
        anchors { left: parent.left; bottom: parent.bottom }
        anchors.bottomMargin: Theme.bloomPad
        width: root.swellWidth
        height: root.swellHeight
        clip: true
        elevation: 2
        // TRK-3651 — widgets have no outer bloom; a 20 px ramp here was the
        // extra "layer" on Start that the chips never drew.
        bloomAtRest: false
        // The start menu is glass, at the bar's density. It was
        // `glassFillStrong` (0.66) — a black slab with a rim, which is exactly
        // what the owner photographed and rejected. `surfaceMid` is the bar's
        // own body; the GlassEdge's Glaze below supplies the depth the bar
        // gets from its gradient. Theme.qml § THE MATERIAL FORMULA.
        fill: Theme.panelMid   // TRK-1812
        // ── ALL FOUR CORNERS, ONE RADIUS (WIP-335) ──────────────────────────
        // Owner, 2026-08-11, looking at the live menu: "the corners around the
        // edges of the start menu, they look like there sharp and then round
        // both — we need to fix that."
        //
        // It was `r0` on three corners and `r3` on the top-right only, on the
        // reasoning that top-right is "the only corner that faces open space".
        // That reasoning describes a panel welded into the screen corner, and
        // this is not one: the swell floats clear of the right half of the
        // display and stands off the bar, so its bottom-right and top-left sit
        // over wallpaper too. One square corner beside one round one is what
        // reads as unfinished — the eye sees the mix, not the logic.
        //
        // The reference language the owner set for this build is a fully
        // rounded floating card, and the rest of the shell already follows it
        // (Pane, tiles, pills, toasts, flyouts). This is the last surface that
        // did not. All three layers below — body, GlassEdge rim and the
        // ReactiveEdge border — carry the same four values, or the rim traces
        // a different outline than the body it is meant to edge.
        radiusTL: Theme.r3
        radiusTR: Theme.r3
        radiusBR: Theme.r3
        radiusBL: Theme.r3

        // TRK-3082: Start is Overlay over windows. Same sky crop as the
        // chips so the glass mixes plum the way they do. z -1 is behind
        // Pane's fill shader. Owner 20:18 left this file alone because the
        // stack already matched; the mix still needs the sky underneath.
        SkyBehind {
            z: -1
            anchors.fill: parent
            live: root.contentShown
            paneScreenX: Theme.s7 + card.x
            paneScreenY: (root.screen ? root.screen.height : 800)
                         - (Theme.chromeH - Theme.bloomPad + root.barGap)
                         - root.implicitHeight + card.y
            screenW: root.screen ? root.screen.width : 1280
            screenH: root.screen ? root.screen.height : 800
            radius: Theme.r3
        }

        // The rise is a TRANSFORM, not a `y` binding. `y` participates in
        // the window's implicit size, so animating it makes the surface
        // resize the window that sizes the surface — Qt calls that a binding
        // loop and re-evaluates it every frame for nothing.
        transform: Translate {
            y: Bus.launcherOpen ? 0 : root.swellHeight
            Behavior on y {
                NumberAnimation {
                    id: openAnim
                    duration: Bus.launcherOpen ? Theme.durRise : Theme.durSink
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Bus.launcherOpen ? Theme.curveRise : Theme.curveSink
                }
            }
        }
        opacity: Bus.launcherOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.durQuick } }

        // GlassEdge / MirrorEdge / the glacier[4] seam sit AFTER the living
        // paint, same as SidePanel: the paint is the body, the edge is the
        // pane. Swell ground is the next child — under the paint (WIP-265).

        // ── the living paint (see Bar.qml for the contract) ──────────────
        // THE WHOLE CARD, and it answers your hand anywhere on it.
        //
        // 2026-08-09, the owner, looking at the open menu on the live screen:
        //   "you can kind of faintly see the liquid swirls — I want to be able
        //    to see them like I do on the bottom bar, but make it so anywhere
        //    you move your mouse in the start menu the swirls activate, not
        //    just the bottom of the start menu."
        //
        // That supersedes the base-only paint this block used to hold, and the
        // reasoning it carried ("a page of labels does not want a light show
        // behind it"). It was not wrong about the risk — it was wrong about
        // where legibility comes from. A 96 px strip at opacity 0.26 under a
        // 0.52→0.80 veil is not a quiet light, it is an invisible one: the
        // owner could not see the build's own signature on its most-opened
        // surface. Legibility is now bought where HORIZON says to buy it —
        // locally, under the type, from the cards' own bodies and the
        // masthead's veil — instead of by dimming the paint to nothing.
        //
        // Brightness is the BAR's, exactly, because "like the bottom bar" is a
        // measurement and not a mood: opacity 0.85, exposure 1.45, bloom 0.80,
        // introStrength 0.55. See Bar.qml § brightness for why these three
        // move together — dye saturation, not gain, is what kills filaments.
        //
        // ── the Swell body, MOVED UNDER THE PAINT (WIP-265) ──────────
        // Identical change and identical reasoning to SidePanel.qml — see
        // the block above its swirl Loader. `GlassEdge` draws ABOVE this
        // Loader, so WIP-259's `body: 1` was darkening the living paint
        // rather than the window behind the card, which is both why the
        // Start Menu's paint went flat AND why a terminal was still legible
        // straight across the app grid. Density comes from
        // `Theme § THE SWELL GROUND`, denser than WIP-259's over-the-paint
        // numbers because underneath it is the only thing doing the job.
        CutRect {
            anchors.fill: parent
            radius: Theme.r3
            gradTop:  Theme.swellGroundTop
            gradMid:  Theme.swellGroundMid
            gradFoot: Theme.swellGroundFoot
        }

        // ⚠ Loaded ON DEMAND — a ShaderEffectSource in a never-exposed
        // window segfaults the scene graph (see Flyout.qml).
        Loader {
            id: cardSwirl
            anchors.fill: parent
            // Owner 2026-09-10: Start was too plain vs the bar and the
            // widget chips. The 08-20 ISO lock (`active: false`) is lifted.
            // Gate on the pref AND on contentShown so the 30-layer
            // ShaderEffectSource chain tears down on close — a live solver
            // in a never-unmapped window (WIP-252) is the segfault this
            // Loader exists to prevent. contentShown holds through the
            // sink linger, then drops; the window itself stays mapped.
            active: Prefs.swirlEnabled && root.contentShown
            sourceComponent: Swirl {
                id: cardPaint
                intensity: Prefs.swirlIntensity
                // The card's own corner. Only the TR faces open space; the
                // other three sit flush to the screen edges, and the solver's
                // vignette has already faded the paint to nothing there, so
                // one radius for all four costs nothing visible.
                cornerRadius: Theme.r3
                // Fed from the Wake below, not from its own HoverHandler: the
                // paint must answer the pointer over the whole page including
                // the parts the tiles and the app list cover, and a handler
                // inside the Swirl would sit UNDER them and never see it.
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
                alwaysAlive: true
                batterySaver: false
                restOpacity: 1.0
                maxStepHz: 72
                // Exact bar recipe (BarSeam.qml). impulseRadius is a fraction
                // of THIS item's height, so the bar's 0.10 is ~17 px on a
                // 168 px strip and ~58 px on Start — that is why the first
                // port looked huge. Scale to the bar's paint height so a
                // strand is the same number of pixels here as on the bar.
                paintMode: Theme.lookMagma
                    ? "paint"
                    : Prefs.swirlMode
                ramp: PaintMood.ramp
                introStrength: 0.55
                opacity: 0.85
                exposure: 0.92
                saturation: Theme.lookMagma ? 1.22 : 1.0
                sheen: Theme.lookMagma ? 0.35 : 0.18
                injectGain: Theme.lookMagma ? 0.70 : 0.38
                sweepLo: 0
                sweepHi: 1.0
                sweepGamma: Theme.lookMagma ? 1.35 : 1.0
                impulseRadius: (Theme.lookMagma ? 0.10 : 0.15)
                               * Theme.paintH / Math.max(height, Theme.paintH)
                curlAmp: Theme.lookMagma ? 0.64 : 1.55
                force: 5600
                decayRate: 0.36
                ambientAmp: 0.86
                ambientVortex: 0.90
                ambientCurrentX: 0.042
                ambientCurrentY: 0.032
                ambientEvenSweep: true
                ambientDye: 0.48
                velocityDecay: 0.12
                pointerForceMul: 1.21
                simShort: 96
                bloom: Theme.lookMagma ? 0.80 : 0.45
                audioBass: Beat.bass
                audioMid: Beat.mid
                audioHigh: Beat.high
                audioPulse: Beat.pulse
                audioKick: Beat.kick
                audioDrive: 4.5
                audioDyeKick: 1.6
                musicActive: Beat.hot
            }
        }

        // ── the Wake · the paint answers your hand anywhere on the page ──
        // The bar's Wake (Bar.qml § the Wake), lifted onto the Swell. Same
        // contract: only feed on REAL movement, because `pointChanged` also
        // fires for velocity decay and for frame callbacks, and feeding a
        // stationary pointer 60 times a second holds the solver awake forever
        // for nothing.
        //
        // A HoverHandler and not a MouseArea, and it lives on the Swell rather
        // than over the content: a HoverHandler is passive, so every tile,
        // row, scrollbar and the search field keep their clicks and their own
        // hover states. This only watches.
        property real _wakeX: -1
        property real _wakeY: -1
        // An untyped handle on the loaded Swirl, and the type matters.
        // Loader.item is declared QObject, so a direct feedAt() through it
        // trips the linter's missing-property check — the same warning class
        // as the undefined binding that shipped the unusable 2026.08.07 ISO.
        // The obvious silencer, a cast to Swirl, resolved to NULL at runtime
        // and killed the Wake outright (WIP-216). A var is untyped, so member
        // lookup is dynamic: nothing to warn about, and nothing to null.
        // A `var`, deliberately, and NOT `cardSwirl.item as Swirl`.
        // The cast was the previous attempt at silencing qmllint and it
        // returned null at runtime, which killed the Wake outright: the paint
        // still loaded and still ran its intro, but nothing fed it, so a few
        // seconds after opening the menu the field decayed and the owner
        // reported 'start menu still has no swirls'. It was not the drift
        // that time; it was this line.
        // `var` is untyped, so member lookup is dynamic — qmllint raises no
        // missing-property warning on it, and the call cannot be nulled by a
        // cast that does not resolve.
        property var paint: cardSwirl.item
        HoverHandler {
            id: cardWake
            onHoveredChanged: if (!hovered) { card._wakeX = -1; card._wakeY = -1; }
            onPointChanged: {
                if (!hovered || !Prefs.swirlEnabled || !card.paint)
                    return;
                var px = point.position.x;
                var py = point.position.y;
                if (Math.abs(px - card._wakeX) < 1.0 && Math.abs(py - card._wakeY) < 1.0)
                    return;
                card._wakeX = px;
                card._wakeY = py;
                // Straight through, both axes. The bar has to compress y into
                // 0.14–0.46 because half its paint item hangs off the bottom of
                // the screen; this one fills its card exactly, so the pointer's
                // position IS the stroke's position and the paint gathers under
                // your hand wherever it is.
                card.paint.feedAt(px / Math.max(card.width, 1),
                                  py / Math.max(card.height, 1));
            }
        }

        // The glass sits ON the paint: Lip / Sheen / Glaze from the one
        // component the bar and the widget chips use. body 0 — density is
        // the swellGround under the swirl, not a second darkener over it
        // (WIP-259 / WIP-265). wash 0 — TRK-3056, no extra crown strip.
        GlassEdge {
            anchors.fill: parent
            radiusTL: Theme.r3
            radiusTR: Theme.r3
            radiusBR: Theme.r3
            radiusBL: Theme.r3
            body: 0
            wash: 0
            edging: 0.85
        }

        ReactiveEdge {
            livingEdgeEnabled: false   // owner 2026-09-07: not the Start menu
            haloAtRest: false
            radiusTL: Theme.r3
            radiusTR: Theme.r3
            radiusBR: Theme.r3
            radiusBL: Theme.r3
        }

        MirrorEdge {
            radiusTL: Theme.r3; radiusTR: Theme.r3
            radiusBR: Theme.r3; radiusBL: Theme.r3
            depth: 10
            strength: 0.58
        }

        // 1 px glacier[4] — WidgetChip / SetSlab seam. CutRect so a chamfer
        // cannot leave a rounded spur on a cut card.
        CutRect {
            anchors.fill: parent
            radius: Theme.r3
            color: "transparent"
            borderWidth: Theme.lookOutlineW
            borderColor: Theme.soften(Theme.lookSeam, 0.45)
        }

        // Colour may move; legibility may not (accent.json _swirl rule 5).
        //
        // The veil that used to live here was 96 px tall and ran to 0.80 —
        // it existed to bury a paint that was already invisible. What the
        // page actually needs is the opposite shape: nothing across the body,
        // where the paint is the subject and the cards carry their own fills,
        // and a soft gather at the very base where the app-list rows are
        // unboxed type sitting directly on the paint.
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 132
            visible: Prefs.swirlEnabled
            // Same corner discipline as the card: r3 on all four corners,
            // and nothing clips to it, so a square gather would stand proud
            // of the rounded rim at both bottom corners.
            bottomLeftRadius: Theme.r3
            bottomRightRadius: Theme.r3
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.shelfNone }
                GradientStop { position: 0.55; color: Theme.soften(Theme.void_, 0.22) }
                GradientStop { position: 1.0; color: Theme.soften(Theme.void_, 0.46) }
            }
        }

        // ══ THE GLASS MATERIAL (WIP-787) ═════════════════════════════════
        // Owner 2026-08-19: the thing that MOVES around the EDGES when Start
        // opens. Component `GlassMaterial`; on-switch `focused`. Already here
        // — keep. Not GlassEdge (static lip), not MirrorEdge (static fall),
        // not ReactiveEdge (music/CPU colour, still at rest), not the card
        // Swirl (fills the face). Reuse recipe: GlassMaterial.qml § USE.
        // Position is the wiring: after those four, so the rim sits ON the
        // paint and UNDER the content (WIP-265).
        GlassMaterial {
            anchors.fill: parent
            // The Start Menu holds the Hyprland focus grab whenever it is open,
            // so open IS focused for this surface. Its unfocused state is a real
            // state and not a theoretical one — it is what the card wears while
            // it sinks — and the decouple is what plays during that.
            focused: Bus.launcherOpen
            // The SAME drift offset the card's own Swirl uses (0.0), so the
            // filament is the colour of the paint it is lying on rather than a
            // second, disagreeing colour. `driftCenter` wraps, so this reads the
            // shell-wide drift at this surface's own place in it.
            driftOffset: 0.0
            // GLOBAL LAYOUT COORDINATES, per `field.coordinate_space`. The
            // window is anchored bottom-left behind the bar's exclusive zone, so
            // the card's origin is x 0 and y the screen's height less the bar,
            // the bloom pad and the card itself. Approximate to within the bloom
            // pad, which at a field scale of ~380 px is far below the marbling's
            // own feature size — but it is an approximation and not a measured
            // origin, and it is written down as one.
            paneScreenX: 0
            paneScreenY: (root.screen ? root.screen.height : 800)
                         - Theme.chromeH - root.barGap - Theme.bloomPad - root.swellHeight
            screenW: root.screen ? root.screen.width : 1280
            screenH: root.screen ? root.screen.height : 800
            radiusTL: Theme.r3
            radiusTR: Theme.r3
            radiusBR: Theme.r3
            radiusBL: Theme.r3
        }

        // ══ DAILY · Start is how you begin (TRK-957) ═════════════════════
        // Owner 2026-08-20: a launcher, not a cockpit. Left rail (face,
        // categories, lock, power), search first, six large pinned tiles
        // (icon on top, name only), unpinned as an icon grid. Search
        // results stay a list so PAGE/FILE captions still work. Recents
        // strip only when recentFiles.length > 0 — never Places. Classic
        // Atrium keeps the opt-in cockpit. Radii untouched (WIP-348).
        RowLayout {
            visible: root.daily
            anchors.fill: parent
            clip: true
            // TRK-1800: one frame on all four sides. The right gutter was s8
            // (24) against s6 (16) everywhere else, so the deck sat off-centre
            // in its own card. TRK-2910 keeps that symmetry and states the
            // frame ONCE for the whole shell: s6 (16) vertical, s7 (20)
            // horizontal — the `.hub{padding:16px 20px}` the settings mockup
            // already gives Settings.qml and SetPage.qml's heading. Daily
            // pays 8 px of deck width for it; Classic, below, gets 24 back.
            anchors.topMargin: Theme.s6
            // r3 (22) not s6 (16): the power chip sat in the bottom-left
            // fillet and the card's rounded clip knifed it.
            anchors.bottomMargin: Theme.r3
            anchors.leftMargin: Theme.s7
            anchors.rightMargin: Theme.s7
            spacing: Theme.s6

            // ── the rail: who you are, what you're looking at, and out ───
            ColumnLayout {
                Layout.fillHeight: true
                // TRK-1808: the column is exactly as wide as its tiles. A 54
                // column around 46 px children left 4 px of slack down each
                // side, so nothing in the rail ever lined up with anything.
                Layout.preferredWidth: 56
                Layout.bottomMargin: Theme.s3
                spacing: Theme.s3

                // The account photo → Settings ▸ Account, same contract as
                // Classic's identity tile (and the same ~/.face file).
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 56

                    CrystalGem {
                        anchors.fill: parent
                        visible: dFace.status !== Image.Ready
                        hot: dAvatarHover.hovered
                        on: false
                        lookX: dAvatarHover.hovered ? 0.15 : 0
                        lookY: dAvatarHover.hovered ? -0.10 : 0
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: dFace.status === Image.Ready
                        radius: width / 2
                        color: "transparent"
                    }
                    Image {
                        id: dFace
                        anchors.fill: parent
                        // WIP-640(d): only when it is really there — see
                        // Sys.qml § the account picture.
                        source: Sys.hasFace ? ("file://" + Sys.facePath) : ""
                        sourceSize.width: 92; sourceSize.height: 92
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: dFace
                        source: dFace
                        visible: dFace.status === Image.Ready
                        maskEnabled: true
                        maskSource: dFaceMask
                    }
                    Item {
                        id: dFaceMask
                        anchors.fill: parent
                        layer.enabled: true
                        visible: false
                        Rectangle { anchors.fill: parent; radius: width / 2; color: "black" }
                    }
                    HoverHandler { id: dAvatarHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: root.openQmlSettings("account")
                    }
                }

                Item { Layout.preferredHeight: Theme.s4 }

                Repeater {
                    model: root.categories
                    delegate: CrystalChip {
                        required property var modelData
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 52
                        Layout.preferredHeight: 52
                        Layout.minimumHeight: 52
                        Layout.fillWidth: false
                        Layout.fillHeight: false
                        gemPx: 52
                        glyph: modelData.glyph
                        label: modelData.label
                        floatName: true
                        on: root.activeCat === modelData.key && !root.searching
                        onTapped: {
                            root.activeCat = modelData.key;
                            root.query = "";
                            dSearch.text = "";
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                // Lock and power at the foot of the rail — the same two
                // reach-for-by-mouse acts Classic's masthead carries.
                Repeater {
                    model: [
                        { glyph: "\uf023", act: "lock"  },
                        { glyph: "\uf011", act: "power" }
                    ]
                    delegate: CrystalChip {
                        required property var modelData
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 52
                        Layout.preferredHeight: 52
                        Layout.minimumHeight: 52
                        Layout.fillWidth: false
                        Layout.fillHeight: false
                        gemPx: 52
                        glyph: modelData.glyph
                        label: modelData.act === "power" ? qsTr("Power") : qsTr("Lock")
                        floatName: true
                        danger: modelData.act === "power"
                        onTapped: {
                            if (modelData.act === "power") Bus.togglePower();
                            else Quickshell.execDetached(["loginctl", "lock-session"]);
                        }
                    }
                }
            }

            // ── the rail divider, TAPERED (WIP-340) ─────────────────────────
            // Owner, 2026-08-11, after the card corners went round: the menu
            // still read as "square and rounded both". The card was not the
            // problem by then — this was.
            //
            // It was a bare 1px Rectangle with `fillHeight: true` and no
            // radius, so it ran the FULL height of the content and stopped dead
            // at both ends, square, a few pixels from corners that had just
            // been rounded to r3. Every other rule in this build is the `Rail`
            // component, which tapers and fades at its ends precisely so a
            // hairline never terminates in a hard edge — this one line had
            // never been converted, and next to a round corner it is the thing
            // the eye catches.
            //
            // Same treatment, vertically: fade to nothing at both ends so it
            // resolves into the glass instead of butting into the corner, and
            // hold it off the card's radius so it cannot reach the curve at
            // all. `Rail` itself is horizontal-only, so this is its gradient
            // rather than a rewrite of a shared component other surfaces rely
            // on.
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                Layout.topMargin: Theme.r3
                Layout.bottomMargin: Theme.r3
                radius: width / 2
                gradient: Gradient {
                    GradientStop { position: 0.00; color: "transparent" }
                    GradientStop { position: 0.18; color: root.iceHairline }
                    GradientStop { position: 0.82; color: root.iceHairline }
                    GradientStop { position: 1.00; color: "transparent" }
                }
            }

            // ── the deck ─────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.s5

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.rightMargin: Theme.s6
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: root.helloLine
                        color: Theme.text
                        font.family: Theme.fScript
                        font.pixelSize: Math.round(Theme.tDisplay * Theme.scriptScale)
                        font.letterSpacing: Theme.trackScript
                        elide: Text.ElideRight
                        clip: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: Qt.formatDate(clock.date, "dddd · d MMMM")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        elide: Text.ElideRight
                        clip: true
                    }
                }

                // ── search first — WidgetChip glass, not a flat ice plate ──
                GlassChip {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    focusLevel: dSearch.activeFocus ? 1.0 : 0.18
                    edging: 0.70

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.s5
                        anchors.rightMargin: Theme.s5
                        spacing: Theme.s4

                        Text {
                            text: "\uf002"
                            font.family: Theme.fIcon
                            font.pixelSize: Theme.tCaption
                            Layout.alignment: Qt.AlignVCenter
                            color: dSearch.activeFocus ? root.iceInteractive : Theme.textDim
                        }
                        TextInput {
                            id: dSearch
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            color: Theme.text
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tLabel
                            verticalAlignment: TextInput.AlignVCenter
                            selectByMouse: true
                            selectionColor: Theme.soften(root.iceInteractive, 0.45)
                            clip: true
                            onTextChanged: root.query = text
                            onAccepted: root.acceptSearch()
                            focus: root.daily
                            cursorDelegate: Rectangle {
                                width: 2
                                color: root.iceInteractive
                                SequentialAnimation on opacity {
                                    running: dSearch.activeFocus
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 0; duration: Theme.durBase }
                                    NumberAnimation { to: 1; duration: Theme.durBase }
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: qsTr("Search applications, files and settings…")
                                color: Theme.textDim
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tLabel
                                // Stay until they type. Hiding on focus left
                                // an empty ice box with no caret (the
                                // "doesn't look focused" still).
                                visible: dSearch.text.length === 0
                            }
                        }
                        Text {
                            text: root.searchCountLabel
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                            font.letterSpacing: Theme.trackMicro
                        }
                    }
                }

                // Pinned tiles, unpinned icon grid, search list, recents strip.
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Theme.s4

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.rightMargin: Theme.s6
                            visible: !root.searching && root.activeCat === "all"
                            spacing: Theme.s4
                            Text {
                                text: qsTr("PINNED")
                                color: Theme.textDim
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tMicro
                                font.weight: Font.Medium
                                font.letterSpacing: Theme.trackMicro
                            }
                            Rail { Layout.fillWidth: true; tone: 0.3; strength: 0.22; waist: 0.9 }
                            // TRK-1808: the mockup's section head is label,
                            // then a hairline that eats the row, then the count
                            // hard right in mono. The count was missing here
                            // entirely, so the head trailed off into nothing.
                            Text {
                                text: root.pinnedApps.length
                                color: Theme.soften(Theme.textDim, 0.7)
                                font.family: Theme.fNum
                                font.pixelSize: Theme.tMicro
                            }
                        }

                        // ── TRK-2203 · THE PIN SHELF ─────────────────────
                        // The pinned six were six loose cards on the panel
                        // ground, at the same weight and the same spacing as
                        // the app grid twelve pixels below them. The head said
                        // PINNED; the tiles said nothing. Two rows of squares
                        // separated only by a hairline is not a tier, and it is
                        // a large part of why this surface reads as one
                        // undifferentiated field of icons.
                        //
                        // They sit on a PLATE now — the same containing Pane
                        // the vitals card uses (elevation 1, r2, void 0.55), so
                        // no new material is invented. The tiles inside step
                        // DOWN in weight because the plate is now carrying it:
                        // a tier is a thing you can see the edge of.
                        // TRK-3370 — a card-sized plate on the Start body
                        // wears the widgets' stack (SetSlab), not a flat
                        // soften(void_) fill.
                        // One row of six. A 3×2 of 132 px prize tiles ate the
                        // deck and left APPS a 120 px strip at the foot.
                        GlassChip {
                            id: pinTray
                            Layout.fillWidth: true
                            Layout.rightMargin: Theme.s6
                            visible: !root.searching && root.activeCat === "all"
                            implicitHeight: pinDeck.implicitHeight + Theme.s4 * 2
                            focusLevel: 0.22
                            edging: 0.85
                        GridLayout {
                            id: pinDeck
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.s4
                            columns: 6
                            rowSpacing: Theme.s3
                            columnSpacing: Theme.s3

                            Repeater {
                                model: root.pinnedApps
                                delegate: GlassTile {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 100
                                    prize: true
                                    iconName: modelData.icon
                                    label: modelData.name
                                    coreTint: root.tileCore(modelData.exec)
                                    pip: root.tilePip(modelData.exec)
                                    pipKind: "amber"
                                    onActivated: root.launch(modelData.exec)
                                }
                            }
                        }
                        }

                        // ══ the REFLECTION · the deck stands on polished glass ══
                        // Owner, 2026-08-09: "needs to look more like how the
                        // bottom bar, where the icons have that mirror look
                        // underneath them… it should look like a mirror, then
                        // whatever moves by it you see."
                        //
                        // This is Bar.qml's dock-icon recipe, unchanged in
                        // kind and moved onto the Start Menu's pinned deck:
                        // a flipped copy of the object, masked by a gradient
                        // that dies over Theme.reflectH, at Theme.reflectAlpha.
                        // One source for the whole deck rather than six —
                        // same picture, one texture instead of six.
                        //
                        // It is a LIVE ShaderEffectSource, which is the half
                        // that answers "whatever moves by it you see": the
                        // tiles it mirrors sit over the drifting paint, so the
                        // reflection carries the paint's motion too. What it
                        // honestly cannot do is mirror other WINDOWS — a
                        // layer-shell surface cannot sample what the
                        // compositor draws above it, and no amount of QML
                        // changes that.
                        Item {
                            id: pinMirrorSlot
                            // TRK-1808 / WIP-659(a) CLOSED BY REMOVAL. This
                            // reflection samples the bottom 34 px of the pin
                            // deck. That band used to be tile bottom; with the
                            // deck at one row of 80 it is now the LABEL band,
                            // so it mirrored the words "Files / Web Browser /
                            // Mail ..." upside down under the row. The 08-15 VM
                            // audit had already filed it as a "clipped phantom
                            // third row"; the height change made it unmistakable.
                            // The mockup has no reflection under the pins, so it
                            // goes rather than gets re-tuned. Invisible in a
                            // ColumnLayout also surrenders its 34 px.
                            visible: false
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            // ⚠ WIP-659(a) — WHY THE THREE INNER ITEMS ARE
                            // LIFTED BY `-lift`. The 08-15 VM audit filed this
                            // reflection as a defect: "the PINNED grid shows a
                            // clipped phantom third row — empty tile outlines
                            // under Settings/Terminal/Store". It is not a
                            // phantom row and it is not clipped; it is this
                            // mirror, which the owner asked for by name
                            // (2026-08-09, see above). What made it READ as a
                            // third row is that it did not touch the object it
                            // reflects: the ColumnLayout's own `spacing`
                            // (Theme.s4) sat between the deck and this slot,
                            // and the mirrored slice's first 4px are the empty
                            // band under each tile's Pane — twelve pixels of
                            // nothing, and then a bright tile edge, which the
                            // eye reads as the top of a NEW tile rather than
                            // the bottom of the one above. A reflection that
                            // is not in contact with its object is a picture
                            // of a different object.
                            //
                            // Nothing is resized and nothing is clipped: the
                            // three inner items draw `lift` px higher, into
                            // the layout gap they were separated by, and the
                            // sourceRect starts at the Pane's real bottom
                            // edge. The alpha, the mask depth and the owner's
                            // 1.9× strength are all untouched.
                            readonly property int lift: Theme.s4
                            // The empty band under each tile's Pane
                            // (`anchors.bottomMargin: 6` on the delegate).
                            readonly property int deckPad: 6
                            // Closed menu: nothing here renders at all. The
                            // live-gate below stops the updates; this stops
                            // the render, and between them the scene graph
                            // has nothing to walk in an unexposed window.
                            // TRK-1808 removed this slot by binding `visible: false`
                            // above; WIP-252's render gate below it then bound `visible`
                            // a SECOND time on the same object, which QML rejects outright
                            // ("Property value set multiple times") -> Launcher unavailable
                            // -> the WHOLE shell failed to load. Kept the removal, dropped
                            // the stale render gate: an invisible slot needs no render gate.

                            // ⚠ THE FLIP MUST BE BAKED INTO A LAYER (WIP-333).
                            // Owner, 2026-08-11: "the mirrored look is
                            // backwards" — and it was not mirrored at all. The
                            // Scale used to sit on the ShaderEffectSource
                            // itself, and a ShaderEffectSource that is only
                            // consumed as `source:` by MultiEffect is SAMPLED,
                            // not drawn: its own transform never runs, so the
                            // reflection was a straight copy of the tiles with
                            // the subtitles still reading right-side-up.
                            //
                            // Bar.qml has always been correct and is why the
                            // owner likes the bar's version: there the flip is
                            // on an Image INSIDE a `layer.enabled` Item, so it
                            // is baked into that layer's texture before anything
                            // samples it. Same structure here — the wrapper is
                            // the fix, not the Scale.
                            //
                            // Not `textureMirroring: NoMirroring` either, which
                            // also flips: that property exists to correct the
                            // FBO's y-axis and defaults to MirrorVertically, so
                            // using it to mean "upside down" reads as a bug to
                            // the next person and breaks if the default moves.
                            Item {
                                id: pinMirror
                                anchors.fill: parent
                                anchors.topMargin: -pinMirrorSlot.lift
                                anchors.bottomMargin: pinMirrorSlot.lift
                                visible: false
                                layer.enabled: true
                                ShaderEffectSource {
                                    anchors.fill: parent
                                    // NOT unconditionally live. A ShaderEffectSource
                                    // that keeps updating inside a window the
                                    // compositor has never exposed segfaults the
                                    // scene graph in QQuickItem::update() -- the trap
                                    // cardSwirl's Loader already documents, which I
                                    // walked into by leaving these two ungated. It
                                    // crashed the owner's shell.
                                    live: Bus.launcherOpen   // WIP-252: stop at close START
                                    hideSource: false
                                    sourceItem: pinDeck
                                    // Only the bottom slice of the deck: a
                                    // reflection shows the near edge of the object,
                                    // not the whole of it.
                                    sourceRect: Qt.rect(0,
                                        Math.max(0, pinDeck.height - 34 - pinMirrorSlot.deckPad),
                                        pinDeck.width, 34)
                                    transform: Scale { origin.y: 17; yScale: -1 }
                                }
                            }
                            Item {
                                id: pinMirrorMask
                                anchors.fill: parent
                                anchors.topMargin: -pinMirrorSlot.lift
                                anchors.bottomMargin: pinMirrorSlot.lift
                                visible: false
                                layer.enabled: true
                                Rectangle {
                                    anchors.fill: parent
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: Theme.soften(Theme.text, 1.0) }
                                        GradientStop { position: Theme.reflectH; color: Theme.soften(Theme.text, 0.0) }
                                        GradientStop { position: 1.0; color: Theme.soften(Theme.text, 0.0) }
                                    }
                                }
                            }
                            MultiEffect {
                                anchors.fill: parent
                                anchors.topMargin: -pinMirrorSlot.lift
                                anchors.bottomMargin: pinMirrorSlot.lift
                                source: pinMirror
                                maskEnabled: true
                                maskSource: pinMirrorMask
                                // Above the dock icons' own 0.30: the owner
                                // asked for this one to be MORE visible than
                                // the bar's ("the mirror needs to be more
                                // visible"), and a tile is a much larger
                                // object than a 22 px icon, so the same alpha
                                // reads as less on it.
                                opacity: Theme.reflectAlpha * 1.9
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.rightMargin: Theme.s6
                            spacing: Theme.s4
                            Text {
                                text: root.searching ? qsTr("RESULTS")
                                    : root.activeCat === "all" ? "APPS"
                                    : root.catLabel(root.activeCat)
                                color: Theme.textDim
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tMicro
                                font.weight: Font.Medium
                                font.letterSpacing: Theme.trackMicro
                            }
                            Rail { Layout.fillWidth: true; tone: 0.3; strength: 0.22; waist: 0.9 }
                            // TRK-1808: this count used to sit BEFORE the rail,
                            // so it hung mid-row beside the label and the head
                            // had no right end. It anchors the right now, in
                            // fNum — the label already says what is being
                            // counted, so the number carries itself.
                            Text {
                                text: root.searching ? root.filteredApps.length
                                                     : root.rosterApps.length
                                color: Theme.soften(Theme.textDim, 0.7)
                                font.family: Theme.fNum
                                font.pixelSize: Theme.tMicro
                            }
                        }

                        Flickable {
                            id: dGridScroll
                            visible: !root.searching
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 220
                            contentHeight: dAppGrid.implicitHeight
                            clip: true
                            // MultiEffect bloom on the gems draws outside the
                            // item; without a layer, Flickable.clip cannot
                            // keep a scrolled row inside the Start pane.
                            layer.enabled: true
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollRail { flick: dGridScroll }

                            Rectangle {
                                y: dGridScroll.contentY + dGridScroll.height - height
                                width: dGridScroll.width
                                height: 44
                                z: 5
                                visible: dGridScroll.contentHeight > dGridScroll.height + 4
                                opacity: Math.min(1, Math.max(0,
                                    (dGridScroll.contentHeight - dGridScroll.height - dGridScroll.contentY) / 40))
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: Theme.shelfNone }
                                    GradientStop { position: 1.0; color: Theme.soften(Theme.void_, 0.92) }
                                }
                            }

                            GridLayout {
                                id: dAppGrid
                                width: parent.width - Theme.s6
                                columns: 4
                                rowSpacing: Theme.s5
                                columnSpacing: Theme.s5

                                Repeater {
                                    model: root.rosterApps
                                    delegate: GlassTile {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 108
                                        prize: false
                                        iconName: modelData.icon
                                        label: modelData.name
                                        coreTint: root.tileCore(modelData.exec)
                                        pip: root.tilePip(modelData.exec)
                                        pipKind: "amber"
                                        onActivated: root.launch(modelData.exec)
                                    }
                                }
                            }
                        }

                        Flickable {
                            id: dListScroll
                            visible: root.searching
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentHeight: dList.implicitHeight
                            clip: true
                            layer.enabled: true
                            boundsBehavior: Flickable.StopAtBounds

                            // WIP-332: the rail. The fade below says "there is
                            // more"; it cannot say HOW MUCH more or where you
                            // are in it, which is what a scrollbar is for. Both
                            // stay — they answer different questions.
                            ScrollRail { flick: dListScroll }

                            // Same bottom fade as Classic's grid: says "more
                            // below" without a scrollbar, stops the last row
                            // being knifed by the clip.
                            Rectangle {
                                y: dListScroll.contentY + dListScroll.height - height
                                width: dListScroll.width
                                height: 44
                                z: 5
                                visible: dListScroll.contentHeight > dListScroll.height + 4
                                opacity: Math.min(1, Math.max(0,
                                    (dListScroll.contentHeight - dListScroll.height - dListScroll.contentY) / 40))
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: Theme.shelfNone }
                                    GradientStop { position: 1.0; color: Theme.soften(Theme.void_, 0.92) }
                                }
                            }

                            ColumnLayout {
                                id: dList
                                width: parent.width - Theme.s6
                                spacing: 1

                                Repeater {
                                    model: root.rosterApps
                                    delegate: Rectangle {
                                        id: dRow
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 40
                                        radius: Theme.r1
                                        // At rest this was "transparent", which
                                        // was correct while the paint was a dim
                                        // 96 px strip at the far end of the page
                                        // and this column sat on plain glass.
                                        // With the paint filling the card these
                                        // rows are unboxed type lying directly
                                        // on a moving light, and HORIZON's rule
                                        // is that legibility is bought LOCALLY,
                                        // under the type, never by dimming the
                                        // paint back to nothing. So each row now
                                        // carries the faintest body of its own —
                                        // far too little to read as a box, just
                                        // enough that a ribbon passing under the
                                        // list cannot take the words with it.
                                        color: dRowHover.hovered ? Theme.soften(root.icePrimary, 0.10)
                                                                 : Theme.soften(Theme.void_, 0.30)
                                        Behavior on color { ColorAnimation { duration: Theme.durQuick } }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: Theme.s3
                                            anchors.rightMargin: Theme.s4
                                            spacing: Theme.s5

                                            CrystalGem {
                                                Layout.preferredWidth: 28
                                                Layout.preferredHeight: 28
                                                hot: dRowHover.hovered
                                                iconName: dRow.modelData.icon
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: dRow.modelData.name
                                                color: dRowHover.hovered ? Theme.text : Theme.textMuted
                                                font.family: Theme.fUi
                                                font.pixelSize: Theme.tBody
                                                elide: Text.ElideRight
                                                clip: true
                                                Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                                            }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                visible: dRow.modelData.kind === "settings"
                                                      || dRow.modelData.kind === "file"
                                                text: dRow.modelData.kind === "settings" ? qsTr("PAGE")
                                                    : dRow.modelData.kind === "file" ? qsTr("FILE") : ""
                                                color: Theme.textDim
                                                font.family: Theme.fUi
                                                font.pixelSize: Theme.tMicro
                                                font.letterSpacing: Theme.trackMicro
                                            }
                                        }
                                        HoverHandler { id: dRowHover; cursorShape: Qt.PointingHandCursor }
                                        TapHandler { onTapped: root.launch(dRow.modelData.exec) }
                                    }
                                }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.searching && root.filteredApps.length === 0
                            text: "Nothing matches “" + root.query.trim() + "”.  Press Enter to search everything installed."
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            wrapMode: Text.WordWrap
                        }

                        // ── the foot ────────────────────────────────────
                        // TRK-2302. The mockup's `.foot` is ONE 28 px row:
                        // "recents + foot share one row: the strip is no
                        // longer a lone band". It was a 32 px labelled band
                        // with the edition mark on a second line below it —
                        // two rows spending ~56 px of a 560 px card on three
                        // chips and six words. The chips ARE the label now:
                        // a row of file chips does not need to be told it is
                        // recent files.
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.rightMargin: Theme.s6
                            Layout.preferredHeight: 28
                            spacing: Theme.s4

                            Flickable {
                                visible: !root.searching && root.recentFiles.length > 0
                                id: dRecentStrip
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                flickableDirection: Flickable.HorizontalFlick
                                boundsBehavior: Flickable.StopAtBounds
                                contentWidth: dRecentRow.implicitWidth
                                contentHeight: height

                                RowLayout {
                                    id: dRecentRow
                                    height: dRecentStrip.height
                                    spacing: Theme.s2

                                    Repeater {
                                        model: root.recentFiles
                                        delegate: Rectangle {
                                            id: dRecentChip
                                            required property var modelData
                                            Layout.preferredHeight: 28
                                            implicitWidth: dRecentChipRow.implicitWidth + Theme.s5
                                            radius: Theme.r1
                                            color: dRecentHov.hovered ? Theme.elevated : Theme.soften(Theme.void_, 0.30)
                                            Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                                            RowLayout {
                                                id: dRecentChipRow
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.left: parent.left
                                                anchors.leftMargin: Theme.s3
                                                spacing: Theme.s3
                                                Image {
                                                    Layout.preferredWidth: 16
                                                    Layout.preferredHeight: 16
                                                    sourceSize.width: 16
                                                    sourceSize.height: 16
                                                    smooth: true
                                                    fillMode: Image.PreserveAspectFit
                                                    source: Quickshell.iconPath(root.iconFor(dRecentChip.modelData.name), "folder")
                                                }
                                                Text {
                                                    text: dRecentChip.modelData.name
                                                    color: Theme.text
                                                    font.family: Theme.fUi
                                                    font.pixelSize: Theme.tCaption
                                                    elide: Text.ElideRight
                                                    clip: true
                                                    Layout.maximumWidth: 140
                                                }
                                            }
                                            HoverHandler { id: dRecentHov; cursorShape: Qt.PointingHandCursor }
                                            TapHandler { onTapped: root.openPath(dRecentChip.modelData.path) }
                                        }
                                    }
                                }
                            }

                            // `.foot .mark{margin-left:auto}` — pushed to the
                            // right of the SAME row the chips are on, not a
                            // line of its own beneath them.
                            Text {
                                Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
                                text: qsTr("NYXUS  ·  SUXYN EDITION")
                                color: Theme.textDim
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tMicro
                                font.letterSpacing: Theme.trackMicro
                            }
                        }
                    }
            }

            // ── the SYSTEM panel (TRK-3364) ──────────────────────────────
            // The 08-28 mockup's right column: the machine at a glance and
            // the quick tiles, IN Daily. Nothing here is new instrument —
            // `SystemMeters` and `QuickToggles` are the same components
            // Classic's at-a-glance panel already renders, so Daily and
            // Classic cannot drift apart, and the meters are the same
            // MeterRow the SYSTEM desktop widget language uses.
            // TRK-3370 — side column card onto the widgets' stack.
            GlassChip {
                visible: !Theme.lookMagma
                Layout.fillHeight: true
                Layout.preferredWidth: 264
                edging: 0.85

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.s5
                    spacing: Theme.s4

                    Text {
                        text: qsTr("THIS MACHINE")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                        font.weight: Font.Medium
                        font.letterSpacing: Theme.trackMicro
                    }

                    SystemMeters { compact: true }

                    Rail { Layout.fillWidth: true; tone: 0.85; strength: 0.20; waist: 0.9 }

                    Text {
                        text: qsTr("QUICK")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                        font.weight: Font.Medium
                        font.letterSpacing: Theme.trackMicro
                    }

                    QuickToggles {}

                    Item { Layout.fillHeight: true }
                }
            }
        }

        // ══ CLASSIC · the Atrium (launcherStyle "classic") ═══════════════
        ColumnLayout {
            visible: !root.daily
            anchors.fill: parent
            // TRK-2910: the ONE frame — s6 vertical, s7 horizontal — the same
            // one Daily, the settings hub and every SetPage heading use. This
            // was s9 (32) at the sides against Daily's s6 in the same card and
            // s7 top and bottom: **1040 − 64 = 976 of content, now 1040 − 40 =
            // 1000 (+24), and 760 − 40 = 720 tall, now 728 (+8)**. The +24
            // lands in the app column below, which now fills.
            anchors.leftMargin: Theme.s7
            anchors.rightMargin: Theme.s7
            anchors.topMargin: Theme.s6
            anchors.bottomMargin: Theme.s6
            spacing: Theme.s6

            // ══ the Masthead ═════════════════════════════════════════════
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s5

                // The identity tile is a BUTTON: it opens your account, the
                // way clicking your face does on Windows/macOS. Photo, display
                // name and administrator status all live one click away in
                // QML Settings ▸ Account (pending page until that subject
                // is ported). Never PATH `nyxus-settings`.
                GlassChip {
                    id: idTile
                    Layout.preferredHeight: 56
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: idTileRow.implicitWidth + Theme.s5 * 2
                    focusLevel: idTileHover.hovered ? 0.45 : 0
                    edging: 0.70

                    RowLayout {
                        id: idTileRow
                        anchors.fill: parent
                        anchors.leftMargin: Theme.s4
                        anchors.rightMargin: Theme.s6
                        spacing: Theme.s5

                        Item {
                            Layout.preferredWidth: 44; Layout.preferredHeight: 44
                            Layout.alignment: Qt.AlignVCenter

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Theme.teal
                                // A ring on hover so the round photo reads as
                                // the clickable thing it is.
                                border.width: idTileHover.hovered ? 2 : 1
                                border.color: idTileHover.hovered
                                              ? root.iceInteractive
                                              : root.iceHairline
                                Behavior on border.width { NumberAnimation { duration: Theme.durQuick } }

                                // Fallback: the initial on glass, shown
                                // until a real ~/.face loads (and if the user
                                // never sets one).
                                Text {
                                    anchors.centerIn: parent
                                    visible: facePic.status !== Image.Ready
                                    text: (root.userName.length > 0 ? root.userName.charAt(0) : "n").toUpperCase()
                                    color: Theme.text
                                    font.family: Theme.fUiTitle
                                    font.pixelSize: Theme.tTitle
                                    font.weight: Font.DemiBold
                                }
                            }
                            // The real account photo, cropped to fill and
                            // masked to the circle. cache:false so a picture
                            // changed in Settings shows next open, not stale.
                            Image {
                                id: facePic
                                anchors.fill: parent
                                // WIP-640(d): only when it is really there —
                                // see Sys.qml § the account picture.
                                source: Sys.hasFace ? ("file://" + Sys.facePath) : ""
                                sourceSize.width: 88; sourceSize.height: 88
                                fillMode: Image.PreserveAspectCrop
                                cache: false
                                visible: false      // drawn masked below
                            }
                            MultiEffect {
                                anchors.fill: facePic
                                source: facePic
                                visible: facePic.status === Image.Ready
                                maskEnabled: true
                                maskSource: faceMask
                            }
                            Item {
                                id: faceMask
                                anchors.fill: parent
                                layer.enabled: true
                                visible: false
                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: "black"
                                }
                            }
                        }
                        ColumnLayout {
                            spacing: 2
                            Text {
                                text: root.userName
                                color: Theme.text
                                font.family: Theme.fUiTitle
                                font.pixelSize: Theme.tTitle
                                font.weight: Font.Light
                                font.letterSpacing: Theme.trackTitle
                            }
                            RowLayout {
                                spacing: Theme.s3
                                Rectangle {
                                    Layout.preferredWidth: 6; Layout.preferredHeight: 6; radius: 3
                                    color: Sys.wifiOn ? Theme.ok : Theme.textDim
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                Text {
                                    text: Sys.wifiName.toUpperCase()
                                    color: Theme.textDim
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tMicro
                                    font.letterSpacing: Theme.trackMicro
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 190
                                }
                                // Uptime is the one number that says "this
                                // machine has been up and fine", which is
                                // exactly what a status strip is for. Empty
                                // until the first vitals sample lands rather
                                // than showing a made-up zero.
                                Text {
                                    visible: Sys.uptimeText.length > 0
                                    text: "·  UP " + Sys.uptimeText.toUpperCase()
                                    color: Theme.textDim
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tMicro
                                    font.letterSpacing: Theme.trackMicro
                                }
                            }
                        }
                    }
                    HoverHandler {
                        id: idTileHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: root.openQmlSettings("account")
                    }
                }
                Item { Layout.fillWidth: true }

                // Lock, then power. Two things you reach for by mouse and
                // should never have to hunt for.
                Repeater {
                    model: [
                        { glyph: "\uf023", act: "lock",  label: qsTr("Lock")  },
                        { glyph: "\uf011", act: "power", label: qsTr("Power") }
                    ]
                    delegate: GlassChip {
                        id: idBtn
                        required property var modelData
                        Layout.preferredWidth: 74; Layout.preferredHeight: 52
                        focusLevel: idBtnTap.pressed ? 0.70 : (idBtnHover.hovered ? 1.0 : 0.0)
                        edging: 0.70

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: idBtn.modelData.glyph
                                font.family: Theme.fIcon
                                font.pixelSize: Theme.tBody
                                color: idBtnHover.hovered || idBtnTap.pressed
                                       ? (idBtn.modelData.act === "power" ? root.magmaInteractive : root.iceInteractive)
                                       : Theme.textMuted
                                Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: idBtn.modelData.label
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tMicro
                                font.weight: Font.Medium
                                font.letterSpacing: Theme.trackMicro
                                color: idBtnHover.hovered ? Theme.text : Theme.textDim
                            }
                        }
                        HoverHandler { id: idBtnHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            id: idBtnTap
                            onTapped: {
                                if (idBtn.modelData.act === "power") {
                                    Bus.togglePower();
                                } else {
                                    // Same route as Super+L and the power
                                    // menu: loginctl → hypridle → lock-guard
                                    // → Lock.qml (Earth). Bare hyprlock is
                                    // the old screen.
                                    Quickshell.execDetached(["loginctl", "lock-session"]);
                                    Bus.launcherOpen = false;
                                }
                            }
                        }
                    }
                }
            }

            // ══ search ═══════════════════════════════════════════════════
            GlassChip {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                focusLevel: search.activeFocus ? 1.0 : 0.0
                edging: 0.70

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.s6
                    anchors.rightMargin: Theme.s6
                    spacing: Theme.s5

                    Text {
                        text: "\uf002"
                        font.family: Theme.fIcon
                        Layout.alignment: Qt.AlignVCenter
                        color: search.activeFocus ? root.iceInteractive : Theme.textMuted
                        font.pixelSize: Theme.tBody
                    }
                    TextInput {
                        id: search
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        color: Theme.text
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tBody
                        verticalAlignment: TextInput.AlignVCenter
                        selectByMouse: true
                        selectionColor: Theme.soften(root.iceInteractive, 0.45)
                        clip: true
                        onTextChanged: root.query = text
                        onAccepted: root.acceptSearch()
                        // The menu is opened by pointer or Super, so nothing
                        // else claims the keyboard — take it, or the first
                        // keystroke goes nowhere. Conditional since WIP-199:
                        // two fields with `focus: true` in one scope would
                        // race, and Daily's field must win when Daily shows.
                        focus: !root.daily
                        cursorDelegate: Rectangle {
                            width: 2
                            color: root.iceInteractive
                            SequentialAnimation on opacity {
                                running: search.activeFocus
                                loops: Animation.Infinite
                                NumberAnimation { to: 0; duration: Theme.durBase }
                                NumberAnimation { to: 1; duration: Theme.durBase }
                            }
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Search applications, files and settings…")
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tBody
                            visible: search.text.length === 0
                        }
                    }
                    // Was a decorative sliders glyph that did nothing. It is
                    // the count of what you are looking at now, which is the
                    // one fact a search field can honestly volunteer.
                    Text {
                        text: root.searchCountLabel
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                        font.letterSpacing: Theme.trackMicro
                    }
                }
            }

            // ══ body · apps on the left, the machine on the right ════════
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.s8

                // ── left: pinned, chips, grid ────────────────────────────
                ColumnLayout {
                    Layout.fillHeight: true
                    // TRK-2910. NEITHER column filled: 668 + s8 (24) + 284 =
                    // 976, which was exactly the old inner width, so the row
                    // happened to be full — and any change to the frame, or a
                    // screen where `swellWidth` clamps to `availW`, left the
                    // slack sitting dead at the right edge (a RowLayout hands
                    // spare width only to items that ask for it, and nothing
                    // here did). The app column asks now, so it absorbs the
                    // frame's +24 → **668 → 692** at 1040, and it is what
                    // gives way instead of the vitals pane when the card is
                    // clamped narrower than 1040.
                    Layout.fillWidth: true
                    Layout.preferredWidth: 668
                    spacing: Theme.s5

                    // ── PINNED · the tier the page was missing ───────────
                    // Six big tiles. Hidden entirely while searching, because
                    // during a search the only thing on the page that matters
                    // is the result list, and a fixed row above it is noise
                    // between you and what you asked for.
                    Text {
                        text: qsTr("PINNED")
                        visible: !root.searching
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                        font.weight: Font.Medium
                        font.letterSpacing: Theme.trackMicro
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        visible: !root.searching
                        spacing: Theme.s4

                        Repeater {
                            model: root.pinnedApps
                            delegate: Item {
                                id: hero
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredHeight: 92

                                // Light under the tile, not a shadow behind
                                // it (§4.3). This is the Pool doing on a page
                                // exactly what it does under a dock icon.
                                Pool {
                                    anchors.bottom: parent.bottom
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width
                                    height: 30
                                    tone: root.icePrimary
                                    focusRatio: 0.5
                                    strength: heroHover.hovered ? 0.85 : 0
                                }

                                GlassChip {
                                    anchors.fill: parent
                                    anchors.bottomMargin: 6
                                    focusLevel: heroHover.hovered ? 1.0 : 0.22
                                    edging: 0.85

                                    transform: Translate {
                                        y: heroHover.hovered ? -3 : 0
                                        Behavior on y {
                                            NumberAnimation {
                                                duration: Theme.durQuick
                                                easing.type: Easing.Bezier
                                                easing.bezierCurve: Theme.curveRise
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: Theme.s3

                                        Item {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.preferredWidth: 40
                                            Layout.preferredHeight: 40
                                            CrystalGem {
                                                id: heroIcon
                                                anchors.fill: parent
                                                hot: heroHover.hovered
                                                iconName: hero.modelData.icon
                                            }
                                        }
                                        Text {
                                            Layout.alignment: Qt.AlignHCenter
                                            Layout.maximumWidth: hero.width - Theme.s5
                                            text: hero.modelData.name
                                            color: heroHover.hovered ? Theme.text : Theme.textMuted
                                            font.family: Theme.fUi
                                            font.pixelSize: Theme.tCaption
                                            font.weight: Font.Medium
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
                                            clip: true
                                            Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                                        }
                                    }

                                    HoverHandler { id: heroHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: root.launch(hero.modelData.exec) }
                                }
                            }
                        }
                    }

                    Rail {
                        Layout.fillWidth: true
                        Layout.topMargin: Theme.s2
                        visible: !root.searching
                        tone: 0.3
                        strength: 0.22
                        waist: 0.9
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.s3

                        Repeater {
                            model: root.categories
                            delegate: Rectangle {
                                id: chip
                                required property var modelData
                                readonly property bool on: root.activeCat === chip.modelData.key
                                                           && !root.searching
                                implicitWidth: chipText.implicitWidth + Theme.s7
                                implicitHeight: 26
                                radius: Theme.rFull
                                // 2026-08-09: the active chip goes SOLID rose
                                // (THE RATION — a control in its taken state is
                                // chrome, not glass). The washed sweep2 pill
                                // read as "nothing changed" on hardware.
                                color: chip.on ? Theme.soften(root.icePrimary, 0.28)
                                     : (chipHover.hovered ? Theme.elevated : "transparent")
                                border.width: 1
                                border.color: chip.on ? root.icePrimary
                                                      : Theme.soften(Theme.text, 0.09)
                                Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                                Behavior on border.color { ColorAnimation { duration: Theme.durQuick } }

                                Text {
                                    id: chipText
                                    anchors.centerIn: parent
                                    text: chip.modelData.label
                                    color: chip.on ? Theme.text : Theme.textMuted
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tMicro
                                    font.weight: Font.Medium
                                    font.letterSpacing: Theme.trackMicro
                                }
                                HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler {
                                    onTapped: {
                                        root.activeCat = chip.modelData.key;
                                        root.query = "";
                                        search.text = "";
                                    }
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: qsTr("All apps  ›")
                            color: root.iceInteractive
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            TapHandler {
                                cursorShape: Qt.PointingHandCursor
                                onTapped: {
                                    root.activeCat = "all";
                                    root.query = "";
                                    search.text = "";
                                }
                            }
                        }
                    }

                    // ── the grid ─────────────────────────────────────────
                    // One plate per app, icon drawn like the dock: the real
                    // theme artwork at Theme.dockIcon, rasterised at the
                    // drawn size, with the packaged Reflection under it.
                    // Sweep colorization is gone — that made Start a second
                    // icon family next to the bar.
                    Flickable {
                        ScrollRail { flick: gridScroll }   // WIP-332
                        id: gridScroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: grid.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        // Tells you there is more below without a scrollbar,
                        // and stops the last visible row being sliced in half
                        // by the clip — which is what the panel did before
                        // and which reads as a rendering fault rather than as
                        // "scroll for more". Fixed to the viewport, not the
                        // content, so it stays at the bottom edge while you
                        // scroll, and it goes away once you reach the end.
                        Rectangle {
                            y: gridScroll.contentY + gridScroll.height - height
                            width: gridScroll.width
                            height: 54
                            z: 5
                            visible: gridScroll.contentHeight > gridScroll.height + 4
                            opacity: Math.min(1, Math.max(0,
                                (gridScroll.contentHeight - gridScroll.height - gridScroll.contentY) / 40))
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Theme.shelfNone }
                                GradientStop { position: 1.0; color: Theme.soften(Theme.void_, 0.92) }
                            }
                        }

                        GridLayout {
                            id: grid
                            width: parent.width - Theme.s6
                            columns: 7
                            rowSpacing: Theme.s5
                            columnSpacing: Theme.s2

                            Repeater {
                                model: root.filteredApps

                                delegate: Item {
                                    id: tile
                                    required property var modelData
                                    required property int index
                                    Layout.alignment: Qt.AlignHCenter
                                    // 92, not 96: the label is the widest
                                    // thing in a cell, so it — not the 56 px
                                    // plate — sets the column width, and
                                    // seven columns have to fit 668 px.
                                    Layout.preferredWidth: 92
                                    Layout.preferredHeight: (tile.modelData.kind === "settings"
                                                          || tile.modelData.kind === "file") ? 100 : 86

                                    Pool {
                                        anchors.bottom: parent.bottom
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: parent.width
                                        height: 22
                                        tone: root.icePrimary
                                        focusRatio: 0.6
                                        strength: appHover.hovered ? 0.7 : 0
                                    }

                                    Item {
                                        id: plate
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: appHover.hovered ? -2 : 0
                                        width: 56
                                        height: 56
                                        property real lookX: 0
                                        property real lookY: 0
                                        Behavior on y {
                                            NumberAnimation {
                                                duration: Theme.durQuick
                                                easing.type: Easing.Bezier
                                                easing.bezierCurve: Theme.curveRise
                                            }
                                        }
                                        HoverHandler {
                                            onPointChanged: {
                                                if (!hovered || plate.width < 1)
                                                    return;
                                                plate.lookX = (point.position.x / plate.width) * 2 - 1;
                                                plate.lookY = (point.position.y / plate.height) * 2 - 1;
                                            }
                                            onHoveredChanged: {
                                                if (!hovered) {
                                                    plate.lookX = 0;
                                                    plate.lookY = 0;
                                                }
                                            }
                                        }
                                        CrystalGem {
                                            anchors.fill: parent
                                            hot: appHover.hovered
                                            on: appHover.hovered
                                            tint: root.iceHairline
                                            lookX: plate.lookX
                                            lookY: plate.lookY
                                            iconName: tile.modelData.icon
                                        }
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: plate.bottom
                                        anchors.topMargin: Theme.s3
                                        width: parent.width - Theme.s2
                                        text: tile.modelData.name
                                        color: appHover.hovered ? Theme.text : Theme.textMuted
                                        font.family: Theme.fUi
                                        font.pixelSize: Theme.tCaption
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        clip: true
                                        Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                                    }
                                    Text {
                                        visible: tile.modelData.kind === "settings"
                                              || tile.modelData.kind === "file"
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.top: plate.bottom
                                        anchors.topMargin: Theme.s3 + Theme.tCaption + 2
                                        text: tile.modelData.kind === "settings" ? qsTr("PAGE")
                                            : tile.modelData.kind === "file" ? "FILE" : ""
                                        color: Theme.textDim
                                        font.family: Theme.fUi
                                        font.pixelSize: Theme.tMicro
                                        font.letterSpacing: Theme.trackMicro
                                    }

                                    HoverHandler { id: appHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: root.launch(tile.modelData.exec) }
                                }
                            }
                        }
                    }

                    // Search that finds nothing has to say so. Without this
                    // the grid simply emptied and the page looked broken.
                    Text {
                        Layout.fillWidth: true
                        Layout.bottomMargin: Theme.s6
                        visible: root.searching && root.filteredApps.length === 0
                        text: "Nothing matches “" + root.query.trim() + "”.  Press Enter to search everything installed."
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        wrapMode: Text.WordWrap
                    }
                }

                // ── right: the machine, at a glance ──────────────────────
                // TRK-3370 — side column card onto the widgets' stack.
                SetSlab {
                    visible: !Theme.lookMagma
                    Layout.fillHeight: true
                    Layout.preferredWidth: 284
                    level: 1
                    cornerRadius: Theme.r2

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.s6
                        spacing: Theme.s5

                        // The clock, big, because it is the thing you look
                        // at most and the panel has the room.
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                // ⚠ WAS the bare literal `"h:mm"`, which does
                                // not honour the 12/24-hour setting AT ALL and
                                // is not even 12-hour: Qt's `h` means 0-23
                                // unless an AM/PM marker shares the string, so
                                // this drew "13:47" all afternoon on a machine
                                // set to 12-hour. TRK-3728 removed nine copies
                                // of this mistake; this call site was missed
                                // because it hardcoded the format instead of
                                // branching on the pref, so a search for the
                                // branch did not find it.
                                text: Qt.formatDateTime(clock.date, Prefs.timeFmt)
                                color: Theme.text
                                // The build's one time face — same change and
                                // same reasoning as the Daily masthead clock.
                                font.family: Theme.fTech
                                font.pixelSize: Theme.tDisplay
                                font.weight: Theme.wLabel
                                font.letterSpacing: Theme.trackTech
                                font.features: ({ "tnum": 1 })
                            }
                            Text {
                                text: Qt.formatDateTime(clock.date, "dddd d MMMM").toUpperCase()
                                color: Theme.textDim
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tMicro
                                font.weight: Font.Medium
                                font.letterSpacing: Theme.trackMicro
                            }
                        }

                        Rail { Layout.fillWidth: true; tone: 0.85; strength: 0.20; waist: 0.9 }

                        Text {
                            text: qsTr("THIS MACHINE")
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                            font.weight: Font.Medium
                            font.letterSpacing: Theme.trackMicro
                        }

                        SystemMeters { compact: false }

                        Rail { Layout.fillWidth: true; tone: 0.85; strength: 0.20; waist: 0.9 }

                        Text {
                            text: qsTr("QUICK")
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                            font.weight: Font.Medium
                            font.letterSpacing: Theme.trackMicro
                        }

                        // Same TogglePill as the flyout. Quiet is gone.
                        QuickToggles {}

                        Rail { Layout.fillWidth: true; tone: 0.85; strength: 0.20; waist: 0.9 }

                        // ── places ───────────────────────────────────────
                        Text {
                            text: qsTr("PLACES")
                            visible: root.places.length > 0
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                            font.weight: Font.Medium
                            font.letterSpacing: Theme.trackMicro
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            visible: root.places.length > 0
                            columns: 2
                            rowSpacing: Theme.s2
                            columnSpacing: Theme.s3

                            Repeater {
                                model: root.places
                                delegate: Rectangle {
                                    id: place
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    radius: Theme.r1
                                    color: placeHover.hovered ? Theme.elevated : "transparent"
                                    Behavior on color { ColorAnimation { duration: Theme.durQuick } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Theme.s4
                                        anchors.rightMargin: Theme.s3
                                        spacing: Theme.s4
                                        Image {
                                            Layout.preferredWidth: 17; Layout.preferredHeight: 17
                                            sourceSize.width: 17; sourceSize.height: 17
                                            smooth: true
                                            fillMode: Image.PreserveAspectFit
                                            source: Quickshell.iconPath(root.placeIcon(place.modelData.name), "folder")
                                            opacity: placeHover.hovered ? 1.0 : 0.72
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: place.modelData.name
                                            color: placeHover.hovered ? Theme.text : Theme.textMuted
                                            font.family: Theme.fUi
                                            font.pixelSize: Theme.tCaption
                                            elide: Text.ElideRight
                                            clip: true
                                        }
                                    }
                                    HoverHandler { id: placeHover; cursorShape: Qt.PointingHandCursor }
                                    TapHandler { onTapped: root.openPath(place.modelData.path) }
                                }
                            }
                        }

                        Rail {
                            Layout.fillWidth: true
                            visible: root.places.length > 0
                            tone: 0.85; strength: 0.20; waist: 0.9
                        }

                        // ── recents ──────────────────────────────────────
                        // Still honest: on a machine with no XDG recents
                        // this says so in one quiet line instead of hiding
                        // and leaving a hole, which is what the old panel
                        // did — and the hole was most of what "bla" meant.
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: qsTr("RECENT")
                                color: Theme.textDim
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tMicro
                                font.weight: Font.Medium
                                font.letterSpacing: Theme.trackMicro
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                visible: root.recentFiles.length > 0
                                text: qsTr("More  ›")
                                color: root.iceInteractive
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                                TapHandler {
                                    cursorShape: Qt.PointingHandCursor
                                    onTapped: root.launch("nyxus-files")
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: root.recentFiles.length === 0
                            wrapMode: Text.WordWrap
                            text: qsTr("Nothing opened yet. Files you work on will show up here.")
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                        }
                        Repeater {
                            model: root.recentFiles
                            delegate: Rectangle {
                                id: rec
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                radius: Theme.r1
                                color: recHover.hovered ? Theme.elevated : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.durQuick } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.s4
                                    anchors.rightMargin: Theme.s4
                                    spacing: Theme.s5
                                    CrystalGem {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28
                                        hot: recHover.hovered
                                        iconName: root.iconFor(rec.modelData.name)
                                    }
                                    ColumnLayout {
                                        spacing: 0
                                        Text {
                                            text: rec.modelData.name; color: Theme.text
                                            font.family: Theme.fUi; font.pixelSize: Theme.tLabel
                                            elide: Text.ElideRight; clip: true; Layout.fillWidth: true
                                        }
                                        Text {
                                            text: rec.modelData.sub; color: Theme.textDim
                                            font.family: Theme.fUi; font.pixelSize: Theme.tMicro
                                            elide: Text.ElideRight; clip: true; Layout.fillWidth: true
                                        }
                                    }
                                }
                                HoverHandler { id: recHover; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: root.openPath(rec.modelData.path) }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // The build stamp. HANDOFF § Branding: the desktop
                        // says NYXUS; "Suxyn" is the edition name and lives
                        // in About and the build stamp only. This is one of
                        // those two places.
                        Text {
                            text: qsTr("NYXUS  ·  SUXYN EDITION")
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                            font.letterSpacing: Theme.trackMicro
                        }
                    }
                }
            }
        }
    }

    // Hovered rail NAME. Same motion as the dock caption: pop in in
    // front of the stone, drift up, fade. Sibling of the card so
    // card.clip cannot bury it behind the gem.
    Text {
        id: gemCap
        z: 20
        property string owner: ""
        property real anchorX: 0
        property real baseY: 0
        property real lift: 0

        function hold(t, x, key, startY) {
            text = t;
            anchorX = x;
            owner = key;
            baseY = startY;
            fly.stop();
            opacity = 0;
            lift = 0;
            fly.restart();
        }
        function release() { owner = ""; }

        x: Math.max(Theme.s7, Math.min(root.width - width - Theme.s7, anchorX - width / 2))
        y: gemCap.baseY - gemCap.lift - height
        font.family: Theme.fUi
        font.pixelSize: Theme.tCaption
        font.weight: Font.DemiBold
        font.letterSpacing: Theme.trackMicro * 0.5
        color: Theme.text
        opacity: 0
        visible: root.contentShown && (fly.running || opacity > 0.01)
        elide: Text.ElideRight
        width: Math.min(implicitWidth, 180)
        style: Text.Outline
        styleColor: Theme.soften(Theme.void_, 0.78)

        SequentialAnimation {
            id: fly
            NumberAnimation {
                target: gemCap
                property: "opacity"
                from: 0
                to: 1
                duration: 110
            }
            ParallelAnimation {
                NumberAnimation {
                    target: gemCap
                    property: "lift"
                    from: 0
                    to: 36
                    duration: 1600
                    easing.type: Easing.OutCubic
                }
                SequentialAnimation {
                    PauseAnimation { duration: 280 }
                    NumberAnimation {
                        target: gemCap
                        property: "opacity"
                        to: 0
                        duration: 1320
                        easing.type: Easing.InQuad
                    }
                }
            }
        }
    }
}
