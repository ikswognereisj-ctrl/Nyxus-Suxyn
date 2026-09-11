// Nyxus Suxyn — a settings BUTTON. The control for things that HAPPEN rather
// than things that are.
//
// "Clear the print queue", "Forget this network", "Reload the shell", "Roll
// back". Three properties carry the weight, and they exist because an action
// button in a control center has three jobs a toggle does not:
//
//   `danger`    the action destroys something or interrupts the session.
//               Owner 2026-08-19 palette roles: MAGMA, not ice and not
//               Theme.danger (errors). magma[5] `#ff7847` is the armed
//               fill; magma[0] `#f7a83b` is the armed label. REQUIRES A
//               SECOND CLICK, in place, with the label changed to say
//               what will happen. Not a modal dialogue: a dialogue is a
//               thing you dismiss reflexively, and the second click on
//               the button you already aimed at is both harder to do by
//               accident and faster to do on purpose.
//
//   `busy`      the action is running. The button says so and stops accepting
//               clicks. A `Process` that takes two seconds with no feedback is
//               indistinguishable from a button that does nothing, and the
//               second click starts it twice.
//
//   `done`      the action finished. Says so for a moment and returns to rest.
//               Set it from the process's `onExited`; it clears itself.
import QtQuick

Item {
    id: btn

    property string text: ""
    property string glyph: ""
    property bool danger: false
    // ── TRK-3645 · THE PAGE NEEDS A PRIMARY ─────────────────────────────
    // Owner ruling 2026-09-01. A Settings page had no way to say which
    // control is the one you came for: "Save changes" (which COMMITS the
    // page) and "Reload shell" (disabled) drew identically at rest, both a
    // transparent face with a glacier seam.
    //
    // `primary` carries `Theme.tokenAccentGround` — the SAME rung SetIceFace
    // already uses for `grounded`, not a new colour invented for buttons.
    //
    // AT MOST ONE PER CARD. Two primaries is not twice the emphasis, it is
    // none: if two controls want it, the page is wrong, not the button.
    // `danger` wins where both are set — a destructive action's warning
    // outranks a page's suggestion, and `_armed` overrides everything.
    property bool primary: false
    property bool busy: false
    property string busyText: "Working…"
    property string doneText: "Done"
    // What the button says when it is asking you to confirm. Say what will
    // happen — "Clear 4 jobs" — never "Are you sure?".
    property string confirmText: "Click again to confirm"

    // `enabled` is INHERITED from Item and used as-is. It was briefly declared
    // here as a new property, which qmllint calls out as shadowing: a second
    // `enabled` would leave the Item's real one true, so the handlers would go
    // on accepting clicks while the button drew itself greyed. That is the
    // ContextMenu class of defect — the property that looks set and is not —
    // and it is why the shadow warning is worth listening to rather than
    // silencing with a `final`.

    // ── MAGMA AT REST · owner ruling 2026-08-24 ──────────────────────────
    // "Destructive actions carry magma at rest, not just once armed. That's
    // your third color family, and it's justified functionally, not just
    // aesthetically." Before this, `danger: true` painted exactly like a safe
    // button until the FIRST of the two taps had already been made — the
    // colour only told you the truth AFTER you had acted on it. Now a
    // destructive button is magma from the moment you can see it.
    //
    // ARMING IS STILL A VISIBLE STEP UP, and it has to be: if resting danger
    // and armed danger collapse into one appearance, the two-tap safety
    // mechanism stops being legible. The ladder is ordered on FOUR axes at
    // once, not one — fill 0.11 → 0.34, edge 0.60 → 0.95 alpha, plus the
    // 1.04 scale snap, the DemiBold weight and the label changing to say what
    // will happen. None of the arming logic moved; only paint was added below
    // it.
    //
    // ONE FAMILY PER CONTROL (`ContextMenu.qml`, 2026-08-19: "ice rest/hover;
    // magma = danger. One family per row — a danger row is magma, not
    // ice+gold"). So on a danger button the WHOLE ladder swaps family: the
    // glacier StateEdge and the glacier swirl are gated off and magma draws
    // rest / hover / focus itself. Focus stays distinguishable from hover the
    // way `ContextMenu`'s own hot rows do it — by SHAPE and rung (a 2 px
    // magma[0] ring against a 1 px magma[5] hairline), not by a second hue,
    // because a second hue here would be the ice+magma mix the ruling names.
    //
    // WHICH RUNGS, AND MEASURED. `_ladder` in `theme/accent.json`: index 4 is
    // the DULLEST rung, "demoted to 1px hairlines only"; 0 and 5 "are where
    // the interface takes its accents". magma[1]–[4] are GROUND and are never
    // the mark here — that is the `#891955` failure `AGENTS.md` records, the
    // dullest rung painting the most-clicked control. Ruler: WCAG 2.x
    // relative luminance, (Lhi+0.05)/(Llo+0.05); mark floor 3:1; bed is the
    // real composite — elevated card body `#071318`, `void_`@0.50 face, then
    // the ember tint, computed not assumed:
    //
    //   state        tint   edge                  mark      mark ratio
    //   rest         0.11   magma[5]@0.60  3.22:1 magma[5]  6.68:1
    //   hover/press  0.20   magma[5]@0.80  4.92:1 magma[0]  8.73:1
    //   focus-vis    0.14   magma[0]@0.78  6.12:1 magma[0]  8.44:1  (2 px)
    //   armed        0.34   magma[5]@0.95  6.57:1 magma[0]  5.33:1
    //   disabled     as rest, at face opacity 0.40, and inert
    //
    // Kept so SetPage* callers (`tone: page.tone`) do not break. TRK-3023:
    // a safe button at rest is no longer a bald void plate — glacier[4] seam,
    // 5 px sheen, 3 px glacier[0] lip. TRK-3060 retints the sheen peak
    // (glacier[6] × tealGlow 0.30); lip stays glacier[0]. Magma numbers
    // do not move.
    property real tone: 0.35
    readonly property color markFocus: Theme.paintLayers.glacier[0]
    readonly property color markSeam: Theme.paintLayers.glacier[4]
    // TRK-3060 — 5 px sheen only: glacier peak toward swirl teal glow.
    // Mix at the call site. Both args are already `property color`.
    readonly property color swirlPeak: Theme.mix(Theme.tokenAccentPeak, Theme.tealGlow, 0.30)
    readonly property color markDanger: Theme.paintLayers.magma[5]
    readonly property color markDangerCap: Theme.paintLayers.magma[0]

    signal clicked()

    property bool _armed: false
    property bool _done: false

    // A destructive button that has not been armed yet. This is the state the
    // ruling is about: it is what the user sees BEFORE the first tap.
    readonly property bool _dangerRest: btn.danger && !btn._armed

    // TRK-3645 — primary paints only when nothing louder is happening.
    // `danger` and `_armed` both outrank it, so a destructive button never
    // acquires an inviting glacier ground by a caller setting both flags.
    readonly property bool _primaryRest: btn.primary && !btn.danger && !btn._armed

    implicitWidth: label.implicitWidth + (glyphText.visible ? glyphText.implicitWidth + Theme.s3 : 0)
                   + 2 * Theme.s6
    // TRK-3645: 28 -> 30. The switch is 26 and the choice chips are 26; a 28
    // px button in a row beside them read as a third, arbitrary height. 30
    // gives the one control that is a TARGET a deliberate 4 px over the
    // controls that are merely readouts, instead of an incidental 2.
    implicitHeight: 30

    readonly property string _label: btn.busy ? btn.busyText
                                   : btn._done ? btn.doneText
                                   : btn._armed ? btn.confirmText
                                   : btn.text

    function press() {
        if (!btn.enabled || btn.busy)
            return;
        if (btn.danger && !btn._armed) {
            btn._armed = true;
            disarm.restart();
            return;
        }
        btn._armed = false;
        disarm.stop();
        btn.clicked();
        DiagnosticBus.logButton(btn.text, btn.danger);
    }

    // An armed dangerous button that is left alone goes back to safe. Four
    // seconds: long enough to read the confirm label and act, short enough
    // that a button armed by a stray click is not still armed when you come
    // back to the window.
    Timer {
        id: disarm
        interval: 4000
        onTriggered: btn._armed = false
    }

    onBusyChanged: {
        // Rising edge into "not busy" means the action completed. `done` is
        // the acknowledgement; it is not a state anyone needs to keep.
        if (!btn.busy && btn._wasBusy) {
            btn._done = true;
            doneClear.restart();
        }
        btn._wasBusy = btn.busy;
    }
    property bool _wasBusy: false

    Timer {
        id: doneClear
        interval: 1600
        onTriggered: btn._done = false
    }

    // Confirmation snap — Theme.curveSnap's job. Local scale, not a veil.
    scale: btn._armed ? 1.04 : 1.0
    transformOrigin: Item.Center
    Behavior on scale {
        NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: face
        anchors.fill: parent
        radius: Theme.r1
        opacity: btn.enabled ? 1.0 : 0.4
        antialiasing: true
        // TRK-3645 — the primary's GROUND. tokenAccentGround is SetIceFace's
        // own `grounded` rung, so the page's one committing action is painted
        // in the language the instrument row at the top already uses.
        color: btn._armed ? Theme.soften(btn.markDanger, 0.34)
             : btn._primaryRest ? Theme.tokenAccentGround
             : Theme.soften(Theme.void_, 0.34)
        // TRK-3023 — safe idle is a 1 px glacier[4] seam (hairline, never a
        // fill). Armed keeps magma@0.95. Danger-rest stays width 0; dangerEdge
        // owns that contour and those alphas do not move.
        border.width: btn._armed ? 1 : (btn.danger ? 0 : 1)
        border.color: btn._armed ? Theme.soften(btn.markDanger, 0.95)
                    : btn.markSeam
        Behavior on color { ColorAnimation { duration: Theme.durQuick } }

        // ── the swirls ───────────────────────────────────────────────
        // `SwirlChip` in `bare` mode — the same tuned paint every other
        // control hosts, never a copy of its constants.
        //
        // ⚠ NEVER WHILE ARMED. `_armed` is the destructive-confirm state and
        // it is magma with a 1 px danger border; a button asking "are you
        // sure" must not also be doing something decorative, and the swirl
        // would fight the one colour on it that carries meaning. Gated off,
        // exactly as StateEdge is.
        //
        // A SetButton is momentary — it has no latched ON — which under the
        // owner's "activate on press or hover, never constantly on" rule is
        // not a limitation: interaction is the whole trigger, so a plain
        // button is as valid a host as a toggle.
        SwirlChip {
            id: btnSwirl
            anchors.fill: parent
            z: 0
            bare: true
            cornerRadius: Theme.r1
            enabled: btn.enabled && !btn.busy
            // ⚠ NEVER ON A DANGER BUTTON EITHER (2026-08-24). Default
            // paint is PaintMood.ramp (same as the Line). Leaving that on
            // a magma control still puts two families on one face. The
            // reason is the same one the armed gate already gives, one
            // tap earlier.
            visible: !btn._armed && !btn.danger
            hostHovered: hov.hovered
            hostPressed: tap.pressed
        }

        // ── THE EMBER GROUND · resting danger ────────────────────────
        // A TINT, never an opaque fill: the same shape as StateEdge's
        // `fillTint` and as the armed fill above it, one rung weaker. It sits
        // under the type scrim so the label keeps its bed.
        Rectangle {
            id: ember
            anchors.fill: parent
            z: 0
            radius: Theme.r1
            visible: btn._dangerRest
            color: Theme.soften(btn.markDanger,
                                (hov.hovered || tap.pressed) ? 0.20
                                : btn.activeFocus ? 0.14 : 0.11)
            Behavior on color { ColorAnimation { duration: Theme.durQuick } }
        }

        // TRK-3023 — hover glacier[3] wash at 0.18. Safe only. Magma hover
        // stays ember 0.20; this must not tint a destroy control ice.
        Rectangle {
            anchors.fill: parent
            z: 1
            radius: Theme.r1
            visible: !btn._armed && !btn.danger && (hov.hovered || tap.pressed)
            color: Theme.soften(Theme.paintLayers.glacier[3], 0.08)
        }

        // Type scrim. Void@0.34 sat ON TOP of the swirl and is why Settings
        // buttons looked dull next to flyout pills. Match TogglePill's light
        // veil so the paint stays the signal.
        Rectangle {
            anchors.fill: parent
            z: 1
            radius: Theme.r1
            visible: !btn._armed && (hov.hovered || tap.pressed)
            color: Theme.soften(Theme.void_, 0.06)
        }

        // TRK-3023 geometry, TRK-3060 colour — inner 5 px sheen along the
        // TOP of the face (glacier peak × tealGlow 0.30), then a 3 px
        // glacier[0] lip under it. Straights only, inset by r1 so the band
        // never enters the corner (GlassEdge TRK-932). Sheen is a sheen,
        // not a fill. Hidden on danger — one family per control.
        Rectangle {
            id: iceSheen
            visible: !btn._armed && !btn.danger
            z: 2
            y: 1
            // 5 px / 0.55 on a 28 px face was a second plate over the
            // swirl (same class as SetSwitch's 4 px / 0.92 band). Scale
            // with height; rest alpha is a rim. Hover can step up.
            height: Math.min(5, Math.max(2, Math.round(parent.height * 0.14)))
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.r1
            anchors.rightMargin: Theme.r1
            // TRK-3685 — capsule ends. The icon set's brow is a rounded bar
            // (docs/proof/icons-0901/suite-128.png); a square-ended band inside
            // a rounded face is what made these crowns read as painted on
            // rather than built in. One line, four controls, one shape.
            radius: height / 2
            color: Theme.soften(btn.swirlPeak,
                                (hov.hovered || tap.pressed) ? 0.40 : 0.22)
        }

        Rectangle {
            id: iceLip
            visible: !btn._armed && !btn.danger
            z: 2
            y: iceSheen.y + iceSheen.height
            height: Math.min(3, Math.max(2, Math.round(parent.height * 0.10)))
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.r1
            anchors.rightMargin: Theme.r1
            radius: height / 2                     // TRK-3685 — capsule ends
            color: Theme.soften(btn.markFocus,
                                (hov.hovered || tap.pressed) ? 0.22 : 0.12)
        }

        // Five states. Idle seam is the face's glacier[4] hairline, so this
        // edge is STATE only — hover / press / focus / done. Danger is magma
        // (palette role), not ice and not Theme.danger (errors) — and since
        // 2026-08-24 that is true AT REST, not only once armed.
        StateEdge {
            z: 2
            hovered: hov.hovered
            focusRing: btn.activeFocus
            pressed: tap.pressed
            checked: btn._done
            controlEnabled: btn.enabled && !btn.busy
            radius: Theme.r1
            // Gated off for danger as well as for armed: its rungs are
            // glacier (stateHover `#b7e6f2`, stateFocus `#7fe8ff`) and a
            // danger control is one family. `dangerEdge` below is this
            // control's edge ladder while `danger` is set. Hidden at idle so
            // it cannot paint glacier[0]@0.22 over the glacier[4] seam.
            visible: !btn._armed && !btn.danger
                     && (hov.hovered || tap.pressed || btn.activeFocus || btn._done)
        }

        // ── THE DANGER EDGE · rest / hover / focus, all in family ────
        // Rest is not a bare seam here. On every other control the resting
        // edge is a SEAM (`seams.idle._role`) and 1.0–1.4:1 is correct for
        // it, because the fill and the label are what identify the control.
        // On this one the edge is carrying STATE — "this action destroys
        // something" — before any input has happened, so it is held to the
        // 3:1 component floor like any other state rung: magma[5]@0.60 is
        // 3.22:1 on the card body, computed above.
        Rectangle {
            id: dangerEdge
            anchors.fill: parent
            z: 2
            radius: Theme.r1
            visible: btn._dangerRest
            color: "transparent"
            antialiasing: true
            // 2 px for focus-visible, 1 px otherwise. The thickness is half
            // the reason focus cannot be mistaken for hover inside one hue
            // family; the rung (magma[0] against magma[5]) is the other.
            border.width: btn.activeFocus ? 2 : 1
            border.color: btn.activeFocus
                          ? Theme.soften(btn.markDangerCap, 0.78)
                          : Theme.soften(btn.markDanger,
                                         (hov.hovered || tap.pressed) ? 0.80 : 0.60)
            Behavior on border.color { ColorAnimation { duration: Theme.durQuick } }
        }

        Row {
            z: 3
            anchors.centerIn: parent
            spacing: Theme.s3

            Text {
                id: glyphText
                anchors.verticalCenter: parent.verticalCenter
                visible: btn.glyph !== "" && !btn.busy
                text: btn.glyph
                font.family: Theme.fIcon
                font.pixelSize: Theme.tLabel
                color: btn._armed ? btn.markDangerCap
                     : btn.danger
                       ? (hov.hovered || tap.pressed || btn.activeFocus
                          ? btn.markDangerCap : btn.markDanger)
                       : (hov.hovered || tap.pressed || btn.activeFocus ? btn.markFocus : Theme.textMuted)
                Behavior on color { ColorAnimation { duration: Theme.durQuick } }
            }

            // The busy mark. One rotating glyph, and it is gated on the
            // WINDOW being visible, not on `busy` alone: an animation left
            // running while the window unmaps is the exact shape of the crash
            // this build already hit once (WIP-245 — a QML item's `visible`
            // does not follow its window, and the animation timer is global).
            Text {
                id: spinner
                anchors.verticalCenter: parent.verticalCenter
                visible: btn.busy
                text: "\uf110"                   // spinner glyph
                font.family: Theme.fIcon
                font.pixelSize: Theme.tLabel
                color: Theme.textMuted
                RotationAnimator on rotation {
                    running: spinner.visible
                             && btn.Window.window !== null
                             && btn.Window.window.visible
                    loops: Animation.Infinite
                    from: 0; to: 360
                    duration: 900
                }
            }

            Text {
                id: label
                anchors.verticalCenter: parent.verticalCenter
                text: btn._label
                // ── TRK-3645 · AN ACTION IS NEVER QUIETER THAN ITS OWN
                // DESCRIPTION. The rest colour here was `Theme.textMuted`,
                // inside a SetRow whose title is `Theme.text` — the button
                // sat one rung BELOW the sentence explaining it, on every
                // Settings page. Rest is now `Theme.text`; hover/press/focus
                // still lift to markFocus, so the interactive step survives.
                //
                // The primary's cap is the accent PEAK against its glacier
                // ground, which is the pairing tokenAccentGround was defined
                // with — never plain `text` on an accent fill.
                color: btn._armed ? btn.markDangerCap
                     : (btn._done ? Theme.text
                        : btn.danger
                          ? (hov.hovered || tap.pressed || btn.activeFocus
                             ? btn.markDangerCap : btn.markDanger)
                          : btn._primaryRest
                            ? Theme.tokenAccentPeak
                            : (hov.hovered || tap.pressed || btn.activeFocus ? btn.markFocus : Theme.text))
                font.family: Theme.fUi
                font.pixelSize: Theme.tLabel
                // The primary carries its weight too — one card, one action
                // in DemiBold, so emphasis is not colour alone (which a
                // colour-blind reader loses entirely).
                font.weight: btn._armed || btn._primaryRest ? Font.DemiBold : Font.Medium
                Behavior on color { ColorAnimation { duration: Theme.durQuick } }
            }
        }
    }

    HoverHandler {
        id: hov
        enabled: btn.enabled && !btn.busy
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        id: tap
        enabled: btn.enabled && !btn.busy
        onTapped: {
            btn.press();
            if (!btn.danger && !btn._armed)
                btnSwirl.ignite();
        }
    }

    activeFocusOnTab: btn.enabled
    Keys.onSpacePressed: btn.press()
    Keys.onReturnPressed: btn.press()
}
