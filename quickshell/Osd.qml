// Nyxus Suxyn — the OSD. Volume, mute, mic mute, brightness — on screen.
//
// ── B2-c 2026-08-17 · THIS SURFACE DID NOT EXIST ───────────────────────────
//
// The OSD is named in three places as something this build has: rev 3 §4.12
// ("Volume/brightness OSD uses the §4.6 meter, centered, auto-dismiss 1800ms"),
// §6's toolkit map ("Quickshell / QML | bar, flyouts, OSD, notifications"), and
// §1.1's surface table ("Bar, popup, flyout, notification, OSD"). It was in the
// build once — as eww — and `hyprland.conf` records exactly how it left:
//
//     "The four volume/mic binds were casualties of the eww excision: each
//      chained `&& ~/.config/eww/scripts/osd-show.sh …`, and the [suxyn] pass
//      commented the WHOLE bind instead of amputating the dead OSD tail — so on
//      the owner's first hardware boot the volume keys did nothing (2026-08-08
//      finding). Restored with the working half."
//
// "The working half" is the half that changes the volume. The half that TELLS
// YOU it changed was never rebuilt, so since 2026-08-03 the volume and
// brightness keys have moved the system silently — no meter, no number, no
// indication that the key did anything at all.
//
// ── WHY THIS NEEDS NO CONFIG EDIT (ISO downloaders get it) ────────────────
//
// The keys already call `wpctl` / `brightnessctl` (both packaged). Re-chaining
// them onto a show command would mean editing `hyprland.conf` (two copies, not
// this lane) and putting the OSD's correctness in a different file from the
// OSD. Not necessary:
//
//   · VOLUME / OUTPUT MUTE — `Sys.volume` / `Sys.muted` are live Pipewire
//     bindings. `wpctl` changes the node; this surface reads the node.
//   · MIC MUTE — `Pipewire.defaultAudioSource`, same live model, same bind
//     (`wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle`).
//   · BRIGHTNESS — sysfs does not reliably inotify. Events come from
//     `udevadm monitor --subsystem-match=backlight` (UsbWatch's shape: a
//     blocking stream, not a poll). Then one `nyxus-brightness get`
//     (TRK-1321: reads go through the same device the helper writes,
//     never a bare `brightnessctl get`/`max` against brightnessctl's own
//     first-found pick). No backlight (a desktop) → the monitor never
//     starts. `nyxus-brightness` and `udevadm` are on the ISO; nothing
//     extra to download.
//
// Owner 2026-08-19: keep the bar's short notification flash; do NOT add ten
// more bar flashes. This overlay is the volume/brightness/mic feedback, like
// Windows, centred. Bar.qml is BQ and is not opened.
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Io
import QtQuick

PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nyxus-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    implicitWidth: 260 + Theme.bloomPad * 2
    // TRK-2912: the window is the card plus its bloom, not a second fixed 64
    // that would keep the old box around a shorter pill. `card` is
    // `centerIn: parent` and never reads this back — see the width-only note
    // on `card.height`.
    implicitHeight: card.height + Theme.bloomPad * 2

    property bool shown: false
    // `message` is the pushed kind — everything else here is read from a live
    // model, so those three never need telling. See the header.
    property string kind: "volume"   // volume | brightness | mic | message
    property string msgGlyph: ""
    property string msgText: ""
    property real lastTickMs: 0

    readonly property color markOn: Theme.paintLayers.glacier[5]
    readonly property color markHot: Theme.paintLayers.magma[5]
    readonly property color iceSeam: Theme.paintLayers.glacier[4]

    visible: root.shown || fadeAnim.running
    mask: Region {
        item: root.shown ? card : null
    }

    // ── the way in ──────────────────────────────────────────────────────
    // `qs ipc call osd show "<glyph>" "<text>"`. Void, one line, no return —
    // the same shape every other IpcHandler in this shell uses, and the reason
    // Perf.qml gives for it (no timing hook to hang on) holds here too.
    IpcHandler {
        target: "osd"

        function show(glyph: string, text: string): void {
            root.msgGlyph = glyph || "";
            root.msgText = text || "";
            root.flash("message");
        }
    }

    property bool armed: false
    Timer {
        interval: Theme.durSettle
        running: true
        onTriggered: root.armed = true
    }

    Connections {
        target: Sys
        function onVolumeChanged() { root.flash("volume"); }
        function onMutedChanged()  { root.flash("volume"); }
    }

    function flash(k) {
        if (!root.armed)
            return;
        if (k)
            root.kind = k;
        root.shown = true;
        dismiss.restart();
        // Volume keys repeat. One tick per burst, not one per PipeWire
        // update — the sample is ~0.1 s and stacking it is a rattle.
        if (root.kind === "volume" || root.kind === "mic") {
            var now = Date.now();
            if (now - root.lastTickMs > 180) {
                root.lastTickMs = now;
                Sys.playSound("audio-volume-change");
            }
        }
    }

    Timer {
        id: dismiss
        interval: 1800
        onTriggered: root.shown = false
    }

    // ── mic (live Pipewire source, same as Sys.volume for the sink) ──
    readonly property var mic: Pipewire.defaultAudioSource
    readonly property bool micMuted: (root.mic && root.mic.audio)
                                     ? root.mic.audio.muted : false
    property bool micSeen: false
    PwObjectTracker { objects: root.mic ? [root.mic] : [] }
    onMicMutedChanged: {
        if (!root.micSeen) {
            root.micSeen = true;
            return;
        }
        root.flash("mic");
    }

    // ── brightness (udev events → one nyxus-brightness read; no poll) ──
    // TRK-1321: `probe`/`get` come from the ONE helper (TRK-980) so this
    // meter always names the same device the writer picks (the largest
    // -max backlight-class node), never brightnessctl's own first-found
    // pick via a bare `brightnessctl get`/`max`.
    property string backlight: ""
    property real bright: 0
    property bool brightKnown: false
    property bool blDirty: false

    Process {
        id: blFind
        running: true
        command: ["nyxus-brightness", "probe"]
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = this.text.trim().split(/\s+/);
                root.backlight = (parts.length > 0 && parts[0] !== "")
                    ? parts[0] : "";
            }
        }
    }

    Process {
        id: blMon
        running: root.backlight !== ""
        command: ["stdbuf", "-oL", "udevadm", "monitor", "--udev",
                  "--subsystem-match=backlight"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (line) {
                if (line.indexOf("backlight") < 0)
                    return;
                if (blRead.running)
                    root.blDirty = true;
                else
                    blRead.running = true;
            }
        }
    }

    Process {
        id: blRead
        running: false
        command: ["nyxus-brightness", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                var n = parseInt(this.text.trim());
                if (isNaN(n))
                    return;
                var v = Math.max(0, Math.min(1, n / 100));
                var known = root.brightKnown;
                var was = root.bright;
                root.bright = v;
                root.brightKnown = true;
                if (known && Math.abs(was - v) > 0.004)
                    root.flash("brightness");
            }
        }
        onExited: function (exitCode, exitStatus) {
            blRead.running = false;
            if (root.blDirty) {
                root.blDirty = false;
                blRead.running = true;
            }
        }
    }

    onBacklightChanged: if (root.backlight !== "")
                            blRead.running = true

    // A message has no quantity. The meter is hidden for it rather than
    // parked at zero, which would read as "off" instead of "not applicable".
    readonly property real meterValue: root.kind === "message"
        ? 0
        : root.kind === "brightness"
        ? root.bright
        : (root.kind === "mic"
           ? (root.micMuted ? 0 : 1)
           : (Sys.muted ? 0 : Math.max(0, Math.min(1, Sys.volume))))

    readonly property string glyphText: {
        if (root.kind === "message")
            return root.msgGlyph;
        if (root.kind === "brightness")
            return "";
        if (root.kind === "mic")
            return root.micMuted ? "" : "";
        return Sys.muted ? "" : (Sys.volume > 0.5 ? ""
                                : (Sys.volume > 0 ? "" : ""));
    }

    readonly property string readoutText: {
        if (root.kind === "message")
            return "";
        if (root.kind === "brightness")
            return Math.round(root.bright * 100) + "%";
        if (root.kind === "mic")
            return root.micMuted ? "OFF" : "ON";
        return Sys.muted ? "—" : Math.round(Sys.volume * 100) + "%";
    }

    readonly property string kindLabel: {
        if (root.kind === "message")
            return "";
        if (root.kind === "brightness")
            return qsTr("BRIGHTNESS");
        if (root.kind === "mic")
            return qsTr("MICROPHONE");
        return qsTr("VOLUME");
    }

    readonly property bool silenced: (root.kind === "volume" && Sys.muted)
                                  || (root.kind === "mic" && root.micMuted)
    readonly property string pipKind: root.kind === "message" ? "off"
                                    : (root.silenced ? "magma" : "ice")
    readonly property bool pipPulse: root.shown && root.silenced

    Item {
        id: card
        anchors.centerIn: parent
        // 260 is the meter layout's fixed width and stays exactly that for the
        // three metered kinds. A message is sized by its sentence instead, to
        // a ceiling it elides past. Text metrics only — never a term that
        // reads this item's own height.
        width: root.kind === "message"
               ? Math.max(260, Math.min(460, 22 + Theme.s5
                                             + msgLabel.implicitWidth
                                             + 2 * Theme.s6))
               : 260
        // Frame is padding: kicker + 6 px prize + 2 × s6. Glyph/kicker are
        // font line boxes; nothing here reads card.height back.
        height: (root.kind === "message"
                 ? Math.max(glyph.implicitHeight, msgLabel.implicitHeight)
                 : Math.max(glyph.implicitHeight, kindLab.implicitHeight + Theme.s2 + 6))
                + 2 * Theme.s6
        clip: true
        transformOrigin: Item.Center

        readonly property int rad: Theme.r3

        Rectangle {
            anchors.fill: parent
            radius: card.rad
            color: Theme.elevated
            antialiasing: true
        }
        Pane {
            anchors.fill: parent
            elevation: 2
            bloomAtRest: false
            fill: Theme.panelMid
            radius: card.rad
            focusLevel: root.shown ? 0.42 : 0.12
            live: root.shown && root.kind !== "message" ? 1 : 0

            Rectangle {
                anchors.fill: parent
                radius: card.rad
                gradient: Gradient {
                    GradientStop { position: 0.00; color: Theme.swellGroundTop }
                    GradientStop { position: 0.50; color: Theme.swellGroundMid }
                    GradientStop { position: 1.00; color: Theme.swellGroundFoot }
                }
            }
            GlassEdge {
                anchors.fill: parent
                radiusTL: card.rad
                radiusTR: card.rad
                radiusBR: card.rad
                radiusBL: card.rad
                edging: 0.35
                body: 0
                wash: 0
                glaze: 0
                bleed: 0
            }
            Rectangle {
                anchors.fill: parent
                radius: card.rad
                color: "transparent"
                border.width: 1
                border.color: Theme.soften(root.iceSeam, 0.55)
                antialiasing: true
            }
        }

        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.92
        Behavior on opacity {
            NumberAnimation {
                id: fadeAnim
                duration: Theme.durRise
                easing.type: Easing.OutQuint
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.durRise
                easing.type: Easing.OutQuint
            }
        }

        Item {
            anchors.fill: parent
            anchors.margins: Theme.s6

            Item {
                id: mark
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22

                Text {
                    id: glyph
                    anchors.fill: parent
                    text: root.glyphText
                    color: root.silenced ? root.markHot : Theme.text
                    font.family: Theme.fIcon
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                StatusPip {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: -1
                    kind: root.pipKind
                    pulse: root.pipPulse
                }
            }

            Text {
                id: msgLabel
                visible: root.kind === "message"
                anchors.left: mark.right
                anchors.leftMargin: Theme.s5
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.msgText
                color: Theme.text
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                elide: Text.ElideRight
                clip: true
                verticalAlignment: Text.AlignVCenter
            }

            Text {
                id: kindLab
                visible: root.kind !== "message"
                anchors.left: mark.right
                anchors.leftMargin: Theme.s5
                anchors.right: readout.left
                anchors.rightMargin: Theme.s3
                anchors.top: parent.top
                text: root.kindLabel
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tMicro
                font.weight: Theme.wStrong
                font.letterSpacing: Theme.trackMicro
                elide: Text.ElideRight
                clip: true
            }

            Text {
                id: readout
                visible: root.kind !== "message"
                anchors.right: parent.right
                anchors.top: parent.top
                width: 42
                text: root.readoutText
                color: root.silenced ? root.markHot : Theme.textMuted
                font.family: Theme.fNum
                font.pixelSize: Theme.tMicro
                font.features: ({ "tnum": 1 })
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                clip: true
            }

            Rectangle {
                id: track
                visible: root.kind !== "message"
                anchors.left: mark.right
                anchors.right: parent.right
                anchors.leftMargin: Theme.s5
                anchors.bottom: parent.bottom
                height: 6
                radius: 3
                color: Theme.soften(Theme.void_, 0.50)
                clip: true
                border.width: 1
                border.color: Theme.soften(root.iceSeam, 0.40)
                antialiasing: true

                Rectangle {
                    height: parent.height
                    width: parent.width * root.meterValue
                    radius: track.radius
                    color: root.markOn
                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.durBase
                            easing.type: Easing.OutQuint
                        }
                    }
                }
            }
        }
    }
}
