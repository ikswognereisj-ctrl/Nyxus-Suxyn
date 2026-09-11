pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ Devices ▸ Bluetooth.   MODULE 3.
//
// Backend: BlueZ, through Quickshell.Bluetooth. Not bluetoothctl and not
// blueman. Device lists are ice plates, not name/state/button spreadsheet
// rows. Forget is magma (pairing keys go).
import Quickshell
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    property var entry: null

    title: "Bluetooth"
    blurb: qsTr("Pair, connect and forget devices, and see what is in range.")

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool hasAdapter: page.adapter !== null
    readonly property bool on: page.hasAdapter && page.adapter.enabled

    readonly property var devices: {
        var out = [];
        if (!page.on)
            return out;
        var a = page.adapter;
        var list = a.devices ? (a.devices.values || a.devices) : null;
        if (!list || !list.length)
            return out;
        for (var i = 0; i < list.length; ++i) {
            var d = list[i];
            if (!d || !Sys.btLabel(d))
                continue;
            out.push(d);
        }
        out.sort(function (x, y) {
            var rx = (x.connected ? 0 : (x.paired ? 1 : 2));
            var ry = (y.connected ? 0 : (y.paired ? 1 : 2));
            if (rx !== ry) return rx - ry;
            return String(Sys.btLabel(x)).localeCompare(String(Sys.btLabel(y)));
        });
        return out;
    }

    readonly property var paired: page.devices.filter(function (d) { return d.paired; })
    readonly property var nearby: page.devices.filter(function (d) { return !d.paired; })

    function batteryText(d) {
        if (!d)
            return "";
        var b = d.battery;
        if (b === undefined || b === null)
            return "";
        var n = Number(b);
        if (!isFinite(n) || n <= 0)
            return "";
        if (n <= 1)
            n = n * 100;
        return Math.round(n) + "%";
    }

    function setScanning(v) {
        if (!page.on)
            return;
        if (page.adapter.discovering !== undefined)
            page.adapter.discovering = v;
        else if (page.adapter.discovery !== undefined)
            page.adapter.discovery = v;
        if (v)
            scanStop.restart();
    }

    readonly property bool scanning: page.on
        && (page.adapter.discovering === true || page.adapter.discovery === true)

    LiveMark { id: radioMark; visible: false; actual: page.on }
    LiveMark { id: discMark; visible: false; actual: page.on && page.adapter && page.adapter.discoverable === true }
    LiveMark { id: btActMark; visible: false; actual: page.actDev ? !!page.actDev.connected : false }
    property var actDev: null

    Timer {
        id: scanStop
        interval: 30000
        repeat: false
        onTriggered: page.setScanning(false)
    }

    Component.onDestruction: if (page.scanning) page.setScanning(false)

    // ── open it and it looks ────────────────────────────────────────────────
    // Owner: "where it will actually bring up bluewtooth devies like a regular
    // sysatem would do". Every mainstream Bluetooth panel begins discovery on
    // open; this one waited for the Scan button, so it always greeted you with
    // an empty list and "No devices in range".
    //
    // ⚠ DEFERRED BY A BEAT, deliberately. At Component.onCompleted the adapter
    // is frequently not resolved yet (`Bluetooth.defaultAdapter` is still
    // null), so calling setScanning() there is a silent no-op -- which would
    // look exactly like the bug being fixed.
    Timer {
        id: autoScan
        interval: 500
        repeat: false
        onTriggered: if (page.on && !page.scanning) page.setScanning(true)
    }
    Component.onCompleted: autoScan.start()
    // and again if he switches the adapter on while the page is already up
    onOnChanged: if (page.on && !page.scanning) autoScan.restart()

    SetCard {
        heading: qsTr("Bluetooth")
        tone: page.tone
        note: !page.hasAdapter
              ? qsTr("No Bluetooth adapter is present on this machine.")
              : ""

        SetRow {
            title: qsTr("Bluetooth")
            sub: page.hasAdapter
                 ? (page.on ? qsTr("This machine can connect to devices") : qsTr("Radio off"))
                 : ""
            available: page.hasAdapter
            unavailableReason: qsTr("Unavailable")

            SetSwitch {
                tone: page.tone
                checked: page.on
                pending: radioMark.pending
                failed: radioMark.failed
                onToggled: function (v) {
                    radioMark.request(v);
                    if (page.adapter)
                        page.adapter.enabled = v;
                }
            }
        }

        SetRow {
            title: qsTr("Visible to other devices")
            sub: qsTr("Lets phones nearby find this machine. Turn it off once pairing is done.")
            available: page.on
            unavailableReason: qsTr("Bluetooth is off")

            SetSwitch {
                tone: page.tone
                checked: page.on && page.adapter.discoverable === true
                pending: discMark.pending
                failed: discMark.failed
                onToggled: function (v) {
                    discMark.request(v);
                    if (page.on && page.adapter.discoverable !== undefined)
                        page.adapter.discoverable = v;
                }
            }
        }
    }

    SetCard {
        heading: qsTr("Your devices")
        tone: page.tone

        SetRow {
            visible: page.paired.length === 0
            title: qsTr("Paired devices")
            sub: page.on ? qsTr("Nothing is paired yet — scan below to find a device, then pair it.")
                         : qsTr("Bluetooth is off")
        }

        Repeater {
            model: page.paired
            delegate: SetRow {
                id: pd
                required property var modelData

                title: Sys.btLabel(pd.modelData)
                sub: {
                    var bits = [Sys.btState(pd.modelData)];
                    if (pd.modelData.address)
                        bits.push(String(pd.modelData.address));
                    return bits.join(" · ");
                }
                valueText: page.batteryText(pd.modelData)

                RowLayout {
                    spacing: Theme.s4

                    StatusPip {
                        Layout.alignment: Qt.AlignVCenter
                        kind: page.actDev === pd.modelData
                              ? (btActMark.failed ? "amber" : (btActMark.pending ? "ice" : "off"))
                              : "off"
                        pulse: page.actDev === pd.modelData && (btActMark.pending || btActMark.failed)
                    }

                    // ── TRK-2935 · DISCONNECT IS A DANGER CASE ──────────
                    // `SetButton.qml`'s own header defines `danger` as "the
                    // action destroys something OR INTERRUPTS THE SESSION",
                    // and cutting a live Bluetooth link is the second one
                    // literally: the headphones you are listening through,
                    // the keyboard you are typing on. Its sibling "Forget"
                    // was already `danger: true` while this one — which is
                    // what you actually reach for by mistake, since it sits
                    // first and reads milder — painted like a safe button.
                    //
                    // The flag FOLLOWS `connected`, because this is one
                    // button wearing two actions. Connecting a device is not
                    // destructive and must not be armed; disconnecting is
                    // both. So the magma appears exactly when the label says
                    // "Disconnect" and not a moment otherwise.
                    SetButton {
                        text: pd.modelData.connected ? qsTr("Disconnect") : qsTr("Connect")
                        glyph: ""
                        tone: page.tone
                        danger: !!pd.modelData.connected
                        confirmText: qsTr("Disconnect %1").arg(Sys.btLabel(pd.modelData))
                        onClicked: {
                            page.actDev = pd.modelData;
                            btActMark.request(!pd.modelData.connected);
                            Sys.btActivate(pd.modelData);
                        }
                    }

                    SetButton {
                        text: qsTr("Forget")
                        glyph: ""
                        danger: true
                        confirmText: "Forget " + Sys.btLabel(pd.modelData)
                        onClicked: {
                            var d = pd.modelData;
                            if (d.forget) d.forget();
                            else if (d.remove) d.remove();
                            else console.warn("Bluetooth: this Quickshell build exposes "
                                              + "no forget/remove on a device.");
                        }
                    }
                }
            }
        }
    }

    SetCard {
        heading: qsTr("Nearby")
        tone: page.tone
        note: qsTr("Scanning stops on its own after thirty seconds — it costs radio ")
              + "time and makes the list move while you are reading it."

        SetRow {
            title: page.scanning ? qsTr("Scanning") : qsTr("Scan")
            sub: page.scanning ? qsTr("Put the device into pairing mode now")
                                : qsTr("Finds anything in range that is advertising itself")
            available: page.on
            unavailableReason: qsTr("Bluetooth is off")

            SetButton {
                text: page.scanning ? qsTr("Stop") : qsTr("Scan")
                glyph: ""
                tone: page.tone
                onClicked: page.setScanning(!page.scanning)
            }
        }

        SetRow {
            visible: page.nearby.length === 0 && page.on && !page.scanning
            title: qsTr("In range")
            sub: qsTr("Nothing advertising. Put the device in pairing mode, then Scan.")
        }

        Repeater {
            model: page.nearby
            delegate: SetRow {
                id: nd
                required property var modelData

                title: Sys.btLabel(nd.modelData)
                sub: nd.modelData.address ? String(nd.modelData.address) : ""

                SetButton {
                    text: qsTr("Pair")
                    glyph: ""
                    tone: page.tone
                    onClicked: Sys.btActivate(nd.modelData)
                }
            }
        }
    }

    SetCard {
        heading: qsTr("Devices")
        tone: page.tone
        note: qsTr("Wi-Fi, sound, displays, printers — the same Devices story.")

        SetRow {
            title: qsTr("Wi-Fi")
            sub: qsTr("Scan, join, forget")
            navigates: true
            onActivated: Bus.openSettings("network")
        }
        SetRow {
            title: qsTr("Sound")
            sub: qsTr("Default output — tap a stone, no terminal")
            navigates: true
            onActivated: Bus.openSettings("sound")
        }
        SetRow {
            title: qsTr("Display")
            sub: qsTr("Monitors and Night Light")
            navigates: true
            onActivated: Bus.openSettings("display")
        }
        SetRow {
            title: qsTr("Printers & scanners")
            navigates: true
            onActivated: Bus.openSettings("printers")
        }
    }
}
