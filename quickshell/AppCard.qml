pragma ComponentBehavior: Bound
// Luxury instrument card for glass apps. Pane + swell + GlassEdge body 0
// + glacier[4] seam. glacier[0] is hover rim only. Magma pip is rare.
import QtQuick
import QtQuick.Layouts

Item {
    id: card

    property string kicker: ""
    property string value: ""
    property string unit: ""
    property string telemetry: ""
    property string pipKind: "off"   // ice | amber | magma | off
    property bool live: false
    property bool selected: false
    property real fill: -1
    signal activated()

    Layout.fillWidth: true
    implicitHeight: 118
    implicitWidth: 220
    clip: true

    readonly property color iceHair: Theme.lookSeam
    readonly property bool hot: cardHov.hovered || card.selected

    HoverHandler { id: cardHov; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: tap; onTapped: card.activated() }

    scale: tap.pressed ? 0.985 : (cardHov.hovered ? 1.012 : 1.0)
    Behavior on scale {
        NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutQuint }
    }

    CutRect {
        anchors.fill: parent
        radius: Theme.r2
        color: Theme.elevated
    }
    Pane {
        anchors.fill: parent
        elevation: 1
        bloomAtRest: false
        fill: Theme.panelMid
        radius: Theme.r2
        focusLevel: card.hot ? 0.55 : 0.12
        crown: card.hot ? 0.90 : 0.68

        CutRect {
            anchors.fill: parent
            radius: Theme.r2
            gradTop: Theme.swellGroundTop
            gradMid: Theme.swellGroundMid
            gradFoot: Theme.swellGroundFoot
        }
        GlassEdge {
            anchors.fill: parent
            radiusTL: Theme.r2; radiusTR: Theme.r2
            radiusBR: Theme.r2; radiusBL: Theme.r2
            body: 0
            wash: 0
            edging: 0.70
        }
        CutRect {
            anchors.fill: parent
            radius: Theme.r2
            color: "transparent"
            borderWidth: Theme.lookOutlineW
            borderColor: Theme.soften(card.iceHair, card.hot ? 0.85 : 0.50)
            Behavior on borderColor { ColorAnimation { duration: Theme.durQuick } }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.s5
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                StatusPip {
                    kind: card.pipKind
                    pulse: card.live
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    Layout.fillWidth: true
                    text: card.kicker
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    font.weight: Theme.wStrong
                    font.letterSpacing: Theme.trackMicro
                    elide: Text.ElideRight
                    clip: true
                }
                Text {
                    visible: card.telemetry.length > 0
                    text: card.telemetry
                    color: Theme.textMuted
                    font.family: Theme.fNum
                    font.pixelSize: Theme.tMicro
                    font.features: ({ "tnum": 1 })
                    elide: Text.ElideRight
                    Layout.maximumWidth: 88
                    clip: true
                }
            }

            Row {
                spacing: 6
                Layout.fillWidth: true
                clip: true
                Text {
                    text: card.value
                    color: Theme.text
                    font.family: Theme.fNum
                    font.pixelSize: Theme.tTitle
                    font.weight: Font.DemiBold
                    font.features: ({ "tnum": 1 })
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, parent.width - unitLab.implicitWidth - 8)
                    clip: true
                }
                Text {
                    id: unitLab
                    anchors.baseline: parent.children[0].baseline
                    visible: card.unit.length > 0
                    text: card.unit
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    font.weight: Theme.wStrong
                    font.letterSpacing: Theme.trackMicro
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                visible: card.fill >= 0
                Rectangle {
                    anchors.fill: parent
                    radius: 3
                    // TRK-4149 — was `soften(void_, 0.50)`. void_ is darker
                    // than the card this sits on, so at half alpha the unfilled
                    // run came out BELOW its own background: measured #0E0A0C
                    // of track against #151210 of card. A meter track that is
                    // darker than the surface around it does not read as the
                    // channel the fill runs in, it reads as a scuff on the
                    // card -- which is exactly what the owner saw and called
                    // "darker spots, looks like a line going through it". The
                    // bar looked like a floating stick with a smear trailing
                    // off it instead of a bar sitting in a groove.
                    // The channel is the accent at low alpha now, so the empty
                    // run quietly shows the colour it is going to become. It
                    // reads as part of the instrument, it cannot fall below
                    // the card the way a fixed dark did because it is keyed to
                    // the same accent as the fill, and it follows both looks
                    // for free instead of being a hardcoded near-black.
                    color: Theme.soften(Theme.tokenAccentPrimary, 0.14)
                    Rectangle {
                        height: parent.height
                        width: parent.width * Math.max(0, Math.min(1, card.fill))
                        radius: 3
                        color: Theme.tokenAccentPrimary
                        Behavior on width {
                            NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutQuint }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
