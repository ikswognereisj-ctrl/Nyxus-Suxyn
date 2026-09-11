// Nyxus Suxyn — what is playing, on the lock screen. WIP-415.
//
// The owner's words: "if music is playing I wanted that too, and be able to
// skip song pause play etc without having to log in if I wanted it that way,
// so some type of setting for that."
//
// Two different things live in that sentence and this file keeps them apart,
// because they carry different risk:
//
//   SEEING what is playing      — shown whenever a player exists. He asked for
//                                 it plainly and it is the same fact the bar's
//                                 Crest already shows on the unlocked desktop.
//   CONTROLLING it pre-auth     — a SETTING, and it ships OFF.
//
// ── why the controls default to OFF, which is a decision, not a default ──
// A lock screen is the boundary between "someone is at this machine" and
// "someone is AUTHORISED at this machine". Media keys on a locked laptop mean
// anyone who walks past the desk can pause your call audio, skip your tracks,
// or work out what you are listening to by watching the title change. That is
// small, but it is a real reduction in what the lock is FOR, and the owner's
// own phrasing — "if I wanted it that way" — is a request for a choice, not a
// request for the permissive side of it. So the switch exists and it starts
// off. He turns it on once, deliberately, and then it is his decision rather
// than a thing he discovered had been true all along.
//
// The key is `lock_media_control`, read through `SettingsStore` — the SAME
// call `SetPageNotifications.qml` uses for the lock notification keys, so the
// settings page and the lock surface can never read different sources.
//
// ── no progress bar, on purpose ─────────────────────────────────────────
// MPRIS `position` does not free-run: something has to ask for it, which on a
// lock screen means a timer. `hyprlock.conf` carries a hard rule, learned by
// locking the owner out of his own machine on 2026-08-02, that nothing on a
// lock surface may poll faster than 1000 ms — and the honest reading of that
// history is that a lock screen should add polls only for facts it needs. A
// seek bar you cannot drag (the controls may be off) is decoration that costs
// a wakeup per second forever. Title, artist, art and the three buttons are
// the whole of what he asked for.
//
// ── art ─────────────────────────────────────────────────────────────────
// `trackArtUrl` is frequently empty, and a broken-image icon on a lock screen
// reads as a broken system (the same reasoning as the avatar disc in
// Lock.qml). So the art is a fallback glyph unless a real image loads.
//
// ── 2026-08-22, TRK-2601: the strip vanished while audio played ──────────
// Same root cause as the Crest. It was gated on `Sys.playerHasTrack`, which
// is false for a player publishing an empty `Metadata` dict — the measured
// chromium state, where `playerctl -l` names the player and `playerctl
// status` says `Playing` while `playerctl metadata` fails outright. So the
// locked machine was making noise with nothing on screen to say what, and —
// with the control switch on — no way to stop it. Now gated on
// `MediaSource.present`: a track to name, or sound to silence. An idle
// registered browser is still excluded, which is the WIP-640(b) fix.
//
// ── 2026-08-22, TRK-2605: the transport was four colour emoji ────────────
// U+23EE / U+23F8 / U+25B6 / U+23ED and a U+266A for the art fallback. Those
// are emoji-presentation codepoints: with a colour emoji font in the fallback
// chain the lock screen drew four colour pictograms, against the mockups'
// rule 4 ("No colour emoji anywhere in the chrome"), and without one they
// came out as tofu — on the surface you cannot get past to fix it. They are
// `MediaGlyph` now: 16-grid geometry, 1.4 stroke, colour from the call site.
pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: media

    // The lock passes this down rather than reading it here, so the whole
    // surface animates on one signal.
    property bool active: false

    // Is there anything to show at all? The lock reads this to decide whether
    // to give the strip any height — a media card that says "nothing playing"
    // is clutter on a screen whose job is to be read at a glance.
    // WIP-640(b). `hasPlayer` is only "an MPRIS app is registered" — an idle
    // browser or player registers with no track, and the strip then claimed
    // the lock screen's height to say "Unknown track". `playerHasTrack` is
    // the "is there anything to show" question this comment already asks,
    // and it is what the supervisor's 2026-08-12 ruling in Sys.qml says to
    // gate existence on.
    readonly property bool hasMedia: MediaSource.present

    // THE SECURITY SWITCH. Default false. See the header.
    readonly property bool controlsAllowed:
        SettingsStore.boolValue("lock_media_control", false)

    readonly property string title:  MediaSource.displayTitle
    readonly property string artist: MediaSource.displaySubtitle
    readonly property bool playing: MediaSource.playing

    implicitHeight: 92

    Pane {
        id: card
        anchors.fill: parent
        elevation: 2
        // The lock is a surface you READ, so it takes the deep end of the
        // material formula — `surfaceDeep` (0.34) rather than the bar's 0.15 —
        // and the GlassEdge below adds the body and the glaze. Theme.qml
        // § THE MATERIAL FORMULA is the one place these numbers live.
        fill: Theme.surfaceDeep
        radiusTL: Theme.r3
        radiusTR: Theme.r3
        radiusBR: Theme.r3
        radiusBL: Theme.r3

        // Same edge as the Start menu, the toasts and the bar. One material.
        GlassEdge {
            anchors.fill: parent
            radiusTL: Theme.r3
            radiusTR: Theme.r3
            radiusBR: Theme.r3
            radiusBL: Theme.r3
            // Page-sized and floating over the sky, so it carries the body.
            body: 1
        }
        // The mirror rim — Launcher.qml § the mirror rim carries the ruling
        // (2026-08-14, "complete … system wide"). Flyout weight.
        MirrorEdge {
            radiusTL: Theme.r3; radiusTR: Theme.r3
            radiusBR: Theme.r3; radiusBL: Theme.r3
            depth: 14
            strength: 0.62
        }

        Row {
            anchors.fill: parent
            anchors.margins: Theme.s6
            spacing: Theme.s6

            // ── the art ──────────────────────────────────────────────────
            Item {
                id: artBox
                width: 60
                height: 60
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.r2
                    color: Theme.soften(Theme.void_, 0.55)
                    border.width: 1
                    border.color: Theme.soften(Theme.text, 0.10)
                }
                MediaGlyph {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    name: "note"
                    size: 24
                    color: Theme.textDim
                }
                Image {
                    id: art
                    anchors.fill: parent
                    anchors.margins: 1
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    visible: status === Image.Ready
                    source: MediaSource.artUrl
                }
            }

            // ── what it is ───────────────────────────────────────────────
            Column {
                id: labels
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.s1
                width: card.width - Theme.s6 * 2 - artBox.width
                       - buttons.width - Theme.s6 * 2

                Text {
                    text: qsTr("NOW PLAYING")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    font.letterSpacing: Theme.trackMicro
                }
                Text {
                    width: parent.width
                    text: media.title
                    color: Theme.text
                    font.family: Theme.fUiTitle
                    font.pixelSize: Theme.tBody
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: media.artist
                    color: Theme.textMuted
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    elide: Text.ElideRight
                    visible: media.artist !== ""
                }
            }

            // ── the controls, only if he asked for them ──────────────────
            // `visible: false` AND no MouseArea when the setting is off: a
            // hidden-but-live tap target on a lock screen would be the exact
            // hole the setting exists to close.
            Row {
                id: buttons
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.s5
                visible: media.controlsAllowed
                width: visible ? implicitWidth : 0

                MediaGlyph {
                    name: "prev"
                    size: 18
                    // Dimmed when the source says it cannot — an empty
                    // `Metadata` does NOT imply an empty transport (probed:
                    // CanGoNext/CanGoPrevious stay true), so this is read
                    // from the player, never inferred from the title.
                    opacity: MediaSource.canGoPrevious ? 1 : 0.35
                    color: prevArea.containsMouse ? Theme.tealGlow : Theme.textMuted
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea {
                        id: prevArea
                        anchors.fill: parent
                        anchors.margins: -Theme.s4
                        hoverEnabled: true
                        enabled: media.controlsAllowed
                        onClicked: MediaSource.previous()
                    }
                }
                MediaGlyph {
                    name: media.playing ? "pause" : "play"
                    size: 24
                    color: playArea.containsMouse ? Theme.tealGlow : Theme.text
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea {
                        id: playArea
                        anchors.fill: parent
                        anchors.margins: -Theme.s4
                        hoverEnabled: true
                        enabled: media.controlsAllowed
                        onClicked: MediaSource.togglePlaying()
                    }
                }
                MediaGlyph {
                    name: "next"
                    size: 18
                    opacity: MediaSource.canGoNext ? 1 : 0.35
                    color: nextArea.containsMouse ? Theme.tealGlow : Theme.textMuted
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        anchors.margins: -Theme.s4
                        hoverEnabled: true
                        enabled: media.controlsAllowed
                        onClicked: MediaSource.next()
                    }
                }
            }
        }
    }
}
