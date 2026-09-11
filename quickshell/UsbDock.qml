pragma ComponentBehavior: Bound
// Nyxus Suxyn — removable drives from the bar (TRK-3192).
//
// Same job as the Windows/macOS tray eject: name what you just plugged in,
// Open it, Eject it. The list is UsbWatch.devices (lsblk + udev) — USB
// sticks and SD. An iPhone only appears after it offers a filesystem
// (Trust This Computer / Files); gvfs-afc is packaged but this surface
// does not invent a phone that lsblk cannot see.
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "nyxus-usb"
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors { bottom: true; right: true }
    margins {
        bottom: Theme.chromeH - Theme.bloomPad + Theme.s5
        right: Theme.s7
    }
    implicitWidth: 300 + Theme.bloomPad * 2
    readonly property int availH:
        (screen ? screen.height : 800) - Theme.chromeH - Theme.s5
        - Theme.bloomPad * 2
    readonly property int bodyH:
        Math.min(dockCol.implicitHeight + Theme.s6 * 2, root.availH)
    implicitHeight: root.bodyH + Theme.bloomPad * 2
    visible: Bus.usbDockOpen

    mask: Region {
        x: pane.x; y: pane.y; width: pane.width; height: pane.height
    }

    HyprlandFocusGrab {
        windows: [root]
        active: Bus.usbDockOpen
        onCleared: Bus.usbDockOpen = false
    }
    Shortcut {
        sequence: "Escape"
        enabled: Bus.usbDockOpen
        onActivated: Bus.usbDockOpen = false
    }
    Connections {
        target: UsbWatch
        function onDeviceRemoved(label) {
            if (UsbWatch.devices.length === 0)
                Bus.usbDockOpen = false;
        }
    }

    // ── 0 · THE OPAQUE FLOOR ────────────────────────────────────────
    // TRK-3372. The dock is `WlrLayer.Overlay`: it opens over your
    // windows, and the Pane's own `panelMid` fill is alpha 0.34, so the
    // whole stack passed the 10.6% backdrop `SetSlab.qml` measures. Under
    // the Pane, not inside it, so the Pane's dispersive rim and bloom are
    // still drawn against the wallpaper rather than over a hard edge.
    Rectangle {
        anchors.fill: parent
        anchors.margins: Theme.bloomPad
        radius: Theme.r3
        color: Theme.elevated
        antialiasing: true
    }

    Pane {
        id: pane
        anchors.fill: parent
        anchors.margins: Theme.bloomPad
        elevation: 2
        fill: Theme.panelMid
        radiusTL: Theme.r3
        radiusTR: Theme.r3
        radiusBL: Theme.r3
        radiusBR: Theme.r3

        Rectangle {
            anchors.fill: parent
            radius: Theme.r3
            gradient: Gradient {
                GradientStop { position: 0.00; color: Theme.swellGroundTop }
                GradientStop { position: 0.50; color: Theme.swellGroundMid }
                GradientStop { position: 1.00; color: Theme.swellGroundFoot }
            }
        }
        GlassEdge {
            anchors.fill: parent
            radiusTL: Theme.r3; radiusTR: Theme.r3
            radiusBL: Theme.r3; radiusBR: Theme.r3
            body: 0
            wash: 0
            edging: 0.85
        }

        // ── 4 · THE SEAM ────────────────────────────────────────────
        // 1 px glacier[4], the rung whose own token says hairlines only.
        // The dock had none: it was relying on the Pane's dispersive rim
        // alone, which is elevation, not the seam. Same value and same
        // alpha `SetSlab.qml` gives every other floating surface.
        Rectangle {
            anchors.fill: parent
            radius: Theme.r3
            color: "transparent"
            antialiasing: true
            border.width: 1
            border.color: Theme.soften(Theme.paintLayers.glacier[4], 0.45)
        }

        ColumnLayout {
            id: dockCol
            anchors.fill: parent
            anchors.margins: Theme.s6
            spacing: Theme.s4

            Text {
                text: qsTr("Removable")
                color: Theme.textMuted
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                font.letterSpacing: 1.2
            }

            Text {
                visible: UsbWatch.devices.length === 0
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: qsTr("Nothing is plugged in. USB sticks and cards show here. A phone shows after it offers files.")
                color: Theme.textMuted
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
            }

            Repeater {
                model: UsbWatch.devices
                delegate: ColumnLayout {
                    id: row
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Theme.s2

                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.name
                        color: Theme.text
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tBody
                        elide: Text.ElideRight
                        clip: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: {
                            var bits = [];
                            if (row.modelData.size)
                                bits.push(row.modelData.size);
                            if (row.modelData.mount)
                                bits.push(row.modelData.mount);
                            else
                                bits.push(qsTr("Not opened yet"));
                            return bits.join(" · ");
                        }
                        color: Theme.textMuted
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        elide: Text.ElideRight
                        clip: true
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.s3
                        Text {
                            text: row.modelData.mount !== "" ? qsTr("Open") : qsTr("Mount")
                            color: Theme.paintLayers.glacier[0]
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: {
                                    if (row.modelData.mount !== "")
                                        Quickshell.execDetached(["xdg-open", row.modelData.mount]);
                                    else
                                        UsbWatch.mount(row.modelData.path);
                                }
                            }
                        }
                        Text {
                            text: qsTr("Eject")
                            color: Theme.danger
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler {
                                onTapped: UsbWatch.eject(row.modelData.path)
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }

            Text {
                text: qsTr("USB settings")
                color: Theme.paintLayers.glacier[0]
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        Bus.usbDockOpen = false;
                        Bus.openSettings("usb");
                    }
                }
            }
        }
    }
}
