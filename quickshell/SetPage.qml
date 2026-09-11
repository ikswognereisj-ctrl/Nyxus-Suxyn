// Nyxus Suxyn — the settings PAGE scaffold. LEVEL 3 of the Windows 10 shape.
//
// Every settings page is one of these, for the same reason every surface in
// the shell is a `Pane`: so that the heading sits in the same place, the
// scrolling behaves the same way, and a page written in module 4 does not
// silently invent its own margins. `docs/PLAN_SETTINGS_WINDOWS10_LAYOUT.md`
// §1 asks for "that nice sharp look, how everything flows together" — flow is
// what you get when the frame does not move between pages.
//
//     SetPage {
//         title: "Printers & scanners"
//         blurb: "Discover printers, watch the queue, check ink"
//         SetCard { ... }
//         SetCard { ... }
//     }
//
// Children go straight in; they are laid out in the page's card GRID with
// the standard gap — one column on a narrow window, two or three as the
// window earns them (TRK-3215). The alias targets a container this file
// declares nothing else into —
// see the warning in `Pane.qml` about a default-property alias that captures
// its own siblings and makes an item its own child. That crash is real; this
// shape avoids it.
import QtQuick
import QtQuick.Layouts

Item {
    id: page

    property string title: ""
    property string blurb: ""

    // Where this page sits on the sweep, 0..1. HORIZON's rule is that hue is a
    // function of horizontal position, but a settings page is a column, not a
    // screen — so instead the CATEGORY sets the tone and every card on the page
    // agrees with it. That is what makes Devices and Network feel like
    // different rooms without either of them being a different design.
    property real tone: 0.35
    // Kept so every card on the page can still inherit a category stop.
    // The page chrome itself is uncoloured — heading hairline is a SEAM
    // (glacier[4], never rose glassBorder).
    readonly property color iceHairline: Theme.paintLayers.glacier[4]

    default property alias body: cardWell.data

    // Reported upward so the window can show a scroll position; a page that
    // does not overflow reports 0 and the window shows nothing.
    readonly property real scrollFraction:
        flick.contentHeight <= flick.height ? 0
        : Math.max(0, Math.min(1, flick.contentY
                                  / (flick.contentHeight - flick.height)))

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── the heading ─────────────────────────────────────────────────
        // Outside the scroll area on purpose. On a 1366×768 screen — the
        // viewport the settings design contract names — a heading that scrolls
        // away costs you the only thing on screen that says where you are.
        // Gutters were Theme.s9 (32) all around; the confined 640-wide page
        // then had 64 px of side pad and read empty. Now s7 (20) sides /
        // s6 (16) top — body width inside 640: 576 → 600.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s7
            Layout.rightMargin: Theme.s7
            Layout.topMargin: Theme.s6
            Layout.bottomMargin: Theme.s5
            spacing: Theme.s2

            Text {
                Layout.fillWidth: true
                text: page.title
                color: Theme.text
                font.family: Theme.fTech
                font.pixelSize: Theme.tTitle
                font.weight: Font.DemiBold
                font.letterSpacing: Theme.trackTitle
                elide: Text.ElideRight
                clip: true
            }

            Text {
                Layout.fillWidth: true
                text: page.blurb
                visible: page.blurb !== ""
                color: Theme.textDim
                font.family: Theme.fNum
                font.pixelSize: Theme.tLabel
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                clip: true
            }

            // The one hairline on the page, under the heading. A SEAM
            // (glacier[4]), never a category rainbow — colour in key
            // places lives on the controls (glacier/ice), not the page chrome.
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: Theme.s4
                // `Layout.preferredHeight`, never `height`: an item inside a
                // layout does not own its own geometry, and setting it is the
                // undefined-behaviour case `scripts/audit.sh` greps the lint
                // output for by name.
                Layout.preferredHeight: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: page.iceHairline }
                    GradientStop { position: 0.7; color: Theme.soften(page.iceHairline, 0.12) }
                    GradientStop { position: 1.0; color: Theme.shelfNone }
                }
            }
        }

        // ── the body ────────────────────────────────────────────────────
        Flickable {
            ScrollRail { flick: flick }   // WIP-332
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: bodyColumn.implicitHeight + Theme.s7
            boundsBehavior: Flickable.StopAtBounds
            // A wheel notch should move about one row. Qt's default of 3 lines
            // on a 64 px row list moves nearly three rows and overshoots what
            // the eye was tracking.
            flickDeceleration: 3500

            // ── THE CARD GRID (TRK-3215) → THE CARD COLUMNS (TRK-3582) ──
            // This was a single ColumnLayout: every card on every page in one
            // stack, one card wide, however much window there was. TRK-3215
            // made it a GridLayout whose column count is COMPUTED from the
            // width it actually got — never a constant, and never a per-page
            // choice — and that part is unchanged and is still the contract:
            //
            //   width < 2 * cardMin + gap   →  1 column (the old behaviour,
            //                                  which is still correct on a
            //                                  narrow window and is what the
            //                                  minimumSize case gets)
            //   otherwise                   →  as many columns as fit, to 3
            //
            // WHAT CHANGED, and why a GridLayout could not do it. A GridLayout
            // fills ROW-MAJOR and gives every cell in a row the height of the
            // tallest card in that row. Settings cards are wildly uneven — a
            // two-row "Reload" card beside a nine-row "Queue" card — so every
            // row bought a hole the size of the difference, and `AlignTop` (see
            // SetCard) made that hole visible as blank ground under the short
            // card rather than as a stretched slab. MEASURED on the owner's
            // own 35-page sweep at the shipped page stage, before and after, in
            // `docs/BRIEF_AGENT_SETLOOK_2026-08-31.md`.
            //
            // The mockups do not have those holes: in
            // `nyxus-mockups-2026-08-27/02-system-and-themes-pages.png` the
            // three columns of the Themes page share a top edge and end at
            // three DIFFERENT bottoms. That is masonry, not a grid, and it is
            // what this now is: N equal columns, cards dealt in declaration
            // order into whichever column is currently shortest.
            //
            // Pages are untouched by this. They still declare SetCards into
            // `body` in order; `cardWell` receives them and `deal()` places
            // them. Non-visual children (a page's `Process`, `Timer`,
            // `Connections`) land in `cardWell.data` and never in `.children`,
            // so they are never dealt and never reparented — which is why the
            // deal reads `children` and not `data`.
            Item {
                id: bodyColumn
                width: flick.width - 2 * Theme.s7
                x: Theme.s7
                implicitHeight: masonry.implicitHeight

                // `cardMin` is SetCard's own implicitWidth (480) less the
                // gutter it can give up before a SetRow's label and control
                // start fighting. UNCHANGED at 360, and this note records the
                // experiment that proves it, because the obvious move here is
                // to lower it and that move is wrong.
                //
                // The shipped window was being forced to 960 by a windowrule,
                // which leaves a 660 px page slot and a 620 px body — and
                // 2 × 360 + 12 = 732 does not fit, so every page in the
                // product rendered SINGLE-COLUMN into a body designed for two.
                // The tempting fix is `cardMin: 300`, which does buy two
                // columns at 620. MEASURED at 304 px columns on Settings ▸
                // Display (`/tmp` frame, 2026-08-31): the control takes its
                // implicit width first, so "Adaptive sync" elided to "Ad..."
                // and its description wrapped to ONE WORD PER LINE down
                // fifteen lines; "Scale" elided to "S...". Denser by area and
                // unreadable — the horizontal form of the geometry trap.
                // A row with a segmented control needs ~380 px of column, so
                // the window is what was wrong, not this number: see the
                // `org.quickshell` sizing in
                // `conf.d/nyxus-hyprland-rules.conf` (TRK-3584).
                readonly property int cardMin: 360
                // How many columns the WIDTH can pay for. Not how many the
                // page gets — see `columns`.
                readonly property int fitColumns: Math.max(1, Math.min(3,
                          Math.floor((bodyColumn.width + Theme.s5)
                                     / (bodyColumn.cardMin + Theme.s5))))

                // ── NEVER OPEN A COLUMN THE PAGE CANNOT FILL (TRK-3583) ──
                // MEASURED, and it is the correction to the first cut of this
                // work. Taskbar has one real card and a reset row. Given two
                // columns it put the card left and the reset row right, and by
                // the density metric in the brief the page went from 56.52% to
                // 34.02% — SHORTER (524 px → 381 px) and EMPTIER, because the
                // second column was a strip of ground. An empty column is the
                // same defect as an empty page bottom, turned ninety degrees,
                // and a fix that trades one for the other is not a fix.
                //
                // So the count is CHOSEN, not derived from width alone:
                // simulate the deal at `fitColumns`, then at one fewer, and
                // take the widest arrangement whose SHORTEST column still
                // carries at least `balanceFloor` of its tallest. The floor is
                // a ratio and not a card count because two cards can be a
                // 400 px card and a 60 px row — a count would have called that
                // balanced. 0.45 is where Taskbar (0.30) is refused and every
                // page with real content in both columns is kept; the sweep in
                // the brief lists what each page chose.
                readonly property real balanceFloor: 0.45
                property int columns: 1

                // The cards live here until they are dealt. Zero-sized and
                // invisible; a card is reparented OUT of it into a column and
                // becomes visible again with the column's width.
                Item { id: cardWell; visible: false; width: 0; height: 0 }

                // Captured ONCE, at completion, in declaration order. Not
                // `cardWell.children` at deal time — a dealt card has already
                // left that list, so re-reading it would deal an ever-shorter
                // deck.
                property var cards: []

                // Re-deal when a card's own height changes — a page whose
                // content arrives from a Process (Network, Bluetooth,
                // Background) is short for the first few seconds and then is
                // not. Dealing does not change any card's height, because every
                // column is the same width, so this cannot feed itself.
                readonly property real deckSum: {
                    var s = 0;
                    for (var i = 0; i < bodyColumn.cards.length; i++) {
                        var c = bodyColumn.cards[i];
                        if (c && c.visible)
                            s += c.implicitHeight;
                    }
                    return s;
                }
                onDeckSumChanged: dealTimer.restart()
                onColumnsChanged: dealTimer.restart()
                onFitColumnsChanged: dealTimer.restart()

                Timer {
                    id: dealTimer
                    interval: 32
                    onTriggered: bodyColumn.deal()
                }

                Component.onCompleted: {
                    var kids = cardWell.children;
                    var list = [];
                    for (var i = 0; i < kids.length; i++)
                        list.push(kids[i]);
                    bodyColumn.cards = list;
                    bodyColumn.deal();
                }

                // The greedy deal, run on NUMBERS only. Returns the per-column
                // totals for `n` columns without touching a single item, so
                // `chooseColumns` can try three arrangements and reparent
                // nothing until it has picked one.
                function _simulate(n: int): var {
                    var used = [];
                    for (var k = 0; k < n; k++)
                        used.push(0);
                    for (var i = 0; i < bodyColumn.cards.length; i++) {
                        var card = bodyColumn.cards[i];
                        if (!card || !card.visible)
                            continue;
                        var pick = 0;
                        for (var j = 1; j < n; j++)
                            if (used[j] < used[pick])
                                pick = j;
                        used[pick] += card.implicitHeight + Theme.s5;
                    }
                    return used;
                }

                function chooseColumns(): int {
                    for (var n = bodyColumn.fitColumns; n > 1; n--) {
                        var used = bodyColumn._simulate(n);
                        var lo = used[0], hi = used[0];
                        for (var i = 1; i < n; i++) {
                            if (used[i] < lo) lo = used[i];
                            if (used[i] > hi) hi = used[i];
                        }
                        // HYSTERESIS, and it is not decoration. A card is
                        // TALLER in a narrow column than in a wide one, so the
                        // heights this simulation reads were measured at the
                        // arrangement we are currently in, not the one being
                        // scored. Without a gap between "widen to n" and "stay
                        // at n" a borderline page flips 1 → 2 → 1 forever, one
                        // flip per layout pass.
                        var floor = (n <= bodyColumn.columns)
                                        ? bodyColumn.balanceFloor - 0.12
                                        : bodyColumn.balanceFloor;
                        // hi === 0 is a page whose cards have not been sized
                        // yet. Do not decide on that; one column is the safe
                        // answer and `deckSum` will bring us back.
                        if (hi > 0 && lo >= floor * hi)
                            return n;
                    }
                    return 1;
                }

                // True between a retract and the deal that follows it. While
                // it is set every card is parked in the zero-width well, where
                // a wrapping label reports a height it will never have — so the
                // column count is NOT re-decided from those numbers.
                property bool retracted: false

                function deal(): void {
                    var want = bodyColumn.retracted ? bodyColumn.columns
                                                    : bodyColumn.chooseColumns();
                    if (want !== bodyColumn.columns) {
                        // ⚠ RETRACT FIRST. Changing the Repeater's model
                        // DESTROYS the delegates it drops, and a QQuickItem is
                        // destroyed with its parent — so a card still parented
                        // to column 2 when the model goes 2 → 1 is destroyed
                        // with it and the page loses a card permanently, with
                        // no error anywhere. The well is the safe harbour.
                        for (var r = 0; r < bodyColumn.cards.length; r++)
                            if (bodyColumn.cards[r])
                                bodyColumn.cards[r].parent = cardWell;
                        // The cards are reparented into the new columns on the
                        // next pass, once those delegates exist.
                        bodyColumn.retracted = true;
                        bodyColumn.columns = want;
                        dealTimer.restart();
                        return;
                    }
                    var n = colRep.count;
                    if (n <= 0)
                        return;
                    var cols = [];
                    for (var c = 0; c < n; c++) {
                        var col = colRep.itemAt(c);
                        // A Repeater whose model has just grown has not
                        // instantiated every delegate yet. Come back.
                        if (!col) {
                            dealTimer.restart();
                            return;
                        }
                        cols.push(col);
                    }
                    var used = [];
                    for (var k = 0; k < n; k++)
                        used.push(0);
                    for (var i = 0; i < bodyColumn.cards.length; i++) {
                        var card = bodyColumn.cards[i];
                        if (!card)
                            continue;
                        var pick = 0;
                        for (var j = 1; j < n; j++)
                            if (used[j] < used[pick])
                                pick = j;
                        card.parent = cols[pick];
                        if (card.visible)
                            used[pick] += card.implicitHeight + Theme.s5;
                    }
                    if (bodyColumn.retracted) {
                        // The cards now have real widths again. Re-decide once,
                        // on numbers that mean something.
                        bodyColumn.retracted = false;
                        dealTimer.restart();
                    }
                }

                Row {
                    id: masonry
                    width: parent.width
                    spacing: Theme.s5

                    Repeater {
                        id: colRep
                        model: bodyColumn.columns
                        delegate: ColumnLayout {
                            width: (masonry.width
                                    - (bodyColumn.columns - 1) * Theme.s5)
                                   / bodyColumn.columns
                            height: implicitHeight
                            spacing: Theme.s5
                        }
                    }
                }
            }
        }
    }
}
