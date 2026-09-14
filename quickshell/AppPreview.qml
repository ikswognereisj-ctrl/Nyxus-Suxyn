pragma ComponentBehavior: Bound
// Nyxus Suxyn — visual proof of AppWindow.qml. Not an app.
//
// Standalone:  qs -p ~/.config/quickshell/AppPreview.qml
// Does not load into the live desktop. A bad edit here cannot take
// the shell down. After sign-off, Notes (then Calculator, Media, Files)
// instantiate AppWindow the same way this file does.
import Quickshell
import QtQuick
import QtQuick.Layouts

ShellRoot {
    AppWindow {
        id: win
        open: true
        titleText: qsTr("App window")
        subtitleText: qsTr("template — drag the header · × closes")
        implicitWidth: 720
        implicitHeight: 480
        onDismissed: win.open = false

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.s5

            Text {
                Layout.fillWidth: true
                text: qsTr("Content slot")
                color: Theme.text
                font.family: Theme.fUiTitle
                font.pixelSize: Theme.tTitle
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
            }

            Text {
                Layout.fillWidth: true
                text: qsTr("Notes, Calculator, Media, and Files drop their layouts here. This window is the chrome only.")
                color: Theme.textMuted
                font.family: Theme.fUi
                font.pixelSize: Theme.tBody
                wrapMode: Text.WordWrap
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.soften(Theme.paintLayers.glacier[4], 0.45)
            }

            Text {
                Layout.fillWidth: true
                // Deliberately longer than the pane: elide must hold.
                text: "session-20260909-untitled-final-mix-tracking-string-very-long-filename.flac"
                color: Theme.paintLayers.glacier[5]
                font.family: Theme.fNum
                font.pixelSize: Theme.tCaption
                elide: Text.ElideRight
                maximumLineCount: 1
                wrapMode: Text.NoWrap
            }

            Item { Layout.fillHeight: true }
        }
    }
}
