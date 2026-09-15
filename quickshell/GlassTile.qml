pragma ComponentBehavior: Bound
// Start app tile = the same etched crystal as the dock. The Start PANEL is
// the glass furniture; the mark is the stone. Icon colour lives in the
// centre of the ice (ocular_crystal.frag), not as a plate on a well.
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: tile

    property string iconName: ""
    property bool vectorMark: true
    property string label: ""
    property color coreTint: Theme.plumGlow
    property bool pip: false
    property string pipKind: "amber"
    property bool prize: false
    signal activated()

    implicitWidth: prize ? 96 : 108
    implicitHeight: prize ? 100 : 108

    readonly property bool hot: hov.hovered
    readonly property bool down: press.pressed
    readonly property int gemPx: prize ? 64 : 56
    // How far the gem's layout box overhangs its visible silhouette on each
    // side. See the TRK-4144 note on StatusPip below for the measurement.
    readonly property int gemInset: Math.round(tile.gemPx * 0.1328)
    property real lookX: 0
    property real lookY: 0

    HoverHandler {
        id: hov
        cursorShape: Qt.PointingHandCursor
        onPointChanged: {
            if (!hovered || tile.width < 1)
                return;
            tile.lookX = (point.position.x / Math.max(1, tile.width)) * 2 - 1;
            tile.lookY = (point.position.y / Math.max(1, tile.height)) * 2 - 1;
        }
        onHoveredChanged: {
            if (!hovered) {
                tile.lookX = 0;
                tile.lookY = 0;
            }
        }
    }
    TapHandler { id: press; onTapped: tile.activated() }
    Behavior on lookX { NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutQuint } }
    Behavior on lookY { NumberAnimation { duration: Theme.durBase; easing.type: Easing.OutQuint } }

    Pool {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.88
        height: 16
        tone: tile.coreTint
        coreTone: Theme.plumGlow
        focusRatio: 0.55
        strength: tile.hot ? 0.80 : 0.16
    }

    Item {
        id: cab
        width: tile.gemPx
        height: tile.gemPx
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: prize ? 6 : 4
        scale: tile.down ? 0.96 : (tile.hot ? 1.06 : 1.0)
        Behavior on scale {
            NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutQuint }
        }

        CrystalGem {
            anchors.fill: parent
            hot: tile.hot
            on: tile.hot
            tint: tile.coreTint
            lookX: tile.lookX
            lookY: tile.lookY
            iconName: tile.iconName
        }

        StatusPip {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            // TRK-4144 — the pip was floating in space beside the icon.
            //
            // `cab` is a gemPx square, but CrystalGem does not fill it: the
            // silhouette comes from textures/ocular-tile-sdf.png, whose
            // footprint is x/y 68..443 of 512 — centred, symmetric, and
            // 0.7344 of the quad. Measured off the texture, not guessed. So
            // the corner this anchored to sat gemPx * 0.1328 clear of the
            // tile on both axes: about 7 px out and 7 px down at gemPx 56,
            // which reads as a stray amber dot rather than a badge on the
            // Notes and Calculator tiles (the two tilePip() returns true
            // for).
            //
            // The margins put it back on the silhouette's own corner. The
            // tile is rounded, so a 7 px dot there straddles the curve the
            // way a badge should instead of hovering off the diagonal.
            anchors.rightMargin: tile.gemInset
            anchors.bottomMargin: tile.gemInset
            visible: tile.pip
            kind: tile.pipKind
        }
    }

    Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 2
        text: tile.label
        color: tile.hot ? Theme.text : Theme.textMuted
        font.family: Theme.fUi
        font.pixelSize: Theme.tCaption
        font.weight: tile.hot ? Font.DemiBold : Font.Medium
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        clip: true
        Behavior on color { ColorAnimation { duration: Theme.durQuick } }
    }
}
