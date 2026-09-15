pragma Singleton
pragma ComponentBehavior: Bound
// Nyxus Suxyn — the media/MPRIS helper. TRK-2600..TRK-2604.
//
// ── the defect this file exists for ──────────────────────────────────────
// Measured on the owner's running session, 2026-08-22:
//
//     $ playerctl -l
//     chromium.instance...
//     $ playerctl metadata
//     (nothing)
//
// Audio audible, and the shell showing no track, no artist, no art — the
// Crest hidden outright, the lock strip collapsed, the Meridian still a
// clock. Reproduced deliberately with `docs/proof/media-0822/
// method-mock-mpris.py --mode empty --status Playing`, which stands a player
// on the bus whose `Metadata` dict is `{}`:
//
//     playerctl -l        → chromium.instance4242      (the name IS there)
//     playerctl status    → Playing        rc=0        (the INTERFACE works)
//     playerctl metadata  → "No player could handle    (the METADATA is not)
//                            this command"  rc=1
//
// So the root cause is NOT a wrong bus name, NOT playerctl picking the wrong
// player, and NOT a missing subscription. The player publishes an EMPTY
// `Metadata` — Chromium registers `org.mpris.MediaPlayer2.chromium.instanceN`
// the moment a media session starts, but fills Metadata from the page's
// MediaSession API, so a page that never sets it (a bare <audio>, WebAudio, a
// cross-origin frame) leaves the dict empty for as long as it plays. No
// amount of shell code can invent a title the source never published.
//
// ── what IS ours, and is fixed here ──────────────────────────────────────
// The surface went DARK rather than degrading. `Sys.player` skips any player
// whose title is empty (`if (title.length === 0) continue`), so in that state
// `Sys.hasPlayer` is false and every media surface in the build vanishes
// while sound is coming out of the speakers. That is the worst of the two
// possible wrong answers: the owner cannot even PAUSE it.
//
// And the transport interface is fully alive in that state — the exact trap
// the brief warns about. Probed against the mock, an empty-Metadata player
// still answers `CanPlay`, `CanPause`, `CanGoNext`, `CanGoPrevious` and
// `PlayPause`. Title absent is not interface absent. So this helper keeps a
// playing-but-untitled source VISIBLE and CONTROLLABLE, and says plainly in
// the subtitle that the source is not publishing details.
//
// ── why a new file and not an edit to Sys.qml ────────────────────────────
// `Sys.playerHasTrack` carries a supervisor ruling (2026-08-12) and gates
// Bar.qml's Meridian dial, which is another lane's file right now. Changing
// its meaning underneath that would be a cross-lane edit made silently.
// Sys.qml is left exactly as it is; the widened selection lives here, and the
// Sys.qml narrowing is REPORTED rather than edited.
//
// ── the binding trap this file deliberately avoids ───────────────────────
// `Sys.player` `return`s from the middle of its loop. A QML binding captures
// only the properties it actually READ during evaluation, so returning at
// candidate 0 never captures candidates 1..n — and a second player that
// starts playing later cannot re-run the binding through its own change
// signal. The loop below reads every candidate's `trackTitle`, `isPlaying`
// and `canControl` BEFORE it decides anything, and returns exactly once.
//
// ── the rules live in MediaSelect.js, and the gate RUNS them ─────────────
// The tier table and the visibility rule are a pragma-library so that
// `verify-profile.sh` gate 14b1 can load the shipped file under `qml` and
// execute it over a table of synthetic players. A gate that greps for
// "playingBare" proves nothing; a gate that computes the choice for
// "one playing player with no title" and asserts the surface APPEARS is the
// regression test this defect deserves.
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import "MediaSelect.js" as MediaSelect
import "LyricPhrase.js" as LyricPhrase

QtObject {
    id: src

    readonly property var players:
        (Mpris.players && Mpris.players.values) ? Mpris.players.values : []

    readonly property var player: {
        const vals = src.players;
        const cands = [];
        for (let i = 0; i < vals.length; i++) {
            const p = vals[i];
            // ⚠ Every candidate's properties are READ here, before any
            // decision. A QML binding captures only what it actually read, so
            // a loop that `return`s from the middle never captures the
            // candidates after the winner — and a second player that starts
            // playing later then cannot re-run the binding through its own
            // change signal. `Sys.player` has that shape; this does not.
            cands.push(p ? {
                hasTitle: (p.trackTitle || "").length > 0,
                playing: p.isPlaying === true,
                control: p.canControl === true
            } : null);
        }
        const pick = MediaSelect.classify(cands);
        return pick.index >= 0 ? vals[pick.index] : null;
    }

    readonly property bool hasPlayer: player !== null && player !== undefined

    readonly property string title: hasPlayer ? (player.trackTitle || "") : ""
    readonly property string artist: hasPlayer ? (player.trackArtist || "") : ""
    readonly property string album: hasPlayer ? (player.trackAlbum || "") : ""
    readonly property string artUrl: hasPlayer ? (player.trackArtUrl || "") : ""

    // One call, so `present` and `titleUnpublished` can never drift apart
    // from `hasTrack`/`audible` — and so the gate tests all four at once.
    readonly property var vis: MediaSelect.visibility(
        hasPlayer && title.length > 0,
        hasPlayer && player.isPlaying === true)

    // "There is a track loaded" — the same question `Sys.playerHasTrack`
    // asks, kept under the same name so the two are comparable.
    readonly property bool hasTrack: vis.hasTrack

    // "Sound is coming out." A player can be audible with nothing to name.
    readonly property bool audible: vis.audible

    // ⚠ THE VISIBILITY GATE. Not `hasTrack` (that hides an audible source
    // with no metadata — the reported defect) and not `hasPlayer` (that
    // shows a strip for an idle registered browser, which WIP-640(b) had
    // already had to remove once). A surface appears when there is something
    // to NAME or something to SILENCE.
    readonly property bool present: vis.present

    // True in exactly the reported state: audible, and the source is not
    // telling us what it is. Surfaces say so instead of drawing a blank.
    readonly property bool titleUnpublished: vis.titleUnpublished

    readonly property bool playing: audible
    readonly property bool canGoNext: hasPlayer && player.canGoNext === true
    readonly property bool canGoPrevious: hasPlayer && player.canGoPrevious === true
    readonly property bool canTogglePlaying:
        hasPlayer && (player.canTogglePlaying === true || player.canControl === true)
    readonly property bool canSeek:
        hasPlayer && player.canSeek === true && lengthSec > 0

    // Who it is. `identity` first, then the desktop entry, then the bus name
    // with the MPRIS prefix and Chromium's `.instanceNNNN` suffix trimmed —
    // "chromium.instance4242" is a process id wearing a name badge, and the
    // owner should read "Chromium".
    readonly property string sourceLabel: hasPlayer
        ? MediaSelect.sourceLabel(player.identity, player.desktopEntry,
                                  player.dbusName)
        : ""

    readonly property real lengthSec: {
        if (!hasPlayer || player.lengthSupported !== true)
            return 0;
        const l = player.length;
        return (l && l > 0) ? l : 0;
    }
    readonly property bool positionSupported:
        hasPlayer && player.positionSupported === true

    function positionSec() {
        if (!hasPlayer || player.positionSupported !== true)
            return 0;
        const p = player.position;
        return (p && p > 0) ? p : 0;
    }

    // ── what a surface should actually draw ──────────────────────────────
    // One place, so the Crest and the lock strip can never word the same
    // state differently.
    readonly property string displayTitle: {
        if (hasTrack)
            return title;
        if (titleUnpublished)
            return sourceLabel.length ? sourceLabel : qsTr("Playing");
        return "";
    }
    readonly property string displaySubtitle: {
        if (hasTrack)
            return artist;
        if (titleUnpublished)
            return qsTr("Playing — this source publishes no track details");
        return "";
    }

    function previous() { if (canGoPrevious) player.previous(); }
    function next() { if (canGoNext) player.next(); }
    function togglePlaying() { if (canTogglePlaying) player.togglePlaying(); }
    function seekFraction(f) {
        if (!canSeek)
            return;
        const c = Math.max(0, Math.min(1, f));
        player.position = c * lengthSec;
    }

    // ══ REPEAT AND RESUME ═══════════════════════════════════ TRK-4120 ══
    //
    // ── the defect this block exists for ─────────────────────────────────
    // Settings ▸ System ▸ Media shipped two rows — "Repeat" (Off/All/One)
    // and "Resume where playback stopped" — and a grep for either key
    // across the whole shell, `/usr/local/bin` and `~/.config/hypr` found
    // exactly ONE file: `SetPageMedia.qml`, the page that WRITES them.
    // Nothing read them back. Both rows moved, both rows saved, and the
    // machine did the same thing either way. A settings row that persists
    // its own switch position and nothing else is worse than no row: it
    // reports a state the audio pipeline has never heard of.
    //
    // ── why repeat lives on the player and resume lives here ─────────────
    // Repeat IS an MPRIS property (`LoopStatus`), so the player owns it and
    // we must not keep a second copy that can disagree. `repeatMode` READS
    // the player whenever a player supports loop, so flipping repeat inside
    // the player's own window shows up on our card instead of leaving the
    // card stale; the stored key is the WANT, pushed onto each player that
    // wins the pick so the choice survives closing the player and the
    // session. When nothing supports loop we fall back to reporting the
    // want, because that is the only honest thing left to report.
    //
    // Resume has no MPRIS equivalent at all — the spec has no notion of a
    // previous session. So the position is ours to keep, and the rule is
    // deliberately narrow: seek back exactly once, and only when a player
    // appears holding the SAME track, still sitting at the start, able to
    // seek. A different track, an already-scrubbed position, or a player
    // that cannot seek is left alone. Dropping someone into the middle of a
    // track they did not leave there is a worse failure than not resuming.

    readonly property bool loopSupported: hasPlayer && player.loopSupported === true
    readonly property bool shuffleSupported: hasPlayer && player.shuffleSupported === true

    // The want, as the Settings page stores it. Reactive: `stringValue`
    // reads `SettingsStore.doc`, which is reassigned (not mutated) on write.
    readonly property string repeatWanted: SettingsStore.stringValue("app_media_repeat", "Off")
    readonly property bool resumeWanted: SettingsStore.boolValue("app_media_resume", true)

    readonly property string repeatMode: {
        if (!src.loopSupported)
            return src.repeatWanted;
        switch (src.player.loopState) {
        case MprisLoopState.Track:    return "One";
        case MprisLoopState.Playlist: return "All";
        default:                      return "Off";
        }
    }

    function setRepeat(mode) {
        const m = (mode === "One" || mode === "All") ? mode : "Off";
        SettingsStore.setValue("app_media_repeat", m);
        src._pushRepeat();
    }

    function cycleRepeat() {
        src.setRepeat(src.repeatMode === "Off" ? "All"
                    : src.repeatMode === "All" ? "One" : "Off");
    }

    function _pushRepeat() {
        // ⚠ Reads `src.player` DIRECTLY, not the `loopSupported` property.
        // This runs from `onPlayerChanged`, and a QML property binding that
        // depends on `player` has NOT necessarily re-evaluated by the time
        // that handler runs — `src.loopSupported` still held the OUTGOING
        // player's answer, so the first push after a hand-off was skipped
        // against a player that did support loop. Measured: pausing a
        // titled Chromium handed the pick to a playing VLC and the want
        // never landed. A handler that fires on a change must read the
        // source of that change, never a derived property of it.
        const p = src.player;
        if (!p || p.loopSupported !== true)
            return;
        const want = src.repeatWanted;
        const target = want === "One" ? MprisLoopState.Track
                     : want === "All" ? MprisLoopState.Playlist
                                      : MprisLoopState.None;
        if (p.loopState !== target)
            p.loopState = target;
    }

    // Identity of a track across sessions. MPRIS track ids are per-player
    // object paths and do not survive the player closing, so the human
    // fields are what can be compared tomorrow.
    readonly property string trackSig: src.hasPlayer
        ? ((src.title || "") + "\u241f" + (src.album || "") + "\u241f" + (src.artist || ""))
        : ""

    // Set once a signature has been offered its resume, so a paused track
    // the owner deliberately rewound is never yanked forward a second time.
    property string _resumedSig: ""

    function _saveResume() {
        if (!src.resumeWanted || !src.hasPlayer || !src.positionSupported)
            return;
        if (src.trackSig.length === 0 || src.lengthSec <= 0)
            return;
        const p = src.positionSec();
        // Near the end is a finished track, not a bookmark.
        if (p < 5 || p > src.lengthSec - 10)
            return;
        SettingsStore.setValues({
            "media_resume_sig": src.trackSig,
            "media_resume_pos": Math.round(p)
        });
    }

    function _tryResume() {
        if (!src.resumeWanted || !src.hasPlayer || !src.canSeek)
            return;
        const sig = src.trackSig;
        if (sig.length === 0 || sig === src._resumedSig)
            return;
        if (SettingsStore.stringValue("media_resume_sig", "") !== sig)
            return;
        const at = SettingsStore.numberValue("media_resume_pos", 0);
        if (at < 5 || at > src.lengthSec - 10)
            return;
        // Only from the start. Anything else is a position the owner chose.
        if (src.positionSec() > 3)
            return;
        src._resumedSig = sig;
        src.player.position = at;
    }

    onPlayerChanged: {
        src._pushRepeat();
        src._resumedSig = "";
        resumeSettle.restart();
    }
    onTrackSigChanged: resumeSettle.restart()
    onRepeatWantedChanged: src._pushRepeat()
    // A player registers on the bus before it has answered for every
    // property, so `loopSupported` can flip true a beat after the player
    // object appears. This is the late-arrival push the hand-off missed.
    onLoopSupportedChanged: if (src.loopSupported) src._pushRepeat()

    // A player publishes its track and its length in separate D-Bus
    // property changes, so the first frame after a track appears often has
    // a signature and no length yet. Seeking then is a seek to nowhere.
    property Timer resumeSettle: Timer {
        interval: 900; repeat: false
        onTriggered: src._tryResume()
    }

    property Timer resumeSave: Timer {
        running: src.resumeWanted && src.playing && src.positionSupported
        interval: 5000; repeat: true
        onTriggered: src._saveResume()
    }

    // ══ SYNCED LYRICS, A FEW WORDS AT A TIME ════════════════ TRK-3812 ══
    //
    // The bar shows a SHORT PHRASE: it pops up, fades, the next takes its
    // place. Everything below feeds exactly five properties, and a renderer
    // needs nothing else:
    //
    //     MediaSource.lyricText        string  — the phrase, "" when none
    //     MediaSource.lyricLoaded      bool    — a timeline exists at all
    //     MediaSource.lyricSeq         int     — +1 on EVERY phrase change
    //     MediaSource.lyricExact       bool    — every word of it was A2
    //     MediaSource.lyricAnchored    bool    — its START is a real stamp
    //
    // A PANEL needs three more, and only a panel uses them (TRK-3980):
    //
    //     MediaSource.lyricLines       array   — [[start, end, text], …]
    //     MediaSource.lyricLineIdx     int     — the line being sung, or -1
    //     MediaSource.lyricNote        string  — WHY there are none, in words
    //
    // ⚠ `lyricSeq` exists because comparing the string cannot see a repeat:
    // "no no no" is three words and one string. Drive the fade off the seq
    // change, never off `onLyricTextChanged`.
    //
    // ══ THE PHRASE, AND WHY IT IS NOT ONE WORD ANY MORE ══════ TRK-3817 ══
    // Owner, 2026-09-07, watching the one-word build on his own bar:
    //
    //   "i think what it needs is more words at once in a sence instead of
    //    one or two then it looks like it goes by to fast"
    //   "i think the words needs to stay a little longer so the eye ca[n]
    //    catch it and read it ... not even a second probaly"
    //
    // ⚠ THE CADENCE HE APPROVED IS UNCHANGED. He had already ruled that the
    // lyrics pop and fade exactly like the music notes, and that is not what
    // he is complaining about — he is complaining about DENSITY and DWELL.
    // So this is not a static line pinned in one place; it is the same
    // pop-and-fade with a bigger unit inside it.
    //
    // ⚠ THE DWELL IS BOUGHT BY THE UNIT'S SIZE, NOT BY A LONGER TIMER, and
    // that distinction is the whole design. A word's life on screen is
    // bounded by the NEXT word arriving — the renderer's one slot restarts.
    // So "hold it longer" cannot be a duration: raising one would either
    // overlap two phrases or push the display behind the music. Grouping
    // four words into one unit multiplies the dwell by four AT ZERO LAG,
    // because the unit got bigger rather than the timing looser.
    //
    // Measured on his own test track (Kendrick Lamar, "Not Like Us", 905
    // words, 274 s), dwell = time from a unit appearing to the next unit
    // replacing it:
    //
    //     one word          median  240 ms   p10  157 ms
    //     4-word phrase     median  857 ms   p10  574 ms
    //
    // 857 ms is inside the bound he set himself ("not even a second"), and
    // p10 574 ms is what the FASTEST passages get — the ones he was
    // pointing at. `_phraseMaxWords` is that 4; see it for the rest.
    //
    // ══ AND IT BUYS TIMING ACCURACY, WHICH IS NOT A SIDE EFFECT ═════════
    // ⚠ `lyricExact` is false for almost every word — on that track it is
    // false for ALL 905, because LRCLIB's record carries no A2 markers at
    // all. LRC stamps LINES; the fetcher spreads the words across the
    // line's interval weighted by syllables, and that is an ESTIMATE that
    // drifts on a fast line.
    //
    // `anchor` (schema 2, the word tuple's fifth field) is the different
    // and more useful question: is this word's START a literal timestamp
    // off the file? A phrase is built to BEGIN on an anchored word wherever
    // the line allows it, so the moment that matters — when the phrase
    // appears — lands on a real stamp far more often:
    //
    //     one word          12% of units start on a literal stamp
    //     4-word phrase     38% of units start on a literal stamp
    //
    // That is 3.2x, on the same data, from grouping alone. `lyricAnchored`
    // reports it per unit so a renderer could treat the two differently;
    // nothing does yet, and it is not invented for a future — it is the
    // measurement's own subject, exposed rather than hidden.
    //
    // ── why this lives in MediaSource and not in a new singleton ────────
    // A new QML type needs a new file, a new qmldir line AND a full shell
    // restart, because Qt caches the type registry. The owner is using the
    // machine. Extending a singleton that already holds the player, the
    // position and the track identity costs a reload, not a restart — and
    // this data has no other honest home: it is a property of the track.
    //
    // ── OFF BY DEFAULT, AND OFF MEANS NOTHING RUNS ─────────────────────
    // `Prefs.lyricsOnline` ships false. With it false there is no Process,
    // no FileView path, no timer running, and nothing leaves the machine.
    // The fetcher checks the same key again for itself — a shell bug must
    // not be able to put a request on the wire.
    //
    // ── the two clocks, and the 1000 ms floor ──────────────────────────
    // HANDOFF's floor exists because two hyprlock labels SPAWNING
    // SUBPROCESSES every 50 ms starved the event loop and locked the owner
    // out of his machine. The subject of that rule is the fork, and it is
    // honoured exactly: the only thing that reads the PLAYER — a D-Bus
    // property fetch — runs at 1000 ms, the same rate MediaCrest and the
    // Widgets deck already poll at.
    //
    // Word rate is far higher than line rate (a dense rap line is 5-7 words
    // a second, ~150 ms a word), so a 1 Hz tick would land whole words late.
    // The word cursor therefore runs at 100 ms off a LOCAL clock —
    // `_posBase + (Date.now() - _posBaseMs)/1000` — which is pure JS
    // arithmetic and one array comparison. No fork, no D-Bus, no file read,
    // no allocation. It advances an index; it never searches. And it only
    // runs when a timeline is actually loaded AND audio is playing, which
    // in the common case (LRCLIB has nothing for the track) is never.
    readonly property bool lyricsWanted:
        Prefs.lyricsOnline === true && hasTrack && title.length > 0

    // The track identity the fetcher is keyed on. Album is deliberately not
    // part of it: it is not sent, so it must not change the cache key.
    readonly property string lyricSig: lyricsWanted
        ? (artist + " / " + title + " / " + Math.round(lengthSec))
        : ""

    // [[start, end, text, exact, anchored], …] — the UNITS, already grouped.
    // The cursor below never regroups: the parse and the grouping are both
    // paid once, at load, and after that this is numbers and an index.
    property var _lyricUnits: []
    property int _lyricIdx: -1
    property real _posBase: 0
    property real _posBaseMs: 0

    // ⚠ THE TWO NUMBERS THAT DECIDE THE PHRASE. Both were chosen from the
    // measurement in the header, not from taste:
    //
    //   _phraseMaxWords 4 — dwell median 240 ms (1 word) → 857 ms, inside
    //     the "not even a second" the owner set. 5 words reads 1076 ms,
    //     which is PAST his bound, and 3 reads 682 ms, which leaves the
    //     fastest passages at p10 443 ms — the strobe he complained about.
    //
    //   _phraseMaxChars 24 — a WIDTH bound, and it exists because the bar
    //     is 1920 px with functional chrome at both ends and in the middle
    //     (BarSpectrum § THE KEEP-OUT). Uncapped, 4 words reaches 27
    //     characters; capped at 24 the longest phrase on the test track is
    //     23 and dwell only falls 869 → 857 ms. Twelve milliseconds is what
    //     the width guarantee costs.
    readonly property int _phraseMaxWords: 4
    readonly property int _phraseMaxChars: 24

    readonly property bool lyricLoaded: _lyricUnits.length > 0
    property string lyricText: ""
    property int lyricSeq: 0
    property bool lyricExact: false
    property bool lyricAnchored: false

    // ══ THE PANEL'S HALF, AND IT IS ADDITIVE ═══════════════ TRK-3980 ══
    //
    // ⚠ NOTHING BELOW TOUCHES THE FETCH. Everything in this section is
    // computed FROM the document the block above already loaded, and the
    // argv, the timers and the phrase cursor are byte-for-byte what they
    // were. That constraint is not tidiness: on 2026-09-08 this file grew a
    // settle timer, an in-flight signature and a `--file` argument, and the
    // owner lost lyrics entirely for a night. The measured cause was the
    // `--file`: `nyxus-lyrics` never implemented it, argparse exited 2 with
    // "unrecognized arguments", nothing reached stdout, and every track read
    // as "no lyrics". Reverting this file to its 487-line form fixed it in
    // one restart — which is the proof that the FETCH was never the problem.
    // So a display feature is written as a display feature.
    //
    //   lyricLines    [[start, end, text], …] — the WHOLE song, in lines.
    //   lyricLineIdx  which one is being sung. Unlike `lyricText` it HOLDS
    //                 between lines: a panel needs somewhere for the eye to
    //                 rest, a bar does not. LyricPhrase.lineAt carries why.
    property var lyricLines: []
    property int lyricLineIdx: -1

    // ── SILENCE IS NOT AN ANSWER ────────────────────────────────────────
    // Owner, 2026-09-08, four times: "no lyrics still". A track with no
    // lyrics and a feature that has fallen over render IDENTICALLY — as
    // nothing at all — and the reasonable reading of nothing is "broken".
    // He spent a night on that ambiguity.
    //
    // `lyricWhy` is the fetcher's own word, carried verbatim so this file
    // never invents a reason; `lyricNote` is that word as one sentence a
    // person reads. "" means there is nothing to say — the words are on
    // screen, or the feature is off, or there is no track.
    //
    // ⚠ NOTHING READS THESE TO DECIDE ANYTHING. They are strings for a
    // surface to draw. A guard that branched on `lyricWhy` would be a second
    // control path through a feature that has already been broken twice by
    // control paths.
    property string lyricWhy: ""

    readonly property bool lyricMiss: src.lyricWhy.length > 0 && !src.lyricLoaded

    readonly property string lyricNote: {
        if (!src.lyricMiss)
            return "";
        switch (src.lyricWhy) {
        case "looking":
            return qsTr("Looking for lyrics…");
        case "instrumental":
            return qsTr("Instrumental — there are no words");
        case "no synced lines":
            // ⚠ THE HONEST ONE. lrclib holds a plain sheet for this track and
            // no timings, and this build shows timed lyrics. Saying "no
            // lyrics" here would be a lie the owner could disprove in a
            // browser in ten seconds.
            return qsTr("Only unsynced lyrics exist for this track");
        case "no match":
            return qsTr("No lyrics found for this track");
        case "helper":
            // The helper printed no path at all: not installed, not on PATH,
            // or refused by its own consent gate. It is the one state that is
            // about the BUILD rather than about the song, and it is the state
            // the 2026-09-08 `--file` crash sat in for a whole night while
            // rendering as an empty panel.
            return qsTr("The lyrics helper did not answer — nyxus-lyrics may not be installed");
        case "unreadable":
            // A document the fetcher WROTE and this file refused. That is a
            // defect, not a state of the music, and it says so rather than
            // hiding inside "no lyrics" the way the schema-1 pin did.
            return qsTr("The lyrics helper answered in a format this build cannot read");
        case "off":
            return qsTr("Synced lyrics are switched off — Settings ▸ Appearance");
        case "silent":
            return qsTr("Nothing is playing");
        default:
            return qsTr("No lyrics found for this track");
        }
    }

    function _lyricClear() {
        src._lyricUnits = [];
        src.lyricLines = [];
        src.lyricLineIdx = -1;
        src._lyricIdx = -1;
        src._lyricSeqIdx = -2;
        if (src.lyricText.length > 0) {
            src.lyricText = "";
            src.lyricExact = false;
            src.lyricAnchored = false;
            src.lyricSeq = src.lyricSeq + 1;
        }
    }

    // ── the grouping ────────────────────────────────────────────────────
    // ⚠ THE RULES ARE IN `LyricPhrase.js`, NOT HERE, AND THAT IS SO A GATE
    // CAN RUN THEM. `MediaSelect.js` beside it set the precedent in this
    // same file: verify-profile 14b1 loads the shipped library under `qs`
    // and executes its state table. A gate that greps for `_phraseMaxWords`
    // proves nothing; gate 14g1 runs the grouping over fixtures and asserts
    // that a phrase never crosses a line.
    function _lyricGroup(words) {
        return LyricPhrase.group(words, src._phraseMaxWords,
                                 src._phraseMaxChars);
    }

    onLyricSigChanged: {
        src._lyricClear();
        lyricDoc.path = "";
        if (src.lyricSig.length > 0) {
            src.lyricWhy = "looking";            // TRK-3980, a string only
            lyricFetch.running = true;
        } else {
            // An empty signature has exactly two causes and they are
            // different sentences to a person: he never switched the feature
            // on, or nothing is playing. Guessing between them is what made
            // "nothing at all" the only thing this feature ever said.
            src.lyricWhy = Prefs.lyricsOnline === true ? "silent" : "off";
        }
    }

    // ⚠ DETACHED FROM THE PLAYER IN EVERY SENSE. This process is handed
    // three strings on argv and reports a path on stdout. It holds no bus
    // name, it cannot seek, it cannot pause, and the shell never waits on
    // it: `running = true` and the answer arrives whenever it arrives. The
    // worst thing a hung lookup can do is nothing.
    property Process _lyricFetch: Process {
        id: lyricFetch
        running: false
        // TRK-3435 — shipped-first PATH through `env`, so argv never
        // crosses a shell. HardwareCaps.qml carries the ruling.
        command: ["env",
                  "PATH=" + (Quickshell.env("NYXUS_BIN_DIR") || "/usr/local/bin")
                          + ":" + Quickshell.env("PATH"),
                  "nyxus-lyrics",
                  "--artist", src.artist,
                  "--title", src.title,
                  "--duration", String(Math.round(src.lengthSec))]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = String(this.text).trim();
                // No path means the key is off, the track had no title, or
                // the helper is not installed. All three are "no lyrics",
                // which is a state, not an error. Nothing is said.
                lyricDoc.path = (p.length > 0 && p.charAt(0) === "/") ? p : "";
                // …except that "nothing is said" is what cost the owner a
                // night. A helper that printed no path answered the
                // question; it just answered it with nothing, and a panel
                // that draws an empty box for that is the bug (TRK-3980).
                if (lyricDoc.path === "")
                    src.lyricWhy = "helper";
            }
        }
    }

    // One read per track. The document is a flat array so the parse cost is
    // paid once here and never again — the cursor below only ever compares
    // numbers.
    property FileView _lyricDoc: FileView {
        id: lyricDoc
        path: ""
        printErrors: false
        onLoaded: {
            let doc = null;
            try {
                doc = JSON.parse(lyricDoc.text());
            } catch (e) {
                doc = null;                      // malformed: no lyrics
            }
            // ⚠ THE SCHEMA NUMBER IS THE READER'S CONTRACT, AND IT COST A
            // ROUND. `nyxus-lyrics` moved to schema 2 to carry the `anchor`
            // field the phrase builder groups on, and this line still said
            // `!== 1` — so every document the new fetcher wrote was refused
            // here, silently, as "this track has no lyrics". Nothing logged,
            // nothing failed, the bar simply showed no words. A reader that
            // pins an exact version has to be edited in the same breath as
            // the writer; 2 is the version whose fifth field this file
            // requires, and a document without it cannot be grouped.
            if (!doc || doc.v !== 2) {
                src._lyricClear();
                src.lyricWhy = "unreadable";     // TRK-3980, a string only
                return;
            }
            if (doc.miss === true || !doc.words || doc.words.length === 0) {
                src._lyricClear();
                // ⚠ THE FETCHER'S OWN WORD, NOT ONE INVENTED HERE. The
                // difference between "no match" and "no synced lines" is the
                // difference between "the catalogue has never heard of this
                // track" and "it has the words but not the timings", and only
                // the thing that asked lrclib knows which. `instrumental` is
                // carried as its own flag as well as in `why`, and the flag
                // is the one that cannot be reworded.
                src.lyricWhy = doc.instrumental === true
                               ? "instrumental"
                               : String(doc.why || "no match");
                return;
            }
            src.lyricWhy = "";
            src._lyricUnits = src._lyricGroup(doc.words);
            src.lyricLines = LyricPhrase.lines(doc.words);
            src._lyricIdx = -1;
            src._posBase = src.positionSec();
            src._posBaseMs = Date.now();
            // Resolved HERE as well as on the tick, because the tick does not
            // run while paused: a panel opened on a paused song at 2:14 must
            // land on the line at 2:14, not at the top of the sheet.
            src.lyricLineIdx = LyricPhrase.lineAt(src.lyricLines,
                                                  src._posBase, 4.0);
        }
        onLoadFailed: {
            src._lyricClear();
            src.lyricWhy = "unreadable";
        }
    }

    // The 1 Hz half: the only thing here that touches the player.
    property Timer _lyricPos: Timer {
        interval: 1000
        repeat: true
        running: src.lyricLoaded && src.playing
        triggeredOnStart: true
        onTriggered: {
            src._posBase = src.positionSec();
            src._posBaseMs = Date.now();
        }
    }

    // The 10 Hz half: local arithmetic and an index that walks forward.
    property Timer _lyricTick: Timer {
        interval: 100
        repeat: true
        running: src.lyricLoaded && src.playing
        onTriggered: {
            const w = src._lyricUnits;
            const pos = src._posBase + (Date.now() - src._posBaseMs) / 1000;
            let i = src._lyricIdx;

            // A seek backwards is the only case that cannot be walked
            // forward, and it is rare enough to pay a bisection for.
            if (i >= 0 && (i >= w.length || pos < w[i][0])) {
                let lo = 0, hi = w.length - 1;
                i = -1;
                while (lo <= hi) {
                    const mid = (lo + hi) >> 1;
                    if (w[mid][0] <= pos) { i = mid; lo = mid + 1; }
                    else hi = mid - 1;
                }
            }
            while (i + 1 < w.length && w[i + 1][0] <= pos)
                i++;
            src._lyricIdx = i;

            // Past its end, a phrase is gone — the gap between lines is
            // silence and must read as silence, not as a held banner.
            const on = i >= 0 && pos < w[i][1];
            const text = on ? String(w[i][2]) : "";
            const exact = on ? (w[i][3] === 1) : false;
            const anch = on ? (w[i][4] === 1) : false;
            if (text !== src.lyricText || i !== src._lyricSeqIdx) {
                src.lyricText = text;
                src.lyricExact = exact;
                src.lyricAnchored = anch;
                src._lyricSeqIdx = i;
                // ⚠ The seq moves on the INDEX changing, not on the string:
                // "no no no" must fire three times.
                src.lyricSeq = src.lyricSeq + 1;
            }

            // ── the PANEL's cursor, on the same tick ─────── TRK-3980 ──
            // Same clock, same `pos`, no second timer: a panel whose
            // highlight ran off its own tick would drift against the bar's
            // phrase by up to two frames and the two are on screen together.
            // `lineAt` is a walk over ~40 lines every 100 ms and it is only
            // reached when a timeline is loaded AND audio is playing.
            const li = LyricPhrase.lineAt(src.lyricLines, pos, 4.0);
            if (li !== src.lyricLineIdx)
                src.lyricLineIdx = li;
        }
    }

    // The index the last emitted phrase came from. Separate from _lyricIdx
    // so that a phrase ENDING (text -> "") and the next one STARTING are two
    // distinct events even though the index did not move in between.
    property int _lyricSeqIdx: -2
}
