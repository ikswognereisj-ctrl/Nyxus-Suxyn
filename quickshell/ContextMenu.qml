// Nyxus Suxyn — the context menu surface. One menu, every surface.
//
// WIP-126. The owner asked for right-click to mean something everywhere:
// "right click on the bottom bar that will bring up something for all that;
// right click the background that would be like create new file etc; just like
// if you right click on an image you can save… I want this thing straight
// flawless with all the works."
//
// ── WHY THIS IS QML AND NOT THE ROFI SCRIPT ───────────────────────────────
//
// `nyxus-context-menu.sh` exists and works, and it stays — see the end of this
// note. But it cannot serve the bar. The bar is a QML surface, and asking it to
// spawn a subprocess to draw a menu *about its own clock* means a second
// process, a second toolkit, a second palette and a round-trip, every time you
// right-click your own taskbar. It would also never match: rofi themed to look
// like Nyxus Glass still is not Nyxus Glass, and the owner's word was
// "flawless".
//
// So the rule from docs/PLAN_CONTEXT_MENUS.md §4 applies — BOTH halves ship,
// and the cheap one is the safety net, exactly as Frame.qml keeps Hyprland's
// own border underneath the living paint. This surface is what you see when
// the shell is running. The script remains the fallback for when it is not,
// and remains the thing shell scripts and GTK apps can call.
//
// ── WHAT MAKES A CONTEXT MENU DIFFERENT FROM A PANEL ──────────────────────
//
// It belongs AT THE POINTER, and it must never leave the screen. That sounds
// obvious and it is exactly what the rofi version got wrong for months: rofi
// centres its window, so the desktop menu read as "its own separate window"
// rather than as a menu belonging to the click that summoned it (the owner
// said so on 2026-08-06). Clamping is not polish either — right-click near the
// bottom-right corner without it and half the entries are off-screen.
//
// Because this is a bar-anchored build, the menu FLIPS rather than merely
// clamping: a click near the bottom opens upward from the pointer, the way
// every taskbar menu on every platform does. Clamping alone would put the
// menu's top-left at the pointer and then shove it up, which slides it out
// from under the cursor.
//
// ── WIP-557 · AND WHY THE DESKTOP'S RIGHT-CLICK NOW COMES IN HERE ──────
//
// The note above says the script "stays" and "remains the fallback for when
// the shell is not running". That was the intent. It is not what shipped.
// Nothing ever asked this surface for a DESKTOP menu: `Menu.openAt` had
// exactly one caller in the entire shell — Bar.qml — so the QML menu served
// the shelf and nothing else. The desktop layer (nyxus_desktop.py) went
// straight to `nyxus-context-menu.sh`, which draws rofi. The "fallback" was
// the only path, which is why the owner kept reporting the same thing: "the
// right mouse click remember the odd one that didnt belong and wasnt themed
// or whatever thats still there."
//
// Measured, not assumed — from his own live session, 2026-08-12:
//
//   07:03:26,164 INFO click button=3 at (125, 432) icon_hit=False
//   07:03:26,167 INFO menu spawned: …/nyxus-context-menu.sh main (pid 94315)
//
// So the desktop asks THIS surface first, over IPC, and reaches the script
// only when it gets no answer — which is what "fallback" was always supposed
// to mean, and is the same pre-flight shape `nyxus-lock-guard` uses against
// the `lock` target.
//
// The IpcHandler lives in this file and not in shell.qml for two reasons: the
// menu's entry point belongs with the menu, and shell.qml already
// instantiates this component, so routing the desktop here costs no edit in a
// file another agent may be holding.
// ── B2-c 2026-08-17 · WHAT EACH PART OF THIS MENU IS, AND WHAT FLOOR IT TAKES
//
// Classify, then judge — audit item 23's method. The two edge ladders in
// `_tokens.edges` have different floors and one exemption between them, so
// naming the wrong ladder is how a value ends up "legal" and wrong at once.
//
//   THE CARD FRAME is a SEAM (`seams.structural`). It divides the menu from
//   whatever you right-clicked; it carries no state and it is not what
//   identifies any control — fill, label and position do that. WCAG 1.4.11
//   therefore EXEMPTS it. The 2.28:1 / 1.14:1 figures below were measured
//   on `Theme.glassBorder` (#891955, rose[4]). Live chrome is glacier[4]
//   (`root.iceHairline`) in the same 1px-seam role. Do not lift them.
//   #891955 in a 1px border was the exact role its demotion permits
//   ("1px dividers only, never a fill") — so unlike the scrollbar thumb and
//   swaync's slider, THIS use of the retired rung is not a defect. It was
//   checked rather than assumed.
//
//   THE SEPARATOR is the same seam, and already teal-at-low-alpha, which is
//   the hue `seams.structural` asks for. 1.21:1, exempt. Unchanged.
//
//   A ROW UNDER THE POINTER IS STATE, at the 3:1 floor with NO exemption:
//   the highlight is the only thing that says which entry will fire, so it is
//   "visual information required to identify … state" in as many words.
//
// AND THAT IS WHERE THIS FILE WAS WRONG. The hover cue was a single field,
// `soften(teal, 0.13)`, measuring 1.14:1 against the card — the state was
// announced at a fifth of its floor. It cannot be fixed by raising the alpha:
// `_findings.teal_alpha_bisection` already proved teal needs alpha >= 0.593 to
// reach 3:1 on this ground, and I re-measured it against this card's own bed
// (0.60 -> 3.05:1). A nearly-solid teal row is not what section 4.9 wants —
// "rows are quiet; only the fill moves", no border, no glow.
//
// The resolution is section 4.9's OWN vocabulary. It already defines a 3:1-
// capable state mark that is neither a border nor a glow — "a 2px left bar in
// accent-primary" — and assigns it to Selected. So the quiet field stays as the
// AMBIENT cue and the solid bar becomes the IDENTIFYING one. The field is no
// longer carrying the requirement alone, so its 1.14:1 is decoration and exempt.
//
// FIVE STATES, and the two that did not exist. Idle, hover, disabled and
// pressed were all here. FOCUS-VISIBLE WAS NOT: this menu had no keyboard
// navigation at all — `Keys.onEscapePressed` and nothing else, `currentIndex`
// pinned at -1 — so a menu opened from the keyboard could not be driven from
// the keyboard, and rev 3 section 3 calls focus-visible "non-negotiable; this
// is the accessibility floor". Arrow/Home/End/Enter now drive it and the
// focused row draws a 2px ring.
//
// HUE-CODED, NOT BRIGHTNESS-CODED, which is the accessibility requirement
// `_why_hue_coded` says the old single ladder structurally could not meet.
// 2026-08-19 owner: drop rose. Live hover is glacier[5] (`root.icePrimary`),
// live focus is glacier[0] (`root.iceInteractive`). The hexes below are the
// rose-era measurements that justified hue-coding, not the current stops:
//
//   hover  #d765a2  (Theme.accentSolidHalo)  6.12:1 on the card's dark bed
//   focus  #0aa2d6  (Theme.teal)             6.98:1 on the same bed
//
// Those are the owner's ruled rungs. `#ae206c` — which accent.json still
// records as `state.hover` — is deliberately NOT used: the owner ruled it
// measures 2.86-3.04:1 on a glass-over-art bed and no fill alpha rescues it,
// and on this card's bed I measure 3.15:1 dark / 1.57:1 light, so it fails
// outright wherever the wallpaper is bright. Reported as a divergence between
// accent.json's `state.hover` and the ruling; accent.json is read-only here.
//
// ⚠ THE BED, AND THE PART THIS DOES NOT FIX. A context menu opens over
// arbitrary content, so it has no fixed ground, and this surface is
// `nyxus-menu` — `nyxus-hyprland-layerblur.conf:55` sets `blur off` for
// `^(nyxus.*)$`, so THE BACKDROP IS NOT EVEN AVERAGED. Measured over the
// darkest and the brightest 248x300 region of all 23 shipped wallpapers,
// composited through `glassFillStrong`, the bed runs L 0.00121 to L 0.05236.
// On the bright end #d765a2 is 3.06:1 (it just holds) and #0aa2d6 is 3.49:1;
// against a single near-white star, with no blur to average it, both fall
// under. Bisected, the card fill would need alpha >= 0.759 for #d765a2 to hold
// 3:1 over white and it ships at 0.66. That is a translucency limit, not a
// colour one, it lives in read-only `Theme.qml`, and it is REPORTED AND OWED
// rather than tuned here.
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root

    // 2026-08-19 · owner palette map: ice rest/hover; magma = danger.
    // One family per row — a danger row is magma, not ice+gold.
    readonly property color iceInteractive: Theme.paintLayers.glacier[0]
    readonly property color icePrimary:     Theme.paintLayers.glacier[5]
    readonly property color iceHairline:    Theme.paintLayers.glacier[4]
    readonly property color magmaInteractive: Theme.paintLayers.magma[0]
    readonly property color magmaPrimary:     Theme.paintLayers.magma[5]

    // `Menu.open` is the request; the fade animation keeps the surface alive
    // through the close so it does not vanish mid-fade.
    //
    // This read `fade.running`, and `fade` was the id of a Behavior. A Behavior
    // has no `running` property, so the whole expression evaluated to UNDEFINED
    // whenever `Menu.open` was false -- and an undefined binding does not
    // assign, so `visible` kept its default of true. The result shipped in
    // 2026.08.07: a full-screen, Overlay-layer, keyboard-Exclusive surface at
    // opacity 0, permanently mapped over everything. It ate every click and
    // every keystroke on the desktop while being completely invisible; only
    // compositor-level keybinds still worked, because Hyprland handles those
    // before any client sees them. qmllint had the answer all along --
    // "Member \"running\" not found on type \"Behavior\"" -- which is why
    // audit.sh now fails on missing-property rather than only counting
    // unresolved types.
    visible: Menu.open || fadeAnim.running

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive, so Escape closes it and so the click that dismisses it cannot
    // also land on whatever is underneath. A menu that closes AND activates
    // the thing behind it is the single most annoying bug in this class.
    //
    // Only while it is actually open, though. Belt and braces after the above:
    // if this surface is ever mapped when it should not be, it must not also be
    // holding the keyboard hostage.
    WlrLayershell.keyboardFocus: Menu.open ? WlrKeyboardFocus.Exclusive
                                           : WlrKeyboardFocus.None
    WlrLayershell.namespace: "nyxus-menu"

    // And it must not eat input either. SidePanel carries the same guard with
    // the same reasoning: an invisible surface with a full-screen input region
    // is indistinguishable from a broken desktop.
    mask: Region {
        width: Menu.open ? root.width : 0
        height: Menu.open ? root.height : 0
    }

    // ── geometry ─────────────────────────────────────────────────────
    readonly property int menuW: 248
    readonly property int padV: Theme.s3
    readonly property int rowH: 36
    readonly property int sepH: 9
    readonly property int titleH: Menu.title.length > 0 ? 26 : 0

    // Measured from the model rather than from the laid-out column, because
    // the position has to be known BEFORE the first frame — a menu that lays
    // out at 0,0 and then jumps to the pointer is visible as a flicker.
    readonly property int bodyH: {
        let h = 0;
        const it = Menu.items || [];
        for (let i = 0; i < it.length; i++)
            h += it[i].separator ? root.sepH : root.rowH;
        return h + 2 * root.padV + root.titleH;
    }

    // Anchor in this surface's coordinates. The surface spans one screen, and
    // Menu carries which screen the click was on.
    readonly property real ax: Menu.anchorX
    readonly property real ay: Menu.anchorY

    // Flip, then clamp. Order matters: flipping decides which corner of the
    // menu sits at the pointer, clamping then keeps that choice on-screen.
    // Owner 2026-08-19: bar-anchored menus keep Theme.s5 of air above chromeH
    // so they do not sit flush on the bar. Desktop clicks (well above the
    // zone) are unchanged.
    readonly property int floorY: root.height - Theme.chromeH - Theme.s5
    readonly property bool flipUp: root.ay + root.bodyH > root.floorY
    readonly property bool flipLeft: root.ax + root.menuW > root.width - 4

    readonly property real px: Math.max(4, Math.min(
        root.flipLeft ? root.ax - root.menuW : root.ax,
        root.width - root.menuW - 4))
    readonly property real py: Math.max(4, Math.min(
        root.flipUp ? root.ay - root.bodyH : root.ay,
        root.floorY - root.bodyH))

    // ── dismissal ────────────────────────────────────────────────────
    // Anywhere outside the card. Accepts every button: right-clicking the
    // desktop while a menu is open should close this one, not stack a second.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: Menu.close()
    }

    // ── keyboard ─────────────────────────────────────────────────────
    // This Item held Escape and nothing else, which is why the menu had no
    // focus-visible state to style: there was no way to focus a row.
    //
    // `Menu.open` gates `focus` as well as the layershell's keyboardFocus, so
    // the closing fade cannot swallow a keystroke meant for the desktop.
    Item {
        anchors.fill: parent
        focus: Menu.open
        Keys.onEscapePressed: Menu.close()
        Keys.onDownPressed:   root.step(1)
        Keys.onUpPressed:     root.step(-1)
        Keys.onReturnPressed: root.activate()
        Keys.onEnterPressed:  root.activate()
        Keys.onSpacePressed:  root.activate()
        // ⚠ Home and End go through the generic handler because `Keys` HAS NO
        // `onHomePressed` / `onEndPressed`. Qt's attached Keys object publishes
        // a fixed list of convenience signals (escape, return, enter, space,
        // the arrows, tab, delete, the digits …) and those two are not on it.
        //
        // Worth recording because of HOW it was found: `qmllint -I shell`
        // reported this file CLEAN with `Keys.onEndPressed` in it, and
        // Quickshell then refused to load the whole shell —
        // "Cannot assign to non-existent property onEndPressed", taking
        // ContextMenu and therefore shell.qml down with it. The lint gate does
        // not resolve attached-property signal names, so a green qmllint is
        // not proof the shell starts. Only running it is.
        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Home) {
                root.jump(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_End) {
                root.jump(-1);
                event.accepted = true;
            }
        }
    }

    // Separators and disabled entries are SKIPPED rather than merely
    // unselectable: landing focus on a divider and making the user press Down
    // again is the same class of defect as a disabled control that still
    // responds to the pointer (rev 3 section 3).
    function selectable(e) {
        return !!e && e.separator !== true && e.enabled !== false;
    }

    // Wraps. `i < 0` seeds from just outside the range in the direction of
    // travel, so the first Down lands on the first row and the first Up on the
    // last one — without that, Up from nothing skips the final entry.
    function step(dir) {
        const it = Menu.items || [];
        if (it.length === 0)
            return;
        let i = list.currentIndex;
        if (i < 0)
            i = dir > 0 ? -1 : it.length;
        for (let n = 0; n < it.length; n++) {
            i = ((i + dir) % it.length + it.length) % it.length;
            if (root.selectable(it[i])) {
                list.currentIndex = i;
                return;
            }
        }
    }

    // Home / End: the first or last selectable entry, found by walking in from
    // the end rather than by index arithmetic, so a menu that begins or ends
    // with a separator still behaves.
    function jump(dir) {
        const it = Menu.items || [];
        let i = dir > 0 ? 0 : it.length - 1;
        while (i >= 0 && i < it.length) {
            if (root.selectable(it[i])) {
                list.currentIndex = i;
                return;
            }
            i += dir;
        }
    }

    function activate() {
        const it = Menu.items || [];
        const i = list.currentIndex;
        if (i < 0 || i >= it.length || !root.selectable(it[i]))
            return;
        root.invoke(it[i]);
    }

    // ONE implementation, two front ends — the pointer's TapHandler and the
    // keyboard's activate() both come here. Writing the close-then-dispatch
    // sequence twice is how the two paths drift, and this repo has shipped that
    // fault before.
    // PATH `nyxus-settings` is NYXUS Panel on this host (`~/.local/bin`,
    // class `io.nyxus.settings`, stars + orbs). Bar.qml still ships
    // `cmd: ["nyxus-settings", …]` (BQ; not edited). Catch it here so every
    // QML menu — Start is already QML, the shelf was not — raises
    // Settings.qml instead of exec'ing the other product.
    function isNyxusSettingsCmd(cmd) {
        if (typeof cmd === "string") {
            if (cmd === "nyxus-settings" || cmd === "@settings") return true;
            return cmd.indexOf("nyxus-settings") !== -1
                || cmd.indexOf("nyxus_settings") !== -1
                || cmd.indexOf("io.nyxus.settings") !== -1;
        }
        if (!cmd || !cmd.length) return false;
        var bin = String(cmd[0]);
        return bin === "nyxus-settings" || bin === "@settings"
            || bin.indexOf("nyxus-settings") !== -1
            || bin.indexOf("nyxus_settings") !== -1
            || bin.indexOf("io.nyxus.settings") !== -1;
    }
    function settingsKeyFromCmd(cmd) {
        if (typeof cmd === "string" || !cmd || cmd.length < 2)
            return "";
        return String(cmd[1]);
    }

    function invoke(entry) {
        if (!!entry.items)
            return;                      // submenu row: nothing to fire yet
        // Close FIRST. An action that opens a window wants the menu already
        // gone, and an action that throws must not leave the menu stuck open
        // over the desktop.
        Menu.close();
        if (typeof entry.action === "function")
            entry.action();
        else if (entry.cmd) {
            if (root.isNyxusSettingsCmd(entry.cmd))
                Bus.openSettings(root.settingsKeyFromCmd(entry.cmd));
            else
                Quickshell.execDetached(entry.cmd);
        }
    }

    // ── the card ─────────────────────────────────────────────────────
    Item {
        id: card
        x: root.px
        y: root.py
        width: root.menuW
        height: root.bodyH

        opacity: Menu.open ? 1 : 0
        Behavior on opacity {
            // The id belongs on the ANIMATION, not the Behavior: a Behavior has
            // no `running` property, so `fade.running` read undefined and the
            // `visible` binding never resolved. See the note on `visible`.
            NumberAnimation {
                id: fadeAnim
                duration: Theme.durQuick
                easing.type: Easing.OutQuad
            }
        }

        // Grows out of the corner the pointer is at, so the menu reads as
        // coming FROM the click rather than appearing near it.
        transform: Scale {
            origin.x: root.flipLeft ? card.width : 0
            origin.y: root.flipUp ? card.height : 0
            xScale: Menu.open ? 1 : 0.94
            yScale: Menu.open ? 1 : 0.94
            Behavior on xScale { NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutCubic } }
            Behavior on yScale { NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutCubic } }
        }

        // Re-layout on a fresh open rather than mutating the open one.
        Connections {
            target: Menu
            function onNonceChanged() { list.currentIndex = -1; }
        }

        // ── 0 · THE OPAQUE FLOOR ────────────────────────────────────
        // TRK-3372. This menu is `WlrLayer.Overlay` — it opens OVER your
        // windows, and every layer below it was alpha, so it passed the
        // 10.6% `SetSlab.qml` measures for exactly this stack. The GTK
        // sheets say the same thing about their own menus in prose ("it
        // can open over a white PDF") and had the same hole. Nothing
        // behind a menu reaches the eye now, and the composited colour
        // does not move — SetSlab carries the arithmetic.
        Rectangle {
            anchors.fill: parent
            radius: Theme.r2
            color: Theme.elevated
            antialiasing: true
        }

        // ── 1 · Start's paint, and 4 · the seam ─────────────────────
        Rectangle {
            anchors.fill: parent
            radius: Theme.r2
            color: Theme.panelMid
            border.width: 1
            border.color: root.iceHairline
            antialiasing: true
        }
        // TRK-3051 — lock (owner 09:40): widgets + right flyout.
        // swellGround under the edge, same three stops as
        // Widgets.qml / SidePanel.qml. Not Pane (pane.frag purple,
        // TRK-2933). Declaration: fill, swell, GlassEdge.
        Rectangle {
            anchors.fill: parent
            radius: Theme.r2
            gradient: Gradient {
                GradientStop { position: 0.00; color: Theme.swellGroundTop }
                GradientStop { position: 0.50; color: Theme.swellGroundMid }
                GradientStop { position: 1.00; color: Theme.swellGroundFoot }
            }
        }

        // Gate 13pu: every layer surface in this shell draws the shared edge.
        GlassEdge {
            anchors.fill: parent
            radiusTL: Theme.r2
            radiusTR: Theme.r2
            radiusBR: Theme.r2
            radiusBL: Theme.r2
            // Lock: body 0. body 1 on glassFillStrong was double
            // density vs widgets + flyout (TRK-3048). Density is the
            // swellGround under this edge, same as SidePanel WIP-265.
            body: 0
            wash: 0
            // TRK-3629 · quieted with the Start menu and the side panel.
            // `edging` scales the Lip and the Sheen — the layers the owner
            // saw stacked on the Start menu's edge on 2026-09-01. This
            // surface had never set it either, so it took the 1.0 default
            // while SidePanel ran 0.85, the widget chips 0.70/0.85, SetSlab
            // 0.46/0.66 and Toasts 0.35. 0.85 is SidePanel's value: the same
            // rung every other floating pane that was actually tuned uses.
            // Nothing else moves — body stays 0, the swell, ReactiveEdge and
            // the seam are untouched.
            edging: 0.85
        }
        ReactiveEdge {
            // TRK-3649 - no resting outer halo. This pane floats over the
            // desktop, so the always-on 8 px band outside its edge read as a
            // second edge - the widgets never drew it. The beat bloom stays.
            haloAtRest: false
            radiusTL: Theme.r2
            radiusTR: Theme.r2
            radiusBR: Theme.r2
            radiusBL: Theme.r2
        }
        // The mirror rim — Launcher.qml § the mirror rim carries the ruling
        // (2026-08-14, "complete … system wide").
        //
        // Z-ROLE (requirement 2, 2026-08-24). This card was wearing SetCard's
        // INLINE weight (depth 12 / strength 0.62) — the rim of a tile that
        // sits INSIDE a page. A context menu is not inside anything: it is a
        // transient interrupt that opens OVER whatever you right-clicked,
        // including over Task View and the picker, both of which carry a
        // heavier rim than this did (TaskView 20/1.0, EmojiPicker 14/0.62).
        // Nothing in the stack said which one was on top.
        //
        // These are NOT new numbers. They are SetChoice.qml's — the tree's
        // other popover modal, the only surface besides PowerMenu at
        // `Pane { elevation: 3 }` — which draws MirrorEdge at depth 14 and
        // the component's default strength 1.0. One popover-modal rim weight,
        // spelled the same in both files.
        MirrorEdge {
            radiusTL: Theme.r2; radiusTR: Theme.r2
            radiusBR: Theme.r2; radiusBL: Theme.r2
            depth: 14
            strength: 1.0
        }

        // Swallow clicks on the card so the dismiss handler behind it does not
        // fire before a row's own handler does.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onPressed: mouse => { mouse.accepted = true; }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: root.padV
            anchors.bottomMargin: root.padV
            spacing: 0

            // What you right-clicked. The whole premise of the menu is that it
            // is ABOUT something, and naming that thing is what makes a bar
            // with eight zones legible.
            Text {
                visible: Menu.title.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: root.titleH
                Layout.leftMargin: Theme.s5
                Layout.rightMargin: Theme.s5
                text: Menu.title
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                font.letterSpacing: Theme.trackMicro
                font.capitalization: Font.AllUppercase
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                interactive: contentHeight > height + 1
                currentIndex: -1
                model: Menu.items
                ScrollRail { flick: list }

                delegate: Loader {
                    required property var modelData
                    required property int index
                    width: list.width
                    height: modelData.separator ? root.sepH : root.rowH
                    sourceComponent: modelData.separator ? sepC : rowC

                    // Loader does not forward the model to its item, and the
                    // component cannot reach `modelData` through it either —
                    // so hand both across explicitly. Getting this wrong is
                    // silent: the row renders with a blank label.
                    onLoaded: {
                        if (!modelData.separator) {
                            item.entry = modelData;
                            item.idx = index;
                        }
                    }
                }
            }
        }
    }

    // ══ WIP-557 · THE DESKTOP'S RIGHT-CLICK ═════════════════════
    //
    // The actions are NOT reimplemented here. Every one of them that is more
    // than "launch this program" is dispatched to `nyxus-context-menu.sh act
    // …`, a mode that draws nothing at all. One implementation of "make a
    // uniquely-named New Folder", one of "poke the desktop's IPC socket", two
    // front ends. Rewriting them in JS would be a second answer to the same
    // question, and this repo has shipped that fault five times.
    readonly property string ctxScript: "nyxus-context-menu.sh"

    function actCmd(action, arg) {
        return arg === undefined ? [root.ctxScript, "act", action]
                                 : [root.ctxScript, "act", action, arg];
    }

    // Sort is a menu of its own rather than a submenu: submenus are WIP-126
    // phase 2 and the row delegate still renders `items` as an inert "›".
    // Re-opening at the SAME anchor is what the rofi version did (`exec "$0"
    // sort`) and it reads correctly — the second menu replaces the first
    // where the first one stood.
    function sortEntries() {
        return [
            { label: qsTr("By name"),          cmd: root.actCmd("sort", "name") },
            { label: qsTr("By kind"),          cmd: root.actCmd("sort", "kind") },
            { label: qsTr("By date modified"), cmd: root.actCmd("sort", "mtime") },
            { label: qsTr("By size"),          cmd: root.actCmd("sort", "size") },
            { separator: true },
            { label: qsTr("Snap to grid"),     cmd: root.actCmd("sort", "grid") },
            { label: qsTr("Auto-arrange"),     cmd: root.actCmd("sort", "auto") }
        ];
    }

    function desktopEntries() {
        return [
            { label: qsTr("New folder"),        cmd: root.actCmd("new-folder") },
            { label: qsTr("New text file"),     cmd: root.actCmd("new-text-file") },
            { separator: true },
            { label: qsTr("Open in terminal"),  cmd: root.actCmd("open-terminal") },
            { label: qsTr("Open Files"),        cmd: root.actCmd("open-files") },
            { label: qsTr("Recents"),           cmd: root.actCmd("recents") },
            { label: qsTr("Eject USB"),         cmd: root.actCmd("usb") },
            { separator: true },
            { label: qsTr("Change wallpaper…"), cmd: ["nyxus-wallpaper-studio"] },
            // QML Settings — do not exec `nyxus-settings`. On this host PATH
            // finds ~/.local/bin/nyxus-settings (NYXUS Panel, stars + orbs).
            // Bus.openSettings is the one choke point (WIP-599 / TRK-923).
            { label: qsTr("Personalize…"), action: function () {
                Bus.openSettings("appearance");
            } },
            { label: qsTr("Display settings"), action: function () {
                Bus.openSettings("display");
            } },
            { label: qsTr("Sort icons…"), action: function () {
                Menu.openAt(Menu.anchorX, Menu.anchorY, root.sortEntries(),
                            Menu.anchorScreen, "Sort icons");
            } },
            { label: qsTr("Refresh desktop"),   cmd: root.actCmd("refresh") },
            { separator: true },
            { label: qsTr("System info"), action: function () {
                Bus.openSettings("about");
            } },
            // WIP-114: never lock an account with no password. The guard is
            // the single choke point for every lock route in this build.
            { label: qsTr("Lock screen"),       cmd: ["nyxus-lock-guard"] },
            { label: qsTr("Power…"), action: function () { Bus.togglePower(); } }
        ];
    }

    function iconTitle(path) {
        var s = String(path || "");
        var n = s.lastIndexOf("/");
        return n < 0 ? s : s.slice(n + 1);
    }

    // TRK-1510 · per-icon right-click. Rows match nyxus-context-menu.sh
    // `_icon_menu` and dispatch through `act`, so Open with / Rename / Delete
    // keep the script's pickers instead of a second implementation. "Set as
    // wallpaper" lives HERE, not in desktopEntries — that split is what
    // 13q38 now computes (it used to forbid the string anywhere in this file
    // because this file had no per-file mode).
    function iconEntries(path, isImage) {
        var rows = [
            { label: "Open",                   cmd: root.actCmd("open", path) },
            { label: "Open with…",             cmd: root.actCmd("open-with", path) },
            { label: "Open containing folder", cmd: root.actCmd("open-folder", path) },
            { label: "Open in terminal",       cmd: root.actCmd("open-terminal", path) },
            { label: "Open as root",           cmd: root.actCmd("open-root", path) },
            { label: "Copy path",              cmd: root.actCmd("copy-path", path) },
            { label: "Copy file",              cmd: root.actCmd("copy-file", path) },
            { label: "Previous versions",      cmd: root.actCmd("prev-versions", path) }
        ];
        if (isImage)
            rows.push({ label: "Set as wallpaper", cmd: root.actCmd("wallpaper", path) });
        rows.push(
            { label: "Rename…",            cmd: root.actCmd("rename", path) },
            { label: "Scan with Hemera",   cmd: root.actCmd("scan", path) },
            { label: "Move to Trash",      cmd: root.actCmd("trash", path) },
            { label: "Delete permanently", danger: true,
              cmd: root.actCmd("delete", path) },
            { label: "Properties",         cmd: root.actCmd("properties", path) }
        );
        return rows;
    }

    IpcHandler {
        target: "menu"

        // ⚠ EVERY function returns a STRING, for the reason shell.qml records
        // against the `lock` target: `qs ipc call` prints "Target not found."
        // and still exits 0, so a caller cannot use the exit status to tell
        // "the shell drew the menu" from "there is no shell". nyxus_desktop.py
        // matches the OUTPUT, and falls back to the rofi script on anything
        // else — including this handler never having been reached.
        function ready(): string { return "ready"; }

        // x/y are SCREEN coordinates. The desktop layer spans the whole
        // output at the BOTTOM layer with no margins, so its surface-local
        // click coordinates are already screen coordinates — the mapToGlobal
        // trap Bar.qml documents (WIP-135) does not apply here.
        function desktop(x: int, y: int): string {
            Menu.openAt(x, y, root.desktopEntries(), null, "Desktop");
            return "opened";
        }

        // TRK-1510 · icon(x, y, path, kind). kind is "image" or anything
        // else; "image" is the only value that shows Set as wallpaper
        // (GAP-937: a row that always appears and works on one file in ten
        // teaches people it is broken).
        function icon(x: int, y: int, path: string, kind: string): string {
            var p = String(path || "");
            if (!p.length)
                return "missing";
            Menu.openAt(x, y, root.iconEntries(p, kind === "image"),
                        null, root.iconTitle(p));
            return "opened";
        }
    }

    // ── a separator ──────────────────────────────────────────────────
    Component {
        id: sepC
        Item {
            Rectangle {
                anchors.centerIn: parent
                width: parent.width - 2 * Theme.s5
                height: 1
                color: root.iceHairline
            }
        }
    }

    // ── a row ────────────────────────────────────────────────────────
    Component {
        id: rowC
        Item {
            id: rowRoot
            property var entry: ({})
            property int idx: -1
            readonly property bool on: rowRoot.entry.enabled !== false
            // Pointer hover and keyboard focus are tracked SEPARATELY and drawn
            // differently. Collapsing them into one "highlighted" flag is what
            // makes keyboard focus indistinguishable from hover, which rev 3
            // section 7 forbids outright.
            readonly property bool hovered: hov.hovered && rowRoot.on
            readonly property bool focused: list.currentIndex === rowRoot.idx
                                            && rowRoot.on
            readonly property bool hot: rowRoot.entry.danger === true
            readonly property color keyInteractive: rowRoot.hot ? root.magmaInteractive : root.iceInteractive
            readonly property color keyPrimary: rowRoot.hot ? root.magmaPrimary : root.icePrimary

            Rectangle {
                id: field
                anchors.fill: parent
                anchors.leftMargin: Theme.s2
                anchors.rightMargin: Theme.s2
                radius: Theme.r1
                // A hover FIELD, not a hover glow. §3.5 of the design language
                // reserves luminance for edges; a filled highlight is what a
                // list row does everywhere and is the one place a field reads
                // as correct rather than heavy.
                //
                // It is now the AMBIENT half of the cue only — 1.14:1, and no
                // longer the thing that identifies the state, so it is exempt
                // decoration rather than a component indicator under its floor.
                // The `mark` below is what carries the 3:1 requirement.
                color: tap.pressed
                       ? Theme.soften(rowRoot.keyPrimary, 0.18)
                       : (rowRoot.hovered
                          ? Theme.soften(rowRoot.keyInteractive, 0.13) : "transparent")
                Behavior on color { ColorAnimation { duration: Theme.durQuick } }

                // FOCUS-VISIBLE. A 2px ring, per rev 3 §3, in a DIFFERENT HUE
                // from hover rather than a brighter one — `_why_hue_coded` is
                // explicit that a brightness step does not satisfy the
                // requirement for anyone who cannot compare two intensities of
                // the same colour side by side. 6.98:1 on this card's dark bed.
                border.width: rowRoot.focused ? 2 : 0
                border.color: rowRoot.keyInteractive
            }

            // THE STATE MARK — §4.9's own 2px left bar, which is the one 3:1-
            // capable state indicator that section allows on a row (it is not a
            // border and not a glow). Hover takes the ruled hover rung; focus
            // takes the ruled focus rung, so the bar agrees with the ring.
            Rectangle {
                anchors.left: field.left
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: parent.height - Theme.s2
                radius: 1
                color: rowRoot.focused ? rowRoot.keyInteractive : rowRoot.keyPrimary
                opacity: (rowRoot.focused || rowRoot.hovered) ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Theme.durQuick } }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.s5
                anchors.rightMargin: Theme.s5
                spacing: Theme.s4

                // The tick column. Always present, so labels align whether or
                // not a given menu has checkable entries in it.
                Text {
                    Layout.preferredWidth: 11
                    text: rowRoot.entry.check === true ? "✓" : ""
                    color: root.iceInteractive
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tLabel
                }

                Text {
                    Layout.fillWidth: true
                    text: rowRoot.entry.label || ""
                    // Danger is MAGMA, and on the LABEL only.
                    //
                    // Owner 2026-08-19: destructive = magma family. Gold was
                    // the old signal (PowerMenu armed seam). Magma is the
                    // map now; ice chrome stays on ordinary rows. On the
                    // label and never as a fill — §3.5 still forbids a
                    // filled accent row.
                    color: !rowRoot.on ? Theme.textDim
                           : (rowRoot.hot ? root.magmaInteractive : Theme.text)
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tBody
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                }

                // Submenu affordance is WIP-126 phase 2. A chevron that does
                // nothing is a lie; hide it until the row can actually open.
                Text {
                    visible: false
                    text: "›"
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tHead
                }
            }

            // Disabled rows are INERT — no hover response at all, which rev 3
            // §3 calls a bug when it is otherwise.
            HoverHandler { id: hov; enabled: rowRoot.on }

            // Moving the pointer onto a row takes keyboard focus with it, so the
            // ring and the pointer can never point at two different entries at
            // once. Without this, arrowing down and then reaching for the mouse
            // leaves two rows lit and Enter fires the one you are not touching.
            onHoveredChanged: if (rowRoot.hovered) list.currentIndex = rowRoot.idx

            TapHandler {
                id: tap
                enabled: rowRoot.on && !rowRoot.entry.items
                onTapped: root.invoke(rowRoot.entry)
            }
        }
    }
}
