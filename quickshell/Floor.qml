pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import QtQuick

// THE FLOOR — 10-foot library on HDMI. Glass over Headliner stars.
PanelWindow {
    id: floor

    readonly property bool onTv: floor.screen && String(floor.screen.name || "").indexOf("HDMI") === 0
    visible: floor.onTv || Prefs.arcadeMode

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "nyxus-floor"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    FloorHub {
        id: hub
        anchors.fill: parent
        focus: true
    }
}
