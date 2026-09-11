pragma ComponentBehavior: Bound
// Nyxus Suxyn — last-resort page when a catalog key has no QML file.
// Owner 2026-08-19: ONE glass Settings. This file does not launch GTK
// nyxus-settings and does not open a terminal. The catalog only lists
// pages that exist, so this Loader target should stay unreachable.
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    property var entry: null

    title: page.entry ? page.entry.title : qsTr("Settings")
    blurb: page.entry ? page.entry.blurb : ""

    SetCard {
        heading: qsTr("Not in this Settings")
        tone: page.tone
        note: qsTr("This window is the glass control center. A missing page is a catalog gap, not a door into the leftover GTK app.")

        SetRow {
            title: qsTr("Settings home")
            sub: qsTr("This page is not available yet")
            navigates: true
            onActivated: Bus.openSettings("")
        }
    }
}
