pragma ComponentBehavior: Bound
// Nyxus Suxyn — a settings SLIDER.
//
// Same two modes as `SetSwitch`: bind it to a store key and it saves itself,
// or drive it and answer `moved`. A slider adds two things a switch does not
// need, and both exist because of how sliders are actually used:
//
//   `live`      whether dragging emits continuously or only on release.
//               ON for anything you judge by eye or ear while you move it —
//               volume, text size, pointer speed. OFF for anything whose
//               application costs something (a resolution change, a command
//               per step), because a continuous drag would fire it sixty
//               times a second. The store's own write is debounced either
//               way, so `live: true` is not a file-write storm; it is a
//               binding storm, which is a different budget.
//
//   `snap`      step size. 0 is continuous. A slider with no step is why
//               people end up with a text scale of 1.0374.
//
// The readout is part of the control, not a label next to it. A slider whose
// value you cannot read is a guess, and "boring details" is the standard here:
// a font-size slider that does not say "14 pt" has not done its job.
import QtQuick

Item {
    id: sld

    property string key: ""
    // Log this name on the diagnostic bus without binding the store.
    property string logAs: ""
    property real defaultValue: 1.0

    property real from: 0.0
    property real to: 1.0
    property real snap: 0.0

    property real value: sld.key !== ""
                         ? SettingsStore.numberValue(sld.key, sld.defaultValue)
                         : sld.defaultValue

    property bool live: true

    // How the number is shown. Return a string; the default prints sensible
    // precision rather than "0.6000000000000001".
    property var format: function (v) {
        var span = Math.abs(sld.to - sld.from);
        if (sld.snap >= 1 || span >= 50)
            return String(Math.round(v));
        return v.toFixed(2);
    }

    property string suffix: ""
    // Kept so SetPage* callers (`tone: page.tone`) do not break. Paint is
    // the SliderRow light-bar: primary fill, interactive cap. Never sweepAt.
    property real tone: 0.35
    readonly property color markOn: Theme.paintLayers.glacier[5]
    readonly property color markFocus: Theme.paintLayers.glacier[0]
    readonly property color markPeak: Theme.paintLayers.glacier[6]
    readonly property color markHairline: Theme.lookSeam

    signal moved(real value)
    signal released(real value)

    implicitWidth: 200
    implicitHeight: 32
    opacity: sld.enabled ? 1.0 : 0.4

    readonly property real _span: Math.max(1e-6, sld.to - sld.from)
    readonly property real _frac: Math.max(0, Math.min(1, (sld._shown - sld.from) / sld._span))

    function _quantise(v) {
        var c = Math.max(sld.from, Math.min(sld.to, v));
        if (sld.snap > 0)
            c = sld.from + Math.round((c - sld.from) / sld.snap) * sld.snap;
        return Math.max(sld.from, Math.min(sld.to, c));
    }

    // TRK-3462: `_commit` used to do `sld.value = q`, and a JS assignment
    // DESTROYS the `value:` binding — the default store binding in key-bound
    // mode, the host's own (`value: Sys.volume`) in driven mode. After the
    // first touch the slider stopped following anything: a Reset of the page,
    // a volume moved by the media keys, brightness moved from the flyout —
    // none of them moved the handle again until the page was reloaded.
    // The fix is an OVERLAY: while interacting, `_pending` is what is shown;
    // the binding underneath is never written to. It reconciles the moment
    // the bound value changes, or after a short settle when it does not —
    // so the control ends on the truth, not on the wish.
    property real _pending: 0
    property bool _overlay: false
    readonly property real _shown: sld._overlay ? sld._pending : sld.value

    onValueChanged: { sld._overlay = false; overlaySettle.stop(); }

    Timer {
        id: overlaySettle
        interval: 400
        repeat: false
        onTriggered: sld._overlay = false
    }

    function _commit(v, final) {
        var q = sld._quantise(v);
        if (q === sld._shown && !final)
            return;
        sld._pending = q;
        sld._overlay = true;
        overlaySettle.restart();
        if (sld.key !== "" && (sld.live || final))
            SettingsStore.setValue(sld.key, q);
        if (sld.live || final)
            sld.moved(q);
        if (final) {
            sld.released(q);
            DiagnosticBus.logSlider(sld.logAs !== "" ? sld.logAs : sld.key, q, sld.from, sld.to);
        }
    }

    // ── the readout ─────────────────────────────────────────────────────
    Text {
        id: readout
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: sld.format(sld._shown) + sld.suffix
        color: drag.active || hov.hovered || sld.activeFocus
               ? sld.markFocus : Theme.textMuted
        font.family: Theme.fNum
        font.pixelSize: Theme.tLabel
        horizontalAlignment: Text.AlignRight
        // Reserved width, so the track does not breathe in and out by a pixel
        // every time the number gains or loses a digit. Measured from the
        // widest string the range can produce, not guessed.
        width: Math.max(34, metrics.width)
        Behavior on color { ColorAnimation { duration: Theme.durQuick } }

        TextMetrics {
            id: metrics
            font: readout.font
            text: sld.format(sld.to) + sld.suffix
        }
    }

    // ── the track ───────────────────────────────────────────────────────
    Item {
        id: trackArea
        anchors.left: parent.left
        anchors.right: readout.left
        anchors.rightMargin: Theme.s5
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height

        // ── TRK-3685 · THE GROOVE JOINS THE SLOT FAMILY ──────────────────
        // This control was explicitly left alone on 2026-09-01 while
        // SetSwitch, SetButton and SetChoice were rebuilt, so it is the one
        // still speaking the older dialect. Two things, both measurable:
        //
        //   · IT WAS A CAPSULE. `radius: height / 2` = 7 in a 14 px groove,
        //     i.e. 0.50 of the height. SetSwitch's TRK-3645 ruling moved the
        //     kit off that on the owner's treatment-C green light — its slot
        //     is r9 in 26, 0.346, "deliberately short of h/2 … a capsule is
        //     MOULDED, a slot is CUT". 14 * 0.346 = 4.8 -> 5. Same family,
        //     same arithmetic, not a new number.
        //   · IT HAD NO SEAM. Every other control in the kit carries a 1 px
        //     glacier[4] hairline at rest; this one carried GlassEdge's
        //     `edging` and nothing else, so the groove had no boundary of its
        //     own against the card. glacier[4] as a 1 px border is precisely
        //     the role its token permits ("1px dividers only, NEVER a fill"),
        //     and it steps hue to the ice rung when the control is live — the
        //     same hue-not-alpha step SetSwitch's rim note argues for, because
        //     a hue step survives a glance that an alpha step does not.
        Rectangle {
            id: rail
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 14
            readonly property real slotRatio: 0.346      // SetSwitch's 9/26
            radius: Math.round(height * slotRatio)       // 5
            color: Theme.shelfDeep
            antialiasing: true
            border.width: 1
            border.color: drag.active || hov.hovered || sld.activeFocus
                          ? Theme.soften(sld.markFocus, 0.72)
                          : Theme.soften(sld.markHairline, 0.70)
            Behavior on border.color { ColorAnimation { duration: Theme.durQuick } }

            SwirlChip {
                anchors.fill: parent
                z: 0
                bare: true
                cornerRadius: rail.radius
                hostHovered: hov.hovered
                hostPressed: drag.active
            }

            // Same 14 px light-bar as SliderRow: GlassEdge glaze 0 because a
            // thin groove already has a body; the Lip would BE the track.
            GlassEdge {
                anchors.fill: parent
                radiusTL: rail.radius
                radiusTR: rail.radius
                radiusBR: rail.radius
                radiusBL: rail.radius
                edging: drag.active || sld.activeFocus ? 0.70 : (hov.hovered ? 0.52 : 0.45)
                glaze: 0.0
                wash: 0
            }

            // Inner well — the cut inside the glass. 4 px at the top of the
            // groove, above GlassEdge so the sheen cannot hide it. Not a
            // 1 px hairline (Calendar: 2 px was invisible).
            //
            // ⚠ THIS IS DELIBERATELY DARK WHERE EVERY OTHER CONTROL'S TOP BAND
            // IS BRIGHT, and that is not a mismatch — it is the same physics
            // read correctly. A button, a chip and a pill are slabs standing
            // PROUD of the card, so light from above catches their top face and
            // the crown is a highlight. A groove is CUT INTO the card, so the
            // same light leaves its top inner wall in shadow. Inverting this to
            // match the others would make the slider look raised, which is the
            // one thing a track must not look. The bright band on this control
            // is the fill's catch-light below, and it appears as the value does
            // — form carrying state, which is the rule.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.leftMargin: rail.radius
                anchors.rightMargin: rail.radius
                anchors.topMargin: 1
                height: 4
                radius: height / 2
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: Theme.soften(Theme.void_, 0.55)
                    }
                    GradientStop { position: 1.0; color: Theme.shelfNone }
                }
            }

            Item {
                anchors.fill: parent
                clip: true

                Rectangle {
                    id: fill
                    // ── TRK-3685 · THE FLOOR WAS LYING ABOUT THE VALUE ──────
                    // It was `Math.max(rail.height, …)` = a 14 px minimum. On
                    // the 230 px track this specimen draws, a slider reading
                    // "0%" painted 14/230 = 6.1% of the groove lit — the number
                    // said nothing and the picture said six percent. The floor
                    // exists so the leading cap stays visible and grabbable at
                    // the bottom of the range, and the cap is 5 px wide with a
                    // 1 px shoulder either side, so 7 is what that actually
                    // needs. 7/230 = 3.0%. Measured before and after on the
                    // property the change is about: lit fraction at value 0,
                    // 6.1% -> 3.0%, with the cap still drawn.
                    width: Math.max(7, Math.min(1, sld._frac) * rail.width)
                    // TRK-3730 polish · the fill GLIDES to a click-to-jump,
                    // a keyboard step or a Reset — but never during a drag,
                    // where it must track the finger with no lag. `enabled:
                    // !drag.active` is the whole trick.
                    Behavior on width {
                        enabled: !drag.active
                        NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutCubic }
                    }
                    height: parent.height
                    radius: rail.radius
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0.0
                            color: Theme.soften(sld.markOn, 0.55)
                        }
                        GradientStop { position: 1.0; color: sld.markOn }
                    }

                    // 4 px glacier[6] catch-light along the TOP of the fill.
                    // TRK-3685 — capsule ends and a 1 px shoulder, so it is the
                    // same brow shape SetButton, SetChoice and TogglePill now
                    // draw and the same one the icon tiles carry. This is THIS
                    // control's crown: it is on the lit part, so its LENGTH is
                    // the value. State by form.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: 1
                        anchors.rightMargin: 1
                        anchors.topMargin: 1
                        height: 4
                        radius: height / 2
                        gradient: Gradient {
                            GradientStop {
                                position: 0.0
                                color: Theme.soften(sld.markPeak, 0.90)
                            }
                            GradientStop { position: 1.0; color: Theme.shelfNone }
                        }
                    }

                    // The cap IS the handle — leading edge of the light,
                    // interactive rung, no generic white knob.
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5
                        height: parent.height - 4
                        // TRK-3685 — 2.5 was a capsule on a 5 px bar. The kit's
                        // knob family is 0.30 of the short side (SetSwitch r6 in
                        // 20), so 1.5. A slab cap, like every other mark.
                        radius: 1.5
                        color: sld.markFocus
                        opacity: 0.92
                    }
                }
            }
        }

        // Step ticks, but only when there are few enough to mean something.
        // Twenty ticks is texture; five is information.
        Repeater {
            model: (sld.snap > 0 && sld._span / sld.snap <= 12)
                   ? Math.round(sld._span / sld.snap) + 1 : 0
            delegate: Rectangle {
                required property int index
                width: 2
                height: 2
                radius: 1
                color: sld.markHairline
                x: (rail.width - 2) * (index / Math.max(1, Math.round(sld._span / sld.snap)))
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 10
            }
        }

        HoverHandler { id: hov; enabled: sld.enabled; cursorShape: Qt.PointingHandCursor }

        // Click anywhere on the track jumps there; then keep dragging from
        // that point. Windows and macOS both do this and the alternative —
        // click does nothing unless you hit the 13 px knob — is the single
        // most irritating slider behaviour there is.
        TapHandler {
            enabled: sld.enabled
            onTapped: function (point) {
                sld._commit(sld.from + (point.position.x / trackArea.width) * sld._span, true);
            }
        }

        DragHandler {
            id: drag
            enabled: sld.enabled
            target: null
            xAxis.enabled: true
            yAxis.enabled: false
            onCentroidChanged: {
                if (!drag.active)
                    return;
                sld._commit(sld.from
                            + (drag.centroid.position.x / trackArea.width) * sld._span,
                            false);
            }
            onActiveChanged: if (!drag.active) sld._commit(sld._shown, true)
        }
    }

    // Keyboard: arrows step, Home/End go to the ends. The step is `snap` where
    // one is declared, otherwise a hundredth of the range — a continuous
    // slider still has to be nudgeable.
    activeFocusOnTab: true
    readonly property real _kbStep: sld.snap > 0 ? sld.snap : sld._span / 100
    Keys.onLeftPressed:  sld._commit(sld._shown - sld._kbStep, true)
    Keys.onRightPressed: sld._commit(sld._shown + sld._kbStep, true)
    Keys.onPressed: function (e) {
        if (e.key === Qt.Key_Home) { sld._commit(sld.from, true); e.accepted = true; }
        else if (e.key === Qt.Key_End) { sld._commit(sld.to, true); e.accepted = true; }
    }

    StateEdge {
        hovered: false
        focusRing: sld.activeFocus
        pressed: drag.active
        checked: false
        controlEnabled: sld.enabled
        radius: Theme.r1
        activeFillAlpha: 0
    }
}
