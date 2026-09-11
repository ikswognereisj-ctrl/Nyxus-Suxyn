pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ System ▸ Windowing.
// Deep-link key `compositor` (Bar context menu). Reload is hyprctl in this
// window. Floating-by-default is a HANDOFF decision, not a dead toggle.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    property var entry: null
    title: qsTr("Windowing")
    blurb: qsTr("Hyprland — floating by default, snap on drag-to-edge.")

    property string version: ""
    property string lastNote: ""

    // Read through SettingsStore, the same writer the rows below call, so the
    // page can never show a state the file does not hold. Prefs.qml exposes
    // the same two keys to the panes themselves; the defaults must agree with
    // its adapter block, or the page shows one thing and the shell draws
    // another — the defect the lock screen's earth cost the owner two trips
    // to find.
    readonly property bool frostOn: SettingsStore.boolValue("frost_enabled", false)
    readonly property real frostStrength: SettingsStore.numberValue("frost_strength", 0.5)

    Component.onCompleted: ver.running = true

    Process {
        id: ver
        running: false
        command: ["hyprctl", "version"]
        stdout: StdioCollector {
            onStreamFinished: {
                var line = String(this.text).split("\n")[0] || "";
                page.version = line.trim();
            }
        }
    }

    Process {
        id: reload
        running: false
        command: ["hyprctl", "reload"]
        onExited: function (code) {
            page.lastNote = code === 0 ? "Compositor config reloaded." : "hyprctl reload did not run.";
        }
    }

    SetCard {
        heading: qsTr("Hyprland")
        tone: page.tone
        note: qsTr("Tiling is a keybind, not the default. This page does not pretend to be a full compositor control panel.")

        SetRow {
            title: qsTr("Version")
            sub: qsTr("Floating by default, snap on drag-to-edge")
            valueText: page.version !== "" ? page.version : "—"
        }

        SetRow {
            title: qsTr("Reload configuration")
            sub: page.lastNote !== "" ? page.lastNote
                                      : qsTr("Keeps windows open — the same reload Updates uses")

            SetButton {
                text: qsTr("Reload")
                tone: page.tone
                busy: reload.running
                onClicked: reload.running = true
            }
        }

        SetRow {
            title: qsTr("Display")
            sub: qsTr("Resolution, scale, Night Light")
            navigates: true
            onActivated: Bus.openSettings("display")
        }
    }

    // ── THE FROST ────────────────────────────────────────────────────────
    // The owner's ask, in his words: "blurred out so you couldn't read or see
    // what was on a window … you see the outlines of stuff but its blurred
    // out." Frost.qml's header carries why this cannot be a compositor
    // setting and has to be a layer surface.
    SetCard {
        heading: qsTr("Unfocused windows")
        tone: page.tone
        note: qsTr("Blur is a real GPU pass. It is off until you switch it on, and the strength below is the only part of it that costs nothing to change.")

        SetRow {
            title: qsTr("Blur unfocused windows")
            sub: page.frostOn
                 ? qsTr("Text becomes unreadable; the window's shape stays. The focused window is never blurred.")
                 : qsTr("Every window stays sharp")

            SetSwitch {
                key: "frost_enabled"
                defaultValue: false
                tone: page.tone
            }
        }

        // Strength is the pane's own TINT, not the blur radius — the radius is
        // a compositor global and cannot be varied per layer surface, so this
        // is the one part of the effect a setting can actually move. Three
        // stops rather than a slider, matching how Appearance offers the
        // control paint's drift: a slider on an effect you cannot see change
        // until you click away from the window is a control nobody can aim.
        SetRow {
            title: qsTr("Blur strength")
            sub: qsTr("Blur only, or blur with added shade")
            available: page.frostOn
            unavailableReason: qsTr("Blur is off")

            SetChoice {
                key: "frost_strength"
                defaultValue: 0.5
                tone: page.tone
                segmentLimit: 3
                options: [
                    { value: 0.0, label: qsTr("Light") },
                    { value: 0.5, label: qsTr("Medium") },
                    { value: 1.0, label: qsTr("Heavy") }
                ]
            }
        }
    }

    // TRK-1261 — the page's Reset button clears exactly the keys it owns, and
    // a key missing from this list is a key Reset silently leaves behind.
    // This page had no reset row until the frost gave it its first two
    // persisted settings.
    SetResetRow {
        what: qsTr("Windowing")
        keys: ["frost_enabled", "frost_strength"]
    }
}
