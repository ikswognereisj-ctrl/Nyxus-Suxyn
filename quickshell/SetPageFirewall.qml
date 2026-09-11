pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ Privacy & Security ▸ Firewall.
// Status from nyxus-secure; toggle via pkexec apply. Same engine as HEMERA
// and the wizard. No terminal, no GTK dump.
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
    title: qsTr("Firewall")
    blurb: qsTr("Unsolicited inbound stays out unless you opt out.")

    property string fw: "off"
    property string lastNote: ""
    property string applySpec: ""

    function reload() { st.running = true; }
    Component.onCompleted: page.reload()

    Process {
        id: st
        running: false
        command: ["env", page.execPath, "nyxus-secure", "status"]   // TRK-3435
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = String(this.text).split("\n");
                for (var i = 0; i < lines.length; ++i) {
                    if (lines[i].indexOf("firewall=") === 0)
                        page.fw = lines[i].slice(9).trim();
                }
            }
        }
    }

    Process {
        id: apply
        running: false
        command: ["env", page.execPath,   // TRK-3435
                  "pkexec", "nyxus-secure", "apply", page.applySpec]
        onExited: function (code) {
            page.lastNote = code === 0 ? qsTr("Firewall updated.") : qsTr("Could not change the firewall.");
            page.reload();
        }
    }

    SetCard {
        heading: qsTr("Incoming")
        tone: page.tone
        note: page.lastNote !== "" ? page.lastNote
              : qsTr("The system firewall blocks unsolicited inbound connections by default. Changing it may ask for your password; no terminal opens.")

        // TRK-3427: turning the firewall OFF used to be the same plain tap
        // as turning it on — no danger hue, no confirm, on the one control
        // whose off-state opens the machine to unsolicited inbound. The
        // state is stated plainly here; the state CHANGE carries the
        // build's own two-tap danger ladder on the button below.
        SetRow {
            title: qsTr("Firewall")
            sub: page.fw === "on" ? qsTr("Protecting this PC") : qsTr("Off — inbound is open")
            valueText: page.fw === "on" ? qsTr("On") : qsTr("Off")
        }

        SetRow {
            title: page.fw === "on" ? qsTr("Turn the firewall off")
                                    : qsTr("Turn the firewall on")
            sub: page.fw === "on"
                 ? qsTr("Opens this machine to unsolicited inbound connections")
                 : qsTr("Unsolicited inbound stays out")

            SetButton {
                text: page.fw === "on" ? qsTr("Turn off") : qsTr("Turn on")
                danger: page.fw === "on"
                confirmText: qsTr("Click again — inbound opens")
                busy: apply.running
                onClicked: {
                    var spec = "firewall=" + (page.fw === "on" ? "off" : "on");
                    page.applySpec = spec;
                    apply.command = ["env", page.execPath,   // TRK-3435
                                     "pkexec", "nyxus-secure", "apply", spec];
                    apply.running = true;
                }
            }
        }

        SetRow {
            title: qsTr("More protections")
            sub: qsTr("App confinement, encrypted DNS, and MAC randomisation live on Security")
            navigates: true
            onActivated: Bus.openSettings("security")
        }
    }
}
