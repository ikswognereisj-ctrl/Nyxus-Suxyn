pragma ComponentBehavior: Bound
// One dye on the layer lab: stops, a widget chip, a stone, glass seam, Wear.
import QtQuick
import QtQuick.Layouts

SetCard {
    id: card
    property string layerId: "glacier"
    property string layerLabel: ""
    property string layerNote: ""
    property var ramp: []
    property bool wearing: false

    signal wearRequested(string id)

    heading: card.layerLabel
    note: card.layerNote + (card.wearing ? qsTr("  ·  on the bar") : "")

    readonly property color pale: card.ramp.length > 5 ? card.ramp[5] : "#b7e6f2"
    readonly property color mid: card.ramp.length > 4 ? card.ramp[4] : "#4f7fa6"
    readonly property color dark: card.ramp.length > 1 ? card.ramp[1] : "#123a5e"
    readonly property color peak: card.ramp.length > 6 ? card.ramp[6] : "#eefcff"

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.s2
        Repeater {
            model: 7
            Rectangle {
                required property int index
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 6
                color: card.ramp.length > index ? card.ramp[index] : "#123a5e"
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.s4

        Rectangle {
            Layout.preferredWidth: 168
            Layout.preferredHeight: 88
            radius: Theme.r2
            color: Qt.rgba(card.dark.r, card.dark.g, card.dark.b, 0.92)
            border.width: 1
            border.color: card.mid

            Column {
                anchors.centerIn: parent
                spacing: 2
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "14:32"
                    color: card.pale
                    font.family: Theme.fTech
                    font.pixelSize: 28
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("widget")
                    color: card.mid
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                }
            }
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 8
                width: 8
                height: 8
                radius: 4
                color: card.peak
            }
        }

        CrystalGem {
            Layout.preferredWidth: 56
            Layout.preferredHeight: 56
            tint: card.pale
            on: card.wearing
            iconName: ""
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            radius: Theme.r2
            color: "transparent"
            border.width: 1
            border.color: card.mid
            Text {
                anchors.centerIn: parent
                text: qsTr("glass seam")
                color: card.pale
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
            }
        }

        SetIceFace {
            Layout.preferredWidth: 120
            Layout.preferredHeight: 56
            compact: true
            kicker: card.wearing ? qsTr("WEARING") : qsTr("WEAR")
            caption: card.layerLabel
            selected: card.wearing
            interactive: true
            onActivated: card.wearRequested(card.layerId)
        }
    }
}
