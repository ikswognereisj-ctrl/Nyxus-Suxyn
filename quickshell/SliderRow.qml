// Nyxus Suxyn — a Lightbar. Brightness and volume.
//
// HORIZON: the filled part of the track is light filling up, not a generic
// 4 px rail with a white knob. The track is 14 px; the cap at the leading
// edge IS the handle.
//
// 2026-08-19 · KEY PLACES only. Fill is glacier[5] `#b7e6f2`; cap is
// glacier[0] `#7fe8ff`. Owner: drop rose (magenta+teal mixed olive).
// Same track language as SetSlider. Not the full sweep rainbow.
//
// The track takes the press, not just the handle. The first cut only accepted
// a drag that started exactly on a 16 px circle, which means clicking the
// track did nothing — the single most common way people use a slider.
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: row
    property string icon: ""
    property real value: 0.5
    property string label: ""
    // Off by default so the two existing call sites keep their exact shape;
    // the flyout turns it on for the hero pair at the top of the panel.
    property bool showReadout: false
    readonly property color markOn: Theme.stateLayer[5]
    readonly property color markFocus: Theme.stateLayer[0]
    readonly property color markPeak: Theme.stateLayer[6]
    signal moved(real v)

    spacing: Theme.s5

    // TRK-2407 — the mockup's `.srow .ic` is a fixed 20 px column that never
    // shrinks (`width:20; flex:0 0 20px`). This was a bare `Text` carrying
    // only `Layout.preferredWidth`, which is a REQUEST: a row whose minimum
    // exceeds what it is given shrinks a preferred-width item, and a centred
    // glyph wider than its box then hangs outside the box. A floor is what
    // makes the column a column.
    Text {
        Layout.preferredWidth: Theme.s7
        Layout.minimumWidth: Theme.s7
        text: row.icon
        font.family: Theme.fIcon
        font.weight: Font.Black
        font.pixelSize: Theme.tBody
        color: lane.pressing ? Theme.text : Theme.textMuted
        horizontalAlignment: Text.AlignHCenter
        Behavior on color { ColorAnimation { duration: Theme.durQuick } }
    }

    Item {
        id: lane
        Layout.fillWidth: true
        Layout.preferredHeight: 22

        property bool pressing: false
        readonly property real usable: Math.max(1, width)

        function setFromX(px) {
            var v = Math.max(0, Math.min(1, px / lane.usable));
            row.value = v;
            row.moved(v);
        }

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 14
            radius: height / 2
            // Was `soften(text, 0.08)` -- white at 8%, which is a GREY, and
            // §4.5 is explicit that a dark in this palette is a saturated
            // colour and never a grey. The groove is now thin glass: the same
            // body the bar uses, so the light below sits IN something rather
            // than on top of a pale smear.
            color: Theme.shelfDeep

            SwirlChip {
                anchors.fill: parent
                z: 0
                bare: true
                cornerRadius: track.radius
                hostHovered: laneHov.hovered
                hostPressed: lane.pressing
            }

            // Quiet edge only. A 14 px groove is the thin pane, not a slab, so
            // the Glaze is off -- it already has a body of its own, which is
            // the condition GlassEdge documents for glaze 0.
            GlassEdge {
                anchors.fill: parent
                radiusTL: track.radius
                radiusTR: track.radius
                radiusBR: track.radius
                radiusBL: track.radius
                edging: lane.pressing ? 0.70 : 0.45
                glaze: 0.0
                wash: 0
            }

            // Inner well — the cut inside the glass. 4 px at the top of the
            // groove, above GlassEdge so the sheen cannot hide it. Not a
            // 1 px hairline (Calendar: 2 px was invisible).
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
                    id: fill
                    width: Math.max(track.height,
                                    Math.min(1, Math.max(0, row.value)) * track.width)
                    height: parent.height
                    radius: height / 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0.0
                            color: Theme.soften(row.markOn, 0.55)
                        }
                        GradientStop { position: 1.0; color: row.markOn }
                    }

                    // 4 px glacier[6] catch-light along the TOP of the fill.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 4
                        radius: 2
                        gradient: Gradient {
                            GradientStop {
                                position: 0.0
                                color: Theme.soften(row.markPeak, 0.90)
                            }
                            GradientStop { position: 1.0; color: Theme.shelfNone }
                        }
                    }

                    // The cap. This is the handle: the leading edge of the
                    // light, brighter than the body it ends, so the value is
                    // legible at a glance without a dot sitting on top of
                    // the thing it is measuring. Interactive rung — key place.
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5
                        height: parent.height - 4
                        radius: 2.5
                        color: row.markFocus
                        opacity: 0.92
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPressed: mouse => { lane.pressing = true; lane.setFromX(mouse.x); }
            onReleased: lane.pressing = false
            onCanceled: lane.pressing = false
            onPositionChanged: mouse => { if (pressed) lane.setFromX(mouse.x); }
        }
        HoverHandler { id: laneHov; enabled: row.enabled }
    }

    Text {
        visible: row.showReadout
        Layout.preferredWidth: row.showReadout ? 38 : 0
        horizontalAlignment: Text.AlignRight
        text: Math.round(Math.max(0, Math.min(1, row.value)) * 100) + "%"
        color: lane.pressing ? row.markFocus : Theme.textMuted
        font.family: Theme.fNum
        font.pixelSize: Theme.tMicro
    }
}
