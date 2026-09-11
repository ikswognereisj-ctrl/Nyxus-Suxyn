pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ Personalization ▸ Taskbar.
// The Line is Bar.qml (BQ — not edited). This page writes Start style and
// states the pinning that already works from a running app. No dead dock.toml.
import Quickshell
import QtQuick

SetPage {
    id: page
    property var entry: null
    title: qsTr("Taskbar")
    blurb: qsTr("The Line along the bottom of the screen.")

    SetCard {
        heading: qsTr("The Line")
        tone: page.tone
        note: qsTr("Right-click a running app on the Line to pin or unpin it. Icon size and dissolve are the taskbar's own settings.")

        SetRow {
            title: qsTr("Start menu style")
            sub: qsTr("Daily is the launcher; Classic keeps the Atrium")

            SetChoice {
                tone: page.tone
                key: "launcher_style"
                defaultValue: "daily"
                options: [
                    { value: "daily",   label: qsTr("Daily") },
                    { value: "classic", label: qsTr("Classic") }
                ]
            }
        }

        SetRow {
            title: qsTr("Clock")
            sub: qsTr("24-hour and seconds are set under Date & time")
            navigates: true
            onActivated: Bus.openSettings("datetime")
        }

        SetRow {
            title: qsTr("Desktop widgets")
            sub: qsTr("Six chips on the wallpaper — not this taskbar clock")
            navigates: true
            onActivated: Bus.openSettings("widgets")
        }

        SetRow {
            title: qsTr("On the bar")
            sub: qsTr("Swirls, hover, the music visualizer, and lyrics — Appearance")
            navigates: true
            onActivated: Bus.openSettings("appearance")
        }
    }

    // TRK-3424 — this page OWNS `launcher_style` now (the Appearance copy
    // became a link), so it carries the reset for it, per TRK-1261's rule
    // that a page's reset row lists exactly the keys the page writes.
    SetResetRow {
        what: qsTr("Taskbar")
        keys: ["launcher_style"]
    }
}
