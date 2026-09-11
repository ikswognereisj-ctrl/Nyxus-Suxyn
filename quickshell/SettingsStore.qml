pragma Singleton
// Nyxus Suxyn — the settings STORE. The one place the shell writes a setting.
//
// ── why this file exists, and why it is not Prefs.qml ────────────────────
// `Prefs.qml` is READ-ONLY on purpose, and its header says why: it declares a
// JsonAdapter holding only the handful of keys the shell reads, and a
// `writeAdapter()` on that adapter serialises *the declared properties only* —
// so saving one toggle would silently delete the other forty-odd sections'
// settings. That rule (WIP-108, "one writer") was correct for as long as the
// GTK control center was the only thing that ever wrote the file.
//
// The Master Settings surface is a writer. So it needs a writer that cannot
// lose a key it has never heard of, and that is the whole design here:
//
//   READ    the file as TEXT, parse the WHOLE document into `doc`
//   MODIFY  one key in that whole document
//   WRITE   the whole document back
//
// Nothing is ever reconstructed from a schema, so a key written by the GTK app,
// by a future module, or by a hand-edit survives every save this file makes.
// That is the difference between a merge and an overwrite, and it is the only
// reason two writers on one file is safe.
//
// ── the loop that this file must not enter ───────────────────────────────
// `watchChanges` fires on OUR OWN write as well as on someone else's. Reloading
// there is not merely wasteful: a save is debounced, so between `setValue()`
// and the flush there is a window in which `doc` holds edits the file does not.
// A reload landing in that window would throw them away and the switch would
// visibly snap back under the user's finger. `_dirty` closes the window —
// while we owe the file a write, we do not accept one from it.
//
// ── the directory ────────────────────────────────────────────────────────
// A fresh HOME has no `~/.config/nyxus` at all. `setText()` on a path whose
// parent does not exist fails, and it fails quietly enough to look like "the
// toggle did nothing". One `mkdir -p`, once, on the first save of a session.
//
// ── the schema (TRK-1260) ────────────────────────────────────────────────
// The file carries `schema_version`. `SettingsSchema.js` owns the number and
// the ordered migration table; this file only RUNS it, on every successful
// load: a document behind the current schema is backed up to
// `settings.json.bak-<from>` FIRST (synchronously — a migration that cannot
// back up does not run), then migrated and written back. A missing key reads
// as schema 1. The table is idempotent, so the reload our own write triggers
// finds nothing to do and writes nothing — the loop the header above warns
// about stays closed. `migrationDryRun()` lists what a migration would do and
// changes nothing; the Reset page (SetPageReset.qml) has the button for it.
//
// ── reset (TRK-1261) ────────────────────────────────────────────────────
// `clearValues(keys)` is a page's Reset row: the keys go, in one write, so
// each falls back to the shipped default. `resetAll()` backs the whole file
// up to `settings.json.bak-reset-<stamp>` and writes a fresh document that
// holds nothing but `schema_version`. Both remove rather than write defaults
// — see `clearValue()` for why that is the only reset that stays correct
// when a shipped default moves.
import Quickshell
import Quickshell.Io
import QtQuick
import "SettingsSchema.js" as Schema

Singleton {
    id: store

    // The same file `Prefs.qml` watches and the GTK control center owns.
    // One file: the shell, the control center and this surface all describe
    // the same machine, so they must not each keep their own truth.
    readonly property string dir:  Quickshell.env("HOME") + "/.config/nyxus"
    readonly property string path: dir + "/settings.json"

    // The whole parsed document. Read it through `value()`; do not mutate it
    // in place from outside — QML will not see a property change on an
    // in-place edit of a JS object, so the UI would not follow.
    property var doc: ({})

    // True once the file has been read (or confirmed absent). Until then a
    // page should show the defaults it would show for a fresh install, not
    // a spinner — this file is a few kB on local disk.
    property bool loaded: false

    // We owe the file a write. Also the flag that keeps the watcher from
    // reloading over unflushed edits — see the header.
    property bool dirty: false

    // Human-facing save state, for the footer strip in Settings.qml. Empty
    // string means "nothing to say", which is the resting state.
    property string status: ""

    // Non-empty if the last load found something that is not JSON. The file is
    // NOT overwritten in that case: silently replacing a corrupt settings file
    // destroys the only copy of everything the user configured, and the same
    // decision is already made and written down in the reminders singleton.
    //
    // (That sentence deliberately does not spell the reminder store's filename.
    // The `13pr3` gate in `verify-profile.sh` scans every shell file for
    // `Reminders.<member>` to catch a surface calling a member the store does
    // not define — but it scans the raw text, comments included, so the file's
    // own NAME in a sentence reads to it as a call to a member called "qml"
    // and fails the gate. That is `AGENTS.md`'s "a gate you can satisfy with a
    // comment is not a gate" from the other direction: a gate a comment can
    // BREAK. Logged as a checklist row rather than patched here, because the
    // gate belongs to whoever owns WIP-103/108.)
    property string parseError: ""

    // ── schema state, for the Reset page and the log ────────────────────
    // The schema this shell writes. `schemaVersion` is what the loaded file
    // claims (1 until a file with the key is read); they differ only in the
    // moment between a load and the migration write that follows it, or when
    // a NEWER file than this shell knows is found — that one is left alone.
    readonly property int schemaCurrent: Schema.CURRENT
    property int schemaVersion: 1
    // Path of the last backup this session wrote ("" if none). A migration
    // or a full reset that could not back up did not happen, and says so in
    // `status`.
    property string lastBackup: ""

    // Emitted after every successful commit, with the keys that changed. The
    // shell mostly does not need this — `Prefs.qml` is watching the file and
    // will re-read it anyway — but a page that has to run a command as well as
    // save a value (a cursor theme, say) hangs that off this.
    signal committed(var keys)

    // ── reading ─────────────────────────────────────────────────────────
    // `fallback` is returned for a key that is absent, for a key whose value
    // is null, and for every key at all before the first load completes. That
    // last one matters: a page binding `checked: SettingsStore.value(k, true)`
    // must not flicker off and back on during startup.
    function value(key, fallback) {
        if (!store.doc)
            return fallback;
        var v = store.doc[key];
        return (v === undefined || v === null) ? fallback : v;
    }

    function boolValue(key, fallback) {
        var v = store.value(key, fallback);
        return v === true || v === "true" || v === 1;
    }

    function numberValue(key, fallback) {
        var v = Number(store.value(key, fallback));
        return isNaN(v) ? fallback : v;
    }

    function stringValue(key, fallback) {
        var v = store.value(key, fallback);
        return v === undefined || v === null ? fallback : String(v);
    }

    // ── writing ─────────────────────────────────────────────────────────
    // Reassigns `doc` rather than mutating it, because QML's change signal is
    // on the PROPERTY, not on the object graph underneath it: an in-place
    // `doc[key] = v` updates the data and leaves every binding in the window
    // showing the old value. Copying a settings document is a few dozen keys
    // and happens on a click, so the cost is not worth a subtler mechanism.
    function setValue(key, v) {
        var next = {};
        for (var k in store.doc)
            next[k] = store.doc[k];
        if (next[key] === v)
            return;                     // no write, no debounce, no churn
        next[key] = v;
        store.doc = next;
        store._remember(key, v);
        store.dirty = true;
        store.status = "Saving…";
        saveTimer.restart();
    }

    // Several keys, one write. A page that changes a pair of related values
    // (a font family and its size) should not produce two file writes and two
    // reload storms in the rest of the shell.
    function setValues(obj) {
        var next = {};
        for (var k in store.doc)
            next[k] = store.doc[k];
        var touched = false;
        for (var j in obj) {
            if (next[j] === obj[j])
                continue;
            next[j] = obj[j];
            store._remember(j, obj[j]);
            touched = true;
        }
        if (!touched)
            return;
        store.doc = next;
        store.dirty = true;
        store.status = "Saving…";
        saveTimer.restart();
    }

    // Remove a key entirely, so it falls back to the shipped default. This is
    // what a "Reset" button does, and it is NOT the same as writing the default
    // value: a written default is a decision the user made and a future change
    // to the shipped default would not reach them.
    function clearValue(key) {
        if (!store.doc || store.doc[key] === undefined)
            return;
        var next = {};
        for (var k in store.doc)
            if (k !== key)
                next[k] = store.doc[k];
        store.doc = next;
        store._remember(key, store._deletedMark);
        store.dirty = true;
        store.status = "Saving…";
        saveTimer.restart();
    }

    // Several keys, one removal, one write — a page's Reset row (TRK-1261).
    // Keys that are not in the document are skipped, so resetting a page that
    // is already at its defaults costs no write.
    function clearValues(keys) {
        if (!store.doc)
            return;
        var next = {};
        for (var k in store.doc)
            next[k] = store.doc[k];
        var touched = false;
        for (var i = 0; i < keys.length; ++i) {
            if (next[keys[i]] === undefined)
                continue;
            delete next[keys[i]];
            store._remember(keys[i], store._deletedMark);
            touched = true;
        }
        if (!touched)
            return;
        store.doc = next;
        store.dirty = true;
        store.status = "Saving…";
        saveTimer.restart();
    }

    // Everything back to the shipped defaults (TRK-1261). Backup FIRST, from
    // the text on disk, to `settings.json.bak-reset-<stamp>`; if that write
    // fails nothing else happens and `status` says so. Then the document
    // becomes `{ schema_version: CURRENT }` and is written at once — not
    // debounced, because the next thing the user does is look at the page.
    // The GTK control center shares this file, so its sections go too; the
    // Reset page says that in words before the button is armed.
    function resetAll() {
        var onDisk = "";
        try { onDisk = String(file.text()); } catch (e) { onDisk = ""; }
        if (onDisk !== "") {
            var stamp = Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss");
            if (!store._backup(onDisk, "bak-reset-" + stamp)) {
                store.status = "Not reset — the backup could not be written";
                return;
            }
        }
        for (var k in store.doc)
            if (k !== Schema.VERSION_KEY)
                store._remember(k, store._deletedMark);
        var fresh = {};
        fresh[Schema.VERSION_KEY] = Schema.CURRENT;
        store._remember(Schema.VERSION_KEY, Schema.CURRENT);
        store.doc = fresh;
        store.schemaVersion = Schema.CURRENT;
        store.dirty = true;
        store.status = "Saving…";
        saveTimer.stop();
        store._write();
    }

    // What a migration of the CURRENT document would do, as text, and nothing
    // else. Also logged, so `qs log` carries it.
    function migrationDryRun() {
        var lines = [];
        Schema.dryRun(store.doc, function (s) { lines.push(s); });
        for (var i = 0; i < lines.length; ++i)
            console.info("SettingsStore: " + lines[i]);
        return lines.join("\n");
    }

    // Write `text` to `<path>.<suffix>`, blocking, and report whether it
    // landed. The backup FileView has `blockWrites` on, so `setText` returns
    // after the file is on disk and `saved` / `saveFailed` have fired; nothing
    // that depends on the backup runs before the answer is known.
    function _backup(text, suffix) {
        store._backupState = "";
        backupFile.path = store.path + "." + suffix;
        backupFile.setText(text);
        backupFile.waitForJob();
        if (store._backupState !== "ok") {
            console.warn("SettingsStore: backup to " + backupFile.path
                         + " did not land (" + (store._backupState || "no answer")
                         + ") — refusing to touch " + store.path);
            return false;
        }
        store.lastBackup = backupFile.path;
        console.info("SettingsStore: backed up " + store.path + " to " + backupFile.path);
        return true;
    }
    property string _backupState: ""

    FileView {
        id: backupFile
        // Path is set per backup; the preload of a not-yet-existing backup
        // is not an error and must not print.
        printErrors: false
        blockWrites: true
        onSaved: store._backupState = "ok"
        onSaveFailed: (error) => { store._backupState = "failed: " + error; }
    }

    // Write now rather than at the end of the debounce. The window's close
    // handler calls this so that closing Settings a tenth of a second after a
    // click cannot lose that click.
    function flush() {
        if (store.dirty)
            store._write();
    }

    // ── the pending set, and the race it exists to close ────────────────
    // Not just WHICH keys changed since the last write, but what they were
    // changed TO. That extra half is not bookkeeping — it is the fix for a
    // real race, found by testing the write path rather than by reading it:
    //
    //   The file loads ASYNCHRONOUSLY. `onLoaded` assigns `doc` from the file.
    //   A change made in the window between the store being constructed and
    //   the load completing — a click in the first second, or on a slow disk,
    //   or when the shell is reloaded with Settings already open — was
    //   therefore OVERWRITTEN by the file, silently, and the control snapped
    //   back with no error anywhere.
    //
    //   `dirty` already stopped the WATCHER from doing that (see the header),
    //   but the first load is not the watcher and went straight past it.
    //
    // So the load now merges: the file is the base, and anything not yet
    // written is re-applied on top of it. Proven by making it happen —
    // `_write_probe` set before the load completed survived it.
    property var _pendingValues: ({})

    // A deletion is a pending change too, and `undefined` cannot represent it
    // because that is also what an absent key reads as. A unique object can.
    readonly property var _deletedMark: ({ __deleted: true })

    function _remember(key, v) {
        var p = {};
        for (var k in store._pendingValues)
            p[k] = store._pendingValues[k];
        p[key] = v;
        store._pendingValues = p;
    }

    function _pendingKeys() {
        var out = [];
        for (var k in store._pendingValues)
            out.push(k);
        return out;
    }

    // Set for exactly as long as it takes our own write to come back round as
    // a file-change notification.
    property bool _mkdirDone: false

    Timer {
        id: saveTimer
        // Long enough that dragging a slider is one write rather than sixty,
        // short enough that letting go of it feels immediate. The same 260 ms
        // the rest of the build calls `durBase` — this is a UI latency, so it
        // comes off the motion scale rather than being a number of its own.
        interval: Theme.durBase
        repeat: false
        onTriggered: store._write()
    }

    // The directory, once per session, before the first write of that session.
    // `mkdir -p` on a path that already exists is a success and a no-op, so
    // there is nothing to check first.
    //
    // Completion is taken from `runningChanged`, not from `exited`. Quickshell's
    // `exited` signal carries a `QProcess::ExitStatus`, a type the QML type
    // system cannot resolve, so ANY handler for it — even one that ignores the
    // parameter — makes qmllint report that it cannot compile the handler. No
    // other file in this shell subscribes to `exited`, and adding the first
    // instance of a warning class is how a lint gate stops being read. What is
    // actually wanted here is "mkdir has finished", which is `running` going
    // false, and the diagnosis is better taken from stderr than from a number.
    Process {
        id: mkdirProc
        command: ["mkdir", "-p", store.dir]

        stderr: StdioCollector {
            onStreamFinished: {
                if (String(this.text).trim() !== "")
                    console.warn("SettingsStore: could not create " + store.dir
                                 + " — " + String(this.text).trim()
                                 + ". A save will not persist until that path "
                                 + "is writable.");
            }
        }

        onRunningChanged: {
            if (mkdirProc.running)
                return;
            // Marked done even on failure, deliberately: retrying mkdir before
            // every write would turn a permissions problem into a subprocess
            // per click. The write below will fail loudly instead, once.
            store._mkdirDone = true;
            store._writeNow();
        }
    }

    function _write() {
        // First write of the session goes the long way round, through mkdir.
        // Every later one is direct: the directory does not stop existing.
        if (!store._mkdirDone) {
            if (!mkdirProc.running)
                mkdirProc.running = true;
            return;
        }
        store._writeNow();
    }

    function _writeNow() {
        // A document with no schema_version at all is a FRESH file (or one
        // whose migration could not back up — see onLoaded). Stamp the schema
        // this shell writes. Only when ABSENT: a file at a newer schema than
        // this shell knows keeps its number, because stamping CURRENT over it
        // would be a lie the next shell acts on.
        if (store.doc && store.doc[Schema.VERSION_KEY] === undefined) {
            var stamped = {};
            for (var sk in store.doc)
                stamped[sk] = store.doc[sk];
            stamped[Schema.VERSION_KEY] = Schema.CURRENT;
            store.doc = stamped;
            store.schemaVersion = Schema.CURRENT;
        }
        var text;
        try {
            // Two-space indent and a trailing newline, so the file stays
            // something a person can open and read, and so a diff of it is a
            // diff of the setting that changed rather than of one long line.
            text = JSON.stringify(store.doc, null, 2) + "\n";
        } catch (e) {
            store.status = "Not saved — " + e;
            console.warn("SettingsStore: refusing to write unserialisable "
                         + "document: " + e);
            store.dirty = false;
            return;
        }
        file.setText(text);
        var keys = store._pendingKeys();
        store._pendingValues = ({});
        store.dirty = false;
        store.status = "Saved";
        statusClear.restart();
        store.committed(keys);
    }

    // "Saved" is a confirmation, not a state. It says its piece and goes.
    Timer {
        id: statusClear
        interval: 1800
        repeat: false
        onTriggered: if (!store.dirty) store.status = ""
    }

    FileView {
        id: file
        path: store.path
        watchChanges: true

        // A fresh install has no settings.json until the first save. That is
        // the designed first-run state, not an error, and it must not print.
        printErrors: false

        // See the header: while we owe the file a write, the file does not get
        // to tell us what the settings are.
        onFileChanged: if (!store.dirty) file.reload()

        onLoaded: {
            try {
                var parsed = JSON.parse(file.text());
                // A JSON document that is not an object — `[]`, `3`, `"x"` —
                // is as unusable as a syntax error and is handled the same
                // way: keep what we have, say so, overwrite nothing.
                if (parsed === null || typeof parsed !== "object"
                        || Array.isArray(parsed))
                    throw new Error("top level is not an object");

                // MERGE, never replace — the file is the base and anything
                // still owed to it is re-applied on top. See the note on
                // `_pendingValues` for the race this closes and how it was
                // found. With nothing pending this is exactly `doc = parsed`,
                // which is the overwhelmingly common case.
                if (store.dirty) {
                    for (var k in store._pendingValues) {
                        if (store._pendingValues[k] === store._deletedMark)
                            delete parsed[k];
                        else
                            parsed[k] = store._pendingValues[k];
                    }
                }
                store.parseError = "";

                // ── migrate (TRK-1260) ───────────────────────────────
                // Pure table walk first; the file is touched only if it
                // says so, and only after the backup is on disk.
                var mig = Schema.migrate(parsed);
                store.schemaVersion = mig.from;
                if (mig.needed) {
                    var raw = "";
                    try { raw = String(file.text()); } catch (e2) { raw = ""; }
                    if (store._backup(raw, "bak-" + mig.from)) {
                        // Every change is owed to the file, so the merge on
                        // a concurrent load re-applies it (see _pendingValues).
                        for (var c = 0; c < mig.changes.length; ++c) {
                            var ch = mig.changes[c];
                            if (ch.action === "set")
                                store._remember(ch.key, mig.doc[ch.key]);
                            else
                                store._remember(ch.key, store._deletedMark);
                            if (ch.action === "rename")
                                store._remember(ch.to, mig.doc[ch.to]);
                        }
                        parsed = mig.doc;
                        store.schemaVersion = mig.to;
                        console.info("SettingsStore: migrated " + store.path
                                    + " schema " + mig.from + " -> " + mig.to
                                    + " (" + mig.changes.length + " change(s); backup "
                                    + store.lastBackup + ")");
                        // The directory exists — the file was just read from it.
                        store._mkdirDone = true;
                        store.dirty = true;
                        store.status = "Saving…";
                        saveTimer.stop();
                        store.doc = parsed;
                        store._write();
                    } else {
                        // No backup, no migration. Prefs.qml coerces the same
                        // rules at read time, so the shell still wears the
                        // defaults; the file is simply left as it was.
                        store.status = "Settings file not migrated — backup failed";
                        store.doc = parsed;
                    }
                } else {
                    store.doc = parsed;
                }
            } catch (e) {
                store.parseError = String(e);
                console.warn("SettingsStore: " + store.path + " is not usable ("
                             + e + "). Showing defaults. The file has NOT been "
                             + "overwritten — saving from Settings will replace "
                             + "it, so fix or move it first if it matters.");
            }
            store.loaded = true;
        }

        onLoadFailed: {
            // The overwhelmingly common cause is "no file yet". Anything else
            // (a permission problem on someone's restored home directory) has
            // the same shape from here and the same right answer: run on the
            // shipped defaults and let a save try to create the file.
            store.loaded = true;
        }
    }
}
