// Nyxus Suxyn — a quick-settings toggle.
//
// HORIZON §4.3/§4.4: on is not "filled with the accent colour", it is LIT —
// the Pane's rim goes to full sweep intensity and the body warms slightly.
// Off is the same object with the light turned down. One state, one physical
// difference, no second design.
//
// 2026-08-05: that rule was right and the execution was too quiet to read.
// A lit pill differed from a dark one by a rim and a slightly bluer fill, so
// a grid of six of them looked like six identical dark rectangles and you had
// to read the word "On" under each label to know the state of your own
// machine. Now an active toggle also POOLS LIGHT under itself and carries a
// wash in the body — the same treatment the dock icons and the pinned tiles
// get, so "this thing is live" looks the same everywhere in the build. Still
// no flat accent fill anywhere.
//
// 2026-08-19 · KEY PLACES ONLY (owner). Chrome is glacier/ice, not rose:
// glacier[0] `#7fe8ff` on focus/hover, glacier[5] `#b7e6f2` on active.
// Owner 19:10: drop rose — magenta+teal on the same chip mixed muddy olive.
// Swirls stay on their own layer. `tone` stays on the API; it does not paint.
import QtQuick
import QtQuick.Layouts

Item {
    id: pill
    property string label: ""
    property string sub: ""
    property string icon: ""
    property bool active: false
    // Kept for callers (SidePanel still passes a sweep position). Chrome
    // no longer follows it — owner 2026-08-19: colour in key places only,
    // glacier/ice, not a different hue per pill.
    property real tone: 0.35
    signal toggled

    // TRK-2401 · the 2026-08-22 mockup draws `.tpill` at h56 / r14, two lines
    // of 12 + 10 on a 12 px inset. It was 62 with 10 + 9 type, which is why a
    // grid of them read as captions rather than as controls. The Pool sits in
    // the bottom 4, so the Pane is 52 and the two text lines (12 * 1.2 +
    // 10 * 1.2 = 27) clear it with room on both sides.
    Layout.fillWidth: true
    Layout.preferredHeight: 56
    opacity: pill.enabled ? 1.0 : 0.4

    readonly property color markOn: Theme.stateLayer[5]
    readonly property color markFocus: Theme.stateLayer[0]
    // TRK-3045 — 4 px sheen only: glacier peak toward swirl teal glow.
    // Mix at the call site. Both args are already `property color`.
    readonly property color swirlPeak: Theme.mix(Theme.tokenAccentPeak, Theme.tealGlow, 0.30)

    Pool {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: 22
        tone: pill.active ? pill.markOn : pill.markFocus
        focusRatio: 0.55
        strength: !pill.enabled ? 0
                : (tap.pressed ? 1.0
                : (pill.active ? 0.8 : (hov.hovered ? 0.3 : 0)))
    }

    Pane {
        anchors.fill: parent
        anchors.bottomMargin: 4
        elevation: 1
        radius: Theme.r2
        // TRK-3022 — OFF was void@0.50, same dark plate as every idle
        // neighbour. Deeper well so the ice facet above it reads as a cut
        // chip, not six identical rectangles. ON stays 0.34 (lit, open).
        fill: Theme.soften(Theme.void_, pill.active ? 0.34 : 0.82)
        focusLevel: !pill.enabled ? 0
                  : (tap.pressed ? 0.70
                  : (pill.active ? 1.0 : (hov.hovered ? 0.35 : 0.0)))

        // Settings Home tiles: lift the chip, never Item.scale.
        transform: Translate {
            y: hov.hovered && pill.enabled ? -2 : 0
            Behavior on y {
                NumberAnimation {
                    duration: Theme.durQuick
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveRise
                }
            }
        }

        // The pill is a CHIP of the build's glass, not a rounded rectangle
        // that happens to sit on it. `edging` is what GlassEdge documents for
        // exactly this — an inline card is a chip of the same glass, not
        // another slab — so the Lip and Sheen stay quieter than a Swell's and
        // the pill never competes with the panel hosting it.
        //
        // The edge is present in BOTH states on purpose. §4.3's rule is one
        // object with the light turned up or down, so what changes with
        // `active` is how much light stands in the pane, not whether the pane
        // is made of glass. A pill that gained an edge only when lit would be
        // two different objects.
        GlassEdge {
            anchors.fill: parent
            radiusTL: Theme.r2
            radiusTR: Theme.r2
            radiusBR: Theme.r2
            radiusBL: Theme.r2
            wash: 0
            edging: !pill.enabled ? 0.22
                  : (tap.pressed ? 0.95
                  : (pill.active ? 0.80 : (hov.hovered ? 0.52 : 0.30)))
            glaze:  !pill.enabled ? 0.18
                  : (tap.pressed ? 0.85
                  : (pill.active ? 0.70 : (hov.hovered ? 0.45 : 0.28)))
            Behavior on edging { NumberAnimation { duration: Theme.durQuick } }
            Behavior on glaze  { NumberAnimation { duration: Theme.durQuick } }
        }

        // ── THE SWIRLS · the reason this control exists in this palette ──
        // Owner, 2026-08-23: "there suppose to be swirls inside them"; and
        // then, on being shown the static version: "thats why we built the
        // mock up swirl button so why didnt we use it and apply it to this
        // build." Both correct. `SwirlChip` had been built, previewed and
        // then left instantiated nowhere, and the recolour that followed
        // painted this pill flat while sitting in the very file the paint was
        // meant to live in.
        //
        // ⚠ IT IS `SwirlChip` ITSELF, IN `bare` MODE — NOT A COPY OF ITS
        // SWIRL BLOCK. That block carries a dozen tuned constants
        // (impulseRadius, exposure, bloom, injectGain, ambientDye, ambientAmp,
        // the wake policy). Pasting them here and again into SetSwitch would
        // put one material in three files, which is the exact drift that
        // produced "the bar is rose and the flyout is glacier" — the thing
        // the shared ramp layer was introduced to end. One tuned paint, three
        // hosts.
        //
        // UNDER the wash and the content, over the Pane: the paint is light
        // inside the chip, not a sheet laid on top of it, and the label must
        // stay readable across it (accent.json _swirl rule 5 — colour never
        // goes behind text).
        SwirlChip {
            id: swirl
            anchors.fill: parent
            anchors.margins: 1
            z: 0
            bare: true
            cornerRadius: Math.max(0, Theme.r2 - 1)
            active: pill.active
            enabled: pill.enabled
            hostHovered: hov.hovered
            hostPressed: tap.pressed
            liveWhileLatched: true
        }

        // ── the content scrim ────────────────────────────────────────
        // §4.2's layer stack, at pill scale: body → paint → SCRIM → content.
        // The bar has carried one of these for exactly this reason; the pill
        // did not need one while its ON state was a flat wash, and needs one
        // now that a live field runs under the label.
        //
        // Sized to the TYPE, not to the pane: transparent at the very bottom
        // where the Pool's light comes up and there is nothing to read, and
        // thickening through the two text lines. That direction is the one
        // Bar.qml had to correct — the first cut of its scrim was heaviest at
        // the top "because the type lives there", and measurement showed it
        // does not.
        //
        // ⚠ It is ABOVE the paint and BELOW the RowLayout, which is what
        // makes it a scrim rather than a veil (WIP-783): it is bounded by the
        // pill, it exists to make text legible, and nothing is hidden beneath
        // it that anyone needs to inspect.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.r2
            visible: pill.active || hov.hovered || tap.pressed
            gradient: Gradient {
                GradientStop { position: 0.00; color: Theme.soften(Theme.void_, 0.05) }
                GradientStop { position: 0.72; color: Theme.soften(Theme.void_, 0.06) }
                GradientStop { position: 1.00; color: Theme.soften(Theme.void_, 0.0) }
            }
        }

        // The wash. Only present when the toggle is on, and only at the top
        // corner, so the body under the label stays dark enough to read
        // against (accent.json _swirl rule 5: colour never goes behind text).
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.r2
            visible: pill.active || hov.hovered || tap.pressed
            // TRK-2989: a full-strength wash over a frozen field is why
            // latched pills looked faint next to the bar. Tint, do not cover.
            opacity: tap.pressed ? 0.22 : (pill.active ? 0.0 : 0.28)
            Behavior on opacity { NumberAnimation { duration: Theme.durQuick } }
            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: Theme.soften(pill.active ? pill.markOn : pill.markFocus, 0.24)
                }
                GradientStop { position: 1.0; color: Theme.shelfNone }
            }
        }

        // TRK-3022 — cut ice chip. 1px crowns failed the Calendar lesson.
        // Sibling Rectangles around SwirlChip (knobs untouched). Peak sits
        // on the pane, lip directly under it. Inset Theme.r2 so the bands
        // stay on the straight, same as GlassEdge / Settings Home.
        //
        // ── TRK-3685 · THREE CONTROLS COMPUTED THIS BAND, ONE HARD-CODED IT ──
        // SetButton, SetChoice's dropdown and SetSwitch all derive the crown
        // from the body's height — `min(5, round(h * 0.14))` for the sheen and
        // `min(3, round(h * 0.10))` for the lip. This one wrote 4 and 3 flat.
        // On a 52 px pane that is proportionally the THINNEST crown in the kit
        // while sitting on the LARGEST face: 0.14 * 52 = 7, clamped to the
        // shared ceiling of 5, so the pill was drawing 4 where its own family
        // rule asks for 5. Not a big number, and exactly the kind of drift that
        // makes a grid of controls read as "close but not the same object".
        //
        // The other two changes are the ones you actually see:
        //   · `y: 0` -> `y: 1`. It sat ON the Pane's top edge and covered it.
        //     Every sibling starts at 1, INSIDE the rim, and the icon tiles do
        //     the same thing — the tile's rim is visible above the brow, which
        //     is what makes the brow look inlaid instead of stuck on.
        //   · capsule ends. The icons' brow is a rounded bar; a square-ended
        //     band inside a rounded body is the tell.
        Rectangle {
            id: pillSheen
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.r2
            anchors.rightMargin: Theme.r2
            y: 1
            height: Math.min(5, Math.max(2, Math.round(parent.height * 0.14)))
            radius: height / 2
            color: Theme.soften(pill.swirlPeak,
                                !pill.enabled ? 0.22
                                : (tap.pressed ? 0.95
                                : (pill.active ? 0.90
                                : (hov.hovered ? 0.48 : 0.30))))
            // ── TRK-4141 · THE BROW WAS LIT WHETHER OR NOT ANYTHING WAS ON ──
            // Owner, 2026-09-15, on the theme reading same-y everywhere.
            // Measured the flyout brows straight off a screenshot:
            //
            //   Wi-Fi    ON   R235 G153 B79   lum 160
            //   Airplane OFF  R161 G106 B53   lum 116
            //
            // Same hue, 1.45x apart — which is this ladder's 0.90 over 0.62.
            // Brightness alone is the weakest channel there is, so eight tiles
            // in a grid all wore what looked like the same lit brow and the
            // state had to be read off the word "Off" in 11 px type.
            //
            // It was worse on the way past: hover was 0.82 against active's
            // 0.90. Hovering an OFF tile lit its brow to within 9% of ON, so
            // the pointer made things look like they had switched on.
            //
            // Idle 0.62 -> 0.30 and hover 0.82 -> 0.48. Active is untouched at
            // 0.90, so ON does not get dimmer — OFF gets quieter, which is the
            // half of the pair that was lying.
            //
            // Measured back off the same screenshot afterwards, mean luminance
            // across the whole brow band rather than its peak row:
            //
            //   ON    153.9 -> 154.0   (unmoved, as intended)
            //   OFF   105.4 ->  73.1   (-31%)
            //   ratio  1.46x -> 2.11x
            //
            // Not the 3x the alphas imply — soften() composites over a lit
            // ground, so the floor never reaches the alpha ratio. 2.11x is the
            // number that is actually on screen.
            //
            // This also takes five of the eight brightest ember bars out of
            // the flyout, which is most of the repetition the owner was
            // seeing: the ember that is left is on the tiles that earned it.
            //
            // The cool lip below keeps its own ladder — hue AND brightness now
            // both report state, so the pair survives a bad angle or a
            // washed-out panel where either alone would not.
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.r2
            anchors.rightMargin: Theme.r2
            y: pillSheen.y + pillSheen.height
            height: Math.min(3, Math.max(2, Math.round(parent.height * 0.10)))
            radius: height / 2
            color: Theme.soften(pill.markFocus,
                                !pill.enabled ? 0.12
                                : (tap.pressed ? 0.55
                                : (pill.active ? 0.48
                                : (hov.hovered ? 0.42 : 0.32))))
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.s5
            anchors.rightMargin: Theme.s5
            spacing: Theme.s4

            // TRK-2407 — the mockup is explicit: `.tpill .ic{flex:0 0 auto}`.
            // The icon never gives up width; the LABEL is what elides. This
            // had no width hint at all, so it took its implicit size and the
            // layout was free to squeeze it once the label went from 10 to
            // the mockup's 12 (TRK-2401) and "Do Not Disturb" stopped fitting
            // a 148 px half-pill. A floor plus a centred alignment is the
            // 20 px column the mockup draws.
            Text {
                Layout.preferredWidth: Theme.s7
                Layout.minimumWidth: Theme.s7
                horizontalAlignment: Text.AlignHCenter
                text: pill.icon
                font.family: Theme.fIcon
                font.weight: Font.Black
                font.pixelSize: Theme.tHead
                color: pill.active || hov.hovered || tap.pressed ? pill.markFocus : Theme.textMuted
                Behavior on color { ColorAnimation { duration: Theme.durQuick } }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: pill.label
                    color: pill.active ? Theme.text : Theme.textMuted
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tLabel      // TRK-2401 — mockup `.tt` 12
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                }
                Text {
                    Layout.fillWidth: true
                    text: pill.sub
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption    // TRK-2401 — mockup `.ss` 10
                    elide: Text.ElideRight
                }
            }
        }
    }

    HoverHandler { id: hov; enabled: pill.enabled; cursorShape: Qt.PointingHandCursor }
    // The press IGNITES the paint, which is the owner's original ask read
    // literally: "so when you press it the swirls activate". `ignite()`
    // replays the intro and drops paint in the middle — a chip that has been
    // asleep has nothing in it for a lone drop to fold against.
    TapHandler {
        id: tap
        enabled: pill.enabled
        onTapped: {
            pill.toggled();
            swirl.ignite();
        }
    }

    activeFocusOnTab: pill.enabled
    Keys.onSpacePressed: pill.toggled()
    Keys.onReturnPressed: pill.toggled()

    // Focus-visible contour hugs the Pane (bottomMargin 4), not the Pool.
    // Interactive rung, 1 px, no area — never glacier[4] as a fill.
    Rectangle {
        anchors.fill: parent
        anchors.bottomMargin: 4
        color: "transparent"
        visible: pill.activeFocus && pill.enabled
        border.width: 1
        border.color: Theme.soften(pill.markFocus, 0.55)
        radius: Theme.r2
    }
}
