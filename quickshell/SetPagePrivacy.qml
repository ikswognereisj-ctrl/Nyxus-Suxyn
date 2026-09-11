pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ Privacy & Security ▸ Privacy.
// Clipboard history is cliphist (already watching). Clear happens in this
// window. No location daemon is claimed.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    property var entry: null
    title: qsTr("Privacy")
    blurb: qsTr("What this desktop remembers, and what shows on a locked screen.")

    property string lastNote: ""
    property int clipCount: -1

    Component.onCompleted: clipCountProc.running = true

    Process {
        id: wipe
        running: false
        command: ["cliphist", "wipe"]
        onExited: function (code) {
            page.lastNote = code === 0 ? "Clipboard history cleared." : "cliphist did not clear (not running, or not packaged).";
            if (code === 0)
                page.clipCount = 0;
            else
                clipCountProc.running = true;
        }
    }

    Process {
        id: clipCountProc
        running: false
        command: ["sh", "-c",
            'command -v cliphist >/dev/null 2>&1 || { echo missing; exit 0; }; '
          + 'n=$(cliphist list 2>/dev/null | wc -l); echo "$n"']
        stdout: StdioCollector {
            onStreamFinished: {
                var t = String(this.text).trim();
                if (t === "missing")
                    page.clipCount = -2;
                else {
                    var n = parseInt(t, 10);
                    page.clipCount = isNaN(n) ? -1 : n;
                }
            }
        }
    }

    SetCard {
        heading: qsTr("Clipboard")
        tone: page.tone
        note: qsTr("The flyout already shows this history. Passwords should not be kept — cliphist is the watcher, not a password manager.")

        SetIceFace {
            kicker: qsTr("CLIPBOARD")
            reading: page.clipCount >= 0 ? String(page.clipCount) : (page.clipCount === -2 ? "—" : "…")
            caption: qsTr("Clear clipboard history")
            detail: page.clipCount === -2
                    ? qsTr("cliphist is not on PATH")
                    : (page.clipCount === 1
                       ? qsTr("1 entry on this account")
                       : qsTr("%1 entries on this account").arg(page.clipCount >= 0 ? page.clipCount : 0))
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4

            SetButton {
                text: qsTr("Clear")
                danger: true
                confirmText: qsTr("Clear all clips")
                tone: page.tone
                busy: wipe.running
                enabled: page.clipCount !== -2
                onClicked: wipe.running = true
            }
        }

        SetIceFace {
            visible: page.lastNote !== ""
            compact: true
            kicker: qsTr("NOTE")
            caption: page.lastNote
        }
    }

    SetCard {
        heading: qsTr("Location")
        tone: page.tone
        note: qsTr("This image does not run a location daemon. Nothing here can look like it turns tracking on.")

        SetRow {
            title: qsTr("Location services")
            available: false
            unavailableReason: qsTr("Not on this image. Weather uses a one-shot lookup when you ask, not a tracker.")
        }
    }

    SetCard {
        heading: qsTr("What else remembers")
        tone: page.tone
        note: qsTr("These are the other stores this desktop keeps. Each one is configured on its own page.")

        // TRK-3812 · a POINTER, never a second writer. One key, one control,
        // and that control lives with the rest of the bar's media settings —
        // two stones writing `lyrics_online` is how a page and a shell end up
        // disagreeing about what somebody consented to.
        SetRow {
            title: qsTr("Synced lyrics (network lookup)")
            sub: qsTr("Ships off. On, it sends the artist, title and length of what you are playing to lrclib.net — Appearance")
            navigates: true
            onActivated: Bus.openSettings("appearance")
        }

        SetRow {
            title: qsTr("Notifications while locked")
            sub: qsTr("Opens Lock screen — the live switches live there")
            navigates: true
            onActivated: Bus.openSettings("screenlock")
        }

        SetRow {
            title: qsTr("USB notifications and automount")
            sub: qsTr("What happens when you plug a drive in")
            navigates: true
            onActivated: Bus.openSettings("usb")
        }

        SetRow {
            title: qsTr("Notifications")
            sub: qsTr("Toasts, Do Not Disturb, USB and battery alerts")
            navigates: true
            onActivated: Bus.openSettings("notifications")
        }

        SetRow {
            title: qsTr("Security")
            sub: qsTr("Lock now, fingerprint, encryption")
            navigates: true
            onActivated: Bus.openSettings("security")
        }
    }
}
