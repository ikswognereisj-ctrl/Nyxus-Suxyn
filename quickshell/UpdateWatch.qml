pragma Singleton
// Nyxus Suxyn — update count without asking. GAP-942 / WIP-526.
//
// nyxus-update-check already writes ~/.cache/nyxus/update-check.json and
// notifies. The Store sidebar already badges. This is the flyout / Start
// reader of that same file so a count exists without editing Bar.qml (BQ).
// FileView is inotify, not a poll.
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: watch

    property int count: 0
    readonly property bool hasUpdates: count > 0

    // TRK-3215 — WHEN it was last checked, not just how many. The same file
    // already carries it: `nyxus-update-check` writes
    // `{"count": N, "checked": <epoch seconds>}`. Zero means the check has
    // never run on this machine (or the file is unreadable).
    //
    // TRK-3538 — every branch here is a fragment meant to follow a
    // "checked " prefix ("checked 5 min ago", "checked just now", "checked
    // never"). It used to return the standalone clause "never checked" for
    // the zero case, which read fine alone but stuttered wherever a caller
    // (Settings.qml's status strip, currently the only one) prepends its own
    // "checked ". Keep every branch a bare fragment so any future caller can
    // prepend "checked " without re-checking this file for the one outlier.
    property int checkedAt: 0
    readonly property string checkedLabel: {
        if (watch.checkedAt <= 0)
            return qsTr("never");
        var mins = Math.floor((Date.now() / 1000 - watch.checkedAt) / 60);
        if (mins < 0)
            return Qt.formatDateTime(new Date(watch.checkedAt * 1000), "d MMM HH:mm");
        if (mins < 1)
            return qsTr("just now");
        if (mins < 60)
            return mins + qsTr(" min ago");
        if (mins < 24 * 60)
            return Math.floor(mins / 60) + qsTr(" h ago");
        return Qt.formatDateTime(new Date(watch.checkedAt * 1000), "d MMM HH:mm");
    }
    readonly property string label: count <= 0
        ? "Updates"
        : (count === 1 ? "1 update" : count + " updates")

    function openStore() {
        Quickshell.execDetached(["nyxus-store", "--section", "updates"]);
    }
    function openSettings() {
        Bus.openSettings("updates");
    }
    function openBackup() {
        Bus.openSettings("backup");
    }
    function start() {}

    FileView {
        id: stateFile
        path: Quickshell.env("HOME") + "/.cache/nyxus/update-check.json"
        watchChanges: true
        printErrors: false
        onFileChanged: stateFile.reload()
        onLoaded: {
            try {
                var d = JSON.parse(stateFile.text());
                var n = parseInt(d.count, 10);
                watch.count = isNaN(n) ? 0 : n;
                var c = parseInt(d.checked, 10);
                watch.checkedAt = isNaN(c) ? 0 : c;
            } catch (e) {
                watch.count = 0;
                watch.checkedAt = 0;
            }
        }
        onLoadFailed: {
            watch.count = 0;
            watch.checkedAt = 0;
        }
    }
}
