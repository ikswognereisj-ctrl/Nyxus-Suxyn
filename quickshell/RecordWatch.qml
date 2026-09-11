pragma Singleton
// Nyxus Suxyn — is a screen recording running?   WIP-464 / GAP-464.
//
// nyxus-record writes $XDG_RUNTIME_DIR/nyxus-record.pid while wf-recorder
// is alive and unlinks it on stop. FileView watches that file (inotify,
// not a poll). The HUD (RecordHud.qml) and the Capture flyout both read
// `active` so a stop control remains after SidePanel closes.
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: watch

    readonly property string pidPath: {
        var d = Quickshell.env("XDG_RUNTIME_DIR");
        if (d && d.length)
            return d + "/nyxus-record.pid";
        return "/tmp/nyxus-record.pid";
    }
    property bool active: false

    function stop() {
        Quickshell.execDetached(["nyxus-record", "stop"]);
    }
    function toggle() {
        Quickshell.execDetached(["nyxus-record", "toggle"]);
    }
    function start() {}

    FileView {
        id: pidFile
        path: watch.pidPath
        watchChanges: true
        printErrors: false
        onFileChanged: pidFile.reload()
        onLoaded: {
            var t = pidFile.text().trim();
            watch.active = t.length > 0;
        }
        onLoadFailed: watch.active = false
    }
}
