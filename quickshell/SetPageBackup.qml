pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ Accounts ▸ Backup & rollback.
// snapper list in this window. Take a snapshot through polkit. No terminal.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    property var entry: null
    title: qsTr("Backup & rollback")
    blurb: qsTr("Snapshots on this disk, and the backup that lives off it.")

    property var snaps: []
    property bool readable: false
    property string lastNote: ""      // the last ACTION's result — never the list's
    property string listNote: ""      // why the list is empty or missing
    property bool refused: false      // snapper answered "No permissions."

    function reload() { listProc.running = true; }
    Component.onCompleted: { page.reload(); bkProbe.running = true; }

    // ── TRK-3745 · one parser, two callers ──────────────────────────────
    // The bare list below and the elevated one further down produce exactly
    // the same text, so they must not read it two different ways.
    //
    // `refusalIn` is the important half. snapper answers a caller who is not
    // in the config's ALLOW_USERS with the words "No permissions." — and the
    // 2026-09-08 audit recorded it doing so while EXITING 0. It exits 1 when
    // measured here, so the exit code alone may or may not be a lie
    // depending on version and dbus path; either way a caller that trusts it
    // reads a refusal as an empty list, and "you have no restore points" is
    // the most dangerous sentence this page could get wrong. So the text is
    // checked as well as the status, and a refusal is a refusal from either.
    function refusalIn(t) {
        var s = String(t);
        return s.indexOf("No permissions") >= 0 || s.indexOf("no permissions") >= 0;
    }

    // ── audit-0908 · TRK-3963 · CLI text is not UI copy ─────────────────
    //
    // Seven places on this page assigned `String(v.error)` straight into the
    // note under a control. `nyxus-backup`'s messages are written for a
    // terminal and are correct there — the restore preview showed
    //
    //     no reachable target (plug the drive in, or pass --from DIR)
    //
    // to somebody who has no terminal open and no way to pass a flag,
    // elided mid-sentence because the row is not that wide
    // (docs/proof/audit-0908/shots/28-backup.png).
    //
    // The fix is NOT to hide the tool's output — an error nobody can see is
    // worse than an ugly one. It is to answer the question the person on this
    // page is actually asking ("what do I do now?") for the causes we know,
    // and to be plain about the provenance of the rest. An unrecognised
    // message is still shown, prefixed so it reads as a report FROM the tool
    // rather than as an instruction from this page, with any "(pass --x …)"
    // aside removed — that aside is advice for a caller who has a command
    // line, and this page is the reason they do not.
    //
    // Matched on substrings rather than exact text on purpose: these strings
    // carry drive names and paths, and a table of exact sentences would be a
    // second copy of the helper's wording to keep in step.
    function bkSay(raw) {
        var s = String(raw || "").trim();
        if (s === "")
            return "";
        if (s.indexOf("no reachable target") >= 0)
            return qsTr("No backup destination is reachable — plug in the drive you set up, or add one below.");
        if (s.indexOf("is plugged in") >= 0 && s.indexOf("no drive labelled") >= 0)
            return qsTr("The drive this destination points at is not plugged in.");
        if (s.indexOf("not mounted") >= 0)
            return qsTr("The drive is plugged in but not mounted, so nothing can be written to it.");
        if (s.indexOf("is not a NyxusBackup folder") >= 0)
            return qsTr("That folder holds no NYXUS backup — there is no NyxusBackup directory inside it.");
        if (s.indexOf("holds no backups") >= 0)
            return qsTr("That destination has no backups on it yet.");
        if (s.indexOf("is not a folder that exists right now") >= 0)
            return qsTr("That destination folder does not exist right now.");
        if (s.indexOf("same filesystem as your home") >= 0)
            return qsTr("That destination is on the same disk as your home folder, so it would not survive that disk failing. Pick somewhere else.");
        if (s.indexOf("snapshot") >= 0 && s.indexOf("no ") === 0)
            return qsTr("There is no snapshot on that destination to restore from.");
        if (s.indexOf("rsync is not installed") >= 0)
            return qsTr("The copying tool (rsync) is not installed, so backups cannot run on this machine.");
        if (s.indexOf("rsync exit") >= 0)
            return qsTr("The copy stopped part-way. The backup tool reported: %1")
                       .arg(s.replace(/^rsync exit [0-9]+:\s*/, ""));
        // Unknown. Say where it came from, and drop the terminal advice.
        return qsTr("The backup tool reported: %1")
                   .arg(s.replace(/\s*\((?:[^()]*--[^()]*)\)\s*/g, " ").trim());
    }

    function parseList(text) {
        var out = [];
        var lines = String(text).split("\n");
        for (var i = 0; i < lines.length; ++i) {
            var l = lines[i].trim();
            if (l === "" || l.indexOf("current") >= 0) continue;
            out.push({ line: l });
        }
        return out;
    }

    Process {
        id: listProc
        running: false
        command: ["snapper", "--no-headers", "-c", "root", "list", "--columns", "number,date,description"]
        property string outText: ""
        property string errText: ""
        onRunningChanged: if (running) { outText = ""; errText = ""; }
        stdout: StdioCollector {
            onStreamFinished: { listProc.outText = String(this.text); }
        }
        stderr: StdioCollector {
            onStreamFinished: { listProc.errText = String(this.text); }
        }
        onExited: function (code) {
            var refused = page.refusalIn(listProc.outText)
                          || page.refusalIn(listProc.errText);
            page.refused = refused;
            page.readable = code === 0 && !refused;
            page.snaps = page.readable ? page.parseList(listProc.outText) : [];
            if (page.readable)
                page.listNote = "";
            else if (refused)
                // Name the actual cause. This is not "snapper is broken" and
                // it is not "you have no snapshots": snapper ships
                // ALLOW_USERS empty, so it refuses to list for anyone but
                // root. Installs made after TRK-3745 set it during
                // postinstall; this machine predates that.
                page.listNote = qsTr("snapper will not list snapshots for this account — its root config allows nobody but the administrator to read it. The button below asks for a password and shows them anyway.");
            else
                page.listNote = qsTr("Snapshots could not be listed (snapper missing, or this machine's root is not btrfs).");
        }
    }

    // The way out that does not need a terminal and does not need the config
    // changed: ask once, with a password, on purpose. Not run automatically —
    // a page that raises a polkit prompt just by being opened trains people
    // to click through them.
    Process {
        id: elevListProc
        running: false
        command: ["pkexec", "snapper", "--no-headers", "-c", "root", "list",
                  "--columns", "number,date,description"]
        property string outText: ""
        onRunningChanged: if (running) outText = "";
        stdout: StdioCollector {
            onStreamFinished: { elevListProc.outText = String(this.text); }
        }
        onExited: function (code) {
            if (code === 0 && !page.refusalIn(elevListProc.outText)) {
                page.snaps = page.parseList(elevListProc.outText);
                page.readable = true;
                page.listNote = "";
            } else {
                page.lastNote = qsTr("Could not read the snapshot list even with a password.");
            }
        }
    }

    Process {
        id: takeProc
        running: false
        command: ["pkexec", "snapper", "-c", "root", "create", "--description", "Settings"]
        onExited: function (code) {
            page.lastNote = code === 0 ? "Snapshot taken." : "Could not take a snapshot.";
            page.reload();
        }
    }

    SetCard {
        heading: qsTr("Restore points")
        tone: page.tone
        note: qsTr("Updates take a snapshot first. On-disk rollback of a running system is not this button. Restore of the off-disk copy is the Restore card.")

        // TRK-3745: `detail` used to read `page.lastNote`, which is also what
        // the NOTE row at the bottom of this card shows — so a failed listing
        // printed the same sentence twice, once here and once again below.
        // The list's own explanation lives in `listNote` now; `lastNote` is
        // only ever the result of something the person just pressed.
        SetIceFace {
            visible: !page.readable
            compact: true
            kicker: qsTr("SNAPSHOTS")
            caption: page.refused
                     ? qsTr("Snapshots are on this disk, but not readable from here")
                     : qsTr("Snapshots could not be listed")
            detail: page.listNote
        }

        RowLayout {
            visible: page.refused
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4

            SetButton {
                text: qsTr("Show restore points")
                tone: page.tone
                busy: elevListProc.running
                enabled: !elevListProc.running
                onClicked: elevListProc.running = true
            }
        }

        SetIceFace {
            visible: page.readable && page.snaps.length === 0
            compact: true
            kicker: qsTr("SNAPSHOTS")
            caption: qsTr("No snapshots yet")
        }

        Repeater {
            model: page.snaps
            delegate: SetIceFace {
                required property var modelData
                compact: true
                kicker: qsTr("SNAPSHOT")
                caption: modelData.line
            }
        }

        SetIceFace {
            compact: true
            kicker: qsTr("TAKE ONE")
            caption: qsTr("Take a snapshot now")
            detail: qsTr("Polkit will ask. Nothing opens a terminal.")
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4

            SetButton {
                text: qsTr("Snapshot")
                tone: page.tone
                busy: takeProc.running
                enabled: !takeProc.running
                onClicked: takeProc.running = true
            }
        }

        SetIceFace {
            visible: page.lastNote !== ""
            compact: true
            kicker: qsTr("NOTE")
            caption: page.lastNote
        }
    }

    // ══ TRK-1353 / TRK-1601 · the OFF-DISK half ═══════════════════════════
    //
    // Snapper (above) keeps snapshots ON this disk; they die with the drive.
    // `nyxus-backup` writes to a place that is NOT this disk and reads it back
    // on any machine. Everything below is that CLI and nothing else — every
    // control here runs a verb and every reading is parsed out of that verb's
    // own `--json`. Nothing on this page records a preference that nothing
    // reads (the `Prefs.launcherStyle` defect); the schedule switch is
    // `schedule on|off` against the real user timer and its readback is
    // `systemctl --user is-enabled`, quoted through `status --json`.
    //
    // Arguments are passed as argv, never through `sh -c`: a destination path
    // is text a person typed, and a shell would be an injection.

    property bool bkPresent: false
    property bool bkProbed: false
    property var bkTargets: []
    property bool bkScheduled: false
    property string bkNext: ""
    property string bkNote: ""
    property var bkSets: ({})
    property var bkSetNames: []
    property string bkListNote: ""

    // the add-a-destination form
    property string bkNewName: ""
    property string bkNewWhere: ""
    property bool bkNewIsLabel: true

    // the restore flow: nothing is written until a dry run has been read
    property string bkRestoreSet: ""
    property var bkPreview: []
    property bool bkPreviewed: false
    property string bkPreviewLine: ""

    function bkReload() {
        if (!bkStatusProc.running)
            bkStatusProc.running = true;
    }

    function bkReloadList() {
        if (!bkListProc.running)
            bkListProc.running = true;
    }

    // ── TRK-3435 · SHIPPED-FIRST RESOLUTION, the whole batch ─────────────
    // Every `nyxus-*` shell-out on this page (and its nine sibling pages)
    // used to exec by BARE NAME through qs's PATH, which starts with
    // `~/.local/bin` — the TRK-3367 trap: a stale preview copy, or a
    // different product wearing the same name (`nyxus-settings` IS the old
    // Panel there), silently wins over the shipped tool. The rule now:
    // the PATH is COMPOSED IN QML and applied through `env`, so an argv
    // command stays argv end to end —
    //
    //     ["env", page.execPath, "nyxus-backup", …]
    //
    // never `sh -c` (13z11: a destination path is text a person typed, and
    // this page's own header rules a shell out for it). Installed system:
    // `/usr/local/bin` (where every one of these tools ships) wins over any
    // shadow. Dev checkout that WANTS its own copy: set NYXUS_BIN_DIR — the
    // same override-wins/shipped-default shape TRK-3394 gave the app modules
    // with NYXUS_APP_DIR. Machine where the preferred dir lacks the tool
    // (this dev box has no /usr/local/bin nyxus-* at all): the entry
    // contributes nothing and resolution falls through to the ordinary
    // PATH, byte-for-byte the old behaviour. Probe/dispatcher SCRIPTS that
    // carry no person-typed text keep the same rule as an in-script
    // PATH=… line instead.
    readonly property string execPath: "PATH="
        + (Quickshell.env("NYXUS_BIN_DIR") || "/usr/local/bin")
        + ":" + Quickshell.env("PATH")

    Process {
        id: bkProbe
        running: false
        command: ["sh", "-c",
            'PATH="${NYXUS_BIN_DIR:-/usr/local/bin}:$PATH"; '
          + 'command -v nyxus-backup >/dev/null 2>&1 && echo yes || echo no']
        stdout: StdioCollector {
            onStreamFinished: {
                page.bkProbed = true;
                page.bkPresent = String(this.text).trim() === "yes";
                if (page.bkPresent) {
                    page.bkReload();
                    page.bkReloadList();
                }
            }
        }
    }

    // ── status: targets, last run, schedule ──────────────────────────────
    Process {
        id: bkStatusProc
        running: false
        command: ["env", page.execPath, "nyxus-backup", "status", "--json"]   // TRK-3435
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = String(this.text).trim();
                if (raw === "")
                    return;
                var v = null;
                try {
                    v = JSON.parse(raw);
                } catch (e) {
                    page.bkNote = qsTr("Backup status could not be read.");
                    return;
                }
                page.bkTargets = v.targets || [];
                page.bkScheduled = !!(v.schedule && v.schedule.enabled);
                page.bkNext = String((v.schedule && v.schedule.next) || "");
            }
        }
    }

    // ── list: what is already on the destination ─────────────────────────
    Process {
        id: bkListProc
        running: false
        command: ["env", page.execPath, "nyxus-backup", "list", "--json"]   // TRK-3435
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = String(this.text).trim();
                if (raw === "") {
                    page.bkSets = ({});
                    page.bkSetNames = [];
                    return;
                }
                var v = null;
                try {
                    v = JSON.parse(raw);
                } catch (e) {
                    page.bkListNote = qsTr("The destination's contents could not be read.");
                    return;
                }
                if (v.error) {
                    page.bkListNote = page.bkSay(v.error);
                    page.bkSets = ({});
                    page.bkSetNames = [];
                    return;
                }
                page.bkListNote = "";
                page.bkSets = v.sets || ({});
                var names = [];
                for (var k in page.bkSets)
                    names.push(k);
                page.bkSetNames = names;
                // Restore is the product act: pick the first set that
                // actually has a snapshot so Preview/Restore are live
                // without an extra tap.
                if (page.bkRestoreSet === "") {
                    for (var i = 0; i < names.length; ++i) {
                        var snaps = (page.bkSets[names[i]] || {}).snapshots || [];
                        if (snaps.length > 0) {
                            page.bkRestoreSet = names[i];
                            break;
                        }
                    }
                }
            }
        }
    }

    // ── target add / remove ──────────────────────────────────────────────
    Process {
        id: bkAddProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var v = null;
                try {
                    v = JSON.parse(String(this.text).trim());
                } catch (e) {
                    page.bkNote = qsTr("The destination could not be added.");
                    return;
                }
                if (v.error) {
                    page.bkNote = page.bkSay(v.error);
                    return;
                }
                var t = v.target || {};
                page.bkNote = t.reachable
                    ? qsTr("Added %1 — reachable now (%2, %3 mode).")
                          .arg(String(v.added)).arg(String(t.fstype)).arg(String(t.mode))
                    : qsTr("Added %1 — not reachable right now: %2")
                          .arg(String(v.added)).arg(String(t.why || ""));
                page.bkNewName = "";
                page.bkNewWhere = "";
                page.bkReload();
                page.bkReloadList();
            }
        }
    }

    function bkAddTarget() {
        if (bkAddProc.running)
            return;
        var name = String(page.bkNewName).trim();
        var where = String(page.bkNewWhere).trim();
        if (name === "" || where === "") {
            page.bkNote = qsTr("Give the destination a name and a place.");
            return;
        }
        bkAddProc.command = ["env", page.execPath,   // TRK-3435 — argv, no shell
                             "nyxus-backup", "target", "add", name,
                             page.bkNewIsLabel ? "--label" : "--path", where,
                             "--json"];
        bkAddProc.running = true;
    }

    Process {
        id: bkRemoveProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var v = null;
                try {
                    v = JSON.parse(String(this.text).trim());
                } catch (e) {
                    page.bkNote = qsTr("The destination could not be removed.");
                    return;
                }
                page.bkNote = v.error
                    ? page.bkSay(v.error)
                    : qsTr("Removed %1. The files already on it are untouched.").arg(String(v.removed));
                page.bkReload();
                page.bkReloadList();
            }
        }
    }

    function bkRemoveTarget(name) {
        if (bkRemoveProc.running)
            return;
        bkRemoveProc.command = ["env", page.execPath,   // TRK-3435
                                "nyxus-backup", "target", "remove", String(name), "--json"];
        bkRemoveProc.running = true;
    }

    // ── run ──────────────────────────────────────────────────────────────
    property bool bkRunDry: false

    Process {
        id: bkRunProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var v = null;
                try {
                    v = JSON.parse(String(this.text).trim());
                } catch (e) {
                    page.bkNote = qsTr("The backup produced no readable report.");
                    return;
                }
                if (v.error) {
                    page.bkNote = page.bkSay(v.error);
                    return;
                }
                var files = 0;
                var ran = v.ran || [];
                for (var i = 0; i < ran.length; ++i)
                    files += (ran[i].stats && ran[i].stats.files_transferred) || 0;
                if (ran.length === 0) {
                    var sk = v.skipped || [];
                    page.bkNote = sk.length > 0
                        ? qsTr("Nothing ran — %1: %2").arg(String(sk[0].target)).arg(String(sk[0].why))
                        : qsTr("Nothing ran — no destination was reachable.");
                } else if (v.dry_run) {
                    page.bkNote = qsTr("Dry run: %1 file(s) would be copied. Nothing was written.").arg(files);
                } else {
                    page.bkNote = v.ok
                        ? qsTr("Backup finished: %1 file(s) copied.").arg(files)
                        : qsTr("Backup had a problem — see ~/.cache/nyxus/backup.log.");
                }
                page.bkReload();
                page.bkReloadList();
            }
        }
    }

    function bkRun(dry) {
        if (bkRunProc.running)
            return;
        page.bkRunDry = dry === true;
        var cmd = ["env", page.execPath, "nyxus-backup", "run", "--json"];   // TRK-3435
        if (page.bkRunDry)
            cmd.push("--dry-run");
        bkRunProc.command = cmd;
        page.bkNote = page.bkRunDry ? qsTr("Working out what would copy…")
                                    : qsTr("Copying…");
        bkRunProc.running = true;
    }

    // ── schedule ─────────────────────────────────────────────────────────
    Process {
        id: bkSchedProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var v = null;
                try {
                    v = JSON.parse(String(this.text).trim());
                } catch (e) {
                    page.bkNote = qsTr("The schedule could not be changed.");
                    page.bkReload();
                    return;
                }
                // Readback is the unit's own state, not the click.
                page.bkScheduled = !!v.enabled;
                page.bkNext = String(v.next || "");
                if (!v.ok && v.error)
                    page.bkNote = page.bkSay(v.error);
                else
                    page.bkNote = v.enabled ? qsTr("Daily backup is on.")
                                            : qsTr("Daily backup is off.");
                page.bkReload();
            }
        }
    }

    function bkSchedule(on) {
        if (bkSchedProc.running)
            return;
        bkSchedProc.command = ["env", page.execPath,   // TRK-3435
                               "nyxus-backup", "schedule", on ? "on" : "off", "--json"];
        bkSchedProc.running = true;
    }

    // ── restore, dry run first ───────────────────────────────────────────
    Process {
        id: bkRestoreProc
        running: false
        property bool dry: true
        stdout: StdioCollector {
            onStreamFinished: {
                var v = null;
                try {
                    v = JSON.parse(String(this.text).trim());
                } catch (e) {
                    page.bkNote = qsTr("The restore produced no readable report.");
                    return;
                }
                if (v.error) {
                    page.bkNote = page.bkSay(v.error);
                    page.bkPreviewed = false;
                    return;
                }
                var files = (v.stats && v.stats.files_transferred) || 0;
                if (bkRestoreProc.dry) {
                    var lines = v.would_change || [];
                    if (v.packages !== undefined) {
                        lines = (v.missing || []).map(function (p) { return p; });
                        page.bkPreviewLine =
                            qsTr("%1 package(s) in the manifest, %2 not installed here.")
                                .arg(v.packages).arg((v.missing || []).length);
                    } else {
                        page.bkPreviewLine =
                            qsTr("Would restore %1 file(s) from snapshot %2 into %3.")
                                .arg(files).arg(String(v.snapshot)).arg(String(v.to || ""));
                    }
                    page.bkPreview = lines.slice(0, 24);
                    page.bkPreviewed = true;
                } else {
                    page.bkPreviewed = false;
                    page.bkPreview = [];
                    page.bkNote = v.ok
                        ? qsTr("Restored %1 from snapshot %2. Log out and back in so the desktop re-reads its settings.")
                              .arg(String(v.what)).arg(String(v.snapshot))
                        : qsTr("Restore failed: %1").arg(String(v.error || ""));
                }
            }
        }
    }

    function bkRestore(setName, dry) {
        if (bkRestoreProc.running)
            return;
        page.bkRestoreSet = String(setName);
        bkRestoreProc.dry = dry === true;
        var cmd = ["env", page.execPath,   // TRK-3435
                   "nyxus-backup", "restore", String(setName), "--json"];
        if (bkRestoreProc.dry)
            cmd.push("--dry-run");
        bkRestoreProc.command = cmd;
        page.bkNote = bkRestoreProc.dry
            ? qsTr("Working out what would change…")
            : qsTr("Bringing files back…");
        bkRestoreProc.running = true;
    }

    // ── the faces ────────────────────────────────────────────────────────

    SetCard {
        heading: qsTr("Off this disk")
        tone: page.tone
        visible: page.bkProbed && !page.bkPresent
        note: qsTr("Snapshots above live on this drive and die with it. The off-disk backup is a separate tool.")

        SetIceFace {
            compact: true
            kicker: qsTr("NOT INSTALLED")
            caption: qsTr("nyxus-backup is not on this system")
            detail: qsTr("Nothing on this half of the page can run without it.")
        }
    }

    SetCard {
        heading: qsTr("Where backups go")
        tone: page.tone
        visible: page.bkPresent
        note: qsTr("A second drive, a network folder, or a USB stick named by its filesystem label. A stick can be read back on any machine, including a fresh install.")

        SetIceFace {
            visible: page.bkTargets.length === 0
            compact: true
            kicker: qsTr("NO DESTINATION")
            caption: qsTr("Nothing is backed up off this disk yet")
            detail: qsTr("Add a place below.")
        }

        Repeater {
            model: page.bkTargets
            delegate: SetIceFace {
                required property var modelData
                compact: true
                kicker: modelData.reachable ? qsTr("REACHABLE") : qsTr("NOT HERE")
                caption: String(modelData.name) + " — "
                       + (modelData.label ? qsTr("label %1").arg(String(modelData.label))
                                          : String(modelData.path || ""))
                detail: modelData.reachable
                        ? qsTr("%1 · %2 mode").arg(String(modelData.fstype)).arg(String(modelData.mode))
                        : String(modelData.why || "")
                selected: modelData.reachable === true
            }
        }

        Repeater {
            model: page.bkTargets
            delegate: RowLayout {
                id: forgetRow
                required property var modelData
                Layout.fillWidth: true
                Layout.leftMargin: Theme.s4
                Layout.rightMargin: Theme.s4

                SetButton {
                    text: qsTr("Forget %1").arg(String(forgetRow.modelData.name))
                    tone: page.tone
                    danger: true
                    confirmText: qsTr("Click again — the files on it stay")
                    busy: bkRemoveProc.running
                    enabled: !bkRemoveProc.running
                    onClicked: page.bkRemoveTarget(forgetRow.modelData.name)
                }
            }
        }

        SetIceFace {
            compact: true
            kicker: qsTr("ADD A PLACE")
            caption: page.bkNewIsLabel ? qsTr("A USB stick, by its label")
                                       : qsTr("A folder that is already mounted")
            detail: qsTr("Tap to switch between a stick label and a folder path.")
            interactive: true
            onActivated: page.bkNewIsLabel = !page.bkNewIsLabel
        }

        TextInput {
            id: bkNameField
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            Layout.preferredHeight: 28
            color: Theme.text
            font.family: Theme.fUi
            font.pixelSize: Theme.tLabel
            text: page.bkNewName
            onTextChanged: page.bkNewName = text
        }

        SetIceFace {
            compact: true
            kicker: qsTr("NAME")
            caption: page.bkNewName === "" ? qsTr("A short name for this place") : page.bkNewName
        }

        TextInput {
            id: bkWhereField
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            Layout.preferredHeight: 28
            color: Theme.text
            font.family: Theme.fUi
            font.pixelSize: Theme.tLabel
            text: page.bkNewWhere
            onTextChanged: page.bkNewWhere = text
        }

        SetIceFace {
            compact: true
            kicker: page.bkNewIsLabel ? qsTr("LABEL") : qsTr("PATH")
            caption: page.bkNewWhere === ""
                     ? (page.bkNewIsLabel ? qsTr("The stick's filesystem label")
                                          : qsTr("/run/media/you/Backup"))
                     : page.bkNewWhere
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4

            SetButton {
                text: qsTr("Add destination")
                tone: page.tone
                busy: bkAddProc.running
                enabled: !bkAddProc.running
                       && page.bkNewName !== "" && page.bkNewWhere !== ""
                onClicked: page.bkAddTarget()
            }
        }
    }

    SetCard {
        heading: qsTr("Restore")
        tone: page.tone
        visible: page.bkPresent
        note: qsTr("The product act. Preview is rsync's own dry run; Restore writes only after that preview and a second tap. A registered USB stick toasts through nyxus-backup offer — the same tool, not a second copy.")

        SetIceFace {
            visible: page.bkListNote !== ""
            compact: true
            kicker: qsTr("DESTINATION")
            caption: page.bkListNote
        }

        Repeater {
            model: page.bkSetNames
            delegate: SetIceFace {
                required property string modelData
                compact: true
                kicker: qsTr("SET")
                reading: String(((page.bkSets[modelData] || {}).snapshots || []).length)
                caption: modelData
                detail: (page.bkSets[modelData] || {}).latest
                        ? qsTr("newest: %1").arg(String(page.bkSets[modelData].latest))
                        : qsTr("nothing backed up yet")
                selected: page.bkRestoreSet === modelData
                interactive: ((page.bkSets[modelData] || {}).snapshots || []).length > 0
                onActivated: {
                    page.bkRestoreSet = modelData;
                    page.bkPreviewed = false;
                    page.bkPreview = [];
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            spacing: Theme.s4
            visible: page.bkRestoreSet !== ""

            SetButton {
                text: qsTr("Preview restore")
                tone: page.tone
                busy: bkRestoreProc.running && bkRestoreProc.dry
                enabled: !bkRestoreProc.running
                onClicked: page.bkRestore(page.bkRestoreSet, true)
            }

            SetButton {
                text: qsTr("Restore %1").arg(page.bkRestoreSet)
                tone: page.tone
                danger: true
                confirmText: qsTr("Restore now — writes these files back")
                busy: bkRestoreProc.running && !bkRestoreProc.dry
                // The dry run is not advice, it is the gate: nothing is
                // written until this window has shown what would change.
                enabled: !bkRestoreProc.running && page.bkPreviewed
                onClicked: page.bkRestore(page.bkRestoreSet, false)
            }
        }

        SetIceFace {
            visible: page.bkPreviewed
            compact: true
            kicker: qsTr("WOULD CHANGE")
            caption: page.bkPreviewLine
            detail: page.bkPreview.length === 0
                    ? qsTr("Nothing would change — this machine already matches the snapshot.")
                    : ""
        }

        Repeater {
            model: page.bkPreview
            delegate: SetIceFace {
                required property string modelData
                compact: true
                kicker: qsTr("ITEM")
                caption: modelData
            }
        }

        SetIceFace {
            visible: page.bkNote !== ""
            compact: true
            kicker: qsTr("NOTE")
            caption: page.bkNote
        }
    }

    SetCard {
        heading: qsTr("Back up now")
        tone: page.tone
        visible: page.bkPresent
        // Owner ruling 2026-08-22, "split the console, keep the config":
        // starting a backup is an ACTION and stays; the run history and the
        // last result CHANGE WITHOUT YOU and are Condition's (TRK-1609).
        // `status --json` still feeds this page — for the targets and the
        // schedule, which are configuration — and its `last_run` / `summary`
        // are deliberately not read here.
        note: qsTr("Your files, your desktop settings, and a list of the packages you installed on purpose. A dry run writes nothing. What each run copied is recorded, and is not shown on this page.")

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            spacing: Theme.s4

            SetButton {
                text: qsTr("Dry run")
                tone: page.tone
                busy: bkRunProc.running && page.bkRunDry
                enabled: !bkRunProc.running && page.bkTargets.length > 0
                onClicked: page.bkRun(true)
            }

            SetButton {
                text: qsTr("Back up now")
                tone: page.tone
                busy: bkRunProc.running && !page.bkRunDry
                enabled: !bkRunProc.running && page.bkTargets.length > 0
                onClicked: page.bkRun(false)
            }
        }

        SetIceFace {
            compact: true
            kicker: page.bkScheduled ? qsTr("DAILY: ON") : qsTr("DAILY: OFF")
            caption: qsTr("Back up once a day when a destination is plugged in")
            detail: page.bkScheduled && page.bkNext !== "" && page.bkNext !== "n/a"
                    ? qsTr("Next: %1").arg(page.bkNext)
                    : qsTr("A day the stick is in a drawer is an ordinary day, not a failure.")
            selected: page.bkScheduled
            interactive: true
            onActivated: page.bkSchedule(!page.bkScheduled)
        }

        SetIceFace {
            visible: page.bkNote !== ""
            compact: true
            kicker: qsTr("NOTE")
            caption: page.bkNote
        }
    }
}
