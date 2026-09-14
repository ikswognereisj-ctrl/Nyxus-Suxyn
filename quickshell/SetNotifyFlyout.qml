pragma ComponentBehavior: Bound
// Nyxus Suxyn — the Settings NOTIFICATIONS FLYOUT. TRK-3217.
//
// ══ what this is ═══════════════════════════════════════════════════════════
// The right-hand panel in the owner's 2026-08-27 mockup
// (`01-apps-notifications-page`): the global switches, the live notification
// entries, and a card of per-app switches.
//
// ══ IT IS A DRAWER, NOT A LAYER SURFACE (TRK-3224) ═════════════════════════
// It shipped once as a `PanelWindow` on `WlrLayer.Overlay`, mapped for as
// long as Settings was open. Owner, 2026-08-28: it sat on top of everything
// he put beside Settings and there was no way to put it away. An Overlay
// layer surface outranks every normal toplevel by protocol, so that is not a
// stacking bug to tune — it is the wrong kind of surface. It is now an `Item`
// inside the Settings window: it shares that window's stacking, and it slides
// in and out on a control, closed by default.
//
// Owner ruling TRK-1811 — **one section at a time, the rail is the switcher**
// — is enforced by the host: `Settings.qml` holds one `drawer` string, so
// opening this closes the utility hub and the other way round.
//
// ══ everything on it is real ═══════════════════════════════════════════════
//   · the entries are `Sys.notifications` — the tracked list from the
//     NotificationServer this shell IS. Dismiss really dismisses; the count
//     is the length of that model, never a figure typed into a label.
//   · Do Not Disturb is `Sys.dnd`, which persists to `notify_dnd`.
//   · the chime switch is `ui_sound_notify`, the SAME key
//     `SetPageNotifications` writes, so the page and this panel cannot
//     disagree. (TRK-3423: the reader-less `notify_sound` twin is gone.)
//   · the per-app switches write `notify_apps` and are ENFORCED in
//     `Sys.qml`'s one notification path (`appNotifyAllowed` /
//     `appNotifySound`). A switch here changes what the machine does, not
//     what this file draws.
//   · the app list is DERIVED from apps that have actually sent a
//     notification in this session plus any that already carry a rule
//     (`Sys.notifyApps`). It is never a stock list of application names.
//
// The mockup's third per-app row — "Show on Lock Screen" — is deliberately
// absent: this build's lock surface (`shell/Lock.qml`) does not render
// notifications at all, so the switch would have nothing to switch.
// CHECKLIST TRK-3220 carries that, rather than a dead toggle carrying it.
//
// Colour: `SetSlab` everywhere — the one opaque Settings material, whose
// header carries the numbers that put it on his widgets' measured colour.
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: fly

    // ── the drawer ──────────────────────────────────────────────────────
    // Always laid out; `x` is what moves. `visible` follows the slide so a
    // closed drawer takes no paint and no input.
    property bool open: false
    signal closeRequested()

    readonly property int bodyW: 300

    width: fly.bodyW
    x: fly.open ? (fly.parent ? fly.parent.width - fly.bodyW : 0)
                : (fly.parent ? fly.parent.width : 0)
    visible: fly.parent ? fly.x < fly.parent.width : false
    Behavior on x {
        NumberAnimation {
            duration: Theme.durBase
            easing.type: Easing.Bezier
            easing.bezierCurve: fly.open ? Theme.curveRise : Theme.curveSink
        }
    }

    readonly property var entries: {
        var model = Sys.notifications;
        if (!model)
            return [];
        var list = (model.values !== undefined && model.values !== null)
                   ? model.values : model;
        return list ? list : [];
    }

    // TRK-3223 — the one opaque Settings material. A drawer that slides over
    // the page must hide it; the old `panelMid` + swell stack showed 10.6% of
    // whatever was beneath, which over a terminal is the defect the owner
    // photographed.
    SetSlab {
        id: pane
        anchors.fill: parent
        cornerRadius: Theme.r2
        level: 2

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.s4
            spacing: Theme.s3

            // ── the head ────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s3

                Text {
                    Layout.fillWidth: true
                    text: qsTr("Notifications")
                    color: Theme.text
                    // TRK-3431: fUi — a 13px strip label is body type, not a
                    // display face.
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tBody
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    text: fly.entries.length
                    visible: fly.entries.length > 0
                    color: Theme.textDim
                    font.family: Theme.fNum
                    font.pixelSize: Theme.tMicro
                }

                // Dismiss everything waiting.
                Text {
                    text: ""
                    visible: fly.entries.length > 0
                    font.family: Theme.fIcon
                    font.pixelSize: Theme.tCaption
                    color: clearHov.hovered ? Theme.text : Theme.textDim
                    HoverHandler { id: clearHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: Sys.clearNotifications() }
                }

                // Put the drawer away. Escape and the scrim do it too — the
                // host owns both — but a person who opened this with a button
                // expects to see the way back on the panel.
                Text {
                    text: ""
                    font.family: Theme.fIcon
                    font.pixelSize: Theme.tCaption
                    color: shutHov.hovered ? Theme.text : Theme.textDim
                    HoverHandler { id: shutHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: fly.closeRequested() }
                }
            }

            // ── the global switches ─────────────────────────────────
            Slab {
                Layout.fillWidth: true
                Layout.preferredHeight: 74

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.s3
                    spacing: 0

                    SwitchLine {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        label: qsTr("Allow notifications")
                        reading: Sys.dnd ? qsTr("Quiet") : qsTr("On")
                        // The switch reads "allowed", so it is the INVERSE of
                        // Do Not Disturb — one state, drawn the way the label
                        // is worded, never a second key.
                        checked: !Sys.dnd
                        onPicked: function (v) { Sys.dnd = !v; }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Theme.soften(Theme.lookSeam, 0.55)
                    }

                    SwitchLine {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        label: qsTr("Play sound")
                        reading: Prefs.uiSoundNotify ? qsTr("On") : qsTr("Off")
                        checked: Prefs.uiSoundNotify
                        // TRK-3423: `notify_sound` had zero readers — one key.
                        onPicked: function (v) {
                            SettingsStore.setValue("ui_sound_notify", v);
                        }
                    }
                }
            }

            // ── the live entries ────────────────────────────────────
            Slab {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 120

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.s3
                    spacing: Theme.s2

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("WAITING")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                        font.weight: Font.DemiBold
                        font.letterSpacing: Theme.trackMicro
                    }

                    ListView {
                        ScrollRail { flick: notifList }
                        id: notifList
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: Theme.s2
                        model: fly.entries
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Item {
                            id: entryRow
                            required property var modelData
                            width: notifList.width
                            height: entryCol.implicitHeight + Theme.s3

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.r1
                                color: entryHov.hovered
                                       ? Theme.soften(Theme.paintLayers.glacier[0], 0.10)
                                       : "transparent"
                            }

                            ColumnLayout {
                                id: entryCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.topMargin: Theme.s2
                                anchors.leftMargin: Theme.s3
                                anchors.rightMargin: Theme.s3
                                spacing: 0

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.s2

                                    Text {
                                        Layout.fillWidth: true
                                        text: String(entryRow.modelData.summary || "")
                                        color: Theme.text
                                        font.family: Theme.fUi
                                        font.pixelSize: Theme.tMicro
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: ""
                                        visible: entryHov.hovered
                                        font.family: Theme.fIcon
                                        font.pixelSize: Theme.tMicro
                                        color: Theme.textDim
                                        TapHandler {
                                            onTapped: entryRow.modelData.dismiss()
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: String(entryRow.modelData.appName || "")
                                    visible: text !== ""
                                    color: Theme.textDim
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tMicro
                                    elide: Text.ElideRight
                                }
                            }

                            HoverHandler { id: entryHov; cursorShape: Qt.PointingHandCursor }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: fly.entries.length === 0
                        text: qsTr("Nothing waiting.")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                    }
                }
            }

            // ── the per-app rules ───────────────────────────────────
            Slab {
                Layout.fillWidth: true
                Layout.preferredHeight: appsCol.implicitHeight + 2 * Theme.s3
                Layout.maximumHeight: 220

                ColumnLayout {
                    id: appsCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.s3
                    spacing: Theme.s2

                    Text {
                        Layout.fillWidth: true
                        text: qsTr("PER APP")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                        font.weight: Font.DemiBold
                        font.letterSpacing: Theme.trackMicro
                    }

                    Repeater {
                        model: Sys.notifyApps.slice(0, 4)

                        delegate: ColumnLayout {
                            id: appBlock
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: String(appBlock.modelData)
                                color: Theme.text
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tMicro
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            SwitchLine {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                label: qsTr("Allow")
                                checked: Sys.appNotifyAllowed(appBlock.modelData)
                                onPicked: function (v) {
                                    Sys.setAppNotifyRule(appBlock.modelData, "allow", v);
                                }
                            }

                            SwitchLine {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                label: qsTr("Play sound")
                                checked: Sys.appNotifySound(appBlock.modelData)
                                onPicked: function (v) {
                                    Sys.setAppNotifyRule(appBlock.modelData, "sound", v);
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: Sys.notifyApps.length === 0
                        wrapMode: Text.WordWrap
                        text: qsTr("No app has sent a notification yet. One appears here as soon as it does.")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                    }

                    Text {
                        Layout.fillWidth: true
                        visible: Sys.notifyApps.length > 4
                        text: (Sys.notifyApps.length - 4) + qsTr(" more in Settings ▸ Notifications")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    // ══ the parts ══════════════════════════════════════════════════════

    component Slab: Item {
        default property alias content: inner.data

        // TRK-3223 — the one opaque material, same as every other card.
        SetSlab {
            anchors.fill: parent
            cornerRadius: Theme.r2
            level: 1
        }

        Item { id: inner; anchors.fill: parent }
    }

    // One labelled switch. Driven mode on `SetSwitch` — this panel owns
    // where the value goes, because two of these three destinations are not
    // a single settings key.
    component SwitchLine: RowLayout {
        id: line
        property string label: ""
        property string reading: ""
        property bool checked: false
        signal picked(bool value)
        spacing: Theme.s3

        Text {
            Layout.fillWidth: true
            text: line.label
            color: Theme.text
            font.family: Theme.fUi
            font.pixelSize: Theme.tMicro
            elide: Text.ElideRight
        }

        Text {
            text: line.reading
            visible: line.reading !== ""
            color: Theme.textDim
            font.family: Theme.fUi
            font.pixelSize: Theme.tMicro
        }

        SetSwitch {
            id: lineSwitch
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 38
            implicitHeight: 20
            checked: line.checked
            // RE-BIND. In driven mode `SetSwitch.activate()` ASSIGNS its own
            // `checked`, which destroys the binding above — after one tap the
            // switch would stop following the value it is showing and would
            // drift the first time that value changed anywhere else.
            // Restoring the binding here is the whole fix, and it has to come
            // after `picked`, because that is what makes the change.
            onToggled: function (v) {
                line.picked(v);
                lineSwitch.checked = Qt.binding(function () { return line.checked; });
            }
        }
    }
}
