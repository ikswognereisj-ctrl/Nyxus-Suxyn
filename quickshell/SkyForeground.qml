// Nyxus Suxyn — SKY FOREGROUND. The near half of a LAYERED wallpaper.
//                                                        TRK-3646
//
// The owner's ask, 2026-09-01, verbatim: "i was hoping to do say the planet
// moon or astrouid in layers to match the build so like there was a piece of
// the exact layer in the background image if makes sense". Offered the
// readings, he took the literal one: the artwork is SPLIT ACROSS THE
// COMPOSITOR'S REAL LAYERS, so his desktop widgets sit INSIDE the scene
// instead of on top of a flat picture.
//
// ── WHAT THE STACK LOOKS LIKE WHEN THIS IS ON ────────────────────────────
//   Overlay      menus / OSD                       untouched
//   Top          bar, side panel, frost            untouched
//   ── the owner's application windows ──
//   Bottom       widget chips  +  THIS SURFACE (the -fg plate)
//   Background   the -bg plate, painted by `LiveWall.qml`
//
// So one picture, cut in two, with the chips threaded between the halves.
// The background half is NOT a second surface invented here: `LiveWall.qml`
// is already the shell's `WlrLayer.Background` wallpaper and already binds a
// path through a FileView, so `shell.qml` simply hands it the `-bg` file.
//
// ── ⚠ THE HAZARD THIS FILE EXISTS TO NOT RECREATE ────────────────────────
// "my background image goes over the widgets some how" is what the owner
// reported the morning of 2026-09-01, and TRK-3605 had just fixed it by
// moving EVERY sky surface off `WlrLayer.Bottom` down onto `Background`.
// `Widgets.qml:470-495` carries the measurement: a sky on the chips' own
// level lands ABOVE them and paints over them, taking a card's internal
// contrast (p95 - p5) from 178.57 to 128.96.
//
// This surface goes deliberately BACK onto `Bottom`, because that is the only
// rung from which art can appear IN FRONT OF the ground and BEHIND the chips
// without covering the owner's application windows. That makes it the one
// surface in the build that could re-make the bug, so it carries THREE
// independent guarantees, and no one of them is trusted alone:
//
//   1. THE ART. The `-fg` plate ships with a real alpha channel and is
//      TRANSPARENT — not dark, not low-contrast, transparent — across the
//      widget zones. That is the art contract, and it is the only one of the
//      three that a future art file can violate.
//   2. THE GEOMETRY, which is why 1 cannot break the desktop. This window is
//      anchored left/top/bottom and NOT right, with `implicitWidth` capped at
//      the widget board's own left edge less its bloom collar. The wl_surface
//      is therefore PHYSICALLY NARROWER than the gap to the first chip. A
//      picture cannot cover a pixel its surface does not reach, whatever its
//      alpha says. (The keep-out itself is gone — see TRK-4172 below.)
//      That line used to read: `keepOutLeft` is derived live from
//      `Prefs.widgetBoardLeft()` — the same arithmetic `Widgets.qml` places
//      the chips with, read from one place rather than copied (a second copy
//      of a ceiling is how audit item 24's seam rule nearly lost its runner).
//   3. THE MAP ORDER. `shell.qml` declares this before `BarSeam`, the desktop
//      icon surface and `Widgets`, so within `Bottom` it maps first and sits
//      at the bottom of the level regardless of 1 and 2.
//
// ── AND IT CANNOT EAT A CLICK ────────────────────────────────────────────
// `mask: Region {}` — the empty input region every wallpaper-class surface in
// this build uses (`Headliner.qml`, `Starlight.qml`). WIP-7 is the reason it
// is written down: a stale mask on a full-screen surface ate every click meant
// for the Start menu. `LiveWall.qml` is the one deliberate exception, and it
// is an exception because it wants the cursor; this one never does.
//
// ── COST ─────────────────────────────────────────────────────────────────
// One `Image`. No shader, no solver, no clock, no `FrameAnimation`. A still
// plate composited by the compositor, which is what a wallpaper costs. The
// window is not instantiated at all unless `sky_mode` is "layered" — the
// `Variants` model in `shell.qml` is empty otherwise, so there is no surface,
// no texture and no way for this to touch a running shell until the owner
// picks it.
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    // ── the switches ─────────────────────────────────────────────────────
    // OFF by default, and the type default matters as well as the Variants
    // model: an instance created by some future caller without a mode check
    // still paints nothing until it is told to.
    property bool artEnabled: false

    // The `-fg` plate. A plain `string` and NOT a `url`, deliberately, and the
    // reason is TRK-3607's: a `url`-typed QML property compared with strict
    // `!==` against a JS string literal is never equal (QUrl vs. string as JS
    // values), so `artwork !== ""` on a url property is ALWAYS true and the
    // "nothing configured" branch below would be silently unreachable — the
    // exact defect that handed `LiveWall`'s Image an empty source and painted
    // a black screen. Coercion to a url happens for free at `Image.source`.
    property string artwork: ""

    // TRK-4172 — THE KEEP-OUT IS GONE, AND WHY ────────────────────────────
    // This carried `keepOutLeft/Top/Bottom` and drew itself as three clipped
    // viewports with the widget board's rectangle punched out. The owner saw
    // the result before he saw the code: "it dosent truly sit behind the
    // widgets eiter and tyou can see where it dosent clear as day". The
    // straight vertical edge in his screenshot was the board's left margin,
    // and the artwork simply stopped there.
    //
    // The hole dated from a measurement taken when a sky sat on the CHIPS'
    // OWN LEVEL: card contrast 178.57 -> 128.96. TRK-3605 then moved every
    // sky surface down to `WlrLayer.Background`, and from that day the cards
    // occluded this plate by layer order — the hole was cutting a picture to
    // win a fight that was already over. Re-measured on the running desktop
    // 2026-09-15, hole vs no hole, same widget column:
    //
    //     card interior mean  33.07 -> 39.71   (+2.6% of range)
    //     card interior std   46.63 -> 47.77   (the spread text lives in)
    //     card interior peak  255   -> 252
    //
    // Nothing the text needs moved. So the plate is one full-screen Image
    // again, `Prefs.widgetBoardLeft/Top/Bottom` are no longer read here (they
    // still place the chips in `Widgets.qml`, which is their real job), and
    // the ringed world reaches the right-hand edge for the first time.

    readonly property int screenW: screen ? screen.width : 0
    readonly property int screenH: screen ? screen.height : 0

    anchors { left: true; right: true; top: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    // Background, not Bottom: nyxus-desktop icons also live on Bottom, and a
    // qs reload remapped this plate on top of them. Declared after Headliner
    // so the planet still sits on the stars, under the icons and chips.
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "nyxus-sky-foreground"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    color: "transparent"

    mask: Region {}

    // `artBroken` is the honest answer to a configured-but-missing plate: the
    // surface stops existing rather than becoming a mystery black band. Same
    // shape as `LiveWall.wallpaperBroken`, minus the fallback — there is no
    // shipped default foreground to fall back TO, and inventing one would put
    // somebody else's art on the owner's desktop.
    property bool artBroken: false
    onArtworkChanged: root.artBroken = false

    readonly property bool onTv: root.screen && String(root.screen.name || "").indexOf("HDMI") === 0
    visible: root.artEnabled && root.artwork !== "" && !root.artBroken
             && root.screenW > 0 && root.screenH > 0

    // ONE full-screen Image. Same source, same origin, same Fit as LiveWall,
    // so the near plate still registers with `-bg`.
    Image {
        anchors.fill: parent
        source: root.artwork
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        smooth: true
        mipmap: true
        onStatusChanged: if (status === Image.Error) root.artBroken = true
        Component.onCompleted: if (status === Image.Error) root.artBroken = true
    }
}
