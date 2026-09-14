pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ System ▸ Health (TRK-1233).
//
// `nyxus doctor` and `nyxus status` as a page. Two processes, each run ONCE
// when the page opens and again only when asked (About's rule: no timer, a
// panel gathers on open). Both emit JSON:
//
//   nyxus-doctor --json --fast    → { summary:{ok,warn,fail}, checks:[…] }
//   nyxus-status --json           → { units:[…], processes:[…] }
//
// `--fast` skips `pacman -Qu` so the page answers in about a second; the
// full check is one click away in a terminal (`nyxus doctor`).
//
// Levels paint with the build's own tokens and nothing else: Theme.ok,
// Theme.warn, Theme.danger — the three semantic rungs Theme declares for
// exactly this, and the one place `danger` is legal as a mark (errors).
// The chip is a hairline + text, never a filled badge (HORIZON §4.3: on is
// LIT, not filled).
//
// Switches: the nyxus-* user units can be turned off and on here — driven
// SetSwitch (`key: ""`), the system is the truth, not settings.json. The
// stack units (PipeWire, the portals, the polkit agent) are listed read-only;
// nyxus-status refuses them too, so the page cannot do what the CLI forbids.
//
// "Copy report" runs `nyxus-doctor --report --fast --json`, which writes
// ~/Downloads/nyxus-report-<date>.tar.gz (checks, journal tail for the nyxus
// units, hardware, build stamp, settings.json with secrets stripped), then
// puts that PATH on the clipboard through wl-copy — the same door every
// other copy button in this build uses.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page

    property var entry: null

    title: qsTr("Health")
    blurb: qsTr("What the desktop leans on, whether it is up, and what to do when it is not.")

    // ── state ───────────────────────────────────────────────────────────
    property var checks: []
    property var summary: ({ ok: 0, warn: 0, fail: 0 })
    property bool doctorDone: false
    property string doctorError: ""
    property string doctorStamp: ""

    property var units: []
    property var processes: []
    property bool statusDone: false
    property string statusError: ""

    property string reportPath: ""
    property bool reportBusy: false

    readonly property string unknownText: "—"

    function levelColor(level) {
        if (level === "ok")   return Theme.ok;
        if (level === "warn") return Theme.warn;
        return Theme.danger;
    }
    function levelText(level) {
        if (level === "ok")   return "OK";
        if (level === "warn") return "WARN";
        return "FAIL";
    }
    function levelGlyph(level) {
        if (level === "ok")   return "";
        if (level === "warn") return "";
        return "";
    }
    function fmtRss(kb) {
        if (kb === null || kb === undefined) return "";
        if (kb >= 1024) return Math.round(kb / 1024) + " MiB";
        return kb + " KiB";
    }
    function unitLine(u) {
        var bits = [];
        bits.push(u.active + (u.sub && u.sub !== u.active ? " (" + u.sub + ")" : ""));
        if (u.pid) bits.push("pid " + u.pid);
        if (u.cpu_pct !== null && u.cpu_pct !== undefined) bits.push(u.cpu_pct.toFixed(1) + "% cpu");
        var r = page.fmtRss(u.rss_kb);
        if (r !== "") bits.push(r);
        if (u.restarts > 0) bits.push(u.restarts + " restart" + (u.restarts === 1 ? "" : "s"));
        return bits.join(" · ");
    }
    function headline() {
        if (!page.doctorDone) return page.doctorError !== "" ? "NO ANSWER" : "READING";
        if (page.summary.fail > 0) return page.summary.fail + " FAIL";
        if (page.summary.warn > 0) return page.summary.warn + " WARN";
        return "ALL UP";
    }
    function headlineCaption() {
        if (!page.doctorDone)
            return page.doctorError !== "" ? page.doctorError : "nyxus doctor is running…";
        return page.summary.ok + " OK · " + page.summary.warn + " WARN · " + page.summary.fail + " FAIL"
               + (page.doctorStamp !== "" ? " · as of " + page.doctorStamp : "");
    }
    function serviceRows() {
        var out = [];
        for (var i = 0; i < page.checks.length; i++) {
            var c = page.checks[i];
            if (c && c.service && c.level && c.level !== "ok")
                out.push(c);
        }
        return out;
    }

    // ── the doctor ──────────────────────────────────────────────────────
    // `nyxus-doctor` is the shipped launcher (/usr/local/bin); a preview
    // HOME carries its own in ~/.local/bin. The dispatcher form is the
    // fallback so a machine with only `nyxus` on PATH still answers.
    Process {
        id: doctorProc
        running: false
        command: ["sh", "-c",
                  // TRK-3435: shipped-first (ruling: SetPageBackup.qml).
                  'PATH="${NYXUS_BIN_DIR:-/usr/local/bin}:$PATH"; '
                  + "if command -v nyxus-doctor >/dev/null 2>&1; then exec nyxus-doctor --json --fast; fi; "
                  + "exec nyxus doctor --json --fast"]
        stdout: StdioCollector {
            onStreamFinished: {
                var txt = String(this.text).trim();
                try {
                    var d = JSON.parse(txt);
                    page.checks = d.checks || [];
                    page.summary = d.summary || { ok: 0, warn: 0, fail: 0 };
                    if (!d.summary && page.checks.length) {
                        var ok = 0, warn = 0, fail = 0;
                        for (var i = 0; i < page.checks.length; i++) {
                            var lv = String(page.checks[i].level || "").toLowerCase();
                            if (lv === "ok") ok++;
                            else if (lv === "warn") warn++;
                            else if (lv === "fail") fail++;
                        }
                        page.summary = { ok: ok, warn: warn, fail: fail };
                    }
                    page.doctorError = "";
                    page.doctorDone = true;
                    page.doctorStamp = Qt.formatDateTime(new Date(), "HH:mm:ss");
                } catch (e) {
                    page.doctorDone = false;
                    page.doctorError = qsTr("Unavailable");
                    console.warn("Health: doctor parse failed: " + e + " :: " + txt.substring(0, 200));
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (String(this.text).trim() !== "")
                    console.warn("Health: doctor stderr: " + this.text);
            }
        }
    }

    // ── the inventory ───────────────────────────────────────────────────
    Process {
        id: statusProc
        running: false
        command: ["sh", "-c",
                  'PATH="${NYXUS_BIN_DIR:-/usr/local/bin}:$PATH"; '   // TRK-3435
                  + "if command -v nyxus-status >/dev/null 2>&1; then exec nyxus-status --json; fi; "
                  + "exec nyxus status --json"]
        stdout: StdioCollector {
            onStreamFinished: {
                var txt = String(this.text).trim();
                try {
                    var d = JSON.parse(txt);
                    page.units = d.units || [];
                    page.processes = d.processes || [];
                    page.statusError = "";
                    page.statusDone = true;
                } catch (e) {
                    page.statusDone = false;
                    page.statusError = qsTr("Unavailable");
                    console.warn("Health: status parse failed: " + e + " :: " + txt.substring(0, 200));
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (String(this.text).trim() !== "")
                    console.warn("Health: status stderr: " + this.text);
            }
        }
    }

    // ── a switch flip: enable/disable, then re-read the inventory ───────
    Process {
        id: switchProc
        running: false
        property string unit: ""
        // Re-read the inventory when the flip has finished. `onRunningChanged`
        // rather than `onExited`: the exited signal carries a QProcess enum
        // the linter cannot resolve from here, and the page does not need it.
        onRunningChanged: if (!running) statusProc.running = true
        stderr: StdioCollector {
            onStreamFinished: {
                if (String(this.text).trim() !== "")
                    console.warn("Health: switch " + switchProc.unit + ": " + this.text);
            }
        }
    }
    function setUnit(unit, on) {
        switchProc.unit = unit;
        switchProc.command = ["sh", "-c",
                              'PATH="${NYXUS_BIN_DIR:-/usr/local/bin}:$PATH"; '   // TRK-3435
                              + "if command -v nyxus-status >/dev/null 2>&1; then exec nyxus-status "
                              + (on ? "--on" : "--off") + " \"$1\"; fi; exec nyxus status "
                              + (on ? "--on" : "--off") + " \"$1\"", "sh", unit];
        switchProc.running = true;
    }

    // ── the report bundle ───────────────────────────────────────────────
    Process {
        id: reportProc
        running: false
        command: ["sh", "-c",
                  'PATH="${NYXUS_BIN_DIR:-/usr/local/bin}:$PATH"; '   // TRK-3435
                  + "if command -v nyxus-doctor >/dev/null 2>&1; then exec nyxus-doctor --report --fast --json; fi; "
                  + "exec nyxus doctor --report --fast --json"]
        onRunningChanged: page.reportBusy = running
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(String(this.text).trim());
                    page.reportPath = d.report || "";
                    if (page.reportPath !== "") {
                        copyProc.command = ["wl-copy", "--", page.reportPath];
                        copyProc.running = true;
                    }
                } catch (e) {
                    console.warn("Health: report parse failed: " + e);
                }
            }
        }
    }
    Process { id: copyProc; running: false }

    function refresh() {
        doctorProc.running = true;
        statusProc.running = true;
    }
    Component.onCompleted: page.refresh()

    // ══ the page ═══════════════════════════════════════════════════════
    SetCard {
        heading: qsTr("This machine, right now")
        tone: page.tone
        note: qsTr("Every row is computed by `nyxus doctor` on this machine; nothing here calls out. ")
              + "A WARN is a note, a FAIL names what is broken and the line under it is the fix."

        SetRow {
            title: qsTr("Health")
            sub: page.headlineCaption()
            valueText: page.headline()
        }

        SetRow {
            glyph: ""
            title: qsTr("Run the checks again")
            sub: page.doctorStamp === "" ? qsTr("Reading…") : qsTr("Last read at ") + page.doctorStamp + ". Nothing here polls."

            SetButton {
                text: qsTr("Refresh")
                glyph: ""
                tone: page.tone
                busy: doctorProc.running || statusProc.running
                onClicked: page.refresh()
            }
        }
    }

    SetCard {
        heading: qsTr("Service")
        tone: page.tone
        note: qsTr("Oil-change reminders from the same doctor as the checks. ")
              + "Every number is measured on this machine. A missing tool says unavailable, never zero."

        SetRow {
            visible: page.serviceRows().length === 0 && page.doctorDone
            title: qsTr("Nothing waiting")
            sub: qsTr("Disk, SMART, backup, updates age, RAM, NIC and thermal are OK or unavailable.")
        }
        SetRow {
            visible: !page.doctorDone
            title: qsTr("Waiting for the doctor…")
        }

        SetRow {
            glyph: ""
            title: qsTr("Battery remaining")
            sub: !Sys.hasBattery
                 ? qsTr("unavailable — this machine has no battery")
                 : (Sys.batteryCharging
                    ? qsTr("%1% remaining · charging").arg(Sys.batteryPercent)
                    : (qsTr("%1% remaining").arg(Sys.batteryPercent)
                       + (!Sys.batteryCharging && Sys.batteryPercent <= 15
                          ? "\n" + qsTr("If you wait: the session will sleep, then the machine will go dark")
                          : "")))
        }

        SetRow {
            glyph: ""
            title: qsTr("Screen time")
            sub: Sys.uptimeText.length > 0
                 ? qsTr("%1 remaining · session since boot, not per-app").arg(Sys.uptimeText)
                 : qsTr("unavailable — session uptime has not been read")
        }

        Repeater {
            model: page.serviceRows()
            delegate: SetRow {
                id: svc
                required property var modelData
                glyph: page.levelGlyph(svc.modelData.level)
                title: svc.modelData.name
                sub: svc.modelData.detail
                     + (svc.modelData.fix ? "\n" + qsTr("Do this: ") + svc.modelData.fix : "")
                     + (svc.modelData.if_ignored ? "\n" + qsTr("If you wait: ") + svc.modelData.if_ignored : "")

                Rectangle {
                    implicitWidth: svcChip.implicitWidth + 2 * Theme.s4
                    implicitHeight: 22
                    radius: Theme.r1
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.soften(page.levelColor(svc.modelData.level), 0.85)
                    Text {
                        id: svcChip
                        anchors.centerIn: parent
                        text: page.levelText(svc.modelData.level)
                        font.family: Theme.fNum
                        font.pixelSize: Theme.tLabel
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                        color: page.levelColor(svc.modelData.level)
                    }
                }
            }
        }

        SetRow {
            glyph: ""
            title: qsTr("Live trend")
            sub: qsTr("Same 5 s ambient tick as the desktop (never a second poll). Processor, memory, temperature, network.")
        }
        Canvas {
            id: healthSpark
            implicitHeight: 48
            Layout.fillWidth: true
            onWidthChanged: requestPaint()
            Connections {
                target: Sys
                function onHistCpuChanged() { healthSpark.requestPaint(); }
            }
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                function stroke(samples, color) {
                    var s = samples || [];
                    if (s.length < 2 || width < 8) return;
                    var mx = 1;
                    for (var i = 0; i < s.length; i++)
                        if (Number(s[i]) > mx) mx = Number(s[i]);
                    ctx.strokeStyle = color;
                    ctx.lineWidth = 1.4;
                    ctx.beginPath();
                    for (var j = 0; j < s.length; j++) {
                        var x = j * (width - 1) / (s.length - 1);
                        var y = height - 1 - (Number(s[j]) / mx) * (height - 2);
                        if (j === 0) ctx.moveTo(x, y);
                        else ctx.lineTo(x, y);
                    }
                    ctx.stroke();
                }
                stroke(Sys.histCpu, Theme.paintLayers.glacier[5]);
                stroke(Sys.histMem, Theme.paintLayers.glacier[0]);
                if (Sys.hasTemp)
                    // TRK-3432: was magma[5] — magma's registered role is
                    // destroy/record, not a chart series. warn (gold) is the
                    // sanctioned heat-adjacent ink, and it stays legible
                    // beside the three glacier rungs.
                    stroke(Sys.histTemp, Theme.warn);
                stroke(Sys.histNet, Theme.lookSeam);
            }
        }
    }

    SetCard {
        heading: qsTr("Checks")
        tone: page.tone

        SetRow {
            visible: page.checks.length === 0
            title: page.doctorError !== "" ? page.doctorError : qsTr("Waiting for the doctor…")
            sub: page.doctorError !== "" ? qsTr("Health checks could not run on this machine.") : ""
        }

        Repeater {
            model: page.checks
            delegate: SetRow {
                id: chk
                required property var modelData
                glyph: page.levelGlyph(chk.modelData.level)
                title: chk.modelData.name
                sub: chk.modelData.detail
                     + (chk.modelData.level !== "ok" && chk.modelData.fix ? "\nfix: " + chk.modelData.fix : "")
                     + (chk.modelData.level !== "ok" && chk.modelData.if_ignored
                        ? "\nif you wait: " + chk.modelData.if_ignored : "")

                // The level chip: hairline + text in the level's rung. No fill.
                Rectangle {
                    implicitWidth: chipText.implicitWidth + 2 * Theme.s4
                    implicitHeight: 22
                    radius: Theme.r1
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.soften(page.levelColor(chk.modelData.level), 0.85)

                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: page.levelText(chk.modelData.level)
                        font.family: Theme.fNum
                        font.pixelSize: Theme.tLabel
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                        color: page.levelColor(chk.modelData.level)
                    }
                }
            }
        }
    }

    SetCard {
        heading: qsTr("Units and timers")
        tone: page.tone
        note: qsTr("The nyxus-* user units can be switched off here (disable + stop) and back on. ")
              + "PipeWire, WirePlumber, the portals and the polkit agent are listed so you can see them, "
              + "and are not switchable — the desktop does not work without them."

        SetRow {
            visible: page.units.length === 0
            title: page.statusError !== "" ? page.statusError : qsTr("Waiting for the inventory…")
        }

        Repeater {
            model: page.units
            delegate: SetRow {
                id: ur
                required property var modelData
                glyph: ur.modelData.kind === "timer" ? "" : ""
                title: ur.modelData.name
                sub: (ur.modelData.purpose ? ur.modelData.purpose + "\n" : "") + page.unitLine(ur.modelData)
                valueText: ur.modelData.switchable ? "" : (ur.modelData.active + " · " + ur.modelData.enabled)

                SetSwitch {
                    visible: ur.modelData.switchable
                    tone: page.tone
                    checked: ur.modelData.active === "active"
                             || ur.modelData.enabled === "enabled"
                    enabled: !switchProc.running
                    onToggled: function (v) { page.setUnit(ur.modelData.name, v); }
                }
            }
        }
    }

    SetCard {
        heading: qsTr("Session processes")
        tone: page.tone
        note: qsTr("What Hyprland starts at login — the shell and its supervisor, the wallpaper engine, the keyring, ")
              + "the portals, the clipboard watchers, the NYXUS daemons. An inactive row is something the session "
              + "is supposed to start and has not; the doctor above says whether that matters."

        Repeater {
            model: page.processes
            delegate: SetRow {
                id: pr
                required property var modelData
                glyph: pr.modelData.active === "active" ? "" : ""
                title: pr.modelData.name
                sub: pr.modelData.purpose
                valueText: pr.modelData.active === "active"
                           ? page.unitLine(pr.modelData)
                           : qsTr("not running")
            }
        }
    }

    SetCard {
        heading: qsTr("Report")
        tone: page.tone
        note: qsTr("The bundle holds the checks, `nyxus status`, the journal tail for the nyxus units and this boot, ")
              + "a hardware summary, the build stamp, and settings.json with anything that looks like a secret "
              + "replaced by [stripped]. The path is copied to the clipboard through wl-copy."

        SetRow {
            glyph: ""
            title: qsTr("Copy report")
            sub: page.reportPath !== ""
                 ? "Written: " + page.reportPath + " — path is on the clipboard"
                 : "Writes ~/Downloads/nyxus-report-<date>.tar.gz and copies its path"

            SetButton {
                text: qsTr("Copy report")
                glyph: ""
                tone: page.tone
                busy: page.reportBusy
                busyText: qsTr("Writing…")
                onClicked: reportProc.running = true
            }
        }

        SetRow {
            glyph: ""
            title: qsTr("In a terminal")
            sub: qsTr("`nyxus doctor` (full, with the update check) · `nyxus status` · `nyxus status --off <unit>`")
        }
    }
}
