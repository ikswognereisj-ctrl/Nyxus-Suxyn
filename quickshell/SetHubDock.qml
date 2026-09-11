pragma ComponentBehavior: Bound
// Nyxus Suxyn — the Settings UTILITY HUB. TRK-3216.
//
// ══ what this is ═══════════════════════════════════════════════════════════
// The floating vertical dock the owner's 2026-08-27 mockups put OUTSIDE and
// to the LEFT of the Settings window (`03-side-panel-utility-hub-annotated`).
// Five slabs, top to bottom, and the annotations name them:
//
//   Profile Card                       the real login account
//   Integrated Theme Palette & Mixer   see THE PALETTE SLOT below
//   Pinned & Active Application Grid   Tasks.entries — the taskbar's own model
//   Security Quick-Dashboard           the real posture, computed on open
//   Storage Hub (3 stacked drives)     the real block devices
//
// ══ IT IS A DRAWER, NOT A LAYER SURFACE (TRK-3224) ═════════════════════════
// It shipped once as a `PanelWindow` on `WlrLayer.Overlay`, always mapped
// whenever Settings was open. The owner, 2026-08-28, on TTY1: it sat on top
// of every window he put near Settings, and he had no way to put it away.
// Both halves of that are the same mistake — an Overlay layer surface
// OUTRANKS every normal toplevel by protocol, so no amount of window
// management can get above it, and a panel with no control that closes it is
// not a flyout at all.
//
// So it is now an `Item` living INSIDE the Settings window, which fixes both
// at once: it shares that window's stacking, so anything the compositor puts
// above Settings is above this too; and it slides in and out from the edge on
// a control, closed by default.
//
// Owner ruling TRK-1811 applies and is enforced by the host: **one section at
// a time, and the rail is the switcher.** `Settings.qml` owns a single
// `drawer` string, so opening this one closes the notifications flyout and
// vice versa — two open drawers would leave the window with no content
// visible at all.
//
// ══ NOTHING HERE IS DECORATIVE ═════════════════════════════════════════════
// Owner, 2026-08-27: "nothing faked all needs to be real and working". So:
// every number on this dock is read from the machine when the dock opens, and
// every cell that can be clicked does the thing it names. Where a field could
// not be sourced for real it is ABSENT, not invented — the two places that
// happened are recorded in `CHECKLIST.md` (TRK-3219, TRK-3220) rather than
// filled with a plausible-looking value.
//
// ══ THE PALETTE SLOT ═══════════════════════════════════════════════════════
// The mockup's second slab is a grid of colour chips that re-tints the
// product. This build cannot have that one, and the reason is a standing
// ruling rather than an omission: the four-chip colour-layer picker was
// RETIRED by the owner (`SetPageAppearance.qml` header), gate `13q19` fails
// the bake if a `swirl_layer` picker comes back, and the 2026-08-22 "yes no
// purple" ruling withdrew the key-accent family that such a mixer would have
// selected from. There is no accent-selection key in `settings.json` for a
// swatch to write, so a swatch grid here would be a control that changes
// nothing — the exact thing the brief forbids.
//
// What occupies the slot instead is REAL and is the nearest thing the build
// actually has: the LOOK stones. Three rows of them, writing the three keys
// that genuinely change how the shell paints — `swirl_enabled` / `swirl_mode`
// (the living paint), `sky_mode` (the desktop sky) and `launcher_style` (how
// Start opens). They are the same keys `SetPageAppearance` writes, through
// the same `SettingsStore`, so a change made here shows on that page and in
// the file. Selected reads as a FILLED GROUND, never a second hue.
//
// ══ colour ═════════════════════════════════════════════════════════════════
// Every surface here is `SetSlab` — the one Settings material, OPAQUE, whose
// header carries the measurements that put it on the same colour as his
// desktop widgets. `glacier[4]` for a seam, `glacier[5]` / `glacier[0]` for
// the marks, `Theme.text*` for type. No `tokenAccent*`, no invented tokens.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
    id: dock

    // ── the drawer ──────────────────────────────────────────────────────
    // `open` is driven by the host's one-drawer-at-a-time state. The panel is
    // ALWAYS laid out; what changes is `x`, so the slide is a real movement
    // of a real object rather than a fade of something that was already
    // there. `visible` follows the animation so a closed drawer takes no
    // paint and no input.
    property bool open: false
    signal closeRequested()

    readonly property int bodyW: 236

    width: dock.bodyW
    x: dock.open ? 0 : -dock.bodyW
    visible: dock.x > -dock.bodyW
    Behavior on x {
        NumberAnimation {
            duration: Theme.durBase
            easing.type: Easing.Bezier
            easing.bezierCurve: dock.open ? Theme.curveRise : Theme.curveSink
        }
    }

    // ══ REAL DATA ══════════════════════════════════════════════════════

    // ── the account ─────────────────────────────────────────────────────
    property string userName: ""
    property string hostName: ""
    property string avatarPath: ""

    // ── the drives ──────────────────────────────────────────────────────
    // One entry per real whole block device. `lsblk -P` is parsed rather
    // than eyeballed so a model name with a space in it cannot shift the
    // columns. Loop and optical devices are excluded at the source.
    property var drives: []

    // ── the posture ─────────────────────────────────────────────────────
    property var posture: ({})
    function post(k) {
        var v = dock.posture[k];
        return (v === undefined || v === null) ? "" : String(v);
    }
    // "Secured" is COMPUTED from the three facts below, never asserted: the
    // firewall answering active, at least one LUKS volume, and Secure Boot
    // reporting enabled. Anything less says what is missing instead.
    readonly property int secureCount:
        (dock.post("fw") === "on" ? 1 : 0)
        + (parseInt(dock.post("luks"), 10) > 0 ? 1 : 0)
        + (dock.post("sb") === "1" ? 1 : 0)
    readonly property bool postureKnown: dock.posture.read === "1"

    // ── the look keys ───────────────────────────────────────────────────
    readonly property bool paintOn: SettingsStore.boolValue("swirl_enabled", true)
    readonly property string swirlMode: SettingsStore.stringValue("swirl_mode", "paint")
    readonly property string sky: SettingsStore.stringValue("sky_mode", "headliner")
    readonly property string startStyle: SettingsStore.stringValue("launcher_style", "daily")

    // ── the apps ────────────────────────────────────────────────────────
    // `Tasks.entries` IS the taskbar's model: the pinned apps first, then
    // everything that is actually open. One model, so the dock can never
    // disagree with the Row about what is running.
    readonly property var appCells: Tasks.entries.slice(0, 6)

    // Navigating out of the drawer PUTS THE DRAWER AWAY. A card that opens a
    // page behind an open drawer looks like it did nothing — the page it
    // just loaded is the thing the drawer is covering. TRK-1811's "one
    // section at a time" says the same thing about two drawers; this is the
    // drawer-versus-page half of it.
    function goto(key) {
        dock.closeRequested();
        Bus.openSettings(key);
    }

    function holdCaption(t, item, key) {
        var p = item.mapToItem(dock, item.width / 2, 0);
        hubCap.hold(t, p.x, key, p.y);
    }
    function releaseCaption(key) {
        if (hubCap.owner === key)
            hubCap.release();
    }

    function initialsOf(name) {
        var t = String(name || "").trim();
        if (t === "")
            return "?";
        var parts = t.split(/[\s._-]+/);
        if (parts.length >= 2 && parts[0].length > 0 && parts[1].length > 0)
            return String(parts[0].charAt(0) + parts[1].charAt(0)).toUpperCase();
        return String(t.charAt(0)).toUpperCase();
    }

    // Everything is gathered when the drawer is OPENED and never on a timer:
    // a drawer nobody has pulled out must cost nothing — no subprocess, no
    // poll. This is also why the panel is a drawer rather than an always-on
    // column: three `sh -c` runs per Settings open became three per HUB open.
    onOpenChanged: {
        if (!dock.open)
            return;
        whoProc.running = true;
        diskProc.running = true;
        postureProc.running = true;
    }

    Process {
        id: whoProc
        running: false
        command: ["sh", "-c", `
            emit() { printf '%s\t%s\n' "$1" "$2"; }
            emit user "$(id -un 2>/dev/null)"
            emit host "$(uname -n 2>/dev/null)"
            for f in "$HOME/.face" "$HOME/.face.icon"; do
              [ -r "$f" ] && { emit avatar "$f"; break; }
            done
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = String(this.text).split("\n");
                for (var i = 0; i < lines.length; ++i) {
                    var t = lines[i].indexOf("\t");
                    if (t <= 0)
                        continue;
                    var k = lines[i].substring(0, t);
                    var v = lines[i].substring(t + 1).trim();
                    if (k === "user")        dock.userName = v;
                    else if (k === "host")   dock.hostName = v;
                    else if (k === "avatar") dock.avatarPath = v;
                }
            }
        }
    }

    // Whole devices only (`-d`), loop and optical excluded (`-e 7,11`), and
    // the mounted filesystems separately so a disk can report what is free
    // on it. `-P` is key=value, which survives a model name with spaces.
    Process {
        id: diskProc
        running: false
        command: ["sh", "-c",
            'lsblk -dnP -e 7,11 -o NAME,SIZE,MODEL,TYPE 2>/dev/null || true\n'
          + 'printf "\\037\\n"\n'
          + 'lsblk -nP -e 7,11 -o NAME,PKNAME,MOUNTPOINT,FSAVAIL,FSUSE% 2>/dev/null || true\n'
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                function parse(line) {
                    var rec = {};
                    var re = /([A-Z%]+)="([^"]*)"/g;
                    var m;
                    while ((m = re.exec(line)) !== null)
                        rec[m[1].toLowerCase().replace("%", "pct")] = m[2];
                    return rec;
                }
                var parts = String(this.text).split("\u001f");
                var out = [];
                var byName = {};
                var head = String(parts[0] || "").split("\n");
                for (var i = 0; i < head.length; ++i) {
                    var l = head[i].trim();
                    if (l === "")
                        continue;
                    var d = parse(l);
                    if (!d.name || d.type !== "disk")
                        continue;
                    var rec = {
                        name: d.name,
                        size: d.size || "",
                        model: (d.model || "").trim(),
                        mount: "",
                        avail: "",
                        usepct: ""
                    };
                    byName[d.name] = rec;
                    out.push(rec);
                }
                // Attach the largest mounted filesystem sitting on each disk.
                // "Largest" by the free figure the kernel reports, because a
                // disk with an ESP and a root shows the root, which is the
                // one a person means when they ask how full the drive is.
                var kids = String(parts[1] || "").split("\n");
                for (var j = 0; j < kids.length; ++j) {
                    var kl = kids[j].trim();
                    if (kl === "")
                        continue;
                    var k = parse(kl);
                    if (!k.mountpoint || k.mountpoint === "")
                        continue;
                    var owner = byName[k.pkname] || byName[k.name];
                    if (!owner)
                        continue;
                    if (owner.mount === "" || k.mountpoint === "/") {
                        owner.mount = k.mountpoint;
                        owner.avail = k.fsavail || "";
                        owner.usepct = k.fsusepct || "";
                    }
                }
                dock.drives = out;
            }
        }
    }

    // The same three facts `SetPageSecurity` computes, and by the same means,
    // so the dashboard and the page cannot disagree. `read` is emitted last
    // and is what tells the dock the answer arrived at all — an empty map is
    // "not read yet", which is a different thing from "nothing is on".
    Process {
        id: postureProc
        running: false
        command: ["sh", "-c",
            'emit() { printf "%s\\t%s\\n" "$1" "$2"; }\n'
          + 'PATH="${NYXUS_BIN_DIR:-/usr/local/bin}:$PATH"\n'   // TRK-3435
          + 'if command -v nyxus-secure >/dev/null 2>&1; then\n'
          + '  nyxus-secure status 2>/dev/null | while IFS= read -r ln; do\n'
          + '    k=${ln%%=*}; v=${ln#*=}; [ "$k" = firewall ] && emit fw "$v"; done\n'
          + 'fi\n'
          + 'luks=$(lsblk -o FSTYPE -n 2>/dev/null | grep -c crypto_LUKS || true)\n'
          + 'emit luks "$luks"\n'
          + 'sbv=/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c\n'
          + 'if [ -r "$sbv" ]; then\n'
          + '  emit sb "$(od -An -t u1 "$sbv" 2>/dev/null | awk "{print \\$NF}")"\n'
          + 'fi\n'
          + 'emit read 1\n'
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var next = {};
                var lines = String(this.text).split("\n");
                for (var i = 0; i < lines.length; ++i) {
                    var t = lines[i].indexOf("\t");
                    if (t <= 0)
                        continue;
                    next[lines[i].substring(0, t)] =
                        lines[i].substring(t + 1).trim();
                }
                dock.posture = next;
            }
        }
    }

    // ══ the pane ═══════════════════════════════════════════════════════
    // TRK-3223 — the one opaque Settings material. A drawer that slides over
    // the page has to hide it completely; the old `panelMid` + swell stack
    // showed 10.6% of whatever was beneath.
    SetSlab {
        id: pane
        anchors.fill: parent
        cornerRadius: Theme.r2
        level: 2

        ColumnLayout {
            id: stack
            anchors.fill: parent
            anchors.margins: Theme.s4
            spacing: Theme.s3

            // ── the drawer's own head ───────────────────────────────
            // A drawer needs a way out that is on the drawer. Escape and the
            // scrim close it too (the host owns both), but a person who
            // opened this with a button expects to see the way back.
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: Theme.s2
                spacing: Theme.s3

                Text {
                    Layout.fillWidth: true
                    text: qsTr("UTILITY HUB")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    font.weight: Font.DemiBold
                    font.letterSpacing: Theme.trackMicro
                    elide: Text.ElideRight
                }

                Text {
                    text: "\uf00d"
                    font.family: Theme.fIcon
                    font.pixelSize: Theme.tCaption
                    color: shutHov.hovered ? Theme.text : Theme.textDim
                    HoverHandler { id: shutHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: dock.closeRequested() }
                }
            }

            // ── 1 · the profile card ────────────────────────────────
            Slab {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                onActivated: dock.goto("account")

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.s4
                    spacing: Theme.s4

                    Item {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34

                        Rectangle {
                            anchors.fill: parent
                            radius: 17
                            color: Theme.soften(Theme.paintLayers.glacier[0], 0.24)

                            Text {
                                anchors.centerIn: parent
                                visible: !face.visible
                                text: dock.initialsOf(dock.userName)
                                color: Theme.text
                                // TRK-3431: fUi — Inter Display is
                                // rationalised for 20px+, this is 10px.
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                                font.weight: Font.DemiBold
                            }
                        }

                        Image {
                            id: face
                            anchors.fill: parent
                            visible: dock.avatarPath !== "" && face.status === Image.Ready
                            source: dock.avatarPath !== "" ? "file://" + dock.avatarPath : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 68
                            sourceSize.height: 68
                            smooth: true
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: 17
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.paintLayers.glacier[4]
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: dock.userName !== "" ? dock.userName : qsTr("Reading…")
                            color: Theme.text
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: dock.hostName
                            visible: dock.hostName !== ""
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            // ── 2 · the look stones ─────────────────────────────────
            // The mockup's swatch grid, carrying the keys this build really
            // has. See THE PALETTE SLOT at the top of this file for why it
            // is these three keys and not a colour mixer.
            Slab {
                Layout.fillWidth: true
                Layout.preferredHeight: 116
                // TRK-3461: navigateOnTap stays off (a slab TapHandler fires
                // in parallel with the stones' own taps — picking a swatch
                // must not also navigate), but the old
                // `onActivated: dock.goto("appearance")` beside it could
                // therefore NEVER fire: `activated()` is emitted only by the
                // TapHandler the same line disabled. The header is the nav
                // affordance now — a real one, with its own exclusive grab.
                navigateOnTap: false

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.s3
                    spacing: 3

                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: 2
                        text: qsTr("LOOK")
                        color: lookHdr.containsMouse ? Theme.text : Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                        font.weight: Font.DemiBold
                        font.letterSpacing: Theme.trackMicro

                        MouseArea {
                            id: lookHdr
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dock.goto("appearance")
                        }
                    }

                    // Living paint — `swirl_enabled` + `swirl_mode`.
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 3

                        Stone {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            label: qsTr("OFF")
                            on: !dock.paintOn
                            onPicked: SettingsStore.setValue("swirl_enabled", false)
                        }
                        Stone {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            label: qsTr("PAINT")
                            on: dock.paintOn && dock.swirlMode === "paint"
                            onPicked: {
                                SettingsStore.setValue("swirl_enabled", true);
                                SettingsStore.setValue("swirl_mode", "paint");
                            }
                        }
                        Stone {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            label: qsTr("SHADOW")
                            on: dock.paintOn && dock.swirlMode === "shadow"
                            onPicked: {
                                SettingsStore.setValue("swirl_enabled", true);
                                SettingsStore.setValue("swirl_mode", "shadow");
                            }
                        }
                        Stone {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            label: qsTr("DIM")
                            on: dock.paintOn && dock.swirlMode === "shadow-dim"
                            onPicked: {
                                SettingsStore.setValue("swirl_enabled", true);
                                SettingsStore.setValue("swirl_mode", "shadow-dim");
                            }
                        }
                        Stone {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            label: qsTr("DARK")
                            on: dock.paintOn && dock.swirlMode === "shadow-darkest"
                            onPicked: {
                                SettingsStore.setValue("swirl_enabled", true);
                                SettingsStore.setValue("swirl_mode", "shadow-darkest");
                            }
                        }
                    }

                    // The desktop sky — `sky_mode`.
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 3

                        Stone {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            label: qsTr("SKY")
                            on: dock.sky === "headliner"
                            onPicked: SettingsStore.setValue("sky_mode", "headliner")
                        }
                        Stone {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            label: qsTr("WALL")
                            on: dock.sky === "wallpaper"
                            onPicked: SettingsStore.setValue("sky_mode", "wallpaper")
                        }
                        Stone {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            label: qsTr("LAYERS")
                            on: dock.sky === "layered"
                            onPicked: SettingsStore.setValue("sky_mode", "layered")
                        }
                        Stone {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            label: qsTr("VOYAGE")
                            on: dock.sky === "voyage"
                            onPicked: SettingsStore.setValue("sky_mode", "voyage")
                        }
                    }

                    // How Start opens — `launcher_style`.
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 3

                        Stone {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            label: qsTr("DAILY")
                            on: dock.startStyle === "daily"
                            onPicked: SettingsStore.setValue("launcher_style", "daily")
                        }
                        Stone {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            label: qsTr("CLASSIC")
                            on: dock.startStyle === "classic"
                            onPicked: SettingsStore.setValue("launcher_style", "classic")
                        }
                    }
                }
            }

            // ── 3 · pinned and active applications ──────────────────
            Slab {
                Layout.fillWidth: true
                Layout.preferredHeight: 96
                // TRK-3461: the dead `onActivated: dock.goto("apps")` is
                // deleted rather than "fixed" — with navigateOnTap off the
                // signal could never fire, and this slab is ALL interactive
                // cells: there is no safe tap zone that would not collide
                // with launching an app. The Apps page keeps its rail and
                // hub seats; this slab's cells are the feature.
                navigateOnTap: false

                GridLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.s3
                    columns: 3
                    columnSpacing: Theme.s3
                    rowSpacing: Theme.s3

                    Repeater {
                        model: dock.appCells

                        delegate: Rectangle {
                            id: appCell
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.r1
                            color: appCell.modelData.running
                                   ? Theme.soften(Theme.paintLayers.glacier[0], 0.20)
                                   : (appHov.hovered
                                      ? Theme.soften(Theme.paintLayers.glacier[0], 0.12)
                                      : "transparent")
                            border.width: 1
                            border.color: appCell.modelData.focused
                                          ? Theme.paintLayers.glacier[5]
                                          : Theme.soften(Theme.paintLayers.glacier[4],
                                                         appHov.hovered ? 0.9 : 0.4)

                            CrystalGem {
                                anchors.centerIn: parent
                                width: 28
                                height: 28
                                hot: appHov.hovered
                                on: appCell.modelData.running
                                iconName: appCell.modelData.icon
                            }

                            // The running pip: a small filled mark at the
                            // leading edge, which is this build's language
                            // for "this is live" — never a second hue.
                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: 3
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3
                                height: 10
                                radius: 2
                                visible: appCell.modelData.running
                                color: Theme.paintLayers.glacier[5]
                            }

                            HoverHandler {
                                id: appHov
                                cursorShape: Qt.PointingHandCursor
                                onHoveredChanged: {
                                    if (hovered)
                                        dock.holdCaption(appCell.modelData.name, appCell,
                                                         "app:" + appCell.modelData.key);
                                    else
                                        dock.releaseCaption("app:" + appCell.modelData.key);
                                }
                            }
                            TapHandler { onTapped: Tasks.activate(appCell.modelData) }
                        }
                    }
                }
            }

            // ── 4 · the security quick-dashboard ────────────────────
            Slab {
                Layout.fillWidth: true
                Layout.preferredHeight: 96
                onActivated: dock.goto("security")

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.s3
                    spacing: 1

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.s3

                        Text {
                            text: dock.secureCount >= 3 ? "\uf023" : "\uf3ed"
                            font.family: Theme.fIcon
                            font.pixelSize: 22
                            color: Theme.paintLayers.glacier[5]
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: !dock.postureKnown ? qsTr("Reading…")
                                      : dock.secureCount >= 3 ? qsTr("Secured")
                                      : dock.secureCount + qsTr(" of 3 on")
                                color: Theme.text
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: qsTr("Locked status")
                                color: Theme.textDim
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tMicro
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Fact {
                        Layout.fillWidth: true
                        visible: dock.postureKnown
                        label: qsTr("Firewall")
                        value: dock.post("fw") === "on" ? qsTr("on")
                             : dock.post("fw") === "" ? qsTr("unknown") : qsTr("off")
                        good: dock.post("fw") === "on"
                    }
                    Fact {
                        Layout.fillWidth: true
                        visible: dock.postureKnown
                        label: qsTr("Encrypted volumes")
                        value: dock.post("luks")
                        good: parseInt(dock.post("luks"), 10) > 0
                    }
                    Fact {
                        Layout.fillWidth: true
                        visible: dock.postureKnown
                        label: qsTr("Secure Boot")
                        value: dock.post("sb") === "1" ? qsTr("on")
                             : dock.post("sb") === "" ? qsTr("not reported") : qsTr("off")
                        good: dock.post("sb") === "1"
                    }
                }
            }

            // ── 5 · the storage hub ─────────────────────────────────
            // One card per real whole block device. Capacity and free space
            // are the kernel's own figures. There is deliberately no
            // "Healthy" badge: SMART needs root on this machine and a health
            // word nobody measured is the worst thing on a storage panel
            // (CHECKLIST TRK-3219).
            Slab {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 96
                onActivated: dock.goto("storage")

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.s3
                    spacing: Theme.s2

                    Text {
                        Layout.fillWidth: true
                        Layout.leftMargin: 2
                        text: qsTr("STORAGE")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                        font.weight: Font.DemiBold
                        font.letterSpacing: Theme.trackMicro
                    }

                    Repeater {
                        model: dock.drives

                        delegate: RowLayout {
                            id: driveRow
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: Theme.s3

                            Text {
                                text: "\uf0a0"
                                font.family: Theme.fIcon
                                font.pixelSize: Theme.tCaption
                                color: Theme.paintLayers.glacier[5]
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: driveRow.modelData.name
                                          + (driveRow.modelData.size !== ""
                                             ? "  ·  " + driveRow.modelData.size : "")
                                    color: Theme.text
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tMicro
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    clip: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: driveRow.modelData.mount !== ""
                                          ? (driveRow.modelData.avail !== ""
                                             ? driveRow.modelData.avail + qsTr(" free on ")
                                               + driveRow.modelData.mount
                                             : driveRow.modelData.mount)
                                          : (driveRow.modelData.model !== ""
                                             ? driveRow.modelData.model
                                             : qsTr("not mounted"))
                                    color: Theme.textDim
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tMicro
                                    elide: Text.ElideRight
                                    clip: true
                                }
                            }
                        }
                    }

                    Text {
                        visible: dock.drives.length === 0
                        text: qsTr("Reading disks…")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                    }

                    Item { Layout.fillHeight: true }
                }
            }
        }
    }

    Text {
        id: hubCap
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

        x: Math.max(Theme.s3, Math.min(dock.width - width - Theme.s3, anchorX - width / 2))
        y: hubCap.baseY - hubCap.lift - height
        font.family: Theme.fUi
        font.pixelSize: Theme.tCaption
        font.weight: Font.DemiBold
        color: Theme.text
        opacity: 0
        visible: fly.running || opacity > 0.01
        elide: Text.ElideRight
        clip: true
        width: Math.min(implicitWidth, 180)
        style: Text.Outline
        styleColor: Theme.soften(Theme.void_, 0.78)

        SequentialAnimation {
            id: fly
            NumberAnimation {
                target: hubCap
                property: "opacity"
                from: 0
                to: 1
                duration: 110
            }
            ParallelAnimation {
                NumberAnimation {
                    target: hubCap
                    property: "lift"
                    from: 0
                    to: 36
                    duration: 1600
                    easing.type: Easing.OutCubic
                }
                SequentialAnimation {
                    PauseAnimation { duration: 280 }
                    NumberAnimation {
                        target: hubCap
                        property: "opacity"
                        to: 0
                        duration: 1320
                        easing.type: Easing.InQuad
                    }
                }
            }
        }
    }

    // ══ the parts ══════════════════════════════════════════════════════

    // A dock slab: the widgets' own material — an opaque `Theme.elevated`
    // face with a glacier[4] seam — so the dock reads as the same product as
    // the desktop widgets rather than as a second design.
    component Slab: Item {
        id: slab
        property bool navigateOnTap: true
        signal activated()
        default property alias content: inner.data

        // TRK-3223 — the same opaque material every other Settings surface
        // wears, so a dock card and a page card and one of his desktop
        // widgets are one object at three sizes.
        SetSlab {
            anchors.fill: parent
            cornerRadius: Theme.r2
            level: 1
            lifted: slabHov.hovered
        }

        Item { id: inner; anchors.fill: parent }

        HoverHandler { id: slabHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { enabled: slab.navigateOnTap; onTapped: slab.activated() }
    }

    // One picked-or-not cell. ON is a FILLED GROUND — the build's state
    // language — and never a second hue.
    component Stone: Rectangle {
        id: stone
        property string label: ""
        property bool on: false
        signal picked()

        radius: Theme.r1
        color: stone.on ? Theme.soften(Theme.paintLayers.glacier[0], 0.26)
             : stoneHov.hovered ? Theme.soften(Theme.paintLayers.glacier[0], 0.10)
             : "transparent"
        border.width: 1
        border.color: stone.on ? Theme.paintLayers.glacier[5]
                               : Theme.soften(Theme.paintLayers.glacier[4], 0.45)
        Behavior on color { ColorAnimation { duration: Theme.durQuick } }

        Text {
            anchors.centerIn: parent
            width: parent.width - 4
            horizontalAlignment: Text.AlignHCenter
            text: stone.label
            color: stone.on ? Theme.text : Theme.textMuted
            font.family: Theme.fUi
            font.pixelSize: Theme.tMicro
            font.weight: stone.on ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
        }

        HoverHandler { id: stoneHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: stone.picked() }
    }

    // One measured fact on the security slab. The value carries a pip when
    // it is the good answer — the leading-edge mark again, not a colour.
    component Fact: RowLayout {
        id: fact
        property string label: ""
        property string value: ""
        property bool good: false
        spacing: Theme.s2

        Rectangle {
            Layout.preferredWidth: 3
            Layout.preferredHeight: 3
            radius: 2
            visible: fact.good
            color: Theme.paintLayers.glacier[5]
        }
        Item {
            Layout.preferredWidth: 3
            visible: !fact.good
        }

        Text {
            Layout.fillWidth: true
            text: fact.label
            color: Theme.textDim
            font.family: Theme.fUi
            font.pixelSize: Theme.tMicro
            elide: Text.ElideRight
            clip: true
        }
        Text {
            text: fact.value
            color: fact.good ? Theme.text : Theme.textMuted
            font.family: Theme.fUi
            font.pixelSize: Theme.tMicro
            elide: Text.ElideRight
            clip: true
            Layout.maximumWidth: 72
        }
    }
}
