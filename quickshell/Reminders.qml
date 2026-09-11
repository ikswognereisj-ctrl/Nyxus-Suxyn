pragma Singleton
// Nyxus Suxyn — the reminder store. ONE object, read by everything.
//
// WIP-103/WIP-108. The owner: "if you have a reminder it will show on that
// calendar ... same with the clock, timers etc ... so everything is tied
// together and connects as one and works together."
//
// That sentence is an architectural constraint, not a feature request. The
// tempting build is a calendar that owns reminders and a clock that owns
// alarms, and then the two drift: a reminder made in one is invisible in the
// other, "tomorrow 9am" means two different things depending on which surface
// you asked, and every new surface adds another copy of the same fact. This
// repo has already paid for that shape twice at the file level — the dual-tree
// config drift that gate 13pv exists to catch is the same bug in another
// register.
//
// So: one store. The calendar renders it, the clock renders it, notifications
// fire from it, and anything added later reads it rather than growing its own.
//
// PERSISTENCE. Written to ~/.local/state/nyxus/reminders.json, not to
// .config: this is state the machine produces, not configuration a person
// hand-edits, and XDG is explicit about the difference. Writes are atomic
// (temp file, then rename) because a half-written JSON file on a power cut
// would take the calendar down with a parse error at every subsequent start,
// and a reminder store that eats itself is worse than one that never existed.
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: store

    // Each entry: { id, ts (epoch ms), text, done, kind, recur, lastFired }
    // kind:  reminder | alarm | event   (default reminder)
    // recur: none | daily | weekly      (default none)
    // `ts` is absolute epoch milliseconds, never a Y-M-D string. A string
    // would have to carry a timezone to be unambiguous, and the owner also
    // wants the time zone to be changeable (WIP-103), which would then
    // silently re-interpret every reminder already stored.
    property var items: []

    readonly property string dir:  (Quickshell.env("XDG_STATE_HOME")
                                    || (Quickshell.env("HOME") + "/.local/state")) + "/nyxus"
    readonly property string path: store.dir + "/reminders.json"

    signal changed()

    // ── reading ──────────────────────────────────────────────────────
    // Local Y-M-D, deliberately. A reminder belongs to the day the person is
    // living in, so bucketing by UTC would move an 11pm reminder to tomorrow
    // for anyone west of Greenwich.
    function dayKey(d) {
        return d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate();
    }

    function _norm(it) {
        if (!it) return null;
        return {
            id: it.id,
            ts: it.ts,
            text: it.text,
            done: !!it.done,
            kind: it.kind || "reminder",
            recur: it.recur || "none",
            lastFired: it.lastFired || 0
        };
    }

    function _dayStart(y, m, d) {
        return new Date(y, m, d).getTime();
    }

    function occursOnDay(it, y, m, d) {
        if (!it) return false;
        var day0 = store._dayStart(y, m, d);
        var day1 = day0 + 86400000;
        var t = it.ts;
        var recur = it.recur || "none";
        if (recur === "none" || !recur)
            return t >= day0 && t < day1;
        var orig0 = store._dayStart(
            new Date(t).getFullYear(),
            new Date(t).getMonth(),
            new Date(t).getDate());
        if (day0 < orig0)
            return false;
        if (recur === "daily")
            return true;
        if (recur === "weekly")
            return new Date(t).getDay() === new Date(y, m, d).getDay();
        return t >= day0 && t < day1;
    }

    function nextOccurrence(it, now) {
        if (!it) return 0;
        var t = it.ts;
        var recur = it.recur || "none";
        if (recur === "none" || !recur)
            return t;
        var step = recur === "weekly" ? 7 * 86400000 : 86400000;
        if (t >= now - 120000)
            return t;
        var n = Math.floor((now - t) / step);
        var cand = t + n * step;
        if (cand < now - 120000)
            cand += step;
        return cand;
    }

    function forDay(y, m, d) {
        var out = [];
        for (var i = 0; i < store.items.length; i++) {
            var it = store.items[i];
            if (!it) continue;
            if (store.occursOnDay(it, y, m, d)) out.push(it);
        }
        out.sort(function (a, b) { return a.ts - b.ts; });
        return out;
    }

    function countForDay(y, m, d) { return store.forDay(y, m, d).length; }

    // The next few things coming up, for the clock surface and the flyout.
    function upcoming(limit) {
        var now = Date.now();
        var out = [];
        for (var i = 0; i < store.items.length; i++) {
            var it = store.items[i];
            if (!it || it.done) continue;
            var nxt = store.nextOccurrence(it, now);
            if (nxt >= now)
                out.push({
                    id: it.id, ts: nxt, text: it.text, done: it.done,
                    kind: it.kind || "reminder", recur: it.recur || "none",
                    lastFired: it.lastFired || 0
                });
        }
        out.sort(function (a, b) { return a.ts - b.ts; });
        return out.slice(0, limit || 5);
    }

    // ── writing ──────────────────────────────────────────────────────
    function add(ts, text, kind, recur) {
        if (!text || !String(text).trim()) return null;
        var it = {
            id: String(Date.now()) + "-" + Math.floor(Math.random() * 1e6),
            ts: ts,
            text: String(text).trim(),
            done: false,
            kind: kind || "reminder",
            recur: recur || "none",
            lastFired: 0
        };
        var next = store.items.slice();
        next.push(it);
        store.items = next;          // assign, never mutate: QML tracks the
        store.persist();             // property, not the array's contents
        return it;
    }

    function remove(id) {
        var next = [];
        for (var i = 0; i < store.items.length; i++)
            if (store.items[i] && store.items[i].id !== id) next.push(store.items[i]);
        store.items = next;
        store.persist();
    }

    function toggleDone(id) {
        var next = [];
        for (var i = 0; i < store.items.length; i++) {
            var it = store._norm(store.items[i]);
            if (!it) continue;
            if (it.id === id)
                it.done = !it.done;
            next.push(it);
        }
        store.items = next;
        store.persist();
    }

    function snooze(id, minutes) {
        var mins = minutes > 0 ? minutes : 5;
        var next = [];
        var now = Date.now();
        for (var i = 0; i < store.items.length; i++) {
            var it = store._norm(store.items[i]);
            if (!it) continue;
            if (it.id === id) {
                var base = store.nextOccurrence(it, now);
                if (base < now)
                    base = now;
                it.ts = base + mins * 60000;
                it.done = false;
                it.lastFired = 0;
            }
            next.push(it);
        }
        store.items = next;
        store.persist();
    }

    function _fireDue() {
        var now = Date.now();
        var next = [];
        var fired = false;
        for (var i = 0; i < store.items.length; i++) {
            var it = store._norm(store.items[i]);
            if (!it) continue;
            if (it.done) {
                next.push(it);
                continue;
            }
            var nxt = store.nextOccurrence(it, now);
            var due = nxt <= now + 15000 && nxt >= now - 120000;
            var fresh = !it.lastFired || (now - it.lastFired > 55000);
            if (due && fresh) {
                var label = it.kind === "alarm" ? qsTr("Alarm")
                          : (it.kind === "event" ? qsTr("Appointment") : qsTr("Reminder"));
                Sys.announce(label, it.text, "Nyxus",
                             it.kind === "alarm" ? "alert" : "notification");
                it.lastFired = now;
                fired = true;
            }
            next.push(it);
        }
        if (fired) {
            store.items = next;
            store.persist();
        }
    }

    function persist() {
        store.changed();
        writer.running = true;
    }

    // Atomic: write a sibling temp file, then rename over the target. rename(2)
    // within one directory is atomic, so a reader never sees a partial file and
    // a crash mid-write leaves the previous good copy intact.
    Process {
        id: writer
        command: ["sh", "-c",
            'mkdir -p "$NYX_DIR" && printf %s "$NYX_JSON" > "$NYX_DIR/.reminders.tmp" '
            + '&& mv -f "$NYX_DIR/.reminders.tmp" "$NYX_DIR/reminders.json"']
        environment: ({
            "NYX_DIR": store.dir,
            "NYX_JSON": JSON.stringify(store.items)
        })
    }

    // ── loading ──────────────────────────────────────────────────────
    // A missing file is the normal first-run case and must not warn. A
    // CORRUPT file is different: keep the empty list so the shell still runs,
    // but say so, because silently discarding someone's reminders is the kind
    // of thing that should never happen quietly.
    FileView {
        id: reader
        path: store.path
        watchChanges: true
        onFileChanged: reader.reload()
        onLoaded: {
            try {
                var parsed = JSON.parse(reader.text());
                var raw = Array.isArray(parsed) ? parsed : [];
                var normed = [];
                for (var i = 0; i < raw.length; i++) {
                    var n = store._norm(raw[i]);
                    if (n) normed.push(n);
                }
                store.items = normed;
                store.changed();
            } catch (e) {
                console.warn("Reminders: " + store.path + " is not valid JSON ("
                             + e + ") — starting empty rather than discarding it. "
                             + "The file has NOT been overwritten.");
                store.items = [];
            }
        }
    }

    // Due-watch. Only while something is still open. 15 s is enough for
    // "now" without a 1 Hz idle cost on a quiet session.
    Timer {
        interval: 15000
        repeat: true
        running: {
            for (var i = 0; i < store.items.length; i++) {
                if (store.items[i] && !store.items[i].done)
                    return true;
            }
            return false;
        }
        onTriggered: store._fireDue()
    }
}
