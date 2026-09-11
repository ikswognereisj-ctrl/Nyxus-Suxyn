pragma ComponentBehavior: Bound
// Settings ▸ System ▸ Monitor.
import QtQuick

SetPage {
    id: page
    property var entry: null

    title: qsTr("Monitor")
    blurb: qsTr("How System Monitor samples this machine.")

    SetCard {
        heading: qsTr("Sampling")
        tone: page.tone
        SetRow {
            title: qsTr("Refresh every (seconds)")
            SetSlider {
                key: "app_mon_refresh_secs"
                defaultValue: 2
                from: 1; to: 30; snap: 1
            }
        }
        SetRow {
            title: qsTr("Graph history (seconds)")
            SetSlider {
                key: "app_mon_graph_span"
                defaultValue: 60
                from: 30; to: 600; snap: 30
            }
        }
        SetRow {
            title: qsTr("Show every CPU core")
            SetSwitch { key: "app_mon_per_core"; defaultValue: true }
        }
        SetRow {
            title: qsTr("Network rate in")
            SetChoice {
                key: "app_mon_net_unit"
                defaultValue: "byte/s"
                options: ["byte/s", "bit/s"]
            }
        }
    }

    SetResetRow {
        what: qsTr("Monitor")
        keys: ["app_mon_refresh_secs", "app_mon_graph_span",
               "app_mon_per_core", "app_mon_net_unit"]
    }
}
