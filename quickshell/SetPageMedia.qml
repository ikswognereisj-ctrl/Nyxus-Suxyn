pragma ComponentBehavior: Bound
// Settings ▸ System ▸ Media. Does not touch tape or MediaCrest.
import QtQuick

SetPage {
    id: page
    property var entry: null

    title: qsTr("Media")
    blurb: qsTr("Library order, auto mixes, resume. No visualizer. The bar crest is not this page.")

    SetCard {
        heading: qsTr("Library")
        tone: page.tone
        SetRow {
            title: qsTr("Auto mixes")
            sub: qsTr("Build Recently Added, Kept, A–Z, and genre mixes from this library")
            SetSwitch { key: "app_media_auto_mixes"; defaultValue: true }
        }
        SetRow {
            title: qsTr("Resume where playback stopped")
            sub: qsTr("Seeks back to the saved spot when the same track opens at the start")
            SetSwitch { key: "app_media_resume"; defaultValue: true }
        }
        SetRow {
            title: qsTr("Repeat")
            sub: qsTr("Applied to the playing source as MPRIS LoopStatus")
            SetChoice {
                key: "app_media_repeat"
                defaultValue: "Off"
                options: ["Off", "All", "One"]
            }
        }
    }

    SetResetRow {
        what: qsTr("Media")
        keys: ["app_media_auto_mixes", "app_media_resume", "app_media_repeat"]
    }
}
