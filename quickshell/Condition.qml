pragma ComponentBehavior: Bound
// Nyxus Suxyn — CONDITION. The console half of Settings.
//
// TRK-1804. Owner ruling 2026-08-22, on the question "should Security be its
// own thing": the split that matters is not security-versus-settings, it is
// **watching versus configuring**. The test for any page is *does it change
// without me*.
//
// Security's live half did — a ring, a scan you run, a history you read, and a
// QUEUE OF QUARANTINE DECISIONS waiting on a human. So did Updates, Health and
// Backup. None of those is a value you set, and none of them can reach you from
// a Settings page, because Settings is closed. That queue is the entire
// justification for this surface existing.
//
// What STAYED in Settings, deliberately: the four protection baseline switches,
// Firewall, Privacy and Secure Boot. Those are values you set, and they belong
// where people look for settings.
//
// ── EVERY BOARD READS A REAL BACKEND ──────────────────────────────────────
// Nothing here is a placeholder, and nothing displays a number it invented:
//   updates    `nyxus-update --check`        (same source as SetPageUpdates)
//   health     `nyxus-doctor --json --fast`  (same source as SetPageHealth)
//   snapshots  `snapper list`                (same source as SetPageBackup)
//   protection `nyxus-hemera status --json`  (same source as SetPageSecurity)
// If a backend is absent the board says so in words rather than showing a
// hopeful zero — an installed-but-never-run check reported as "0 problems" is
// the dishonesty GHOST was built to avoid.
//
// ── IT IS A WINDOW, NOT A FLYOUT ──────────────────────────────────────────
// Same `FloatingWindow` as Settings, and the same 960×640, because it is
// Settings' sibling rather than a different design. HORIZON's "transient
// surfaces rise out of the Line" is about transient surfaces; this is
// something you leave open on one monitor while a scan finishes.
//
// ── REFRESH IS EVENT-DRIVEN ───────────────────────────────────────────────
// Every probe runs on OPEN and on an explicit Refresh, never on a timer. The
// repo's rule, learned the hard way: two labels spawning subprocesses every
// 50 ms once starved the event loop badly enough that the lock screen could
// not be unlocked.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

FloatingWindow {
    id: win

    title: qsTr("Condition")
    visible: Bus.conditionOpen
    color: Theme.void_

    implicitWidth: 960
    implicitHeight: 640

    readonly property color iceInteractive: Theme.lookHot
    readonly property color icePrimary: Theme.lookPale
    readonly property color iceHairline: Theme.lookSeam

    // ── state, all of it from a real probe ───────────────────────────────
    property int updateCount: -1        // -1 = not checked yet
    property bool updatesUnavailable: false
    property int snapshotCount: -1
    property bool snapshotsUnavailable: false
    // TRK-3181 — last off-disk backup lives on THIS board only
    // (nyxus-backup status --json last_run). Health board is HEALTH's.
    property bool backupProbed: false
    property bool backupUnavailable: false
    property bool backupHadRun: false
    property bool backupLastOk: false
    property string backupSummary: ""
    property int healthOk: 0
    property int healthWarn: 0
    property int healthFail: 0
    property bool healthUnavailable: false
    property var healthChecks: []
    property bool hemeraUnavailable: false
    property int quarantineCount: 0
    property string firewall: ""
    property bool probing: false

    // A board that has never been probed says so. It does NOT say zero.
    function countText(n, unavailable) {
        if (unavailable) return qsTr("unavailable");
        if (n < 0) return qsTr("not checked");
        return String(n);
    }

    // ── the queue. This is why the surface exists. ───────────────────────
    readonly property var needs: {
        var out = [];
        if (win.quarantineCount > 0)
            out.push({ tag: qsTr("Quarantine"),
                       title: qsTr("%1 file(s) held").arg(win.quarantineCount),
                       sub: qsTr("Held, not deleted — they wait for your decision") });
        if (win.updateCount > 0)
            out.push({ tag: qsTr("Updates"),
                       title: qsTr("%1 update(s) ready").arg(win.updateCount),
                       sub: qsTr("A snapshot is taken before anything is applied") });
        if (Sys.diskPercent >= 75)
            out.push({ tag: qsTr("Disk"),
                       title: qsTr("Root disk at %1%").arg(Sys.diskPercent),
                       sub: Sys.diskText });
        if (win.healthFail > 0)
            out.push({ tag: qsTr("Health"),
                       title: qsTr("%1 check(s) failing").arg(win.healthFail),
                       sub: qsTr("Settings ▸ System ▸ Health names the fix") });
        for (var hi = 0; hi < win.healthChecks.length; hi++) {
            var hc = win.healthChecks[hi];
            if (!hc || !hc.service || hc.level === "ok")
                continue;
            out.push({ tag: qsTr("Service"),
                       title: String(hc.name || ""),
                       sub: (hc.if_ignored ? qsTr("If you wait: ") + hc.if_ignored
                                           : (hc.fix || hc.detail || "")) });
        }
        if (win.firewall === "off")
            out.push({ tag: qsTr("Firewall"),
                       title: qsTr("Firewall is off"),
                       sub: qsTr("Inbound is open. Security still has the switch.") });
        return out;
    }

    function refresh() {
        win.probing = true;
        updateProbe.running = true;
        snapshotProbe.running = true;
        healthProbe.running = true;
        hemeraProbe.running = true;
        fwProbe.running = true;
        backupProbe.running = true;
    }
    onVisibleChanged: if (visible) win.refresh()

    // ── probes ───────────────────────────────────────────────────────────
    Process {
        id: updateProbe
        running: false
        command: ["sh", "-c",
            'if command -v nyxus-update >/dev/null 2>&1; then '
          + '  nyxus-update --check 2>/dev/null; exit 0; '
          + 'elif command -v checkupdates >/dev/null 2>&1; then '
          + '  checkupdates 2>/dev/null; exit 0; '
          + 'else echo "__NOCHECK__"; fi']
        stdout: StdioCollector {
            onStreamFinished: {
                var t = String(this.text).trim();
                if (t.indexOf("__NOCHECK__") >= 0) {
                    win.updatesUnavailable = true; win.updateCount = -1;
                } else {
                    win.updatesUnavailable = false;
                    win.updateCount = t === "" ? 0 : t.split("\n").filter(function (l) {
                        return l.trim() !== "";
                    }).length;
                }
                win.probing = false;
            }
        }
    }

    Process {
        id: snapshotProbe
        running: false
        command: ["sh", "-c",
            'if command -v snapper >/dev/null 2>&1; then '
          + '  snapper list 2>/dev/null | tail -n +3 | grep -c . ; '
          + 'else echo "__NOCHECK__"; fi']
        stdout: StdioCollector {
            onStreamFinished: {
                var t = String(this.text).trim();
                if (t === "" || t.indexOf("__NOCHECK__") >= 0) {
                    win.snapshotsUnavailable = true; win.snapshotCount = -1;
                } else {
                    win.snapshotsUnavailable = false;
                    win.snapshotCount = parseInt(t, 10);
                    if (isNaN(win.snapshotCount)) {
                        win.snapshotCount = -1; win.snapshotsUnavailable = true;
                    }
                }
            }
        }
    }

    Process {
        id: backupProbe
        running: false
        command: ["sh", "-c",
            'if command -v nyxus-backup >/dev/null 2>&1; then nyxus-backup status --json 2>/dev/null; '
          + 'else echo "__NOCHECK__"; fi']
        stdout: StdioCollector {
            onStreamFinished: {
                var t = String(this.text).trim();
                win.backupProbed = true;
                if (t === "" || t.indexOf("__NOCHECK__") >= 0) {
                    win.backupUnavailable = true;
                    win.backupHadRun = false;
                    win.backupSummary = "";
                    return;
                }
                try {
                    var d = JSON.parse(t);
                    win.backupUnavailable = false;
                    var lr = d.last_run || null;
                    win.backupHadRun = !!(lr && lr.when);
                    win.backupLastOk = !!(lr && lr.ok);
                    win.backupSummary = String(d.summary || "");
                    if (win.backupSummary === "" && win.backupHadRun)
                        win.backupSummary = qsTr("Last backup %1").arg(String(lr.when));
                } catch (e) {
                    win.backupUnavailable = true;
                    win.backupHadRun = false;
                    win.backupSummary = "";
                }
            }
        }
    }

    Process {
        id: healthProbe
        running: false
        command: ["sh", "-c",
            'if command -v nyxus-doctor >/dev/null 2>&1; then exec nyxus-doctor --json --fast; fi; '
          + 'if command -v nyxus >/dev/null 2>&1; then exec nyxus doctor --json --fast; fi; '
          + 'echo "__NOCHECK__"']
        stdout: StdioCollector {
            onStreamFinished: {
                var t = String(this.text).trim();
                if (t === "" || t.indexOf("__NOCHECK__") >= 0) {
                    win.healthUnavailable = true;
                    return;
                }
                try {
                    var d = JSON.parse(t);
                    var checks = d.checks || [];
                    var ok = 0, warn = 0, fail = 0;
                    for (var i = 0; i < checks.length; i++) {
                        var lv = String(checks[i].level || checks[i].status || "").toLowerCase();
                        if (lv === "ok" || lv === "pass") ok++;
                        else if (lv === "warn") warn++;
                        else if (lv === "fail") fail++;
                    }
                    win.healthChecks = checks;
                    win.healthOk = ok; win.healthWarn = warn; win.healthFail = fail;
                    win.healthUnavailable = false;
                } catch (e) {
                    win.healthUnavailable = true;
                }
            }
        }
    }

    Process {
        id: hemeraProbe
        running: false
        command: ["sh", "-c",
            'if command -v nyxus-hemera >/dev/null 2>&1; then nyxus-hemera status --json 2>/dev/null; '
          + 'else echo "__NOCHECK__"; fi']
        stdout: StdioCollector {
            onStreamFinished: {
                var t = String(this.text).trim();
                if (t === "" || t.indexOf("__NOCHECK__") >= 0) {
                    win.hemeraUnavailable = true; win.quarantineCount = 0;
                    return;
                }
                try {
                    var d = JSON.parse(t);
                    var v = d.vault || {};
                    var n = v.awaiting_decision;
                    if (typeof n === "number")
                        win.quarantineCount = n;
                    else if (Array.isArray(v))
                        win.quarantineCount = v.length;
                    else
                        win.quarantineCount = 0;
                    win.hemeraUnavailable = false;
                } catch (e) {
                    win.hemeraUnavailable = true; win.quarantineCount = 0;
                }
            }
        }
    }

    Process {
        id: fwProbe
        running: false
        command: ["sh", "-c",
            'if command -v nyxus-secure >/dev/null 2>&1; then '
          + '  nyxus-secure status 2>/dev/null | awk -F= \'/^firewall=/{print $2; exit}\'; '
          + 'elif command -v firewall-cmd >/dev/null 2>&1; then '
          + '  firewall-cmd --state 2>/dev/null | grep -qi running && echo on || echo off; '
          + 'else echo unknown; fi']
        stdout: StdioCollector {
            onStreamFinished: {
                var t = String(this.text).trim().toLowerCase();
                if (t === "on" || t === "off")
                    win.firewall = t;
                else
                    win.firewall = "";
            }
        }
    }

    // ═══ CHROME ══════════════════════════════════════════════════════════
    // Same glass as Settings / AppWindow. The void Rectangle was the
    // leftover: a flat Theme.void_ box instead of Pane + swell +
    // GlassEdge body 0 + glacier[4] seam.
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
        bloomAtRest: false

        CutRect {
            anchors.fill: parent
            radius: Theme.r3
            gradTop: Theme.swellGroundTop
            gradMid: Theme.swellGroundMid
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

            // header, 48, matching Settings
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                clip: true
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.s6
                    anchors.rightMargin: Theme.s5
                    spacing: Theme.s4

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Condition")
                        color: Theme.text
                        font.family: Theme.fUiTitle
                        font.pixelSize: Theme.tHead
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        clip: true
                    }
                    SetButton {
                        text: win.probing ? qsTr("Checking…") : qsTr("Refresh")
                        onClicked: win.refresh()
                    }
                }
                Rectangle {
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    anchors.leftMargin: Theme.s6
                    anchors.rightMargin: Theme.s6
                    height: 1
                    color: win.iceHairline
                    opacity: 0.22
                }
            }

            // body
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: Theme.s6
                spacing: Theme.s5

                // ── NEEDS YOU ────────────────────────────────────────
                // TRK-3370 — onto the widgets' stack. The glacier[3] tint it
                // wore was a mid rung used as a FILL, the exact role its own
                // token forbids (audit item 23's discriminator).
                SetSlab {
                    Layout.fillWidth: true
                    Layout.preferredHeight: needsCol.implicitHeight + Theme.s5 * 2
                    cornerRadius: Theme.r2

                    ColumnLayout {
                        id: needsCol
                        anchors.fill: parent
                        anchors.margins: Theme.s5
                        spacing: Theme.s4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.s4
                            Text {
                                text: qsTr("NEEDS YOU")
                                color: Theme.textDim
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tMicro
                                font.weight: Font.Medium
                                font.letterSpacing: Theme.trackMicro
                            }
                            Rail { Layout.fillWidth: true; tone: 0.3; strength: 0.22; waist: 0.9 }
                            Text {
                                text: win.needs.length
                                color: Theme.soften(Theme.textDim, 0.7)
                                font.family: Theme.fNum
                                font.pixelSize: Theme.tMicro
                            }
                        }

                        // Empty is the normal state, and it says so in one line
                        // rather than leaving a blank panel that reads as broken.
                        Text {
                            visible: win.needs.length === 0
                            Layout.fillWidth: true
                            text: qsTr("Nothing is waiting on you.")
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tBody
                        }

                        Repeater {
                            model: win.needs
                            delegate: Rectangle {
                                id: needRow
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                radius: Theme.r1
                                color: Theme.soften(Theme.void_, 0.42)

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.s5
                                    anchors.rightMargin: Theme.s5
                                    spacing: Theme.s5

                                    Text {
                                        text: needRow.modelData.tag
                                        color: win.icePrimary
                                        font.family: Theme.fUi
                                        font.pixelSize: Theme.tMicro
                                        font.weight: Font.Medium
                                        font.letterSpacing: Theme.trackMicro
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text {
                                            Layout.fillWidth: true
                                            text: needRow.modelData.title
                                            color: Theme.text
                                            font.family: Theme.fUi
                                            font.pixelSize: Theme.tLabel
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                            clip: true
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: needRow.modelData.sub
                                            color: Theme.textDim
                                            font.family: Theme.fUi
                                            font.pixelSize: Theme.tCaption
                                            elide: Text.ElideRight
                                            clip: true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── THE FOUR BOARDS ──────────────────────────────────
                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 2
                    columnSpacing: Theme.s5
                    rowSpacing: Theme.s5

                    Repeater {
                        model: [
                            { key: "prot",  head: qsTr("PROTECTION") },
                            { key: "upd",   head: qsTr("UPDATES") },
                            { key: "snap",  head: qsTr("SNAPSHOTS") },
                            { key: "heal",  head: qsTr("HEALTH") }
                        ]
                        // TRK-3370 — board cards onto the widgets' stack.
                        delegate: SetSlab {
                            id: board
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            cornerRadius: Theme.r2

                            readonly property string reading: {
                                switch (board.modelData.key) {
                                case "prot": return win.hemeraUnavailable ? qsTr("unavailable")
                                            : (win.quarantineCount > 0
                                               ? qsTr("%1 held").arg(win.quarantineCount)
                                               : qsTr("Active"));
                                case "upd":  return win.countText(win.updateCount, win.updatesUnavailable);
                                case "snap":
                                    if (win.backupProbed && !win.backupUnavailable && win.backupHadRun)
                                        return win.backupLastOk ? qsTr("BACKED UP") : qsTr("LAST RUN FAILED");
                                    if (win.snapshotsUnavailable)
                                        return qsTr("unavailable");
                                    return win.countText(win.snapshotCount, win.snapshotsUnavailable);
                                case "heal": return win.healthUnavailable ? qsTr("unavailable")
                                            : (win.healthFail > 0
                                               ? qsTr("%1 fail").arg(win.healthFail)
                                               : (win.healthWarn > 0
                                                  ? qsTr("%1 warn").arg(win.healthWarn)
                                                  : qsTr("ALL UP")));
                                }
                                return "";
                            }
                            readonly property string settingsKey: {
                                switch (board.modelData.key) {
                                case "prot": return "security";
                                case "upd":  return "updates";
                                case "snap": return "backup";
                                case "heal": return "health";
                                }
                                return "";
                            }
                            readonly property string detail: {
                                switch (board.modelData.key) {
                                case "prot": return win.hemeraUnavailable
                                            ? qsTr("nyxus-hemera is not installed")
                                            : qsTr("HEMERA is watching while you are awake");
                                case "upd":  return win.updatesUnavailable
                                            ? qsTr("No update checker on PATH")
                                            : qsTr("A snapshot is taken before anything is applied");
                                case "snap":
                                    if (win.backupSummary !== "")
                                        return win.backupSummary;
                                    if (win.snapshotsUnavailable)
                                        return qsTr("Snapshots could not be listed");
                                    if (win.backupProbed && win.backupUnavailable)
                                        return qsTr("No off-disk backup tool — snapper count only");
                                    if (win.backupProbed && !win.backupHadRun)
                                        return qsTr("No off-disk backup yet");
                                    return qsTr("Taken before every update");
                                case "heal": return win.healthUnavailable
                                            ? qsTr("nyxus-doctor is not available")
                                            : qsTr("%1 warning(s), %2 failing")
                                              .arg(win.healthWarn).arg(win.healthFail);
                                }
                                return "";
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.s5
                                spacing: Theme.s4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.s4
                                    Text {
                                        text: board.modelData.head
                                        color: Theme.textDim
                                        font.family: Theme.fUi
                                        font.pixelSize: Theme.tMicro
                                        font.weight: Font.Medium
                                        font.letterSpacing: Theme.trackMicro
                                    }
                                    Rail { Layout.fillWidth: true; tone: 0.3; strength: 0.22; waist: 0.9 }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: board.reading
                                    color: Theme.text
                                    font.family: Theme.fUiTitle
                                    font.pixelSize: Theme.tTitle
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    clip: true
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: board.detail
                                    color: Theme.textDim
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tCaption
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                    clip: true
                                }
                                Item { Layout.fillHeight: true }

                                // TRK-1805 RESOLVED BY LINKING, NOT MOVING. The
                                // full pages (Updates 492 lines, Health 386,
                                // Backup 105) carry the real controls -- apply,
                                // rollback, run a scan. Deleting them from the
                                // Settings catalogue to hit a category count
                                // would strand those controls with no route to
                                // them, which is a worse defect than a page
                                // living in a tidy place. So Condition WATCHES
                                // and links; Settings CONFIGURES. One route to
                                // each control, not two copies of it.
                                SetButton {
                                    text: qsTr("Open")
                                    onClicked: {
                                        Bus.conditionOpen = false;
                                        Bus.openSettings(board.settingsKey);
                                    }
                                }
                            }
                        }
                    }
                }
            }
    }
}
