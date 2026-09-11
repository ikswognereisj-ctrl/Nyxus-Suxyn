pragma ComponentBehavior: Bound
// Settings ▸ System ▸ Notes. Live keys the glass Notes window reads.
import QtQuick

SetPage {
    id: page
    property var entry: null

    title: qsTr("Notes")
    blurb: qsTr("How the notebook writes, and what it shows.")

    SetCard {
        heading: qsTr("Editor")
        tone: page.tone
        SetRow {
            title: qsTr("Write in")
            sub: qsTr("First line is still the title")
            SetChoice {
                key: "app_notes_format"
                defaultValue: "Markdown"
                options: ["Markdown", "Plain text"]
            }
        }
        SetRow {
            title: qsTr("Type size")
            sub: qsTr("Notes window only")
            SetSlider {
                key: "app_notes_font_size"
                defaultValue: 13
                from: 9; to: 28; snap: 1
            }
        }
        SetRow {
            title: qsTr("Notebook sidebar")
            SetSwitch { key: "app_notes_sidebar"; defaultValue: true }
        }
        SetRow {
            title: qsTr("Autosave after (seconds)")
            sub: qsTr("0 writes on close")
            SetSlider {
                key: "app_notes_autosave_secs"
                defaultValue: 10
                from: 0; to: 120; snap: 5
            }
        }
    }

    SetResetRow {
        what: qsTr("Notes")
        keys: ["app_notes_format", "app_notes_font_size",
               "app_notes_sidebar", "app_notes_autosave_secs"]
    }
}
