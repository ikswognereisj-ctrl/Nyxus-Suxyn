pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ Devices ▸ USB & removable devices.   MODULE 3.
//
// The surface for `UsbWatch.qml`. The watcher owns the device list, the udev
// stream and the udisks2 actions; this page shows them and switches the two
// behaviours on and off. That split is deliberate — read the header of
// `UsbWatch.qml` for why the watch cannot live in a page.
//
// Backend: udev (`udevadm monitor`) for the events, `lsblk -J` for what is
// there, `udisksctl` for mount / unmount / power-off. No sudo anywhere: udisks2
// is a system daemon that does the privileged part behind polkit, which is the
// whole reason a desktop can offer this without asking for a password.
import Quickshell
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    property var entry: null

    title: qsTr("USB & removable devices")
    blurb: qsTr("What's plugged in, and what happens when you connect something.")

    // Ask for a fresh read when the page opens. The watcher is event-driven, so
    // its list is already current — this is for the case where it was started
    // with both features off and has never had an event to react to.
    Component.onCompleted: UsbWatch.refresh()

    // ══ WHAT IS PLUGGED IN ═════════════════════════════════════════════
    SetCard {
        heading: qsTr("Connected now")
        tone: page.tone
        note: UsbWatch.lastError !== ""
              ? qsTr("The last action didn't complete.")
              : qsTr("Drives appear and disappear here as you plug them in and pull ")
                + "them out — the list follows the kernel, it is not polled."

        SetRow {
            visible: UsbWatch.devices.length === 0
            title: qsTr("Removable drives")
            sub: UsbWatch.scanned ? qsTr("Nothing removable is connected") : qsTr("Looking…")
        }

        Repeater {
            model: UsbWatch.devices

            delegate: SetRow {
                id: dev
                required property var modelData
                readonly property bool mounted: modelData.mount !== ""
                readonly property bool busy: UsbWatch.busyPath === modelData.path

                title: modelData.name
                sub: {
                    var bits = [];
                    if (modelData.fstype !== "")
                        bits.push(modelData.fstype.toUpperCase());
                    if (modelData.bus !== "")
                        bits.push(modelData.bus.toUpperCase());
                    bits.push(dev.mounted ? qsTr("Ready at %1").arg(modelData.mount)
                                          : qsTr("Not opened yet"));
                    return bits.join(" · ");
                }
                valueText: modelData.size !== "" ? modelData.size : ""

                RowLayout {
                    spacing: Theme.s4

                    SetButton {
                        text: dev.mounted ? qsTr("Close") : qsTr("Open")
                        glyph: ""
                        tone: page.tone
                        busy: dev.busy
                        onClicked: dev.mounted ? UsbWatch.unmount(dev.modelData.path)
                                               : UsbWatch.mount(dev.modelData.path)
                    }

                    SetButton {
                        text: qsTr("Eject")
                        glyph: ""
                        danger: true
                        confirmText: qsTr("Power off %1").arg(dev.modelData.name)
                        busy: dev.busy
                        onClicked: UsbWatch.eject(dev.modelData.path)
                    }
                }
            }
        }
    }

    // ══ WHAT HAPPENS ON PLUG-IN ════════════════════════════════════════
    SetCard {
        heading: qsTr("When you plug something in")
        tone: page.tone
        note: qsTr("With both of these off, nothing is watching and no background ")
              + "process runs at all — the udev monitor only exists while one "
              + "of them is on."

        SetRow {
            glyph: ""
            title: qsTr("Show a notification")
            sub: qsTr("A toast naming the drive when it is connected, and again when it is removed")
            SetSwitch { key: "usb_notify"; defaultValue: true; tone: page.tone }
        }

        SetRow {
            glyph: ""
            title: qsTr("Open it automatically")
            sub: qsTr("Mounts the drive as soon as it appears, so it is ready without a click")
            SetSwitch { key: "usb_automount"; defaultValue: true; tone: page.tone }
        }

        SetRow {
            glyph: ""
            title: qsTr("After connecting")
            sub: qsTr("What to do once a drive is ready. Ask is the plug-in toast; there is no extra dialog.")

            SetChoice {
                key: "usb_action"
                defaultValue: "nothing"
                tone: page.tone
                options: [
                    { value: "nothing", label: qsTr("Nothing") },
                    { value: "files",   label: qsTr("Open Files") },
                    { value: "ask",     label: qsTr("Ask") }
                ]
            }
        }

        SetRow {
            glyph: ""
            title: qsTr("Check again now")
            sub: UsbWatch.devices.length === 1
                 ? qsTr("1 removable drive found")
                 : qsTr("%1 removable drives found").arg(UsbWatch.devices.length)

            SetButton {
                text: qsTr("Rescan")
                glyph: ""
                tone: page.tone
                onClicked: UsbWatch.refresh()
            }
        }

        SetRow {
            glyph: ""
            title: qsTr("Drives are mounted automatically")
            sub: qsTr("Under your own account. No administrator password is needed.")
        }

        SetRow {
            glyph: ""
            title: qsTr("Nothing polls")
            sub: qsTr("The system announces the change the moment it happens, and the ")
                 + "list is read once in response. An idle machine runs no timer for this."
        }
    }

    // TRK-3423 — this page owns the three usb_* keys (the Notifications copy
    // of `usb_notify` became a link), and it was the one settings page with
    // writable keys and NO way to reset them.
    SetResetRow {
        what: qsTr("USB & removable devices")
        keys: ["usb_notify", "usb_automount", "usb_action"]
    }
}
