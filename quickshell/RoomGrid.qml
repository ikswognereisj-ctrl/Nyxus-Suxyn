pragma ComponentBehavior: Bound
// Nyxus Suxyn — THE ROOMS: the grid, drawn once (TRK-1701).
//
// ONE drawing of the grid, used by the HUD map (Station.qml) and by the
// Settings page (SetPageStation.qml). A second drawing is how the map and the
// page start disagreeing about which room you are in.
//
// WHAT A CELL SAYS, and how it says it — by SHAPE, never by hue alone:
//   the room you are IN   a FILLED ground (the tint at low alpha). Filled is
//                         the "on" state everywhere in this shell.
//   focus / hover         a 2 px ring OUTSIDE the cell. Focus is a ring, "on"
//                         is a fill: two different shapes, so they read apart
//                         even when both are the same glacier tint. (Adding a
//                         second hue to separate them is the door the purple
//                         came through; it stays shut.)
//   windows in the room   filled dots along the bottom edge, one per window up
//                         to five, then a count. An empty room has none, so
//                         occupied and empty are one glance apart.
//   the workspace number  in the cell's corner, always. ws = row * cols + col
//                         + 1, so the map is also the explanation of the map.
//   carrying              the strip under the grid, with a drawn mark (no
//                         glyph, no emoji) and the window's title in words.
//
// Everything is laid out on whole pixels — integer cell sizes, integer gaps,
// Math.round on every x/y — because a half-pixel border is a blurry border
// and this is the surface the owner looks at most.
import QtQuick

Item {
    id: gridView

    // when false every cell is inert: a click cannot land on a map that is
    // fading, or on the Settings page's preview
    property bool interactive: false
    property int cellW: 76
    property int cellH: 44
    property int gap: 6
    property bool showCarry: true
    // the room the grid should mark as "you are here". Bound to Rooms by
    // default; the Settings page can pass its own for a preview.
    property int hereWs: Rooms.liveWs
    property int focusWs: 0                     // the cell under the pointer / keyboard

    signal jump(int ws)

    readonly property int cols: Rooms.cols
    readonly property int rows: Rooms.rows
    implicitWidth: cols * cellW + (cols - 1) * gap
    implicitHeight: rows * cellH + (rows - 1) * gap
                  + (showCarry && Rooms.carrying !== "" ? carryStrip.height + gap : 0)

    // ── the cells ────────────────────────────────────────────────────────
    Repeater {
        model: gridView.rows * gridView.cols

        Rectangle {
            id: cell
            required property int index
            readonly property int row: Math.floor(index / gridView.cols)
            readonly property int col: index % gridView.cols
            // THE FORMULA lives in Rooms and nowhere else — the map's click
            // and the arrow keys reach the same workspace through this call
            readonly property int ws: Rooms.wsOf(row, col)
            readonly property string name: Rooms.roomAt(row, col)
            readonly property bool here: ws === gridView.hereWs
            readonly property bool focused: ws === gridView.focusWs
            readonly property int wins: Rooms.countOf(ws)
            readonly property color tintc: Rooms.tint(name)

            x: Math.round(col * (gridView.cellW + gridView.gap))
            y: Math.round(row * (gridView.cellH + gridView.gap))
            width: gridView.cellW
            height: gridView.cellH
            radius: 8
            visible: name !== ""

            // "on" is a FILL. An empty room is a plain glass ground.
            color: here ? Qt.rgba(tintc.r, tintc.g, tintc.b, 0.26) : Theme.glassFill
            border.width: 1
            border.color: here ? tintc : Theme.soften(Theme.text, wins > 0 ? 0.40 : 0.11)
            Behavior on color { ColorAnimation { duration: Theme.durBase; easing.type: Easing.OutCubic } }
            Behavior on border.color { ColorAnimation { duration: Theme.durBase } }

            // focus is a RING, and it sits outside the cell so it can never be
            // mistaken for the fill
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: parent.radius + 3
                color: "transparent"
                border.width: 2
                border.color: cell.focused ? Theme.soften(cell.tintc, 0.85) : "transparent"
                Behavior on border.color { ColorAnimation { duration: Theme.durQuick } }
            }

            // the workspace number — small, in the corner, always
            Text {
                x: 6
                y: 5
                text: String(cell.ws)
                color: cell.here ? Theme.textMuted : Theme.textDim
                font.family: Theme.fNum
                font.pixelSize: Theme.tMicro
                renderType: Text.NativeRendering
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                // lifted only when there are dots to make room for. Rendering
                // the grid with an empty room showed the name sitting 2 px
                // high when nothing was below it.
                y: Math.round((cell.height - height) / 2) - (cell.wins > 0 ? 3 : 0)
                text: cell.name
                color: cell.here ? Theme.text : Theme.textMuted
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                font.letterSpacing: 0.5
                font.weight: cell.here ? Font.DemiBold : Font.Normal
                renderType: Text.NativeRendering
                elide: Text.ElideRight
                width: cell.width - 10
                horizontalAlignment: Text.AlignHCenter
            }

            // occupancy: one dot per window up to five, then "5+"
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5
                spacing: 3
                visible: cell.wins > 0
                Repeater {
                    model: Math.min(cell.wins, 5)
                    Rectangle {
                        width: 4
                        height: 4
                        radius: 2
                        color: cell.here ? cell.tintc : Theme.soften(Theme.text, 0.55)
                    }
                }
                Text {
                    visible: cell.wins > 5
                    text: "+"
                    color: Theme.soften(Theme.text, 0.55)
                    font.family: Theme.fNum
                    font.pixelSize: Theme.tMicro
                    renderType: Text.NativeRendering
                }
            }

            // the whole cell is the hit target, and it is dead while the map
            // is not fully up — a stray click on a fading overlay must not
            // teleport anyone
            MouseArea {
                anchors.fill: parent
                enabled: gridView.interactive && cell.name !== ""
                hoverEnabled: gridView.interactive
                cursorShape: Qt.PointingHandCursor
                onEntered: gridView.focusWs = cell.ws
                onExited: if (gridView.focusWs === cell.ws) gridView.focusWs = 0
                onClicked: gridView.jump(cell.ws)
            }
        }
    }

    // ── carrying ─────────────────────────────────────────────────────────
    // Not a colour cue: a drawn mark plus the word CARRYING plus the title.
    // Drawn, because a glyph or an emoji is what collapses into a box on a
    // machine that is missing the font.
    Rectangle {
        id: carryStrip
        visible: gridView.showCarry && Rooms.carrying !== ""
        y: Math.round(gridView.rows * (gridView.cellH + gridView.gap))
        width: gridView.cols * gridView.cellW + (gridView.cols - 1) * gridView.gap
        height: 24
        radius: 8
        color: Qt.rgba(Theme.tealGlow.r, Theme.tealGlow.g, Theme.tealGlow.b, 0.16)
        border.width: 2
        border.color: Theme.soften(Theme.tealGlow, 0.8)

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            // the mark: a small square lifted off a line — something held up
            Item {
                width: 12
                height: 12
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    x: 1; y: 0; width: 10; height: 7; radius: 2
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.tealGlow
                }
                Rectangle {
                    x: 0; y: 10; width: 12; height: 2
                    color: Theme.soften(Theme.tealGlow, 0.7)
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("CARRYING")
                color: Theme.text
                font.family: Theme.fUiTitle
                font.pixelSize: Theme.tMicro
                font.letterSpacing: 2
                font.weight: Font.DemiBold
                renderType: Text.NativeRendering
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, carryStrip.width - 110)
                text: Rooms.carriedTitle
                color: Theme.textMuted
                font.family: Theme.fUi
                font.pixelSize: Theme.tMicro
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }
        }
    }
}
