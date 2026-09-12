// Nyxus Suxyn — the desktop widgets (WIP-140 §4, v4 · TRK-3042).
//
// Six chips on the desktop: clock, vitals, sticky note, calendar, weather,
// now-playing.
//
// ── FOUR RULINGS ON THE MATERIAL, EACH SUPERSEDING THE FACE NOT THE PHOTO ──
// All four are recorded here on purpose. A ruling that changes must leave
// its predecessor legible, or the next reader re-derives the reversal from
// nothing and re-makes the mistake it was guarding against.
//
//   2026-08-20 · THE ICE LOCK (superseded for these six cards)
//     Owner: chrome is glacier ice objects, "not a glass Pane + GlassEdge
//     veil" and not a `Theme.sweep0` `#0aa2d6` fill. Under it sat a
//     MEASUREMENT, not a preference: WIP-259 photographed exactly that
//     treatment on exactly these cards and it read as A DARK BOX ON THE
//     WALLPAPER. From 08-20 until 08-24 this file drew its own opaque ice
//     plate on a `Canvas` — `Theme.elevated` face, glacier[4] seam,
//     glacier[6] crown hairline.
//
//   2026-08-24 · THE FLYOUT RULING (superseded for the FACE, 08-25)
//     Owner, verbatim: "the widgets still dont look like the flyout from
//     clicking on the clock on the bottom bar". That took the Clock popup's
//     EDGE onto a still-opaque `Theme.elevated` face, with `GlassEdge.body`
//     held at 0. The Clock popup's own `body: 1` measures L 7.6 vs these
//     cards' L 16.8 — copying that body wholesale IS WIP-259.
//
//   2026-08-25 · MATCH START (TRK-3042; crown superseded by TRK-3056)
//     Owner, 09:26: widgets are an opaque ice slab (`Theme.elevated`
//     `#071318`) while Start is dark black glass. The face now takes
//     Start's recipe (`Launcher.qml` Pane `id: card`): `fill: Theme.panelMid`
//     (alpha 0.34), a swellGround Rectangle UNDER the paint
//     (Top/Mid/Foot 0.84 / 0.89 / 0.93), `GlassEdge.body` still **0**.
//     Crown was the wave 7/8 6 px sheen + 3 px lip (owner 10:03 took
//     that strip off). Turning `body` on is still the dark-box photograph.
//     ⚠ READ THAT SENTENCE AS THE COMPLAINT IT IS (TRK-3606). "widgets
//     are an opaque ice slab" is the owner describing the DEFECT he was
//     looking at, not a requirement that they be opaque — the ruling is
//     the clause after it, dark black glass like Start. A 2026-08-31
//     brief quoted this line as an opacity ruling and asked for the
//     faces to be sealed; doing that re-makes exactly what he
//     complained about here.
//
//   2026-08-25 · STRIP THE CROWN (current · TRK-3056)
//     Owner 10:02/10:03: dark glass is good. The whitish strip on top of
//     every plate is the 6 px glacier[6] `#eefcff` iceSheen + 3 px iceLip.
//     Those two Rectangles are gone. Keep panelMid + swellGround +
//     GlassEdge.body 0. GlassEdge edging (bar language faint sheen) stays.
//
// WHAT SURVIVES EVERY REVERSAL: WIP-259's photograph. It was a measurement
// and it is still true, so it is the acceptance bar rather than a
// prohibition — the test is not "has a Pane", it is "reads like Start
// AND does not read as a dark box", and the second half is still a
// NUMBER. `WidgetChip`'s material block carries how that is satisfied
// (short version: Start's FACE, `GlassEdge.body` held at 0 — the popup's
// own face measures L 7.6 to these cards' 16.8, so copying `body: 1`
// wholesale is what would have re-made WIP-259). Before/after luminance
// per card for the 08-24 edge pass: docs/proof/widgets-pane-0824/.
//
// ── WHAT v2 CHANGED, AND WHY ────────────────────────────────────────────
// Owner 2026-08-24: "they're plain as can be right now … make them so
// they're more useful and wanted to be used. make them real widgets."
//
// The defect was never the material. It was that six cards wore ONE
// treatment and each showed one or two facts, while the data they wanted
// was already published one property away:
//
//   · `Sys.qml` publishes cpuPercent, memPercent/memText, gpuPercent/Text,
//     diskPercent/Text, netPercent/Text, tempC/tempText, fanPercent/Text
//     and uptimeText — LIVE, at zero added cost, because `BorderPulse.qml`
//     latches `Sys.ambientVitals` true at shell start and has since
//     2026-08-09. The vitals chip read TWO of them (battery, volume).
//   · `MonthCalendar.qml` is a finished Monday-first month grid reading the
//     same `Reminders` store — the calendar chip printed one date string.
//   · `nyxus-lock-weather` caches `cond`, `sub` and real `sunrise`/`sunset`
//     minutes. The weather chip read `big` and `line`, and `line` RESTATES
//     `big` ("23°" over "Sunny · 23°C"), which VOICE_AND_COPY §0 rule 5
//     bans outright.
//   · `MediaSource.qml` (TRK-2600..2604) is the canonical MPRIS view and
//     carries position, length, seek and a source label. This file was
//     still calling `Sys.player` directly.
//   · `MediaGlyph.qml` (TRK-2605) is "the one icon family, as geometry",
//     and its own header names Nerd Font private-use transport codepoints
//     as the violation it exists to end. This file drew U+F048 / U+F04B /
//     U+F04C / U+F051 / U+F001. They are gone.
//
// So v2 changes LAYOUT, DENSITY, CONTENT and HIERARCHY and does not touch
// the material: same `Theme.elevated` face, same glacier[4] seam, same
// glacier[6] crown, same `Theme.r2`. HANDOFF names these chips as the
// reference for solids and a reference that moves is not one.
//
// ⚠ v3 is what moved the EDGE onto the shared `Pane`/`GlassEdge`/
// `MirrorEdge` stack. v4 (TRK-3042) moved the FACE off the opaque
// `Theme.elevated` slab onto Start's dark glass (swell under `panelMid`).
// Anything citing this file as the reference for an opaque ice plate or
// a hand-drawn ice seam should cite `SetIceFace`/`TaskFace` instead.
//
// ── SIZED TO CONTENT, NOT TO A MAGIC NUMBER (the TRK-2903 discipline) ───
// Every chip but the note now derives `chipH` from its body's
// `implicitHeight`. The Clock popup shipped a fixed 600 px that measured
// 35% empty on an ordinary day; these shipped fixed 84/96/112/130 px and
// were empty for the same reason. The note keeps a fixed height on purpose
// — it is a scroll area, and a box that grows as you type is not one.
//
// Design rules inherited from the plan, no exceptions:
//   · BOTTOM layer — windows always cover widgets; Task View ignores them.
//   · Every widget is its own small PanelWindow sized to its chip. This is
//     deliberate: an invisible full-screen surface already ate every click
//     on this desktop once (4c3661e), and a window that is exactly its
//     visible chip cannot repeat that class of bug.
//   · OFF by default (Prefs.widgetsEnabled) — a feature that costs cycles
//     forever ships switched off (the WIP-132 lesson).
//   · Nothing polls while hidden: every Timer is gated on its window's
//     visibility binding.
//   · The weather chip READS nyxus-lock-weather's cache. It never fetches —
//     a widget is a view of a store an app owns (two fetchers is how the
//     eww build rotted).
//   · Interactive only where the action is real. Every tap target here
//     opens a surface that exists (`Bus.openFlyoutAt` sections are the
//     SidePanel's own keys) or drives a transport the player says it
//     supports. Nothing is decorative.
//   · Still owed from the plan: drag + snap placement — positions are
//     Settings-owned numbers, and the `Prefs.widget_*` schema is untouched
//     by this pass (`SetPageWidgets.qml` reads it).
//
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    component WidgetChip: PanelWindow {
        id: chip
        required property string slug
        property int chipW: 240
        property int chipH: 96
        default property alias content: inner.data

        // ── THE Z-ROLE · `Pane.qml`'s ladder, picked per card ────────────
        // 0 chrome · 1 inline · 2 swell · 3 modal. A desktop widget is
        // NEVER 3: a modal is a surface that has taken the screen, and
        // these are objects lying on it. The owner's other sentence in the
        // same 08-24 conversation was "but not everywhere" — six cards
        // wearing one heavy rim is the same defect v2 was sent to fix,
        // moved one layer out. Each caller picks its rung and says why.
        property int zRole: 1
        // The living border (ReactiveEdge) — mood is CPU band, lift is the
        // music beat. It goes ONLY on the two cards whose subject is
        // literally one of those two things. A sticky note does not have a
        // workload.
        property bool living: false
        // A card at the same rung as another, held one notch back in its
        // edging and its reflection. The ladder has four rungs and this
        // set needs a half-step between them.
        property bool quiet: false

        visible: Prefs.widgetsEnabled && Prefs.widgetOn(slug)
        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        anchors { top: true; left: true }

        // ── THE BLOOM PAD · why this window is bigger than its card ──────
        // `Pane`'s bloom is drawn OUTSIDE the pane (`anchors.margins:
        // -bloomPx` on its ShaderEffect), so a window sized exactly to the
        // card clips the glow off and the surface loses the halo that is
        // half of what makes the Clock popup read as lit. Clock.qml solves
        // it by padding the window and insetting the pane; this does the
        // same, and then pulls the layer-shell margin back by the pad so
        // the VISIBLE card stays on the exact pixel `placedX` / `placedY`
        // put it on. X is the Settings number minus a single boardShift
        // so the two columns move as one group (Install column stays
        // free). Y is the Settings number unless that would overlap the
        // chip above in the same column — then it is that chip's bottom
        // plus Theme.s8. TRK-2939 baked sticky at y=620 for a ~292 px
        // vitals; live vitals is 332 px, so the baked Y overlapped
        // (TRK-3075). Do not bake a new Y. Content height moves.
        //
        // Independent per-chip clamp (`min(x, screen.width - chipW)`) is
        // forbidden: on a screen narrower than the 2-col board it stacks
        // clock and calendar on the SAME x. The board is one group — every
        // chip subtracts the same boardShift, and ICON_RESERVED (grid_x 16
        // + ICON_W 96 + pad 24) keeps the first desktop-icon column free.
        //
        // ⚠ TRK-3646 — THE ARITHMETIC MOVED TO `Prefs.qml`, UNCHANGED. It did
        // not move for tidiness: `SkyForeground.qml` (the near half of the
        // layered wall, a `WlrLayer.Bottom` surface at the chips' own level)
        // has to cap its wl_surface at THIS number or it could cover a chip,
        // which is the exact defect TRK-3605 had just fixed. A second copy of
        // that edge in the new file is the class audit item 24 exists for. So
        // there is one declaration and two readers, and `boardShift` /
        // `placedX` below still compute exactly what they computed before —
        // same +300+48, same 136, same min/max shape.
        readonly property int stackGutter: Theme.s8
        readonly property int boardShift: Prefs.widgetBoardShift(screen ? screen.width : 0)
        // ── A COLUMN IS ONE COLUMN · X and the rhythm come from the ROOT ──
        // Every card takes its X, and every stacked card takes its Y, from
        // the column it is declared in — never from its own stored number.
        // Two reasons, and the second one is the whole reason this pass
        // exists:
        //
        //  1. Flush edges are not decoration. Three widths and three left
        //     edges do not read as a column, and this set had both.
        //  2. **The stored numbers are stale on every machine that has
        //     already run.** `Prefs` reads `~/.config/nyxus/settings.json`,
        //     and the adapter defaults only fill keys that file does NOT
        //     carry. The owner's live file carries all twelve
        //     (`widget_sticky_x: 1232`, `widget_sticky_y: 668` — TRK-2939's
        //     baked pair), so a fix that only moved the Prefs defaults would
        //     have changed nothing on his desktop and everything in a
        //     screenshot of a fresh HOME. Measured here, not assumed: the
        //     nested capture with only the defaults moved put the note back
        //     in the LEFT column, painted over SYSTEM's lower rows —
        //     TRK-3209's photograph, arriving by a new road.
        //
        // Nothing writes these keys — `SetPageWidgets.qml` toggles the six
        // booleans and nothing else, and drag placement is still owed — so
        // the per-chip X/Y were never a user preference, only a bake. The
        // arrangement is a LAYOUT decision and it lives here, in the
        // `stackAfter` chain, which is the one place that cannot go stale.
        readonly property var columnRoot: {
            var head = chip
            var p = chip.stackAfter
            while (p) { head = p; p = p.stackAfter }
            return head
        }
        readonly property int columnX: Prefs.widgetX(chip.columnRoot.slug)
        readonly property int columnTopY: Prefs.widgetY(chip.columnRoot.slug)
        property int dragDX: 0
        property int dragDY: 0
        readonly property bool free: Prefs.widgetPlaced(slug)
        readonly property int placedX: {
            var x = chip.free
                  ? (Prefs.widgetX(chip.slug) + chip.dragDX)
                  : (chip.columnX - chip.boardShift + chip.dragDX)
            if (!chip.free)
                return x
            var maxX = (chip.screen ? chip.screen.width : 0) - chip.chipW
            return Math.max(Prefs.widgetIconReserved, Math.min(x, Math.max(Prefs.widgetIconReserved, maxX)))
        }

        // ── THE BOTTOM FENCE · why a column can move as a group (TRK-3230) ──
        // Owner 08-27, looking at his own desktop: "the bottom one overlaps
        // the bar." The note ran INTO the chrome zone at the foot of the
        // screen. Y had a floor (stack under the chip above) and no
        // CEILING, so a column whose cards grew simply grew off the bottom.
        //
        // The clearance is DERIVED, never a baked offset for today's bar.
        // `Bar.qml` pins `exclusiveZone: Theme.chromeH` explicitly and
        // unconditionally — that one token IS the reserved height, and it is
        // deliberately independent of the bar's `implicitHeight` (the
        // dissolve grows the surface and must not grow the zone). So the
        // usable desktop is `screen.height - Theme.chromeH`, and if the
        // chrome zone ever changes the fence follows it with no edit here.
        // A per-chip clamp is forbidden for the same reason the per-chip X
        // clamp is: pulling ONE card up drives it into the card above, which
        // is the TRK-3209 photograph (the note painted over SYSTEM's lower
        // rows). The column is one group and lifts by one amount, computed
        // from the LAST VISIBLE card in it and capped so the column head
        // never leaves the top of the screen.
        //
        // The chain therefore runs on `stackedY` (unclamped) and never on
        // `placedY`: `placedY` depends on the lift, the lift depends on the
        // tail's `stackedY`, and routing the chain through `placedY` would
        // close that into a binding loop.
        property var stackAfter: null
        // The deepest card in this chip's column. Every chip in a column
        // names the same tail so all of them lift together.
        property var columnTail: null
        readonly property int boardTopMin: Theme.s8
        // The bar's reserved zone, and the only number in this file that
        // comes from another surface. Not `Theme.barHeight` (52) — that is
        // the Start hit target inside the chrome, not what the compositor
        // holds back.
        readonly property int barReserved: Theme.chromeH
        readonly property int availBottom: (screen ? screen.height : 0) - barReserved

        // ── PAINTED HEIGHT · THE CYCLE THIS USED TO CLOSE ────────────────
        // Was:  Math.max(chipH, implicitHeight - 2 * Theme.bloomPad)
        //
        // MEASURED on his 1920x1200 screen, 2026-09-08, from `hyprctl layers`
        // (the two rectangles are the layer surfaces, card = surface + padT):
        //     calendar  card y 120  h 239  ->  weather card top 383   OK
        //     weather   card y 383  h 125  ->  note    card top 476
        //                                      note SHOULD start at 532
        // The note ran 56 px UP INTO the weather card and the weather card's
        // rounded bottom was drawn through the note's `NOTE` / `Notes` header
        // row -- photographed at `docs/proof/audit-0908/`. 56 px is exactly
        // the weather card's empty-to-populated growth: `wxBody` is ~45 px
        // tall while the chip waits for `~/.cache/nyxus/lockweather` and
        // ~101 px once the reader returns, i.e. `chipH` 69 -> 125. The note
        // was laid out against the weather card's FIRST-FRAME height and
        // never moved when the card grew, while the weather WINDOW did grow
        // (its surface is 173 = 125 + two bloom pads). So `chipH` was live
        // and `paintedH` -- the number the column is laid out from -- was not.
        //
        // The reason is a cycle, and it runs through the `max`'s second term:
        //     paintedH -> implicitHeight -> padT -> placedY -> columnLift
        //              -> columnOverflow -> TAIL chip's stackedY -> paintedH
        // `columnOverflow` reads the tail's `stackedY`, and the tail's
        // `stackedY` reads this chip's `paintedH`. The block above worried
        // about exactly this ("routing the chain through `placedY` would
        // close the lift's binding loop") and then closed it anyway by the
        // back door. QML resolves a cycle by dropping one of its bindings,
        // and the one it dropped froze this value at the first frame.
        //
        // The second term was never once the larger of the two anyway: with
        // `implicitHeight: chipH + padT + Theme.bloomPad` and
        // `padT: Math.min(Theme.bloomPad, placedY)` it is
        // `chipH + padT - Theme.bloomPad`, and `padT <= Theme.bloomPad`
        // makes that `<= chipH` for every value either can take. No chip in
        // this file sets `implicitHeight` itself (grep it), so the `max` was
        // dead arithmetic that bought nothing and cost the cycle.
        //
        // The card's height is `chipH`, which depends only on the card's own
        // content -- nothing downstream of `placedY` can reach it now.
        // Modelled before/after in a throwaway Quickshell instance with these
        // exact numbers: with the old expression the engine warns
        // "Binding loop detected for property stackedY"; with this one it
        // does not, and the note lands at 532 the moment the weather card
        // grows to 125.
        readonly property int paintedH: chipH

        // Where the card WOULD sit with only the stack applied. One gutter
        // between neighbours, always — the old `max(storedY, floor)` kept
        // whichever baked number happened to be larger, which is why the
        // Calendar→Weather gap was 69 px while Clock→SYSTEM was 24.
        //
        // A hidden chip reserves nothing, and it does not hold the top of
        // the column either: before TRK-3230, turning SYSTEM off still
        // pushed the note down past where SYSTEM would have been.
        readonly property int stackedY: {
            var prev = chip.stackAfter
            while (prev && !prev.visible)
                prev = prev.stackAfter
            if (prev)
                return prev.stackedY + prev.paintedH + chip.stackGutter
            return chip.columnTopY
        }
        // How far the column overruns the fence, measured on the last card
        // in it that actually paints.
        readonly property int columnOverflow: {
            if (!chip.screen)
                return 0
            var tail = chip.columnTail ? chip.columnTail : chip
            while (tail && !tail.visible)
                tail = tail.stackAfter
            if (!tail)
                return 0
            return Math.max(0, tail.stackedY + tail.paintedH - chip.availBottom)
        }
        // Capped so the lift can never push the head off the top edge. If a
        // column is taller than the whole usable desktop the head wins and
        // the overrun stays visible — an honest overflow beats a card
        // silently rendered at a negative Y.
        readonly property int columnLift: Math.min(
            columnOverflow, Math.max(0, columnTopY - boardTopMin))
        readonly property int placedY: {
            var y = chip.free
                  ? (Prefs.widgetY(chip.slug) + chip.dragDY)
                  : Math.max(0, chip.stackedY - chip.columnLift + chip.dragDY)
            var maxY = chip.availBottom - chip.paintedH
            return Math.max(chip.boardTopMin, Math.min(y, Math.max(chip.boardTopMin, maxY)))
        }
        readonly property int padL: Math.min(Theme.bloomPad, placedX)
        readonly property int padT: Math.min(Theme.bloomPad, placedY)
        margins {
            top: placedY - padT
            left: placedX - padL
        }
        implicitWidth: chipW + padL + Theme.bloomPad
        implicitHeight: chipH + padT + Theme.bloomPad
        exclusiveZone: 0
        color: "transparent"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "nyxus-widget-" + slug
        // Start types because `Launcher.qml` sets OnDemand and grabs focus
        // while the menu is open. These chips default to None so a vitals
        // tap does not steal keys from the focused window. The sticky note
        // is the one chip that is a text field — it opts in via wantsKeys.
        // Exclusive here would take every key for as long as widgets are
        // on, which is the WIP-130 invisible-overlay class.
        property bool wantsKeys: false
        WlrLayershell.keyboardFocus: wantsKeys ? WlrKeyboardFocus.OnDemand
                                               : WlrKeyboardFocus.None

        // Input is the card, not the padded window. Without this the bloom
        // pad is a 24 px invisible collar that eats desktop clicks around
        // every widget — the same trap Clock.qml and Flyout.qml document,
        // and a cousin of the full-screen surface that ate every click on
        // this desktop once (4c3661e).
        mask: Region {
            x: face.x; y: face.y; width: face.width; height: face.height
        }

        // ── THE MATERIAL · four rulings, the photograph kept ────────────
        //
        // 2026-08-20, the ice lock. The owner: chrome is glacier ice
        // objects, "not a glass Pane + GlassEdge veil" and not a
        // `Theme.sweep0` `#0aa2d6` fill. That ruling had a MEASUREMENT
        // under it, not a preference: WIP-259 photographed a Pane +
        // GlassEdge + MirrorEdge widget card and it read as A DARK BOX ON
        // THE WALLPAPER. So this component drew its own opaque ice plate
        // on a Canvas — `Theme.elevated` face, glacier[4] seam, glacier[6]
        // crown hairline — from 08-20 until 08-24.
        //
        // 2026-08-24, the owner, verbatim: "the widgets still dont look
        // like the flyout from clicking on the clock on the bottom bar".
        // That reversed the 08-20 lock for THESE six cards: Clock popup
        // EDGE on a still-opaque `Theme.elevated` face. The Clock popup
        // sets `body: 1`, and its face measures L 7.6 against this card's
        // 16.8 — the popup is the DARKER object. GlassEdge's own header
        // says `body` is for a surface that has no body of its own and
        // that stacking it on one that does is "a dark card on a dark
        // card, which is the failure this build already had once". That
        // failure IS WIP-259. POLISH then put TRK-3003's 1 px glacier[6]
        // hairline on that opaque face.
        //
        // 2026-08-25, owner 09:26 (TRK-3042): widgets are an opaque ice
        // slab (`Theme.elevated` `#071318`) while Start is dark black
        // glass. Match Start WITHOUT turning `GlassEdge.body` on — WIP-259
        // photographed body-on-wallpaper widgets as a dark box, and
        // copying `body: 1` wholesale would re-make it.
        //
        // HOW THAT IS HONOURED. Sampled off the real Clock popup by
        // region: left rim #839198 (H200, ice) → right rim #6c4960
        // (H320.6, plum) → foot #663e58. That gradient is `_gradient.sweep`
        // dispersed around the perimeter by `shaders/pane.frag` — a RIM,
        // not a fill. `#891955` is a legal palette member (`_chrome.border`,
        // `_gradient.sweep[4]`, `_paint_layers.rose[4]`); the role its own
        // token forbids is FILL, and nothing here fills with it.
        //
        // Face is Start dark glass. `GlassEdge.body` is still 0. The
        // 6 px iceSheen + 3 px iceLip crown is gone (owner 10:03 /
        // TRK-3056). GlassEdge edging stays.
        //
        //   · `Pane` with `fill: Theme.panelMid` (alpha 0.34) — Start's
        //     own body (`Launcher.qml` `id: card`). Not `Theme.elevated`.
        //   · A swellGround `Rectangle` UNDER the paint (early child,
        //     before GlassEdge / content): Top/Mid/Foot 0.84 / 0.89 / 0.93,
        //     `radius: Theme.r2`. Same stops as Start. No swirl Loader
        //     (Start's is `active: false` anyway).
        //   · `GlassEdge` with **`body: 0`**. This is the WIP-259 line.
        //     Glaze, Lip, Sheen, Bleed, MirrorEdge and ReactiveEdge all
        //     stay: they are light IN the pane and they raise the face.
        //   · No 6 px glacier[6] iceSheen / 3 px iceLip. Owner 10:03:
        //     that was the whitish strip on top of every plate. Do not
        //     restack it. GlassEdge's own faint sheen (edging) stays.
        //
        // The acceptance bar is "reads like Start AND does not read as a
        // dark box". The 08-24 edge pass is in docs/proof/widgets-pane-0824/.
        property bool hovered: false

        // The content inset. Named because v2's chips derive their height
        // from their body and the arithmetic has to agree with the anchor
        // margin below, in one place rather than six.
        readonly property int pad: Theme.s5

        // ── 0 · THE FLOOR IS THE HEADLINER, AND IT IS NOT DRAWN HERE ────
        // RULED 2026-08-29 (TRK-3401). This chip carries layers 1-4 and no
        // explicit floor, and that is a decision, not a gap.
        //
        // WHAT THIS COMPONENT IS, stated plainly because the question was
        // asked and the obvious guess is wrong: `WidgetChip` is not a toggle
        // and not a button inside a widget. It IS the desktop widget CARD —
        // a `PanelWindow` on `WlrLayer.Bottom`, six of them (clock, vitals,
        // sticky, calendar, weather, nowplaying). It has NO latched state of
        // any kind; its only states are `hovered` and `living`. The
        // latch/swirl model lives in `SwirlChip.qml` and `Pane.livingPaint`
        // and is worn by SidePanel rows — a different component family. So
        // "gate the floor on latch state, the way the swirl is gated" has
        // nothing here to gate on, and the mirror worry — a floor popping in
        // and out on a frequently-tapped control — cannot arise either.
        //
        // WHY NO FLOOR. Windows always cover widgets (see the design rules in
        // this file's header). A Bottom-layer surface therefore has NOTHING
        // behind it but the desktop ground itself — the Headliner sky, or the
        // wallpaper. `SetSlab.qml`'s defect (TRK-3310) is backdrop
        // transmittance through a surface that floats over your WINDOWS, and
        // that defect cannot occur on this component at all.
        //
        // So the floor buys nothing here, and it costs the one thing the
        // glass can actually transmit. Transmittance at the crown is
        // (1 - 0.34) x (1 - 0.84) = 10.6%, and on this surface that is the
        // starfield showing through the pane. Compositing the stack over the
        // sky lands the crown at ~#010305; over a `Theme.elevated` floor it
        // is #020507 — one to two counts per channel, below what the eye
        // resolves on a near-black ground, and the owner's own reference
        // capture brackets BOTH (it measures widget interiors at
        // #020306…#030e14). Paying a visible loss for an invisible gain is
        // the wrong trade.
        //
        // ⚠ A CORRECTION, recorded rather than quietly dropped: an earlier
        // draft of this note claimed the 10.6% was "the living paint, the
        // subject of TRK-3395..3398". That was wrong. `paintPlumHorizon` is
        // read by `SwirlChip.qml` and nothing else, and commit b72ed65e is
        // BarSeam's display pass plus the control paint — neither is what
        // sits behind a widget. What sits behind a widget is the Headliner.
        //
        // THE INVARIANT THIS RULING RESTS ON is the layer, and only the
        // layer: `WlrLayershell.layer: WlrLayer.Bottom`, set below. If a chip
        // is ever promoted to Top or Overlay it gains a real backdrop, the
        // TRK-3310 defect becomes possible, and it needs a floor that day —
        // either `Theme.elevated` or a `SkyBehind` (which is what the Start
        // menu, Clock, flyout and crest use, and which is NOT free: it is a
        // screen-size sky per surface, gated on `live` for exactly that
        // reason, WIP-245).
        //
        // ── TRANSMITTANCE, MEASURED · TRK-3603/3604 (2026-08-31) ────────
        // The 10.6% above is arithmetic. It has now been photographed, on
        // the SYSTEM vitals card, same rect, same nested session, ground
        // painted by swaybg at wlr level 0 with no sky surface present:
        // over pure black the card reads p5 3.14 / mean 28.75, over pure
        // WHITE p5 16.50 / mean 45.02. So the face transmits 5.2% at its
        // darkest fifth and 6.38% on the mean — inside the 10.6% crown /
        // 4.6% foot bracket this note derives, and the derivation is
        // therefore sound. Against `suxyn-violet-rapture`, whose mean Y
        // behind this card is 76.21, that 6.38% is +1.07 at p5 and +4.86
        // on the mean, and the card's internal contrast (p95 - p5) does
        // not fall at all: 178.57 over black, 180.01 over the wallpaper.
        // Numbers and captures: docs/proof/widgetglass-0831/.
        //
        // ⚠ THE INVARIANT IS NOT ONLY THE LAYER. The paragraph above says
        // the ruling rests on `WlrLayer.Bottom` "and only the layer". That
        // is incomplete, and the missing half is the one that moved: the
        // trade also assumed WHAT IS BEHIND IS NEAR-BLACK. It survives a
        // bright wallpaper — 6.38% of it is a count or five — but it would
        // not survive a bright surface introduced UNDER these chips at the
        // same level. Re-measure before assuming, do not re-derive.
        //
        // AND IT IS NOT WHERE THE WIDGETS WASH OUT. Measured the same
        // night on the same rect: with `sky_mode: "voyage"` +
        // `voyage_enabled: false` the Starlight surface — Bottom layer,
        // same level as these chips — lands ABOVE the cards and paints its
        // nebula over them, taking the range from 178.57 to 128.96 over a
        // BLACK ground (the wallpaper is not involved) and 121.26 over
        // the wallpaper. The shipped `sky_mode: "headliner"` does not do
        // this (180.06). That is 87% of the loss, it is a stacking order
        // and not a material, and it is NOT fixable in this file:
        // `WlrLayer.Bottom` is already the highest rung a surface can hold
        // without covering the owner's windows. See TRK-3605.
        Pane {
            id: face
            // ── the widgets step back for the flyout ────────────────────
            // The flyout opens at the right screen edge, which is where this
            // deck lives, so it lands on the chips and leaves their readouts
            // half-covered. Owner's call (2026-09-07): fade them.
            //
            // ⚠ ON THE FACE, NOT ON THE CONTENT. Fading only the inner column
            // left the empty glass FRAMES hanging there — six lit outlines
            // around nothing, which read worse than the overlap did. The face
            // is the glass, so fading it takes the frame with it.
            //
            // ⚠ OPACITY, NOT `visible`, on the window itself: a chip is a
            // layer-shell PanelWindow on WlrLayer.Bottom, and hiding one tears
            // the surface down and rebuilds it on the way back — heavier, and
            // visibly late. The surface stays; the glass fades.
            // Owner 2026-09-07, second pass: DIM, not hide. Fading them all
            // the way out made the deck vanish and reappear, which he noticed
            // and asked about; at 0.22 the chips read as sitting BEHIND the
            // panel instead of being half-covered by it, and you can still
            // glance a value while the panel is open.
            opacity: Bus.flyoutOpen ? 0.22 : 1
            visible: opacity > 0.01
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durBase
                    easing.type: Easing.Bezier
                    easing.bezierCurve: Theme.curveMove
                }
            }
            x: chip.padL
            y: chip.padT
            width: chip.chipW
            height: chip.chipH
            elevation: chip.zRole
            fill: Theme.panelMid
            radius: Theme.r2
            // Hover is expressed as LIGHT, never as a second outline colour
            // (Pane.qml §4.4: "Never a blue outline"). `focusLevel` widens
            // and lifts the same dispersive rim that is already there, so a
            // hovered card is the same object under more light.
            focusLevel: chip.hovered ? 0.45 : 0
            Behavior on focusLevel {
                NumberAnimation { duration: Theme.durQuick }
            }

            // Start dark glass: swell under panelMid, before GlassEdge /
            // content. Same Top/Mid/Foot as Launcher.qml `id: card`.
            // ABOVE the card's Pane: a rounded gradient here would paint
            // over the cut corner, so the chamfer would be erased on all six
            // desktop widgets rather than merely missed.
            CutRect {
                anchors.fill: parent
                radius: Theme.r2
                gradTop:  Theme.swellGroundTop
                gradMid:  Theme.swellGroundMid
                gradFoot: Theme.swellGroundFoot
            }

            HoverHandler { onHoveredChanged: chip.hovered = hovered }

            GlassEdge {
                anchors.fill: parent
                radiusTL: Theme.r2; radiusTR: Theme.r2
                radiusBR: Theme.r2; radiusBL: Theme.r2
                // ⚠ ZERO, and the comment block above is the whole reason.
                // This is the one property that turns this card back into
                // WIP-259's dark box. Start's card is also 0.
                body: 0
                wash: 0
                // A chip is a smaller piece of the same glass, so the Lip
                // and Sheen come down a notch — GlassEdge's own note on
                // `edging`.
                edging: chip.quiet ? 0.70 : chip.zRole === 0 ? 0.70 : 0.85
            }
            MirrorEdge {
                radiusTL: Theme.r2; radiusTR: Theme.r2
                radiusBR: Theme.r2; radiusBL: Theme.r2
                // The popup runs depth 14 / 0.62 at 320 px and r3. These
                // cards are smaller and rounder-cornered, and a quiet card
                // is quiet in its reflection too.
                depth: 10
                strength: chip.quiet ? 0.34
                        : chip.zRole === 0 ? 0.34
                        : chip.zRole === 1 ? 0.46 : 0.58
            }
            Loader {
                anchors.fill: parent
                active: chip.living
                sourceComponent: ReactiveEdge {
                    radiusTL: Theme.r2; radiusTR: Theme.r2
                    radiusBR: Theme.r2; radiusBL: Theme.r2
                    baseStrength: 0.22
                    // TRK-3652 - no resting outer halo, same as every
                    // floating pane (TRK-3649). Exactly two chips reach
                    // this Loader, `living: true`: wVitals (the SYSTEM
                    // card) and wPlaying. That is why the owner saw the
                    // band on "the system one" and nowhere else among the
                    // widgets after the pane fixes landed - every other
                    // chip draws no ReactiveEdge at all, so it had nothing
                    // to switch off. The LIVING BORDER IS UNTOUCHED: the
                    // rim line still carries the CPU-band mood at 0.22 and
                    // the halo still blooms on a beat, from 0 instead of
                    // from a permanent 8 px.
                    haloAtRest: false
                }
            }

            // ── 4 · THE SEAM (TRK-3372) ─────────────────────────────
            // 1 px, glacier[4] — the last of the canonical five, and the
            // one this card did not have. `SetSlab.qml` draws it on every
            // Settings surface and `widget_face()` on every GTK card, both
            // deriving the value from THIS component as the reference; the
            // reference itself was leaning on `Pane`'s dispersive rim,
            // which is ELEVATION (§4.3, "elevation is light") and not the
            // seam. They are different cues doing different jobs, and the
            // whole build had one of them everywhere except here.
            //
            // Same alphas as SetSlab so a widget and a Settings card are
            // the same object: 0.45 at rest, 0.85 lifted. Hover stays
            // LIGHT — `focusLevel` on the Pane above is what widens, and
            // this rides with it rather than replacing it.
            // The widget's OUTLINE — the one line the eye follows around
            // the corner, so a rounded hairline on a cut card is the most
            // visible way to get this wrong.
            CutRect {
                anchors.fill: parent
                radius: Theme.r2
                color: "transparent"
                borderWidth: 1
                borderColor: Theme.soften(Theme.paintLayers.glacier[4],
                                          chip.hovered ? 0.85 : 0.45)
                Behavior on borderColor {
                    ColorAnimation { duration: Theme.durQuick }
                }
            }

            // ── the widgets step back for the flyout ────────────────
            // The flyout opens at the right screen edge, which is where this
            // deck lives, so it lands on top of the chips and leaves their
            // readouts half-covered. Owner's call (2026-09-07): fade.
            //
            // ⚠ OPACITY, NOT `visible`. A chip is a layer-shell PanelWindow
            // on WlrLayer.Bottom; hiding one tears the surface down and
            // rebuilds it on the way back, which is both heavier and visibly
            // late. The surface stays, its content fades.
            //
            // Bound to the flag SidePanel already maintains on every open and
            // close, so there is no second source of truth to drift.
            Item { id: inner; anchors.fill: parent; anchors.margins: chip.pad }

            DragHandler {
                id: grab
                target: null
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.SizeAllCursor
                // Sticky keeps the field; drag from empty chrome / header.
                grabPermissions: PointerHandler.CanTakeOverFromItems
                                 | PointerHandler.ApprovesTakeOverByAnything
                onActiveChanged: {
                    if (grab.active)
                        return;
                    var nx = Math.round(chip.placedX / 24) * 24;
                    var ny = Math.round(chip.placedY / 24) * 24;
                    var keys = {};
                    keys["widget_" + chip.slug + "_x"] = nx;
                    keys["widget_" + chip.slug + "_y"] = ny;
                    keys["widget_" + chip.slug + "_placed"] = true;
                    SettingsStore.setValues(keys);
                    chip.dragDX = 0;
                    chip.dragDY = 0;
                }
                onTranslationChanged: {
                    if (!grab.active)
                        return;
                    chip.dragDX = grab.translation.x;
                    chip.dragDY = grab.translation.y;
                }
            }
        }
    }

    // ── the shared small parts ───────────────────────────────────────────
    // Three of these existed six times inline, in six slightly different
    // weights, which is half of why the chips read as one flat treatment:
    // no chip had a HEADER, so every chip was a body.

    // The section head. Uppercase micro Inter with the shell's standing
    // micro tracking — the same typographic label the Start rail, the
    // flyout sections and MonthCalendar's weekday row already speak in.
    // §0 rule 1: uppercase here is typographic, not textual.
    component ChipHead: RowLayout {
        id: head
        property string title: ""
        property string trail: ""
        // A state light, off unless the chip has state to report. See the
        // success ruling in the Vitals block below for why this is the only
        // green in this file.
        property bool pip: false
        property color pipColor: Theme.success.body
        Layout.fillWidth: true
        spacing: Theme.s3
        Rectangle {
            visible: head.pip
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 7; implicitHeight: 7; radius: 3.5
            color: head.pipColor
            Behavior on color { ColorAnimation { duration: Theme.durBase } }
        }
        Text {
            text: head.title
            color: Theme.textDim              // 8.60:1 on Theme.elevated
            font.family: Theme.fUi
            font.pixelSize: Theme.tMicro
            font.weight: Theme.wStrong
            font.letterSpacing: Theme.trackMicro
        }
        Item { Layout.fillWidth: true }
        Text {
            visible: text.length > 0
            text: head.trail
            color: Theme.textMuted            // 12.26:1 on Theme.elevated
            font.family: Theme.fNum
            font.pixelSize: Theme.tMicro
            font.features: ({ "tnum": 1 })
        }
    }

    // A hairline between a head and its body. ALPHA, therefore a seam and
    // not a state (`_tokens.edges.seams.idle._role`) — seams are exempt
    // from the 3:1 mark floor by that ruling, which is why this is the one
    // element here with no ratio quoted against it.
    component ChipRule: Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.soften(Theme.paintLayers.glacier[4], 0.34)
    }

    // TRK-3762. This was a Canvas drawing a 1.4 px `glacier[5]` polyline —
    // the flattest object in the widget deck and, by rule 4, a colourblind
    // one: a processor at 8% and one at 96% drew the same picture in the
    // same cyan. It is now the shared segmented-cell field, so the history
    // carries its own load bands and this deck speaks the same language as
    // Monitor's graphs and the owner's reference images.
    //
    // ⚠ THE BODY IS ONE LINE ON PURPOSE. `CellSpark` is the one definition
    // (its Cairo twin is `nyxus_cells.cell_field`); re-cutting the geometry
    // here is how `nyxus_media.py` ended up with a second glass recipe that
    // TRK-3275/TRK-3371 had to delete. The alias exists only so the ~6 call
    // sites in this file keep their name.
    //
    // It is also cheaper than what it replaces: the Canvas rasterised the
    // whole strip in software on every samples change, per chip, several
    // times a minute. Retained Rectangles do that work once and then nothing.
    // the trend line, restored (owner 2026-09-07)
    // d3e96c6f counted these into lit cells. He reversed it: a graph is a
    // LINE. This is the pre-d3e96c6f Canvas verbatim, with `banded` kept as
    // an accepted no-op so the battery chip that opts out still loads.
    component ChipSpark: Canvas {
        id: spark
        property var samples: []
        property bool banded: true      // accepted, inert -- see MeterRow
        Layout.fillWidth: true
        implicitHeight: 16
        onSamplesChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            var s = spark.samples || [];
            if (s.length < 2 || width < 8 || height < 4)
                return;
            var mx = 1;
            for (var i = 0; i < s.length; i++) {
                var n = Number(s[i]);
                if (n > mx) mx = n;
            }
            ctx.strokeStyle = Theme.paintLayers.glacier[5];
            ctx.lineWidth = 1.4;
            ctx.beginPath();
            for (var j = 0; j < s.length; j++) {
                var x = j * (width - 1) / (s.length - 1);
                var y = height - 1 - (Number(s[j]) / mx) * (height - 2);
                if (j === 0) ctx.moveTo(x, y);
                else ctx.lineTo(x, y);
            }
            ctx.stroke();
        }
    }

    component RateRow: RowLayout {
        id: rate
        property string label: ""
        property string detail: ""
        property bool   detailOk: false
        property string readout: ""
        Layout.fillWidth: true
        spacing: Theme.s3
        Text {
            Layout.fillWidth: true
            text: rate.label
            color: Theme.textMuted            // 12.26:1
            font.family: Theme.fUi
            font.pixelSize: Theme.tCaption
            elide: Text.ElideRight
        }
        Text {
            visible: text.length > 0
            text: rate.detail
            color: rate.detailOk ? Theme.success.dim   // 8.10:1
                                 : Theme.textDim       // 8.60:1
            font.family: Theme.fUi
            font.pixelSize: Theme.tMicro
            elide: Text.ElideRight
            Layout.maximumWidth: 96
        }
        Text {
            text: rate.readout
            color: Theme.text                 // 16.70:1
            font.family: Theme.fNum
            font.pixelSize: Theme.tMicro
            font.features: ({ "tnum": 1 })
        }
    }

    // ── Clock ────────────────────────────────────────────────────────────
    // Was: one centred numeral and a date, in 120 px, of which the numeral
    // used 64. Now: the numeral keeps its billing, seconds ride beside it so
    // the chip is visibly LIVE at a glance rather than once a minute, and
    // the footer carries how far through the day you actually are.
    WidgetChip {
        id: wClock
        slug: "clock"
        // LEFT column: Clock → SYSTEM. Two cards, because SYSTEM alone is
        // taller than the other three put together (TRK-3231).
        columnTail: wVitals
        // SWELL. This is the card the owner held up against the Clock
        // POPUP, and the popup is a swell — same subject, same rung, so
        // the desktop copy and the flyout are one object seen twice.
        // ⚠ OWNER RULING 2026-08-31, TRK-3544 — was `2`. He asked why only
        // the Clock and SYSTEM wore a lit rim while the Calendar, Weather
        // and Note did not, and then: "i think i like it with out that look
        // though looks cleaner to me with out it." The tier was real design
        // — the comment above each of these three still records why each was
        // a swell — but the STEP was not a ramp. `e1Bloom` is 0 and `e2Bloom`
        // is 20, so rung 2 did not glow more than rung 1, it glowed where
        // rung 1 did not glow at all; and the rim (0.58 -> 0.88) and the
        // MirrorEdge fall (0.46 -> 0.58) both stepped at the same boundary.
        // Three cues moving together across a cliff is why it read as "these
        // two have edges and those do not" instead of as a hierarchy.
        // Restore by setting this back to 2; nothing else was touched.
        zRole: 1
        chipW: 300
        chipH: Math.ceil(clockBody.implicitHeight) + 2 * pad

        property date now: new Date()
        // 0..1 through the local day. Derived from the clock this chip is
        // already running; no new source, no new timer.
        readonly property real dayFrac: {
            var d = wClock.now;
            return (d.getHours() * 3600 + d.getMinutes() * 60 + d.getSeconds())
                   / 86400;
        }

        // ── THE SECOND ZONE · read from the tz database, not from Intl ────
        // This row used to be built with `new Intl.DateTimeFormat(...)` in a
        // try/catch. PROBED on his machine, 2026-09-08, in a throwaway
        // Quickshell instance:
        //     ReferenceError: Intl is not defined
        // QML's V4 engine ships no `Intl` object at all, so the try block
        // threw on the FIRST statement, every evaluation, on every machine
        // — and the catch arm printed `New York  ·  America/New_York`. That
        // is the raw IANA id with its underscore, which is what the owner
        // sees; and the row never once showed a New York TIME, which is the
        // whole reason the row exists. (`Clock.qml:166 worldLine()` is the
        // same dead branch for four cities and is NOT fixed here — it is
        // another lane's file. Same mechanism, same probe.)
        //
        // `date` reads /usr/share/zoneinfo, so DST is the zone database's
        // problem and not a hand-rolled US rule that goes wrong the year
        // Congress moves the date. One `sh` per minute, on the same cadence
        // the weather chip already uses, and only while the chip is visible.
        // Both formats come back in one line so the 12/24 h toggle does not
        // wait for the next tick.
        property string zoneT24: ""
        property string zoneT12: ""
        property string zoneAbbr: ""
        readonly property string zoneName: qsTr("New York")

        Process {
            id: zoneRead
            command: ["sh", "-c",
                "TZ=America/New_York date +'%H:%M|%-I:%M %p|%Z'"]
            stdout: StdioCollector {
                onStreamFinished: {
                    var p = text.trim().split("|");
                    wClock.zoneT24  = (p[0] || "").trim();
                    wClock.zoneT12  = (p[1] || "").trim();
                    wClock.zoneAbbr = (p[2] || "").trim();
                }
            }
        }
        Timer {
            running: wClock.visible
            interval: 60000; repeat: true
            triggeredOnStart: true
            onTriggered: zoneRead.running = true
        }

        ColumnLayout {
            id: clockBody
            // Width only. chipH is derived from implicitHeight, so filling
            // the parent height was a rearrange loop (RowLayout @958).
            width: parent.width
            spacing: Theme.s3

            RowLayout {
                id: timeRow
                Layout.fillWidth: true
                spacing: Theme.s4

                Text {
                    // ⚠ `Prefs.timeBare`, NOT `Prefs.timeFmt` — TRK-3907,
                    // and this is the defect the owner reported three times.
                    // `timeFmt`'s 12-hour arm is "h:mm AP", so this drew the
                    // meridiem INSIDE the 64 px numeral while the small "AP"
                    // below drew it a second time; "11:28 PM" in 64 px
                    // Orbitron measures ~360 px against a 276 px content box
                    // (chipW 300 less two `pad` of 12), and a RowLayout
                    // cannot shrink a Text with no bounded width — so the
                    // overrun put the seconds, the marker and the row
                    // beneath them out on the wallpaper. The marker belongs
                    // to the column beside this one, at `tMicro`, exactly
                    // once. See `Prefs.timeBare` for why the numerals-only
                    // form has to be a function and not a format string.
                    text: Prefs.timeBare(wClock.now)
                    color: Theme.text                 // 16.70:1 on Theme.elevated
                    // The largest numeral in the build, read at room distance
                    // and nothing but digits — `fTech`'s whole reason for
                    // shipping. JetBrainsMono held this because it was the only
                    // numeral face the shell knew about; it is a CODE face,
                    // drawn for a 13px line of source, and at 64px its terminal
                    // serifs read as clutter rather than as a clock.
                    font.family: Theme.fTech
                    font.pixelSize: Theme.tJumbo
                    font.weight: Theme.wStrong
                    font.letterSpacing: Theme.trackTech
                    // A minute must not shift the colon sideways.
                    font.features: ({ "tnum": 1 })
                    // The fence, so this can never leave the card again for
                    // any other reason — a wider fallback face, a 1.40 font
                    // scale, a locale whose 12-hour hour is two digits. A
                    // bounded width plus HorizontalFit means the numeral
                    // SHRINKS to fit rather than overflowing, and it never
                    // elides: a clipped clock is worse than a slightly
                    // smaller one. At the shipping 276 px box "11:28" sits
                    // well inside the bound, so this costs nothing today and
                    // is only ever a floor.
                    // ⚠ BOUNDED, NOT FILLED. Owner 2026-09-07: "the seconds
                    // and then where it says AM they are way to far away from
                    // the time where they should be next to".
                    //
                    // `fillWidth` made this numeral eat every spare pixel in
                    // the row, and since the spacer at the end of the row also
                    // fills, the two split the slack and shoved the
                    // seconds/meridiem column into the middle of the card,
                    // stranded away from the digits they belong to.
                    //
                    // A MAXIMUM keeps the whole fence the comment above
                    // describes — the text is still bounded, so HorizontalFit
                    // still shrinks it rather than letting it overrun the card
                    // — while letting it take only the width it actually
                    // needs, so the seconds sit against it.
                    Layout.maximumWidth: Math.max(1, wClock.chipW - 2 * wClock.pad
                                                     - secCol.implicitWidth
                                                     - timeRow.spacing)
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: Theme.tDisplay
                }

                ColumnLayout {
                    id: secCol
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: Theme.s5
                    spacing: 0
                    Text {
                        // Seconds are the whole reason this chip stops
                        // reading as a sticker: something on it moves.
                        // Deliberately small and dim — a clock you read is
                        // the minutes, a clock you believe is the seconds.
                        text: Qt.formatTime(wClock.now, "ss")
                        color: Theme.textDim          // 8.60:1
                        font.family: Theme.fTech   // TIMEPIECE -> fTech (gate 13q21): the seconds sit beside the
                        // fTech hour and a clock that changes face mid-readout is
                        // the "clocks disagree again" defect that gate exists for.
                        font.pixelSize: Theme.tCaption
                        font.features: ({ "tnum": 1 })
                    }
                    Text {
                        visible: !Prefs.clock24h
                        text: Qt.formatTime(wClock.now, "AP")
                        color: Theme.textDim          // 8.60:1
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                        font.letterSpacing: Theme.trackMicro
                    }
                }

                Item { Layout.fillWidth: true }
            }

            Text {
                Layout.fillWidth: true
                // §3: weekday + day + month, compact.
                text: Qt.formatDate(wClock.now, "dddd · d MMMM")
                color: Theme.textMuted                // 12.26:1
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                elide: Text.ElideRight
            }

            ChipRule {}

            // The shared meter, not a seventh copy of one. Ice fill at
            // glacier[5] `#b7e6f2` — 14.00:1 on Theme.elevated — never hot:
            // the time of day is not a warning.
            MeterRow {
                Layout.fillWidth: true
                label: qsTr("Day")
                value: wClock.dayFrac
                readout: Math.round(wClock.dayFrac * 100) + "%"
            }

            Text {
                Layout.fillWidth: true
                text: {
                    var hm = Prefs.clock24h ? wClock.zoneT24 : wClock.zoneT12;
                    if (hm === "")
                        // First tick has not landed yet. The place name on
                        // its own is true and quiet; the raw id never was.
                        return wClock.zoneName;
                    return wClock.zoneName + "  " + hm
                           + (wClock.zoneAbbr === ""
                              ? "" : "  ·  " + wClock.zoneAbbr);
                }
                color: Theme.textDim
                font.family: Theme.fTech
                font.pixelSize: Theme.tMicro
                font.features: ({ "tnum": 1 })
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: (Reminders.items, Reminders.upcoming(1).length > 0)
                text: {
                    Reminders.items;
                    var u = Reminders.upcoming(1);
                    if (u.length === 0)
                        return "";
                    var t = Qt.formatTime(new Date(u[0].ts), Prefs.timeFmt);
                    return (u[0].kind === "alarm" ? qsTr("Alarm") : qsTr("Next"))
                           + "  " + t + "  ·  " + (u[0].text || "");
                }
                color: Theme.paintLayers.glacier[0]
                font.family: Theme.fTech
                font.pixelSize: Theme.tMicro
                font.features: ({ "tnum": 1 })
                elide: Text.ElideRight
            }
        }

        // A real destination: the Clock surface, which owns the month and
        // the reminder editor. `Bus.toggleClock()` is its only opener.
        TapHandler { onTapped: Bus.toggleClock() }

        Timer {
            running: wClock.visible
            interval: 1000; repeat: true
            onTriggered: wClock.now = new Date()
        }
    }

    // ── Vitals ───────────────────────────────────────────────────────────
    // THE card the brief is about. It showed `BAT 99% · CHARGING` and
    // `VOL 0%` — two facts, one of which is on the bar already — while
    // seven live measurements sat unread in `Sys`.
    //
    // Cost, stated honestly rather than waved at. `BorderPulse.qml` latches
    // `Sys.ambientVitals = true` at shell start (2026-08-09, "the border IS
    // looking at cpuPercent all the time now"), so a 5 s core tick —
    // processor, memory, uptime, storage, network, temperature — is ALREADY
    // running whether this chip exists or not. Six of the eight rows below
    // are therefore free.
    //
    // Graphics and fans ride only the 2 s pass (`_vitalsGpuFans`), so this
    // chip declares itself a vitals consumer the same way `SidePanel.qml`
    // and `Launcher.qml` do. The measured delta is one `sh -c` every 2 s
    // instead of every 5 s while the widget is switched ON, and nothing at
    // all while it is off — the file's rule is "nothing polls while
    // hidden", and the Binding's `when` is that rule.
    //
    // A hover-gated Binding was tried first and rejected: at rest the
    // Graphics and Fans rows would sit at 0% / "—" and pop to life under
    // the pointer, which is both a dead row and a layout jump — the exact
    // "empty junk" the Start rail's `has*` gating exists to prevent.
    //
    // Every row is gated on its `Sys.has*` capability flag, so a desktop
    // with no battery, no fans and no util GPU draws six rows rather than
    // three empty ones.
    WidgetChip {
        id: wVitals
        slug: "vitals"
        stackAfter: wClock
        columnTail: wVitals
        // SWELL, and the one card that also gets the LIVING border: its
        // whole subject is the CPU band ReactiveEdge encodes, and it
        // already carries the state light for the same reason. An
        // instrument reporting the machine may report it at its edge too.
        // ⚠ OWNER RULING 2026-08-31, TRK-3544 — was `2`. He asked why only
        // the Clock and SYSTEM wore a lit rim while the Calendar, Weather
        // and Note did not, and then: "i think i like it with out that look
        // though looks cleaner to me with out it." The tier was real design
        // — the comment above each of these three still records why each was
        // a swell — but the STEP was not a ramp. `e1Bloom` is 0 and `e2Bloom`
        // is 20, so rung 2 did not glow more than rung 1, it glowed where
        // rung 1 did not glow at all; and the rim (0.58 -> 0.88) and the
        // MirrorEdge fall (0.46 -> 0.58) both stepped at the same boundary.
        // Three cues moving together across a cliff is why it read as "these
        // two have edges and those do not" instead of as a hierarchy.
        // Restore by setting this back to 2; nothing else was touched.
        zRole: 1
        // ⚠ owner 2026-09-07: no beat pulse on the widgets. These two
        // chips are the ONLY ones that reached the ReactiveEdge Loader,
        // so this is the whole of it for the widget layer.
        living: false
        chipW: 300
        chipH: Math.ceil(vitalsBody.implicitHeight) + 2 * pad

        Binding {
            target: Sys
            property: "vitalsActive"
            value: true
            when: wVitals.visible
        }

        ColumnLayout {
            id: vitalsBody
            anchors.fill: parent
            spacing: Theme.s4

            // ── THE ONE GREEN, AND WHY IT IS HERE AND NOWHERE ELSE ─────
            // `Theme.success` (owner ruling 2026-08-24, hue-locked H151.9)
            // shipped DEFINED BUT UNAPPLIED — its own header says "nothing
            // in the shell renders differently because this property exists.
            // Wiring it into controls is a separate pass." This is the first
            // application, and it is scoped by the test the owner set when
            // he approved it: green must be "telling you something true, not
            // just breaking up the palette for its own sake".
            //
            // So: a state light that reports whether the machine is in band.
            // Green when nothing measured is hot, magma when something is —
            // the same discriminator MeterRow already uses per row, summed
            // into one glance so you do not have to read seven bars to know.
            // It is never decoration: on a machine with no temperature and
            // no battery there is still processor, memory and storage to
            // judge, and the light means what it says.
            //
            //   Theme.success.body  #2cf597  13.10:1 on Theme.elevated
            //   magma[5]            #ff7847   7.20:1 on Theme.elevated
            //
            // The other five chips get NO green, deliberately. A clock, a
            // month, a temperature reading and a track have no good-or-bad
            // state to report, and a green rim on them would be exactly the
            // paint job the ruling excludes.
            readonly property bool inBand:
                Sys.cpuPercent < 90 && Sys.memPercent < 90
                && Sys.diskPercent < 90
                && !(Sys.hasGpu && Sys.gpuPercent >= 90)
                && !(Sys.hasTemp && Sys.tempC >= 85)
                && !(Sys.hasBattery && !Sys.batteryCharging
                     && Sys.batteryPercent <= 15)
            // Remaining, same voice as Memory / Temperature. UPower already
            // owns the number (`Sys.hasBattery` / `Sys.batteryPercent`). No
            // timer: samples ride property notify, never a second poll.
            property var histBat: []
            readonly property string batteryReadout: {
                if (!Sys.hasBattery)
                    return qsTr("unavailable");
                var bits = [qsTr("%1% remaining").arg(Sys.batteryPercent)];
                if (Sys.batteryCharging)
                    bits.push(qsTr("charging"));
                var t = Sys.battery ? Number(Sys.battery.timeToEmpty) : 0;
                if (!Sys.batteryCharging && t > 0) {
                    var m = Math.round(t / 60);
                    if (m >= 60)
                        bits.push(qsTr("%1 h %2 m").arg(Math.floor(m / 60)).arg(m % 60));
                    else
                        bits.push(qsTr("%1 m").arg(m));
                }
                return bits.join(" · ");
            }
            readonly property string btConnectedNames: {
                var ds = Sys.btDevices;
                var names = [];
                for (var i = 0; i < ds.length; i++) {
                    if (!ds[i] || !ds[i].connected)
                        continue;
                    var n = Sys.btLabel(ds[i]);
                    if (n)
                        names.push(n);
                }
                return names.join(", ");
            }
            Connections {
                target: Sys
                function onBatteryPercentChanged() {
                    if (!Sys.hasBattery)
                        return;
                    var next = vitalsBody.histBat.slice();
                    next.push(Sys.batteryPercent);
                    if (next.length > 36)
                        next.splice(0, next.length - 36);
                    vitalsBody.histBat = next;
                }
            }

            ChipHead {
                title: qsTr("SYSTEM")
                pip: true
                pipColor: vitalsBody.inBand ? Theme.success.body
                                            : Theme.paintLayers.magma[5]
                // §3 uptime: largest two units, no spaces between value and
                // unit. `Sys.uptimeText` already formats it that way.
                trail: Sys.uptimeText.length > 0
                       ? qsTr("Up %1").arg(Sys.uptimeText) : ""
            }
            ChipRule {}

            // MeterRow owns the hot rule: ice `glacier[5]` #b7e6f2 (14.00:1)
            // at rest, `magma[5]` #ff7847 (7.20:1) with a `magma[0]` #f7a83b
            // crown (9.52:1) when the value is a genuine warning. magma[1]
            // through [4] are ground stops and are never reachable from here.
            // Thresholds are the Start rail's, to the number — one machine,
            // one idea of "hot".
            MeterRow {
                Layout.fillWidth: true
                label: qsTr("Processor")
                value: Sys.cpuPercent / 100
                readout: Sys.cpuPercent + "%"
                hot: Sys.cpuPercent >= 90
            }
            ChipSpark { samples: Sys.histCpu }
            MeterRow {
                Layout.fillWidth: true
                label: qsTr("Memory")
                value: Sys.memPercent / 100
                readout: Sys.memText || (Sys.memPercent + "%")
                hot: Sys.memPercent >= 90
            }
            ChipSpark { samples: Sys.histMem }
            MeterRow {
                Layout.fillWidth: true
                visible: Sys.hasGpu
                label: qsTr("Graphics")
                value: Sys.gpuPercent / 100
                readout: Sys.gpuText
                hot: Sys.gpuPercent >= 90
            }
            MeterRow {
                Layout.fillWidth: true
                visible: Sys.hasTemp
                label: qsTr("Temperature")
                value: Sys.tempPercent / 100
                readout: Sys.tempC > 0 ? (Sys.tempC + "°C") : Sys.tempText
                hot: Sys.tempC >= 85
            }
            ChipSpark { visible: Sys.hasTemp; samples: Sys.histTemp }
            MeterRow {
                Layout.fillWidth: true
                label: qsTr("Storage")
                value: Sys.diskPercent / 100
                readout: Sys.diskText || (Sys.diskPercent + "%")
                hot: Sys.diskPercent >= 90
            }
            ChipSpark { samples: Sys.histDisk }
            MeterRow {
                Layout.fillWidth: true
                visible: Sys.hasBattery
                label: qsTr("Battery")
                value: Sys.batteryPercent / 100
                // Battery is the one meter here whose scale is INVERTED:
                // 95% is good, 8% is the emergency. Banding by magnitude
                // would paint a full battery magma, so the load bands are
                // off and the `hot` predicate below owns the colour.
                banded: false
                readout: vitalsBody.batteryReadout
                hot: !Sys.batteryCharging && Sys.batteryPercent <= 15
            }
            ChipSpark {
                // ⚠ NOT BANDED, AND IT IS NOT AN OVERSIGHT. Battery is the
                // one percentage in this deck whose scale is INVERTED: 95% is
                // good and 8% is the emergency. Banding it by magnitude would
                // paint a full battery magma — "this matters" — and a nearly
                // dead one glacier, which is rule 4 stated backwards.
                visible: Sys.hasBattery
                samples: vitalsBody.histBat
                banded: false
            }

            // ── the two rates, which are NOT gauges ─────────────────────
            // ADDENDUM_SCREENS §A1 is explicit: "a gauge requires a bounded
            // 0–100 value. A throughput rate has no ceiling and must not be
            // drawn as a ring. Network belongs in a sparkline or a plain
            // mono readout."
            //
            // `Sys.netPercent` AND `Sys.fanPercent` are both fractions of a
            // ROLLING PEAK (`_netPeak`, `_fanPeak`) rather than of a real
            // ceiling, so both are exactly the unbounded number that ruling
            // is about. Fans was drawn as a bar on the first pass of this
            // redesign and photographed FULL AND RED at 8571 rpm — which is
            // arithmetic, not heat: `_fanPeak = max(2000, peak*0.96, rpm)`
            // means the very first sample sets the peak to itself, so the
            // bar reads 100% and trips `hot` on every cold boot. A meter
            // that is pinned by construction is worse than no meter. The
            // Start rail (`Launcher.qml` SystemMeters) draws both as bars
            // and carries the same defect — that is a row for its lane, not
            // a thing to fix from here.
            //
            // So the bounded metrics above are gauges, and these two are
            // readouts. That difference is the hierarchy.
            ChipRule { Layout.topMargin: Theme.s1 }

            RateRow {
                visible: Sys.hasNet
                label: qsTr("Network")
                // "Connected" is the second sanctioned green: a named link
                // is affirmatively fine, and `Theme.success.dim` #09c36c is
                // 8.10:1 on Theme.elevated — the resting rung, "true, but
                // not news", which is exactly what a working Wi-Fi is. With
                // no named link it falls back to the neutral rung: an
                // unnamed interface is not a claim that anything works.
                // RECONCILE NOTE (2026-09-06): the other lane's live copy
                // extends this to show link capacity too (`Sys.netLinkText`,
                // fed by extra `ni[2..4]` fields the probe script — and its
                // Sys.qml parsing — emit). That plumbing was not brought into
                // this repo in this pass because it spans the shell's probe
                // command as well as Sys.qml, not just a Widgets.qml read;
                // bringing over the read without the source would silently
                // show nothing. See the reconciliation report for the full
                // Sys.qml diff. Left as the simple name-only readout below
                // until that lands as its own change.
                detail: Sys.netIfaces > 0 && Sys.netUp === 0
                        ? qsTr("down")
                        : (Sys.wifiOn && Sys.wifiName.length > 0
                           ? Sys.wifiName : qsTr("Wired"))
                detailOk: Sys.netUp > 0 && Sys.wifiOn && Sys.wifiName.length > 0
                readout: Sys.netText
            }
            ChipSpark { visible: Sys.hasNet; samples: Sys.histNet }
            RateRow {
                visible: Sys.hasFans
                label: qsTr("Fans")
                readout: Sys.fanText
            }
            // TRK-3196 — what you are listening on. Sys.sinkLabel already
            // turns PipeWire nodes into Headphones / Bluetooth / Speakers.
            // Omit when there is no sink; do not invent a battery on buds.
            RateRow {
                visible: Sys.playbackSink !== null
                         && Sys.sinkLabel(Sys.playbackSink).length > 0
                label: qsTr("Sound")
                detail: Sys.muted ? qsTr("muted") : ""
                readout: Sys.sinkLabel(Sys.playbackSink)
            }
            RateRow {
                visible: vitalsBody.btConnectedNames.length > 0
                label: qsTr("Bluetooth")
                readout: vitalsBody.btConnectedNames
            }
            // Session uptime is the honest stand-in for screen time
            // (TRK-3189). `Sys.uptimeText` is already parsed from
            // /proc/uptime on the existing vitals `sh` — no FileView,
            // no Process, no Timer. Empty string means unread: omit,
            // never invent per-app minutes.
            RateRow {
                visible: Sys.uptimeText.length > 0
                label: qsTr("Screen time")
                detail: qsTr("since boot")
                readout: Sys.uptimeText.length > 0
                         ? qsTr("%1 remaining").arg(Sys.uptimeText)
                         : qsTr("unavailable")
            }
        }

        // Deep-link into the panel that owns these numbers in full. "system"
        // is SidePanel's own section key, not a string invented here.
        TapHandler { onTapped: Bus.openHardware() }
    }

    // ── Sticky note ──────────────────────────────────────────────────────
    // Keeps its fixed height on purpose: it is a scroll area, and the one
    // widget here whose size is a promise about how much you can write
    // rather than a report of how much there is.
    WidgetChip {
        id: wSticky
        slug: "sticky"
        // ── TRK-3231 · THE NOTE MOVED COLUMNS ────────────────────────────
        // It used to be the third card under Clock and SYSTEM, and that is
        // what put it in the bar: SYSTEM is the tallest card in the set by
        // a wide margin, so the left column carried three cards' worth of
        // height plus a card that only grows as the machine reports more,
        // while the right column ran out of content less than half way down
        // and left a large empty region under Weather. Same five widgets,
        // same data, redistributed: LEFT is Clock → SYSTEM, RIGHT is
        // Calendar → Weather → NOTE, and the two columns now end within
        // about a card of each other instead of one overrunning the chrome
        // while the other stops mid-screen. The fence above is what keeps
        // that true when the heights move; this is what makes the set read
        // as an arrangement.
        stackAfter: wWeather
        columnTail: wPlaying
        // INLINE, and the quietest card in the set — no bloom, the
        // lowest MirrorEdge strength, the softest Lip and Sheen. A note is
        // a piece of paper lying ON the desktop: it emits no light, it has
        // no state, nothing about it floats.
        //
        // It was cut at zRole 0 (chrome) first, because that is what "a
        // note is not an instrument" argues for, and the capture said no:
        // measured off the same frame, the left rim peaked at **L 58.07**
        // against 70.31 / 74.53 for the two inline cards and 92.92 /
        // 103.91 for the two swells — the card stopped having an edge and
        // went back to being a soft dark rectangle on the wallpaper, which
        // is WIP-259's failure arriving by the opposite road. e0's rim
        // (0.38) is calibrated for the BAR, a surface that spans the screen
        // and is read by its contents; a card floating on a
        // wallpaper has to draw its own outline. So: rung 1, everything
        // else about it kept quiet. Numbers in
        // docs/proof/widgets-pane-0824/.
        zRole: 1
        // Quieter than the other two inline cards, which is where the
        // note's own rung really lives.
        quiet: true
        // 300 to sit flush with Calendar and Weather above it — a column
        // of three widths does not read as a column (TRK-3231).
        //
        // 190 → 260 in the same pass, and it is the note that grows because
        // it is the only card here whose height is a PROMISE rather than a
        // report: everything else is `implicitHeight`, so making one of them
        // taller would just add empty box. Measured on the nested 1920×1080
        // capture: LEFT ends at 827 and RIGHT ended at 748, both against a
        // 996 fence — 190 left the right column stopping 79 px short of its
        // neighbour for no reason. At 260 it ends at 818 and the note shows
        // roughly three more lines before it has to scroll.
        chipW: 300; chipH: 260
        wantsKeys: true

        FileView {
            id: stickyFile
            path: Quickshell.env("HOME") + "/.local/state/nyxus/sticky.txt"
            blockLoading: false
            watchChanges: true
            onFileChanged: stickyFile.reload()
            onLoaded: wSticky.hydrateNote()
        }

        // Start's search field has no live `text:` binding to a file.
        // `text: stickyFile.text()` reapplied the disk value on every
        // FileView notify and ate the keystroke — the field looked dead
        // even after the compositor granted keys.
        function hydrateNote() {
            if (stickyEdit.activeFocus)
                return;
            var t = stickyFile.text() || "";
            if (stickyEdit.text !== t)
                stickyEdit.text = t;
        }

        // Same door as Clock / Start: OnDemand lets the compositor give
        // this layer keys; the grab is what actually takes them from the
        // focused window once the note has Qt focus.
        HyprlandFocusGrab {
            windows: [wSticky]
            active: stickyEdit.activeFocus
        }

        IpcHandler {
            target: "sticky"
            function focusNote(): string {
                stickyEdit.forceActiveFocus();
                return stickyEdit.activeFocus ? "focused" : "miss";
            }
            function peek(): string { return stickyEdit.text; }
            // Harness door. Inserts at the caret after taking Qt focus —
            // the compositor key path is OnDemand + the grab; this is how
            // a nested run without wtype still lands bytes in the field.
            function enter(s: string): string {
                stickyEdit.forceActiveFocus();
                stickyEdit.insert(stickyEdit.cursorPosition, s);
                return stickyEdit.text;
            }
        }

        // TRK-2930: the note only ever saved on `onEditingFinished`, which
        // for a TextEdit means losing focus — and a desktop widget on the
        // BOTTOM layer under a full-screen window may never get focus back
        // to lose. Type a note, walk away, and the shell restarts with an
        // empty chip. So it also autosaves on a quiet second, and the head
        // says when it last wrote, because a note you cannot tell was saved
        // is a note you do not trust.
        property string savedAt: ""
        Timer {
            id: stickySave
            // 13q32: the floor is 1000 ms and it applies to a DEBOUNCE too.
            // This is not a poll — it fires once after you stop typing — but
            // the gate cannot tell those apart from the outside, and the
            // reason it exists does not care: HANDOFF records two labels at
            // 50 ms starving the event loop until the password field
            // rendered but would not accept input. 1000 ms of quiet before
            // a note saves is not a worse note.
            interval: 1000
            onTriggered: {
                stickyFile.setText(stickyEdit.text);
                wSticky.savedAt = Qt.formatTime(new Date(),
                                                Prefs.timeFmt);
            }
        }

        ColumnLayout {
            id: stickyBody
            anchors.fill: parent
            spacing: Theme.s3

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s3
                Rectangle {          // the gold pin, now on the head line
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 7; implicitHeight: 7; radius: 3.5
                    color: Theme.gold                 // 3.73:1 on Theme.elevated
                }
                Text {
                    text: qsTr("NOTE")
                    color: Theme.textDim              // 8.60:1
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    font.weight: Theme.wStrong
                    font.letterSpacing: Theme.trackMicro
                }
                Item { Layout.fillWidth: true }
                Text {
                    // The third and last green: the stamp only ever appears
                    // AFTER a write actually landed, so it is a report of a
                    // good thing that happened rather than a decoration.
                    // `Theme.success.dim` #09c36c — 8.10:1 on Theme.elevated.
                    visible: wSticky.savedAt.length > 0
                    text: qsTr("Saved %1").arg(wSticky.savedAt)
                    color: Theme.success.dim          // 8.10:1
                    font.family: Theme.fNum
                    font.pixelSize: Theme.tMicro
                    font.features: ({ "tnum": 1 })
                }
                Text {
                    // Same store as the Notes app lives beside, not instead
                    // of, this chip. Does not take keys — the editor still
                    // owns wantsKeys / OnDemand (TRK-3148).
                    text: qsTr("Notes")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    font.weight: Theme.wStrong
                    TapHandler {
                        onTapped: Bus.openNotes()
                    }
                }
            }
            ChipRule {}

            Flickable {
                // WIP-640(e). This said `flick: stickyEdit` — a TextEdit —
                // and ScrollRail's `flick` is a `required property
                // Flickable`, so every single shell start logged
                //   "Unable to assign QQuickTextEdit to QQuickFlickable"
                // and the rail was left with no surface: it never drew, and
                // the one sticky note in the build scrolled with no
                // indicator, which is the exact defect WIP-332 exists to
                // have removed. The rail wants the SCROLLING surface, not
                // the thing being scrolled — so the Flickable has a name and
                // gives it.
                id: stickyFlick
                ScrollRail { flick: stickyFlick }   // WIP-332 · WIP-640(e)
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                // A short note must not eat the first click as a flick —
                // that click is what focuses the field.
                interactive: contentHeight > height
                // Explicit, because a Flickable whose content height is left
                // to be derived reports it from the contentItem's children —
                // and one of those children is now the rail itself, which is
                // bound to the very numbers it would then be sizing.
                contentHeight: stickyEdit.paintedHeight + Theme.s3
                contentWidth: width

                TextEdit {
                    id: stickyEdit
                    width: stickyFlick.width
                    wrapMode: TextEdit.Wrap
                    color: Theme.text                 // 16.70:1
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tBody
                    selectByMouse: true
                    activeFocusOnPress: true
                    selectionColor: Theme.soften(Theme.paintLayers.glacier[0], 0.28)
                    onTextChanged: stickySave.restart()
                    onEditingFinished: stickySave.triggered()
                    Component.onCompleted: wSticky.hydrateNote()

                    // Start's placeholder hides on focus and does not steal
                    // the click. `enabled: false` so it cannot eat the press
                    // that should focus the editor.
                    Text {
                        anchors.fill: parent
                        enabled: false
                        visible: stickyEdit.text.length === 0
                                 && !stickyEdit.activeFocus
                        text: qsTr("Nothing noted. Click to write.")
                        color: Theme.textDim          // 8.60:1
                        font.family: Theme.fUi
                        font.italic: true
                        font.pixelSize: Theme.tBody
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }

    // ── Calendar ─────────────────────────────────────────────────────────
    // Was a date string and a caption, in a 130 px box that was two thirds
    // air. `MonthCalendar.qml` already existed, already Monday-first,
    // already sizing itself to the month's real row count (TRK-2902), and
    // already reading the SAME `Reminders` store this chip's agenda reads.
    // It is EMBEDDED, not re-drawn: a second month grid is a second thing
    // that can disagree about what day it is — the Clock popup's own words.
    WidgetChip {
        id: wCal
        slug: "calendar"
        // RIGHT column: Calendar → Weather → NOTE → Now playing.
        columnTail: wPlaying
        // INLINE. The largest card, and a REFERENCE SHEET: a month you
        // read. It is not reporting anything live and it is not a
        // transport. At 2 its bloom would be the biggest light source on
        // the desktop for the least reason on it.
        zRole: 1
        chipW: 300
        chipH: Math.ceil(calBody.implicitHeight) + 2 * pad

        property date today: new Date()
        // Rolls the grid over midnight. One tick a minute, only while shown.
        Timer {
            running: wCal.visible
            interval: 60000; repeat: true
            onTriggered: wCal.today = new Date()
        }

        readonly property var agenda: {
            // `Reminders.items` is named to declare the dependency: the store
            // REASSIGNS the array on every write precisely so bindings that
            // touch it re-run (MonthCalendar's dot count relies on the same
            // thing). Written as a statement rather than a comma expression,
            // which qmllint's `comma` category flags.
            Reminders.items;
            return wCal.visible ? Reminders.upcoming(3) : [];
        }

        ColumnLayout {
            id: calBody
            anchors.fill: parent
            spacing: Theme.s4

            MonthCalendar {
                Layout.fillWidth: true
                // `now` is a plain property, so it does NOT follow the clock
                // on its own — bind it, or the "today" disc would be stuck
                // on whichever day the shell happened to start.
                now: wCal.today
                // A month grid is the wrong place to host an editor (its own
                // header says so), so a tap hands off to the surface that
                // has one. Honest limit, inherited from the Clock popup: the
                // handoff carries the SECTION, not the day.
                onDaySelected: function (y, m, d) { Bus.openCalendar(); }
            }

            Text {
                Layout.fillWidth: true
                visible: Holidays.hasAny(wCal.today.getFullYear(),
                                         wCal.today.getMonth(),
                                         wCal.today.getDate())
                text: Holidays.namesForDay(wCal.today.getFullYear(),
                                           wCal.today.getMonth(),
                                           wCal.today.getDate()).join(" · ")
                color: Theme.teal
                font.family: Theme.fUi
                font.pixelSize: Theme.tMicro
                wrapMode: Text.Wrap
            }

            ChipRule {}

            ChipHead {
                title: qsTr("NEXT")
                trail: wCal.agenda.length > 0 ? String(wCal.agenda.length) : ""
            }

            Repeater {
                model: wCal.agenda
                delegate: RowLayout {
                    id: agendaRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Theme.s4
                    // A time column, not a bullet. "· thing" told you
                    // nothing you did not already know; the hour is the
                    // reason you looked.
                    //
                    // Anything not today carries its weekday. `upcoming()`
                    // reaches days ahead, and a bare "16:12" three rows down
                    // from two of today's is a lie by omission.
                    Text {
                        readonly property date at: new Date(agendaRow.modelData.ts)
                        readonly property bool today:
                            Reminders.dayKey(at) === Reminders.dayKey(new Date())
                        text: today
                              ? Qt.formatTime(at, Prefs.timeFmt)
                              : Qt.formatDate(at, "ddd d")
                        color: Theme.paintLayers.glacier[0]   // 13.35:1
                        font.family: Theme.fTech   // TIMEPIECE -> fTech (13q21): it prints a
                        // clock time, so it speaks the clock's face. The
                        // ddd-d branch is a date on the same run of glyphs.
                        font.pixelSize: Theme.tCaption
                        font.features: ({ "tnum": 1 })
                    }
                    Text {
                        Layout.fillWidth: true
                        text: agendaRow.modelData.text
                              || agendaRow.modelData.title || ""
                        color: Theme.textMuted                // 12.26:1
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        elide: Text.ElideRight
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: wCal.agenda.length === 0
                // Was "nothing scheduled — enjoy it": lower case, an em-dash
                // aside, and reassurance. VOICE §0 rules 1 and 5 and §4.
                text: qsTr("Nothing scheduled.")
                color: Theme.textDim                          // 8.60:1
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
            }
        }
    }

    // ── Weather (view of nyxus-lock-weather's cache — never a fetcher) ──
    // Was `23°` over `Sunny · 23°C` — the second line restating the first,
    // which VOICE §0 rule 5 bans in as many words. The cache the lock
    // screen reads has four more fields this chip never opened: `cond`,
    // `sub` (feels-like, high, low, area) and real `sunrise`/`sunset`
    // minutes. Same file, same single reader, four more facts.
    WidgetChip {
        id: wWeather
        slug: "weather"
        stackAfter: wCal
        columnTail: wPlaying
        // INLINE. An ambient readout of a cache another app owns —
        // glanceable, passive, nothing to drive.
        zRole: 1
        // Flush with Calendar above and the note below it (TRK-3231).
        chipW: 300
        chipH: Math.ceil(wxBody.implicitHeight) + 2 * pad

        property string big: ""
        property string cond: ""
        property string sub: ""
        property int sunriseMin: -1
        property int sunsetMin: -1
        property date wxNow: new Date()

        readonly property bool hasData: wWeather.big !== ""
        readonly property bool hasSun: wWeather.sunriseMin >= 0
                                       && wWeather.sunsetMin > wWeather.sunriseMin
        readonly property int nowMin: wWeather.wxNow.getHours() * 60
                                      + wWeather.wxNow.getMinutes()
        readonly property real dayFrac: wWeather.hasSun
            ? Math.max(0, Math.min(1,
                (wWeather.nowMin - wWeather.sunriseMin)
                / (wWeather.sunsetMin - wWeather.sunriseMin)))
            : 0

        function hhmm(mins) {
            if (mins < 0) return "—";
            var d = new Date();
            d.setHours(Math.floor(mins / 60), mins % 60, 0, 0);
            return Qt.formatTime(d, Prefs.timeFmt);
        }

        Process {
            id: weatherRead
            // Same field order the lock scene's reader uses, for the same
            // reason it uses one process: this is a hot-ish path and six
            // `cat`s in one `sh` is one fork, not six.
            command: ["sh", "-c",
                "for f in big cond sub sunrise sunset; do "
                + "cat ~/.cache/nyxus/lockweather/$f 2>/dev/null; echo; done"]
            stdout: StdioCollector {
                onStreamFinished: {
                    var p = text.split("\n");
                    wWeather.big  = (p[0] || "").trim();
                    wWeather.cond = (p[1] || "").trim();
                    wWeather.sub  = (p[2] || "").trim();
                    var sr = parseInt((p[3] || "").trim(), 10);
                    var ss = parseInt((p[4] || "").trim(), 10);
                    wWeather.sunriseMin = isNaN(sr) ? -1 : sr;
                    wWeather.sunsetMin  = isNaN(ss) ? -1 : ss;
                }
            }
        }
        Timer {
            running: wWeather.visible
            interval: 60000; repeat: true
            triggeredOnStart: true
            onTriggered: {
                wWeather.wxNow = new Date();
                weatherRead.running = true;
            }
        }

        ColumnLayout {
            id: wxBody
            anchors.fill: parent
            spacing: Theme.s3

            // ── the empty state has to look DELIBERATE, not broken ───────
            // This used to render a single 30 px em-dash whenever the cache
            // was missing, which is a box with a dash in it —
            // indistinguishable from a widget that has crashed, and it was
            // photographed on hardware and reported as a defect.
            //
            // The cause was upstream (nyxus-lock-weather only ran from
            // hypridle's lock_cmd, so the store had no owner until the first
            // lock — fixed in conf.d/nyxus-services.conf), but the empty
            // state still has to hold for the honest cases: no network at
            // login, or the first 25 s of a boot before the seeding run
            // lands. So it says what is true, quietly, at caption weight.
            Text {
                Layout.fillWidth: true
                Layout.topMargin: Theme.s5
                visible: !wWeather.hasData
                text: qsTr("Waiting for weather.")
                color: Theme.textDim                          // 8.60:1
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                horizontalAlignment: Text.AlignHCenter
            }
            // Seam, not a fill — a 2 px glacier hairline so the empty chip
            // reads as a designed wait, not a crashed box with one line.
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: Theme.s5
                visible: !wWeather.hasData
                width: 24
                height: 2
                radius: 1
                color: Theme.soften(Theme.paintLayers.glacier[4], 0.55)
            }

            RowLayout {
                Layout.fillWidth: true
                visible: wWeather.hasData
                spacing: Theme.s4
                // `big` is the cache's glyph-plus-temperature string. It is
                // the one number you came for, so it gets display weight and
                // the line under it stops repeating it.
                Text {
                    text: wWeather.big
                    color: Theme.text                         // 16.70:1
                    font.family: Theme.fNum
                    font.pixelSize: Theme.tDisplay
                    font.features: ({ "tnum": 1 })
                }
                Item { Layout.fillWidth: true }
                Text {
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: Theme.s3
                    // `cond` is one of: clear partly clouds fog rain snow
                    // storm. One word per concept, sentence case.
                    text: wWeather.cond.length > 0
                          ? wWeather.cond.charAt(0).toUpperCase()
                            + wWeather.cond.slice(1)
                          : ""
                    color: Theme.textMuted                    // 12.26:1
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                }
            }

            Text {
                Layout.fillWidth: true
                visible: wWeather.hasData && wWeather.sub.length > 0
                // "feels 19° · ↑26° ↓10° · New Hudson" — written by the
                // cache, read by the lock screen since 08-12, and by
                // nothing on the desktop until now.
                text: wWeather.sub
                color: Theme.textDim                          // 8.60:1
                font.family: Theme.fUi
                font.pixelSize: Theme.tMicro
                elide: Text.ElideRight
            }

            ChipRule { visible: wWeather.hasSun }

            // Daylight, as the shared meter: the label is the sunrise, the
            // readout is the sunset, and the track between them is where
            // now sits. Real minutes from the cache, not a guess — the same
            // numbers the lock scene lights its sky from.
            MeterRow {
                Layout.fillWidth: true
                visible: wWeather.hasSun
                label: qsTr("Sunrise %1").arg(wWeather.hhmm(wWeather.sunriseMin))
                value: wWeather.dayFrac
                readout: qsTr("Sunset %1").arg(wWeather.hhmm(wWeather.sunsetMin))
            }
        }
    }

    // ── Now Playing ──────────────────────────────────────────────────────
    // Rebuilt on `MediaSource` (TRK-2600..2604), which is the canonical
    // MPRIS view in this shell — "one place, so the Crest and the lock strip
    // can never word the same state differently". Reading `Sys.player`
    // straight, as this chip did, is the older path and it is the one that
    // announced a track for a browser sitting idle with an empty Metadata
    // dict. `MediaSource.present` is the question a chip should ask.
    //
    // Transport is `MediaGlyph` (TRK-2605), the one icon family. This chip
    // drew Nerd Font private-use codepoints — U+F048 / U+F04B / U+F04C /
    // U+F051 / U+F001 — which is the exact violation MediaGlyph's own header
    // exists to end (a second family, on the font's grid, that cannot take
    // the 1.4 stroke).
    WidgetChip {
        id: wPlaying
        slug: "nowplaying"
        // Last card of the RIGHT column, and off by default — it arrives
        // only while something is playing, so it stacks under the note
        // rather than displacing it.
        stackAfter: wSticky
        columnTail: wPlaying
        // SWELL + LIVING. It exists only while something is playing, so
        // it arrives and leaves like a popup rather than sitting on the
        // desktop; and ReactiveEdge's lift IS the beat, which is the one
        // thing this card is about.
        // ⚠ OWNER RULING 2026-08-31, TRK-3544 — was `2`. He asked why only
        // the Clock and SYSTEM wore a lit rim while the Calendar, Weather
        // and Note did not, and then: "i think i like it with out that look
        // though looks cleaner to me with out it." The tier was real design
        // — the comment above each of these three still records why each was
        // a swell — but the STEP was not a ramp. `e1Bloom` is 0 and `e2Bloom`
        // is 20, so rung 2 did not glow more than rung 1, it glowed where
        // rung 1 did not glow at all; and the rim (0.58 -> 0.88) and the
        // MirrorEdge fall (0.46 -> 0.58) both stepped at the same boundary.
        // Three cues moving together across a cliff is why it read as "these
        // two have edges and those do not" instead of as a hierarchy.
        // Restore by setting this back to 2; nothing else was touched.
        zRole: 1
        // ⚠ owner 2026-09-07: no beat pulse on the widgets. These two
        // chips are the ONLY ones that reached the ReactiveEdge Loader,
        // so this is the whole of it for the widget layer.
        living: false
        chipW: 300
        chipH: Math.ceil(npBody.implicitHeight) + 2 * pad
        visible: Prefs.widgetsEnabled && Prefs.widgetOn(slug)
                 && MediaSource.present && !Prefs.mediaBarPop

        // MPRIS `position` does not free-run — something has to ask. Same
        // half-second tick MediaCrest uses, and only while this chip is
        // visible AND something is actually playing.
        property int tick: 0
        Timer {
            interval: 1000   // 13q32 floor: nothing polls under
            // 1000 ms. Two labels spawning subprocesses every 50 ms once
            // starved the event loop and locked the owner out of hyprlock
            // (HANDOFF, Rules learned the hard way). A seek rail that
            // updates once a second is not a worse seek rail.
            repeat: true
            running: wPlaying.visible && MediaSource.playing
            onTriggered: wPlaying.tick++
        }
        readonly property real posSec: { wPlaying.tick; return MediaSource.positionSec(); }
        readonly property real lenSec: MediaSource.lengthSec
        // A timeline with no length is two 0:00 stamps either side of an
        // empty rail — it says "broken", not "unknown". MediaCrest's rule,
        // MediaCrest's reason. A stream simply gets no timeline.
        readonly property bool hasTimeline: wPlaying.lenSec > 0
        readonly property real frac: wPlaying.hasTimeline
            ? Math.min(1, wPlaying.posSec / wPlaying.lenSec) : 0

        function fmt(sec) {
            if (!sec || sec < 0) return "0:00";
            var s = Math.floor(sec % 60);
            return Math.floor(sec / 60) + ":" + (s < 10 ? "0" + s : s);
        }

        ColumnLayout {
            id: npBody
            anchors.fill: parent
            spacing: Theme.s4

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s5

                Rectangle {
                    id: art
                    implicitWidth: 60; implicitHeight: 60
                    radius: Theme.r1
                    color: Theme.void_
                    clip: true
                    MediaGlyph {
                        anchors.centerIn: parent
                        visible: albumArt.status !== Image.Ready
                        name: "note"
                        size: Theme.tTitle
                        color: Theme.paintLayers.glacier[4]   // 4.41:1
                    }
                    Image {
                        id: albumArt
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        source: MediaSource.artUrl
                        visible: status === Image.Ready
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Theme.s2

                    Text {
                        Layout.fillWidth: true
                        // The source, above the track, at micro weight: a
                        // now-playing card that does not say WHERE the sound
                        // is coming from is the one thing people actually
                        // look at these for when two things are making noise.
                        text: MediaSource.sourceLabel.length > 0
                              ? MediaSource.sourceLabel.toUpperCase() : qsTr("NOW PLAYING")
                        color: Theme.textDim                  // 8.60:1
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                        font.weight: Theme.wStrong
                        font.letterSpacing: Theme.trackMicro
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: MediaSource.displayTitle.length > 0
                              ? MediaSource.displayTitle : qsTr("Nothing playing")
                        color: Theme.text                     // 16.70:1
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tLabel
                        font.weight: Theme.wLabel
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: text.length > 0
                        text: MediaSource.displaySubtitle
                        color: Theme.textMuted                // 12.26:1
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        elide: Text.ElideRight
                    }
                }
            }

            // The timeline. Tap to seek, but ONLY where the player says it
            // can seek — `MediaSource.canSeek` gates the handler, so this is
            // never a control that does nothing.
            ColumnLayout {
                Layout.fillWidth: true
                visible: wPlaying.hasTimeline
                spacing: Theme.s2

                Rectangle {
                    id: rail
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4
                    radius: 2
                    // The same groove the shared meter uses: an alpha shelf,
                    // never a grey (§4.5 — a dark in this palette is a
                    // saturated colour).
                    color: Theme.shelfDeep
                    Rectangle {
                        width: parent.width * wPlaying.frac
                        height: parent.height
                        radius: 2
                        color: Theme.paintLayers.glacier[5]   // 14.00:1
                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.durQuick
                                easing.type: Easing.Bezier
                                easing.bezierCurve: Theme.curveMove
                            }
                        }
                    }
                    TapHandler {
                        enabled: MediaSource.canSeek
                        onTapped: function (pt) {
                            MediaSource.seekFraction(pt.position.x / rail.width);
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: wPlaying.fmt(wPlaying.posSec)
                        color: Theme.textDim                  // 8.60:1
                        font.family: Theme.fNum
                        font.pixelSize: Theme.tMicro
                        font.features: ({ "tnum": 1 })
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: wPlaying.fmt(wPlaying.lenSec)
                        color: Theme.textDim                  // 8.60:1
                        font.family: Theme.fNum
                        font.pixelSize: Theme.tMicro
                        font.features: ({ "tnum": 1 })
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s7

                Item { Layout.fillWidth: true }

                // Each control dims to the seam rung when the player says it
                // cannot do the thing. A lit button that does nothing is the
                // defect; a dim one that says so is the fix.
                MediaGlyph {
                    name: "prev"
                    size: Theme.tHead
                    color: MediaSource.canGoPrevious
                           ? Theme.textMuted                  // 12.26:1
                           : Theme.paintLayers.glacier[4]     //  4.41:1
                    TapHandler {
                        enabled: MediaSource.canGoPrevious
                        onTapped: MediaSource.previous()
                    }
                }
                MediaGlyph {
                    name: MediaSource.playing ? "pause" : "play"
                    size: Theme.tTitle
                    color: MediaSource.canTogglePlaying
                           ? Theme.paintLayers.glacier[0]     // 13.35:1
                           : Theme.paintLayers.glacier[4]     //  4.41:1
                    TapHandler {
                        enabled: MediaSource.canTogglePlaying
                        onTapped: MediaSource.togglePlaying()
                    }
                }
                MediaGlyph {
                    name: "next"
                    size: Theme.tHead
                    color: MediaSource.canGoNext
                           ? Theme.textMuted                  // 12.26:1
                           : Theme.paintLayers.glacier[4]     //  4.41:1
                    TapHandler {
                        enabled: MediaSource.canGoNext
                        onTapped: MediaSource.next()
                    }
                }

                Item { Layout.fillWidth: true }

                // The panel that owns media in full. "media" is SidePanel's
                // own section key.
                MediaGlyph {
                    name: "more"
                    size: Theme.tHead
                    color: Theme.textDim                      // 8.60:1
                    TapHandler { onTapped: Bus.openMedia() }
                }
            }
        }
    }
}
