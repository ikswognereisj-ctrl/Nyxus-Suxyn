pragma Singleton
// Nyxus Suxyn — Wi-Fi, wired and Bluetooth connect/disconnect, once and
// quietly.
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
    // ── TRK-4135 · the wire ──────────────────────────────────────────
    // Owner, 2026-09-14: "do i have notifcations for like when wifi
    // bluetooth connect or disconnect or when i plug my phone in or lose
    // network or it comes back".
    //
    // Wi-Fi, Bluetooth, USB and battery all already announced. The wire
    // did not — this file was Wi-Fi-only for anything network-shaped, so
    // pulling the ethernet cable was the one connectivity event on the
    // machine that happened in total silence. SetPageNetwork has known
    // about wired devices the whole time (`wiredDevs`, `wiredLabel`);
    // nothing ever turned that knowledge into a card.
    readonly property bool notifyWired: SettingsStore.boolValue("notify_wired", true)

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

    // TRK-4135 — the wire. Same three-part shape as Bluetooth above: a
    // fingerprint to change off, a primed flag so login is silent, and a
    // map of what was connected last time so a swap is two cards and not
    // a count that happens to match.
    property bool wiredPrimed: false
    property var lastWired: ({})

    // Every WIRED device NetworkManager knows, keyed by interface.
    // Interface name, not the display label: `enp5s0` is stable across a
    // rename and is what tells two docks apart.
    //
    // ⚠ `type === Wired`, NOT `type !== Wifi`. DeviceType has three values
    // — None, Wifi, Wired — so the negative form also catches None, which
    // is where anything virtual lands. `nmcli device` on this machine
    // lists lo, tailscale0 and p2p-dev-wlan0 next to the real enp2s0, and
    // announcing the loopback coming up is not a feature.
    //
    // Checked rather than assumed: Quickshell's Networking.devices does
    // NOT surface those three. The Network settings page uses the negative
    // form and renders exactly one ETHERNET card (enp2s0), so it is not
    // carrying a latent bug. The positive test is still the right one here
    // — it is correct because of what it asks for, not because of what the
    // backend currently happens to hand us.
    // Keyed by the device's own name (`enp2s0`), which is the interface —
    // stable across a relabel and what tells two docks apart.
    //
    // ⚠ NOT `d.interface`. The first cut of this read that, NetworkDevice
    // has no such property, so every lookup was undefined, the map came
    // back empty and no wired card could ever fire. It was caught by
    // pulling the cable and watching nothing happen, which is the only
    // reason to test a notification by actually causing the event.
    // NetworkDevice exposes: type, name, networks, address, connected,
    // state, nmManaged, autoconnect.
    function _wiredMap() {
        var map = {};
        var devs = Networking.devices ? Networking.devices.values : [];
        for (var i = 0; i < devs.length; i++) {
            var d = devs[i];
            if (!d || d.type !== DeviceType.Wired)
                continue;
            var iface = String(d.name || "");
            if (!iface)
                continue;
            map[iface] = { name: iface, connected: !!d.connected };
        }
        return map;
    }

    readonly property string wiredSig: {
        var map = watch._wiredMap();
        var parts = [];
        for (var k in map)
            parts.push(k + ":" + (map[k].connected ? "1" : "0"));
        parts.sort();
        return parts.join("|");
    }

    function _evaluateWired() {
        var now = watch._wiredMap();

        // First reading is the state the machine was already in — same
        // rule as Wi-Fi and Bluetooth. Logging in on a cable that never
        // moved is not an event.
        if (!watch.wiredPrimed) {
            watch.lastWired = now;
            watch.wiredPrimed = true;
            return;
        }

        var before = watch.lastWired;
        watch.lastWired = now;

        if (!watch.notifyWired)
            return;

        for (var iface in now) {
            var was = before[iface];
            // A device that only just APPEARED and is already down is a
            // dock waking up, not an unplug. Announce it only when it is
            // carrying, so plugging in a hub does not fire "Unplugged"
            // for every port on it.
            if (!was) {
                if (now[iface].connected)
                    Sys.announce(iface, qsTr("Connected"), "Wired",
                                 "network-connectivity-established");
                continue;
            }
            if (was.connected === now[iface].connected)
                continue;
            if (now[iface].connected)
                Sys.announce(iface, qsTr("Connected"), "Wired",
                             "network-connectivity-established");
            else
                Sys.announce(iface, qsTr("Unplugged"), "Wired",
                             "network-connectivity-lost");
        }

        // Gone entirely — the adapter itself was pulled, not just the
        // cable. Only worth a card if it was carrying when it went.
        for (var old in before) {
            if (now[old] || !before[old].connected)
                continue;
            Sys.announce(old, qsTr("Disconnected"), "Wired",
                         "network-connectivity-lost");
        }
    }

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
    // TRK-4135 — a cable bounces: NetworkManager takes a device down,
    // brings it back up and re-IPs it, and each of those moves the
    // fingerprint. 600 ms folds that into one card, same as the other two.
    Timer {
        id: wiredSettle
        interval: 600
        repeat: false
        onTriggered: watch._evaluateWired()
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
    onWiredSigChanged: wiredSettle.restart()

    function start() {
        if (!watch.wifiPrimed)
            watch._evaluateWifi();
        if (!watch.btPrimed)
            watch._evaluateBt();
        if (!watch.wiredPrimed)
            watch._evaluateWired();
    }

    Component.onCompleted: watch.start()
}
