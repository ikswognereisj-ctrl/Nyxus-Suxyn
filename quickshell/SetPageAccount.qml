pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ Accounts ▸ Your account.
// Read-only identity from the session. Does not spawn passwd in a terminal.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    property var entry: null
    // TRK-3435: shipped-first PATH, composed in QML and applied via `env`
    // so argv never crosses a shell. Ruling: SetPageBackup.qml.
    readonly property string execPath: "PATH="
        + (Quickshell.env("NYXUS_BIN_DIR") || "/usr/local/bin")
        + ":" + Quickshell.env("PATH")
    title: qsTr("Your account")
    blurb: qsTr("Who is signed in. The first user from install is an administrator. This page does not invent a Users list.")

    property string userName: ""
    property string realName: ""
    property string hostName: ""
    property string uid: ""
    property string groups: ""
    property string loginShell: ""
    property bool isAdmin: false
    property string luksCount: ""
    property string failNote: ""
    property bool guestExists: false
    property string guestNote: ""
    // TRK-3185 — last off-disk run, same JSON Condition SNAPSHOTS already reads.
    // Honest empty if the tool is missing or nothing has run. Not a GPS.
    property bool backupProbed: false
    property bool backupUnavailable: false
    property bool backupHadRun: false
    property bool backupLastOk: false
    property string backupSummary: ""
    property string lockNote: ""
    // TRK-3200 — rename this machine. Same rules as the welcome hostname
    // step. hostnamectl talks to hostnamed; polkit asks. No terminal.
    property string renameDraft: ""
    property string renameNote: ""
    function hostnameError(name) {
        var n = String(name || "").trim().toLowerCase();
        if (!n)
            return qsTr("Give the machine a name.");
        if (n.length > 63)
            return qsTr("Keep it to 63 characters.");
        if (!/^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$/.test(n))
            return qsTr("Letters, numbers, hyphens. Start and end with a letter or number.");
        return "";
    }

    Component.onCompleted: {
        idProc.running = true;
        backupProbe.running = true;
    }

    Process {
        id: lockNow
        running: false
        command: ["env", page.execPath, "nyxus-lock-guard"]   // TRK-3435
        onExited: function (code) {
            if (code !== 0)
                page.lockNote = qsTr("Could not lock this session.");
            else
                page.lockNote = "";
        }
    }

    Process {
        id: idProc
        running: false
        command: ["sh", "-c",
            'printf "user\\t%s\\n" "$(id -un 2>/dev/null)"\n'
          + 'printf "uid\\t%s\\n" "$(id -u 2>/dev/null)"\n'
          + 'printf "host\\t%s\\n" "$(hostname 2>/dev/null || hostnamectl --static 2>/dev/null || cat /etc/hostname 2>/dev/null)"\n'
          + 'gecos=$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f5 | cut -d, -f1)\n'
          + 'printf "gecos\\t%s\\n" "$gecos"\n'
          + 'printf "shell\\t%s\\n" "$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)"\n'
          + 'printf "groups\\t%s\\n" "$(id -Gn 2>/dev/null | tr " " ", ")"\n'
          + 'g=$(id -nG 2>/dev/null)\n'
          + 'case " $g " in *" wheel "*|*" sudo "*) printf "admin\\tyes\\n" ;; *) printf "admin\\tno\\n" ;; esac\n'
          + 'luks=$(lsblk -o FSTYPE -n 2>/dev/null | grep -c crypto_LUKS || true)\n'
          + 'printf "luks\\t%s\\n" "$luks"\n'
          + 'u=$(id -un 2>/dev/null)\n'
          + 'if command -v faillock >/dev/null 2>&1; then\n'
          + '  fl=$(faillock --user "$u" 2>/dev/null | grep -cE ":[0-9]{2}:[0-9]{2}:[0-9]{2}" || true)\n'
          + '  printf "fail\\t%s\\n" "$fl"\n'
          + 'elif journalctl -b -q -o cat -n 40 2>/dev/null | grep -qiE "authentication failure|failed password"; then\n'
          + '  printf "fail\\tjournal\\n"\n'
          + 'else printf "fail\\tnone\\n"; fi\n'
          + 'if id -u guest >/dev/null 2>&1; then printf "guest\\tyes\\n"; else printf "guest\\tno\\n"; fi\n']
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = String(this.text).split("\n");
                for (var i = 0; i < lines.length; ++i) {
                    var t = lines[i].indexOf("\t");
                    if (t < 0) continue;
                    var k = lines[i].slice(0, t);
                    var v = lines[i].slice(t + 1);
                    if (k === "user") page.userName = v;
                    else if (k === "host") page.hostName = v;
                    else if (k === "gecos") page.realName = v;
                    else if (k === "uid") page.uid = v;
                    else if (k === "shell") page.loginShell = v;
                    else if (k === "groups") page.groups = v;
                    else if (k === "admin") page.isAdmin = (v === "yes");
                    else if (k === "luks") page.luksCount = v;
                    else if (k === "fail") {
                        if (v === "none" || v === "0")
                            page.failNote = qsTr("No failed sign-in recorded for this user in faillock this boot");
                        else if (v === "journal")
                            page.failNote = qsTr("The journal mentions a failed sign-in this boot (count not readable without extra rights)");
                        else
                            page.failNote = qsTr("%1 failed attempt(s) in faillock").arg(v);
                    } else if (k === "guest") page.guestExists = (v === "yes");
                }
                if (page.renameDraft === "" && page.hostName !== "")
                    page.renameDraft = page.hostName;
            }
        }
    }

    Process {
        id: renameHost
        running: false
        command: ["hostnamectl", "set-hostname", page.renameDraft.trim().toLowerCase()]
        onExited: function (code) {
            if (code !== 0) {
                page.renameNote = qsTr("Could not rename this machine. Administrator permission was not granted.");
                return;
            }
            page.renameNote = qsTr("Renamed. New shells and the greeter will see it.");
            idProc.running = true;
        }
    }

    Process {
        id: guestCreate
        running: false
        // TRK-3435: pkexec resolves the program through the CALLER's PATH,
        // so the shipped-first prefix governs which copy gets elevated.
        command: ["env", page.execPath, "pkexec", "nyxus-guest-create"]
        stdout: StdioCollector {
            onStreamFinished: page.guestNote = String(this.text).trim()
        }
        onExited: idProc.running = true
    }

    Process {
        id: backupProbe
        running: false
        command: ["sh", "-c",   // TRK-3435
            'PATH="${NYXUS_BIN_DIR:-/usr/local/bin}:$PATH"; '
          + 'if command -v nyxus-backup >/dev/null 2>&1; then nyxus-backup status --json 2>/dev/null; '
          + 'else echo "__NOCHECK__"; fi']
        stdout: StdioCollector {
            onStreamFinished: {
                var t = String(this.text).trim();
                page.backupProbed = true;
                if (t === "" || t.indexOf("__NOCHECK__") >= 0) {
                    page.backupUnavailable = true;
                    page.backupHadRun = false;
                    page.backupSummary = "";
                    return;
                }
                try {
                    var d = JSON.parse(t);
                    page.backupUnavailable = false;
                    var lr = d.last_run || null;
                    page.backupHadRun = !!(lr && lr.when);
                    page.backupLastOk = !!(lr && lr.ok);
                    page.backupSummary = String(d.summary || "");
                    if (page.backupSummary === "" && page.backupHadRun)
                        page.backupSummary = qsTr("Last backup %1").arg(String(lr.when));
                } catch (e) {
                    page.backupUnavailable = true;
                    page.backupHadRun = false;
                    page.backupSummary = "";
                }
            }
        }
    }

    SetCard {
        heading: qsTr("Signed in")
        tone: page.tone
        note: qsTr("Password and fingerprint enrolment stay on the lock and sign-in surfaces. This page does not open a terminal to change them, and it does not grow a Users list.")

        SetRow {
            title: qsTr("You")
            sub: (page.realName !== "" ? page.realName : qsTr("No full name on this account"))
                 + " · " + (Sys.hasFace
                     ? qsTr("Picture set — Start and the flyout already show it")
                     : qsTr("No picture yet — Start uses the same file"))
            valueText: page.userName !== "" ? page.userName : "—"
        }

        SetRow {
            title: qsTr("This machine")
            sub: qsTr("Host name (hostname, then hostnamectl, then /etc/hostname)")
            valueText: page.hostName !== "" ? page.hostName : "—"
        }

        SetRow {
            glyph: ""
            title: qsTr("Machine name")
            sub: qsTr("Letters, numbers, and hyphens — used on the network and by other machines")
            visible: page.isAdmin

            Pane {
                width: 220
                height: 28
                elevation: 1
                radius: Theme.r1
                fill: Theme.soften(Theme.void_, 0.50)
                focusLevel: hostField.activeFocus ? 1.0 : 0.0

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.r1
                    color: "transparent"
                    border.width: 1
                    border.color: hostField.activeFocus
                                  ? Theme.paintLayers.glacier[0]
                                  : Theme.soften(Theme.text, 0.14)
                }

                TextInput {
                    id: hostField
                    anchors.fill: parent
                    anchors.leftMargin: Theme.s4
                    anchors.rightMargin: Theme.s4
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tLabel
                    selectByMouse: true
                    clip: true
                    text: page.renameDraft
                    onTextChanged: page.renameDraft = text
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            visible: page.isAdmin

            SetButton {
                text: qsTr("Rename this machine")
                tone: page.tone
                busy: renameHost.running
                enabled: !renameHost.running
                         && page.hostnameError(page.renameDraft) === ""
                         && page.renameDraft.trim().toLowerCase() !== page.hostName.toLowerCase()
                onClicked: {
                    var err = page.hostnameError(page.renameDraft);
                    if (err) {
                        page.renameNote = err;
                        return;
                    }
                    renameHost.running = true;
                }
            }
        }

        SetRow {
            visible: !page.isAdmin
            title: qsTr("Rename")
            available: false
            unavailableReason: qsTr("Unavailable")
            sub: qsTr("An administrator has to rename this machine. This account is not in wheel or sudo.")
        }

        SetRow {
            visible: page.renameNote !== ""
            title: qsTr("Note")
            sub: page.renameNote
        }
    }

    SetCard {
        heading: qsTr("This session")
        tone: page.tone
        note: qsTr("Facts from the account you are in now. Changing them is not a Settings form.")

        SetRow {
            title: qsTr("User ID")
            sub: page.loginShell !== "" ? page.loginShell : qsTr("Login shell unknown")
            valueText: page.uid !== "" ? page.uid : "—"
        }

        SetRow {
            title: qsTr("Role")
            sub: page.isAdmin
                 ? qsTr("This account is in wheel or sudo — the first user from install is an administrator, like Windows or Apple.")
                 : qsTr("Not in wheel or sudo. Administrator actions will ask for another account.")
            valueText: page.isAdmin ? qsTr("Administrator") : qsTr("Standard")
        }

        SetRow {
            title: qsTr("Groups")
            sub: page.groups !== "" ? page.groups : qsTr("None reported")
        }

        SetRow {
            title: qsTr("Disk encryption")
            sub: Number(page.luksCount) > 0
                 ? qsTr("%1 LUKS volume(s) — a fact, not a switch. Install hid the encrypt checkbox.").arg(page.luksCount)
                 : qsTr("No LUKS volumes. Turning encryption on is an install-time choice.")
            valueText: Number(page.luksCount) > 0 ? qsTr("On") : qsTr("Off")
        }

        SetRow {
            title: qsTr("Failed sign-in")
            sub: page.failNote !== "" ? page.failNote : qsTr("Not checked yet")
        }

        SetRow {
            title: qsTr("Session")
            sub: qsTr("Hyprland + Quickshell — the glass desktop. Windowing and Rooms live under System.")
        }
    }

    SetCard {
        heading: qsTr("Find this machine")
        tone: page.tone
        note: qsTr("What this computer can honestly say if it is lost. There is no GPS, no phone ping, and no cloud account. A full Find My needs an owner call.")

        SetRow {
            title: qsTr("This machine")
            sub: qsTr("The name already on this page. Not a location.")
            valueText: page.hostName !== "" ? page.hostName : "—"
        }

        SetRow {
            title: qsTr("Last backup")
            sub: page.backupSummary !== ""
                 ? page.backupSummary
                 : (page.backupUnavailable
                    ? qsTr("Unavailable")
                    : qsTr("No off-disk backup yet"))
            valueText: !page.backupProbed
                     ? qsTr("Not checked")
                     : (page.backupUnavailable
                        ? qsTr("Unavailable")
                        : (page.backupHadRun
                           ? (page.backupLastOk ? qsTr("Backed up") : qsTr("Last run failed"))
                           : qsTr("None")))
        }

        SetRow {
            title: qsTr("Disk encryption")
            sub: Number(page.luksCount) > 0
                 ? qsTr("%1 LUKS volume(s) — the same read-only fact as above.").arg(page.luksCount)
                 : qsTr("No LUKS volumes. Not a switch.")
            valueText: Number(page.luksCount) > 0 ? qsTr("On") : qsTr("Off")
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            spacing: Theme.s4

            SetButton {
                text: qsTr("Lock now")
                tone: page.tone
                busy: lockNow.running
                enabled: !lockNow.running
                onClicked: lockNow.running = true
            }
        }

        SetRow {
            visible: page.lockNote !== ""
            title: qsTr("Note")
            sub: page.lockNote
        }

        SetRow {
            title: qsTr("Security…")
            sub: qsTr("Fingerprint report, encryption, and firmware")
            navigates: true
            onActivated: Bus.openSettings("security")
        }
    }

    SetCard {
        heading: qsTr("Guest")
        tone: page.tone
        note: qsTr("A confined second account, not an administrator. The greeter lists passwd users; there is no auto-login and no dedicated Guest button (that would touch the look-seat).")

        SetRow {
            title: qsTr("Guest")
            sub: page.guestExists
                 ? qsTr("Account guest exists. Not wheel. Sign-in is the greeter user list.")
                 : qsTr("Creates /home/guest with no administrator groups. Polkit will ask.")
            valueText: page.guestExists ? qsTr("Present") : qsTr("Not created")
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            visible: !page.guestExists

            SetButton {
                text: qsTr("Create guest account")
                danger: true
                confirmText: qsTr("Create guest — not an administrator")
                busy: guestCreate.running
                enabled: !guestCreate.running
                onClicked: guestCreate.running = true
            }
        }

        SetRow {
            visible: page.guestNote !== ""
            title: qsTr("Note")
            sub: page.guestNote
        }
    }

    SetCard {
        heading: qsTr("Related")
        tone: page.tone

        SetRow {
            title: qsTr("Lock & sign-in")
            sub: qsTr("Lock now, fingerprint report, encryption and firmware")
            navigates: true
            onActivated: Bus.openSettings("security")
        }

        SetRow {
            title: qsTr("Lock screen")
            sub: qsTr("Earth, moon, and what shows while locked")
            navigates: true
            onActivated: Bus.openSettings("screenlock")
        }

        SetRow {
            title: qsTr("Keep awake")
            sub: qsTr("Screensaver. Lock delay is hypridle at 10 minutes.")
            navigates: true
            onActivated: Bus.openSettings("idle")
        }

        SetRow {
            title: qsTr("Date & time")
            navigates: true
            onActivated: Bus.openSettings("datetime")
        }
    }
}
