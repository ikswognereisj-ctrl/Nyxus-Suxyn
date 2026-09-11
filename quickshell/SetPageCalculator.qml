pragma ComponentBehavior: Bound
// Settings ▸ System ▸ Calculator.
import QtQuick

SetPage {
    id: page
    property var entry: null

    title: qsTr("Calculator")
    blurb: qsTr("Precision, angle, grouping, and the tape.")

    SetCard {
        heading: qsTr("Numbers")
        tone: page.tone
        SetRow {
            title: qsTr("Trigonometry in")
            SetChoice {
                key: "app_calc_angle"
                defaultValue: "Degrees"
                options: ["Degrees", "Radians"]
            }
        }
        SetRow {
            title: qsTr("Group thousands")
            SetSwitch { key: "app_calc_thousands"; defaultValue: true }
        }
        SetRow {
            title: qsTr("Significant digits")
            SetSlider {
                key: "app_calc_precision"
                defaultValue: 10
                from: 2; to: 15; snap: 1
            }
        }
        SetRow {
            title: qsTr("Copy the answer on =")
            SetSwitch { key: "app_calc_copy_on_equals"; defaultValue: false }
        }
    }

    SetResetRow {
        what: qsTr("Calculator")
        keys: ["app_calc_angle", "app_calc_thousands",
               "app_calc_precision", "app_calc_copy_on_equals"]
    }
}
