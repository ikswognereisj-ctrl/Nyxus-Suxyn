// Nyxus Suxyn — a settings SWITCH.
//
// Two ways to use it, and the first is the one to reach for:
//
//   key-bound   SetSwitch { key: "usb_notify" }
//               Reads and writes `~/.config/nyxus/settings.json` through
//               SettingsStore. No handler, no local state, nothing to forget
//               to save. This is why the store exists.
//
//   driven      SetSwitch { checked: radio.on; onToggled: radio.setOn(v) }
//               For a fact that lives in the SYSTEM rather than in our config
//               — a Bluetooth radio, a systemd unit, a printer's accepting
//               flag. Set `key: ""` (the default) and drive it yourself.
//
// Mixing the two is a bug: a switch bound to a key AND to a system fact will
// fight itself the moment the two disagree, and they always eventually do.
// `key !== ""` decides which one is in charge, once, here.
//
// 2026-08-19 · same kit as TogglePill, compact. HORIZON §4.3: on is LIT, not
// filled. Colour is KEY PLACES only, glacier/ice (owner: drop rose):
//   active / pool     Theme.paintLayers.glacier[5]  (#b7e6f2)
//   focus             Theme.paintLayers.glacier[0]  (#7fe8ff)
// GlassEdge + wash + Pool copy TogglePill. Compact 46×24 because a SetRow
// cannot host a 62 px flyout chip — metrics copy the pill, size does not.
// `tone` stays on the API so pages do not break; it no longer paints.
import QtQuick

Item {
    id: sw

    // Store-bound mode.
    property string key: ""
    property bool defaultValue: false

    // Driven mode — and the readout in both modes.
    property bool checked: sw.key !== ""
                           ? SettingsStore.boolValue(sw.key, sw.defaultValue)
                           : false

    // Kept so SetPage* callers (`tone: page.tone`) do not break.
    property real tone: 0.35
    readonly property color markOn: Theme.paintLayers.glacier[5]
    readonly property color markFocus: Theme.paintLayers.glacier[0]
    // TRK-3046: 30% tealGlow into glacier[6] ice. Catch-light band only.
    readonly property color swirlPeak: Theme.mix(Theme.tokenAccentPeak, Theme.tealGlow, 0.30)

    // Emitted with the NEW value, after the store has been told in key-bound
    // mode. A page that must also run a command (restart a unit, apply an
    // hyprctl setting) hangs it off this and does not have to re-read the key.
    signal toggled(bool value)

    // Ping-loop. Driven hosts set `pending` until the daemon matches
    // `checked`, and `failed` if the timeout fires. The knob still follows
    // `checked` only — never a guessed success.
    property bool pending: false
    property bool failed: false

    // ── TRK-3645 · THE SLOT · geometry lives HERE, once ─────────────────
    // Owner ruling 2026-09-01, treatment C ("slab C … more in depth with
    // detail and it to be highly polished as well greeen light").
    //
    // WHAT WAS WRONG, measured rather than felt. The item was 24 tall; the
    // track was `anchors.fill` with `bottomMargin: 3`, so the track was 21;
    // the knob was `parent.height - 6` = 18 at `y: 3`. That is 3 px of
    // clearance ABOVE the knob and ZERO below it — the knob was not centred
    // in its own track, on every switch in the product. And 18/21 = 86%:
    // the ball WAS the control and the track was a hairline behind it. An
    // 86% capsule-with-a-ball is the shape every phone OS has shipped since
    // 2013, which is exactly what the owner meant by "the old ones".
    //
    // WHAT IT IS NOW. 46x26. The track is the WHOLE item — no asymmetric
    // margin — and `trackInset` is the ONE number the knob is derived from,
    // so the four clearances are equal by construction and cannot drift
    // apart in a later edit. 26 - 2*3 = 20, giving 20/26 = 77%: a knob
    // riding IN a machined slot with a visible well around it.
    //
    // `slotRadius` 9 in a 26 px height is deliberately short of h/2 = 13.
    // That is the whole point of C: a capsule is MOULDED, a slot is CUT. It
    // is the same language SetIceFace already speaks at the top of the page,
    // so the controls stop looking borrowed from a different product than
    // the instrument row above them.
    readonly property int trackInset: 3
    readonly property real slotRadius: 9
    readonly property real knobRadius: 6

    implicitWidth: 46
    implicitHeight: 26
    opacity: sw.enabled ? 1.0 : 0.4

    function activate() {
        if (!sw.enabled)
            return;
        var next = !sw.checked;
        if (sw.key !== "")
            SettingsStore.setValue(sw.key, next);
        // TRK-3462: driven mode used to do `sw.checked = next` here — and a
        // JS assignment DESTROYS the host's `checked:` binding, so after one
        // tap the switch stopped following the fact it was showing (an orca
        // launch that failed left the switch ON forever; a mute changed
        // elsewhere never moved it). Every driven host binds `checked` to a
        // live system fact and acts in onToggled, so the honest contract is:
        // emit, let the host change the fact, and the bound visual follows
        // the REAL state — including not moving when the action failed.
        // (SetNotifyFlyout's per-host re-bind workaround predates this and
        // is now a harmless no-op.)
        sw.toggled(next);
        DiagnosticBus.logSwitch(sw.key, next);
    }

    // Same cue the flyout pills and the dock use: light standing under a
    // live control. Anchored inside this item so it does not grow the row.
    Pool {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: 12
        tone: sw.checked ? sw.markOn : sw.markFocus
        focusRatio: 0.55
        strength: !sw.enabled ? 0
                : (tap.pressed ? 1.0
                : (sw.checked ? 0.8 : (hov.hovered ? 0.3 : 0)))
    }

    // The track. Compact TogglePill: same glass chip, same Pool, same wash,
    // same two glacier rungs. Not a second Pane (SetCard forbids stacking
    // bodies). GlassEdge + wash, not a second widget family.
    Rectangle {
        id: track
        // TRK-3645: was `anchors.bottomMargin: 3`, which is what made the
        // knob non-concentric. The track is the whole item now.
        anchors.fill: parent
        radius: sw.slotRadius
        // TRK-3021: OFF is a darker inset well, not a 0.50 flat fill.
        color: Theme.soften(Theme.void_, sw.checked ? 0.42 : 0.86)
        Behavior on color { ColorAnimation { duration: Theme.durQuick } }

        // ── TRK-3645 · THE RIM · defect 3, "OFF reads as a hairline" ─────
        // OFF and ON used to differ essentially by KNOB POSITION plus one
        // grey step (textMuted -> text). At 20 px that is not a state
        // signal, and the OFF track's rim measured 2.56:1 against the card
        // ground — present in the framebuffer, absent to the eye.
        //
        // So OFF/ON now differ on THREE axes at once: the GROUND (the
        // `color` above, 0.86 -> 0.42), this RIM, and the knob's own rung.
        //
        // The rim also changes HUE, not just alpha: glacier[4] steel when
        // off, markOn ice when on. A hue step survives a glance that an
        // alpha step does not.
        //
        // 0.70 on glacier[4] = 2.79:1, chosen ABOVE the 0.55 divider rung
        // deliberately: a 46 px capsule needs more rim than a 456 px rule to
        // read at the same weight, because contrast is not the only variable
        // — extent is. Both stay under the 3:1 component floor.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: 1
            border.color: !sw.enabled
                    ? Theme.soften(Theme.lookSeam, 0.30)
                    : (sw.checked
                       ? Theme.soften(sw.markOn, tap.pressed ? 0.95
                                              : (hov.hovered ? 0.85 : 0.72))
                       : Theme.soften(Theme.lookSeam,
                                      tap.pressed ? 0.95
                                    : (hov.hovered ? 0.84 : 0.70)))
            Behavior on border.color { ColorAnimation { duration: Theme.durQuick } }
        }

        GlassEdge {
            anchors.fill: parent
            radiusTL: track.radius
            radiusTR: track.radius
            radiusBR: track.radius
            radiusBL: track.radius
            wash: 0
            edging: !sw.enabled ? 0.22
                  : (tap.pressed ? 0.95
                  : (sw.checked ? 0.80 : (hov.hovered ? 0.52 : 0.30)))
            glaze:  !sw.enabled ? 0.18
                  : (tap.pressed ? 0.85
                  : (sw.checked ? 0.70 : (hov.hovered ? 0.45 : 0.28)))
            Behavior on edging { NumberAnimation { duration: Theme.durQuick } }
            Behavior on glaze  { NumberAnimation { duration: Theme.durQuick } }
        }

        // Recessed floor of the capsule — darker than the rim so OFF reads
        // as a machined well. Under the swirl; ON paint covers it.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            // TRK-3645: was `height / 2`, which re-rounded this floor into a
            // capsule INSIDE a slot — two disagreeing corner families stacked
            // one on top of the other, 2 px apart. A concentric inner corner
            // is the outer corner minus the inset, always.
            radius: parent.radius - 2
            color: Theme.soften(Theme.void_, sw.checked ? 0.34 : 0.82)
            Behavior on color { ColorAnimation { duration: Theme.durQuick } }
        }

        // ── THE SWIRLS ───────────────────────────────────────────────
        // `SwirlChip` in `bare` mode — the SAME tuned paint the flyout pills
        // and the preview board use, not a third copy of its constants. See
        // TogglePill.qml's note: one material, three hosts.
        //
        // `cornerRadius` follows the TRACK, which is a capsule (radius =
        // height/2), not a Theme.r2 card. The display pass's rounded-rect SDF
        // has to agree with the body it paints inside or it squares off the
        // very corners the track rounded.
        SwirlChip {
            id: swirl
            anchors.fill: parent
            anchors.margins: 1
            z: 0
            bare: true
            cornerRadius: track.radius - 1
            active: sw.checked
            enabled: sw.enabled
            hostHovered: hov.hovered
            hostPressed: tap.pressed
            liveWhileLatched: true
            // Dye comes from SwirlChip → PaintMood.ramp (Line / glacier
            // horizon). Do not pass controlSwirlRamp — that is the glacier
            // LAYER, not the bar. Latch opacity is SwirlChip's 0.78
            // (TRK-3074) — 1.0 on this 24 px track was the wash.
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: track.radius
            visible: sw.checked || hov.hovered || tap.pressed
            // TRK-2989: opacity 1.0 on a latched track sat ON TOP of the
            // frozen swirl and read as a dull glacier wash, then "off".
            // The paint is the ON signal; this tint is a hint, not a sheet.
            opacity: tap.pressed ? 0.12 : (sw.checked ? 0.0 : 0.06)
            Behavior on opacity { NumberAnimation { duration: Theme.durQuick } }
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Theme.soften(sw.checked ? sw.markOn : sw.markFocus, 0.24)
                }
                GradientStop { position: 1.0; color: Theme.shelfNone }
            }
        }

        // Catch-light is a RIM, not a sheet. TRK-2989 already dropped the
        // ON wash because it sat on the swirl; the 4 px / 0.92 band was
        // the same class on a 21 px track (measured: top half cyan, swirl
        // crushed into the bottom). Span scales with height so a flyout
        // pill is unchanged; ON alpha is a hint so the field stays the
        // signal. Calendar floor: 2 px, not 1.
        Rectangle {
            id: catchLight
            anchors.fill: parent
            anchors.margins: 1
            radius: track.radius - 1
            color: Theme.shelfNone
            readonly property real span: Math.max(1, height)
            readonly property real band: Math.min(4, Math.max(2, Math.round(height * 0.14)))
            readonly property real peakA: !sw.enabled ? 0.22
                    : (tap.pressed ? 0.50
                    : (sw.checked ? 0.28 : (hov.hovered ? 0.42 : 0.32)))
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Theme.soften(sw.swirlPeak, catchLight.peakA)
                }
                GradientStop {
                    position: catchLight.band / catchLight.span
                    color: Theme.soften(sw.swirlPeak, catchLight.peakA * 0.55)
                }
                GradientStop {
                    position: Math.min(1, (catchLight.band + 1) / catchLight.span)
                    color: Theme.shelfNone
                }
                GradientStop { position: 1.0; color: Theme.shelfNone }
            }
        }

        // ON lip under the catch-light. Same rule: rim, not a second cyan
        // plate. GlassEdge already carries edging 0.80 when checked.
        Rectangle {
            id: onLip
            anchors.fill: parent
            anchors.margins: 1
            radius: track.radius - 1
            color: Theme.shelfNone
            opacity: sw.checked ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durQuick } }
            readonly property real span: Math.max(1, height)
            readonly property real band: Math.min(3, Math.max(2, Math.round(height * 0.10)))
            readonly property real lipA: tap.pressed ? 0.36 : (hov.hovered ? 0.28 : 0.18)
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.shelfNone }
                GradientStop {
                    position: catchLight.band / onLip.span
                    color: Theme.shelfNone
                }
                GradientStop {
                    position: (catchLight.band + 0.2) / onLip.span
                    color: Theme.soften(sw.markFocus, onLip.lipA)
                }
                GradientStop {
                    position: (catchLight.band + onLip.band) / onLip.span
                    color: Theme.soften(sw.markFocus, onLip.lipA)
                }
                GradientStop {
                    position: Math.min(1, (catchLight.band + onLip.band + 1) / onLip.span)
                    color: Theme.shelfNone
                }
                GradientStop { position: 1.0; color: Theme.shelfNone }
            }
        }
    }

    // The knob. Idle is muted type; on is the same object catching light —
    // the 1 px markOn ring stays, plus a 3 px glacier[6] peak on the upper
    // face (TRK-3021). Never a filled accent disc. Slide is the x Behavior.
    Rectangle {
        id: knob
        // TRK-3645 — derived from ONE inset, so the four clearances are equal
        // by construction: 26 - 2*3 = 20, at y=3, leaving 3 px above, 3 px
        // below, 3 px at each end of travel. The old form (`parent.height - 6`
        // at a hard-coded `y: 3`, inside a track shortened by a bottomMargin)
        // happened to produce 3 above and 0 below, and nothing in the code
        // said which of the two 3s was the one that mattered.
        width: parent.height - 2 * sw.trackInset
        height: width
        // A SLAB, not a ball: r6 in 20 px. The knob is the slot's family, one
        // step tighter (slot r9 - trackInset 3 = 6), so the two corner
        // families agree instead of merely coexisting.
        radius: sw.knobRadius
        y: sw.trackInset
        x: sw.checked ? parent.width - width - sw.trackInset : sw.trackInset
        color: sw.checked ? Theme.text : Theme.textMuted
        Behavior on x {
            NumberAnimation {
                duration: Theme.durQuick
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveSnap
            }
        }
        Behavior on color { ColorAnimation { duration: Theme.durQuick } }

        // Upper-face shade so the 3 px peak sits on a sphere, not a flat disc.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.shelfNone
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Theme.soften(Theme.tokenAccentPeak, sw.checked ? 0.42 : 0.22)
                }
                GradientStop { position: 0.40; color: Theme.shelfNone }
                GradientStop {
                    position: 1.0
                    color: Theme.soften(Theme.void_, 0.30)
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            // TRK-3645: was `width / 2` — a circle drawn inside a slab knob.
            radius: parent.radius - 1
            color: "transparent"
            visible: sw.checked
            border.width: 1
            border.color: Theme.soften(sw.markOn, 0.85)
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 2
            width: parent.width - 6
            height: 3
            radius: height / 2
            color: Theme.soften(Theme.tokenAccentPeak,
                                sw.checked ? 0.95
                                : (hov.hovered || tap.pressed ? 0.78 : 0.58))
            Behavior on color { ColorAnimation { duration: Theme.durQuick } }
        }
    }

    HoverHandler {
        id: hov
        enabled: sw.enabled
        cursorShape: Qt.PointingHandCursor
    }
    // The press IGNITES the paint — the owner's original ask read literally:
    // "so when you press it the swirls activate".
    TapHandler {
        id: tap
        enabled: sw.enabled
        onTapped: {
            sw.activate();
            swirl.ignite();
        }
    }

    // Keyboard: a settings app that cannot be driven from the keyboard fails
    // its own Ease of Access page.
    focus: false
    activeFocusOnTab: sw.enabled
    Keys.onSpacePressed: sw.activate()
    Keys.onReturnPressed: sw.activate()

    // Focus-visible contour — same contract as TogglePill: 1 px interactive
    // hairline, no area, never glacier[4] as a fill.
    Rectangle {
        anchors.fill: track
        color: "transparent"
        visible: sw.activeFocus && sw.enabled
        border.width: 1
        border.color: Theme.soften(sw.markFocus, 0.55)
        radius: track.radius
    }

    StatusPip {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -2
        anchors.topMargin: -3
        kind: sw.failed ? "amber" : (sw.pending ? "ice" : "off")
        pulse: sw.pending || sw.failed
        z: 8
    }
}
