pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ Privacy & Security ▸ Secure Boot.
// Read-only firmware facts. No mokutil in a terminal. No key enrolment UI
// that would lie about being able to change it from here.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    property var entry: null
    title: qsTr("Secure Boot")
    blurb: qsTr("A firmware report. This page cannot turn Secure Boot on or enrol keys.")

    property string sb: ""
    property string efi: "0"
    property string tpm: "0"
    property string lastNote: ""

    Component.onCompleted: proc.running = true

    Process {
        id: proc
        running: false
        // TRK-3451: these were `echo efi\t1` — the shell strips the backslash
        // (an unquoted `\t` is just `t`), so no line ever carried a real TAB
        // and the parser below matched nothing: every machine read "Not UEFI",
        // SB "—", TPM "NO" forever, with exit 0 so lastNote never fired.
        // printf is how SetPageSecurity gathers the same facts, and it works.
        command: ["sh", "-c",
            'if [ -d /sys/firmware/efi ]; then printf "%s\\t%s\\n" efi 1; else printf "%s\\t%s\\n" efi 0; fi\n'
          + 'if [ -d /sys/class/tpm/tpm0 ]; then printf "%s\\t%s\\n" tpm 1; else printf "%s\\t%s\\n" tpm 0; fi\n'
          + 'p=/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c\n'
          + 'if [ -r "$p" ]; then printf "%s\\t%s\\n" sb "$(od -An -t u1 "$p" 2>/dev/null | awk "{print \\$NF}")"; else printf "%s\\t%s\\n" sb ""; fi\n']
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = String(this.text).split("\n");
                for (var i = 0; i < lines.length; ++i) {
                    var t = lines[i].indexOf("\t");
                    if (t < 0) continue;
                    var k = lines[i].slice(0, t);
                    var v = lines[i].slice(t + 1);
                    if (k === "efi") page.efi = v;
                    else if (k === "tpm") page.tpm = v;
                    else if (k === "sb") page.sb = v;
                }
            }
        }
        onExited: function (code) {
            if (code !== 0)
                page.lastNote = qsTr("Firmware state could not be read.");
        }
    }

    SetCard {
        heading: qsTr("Firmware")
        tone: page.tone
        note: page.lastNote !== "" ? page.lastNote
              : qsTr("Enrolling keys and turning Secure Boot on or off are done in the firmware setup screen, not here — a switch on this page could not actually apply.")

        SetRow {
            title: qsTr("Firmware type")
            sub: page.efi === "1" ? qsTr("This is a UEFI machine") : qsTr("This machine boots with legacy BIOS, not UEFI")
            valueText: page.efi === "1" ? qsTr("UEFI") : qsTr("Legacy BIOS")
        }

        SetRow {
            title: qsTr("Secure Boot")
            sub: page.efi !== "1"
                 ? qsTr("This firmware has nothing to report")
                 : (page.sb === "1" ? qsTr("The firmware reports it is on")
                    : (page.sb === "0" ? qsTr("The firmware reports it is off")
                       : qsTr("Could not read Secure Boot status from the firmware")))
            valueText: page.sb === "1" ? qsTr("On") : (page.sb === "0" ? qsTr("Off") : "—")
        }

        SetRow {
            title: qsTr("TPM")
            sub: page.tpm === "1" ? qsTr("Present") : qsTr("Not detected")
            valueText: page.tpm === "1" ? qsTr("Yes") : qsTr("No")
        }

        SetRow {
            title: qsTr("Security")
            sub: qsTr("Lock now, encryption, firewall, scan")
            navigates: true
            onActivated: Bus.openSettings("security")
        }
    }
}
