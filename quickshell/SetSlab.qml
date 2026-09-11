pragma ComponentBehavior: Bound
// Nyxus Suxyn — THE SETTINGS SLAB. One material, and it is OPAQUE. TRK-3310.
//
// ══ why this file exists ═══════════════════════════════════════════════════
// Owner, 2026-08-28, looking at the merged Settings redesign on TTY1: *"it
// gets real see through especially on top of other things"*, and, sending a
// full-size capture of his own desktop widgets, *"this is how it all should
// look"*.
//
// Both sentences are about one defect and this component is the fix. Before
// it, four files each rolled their own card face — the Settings window body,
// `SetCard`, the utility hub's slabs and the notifications flyout's — and
// every one of them was built on ALPHA. A translucent card is invisible as a
// defect on a black wallpaper, which is the only place the desktop widgets
// are ever seen, and obvious the moment a Settings window is dragged over a
// terminal. MEASURED on his own capture
// (`nyxus-mockups-2026-08-27/CURRENT-settings-too-transparent.png`): terminal
// text and the desktop clock read straight THROUGH the window body.
//
// ══ THE RECIPE IS STILL TWO LAYERS. THAT IS THE POINT ══════════════════════
// The obvious fix is wrong and the app lane has already proved it on the GTK
// side: replacing the stack with ONE flat fill of the composited result
// cannot blend, so every edge, glaze and swell in the material dies with it.
// So this keeps the widgets' exact stack and puts an OPAQUE FLOOR under it:
//
//   0 · `Theme.elevated`  #071318   an opaque Rectangle. NEW. This is the
//                                   whole fix — nothing behind the slab can
//                                   reach the eye, whatever is behind it.
//   1 · `Theme.panelMid`  α 0.34    Start's paint (`Launcher.qml` Pane
//                                   `id: card`), unchanged.
//   2 · `swellGround`     0.84 / 0.89 / 0.93   the ramp, unchanged.
//   3 · `GlassEdge`       body: 0   turning `body` on is the documented
//                                   "dark box on the wallpaper" failure
//                                   (WIP-259) and it stays off.
//   4 · `glacier[4]`      #4f7fa6   a 1 px seam, the rung's allowed role.
//
// ══ THE ARITHMETIC, so the claim is not a hope ═════════════════════════════
// `elevated` #071318 is (0.0275, 0.0745, 0.0941). Compositing 1 over 0:
//
//   panelMid  0.34·(0.010,0.026,0.034) + 0.66·elevated
//             = (0.02155, 0.05801, 0.07367)
//
// then the swell over that:
//
//   crown  0.84·(0.006,0.014,0.020) + 0.16·(above) = (0.0085,0.0210,0.0286)
//                                                  → #020507
//   foot   0.93·(0.004,0.008,0.014) + 0.07·(above) = (0.0052,0.0115,0.0182)
//                                                  → #010305
//
// and the owner's reference capture
// (`REFERENCE-this-is-how-it-should-look.png`) measures the widget card
// interior at **#020306 … #030e14** and its meter groove at **#04090a**.
// Same colour as before the fix — and now 0% transmittance where the old
// stack passed 0.66 × 0.16 ≈ **10.6%** of whatever was behind it.
//
// BEFORE / AFTER, for the property the claim names (backdrop transmittance
// through a Settings surface, at the crown):  **10.6% → 0.0%**.
//
// ══ what this is NOT ═══════════════════════════════════════════════════════
// Not a new token. `Theme.elevated`, `Theme.panelMid` and the three
// `swellGround` stops are exactly the values already in `Theme.qml`; nothing
// here invents a colour, lightens `elevated`, or introduces a second hue.
//
// ══ ONE WINDOW (TRK-3260) ══════════════════════════════════════════════════
// This is a plain `Item`. It declares no `Window`, no `PanelWindow` and no
// `FloatingWindow`, and every use of it is a child of the Settings window's
// own surface. The v1 redesign crashed the owner's shell five times with
// `QQuickItem: Cannot use same item on different windows at the same time`
// because its side panels were layer surfaces — separate windows — sharing
// items with the Settings window. Nothing in this file or its consumers can
// re-make that: there is only ever one window in play.
import QtQuick

Item {
    id: slab

    property int cornerRadius: Theme.r2
    // The elevation the Pane rim is drawn at. 1 is a card inside a surface;
    // 2 is the surface itself.
    property int level: 1
    // Hover lifts the SAME rim rather than adding an outline — `Pane.qml`
    // §4.4, "never a blue outline".
    property bool lifted: false
    // A slab that is the window's own body wants no seam of its own; a card
    // sitting on that body does.
    property bool seam: true

    // ── THE FLOOR'S RUNG · TRK-3745 ──────────────────────────────────────
    // Owner, 2026-09-06, on his own screenshots: *"i dont want it looking like
    // one solid colors it needs deffition"*, and *"create the look in those
    // places with different layers and shaders to get different looks like how
    // i did with the widgets but keep the widget look the main"*.
    //
    // THE DEFECT THIS PARAMETER FIXES, MEASURED. `docs/DESIGN_DEPTH_2026-09-06`
    // rule 1 says a raised surface must be visibly raised, and the build ships
    // three rungs for it: void #020506, surface #040b0e, elevated #071318.
    // Settings was using TWO of them. Its window body's floor was `elevated`
    // and every `SetCard`'s floor is also `elevated`, so a card and the panel
    // it sits on differed by **ΔRGB (0,0,0)** — the eye has nothing to
    // separate them with and reads one sheet with lines drawn on it, which is
    // exactly the diagnosis he made of Monitor.
    //
    // ⚠ THIS IS A PARAMETER ON THE ONE MATERIAL, NOT A SECOND MATERIAL. The
    // stack above is untouched: same Pane, same swell, same GlassEdge, same
    // MirrorEdge, same seam. Only the rung the whole thing composites against
    // moves. Hand-rolling a second card face is the failure this component was
    // created to end (four files each with their own recipe, WIP-259's dark
    // card on a dark card, TRK-3275's duplicated `.card`), and varying a dial
    // is the documented alternative — the bar does exactly this with
    // `GlassEdge`'s glaze/edging/bleed.
    //
    // ⚠ IT IS NOT DERIVED FROM `level`, DELIBERATELY. `level` is the Pane rim's
    // elevation and Settings' hub tiles animate it on hover
    // (`level: hovered ? 2 : 1`). Binding the floor to it would DARKEN a tile
    // as the pointer arrives, which is backwards, so the two are separate
    // knobs and a caller says which it means.
    //
    // Default `Theme.elevated` — a card. A surface that CONTAINS cards passes
    // `Theme.surface`, and the window under both stays `Theme.void_`.
    //
    // BEFORE / AFTER for the property the claim names (the value step between a
    // Settings card and the panel it sits on):  **ΔRGB (0,0,0) → (3,8,10)**.
    property color ground: Theme.elevated

    default property alias content: inner.data

    // ── 0 · THE OPAQUE FLOOR ────────────────────────────────────────────
    // `Theme.elevated` carries no alpha. Everything above it is the widgets'
    // own translucent stack, blending against this instead of against the
    // terminal behind the window.
    // ⚠ CutRect, NOT Rectangle, and the reason is the chamfer. This floor is
    // OPAQUE and sits UNDER the Pane, so if it stayed a rounded Rectangle
    // while the Pane cut its corners, the floor would show through the
    // triangle the cut removes — an opaque notch at every corner of every
    // card. At cut 0 it draws exactly what the Rectangle drew (measured to
    // ZERO differing pixels, scripts/verify-cutrect.py).
    CutRect {
        anchors.fill: parent
        radius: slab.cornerRadius
        // `slab.ground`, defaulting to Theme.elevated — see its declaration.
        // Still one rung of the shipped ladder, still carrying no alpha, so
        // the 10.6% → 0.0% transmittance result above is unchanged whichever
        // rung a caller names.
        color: slab.ground
    }

    // ── 1 · Start's paint ───────────────────────────────────────────────
    Pane {
        id: ground
        anchors.fill: parent
        elevation: slab.level
        radius: slab.cornerRadius
        fill: Theme.panelMid
        focusLevel: slab.lifted ? 0.45 : 0
        Behavior on focusLevel { NumberAnimation { duration: Theme.durQuick } }

        // ── 2 · the widgets' swell, unchanged ───────────────────────────
        // ⚠ The swell is the layer that MOST needs cutting, because it is
        // ABOVE the Pane: a rounded gradient here paints straight over the
        // cut corner, so the chamfer would not merely be missed, it would be
        // erased on every card in the build.
        CutRect {
            anchors.fill: parent
            radius: slab.cornerRadius
            gradTop:  Theme.swellGroundTop
            gradMid:  Theme.swellGroundMid
            gradFoot: Theme.swellGroundFoot
        }

        // ── 3 · the edge ────────────────────────────────────────────────
        // `body: 0`. A GlassEdge body stacked on a surface that already has
        // one reads as a dark card on a dark card, and that failure is in
        // this build's history once already (WIP-259).
        GlassEdge {
            anchors.fill: parent
            radiusTL: slab.cornerRadius; radiusTR: slab.cornerRadius
            radiusBR: slab.cornerRadius; radiusBL: slab.cornerRadius
            body: 0
            wash: 0
            glaze: slab.lifted ? 0.62 : 0.42
            edging: slab.lifted ? 0.66 : 0.46
            bleed: 0.55
            Behavior on glaze { NumberAnimation { duration: Theme.durQuick } }
            Behavior on edging { NumberAnimation { duration: Theme.durQuick } }
        }

        MirrorEdge {
            radiusTL: slab.cornerRadius; radiusTR: slab.cornerRadius
            radiusBR: slab.cornerRadius; radiusBL: slab.cornerRadius
            depth: 12
            strength: slab.lifted ? 0.85 : 0.62
            Behavior on strength { NumberAnimation { duration: Theme.durQuick } }
        }
    }

    // ── 4 · the seam ────────────────────────────────────────────────────
    // 1 px, glacier[4] — the rung whose own token says hairlines only, never
    // a fill. The reference capture measures a widget card's left edge at
    // #0b0d0f…#14191c, which is this rung at low alpha over the ground.
    // ⚠ The seam is the CARD'S OUTLINE — the one line the eye follows around
    // the corner — so a rounded hairline over a cut card is the "dark spur"
    // failure DESIGN_LANGUAGE_NYXUS_GLASS rule 3 names, drawn in the most
    // visible place available. CutRect strokes it inset by half the width, so
    // at cut 0 it lands on the same pixels the Rectangle border did (7
    // differing px on the straight runs, measured).
    CutRect {
        anchors.fill: parent
        visible: slab.seam
        radius: slab.cornerRadius
        color: "transparent"
        borderWidth: 1
        borderColor: Theme.soften(Theme.paintLayers.glacier[4],
                                  slab.lifted ? 0.85 : 0.45)
        Behavior on borderColor { ColorAnimation { duration: Theme.durQuick } }
    }

    Item { id: inner; anchors.fill: parent }
}
