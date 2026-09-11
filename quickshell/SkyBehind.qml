// Nyxus Suxyn — the sky the widget chips already sit on, cropped into a pane.
//
// Widget chips live on WlrLayer.Bottom over the Headliner (or wallpaper).
// Overlay / Top popups sit over WINDOWS, so the same panelMid + swell reads
// as a hole. Painting Theme.elevated under them (TRK-3082 first cut) made a
// dark teal box and killed the plum mix. This item is the missing layer:
// the current sky, screen-aligned, opaque, rounded to the pane, UNDER the
// glass. Windows cannot show through; the glass still mixes like a chip.
//
// HeadlinerSky is an Item (lock / screensaver already host it). Instantiated
// at SCREEN size with a negative offset so the fibre lattice matches the
// desktop, then clipped. Loader.active follows `live` so a hidden popup
// does not keep a second 25 fps sky (WIP-245: do not leave a shader ticking
// in an unmapped window).
//
// Voyage / 2D Starlight have no Item form (they are PanelWindows). Those
// modes get the true-black floor the Headliner uses in the gaps — not a
// second raymarch. Default sky_mode is headliner.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool live: true
    property real paneScreenX: 0
    property real paneScreenY: 0
    property int screenW: 1920
    property int screenH: 1080
    property int radius: Theme.r3

    clip: true
    layer.enabled: root.radius > 0 && root.width > 2 && root.height > 2
    layer.smooth: true
    layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: roundMask
    }

    Item {
        id: roundMask
        width: root.width
        height: root.height
        visible: false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            color: Theme.text
            radius: root.radius
            antialiasing: true
        }
    }

    // Headliner.qml window colour. HeadlinerSky is transparent in the gaps.
    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    Loader {
        active: root.live && Prefs.skyWantsHeadliner
                && root.screenW > 8 && root.screenH > 8
        width: root.screenW
        height: root.screenH
        x: -root.paneScreenX
        y: -root.paneScreenY
        sourceComponent: HeadlinerSky {
            active: root.live
            twinkling: true
        }
    }

    readonly property url skyStill: {
        if (root.wallUrl !== "")
            return root.wallUrl;
        if (Prefs.skyWantsLayered && Prefs.layeredWallBg !== "")
            return Prefs.layeredWallBg;
        return "";
    }

    Loader {
        // Wallpaper still AND layered mode. Overlay panes (Start, flyout)
        // sit over windows, so without this they get the black floor and
        // read as a slab while widget chips sit on the real sky.
        // Headliner stays the other Loader. Voyage stays black.
        active: root.live
                && (Prefs.skyWantsWallpaper || Prefs.skyWantsLayered)
                && root.screenW > 8 && root.screenH > 8
                && root.skyStill !== ""
        width: root.screenW
        height: root.screenH
        x: -root.paneScreenX
        y: -root.paneScreenY
        sourceComponent: Image {
            source: root.skyStill
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }
    }

    property url wallUrl: ""

    FileView {
        id: wallConf
        path: (Quickshell.env("HOME") || "") + "/.config/nyxus/wallpaper.conf"
        watchChanges: true
        printErrors: false
        onFileChanged: wallConf.reload()
        onLoaded: root.wallUrl = root._pathToUrl(root._parseWallPath(wallConf.text()))
        onLoadFailed: root.wallUrl = ""
    }

    function _parseWallPath(raw) {
        var lines = String(raw).split("\n");
        for (var i = 0; i < lines.length; i++) {
            var ln = lines[i];
            if (ln.indexOf("WALLPAPER_PATH=") === 0) {
                var p = ln.substring(15);
                if (p.charAt(0) === "\"" && p.charAt(p.length - 1) === "\"")
                    p = p.substring(1, p.length - 1);
                return p;
            }
        }
        return "";
    }

    function _pathToUrl(p) {
        if (!p || p.length < 2)
            return "";
        if (p.indexOf("file:") === 0)
            return p;
        return "file://" + p;
    }
}
