pragma ComponentBehavior: Bound
// Nyxus Suxyn — a Settings ICE OBJECT. The face a page is, not a form row.
//
// Clock has TimeFace, Calendar has IceDay, Hardware has IceInstrument.
// Settings pages that were still a labelled spreadsheet use this instead:
// opaque elevated body `#071318`, seam `#4f7fa6`, 6 px peak sheen
// `#eefcff` over a 3 px glacier[0] lip on the top edge (TRK-3025; the
// 1.0–1.6 px hairline was the Calendar fail), hover `#b7e6f2`, SELECTED
// ground `#0e1f2e` (glacier[3] laid over the body, TRK-2930 below) and
// FOCUS ring glacier[0] `#7fe8ff` — two states, two shapes, see below.
//
// Magma is not this object — destroy stays on SetButton danger.
//
// ⚠ The paragraph above said "SELECTED ground glacier[3] `#274b7a`" until
// 2026-08-24, and had been false since TRK-1784 moved the declaration to
// `Theme.groundFrom`. The ground is declared at ONE place, below; measure
// there, not here.
//
// Canvas paints the stone. Type sits on top so it can elide. A translucent
// fill here is a veil (WIP-783); the body is elevated, not glass-on-glass.
//
// 2026-08-22 - TWO STATES, TWO SHAPES (TRK-1606, SUP ruling under the owner's
// delegation; the owner's standing order is "no purple"). This object used to
// define `lit: selected || activeFocus`, so ON and focus-visible were the SAME
// PIXELS - one ~1.8 px edge stroke - and ~32 Settings pages inherited that. A
// control that was both on AND focused could not say so, and a control that
// was merely focused looked switched on. The build already rules the fix and
// StateEdge already ships it, so nothing is invented here:
//
//   ON / selected / current  ->  a FILLED GROUND, plus the brightest edge and
//                                crown on the ladder. The mechanism is
//                                unchanged and is not up for revision; only
//                                the RUNG of the ground moved, 2026-08-24 -
//                                see TRK-2930 at the ground's declaration.
//   focus-visible            ->  a 2 px OUTER RING in glacier[0] `#7fe8ff`,
//                                drawn outside the body with a 2 px gap. A
//                                contour, never a fill: `accent-peak`'s
//                                luminance finding applies to anything with
//                                area, and a ring has none.
//   hover                    ->  NEITHER. A 5% veil and a brighter seam - no
//                                ground change, no ring. It cannot be mistaken
//                                for either, because it moves neither shape.
//                                (10% until 2026-08-24; see TRK-2930 at the
//                                veil, it collided with the new ground's V.)
//
// The two are independent by construction: `grounded` reads `selected` only,
// `ringed` reads `activeFocus` only, and both can be true at once. They are
// separated by SHAPE (area vs contour), never by a second hue - a second hue
// is exactly the door the purple came through, and gate `13t80` now fails the
// build on the withdrawn hexes. Everything here stays glacier.
//
// One consequence, stated so it is not discovered: the body inset went 1.5 ->
// 4.0 to make room for the outer ring inside the item's own bounds. The plate
// is 2.5 px smaller per side; `implicitHeight` and every Layout hint are
// UNCHANGED, so no page reflows.
//
// And the detail line moves textDim -> textMuted while grounded. That began
// as a floor rescue: on the old bright ground `#a8aecc` measured 4.09:1,
// under the 4.5:1 text floor, and `#c9d0e8` 5.83:1. On the TRK-2930 ground
// `#0e1f2e` both clear it (7.63:1 and 10.88:1), so it is emphasis now, and
// kept. The ground is not allowed to cost the page its text.
import QtQuick
import QtQuick.Layouts

Item {
    id: face

    property string kicker: ""
    property string reading: ""
    // TRK-3428 — optional SEMANTIC ink for the reading only: success while
    // connected/protecting, danger while open. Transparent means "not set"
    // and the face renders exactly as before, so the other thirty-odd hosts
    // are untouched. Never a fill, never a second hue on chrome — this is
    // the one place the state language allows the semantic ladders.
    property color readingTint: "transparent"
    property string caption: ""
    property string detail: ""
    property real fillPct: -1
    property bool selected: false
    // TRK-1781 · ATTENTION. SUP ruling 2026-08-22: the state language is
    // ON = filled ground · FOCUS = 2px outer ring · ATTENTION = a small
    // filled pip at the leading edge, with NO ground and NO ring. Three
    // distinct SHAPES in one hue family — never a second hue, because a
    // second hue is the door the purple came through.
    //
    // It exists because eight call sites were passing `selected` to mean
    // *attention* or *busy* — a notification waiting, a printer out of ink.
    // Under ICEPLATE's filled ground those now read as SWITCHED ON, which
    // is worse than the ambiguity it replaced.
    property bool attention: false
    property bool interactive: false
    property bool compact: false

    signal activated()

    Layout.fillWidth: true
    Layout.leftMargin: Theme.s4
    Layout.rightMargin: Theme.s4
    Layout.topMargin: Theme.s3
    Layout.bottomMargin: Theme.s3
    implicitWidth: 160
    // ── THE HEIGHT IS THE CONTENT'S, NOT A CONSTANT (TRK-3581) ───────────
    // Owner, 2026-08-31: *"more filled up, no empty space."* This was a
    // LADDER OF CONSTANTS — 88 compact / 100 otherwise, +18 for a fill bar,
    // +14 for a detail line — and the plate was given that height whatever it
    // was carrying. MEASURED on the shipped compact face with a kicker and one
    // caption line (Taskbar ▸ CLOCK, `/tmp` frame 2026-08-31): its content
    // column asks for 8 (topMargin) + 9 (kicker) + 4 (spacing) + 18 (caption)
    // + 8 (bottomMargin) = **47 px** and was handed **88** — 41 px of nothing,
    // 47% of the plate. Thirty-four pages build on this file, so that air is
    // most of the emptiness the owner is looking at, and it is not a layout
    // opinion: it is a number the component already knew and threw away.
    //
    // `col` anchor-fills the face, so its `implicitHeight` is computed from
    // its children's implicit sizes and NOT from the height it is given —
    // there is no cycle here. Widths flow down, heights flow up.
    //
    // A FLOOR, not just the content. A plate is a touch target and a member of
    // a list, and a 34 px row beside a 56 px `SetRow` reads as a mistake. 44 /
    // 56 are `SetRow`'s own two heights (its `dense` ternary), so a card mixing
    // rows and plates keeps one rhythm. The lens `reading` carries its own
    // 32 px minimum through `col` and needs no term here.
    // `col`'s anchor margins are OUTSIDE its implicitHeight — a ColumnLayout
    // reports what its children ask for, not what its anchors then inset — so
    // the 2 × s4 is added here rather than assumed.
    readonly property int _faceH:
        Math.max(face.compact ? 44 : 56,
                 Math.ceil(col.implicitHeight) + 2 * Theme.s4)
    implicitHeight: face._faceH
    Layout.preferredHeight: face._faceH
    activeFocusOnTab: face.interactive
    Accessible.role: face.interactive ? Accessible.Button : Accessible.StaticText
    // The ground is a state, so it is reported as one. A separation that only
    // exists in pixels is not a separation for someone using a screen reader.
    Accessible.checkable: face.interactive
    Accessible.checked: face.grounded
    Accessible.name: {
        var bits = [face.kicker, face.reading, face.caption, face.detail]
                    .filter(function (s) { return s && s !== ""; });
        return bits.join(" · ");
    }

    readonly property color iceElevated: Theme.elevated
    readonly property color iceSeam:     Theme.lookSeam
    readonly property color icePeak:     Theme.paintLayers.glacier[6]
    readonly property color iceHover:    Theme.paintLayers.glacier[5]
    readonly property color iceFocus:    Theme.paintLayers.glacier[0]
    readonly property color iceVoid:     Theme.void_

    // The selected/pressed GROUND. Taken off paintLayers so a repaint of the
    // layer carries it, exactly as the seam and hover rungs above already do.
    // Gate 13x80 reads THIS line and requires `Theme.paintLayers` on it, so
    // the ground's provenance is visible where the ground is declared rather
    // than one indirection away.
    //
    // TRK-2930, 2026-08-24 - THE RUNG CAME DOWN. Owner, on Settings > System >
    // Display: "that blue-ish colour, I feel like that much of seeing it
    // doesn't look right in the build."
    //
    // MEASURED on docs/proof/blue-audit-0824/display.png and
    // docs/proof/selfill-0824/*-before.png, as the modal colour of each
    // region, not a point sample:
    //
    //     selected ground   #3b6590   S 0.59   V 0.565      <- was
    //     idle plate body   #071318   S 0.71   V 0.094      6.0x darker
    //     sibling cards     #06070b            V 0.043     13.1x darker
    //     page background   #020507            V 0.027
    //
    // A ground 6x lighter than the plate it sits in, over ~4.7% of the window
    // in one unbroken block, stops being an accent and becomes a SECOND
    // BACKGROUND - and this build has one background language: dark ground,
    // light edges. It is the `#891955`-as-a-fill failure exactly (AGENTS.md):
    // membership in the ramp was never the violated property, the USE was.
    // glacier[3] is a mid rung; mid rungs live in edges, seams and small
    // marks.
    //
    // THE FIX IS A RUNG, NOT A MECHANISM. AGENTS_TRACKING standing ruling 2 -
    // "ON/selected = filled ground" - is untouched: the ground is still a
    // fill, still opaque, still the whole body. It is now the plate body
    // itself carried 22% toward glacier[3], the ramp stop whose declared role
    // IS the selected ground (Theme.tokenAccentDeep, "the pressed / selected
    // ground"). Same ramp, same role, lower rung - no new hue, no second
    // family, TRK-2818 disposition C.
    //
    //     new ground        #0e1f2e   S 0.69   V 0.179   H 207
    //       vs idle body    1.9x  (was 6.0x)
    //       vs sibling card 4.2x  (was 13.1x)
    //
    // ⚠ AND THE 3:1 COMPONENT FLOOR MOVED WITH IT, deliberately. TRK-1784
    // raised this stop to clear 3:1 against the plate as a FILL. At this rung
    // the fill is 1.13:1 on the body and cannot carry that floor, so the
    // BOUNDARY carries it instead and had to get brighter to do so: the
    // selected edge is glacier[6] `#eefcff` at 15.92:1 on this ground, 1.8 px,
    // against an idle seam of 4.41:1 at 1.2 px. See the edge ladder in the
    // Canvas. If this ground is ever darkened further, the edge is what has to
    // answer for it - never lighten the fill back.
    //
    // Text over the new ground, recomputed, all clearing the 4.5:1 text floor:
    // caption `#edf1ff` 14.82:1, kicker `#b7e6f2` 12.42:1, detail `#c9d0e8`
    // 10.88:1 (was 5.83:1), `#a8aecc` 7.63:1 (was 4.09:1, under floor).
    //
    // ⚠ NOT Theme.groundFrom / Theme.tokenAccentGround any more. That stop is
    // still correct for `StateEdge`, which uses it at 22% ALPHA on controls
    // the size of a word - a tint, not a slab. StateEdge is out of this lane's
    // fence and is unchanged; its selected segment already measures #04090c
    // V 0.047 in the body with the edge doing the work, which is the surface
    // that was RIGHT on the same page and is why this fix is shaped this way.
    // ⚠ Qt.color() FIRST. `paintLayers.glacier[n]` entries are hex STRINGS;
    // Theme.mix reads `.r` off its arguments, and `.r` on a string is
    // undefined -> NaN -> a BLACK ground with no error anywhere. Theme's own
    // `groundFrom` carries this same warning and the same Qt.color() call.
    // `Theme.elevated` is already a color property and needs no conversion.
    readonly property color iceGround:   Theme.mix(Qt.color(Theme.paintLayers.glacier[3]),
                                                   Theme.elevated, 0.78)

    // -- the two states, kept apart on purpose ---------------------------
    // Read `grounded` and `ringed` and nothing else. They are deliberately
    // NOT combined into one boolean: the whole defect this file is fixing was
    // a single boolean standing for two different states.
    readonly property bool grounded: face.selected
    readonly property bool ringed:   face.interactive && face.activeFocus
    // Independent of both, by construction: a plate can want attention
    // whether or not it is on, and whether or not it has focus.
    readonly property bool pipped:   face.attention
    property bool hovered: false

    // -- THE SWIRL'S LIFETIME ----------------------------------------------
    // Settings loads ONE page at a time (`Settings.qml` pageLoader). A
    // hover-only Loader meant the owner opened Appearance / Notifications
    // and saw ice slabs with no paint until they hunted with the pointer —
    // "still only a few". Interactive faces load the chip with the page.
    // Readouts still never load one. Solver still freezes after linger
    // unless the face is selected (`liveWhileLatched`).
    signal paintIgnite()
    signal paintWake()

    readonly property color trackTint: {
        var p = face.fillPct;
        if (p < 0)
            return face.iceSeam;
        if (p < 60)
            return face.iceSeam;
        if (p < 80)
            return face.iceHover;
        return face.iceFocus;
    }

    function _rr(ctx, x, y, w, h, r) {
        r = Math.max(0, Math.min(r, w / 2, h / 2));
        ctx.beginPath();
        ctx.moveTo(x + r, y);
        ctx.arcTo(x + w, y, x + w, y + h, r);
        ctx.arcTo(x + w, y + h, x, y + h, r);
        ctx.arcTo(x, y + h, x, y, r);
        ctx.arcTo(x, y, x + w, y, r);
        ctx.closePath();
    }

    // ── THE READOUT GROUND IS THE WIDGET STACK (TRK-3365) ────────────────
    // Owner 2026-08-28: "every page needs to match the same … the colors the
    // same as the widgets." 34 pages build on this file, and its readout
    // body was the one surface still a FLAT `Theme.elevated` fill while the
    // window, hub tiles and cards all wear the two-layer widget material.
    // `SetSlab` (the one place that stack is declared) now seats under the
    // Canvas; the Canvas keeps every STATE it drew — selected ground, hover
    // veil, the three-rung edge ladder, pip, focus ring — and simply stops
    // flat-filling the idle body. Interactive faces are untouched: they
    // already wear the TogglePill stack (well + swirl), which is its own
    // ruled language. `seam: false` because this Canvas draws the seam
    // ladder itself, at state-dependent rungs SetSlab cannot know.
    SetSlab {
        visible: !face.interactive
        anchors.fill: parent
        anchors.margins: 4
        z: 0
        cornerRadius: 14
        seam: false
    }

    Canvas {
        id: plate
        anchors.fill: parent
        z: 1
        onPaint: {
            var ctx = getContext("2d");
            var w = plate.width, h = plate.height;
            ctx.reset();
            if (w < 8 || h < 8)
                return;
            // Body inset 4.0 leaves the outer 0..2 band for the focus ring
            // and a 2 px gap between the two, so the ring reads as a ring and
            // not as a thicker edge. Both ring edges land on whole logical
            // pixels (0 and 2), which is whole device pixels at 1x AND at 2x -
            // a 2 px stroke centred on a half-pixel is where this goes ugly.
            var pad = 4.0;
            var cw = w - 2 * pad;
            var ch = h - 2 * pad;
            var rad = 14;

            // -- STATE 1 - THE GROUND. `grounded` and nothing else. --------
            // Interactive faces paint their well as a Rectangle UNDER the
            // swirl (TogglePill stack: fill, then paint, then rim). Filling
            // here would sit ON the paint and dull it — that was Settings
            // "bright and dull". Readouts still fill the ice plate.
            // TRK-3365: idle readouts no longer flat-fill — the SetSlab
            // beneath carries the widget stack. Only the SELECTED ground
            // still fills, at its ruled rung. The ternary looks degenerate
            // under the guard and is load-bearing: 13x80 derives the GROUND
            // DRIVER from this exact line (`fillStyle = String(face.X ?`),
            // and `grounded` is that driver — selected only, never focus.
            if (!face.interactive && face.grounded) {
                face._rr(ctx, pad, pad, cw, ch, rad);
                ctx.fillStyle = String(face.grounded ? face.iceGround
                                                     : "transparent");
                ctx.fill();
            }

            // Hover is NEITHER state: a veil over whichever ground is there,
            // so it can never promote an off plate into an on one.
            //
            // TRK-2930: 0.10 -> 0.05, and this is the ONE number the darker
            // ground forced outside itself. COMPUTED, not eyeballed: a 0.10
            // veil of glacier[5] over the idle body lands at #19282e, V 0.180
            // - which is EXACTLY the V of the new selected ground. At the old
            // ground (V 0.565) hover could not be mistaken for selected; at
            // this one it could, and "hover can never promote an off plate
            // into an on one" has to keep being true after the rung moves.
            // At 0.05 the ordering is restored and is monotonic, which is the
            // property worth having: idle #071318 V 0.094 < hovered #101d22
            // V 0.133 < selected #0e1f2e V 0.180 < selected+hovered #131f2c.
            // Hover loses nothing it was carrying - its real signal is the
            // seam jumping glacier[4] -> glacier[5], 3.17:1 apart, plus the
            // swirl field igniting under the pointer.
            // Interactive: skip the veil. It would sit on the paint.
            if (face.hovered && !face.interactive) {
                face._rr(ctx, pad, pad, cw, ch, rad);
                ctx.fillStyle = String(Theme.soften(face.iceHover, 0.05));
                ctx.fill();
            }

            // The body seam, and THE EDGE LADDER - one ramp, three rungs,
            // TRK-2930. Deliberately does NOT carry focus any more: focus is
            // the outer ring below, in a different hue rung and a different
            // shape.
            //
            //     idle      glacier[4] #4f7fa6   1.2 px   4.41:1 on the body
            //     hover     glacier[5] #b7e6f2   1.4 px
            //     SELECTED  glacier[6] #eefcff   1.8 px  15.92:1 on the ground
            //
            // Selected used to paint the SAME edge as hover - glacier[5] at
            // 1.4 - because the slab was doing all the work and the boundary
            // had nothing to say. With the ground down at V 0.179 the edge IS
            // the signal, so it takes the top rung and the widest stroke.
            // Three rungs of one ramp separate three states; a second hue
            // is the door the purple came through. The TRK-3025 6+3 top
            // strip is gone (TRK-3056 / owner 10:03); this rim is not it.
            var edge = face.grounded ? face.icePeak
                     : (face.hovered ? face.iceHover : face.iceSeam);
            var lw = face.grounded ? 1.8 : (face.hovered ? 1.4 : 1.2);
            face._rr(ctx, pad, pad, cw, ch, rad);
            ctx.lineWidth = lw;
            ctx.strokeStyle = String(edge);
            ctx.stroke();

            // -- STATE 3 - THE PIP. `attention` and nothing else. ----------
            // A filled dot at the leading edge. No ground, no ring, no change
            // to the seam: the SHAPE is the signal, so it cannot be confused
            // with on-ness however many of the three are true at once. Peak
            // rung, because a pip is small and has to survive being small.
            if (face.pipped) {
                ctx.beginPath();
                ctx.arc(pad + 7, pad + ch / 2, 2.5, 0, Math.PI * 2);
                ctx.fillStyle = String(face.icePeak);
                ctx.fill();
            }

            // -- STATE 2 - THE OUTER RING. `ringed` and nothing else. ------
            // Drawn last so it is never veiled by the body, and drawn whether
            // or not the plate is grounded - a plate that is BOTH on and
            // focused shows a filled ground AND a ring, which is the whole
            // point of the ruling.
            if (face.ringed) {
                var rw = 2.0;
                var ro = rw / 2;                 // centre the stroke on 0..2
                face._rr(ctx, ro, ro, w - rw, h - rw, rad + (pad - ro));
                ctx.lineWidth = rw;
                ctx.strokeStyle = String(face.iceFocus);
                ctx.stroke();
            }
        }
    }

    Rectangle {
        visible: face.interactive
        anchors.fill: parent
        anchors.margins: 4
        z: 0
        radius: 14
        color: Theme.soften(Theme.void_, face.grounded ? 0.34 : 0.82)
        Behavior on color { ColorAnimation { duration: Theme.durQuick } }
    }

    // -- the swirls -------------------------------------------------------
    // `SwirlChip` in `bare` mode — the same tuned paint the flyout pills
    // host (PaintMood.ramp). Rest-visible: selected faces keep moving
    // (`liveWhileLatched`); idle faces freeze a full field. Hover/press
    // still wake and ignite.
    //
    // GEOMETRY FOLLOWS THE CANVAS, NOT THE ITEM. The plate is drawn inset by
    // `pad` 4.0 with corner radius 14, leaving the outer band for the focus
    // ring.
    Loader {
        id: faceSwirl
        anchors.fill: parent
        anchors.margins: 4
        z: 0
        active: face.interactive && Prefs.swirlEnabled
        sourceComponent: SwirlChip {
            id: faceChip
            bare: true
            cornerRadius: 14
            enabled: face.interactive
            active: face.selected
            liveWhileLatched: true
            hostHovered: face.hovered
            hostPressed: iceTap.pressed

            Connections {
                target: face
                function onPaintIgnite(): void { faceChip.ignite(); }
                function onPaintWake(): void { faceChip.wake(); }
            }
        }
    }

    ColumnLayout {
        id: col
        anchors.fill: parent
        z: 1
        anchors.leftMargin: Theme.s5
        anchors.rightMargin: Theme.s5
        anchors.topMargin: Theme.s4
        anchors.bottomMargin: Theme.s4
        spacing: Theme.s2

        Text {
            visible: face.kicker !== ""
            Layout.fillWidth: true
            text: face.kicker
            color: face.iceHover
            font.family: Theme.fUi
            font.pixelSize: Theme.tMicro
            font.weight: Font.DemiBold
            font.letterSpacing: Theme.trackMicro
            elide: Text.ElideRight
            clip: true
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.s4

            Item {
                visible: face.reading !== ""
                Layout.preferredWidth: lensBox.implicitWidth
                Layout.preferredHeight: lensBox.implicitHeight
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    id: lensBox
                    anchors.centerIn: parent
                    implicitHeight: Math.max(32, lensTxt.implicitHeight + 12)
                    implicitWidth: Math.max(implicitHeight, lensTxt.implicitWidth + 28)
                    radius: height / 2
                    color: Theme.soften(face.iceFocus, 0.16)
                    border.width: 1.6
                    border.color: face.iceFocus

                    Text {
                        id: lensTxt
                        anchors.centerIn: parent
                        text: face.reading
                        color: face.readingTint.a > 0 ? face.readingTint
                                                      : face.icePeak
                        font.family: Theme.fUiTitle
                        font.pixelSize: face.compact ? Theme.tHead : Theme.tTitle
                        font.weight: Font.DemiBold
                        clip: true
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    visible: face.caption !== ""
                    Layout.fillWidth: true
                    text: face.caption
                    color: Theme.text
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tBody
                    wrapMode: Text.WordWrap
                    maximumLineCount: face.compact ? 2 : 3
                    elide: Text.ElideRight
                    clip: true
                }

                Text {
                    visible: face.detail !== ""
                    Layout.fillWidth: true
                    text: face.detail
                    // Was 4.09:1 over the OLD #3b6590 ground as textDim, under
                    // the 4.5:1 text floor, which is why this branch exists.
                    // On the TRK-2930 ground #0e1f2e both clear it - textDim
                    // 7.63:1, textMuted 10.88:1 - so the branch is now
                    // emphasis rather than a floor rescue, and is kept for
                    // that. Measured, not adjusted by eye.
                    color: face.grounded ? Theme.textMuted : Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    clip: true
                }
            }
        }

        Item {
            visible: face.fillPct >= 0
            Layout.fillWidth: true
            Layout.preferredHeight: 10

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: face.iceVoid
                border.width: 1
                border.color: face.iceSeam
            }

            Rectangle {
                id: fillPill
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: {
                    var p = Math.max(0, Math.min(100, face.fillPct));
                    var w = parent.width;
                    var h = parent.height;
                    if (p <= 0)
                        return 0;
                    return Math.min(w, Math.max(h, w * p / 100.0));
                }
                radius: height / 2
                color: Theme.soften(face.trackTint, 0.88)

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: parent.radius
                    anchors.rightMargin: parent.radius
                    height: 1
                    color: Theme.soften(face.icePeak, 0.32)
                }
            }
        }
    }

    HoverHandler {
        enabled: face.interactive
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: {
            face.hovered = hovered;
            plate.requestPaint();
            if (hovered)
                face.paintWake();
        }
    }

    TapHandler {
        id: iceTap
        enabled: face.interactive
        onTapped: {
            face.forceActiveFocus();
            face.activated();
            face.paintWake();
            face.paintIgnite();
        }
    }

    Keys.onReturnPressed: function (e) {
        if (face.interactive) {
            face.activated();
            e.accepted = true;
        }
    }
    Keys.onSpacePressed: function (e) {
        if (face.interactive) {
            face.activated();
            e.accepted = true;
        }
    }

    onGroundedChanged: plate.requestPaint()
    onRingedChanged: plate.requestPaint()
    onPippedChanged: plate.requestPaint()
    onHoveredChanged: plate.requestPaint()
    onWidthChanged: plate.requestPaint()
    onHeightChanged: plate.requestPaint()
    Component.onCompleted: plate.requestPaint()
}
