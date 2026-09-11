pragma ComponentBehavior: Bound
// Settings ▸ System ▸ Store.
import QtQuick

SetPage {
    id: page
    property var entry: null

    title: qsTr("Store")
    blurb: qsTr("Which sources the glass Store searches, and where it opens.")

    SetCard {
        heading: qsTr("Sources")
        tone: page.tone
        SetRow {
            title: qsTr("Include the AUR")
            sub: qsTr("pacman stays the default")
            SetSwitch { key: "app_store_include_aur"; defaultValue: true }
        }
        SetRow {
            title: qsTr("Include Flatpak")
            SetSwitch { key: "app_store_include_flatpak"; defaultValue: true }
        }
        SetRow {
            title: qsTr("Open on")
            SetChoice {
                key: "app_store_landing"
                defaultValue: "Featured"
                options: ["Featured", "Recommended", "Installed", "Updates"]
            }
        }
        SetRow {
            title: qsTr("Confirm before installing")
            SetSwitch { key: "app_store_confirm_install"; defaultValue: true }
        }
    }

    SetResetRow {
        what: qsTr("Store")
        keys: ["app_store_include_aur", "app_store_include_flatpak",
               "app_store_landing", "app_store_confirm_install"]
    }
}
