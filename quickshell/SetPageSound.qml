pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ System ▸ Sound.   MODULE 5.
//
// PipeWire through Quickshell.Services.Pipewire. Nodes classified by
// media.class. PwObjectTracker is required or volume reads 0.
//
// Output / input / application instruments, not a labelled spreadsheet.
// Magma stays off (nothing here destroys).
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    property var entry: null

    title: qsTr("Sound")
    blurb: qsTr("Output, input, per-application volume. Tap a stone for the default — no terminal.")

    // TRK-3435 — shipped-first PATH through `env`, so argv never crosses a
    // shell. Same form as Bar.qml's zone menu; HardwareCaps.qml carries the
    // ruling.
    readonly property string execPath: "PATH="
        + (Quickshell.env("NYXUS_BIN_DIR") || "/usr/local/bin")
        + ":" + Quickshell.env("PATH")

    function _class(n) {
        if (!n || !n.properties)
            return "";
        var c = n.properties["media.class"];
        return c === undefined ? "" : String(c);
    }

    function _label(n) {
        if (!n)
            return "";
        var p = n.properties || {};
        var app = p["application.name"] || p["node.nick"];
        if (app)
            return String(app);
        return String(n.description || n.nickname || n.name || "Audio");
    }

    function _nodeKey(n) {
        if (!n)
            return "";
        var p = n.properties || {};
        return String(n.name || p["node.name"] || n.id || page._label(n));
    }

    function _detail(n) {
        var p = (n && n.properties) || {};
        var m = p["media.name"];
        if (!m)
            return "";
        var s = String(m);
        var low = s.toLowerCase();
        if (low === "playback" || low === "capture" || low === "audio stream"
                || low === page._label(n).toLowerCase())
            return "";
        return s;
    }

    readonly property var _all: Pipewire.nodes ? Pipewire.nodes.values : []

    function _filter(cls) {
        var out = [];
        for (var i = 0; i < page._all.length; ++i) {
            var n = page._all[i];
            if (!n || !n.audio)
                continue;
            if (page._class(n) === cls)
                out.push(n);
        }
        return out;
    }

    readonly property var sinks:   page._filter("Audio/Sink")
    readonly property var sources: page._filter("Audio/Source")
    readonly property var playing: page._filter("Stream/Output/Audio")
    readonly property var recording: page._filter("Stream/Input/Audio")

    readonly property var defaultSink: Pipewire.defaultAudioSink
    readonly property var defaultSource: Pipewire.defaultAudioSource

    PwObjectTracker {
        objects: Pipewire.nodes ? Pipewire.nodes.values : []
    }

    function _pct(v) { return Math.round(v * 100) + "%"; }
    function _pctN(n) {
        if (!n || !n.audio)
            return 0;
        return Math.round(n.audio.volume * 100);
    }
    function _fill(n) { return Math.min(100, page._pctN(n)); }

    // Unique devices, same collapse as the bar picker. Returns nodes so a
    // tap can write preferredDefaultAudioSink directly.
    function _deviceFaces(list, current) {
        var sorted = list.slice().sort(function (a, b) {
            if ((a === current) !== (b === current))
                return a === current ? -1 : 1;
            return 0;
        });
        var seen = {};
        var out = [];
        for (var i = 0; i < sorted.length; ++i) {
            var n = sorted[i];
            var label = page._label(n);
            if (label === "" || seen[label])
                continue;
            seen[label] = true;
            out.push(n);
        }
        return out;
    }

    readonly property var sinkFaces: page._deviceFaces(page.sinks, page.defaultSink)
    readonly property var sourceFaces: page._deviceFaces(page.sources, page.defaultSource)

    LiveMark { id: sinkMark; visible: false; actual: page._nodeKey(page.defaultSink) }
    LiveMark { id: sourceMark; visible: false; actual: page._nodeKey(page.defaultSource) }
    LiveMark { id: muteMark; visible: false; actual: Sys.muted }
    LiveMark { id: tapeMark; visible: false; actual: TapeState.armed }

    SetCard {
        heading: qsTr("Output")
        tone: page.tone
        note: page.sinks.length === 0
              ? "PipeWire is reporting no output devices at all. That is a "
                + "service problem rather than a settings one — check that "
                + "wireplumber is running."
              : "Tap a stone to make it the default output — no terminal. The lens is live volume."

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.s2
            visible: page.sinkFaces.length > 0

            Repeater {
                model: page.sinkFaces
                delegate: SetIceFace {
                    required property var modelData
                    Layout.fillWidth: true
                    compact: true
                    kicker: modelData === page.defaultSink ? "DEFAULT" : qsTr("OUTPUT")
                    reading: modelData.audio ? (page._pctN(modelData) + "%") : ""
                    caption: page._label(modelData)
                    selected: modelData === page.defaultSink
                    interactive: true
                    attention: (sinkMark.pending || sinkMark.failed)
                               && sinkMark.want === page._nodeKey(modelData)
                    onActivated: {
                        sinkMark.request(page._nodeKey(modelData));
                        Pipewire.preferredDefaultAudioSink = modelData;
                        DiagnosticBus.append("wpctl: default sink " + page._label(modelData));
                    }
                }
            }
        }

        SetIceFace {
            visible: page.sinks.length === 0
            compact: true
            kicker: qsTr("OUTPUT")
            caption: qsTr("No output device found")
        }

        SetIceFace {
            visible: Sys.playbackSink !== null && Sys.playbackSink.audio !== null
            kicker: qsTr("VOLUME")
            reading: page._pct(Sys.volume)
            caption: Sys.playbackSink ? page._label(Sys.playbackSink) : ""
            detail: Sys.muted
                    ? "Muted" : "To 150% — quiet laptop speakers on a loud video"
            fillPct: page._fill(Sys.playbackSink)
            selected: Sys.muted
        }

        SetSlider {
            visible: Sys.playbackSink !== null && Sys.playbackSink.audio !== null
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            tone: page.tone
            logAs: "sound_output_volume"
            from: 0; to: 1.5; snap: 0.01
            value: Sys.volume
            format: function (v) { return Math.round(v * 100) + "%"; }
            onMoved: function (v) { Sys.setVolume(v); }
        }

        SetIceFace {
            visible: page.defaultSink !== null && page.defaultSink.audio !== null
            compact: true
            kicker: qsTr("MUTE")
            caption: Sys.muted ? qsTr("Silent") : qsTr("Open")
            selected: Sys.muted
            interactive: true
            attention: muteMark.pending || muteMark.failed
            onActivated: {
                muteMark.request(!Sys.muted);
                Sys.toggleMute();
                DiagnosticBus.logSwitch("mute", !Sys.muted);
            }
        }
    }

    SetCard {
        heading: qsTr("Interface sounds")
        tone: page.tone
        note: qsTr("Clicks, notifications, battery, and USB from the shell. ")
              + "This fader does not move YouTube or the output device."

        SetRow {
            glyph: ""
            title: qsTr("System UI sounds")
            sub: qsTr("On plays the build's glass events. Off is silent in the shell.")
            SetSwitch { key: "ui_sounds"; defaultValue: true; tone: page.tone }
        }

        SetRow {
            glyph: ""
            title: qsTr("UI volume")
            sub: qsTr("Separate from media. Default 40%.")
            available: SettingsStore.boolValue("ui_sounds", true)
            unavailableReason: qsTr("Interface sounds are off")
            SetSlider {
                key: "ui_sound_volume"
                defaultValue: 0.40
                width: 250
                tone: page.tone
                from: 0; to: 1; snap: 0.05
                format: function (v) { return Math.round(v * 100) + "%"; }
            }
        }

        SetRow {
            glyph: ""
            title: qsTr("Press")
            sub: qsTr("Soft click when a control takes the press")
            available: SettingsStore.boolValue("ui_sounds", true)
            unavailableReason: qsTr("Interface sounds are off")
            SetSwitch { key: "ui_sound_press"; defaultValue: true; tone: page.tone }
        }

        SetRow {
            glyph: ""
            title: qsTr("Notify")
            sub: qsTr("Toast and message chime")
            available: SettingsStore.boolValue("ui_sounds", true)
            unavailableReason: qsTr("Interface sounds are off")
            SetSwitch { key: "ui_sound_notify"; defaultValue: true; tone: page.tone }
        }

        SetRow {
            glyph: ""
            title: qsTr("Knock")
            sub: qsTr("Bump when something hits a screen edge")
            available: SettingsStore.boolValue("ui_sounds", true)
            unavailableReason: qsTr("Interface sounds are off")
            SetSwitch { key: "ui_sound_knock"; defaultValue: true; tone: page.tone }
        }

        SetRow {
            glyph: ""
            title: qsTr("Lock")
            sub: qsTr("Lock and unlock from the shell. Session bind still chimes.")
            available: SettingsStore.boolValue("ui_sounds", true)
            unavailableReason: qsTr("Interface sounds are off")
            SetSwitch { key: "ui_sound_lock"; defaultValue: true; tone: page.tone }
        }
    }

    SetCard {
        heading: qsTr("Applications")
        tone: page.tone
        note: qsTr("Each application keeps its own level. PipeWire remembers it, so ")
              + "turning one down here stays turned down the next time it runs."

        SetIceFace {
            visible: page.playing.length === 0
            compact: true
            kicker: qsTr("PLAYING")
            caption: qsTr("Nothing is playing")
            detail: qsTr("Applications appear here while they make sound.")
        }

        Repeater {
            model: page.playing
            delegate: ColumnLayout {
                id: playCol
                required property var modelData
                Layout.fillWidth: true
                spacing: Theme.s2

                SetIceFace {
                    Layout.fillWidth: true
                    compact: true
                    kicker: playCol.modelData.audio && playCol.modelData.audio.muted
                            ? "MUTED" : "APP"
                    reading: page._pctN(playCol.modelData) + "%"
                    caption: page._label(playCol.modelData)
                    detail: page._detail(playCol.modelData)
                    fillPct: page._fill(playCol.modelData)
                    selected: !!(playCol.modelData.audio && playCol.modelData.audio.muted)
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.s4
                    Layout.rightMargin: Theme.s4
                    spacing: Theme.s3

                    SetSlider {
                        Layout.fillWidth: true
                        tone: page.tone
                        from: 0; to: 1; snap: 0.01
                        value: playCol.modelData.audio
                               ? playCol.modelData.audio.volume : 0
                        format: function (v) { return Math.round(v * 100) + "%"; }
                        onMoved: function (v) {
                            if (playCol.modelData.audio)
                                playCol.modelData.audio.volume = v;
                        }
                    }

                    SetSwitch {
                        tone: page.tone
                        checked: playCol.modelData.audio
                                 ? playCol.modelData.audio.muted : false
                        onToggled: function (v) {
                            if (playCol.modelData.audio)
                                playCol.modelData.audio.muted = v;
                        }
                    }
                }
            }
        }
    }

    SetCard {
        heading: qsTr("Input")
        tone: page.tone
        note: qsTr("Every microphone, not only the default — the one you are not using is the one that is hissing.")

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.s2
            visible: page.sourceFaces.length > 0

            Repeater {
                model: page.sourceFaces
                delegate: SetIceFace {
                    required property var modelData
                    Layout.fillWidth: true
                    compact: true
                    kicker: modelData === page.defaultSource ? "DEFAULT" : qsTr("MIC")
                    reading: modelData.audio ? (page._pctN(modelData) + "%") : ""
                    caption: page._label(modelData)
                    selected: modelData === page.defaultSource
                    interactive: true
                    attention: (sourceMark.pending || sourceMark.failed)
                               && sourceMark.want === page._nodeKey(modelData)
                    onActivated: {
                        sourceMark.request(page._nodeKey(modelData));
                        Pipewire.preferredDefaultAudioSource = modelData;
                        DiagnosticBus.append("wpctl: default source " + page._label(modelData));
                    }
                }
            }
        }

        Repeater {
            model: page.sources
            delegate: ColumnLayout {
                id: srcCol
                required property var modelData
                Layout.fillWidth: true
                spacing: Theme.s2

                SetIceFace {
                    Layout.fillWidth: true
                    compact: true
                    kicker: srcCol.modelData === page.defaultSource ? qsTr("DEFAULT MIC") : qsTr("MIC")
                    reading: page._pctN(srcCol.modelData) + "%"
                    caption: page._label(srcCol.modelData)
                    detail: (srcCol.modelData.audio && srcCol.modelData.audio.muted)
                            ? "Muted" : ""
                    fillPct: page._fill(srcCol.modelData)
                    selected: srcCol.modelData === page.defaultSource
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.s4
                    Layout.rightMargin: Theme.s4
                    spacing: Theme.s3

                    SetSlider {
                        Layout.fillWidth: true
                        tone: page.tone
                        from: 0; to: 1.5; snap: 0.01
                        value: srcCol.modelData.audio
                               ? srcCol.modelData.audio.volume : 0
                        format: function (v) { return Math.round(v * 100) + "%"; }
                        onMoved: function (v) {
                            if (srcCol.modelData.audio)
                                srcCol.modelData.audio.volume = v;
                        }
                    }

                    SetSwitch {
                        tone: page.tone
                        checked: srcCol.modelData.audio
                                 ? srcCol.modelData.audio.muted : false
                        onToggled: function (v) {
                            if (srcCol.modelData.audio)
                                srcCol.modelData.audio.muted = v;
                        }
                    }
                }
            }
        }

        SetIceFace {
            visible: page.sources.length === 0
            compact: true
            kicker: qsTr("MIC")
            caption: qsTr("No microphone or line-in found")
        }

        SetIceFace {
            visible: page.recording.length > 0
            compact: true
            kicker: qsTr("LISTENING")
            reading: String(page.recording.length)
            caption: page.recording.length === 1
                     ? "1 application is listening"
                     : page.recording.length + " applications are listening"
            detail: {
                var names = [];
                for (var i = 0; i < page.recording.length; ++i)
                    names.push(page._label(page.recording[i]));
                return names.join(", ");
            }
        }
    }

    // ══ TRK-3821 · THE TAPE ═══════════════════════════════════════════════
    // The bar's now-playing zone menu arms it too; this is the SAME state and
    // the SAME command, not a second copy of it. Both surfaces READ
    // ~/.config/nyxus/tape.json (TapeState.qml) and both surfaces WRITE by
    // spawning `nyxus-tape --toggle`, whose daemon is the file's single
    // writer. One state, one writer, two surfaces, and no way to disagree.
    //
    // ⚠ The switch is in DRIVEN mode (no `key:`), bound to TapeState.armed —
    // a fact the daemon publishes, re-derived against its recorded pid. So a
    // daemon killed by a reboot or an OOM cannot leave this showing ON, and
    // per SetSwitch's TRK-3462 contract we act in onToggled and let the bound
    // visual follow the real state. It does not move when arming failed.
    SetCard {
        heading: qsTr("Keep the songs I play")
        tone: page.tone
        note: qsTr("Turn this on and every song that plays through from its start is kept into "
                 + "your own library — the sound, the artist, the title, the album, the cover "
                 + "and the synced words, as files you own and can play with the power off. It "
                 + "records this machine's own output, in real time: a four-minute song takes "
                 + "four minutes. Nothing runs at all while it is off.")

        SetRow {
            title: qsTr("Keep songs while they play")
            sub: TapeState.armed
                 ? (TapeState.waitingForNextTrack
                    ? qsTr("On — starts with the next song")
                    : qsTr("On — keeping: %1").arg(TapeState.taping))
                 : qsTr("Off — nothing is being recorded")
            available: page.tapeOk
            unavailableReason: qsTr("Needs parec, playerctl and ffmpeg on this machine.")

            SetSwitch {
                checked: TapeState.armed
                tone: page.tone
                enabled: page.tapeOk
                pending: tapeMark.pending
                failed: tapeMark.failed
                // ⚠ --toggle, never --arm/--disarm: the daemon decides which
                // way it goes from the state IT published, so a surface that
                // is momentarily stale cannot drive it into the wrong state.
                onToggled: function (v) {
                    tapeMark.request(v);
                    tapeToggle.running = true;
                }
            }
        }

        // ⚠ Arming mid-song deliberately does NOT keep that song — by the time
        // you press the button the song is half over, and a half-track is the
        // pile of fragments the button exists to prevent. The switch's own
        // `sub` above says so; a second row repeating it was one row too many.
        SetRow {
            title: qsTr("Kept so far")
            valueText: TapeState.kept > 0 ? String(TapeState.kept) : qsTr("None yet")
            sub: TapeState.last !== "" ? qsTr("Last: %1").arg(TapeState.last)
                                       : TapeState.keepsDir
            navigates: true
            onActivated: openKeeps.running = true
        }

        // ── the options. Ordinary settings, written by Settings, unlike the
        //    transient armed-ness above. TapeState.qml's header says why.
        SetRow {
            title: qsTr("Which sound to keep")
            sub: qsTr("Effects are a listening preference, not part of the song — and baking "
                    + "them in applies them a second time on playback.")

            SetChoice {
                key: "tape_source"
                defaultValue: "player"
                value: Prefs.tapeSource
                // ⚠ Must stay in step with Prefs.tapeSource's accepted list.
                options: [
                    { label: qsTr("The music only"),  value: "player" },
                    { label: qsTr("All of my audio"), value: "output" }
                ]
                tone: page.tone
                onChosen: function (v) { SettingsStore.setValue("tape_source", v); }
            }
        }

        SetRow {
            title: qsTr("File format")
            sub: qsTr("The stream is already compressed, so lossless buys no detail back — it "
                    + "avoids a second round of loss on a recording that happened once.")

            SetChoice {
                key: "tape_format"
                defaultValue: "flac"
                value: Prefs.tapeFormat
                options: [
                    { label: qsTr("Lossless (FLAC)"), value: "flac" },
                    { label: qsTr("Smaller (MP3)"),   value: "mp3" }
                ]
                tone: page.tone
                onChosen: function (v) { SettingsStore.setValue("tape_format", v); }
            }
        }

        // ⚠ THE ADVERT FLOOR, and it is honest about what it cannot do.
        // Nothing the player publishes separates a long advert from a short
        // song, so this length floor is the bound. Measured on this machine:
        // the adverts ran 15.0 s and 36.3 s.
        SetRow {
            title: qsTr("Ignore anything shorter than")
            sub: qsTr("Adverts are short. Anything under this is not treated as a song, so it "
                    + "never starts a recording of its own.")
            valueText: qsTr("%1 seconds").arg(Prefs.tapeMinSeconds)

            SetChoice {
                key: "tape_min_seconds"
                defaultValue: 60
                value: Prefs.tapeMinSeconds
                options: [
                    { label: qsTr("45s"), value: 45 },
                    { label: qsTr("60s"), value: 60 },
                    { label: qsTr("90s"), value: 90 }
                ]
                tone: page.tone
                onChosen: function (v) { SettingsStore.setValue("tape_min_seconds", v); }
            }
        }

        SetRow {
            title: qsTr("Open my kept songs")
            sub: qsTr("They are in Media, under Kept — grouped by artist and album.")
            navigates: true
            onActivated: Bus.openMedia()
        }
    }

    SetCard {
        heading: qsTr("System sounds")
        tone: page.tone
        note: qsTr("Interface sounds above are the live pack. This leftover is saved, not applied, and there is no Sound Pack page under Personalization.")

        SetRow {
            title: qsTr("GTK sound pack")
            available: false
            unavailableReason: qsTr("Not wired. Interface sounds above are the live pack.")
        }

        SetButton {
            Layout.leftMargin: Theme.s4
            text: qsTr("Play a test tone")
            glyph: ""
            tone: page.tone
            busy: testSound.running
            onClicked: testSound.running = true
        }
    }

    SetCard {
        heading: qsTr("Also on this machine")
        tone: page.tone
        note: qsTr("Wi-Fi, Bluetooth, displays, printers — the same Devices story.")

        SetRow {
            title: qsTr("Wi-Fi")
            sub: qsTr("Scan, join, forget")
            navigates: true
            onActivated: Bus.openSettings("network")
        }
        SetRow {
            title: qsTr("Bluetooth")
            navigates: true
            onActivated: Bus.openSettings("bluetooth")
        }
        SetRow {
            title: qsTr("Display")
            sub: qsTr("Monitors and Night Light")
            navigates: true
            onActivated: Bus.openSettings("display")
        }
        SetRow {
            title: qsTr("Printers & scanners")
            navigates: true
            onActivated: Bus.openSettings("printers")
        }
    }

    // ══ TRK-3821 · the tape's plumbing ════════════════════════════════════
    // ⚠ NOT A DEAD ROW. `tapeOk` is probed from the tool itself rather than
    // assumed, so if an image ever ships without parec/playerctl/ffmpeg the
    // switch is disabled WITH A REASON instead of silently doing nothing.
    property bool tapeOk: true

    Process {
        id: tapeProbe
        running: true
        command: ["env", page.execPath, "nyxus-tape", "--probe"]   // TRK-3435
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var d = JSON.parse(String(this.text));
                    page.tapeOk = d.ok === true;
                } catch (e) {
                    // A tool that is not there at all cannot answer. Treat an
                    // unparseable probe as "cannot", never as "fine".
                    page.tapeOk = false;
                }
            }
        }
    }

    Process {
        id: tapeToggle
        running: false
        command: ["env", page.execPath, "nyxus-tape", "--toggle"]   // TRK-3435
        // Nothing to read back: the daemon republishes tape.json and
        // TapeState's FileView drives every bound surface from that.
        onExited: function (code) {
            if (code !== 0)
                tapeMark.fail();
        }
    }

    Process {
        id: openKeeps
        running: false
        // ⚠ NO ARGUMENT. `nyxus_media.py`'s do_command_line treats every
        // argument as a PATH TO PLAY, so a `--kept` flag would be handed to
        // play_paths as a filename. The Media app is being rewritten by the
        // graffiti lane; when it grows a real flag for the kept collection
        // this is the one line that changes.
        command: ["env", page.execPath, "nyxus-media"]   // TRK-3435
    }

    Process {
        id: testSound
        running: false
        command: ["sh", "-c",
            'for f in /usr/share/sounds/nyxus/notification.ogg '
          + '/usr/share/sounds/nyxus/notification.wav '
          + '/usr/share/sounds/freedesktop/stereo/message.oga; do '
          + '[ -r "$f" ] && exec paplay "$f"; done; '
          + 'echo "no system sound file found" >&2; exit 1']
        stderr: StdioCollector {
            onStreamFinished: {
                if (String(this.text).trim() !== "")
                    console.warn("Sound: test tone — " + String(this.text).trim());
            }
        }
    }

    // ── audit-0908 · TRK-3968 ───────────────────────────────────────────
    // Nine keys written here and no way back short of the whole-file reset,
    // which also takes the GTK control center's settings with it. `keys` is
    // exactly what this page writes; gate 13r81 checks both directions.
    // Nothing here needs the `cleared` hook — every one of these is read
    // straight out of the store by whatever plays the sound or the tape, so
    // removing the key IS the reset.
    //
    // `ui_sound_notify` is also listed by Notifications, on purpose. Both
    // pages offer that switch, so both must be able to clear it: the gate
    // requires a page to list every key it writes, and a key genuinely
    // belonging to two surfaces is not a duplicate to pick a winner for.
    SetResetRow {
        what: qsTr("Sound")
        keys: ["ui_sounds", "ui_sound_volume", "ui_sound_press",
               "ui_sound_notify", "ui_sound_knock", "ui_sound_lock",
               "tape_source", "tape_format", "tape_min_seconds"]
    }
}
