pragma ComponentBehavior: Bound
// Settings ▸ System ▸ Weather. Units write weather.json through weather-io.
import Quickshell
import Quickshell.Io
import QtQuick

SetPage {
    id: page
    property var entry: null

    title: qsTr("Weather")
    blurb: qsTr("Units and the live sky. Same file the Weather window reads.")

    property string units: "imperial"
    property bool pendingUnits: false
    property bool failedUnits: false

    function io() { return (Quickshell.env("HOME") || "") + "/.config/quickshell/weather-io.py"; }

    Component.onCompleted: show.running = true

    Process {
        id: show
        running: false
        command: ["python3", page.io(), "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    page.units = j.units || "imperial";
                    page.pendingUnits = false;
                    page.failedUnits = false;
                } catch (e) { page.failedUnits = true; }
            }
        }
    }

    Process {
        id: setUnits
        running: false
        command: ["python3", page.io(), "units"]
        onExited: function (code) {
            if (code !== 0)
                page.failedUnits = true;
            show.running = true;
        }
    }

    SetCard {
        heading: qsTr("Reading")
        tone: page.tone
        SetRow {
            title: qsTr("Units")
            sub: page.units === "imperial" ? qsTr("Fahrenheit, mph") : qsTr("Celsius, km/h")
            valueText: page.units === "imperial" ? "°F" : "°C"
            SetSwitch {
                checked: page.units === "imperial"
                pending: page.pendingUnits
                failed: page.failedUnits
                onToggled: {
                    page.pendingUnits = true;
                    page.failedUnits = false;
                    setUnits.running = false;
                    setUnits.running = true;
                }
            }
        }
        SetRow {
            title: qsTr("Live sky in the window")
            SetSwitch { key: "app_weather_live_sky"; defaultValue: true }
        }
        SetRow {
            title: qsTr("Refresh every (minutes)")
            SetSlider {
                key: "app_weather_refresh_mins"
                defaultValue: 60
                from: 10; to: 360; snap: 10
            }
        }
    }

    SetResetRow {
        what: qsTr("Weather")
        keys: ["app_weather_live_sky", "app_weather_refresh_mins"]
    }
}
