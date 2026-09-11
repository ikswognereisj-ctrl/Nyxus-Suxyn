// Nyxus Suxyn — a labelled read-only meter (processor, memory).
//
// The same visual grammar as SliderRow, minus the handle: a label, a track
// that fills with the signature sweep, and a readout. A meter and a slider
// look related because they are the same object with and without a grip.
import QtQuick
import QtQuick.Layouts

// TRK-1808: this was a ROW -- label | track | readout -- so two fixed text
// columns ate 140 px of a 284 px pane and the meter itself was a ~140 px stub
// between them. It is now a COLUMN: the label and the readout share one line,
// and the track gets the whole width underneath. Every caller already places
// MeterRow inside a ColumnLayout with fillWidth, so no call site changes; the
// row is ~10 px taller, which is the cost of the track being a track.
ColumnLayout {
    id: meter
    property string label: ""
    property real value: 0          // 0..1
    property string readout: ""
    // Magma only when the value is a warning (hot / near-full). Ice rest.
    property bool hot: false
    // ACCEPTED, DELIBERATELY INERT (owner 2026-09-07). d3e96c6f made the
    // fill's colour follow its magnitude; he asked for "how they were
    // before", and before is glacier at every reading with magma only when
    // the caller says `hot`. The property stays declared so that the call
    // sites still passing it keep LOADING -- see the module docstring.
    property bool banded: true
    readonly property color markOn: hot ? Theme.paintLayers.magma[5]
                                        : Theme.paintLayers.glacier[5]
    // Catch-light: glacier[6] is Theme.tokenAccentPeak. magma[0] only when hot.
    // paintLayers.magma[0] is a hex STRING (#f7a83b). Qt.color() before .r
    // (PQ 08-21); Theme.soften(markPeak) reads channels.
    readonly property color markPeak: hot ? Qt.color(Theme.paintLayers.magma[0])
                                          : Theme.paintLayers.glacier[6]

    spacing: Theme.s3

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.s5

    Text {
        // The label now takes the width it needs and the readout sits hard
        // right, so neither has to be guessed at in advance.
        Layout.fillWidth: true
        text: meter.label
        color: Theme.textMuted
        font.family: Theme.fUi
        font.pixelSize: Theme.tCaption
        elide: Text.ElideRight
    }

    Text {
        horizontalAlignment: Text.AlignRight
        text: meter.readout
        color: meter.hot ? meter.markPeak : Theme.tokenAccentPrimary
        font.family: Theme.fNum
        font.pixelSize: Theme.tMicro
    }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 12
        radius: height / 2
        // Was `soften(text, 0.10)` -- white at 10%, a GREY, which §4.5 bans:
        // a dark in this palette is a saturated colour. Same defect the slider
        // groove carried.
        //
        // Deliberately NO GlassEdge here, and the reason is arithmetic rather
        // than taste. `edging` scales the Lip's OPACITY, never its height:
        // GlassEdge fixes the Lip at Theme.glassLipH (3 px). On a 12 px groove
        // that Lip is a quarter of the height and would eat the inner well.
        // Sliders at 14 px carry GlassEdge because they also have a cap; a
        // meter has no cap and stays a short track. The 4 px well + 4 px fill
        // catch-light are the cut-glass that fits, and none of the part that
        // does not.
        color: Theme.shelfDeep

        // Inner well — the cut inside the glass. 4 px at the top of the
        // groove. Not a 1 px hairline (Calendar: 2 px was invisible).
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 4
            radius: 2
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Theme.soften(Theme.void_, 0.55)
                }
                GradientStop { position: 1.0; color: Theme.shelfNone }
            }
        }

        Item {
            anchors.fill: parent
            clip: true

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, meter.value))
                height: parent.height
                radius: height / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0.0
                        color: Theme.soften(meter.markOn, 0.55)
                    }
                    GradientStop { position: 1.0; color: meter.markOn }
                }
                // 4 px catch-light along the TOP of the fill. Ice is
                // glacier[6] / tokenAccentPeak; hot is magma[0]. Rides the
                // FILL rather than the track because §11.1 is that glass marks
                // what is live -- the empty half of a meter is not. No cap:
                // a meter is the same groove as a slider without a grip.
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 4
                    radius: 2
                    visible: parent.width > 3
                    gradient: Gradient {
                        GradientStop {
                            position: 0.0
                            color: Theme.soften(meter.markPeak, 0.90)
                        }
                        GradientStop { position: 1.0; color: Theme.shelfNone }
                    }
                }

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.durBase
                        easing.type: Easing.Bezier
                        easing.bezierCurve: Theme.curveMove
                    }
                }
            }
        }
    }
}
