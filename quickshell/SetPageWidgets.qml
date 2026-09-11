pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ Personalization ▸ Desktop widgets.
//
// WIP-140 owed this page. Prefs already reads widgets_enabled + widget_<slug>.
// The six chips live in Widgets.qml. Turning one off does NOT touch the bar
// clock, the calendar inside the clock popup, the Calendar app, or lock
// weather — those are separate. Owner 08-16 kept all six in the build
// (WIP-699); this page is how you hide the ones you do not use.
import Quickshell
import QtQuick

SetPage {
    id: page
    property var entry: null
    title: qsTr("Desktop widgets")
    blurb: qsTr("Chips on the wallpaper. None of them is the bar clock.")

    readonly property bool master: SettingsStore.boolValue("widgets_enabled", true)

    SetCard {
        heading: qsTr("Desktop widgets")
        tone: page.tone
        note: qsTr("Turning this off hides every chip below and stops their timers. Drag a chip to move it — it snaps to a 24 px grid and stays off the bar and the icon column. The taskbar clock, calendar popup, Calendar app, and lock-screen weather are unaffected.")

        SetRow {
            title: qsTr("Desktop widgets")
            sub: page.master
                 ? qsTr("Chips can show on the wallpaper")
                 : qsTr("All six hidden — the taskbar clock stays")
            SetSwitch { key: "widgets_enabled"; defaultValue: true; tone: page.tone }
        }
    }

    SetCard {
        heading: qsTr("Which chips")
        tone: page.tone
        note: qsTr("The five chips ship on. Now Playing is off by default and hides itself when nothing is playing.")

        SetRow {
            title: qsTr("Clock")
            sub: qsTr("Big time on the wallpaper — not the taskbar clock")
            available: page.master
            unavailableReason: qsTr("Unavailable")
            SetSwitch { key: "widget_clock"; defaultValue: true; tone: page.tone }
        }
        SetRow {
            title: qsTr("Vitals")
            sub: qsTr("Battery and volume — the flyout still has them")
            available: page.master
            unavailableReason: qsTr("Unavailable")
            SetSwitch { key: "widget_vitals"; defaultValue: true; tone: page.tone }
        }
        SetRow {
            title: qsTr("Sticky note")
            sub: qsTr("Scratch note on the wallpaper")
            available: page.master
            unavailableReason: qsTr("Unavailable")
            SetSwitch { key: "widget_sticky"; defaultValue: true; tone: page.tone }
        }
        SetRow {
            title: qsTr("Calendar")
            sub: qsTr("Month peek — not the Calendar app, not the clock popup")
            available: page.master
            unavailableReason: qsTr("Unavailable")
            SetSwitch { key: "widget_calendar"; defaultValue: true; tone: page.tone }
        }
        SetRow {
            title: qsTr("Weather")
            sub: qsTr("Reads the lock-screen cache — does not fetch")
            available: page.master
            unavailableReason: qsTr("Unavailable")
            SetSwitch { key: "widget_weather"; defaultValue: true; tone: page.tone }
        }
        SetRow {
            title: qsTr("Now Playing")
            sub: qsTr("Transport card for the current track")
            available: page.master
            unavailableReason: qsTr("Unavailable")
            SetSwitch { key: "widget_nowplaying"; defaultValue: false; tone: page.tone }
        }
    }

    SetResetRow {
        what: qsTr("Desktop widgets")
        keys: ["widgets_enabled", "widget_clock", "widget_vitals", "widget_sticky",
               "widget_calendar", "widget_weather", "widget_nowplaying"]
    }
}
