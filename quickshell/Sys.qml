pragma Singleton
// NYXUS Daily Driver — live system state.
//
// One place that reads Quickshell's real service singletons (UPower, Pipewire,
// Networking, Bluetooth, Mpris) and exposes clean, derived properties the Bar
// and Flyout bind to. Keeping the raw service access here means the surfaces
// never repeat the null-guards, and there is a single spot to retune if an API
// shifts. APIs verified against Quickshell 0.3.0's shipped qmltypes on
// 2026-08-02.
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Notifications
import Quickshell.Io
import QtQuick

Singleton {
    id: sys

    // ── notifications ────────────────────────────────────────────────────
    // Quickshell is the notification daemon for the Daily shell (so the flyout
    // shows real notifications and toasts, and there is exactly one daemon on
    // the bus). The daily bake therefore does NOT start swaync.
    readonly property var notifications: notifServer.trackedNotifications
    // Do Not Disturb. The flyout's DND pill used to shell out to
    // `swaync-client`, which does nothing here because swaync is not the
    // daemon — this shell is. DND therefore has to live in this process.
    // Semantics: a silenced notification is still *tracked*, so it is waiting
    // in the flyout when you come back. Only the interruption is suppressed.
    property bool dnd: false
    property bool _dndReady: false
    // Emitted for each fresh notification so the transient toast layer
    // (Toasts.qml) can show it briefly; the flyout reads trackedNotifications.
    signal notified(string summary, string body, string appName)
    // Critical only. HORIZON §5.3: routine notifications surface in the
    // horizon's Crest and live in the flyout — they do not get a floating
    // card, because a popup that covers your work to say a download finished
    // is a defect every desktop has agreed to ship. "Urgent" has to mean
    // something, so the one thing that still interrupts is the one the sender
    // marked critical.
    signal urgent(string summary, string body, string appName)

    // ── THE BOUND on the tracked list (WIP-661) ──────────────────────────
    // Until this existed, nothing in the whole shell ever expired, aged out
    // or capped `trackedNotifications`. Every notification was marked
    // `tracked = true` below and the ONLY removal in the build was the user
    // pressing "Clear all" in the flyout (SidePanel.qml § NOTIFICATIONS) or
    // the ✕ on one card. A session nobody clears therefore accumulated every
    // notification it had ever received, for the life of the process — and
    // with `imageSupported` on, the image-bearing ones hold their pixels too.
    // That is unbounded BY CONSTRUCTION, which is the shape of WIP-632's
    // "1.71 GB after a while": not a spike, a floor that only rises.
    //
    // The policy, and what it costs the person using this:
    //   · CAP — at most `notifCap` notifications are ever tracked. Past that
    //     the OLDEST are expired. Oldest is the honest choice: it is the one
    //     whose toast fired longest ago, the one that has been sitting in the
    //     flyout the longest, and the one at the TOP of the list the flyout
    //     draws. What a user loses: if more than notifCap arrive without ever
    //     clearing, the earliest ones are no longer in the flyout.
    //   · AGE-OUT — a notification older than `notifMaxAgeMs` is expired.
    //     What a user loses: something that arrived more than a day ago,
    //     was never cleared and was never acted on is gone. Critical urgency
    //     is EXEMPT from the age-out, because the spec says a critical
    //     notification does not time out and because this shell already threw
    //     it on screen as a floating card (see `urgent` above) — it was seen.
    //   · Critical is NOT exempt from the cap. Exempting it there would put
    //     the unbounded path straight back for exactly the sender most likely
    //     to flood, which is the bug this row exists to close.
    //
    // Both run on the ONE path that adds a notification, so the tracked list
    // cannot pass the cap even momentarily and the shell keeps NO clock of
    // its own — a timer here would be an idle cost the design refuses to pay
    // (Bar.qml § the Meridian records the same reasoning for the clock), and
    // nothing can grow while nothing is arriving.
    readonly property int notifCap: 100
    readonly property int notifMaxAgeMs: 24 * 60 * 60 * 1000
    // id → { t: arrival epoch ms, n: arrival sequence }. REBUILT from the live
    // model on every trim rather than appended to, so it can never outgrow or
    // outlive the model it describes — a leak fixer that leaks is the one joke
    // this row cannot afford.
    //
    // Why a sequence number and not just the clock: a FLOOD is the exact case
    // the cap defends against, and a flood arrives inside one millisecond, so
    // every stamp would be equal and Array.sort is not required to be stable.
    // With equal keys the cap could evict the notification that just arrived —
    // the newest, the one that is certainly unseen — which is the one outcome
    // this row forbids. `n` makes arrival order a TOTAL order; `t` is only ever
    // asked how old something is. `real`, not `int`: doubles are exact to 2^53,
    // and a 32-bit counter is a wrap nobody would ever find.
    property var notifBorn: ({})
    property real notifSeq: 0

    function trimNotifications() {
        var model = notifServer.trackedNotifications;
        var list = model ? (model.values || []) : [];
        var now = Date.now();
        var i;
        // 1 · stamp what is new, forget what is gone.
        var born = {};
        for (i = 0; i < list.length; i++) {
            var k = "" + list[i].id;
            if (sys.notifBorn[k] !== undefined) {
                born[k] = sys.notifBorn[k];
            } else {
                sys.notifSeq = sys.notifSeq + 1;
                born[k] = { t: now, n: sys.notifSeq };
            }
        }
        // Expiring mutates the model we would be walking, so decide against a
        // copy and act afterwards — clearNotifications() records the same trap.
        var copy = list.slice();
        var doomed = [];
        // 2 · the age-out.
        for (i = 0; i < copy.length; i++) {
            if (copy[i].urgency === NotificationUrgency.Critical)
                continue;
            if (now - born["" + copy[i].id].t >= sys.notifMaxAgeMs)
                doomed.push(copy[i]);
        }
        // 3 · the cap, oldest first.
        var kept = [];
        for (i = 0; i < copy.length; i++)
            if (doomed.indexOf(copy[i]) < 0)
                kept.push(copy[i]);
        kept.sort(function (a, b) {
            return born["" + a.id].n - born["" + b.id].n;
        });
        for (i = 0; kept.length - i > sys.notifCap; i++)
            doomed.push(kept[i]);
        // 4 · forget the stamps of what is about to go, THEN publish the map.
        //     Stamping before the eviction and publishing before it was the
        //     harness's one real catch: the map came out one entry longer than
        //     the model every time it evicted, so between trims it carried the
        //     dead. Self-correcting, but this row is about things that carry
        //     what nobody is using.
        for (i = 0; i < doomed.length; i++)
            delete born["" + doomed[i].id];
        sys.notifBorn = born;
        // 5 · expire(), never dismiss(): the sending application is told the
        //     truth over the bus — this one timed out; the user did not wave
        //     it away, and an app that reopens on Dismissed would be lied to.
        for (i = 0; i < doomed.length; i++)
            doomed[i].expire();
    }

    // ══ PER-APP NOTIFICATION RULES (TRK-3217) ══════════════════════════
    // The Settings notifications flyout offers a per-app Allow and a per-app
    // Sound. They are settings, so they live in `settings.json` like every
    // other one, under a single `notify_apps` object keyed by the app name
    // the notification itself carries:
    //
    //     "notify_apps": { "Thunderbird": { "allow": false, "sound": true } }
    //
    // ⚠ THE RULE IS ENFORCED HERE, on the one path that turns a notification
    // into a toast and a chime — not in the flyout that draws the switches.
    // A switch whose only effect is on the surface that draws it is the
    // decorative-toggle defect the 2026-08-27 brief forbids, and this build
    // has already shipped the shape once (a Settings page for cliphist with
    // no watcher behind it).
    //
    // ABSENT MEANS ALLOWED. An app that has never been touched has no entry
    // and is not silenced — a fresh `settings.json` must behave exactly as
    // it did before this key existed.
    //
    // The record is NOT affected. A muted app's notification is still
    // tracked, so it is still in the inbox and still counted; what a mute
    // takes away is the interruption, which is the same division DND makes.
    function _appRule(appName) {
        var all = SettingsStore.value("notify_apps", null);
        if (!all || typeof all !== "object")
            return null;
        var r = all[String(appName || "")];
        return (r && typeof r === "object") ? r : null;
    }

    function appNotifyAllowed(appName) {
        var r = sys._appRule(appName);
        return !(r && r.allow === false);
    }

    function appNotifySound(appName) {
        var r = sys._appRule(appName);
        return !(r && r.sound === false);
    }

    // Write one field of one app's rule without disturbing the others. A
    // read-modify-write of the whole object, because `SettingsStore.setValue`
    // replaces the value at a key and a per-field write would drop the rest.
    function setAppNotifyRule(appName, field, value) {
        var name = String(appName || "");
        if (name === "")
            return;
        var all = SettingsStore.value("notify_apps", null);
        var next = {};
        if (all && typeof all === "object")
            for (var k in all)
                next[k] = all[k];
        var cur = (next[name] && typeof next[name] === "object")
                  ? next[name] : {};
        var rule = {};
        for (var f in cur)
            rule[f] = cur[f];
        rule[field] = value;
        next[name] = rule;
        SettingsStore.setValue("notify_apps", next);
    }

    // Every app name this session has actually seen a notification from, in
    // first-seen order, plus every app already carrying a rule. Derived, so
    // the flyout can never list an app that has not really spoken here.
    readonly property var notifyApps: {
        var seen = [];
        var mark = {};
        var model = notifServer.trackedNotifications;
        var list = (model && model.values) ? model.values : [];
        for (var i = 0; i < list.length; i++) {
            var a = String(list[i].appName || "");
            if (a === "" || mark[a])
                continue;
            mark[a] = true;
            seen.push(a);
        }
        var all = SettingsStore.value("notify_apps", null);
        if (all && typeof all === "object")
            for (var k in all)
                if (!mark[k] && String(k) !== "") {
                    mark[k] = true;
                    seen.push(String(k));
                }
        return seen;
    }

    NotificationServer {
        id: notifServer
        keepOnReload: false
        bodySupported: true
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: true
        onNotification: function (n) {
            n.tracked = true;
            // WIP-661. The bound lives HERE, on the only path that adds one,
            // and it runs before anything can return early — DND leaves below
            // without touching the list, so a silenced session would otherwise
            // be the one that grows fastest and the one nobody is watching.
            sys.trimNotifications();
            var s = n.summary || n.appName || "Notification";
            var b = n.body || "";
            var a = n.appName || "";
            // Tracked above regardless, so DND / Quiet Hours hide the toast,
            // not the record. Same rule as Sys.announce (TRK-3193).
            var block = SettingsStore.value("notifications", null);
            var always = block && typeof block === "object" && block.alarms_always;
            var crit = n.urgency === NotificationUrgency.Critical;
            if ((sys.dnd || sys.quietHoursActive()) && !(always && crit))
                return;
            // TRK-3217 — an app the user has switched off does not interrupt.
            // Deliberately AFTER tracking and BEFORE the toast: the record
            // keeps it, the screen does not.
            if (!sys.appNotifyAllowed(a))
                return;
            sys.notified(s, b, a);
            if (crit)
                sys.urgent(s, b, a);
            if (sys.appNotifySound(a))
                sys.playSound(crit ? "alert" : "notification");
        }
    }
    function clearNotifications() {
        var list = notifServer.trackedNotifications ? notifServer.trackedNotifications.values : [];
        // Dismiss a copy — expiring mutates the model we are iterating.
        var copy = list.slice();
        for (var i = 0; i < copy.length; i++) copy[i].dismiss();
    }

    // System chimes. One helper so DND / a missing binary cannot fork a
    // second path. Hyprland already calls `nyxus-sound login|lock|unlock|logout`
    // — this is the in-process half (toast, battery, USB, Start, OSD).
    // Fail silent: execDetached with a missing binary is a no-op.
    // TRK-3180. In-shell nags (timer, reminders) used to emit `notified`
    // and skip the DND check NotificationServer already has. One door:
    // toast + sound, or neither. Quiet hours use the EXISTING
    // `notifications.quiet_hours` / `quiet_from` / `quiet_to` block
    // (`nyxus-quiet-hours`, GAP-917) — this is a read at announce time,
    // not a second scheduler. `alarms_always` is the existing bypass.
    function _hhmmToMin(s) {
        var m = String(s || "").match(/^\s*(\d{1,2}):(\d{2})\s*$/);
        if (!m)
            return -1;
        var h = parseInt(m[1], 10), mi = parseInt(m[2], 10);
        if (h > 23 || mi > 59)
            return -1;
        return h * 60 + mi;
    }

    function quietHoursActive() {
        var block = SettingsStore.value("notifications", null);
        if (!block || typeof block !== "object" || !block.quiet_hours)
            return false;
        var a = sys._hhmmToMin(block.quiet_from || "22:00");
        var b = sys._hhmmToMin(block.quiet_to || "07:00");
        if (a < 0 || b < 0 || a === b)
            return false;
        var now = new Date();
        var cur = now.getHours() * 60 + now.getMinutes();
        if (a < b)
            return cur >= a && cur < b;
        return cur >= a || cur < b;
    }

    function announce(summary, body, appName, soundEv, force) {
        var alarm = (soundEv === "alert");
        var block = SettingsStore.value("notifications", null);
        var always = block && typeof block === "object" && block.alarms_always;
        if ((sys.dnd || sys.quietHoursActive()) && !force && !(always && alarm))
            return;
        sys.notified(summary || "", body || "", appName || "");
        sys.playSound(soundEv || "notification");
    }

    function hydrateDnd() {
        sys.dnd = SettingsStore.boolValue("notify_dnd", false);
        sys._dndReady = true;
    }

    onDndChanged: {
        if (!sys._dndReady)
            return;
        SettingsStore.setValue("notify_dnd", sys.dnd);
    }

    Connections {
        target: SettingsStore
        function onLoadedChanged() {
            if (SettingsStore.loaded)
                sys.hydrateDnd();
        }
    }

    Component.onCompleted: {
        if (SettingsStore.loaded)
            sys.hydrateDnd();
    }

    function playSound(ev) {
        if (!ev)
            return;
        if (!Prefs.uiSounds)
            return;
        if (!sys._uiEventOn(String(ev)))
            return;
        var pct = Math.round(Math.max(0, Math.min(1, Prefs.uiSoundVolume)) * 100);
        Quickshell.execDetached(["nyxus-sound", "--ui-gain", String(pct), String(ev)]);
    }

    // TRK-1087 — Prefs mute only. Does not write .disabled files.
    // Unlock shares lock. Unmapped events stay on while the master is on.
    function _uiEventOn(name) {
        switch (name) {
        case "press":
        case "tup":
        case "ui-press":
            return Prefs.uiSoundPress;
        case "notification":
        case "notify":
        case "ui-notify":
        case "message":
            return Prefs.uiSoundNotify;
        case "knock":
        case "bump":
        case "ui-knock":
        case "wall":
            return Prefs.uiSoundKnock;
        case "lock":
        case "ui-lock":
        case "unlock":
        case "ui-unlock":
            return Prefs.uiSoundLock;
        default:
            return true;
        }
    }

    // ── battery (UPower display device) ──────────────────────────────────
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery !== null && battery.isLaptopBattery && battery.isPresent
    // UPower reports 0–100; guard the 0–1 case just in case a backend normalises.
    readonly property int batteryPercent: {
        if (!battery) return 0;
        var p = battery.percentage;
        return Math.round(p <= 1 ? p * 100 : p);
    }
    readonly property bool batteryCharging: battery !== null
        && (battery.state === UPowerDeviceState.Charging
            || battery.state === UPowerDeviceState.FullyCharged
            || battery.state === UPowerDeviceState.PendingCharge)

    // ── audio (the sink that actually makes sound) ────────────────────
    // PipeWire's default is often Easy Effects, a virtual node. wpctl and
    // `defaultAudioSink.audio.volume` move that node's fader, the OSD
    // changes, and the DAC does not — EE already captured the stream at
    // unity and plays it out Speakers/Headphones. Volume must follow the
    // hardware (or Bluetooth) sink, not the filter.
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var playbackSink: {
        var def = sys.sink;
        if (!def)
            return null;
        var nm = String(def.name || "").toLowerCase();
        var ds = String(def.description || "").toLowerCase();
        var virt = nm.indexOf("easyeffects") >= 0 || ds.indexOf("easy effects") >= 0
                || nm.indexOf("jamesdsp") >= 0;
        if (!virt)
            return def;
        var all = Pipewire.nodes ? Pipewire.nodes.values : [];
        var analog = null;
        for (var i = 0; i < all.length; i++) {
            var n = all[i];
            if (!n || n === def || !n.isSink || n.isStream)
                continue;
            var nname = String(n.name || "").toLowerCase();
            var ndesc = String(n.description || "").toLowerCase();
            if (nname.indexOf("easyeffects") >= 0 || ndesc.indexOf("easy effects") >= 0)
                continue;
            if (ndesc.indexOf("hdmi") >= 0 || ndesc.indexOf("displayport") >= 0)
                continue;
            if (nname.indexOf("pro-output") >= 0)
                continue;
            var lab = ndesc + " " + nname;
            if (lab.indexOf("headphone") >= 0 || lab.indexOf("headset") >= 0)
                return n;
            if (nname.indexOf("bluez_output") >= 0)
                return n;
            if (lab.indexOf("speaker") >= 0 || lab.indexOf("analog") >= 0)
                analog = analog || n;
        }
        return analog || def;
    }
    readonly property real volume: (playbackSink && playbackSink.audio) ? playbackSink.audio.volume : 0
    readonly property bool muted: (playbackSink && playbackSink.audio) ? playbackSink.audio.muted : false
    function setVolume(v) {
        if (playbackSink && playbackSink.audio)
            playbackSink.audio.volume = Math.max(0, Math.min(1, v));
    }
    function toggleMute() {
        if (playbackSink && playbackSink.audio)
            playbackSink.audio.muted = !playbackSink.audio.muted;
    }
    readonly property var source: Pipewire.defaultAudioSource
    readonly property bool micMuted: (source && source.audio) ? source.audio.muted : false
    function toggleMic() {
        if (source && source.audio)
            source.audio.muted = !source.audio.muted;
    }
    // Track both: default so the picker stays live, playback so the fader
    // is the DAC Easy Effects is writing to.
    PwObjectTracker {
        objects: {
            var o = [];
            if (sys.sink)
                o.push(sys.sink);
            if (sys.playbackSink && sys.playbackSink !== sys.sink)
                o.push(sys.playbackSink);
            if (sys.source)
                o.push(sys.source);
            return o;
        }
    }

    // ── audio outputs ────────────────────────────────────────────────────
    // Every real sink Pipewire knows about, so the flyout can offer a picker
    // instead of a volume slider that silently applies to whatever the
    // system happens to have chosen. Streams are excluded — those are
    // applications playing audio, not devices you can send audio to.
    readonly property var audioSinks: {
        var out = [];
        var seen = {};
        var all = Pipewire.nodes ? Pipewire.nodes.values : [];
        for (var i = 0; i < all.length; i++) {
            var n = all[i];
            if (!n || !n.isSink || n.isStream)
                continue;
            // WIP-102. The owner's machine listed "HDMI 1", "HDMI 2", "HDMI 3"
            // on a laptop with ONE HDMI port, and he could not tell what any of
            // them were. PipeWire enumerates a card's HDMI outputs per profile,
            // so the extras are ports that exist in the codec and are attached
            // to nothing. The old code knew (see the note this replaces) and
            // only capped the list at five, which hides the fourth without
            // making the first three mean anything.
            //
            // Collapse by the name a PERSON would read. Two entries that say
            // the same thing are the same choice as far as the picker is
            // concerned, and the first one wins because the current sink is
            // sorted to the front below.
            var label = sys.sinkLabel(n);
            if (seen[label])
                continue;
            seen[label] = true;
            out.push(n);
        }
        out.sort(function (a, b) {
            if ((a === sys.sink) !== (b === sys.sink)) return a === sys.sink ? -1 : 1;
            return 0;
        });
        return out.slice(0, 5);
    }

    // The label a person reads in the picker. `description` first, because it
    // is the human string ("Built-in Audio Analog Stereo") where `nickname` is
    // often the raw port ("HDMI 3"); `name` last, because it is the PipeWire
    // node id and is never fit to show.
    //
    // The rewrites below turn what is left into where the sound comes out,
    // which is the only thing the person choosing actually wants to know.
    // Deliberately conservative: anything unrecognised is passed through
    // rather than mangled, so a device we have not seen still reads sensibly.
    function sinkLabel(n) {
        if (!n) return "";
        var raw = n.description || n.nickname || n.name || "Output";
        var s = String(raw);
        var low = s.toLowerCase();

        if (low.indexOf("bluez") >= 0 || low.indexOf("bluetooth") >= 0)
            return n.nickname || "Bluetooth";
        if (low.indexOf("hdmi") >= 0 || low.indexOf("displayport") >= 0)
            return "HDMI";                       // the display, whichever port
        if (low.indexOf("headphone") >= 0 || low.indexOf("headset") >= 0)
            return "Headphones";
        if (low.indexOf("usb") >= 0)
            return n.nickname || "USB audio";
        if (low.indexOf("speaker") >= 0 || low.indexOf("analog") >= 0
            || low.indexOf("built-in") >= 0 || low.indexOf("internal") >= 0)
            return "Speakers";
        return s;
    }
    function setSink(n) { if (n) Pipewire.preferredDefaultAudioSink = n; }

    // ── per-application volume (WIP-702 · GAP-926) ───────────────────────
    // The flyout could move ONE slider — the master — so turning a video down
    // without turning the music down meant opening `pavucontrol`, a GTK2
    // window in nobody's theme. Windows and macOS both give you a slider per
    // playing app in the panel you already opened; this is that list.
    //
    // NO NEW BACKEND AND NO POLLING. `Quickshell.Services.Pipewire` is
    // already this file's audio source — the master slider, the mute and the
    // output picker all come from it — and `Pipewire.nodes` is a live model:
    // a stream appearing or vanishing re-evaluates this binding on its own,
    // which is why there is no timer here and no list to reconcile by hand.
    //
    // WHAT COUNTS AS AN APP STREAM: `isStream` and NOT `isSink`. A sink is a
    // device you send audio TO (the `audioSinks` list above); a non-sink
    // stream is an application playing INTO one. Recording streams are sinks
    // from PipeWire's point of view of the direction, so a microphone client
    // does not turn up here pretending to be a music player.
    //
    // `n.audio` is required, not assumed: a node can exist for a beat before
    // its audio interface is bound, and a row whose slider has nothing behind
    // it is a control that lies.
    readonly property var appStreams: {
        var out = [];
        var all = Pipewire.nodes ? Pipewire.nodes.values : [];
        for (var i = 0; i < all.length; i++) {
            var n = all[i];
            if (!n || !n.isStream || n.isSink || !n.audio) continue;
            out.push(n);
        }
        return out;
    }

    // ⚠ THE TRACKER IS WHAT MAKES THE SLIDERS LIVE. A PwNode's `audio`
    // interface is not bound until something asks for it — the same reason
    // the default sink above has a tracker of its own. Without this the rows
    // would draw and then never move, and worse, writing a volume would go
    // nowhere. The list is bound, so a stream that goes away is untracked in
    // the same evaluation that drops its row: nothing to leak, nothing to
    // clean up on a timer.
    PwObjectTracker { objects: sys.appStreams }

    // The name a person reads. `application.name` is what the app declares
    // about ITSELF ("Chromium", "mpv"); `media.name` is what is playing and
    // is often a URL or a file path, so it is a subtitle and never the title.
    // `description`/`nickname` last, because those are frequently the raw
    // node string. Deliberately conservative — anything unrecognised is
    // passed through rather than mangled, exactly like `sinkLabel`.
    function streamLabel(n) {
        if (!n) return "";
        var p = n.properties || ({});
        var name = p["application.name"] || n.description || n.nickname || n.name;
        return String(name || "Application");
    }
    function streamDetail(n) {
        if (!n) return "";
        var p = n.properties || ({});
        var media = p["media.name"] || "";
        var label = sys.streamLabel(n);
        // Never repeat the title back as its own subtitle.
        return (media && String(media) !== label) ? String(media) : "";
    }
    function streamIcon(n) {
        if (!n) return "";
        var p = n.properties || ({});
        return String(p["application.icon-name"] || "");
    }
    function setStreamVolume(n, v) {
        if (n && n.audio) n.audio.volume = Math.max(0, Math.min(1, v));
    }
    function toggleStreamMute(n) {
        if (n && n.audio) n.audio.muted = !n.audio.muted;
    }

    // ── Wi-Fi networks ───────────────────────────────────────────────────
    // Real scan results from NetworkManager, strongest first. `connect()`
    // works for networks NetworkManager already has a saved profile for;
    // anything else needs a password, and asking for one properly is a job
    // for nm-connection-editor rather than a text field in a flyout.
    readonly property var wifiNetworks: {
        var out = [];
        if (!Networking.wifiEnabled) return out;
        var devs = sys._wifiDevices;
        for (var i = 0; i < devs.length; i++) {
            var nets = devs[i].networks ? devs[i].networks.values : [];
            for (var j = 0; j < nets.length; j++)
                if (nets[j] && nets[j].name)
                    out.push(nets[j]);
        }
        out.sort(function (a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            return (b.signalStrength || 0) - (a.signalStrength || 0);
        });
        return out.slice(0, 24);
    }

    // ── vitals ───────────────────────────────────────────────────────────
    // CPU, memory and uptime, read from /proc — real numbers, no estimates.
    //
    // ⛔ THE HYPRLOCK LESSON (AUDIT-PLAN item 1): a label that spawns
    // subprocesses every 50 ms starved the lock screen's event loop until it
    // stopped accepting keystrokes. This is the opposite shape: ONE `sh` every
    // two seconds, and only while something is actually looking at the
    // numbers. Nothing polls while the flyout is shut.
    property bool vitalsActive: false
    // Ambient consumers (owner ruling 2026-08-09, "react to how the computer
    // is running"): the reactive borders — BorderPulse on the windows,
    // ReactiveEdge on the panes — DISPLAY the workload mood all the time, so
    // "somebody is looking" is now permanently true at border granularity.
    // Without this, cpuPercent froze whenever the flyout was shut and the
    // moods could never change at rest — WIP-198 shipped that gap unseen.
    // One `sh` every five seconds is the price of the feature; the 2 s
    // cadence below still takes over whenever a real vitals page is open.
    property bool ambientVitals: false
    property int cpuPercent: 0
    property int memPercent: 0
    property string memText: ""
    property string uptimeText: ""
    property real _prevBusy: -1
    property real _prevTotal: -1

    // ── disk + network, for the vitals rail (WIP-334) ────────────────────
    // Owner asked for the three rings to become five or six, with network
    // among them. A ring is a RATIO, so each of these has to resolve to
    // 0..1 honestly rather than being drawn from a number that has no
    // ceiling — which is the whole difficulty with throughput.
    //
    //   diskPercent — used space on /, which is a real percentage.
    //   netPercent  — throughput against a ROLLING PEAK, not a made-up
    //                 "max speed". A link's ceiling is unknowable from
    //                 /proc (a 1 Gb NIC on a 40 Mb line reads as neither),
    //                 so the ring shows this burst relative to the biggest
    //                 burst seen recently and the readout carries the real
    //                 rate. The peak decays so one 900 MB/s copy does not
    //                 flatten the ring for the rest of the session.
    property int diskPercent: 0
    property string diskText: ""
    property int netPercent: 0
    property string netText: "—"
    property real _prevNetBytes: -1
    property real _netPeak: 262144        // 256 KB/s floor, so idle is not 100%
    property real _prevNetAt: 0
    // The LINK, as opposed to the RATE above. `netLinkText` is what the widget
    // shows so a glance answers "what am I connected at?" rather than only
    // "how much is moving this second?".
    property string netIface: ""
    property int netLinkMbps: 0
    property string netKind: ""
    // Wi-Fi link quality, 0-70 from /proc/net/wireless; -1 when not wireless.
    property int netWifiQual: -1
    readonly property string netLinkText: {
        if (sys.netIface === "")
            return "—";
        if (sys.netKind === "wifi")
            return sys.netWifiQual >= 0
                   ? Math.round(100 * Math.min(70, sys.netWifiQual) / 70) + "%"
                   : "Wi-Fi";
        if (sys.netLinkMbps >= 1000)
            return (sys.netLinkMbps / 1000).toFixed(sys.netLinkMbps % 1000 === 0 ? 0 : 1) + " Gb/s";
        return sys.netLinkMbps > 0 ? sys.netLinkMbps + " Mb/s" : "link";
    }

    // Start / flyout SYSTEM rail (owner 2026-08-19). Presence is probed
    // from sysfs once (and again whenever a vitals surface opens) so a
    // machine without fans or a discrete/util GPU does not draw empty
    // rows. Values ride the SAME `sh` as CPU/RAM — nvidia-smi only while
    // vitalsActive, never on the 5 s ambient tick (hyprlock lesson).
    // `lm_sensors` is already on the ISO; this reads hwmon sysfs, not
    // `sensors`. No new package.
    property bool hasGpu: false
    // nv | amd | igpu | none | unknown — swirl auto-tier uses this so an
    // Intel-only laptop does not run the 3060 "full" 60 Hz dye budget.
    property string gpuClass: "unknown"
    readonly property int swirlGpuStep: {
        if (sys.gpuClass === "igpu")
            return 1;
        if (sys.gpuClass === "none")
            return 2;
        return 0;
    }
    property bool hasFans: false
    property bool hasNet: false
    property int gpuPercent: 0
    property string gpuText: "—"
    property int fanPercent: 0
    property string fanText: "—"
    property real _fanPeak: 2000
    // Hottest hwmon temp*_input in a sane range (15–120 °C). One number
    // for Start / flyout: how warm the machine is running. Magma at ≥85 °C.
    property bool hasTemp: false
    property int tempC: 0
    property int tempPercent: 0
    property string tempText: "—"
    // Slow sparkline buffers — one sample per ambient/vitals tick (5 s or 2 s),
    // never a second timer (WIP-116 / hyprlock lesson). 36 samples ≈ 3 min at 5 s.
    readonly property int histCap: 36
    property var histCpu: []
    property var histMem: []
    property var histTemp: []
    property var histNet: []
    property var histDisk: []
    property int netIfaces: 0
    property int netUp: 0
    property string _healthToastKey: ""
    // TRK-3374 — consecutive samples with no interface up. A Wi-Fi roam or
    // DHCP renegotiation drops operstate for a single sample; an URGENT
    // "Network is down" for that is a false alarm (owner photographed it
    // firing while traffic was live at 851 B/s).
    property int _netDownTicks: 0

    function _pushHist(arr, v) {
        var next = arr.slice();
        next.push(v);
        if (next.length > sys.histCap)
            next.splice(0, next.length - sys.histCap);
        return next;
    }
    function _maybeHealthToast() {
        var key = "", sum = "", body = "", crit = false;
        if (sys.hasTemp && sys.tempC >= 85) {
            key = "thermal"; crit = sys.tempC >= 95;
            sum = "Machine is hot";
            body = sys.tempC + " °C — if you wait, clocks drop then the machine may shut down";
        } else if (sys.memPercent >= 90) {
            key = "ram"; crit = sys.memPercent >= 95;
            sum = "Memory is tight";
            body = sys.memPercent + "% in use — if you wait, the kernel may kill apps (including the shell)";
        } else if (sys.diskPercent >= 90) {
            key = "disk"; crit = sys.diskPercent >= 98;
            sum = "Disk is filling";
            body = sys.diskPercent + "% used — if you wait, updates and snapshots start failing";
        } else if (sys.netIfaces > 0 && sys.netUp === 0) {
            // TRK-3374 — two consecutive down samples before the toast, so a
            // one-sample operstate flap never pages the owner as critical.
            sys._netDownTicks += 1;
            if (sys._netDownTicks >= 2) {
                key = "nic"; crit = true;
                sum = "Network is down";
                body = "No interface is up — if you wait, updates and time-sync stay stuck";
            }
        } else {
            sys._netDownTicks = 0;
        }
        if (key === "") {
            sys._healthToastKey = "";
            return;
        }
        if (key === sys._healthToastKey)
            return;
        sys._healthToastKey = key;
        sys.announce(sum, body, "Health", crit ? "alert" : "notification", crit);
        if (crit)
            sys.urgent(sum, body, "Health");
    }

    readonly property string _vitalsCore:
        "awk '/^cpu /{print $2+$3+$4+$6+$7+$8, $2+$3+$4+$5+$6+$7+$8}' /proc/stat; "
        + "awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{print t, a}' /proc/meminfo; "
        + "awk '{print int($1)}' /proc/uptime; "
        + "df -P / | awk 'NR==2{print $3, $2}'; "
        + "awk -F'[: ]+' '/:/ && $2 !~ /^(lo|veth|virbr|docker|br-)/ "
        + "{rx+=$3; tx+=$11} END{print rx+tx}' /proc/net/dev; "
        + "m=0; for f in /sys/class/hwmon/hwmon*/temp*_input; do "
        + "[ -r \"$f\" ] || continue; v=$(cat \"$f\" 2>/dev/null || echo 0); "
        + "[ \"$v\" -ge 15000 ] && [ \"$v\" -le 120000 ] && [ \"$v\" -gt \"$m\" ] && m=$v; "
        + "done; echo $m; "
        + "n=0; up=0; ifn=-; spd=0; knd=-; for d in /sys/class/net/*; do "
        + "b=$(basename \"$d\"); "
        + "case \"$b\" in lo|veth*|docker*|br-*|virbr*) continue ;; esac; "
        + "n=$((n+1)); "
        + "[ \"$(cat \"$d/operstate\" 2>/dev/null)\" = up ] && up=$((up+1)); "
        // The LINK the owner is actually using: first carrier-up interface,
        // preferring a wired one (a laptop with both up should report the
        // wire). `speed` is the negotiated rate in Mb/s; wifi has no usable
        // value there, so it reports 0 and the readout says "Wi-Fi".
        + "if [ \"$(cat \"$d/carrier\" 2>/dev/null)\" = 1 ]; then "
        + "  if [ -d \"$d/wireless\" ]; then k=wifi; else k=wired; fi; "
        + "  s=$(cat \"$d/speed\" 2>/dev/null | tr -dc 0-9); [ -n \"$s\" ] || s=0; "
        + "  if [ \"$ifn\" = - ] || { [ \"$knd\" = wifi ] && [ \"$k\" = wired ]; }; then "
        + "    ifn=$b; spd=$s; knd=$k; fi; "
        + "fi; "
        + "done; "
        // Wi-Fi has no usable `speed`, so carry SIGNAL instead: link quality
        // out of 70 from /proc/net/wireless. A file read, not an `iw` spawn.
        + "wq=$(awk 'NR>2{gsub(/\\./,\"\",$3); print $3; exit}' /proc/net/wireless 2>/dev/null); "
        + "[ -n \"$wq\" ] || wq=-1; "
        + "echo $n $up $ifn $spd $knd $wq"
    // Lines 6–7 only while Start / flyout SYSTEM is looking.
    readonly property string _vitalsGpuFans: "; "
        + "if [ -d /proc/driver/nvidia ] && command -v nvidia-smi >/dev/null 2>&1; then "
        + "u=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -dc 0-9); "
        + "if [ -n \"$u\" ]; then echo nv $u; else echo none; fi; "
        + "else g=; "
        + "for p in /sys/class/drm/card*/device/gpu_busy_percent; do "
        + "[ -r \"$p\" ] && g=\"amd $(cat \"$p\")\" && break; done; "
        + "if [ -z \"$g\" ]; then for card in /sys/class/drm/card*; do "
        + "act=$card/gt/gt0/rps_act_freq_mhz; mx=$card/gt/gt0/rps_max_freq_mhz; "
        + "[ -r \"$act\" ] && [ -r \"$mx\" ] || continue; "
        + "a=$(cat \"$act\"); m=$(cat \"$mx\"); "
        + "[ \"$m\" -gt 0 ] 2>/dev/null && g=\"igpu $((a * 100 / m)) $a\" && break; "
        + "done; fi; echo ${g:-none}; fi; "
        + "max=0; n=0; for f in /sys/class/hwmon/hwmon*/fan*_input; do "
        + "[ -r \"$f\" ] || continue; n=$((n+1)); "
        + "v=$(cat \"$f\" 2>/dev/null || echo 0); "
        + "[ \"$v\" -gt \"$max\" ] 2>/dev/null && max=$v; done; echo $n $max"

    onVitalsActiveChanged: if (sys.vitalsActive) hwProbe.running = true

    Process {
        id: hwProbe
        running: true
        command: ["sh", "-c",
            "fans=0; for f in /sys/class/hwmon/hwmon*/fan*_input; do "
            + "[ -r \"$f\" ] && fans=1 && break; done; "
            + "gpu=0; [ -d /proc/driver/nvidia ] && gpu=1; "
            + "for p in /sys/class/drm/card*/device/gpu_busy_percent; do "
            + "[ -r \"$p\" ] && gpu=1; done; "
            + "for p in /sys/class/drm/card*/gt/gt0/rps_act_freq_mhz; do "
            + "[ -r \"$p\" ] && gpu=1; done; "
            + "for v in /sys/class/drm/card*/device/vendor; do "
            + "[ -r \"$v\" ] || continue; id=$(cat \"$v\"); "
            + "case \"$id\" in 0x10de|0x1002) gpu=1 ;; esac; done; "
            + "net=0; awk -F'[: ]+' '/:/ && $2 !~ /^(lo|veth|virbr|docker|br-)/ "
            + "{f=1} END{exit f?0:1}' /proc/net/dev && net=1; "
            + "temp=0; for f in /sys/class/hwmon/hwmon*/temp*_input; do "
            + "[ -r \"$f\" ] && temp=1 && break; done; "
            + "gpuclass=none; "
            + "[ -d /proc/driver/nvidia ] && gpuclass=nv; "
            + "if [ \"$gpuclass\" = none ]; then "
            + "  for p in /sys/class/drm/card*/device/gpu_busy_percent; do "
            + "    [ -r \"$p\" ] && gpuclass=amd && break; done; "
            + "fi; "
            + "if [ \"$gpuclass\" = none ]; then "
            + "  for p in /sys/class/drm/card*/gt/gt0/rps_act_freq_mhz; do "
            + "    [ -r \"$p\" ] && gpuclass=igpu && break; done; "
            + "fi; "
            + "echo $fans $gpu $net $temp $gpuclass"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = this.text.trim().split(" ");
                if (p.length < 3) return;
                sys.hasFans = p[0] === "1";
                sys.hasGpu = p[1] === "1";
                sys.hasNet = p[2] === "1";
                if (p.length > 3)
                    sys.hasTemp = p[3] === "1";
                if (p.length > 4 && p[4].length)
                    sys.gpuClass = p[4];
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: sys.vitalsActive
        triggeredOnStart: true
        onTriggered: vitalsProc.running = true
    }
    Timer {
        interval: 5000
        repeat: true
        running: sys.ambientVitals && !sys.vitalsActive
        triggeredOnStart: true
        onTriggered: vitalsProc.running = true
    }
    Process {
        id: vitalsProc
        command: ["sh", "-c",
            sys.vitalsActive ? (sys._vitalsCore + sys._vitalsGpuFans) : sys._vitalsCore]
        stdout: StdioCollector {
            onStreamFinished: {
                var L = this.text.trim().split("\n");
                if (L.length < 3) return;
                var c = L[0].split(" ");
                var busy = parseFloat(c[0]), total = parseFloat(c[1]);
                if (sys._prevTotal >= 0 && total > sys._prevTotal)
                    sys.cpuPercent = Math.max(0, Math.min(100, Math.round(
                        100 * (busy - sys._prevBusy) / (total - sys._prevTotal))));
                sys._prevBusy = busy;
                sys._prevTotal = total;

                var m = L[1].split(" ");
                var tot = parseFloat(m[0]) / 1048576.0;     // kB → GiB
                var avail = parseFloat(m[1]) / 1048576.0;
                if (tot > 0) {
                    sys.memPercent = Math.round(100 * (tot - avail) / tot);
                    sys.memText = (tot - avail).toFixed(1) + " / " + tot.toFixed(1) + " GB";
                }

                var up = parseInt(L[2]);
                var d = Math.floor(up / 86400), h = Math.floor((up % 86400) / 3600), mi = Math.floor((up % 3600) / 60);
                sys.uptimeText = d > 0 ? (d + "d " + h + "h") : (h > 0 ? (h + "h " + mi + "m") : (mi + "m"));

                // ── disk (WIP-334) ──────────────────────────────────────
                if (L.length > 3) {
                    var dk = L[3].split(" ");
                    var used = parseFloat(dk[0]), cap = parseFloat(dk[1]);
                    if (cap > 0) {
                        sys.diskPercent = Math.max(0, Math.min(100,
                            Math.round(100 * used / cap)));
                        sys.diskText = (used / 1048576).toFixed(0) + " / "
                                     + (cap / 1048576).toFixed(0) + " GB";
                    }
                }

                // ── network (WIP-334) ───────────────────────────────────
                // Rate from the byte delta over real elapsed time — NOT the
                // timer interval, which is 2 s or 5 s depending on whether a
                // vitals surface is open, and drifts under load either way.
                if (L.length > 4) {
                    var bytes = parseFloat(L[4]);
                    var now = Date.now();
                    if (sys._prevNetBytes >= 0 && now > sys._prevNetAt) {
                        var secs = (now - sys._prevNetAt) / 1000;
                        var rate = Math.max(0, (bytes - sys._prevNetBytes) / secs);

                        // Decay the peak ~4%/sample so one big transfer does
                        // not flatten the ring for the rest of the session,
                        // then let this sample raise it.
                        sys._netPeak = Math.max(262144, sys._netPeak * 0.96, rate);
                        sys.netPercent = Math.max(0, Math.min(100,
                            Math.round(100 * rate / sys._netPeak)));

                        sys.netText = rate >= 1048576
                            ? (rate / 1048576).toFixed(1) + " MB/s"
                            : (rate >= 1024 ? Math.round(rate / 1024) + " KB/s"
                                            : Math.round(rate) + " B/s");
                    }
                    sys._prevNetBytes = bytes;
                    sys._prevNetAt = now;
                }

                // Line 6: hottest hwmon temp, millidegrees. Always on the
                // core pass (sysfs, no nvidia-smi). 35–95 °C maps the bar.
                if (L.length > 5) {
                    var milli = parseInt(L[5].trim(), 10);
                    if (!isNaN(milli) && milli >= 15000) {
                        sys.hasTemp = true;
                        sys.tempC = Math.round(milli / 1000);
                        sys.tempPercent = Math.max(0, Math.min(100,
                            Math.round(100 * (sys.tempC - 35) / 60)));
                        sys.tempText = sys.tempC + "°";
                    } else {
                        sys.tempC = 0;
                        sys.tempPercent = 0;
                        sys.tempText = "—";
                    }
                }

                // Line 7: non-loopback ifaces / how many are operstate=up.
                if (L.length > 6) {
                    var ni = L[6].trim().split(" ");
                    var nIf = parseInt(ni[0], 10);
                    var nUp = parseInt(ni[1], 10);
                    if (!isNaN(nIf)) {
                        sys.netIfaces = nIf;
                        sys.netUp = isNaN(nUp) ? 0 : nUp;
                        if (nIf > 0)
                            sys.hasNet = true;
                        // ni[2..4] = iface, negotiated Mb/s, wired|wifi.
                        if (ni.length > 4 && ni[2] !== "-") {
                            sys.netIface = ni[2];
                            var sp = parseInt(ni[3], 10);
                            sys.netLinkMbps = isNaN(sp) ? 0 : sp;
                            sys.netKind = ni[4];
                            var wq = ni.length > 5 ? parseInt(ni[5], 10) : -1;
                            sys.netWifiQual = isNaN(wq) ? -1 : wq;
                        } else {
                            sys.netIface = "";
                            sys.netLinkMbps = 0;
                            sys.netKind = "";
                        }
                    }
                }

                sys.histCpu = sys._pushHist(sys.histCpu, sys.cpuPercent);
                sys.histMem = sys._pushHist(sys.histMem, sys.memPercent);
                sys.histDisk = sys._pushHist(sys.histDisk, sys.diskPercent);
                if (sys.hasTemp && sys.tempC > 0)
                    sys.histTemp = sys._pushHist(sys.histTemp, sys.tempC);
                sys.histNet = sys._pushHist(sys.histNet, sys.netPercent);
                sys._maybeHealthToast();

                // Line 8: GPU util. nv / amd / igpu / none.
                // Presence is hwProbe; a missing number is "—", not a hidden
                // row and not a fake 0%.
                if (L.length > 7) {
                    var g = L[7].trim().split(" ");
                    if (g[0] === "none" || g.length < 2) {
                        sys.gpuPercent = 0;
                        sys.gpuText = "—";
                    } else {
                        var gp = parseInt(g[1], 10);
                        if (isNaN(gp)) {
                            sys.gpuPercent = 0;
                            sys.gpuText = "—";
                        } else {
                            sys.gpuPercent = Math.max(0, Math.min(100, gp));
                            sys.gpuText = (g[0] === "igpu" && g.length > 2)
                                ? (g[2] + " MHz")
                                : (sys.gpuPercent + "%");
                        }
                    }
                }

                // Line 8: fan count + max RPM among readable nodes.
                if (L.length > 8) {
                    var fn = L[8].trim().split(" ");
                    var nFans = parseInt(fn[0], 10);
                    var rpm = parseInt(fn[1], 10);
                    if (!isNaN(nFans) && nFans > 0 && !isNaN(rpm)) {
                        sys._fanPeak = Math.max(2000, sys._fanPeak * 0.96, rpm);
                        sys.fanPercent = rpm <= 0 ? 0 : Math.max(0, Math.min(100,
                            Math.round(100 * rpm / sys._fanPeak)));
                        sys.fanText = rpm + " rpm";
                    }
                }
            }
        }
    }

    // ── Wi-Fi ────────────────────────────────────────────────────────────
    readonly property bool wifiOn: Networking.wifiEnabled
    // Whether this machine has a Wi-Fi radio at all. A desktop on Ethernet
    // should not be shown an empty network list.
    readonly property bool hasWifi: sys._wifiDevices.length > 0
    function toggleWifi() { Networking.wifiEnabled = !Networking.wifiEnabled; }
    function wifiScan() {
        if (!Networking.wifiEnabled)
            return;
        wifiScanProc.running = false;
        wifiScanProc.running = true;
    }
    Process {
        id: wifiScanProc
        running: false
        command: ["nmcli", "device", "wifi", "rescan"]
    }
    // Name of the currently-connected network, or a plain On/Off. Recomputes
    // when the device set changes; good enough for a status sub-label.
    // ⚠ Wi-Fi DEVICES ONLY. `Networking.devices` includes the wired
    // interface, and the first "connected network" on this machine is the
    // Ethernet port — so the Wi-Fi tile proudly reported `enp47s0` as the
    // network you were on. Filtering by device type is the fix.
    readonly property var _wifiDevices: {
        var out = [];
        var devs = Networking.devices ? Networking.devices.values : [];
        for (var i = 0; i < devs.length; i++)
            if (devs[i] && devs[i].type === DeviceType.Wifi)
                out.push(devs[i]);
        return out;
    }
    readonly property string wifiName: {
        if (!Networking.wifiEnabled) return "Off";
        var devs = sys._wifiDevices;
        for (var i = 0; i < devs.length; i++) {
            var nets = devs[i].networks ? devs[i].networks.values : [];
            for (var j = 0; j < nets.length; j++)
                if (nets[j] && nets[j].connected) return nets[j].name;
        }
        return "On";
    }

    // ── Bluetooth ────────────────────────────────────────────────────────
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter !== null && btAdapter.enabled
    function toggleBt() { if (btAdapter) btAdapter.enabled = !btAdapter.enabled; }

    // WIP-101. The shell knew whether the radio was ON and nothing else, so
    // "manage Bluetooth" could only mean launching blueman-manager — a stock
    // GTK window with an Adapter/Device/View/Help menubar, which the owner
    // photographed and correctly called default. A toggle is not a Bluetooth
    // UI; the question a person actually has is "which of my things is
    // connected, and can I connect this one".
    //
    // Defensive on purpose: this reads an external API surface, and a missing
    // adapter or an older Quickshell that names these differently must degrade
    // to an empty list rather than throw inside a property binding, which in
    // QML takes the whole panel down with it.
    readonly property var btDevices: {
        var out = [];
        var a = sys.btAdapter;
        if (!a || !a.enabled) return out;
        var list = a.devices ? (a.devices.values || a.devices) : null;
        if (!list || !list.length) return out;
        for (var i = 0; i < list.length; i++) {
            var d = list[i];
            if (!d) continue;
            // Unnamed devices are beacons, car kits advertising in passing and
            // other people's headphones. A picker that lists them is noise.
            if (!sys.btLabel(d)) continue;
            out.push(d);
        }
        // Connected first, then paired-but-not-connected, then the rest —
        // which is the order of how likely you are to want to touch it.
        out.sort(function (x, y) {
            var rx = (x.connected ? 0 : (x.paired ? 1 : 2));
            var ry = (y.connected ? 0 : (y.paired ? 1 : 2));
            if (rx !== ry) return rx - ry;
            return String(sys.btLabel(x)).localeCompare(String(sys.btLabel(y)));
        });
        return out.slice(0, 24);
    }

    function btLabel(d) {
        if (!d) return "";
        // `alias` is what the user renamed it to and wins if present.
        //
        // ⚠ BUT BLUEZ'S `Alias` FALLS BACK TO THE ADDRESS when a device has
        // no name -- the MAC with its colons turned into dashes. So `alias`
        // is NEVER empty, and the unnamed-device filter in `btDevices` above
        // (`if (!sys.btLabel(d)) continue;`) dropped nothing at all. Every
        // BLE beacon in range listed itself as a row of hex, which is exactly
        // what the owner saw: "its just number though".
        //
        // Recognising that fallback is what makes the existing filter work.
        var alias = d.alias ? String(d.alias) : "";
        // ⚠ MATCH THE SHAPE, NOT THE ADDRESS PROPERTY. The first cut compared
        // `alias` against `d.address` with the colons swapped for dashes, and
        // it did not filter anything -- the rows of hex were still there in
        // the render. `d.address` is not reliably exposed on the device object
        // here, so the comparison silently never ran. A label that IS a MAC is
        // recognisable on its own, in either separator, without depending on a
        // second property being present.
        if (/^([0-9A-F]{2}[-:]){5}[0-9A-F]{2}$/i.test(alias))
            alias = "";
        var nm = d.name ? String(d.name) : "";
        if (/^([0-9A-F]{2}[-:]){5}[0-9A-F]{2}$/i.test(nm))
            nm = "";
        return alias || nm || d.deviceName || "";
    }

    // Start or stop discovery on the default adapter. Named here rather than
    // written out at each call site because the property differs by
    // Quickshell version (`discovering` on current, `discovery` on older),
    // and every caller getting that wrong independently is how this ends up
    // silently not scanning again.
    function btSetScanning(v) {
        var a = sys.btAdapter;
        if (!a || !a.enabled) return false;
        if (a.discovering !== undefined) { a.discovering = v; return true; }
        if (a.discovery !== undefined) { a.discovery = v; return true; }
        return false;
    }

    function btState(d) {
        if (!d) return "";
        if (d.connected) return "Connected";
        if (d.paired)    return "Paired";
        return "Available";
    }

    // One entry point, so the UI never has to decide between pair and connect.
    function btActivate(d) {
        if (!d) return;
        if (d.connected) { if (d.disconnect) d.disconnect(); return; }
        if (!d.paired && d.pair) { d.pair(); return; }
        if (d.connect) d.connect();
    }

    // GAP-932 — headphones / headsets / speakers the volume flyout can
    // connect in one tap. BlueZ Icon is audio-* for A2DP sinks; the name
    // fallback catches buds that advertise as a phone. Not every BT
    // device — a mouse in the volume list is noise.
    function btIsAudio(d) {
        if (!d) return false;
        var ic = String(d.icon || "").toLowerCase();
        if (ic.indexOf("audio") >= 0 || ic.indexOf("headset") >= 0
                || ic.indexOf("headphone") >= 0 || ic.indexOf("speaker") >= 0)
            return true;
        var n = String(sys.btLabel(d)).toLowerCase();
        return n.indexOf("head") >= 0 || n.indexOf("airpod") >= 0
            || n.indexOf("buds") >= 0 || n.indexOf("ear") >= 0
            || n.indexOf("speaker") >= 0 || n.indexOf("headset") >= 0;
    }
    readonly property var btAudioDevices: {
        var all = sys.btDevices;
        var out = [];
        for (var i = 0; i < all.length; i++) {
            if (sys.btIsAudio(all[i]))
                out.push(all[i]);
        }
        return out;
    }

    // ── media (the playing MPRIS player, else the first with a track) ──
    // `[0]` was wrong the moment two sources were registered: a leftover
    // Nyxus Media instance stole the overlay from YouTube Music. Prefer
    // whoever is actually Playing and has a title.
    readonly property var player: {
        const vals = (Mpris.players && Mpris.players.values) ? Mpris.players.values : [];
        const n = vals.length;
        let fallback = null;
        for (let i = 0; i < n; i++) {
            const p = vals[i];
            if (!p)
                continue;
            const title = p.trackTitle || "";
            if (title.length === 0)
                continue;
            if (p.isPlaying === true)
                return p;
            if (fallback === null)
                fallback = p;
        }
        return fallback;
    }
    readonly property bool hasPlayer: player !== null
    readonly property string playerIdentity: {
        if (!player)
            return "";
        return player.identity || player.desktopEntry || "";
    }

    // ── media, derived (Agent AE · BRIEF_AGENT_AE_2026-08-12, the Meridian
    // flips to a music dial) ───────────────────────────────────────────────
    // `hasPlayer` alone answers "does a player exist", which is not the same
    // question as "is there something to show" — a player can be REGISTERED
    // (an app is open) with nothing queued, and the state table's row 1
    // ("no player, OR NO TRACK LOADED") needs that distinguished. This file
    // is the build's single system-facts surface (see the header comment),
    // so the distinction lives here once rather than being re-derived at
    // every call site the way Widgets.qml / SidePanel.qml / LockMedia.qml
    // each independently re-read Sys.player.trackTitle today.
    readonly property string playerTitle: player ? (player.trackTitle || "") : ""
    readonly property string playerArtist: player ? (player.trackArtist || "") : ""
    // The dial-eligibility test. Gated on a LOADED TRACK, not on playback —
    // see playerPlaying below for why those are two different questions.
    readonly property bool playerHasTrack: hasPlayer && playerTitle.length > 0

    // ⚠ Supervisor ruling, 2026-08-12: gate visibility/existence on
    // `playerHasTrack` (a player with a track), never on `playerPlaying`. If
    // the owner pauses, the dial must STAY so he can hit play from the bar —
    // "paused" is not "gone". `playerPlaying` exists only for glyph choice
    // (which icon a play/pause control shows), never for a running/visible
    // condition. Keeping both names distinct, rather than one ambiguous
    // `isPlaying`-shaped bool, is what makes that misuse grep-able.
    readonly property bool playerPlaying: hasPlayer && player.isPlaying === true
    readonly property bool playerCanGoNext: hasPlayer && player.canGoNext === true
    readonly property bool playerCanGoPrevious: hasPlayer && player.canGoPrevious === true

    function playerPrevious() { if (hasPlayer && player.canGoPrevious) player.previous(); }
    function playerNext() { if (hasPlayer && player.canGoNext) player.next(); }
    function playerTogglePlaying() { if (hasPlayer) player.togglePlaying(); }

    // ── the account picture (WIP-640(d)) ─────────────────────────────────
    // Three surfaces draw ~/.face — both Launcher styles and SidePanel's
    // header — and each one used to point an Image straight at the path.
    // A fresh install and the live user have no such file, so every shell
    // start logged two "Cannot open: file:///home/<user>/.face" warnings
    // before falling back to the initial-on-the-sweep disc.
    //
    // Shipping a stock avatar in skel was the other way out and is the wrong
    // one: the initial IS the identity until the user picks a photo (Lock.qml
    // says so in its own words, and BR's Accounts page photographs the honest
    // initial hero), so a generic face for everybody would be a downgrade to
    // silence a log line. So the surfaces ASK FIRST instead.
    //
    // Not a poll: one `test -f` at startup, and `refreshFace()` for the
    // moment a surface is about to show one — which is also what keeps the
    // "a picture changed in Settings shows next open" contract those Images'
    // `cache: false` was written for.
    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string facePath: sys.homeDir.length > 0 ? sys.homeDir + "/.face" : ""
    property bool hasFace: false
    function refreshFace() { if (sys.facePath.length > 0) faceProbe.running = true; }
    Process {
        id: faceProbe
        running: true
        command: ["test", "-f", sys.facePath]
        onExited: function (exitCode, exitStatus) {
            sys.hasFace = (exitCode === 0);
        }
    }
}
