pragma ComponentBehavior: Bound
// Tracking / alert pip. Cyan = live. Amber = waiting or failed. Magma = armed.
import QtQuick

Rectangle {
    id: pip

    property string kind: "ice"   // ice | amber | magma | off
    property bool pulse: false

    width: 7
    height: 7
    radius: 3.5
    visible: pip.kind !== "off"
    color: pip.kind === "magma" ? Theme.paintLayers.magma[5]
         : pip.kind === "amber" ? Theme.goldGlow
         : Theme.tokenAccentInteractive
    opacity: pip.pulse ? 0.45 : 1.0

    SequentialAnimation on opacity {
        running: pip.pulse && pip.visible
        loops: Animation.Infinite
        NumberAnimation { to: 1.0; duration: Theme.durRise; easing.type: Easing.OutQuint }
        NumberAnimation { to: 0.35; duration: Theme.durSettle; easing.type: Easing.OutQuint }
    }
}
