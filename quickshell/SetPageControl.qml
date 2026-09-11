pragma ComponentBehavior: Bound
// Settings ▸ System ▸ Hardware app (the window, not This machine's hardware).
import QtQuick

SetPage {
    id: page
    property var entry: null

    title: qsTr("Hardware")
    blurb: qsTr("How the Hardware window polls this machine.")

    SetCard {
        heading: qsTr("Monitoring")
        tone: page.tone
        SetRow {
            title: qsTr("Poll every (seconds)")
            SetSlider {
                key: "app_hw_poll_secs"
                defaultValue: 2
                from: 1; to: 60; snap: 1
            }
        }
        SetRow {
            title: qsTr("Temperature unit")
            SetChoice {
                key: "app_hw_temp_unit"
                defaultValue: "Celsius"
                options: ["Celsius", "Fahrenheit"]
            }
        }
        SetRow {
            title: qsTr("Warn above (degrees)")
            SetSlider {
                key: "app_hw_warn_temp"
                defaultValue: 85
                from: 50; to: 110; snap: 1
            }
        }
        SetRow {
            title: qsTr("Open on")
            SetChoice {
                key: "app_hw_default_tab"
                defaultValue: "Overview"
                options: ["Overview", "Fans", "Thermal", "Profiles",
                          "RGB", "Power", "Processes"]
            }
        }
    }

    SetResetRow {
        what: qsTr("Hardware")
        keys: ["app_hw_poll_secs", "app_hw_temp_unit",
               "app_hw_warn_temp", "app_hw_default_tab"]
    }
}
