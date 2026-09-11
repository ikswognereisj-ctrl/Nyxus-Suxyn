// Nyxus Suxyn — the emoji & symbol picker. WIP-704 · GAP-B7 · GAP-923.
//
// Super+. (the key Windows uses for the same thing, and free in every one of
// this build's hypr configs — see the bind in hyprland.conf). Type to search,
// arrows/Tab to move, Enter or click to copy, Escape to close. Recents lead.
//
// ── WHY THIS IS NOT rofi-emoji ──────────────────────────────────────────────
// `rofi-emoji` ships in both package tiers with ZERO references anywhere in
// the build, and wiring it would have been one line. It is refused on the
// record in `WIP-557`: rofi is the unthemed toolkit, the owner has already
// caught one rofi surface ("the odd one that didn't belong and wasn't
// themed") and the fix for that was to move the surface INTO the shell and
// leave rofi as an invisible fallback. `GAP-923` restates it. A second rofi
// window bound to a key he would press daily is the same defect, re-shipped.
// The package is left installed and unreferenced — HANDOFF.md's rule about
// not deleting committed things that look unused applies, and removing it is
// the packaging lane's call, not this one's.
//
// ── WHAT "INSERT" MEANS HERE, HONESTLY ──────────────────────────────────────
// It copies to the clipboard with `wl-copy` (wl-clipboard is in both tiers)
// and closes. It does NOT synthesise a keystroke into the focused window.
// That would need `wtype` or `ydotool`; neither is packaged, ydotool wants a
// uinput daemon running as root, and this build does not get a new daemon for
// a convenience. Copy-then-paste is also what a layer-shell surface can do
// truthfully: by the time this window is gone the compositor has restored
// focus to whatever you were typing in, and Ctrl+V lands there.
//
// The build's clipboard HISTORY (`cliphist`, watched by two `wl-paste
// --watch` services in nyxus-services.conf) picks the copy up like any other,
// so a glyph you used an hour ago is still in the clipboard panel. That is
// deliberate reuse: this file starts nothing and watches nothing.
//
// ── TIMERS ──────────────────────────────────────────────────────────────────
// There are none, and that is checked by gate 13q37. Everything here is
// event-driven — a keystroke, a click, a file load. The one deferred call is
// `Qt.callLater` on open to focus the field after the surface maps, which is
// a single-shot on the event loop and not a poll.
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    WlrLayershell.layer: WlrLayer.Overlay
    // OnDemand, matching the Launcher: the surface takes the keyboard while
    // it is focused and gives it straight back when it closes. Exclusive
    // would hold input even after a focus grab cleared, which is the shape
    // that traps a session.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    // Must match ^(nyxus.*)$ or Hyprland's blur rule never sees the surface
    // and the glass renders over raw wallpaper (Theme.qml records this).
    WlrLayershell.namespace: "nyxus-emoji"
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Anchored on neither axis, so the compositor centres it — the same trick
    // the clock surface uses to sit under the centred Meridian without having
    // to know another surface's geometry.
    implicitWidth: 520 + Theme.bloomPad * 2
    implicitHeight: 480 + Theme.bloomPad * 2
    visible: Bus.emojiOpen

    // Input is the pane, not the padded window — the bloom pad would swallow
    // clicks meant for whatever is underneath. Flyout.qml's trap, same fix.
    mask: Region {
        x: pane.x; y: pane.y; width: pane.width; height: pane.height
    }

    HyprlandFocusGrab {
        windows: [root]
        active: Bus.emojiOpen
        onCleared: Bus.emojiOpen = false
    }

    // ── state ────────────────────────────────────────────────────────────
    property string query: ""
    property int cursor: 0
    // The list actually on screen: search results when searching, otherwise
    // recents first and then everything in group order.
    readonly property var shown: root.query.length > 0
        ? EmojiData.search(root.query)
        : root.recentItems.concat(EmojiData.items)
    readonly property bool searching: root.query.length > 0

    // Ice chrome (TRK-968 / WIP-704). Sweep0 `#0aa2d6` is banned as a fill.
    // Same rungs as SetIceFace / MonthCalendar today-stone.
    readonly property color iceElevated: Theme.elevated                 // #071318
    readonly property color iceHover:    Theme.paintLayers.glacier[5]   // #b7e6f2
    readonly property color iceFocus:    Theme.paintLayers.glacier[0]   // #7fe8ff

    // ── recents ──────────────────────────────────────────────────────────
    // Stored as an array of GLYPHS, resolved back to table entries on read.
    // Storing the glyph and not the whole row means a future rename of an
    // entry's keywords does not fossilise the old text in someone's history,
    // and an entry deleted from the table simply drops out of recents instead
    // of leaving a row that matches nothing.
    readonly property int recentMax: 16
    property var recents: []
    readonly property var recentItems: {
        var out = [];
        for (var i = 0; i < root.recents.length; i++) {
            const it = EmojiData.find(root.recents[i]);
            if (it) out.push(it);
        }
        return out;
    }
    readonly property string recentsDir: Quickshell.env("HOME") + "/.local/state/nyxus"
    readonly property string recentsPath: root.recentsDir + "/emoji-recents.json"

    FileView {
        id: recentsFile
        path: root.recentsPath
        blockLoading: false
        // No history yet is the normal first-run case, not an error.
        printErrors: false
        onLoaded: {
            try {
                const parsed = JSON.parse(recentsFile.text());
                root.recents = Array.isArray(parsed) ? parsed.slice(0, root.recentMax) : [];
            } catch (e) {
                // A corrupt file costs the history and nothing else. It is
                // NOT overwritten here — the next pick rewrites it, and until
                // then the bad bytes are still on disk to look at.
                console.warn("EmojiPicker: " + root.recentsPath
                             + " is not valid JSON (" + e + ") — starting with no recents");
                root.recents = [];
            }
        }
    }

    // Written the way the reminder store writes itself: a temp file and an
    // atomic rename, through argv the shell never interpolates into.
    //
    // ⚠ The prose above deliberately does not spell that file's name with its
    // extension. Gate 13pr3 scans every shell QML for `Reminders.<member>`
    // and fails on any member the store does not define — WITHOUT stripping
    // comments first, so a sentence naming `Reminders` followed by a dot read
    // as a call to a member called "qml" and failed the gate. Fixed in the
    // gate too (13pr3 now strips comments); this wording removes the trip
    // hazard from this end as well, since a gate that a comment can FAIL is
    // the same defect as one a comment can satisfy.
    Process {
        id: recentsWriter
        command: ["sh", "-c",
            'mkdir -p "$NYX_DIR" && printf %s "$NYX_JSON" > "$NYX_DIR/.emoji-recents.tmp" '
            + '&& mv -f "$NYX_DIR/.emoji-recents.tmp" "$NYX_DIR/emoji-recents.json"']
        environment: ({
            "NYX_DIR": root.recentsDir,
            "NYX_JSON": JSON.stringify(root.recents)
        })
    }

    // ── the pick ─────────────────────────────────────────────────────────
    function pick(glyph): void {
        if (!glyph || glyph.length === 0) return;
        // argv, never `sh -c "wl-copy " + glyph`. Nothing here is user input
        // today — every glyph comes out of a committed table — but a copy
        // path that takes a string is one refactor away from being an
        // injection point, and Clock.qml's deep link carries the same note.
        //
        // ⚠ `-n` IS LOAD-BEARING. wl-copy APPENDS A TRAILING NEWLINE by
        // default, so without it every paste would drop a line break in
        // after the emoji — in a chat box that is a sent message, in a
        // filename it is an invalid character. `--trim-newline` is the long
        // name. `--` then guarantees a glyph can never be read as an option,
        // which matters the day this table grows an entry starting with `-`.
        Quickshell.execDetached(["wl-copy", "-n", "--", glyph]);
        Bus.emojiPicked(glyph);

        var next = [glyph];
        for (var i = 0; i < root.recents.length; i++)
            if (root.recents[i] !== glyph) next.push(root.recents[i]);
        root.recents = next.slice(0, root.recentMax);
        recentsWriter.running = true;

        Bus.emojiOpen = false;
    }

    // The one way to set the search text. `query` is DERIVED from the field —
    // writing it directly would filter the grid while leaving the box showing
    // something else, which is a picker lying about what it is showing you.
    // (Found on review before this ever ran: `onVisibleChanged` cleared
    // `query` and not `field.text`, so reopening drew the full table under
    // last session's search term.) The cage harness uses this too, which is
    // why the photograph of a filtered grid is honest.
    function setQuery(s): void { field.text = s === undefined ? "" : s; }

    // Opening resets the search and the cursor: a picker that reopens showing
    // last week's query is a picker you have to clear before you can use.
    onVisibleChanged: {
        if (root.visible) {
            root.setQuery("");
            root.cursor = 0;
            recentsFile.reload();
            // The field cannot take focus before the surface is mapped, so
            // the focus request is deferred by exactly one event-loop turn.
            Qt.callLater(function () { field.forceActiveFocus(); });
        }
    }

    readonly property int cols: 10

    function move(d): void {
        const n = root.shown.length;
        if (n === 0) return;
        root.cursor = Math.max(0, Math.min(n - 1, root.cursor + d));
        grid.positionViewAtIndex(root.cursor, GridView.Contain);
    }

    Pane {
        id: pane
        anchors.fill: parent
        anchors.margins: Theme.bloomPad
        elevation: 2
        // TRK-3651 — no outer glow at rest; see Pane.qml. The bloomPad margin
        // above stays: it only insets this pane inside its window.
        bloomAtRest: false
        // TRK-3370 — the widgets' stack: opaque elevated floor as the Pane's
        // own fill, panelMid paint + swellGround ramp below, GlassEdge body 0
        // (a body over the slab is the WIP-259 failure). Arithmetic in
        // SetSlab.qml.
        fill: Theme.elevated
        radius: Theme.r3

        Rectangle {
            anchors.fill: parent
            radius: Theme.r3
            color: Theme.panelMid
        }
        Rectangle {
            anchors.fill: parent
            radius: Theme.r3
            gradient: Gradient {
                GradientStop { position: 0.00; color: Theme.swellGroundTop }
                GradientStop { position: 0.50; color: Theme.swellGroundMid }
                GradientStop { position: 1.00; color: Theme.swellGroundFoot }
            }
        }

        // The Nyxus Glass stack, drawn with the shared components rather than
        // re-derived from the recipe — gate 13pu catches a new surface that
        // skips it, which is exactly how three surfaces once had it and three
        // did not.
        GlassEdge {
            // TRK-3653 - floating popup pane, same class as ContextMenu.
            // It had no `edging`, so it took the component default while
            // the rest of the build had moved off it. Found by
            // docs/proof/audit-0901/glass-consistency.py, not by eye.
            edging: 0.85
            anchors.fill: parent
            radiusTL: Theme.r3; radiusTR: Theme.r3
            radiusBL: Theme.r3; radiusBR: Theme.r3
            body: 0
            wash: 0
        }
        ReactiveEdge {
            radius: Theme.r3
            // TRK-3649 - no resting outer halo. This pane floats over the
            // desktop, so the always-on 8 px band outside its edge read as a
            // second edge - the widgets never drew it. The beat bloom stays.
            haloAtRest: false
        }
        MirrorEdge {
            radiusTL: Theme.r3; radiusTR: Theme.r3
            radiusBL: Theme.r3; radiusBR: Theme.r3
            depth: 14
            strength: 0.62
        }

        // ── 4 · THE SEAM (TRK-3372) ─────────────────────────────────
        // 1 px glacier[4]. The comment above is right that the stack is
        // drawn with the shared components — and the seam is the one
        // layer that has no component, so it was the one that went
        // missing. `SetSlab.qml` draws it; so does every other floating
        // surface in this shell now.
        Rectangle {
            anchors.fill: parent
            radius: Theme.r3
            color: "transparent"
            antialiasing: true
            border.width: 1
            border.color: Theme.soften(Theme.paintLayers.glacier[4], 0.45)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.s6
            spacing: Theme.s4

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: qsTr("EMOJI & SYMBOLS")
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    font.weight: Font.Medium
                    font.letterSpacing: Theme.trackMicro
                    color: Theme.textDim
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.shown.length + (root.shown.length === 1 ? qsTr(" result") : qsTr(" results"))
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    font.letterSpacing: Theme.trackMicro
                    color: Theme.textDim
                }
            }

            // ── search ───────────────────────────────────────────────────
            Pane {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                elevation: 1
                radius: Theme.r2
                fill: Theme.soften(Theme.void_, 0.62)
                focusLevel: field.activeFocus ? 1.0 : 0.0

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.s6
                    anchors.rightMargin: Theme.s6
                    spacing: Theme.s5

                    Text {
                        text: ""
                        font.family: Theme.fIcon
                        font.pixelSize: Theme.tBody
                        color: Theme.textMuted
                    }
                    TextInput {
                        id: field
                        Layout.fillWidth: true
                        color: Theme.text
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tBody
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        focus: true
                        onTextChanged: { root.query = text; root.cursor = 0; }
                        onAccepted: if (root.shown.length > 0) root.pick(root.shown[root.cursor].e)

                        // Every key the surface answers, in one place. Escape
                        // is a Keys handler and not a `Shortcut` because the
                        // field has the keyboard: a Shortcut competes with the
                        // text input for the same press, and losing that race
                        // is how a picker becomes unclosable.
                        Keys.onEscapePressed: Bus.emojiOpen = false
                        Keys.onRightPressed: root.move(1)
                        Keys.onLeftPressed: root.move(-1)
                        Keys.onDownPressed: root.move(root.cols)
                        Keys.onUpPressed: root.move(-root.cols)
                        Keys.onTabPressed: root.move(1)
                        Keys.onBacktabPressed: root.move(-1)

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: qsTr("Search emoji and symbols…")
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tBody
                            visible: !field.text
                        }
                    }
                }
            }

            // ── the "recent" marker ──────────────────────────────────────
            // Only when there are recents AND no query: during a search the
            // list is one ranked thing and a heading over part of it would be
            // a lie about where the boundary is.
            Text {
                Layout.fillWidth: true
                visible: !root.searching && root.recentItems.length > 0
                text: qsTr("RECENT")
                font.family: Theme.fUi
                font.pixelSize: Theme.tMicro
                font.weight: Font.Medium
                font.letterSpacing: Theme.trackMicro
                color: Theme.textDim
            }

            // ── the grid ─────────────────────────────────────────────────
            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: Math.floor(grid.width / root.cols)
                cellHeight: grid.cellWidth
                model: root.shown
                // A GridView keeps a currentIndex of its own; binding it to
                // the surface's cursor keeps ONE idea of "which one is
                // selected" rather than two that can disagree.
                currentIndex: root.cursor
                boundsBehavior: Flickable.StopAtBounds

                ScrollRail { flick: grid }

                delegate: Item {
                    id: cell
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: Theme.r1
                        color: cell.index === root.cursor
                            ? root.iceElevated
                            : (cellHov.hovered ? Theme.soften(root.iceHover, 0.18) : "transparent")
                        border.width: (cell.index === root.cursor || cellHov.hovered) ? 1 : 0
                        border.color: cell.index === root.cursor ? root.iceFocus : root.iceHover
                    }
                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.e
                        // Theme.fEmoji, never the family string. 13q21's
                        // rule is that nothing in the shell writes a font
                        // family — this file did, twice, and the gate caught
                        // it. The token's fallback chain ends at a face that
                        // will draw the code point in monochrome rather than
                        // drawing tofu.
                        font.family: Theme.fEmoji
                        font.pixelSize: Math.round(grid.cellWidth * 0.56)
                    }
                    HoverHandler { id: cellHov }
                    TapHandler {
                        onTapped: root.pick(cell.modelData.e)
                    }
                }
            }

            // ── the footer: what is selected, and how to take it ─────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s5
                Text {
                    text: root.shown.length > 0 ? root.shown[root.cursor].e : ""
                    font.family: Theme.fEmoji
                    font.pixelSize: Theme.tTitle
                }
                Text {
                    Layout.fillWidth: true
                    text: root.shown.length > 0 ? root.shown[root.cursor].n
                                                : "No emoji matches that"
                    color: root.shown.length > 0 ? Theme.textMuted : Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    elide: Text.ElideRight
                }
                Text {
                    text: qsTr("Enter copies  ·  Esc closes")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    font.letterSpacing: Theme.trackMicro
                }
            }
        }
    }
}
