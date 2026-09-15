pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import QtQuick

// THE FLOOR — 10-foot library on HDMI. Glass over Headliner stars.
PanelWindow {
    id: floor

    readonly property bool onTv: floor.screen && String(floor.screen.name || "").indexOf("HDMI") === 0
    // TRK-4150 — was `onTv || Prefs.arcadeMode`, which meant any screen whose
    // name began with HDMI got the ten-foot browser across all of it, with no
    // way for a user to decline: `arcadeMode` is NYXUS_ARCADE out of the
    // environment, a developer's lever rather than a setting. The ISO copies
    // the whole quickshell directory, so all 24 Floor files ship, and a
    // release that opens someone's television into the owner's personal
    // Games/Movies/Music library the moment they plug in a monitor is not a
    // release. Opt-in now, off by default, and the owner's own machine sets
    // `floor_enabled: true` so nothing about his desk changes. The env
    // override stays as its own arm so a developer can still force it on a
    // laptop panel for testing.
    visible: (Prefs.floorEnabled && floor.onTv) || Prefs.arcadeMode

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
