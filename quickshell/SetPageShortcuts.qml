pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ Devices ▸ Keyboard shortcuts.
// TRK-3204. A searchable list of the binds the ISO actually ships.
// Not a second bind engine — Hyprland still owns the keys.
import Quickshell
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    property var entry: null
    title: qsTr("Keyboard shortcuts")
    blurb: qsTr("What the keys do on this machine. Search. Nothing here opens a terminal.")

    property string query: ""

    readonly property var all: [
        { keys: "Super + Space",  does: qsTr("Start menu") },
        { keys: "Super + C",      does: qsTr("Condition") },
        { keys: "Super + Tab",    does: qsTr("Task view") },
        { keys: "Super + Return", does: qsTr("Terminal") },
        { keys: "Super + E",      does: qsTr("Files") },
        { keys: "Super + B",      does: qsTr("Browser") },
        { keys: "Super + L",      does: qsTr("Lock") },
        { keys: "Super + Q",      does: qsTr("Close window") },
        { keys: "Super + F",      does: qsTr("Fullscreen") },
        { keys: "Super + Shift + F", does: qsTr("Maximize") },
        { keys: "Super + Shift + V", does: qsTr("Float window") },
        { keys: "Super + M",      does: qsTr("Minimize") },
        { keys: "Super + P",      does: qsTr("Pseudo-tile") },
        { keys: "Print",          does: qsTr("Screenshot whole screen") },
        { keys: "Shift + Print",  does: qsTr("Screenshot region") },
        { keys: "Alt + Print",    does: qsTr("Screenshot window") },
        { keys: "Ctrl + Alt + Delete", does: qsTr("Power menu") },
        { keys: "Ctrl + Shift + Esc",  does: qsTr("System monitor") },
        { keys: "Ctrl + Alt + arrows", does: qsTr("Walk rooms") },
        { keys: "Super + G",      does: qsTr("Carry a window between rooms") },
        { keys: "Super + arrows", does: qsTr("Snap window") }
    ]

    readonly property var shown: {
        var q = page.query.trim().toLowerCase();
        if (!q)
            return page.all;
        var out = [];
        for (var i = 0; i < page.all.length; ++i) {
            var r = page.all[i];
            var hay = (r.keys + " " + r.does).toLowerCase();
            if (hay.indexOf(q) >= 0)
                out.push(r);
        }
        return out;
    }

    SetCard {
        heading: qsTr("Find a key")
        tone: page.tone
        note: qsTr("These are the binds in the shipped Hyprland config. Changing them is still the compositor page.")

        Pane {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            Layout.preferredHeight: 28
            elevation: 1
            radius: Theme.r1
            fill: Theme.soften(Theme.void_, 0.50)
            focusLevel: qField.activeFocus ? 1.0 : 0.0

            Rectangle {
                anchors.fill: parent
                radius: Theme.r1
                color: "transparent"
                border.width: 1
                border.color: qField.activeFocus
                              ? Theme.paintLayers.glacier[0]
                              : Theme.soften(Theme.text, 0.14)
            }

            TextInput {
                id: qField
                anchors.fill: parent
                anchors.leftMargin: Theme.s4
                anchors.rightMargin: Theme.s4
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                font.family: Theme.fUi
                font.pixelSize: Theme.tLabel
                selectByMouse: true
                clip: true
                onTextChanged: page.query = text
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: qField.text === "" && !qField.activeFocus
                    text: qsTr("Search Start, lock, screenshot…")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tLabel
                }
            }
        }
    }

    SetCard {
        heading: qsTr("Keys")
        tone: page.tone

        Repeater {
            model: page.shown
            delegate: SetRow {
                required property var modelData
                title: modelData.does
                valueText: modelData.keys
            }
        }

        SetRow {
            visible: page.shown.length === 0
            title: qsTr("No matches")
            sub: qsTr("Nothing matches that search")
        }

        SetRow {
            title: qsTr("Keyboard")
            sub: qsTr("Layout and repeat")
            navigates: true
            onActivated: Bus.openSettings("keyboard")
        }
    }
}
