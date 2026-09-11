pragma Singleton
// Nyxus Suxyn — the shell's view of the tape.                    TRK-3818
//
// The tape (`/usr/local/bin/nyxus-tape`) keeps the songs the owner is
// actually hearing into ~/Music/NYXUS Keeps. This singleton is the shell's
// READ-ONLY view of whether it is armed and what is on it.
//
// ── ⚠ WHY THIS IS ITS OWN FILE AND NOT A KEY IN Prefs.qml ────────────────
// `Prefs.qml` says it in as many words: "READ-ONLY by design: the settings
// app is the single writer. Never call writeAdapter() here." Arming is a
// control that lives on the BAR, so if armed-ness were a settings.json key
// the bar's right-click would have to write settings.json — making the shell
// a second writer of the one file that rule exists to protect.
//
// So armed-ness lives in its OWN small file, `~/.config/nyxus/tape.json`,
// whose single writer is `nyxus-tape` itself. Both surfaces that show the
// state (the bar's zone menu, Settings ▸ Sound) READ this file, and both
// surfaces that change it SPAWN `nyxus-tape --toggle`. One state, one writer,
// two surfaces, and no way for them to disagree.
//
// The tape's OPTIONS — format and which monitor — are ordinary settings and
// they do live in Prefs.qml/settings.json, written by Settings, exactly like
// every other preference. Only the transient armed-ness is here.
//
// ⚠ `armed` is not a wish, it is a fact the daemon publishes. nyxus-tape
// re-derives it against the recorded pid before printing --status, so a
// daemon killed by a reboot or an OOM cannot leave a surface stuck showing
// ARMED for ever. This file can still go stale between a kill and the next
// read, which is why `stale` exists and why nothing here is a dead toggle:
// pressing it when the state is wrong simply re-arms.
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: tape

    // ── what the surfaces bind to ─────────────────────────────────────────
    //
    // ⚠ `armed` IS THE HEARTBEAT AND THE FLAG, NEVER THE FLAG ALONE.
    // TRK-3829, and this is the difference between an indicator and a
    // decoration. This file is written by the daemon; a daemon that is
    // SIGKILLed (an OOM, a `kill -9`, a session teardown) never gets to
    // write `armed: false`, so the flag alone would leave the bar lit for
    // ever describing a tape that does not exist. The daemon re-stamps
    // `beat` every 10 s while it lives, so a heartbeat older than
    // `staleAfter` means OFF regardless of what the flag says — the
    // indicator decays to the truth on its own, with nothing polled and no
    // process spawned on the bar.
    readonly property int staleAfter: 45     // 4.5 missed beats
    property double nowSec: Date.now() / 1000
    readonly property bool beating: adapter.beat > 0
                                    && (nowSec - adapter.beat) < staleAfter
    readonly property bool armed: adapter.armed === true && beating
    // The flag says armed and reality does not. `nyxus-tape --status`
    // computes the same thing from /proc and calls it the same name.
    readonly property bool stale: adapter.armed === true && !beating

    // ⚠ Runs ONLY while the file claims armed, and stops the moment the
    // heartbeat is declared dead: an idle desktop with the tape off ticks
    // nothing at all.
    Timer {
        interval: 5000
        repeat: true
        running: adapter.armed === true && tape.beating
        onTriggered: tape.nowSec = Date.now() / 1000
    }
    // The track currently being taped, "Artist — Title", or "" when armed
    // but between tracks. ⚠ EMPTY WHILE ARMED IS THE NORMAL, HONEST STATE:
    // arming mid-song deliberately does not tape that song, so the surfaces
    // must be able to say "starts with the next song" rather than implying
    // something is being captured when nothing is.
    readonly property string taping: adapter.taping || ""
    readonly property int kept: adapter.kept
    readonly property string last: adapter.last || ""
    readonly property string keepsDir: adapter.dir || ""
    // The monitor source actually resolved at arm time — a fact, not the
    // preference. The preference is Prefs.tapeSource; this is what it became.
    readonly property string source: adapter.source || ""

    readonly property bool waitingForNextTrack: armed && taping.length === 0

    // ── ⚠ FOUR STATES, AND THE FOURTH IS THE ONE HE WAS BITTEN BY ────────
    //                                                          TRK-3959
    // Owner, 2026-09-08: "i need something to show if its recording or no so
    // i no", and before that "i had a song on before this one playing now so
    // it didnt record it". Measured on his machine at 04:05 that morning:
    // `~/.config/nyxus/tape.json` said `armed: true`, `beat` 1788838833 =
    // 2026-09-07 23:40:33, and `nyxus-tape --status` reported
    // `"stale": true, "daemons": 0`. The machine had rebooted at 03:09 and
    // NOTHING RESTARTS THE DAEMON (`arm()`'s own header says so: "NO SYSTEMD
    // UNIT ... nothing survives a reboot"). So the song he played was not
    // rejected by the tape's rules -- THE TAPE WAS NOT RUNNING AT ALL.
    //
    // Under `armed` alone those two facts collapse into one word, "off", and
    // that is precisely the word that could not tell him which had happened.
    // `stale` already carried the distinction and no surface drew it. So the
    // phase is derived ONCE, here, and every surface reads it:
    //
    //     "keeping"   armed, and THIS song is going to a file
    //     "waiting"   armed, between tracks -- starts with the next song
    //     "stopped"   the tape was left armed and the daemon is gone.
    //                 A reboot, an OOM, a session teardown. NOT the same as
    //                 off, and saying "off" here is the lie he caught.
    //     "off"       he turned it off, or it has never been on
    //
    // ⚠ There is deliberately no fifth "on?" state. Every one of these is
    // computed from a file the daemon writes plus a clock, so the shell is
    // never guessing -- and if the file is absent that is "off", which is
    // the shipped state of a fresh machine and a fact, not an unknown.
    readonly property bool stopped: stale
    readonly property string phase: armed
                                    ? (waitingForNextTrack ? "waiting"
                                                           : "keeping")
                                    : (stopped ? "stopped" : "off")

    // The words. ⚠ ONE SPELLING, so the bar, the now-playing card and
    // Settings cannot drift into three descriptions of one fact -- which is
    // what `docs/CONTRACT_TAPE_CONTROL.md` §5 asks for in as many words
    // ("please use the same sentence rather than inventing a third").
    readonly property string phrase: phase === "keeping"
        ? qsTr("Keeping: %1").arg(taping)
        : phase === "waiting"
          ? qsTr("On — starts with the next song")
          : phase === "stopped"
            ? qsTr("Off — the tape stopped on its own")
            : qsTr("Off — songs are not being kept")

    // The same fact at badge length, for a surface that has room for a word
    // but not a sentence.
    readonly property string word: phase === "keeping" ? qsTr("KEEPING")
                                 : phase === "waiting" ? qsTr("ARMED")
                                 : phase === "stopped" ? qsTr("STOPPED")
                                                       : qsTr("NOT KEEPING")

    FileView {
        // ⚠ Written ONLY by nyxus-tape, atomically (tmp + rename), so this
        // watcher never sees a half-written document.
        path: Quickshell.env("HOME") + "/.config/nyxus/tape.json"
        watchChanges: true
        onFileChanged: reload()
        // Disarmed is the shipped state and a fresh HOME has no file at all.
        // That is the design, not an error, and it must not print.
        printErrors: false

        JsonAdapter {
            id: adapter
            property bool armed: false
            property string taping: ""
            property int kept: 0
            // unix seconds, re-stamped every 10 s by the running daemon
            property double beat: 0
            property string last: ""
            property string dir: ""
            property string source: ""
        }
    }
}
