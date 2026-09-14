// Nyxus Suxyn — the bar's living paint, on its OWN layer.
//
// TRK-3085 · Owner 00:44: keep the glass (stars through the Shelf) AND
// see swirls. Same Qt surface cannot do both here: additive paint on
// `nyxus-bar` is discarded, opaque paint covers the stars.
//
// This window is Bottom, click-through, no exclusive zone. Declared
// AFTER Headliner in shell.qml so it sits UNDER the Top bar. The glass
// Shelf is still the bar. Not the Spill (owner: no swirls above the bar
// on the wallpaper).
//
// Owner 00:48: treat the tank as a black void. Widget chips already
// prove the compositor will keep additive dye when it sits on an
// opaque plate in the SAME window; a fully-transparent seam is
// discarded the same way the Line was on `nyxus-bar`. Hue-less black,
// not `Theme.void_` (00:13: that read as a coloured plate on the bar).
// The void covers Headliner in this 84 px strip so the dye has a dark
// to be bright against. Stars on the desktop stay; the glass is still
// the Top bar.
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: seam

    anchors { left: true; right: true; bottom: true }
    implicitHeight: Theme.chromeH
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"
    visible: Prefs.swirlEnabled && !Prefs.arcadeMode && !(seam.screen && String(seam.screen.name || "").indexOf("HDMI") === 0)
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "nyxus-bar-seam"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    // TRK-3485 — true restores the opaque floor, i.e. the pre-08-30 bar.
    // See the block above the floor Rectangle for why it came off and for
    // the one invariant that keeps it safe (Bar.qml's exclusive zone).
    // ⚠ ON, 2026-09-07, at the WIDGETS' colour rather than Theme.elevated.
    // The bar was still letting the wallpaper's own bottom edge through — the
    // planet and its glow sit at the foot of his login image — which is what
    // produced a plum line across the last few rows that survived turning the
    // swirl fully off. A floor is the one thing that cannot be argued with.
    property bool barFloor: true
    // ICE widget body #0d060d. MAGMA matches Theme.void_ (#0a0404), not leftover plum.
    readonly property color floorBody: Theme.lookMagma ? Theme.void_ : "#0d060d"
    // TRK-3487 probe — the seam's OWN glass. The Shelf above already draws
    // the bar's glass; this is a second copy, and at panelMid 0.34 over
    // swellGround 0.89 it blocks ~93% on its own.
    // ⚠ TURNED ON, 2026-09-07. With this false the glass Pane below -- the
    // bar's card, its fill and its ground gradient -- IS NOT DRAWN AT ALL,
    // and the bar's entire background was the occluder Swirl painting at full
    // opacity. That is why the owner kept saying "you can see the swirls":
    // the swirls were not showing THROUGH the background, they WERE the
    // background.
    property bool seamGlass: true
    // TRK-3488 — the in-window sky the sheet refracts.
    property bool skyLive: true

    // ── TRK-3703 · THE POWER MENU IS THE REFERENCE NOW · owner 2026-09-01 ──
    //
    // "the power menu swirls i really like those alot" ... "keep them and can
    // we make the bottom that same way."
    //
    // THIS REVERSES THE DIRECTION THIS FILE HAS BEEN TUNED IN SINCE 08-18.
    // Every ruling below — WIP-880's black shadow, BARSWIRL's "just black",
    // TRK-3466's glow ladder, TRK-3476's second contour, TRK-3478's halo
    // floor — was made under an earlier ruling that the BAR was right and
    // everything else had to match it ("the swirls need to match the ones on
    // the bottom bars"). He has now looked at both surfaces on a real install
    // and ruled the other way round. None of that work was wrong; the target
    // moved.
    //
    // THE DIFFERENCE IS ONE BRANCH IN ONE SHADER, and it is worth naming
    // precisely because two earlier attempts at "make these match" went to
    // the RAMP and could not have worked. `BarSeam` passes
    // `ramp: PaintMood.ramp` and `PowerMenu`'s Swirl sets no ramp, so it
    // inherits `PaintMood.ramp` from `Swirl.qml`'s own default — THE SAME
    // ARRAY, not a copy. The colour source has been identical the whole
    // time. What differs is which branch of `swirl_view.frag` the display
    // pass returns from:
    //
    //   occluder = true    shadow.x > 0 -> the OCCLUDER branch. The paint is
    //                      pure black and is read by what it HIDES of a faint
    //                      neutral glow, wearing two thin lit contours.
    //                      Alpha 0, so it is pure ADDED light over the glass.
    //   occluder = false   shadow.x == 0 -> the COLOUR branch. Dye luminance
    //                      out through bloom, a wet sheen, a filmic shoulder
    //                      and a saturation lift. Alpha up to 0.88, so the
    //                      paint COVERS rather than adds.
    //
    // ⚠ THAT ALPHA IS NOT A DETAIL. The occluder branch cannot hide the
    // starfield because it never writes alpha; the colour branch can, and
    // does. Whatever else this switch changes, it changes how much of
    // `SkyBehind` survives inside the 84 px strip, and that is measured in
    // docs/proof/barpaint-0901 rather than assumed.
    //
    // ONE SWITCH, and it is `false`. Setting it back to `true` restores the
    // entire 08-18..08-31 occluder treatment exactly — every rung, contour
    // and floor below is kept and still carries its reasoning, because this
    // surface has now been reversed twice and the next reversal should cost
    // one word.
    // TRK-3704b · TRUE, and it is the owner's ruling after seeing both on his
    // own screen. FALSE ports the power menu's colour treatment onto the bar,
    // which is what he asked for — "keep them and can we make the bottom that
    // same way" — and it does not survive the change of canvas.
    //
    // WHY, measured on his 1920x1200 install rather than reasoned: the power
    // menu's swirl is a small centred panel on matte black; the bar is a
    // 1920 px strip over a wallpaper. The same paint that reads as structured
    // colour across 300 px spreads into a desaturated grey fog across two
    // thousand. Contrast and liveness both PASSED — ground 22.11, tray 6.36:1,
    // detail 2.0876, motion 13.404 — and the picture was still wrong. Nobody
    // checked whether it still read as swirls, which is the same failure the
    // spectrum's linear-axis defect had: the numbers were fine and the image
    // was not.
    //
    // Flipping this to false restores the port in one line, and the whole
    // measured comparison is in docs/proof/barpaint-0901/.
    property bool occluder: true

    // ── the tank (BARSWIRL, owner order 2026-08-29) ──────────────────
    // The tank was one flat black fill — exactly the "one composited rgba"
    // the material law forbids (a flat fill cannot blend and reads as a
    // sticker). The owner's order: the swirls carry "the exact real
    // material" — the canonical five-layer widget glass (SetSlab.qml's
    // stack, TRK-3372). So the plate under the paint is now that stack,
    // value for value:
    //
    //   0 · Theme.elevated #071318   the opaque floor. Keeps 00:48's "the
    //       tank covers Headliner in this strip" — nothing behind the bar
    //       reaches the eye — while replacing hue-less black with the
    //       material's own floor.
    //   1 · Pane fill Theme.panelMid (α 0.34) — Start's paint.
    //   2 · swellGround 0.84 / 0.89 / 0.93 — the widgets' swell.
    //   3 · GlassEdge body: 0 — WIP-259's line. `topEdge: 0` because this
    //       window's top edge IS the bar's top edge, and the 08-18 owner
    //       ruling (Bar.qml § the bevel comes off the top edge) says that
    //       edge announces nothing. GlassEdge.qml names the bar as the one
    //       caller that sets 0. Glaze/bleed at SetSlab's resting values.
    //   4 · glacier[4] 1 px seam, the rung's allowed role. Left/right/
    //       bottom sit on screen edges; the top run is the seam the
    //       widgets wear.
    //
    // Cornerless (Theme.r0 = 0) on purpose: the bar is "full width, flush,
    // cornerless" (HORIZON §1) and rounding the tank would put desktop
    // pixels in the corners of the chrome. The corner treatment the owner
    // pointed at arrives through GlassEdge's bleed pools and the swirl
    // display pass's own corner-bleed, the same way the bar's glass above
    // gets it. Not SetSlab itself: that component has no `topEdge` knob
    // and its Pane rim is a card's, not chrome's — the recipe is
    // transcribed at the bar's own edge rulings instead.
    // ── TRK-3485 · THE FLOOR COMES OFF · owner 2026-08-30 ────────────────
    // "the glass isn't see-through, or look like what I thought it would
    // look like."
    //
    // He is right, and the cause is this Rectangle. Glass with a solid wall
    // behind it is not glass, it is a tinted sheet: there is nothing to see
    // THROUGH, so none of the cues that say "glass" can occur at all. Every
    // treatment tried on this bar has been fighting that, including the
    // refraction of TRK-3482, which failed for exactly this reason — it had
    // only the bar's own smooth gradient to bend.
    //
    // THE WIDGETS DO NOT HAVE THIS FLOOR. TRK-3372 ruled it out for
    // `WidgetChip` explicitly: windows always cover widgets, so the only
    // thing behind a Bottom-layer surface is the desktop ground, and the
    // starfield showing through at ~10.6% transmittance is a FEATURE the
    // floor would cost. So the bar carrying an opaque floor is a way it
    // DIFFERS from the widgets, not a way it matches them — which is what he
    // has been pointing at all day.
    //
    // The 00:48 ruling that put it here — "the tank covers Headliner in this
    // strip so the dye has a dark to be bright against" — was correct FOR THE
    // ADDITIVE TREATMENT: that paint was light added on top and needed a dark
    // ground to read against. TRK-3481 replaced it with a treatment that
    // MODULATES the material rather than adding to it, so the requirement
    // this floor existed to serve no longer exists.
    //
    // ⚠ SAFE BECAUSE OF THE EXCLUSIVE ZONE, and only because of it. `Bar.qml`
    // sets `exclusiveZone: Theme.chromeH` with `ExclusionMode.Normal`, so no
    // window can ever occupy this 84 px strip. What lies behind the seam is
    // therefore the Headliner sky and never window content — TRK-3310's
    // transmittance defect cannot occur here, for the same reason it cannot
    // occur on a widget. IF THAT EXCLUSIVE ZONE IS EVER REMOVED, THIS FLOOR
    // MUST COME BACK.
    //
    // `barFloor: true` restores the old bar in one word.
    Rectangle {
        anchors.fill: parent
        visible: seam.barFloor
        // ── THE FADE ────────────────────────────────────────────────────
        // Owner 2026-09-07: "can we make the top of the bar seem like it
        // fades away so its dark but gets lighter ... until it fades into the
        // bckgrouns".
        //
        // So the floor is no longer a slab. It is the widget's own measured
        // body colour (#0d060d — NOT Theme.elevated #071318, the blue-teal
        // that started this whole thread) carried from fully transparent at
        // the top edge to fully opaque at the foot. The bar stops having a
        // top edge at all: it thickens out of the wallpaper.
        //
        // The curve is deliberately weighted late — nothing until 18%, still
        // only half-there at 55% — because a linear fade on an 84px strip
        // reads as a grey wash rather than as something emerging.
        gradient: Gradient {
            GradientStop { position: 0.00; color: Theme.soften(seam.floorBody, 0) }
            GradientStop { position: 0.28; color: Theme.soften(seam.floorBody, 0.02) }
            GradientStop { position: 0.58; color: Theme.soften(seam.floorBody, 0.40) }
            GradientStop { position: 0.82; color: Theme.soften(seam.floorBody, 0.88) }
            GradientStop { position: 1.00; color: Theme.soften(seam.floorBody, 1.0) }
        }
    }

    // ── TRK-3488 · THE SKY, IN THE WINDOW, SO IT CAN BE BENT ─────────────
    // TRK-3487 made the bar see-through, but a shader can only sample
    // textures in its OWN window. The Headliner is a different compositor
    // surface, so transparency lets the compositor blend the sky in and never
    // hands it to us — and you cannot bend what you cannot read.
    //
    // `SkyBehind` is the build's own answer, already worn by Clock, Launcher,
    // SidePanel, MediaCrest and the widget chips: the REAL `HeadlinerSky`,
    // instantiated at screen size with a negative offset so its lattice lines
    // up with the desktop, then clipped. The same renderer — this is not a
    // picture of the sky, it IS the sky, so the stars inside the bar are
    // continuous with the stars above it.
    //
    // ⚠ COST: a screen-size sky, always on. WIP-245 warns a per-surface sky
    // is not free, which is why every other caller gates it on `live`; the
    // bar never closes. `skyLive: false` returns to the plain
    // compositor-blended sky with no refraction.
    // ⚠ Needs `sky_mode: headliner` — Voyage and 2D Starlight have no Item
    // form and fall back to a black floor, leaving nothing to refract.
    SkyBehind {
        id: skyBack
        z: -1
        anchors.fill: parent
        live: seam.skyLive
        paneScreenX: 0
        // ⚠ SAMPLED FROM WHERE THE BAR ACTUALLY IS, and the experiment that
        // proved it has to be is worth keeping: pointing this at the widgets'
        // band (y420) to "read the same as the widgets" made the bar BRIGHTER,
        // because y420 is exactly where the Milky Way crosses the wallpaper.
        //
        // The widgets are not dark because of WHERE they sit. They are dark
        // because they paint a dark card over the sky. A see-through bar shows
        // whatever sky is behind it and can never match a card, wherever it
        // samples from. So the sky goes back under the bar, and the MATCH is
        // made by the fill below instead.
        paneScreenY: seam.screen ? seam.screen.height - Theme.chromeH : 996
        screenW: seam.screen ? seam.screen.width : 1920
        screenH: seam.screen ? seam.screen.height : 1080
        radius: 0
    }

    ShaderEffectSource {
        id: skyTex
        anchors.fill: parent
        sourceItem: skyBack
        live: true
        hideSource: false
        visible: false
        recursive: false
    }
    Pane {
        visible: seam.seamGlass
        anchors.fill: parent
        elevation: 0
        // ⚠ LOCAL, NOT THE TOKEN. Theme.panelMid is read by the clock, the
        // launcher, the emoji picker, the context menu and the widget chips;
        // this surface wants to be thinner than all of them.
        fill: Qt.rgba(Theme.panelMid.r, Theme.panelMid.g, Theme.panelMid.b, 0.16)
        radius: Theme.r0
        crown: 0

        Rectangle {
            anchors.fill: parent
            // ── the bar becomes actual glass ────────────────────────────
            // Owner 2026-09-07: "what if we made the background of the bar
            // see through or pure glass so its the background then with the
            // music visulizer".
            //
            // THIS gradient was the bar's real ground, not `panelMid` -- it
            // ran at 0.84 / 0.89 / 0.93 alpha, which is not glass, it is a
            // painted floor with a slight tint. Dropped to 0.26 / 0.30 / 0.34
            // so the wallpaper is what you see, and the bar is the edge, the
            // spectrum and the light.
            //
            // ⚠ THE RISK IS READABILITY, and it is real. The clock, the tray
            // and the dock labels now sit on WHATEVER the wallpaper is. Over
            // his starfield (measured pure #000000 behind the bar) that is
            // fine. Over a bright wallpaper it would not be, and the honest
            // fix then is a per-cluster scrim behind the text rather than
            // putting this floor back.
            //
            // The swellGround* tokens are untouched -- they are shared with
            // Widgets, TaskView, UsbDock and Station.
            // ⚠ THE MATCH IS MADE HERE, and it is measured. A widget card's
            // body reads #0d060d on his screen — near-black, very slightly
            // warm, and NOT the blue-teal this gradient used to be. These are
            // that colour, at the opacity a card needs to stop the sky
            // reading through it as texture.
            //
            // The see-through experiment is what established this: at 0.26
            // the bar showed the sky's clouds and stars and looked nothing
            // like a widget; the owner saw the swirls through it. A card is
            // opaque enough to be a card.
            // ⚠ OPAQUE. This is the end of a long chain of measurements and
            // it is worth writing down, because "make it glass" and "make it
            // match the widgets" turned out to be OPPOSITE requests.
            //
            // A widget card reads #0d060d. It is translucent, but the sky
            // BEHIND a widget is pure black, so what you see is the card. The
            // bar sits at the bottom of the screen where the wallpaper has
            // the planet and the nebula in it, so any translucency there
            // shows cloud texture -- which the owner kept reading as "you can
            // see the swirls". At 0.88-0.95 there was still 5-12% of sky
            // coming through, and it measured +19 green / +22 blue against a
            // widget.
            //
            // So the bar is opaque at the widget's own colour. Same material,
            // same reading, and nothing of the sky comes through to betray
            // that it is standing somewhere brighter.
            gradient: Gradient {
                GradientStop {
                    position: 0.00
                    color: Theme.lookMagma
                           ? Qt.rgba(0.047, 0.016, 0.016, 1.0)
                           : Qt.rgba(0.047, 0.000, 0.024, 1.0)
                }
                GradientStop {
                    position: 0.50
                    color: Theme.lookMagma
                           ? Qt.rgba(0.043, 0.014, 0.014, 1.0)
                           : Qt.rgba(0.043, 0.000, 0.020, 1.0)
                }
                GradientStop {
                    position: 1.00
                    color: Theme.lookMagma
                           ? Qt.rgba(0.037, 0.012, 0.012, 1.0)
                           : Qt.rgba(0.037, 0.000, 0.016, 1.0)
                }
            }
        }

        GlassEdge {
            anchors.fill: parent
            body: 0
            wash: 0
            topEdge: 0
            // TRK-3475 (owner, 08-30: "match exactly how the widgets look —
            // remember it's built by layers"): the widgets' own dial values.
            // Widgets.qml/Launcher.qml leave both unset and take GlassEdge's
            // 1.0; the bar sat at SetSlab resting values and read as a
            // different material. Same move as TRK-3417 made for bleed.
            glaze: 1.0
            edging: 1.0
            // TRK-3417 — 1.0, the widgets' own value, not 0.55.
            // The bar is on the five layers now, so it already carried the
            // three bleed pools (rose #ae206c, teal #0aa2d6, plum #891654) —
            // the mechanism that makes widget glass read as glass rather than
            // flat tint, and the rose/plum the owner had already spotted in the
            // bar's corners. It was simply running at 55% of the widgets'
            // pooling, so the bar read as a quieter sibling of the material
            // instead of the same object. Owner ruling 2026-08-29: make it the
            // same. No new hue and no new token — the difference was a dial.
            // `Widgets.qml` and `Launcher.qml` both leave this unset, taking
            // GlassEdge's default 1.0; SetSlab keeps 0.55 deliberately, being a
            // card INSIDE a surface rather than a surface itself.
            bleed: 1.0
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            antialiasing: true
            border.width: 0
            border.color: Theme.soften(Theme.lookSeam, 0.45)
        }
    }

    Swirl {
        id: paint
        opaque: false
        clip: false
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        anchors.bottomMargin: -(Theme.paintH / 2)
        height: Theme.paintH
        // Owner 2026-09-10: swirls on the bar when music is not playing;
        // spectrum FlipPlate is the face when it is. `visible` stays on so
        // the solver keeps a field ready; opacity follows Bus.barMusicUp
        // (Bar.qml's hysteresis, not a second timer).
        visible: Prefs.swirlEnabled
        // ── TRK-3481 · LIQUID GLASS · owner 2026-08-30 ───────────────────
        // "what if we made like a liquid glass as the swirls instead ...
        // using the glass materials instead?"
        //
        // Routes the display pass through the liquid branch INSTEAD of
        // WIP-880's shadow branch (it returns first), so the bar's swirl
        // stops being light laid ON the glass and becomes the glass itself
        // moving. `paintMode` stays "shadow-bar": the liquid branch still
        // reads `shadow.z` for the thickness normaliser, and reverting is
        // then one line — drop this to 0 and the tuned shadow treatment is
        // exactly as it was.
        //
        // On bare ground the branch writes (0,0,0,0), so the bar's
        // background IS the widget material by construction, not by tuning.
        // ⚠ THIS IS ABSORPTION, and 0.85 is SMOKED glass — up to 92% of the
        // light stopped. Twice now that has wiped the starfield out of the
        // bar the moment coverage was opened up (measured max luminance
        // 170 -> 22 both times), because the sheet replaces the sky with an
        // ABSORBED copy of it.
        //
        // Clear glass barely absorbs. What makes it visible is that it BENDS
        // what is behind it and catches light at its folds — refraction and
        // caustics, not darkening. So absorption drops to a trace and the
        // effect is carried by the two terms that do not cost transmission.
        // ⚠ 0 = OFF, and the display falls through to WIP-880's shadow branch.
        //
        // The liquid framing solved the widget match — the background stopped
        // being light laid on glass and became the material itself — but it
        // has never once produced something that READS as swirls. The owner
        // reported it four times: a film over it, teal blotches, a pale cloudy
        // smudge, and finally jagged pixelated fragments. That last one is the
        // caustic aliasing: a fold highlight driven by a finite difference on
        // a coarse dye grid hardens every steep gradient into angular shards
        // when pushed hard enough to be visible.
        //
        // The treatment that DID look like swirls is the occluder with its two
        // contours (TRK-3466 flowline, TRK-3476 filament) — dark flowing forms
        // wearing bright filigree. That is what goes back, now over a bar that
        // is genuinely see-through rather than over an opaque plate.
        liquidStrength: 0
        // TRK-3488 — the tint comes down. At 0.38 it was a broad glacier
        // area-fill and the owner's photo showed what a flat colour over a
        // region reads as: smoke, not glass. Real glass barely tints; it
        // DISTORTS what is behind it. The refraction now carries the effect,
        // so this is only a trace of the material's own colour.
        // ⚠ AREA FILL IS ALWAYS SMOKE. This is a flat colour spread over a
        // region, and every time it has been raised to make the glass more
        // visible the owner has photographed the same pale cloudy smudge —
        // twice now, at 0.38 and again at 0.26. It is the wrong lever and it
        // will always be the wrong lever, because glass is not a tinted area.
        // A trace only; visibility belongs to the two terms below.
        liquidPooling: 0.05
        // The fold. THIN and bright, so it adds light along a line instead of
        // over an area — the difference between a glint and a haze.
        liquidCaustic: 3.6
        // Coverage. The sheet only exists above the ambient mean, so this is
        // what decides how much of the bar it occupies. 0.90 left it a wisp
        // at one end; 0.78 gives it real presence without becoming the wash
        // that read as smoke.
        // ── FILL THE BAR · owner 2026-08-31 ──────────────────────────────
        // "the liquid glass needs to fill the bar so you really can see it."
        //
        // This is the coverage gate: the sheet only exists where thickness
        // rises above the ambient mean, so a high value leaves it a wisp at
        // one end. 0.30 puts glass across essentially the whole strip.
        //
        // This is only safe because absorption is now a trace (0.16). At the
        // old 0.85 a full sheet stopped 92% of the light and wiped the
        // starfield out of the bar — measured twice, max luminance 170 -> 22.
        // Clear glass can fill the frame precisely because it does not stop
        // what is behind it; the stars now bend THROUGH the sheet instead of
        // being hidden by it, which is the whole idea.
        liquidThreshold: 0.30
        // TRK-3488 — the sheet bends the real starfield behind it, with the
        // wavelength separation real glass has.
        refractSource: skyTex
        // ⚠ 0.10 was far too low to see. The earlier finding that "refraction
        // does not read" (TRK-3482) was measured when there was NOTHING
        // structured behind the sheet — it was bending the bar's own smooth
        // gradient. Since TRK-3487 made the bar transmit and TRK-3488 put the
        // real sky in-window, it is bending STARS, which are point sources:
        // displacement of a point is instantly legible where displacement of
        // a gradient is invisible. Same dial, different subject, opposite
        // result.
        // ⚠ THIS IS IN UV, NOT PIXELS. 0.38 is 38% OF THE FRAME — the samples
        // land far from their column, clamp at the texture edge, and the bar
        // went dark: measured max luminance 170 -> 22, i.e. the stars
        // disappeared entirely. A few percent is the whole usable range here;
        // 0.035 is ~67 px of displacement at 1920, which is plenty to see a
        // point source swim.
        refractAmount: 0.105
        refractDispersion: 0.55
        refractVScale: Theme.paintH / Theme.chromeH
        // ⛔ REFRACTION — TRIED, MEASURED, AND REJECTED. 2026-08-30.
        //
        // The owner asked the natural next question: "since glass is clear
        // and see-through, you would see what's behind the liquid glass
        // through it" — and chose the bar's OWN material as the thing seen
        // through, so the bar would stay opaque chrome.
        //
        // It was built properly, not sketched: the five layers wrapped in a
        // `ShaderEffectSource` so the display pass could sample them, a `bg`
        // sampler at binding 2, and a displacement driven by the sheet's
        // surface slope (the thickness gradient — real refraction, the same
        // finite difference the caustic already takes). It compiled, loaded
        // and ran.
        //
        // IT DOES NOT READ, and the reason is physical rather than a tuning
        // failure. Refraction is only visible when there is STRUCTURE behind
        // to bend. This bar's own material is a smooth near-black gradient,
        // so a displaced copy of it is indistinguishable from the original.
        // Measured, nested, same method as everything else here:
        //
        //   liquid, no refraction    contrast 26.12   detail 5.050
        //   refraction 0.022         contrast 16.81   detail 1.159
        //   refraction 0.25 (10x)    contrast 16.74   detail 1.777
        //
        // Ten times the displacement moved contrast by 0.07 — that is the
        // signature of a mechanism with nothing to act on, not of a value set
        // too low. It also COSTS: it replaces the sheet with its bent copy,
        // which throws away the tint that was carrying the swirl, so the bar
        // went from a visible swirl to almost none.
        //
        // What would make it work is something structured behind the sheet —
        // the desktop and its starfield. That means removing the opaque floor
        // (`Theme.elevated`, above), which makes the bar see-through and
        // breaks both the 00:48 ruling and the widget match. The owner ruled
        // that out when he chose "refract the bar's own material".
        //
        // So the whole attempt was reverted rather than shipped default-off:
        // an unused sampler on every Swirl instance in the shell is a real
        // cost for a capability nothing can use here. The finding is the
        // thing worth keeping, and this is where it is kept.
        intensity: Prefs.swirlIntensity
        cornerRadius: Theme.r0
        interactive: false
        alwaysAlive: true
        batterySaver: false
        restOpacity: 1.0
        // TRK-3473 (owner, 08-30, on the clean reverted base): "the swirls
        // need to move smoother… when I hover over it to activate". The sim
        // was stepping at the 60 Hz reference on a 144 Hz panel — motion
        // computed at well under half the drawn rate. 0 = follow the panel
        // (the property's own documented meaning; ⚠ not frozen). Bar
        // instance only; measured step cost ~0.4 ms, so panel-rate stepping
        // stays cheap. Every other surface keeps the tier's 60.
        // ⚠ TRK-3498 — WAS 0 (follow the panel, i.e. 144 Hz here). TRK-3473
        // set that to smooth hover motion, and it worked, but the shell was
        // measured at 73% of a core with this bar running: 144 solver steps a
        // second on a field whose forms turn over in seconds is most of that
        // cost for none of the look. 72 is still above the 60 Hz reference
        // the whole solver was tuned at, and above the rate the eye resolves
        // in a soft field, so the smoothness TRK-3473 bought is kept.
        maxStepHz: 72
        // ── BLACK (BARSWIRL, owner order 2026-08-29) ────────────────────
        // "just black." Pinned to WIP-880's shadow treatment — the swirl is
        // pure black, #000000, read entirely as an OCCLUDER of the faint
        // even glow the display pass lays over the tank (swirl_view.frag's
        // `shadow` branch; glow 12 8-bit levels, occ 0.85). No dye colour,
        // no specular, no bloom reaches the eye. The ramp below still feeds
        // the SOLVER (dye thickness drives the occlusion), so the motion is
        // untouched — not one solver knob moves. Only this instance pins;
        // every other Swirl surface keeps following Prefs.swirlMode.
        // TRK-3703 — gated. Off the pin, this follows `Prefs.swirlMode`
        // exactly as PowerMenu's Swirl does (it sets no `paintMode` at all),
        // so "the same way" is the same BEHAVIOUR and not merely the same
        // picture: both surfaces now answer to the one Settings key, and the
        // shipped default "paint" resolves the ladder to 0.
        // MAGMA: Start's colour branch (Launcher.qml cardPaint). ICE keeps
        // the occluder treatment the owner signed off for glacier.
        paintMode: Theme.lookMagma
            ? "paint"
            : (seam.occluder ? "shadow-bar" : Prefs.swirlMode)
        // ── TRK-3478 · owner 2026-08-30, looking at the deployed bar ─────
        // "the bottom bar, the background or the layers don't look like that
        // of the widgets."
        //
        // He is right, and the earlier answer (TRK-3476: "the glass matches,
        // the rest is the glow, your call") stopped one step short — it named
        // the cause and left it as a ruling to make instead of closing it.
        //
        // THE GLASS REALLY DOES MATCH. Measured with the paint fully off
        // (`Swirl.opacity` 0 — and note that zeroing the glow does NOT turn
        // the paint off, it drops through to the shader's COLOUR path, which
        // cost one bogus measurement before it was caught): the bar's glass
        // ground is 5.63 against a widget's 2.94, +2.69 levels, like for like
        // on the darkest fifth of both. Nothing in layers 0-4 needs to move.
        //
        // WHAT HE IS SEEING is this rung and the halo floor together, laying
        // an even wash on ground that has NO paint on it — ~20 levels at
        // mid-bar where a widget carries none. Measured, nested, same frame:
        //
        //   config                      bar grd   widget   GAP    detail
        //   swirl off (glass only)         5.63     2.94  +2.69   6.6227
        //   floor 0.88 · glow 27 (was)    20.03     2.93 +17.10   6.5466
        //   floor 0.12 · glow 27          11.40     2.93  +8.46   8.2117
        //   floor 0.12 · glow 18  ← set   10.20     2.94  +7.27   8.7701
        //   floor 0.06 · glow 27          15.73     2.94 +12.80   7.8332
        //
        // The gap falls 57% AND the swirl reads BETTER (detail +34%), because
        // the contrast between lit paint and bare ground is what makes a
        // stroke legible — the wash was flattening it, not helping it.
        //
        // ⚠ This is only safe because TRK-3476 landed first. The wash used to
        // BE the swirl's visibility: in shadow mode the paint is an occluder,
        // so with no wash there is nothing to occlude. The two contours
        // (`shadowFlowLine`, `shadowFilament`) are gated on T, so they light
        // the paint and leave bare ground alone — they carry the strokes now,
        // which is what lets the wash come down. Doing this before them would
        // have produced a bar with no visible swirl, which is precisely what
        // TRK-3466 was fighting when it stepped the glow 15→20→24→27.
        //
        // 18 rather than lower: the rung still has to light the occlusion, and
        // 0.06 measured WORSE than 0.12 on both axes (run-to-run field
        // variance is real here — these are live sims, not fixtures — so the
        // two ends were read as a trend, not to the second decimal).
        // ── TRK-3496 · THE BEAT HAS TO BE SEEN, NOT COMPUTED ─────────────
        // The field WAS reacting all along — measured at 81 ms spacing with
        // music playing, per-frame motion pulses 3.15 → 6.44 → 3.81 → 6.40,
        // a 2x swing on hits. The owner still could not see it, and he was
        // right not to: SPEED is a poor perceptual channel. A field moving
        // twice as fast for a fifth of a second looks much like a field
        // moving normally, especially when the thing moving is a dark
        // occluder with thin contours.
        //
        // BRIGHTNESS is not. Pulsing the glow and both contours on the kick
        // makes the swirl BLOOM on the beat, which the eye catches instantly.
        // The solver drive stays — it is what makes the forms churn — but the
        // visible signal now rides the display stage where it can be seen.
        // TRK-3703 — gated. -1 is `Swirl`'s own "use the ladder" sentinel,
        // and with `paintMode` below also falling through to a non-shadow
        // string the ladder resolves to 0, which is what puts the display on
        // the colour branch. Both halves have to agree or the rung wins.
        shadowGlow: seam.occluder ? 18 * (1.0 + 1.15 * Beat.kick) : -1
        ramp: PaintMood.ramp
        sweepLo: 0
        sweepHi: 1.0
        // TRK-3703 — 1.35 is `Swirl`'s default and therefore what the power
        // menu runs, having never set it. It shapes where along the sweep the
        // dye lands, so it only means anything on the colour branch.
        sweepGamma: seam.occluder ? 1.0 : 1.35
        impulseRadius: Theme.lookMagma ? 0.10 : 0.15
        // TRK-3703 — the power menu runs 0.62 (TRK-3669, the value the owner
        // approved the same morning he said he liked its swirls) and it is the
        // ONE display knob that is not inert on either branch. 0.45 here: see
        // the measured table above the display stage — a permanent strip with
        // a tray on it cannot carry the panel's setting without costing 37% of
        // the tray's contrast.
        // ⚠ 0.45 -> 0.12. Owner 2026-09-07, after looking at the bar and a
        // widget side by side: "they dont look anything alike", and he chose
        // "match exactly — paint down to the widgets' level".
        //
        // MEASURED before the change: the bar's ground read #13263a where a
        // widget card reads #0c050c. Both surfaces already fill with
        // Theme.panelMid and the bar's opaque floor is off (barFloor: false),
        // so the glass was never the difference — this permanent paint was.
        //
        // The widgets carry the same solver through SwirlChip, but gated, so
        // a chip at rest is bare glass. This brings the bar to that.
        // Side effect the old comment predicted: the tray gets its contrast
        // back, since 0.45 was costing 37% of it.
        // ⚠ THE OCCLUDER BRANCH IS THE LIVE ONE (`occluder: true` above), so
        // every earlier attempt to quieten this by editing the second number
        // changed nothing. With `seamGlass` now providing a real card, the
        // paint no longer has to BE the background, so it can be what it was
        // always described as: the living seam, not the floor.
        opacity: Bus.barMusicUp ? 0
               : (Theme.lookMagma ? 0.85
                  : (seam.occluder ? 1.00 : 0.45))
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durCeremony
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveMove
            }
        }
        // ── TRK-3395 · THE DISPLAY STAGE, NOT THE RAMP · owner 2026-08-28 ──
        // "we need to make that colour more plum purple." Seven reference
        // images, measured: a plum-burgundy swatch, plum-purple powder paint,
        // two dark blue-purple photos, a poster, and two burgundy-plum stock
        // shots. They agree closely:
        //
        //     references     H 321   S 67%   L 15%
        //     rendered bar   H 315   S 48%   L 22%
        //
        // The RAMP IS ALREADY RIGHT — plumBody #891955 is H 328 S 69% L 32%,
        // plumHaze #2e051b is S 80% L 10%, both squarely in the reference
        // family. What arrives on screen is 19 saturation points weaker and
        // half again too light, so the error is entirely in the DISPLAY PASS.
        // Chasing it in the ramp (which is where several earlier passes went)
        // would have meant inventing ever more saturated hexes to survive a
        // stage that desaturates — treating the symptom at the wrong end.
        //
        // Four knobs, each on the term it owns:
        //   exposure   the tonemap gain. 3.15 was set for the old stops at
        //              38-49% saturation; the plum family carries far more
        //              chroma per unit dye, so the same gain pushes cores
        //              through the "hot cores toward white" stage and out the
        //              other side as pale magenta. This is the lightness fix.
        //   saturation the display's own chroma lift. Raised, because the
        //              stages above it (bloom, sheen, the core lift) all add
        //              broadband white, and white is what eats saturation.
        //   bloom      adds the paint's blurred self back on. Lovely on a
        //              bright field, and on a dark one it is mostly a haze
        //              that lifts the floor and washes the colour.
        //   sheen      a white specular highlight. Same argument: white.
        //
        // ⚠ MOTION KNOBS: the 08-28 "leave the motion alone" ruling was
        // SUPERSEDED BY THE OWNER LIVE on 08-29 ("i wanna see the swirls
        // more active by themselves but where it makes good looking swirls")
        // — TRK-3466. The bar now tunes ambientAmp/ambientDye/decayRate/
        // injectGain (more, longer-lived paint), curlAmp/velocityDecay/
        // impulseRadius (livelier, rounder motion) and force+ambientAmp
        // (scaled together for SLOW drift, the TRK-3074 rule) as INSTANCE
        // overrides; simShort stays trunk. Every other surface untouched.
        // ── TRK-3703 · THE DISPLAY STAGE, PORTED ────────────────
        // The power-menu column is what PowerMenu.qml actually runs: it sets
        // `exposure: 1.15` and leaves the other three at `Swirl.qml`'s
        // defaults, so those defaults ARE the treatment being copied.
        //
        //                   bar (occluder)   power menu   SHIPPED here
        //   exposure              1.30            1.15         1.15
        //   saturation            1.45            1.22         1.22   (default)
        //   sheen                 0.12            0.35         0.18
        //   bloom                 0.38            1.00         0.45
        //   opacity               1.00            0.62         0.45
        //
        // ⚠ The bar's four were set by TRK-3395 for a plum ramp on a stage
        // that then stopped being used at all — WIP-880 moved this surface to
        // the occluder branch, where `look` is never read. They have been
        // dead uniforms since 08-18 and are live again for the first time.
        //
        // ── WHY THE SHIPPED COLUMN IS NOT THE PORT COLUMN ────────────────
        // The verbatim port was BUILT AND MEASURED FIRST, and it fails on a
        // permanent full-width strip for a reason that cannot arise on a
        // centred panel shown for two seconds: THINGS HAVE TO STAY READABLE
        // ON TOP OF IT. Three runs, same nested harness, same caged HOME,
        // same two bed windows (docs/proof/barpaint-0901; `metric.py` carries
        // every definition):
        //
        //                        bed              legibility (WCAG, glyph
        //                                          decile vs bed decile)
        //   config        L* p10  ground  detail  motion   clock   tray   mark
        //   occluder       0.646    7.21  1.5603   0.021   16.41   6.48  13.45
        //   port verbatim  3.504   29.86  1.9228  10.546   13.98   4.09  13.17
        //   shipped        2.174   22.11  2.0876  13.404   16.30   6.36  13.31
        //
        // THE TRAY IS THE LINE. The verbatim port pools bright paint under
        // the right-hand glyph row — its local bed goes 4.66 -> 66.95 levels
        // — and drops tray contrast 6.48:1 -> 4.09:1, a 37% loss on the one
        // row of the bar that is nothing but small monochrome glyphs. That is
        // a defect and not a trade; the shipped column puts it back to
        // 6.36:1, within 2% of the occluder bar.
        //
        // AND IT IS NOT A COMPROMISE ON THE LOOK. The shipped column measures
        // BETTER than the verbatim port on both of the numbers that say the
        // paint is alive — contour content 2.088 against 1.923, and
        // frame-to-frame motion 13.40 against 10.55 — because the terms taken
        // down are the ones that add BROADBAND WHITE over an area (bloom's
        // blurred self, sheen's specular), and white is what flattens a
        // contour and eats a hue. `TRK-3395`'s own note said as much about
        // these two knobs; this is that note applied in the other direction.
        //
        // THE BLACK FLOOR, the number that has vetoed changes on this build:
        // L* p10 goes 0.646 -> 2.174. It rises, and that is stated plainly
        // rather than buried — the colour branch writes alpha where the
        // occluder branch wrote none, so paint that is visible at all must
        // lift the floor it sits on. 2.174 is 38% of the way back from the
        // verbatim port's 3.504, and every one of those L* values is far
        // under the 24 that got the sigil brightness lift refused. If he
        // wants it lower still, `opacity` is the lever and it costs motion
        // and detail roughly in proportion.
        exposure: Theme.lookMagma ? 0.92 : (seam.occluder ? 1.30 : 1.15)
        saturation: Theme.lookMagma ? 1.22 : (seam.occluder ? 1.45 : 1.22)
        sheen: Theme.lookMagma ? 0.35 : (seam.occluder ? 0.12 : 0.18)
        // ── TRK-3396 · THE TOP EDGE FADES · owner 2026-08-28 ────────────
        // "almost like this, I tried to get it better as fading and darker."
        // The screenshots show why: the paint stops at a HARD HORIZONTAL LINE
        // partway up the strip. That line is not a design, it is the top of
        // this item — the band is Theme.paintH (168 px) hung with half below
        // the screen, so what the eye reads as the paint's edge is really a
        // crop, and a crop is exactly what makes it look pasted on rather
        // than lit from below.
        //
        // `dissolveH` is the mechanism already built for this (it is what
        // Bar.qml uses for its own reach): a band at the TOP of the item over
        // which the display pass ramps out to nothing, cubic, reaching
        // exactly zero.
        //
        // ⛔ TRIED AND REJECTED, 2026-08-28. At 64 px, then 38 px, the owner
        // reported "my swirls don't go up to the top of the bar, it's like
        // they get cut off, or the top of the bar is darker". Measuring the
        // vertical profile off his screenshot showed exactly that: zero paint
        // above the ramp, then lightness climbing 7% -> 26% over ~24 px.
        //
        // The reasoning error is worth keeping. A dissolve fades the paint
        // into WHATEVER IS BEHIND IT, and this window's own background is an
        // opaque black plate (see the Rectangle above — it has to be, because
        // additive dye on a transparent seam is discarded by this
        // compositor). So the paint does not fade into the desktop; it fades
        // into black, inside a bar whose top edge is still a hard line. That
        // does not read as a horizon, it reads as a shadow across the top of
        // the bar — which is precisely what he described.
        //
        // A fade here needs the BAND to extend past the bar's top edge so
        // there is something to fade into, and that is the Spill, which he
        // ruled out on 00:44 ("no swirls above the bar on the wallpaper").
        // So: off. The paint runs full strength to the top of the bar.
        //
        // ⚠ It scales the display pass's OUTPUT only. The solver, the grid,
        // the splats and the dye are untouched, so this cannot change how the
        // swirls move — which matters, because the owner asked for the motion
        // left alone. And the band must never be RESIZED to get the same
        // effect: the sim grid is fitted from the aspect, so a resize
        // re-grids the simulation and makes it a different field.
        dissolveH: 0
        // TRK-3466 second half — owner 08-29 live: "can we add more of the
        // swirls themselves". MORE PAINT on the bar's existing overrides:
        // more dye born each ambient step, each stroke carries more, and
        // decay slowed toward the solver default so strokes linger and
        // overlap instead of dying as the next arrives. (First cut added
        // DUPLICATE properties beside paintMode and broke the whole config
        // load — "Property value set multiple times"; the caged
        // shell-load-check caught it, the live shell rode the old config.)
        injectGain: Theme.lookMagma ? 0.70 : 1.75
        // TRK-3484 — the stirrers sweep at constant speed instead of
        // dwelling at their turning points. Sine dwell was pooling the field
        // at both ends of a 22.9:1 bar and starving the middle, which is what
        // the owner's 08-30 screenshot shows. Bar only.
        // ── TRK-3493 · owner 2026-08-31: "different motion ... like swirls" ──
        // 0.72 is mostly shear with a little drag left in — a spiral rather
        // than a pure rotation, which is what a stirred fluid actually does.
        // Pure 1.0 spins neatly and reads mechanical; leaving some along-path
        // push keeps the eddies wandering as they turn.
        // Owner 2026-09-11: idle motion is fine, make it a little different.
        // More shear so the field rolls instead of only sliding, plus a
        // faint vertical current so filaments climb and fall, not just
        // travel the strip.
        ambientVortex: 0.90
        // A slow current along the bar. The stirrers alone pool dye wherever
        // they linger and starve the middle of a 22.9:1 strip — the dark
        // centre in the owner's screenshots. This carries material through.
        ambientCurrentX: 0.042
        ambientCurrentY: 0.032
        ambientEvenSweep: true
        ambientDye: 0.48          // was 0.36
        // Owner 08-29, next breath: "and slower movement when they do" —
        // the TRK-3074 lesson applies: slower is force+ambientAmp scaled
        // TOGETHER (~0.65), never the step rate. Dye, curl and persistence
        // stay high, so the bar holds MANY swirls that DRIFT and wind
        // instead of darting.
        // (First slow-down cut went to 3400/0.52 and the swirls VANISHED —
        // below ~4000 the ambient pushes are too weak to inject visible
        // dye, so the tank drains empty. Slow has a floor.)
        // ── AND IT NEEDS TO MOVE · owner 2026-08-31 ─────────────────────
        // "it needs to move better as well." Scaled TOGETHER with ambientAmp,
        // which is the TRK-3074 rule — the two are one dial for travel speed,
        // and moving force alone changes how hard strokes ignite instead of
        // how fast the field flows. ~30% quicker than the 08-29 slow-drift
        // tuning, which was set for a treatment where the paint itself was
        // the visible thing; now that the STARS are what is moving through
        // the glass, the motion has to be legible in their displacement.
        force: 5600               // trunk 5200 — slower travel, still ignites
        ambientAmp: 0.86          // scaled with force — active but unhurried
        // TRK-3474 (owner, 08-30): "when I'm controlling the swirls it feels
        // laggy". The slow-drift force also weakened his hand. 5200/4300
        // restores the hand to exactly trunk strength; the drift keeps 4300.
        pointerForceMul: 1.21
        curlAmp: Theme.lookMagma ? 0.64 : 1.55
        velocityDecay: 0.12       // trunk 0.16 — motion carries further, so a
                                  // swirl completes its turn instead of dying
        decayRate: 0.36           // was 0.50 — strokes live ~40% longer
        shadowNorm: 1.55          // trunk 2.2 — young thin paint reads DARK
                                  // immediately instead of ghost-faint
        shadowFlowLine: 38 * (1.0 + 1.45 * Beat.kick)        // TRK-3466: the thin glow filament riding
                                  // the strokes' T~0.6 isoline; bar only
        // ── TRK-3476 · the SECOND contour · owner 2026-08-30 ────────────
        // "the swirl doesn't read as swirling enough — more visible motion
        // and turbulence, not just a static tint or wash."
        //
        // Measured first, then set. The bar's dye field IS moving — a
        // 14-frame stage capture at 0.45 s spacing has every frame pair
        // differing, up to 30% of the strip changing by more than 2 levels
        // — so the complaint is not that the sim is asleep. What it is: in
        // `shadow` mode the display maps thickness to darkness MONOTONICALLY,
        // and a monotonic map integrates a spiral and a smooth blob to the
        // same soft gradient. `shadowFlowLine`'s single isoline at T = 0.6
        // is the one term that shows structure, and one contour is one
        // outline. A second contour bands each stroke across its fold, which
        // is how folded paint reads as folded.
        //
        // ALL THREE VALUES ARE MEASURED, NOT PICKED. Seven configurations
        // were rendered through `scripts/capture-harness.sh` (nested — never
        // the owner's live session), 8 frames each, scored over two windows
        // of bar clear of the clock and the dock icons. `detail` is mean
        // |Laplacian|, i.e. contour content, which is what "reads as
        // swirling" actually means; `ground` is the resting floor, which
        // must NOT rise, because that is the bar-vs-widget match TRK-3475
        // settled the same night:
        //
        //   config         ground  contrast   detail          motion
        //   off            12.452    36.62   2.1542   +0.0%    4.833
        //   T .30 W .12    13.132    34.69   3.6966  +71.6%    5.541
        //   T .95 W .12    16.082    32.53   2.5202  +17.0%    4.603
        //   T .30 W .08    12.573    37.15   5.0225 +133.2%    8.377  ← set
        //   T .42 W .12    15.932    33.66   3.7290  +73.1%    5.120
        //   T .30 W .05    12.929    36.89   3.6343  +68.7%    6.286
        //   str 44 W .08   16.798    38.63   2.5474  +18.3%    8.388
        //
        // Three readings, each of which decided one value:
        //
        //   T = 0.30, the OUTER skirt, beats the core (0.95) four to one on
        //   structure at a fifth of the ground cost. The skirt is a stroke's
        //   leading edge, which is where the vorticity pass's spiral arms
        //   live; the core is the blob behind them.
        //
        //   W = 0.08 is an OPTIMUM, not a limit — 0.12 is wider and worse,
        //   0.05 is narrower and also worse. Too wide and the contour stops
        //   being a line and lights the thin haze (that is the +0.68 ground
        //   at W .12); too narrow and it falls between the dye grid's texels
        //   and breaks up. 0.08 is the width that stays a CONTINUOUS line at
        //   this dye resolution, and it is resolution-dependent for that
        //   reason — a future dye-tier change should re-run the sweep.
        //
        //   Strength 30 beats 44. Past ~30 levels the band saturates into a
        //   bright REGION instead of delineating one, so `detail` collapses
        //   (+18.3%) while the ground climbs +4.35 — the exact failure this
        //   change exists to avoid. 30 also keeps it subordinate to the
        //   primary line's 38, which is the intended reading: a band and a
        //   line, not two bands.
        //
        // Net at the set values: contour content +133%, frame-to-frame
        // motion +73% (4.833 -> 8.377), resting ground +0.12 of one 8-bit
        // level — inside noise, so the widget match is not spent to buy it.
        //
        // ⚠ Costs no texture fetch and no solver work: it reads the T the
        // occluder already computed. Four ALU ops and one compare per
        // fragment, so the swirl's frame cost is unchanged. Nothing about
        // WHEN the swirl runs moves — this is only how it looks while on.
        shadowFilament: 30 * (1.0 + 1.45 * Beat.kick)
        shadowFilamentT: 0.30
        shadowFilamentW: 0.08
        // TRK-3478 — the wash on paint-free ground, down from TRK-3475's
        // 0.88. That 0.88 was set for a real defect (at 0.10 the ground
        // tracked the dye and flipped dull<->correct with the music) and the
        // defect has not gone away — what changed is that the contours now
        // carry the strokes, so the ground no longer has to be lit for the
        // swirl to be seen. 0.12 rather than 0.10 keeps a hair more floor
        // than the setting that flipped. WATCH FOR: if the ground breathes
        // with the music again, this is the line, and the fix is to raise it
        // toward 0.30 — not to put the glow back.
        shadowHaloFloor: 0.12
        bloom: Theme.lookMagma ? 0.80 : (seam.occluder ? 0.38 : 0.45)
        introStrength: 0.55
        audioBass: Beat.bass
        audioMid: Beat.mid
        audioHigh: Beat.high
        audioPulse: Beat.pulse
        // ── TRK-3494 · owner 2026-08-31 ──────────────────────────────────
        // "drive it a lot harder so you can actually see it to the music."
        // The shipped boost was a nudge (1 + 0.7*bass + 0.5*pulse); 4.5x the
        // AC term makes a track unmistakable in the field's speed. Only the
        // music-dependent part is scaled, so when the audio stops the bar
        // returns to exactly its resting motion — there is no state to reset.
        audioKick: Beat.kick
        audioDrive: 4.5
        // And a beat has to be SEEN, not only felt: a kick lays extra dye, so
        // transients puff new material in rather than only pushing the
        // existing field faster.
        audioDyeKick: 1.6
        // ── TRK-3495 · the bar becomes a liquid spectrum ─────────────────
        // Five bands from the engine's own VIS_BANDS, laid left to right:
        // bass · low · mid · high · air. Each owns a slice of the width, and
        // the stirrers are driven by whichever slice they are crossing — so
        // the field churns per frequency instead of a graph being drawn over
        // it. No bars, no lines: the swirls themselves are the spectrum.
        //
        // When the music stops every band decays to 0, the term goes to 1.0,
        // and the bar returns to its resting motion with nothing to reset.
        // ⚠ MUST SURVIVE THE FALLBACK. `Beat` runs the engine when it can and
        // cava when it cannot, and cava has only bass/mid/high — `low` and
        // `air` are flat zero on that path. Measured live with music playing
        // and the shell on cava: bass third +50% motion, mid +6%, air -8%,
        // i.e. two of the five slices were dead and the right half of the bar
        // never moved. So the two missing bands are INTERPOLATED from their
        // neighbours rather than read directly; when the engine is delivering
        // they are the real thing, and when it is not the spectrum still
        // spans the whole width instead of collapsing to one end.
        audioSpectrum: [ Beat.bass,
                         Beat.low  > 0 ? Beat.low : (Beat.bass + Beat.mid) * 0.5,
                         Beat.mid,
                         Beat.high,
                         Beat.air  > 0 ? Beat.air : Beat.high * 0.85 ]
        // The cava path subtracts an adaptive floor, so its band values sit
        // far below the engine's absolute ones — the same drive produced a
        // 17x multiplier on paper and 12% in practice. 9.0 makes the spectrum
        // unmistakable on either path.
        spectrumDrive: 9.0
        // ── TRK-3497 · owner 2026-08-31 ──────────────────────────────────
        // "theres no color ... youd want color so you can really see it
        // moving ... add like glacier to it only when music plays though."
        //
        // Pale glacier on the filigree, always. The bar itself is unchanged
        // (occluder, glass, glow). Only the stroke colour moved off black.
        // glacier[5] is the pale ice; glacier[0] teal stays hover light.
        contourColor: Theme.tokenAccentPrimary
        contourTintAmount: 0.85
        musicActive: Beat.hot
    }

    property double _lastDrop: 0
    Connections {
        target: Bus
        function onPaint(nx) {
            const now = Date.now();
            if (now - seam._lastDrop < 80)
                return;
            seam._lastDrop = now;
            // USB 08-26: dropAt dy=-1.6 shot the seam up and down on
            // hover. Wake is a stroke, not a rocket — feed, don't dollop.
            paint.feedAt(nx, 0.32);
        }
    }
}
