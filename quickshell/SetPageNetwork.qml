pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ Devices ▸ Wi-Fi.
//
// Quickshell.Networking for the radio and the scan list (same graph as the
// flyout). nmcli only for a NEW network's password, rescan, forget, and
// the IPv4 line. GUI fields, not a terminal. No NetworkManager secret
// agent (TRK-3114) — unknown SSIDs join from this page.
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    property var entry: null
    // TRK-3435: shipped-first PATH via `env`, never a shell. Ruling:
    // SetPageBackup.qml.
    readonly property string execPath: "PATH="
        + (Quickshell.env("NYXUS_BIN_DIR") || "/usr/local/bin")
        + ":" + Quickshell.env("PATH")

    title: qsTr("Wi-Fi")
    blurb: qsTr("Scan, join, and forget wireless networks. Ethernet is a fact on this page too.")

    property string joinName: ""
    property string joinPass: ""
    property string forgetName: ""
    property string lastNote: ""
    property string ipv4: ""
    property string linkSpeed: ""
    property string actSsid: ""
    property bool portal: false
    property string portalNote: ""

    LiveMark { id: wifiMark; visible: false; actual: Sys.wifiOn }
    LiveMark { id: netActMark; visible: false; actual: page.ssidConnected(page.actSsid) }

    property bool wifiLive: Sys.wifiOn
    onWifiLiveChanged: {
        if (page.wifiLive)
            ipProc.running = true;
        else {
            page.ipv4 = "";
            page.linkSpeed = "";
        }
    }

    function ssidConnected(name) {
        if (!name)
            return false;
        for (var i = 0; i < page.nets.length; ++i)
            if (String(page.nets[i].name) === name)
                return !!page.nets[i].connected;
        return false;
    }

    function linkBits(ip, speed) {
        var bits = [];
        if (ip)
            bits.push(ip);
        if (speed)
            bits.push(speed);
        return bits.length ? bits.join(" · ") : qsTr("On this machine now");
    }

    readonly property var wifiDevs: {
        var out = [];
        var devs = Networking.devices ? Networking.devices.values : [];
        for (var i = 0; i < devs.length; ++i)
            if (devs[i] && devs[i].type === DeviceType.Wifi)
                out.push(devs[i]);
        return out;
    }

    readonly property var wiredDevs: {
        var out = [];
        var devs = Networking.devices ? Networking.devices.values : [];
        for (var i = 0; i < devs.length; ++i)
            if (devs[i] && devs[i].type !== DeviceType.Wifi)
                out.push(devs[i]);
        return out;
    }

    readonly property var nets: {
        var out = [];
        for (var i = 0; i < page.wifiDevs.length; ++i) {
            var list = page.wifiDevs[i].networks
                       ? page.wifiDevs[i].networks.values : [];
            for (var j = 0; j < list.length; ++j)
                if (list[j] && list[j].name)
                    out.push(list[j]);
        }
        out.sort(function (a, b) {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (!!a.known !== !!b.known)
                return a.known ? -1 : 1;
            return (b.signalStrength || 0) - (a.signalStrength || 0);
        });
        return out;
    }

    readonly property var knownNets: page.nets.filter(function (n) {
        return n.connected || n.known;
    })
    readonly property var freshNets: page.nets.filter(function (n) {
        return !n.connected && !n.known;
    })

    // ── audit-0908 · TWO SOURCES, TWO UNITS, ONE FORMAT STRING ──────────
    //
    // Quickshell's Networking module reports `signalStrength` as a FRACTION
    // on 0–1. nmcli's SIGNAL column is an INTEGER on 0–100. Both were being
    // rendered with `signalStrength + "%"`, so the connected network — the
    // one row anybody actually looks at — read **"0.78%"** on the owner's
    // screen while `nmcli … dev wifi list` said `Yourmom.com:100`.
    //
    // Normalise here, at the single place the number is read, and decide by
    // the entry's ORIGIN, never by guessing from the value: 1 is a legal
    // reading in both units (1% and 100%), so no threshold can tell them
    // apart. Any entry this page synthesises from nmcli must stamp
    // `sigUnit: "pct"` on itself; anything without that stamp came from the
    // module and is a fraction.
    function sigPct(n) {
        if (!n)
            return -1;
        var v = Number(n.signalStrength);
        if (!isFinite(v) || v < 0)
            return -1;
        var p = Math.round(n.sigUnit === "pct" ? v : v * 100);
        return p > 100 ? 100 : p;
    }

    function sigText(n) {
        var p = page.sigPct(n);
        return p >= 0 ? (p + "%") : "";
    }

    function wiredLabel(d) {
        if (!d)
            return qsTr("Wired");
        if (d.connected)
            return qsTr("Connected");
        return qsTr("Unplugged");
    }

    Process {
        id: joiner
        running: false
        command: ["nmcli", "device", "wifi", "connect", page.joinName, "password", page.joinPass]
        onExited: function (code) {
            page.joinPass = "";
            if (code === 0) {
                page.lastNote = qsTr("Connected to %1").arg(page.joinName);
                page.joinName = "";
                ipProc.running = true;
            } else {
                page.lastNote = qsTr("Could not join — wrong password, or NetworkManager refused.");
                netActMark.fail();
            }
        }
    }

    Process {
        id: forgetter
        running: false
        command: ["nmcli", "connection", "delete", "id", page.forgetName]
        onExited: function (code) {
            page.lastNote = code === 0
                ? qsTr("Forgot %1").arg(page.forgetName)
                : qsTr("Could not forget that network.");
            page.forgetName = "";
        }
    }

    Process {
        id: rescan
        running: false
        command: ["nmcli", "device", "wifi", "rescan"]
        onExited: function (code) {
            if (code !== 0)
                page.lastNote = qsTr("Rescan did not run (no Wi-Fi device, or nmcli refused).");
        }
    }

    Process {
        id: ipProc
        running: false
        // audit-0908 · THE LOOPBACK BUG. `nmcli -t -f a,b,c device show` prints
        // the fields in the order `-f` ASKS for them, not in block-header
        // order, so GENERAL.TYPE arrives AFTER the IP4.ADDRESS it describes:
        //
        //     IP4.ADDRESS[1]:192.168.0.197/24
        //     GENERAL.CONNECTION:Yourmom.com
        //     GENERAL.TYPE:wifi
        //
        //     IP4.ADDRESS[1]:127.0.0.1/8
        //     GENERAL.CONNECTION:lo
        //     GENERAL.TYPE:loopback
        //
        // The old line-at-a-time `w` flag therefore lagged one device — wlan0's
        // address was read while w was still 0, the wifi line then set w=1, and
        // the LOOPBACK's address is what got printed. Measured on the owner's
        // machine 2026-09-08: old program → 127.0.0.1, this one → 192.168.0.197.
        //
        // Read whole device BLOCKS (awk paragraph mode) so the type and the
        // address are looked at together, and never trust field order again.
        // The type test is an exact string compare so `wifi-p2p` cannot match.
        command: ["sh", "-c",
            // Measured 2026-09-10: GENERAL.SPEED is not a `device show` field
            // (nmcli rejects the whole -f list, so IPv4 went blank too).
            // CAPABILITIES.SPEED is the link readout this nmcli actually has.
            'nmcli -t -f IP4.ADDRESS,GENERAL.CONNECTION,CAPABILITIES.SPEED,GENERAL.TYPE device show 2>/dev/null '
          + '| awk \'BEGIN { RS = ""; FS = "\\n" } '
          + '{ t = ""; a = ""; s = ""; '
          + 'for (i = 1; i <= NF; i++) { '
          + 'if ($i == "GENERAL.TYPE:wifi") t = "wifi"; '
          + 'if (a == "" && $i ~ /^IP4\\.ADDRESS/) '
          + '{ a = $i; sub(/^[^:]*:/, "", a); sub(/\\/.*$/, "", a) } '
          + 'if (s == "" && $i ~ /^CAPABILITIES\\.SPEED/) '
          + '{ s = $i; sub(/^[^:]*:/, "", s) } } '
          + 'if (t == "wifi" && a != "") { print a "\\t" s; exit } }\'']
        stdout: StdioCollector {
            onStreamFinished: {
                var line = String(this.text).trim();
                var tab = line.indexOf("\t");
                if (tab < 0) {
                    page.ipv4 = line;
                    page.linkSpeed = "";
                    return;
                }
                page.ipv4 = line.slice(0, tab);
                var sp = line.slice(tab + 1).trim();
                if (sp === "" || sp === "unknown" || sp === "0"
                        || sp === "0 Mb/s" || sp === "0 Mbit/s")
                    sp = "";
                page.linkSpeed = sp;
            }
        }
    }

    Process {
        id: portalProbe
        running: false
        command: ["env", page.execPath, "nyxus-portal-watch", "--json"]   // TRK-3435
        stdout: StdioCollector {
            onStreamFinished: {
                var raw = String(this.text || "").trim();
                try {
                    var d = JSON.parse(raw);
                    page.portal = !!(d.portal || d.state === "PORTAL"
                                     || d.connectivity === "PORTAL");
                } catch (e) {
                    page.portal = false;
                }
            }
        }
    }

    Process {
        id: portalOpen
        running: false
        command: ["env", page.execPath, "nyxus-portal-watch", "--open"]   // TRK-3435
        onExited: function (code) {
            page.portalNote = code === 0
                              ? qsTr("Opened the sign-in page")
                              : qsTr("Could not open the sign-in page");
            portalProbe.running = true;
        }
    }

    Component.onCompleted: {
        ipProc.running = true;
        portalProbe.running = true;
    }

    SetCard {
        heading: qsTr("Sign in to this network")
        tone: page.tone
        visible: page.portal
        note: qsTr("Hotel and cafe Wi-Fi can look connected until you sign in on a page. This opens that page. It never opens a browser by itself.")

        SetIceFace {
            kicker: qsTr("PORTAL")
            reading: qsTr("NEEDED")
            caption: qsTr("This network is waiting for a sign-in")
            selected: true
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4

            SetButton {
                text: qsTr("Sign in…")
                tone: page.tone
                busy: portalOpen.running
                enabled: !portalOpen.running
                onClicked: portalOpen.running = true
            }
        }

        SetIceFace {
            visible: page.portalNote !== ""
            compact: true
            kicker: qsTr("NOTE")
            caption: page.portalNote
        }
    }

    SetCard {
        heading: qsTr("This machine")
        tone: page.tone
        note: page.wiredDevs.length === 0 && !Sys.hasWifi
              ? qsTr("No network devices reported.")
              : qsTr("Wi-Fi is the same radio the flyout toggles.")

        Repeater {
            model: page.wiredDevs
            delegate: SetIceFace {
                required property var modelData
                compact: true
                kicker: qsTr("ETHERNET")
                reading: page.wiredLabel(modelData)
                caption: String(modelData.name || modelData.iface || qsTr("Wired"))
                detail: modelData.connected && Sys.netKind !== "wifi" && Sys.netLinkMbps > 0
                        ? Sys.netLinkText : ""
                selected: !!modelData.connected
            }
        }

        SetIceFace {
            visible: page.wiredDevs.length === 0
            compact: true
            kicker: qsTr("ETHERNET")
            caption: qsTr("No wired interface")
        }

        SetIceFace {
            kicker: qsTr("WI-FI")
            reading: !Sys.hasWifi ? qsTr("None") : (Sys.wifiOn ? qsTr("On") : qsTr("Off"))
            caption: !Sys.hasWifi
                     ? qsTr("No wireless adapter")
                     : (Sys.wifiOn
                        ? (page.ipv4 !== ""
                           ? qsTr("On this machine · %1").arg(page.linkBits(page.ipv4, page.linkSpeed))
                           : qsTr("Scanning and connecting"))
                        : qsTr("Radio off"))
            selected: Sys.hasWifi && Sys.wifiOn
            interactive: Sys.hasWifi
            attention: wifiMark.pending || wifiMark.failed
            onActivated: {
                if (!Sys.hasWifi)
                    return;
                wifiMark.request(!Sys.wifiOn);
                Sys.toggleWifi();
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            visible: Sys.hasWifi && Sys.wifiOn

            SetButton {
                text: qsTr("Rescan")
                tone: page.tone
                busy: rescan.running
                enabled: !rescan.running
                onClicked: rescan.running = true
            }
        }
    }

    SetCard {
        heading: qsTr("Known networks")
        tone: page.tone
        visible: Sys.hasWifi && Sys.wifiOn
        note: qsTr("Tap a saved plate to connect or disconnect. Forget drops the remembered password.")

        SetIceFace {
            visible: page.knownNets.length === 0
            compact: true
            kicker: qsTr("SAVED")
            caption: qsTr("Nothing remembered yet")
            detail: qsTr("Join a network below and it will appear here.")
        }

        Repeater {
            model: page.knownNets
            delegate: ColumnLayout {
                id: kn
                required property var modelData
                Layout.fillWidth: true
                spacing: Theme.s2

                SetIceFace {
                    Layout.fillWidth: true
                    compact: true
                    // TRK-3428: connected = the FILLED GROUND, the build's
                    // own state language — the word alone did not read.
                    // TRK-3506: `selected` was bound TWICE on this object (here
                    // and again below `fillPct`). QML does not merge duplicate
                    // bindings, it rejects the whole object — which made the
                    // TYPE unavailable, so Settings > Wi-Fi loaded nothing at
                    // all and clicking it in the sidebar showed an empty page.
                    // The `!!` coercion from the duplicate is kept here, so the
                    // rendered state is unchanged; only the second binding goes.
                    selected: !!kn.modelData.connected
                    kicker: kn.modelData.connected ? qsTr("CONNECTED") : qsTr("SAVED")
                    reading: page.sigText(kn.modelData)
                    caption: String(kn.modelData.name)
                    detail: kn.modelData.connected
                            ? page.linkBits(page.ipv4, page.linkSpeed)
                            : qsTr("Password remembered")
                    fillPct: page.sigPct(kn.modelData)
                    interactive: true
                    attention: (netActMark.pending || netActMark.failed)
                               && page.actSsid === String(kn.modelData.name)
                    onActivated: {
                        page.actSsid = String(kn.modelData.name);
                        netActMark.request(!kn.modelData.connected);
                        if (kn.modelData.connected)
                            kn.modelData.disconnect();
                        else
                            kn.modelData.connect();
                        ipProc.running = true;
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.s4
                    Layout.rightMargin: Theme.s4
                    visible: !!kn.modelData.known || !!kn.modelData.connected

                    SetButton {
                        text: qsTr("Forget")
                        danger: true
                        confirmText: qsTr("Forget %1").arg(String(kn.modelData.name))
                        tone: page.tone
                        busy: forgetter.running && page.forgetName === String(kn.modelData.name)
                        onClicked: {
                            page.forgetName = String(kn.modelData.name);
                            forgetter.command = ["nmcli", "connection", "delete", "id", page.forgetName];
                            forgetter.running = true;
                        }
                    }
                }
            }
        }
    }

    SetCard {
        heading: qsTr("Available")
        tone: page.tone
        visible: Sys.hasWifi && Sys.wifiOn
        note: qsTr("A new network asks for the password here, and NetworkManager keeps it for next time.")

        Repeater {
            model: page.freshNets
            delegate: SetIceFace {
                required property var modelData
                compact: true
                kicker: qsTr("AVAILABLE")
                reading: page.sigText(modelData)
                caption: String(modelData.name)
                detail: qsTr("Needs password")
                fillPct: page.sigPct(modelData)
                interactive: true
                onActivated: page.joinName = String(modelData.name)
            }
        }

        SetIceFace {
            visible: page.freshNets.length === 0 && page.nets.length === 0
            compact: true
            kicker: qsTr("SCAN")
            caption: qsTr("Looking for networks…")
            attention: rescan.running
        }

        SetIceFace {
            visible: page.freshNets.length === 0 && page.nets.length > 0
            compact: true
            kicker: qsTr("IN RANGE")
            caption: qsTr("Everything in range is already saved, or the scan is quiet.")
        }
    }

    SetCard {
        heading: qsTr("Join a network")
        tone: page.tone
        visible: page.joinName !== ""
        note: qsTr("Password stays in this window. nmcli is the backend, not the UI.")

        SetIceFace {
            kicker: qsTr("JOIN")
            caption: page.joinName
            detail: qsTr("Network password")
            attention: (netActMark.pending || netActMark.failed)
                       && page.actSsid === page.joinName
        }

        TextInput {
            id: pw
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            Layout.preferredHeight: 28
            echoMode: TextInput.Password
            color: Theme.text
            font.family: Theme.fUi
            font.pixelSize: Theme.tLabel
            text: page.joinPass
            onTextChanged: page.joinPass = text
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            spacing: Theme.s3

            SetButton {
                text: qsTr("Connect")
                tone: page.tone
                busy: joiner.running
                enabled: page.joinPass.length > 0 && !joiner.running
                onClicked: {
                    page.actSsid = page.joinName;
                    netActMark.request(true);
                    joiner.running = true;
                }
            }
            SetButton {
                text: qsTr("Cancel")
                tone: page.tone
                onClicked: { page.joinName = ""; page.joinPass = ""; }
            }
        }
    }

    SetCard {
        heading: qsTr("Also on this machine")
        tone: page.tone

        SetRow {
            title: qsTr("Firewall")
            sub: qsTr("Inbound policy — same switch as Security")
            navigates: true
            onActivated: Bus.openSettings("firewall")
        }
        SetRow {
            title: qsTr("Bluetooth")
            navigates: true
            onActivated: Bus.openSettings("bluetooth")
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
            title: qsTr("USB & removable")
            sub: qsTr("Mount, eject, automount")
            navigates: true
            onActivated: Bus.openSettings("usb")
        }
        SetRow {
            title: qsTr("Printers & scanners")
            navigates: true
            onActivated: Bus.openSettings("printers")
        }

        SetIceFace {
            visible: page.lastNote !== ""
            compact: true
            kicker: qsTr("NOTE")
            caption: page.lastNote
        }
    }
}
