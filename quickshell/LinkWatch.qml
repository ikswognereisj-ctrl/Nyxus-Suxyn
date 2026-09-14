pragma Singleton
// Nyxus Suxyn — Wi-Fi and Bluetooth connect/disconnect, once and quietly.
//
// Same shape as UsbWatch / BatteryWatch: a shell singleton, because a
// Settings page is only alive while it is open. Sys.announce is the one
// door (DND, quiet hours, Toasts). Nothing here calls notify-send.
//
// First reading is the state the machine was ALREADY in. Login does not
// throw a card for the network you are on or the headphones that never
// left. Radio on/off is not an event — turning Wi-Fi or Bluetooth off in
// Settings must not toast, and must not cascade "disconnected" for every
// device the radio dropping takes with it.
//
// Signal strength, scan results, adapter toggles, and EasyEffects are
// not this file's business and must not grow into it.
import Quickshell
import Quickshell.Networking
import QtQuick

Singleton {
    id: watch

    readonly property bool notifyWifi: SettingsStore.boolValue("notify_wifi", true)
    readonly property bool notifyBt: SettingsStore.boolValue("notify_bluetooth", true)

    readonly property var wifiDev: {
        var devs = Networking.devices ? Networking.devices.values : [];
        for (var i = 0; i < devs.length; i++)
            if (devs[i] && devs[i].type === DeviceType.Wifi)
                return devs[i];
        return null;
    }
    readonly property int wifiState: watch.wifiDev ? watch.wifiDev.state
                                                   : ConnectionState.Unknown

    // Fingerprint of connected BT devices + radio. Count alone would miss
    // A dropping in the same tick B appears.
    readonly property string btSig: {
        if (!Sys.btOn)
            return "off";
        var parts = [];
        var all = Sys.btDevices;
        for (var i = 0; i < all.length; i++) {
            var d = all[i];
            if (!d || !d.connected)
                continue;
            parts.push(String(d.address || Sys.btLabel(d)));
        }
        parts.sort();
        return parts.join("|");
    }

    property bool wifiPrimed: false
    property bool lastWifiOn: false
    property string lastSsid: ""
    property int lastWifiState: ConnectionState.Unknown
    property string pendingSsid: ""
    property string lastFailKey: ""
    property real lastFailAt: 0

    property bool btPrimed: false
    property bool lastBtOn: false
    property var lastBtConnected: ({})

    function _ssidOf(name) {
        if (!name || name === "Off" || name === "On")
            return "";
        return String(name);
    }

    function _connectingName() {
        var d = watch.wifiDev;
        if (!d || !d.networks)
            return "";
        var nets = d.networks.values || [];
        for (var i = 0; i < nets.length; i++) {
            if (nets[i] && nets[i].state === ConnectionState.Connecting)
                return String(nets[i].name || "");
        }
        return "";
    }

    function _btMap() {
        var map = {};
        if (!Sys.btOn)
            return map;
        var all = Sys.btDevices;
        for (var i = 0; i < all.length; i++) {
            var d = all[i];
            if (!d || !d.connected)
                continue;
            var addr = String(d.address || Sys.btLabel(d));
            if (!addr)
                continue;
            map[addr] = {
                name: Sys.btLabel(d) || addr,
                audio: Sys.btIsAudio(d)
            };
        }
        return map;
    }

    function _evaluateWifi() {
        var on = Sys.wifiOn;
        var ssid = watch._ssidOf(Sys.wifiName);
        var st = watch.wifiState;

        if (st === ConnectionState.Connecting) {
            var trying = watch._connectingName();
            if (trying)
                watch.pendingSsid = trying;
        }

        if (!watch.wifiPrimed) {
            watch.lastWifiOn = on;
            watch.lastSsid = ssid;
            watch.lastWifiState = st;
            watch.wifiPrimed = true;
            if (ssid)
                watch.pendingSsid = "";
            return;
        }

        var radioFlipped = on !== watch.lastWifiOn;
        var prevSsid = watch.lastSsid;
        var prevSt = watch.lastWifiState;
        watch.lastWifiOn = on;
        watch.lastSsid = ssid;
        watch.lastWifiState = st;

        if (ssid)
            watch.pendingSsid = "";

        // Adapter toggle is a Settings action, not a connection event.
        if (radioFlipped)
            return;

        if (!watch.notifyWifi)
            return;

        if (ssid && ssid !== prevSsid) {
            Sys.announce(ssid, qsTr("Connected"), "Wi-Fi",
                         "network-connectivity-established");
            watch.lastFailKey = "";
            return;
        }

        if (!ssid && prevSsid && on) {
            Sys.announce(prevSsid, qsTr("Disconnected"), "Wi-Fi",
                         "network-connectivity-lost");
            return;
        }

        // Join that never landed. Same network retrying is one card.
        if (on && !ssid && prevSt === ConnectionState.Connecting
                && st === ConnectionState.Disconnected) {
            var who = watch.pendingSsid || qsTr("Wi-Fi");
            var key = "fail:" + who;
            var now = Date.now();
            if (key === watch.lastFailKey && now - watch.lastFailAt < 45000)
                return;
            watch.lastFailKey = key;
            watch.lastFailAt = now;
            Sys.announce(who, qsTr("Could not connect"), "Wi-Fi", "notification");
        }
    }

    function _evaluateBt() {
        var on = Sys.btOn;
        var now = watch._btMap();

        if (!watch.btPrimed) {
            watch.lastBtOn = on;
            watch.lastBtConnected = now;
            watch.btPrimed = true;
            return;
        }

        var radioFlipped = on !== watch.lastBtOn;
        var before = watch.lastBtConnected;
        watch.lastBtOn = on;
        watch.lastBtConnected = now;

        // Radio off empties the device list. That is not N disconnects.
        if (radioFlipped)
            return;

        if (!watch.notifyBt || !on)
            return;

        var k;
        for (k in now) {
            if (before[k])
                continue;
            var added = now[k];
            Sys.announce(added.name,
                         added.audio ? qsTr("Headphones connected")
                                     : qsTr("Connected"),
                         "Bluetooth", "device-added");
        }
        for (k in before) {
            if (now[k])
                continue;
            var gone = before[k];
            Sys.announce(gone.name,
                         gone.audio ? qsTr("Headphones disconnected")
                                    : qsTr("Disconnected"),
                         "Bluetooth", "device-removed");
        }
    }

    // 600 ms is long enough that a roam or a BlueZ connect burst is one
    // difference, short enough that the card still feels like the action.
    Timer {
        id: wifiSettle
        interval: 600
        repeat: false
        onTriggered: watch._evaluateWifi()
    }
    Timer {
        id: btSettle
        interval: 600
        repeat: false
        onTriggered: watch._evaluateBt()
    }

    Connections {
        target: Sys
        function onWifiNameChanged() { wifiSettle.restart(); }
        function onWifiOnChanged() { wifiSettle.restart(); }
        function onBtOnChanged() { btSettle.restart(); }
    }

    onWifiStateChanged: {
        if (watch.wifiState === ConnectionState.Connecting) {
            var n = watch._connectingName();
            if (n)
                watch.pendingSsid = n;
        }
        wifiSettle.restart();
    }
    onBtSigChanged: btSettle.restart()

    function start() {
        if (!watch.wifiPrimed)
            watch._evaluateWifi();
        if (!watch.btPrimed)
            watch._evaluateBt();
    }

    Component.onCompleted: watch.start()
}
