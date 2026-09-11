pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ Time & Language ▸ Date & time.
// Prefs.qml already reads clock_24h / clock_seconds / clock_timezone.
// This page is the writer. Empty timezone means follow the system.
// TRK-3203 — automatic zone is nyxus-autotz (opt-in, pkexec). NTP is
// timedatectl. The GTK Date page already had both; glass did not.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    property var entry: null
    // TRK-3435: shipped-first PATH via `env`, never a shell. Ruling:
    // SetPageBackup.qml.
    readonly property string execPath: "PATH="
        + (Quickshell.env("NYXUS_BIN_DIR") || "/usr/local/bin")
        + ":" + Quickshell.env("PATH")
    title: qsTr("Date & time")
    blurb: qsTr("How the clock on the Line writes the time.")

    readonly property bool h24: SettingsStore.boolValue("clock_24h", false)
    readonly property bool secs: SettingsStore.boolValue("clock_seconds", false)
    readonly property string tz: SettingsStore.stringValue("clock_timezone", "")
    property bool autoTz: false
    property bool autoTzHere: false
    property string autoTzNote: ""
    property bool ntpOn: false
    property string ntpNote: ""

    Component.onCompleted: {
        autoTzProbe.running = true;
        ntpProbe.running = true;
    }

    Process {
        id: autoTzProbe
        running: false
        command: ["env", page.execPath, "nyxus-autotz", "status", "--json"]   // TRK-3435
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = String(this.text || "").trim();
                if (!raw) {
                    page.autoTzHere = false;
                    return;
                }
                try {
                    var d = JSON.parse(raw);
                    page.autoTzHere = true;
                    page.autoTz = !!d.enabled;
                    page.autoTzNote = d.zone ? String(d.zone) : (d.reason ? String(d.reason) : "");
                } catch (e) {
                    page.autoTzHere = false;
                }
            }
        }
        onExited: function (code) {
            if (code !== 0)
                page.autoTzHere = false;
        }
    }

    Process {
        id: autoTzWrite
        running: false
        command: ["env", page.execPath,   // TRK-3435 — pkexec resolves via caller PATH
                  "pkexec", "nyxus-autotz", page.autoTz ? "disable" : "enable"]
        onExited: function (code) {
            page.autoTzNote = code === 0
                              ? (page.autoTz ? qsTr("Automatic time zone off") : qsTr("Automatic time zone on"))
                              : qsTr("Needs administrator — nothing changed");
            autoTzProbe.running = true;
            if (code === 0 && !page.autoTz)
                autoTzApply.running = true;
        }
    }

    Process {
        id: autoTzApply
        running: false
        command: ["env", page.execPath,   // TRK-3435
                  "pkexec", "nyxus-autotz", "apply", "--force", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = String(this.text || "").trim();
                try {
                    var d = JSON.parse(raw);
                    if (d.zone)
                        page.autoTzNote = qsTr("Zone is now %1").arg(String(d.zone));
                    else if (d.error)
                        page.autoTzNote = String(d.error);
                } catch (e) { }
                autoTzProbe.running = true;
            }
        }
        onExited: function (code) {
            if (code !== 0 && page.autoTzNote === "")
                page.autoTzNote = qsTr("Could not determine location — clock unchanged");
        }
    }

    Process {
        id: ntpProbe
        running: false
        command: ["timedatectl", "show", "-p", "NTP", "--value"]
        stdout: StdioCollector {
            onStreamFinished: {
                var v = String(this.text || "").trim().toLowerCase();
                page.ntpOn = (v === "yes" || v === "true" || v === "1");
            }
        }
    }

    Process {
        id: ntpWrite
        running: false
        command: ["timedatectl", "set-ntp", page.ntpOn ? "false" : "true"]
        onExited: function (code) {
            page.ntpNote = code === 0
                           ? (page.ntpOn ? qsTr("Network time off") : qsTr("Network time on"))
                           : qsTr("Could not change network time (polkit refused)");
            ntpProbe.running = true;
        }
    }

    SetCard {
        heading: qsTr("Clock")
        tone: page.tone
        note: qsTr("The bar clock reads these keys live. No format switch lives on the clock itself.")

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s3

            SetIceFace {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("24-HOUR")
                reading: page.h24 ? qsTr("ON") : qsTr("OFF")
                caption: qsTr("How the Line writes the hour")
                selected: page.h24
                interactive: true
                onActivated: SettingsStore.setValue("clock_24h", !page.h24)
            }
            SetIceFace {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("SECONDS")
                reading: page.secs ? qsTr("ON") : qsTr("OFF")
                caption: qsTr("Show the ticking second")
                selected: page.secs
                interactive: true
                onActivated: SettingsStore.setValue("clock_seconds", !page.secs)
            }
        }

        SetIceFace {
            kicker: qsTr("TIME ZONE")
            reading: page.tz === "" ? "SYS" : ""
            caption: page.tz === "" ? qsTr("Following the system") : page.tz
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4

            SetButton {
                text: qsTr("Use system")
                tone: page.tone
                enabled: page.tz !== ""
                onClicked: SettingsStore.setValue("clock_timezone", "")
            }
        }
    }

    SetCard {
        heading: qsTr("Automatic time zone")
        tone: page.tone
        note: page.autoTzHere
              ? qsTr("Opt-in. Reads location through the system location service and picks the nearest zone. Coarse near borders — the manual zone above still wins if this is off.")
              : qsTr("nyxus-autotz is not on PATH. The clock stays whatever you set by hand.")

        SetIceFace {
            visible: page.autoTzHere
            kicker: qsTr("AUTO ZONE")
            reading: page.autoTz ? qsTr("ON") : qsTr("OFF")
            caption: page.autoTz
                     ? qsTr("Location may set the machine clock")
                     : qsTr("Nothing is reading your location")
            selected: page.autoTz
            interactive: true
            attention: autoTzWrite.running
            onActivated: autoTzWrite.running = true
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            visible: page.autoTzHere && page.autoTz

            SetButton {
                text: qsTr("Check location now")
                tone: page.tone
                busy: autoTzApply.running
                enabled: !autoTzApply.running
                onClicked: autoTzApply.running = true
            }
        }

        SetIceFace {
            visible: page.autoTzNote !== ""
            compact: true
            kicker: qsTr("NOTE")
            caption: page.autoTzNote
        }
    }

    SetCard {
        heading: qsTr("Network time")
        tone: page.tone
        note: qsTr("timedatectl NTP. The bar clock follows the system when the zone field above is empty.")

        SetIceFace {
            kicker: qsTr("NTP")
            reading: page.ntpOn ? qsTr("ON") : qsTr("OFF")
            caption: qsTr("Keep this machine's clock in step with the network")
            selected: page.ntpOn
            interactive: true
            attention: ntpWrite.running
            onActivated: ntpWrite.running = true
        }

        SetIceFace {
            visible: page.ntpNote !== ""
            compact: true
            kicker: qsTr("NOTE")
            caption: page.ntpNote
        }
    }

    // ── audit-0908 · TRK-3969 ───────────────────────────────────────────
    // The three keys this page owns, and only those. Deliberately NOT the
    // system clock: a settings-page reset must not reach through to
    // timedatectl and move the machine's time zone or switch NTP off. Those
    // are system state this page CHANGES but does not OWN, they have their
    // own controls above, and they are shared with everything else on the
    // machine. Clearing `clock_timezone` returns the bar clock to following
    // the system, which is what the card already says an empty zone means.
    SetResetRow {
        what: qsTr("Date & time")
        keys: ["clock_24h", "clock_seconds", "clock_timezone"]
    }
}
