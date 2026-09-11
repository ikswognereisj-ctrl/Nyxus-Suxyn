pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ System ▸ Power.
//
// Backend: powerprofilesctl (power-profiles-daemon, packaged) and UPower
// via Sys.qml. Writes the profile the daemon actually has. No terminal.
//
// The page is three ice stones + a battery instrument, not a Current/Charge
// spreadsheet. Magma stays off this page (nothing here destroys).
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    property var entry: null

    title: qsTr("Power")
    blurb: qsTr("Saver, Balanced, Performance — and what the battery is doing.")

    property string profile: ""
    property string lastNote: ""

    readonly property var profiles: [
        { value: "power-saver", label: qsTr("Power saver"),
          sub: qsTr("Lower clocks, longer battery") },
        { value: "balanced", label: qsTr("Balanced"),
          sub: qsTr("The usual default") },
        { value: "performance", label: qsTr("Performance"),
          sub: qsTr("Full clocks, more heat") }
    ]

    Component.onCompleted: getter.running = true

    Process {
        id: getter
        running: false
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                page.profile = String(this.text).trim();
                profileChoice.value = Qt.binding(function () { return page.profile; });
            }
        }
        onExited: function (code) {
            if (code !== 0)
                page.lastNote = "Power profiles are not available on this machine.";
        }
    }

    Process {
        id: setter
        running: false
        property string want: "balanced"
        command: ["powerprofilesctl", "set", setter.want]
        onExited: function (code) {
            if (code !== 0) {
                page.lastNote = "Could not set the profile.";
                profileMark.fail();
                return;
            }
            getter.running = true;
        }
    }

    SetCard {
        heading: qsTr("Power profile")
        tone: page.tone

        SetRow {
            title: qsTr("Profile")
            valueText: page.profile !== "" ? page.profile : ""

            RowLayout {
                spacing: Theme.s3

                LiveMark {
                    id: profileMark
                    Layout.alignment: Qt.AlignVCenter
                    actual: page.profile
                    visible: profileMark.pending || profileMark.failed
                }

                SetChoice {
                    id: profileChoice
                    tone: page.tone
                    value: page.profile
                    options: page.profiles
                    onChosen: function (v) {
                        profileChoice.value = Qt.binding(function () { return page.profile; });
                        if (v === page.profile)
                            return;
                        profileMark.request(v);
                        setter.want = v;
                        setter.running = true;
                    }
                }
            }
        }

        SetRow {
            visible: page.lastNote !== ""
            title: page.lastNote
        }
    }

    SetCard {
        heading: qsTr("Battery")
        tone: page.tone
        note: qsTr("The same source as the bar.")

        SetRow {
            title: Sys.hasBattery ? qsTr("Battery") : qsTr("Power")
            sub: Sys.hasBattery
                 ? (Sys.batteryCharging ? qsTr("Charging or on AC") : qsTr("On battery"))
                 : qsTr("This machine has no battery")
            valueText: Sys.hasBattery ? (Sys.batteryPercent + "%") : qsTr("AC")
        }
    }

    SetCard {
        heading: qsTr("While away")
        tone: page.tone
        note: qsTr("Screensaver and lock timers live on Keep awake.")

        SetRow {
            title: qsTr("Keep awake")
            sub: qsTr("When the screen blanks and when it locks")
            navigates: true
            onActivated: Bus.openSettings("idle")
        }
    }
}
