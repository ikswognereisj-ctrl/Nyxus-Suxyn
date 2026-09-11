pragma ComponentBehavior: Bound
// Nyxus Suxyn — a settings CHOICE. One value out of a known set.
//
// Two renderings of the same control, chosen by how many options there are,
// because the right shape for three is not the right shape for thirty:
//
//   SEGMENTED   up to `segmentLimit` options, all visible at once. Every
//               choice is on screen and one click away, and you can see what
//               the alternatives ARE without opening anything. This is right
//               for "Flat / Adaptive", "Fill / Fit / Stretch", "12 / 24 hour".
//
//   MENU        more than that, or long labels. A button showing the current
//               value, which opens a list. Right for cursor themes, printers,
//               time zones — sets that are long, or that the system discovers
//               at runtime and we cannot lay out in advance.
//
// The menu is parented to the WINDOW's content item, not to the row. A popup
// that is a child of a row inside a `Flickable` is clipped by the Flickable
// and scrolls away underneath the thing that opened it. `Window.window` is how
// a QML item reaches its own window without anyone passing it down.
//
// `options` is a list of `{ value, label }` — and optionally `sub` for a
// second line, which is what makes a printer list ("HP LaserJet · Ready ·
// USB") readable. Plain strings are accepted too and become their own labels.
import QtQuick
import QtQuick.Layouts

Item {
    id: choice

    property string key: ""
    property var defaultValue: ""

    property var options: []
    property int segmentLimit: 4

    property var value: choice.key !== ""
                        ? SettingsStore.value(choice.key, choice.defaultValue)
                        : choice.defaultValue

    readonly property color iceHairline: Theme.paintLayers.glacier[4]
    // Typed wrappers — paintLayers rungs are hex strings; Theme.soften
    // reads .r/.g/.b. Passing a string is the PQ 08-21 NaN-black cut.
    readonly property color markWash: Theme.paintLayers.glacier[3]
    // TRK-3060 — 5 px sheen only: glacier peak toward swirl teal glow.
    // Mix at the call site. Both args are already `property color`.
    readonly property color swirlPeak: Theme.mix(Theme.tokenAccentPeak, Theme.tealGlow, 0.30)

    property real tone: 0.35
    readonly property color markFocus: Theme.paintLayers.glacier[0]
    // Kept so SetPage* callers (`tone: page.tone`) do not break. Paint is
    // StateEdge — never sweepAt(tone).

    // Shown in the button when the set is empty — a discovered set (printers,
    // Bluetooth devices, cursor themes) legitimately has nothing in it, and
    // "None found" is information where an empty box is a defect report.
    property string emptyText: qsTr("None found")

    signal chosen(var value)

    readonly property var _opts: {
        var out = [];
        for (var i = 0; i < choice.options.length; ++i) {
            var o = choice.options[i];
            if (typeof o === "string")
                out.push({ value: o, label: o, sub: "" });
            else
                out.push({ value: o.value, label: o.label === undefined ? String(o.value) : o.label,
                           sub: o.sub === undefined ? "" : o.sub });
        }
        return out;
    }

    readonly property bool segmented: choice._opts.length > 0
                                      && choice._opts.length <= choice.segmentLimit

    readonly property string currentLabel: {
        for (var i = 0; i < choice._opts.length; ++i)
            if (choice._opts[i].value === choice.value)
                return choice._opts[i].label;
        return choice._opts.length === 0 ? choice.emptyText : String(choice.value);
    }

    implicitWidth: segmented ? segRow.implicitWidth : Math.max(150, btn.implicitWidth)
    implicitHeight: 28
    activeFocusOnTab: true
    opacity: choice.enabled ? 1.0 : 0.4
    Keys.onSpacePressed: {
        if (!choice.segmented && choice._opts.length > 0)
            menu.open ? menu.close() : menu.show();
    }
    Keys.onReturnPressed: {
        if (!choice.segmented && choice._opts.length > 0)
            menu.open ? menu.close() : menu.show();
    }
    // ── TRK-3730 · THE SEGMENTED FORM COULD BE FOCUSED BUT NOT OPERATED ──
    // `activeFocusOnTab` is true for BOTH renderings, but only the dropdown
    // answered the keyboard (Space/Return open the menu). A segmented choice
    // took the Tab stop, showed no focus ring, and did nothing to any key —
    // a control you can land on and not use, which is worse than one you
    // cannot reach. Arrows step through the options exactly as a native
    // segmented control does; the ring is on the selected chip below.
    Keys.onLeftPressed:  if (choice.segmented) choice._step(-1)
    Keys.onRightPressed: if (choice.segmented) choice._step(1)

    // Move the selection by `dir` among the options, clamped at the ends —
    // the same walk the arrow keys make on the menu form's list.
    function _step(dir) {
        if (choice._opts.length === 0)
            return;
        var cur = -1;
        for (var i = 0; i < choice._opts.length; ++i)
            if (choice._opts[i].value === choice.value) { cur = i; break; }
        var next = cur < 0 ? (dir > 0 ? 0 : choice._opts.length - 1)
                           : Math.max(0, Math.min(choice._opts.length - 1, cur + dir));
        choice.select(choice._opts[next].value);
    }

    function select(v) {
        if (choice.key !== "")
            SettingsStore.setValue(choice.key, v);
        else
            choice.value = v;
        choice.chosen(v);
        DiagnosticBus.logChoice(choice.key, v);
        menu.close();
    }

    // ── SEGMENTED ───────────────────────────────────────────────────────
    // ── TRK-3645 · THE OUTER FRAME IS GONE ──────────────────────────────
    // It used to draw a hairline at `Theme.r1` = 8, offset -3, wrapping
    // chips that draw their own hairline at `Theme.r1 - 2` = 6.
    //
    // Concentricity across a 3 px gap requires inner = outer - gap = 5. It
    // was 6. So the two contours disagreed by exactly 1 px all the way
    // round — small, constant, and unfixable by eye, which is precisely the
    // "nested bevel" that makes a control read as a 2010 toolbar.
    //
    // Re-deriving the inner radius would make them agree. DELETING the outer
    // one means they CANNOT disagree, and leaves no arithmetic to get wrong
    // the next time somebody changes `r1`. One contour cannot contradict
    // itself. Segments are separate slabs now, 4 px apart (see `spacing`),
    // and the selected one is named by a filled ground plus one bright edge
    // — the same two-states-two-treatments rule SetIceFace uses one level up.

    RowLayout {
        id: segRow
        visible: choice.segmented
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        // TRK-3645: 2 -> 4. With no frame around them the chips need enough
        // void between them to read as separate objects rather than as one
        // strip with seams; 4 is `Theme.s6`'s half-step and matches the
        // switch's 3 px inset family closely enough not to introduce a fifth
        // spacing value into the page.
        spacing: 4

        Repeater {
            model: choice.segmented ? choice._opts : []
            delegate: Item {
                id: seg
                required property var modelData
                readonly property bool on: modelData.value === choice.value
                implicitWidth: segText.implicitWidth + 2 * Theme.s5
                // TRK-3645: 22 -> 26. The dropdown form of this very control
                // is already 26 (see `btn` below), and the switch is now 26.
                // A segmented chip at 22 made the same control two different
                // heights depending on how many options it happened to have.
                implicitHeight: 26

                // ── TRK-3685 · THE SEGMENT WAS THE ONE CHIP WITH NO SKIN ────
                // Everything else in the settings kit is built the same way and
                // has been since TRK-3023/3029/3060: a body, a 1 px glacier[4]
                // SEAM, a 5 px peak sheen along the top and a 3 px glacier[0]
                // lip under it. `btn` — the DROPDOWN FORM OF THIS VERY CONTROL,
                // 200 lines below in this same file — does exactly that.
                //
                // The segment had none of it. No seam, no sheen, no lip: a bare
                // transparent rectangle whose only contour was StateEdge's idle
                // seam. Photographed beside the other five on
                // `docs/proof/controls-0901/before.png` it is the chip made of
                // different stuff, and the icon set that landed the same day
                // (`docs/proof/icons-0901/suite-128.png`) says the same thing at
                // tile scale: ground, rim, a lit band across the top, a glacier
                // mark. That band is what these controls have been calling a
                // sheen; the icons made it the identity cue.
                //
                // This is the "one surface is right and the rest are wrong"
                // method applied INSIDE ONE FILE. Nothing is invented here —
                // every number is lifted from `btn` below, scaled to 26 px by
                // the same expressions.
                //
                // ⚠ AND THE STATE EDGE IS GATED AT IDLE, for the reason `btn`
                // already records: StateEdge's `seamIdle` is glacier[0]@0.22,
                // which paints OVER the glacier[4] hairline and replaces a steel
                // seam with a pale cyan one. `btn` was migrated for that in
                // TRK-3023; the segment never was. Same defect, same file, two
                // renderings of one control — which is exactly how a decision
                // gets applied to half a product.
                Rectangle {
                    id: segFace
                    anchors.fill: parent
                    radius: Theme.r1 - 2
                    antialiasing: true
                    border.width: 1
                    border.color: choice.iceHairline
                    // ── TRK-3645 · SELECTED IS A GROUND, NOT ONLY AN EDGE ──
                    // With the outer frame gone the chips are free-standing
                    // slabs, so the selected one has to be named by the slab
                    // itself rather than by its relationship to a container
                    // that no longer exists. This is SetIceFace's `grounded`
                    // rung, the same one the new primary button uses.
                    //
                    // Behind SwirlChip (z:0), so the owner's 10:18 ruling —
                    // "selected / latched chips must keep moving or they read
                    // as OFF" — still holds: the paint runs on top of it.
                    color: seg.on ? Theme.soften(Theme.tokenAccentGround, 0.55)
                                  : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.durQuick } }

                    // ── the swirls ───────────────────────────────────
                    // Same tuned paint as the flyout pills and the settings
                    // switches: `SwirlChip` in `bare` mode, never a copy of
                    // its constants. One material, every host.
                    //
                    // Owner 10:18: selected / latched chips must keep
                    // moving or they read as OFF. StateEdge + DemiBold
                    // still name which segment is chosen.
                    SwirlChip {
                        id: segSwirl
                        anchors.fill: parent
                        z: 0
                        bare: true
                        cornerRadius: Theme.r1 - 2
                        active: seg.on
                        enabled: choice.enabled
                        hostHovered: segHov.hovered
                        hostPressed: segTap.pressed
                        liveWhileLatched: true
                    }

                    // The type scrim. A segment is 26 px with a centred word
                    // across it, so there is less room here than on a pill —
                    // accent.json _swirl rule 5 (colour never goes behind
                    // text) is the tighter constraint at this size, and the
                    // scrim is correspondingly heavier.
                    Rectangle {
                        anchors.fill: parent
                        z: 1
                        radius: Theme.r1 - 2
                        visible: segHov.hovered || segTap.pressed
                        color: Theme.soften(Theme.void_, 0.06)
                    }

                    // TRK-3685 — the crown, `btn`'s numbers scaled to 26 px:
                    // sheen min(5, round(26 * 0.14)) = 4, lip
                    // min(3, round(26 * 0.10)) = 3. Straights only, inset by the
                    // chip's own radius so the band never enters the corner
                    // (GlassEdge TRK-932), and capsule-ended so it reads as the
                    // same brow the icon tiles carry rather than as a cut-off
                    // stripe. Sheen is a sheen, not a fill.
                    Rectangle {
                        id: segSheen
                        z: 2
                        y: 1
                        height: Math.min(5, Math.max(2, Math.round(parent.height * 0.14)))
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.r1 - 2
                        anchors.rightMargin: Theme.r1 - 2
                        radius: height / 2
                        // The crown carries SELECTION as well as hover. That is
                        // the icon set's own rule read straight across — the lit
                        // band across the top is what says which tile you are
                        // looking at — and it means the chosen segment is named
                        // on TWO axes (ground + crown) plus the DemiBold label,
                        // never by colour alone.
                        color: Theme.soften(choice.swirlPeak,
                                            (segHov.hovered || segTap.pressed) ? 0.40
                                          : seg.on ? 0.55 : 0.22)
                        Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                    }

                    Rectangle {
                        id: segLip
                        z: 2
                        y: segSheen.y + segSheen.height
                        height: Math.min(3, Math.max(2, Math.round(parent.height * 0.10)))
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: Theme.r1 - 2
                        anchors.rightMargin: Theme.r1 - 2
                        radius: height / 2
                        color: Theme.soften(choice.markFocus,
                                            (segHov.hovered || segTap.pressed) ? 0.22
                                          : seg.on ? 0.28 : 0.12)
                        Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                    }

                    StateEdge {
                        z: 2
                        hovered: segHov.hovered
                        // TRK-3730 — the keyboard focus lands on the CONTROL,
                        // and the selected chip is what carries the ring, so
                        // arrow-stepping (above) has a visible anchor. Teal
                        // focus rung over the selected chip; hue, not alpha,
                        // is what keeps it distinct from hover (StateEdge §3).
                        focusRing: choice.activeFocus && choice.segmented && seg.on
                        pressed: segTap.pressed
                        checked: seg.on
                        controlEnabled: choice.enabled
                        radius: Theme.r1 - 2
                        // Idle is the face's glacier[4] seam, not glacier[0]@0.22
                        // painted over it — `btn`'s TRK-3023 rule, migrated.
                        visible: segHov.hovered || segTap.pressed || seg.on
                               || (choice.activeFocus && choice.segmented && seg.on)
                    }
                }

                Text {
                    id: segText
                    anchors.centerIn: parent
                    text: seg.modelData.label
                    color: seg.on || segHov.hovered || segTap.pressed ? Theme.text : Theme.textMuted
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tLabel
                    font.weight: seg.on ? Font.DemiBold : Font.Normal
                    Behavior on color { ColorAnimation { duration: Theme.durQuick } }
                }

                HoverHandler { id: segHov; enabled: choice.enabled; cursorShape: Qt.PointingHandCursor }
                TapHandler { id: segTap; enabled: choice.enabled; onTapped: choice.select(seg.modelData.value) }
            }
        }
    }

    // ── MENU BUTTON ─────────────────────────────────────────────────────
    // TRK-3029 — closed chip was the same empty plate SetButton was:
    // void_@0.50, no seam, no thickness. Same cut-glass as TRK-3023:
    // 1 px glacier[4] hairline, 5 px peak sheen, 3 px glacier[0] lip,
    // hover glacier[3]@0.18. Height stays 26. Segmented SwirlChip /
    // StateEdge, popover crown (TRK-3012), delegates, createObject
    // are not this block.
    Rectangle {
        id: btn
        visible: !choice.segmented
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: btnText.implicitWidth + chev.implicitWidth + 3 * Theme.s4
        width: Math.max(implicitWidth, choice.width)
        height: 26
        radius: Theme.r1
        antialiasing: true
        color: Theme.soften(Theme.void_, 0.34)
        border.width: 1
        border.color: choice.iceHairline

        SwirlChip {
            id: btnSwirl
            anchors.fill: parent
            anchors.margins: 1
            z: 0
            bare: true
            cornerRadius: Theme.r1
            enabled: choice.enabled && choice._opts.length > 0
            hostHovered: btnHov.hovered
            hostPressed: btnTap.pressed
        }

        // Hover wash. Typed markWash — never soften(paintLayers.glacier[3]).
        Rectangle {
            anchors.fill: parent
            z: 1
            radius: Theme.r1
            visible: btnHov.hovered || btnTap.pressed
            color: Theme.soften(choice.markWash, 0.06)
        }

        // TRK-3060 — inner 5 px sheen along the TOP (glacier peak ×
        // tealGlow 0.30), then a 3 px glacier[0] lip under it. Straights
        // only, inset by r1 so the band never enters the corner (GlassEdge
        // TRK-932). Sheen is a sheen, not a fill. Calendar fail: 1 px
        // is invisible. Segmented / popover / createObject are not this block.
        Rectangle {
            id: iceSheen
            z: 2
            y: 1
            height: Math.min(5, Math.max(2, Math.round(parent.height * 0.14)))
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.r1
            anchors.rightMargin: Theme.r1
            // TRK-3685 — capsule ends. The icon tiles' brow is a rounded bar,
            // not a cut stripe; a square-ended band inside a rounded body is
            // the one detail that made these read as painted-on rather than
            // built-in. Same one-line change in SetButton, SetChoice's
            // segments and TogglePill, so all four crowns are one shape.
            radius: height / 2
            color: Theme.soften(choice.swirlPeak,
                                (btnHov.hovered || btnTap.pressed) ? 0.40 : 0.22)
        }

        Rectangle {
            id: iceLip
            z: 2
            y: iceSheen.y + iceSheen.height
            height: Math.min(3, Math.max(2, Math.round(parent.height * 0.10)))
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Theme.r1
            anchors.rightMargin: Theme.r1
            radius: height / 2                     // TRK-3685 — capsule ends
            color: Theme.soften(choice.markFocus,
                                (btnHov.hovered || btnTap.pressed) ? 0.22 : 0.12)
        }

        // Hidden at idle so seams.idle glacier[0]@0.22 cannot cover the
        // glacier[4] hairline (BTN TRK-3023). Hover / press / focus /
        // open still get StateEdge.
        StateEdge {
            z: 2
            hovered: btnHov.hovered
            focusRing: choice.activeFocus
            pressed: btnTap.pressed
            checked: menu.open
            controlEnabled: choice.enabled && choice._opts.length > 0
            radius: Theme.r1
            visible: btnHov.hovered || btnTap.pressed
                     || choice.activeFocus || menu.open
        }

        Text {
            id: btnText
            z: 3
            anchors.left: parent.left
            anchors.leftMargin: Theme.s4
            anchors.right: chev.left
            anchors.rightMargin: Theme.s3
            anchors.verticalCenter: parent.verticalCenter
            text: choice.currentLabel
            color: choice._opts.length === 0 ? Theme.textDim : Theme.text
            font.family: Theme.fUi
            font.pixelSize: Theme.tLabel
            elide: Text.ElideRight
        }

        Text {
            id: chev
            z: 3
            anchors.right: parent.right
            anchors.rightMargin: Theme.s4
            anchors.verticalCenter: parent.verticalCenter
            text: "\uf078"                       // chevron-down
            font.family: Theme.fIcon
            font.pixelSize: Theme.tCaption
            color: btnHov.hovered || menu.open || choice.activeFocus
                   ? choice.markFocus : Theme.textMuted
            Behavior on color { ColorAnimation { duration: Theme.durQuick } }
        }

        HoverHandler {
            id: btnHov
            enabled: choice.enabled && choice._opts.length > 0
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            id: btnTap
            enabled: choice.enabled && choice._opts.length > 0
            onTapped: {
                menu.open ? menu.close() : menu.show();
                btnSwirl.ignite();
            }
        }
    }

    // ── the menu ────────────────────────────────────────────────────────
    // Created into the window's content item on demand and destroyed on close,
    // so a settings window with forty choice controls in it is not carrying
    // forty hidden list views. `Component` + `createObject` rather than a
    // Loader, because the parent is decided at open time.
    QtObject {
        id: menu
        property bool open: false
        property var instance: null

        function show() {
            if (menu.instance)
                menu.close();
            var host = choice.Window.window ? choice.Window.window.contentItem : null;
            if (!host) {
                console.warn("SetChoice: no window to host the menu — "
                             + "the control is not in a window yet.");
                return;
            }
            var pt = choice.mapToItem(host, 0, choice.height + 4);
            // Flip upward when there is not room below. A menu that opens off
            // the bottom of the window is a menu you cannot use.
            var wanted = Math.min(280, choice._opts.length * 34 + 8);
            var below = host.height - pt.y;
            var y = below < wanted ? Math.max(4, pt.y - choice.height - 8 - wanted) : pt.y;
            menu.instance = menuComponent.createObject(host, {
                "x": Math.max(4, Math.min(host.width - 240 - 4, pt.x - 240 + choice.width)),
                "y": y,
                "menuWidth": 240,
                "menuHeight": wanted
            });
            menu.open = true;
        }

        function close() {
            if (menu.instance) {
                menu.instance.destroy();
                menu.instance = null;
            }
            menu.open = false;
        }
    }

    // Closing when the control leaves the scene matters: a page swap while a
    // menu is open would otherwise leave an orphan list floating in the window
    // with nothing behind it.
    Component.onDestruction: menu.close()
    onVisibleChanged: if (!visible) menu.close()

    Component {
        id: menuComponent

        Item {
            id: pop
            property int menuWidth: 240
            property int menuHeight: 200
            width: menuWidth
            height: menuHeight
            z: 9000

            // The click-away catcher, sized to the whole window and BEHIND the
            // list. Without it the only way to dismiss is to pick something,
            // which is not a choice, it is a demand.
            Item {
                parent: pop.parent
                anchors.fill: parent
                z: pop.z - 1
                TapHandler { onTapped: menu.close() }
            }

            Pane {
                anchors.fill: parent
                elevation: 3
                radius: Theme.r2
                // TRK-3370 — the widgets' stack: opaque elevated floor as
                // the Pane fill, panelMid + swellGround below, body 0 (a
                // body over the slab is the WIP-259 failure). Supersedes the
                // soften(void_) wash + body 1 this popover carried.
                fill: Theme.elevated

                HoverHandler { id: popHov }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.r2
                    color: Theme.panelMid
                }
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.r2
                    gradient: Gradient {
                        GradientStop { position: 0.00; color: Theme.swellGroundTop }
                        GradientStop { position: 0.50; color: Theme.swellGroundMid }
                        GradientStop { position: 1.00; color: Theme.swellGroundFoot }
                    }
                }

                GlassEdge {
                    anchors.fill: parent
                    radiusTL: Theme.r2; radiusTR: Theme.r2
                    radiusBR: Theme.r2; radiusBL: Theme.r2
                    body: 0
                    wash: 0
                    glaze: 0.7
                    edging: 0.9
                }
                // TRK-3012 — ice crown on the popover face. Same 1 px
                // glacier[6] hairline as Widgets TRK-3003. Not a second
                // Pane. No Item.scale.
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Theme.r2
                    anchors.rightMargin: Theme.r2
                    y: 1
                    height: 1
                    color: Theme.soften(Theme.tokenAccentPeak,
                                        popHov.hovered ? 0.70 : 0.38)
                }
                MirrorEdge {
                    // TRK-3653 - depth 14 was set and strength was not; 0.62 is what every other depth-12/14 surface runs.
                    // It had no `strength`, so it took the component default while
                    // the rest of the build had moved off it. Found by
                    // docs/proof/audit-0901/glass-consistency.py, not by eye.
                    strength: 0.62
                    radiusTL: Theme.r2; radiusTR: Theme.r2
                    radiusBR: Theme.r2; radiusBL: Theme.r2
                    depth: 14
                }
            }

            ListView {
                id: choiceList
                ScrollRail { flick: choiceList }
                anchors.fill: parent
                anchors.margins: 4
                clip: true
                model: choice._opts
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: -1

                delegate: Item {
                    id: opt
                    required property var modelData
                    width: ListView.view.width
                    height: modelData.sub === "" ? 30 : 42
                    readonly property bool on: modelData.value === choice.value

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 1
                        radius: Theme.r1 - 2
                        color: "transparent"

                        StateEdge {
                            hovered: optHov.hovered
                            focusRing: false
                            pressed: optTap.pressed
                            checked: opt.on
                            controlEnabled: true
                            radius: Theme.r1 - 2
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.s5
                        anchors.rightMargin: Theme.s5
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            text: opt.modelData.label
                            color: Theme.text
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tLabel
                            font.weight: opt.on ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: opt.modelData.sub !== ""
                            text: opt.modelData.sub
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                            elide: Text.ElideRight
                        }
                    }

                    HoverHandler { id: optHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: optTap; onTapped: choice.select(opt.modelData.value) }
                }
            }
        }
    }
}
