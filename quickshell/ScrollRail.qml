// ============================================================================
//  ScrollRail.qml — THE scrollbar. There is exactly one in this build.
//
//  WIP-332. Before this file the shell had ~30 scrolling surfaces —
//  Flickables and ListViews in Launcher, Settings, SidePanel, ContextMenu,
//  Widgets, SetPage, SetChoice, SetPageUpdates — and NOT ONE scrollbar. That
//  is not "they fell back to an unstyled default": the shell imports no
//  QtQuick.Controls at all, and a bare Flickable/ListView draws no scroll
//  indicator whatsoever. So every long list in the product scrolled with no
//  indication that there was anything below the fold, and no way to see how
//  far down you were.
//
//  The brief is explicit that every scrolling surface must carry a
//  custom-configured scrollbar with a defined track, thumb size and hover
//  state, matching the GTK and Qt scrollbars exactly. This is the QML end of
//  that contract; `gtk.css` and `qt5ct/qt6ct` carry the same numbers so a
//  GTK app, a Qt app and a Quickshell panel show the same rail.
//
//  ── the shape ──────────────────────────────────────────────────────────────
//  A SLOT WITH A MARK RIDING IN IT — the same object SetSwitch is, at rail
//  scale. Dark well, 1 px glacier[4] seam, a glacier grip inset inside it. On
//  hover or while scrolling the seam lifts to the ice rung, the grip steps up
//  the ladder and a halo ring lights.
//
//  ── TRK-3685 · 2026-09-01 · THE RAIL DID NOT EXIST UNTIL YOU TOUCHED IT ────
//
//  Before this the track was `color: "transparent"`, `border.width: 0` at rest
//  and 3 px wide; only the thumb was drawn. So the resting rail was a bare
//  bright bar floating on nothing — the ONE control in the settings kit with no
//  container at rest. Photographed beside the other five on
//  `docs/proof/controls-0901/before.png`, it is the odd object in the frame:
//  every other control is a dark body with a hairline rim and a mark inside it,
//  and the icon set landed the same day says the same thing at tile scale
//  (`docs/proof/icons-0901/suite-128.png` — matte ground, rim, lit edge, glacier
//  mark). The rail was the only one made of different stuff.
//
//  ⚠ AND THE TOOLKITS WERE ALREADY RIGHT. `gtk.css` has shipped
//  `scrollbar trough { background-color: rgba(79,127,166,0.35) }` — a VISIBLE
//  resting trough — in both the GTK3 and GTK4 copies for as long as the rule has
//  existed. So a GTK app showed a track at rest and the Quickshell panel two
//  inches away showed nothing, which is exactly the toolkit mismatch this file's
//  own header exists to prevent. The QML end was the one out of step, not GTK.
//
//  THE THREE DIVERGENCES, NAMED, because the header claimed they did not exist:
//
//    1. RESTING TRACK.  gtk: visible trough.  qss: `groove: transparent`.
//       qml: transparent.  -> all three now draw a dark well + 1 px seam.
//    2. STATE LADDER.  `qt5ct/qss/nyxus-galaxy.qss` says in a comment that
//       "State is carried by COLOUR in both, through the same three tokens in
//       the same order", and gtk.css and the qss both ship
//       glacier[5] -> glacier[0] hover -> glacier[6] active. The QML thumb was
//       ONE colour in every state. The comment was prose beside a check, and it
//       was false for a third of what it described. The thumb now walks the
//       same three rungs.
//    3. RADIUS.  gtk 10 px, qt 4 px, qml width/2 = 4 px. Three numbers for one
//       shape.  -> all three are 3 px now: the SLAB family SetSwitch's knob
//       moved to on 2026-09-01 (r6 in a 20 px knob = 0.30), not a capsule.
//       A capsule is MOULDED; a slot is CUT, and this is a cut.
//
//  WHAT IS NOT CHANGED, deliberately: `railW` 8, `thumbMin` 32 and `inset` 2 are
//  the mirrored metrics and they do not move, so the GTK `min-width: 12px`
//  arithmetic (12 - 2 - 2 = 8) and the qss `min-height: 32px` stay correct
//  without being touched.
//
//  `trackW` (3) IS GONE. It was the resting hairline width, and it is the one
//  metric neither toolkit ever mirrored — the qss says so in as many words
//  ("My first cut set 3px here … The hairline is a Quickshell affordance; 8px is
//  the cross-toolkit width"). Deleting it removes the divergence rather than
//  documenting it a third time.
//
//  THE WIDTH SWELL IS GONE WITH IT, and that reverses a decision recorded below,
//  so it is argued rather than assumed. § THE THUMB WAS THE RETIRED RUNG chose
//  GEOMETRY as the state step because at the time NO second colour rung was
//  available: `#891955` reached 3:1 at no alpha and `#ae206c` was darker than
//  the resting stop, so a colour step would have been a step DOWN. That
//  constraint died with the 2026-08-19 move to glacier. glacier[0] `#7fe8ff` and
//  glacier[6] `#eefcff` are both BRIGHTER than glacier[5] `#b7e6f2`, both are
//  already the shipped hover/active rungs in the other two toolkits, and none of
//  the three is anywhere near the floor. MEASURED on this rail's own bed —
//  `Theme.glassFill` (alpha 0.46) composited over the darkest 32x8 region of the
//  23 shipped wallpapers (L 0.00084), giving a bed of L 0.00129. Ruler: WCAG 2.x
//  relative luminance, (Lhi+0.05)/(Llo+0.05); component floor 3.00:1, no
//  exemption for the thumb because the thumb is the thing you grab.
//
//      rest   glacier[5] #b7e6f2   L 0.7307   15.22:1   chroma S 0.244
//      hover  glacier[0] #7fe8ff   L 0.6945   14.51:1   chroma S 0.502
//      drag   glacier[6] #eefcff   L 0.9502   19.50:1   chroma S 0.067
//      seam   glacier[4] #4f7fa6   L 0.1959    4.79:1   (exempt; measured anyway)
//
//  ⚠ SAY WHAT THAT TABLE ACTUALLY SHOWS, because the obvious reading is wrong.
//  HOVER IS NOT A LUMINANCE STEP UP — it is 14.51:1 against rest's 15.22:1, i.e.
//  very slightly DARKER. It is a CHROMA step: 0.244 -> 0.502, saturation
//  doubled at equal lightness. That is a legitimate rung change and it is the
//  one StateEdge's own argument asks for ("an alpha ladder can only make focus a
//  BRIGHTER hover, never a DIFFERENT one"), but it is NOT what a reader would
//  assume from "moves up the ramp", so it is written down. Drag is the
//  luminance step, +30%.
//
//  And the state cue is deliberately never colour ALONE: the halo ring appears,
//  and the seam changes hue from glacier[4] steel to the ice rung — the same
//  three-axes-at-once rule SetSwitch's TRK-3645 rim note argues, for the same
//  reason (a hue step survives a glance that an alpha step does not).
//
//  ── B2-c 2026-08-17 · THE THUMB WAS THE RETIRED RUNG, AS A FILL ────────────
//
//  CLASSIFY FIRST, then judge — audit item 23's method, because the two edge
//  ladders have different floors and the whole #891955 story is a divider used
//  as a fill.
//
//    · the TRACK's 1px border is a SEAM (`_tokens.edges.seams.structural`): it
//      divides the rail from the content, carries no state, and is not what
//      identifies the control. WCAG 1.4.11 EXEMPTS it. `Theme.glassBorder`
//      measures 2.30:1 here and that is CORRECT, not a failure — DO NOT LIFT
//      IT. #891955 as a 1px border is precisely the demoted role its own token
//      permits ("1px dividers only").
//    · the THUMB is not a seam at all. It is the control — the thing you grab —
//      so it is a FILL identifying a component, at the 3:1 floor with NO
//      exemption. This is the one distinction that was wrong.
//
//  The thumb rested on `Theme.accentSolidLow`, which is `plumBody` #891955:
//  the rung accent.json demoted to "1px dividers only, NEVER a fill", painting
//  the draggable grip, at opacity 0.55 on top of that. Same defect as
//  Calamares' `QPushButton:default` and as swaync's `scrollbar slider`, in the
//  third toolkit.
//
//  MEASURED, before and after, on this rail's own bed — `Theme.glassFill` over
//  the darkest 32x8 region of any of the 23 shipped wallpapers (L 0.00084):
//
//      rest  #891955 @0.55  1.40:1   ->  #d765a2 @1.0  6.17:1
//      lit   #ae206c @1.0   3.17:1   ->  #d765a2 @1.0  6.17:1
//
//  Two things that look wrong about that and are not:
//
//  1. #891955 IS NOT SALVAGEABLE BY TUNING. Bisected against this bed it
//     reaches 3:1 at NO alpha and over NO ground — solid it is 2.30:1, and
//     compositing only lowers it. There was no opacity that fixed the old
//     value, which is why the value had to change.
//  2. REST AND LIT ARE NOW THE SAME HUE, deliberately. `#ae206c` cannot stay:
//     the owner ruled it measures 2.86-3.04:1 on glass-over-art and no fill
//     alpha rescues it (bisected here: it needs alpha >= 0.976 to hold 3:1 over
//     a bright ground, i.e. opaque). And it was DARKER than the new resting
//     colour, so keeping it would have made hover a step DOWN. Rather than
//     invent a fourth rung, the state step is carried by GEOMETRY, which is
//     what `_tokens.edges.hover_is_a_delta` asks for — "a delta, not a rung …
//     computed from the level below, so it can never collide": the rail swells
//     3px -> 8px and lights the halo ring. Rev 3 section 4.7 makes width the
//     primary cue for exactly this control ("thumb 4px … 6px … 8px").
//
//  ⚠ WHAT THIS DOES NOT FIX, said plainly. On the LIGHTEST realistic ground the
//  floor is unreachable by any palette stop: the brightest 32x8 region in the
//  shipped set is pure white (`nyxus-login-wall.png` @18,593), `Theme.glassFill`
//  at alpha 0.46 barely dents it (bed L 0.264), and #d765a2 measures 1.00:1
//  there. That is a TRANSLUCENCY problem, not a colour problem — bisected, the
//  fill would have to reach alpha 0.759 for #d765a2 to hold 3:1 over white, and
//  the shipped `glassFillStrong` is 0.66. The fills live in `Theme.qml`, which
//  is read-only behind gate 13q45, so this is REPORTED AND OWED, not tuned
//  here. 6.17:1 over the dark ground with the rung's role corrected is the part
//  that was actually in reach.
//
//  ── the crash rule ─────────────────────────────────────────────────────────
//  Every animation here is a Behavior on a property change. Nothing free-runs.
//  A FrameAnimation or a running NumberAnimation inside a Quickshell panel
//  window keeps ticking off the GLOBAL animation timer after the window
//  unmaps, and dereferences a dead node — that is WIP-245's segfault
//  (`addToDirtyList` / `setEffectiveVisibleRecur`). Behaviors only run when a
//  binding changes, so they cannot tick against an unmapped window. Do not
//  replace them with a timer.
// ============================================================================
import QtQuick

Item {
    id: rail

    // The surface being scrolled. ListView and GridView are Flickables, so
    // they attach the same way.
    required property Flickable flick

    // Metrics. These are the numbers gtk.css and qt5ct mirror — change them
    // here and change them there in the same commit, or the toolkit check in
    // the QA list fails by construction.
    readonly property int railW:    Theme.s4          // 8  — the rail, always
    readonly property int thumbMin: Theme.s9          // 32 — never a dot
    readonly property int inset:    Theme.s1          // 2  — off the edge

    // TRK-3685 · the grip sits INSIDE the slot, the way SetSwitch's knob sits
    // inside its track. One inset, so the clearance is equal on both sides by
    // construction and cannot drift apart in a later edit — that is the lesson
    // TRK-3645 wrote into SetSwitch after finding a knob with 3 px above it and
    // 0 below on every switch in the product.
    readonly property int thumbInset: 1
    // Slab, not capsule: 0.375 of the width, the same corner family SetSwitch's
    // knob moved to (r6 in 20 px). At railW 8 that is 3, which is also the
    // number gtk.css and the qss now carry.
    readonly property real slotRadius: 3

    // 2026-08-19 · owner: glacier/ice chrome only, drop rose.
    // Thumb = glacier[5] (same role rose[5] / accentSolidHalo had).
    // Halo 1px = glacier[6] (peak, line only). Track seam = glacier[4].
    readonly property color icePrimary:  Theme.paintLayers.glacier[5]
    readonly property color iceFocus:    Theme.paintLayers.glacier[0]
    readonly property color icePeak:     Theme.paintLayers.glacier[6]
    readonly property color iceHairline: Theme.paintLayers.glacier[4]

    // Only meaningful when there is something to scroll.
    readonly property bool scrollable: flick && flick.contentHeight > flick.height + 1
    readonly property real ratio: scrollable
        ? Math.max(flick.height / flick.contentHeight, 0)
        : 1

    // `moving` covers flick/drag; `hovered` covers the pointer resting on it.
    property bool hovered: false
    readonly property bool lit: hovered || (flick && (flick.moving || dragger.drag.active))
    // The third rung is DRAG specifically, not "lit": a flick and a hover are
    // not the same act as holding the grip, and gtk.css / the qss both give
    // `:active` its own stop. Two toolkits already split it; this makes three.
    readonly property bool grabbed: dragger.pressed || (flick && flick.dragging)

    // ── placement ───────────────────────────────────────────────────────────
    // Declared as a CHILD of the Flickable it serves, and positioned the way
    // this codebase already pins its bottom fades: a Flickable reparents its
    // children into contentItem, so anchoring would ride the content up and
    // off the top. Binding y to `contentY` instead pins the rail to the
    // viewport. One line at each of the ~30 call sites:
    //
    //     ScrollRail { flick: myFlickable }
    //
    width: railW
    z: 6                                     // above the fade (z:5), below menus
    visible: scrollable
    opacity: scrollable ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.durQuick } }

    x: flick ? flick.width - width - inset : 0
    y: flick ? flick.contentY + inset : 0
    height: flick ? flick.height - inset * 2 : 0

    // ── input: the track ────────────────────────────────────────────────────
    // Declared FIRST so the thumb's own handler sits above it. A click on bare
    // track jumps there, the way every other scrollbar in the world behaves.
    // The hit area is wider than the visual rail — a 3px target is a miss, and
    // the brief asks for a real hover state, not a decorative one.
    MouseArea {
        id: hit
        anchors.fill: parent
        anchors.leftMargin: -Theme.s3
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onEntered: rail.hovered = true
        onExited:  rail.hovered = false
        onClicked: function (mouse) {
            const span = rail.height - thumb.height
            if (!rail.scrollable || span <= 0)
                return
            const t = (mouse.y - thumb.height / 2) / span
            flick.contentY = Math.max(0, Math.min(
                t * (flick.contentHeight - flick.height),
                flick.contentHeight - flick.height))
        }
    }

    // ── track · THE SLOT ────────────────────────────────────────────────────
    // TRK-3685 — present at rest, which is the whole change. A dark well plus a
    // 1 px seam, exactly the two-part construction SetSwitch's track uses and
    // exactly what the icon tiles are made of: a ground, an edge, a mark.
    //
    // The well is `void_` at two alphas, the ladder SetSwitch already runs
    // (0.86 off / 0.42 on), read one rung lighter here because a rail sits over
    // CONTENT rather than over a card and must not punch a black stripe through
    // a list. The seam is glacier[4] — that rung's own token permits exactly
    // this and nothing more ("1px dividers only, NEVER a fill"), so it is drawn
    // as a border and is never the `color`.
    Rectangle {
        id: track
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: rail.railW
        radius: rail.slotRadius
        color: Theme.soften(Theme.void_, rail.lit ? 0.42 : 0.62)
        border.width: 1
        // Hue step, not an alpha step — see the header table. Steel at rest,
        // ice when the rail is live.
        border.color: rail.lit ? Theme.soften(rail.iceFocus, 0.72)
                               : Theme.soften(rail.iceHairline, 0.70)
        Behavior on color { ColorAnimation { duration: Theme.durQuick } }
        Behavior on border.color { ColorAnimation { duration: Theme.durQuick } }
    }

    // ── thumb ───────────────────────────────────────────────────────────────
    Rectangle {
        id: thumb
        anchors.horizontalCenter: parent.horizontalCenter
        // TRK-3685 — the grip rides INSIDE the slot instead of being the slot.
        width: track.width - 2 * rail.thumbInset
        radius: Math.max(1, rail.slotRadius - rail.thumbInset)

        height: Math.max(rail.thumbMin, rail.height * rail.ratio)
        y: rail.scrollable
            ? Math.min(Math.max(0, flick.visibleArea.yPosition * rail.height),
                       rail.height - height)
            : 0

        // ⚠ THE GRIP IS INSET HORIZONTALLY AND NOT VERTICALLY, ON PURPOSE.
        // Equal clearance on all four sides is TRK-3645's rule for a knob in a
        // slot, and it is right for a switch because a switch's knob has two
        // parked positions. A scroll thumb's ends are MEANINGFUL: they are "you
        // are at the top" and "you are at the bottom". A 1 px vertical inset
        // would mean a fully-scrolled list never looks fully scrolled, so the
        // thumb runs the full height of the slot and the inset is horizontal
        // only.
        //
        // TRK-3685 — three rungs, the same three gtk.css and the qss have
        // shipped all along. See the header table for the measurement and for
        // what it actually shows (hover is a CHROMA step, not a brightness one).
        color: rail.grabbed ? rail.icePeak
             : rail.lit     ? rail.iceFocus
             :                rail.icePrimary
        Behavior on width   { NumberAnimation { duration: Theme.durQuick } }
        Behavior on color   { ColorAnimation  { duration: Theme.durQuick } }

        // The halo is the same cue the bar and the pills use on hover: the
        // accent's own rung bled outward, never a new colour.
        //
        // ⚠ IT HAD TO MOVE UP THE RAMP WHEN THE THUMB DID. This ring was
        // `accentSolidHalo` #d765a2 against a #ae206c thumb; the thumb is now
        // #d765a2 itself, so the ring and the grip would have been THE SAME
        // COLOUR and the hover cue would have silently disappeared — the halo
        // still drawn, still animating, and invisible. Caught by asking what
        // the change does not cover rather than by looking at it.
        //
        // So it takes the next rung, `tokenAccentPeak` #ffb3d9: 2.03:1 against
        // the thumb it outlines and 12.49:1 against the rail's dark bed. This is
        // the ONE use `_findings.peak_luminance_breach` explicitly sanctions for
        // this colour — it measures relative luminance 0.585 against the 0.45
        // ambient clamp, and the finding's own ruling is that it is "safe as a
        // GLYPH, or a 1px core — a line or a letterform, where the eye
        // integrates almost no area", and unsafe only as a FILLED area. A 1px
        // border is that line. It is never used as a fill anywhere in this file.
        //
        // ⚠ TRK-3685 · AND IT HAD TO MOVE AGAIN WHEN THE THUMB GAINED A DRAG
        // RUNG. The note above is a warning about the halo and the grip
        // colliding, and adding `grabbed -> glacier[6]` to the thumb walked
        // straight back into it: on the drag state the ring and the thing it
        // outlines would BOTH be `#eefcff`, and the cue would disappear at the
        // exact moment the user is holding the control. So the ring steps DOWN
        // to glacier[0] while the thumb is at peak, and the pair is never one
        // colour in any state:
        //
        //     rest    thumb glacier[5]  ring hidden
        //     hover   thumb glacier[0]  ring glacier[6]   (ring above thumb)
        //     drag    thumb glacier[6]  ring glacier[0]   (ring below thumb)
        //
        // Caught the same way the first collision was — by asking what the
        // change does not cover, not by looking at it.
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + Theme.s3
            height: parent.height + Theme.s3
            radius: parent.radius + Theme.s2 / 2
            color: "transparent"
            border.width: 1
            border.color: rail.grabbed ? rail.iceFocus : rail.icePeak
            opacity: rail.lit ? 0.9 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Theme.durQuick } }
            Behavior on border.color { ColorAnimation { duration: Theme.durQuick } }
        }

        // Dragging the thumb scrolls the surface. Lives inside the thumb so it
        // is above `hit`, or a grab would register as a track jump instead.
        //
        // ⚠ Deliberately NOT `drag.target: thumb`. The thumb's `y` is BOUND to
        // flick.visibleArea.yPosition, and QML drops a binding permanently the
        // moment something assigns to that property — which a drag does on
        // every mouse move. The thumb would follow the pointer once and then
        // never track the content again, and it would look like it worked.
        // So the pointer drives contentY and the binding keeps drawing the
        // thumb, which also means the wheel, a flick and the drag can never
        // disagree about where the thumb is.
        MouseArea {
            id: dragger
            anchors.fill: parent
            anchors.margins: -Theme.s2
            hoverEnabled: true
            onEntered: rail.hovered = true
            onExited:  rail.hovered = false

            property real grabDy: 0          // where in the thumb it was grabbed
            onPressed: function (mouse) { grabDy = mouse.y }
            onPositionChanged: function (mouse) {
                const span = rail.height - thumb.height
                if (!pressed || !rail.scrollable || span <= 0)
                    return
                // Thumb-top in rail space, from the pointer, honouring the grab
                // offset so the thumb does not jump under the cursor on press.
                const top = thumb.y + (mouse.y - grabDy)
                flick.contentY = Math.max(0, Math.min(
                    (Math.max(0, Math.min(top, span)) / span)
                        * (flick.contentHeight - flick.height),
                    flick.contentHeight - flick.height))
            }
        }
    }

}
