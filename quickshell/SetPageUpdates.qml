pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ System ▸ Updates.   MODULE 6.
//
// ── the no-terminal rule, which this page is the hardest case for ───────
// `audit.sh` items 14 and 15 ban an app from spawning a terminal, and this
// build has already been caught doing exactly that twice — `nyxus_updater.py`
// and `nyxus_store.py` both walked a list of emulators and ran pacman inside
// one (`WIP-255`). An update has output you must be able to read, which is why
// it is the control that tempts every desktop into opening a terminal.
//
// So the output comes **into this window**: `pacman` is run with its stdout and
// stderr streamed line by line into the log below, live, with the button
// disabled while it runs. No emulator, no `-e sh -c`, and stdin is closed so a
// backend that unexpectedly prompts fails fast rather than hanging behind a
// window that cannot answer it.
//
// ── the backend ─────────────────────────────────────────────────────────
//   `checkupdates`        what is waiting — reads a private sync DB, so it
//                         never touches the real one and never needs root
//   `pkexec pacman -Syu`  the install, elevated through polkit
//   `fwupdmgr`            firmware
//   `snapper`             a snapshot taken BEFORE the update
//   Quickshell.reload()   the shell, live
//   `hyprctl reload`      the compositor's config, live
//
// **`checkupdates`, never `pacman -Sy`.** A bare `-Sy` leaves the system in a
// partially-synced state that is the documented way to break an Arch install.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    property var entry: null

    title: qsTr("Updates")
    blurb: qsTr("What's waiting, installing it, and reloading the desktop.")

    property var pending: []
    property bool checked: false
    property string checkNote: ""
    property var firmware: []

    ListModel { id: log }
    property int logCap: 400

    readonly property bool autoCheck: SettingsStore.boolValue("updates_autocheck", true)
    // TRK-3419: `updates_interval` deleted — nothing ever wrote it, nothing
    // in this file used it, and the "How often" row is deliberately the
    // honest hard-coded "6 hours" the timer actually runs at.
    readonly property bool snapBefore: SettingsStore.boolValue("updates_snapshot", true)

    function say(line) {
        if (String(line).trim() === "")
            return;
        log.append({ line: String(line) });
        while (log.count > page.logCap)
            log.remove(0);
    }

    Component.onCompleted: {
        page.syncAutoCheckFile(page.autoCheck);
        page.check();
    }

    function syncAutoCheckFile(on) {
        SettingsStore.setValue("updates_autocheck", on);
        autoGate.command = ["sh", "-c",
            'd="$HOME/.config/nyxus"; mkdir -p "$d"; '
          + 'if [ "$1" = "on" ]; then rm -f "$d/update-check.disabled"; '
          + 'else : > "$d/update-check.disabled"; fi',
            "sh", on ? "on" : "off"];
        autoGate.running = true;
    }

    Process {
        id: autoGate
        running: false
        onExited: function (code) { if (code !== 0) console.warn("[Updates] auto-check toggle exited code " + code); }
    }

    function check() { if (!checker.running) { page.checked = false; checker.running = true; } }

    Process {
        id: checker
        running: false
        // ONE updater (TRK-1282): `nyxus-update --check` prints checkupdates
        // lines ("name old -> new") and exits 10 when something is waiting, 2
        // when checkupdates is missing. The in-line fallback survives for a
        // checkout where the CLI is not on PATH.
        command: ["sh", "-c",
            'PATH="${NYXUS_BIN_DIR:-/usr/local/bin}:$PATH"; '   // TRK-3435
          + 'if command -v nyxus-update >/dev/null 2>&1; then '
          + '  nyxus-update --check 2>/dev/null; ec=$?; '
          + '  [ "$ec" = "2" ] && echo "__NOCHECK__"; '
          + '  exit 0; '
          + 'elif command -v checkupdates >/dev/null 2>&1; then '
          + '  checkupdates 2>/dev/null; ec=$?; '
          + '  [ "$ec" = "2" ] && exit 0; '
          + '  exit 0; '
          + 'else echo "__NOCHECK__"; fi']

        onExited: function (code) { if (code !== 0) console.warn("[Updates] update check exited code " + code); }

        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                var lines = String(this.text).split("\n");
                for (var i = 0; i < lines.length; ++i) {
                    var l = lines[i].trim();
                    if (l === "")
                        continue;
                    if (l === "__NOCHECK__") {
                        page.checkNote = "Update information is unavailable right now. "
                                       + "Nothing has been checked, and your package "
                                       + "database has not been touched.";
                        page.pending = [];
                        page.checked = true;
                        return;
                    }
                    var m = /^(\S+)\s+(\S+)\s+->\s+(\S+)$/.exec(l);
                    if (m)
                        out.push({ name: m[1], from: m[2], to: m[3] });
                    else
                        out.push({ name: l, from: "", to: "" });
                }
                page.checkNote = "";
                page.pending = out;
                page.checked = true;
            }
        }
    }

    property bool updating: false

    Process {
        id: updater
        running: false
        stdinEnabled: false

        onExited: function (code) { if (code !== 0) console.warn("[Updates] updater exited code " + code); }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (l) { page.say(l); }
        }
        stderr: SplitParser {
            splitMarker: "\n"
            onRead: function (l) { page.say(l); }
        }

        onRunningChanged: {
            if (updater.running) {
                page.updating = true;
                return;
            }
            page.updating = false;
            page.say("— finished —");
            page.check();
        }
    }

    function runUpdate() {
        if (updater.running)
            return;
        log.clear();
        page.say(page.snapBefore
                 ? "Taking a snapshot first, then updating."
                 : "Updating without a snapshot.");
        // ONE updater (TRK-1282): snapshot → pkexec pacman -Syu → self-check
        // all live in nyxus-update; this page streams its output. The inline
        // sequence below is the fallback for a checkout without the CLI.
        updater.command = ["sh", "-c", `
            snap="$1"
            PATH="\${NYXUS_BIN_DIR:-/usr/local/bin}:$PATH"   # TRK-3435
            if command -v nyxus-update >/dev/null 2>&1; then
              if [ "$snap" = "0" ]; then
                exec nyxus-update --yes --no-snapshot 2>&1
              fi
              exec nyxus-update --yes 2>&1
            fi
            if [ "$snap" != "0" ] && command -v snapper >/dev/null 2>&1; then
              echo "Snapshot: taking one before the update…"
              snapper -c root create -d "before update (NYXUS Settings)" 2>&1 \\
                || echo "Snapshot: not taken (snapper is installed but no root config)"
            elif [ "$snap" = "0" ]; then
              echo "Snapshot: skipped (Settings ▸ Snapshot first is off)"
            else
              echo "Snapshot: snapper is not installed — updating without one"
            fi
            echo "Updating packages…"
            if command -v pkexec >/dev/null 2>&1; then
              pkexec pacman -Syu --noconfirm 2>&1
            else
              echo "pkexec is not available, so this cannot be elevated." >&2
              exit 1
            fi
        `, "sh", page.snapBefore ? "1" : "0"];
        updater.running = true;
    }

    Process {
        id: fw
        running: false
        command: ["sh", "-c",
            'command -v fwupdmgr >/dev/null 2>&1 || exit 0; '
          + 'fwupdmgr get-updates 2>/dev/null | sed -n "s/^ *• //p"']
        onExited: function (code) { if (code !== 0) console.warn("[Updates] firmware check exited code " + code); }
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                var lines = String(this.text).split("\n");
                for (var i = 0; i < lines.length; ++i)
                    if (lines[i].trim() !== "")
                        out.push(lines[i].trim());
                page.firmware = out;
            }
        }
    }

    SetCard {
        heading: qsTr("Available updates")
        tone: page.tone
        note: page.checkNote !== ""
              ? page.checkNote
              : (page.checked && page.pending.length > 0
                 ? "A snapshot is taken automatically before anything is installed"
                 : "Checked against the mirrors without touching your package database")

        SetRow {
            title: qsTr("Updates")
            sub: !page.checked ? qsTr("Looking at the mirrors")
                 : (page.pending.length === 0 ? qsTr("Everything is up to date")
                    : (page.pending.length === 1
                       ? qsTr("1 package can be updated")
                       : qsTr("%1 packages can be updated").arg(page.pending.length)))
            valueText: !page.checked ? "…"
                     : (page.pending.length === 0 ? "0" : String(page.pending.length))
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            spacing: Theme.s4

            SetButton {
                text: qsTr("Check again")
                glyph: ""
                tone: page.tone
                busy: checker.running
                enabled: !page.updating
                onClicked: { page.check(); fw.running = true; }
            }

            SetButton {
                text: qsTr("Install updates")
                glyph: ""
                tone: page.tone
                danger: true
                confirmText: qsTr("Install now — snapshot, then packages")
                enabled: page.pending.length > 0 && !page.updating
                busy: page.updating
                onClicked: page.runUpdate()
            }
        }

        Repeater {
            model: page.pending.slice(0, 40)
            delegate: SetRow {
                required property var modelData
                title: modelData.name
                sub: modelData.to !== "" ? modelData.from + " → " + modelData.to : ""
                valueText: modelData.to !== "" ? modelData.to : ""
            }
        }

        SetRow {
            visible: page.pending.length > 40
            title: qsTr("And more")
            sub: qsTr("The full list is in the log below once the update runs")
            valueText: String(page.pending.length - 40)
        }
    }

    // ══ TRK-1602 → TRK-1608 · REMOVED ON THE OWNER'S RULING ═══════════════
    //
    // "Split the console, keep the config" (owner, 2026-08-22, relayed by SUP).
    // The test is not whether a thing is about updates — it is whether the
    // thing CHANGES WITHOUT YOU. The post-update self-check verdict, the list
    // of failed checks and the rollback it offers all change on their own, so
    // they are not settings. This seat BUILT that card here, gated it, and
    // then deleted it on the ruling rather than ship a surface the owner has
    // said belongs somewhere else. It is specified for the Condition surface
    // in TRK-1608, feed and all.
    //
    // What is left is one line and NO control. A pointer with a button that
    // cannot do anything would be the launcher-honesty defect wearing a
    // signpost, and naming a surface that does not exist yet would be worse.
    SetCard {
        heading: qsTr("After an update")
        tone: page.tone
        note: qsTr("This page is the settings for updating. Whether the last update left this machine able to boot is a reading, not a setting.")

        SetRow {
            title: qsTr("Self-check verdict")
            sub: qsTr("Every update takes a snapshot pair and records a verdict afterwards — kernel, initramfs, bootloader, login, shell supervisor.")
        }
    }

    SetCard {
        heading: qsTr("Output")
        tone: page.tone
        visible: log.count > 0
        note: qsTr("This is pacman's own output, live. Nothing is hidden and no ")
              + "terminal is opened."

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 180
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            // TRK-3430: 16 was off the r-ladder. The flat `elevated` ground
            // stays — a live pacman console is an instrument body (the
            // Hardware page's own vocabulary), not chrome that must blend.
            radius: Theme.r2
            color: Theme.elevated
            border.width: 1.2
            border.color: Theme.lookSeam

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                // TRK-2913: 16 written twice as a literal is s6, the rung the
                // rest of this file uses. Same pixels, one vocabulary.
                anchors.leftMargin: Theme.s6
                anchors.rightMargin: Theme.s6
                anchors.topMargin: 1
                height: 1
                color: Theme.soften(Theme.paintLayers.glacier[6], 0.38)
            }

            ListView {
                ScrollRail { flick: logView }
                id: logView
                anchors.fill: parent
                anchors.margins: Theme.s4
                clip: true
                model: log
                boundsBehavior: Flickable.StopAtBounds
                onCountChanged: if (page.updating && !logView.moving) logView.positionViewAtEnd()

                delegate: Text {
                    required property string line
                    width: logView.width
                    text: line
                    color: /error|failed|cannot/i.test(line) ? Theme.danger
                         : /warning/i.test(line) ? Theme.warn
                         : Theme.textMuted
                    font.family: Theme.fNum
                    font.pixelSize: Theme.tCaption
                    wrapMode: Text.NoWrap
                    elide: Text.ElideRight
                }
            }
        }
    }

    SetCard {
        heading: qsTr("Firmware")
        tone: page.tone
        note: qsTr("Firmware updates come from the vendor through fwupd. They install ")
              + "on the next restart, and some of them cannot be undone."

        SetRow {
            title: qsTr("Firmware")
            sub: page.firmware.length === 0
                 ? qsTr("No firmware updates offered")
                 : (page.firmware.length === 1
                    ? qsTr("1 firmware update offered — %1").arg(page.firmware.join(" · "))
                    : qsTr("%1 firmware updates offered — %2").arg(page.firmware.length).arg(page.firmware.join(" · ")))
            valueText: page.firmware.length === 0 ? "0" : String(page.firmware.length)
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4

            SetButton {
                text: qsTr("Check")
                glyph: ""
                tone: page.tone
                busy: fw.running
                onClicked: fw.running = true
            }
        }
    }

    SetCard {
        heading: qsTr("Checking automatically")
        tone: page.tone
        note: qsTr("Checking is safe and quiet. Installing is never automatic — an ")
              + "update that reboots your machine while you are working is not "
              + "a feature. Off writes ~/.config/nyxus/update-check.disabled, "
              + "which the user timer already honours."

        SetRow {
            title: qsTr("Background check")
            sub: qsTr("Check for updates in the background")

            SetSwitch {
                tone: page.tone
                checked: page.autoCheck
                onToggled: function (v) { page.syncAutoCheckFile(v); }
            }
        }

        SetRow {
            title: qsTr("How often")
            sub: qsTr("The user timer is every 6 hours. Hourly / daily / weekly stones are not wired to that timer.")
            valueText: qsTr("6 hours")
        }

        SetRow {
            title: qsTr("Snapshot first")
            sub: qsTr("So the whole update can be rolled back from Backup (Condition, not Accounts)")

            SetSwitch { key: "updates_snapshot"; defaultValue: true; tone: page.tone }
        }

        SetRow {
            title: qsTr("Backup & rollback")
            sub: qsTr("Snapshots on this disk — Condition opens the same page")
            navigates: true
            onActivated: Bus.openSettings("backup")
        }
    }

    SetCard {
        heading: qsTr("Reload the desktop")
        tone: page.tone
        note: qsTr("None of these log you out or close your windows. If the desktop ")
              + "ever looks wrong after an update, these are the two things to "
              + "try before restarting."

        SetRow {
            title: qsTr("Reload shell")
            sub: qsTr("Rebuilds the taskbar, the Start menu, the panels and this window from their current source. Your windows are untouched.")

            SetButton {
                text: qsTr("Reload shell")
                glyph: ""
                tone: page.tone
                danger: true
                confirmText: qsTr("Reload now — this window will blink")
                onClicked: Quickshell.reload(false);
            }
        }

        SetRow {
            title: qsTr("Reload Hyprland")
            sub: qsTr("Re-reads hyprland.conf — window rules, borders, gestures, keybinds. Windows and workspaces stay exactly as they are.")

            SetButton {
                text: qsTr("Reload Hyprland")
                glyph: ""
                tone: page.tone
                busy: hyprReload.running
                onClicked: hyprReload.running = true
            }
        }

        SetRow {
            title: qsTr("Re-apply input")
            sub: qsTr("Pushes pointer speed, key repeat, layout and cursor to the compositor again — the same thing that happens at login")

            SetButton {
                text: qsTr("Re-apply")
                glyph: ""
                tone: page.tone
                onClicked: HyprApply.apply()
            }
        }
    }

    SetResetRow {
        what: qsTr("Updates")
        keys: ["updates_autocheck", "updates_snapshot"]
    }

    Process {
        id: hyprReload
        running: false
        command: ["hyprctl", "reload"]
        onExited: function (code) { if (code !== 0) console.warn("[Updates] hyprctl reload exited code " + code); }
        stderr: StdioCollector {
            onStreamFinished: {
                var m = String(this.text).trim();
                if (m !== "")
                    console.warn("Updates: hyprctl reload — " + m);
            }
        }
    }
}
