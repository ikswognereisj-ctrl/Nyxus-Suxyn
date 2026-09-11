pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ Ease of Access ▸ Keep awake.
// Nested `power` object in settings.json. Prefs / Screensaver read saver_on
// and saver_secs. lock_secs is stored; hypridle's lock listener is still
// 600 s and glass Settings does not rewrite hypridle.conf (TRK-3126).
import Quickshell
import QtQuick

SetPage {
    id: page
    property var entry: null
    title: qsTr("Keep awake")
    blurb: qsTr("When the screensaver and the lock take over.")

    readonly property var power: {
        var p = SettingsStore.value("power", null);
        if (p && typeof p === "object")
            return {
                saver_on: p.saver_on === undefined ? 1 : p.saver_on,
                saver_secs: p.saver_secs === undefined ? 300 : p.saver_secs,
                lock_secs: p.lock_secs === undefined ? 600 : p.lock_secs
            };
        return { saver_on: 1, saver_secs: 300, lock_secs: 600 };
    }

    function writePower(next) {
        SettingsStore.setValue("power", {
            saver_on: next.saver_on,
            saver_secs: next.saver_secs,
            lock_secs: next.lock_secs
        });
    }

    readonly property bool saverOn: Number(page.power.saver_on) !== 0
    readonly property int saverSecs: Number(page.power.saver_secs)

    SetCard {
        heading: qsTr("Idle")
        tone: page.tone
        note: qsTr("Five minutes to the screensaver, ten to the lock, unless you change it. The flyout Keep Awake switch inhibits this for one session.")

        SetRow {
            title: qsTr("Screensaver")
            sub: qsTr("Shows after the machine sits idle")
            SetSwitch {
                tone: page.tone
                checked: page.saverOn
                onToggled: function (v) {
                    var p = page.power;
                    p.saver_on = v ? 1 : 0;
                    page.writePower(p);
                }
            }
        }

        SetRow {
            title: qsTr("Wait")
            sub: qsTr("Idle time before the screensaver appears")
            available: page.saverOn
            unavailableReason: qsTr("Screensaver is off")

            SetSlider {
                from: 60
                to: 1800
                snap: 60
                live: false
                suffix: " s"
                value: page.saverSecs
                tone: page.tone
                onReleased: function (v) {
                    var p = page.power;
                    p.saver_secs = Math.round(v);
                    page.writePower(p);
                }
            }
        }

        SetRow {
            title: qsTr("Lock")
            available: false
            unavailableReason: qsTr("Fixed at 10 minutes")
            valueText: qsTr("10 min")
        }

        SetRow {
            title: qsTr("Lock screen")
            sub: qsTr("Earth, moon, and what shows while locked")
            navigates: true
            onActivated: Bus.openSettings("screenlock")
        }
    }

    // TRK-1261 — this page writes the nested `power` object; the object is the setting.
    SetResetRow {
        what: qsTr("Keep awake")
        keys: ["power"]
    }
}
