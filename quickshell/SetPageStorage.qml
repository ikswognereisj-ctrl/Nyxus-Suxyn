pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ System ▸ Storage.
//
// Backend: df + lsblk, streamed INTO this window. No terminal. Mount/eject
// for removable media is the USB page (udisks), not a second copy here.
//
// The system disk is an ice instrument (lens + trough), not a "Used on /"
// spreadsheet row. Volumes are plates, not NAME/SIZE/MOUNT columns.
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

    title: qsTr("Storage")
    blurb: qsTr("Disks, free space, and what is mounted.")

    property var disks: []
    property string rootLine: ""
    property string lastNote: ""
    property bool trashWeekly: false
    property string trashNote: ""

    Component.onCompleted: {
        collector.running = true;
        trashWeeklyProbe.running = true;
    }

    Process {
        id: collector
        running: false
        command: ["sh", "-c",
            'df -hP / 2>/dev/null | awk "NR==2 {print \\$2 \\"\\t\\" \\$3 \\"\\t\\" \\$4 \\"\\t\\" \\$5}"\n'
          + 'printf "\\037\\n"\n'
          + 'lsblk -o NAME,FSTYPE,SIZE,FSAVAIL,MOUNTPOINT,TYPE -nP 2>/dev/null || true\n'
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = String(this.text).split("\u001f");
                page.rootLine = String(parts[0] || "").trim();
                var rest = String(parts[1] || "");
                var out = [];
                var lines = rest.split("\n");
                for (var i = 0; i < lines.length; ++i) {
                    var l = lines[i].trim();
                    if (l === "") continue;
                    var rec = {};
                    var re = /([A-Z]+)=("(?:[^"]*)"|\\S+)/g;
                    var m;
                    while ((m = re.exec(l)) !== null)
                        rec[m[1].toLowerCase()] = m[2].replace(/^"|"$/g, "");
                    if (rec.name)
                        out.push(rec);
                }
                page.disks = out;
            }
        }
        onExited: function (code) {
            if (code !== 0)
                page.lastNote = "Could not read disks.";
        }
    }

    Process {
        id: trashWeeklyProbe
        running: false
        command: ["systemctl", "--user", "is-enabled", "nyxus-trash-empty.timer"]
        onExited: function (code) {
            page.trashWeekly = (code === 0);
        }
    }

    Process {
        id: trashEmpty
        running: false
        command: ["gio", "trash", "--empty"]
        onExited: function (code) {
            page.trashNote = code === 0
                             ? qsTr("Trash emptied")
                             : qsTr("Could not empty trash");
        }
    }

    Process {
        id: trashOpen
        running: false
        command: ["env", page.execPath, "nyxus-files", "trash:///"]   // TRK-3435
    }

    Process {
        id: trashWeeklyWrite
        running: false
        command: ["systemctl", "--user",
                  page.trashWeekly ? "disable" : "enable",
                  "--now", "nyxus-trash-empty.timer"]
        onExited: function (code) {
            page.trashNote = code === 0
                             ? (page.trashWeekly ? qsTr("Weekly empty off") : qsTr("Weekly empty on"))
                             : qsTr("Could not change the weekly empty timer");
            trashWeeklyProbe.running = true;
        }
    }

    readonly property var rootBits: page.rootLine.split("\t")
    readonly property real rootPct: {
        if (page.rootBits.length < 4)
            return -1;
        var s = String(page.rootBits[3]).replace("%", "");
        var n = parseFloat(s);
        return isNaN(n) ? -1 : n;
    }
    readonly property string rootReading: {
        if (page.rootPct < 0)
            return "—";
        return Math.round(page.rootPct) + "%";
    }
    readonly property string rootCaption: {
        if (page.rootBits.length < 4)
            return "Not readable";
        return page.rootBits[1] + " used of " + page.rootBits[0];
    }
    readonly property string rootDetail: {
        if (page.rootBits.length < 4)
            return "";
        return page.rootBits[2] + " free on /";
    }

    SetCard {
        heading: qsTr("This system")
        tone: page.tone
        note: qsTr("The root filesystem. Refresh by leaving and returning.")

        SetRow {
            title: qsTr("System disk")
            sub: page.rootDetail !== "" ? page.rootCaption + " · " + page.rootDetail
                                        : page.rootCaption
            valueText: page.rootReading
        }

        SetRow {
            visible: page.lastNote !== ""
            title: page.lastNote
        }
    }

    SetCard {
        heading: qsTr("Volumes")
        tone: page.tone
        note: qsTr("Encrypted volumes show as crypto_LUKS. Removable eject is USB.")

        Repeater {
            model: page.disks
            delegate: SetRow {
                required property var modelData
                title: String(modelData.name || "").toUpperCase()
                sub: [modelData.fstype, modelData.size, modelData.mountpoint]
                     .filter(function (x) { return x && x !== ""; }).join(" · ")
                valueText: modelData.fsavail || modelData.size || ""
            }
        }

        SetRow {
            visible: page.disks.length === 0
            title: qsTr("Volumes")
            sub: qsTr("No volumes reported")
        }

        SetRow {
            title: qsTr("USB & removable")
            sub: qsTr("Mount, eject, plug-in notifications")
            navigates: true
            onActivated: Bus.openSettings("usb")
        }
    }

    SetCard {
        heading: qsTr("Trash")
        tone: page.tone
        note: qsTr("Put Back lives in Files on the Trash view. Empty here does the same thing as the rest of the build.")

        SetRow {
            title: qsTr("Weekly empty")
            sub: qsTr("Once a week, empty the Trash. Off until you turn it on.")

            SetSwitch {
                tone: page.tone
                checked: page.trashWeekly
                onToggled: trashWeeklyWrite.running = true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            spacing: Theme.s4

            SetButton {
                text: qsTr("Open Trash")
                tone: page.tone
                onClicked: trashOpen.running = true
            }
            SetButton {
                text: qsTr("Empty now")
                danger: true
                confirmText: qsTr("Empty Trash — cannot Put Back after this")
                tone: page.tone
                busy: trashEmpty.running
                onClicked: trashEmpty.running = true
            }
        }

        SetRow {
            visible: page.trashNote !== ""
            title: page.trashNote
        }
    }
}
