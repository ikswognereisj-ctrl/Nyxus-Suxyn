pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ Privacy & security ▸ Security.
//
// Product pass 2026-08-26: group by TASK (sign-in, this disk, firmware,
// who may reach the machine, scan) not by helper filename. HEMERA scan
// and the four nyxus-secure switches stay the live apply paths. Secure
// Boot / TPM / LUKS are reports. Fingerprint and Howdy are reports —
// there is no glass enrol UI (TRK-3129 / TRK-3117). Lock now is
// nyxus-lock-guard, the same command the shelf menu uses. Idle lock
// delay stays hypridle 600 s (TRK-3126) — that slider is not here.
//
// Ships from shell/ only (QS_SRC).
import Quickshell
import Quickshell.Io
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

    title: qsTr("Security")
    blurb: qsTr("Lock this session, see what the firmware reports, and what may reach the machine.")

    readonly property color iceOn: Theme.paintLayers.glacier[5]
    readonly property color iceHair: Theme.paintLayers.glacier[4]

    property var posture: ({})
    property var hemera: ({})
    property var vault: []
    property var history: []
    property bool hemeraPresent: false
    property string applySpec: ""
    property string vaultAction: ""
    property string vaultId: ""
    property string lastNote: ""
    property string fpState: ""
    property string fpNote: ""
    property string howdyState: ""

    readonly property var ringNames: [
        { id: "firewall",   label: qsTr("Firewall") },
        { id: "apparmor",   label: qsTr("System Shield") },
        { id: "snapshots",  label: qsTr("Restore points") },
        { id: "updates",    label: qsTr("Updates") },
        { id: "scan",       label: qsTr("Recent scan") },
        { id: "quarantine", label: qsTr("Quarantine") }
    ]

    readonly property var ringOn: {
        var d = page.posture;
        var h = page.hemera;
        var v = {};
        v.firewall = d.fw === "on";
        v.apparmor = d.aa === "on" || d.aaSys === "Y";
        v.snapshots = d.snapKnown === "1" && d.snapLatest !== "";
        var days = d.upgradeDays === "" ? NaN : Number(d.upgradeDays);
        v.updates = !isNaN(days) && days <= 14;
        var sdays = h.scanDays;
        v.scan = (typeof sdays === "number" && sdays <= 14);
        v.quarantine = Number(h.awaiting || 0) === 0 && page.hemeraPresent;
        return v;
    }

    readonly property int ringStanding: {
        var n = 0;
        var v = page.ringOn;
        for (var i = 0; i < page.ringNames.length; ++i)
            if (v[page.ringNames[i].id])
                ++n;
        return n;
    }

    readonly property int ringTotal: page.ringNames.length

    readonly property string sbCaption: {
        if (page.posture.efi !== "1")
            return qsTr("This firmware has no EFI variables to read");
        if (page.posture.sb === "1")
            return qsTr("The firmware reports Secure Boot is on");
        if (page.posture.sb === "0")
            return qsTr("The firmware reports Secure Boot is off");
        return qsTr("Could not read the SecureBoot variable");
    }

    function refresh() {
        postureProc.running = true;
        hemeraProc.running = true;
        vaultProc.running = true;
        histProc.running = true;
        signinProc.running = true;
    }

    function applySecure(spec) {
        page.applySpec = spec;
        page.lastNote = "";
        // TRK-3435: pkexec resolves the program through the caller's PATH.
        secureApply.command = ["env", page.execPath,
                               "pkexec", "nyxus-secure", "apply", spec];
        secureApply.running = true;
    }

    function doVault(act, id) {
        page.vaultAction = act;
        page.vaultId = id;
        vaultDo.command = ["env", page.execPath,   // TRK-3435
                           "nyxus-hemera", "vault", act, id];
        vaultDo.running = true;
    }

    Component.onCompleted: page.refresh()

    Process {
        id: postureProc
        running: false
        command: ["sh", "-c",
            'PATH="${NYXUS_BIN_DIR:-/usr/local/bin}:$PATH"\n'   // TRK-3435
          + 'emit() { printf "%s\\t%s\\n" "$1" "$2"; }\n'
          + 'if command -v nyxus-secure >/dev/null 2>&1; then\n'
          + '  nyxus-secure status 2>/dev/null | while IFS= read -r ln; do\n'
          + '    k=${ln%%=*}; v=${ln#*=}; emit "sec.$k" "$v"; done\n'
          + 'else emit sec.missing 1; fi\n'
          + 'aa=/sys/module/apparmor/parameters/enabled\n'
          + 'if [ -r "$aa" ]; then emit aa.sysfs "$(tr -d "\\n" < "$aa")"; else emit aa.sysfs n; fi\n'
          + 'if command -v snapper >/dev/null 2>&1; then\n'
          + '  out=$(snapper --no-headers -c root list --columns number,date 2>/dev/null) || out=""\n'
          + '  if [ -n "$out" ]; then\n'
          + '    emit snap.known 1\n'
          + '    last=$(printf "%s\\n" "$out" | grep -E -- "-" | tail -1)\n'
          + '    emit snap.latest "$last"\n'
          + '  else emit snap.known 0; emit snap.latest ""; fi\n'
          + 'else emit snap.known 0; emit snap.latest ""; fi\n'
          + 'up=$(grep -E "starting full system upgrade" /var/log/pacman.log 2>/dev/null | tail -1)\n'
          + 'emit upgrade.line "$up"\n'
          + 'if [ -d /sys/class/tpm/tpm0 ]; then emit tpm 1; else emit tpm 0; fi\n'
          + 'if [ -d /sys/firmware/efi ]; then emit efi 1; else emit efi 0; fi\n'
          + 'luks=$(lsblk -o FSTYPE -n 2>/dev/null | grep -c crypto_LUKS || true)\n'
          + 'emit luks "$luks"\n'
          + 'if [ -r /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c ]; then\n'
          + '  sb=$(od -An -t u1 /sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c 2>/dev/null | awk "{print \\$NF}")\n'
          + '  emit sb "$sb"\n'
          + 'else emit sb ""; fi\n'
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var d = {
                    fw: "off", aa: "off", dns: "off", mac: "off",
                    aaSys: "n", snapKnown: "0", snapLatest: "",
                    upgradeDays: "", tpm: "0", efi: "0", luks: "0", sb: ""
                };
                var lines = String(this.text).split("\n");
                for (var i = 0; i < lines.length; ++i) {
                    var t = lines[i].indexOf("\t");
                    if (t < 0) continue;
                    var k = lines[i].slice(0, t);
                    var v = lines[i].slice(t + 1);
                    if (k === "sec.firewall") d.fw = v;
                    else if (k === "sec.apparmor") d.aa = v;
                    else if (k === "sec.dns") d.dns = v;
                    else if (k === "sec.macrandom") d.mac = v;
                    else if (k === "aa.sysfs") d.aaSys = v;
                    else if (k === "snap.known") d.snapKnown = v;
                    else if (k === "snap.latest") d.snapLatest = v;
                    else if (k === "tpm") d.tpm = v;
                    else if (k === "efi") d.efi = v;
                    else if (k === "luks") d.luks = v;
                    else if (k === "sb") d.sb = v;
                    else if (k === "upgrade.line") {
                        var m = v.match(/^\[([^\]]+)\]/);
                        if (m) {
                            var ts = Date.parse(m[1].slice(0, 19));
                            if (!isNaN(ts))
                                d.upgradeDays = String(Math.max(0,
                                    Math.floor((Date.now() - ts) / 86400000)));
                        }
                    }
                }
                page.posture = d;
            }
        }
    }

    Process {
        id: signinProc
        running: false
        command: ["sh", "-c",
            'emit() { printf "%s\\t%s\\n" "$1" "$2"; }\n'
          + 'u=$(id -un 2>/dev/null)\n'
          + 'if ! command -v fprintd-list >/dev/null 2>&1; then\n'
          + '  emit fp none; emit fp.note "No fingerprint service on this image"\n'
          + 'else\n'
          + '  out=$(fprintd-list "$u" 2>&1) || true\n'
          + '  low=$(printf "%s" "$out" | tr "A-Z" "a-z")\n'
          + '  if printf "%s" "$low" | grep -q "no devices available\\|did not find"; then\n'
          + '    emit fp noreader; emit fp.note "No fingerprint reader"\n'
          + '  elif printf "%s" "$low" | grep -q "failed to connect\\|no such file"; then\n'
          + '    emit fp none; emit fp.note "Fingerprint service is not running"\n'
          + '  elif printf "%s" "$out" | grep -qE "^[[:space:]]*-[[:space:]]*#"; then\n'
          + '    n=$(printf "%s" "$out" | grep -cE "^[[:space:]]*-[[:space:]]*#")\n'
          + '    emit fp enrolled; emit fp.note "$n enrolled — used at sign-in and lock, not from this page"\n'
          + '  else\n'
          + '    emit fp empty; emit fp.note "Reader present, none enrolled. Enrolment is on the sign-in surface, not here."\n'
          + '  fi\n'
          + 'fi\n'
          + 'if command -v howdy >/dev/null 2>&1; then\n'
          + '  emit howdy present\n'
          + 'else\n'
          + '  emit howdy missing\n'
          + 'fi\n'
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var fp = "";
                var note = "";
                var howdy = "missing";
                var lines = String(this.text).split("\n");
                for (var i = 0; i < lines.length; ++i) {
                    var t = lines[i].indexOf("\t");
                    if (t < 0) continue;
                    var k = lines[i].slice(0, t);
                    var v = lines[i].slice(t + 1);
                    if (k === "fp") fp = v;
                    else if (k === "fp.note") note = v;
                    else if (k === "howdy") howdy = v;
                }
                page.fpState = fp;
                page.fpNote = note;
                page.howdyState = howdy;
            }
        }
    }

    Process {
        id: hemeraProc
        running: false
        command: ["env", page.execPath, "nyxus-hemera", "status", "--json"]   // TRK-3435
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    page.hemeraPresent = true;
                    var vault = j.vault || {};
                    var last = j.last_scan || {};
                    var sdays = null;
                    var fin = last.finished;
                    if (typeof fin === "number" && fin > 0
                            && (last.result === "clean" || last.result === "partial"
                                || last.result === "findings"))
                        sdays = Math.max(0, Math.floor((Date.now() / 1000 - fin) / 86400));
                    page.hemera = {
                        awaiting: vault.awaiting_decision || 0,
                        scanner: !!j.scanner,
                        defs: (j.definitions || {}),
                        last: last,
                        scanDays: sdays
                    };
                } catch (e) {
                    page.hemeraPresent = false;
                    page.hemera = {};
                }
            }
        }
        onExited: function (code) {
            if (code !== 0) {
                page.hemeraPresent = false;
                page.hemera = {};
            }
        }
    }

    Process {
        id: vaultProc
        running: false
        command: ["env", page.execPath, "nyxus-hemera", "vault", "list", "--json"]   // TRK-3435
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    page.vault = Array.isArray(j) ? j : [];
                } catch (e) {
                    page.vault = [];
                }
            }
        }
        onExited: function (code) {
            if (code !== 0)
                page.vault = [];
        }
    }

    Process {
        id: histProc
        running: false
        command: ["env", page.execPath, "nyxus-hemera", "history", "--json", "--limit", "12"]   // TRK-3435
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    page.history = Array.isArray(j) ? j : [];
                } catch (e) {
                    page.history = [];
                }
            }
        }
    }

    Process {
        id: secureApply
        running: false
        command: ["env", page.execPath,   // TRK-3435
                  "pkexec", "nyxus-secure", "apply", page.applySpec]
        onExited: function (code) {
            page.lastNote = code === 0
                ? qsTr("Protection updated.")
                : qsTr("Could not change protection (cancelled or missing helper).");
            page.refresh();
        }
    }

    Process {
        id: scanProc
        running: false
        command: ["env", page.execPath, "nyxus-hemera", "scan", "quick"]   // TRK-3435
        onExited: function (code) {
            page.lastNote = code === 0
                ? qsTr("Quick scan finished. Findings, if any, wait in Quarantine.")
                : qsTr("Quick scan did not run (engine missing, or no definitions yet).");
            page.refresh();
        }
    }

    Process {
        id: defsProc
        running: false
        command: ["env", page.execPath, "nyxus-hemera", "defs", "update", "--consent", "--json"]   // TRK-3435
        onExited: function (code) {
            page.lastNote = code === 0
                ? qsTr("Virus definitions updated.")
                : qsTr("Definition download did not finish (needs consent, ~300 MB).");
            page.refresh();
        }
    }

    Process {
        id: vaultDo
        running: false
        command: ["env", page.execPath,   // TRK-3435
                  "nyxus-hemera", "vault", page.vaultAction, page.vaultId]
        onExited: function (code) {
            page.lastNote = code === 0 ? qsTr("Vault updated.") : qsTr("Vault action did not complete.");
            page.refresh();
        }
    }

    Process {
        id: lockNow
        running: false
        command: ["env", page.execPath, "nyxus-lock-guard"]   // TRK-3435
        onExited: function (code) {
            if (code !== 0)
                page.lastNote = qsTr("Could not lock (missing or refused).");
        }
    }

    SetCard {
        heading: qsTr("Sign in & lock")
        tone: page.tone
        note: qsTr("Lock now is the same path as the shelf menu. Super+L too. Idle lock stays a system default of 10 minutes — this page does not change it.")

        SetRow {
            title: qsTr("Lock now")
            sub: qsTr("Anyone at the keyboard needs your password. Fingerprint and face, when present, work on the lock surface itself.")

            SetButton {
                text: qsTr("Lock now")
                tone: page.tone
                busy: lockNow.running
                enabled: !lockNow.running
                onClicked: lockNow.running = true
            }
        }

        SetRow {
            title: qsTr("Lock screen look")
            sub: qsTr("Earth, moon, notifications, and media keys while locked")
            navigates: true
            onActivated: Bus.openSettings("screenlock")
        }

        SetRow {
            title: qsTr("Keep awake")
            sub: qsTr("Screensaver delay. Lock-after is a 10 minute fact, not a live slider.")
            navigates: true
            onActivated: Bus.openSettings("idle")
        }

        SetRow {
            title: qsTr("Fingerprint")
            sub: page.fpNote !== "" ? page.fpNote : qsTr("Reading this machine…")
            valueText: page.fpState === "enrolled" ? qsTr("Enrolled")
                     : (page.fpState === "empty" ? qsTr("None")
                     : (page.fpState === "noreader" ? qsTr("No reader")
                     : (page.fpState === "" ? "…" : qsTr("No service"))))
        }

        SetRow {
            title: qsTr("Face")
            sub: page.howdyState === "present"
                 ? qsTr("On disk but not loaded at sign-in on this image — a report, not a switch")
                 : qsTr("Not shipped. Password (and fingerprint, if enrolled) sign you in.")
            valueText: page.howdyState === "present" ? qsTr("Installed") : qsTr("Not on this image")
        }

        SetRow {
            title: qsTr("Your account")
            sub: qsTr("Who is signed in. Password change is not this page.")
            navigates: true
            onActivated: Bus.openSettings("account")
        }
    }

    SetCard {
        heading: qsTr("This disk")
        tone: page.tone
        note: qsTr("Encryption is a fact about the volumes, not a form. Turning LUKS on is an install-time choice.")

        SetRow {
            title: qsTr("Encryption")
            sub: Number(page.posture.luks) > 0
                 ? qsTr("%1 encrypted volume(s) (LUKS)").arg(page.posture.luks)
                 : qsTr("No encrypted volumes on this machine")
            valueText: Number(page.posture.luks) > 0 ? qsTr("On") : qsTr("Off")
        }

        SetRow {
            title: qsTr("TPM")
            sub: page.posture.tpm === "1"
                 ? qsTr("A TPM is in sysfs. This page does not enrol keys.")
                 : qsTr("No TPM in sysfs")
            valueText: page.posture.tpm === "1" ? qsTr("Present") : qsTr("Not detected")
        }

        SetRow {
            title: qsTr("Storage")
            sub: qsTr("Disks, mounts, and what is encrypted")
            navigates: true
            onActivated: Bus.openSettings("storage")
        }
    }

    SetCard {
        heading: qsTr("Firmware")
        tone: page.tone
        note: qsTr("Read from sysfs. Turning Secure Boot on or off, and enrolling keys, is firmware setup — not a switch here.")

        SetRow {
            title: qsTr("Secure Boot")
            sub: page.sbCaption
            valueText: page.posture.sb === "1" ? qsTr("On")
                     : (page.posture.sb === "0" ? qsTr("Off") : "—")
        }

        SetRow {
            title: qsTr("Firmware")
            sub: page.posture.efi === "1"
                 ? qsTr("EFI variables are readable")
                 : qsTr("Legacy firmware — no Secure Boot variable")
            valueText: page.posture.efi === "1" ? qsTr("UEFI") : qsTr("Not UEFI")
        }

        SetRow {
            title: qsTr("Full firmware report")
            sub: qsTr("The same facts on their own page")
            navigates: true
            onActivated: Bus.openSettings("secboot")
        }
    }

    SetCard {
        heading: qsTr("Who may reach this machine")
        tone: page.tone
        note: qsTr("Same four switches as first-run Protection. Firewall and AppArmor arrived ON from the installer. Encrypted DNS and MAC randomisation stay opt-in. Polkit asks; nothing opens a terminal.")

        SetRow {
            title: qsTr("Standing")
            sub: page.ringStanding === page.ringTotal
                 ? qsTr("Firewall, shield, snapshots, updates, scan, and an empty vault")
                 : qsTr("Needs attention — rows below, or Scan")
            valueText: page.ringStanding + "/" + page.ringTotal
        }

        SetRow {
            title: qsTr("Firewall")
            sub: page.posture.fw === "on"
                 ? qsTr("Blocking unsolicited inbound")
                 : qsTr("Off — inbound is open")

            SetSwitch {
                tone: page.tone
                checked: page.posture.fw === "on"
                onToggled: function (v) { page.applySecure("firewall=" + (v ? "on" : "off")); }
            }
        }

        SetRow {
            title: qsTr("System Shield")
            sub: qsTr("AppArmor — keeps a compromised app inside its own lane")

            SetSwitch {
                tone: page.tone
                checked: page.posture.aa === "on" || page.posture.aaSys === "Y"
                onToggled: function (v) { page.applySecure("apparmor=" + (v ? "on" : "off")); }
            }
        }

        SetRow {
            title: qsTr("Encrypted DNS")
            sub: qsTr("Lookups leave the machine encrypted, with DNSSEC. Opt-in.")

            SetSwitch {
                tone: page.tone
                checked: page.posture.dns === "on"
                onToggled: function (v) { page.applySecure("dns=" + (v ? "on" : "off")); }
            }
        }

        SetRow {
            title: qsTr("MAC randomisation")
            sub: qsTr("Networks you walk past cannot recognise this laptop. Opt-in.")

            SetSwitch {
                tone: page.tone
                checked: page.posture.mac === "on"
                onToggled: function (v) { page.applySecure("macrandom=" + (v ? "on" : "off")); }
            }
        }

        SetRow {
            title: qsTr("Firewall page")
            sub: qsTr("Inbound policy on its own page")
            navigates: true
            onActivated: Bus.openSettings("firewall")
        }

        SetRow {
            visible: page.lastNote !== ""
            title: qsTr("Note")
            sub: page.lastNote
        }
    }

    SetCard {
        heading: qsTr("Scan & quarantine")
        tone: page.tone
        note: page.hemeraPresent
              ? qsTr("HEMERA — on-demand scanning. Weekly check is a timer, not this button. No real-time daemon. Isolated findings wait here until you Restore, Delete, or Keep.")
              : qsTr("The scan engine did not answer. Sign-in and firmware above still work.")

        SetRow {
            visible: !page.hemeraPresent
            title: qsTr("Engine")
            available: false
            unavailableReason: qsTr("Unavailable")
            sub: qsTr("Scan, definitions, and the vault need that service")
        }

        SetRow {
            visible: page.hemeraPresent
            title: qsTr("Quick scan")
            sub: qsTr("Downloads, Desktop, and temp. Findings go to Quarantine.")

            SetButton {
                text: qsTr("Scan now")
                tone: page.tone
                busy: scanProc.running
                enabled: page.hemeraPresent && !scanProc.running
                onClicked: scanProc.running = true
            }
        }

        SetRow {
            visible: page.hemeraPresent
            title: qsTr("Last scan")
            sub: {
                var last = page.hemera.last || {};
                if (page.hemera.scanDays === null || page.hemera.scanDays === undefined)
                    return qsTr("No finished scan recorded. Weekly timer is not this button.");
                var r = last.result || "";
                if (r)
                    return qsTr("Last result: %1. Not a realtime daemon.").arg(r);
                return qsTr("Finished scan on record. Not a realtime daemon.");
            }
            valueText: {
                var d = page.hemera.scanDays;
                if (d === null || d === undefined)
                    return qsTr("None");
                if (Number(d) === 0)
                    return qsTr("Today");
                return qsTr("%1d").arg(d);
            }
        }

        SetRow {
            visible: page.hemeraPresent
            title: qsTr("Definitions")
            sub: {
                var d = page.hemera.defs || {};
                if (d.present)
                    return d.note || qsTr("Definitions are present");
                return qsTr("No definitions yet — a scan cannot find anything. About 300 MB, asked once.");
            }

            SetButton {
                text: qsTr("Download")
                tone: page.tone
                busy: defsProc.running
                enabled: page.hemeraPresent && !defsProc.running
                onClicked: defsProc.running = true
            }
        }

        SetRow {
            visible: page.hemeraPresent && page.vault.length === 0
            title: qsTr("Vault")
            sub: qsTr("The vault is empty. A finding waits here until you Restore, Delete, or Keep it.")
        }

        Repeater {
            model: page.vault
            delegate: SetRow {
                id: vt
                required property var modelData
                title: String(vt.modelData.origin || vt.modelData.id || "item")
                sub: String(vt.modelData.signature || "")
                valueText: String(vt.modelData.state || qsTr("Held")).toUpperCase()

                RowLayout {
                    spacing: Theme.s4

                    SetButton {
                        text: qsTr("Restore")
                        tone: page.tone
                        onClicked: page.doVault("restore", String(vt.modelData.id))
                    }
                    SetButton {
                        text: qsTr("Keep")
                        tone: page.tone
                        onClicked: page.doVault("keep", String(vt.modelData.id))
                    }
                    SetButton {
                        text: qsTr("Delete")
                        danger: true
                        confirmText: qsTr("Delete this file")
                        tone: page.tone
                        onClicked: page.doVault("delete", String(vt.modelData.id))
                    }
                }
            }
        }
    }

    SetCard {
        heading: qsTr("Protection history")
        tone: page.tone
        note: qsTr("Every scan and every decision, newest first.")

        SetRow {
            visible: page.history.length === 0
            title: qsTr("History")
            sub: page.hemeraPresent ? qsTr("Nothing has happened yet") : qsTr("History could not be read")
        }

        Repeater {
            model: page.history
            delegate: SetRow {
                required property var modelData
                title: String(modelData.event || qsTr("Event")).toUpperCase()
                sub: String(modelData.origin || modelData.kind || modelData.reason || "")
                valueText: {
                    var ts = Number(modelData.ts || 0);
                    if (ts <= 0) return "";
                    var d = new Date(ts * 1000);
                    return d.toISOString().slice(0, 16).replace("T", " ");
                }
            }
        }
    }
}
