pragma ComponentBehavior: Bound
// Nyxus Suxyn — recording chip. WIP-464.
//
// Visible while nyxus-record holds its pid file, even after the Capture
// flyout closes. Not the swirl bar (BQ). Magma is the stop control
// (owner: magma = record / destructive).
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nyxus-record-hud"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    visible: RecordWatch.active
    mask: Region { item: RecordWatch.active ? chip : null }

    anchors { top: true; right: true }
    margins.top: Theme.s5
    margins.right: Theme.s5
    implicitWidth: 220
    implicitHeight: 44

    readonly property color magmaHot: Theme.paintLayers.magma[5]
    readonly property color icePeak: Theme.paintLayers.glacier[6]

    Pane {
        id: chip
        anchors.fill: parent
        elevation: 2
        radius: Theme.r2
        // TRK-3370 — the widgets' stack: opaque elevated floor as the Pane
        // fill, panelMid + swellGround below. Arithmetic in SetSlab.qml.
        fill: Theme.elevated
        focusLevel: stopHov.hovered ? 0.55 : 0.35

        Rectangle {
            anchors.fill: parent
            radius: Theme.r2
            color: Theme.panelMid
        }
        Rectangle {
            anchors.fill: parent
            radius: Theme.r2
            gradient: Gradient {
                GradientStop { position: 0.00; color: Theme.swellGroundTop }
                GradientStop { position: 0.50; color: Theme.swellGroundMid }
                GradientStop { position: 1.00; color: Theme.swellGroundFoot }
            }
        }

        GlassEdge {
            // TRK-3653 - small transient HUD - the chip rung, not the pane rung.
            // It had no `edging`, so it took the component default while
            // the rest of the build had moved off it. Found by
            // docs/proof/audit-0901/glass-consistency.py, not by eye.
            edging: 0.70
            anchors.fill: parent
            radiusTL: Theme.r2
            radiusTR: Theme.r2
            radiusBR: Theme.r2
            radiusBL: Theme.r2
            // TRK-3370: body 0 — the slab stack above already carries the
            // ground (a body over it is the WIP-259 failure). Still matches
            // Toasts.qml, which now stands on the same slab.
            body: 0
            wash: 0
        }
        // The mirror rim — Launcher.qml § the mirror rim carries the
        // ruling (2026-08-14, "complete … system wide"). Card weight,
        // SetCard's own numbers. Radii untouched.
        MirrorEdge {
            radiusTL: Theme.r2; radiusTR: Theme.r2
            radiusBR: Theme.r2; radiusBL: Theme.r2
            depth: 12
            strength: 0.62
        }

        // ── 4 · THE SEAM (TRK-3372) ─────────────────────────────────
        // 1 px glacier[4]. `SetSlab.qml` — which this HUD's stack is a
        // hand-carried copy of — draws it on every surface it dresses;
        // the copy stopped after the edge. Same rung, same resting alpha.
        Rectangle {
            anchors.fill: parent
            radius: Theme.r2
            color: "transparent"
            antialiasing: true
            border.width: 1
            border.color: Theme.soften(Theme.lookSeam, 0.45)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.s4
            anchors.rightMargin: Theme.s3
            spacing: Theme.s3

            Rectangle {
                Layout.preferredWidth: 8
                Layout.preferredHeight: 8
                radius: 4
                color: root.magmaHot
            }
            Text {
                Layout.fillWidth: true
                text: qsTr("Recording")
                color: root.icePeak
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                elide: Text.ElideRight
                clip: true
            }
            Text {
                text: qsTr("Stop")
                color: stopHov.hovered ? root.magmaHot : Theme.textMuted
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                font.weight: Font.Medium
            }
        }
        HoverHandler { id: stopHov; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: RecordWatch.stop()
        }
    }
}
