pragma ComponentBehavior: Bound
// Nyxus Suxyn — THE APP WINDOW. One FloatingWindow chrome for every
// migrated app (Notes, Calculator, Media, Files).
//
// This is the Next Cut template. GTK /opt/nyxus apps do not live here.
// Each app is a QML file in this directory that instantiates AppWindow
// and fills `content`. The live shell owns the instance; `qs ipc` opens it.
//
// ══ WINDOW ═══════════════════════════════════════════════════════════════
// `FloatingWindow`, not PanelWindow: an app you leave open, move, and
// resize — same contract as Settings.qml. Hyprland already floats
// `org.quickshell`. Client-side close because Hyprland draws a border
// and no buttons on a Wayland toplevel.
//
// `color` is transparent so the compositor does not paint a second
// rectangle behind the glass. The FIRST child is an opaque CutRect floor
// (`Theme.surface`) — without it, terminal text reads through the pane
// (owner 2026-08-28, measured in SetSlab.qml: 10.6% transmittance).
// The glass itself is shaders/pane.frag.qsb (the file on disk; there is
// no pane.qsb). Bloom is 0: a floating pane must not spill a 20 px ramp
// onto the desktop (TRK-3651, Pane.qml).
//
// ══ DRAG ════════════════════════════════════════════════════════════════
// Header MouseArea calls startSystemMove(). The close control is outside
// that area so a click on × cannot pick the window up.
//
// ══ STRINGS ═════════════════════════════════════════════════════════════
// Title, subtitle, and any default-slot text the consumer does not wrap
// must set an explicit width and `elide: Text.ElideRight`. The header
// title already does. Content is clipped.
import Quickshell
import QtQuick
import QtQuick.Layouts

FloatingWindow {
    id: win

    // Consumers override. Empty title is still a window people can close.
    property string titleText: qsTr("App")
    property string subtitleText: ""
    property string iconName: ""
    property bool open: false

    // Rim light. Hover on the chrome raises it (HORIZON §4.4 — light, never
    // a second outline colour).
    property real focusLevel: headerHov.hovered ? 1 : 0

    title: win.titleText
    visible: win.open
    color: "transparent"
    // Quickshell 0.3.1 FloatingWindow has no `flags` property (verified
    // load). Hyprland already floats `org.quickshell` and draws no buttons;
    // the close control below is the client-side chrome.

    implicitWidth: 720
    implicitHeight: 480
    minimumSize: Qt.size(420, 280)

    readonly property int headerH: 48
    readonly property int edge: Theme.s6
    readonly property color ice: Theme.paintLayers.glacier[5]
    readonly property color iceHair: Theme.paintLayers.glacier[4]

    // Safe: the alias target declares no children of its own.
    default property alias content: contentSlot.data

    // Do not assign `open` here — that would break a binding to Bus.
    signal dismissed()
    function dismiss() { win.dismissed() }

    // ── 0 · opaque floor ──────────────────────────────────────────────
    CutRect {
        anchors.fill: parent
        radius: Theme.r3
        color: Theme.surface
    }

    // ── 1 · pane.frag.qsb — the glass ────────────────────────────────
    ShaderEffect {
        id: pane
        anchors.fill: parent
        fragmentShader: Qt.resolvedUrl("shaders/pane.frag.qsb")
        blending: true

        property vector4d geom: Qt.vector4d(width, height, 0, 0)
        property vector4d radii: Qt.vector4d(Theme.r3, Theme.r3, Theme.r3, Theme.r3)
        property vector4d body: Qt.vector4d(Theme.panelMid.r, Theme.panelMid.g,
                                            Theme.panelMid.b, Theme.panelMid.a)
        property vector4d look: Qt.vector4d(Theme.e2Rim, 0.42, 0.55, win.focusLevel)
        property vector4d state: Qt.vector4d(Math.max(0.02, Theme.rimDisp0
            + Theme.rimDispGain * Math.max(0, Math.min(1, win.focusLevel))), 0, 0, 0)

        Behavior on look {
            PropertyAnimation {
                duration: Theme.durQuick
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveMove
            }
        }
    }

    // ── 2 · swell (widget stack, same stops as Settings) ─────────────
    CutRect {
        anchors.fill: parent
        radius: Theme.r3
        gradTop: Theme.swellGroundTop
        gradMid: Theme.swellGroundMid
        gradFoot: Theme.swellGroundFoot
    }

    GlassEdge {
        anchors.fill: parent
        radiusTL: Theme.r3; radiusTR: Theme.r3
        radiusBR: Theme.r3; radiusBL: Theme.r3
        body: 0
        wash: 0
        glaze: 1.0
        edging: 1.0
        bleed: 1.0
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.r3
        color: "transparent"
        antialiasing: true
        border.width: 1
        border.color: Theme.soften(win.iceHair, 0.45)
    }

    // ── chrome ───────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 1
        spacing: 0

        Item {
            id: header
            Layout.fillWidth: true
            Layout.preferredHeight: win.headerH
            Layout.maximumHeight: win.headerH
            clip: true

            HoverHandler { id: headerHov }

            MouseArea {
                id: drag
                anchors.fill: parent
                anchors.rightMargin: 36
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.SizeAllCursor
                onPressed: win.startSystemMove()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: win.edge
                anchors.rightMargin: Theme.s4
                spacing: Theme.s4

                CrystalGem {
                    visible: win.iconName.length > 0
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter
                    iconName: win.iconName
                    hot: headerHov.hovered
                    on: win.open
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.maximumWidth: header.width - 36 - win.edge - Theme.s4
                                       - (win.iconName.length > 0 ? 28 + Theme.s4 : 0)
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: win.titleText
                        color: Theme.text
                        font.family: Theme.fUiTitle
                        font.pixelSize: Theme.tHead
                        font.weight: Font.DemiBold
                        font.hintingPreference: Theme.textHint
                        renderType: Theme.textRender
                        elide: Text.ElideRight
                        clip: true
                        maximumLineCount: 1
                        wrapMode: Text.NoWrap
                    }

                    Text {
                        visible: win.subtitleText.length > 0
                        Layout.fillWidth: true
                        text: win.subtitleText
                        color: Theme.textMuted
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        font.hintingPreference: Theme.textHint
                        renderType: Theme.textRender
                        elide: Text.ElideRight
                        clip: true
                        maximumLineCount: 1
                        wrapMode: Text.NoWrap
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignVCenter
                    radius: Theme.r1
                    color: closeHov.hovered ? Theme.soften(Theme.danger, 0.30)
                                            : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.durQuick } }

                    Text {
                        anchors.centerIn: parent
                        text: "\uf00d"
                        font.family: Theme.fIcon
                        font.pixelSize: Theme.tBody
                        color: closeHov.hovered ? Theme.text : Theme.textMuted
                    }

                    HoverHandler { id: closeHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: win.dismiss() }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Theme.soften(win.iceHair, 0.45)
            }
        }

        Item {
            id: contentSlot
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: win.edge
            clip: true
        }
    }
}
