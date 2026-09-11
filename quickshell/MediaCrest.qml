pragma ComponentBehavior: Bound
// Nyxus Suxyn — the now-playing card ABOVE the bar.
//
// Owner 2026-08-20: this is the real mini-player for ANY MPRIS source
// (YouTube Music, Nyxus Media, a browser). The GTK Media app is a
// separate window and only appears when you launch it.
//
// Dock (chevron) hides this card. The Gauge Crest then shows the same
// NOW PLAYING line notifications already use on the right. Click that
// line to raise the card again. The clock stays the clock.
//
// ── 2026-08-22, TRK-2600: the card used to VANISH while audio played ─────
// It was gated on `Sys.playerHasTrack`, and `Sys.player` skips any player
// whose title is empty. Chromium registers its MPRIS name the moment a media
// session starts but fills `Metadata` from the page's MediaSession API, so a
// page that never sets one plays for as long as it likes with `Metadata =
// {}` — reproduced in `docs/proof/media-0822/method-mock-mpris.py`, where
// `playerctl -l` names the player and `playerctl status` says `Playing` while
// `playerctl metadata` fails outright. The card was therefore absent at
// exactly the moment the owner most wanted a pause button.
//
// The gate is now `MediaSource.present` — a track to NAME, or sound to
// SILENCE. When the source publishes nothing, the card still appears with the
// source's own name, a working transport (probed: `CanPlay` / `CanPause` /
// `CanGoNext` / `CanGoPrevious` are all live on an empty-Metadata player) and
// a subtitle that says why there is no title, rather than a blank line
// implying the shell lost it. MediaSource.qml carries the full finding.
//
// ── icons ────────────────────────────────────────────────────────────────
// Transport was Nerd Font private-use codepoints — a second icon family on
// the font's own grid. The 2026-08-22 mockups set one family: 16px grid, 1.4
// stroke, inheriting its colour from the call site. `MediaGlyph` is that.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

PanelWindow {
    id: root
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "nyxus-media-crest"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // ⚠ `MediaSource.present`, never `hasTrack` — see the header. An idle
    // registered browser is still excluded (`present` is false with no title
    // AND no playback), which is the WIP-640(b) regression this must not undo.
    readonly property bool shown: Prefs.mediaBarPop && MediaSource.present
                                  && !Bus.mediaCrestDocked
                                  && !Bus.launcherOpen && !Bus.powerOpen
                                  && !Bus.flyoutOpen

    visible: root.shown
    mask: Region { item: root.shown ? card : null }

    anchors { left: true; right: true; bottom: true }
    margins.bottom: Theme.chromeH - Theme.bloomPad + Theme.s4
    // 196 was 184 (the card) + 12 (the bloom's headroom). Derived now, so
    // opening the lyrics sheet moves the window and the card together and
    // there is no second number to forget. TRK-3979.
    implicitHeight: card.height + 12 + Theme.bloomPad
    implicitWidth: 580 + Theme.bloomPad * 2

    readonly property color iceInteractive: Theme.paintLayers.glacier[0]
    readonly property color icePrimary: Theme.paintLayers.glacier[5]
    readonly property color iceHairline: Theme.paintLayers.glacier[4]
    readonly property color iceOn: Theme.paintLayers.glacier[3]
    readonly property color icePeak: Theme.paintLayers.glacier[6]

    // ══ THE LYRICS BUTTON ═══════════════════════════════════ TRK-3979 ══
    //
    // Owner, 2026-09-08, after a night of a feature that showed him nothing
    // and never said why: "well i want a button on the music pop up and app".
    //
    // ── 1 · WHY A BUTTON AND NOT AN ALWAYS-ON PANEL ────────────────────
    // The card is 560x184 and every pixel of it is doing a job — art,
    // title, artist, source, tape state, scrubber, transport. A lyrics
    // sheet folded into that either shrinks the transport or overlaps it,
    // and this build has a measured history of clipped and overlapping
    // text. So the sheet is a DRAWER: closed the card is exactly the 184 px
    // he already approved, byte for byte; open, the card grows UPWARDS
    // (this window is bottom-anchored, so height added to it is height
    // added above the transport) and nothing that was on screen moves.
    //
    // ── 2 · ⚠ AND IT MUST NEVER OPEN ON AN EMPTY SHEET ─────────────────
    // This is the whole point of the row. Silence is what he was fighting:
    // a track with no lyrics, a helper that is not installed, and a feature
    // switched off ALL rendered as nothing at all, so the only reading
    // available to him was "broken". Measured against lrclib on 2026-09-08,
    // 22 of 25 sampled "no match" entries in his cache are genuinely absent
    // from the catalogue — so a large fraction of presses legitimately have
    // nothing to show, and every one of those presses gets a SENTENCE
    // instead of a blank box. `MediaSource.lyricNote` is that sentence and
    // it is the fetcher's own reason, never a guess made here.
    property bool lyricsOpen: false

    // The drawer's height, and it is a fixed number on purpose: a drawer
    // that sized itself to the song would jump the whole window between
    // tracks. 168 px is six lines of `tBody` at this line height plus the
    // sheet's own margins — measured, not chosen.
    readonly property int lyricsSheetH: 168

    readonly property bool lyricsHave:
        Prefs.lyricsOnline && MediaSource.lyricLoaded
        && MediaSource.lyricLines.length > 0

    // ⚠ COMPUTED HERE, NOT ONLY IN MediaSource, AND FOR ONE REASON: two of
    // these four states are facts this SURFACE holds and the source does
    // not have to be asked about — the consent key, and whether there is a
    // track at all. The source answers the other two, in the fetcher's own
    // words.
    readonly property string lyricsNote: {
        if (!Prefs.lyricsOnline)
            // Short on purpose: photographed at 560 px it wrapped to two
            // lines and left "on." alone on the second. The link under it
            // says where to go, so the sentence does not have to.
            return qsTr("Synced lyrics are switched off.");
        if (!MediaSource.hasTrack)
            return qsTr("Nothing is playing.");
        if (root.lyricsHave)
            return "";
        if (MediaSource.lyricNote.length > 0)
            return MediaSource.lyricNote;
        return qsTr("Looking for lyrics…");
    }

    // ── ⚠ THE KEEP CHIP'S ONE COMMAND ────────────────────────── TRK-3959
    // TRK-3435 — shipped-first PATH through `env`, so argv never crosses a
    // shell. Identical form to Bar.qml's `shippedPath` and SetPage*'s
    // `execPath`; HardwareCaps.qml carries the ruling.
    readonly property string execPath: "PATH="
        + (Quickshell.env("NYXUS_BIN_DIR") || "/usr/local/bin")
        + ":" + Quickshell.env("PATH")

    // ⚠ `--toggle`, never --arm/--disarm. The DAEMON decides which way the
    // press goes, from the state IT published, so a surface a second out of
    // date cannot drive the tape into the wrong state. The bar's lamp and
    // Settings ▸ Sound spawn this identical line, and nothing here writes
    // `tape.json` -- one writer is the whole reason the surfaces agree.
    // `docs/CONTRACT_TAPE_CONTROL.md` §3.
    Process {
        id: tapeToggle
        command: ["env", root.execPath, "nyxus-tape", "--toggle"]
    }

    property int tick: 0
    Timer {
        interval: 500
        repeat: true
        running: root.shown && MediaSource.playing
        onTriggered: root.tick++
    }

    readonly property real posSec: {
        root.tick;
        return MediaSource.positionSec();
    }
    readonly property real lenSec: MediaSource.lengthSec
    readonly property real frac: root.lenSec > 0
                                 ? Math.min(1, root.posSec / root.lenSec) : 0

    // A timeline with no length is two 0:00 stamps either side of an empty
    // rail — it says "broken", not "unknown". A source that publishes no
    // length (the empty-Metadata case, and every live stream) gets no
    // timeline at all, and the transport moves up to fill the space.
    readonly property bool hasTimeline: root.lenSec > 0

    readonly property string deviceName: {
        var s = Sys.sinkLabel(Sys.sink);
        if (s && s.length)
            return s;
        return "This machine";
    }

    readonly property string sourceName: {
        var id = MediaSource.sourceLabel;
        if (id && id.length)
            return id;
        return qsTr("Now playing");
    }

    property bool hadTrack: MediaSource.present
    onHadTrackChanged: {
        if (!MediaSource.present)
            Bus.mediaCrestDocked = false;
    }

    function fmt(sec) {
        if (!sec || sec < 0)
            return "0:00";
        var s = Math.floor(sec % 60);
        return Math.floor(sec / 60) + ":" + (s < 10 ? "0" + s : s);
    }

    function seekAt(x, w) {
        if (!MediaSource.canSeek || w <= 0)
            return;
        MediaSource.seekFraction(x / w);
        root.tick++;
    }

    Item {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.bloomPad
        width: 560
        // ⚠ NO `Behavior` ON THIS. An eased height on a PanelWindow is a
        // layer-shell resize every frame for the length of the animation --
        // the compositor reconfigures the surface each time -- and this
        // window is an Overlay over his whole screen. The drawer snaps.
        height: 184 + (root.lyricsOpen ? root.lyricsSheetH : 0)

        // Do not `clip: true` here. Item.clip is a RECTANGLE, so the
        // Pane/GlassEdge round corners and a square scissor showed at
        // once. Bloom is off so the shader cannot square the rim either.

        // TRK-3082: same sky-under-glass as Clock / WidgetChip. This card
        // is Overlay over windows; without the crop it is a hole.
        SkyBehind {
            anchors.fill: parent
            live: root.shown
            paneScreenX: {
                var sw = root.screen ? root.screen.width : 1920
                return Math.round((sw - card.width) / 2)
            }
            paneScreenY: {
                var sh = root.screen ? root.screen.height : 1080
                var winY = sh - root.implicitHeight
                           - (Theme.chromeH - Theme.bloomPad + Theme.s4)
                return winY + card.y
            }
            screenW: root.screen ? root.screen.width : 1920
            screenH: root.screen ? root.screen.height : 1080
            radius: Theme.r3
        }

        Pane {
            anchors.fill: parent
            elevation: 2
            bloomPx: 0
            radiusTL: Theme.r3
            radiusTR: Theme.r3
            radiusBR: Theme.r3
            radiusBL: Theme.r3
            // ⚠ DARKENED LOCALLY, NOT IN THE THEME. Owner 2026-09-07:
            // "darken behind the music bar". Theme.panelMid is shared with the
            // bar, clock, launcher, emoji picker and context menu; moving the
            // token would darken all of them to fix one surface.
            fill: Qt.rgba(0.010, 0.026, 0.034, 0.62)   // was panelMid @ 0.34
        }
        Rectangle {
            anchors.fill: parent
            radius: Theme.r3
            // Same reasoning: swellGround* is shared with Widgets, TaskView,
            // UsbDock and Station. These are this panel's own stops -- the
            // theme's values carried up in alpha only, so the hue and the
            // top-to-foot deepening are unchanged.
            gradient: Gradient {
                GradientStop { position: 0.00; color: Qt.rgba(0.006, 0.014, 0.020, 0.94) }
                GradientStop { position: 0.50; color: Qt.rgba(0.005, 0.011, 0.017, 0.965) }
                GradientStop { position: 1.00; color: Qt.rgba(0.004, 0.008, 0.014, 0.985) }
            }
        }

        GlassEdge {
            anchors.fill: parent
            radiusTL: Theme.r3
            radiusTR: Theme.r3
            radiusBR: Theme.r3
            radiusBL: Theme.r3
            // Density is sky + swell under the paint, not GlassEdge.body
            // (WIP-259 / WIP-265). Edging matches Clock / WidgetChip.
            body: 0
            wash: 0
            edging: 0.85
        }
        // Mirror: WidgetChip default zRole 1, same as Clock (TRK-3081/3082).
        MirrorEdge {
            radiusTL: Theme.r3; radiusTR: Theme.r3
            radiusBR: Theme.r3; radiusBL: Theme.r3
            depth: 10
            strength: 0.46
        }

        // ── 4 · THE SEAM (TRK-3372) ─────────────────────────────────────
        // 1 px glacier[4]. The crest had layers 0 (SkyBehind), 1, 2 and 3
        // and stopped there — the only borders in this file are on the
        // controls inside it. Same rung and same resting alpha as
        // `SetSlab.qml` and `Widgets.qml` WidgetChip.
        Rectangle {
            anchors.fill: parent
            radius: Theme.r3
            color: "transparent"
            antialiasing: true
            border.width: 1
            border.color: Theme.soften(Theme.paintLayers.glacier[4], 0.45)
        }

        // Ice hairline on the floor of the card — a player, not a notice.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: Theme.r3
            anchors.rightMargin: Theme.r3
            height: 2
            radius: 1
            color: root.icePrimary
            opacity: 0.55
        }

        // ── THE PLAYER, AND IT IS PINNED TO THE FLOOR ───────── TRK-3979
        // Everything that was here before this drawer existed now lives in
        // `stage`, and `stage` is 184 px tall and anchored to the BOTTOM of
        // the card. That is the whole trick: the card may be 184 or 352, and
        // the art, the names, the scrubber and the transport are at exactly
        // the same screen position either way. Nothing reflows, nothing
        // resizes, nothing can be pushed off the card by the sheet, because
        // the sheet cannot reach them.
        //
        // The glass above (Pane, gradient, GlassEdge, MirrorEdge, seam) is
        // still `anchors.fill: parent`, so an open drawer is the SAME card
        // grown, not a second slab stacked on the first.
        Item {
            id: stage
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 184

        Item {
            id: artStage
            width: 152
            height: 152
            anchors.left: parent.left
            anchors.leftMargin: Theme.s5
            anchors.verticalCenter: parent.verticalCenter

            Item {
                id: sleeve
                width: 140
                height: 140
                anchors.centerIn: parent

                Image {
                    id: art
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: MediaSource.artUrl
                    visible: false
                    asynchronous: true
                }
                Item {
                    id: artMask
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.r2
                        color: "black"
                    }
                }
                MultiEffect {
                    anchors.fill: parent
                    source: art
                    visible: art.status === Image.Ready
                    maskEnabled: true
                    maskSource: artMask
                }

                Rectangle {
                    visible: art.status !== Image.Ready
                    anchors.fill: parent
                    radius: Theme.r2
                    color: Theme.soften(root.iceHairline, 0.22)
                    MediaGlyph {
                        anchors.centerIn: parent
                        name: "note"
                        size: 44
                        stroke: 1.4
                        color: root.iceInteractive
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.r2
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.soften(root.icePeak, 0.45)
                }

                // Progress as a floor hairline on the sleeve, not a ring
                // that escaped the card. Absent with no known length.
                Rectangle {
                    visible: root.hasTimeline
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 6
                    height: 3
                    radius: 1
                    color: Theme.soften(Theme.text, 0.16)
                    Rectangle {
                        width: parent.width * root.frac
                        height: parent.height
                        radius: 1
                        color: root.icePrimary
                    }
                }

                TapHandler {
                    onTapped: MediaSource.togglePlaying()
                }
            }
        }

        ColumnLayout {
            anchors {
                left: artStage.right
                right: parent.right
                top: parent.top
                bottom: parent.bottom
                leftMargin: Theme.s3
                rightMargin: Theme.s6
                topMargin: Theme.s5
                bottomMargin: Theme.s5
            }
            spacing: Theme.s2

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s4

                Rectangle {
                    Layout.preferredHeight: 18
                    Layout.preferredWidth: srcLabel.implicitWidth + Theme.s5
                    radius: 9
                    color: Theme.soften(root.iceInteractive, 0.14)
                    Text {
                        id: srcLabel
                        anchors.centerIn: parent
                        text: root.sourceName
                        color: root.icePrimary
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                        font.weight: Font.Medium
                        font.letterSpacing: Theme.trackMicro
                    }
                }

                // ══ THE KEEP CHIP ═══════════════════════════════ TRK-3959
                //
                // Owner, 2026-09-08: "i need something to show if its
                // recording or no so i no" -- the SECOND time he asked, and
                // he already had the bar lamp (TRK-3830). Two things were
                // wrong and only one of them was the lamp's size:
                //
                //  1 · THIS is the surface he actually watches. His own
                //      words the same night: "the one on the bottom bar
                //      shows the art and i built that as well". The card is
                //      on screen exactly when a song is playing, which is
                //      exactly when the answer matters, and it has room for
                //      the WORD where the bar only had room for a dot.
                //  2 · A dot cannot say WHY. A tape that is off because he
                //      turned it off and a tape that is off because its
                //      daemon died at the reboot are the same dot and
                //      different facts -- and it was the second one that
                //      cost him a song on 2026-09-07. `TapeState.word`
                //      separates them; `TapeState.phrase` is the sentence,
                //      shown on hover so the chip stays quiet at rest.
                //
                // ⚠ NOTHING HERE IS HARDCODED AND NOTHING HERE IS A WISH.
                // Every state comes from `TapeState`, which is the daemon's
                // own file AND its heartbeat (TRK-3829): a tape killed by an
                // OOM or a reboot takes this chip with it inside 45 s. The
                // chip does not move on the press either -- it acts, and
                // lets the watched file move the visual. If arming fails the
                // chip stays off, which is the difference between a control
                // and a dead toggle (HardwareCaps.qml's mandate).
                //
                // Colour follows the thesis: magma is "what MATTERS", so a
                // running tape is magma and everything else is glacier-side
                // quiet. Same 18 px pill as the source label beside it, so
                // it reads as one family rather than a bolted-on badge.
                Rectangle {
                    id: keepChip
                    Layout.preferredHeight: 18
                    // Tracks the clamped text width, not the implicit one, so
                    // the pill matches the elided sentence rather than the
                    // full one it is hiding.
                    //
                    // ⚠ AND THERE IS NO `Behavior` ON THIS. The first cut
                    // wrote `Behavior on Layout.preferredWidth`, which is a
                    // Behavior on an ATTACHED property -- QML does not
                    // support that, and a component that fails to compile
                    // takes the WHOLE shell configuration down with it. That
                    // is `shell/SkyConstellations.qml`'s failure mode from
                    // the night before (CHECKLIST TRK-3958) and it is not
                    // worth an eased width on a chip.
                    Layout.preferredWidth: keepWord.width
                                           + keepDot.width + Theme.s3
                                           + Theme.s5
                    radius: 9
                    readonly property bool hot: TapeState.phase === "keeping"
                    readonly property bool warm: TapeState.phase === "waiting"
                    readonly property bool broke: TapeState.phase === "stopped"
                    color: hot ? Theme.soften(Theme.spectrumTip, 0.20)
                           : broke ? Theme.soften(Theme.spectrumTip, 0.12)
                           : Theme.soften(root.iceInteractive, 0.14)
                    opacity: keepHov.hovered ? 1.0
                             : (hot || warm || broke) ? 1.0 : 0.72
                    Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                    Behavior on opacity { NumberAnimation { duration: Theme.durQuick } }

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.s3

                        // The same three-plus-one state vocabulary the bar
                        // lamp draws, at the same 8 px, so the two surfaces
                        // are recognisably one indicator in two places.
                        Rectangle {
                            id: keepDot
                            anchors.verticalCenter: parent.verticalCenter
                            width: 8
                            height: 8
                            radius: 4
                            color: keepChip.hot ? Theme.spectrumTip
                                                : "transparent"
                            border.width: keepChip.warm ? 1.5 : 1
                            border.color: (keepChip.hot || keepChip.warm
                                           || keepChip.broke)
                                          ? Theme.spectrumTip : Theme.textDim
                            opacity: keepChip.broke ? 0.75 : 1.0
                        }
                        Text {
                            id: keepWord
                            anchors.verticalCenter: parent.verticalCenter
                            // ⚠ Read, never composed here. One spelling of
                            // this fact lives in TapeState.qml so the bar,
                            // this card and Settings cannot drift into three
                            // descriptions of one thing.
                            //
                            // ⚠ AND THIS IS NOT A ToolTip. The first cut of
                            // this chip put the sentence in an attached
                            // `ToolTip`, which would have taken the whole
                            // shell down: `QtQuick.Controls` IS DELIBERATELY
                            // NOT IMPORTED ANYWHERE IN shell/ --
                            // SetPageKeyboard.qml:220 says one import of it
                            // here would be the mistake, and ScrollRail.qml
                            // exists because of the same rule. So the word
                            // grows into the sentence under the pointer
                            // instead, with plain QtQuick and no new import.
                            width: Math.min(implicitWidth, 240)
                            elide: Text.ElideRight
                            text: keepHov.hovered ? TapeState.phrase
                                                  : TapeState.word
                            color: (keepChip.hot || keepChip.broke)
                                   ? Theme.text : root.icePrimary
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                            font.weight: Font.Medium
                            font.letterSpacing: Theme.trackMicro
                        }
                    }

                    HoverHandler {
                        id: keepHov
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler { onTapped: tapeToggle.running = true }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: qsTr("Media output")
                    color: outHov.hovered ? root.iceInteractive : Theme.textMuted
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    font.weight: Font.Medium
                    HoverHandler { id: outHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: Bus.openSettings("sound") }
                    Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                }

                Item {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    MediaGlyph {
                        anchors.centerIn: parent
                        name: "chevronDown"
                        size: 16
                        color: dockHov.hovered ? root.iceInteractive : Theme.textMuted
                        Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                    }
                    HoverHandler { id: dockHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: Bus.mediaCrestDocked = true }
                }
            }

            Text {
                Layout.fillWidth: true
                text: MediaSource.displayTitle.length
                      ? MediaSource.displayTitle : qsTr("Now playing")
                color: Theme.text
                font.family: Theme.fUiTitle
                font.pixelSize: Theme.tTitle
                font.weight: Theme.wStrong
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            Text {
                Layout.fillWidth: true
                // When the source publishes nothing, this says so in words
                // rather than falling through to the audio device, which read
                // as an artist called "Built-in Audio Analogue Stereo".
                text: MediaSource.displaySubtitle.length
                      ? MediaSource.displaySubtitle : root.deviceName
                color: Theme.textMuted
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                elide: Text.ElideRight
            }

            // ── audit-0908 · WHY THERE ARE NO WORDS ─────────────────────
            // Owner, 2026-09-08: "no lyrics still" — said about a track that
            // genuinely has none. A track with no lyrics and a feature that
            // has fallen over both drew NOTHING, so there was no way to tell
            // them apart, and the reasonable reading of nothing is "broken".
            //
            // The crest is where this belongs and the bar is not: this is a
            // surface he opens to look at the track, while the bar is glanced
            // at — and an advert break on YouTube would otherwise put "No
            // lyrics found" on his bar every few songs. Quiet, dim, one line,
            // and only while the feature is switched on.
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                // TRK-3979 — reconnected. This read `MediaSource.lyricNote`,
                // was left dangling at `""` when that file was reverted on
                // 2026-09-08, and the property is back (MediaSource § THE
                // PANEL'S HALF) as a STRING ONLY: nothing branches on it.
                //
                // ⚠ IT GOES QUIET WHEN THE DRAWER IS OPEN. The sheet says
                // the same sentence in the same words two rows up, and one
                // fact printed twice on one card is how a card starts
                // looking broken.
                text: (Prefs.lyricsOnline && !root.lyricsOpen)
                      ? MediaSource.lyricNote : ""
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tMicro
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                visible: root.hasTimeline
                spacing: Theme.s3
                Text {
                    text: root.fmt(root.posSec)
                    color: Theme.textDim
                    font.family: Theme.fNum
                    font.pixelSize: Theme.tMicro
                }
                Item {
                    id: track
                    Layout.fillWidth: true
                    Layout.preferredHeight: 14
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Theme.soften(Theme.text, 0.14)
                        Rectangle {
                            width: parent.width * root.frac
                            height: parent.height
                            radius: 2
                            color: root.icePrimary
                        }
                    }
                    Rectangle {
                        x: Math.max(0, Math.min(track.width - 10, track.width * root.frac - 5))
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10
                        height: 10
                        radius: 5
                        color: root.iceInteractive
                        visible: MediaSource.canSeek
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: MediaSource.canSeek
                        cursorShape: Qt.PointingHandCursor
                        onPressed: root.seekAt(mouse.x, track.width)
                        onPositionChanged: if (pressed) root.seekAt(mouse.x, track.width)
                    }
                }
                Text {
                    text: root.fmt(root.lenSec)
                    color: Theme.textDim
                    font.family: Theme.fNum
                    font.pixelSize: Theme.tMicro
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.s7

                Item {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    opacity: MediaSource.canGoPrevious ? 1 : 0.35
                    MediaGlyph {
                        anchors.centerIn: parent
                        name: "prev"
                        size: 16
                        color: prevHov.hovered ? root.iceInteractive : Theme.textMuted
                        Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                    }
                    HoverHandler { id: prevHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: MediaSource.previous() }
                }

                Item {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                    // ON is a FILLED GROUND, per the 2026-08-22 ladder — the
                    // one control on this card that is "engaged" wears
                    // glacier[3]; hover lifts it, it does not recolour it.
                    Rectangle {
                        anchors.centerIn: parent
                        width: 48
                        height: 48
                        radius: 24
                        color: Theme.soften(root.iceOn, playHov.hovered ? 0.42 : 0.28)
                        border.width: 1
                        border.color: Theme.soften(root.iceInteractive, 0.55)
                        Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                    }
                    MediaGlyph {
                        anchors.centerIn: parent
                        name: MediaSource.playing ? "pause" : "play"
                        size: 20
                        color: root.icePeak
                    }
                    HoverHandler { id: playHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: MediaSource.togglePlaying() }
                }

                Item {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    opacity: MediaSource.canGoNext ? 1 : 0.35
                    MediaGlyph {
                        anchors.centerIn: parent
                        name: "next"
                        size: 16
                        color: nextHov.hovered ? root.iceInteractive : Theme.textMuted
                        Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                    }
                    HoverHandler { id: nextHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: MediaSource.next() }
                }

                Item {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    MediaGlyph {
                        anchors.centerIn: parent
                        name: "more"
                        size: 16
                        color: moreHov.hovered ? root.iceInteractive : Theme.textMuted
                        Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                    }
                    HoverHandler { id: moreHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: Bus.openMedia() }
                }

                // ══ THE LYRICS BUTTON ═══════════════════════ TRK-3979 ══
                //
                // ⚠ IT IS HERE AND NOT IN THE TOP ROW, AND THAT IS
                // MEASURED, NOT TASTE. The column beside the sleeve is 386
                // px wide (560 card - 152 art - s3 - s6). The top row
                // already spends 314 of them: the source pill (~103), the
                // tape chip (~89, and it GROWS to 240 under the pointer),
                // "Media output" (~62), the dock chevron (28) and four
                // 8 px gaps. A "Lyrics" pill needs ~62 more, which leaves
                // ~10 px of slack -- and the first time he hovered the tape
                // chip the two would have collided. This row spends 220 of
                // 386 and has the room with 90 px to spare.
                //
                // ⚠ AND IT IS A WORD, NOT A GLYPH. The whole complaint is
                // that he could not find the lyrics or tell whether they
                // existed; answering that with a sixteenth icon he has to
                // learn is answering the wrong question. It also means no
                // new `MediaGlyph` name, so a contested file this lane does
                // not own stays untouched.
                //
                // ON is a FILLED GROUND -- the same 2026-08-22 ladder the
                // play button above obeys, so "open" reads the same way
                // "playing" does.
                Rectangle {
                    id: lyricPill
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: lyricWord.implicitWidth + Theme.s6
                    radius: 12
                    color: root.lyricsOpen
                           ? Theme.soften(root.iceOn, lyricHov.hovered ? 0.42 : 0.28)
                           : Theme.soften(root.iceInteractive,
                                          lyricHov.hovered ? 0.22 : 0.14)
                    border.width: 1
                    border.color: Theme.soften(root.iceInteractive,
                                               root.lyricsOpen ? 0.55 : 0.30)
                    Behavior on color { ColorAnimation { duration: Theme.durQuick } }

                    Text {
                        id: lyricWord
                        anchors.centerIn: parent
                        text: qsTr("Lyrics")
                        // 14.8:1 at rest and 17.6:1 open, over this card's
                        // own ground composited against a WHITE window --
                        // the worst backdrop an Overlay layer can have.
                        color: root.lyricsOpen ? Theme.text : root.icePrimary
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        font.weight: Font.Medium
                        font.letterSpacing: Theme.trackMicro
                    }

                    // ⚠ NOT A `ToolTip`. `QtQuick.Controls` is deliberately
                    // not imported anywhere in shell/ -- SetPageKeyboard.qml
                    // carries the ruling and the tape chip beside this one
                    // already obeys it.
                    HoverHandler { id: lyricHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.lyricsOpen = !root.lyricsOpen }
                }
            }
        }
        }

        // ══ THE SHEET ═══════════════════════════════════════ TRK-3979 ══
        // Everything above the player, and ONLY when the drawer is open --
        // `visible: false` means no ListView, no delegates and no bindings
        // at all in the state the card spends almost all its life in.
        Item {
            id: lyricSheet
            visible: root.lyricsOpen
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: stage.top
            anchors.leftMargin: Theme.s5
            anchors.rightMargin: Theme.s6
            anchors.topMargin: Theme.s5

            // The header line: what this sheet is, and how it is timed.
            Text {
                id: sheetHead
                anchors.top: parent.top
                anchors.left: parent.left
                text: qsTr("Lyrics")
                color: root.icePrimary
                font.family: Theme.fUi
                font.pixelSize: Theme.tMicro
                font.weight: Font.Medium
                font.letterSpacing: Theme.trackMicro
            }

            // ⚠ THE HONESTY LABEL. `nyxus-lyrics` timestamps LRC per LINE
            // and spreads the words across it by syllable count; `exact` is
            // 1 only where an Enhanced-LRC A2 marker gave a word both its
            // ends, and on the owner's own test track that was ZERO of 905
            // words. A panel that highlighted an estimated line without
            // saying so would be claiming a precision the data does not
            // have -- and he would hear the drift on a fast line and read it
            // as the feature being broken again.
            Text {
                anchors.top: parent.top
                anchors.right: parent.right
                visible: root.lyricsHave
                text: MediaSource.lyricExact ? qsTr("timed")
                                             : qsTr("timings estimated")
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tMicro
            }

            // ── the sheet, when there IS one ────────────────────────────
            ListView {
                id: lyricList
                visible: root.lyricsHave
                anchors.top: sheetHead.bottom
                anchors.topMargin: Theme.s3
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.s4
                clip: true
                spacing: Theme.s1
                boundsBehavior: Flickable.StopAtBounds
                model: root.lyricsOpen ? MediaSource.lyricLines : []

                delegate: Text {
                    required property int index
                    required property var modelData
                    width: lyricList.width
                    text: String(modelData[2])
                    wrapMode: Text.WordWrap
                    // Three rungs, and the middle one is what makes the
                    // sheet readable rather than a wall: the line being
                    // sung is `text` (17.7:1), its neighbours are muted
                    // (13.0:1) and the rest of the song is dim (9.1:1).
                    // Every one of those is over the 4.5:1 body floor with
                    // a white window behind the card.
                    color: index === MediaSource.lyricLineIdx
                           ? Theme.text
                           : (Math.abs(index - MediaSource.lyricLineIdx) === 1
                              ? Theme.textMuted : Theme.textDim)
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tBody
                    font.weight: index === MediaSource.lyricLineIdx
                                 ? Theme.wStrong : Font.Normal
                    Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                }

                // ⚠ FOLLOW, BUT NEVER FIGHT HIM FOR IT. `moving` is true
                // while a hand is on the wheel; auto-scrolling out from
                // under a person reading two verses ahead is the thing that
                // makes a lyric panel unusable.
                Connections {
                    target: MediaSource
                    function onLyricLineIdxChanged() {
                        if (!root.lyricsOpen || lyricList.moving)
                            return;
                        if (MediaSource.lyricLineIdx >= 0)
                            lyricList.positionViewAtIndex(
                                MediaSource.lyricLineIdx, ListView.Center);
                    }
                }
                onVisibleChanged: {
                    if (visible && MediaSource.lyricLineIdx >= 0)
                        positionViewAtIndex(MediaSource.lyricLineIdx,
                                            ListView.Center);
                }
            }

            // ── ⚠ AND WHEN THERE IS NOT ────────────────────────────────
            // The reason this whole row exists. An empty drawer is exactly
            // what a broken feature looks like, so the drawer is never
            // empty: it always carries the sentence for why.
            Item {
                visible: !root.lyricsHave
                anchors.top: sheetHead.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                Column {
                    anchors.centerIn: parent
                    width: parent.width
                    spacing: Theme.s3

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: root.lyricsNote
                        wrapMode: Text.WordWrap
                        color: Theme.textMuted          // 13.0:1, worst case
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tBody
                    }
                    // The one state that is a SETTING rather than a fact
                    // about the song gets the way to change it, on the spot.
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        visible: !Prefs.lyricsOnline
                        text: qsTr("Open Settings ▸ Appearance")
                        color: offHov.hovered ? root.iceInteractive
                                              : root.icePrimary
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        font.weight: Font.Medium
                        HoverHandler { id: offHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: Bus.openSettings("appearance") }
                        Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                    }
                }
            }

            // The sheet's floor: one glacier hairline between the words and
            // the transport, so the drawer reads as a region of this card
            // rather than as a second card balanced on it. Same rung and
            // same resting alpha as the card's own seam.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Theme.soften(root.iceHairline, 0.45)
            }
        }
    }
}
