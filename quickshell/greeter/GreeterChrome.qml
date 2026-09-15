pragma ComponentBehavior: Bound
// Nyxus Suxyn — the greeter's chrome. Clock, battery, network, power.
//
// Deliberately self-contained: the greeter runs as the `greeter` user, before
// any session exists, so it cannot lean on Sys.qml (which drives itself from a
// user session's process tree) or on Prefs (which reads the owner's settings
// store in a home directory this user cannot see). Everything here reads sysfs
// and /proc directly, which are world-readable and present at greeter time.
//
// 12-HOUR CLOCK ON PURPOSE. ReGreet was configured `%H:%M` — 24-hour — which
// contradicts the owner's standing preference that every other clock in the
// build follows (Prefs.timeFmt, TRK-3728). The greeter is the first clock he
// sees each day; it should not be the one that disagrees.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: chrome

    signal power(string what)

    readonly property color dim: "#7a869f"
    readonly property color text: "#c9d0e8"
    readonly property int pad: 34

    // ── clock ────────────────────────────────────────────────────────────────
    property string timeText: ""
    property string dateText: ""
    Timer {
        running: true
        repeat: true
        interval: 1000
        triggeredOnStart: true
        onTriggered: {
            var d = new Date();
            chrome.timeText = Qt.formatDateTime(d, "h:mm AP");
            chrome.dateText = Qt.formatDateTime(d, "dddd, d MMMM");
        }
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: chrome.pad
        spacing: 2

        Text {
            text: chrome.timeText
            color: chrome.text
            font.pixelSize: 46
            font.letterSpacing: 1.5
        }
        Text {
            text: chrome.dateText
            color: chrome.dim
            font.pixelSize: 15
        }
    }

    // ── battery + network ────────────────────────────────────────────────────
    // One shell pass every 5 s. sysfs only: no nvidia-smi, no `iw`, nothing that
    // spawns a heavy child on a machine that has not logged in yet.
    property string battText: ""
    property string netText: ""

    Process {
        id: probe
        running: false
        command: ["sh", "-c",
            "b=/sys/class/power_supply; cap=; st=; "
          + "for d in $b/BAT*; do [ -r \"$d/capacity\" ] || continue; "
          + "cap=$(cat \"$d/capacity\"); st=$(cat \"$d/status\" 2>/dev/null); break; done; "
          + "echo \"${cap:--} ${st:--}\"; "
          + "ifn=-; spd=0; knd=-; "
          + "for d in /sys/class/net/*; do n=$(basename \"$d\"); "
          + "case \"$n\" in lo|veth*|docker*|br-*|virbr*) continue ;; esac; "
          + "[ \"$(cat \"$d/carrier\" 2>/dev/null)\" = 1 ] || continue; "
          + "if [ -d \"$d/wireless\" ]; then k=wifi; else k=wired; fi; "
          + "s=$(cat \"$d/speed\" 2>/dev/null | tr -dc 0-9); [ -n \"$s\" ] || s=0; "
          + "if [ \"$ifn\" = - ] || { [ \"$knd\" = wifi ] && [ \"$k\" = wired ]; }; then "
          + "ifn=$n; spd=$s; knd=$k; fi; done; echo \"$ifn $spd $knd\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var L = String(this.text || "").trim().split("\n");
                if (L.length > 0) {
                    var b = L[0].trim().split(" ");
                    if (b[0] && b[0] !== "-") {
                        var charging = (b[1] || "").toLowerCase().indexOf("charg") === 0;
                        chrome.battText = b[0] + "%" + (charging ? " ⚡" : "");
                    } else {
                        chrome.battText = "";
                    }
                }
                if (L.length > 1) {
                    var n = L[1].trim().split(" ");
                    if (n[0] && n[0] !== "-") {
                        var mb = parseInt(n[1], 10);
                        chrome.netText = n[2] === "wifi"
                            ? "Wi-Fi"
                            : (mb >= 1000 ? (mb / 1000) + " Gb/s"
                                          : (mb > 0 ? mb + " Mb/s" : "Wired"));
                    } else {
                        chrome.netText = qsTr("Offline");
                    }
                }
            }
        }
    }
    Timer {
        running: true
        repeat: true
        interval: 5000
        triggeredOnStart: true
        onTriggered: if (!probe.running) probe.running = true
    }

    ColumnLayout {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: chrome.pad
        spacing: 6

        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: 16
            Text {
                visible: chrome.netText !== ""
                text: chrome.netText
                color: chrome.dim
                font.pixelSize: 14
            }
            Text {
                visible: chrome.battText !== ""
                text: chrome.battText
                color: chrome.dim
                font.pixelSize: 14
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            spacing: 10
            Repeater {
                model: [
                    { glyph: "⏻", what: "poweroff", tip: qsTr("Power off") },
                    { glyph: "⟳", what: "reboot",   tip: qsTr("Restart") },
                    { glyph: "☾", what: "suspend",  tip: qsTr("Sleep") }
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: 34; height: 34; radius: 8
                    color: hov.hovered ? "#16222a" : "transparent"
                    border.width: 1
                    border.color: hov.hovered ? "#2b4450" : "#1a2830"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.glyph
                        color: hov.hovered ? "#edf1ff" : chrome.dim
                        font.pixelSize: 16
                    }
                    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: chrome.power(parent.modelData.what) }
                }
            }
        }
    }
}
