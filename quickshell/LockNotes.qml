// Nyxus Suxyn — notifications on the lock screen. WIP-415.
//
// The owner's words: "maybe something that shows my notifications as well so
// if my screen is locked I can still read them if I choose to."
//
// ── this is a CONSUMER, not a daemon ────────────────────────────────────
// `shell/Sys.qml` already runs the `NotificationServer` that owns
// `org.freedesktop.Notifications`, and Quickshell IS the notification daemon
// for this build — `hyprland.conf` says so, and explains that a second daemon
// is a coin toss over which skin the user sees. Verified on the live bus
// 2026-08-12: `GetServerInformation` returns "quickshell". So this file reads
// `Sys.notifications` (the server's own tracked list) and adds nothing to the
// bus. If you are here to "add notifications to the lock screen", the server
// is already there; only the surface was missing.
//
// ── the leak, and the default that answers it ───────────────────────────
// A message body on a locked screen is readable by anyone in the room. The
// lock exists precisely to hold the line against people who are physically
// present, so rendering the contents of a message on it hands away the one
// thing the lock was protecting — and it does it silently, to a user who
// thinks the machine is secured.
//
// The default SHIPPED as names-without-bodies and the owner reversed it on
// 2026-08-12 -- "on the locked screen as well, so if it was locked I'd still
// see what's going on", asked twice, the second time unprompted. So bodies
// are SHOWN by default and `lock_notifications_hide_body` defaults FALSE.
// The switch that reverses it is Settings > Notifications > "Hide contents on
// the lock screen".
//
// This paragraph said the OPPOSITE until 2026-08-24 -- it still described the
// pre-ruling default while the code below had read `false` since the day of
// the ruling. A header that misstates a PRIVACY default is worse than no
// header: the next person to touch this file would have "corrected" working
// code to match a stale comment and quietly re-hidden the owner's bodies.
//
// ⚠ Both keys ALREADY EXISTED with UI in `SetPageNotifications.qml` and
// nothing read them — `Lock.qml` carried zero notification references. That is
// a setting that configures nothing, the same class of fault gate `13ut`
// watches for. This file is what makes those two switches real.
//
//     lock_notifications             default true    show them at all
//     lock_notifications_hide_body   default false   contents, per the owner
//
// Read through `SettingsStore`, the same call the settings page itself uses,
// so the page and the lock can never disagree about what is on.
pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: notes

    property bool active: false

    // How many to draw before collapsing the rest into a count. A lock screen
    // is a glance, not an inbox — and an unbounded column would push the slab
    // off a short display.
    readonly property int maxShown: 4

    readonly property bool allowed: SettingsStore.boolValue("lock_notifications", true)

    // Bodies are SHOWN by default as of 2026-08-12, on the owner's explicit
    // instruction — "on the locked screen as well, so if it was locked I'd
    // still see what's going on". He asked for it twice; the second time was
    // unprompted.
    //
    // The privacy trade is real and he was told it plainly: a body on a lock
    // screen is readable by anyone standing near the machine, so a message
    // that would embarrass you is visible without your password. The switch
    // to reverse it is Settings ▸ Notifications ▸ "Hide contents on the lock
    // screen", and it takes effect immediately because both this file and
    // that page read the same `SettingsStore` key.
    //
    // The default was FALSE-to-show (hide) until today, chosen by an agent as
    // the safe call. That was the right default to ship with and the wrong
    // one to keep once the owner had ruled.
    readonly property bool hideBodies:
        SettingsStore.boolValue("lock_notifications_hide_body", false)

    readonly property var all: (notes.allowed && Sys.notifications)
        ? Sys.notifications.values : []
    readonly property int total: notes.all.length
    // ---- NEWEST FIRST, and why this is a BUG FIX and not a preference -----
    // `Sys.notifications` is the server's tracked list in ARRIVAL order, so
    // values[0] is the OLDEST -- Sys.qml says so where it explains the cap:
    // "the OLDEST are expired ... the one at the TOP of the list the flyout
    // draws."
    //
    // This file used to draw `all[0 .. maxShown-1]`, which is the four OLDEST.
    // With five or more waiting, a notification that arrived while you were
    // standing at the lock screen DID NOT APPEAR AT ALL -- it went straight
    // into "and N more" while four stale ones held the column. The newest is
    // the entire reason someone glances at a lock screen.
    //
    // Reported by the owner 2026-08-24: "i want it so if there more then one
    // it will show me not just show me the last one".
    //
    // Now: newest at the top, descending, the way Hyprland stacks them.
    readonly property var shown: {
        var out = [];
        for (var i = notes.total - 1; i >= 0 && out.length < notes.maxShown; i--)
            out.push(notes.all[i]);
        return out;
    }
    readonly property int overflow: Math.max(0, notes.total - notes.shown.length)

    // The lock reads this to decide whether to reserve any height.
    readonly property bool hasNotes: notes.allowed && notes.total > 0

    implicitHeight: column.implicitHeight

    Column {
        id: column
        width: parent.width
        spacing: Theme.s2

        Repeater {
            // The ARRAY, not a count: the delegate takes `modelData`, so the
            // newest-first order built above is the order actually drawn.
            model: notes.shown

            // ══ THE CARD, 2026-09-01 ═══════════════════════════════════════
            // Owner: "the lock out screen with earth the notifcations never
            // got updated and they were suppose to."
            //
            // He is right, and the gap is nameable. On 2026-08-28 he sent a
            // capture of his own desktop widgets — "this is how it all should
            // look" — and `SetSlab.qml` was written to be that stack: an
            // OPAQUE `Theme.elevated` floor with the widgets' own paint,
            // swell, glaze, mirror rim and glacier seam over it. `Toasts.qml`
            // (the desktop notification), `SetCard`, the Settings body and the
            // utility hub were all moved onto it. THIS FILE WAS NOT. It was
            // still wearing the pre-ruling recipe — a `Pane` at
            // `glassFillStrong` with `GlassEdge { body: 1 }` — which is the
            // exact translucent card the slab replaced.
            //
            // Two things were wrong with it and both are measured on
            // `docs/proof/lock-0901/before-lock.png` (1920x1200, shot on the
            // live machine through `qs ipc call lock engage` + grim):
            //
            //  1 · MAGENTA. `Pane { elevation: 2 }` runs `pane.frag`'s outer
            //      bloom (`Theme.e2Bloom`, 20 px), and that bloom is the
            //      SIGNATURE SWEEP, whose last stop is `#891955`. The sweep is
            //      DISPERSIVE — which end an edge catches depends on which way
            //      it faces — so the band 20 px outside the stack measures:
            //
            //          left edge   mean hue 204.4°   magenta 0.0%
            //          top edge    mean hue 205.6°   magenta 0.0%
            //          right edge  mean hue 301.2°   magenta 99.6%
            //
            //      ("magenta" = pixels with S > 0.15, V > 0.02 and hue in
            //      280..340°, as a percentage of the coloured pixels in a
            //      21 px band outside that edge.) The owner retired the
            //      magenta/rose family on 2026-09-01 in favour of glacier on
            //      matte black, and a pink halo down the right of every
            //      notification is the largest magenta area on the screen he
            //      sees first every morning. `SetSlab`'s Pane is `level: 1`,
            //      where `Theme.e1Bloom` is 0 and the `bl` term never runs.
            //
            //  2 · NO FLOOR. `glassFillStrong` is alpha 0.66, so the star
            //      field and the galaxy band read straight through the card.
            //      The 2026-08-12 note below already records this being
            //      fought once by raising the alpha; the slab ends the
            //      argument by putting an opaque floor under the same stack.
            //
            // What is deliberately NOT copied from `Toasts.qml`: its hover
            // veil, its state-dependent edge stroke and its dismiss timer.
            // Nothing on a lock screen is hoverable-then-clickable pre-auth
            // and nothing here expires — this is a reading surface, not an
            // interrupt. The MATERIAL is shared; the behaviour is not.
            delegate: Item {
                id: note
                required property var modelData
                readonly property var n: note.modelData
                readonly property bool critical:
                    !!note.n && note.n.urgency === 2

                width: column.width
                // s6, matching `Toasts.qml`'s card margins exactly, so the
                // lock's notification and the desktop's are the same object
                // seen twice rather than two cards that nearly agree.
                height: body.implicitHeight + Theme.s6 * 2

                // r1, not r2. THE sharpness lever: 8 px instead of 14 reads as
                // a cut edge rather than a pill, and it is the single change
                // that moved these closest to the Hyprland look the owner
                // pointed at on 2026-08-24. Kept.
                readonly property int rad: Theme.r1

                // ── the material · ONE line, and it is the build's ────────
                SetSlab {
                    anchors.fill: parent
                    cornerRadius: note.rad
                    level: 1
                    seam: true
                }

                Row {
                    id: body
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: Theme.s6
                        rightMargin: Theme.s6
                    }
                    spacing: Theme.s5

                    // ---- the mark ----------------------------------------
                    // Always drawn, only its colour changes, so every card
                    // keeps the same silhouette — which is what makes a stack
                    // read as deliberate rather than assembled.
                    //
                    // 4 px and full alpha as of 2026-09-01, which is what
                    // HORIZON §4.12 actually states and what `Toasts.qml`
                    // draws. It was 2 px at 0.55 here — a different width AND
                    // a different alpha from the same mark on the desktop, for
                    // no recorded reason. §4.12 also makes this STATE
                    // information (it is the only thing on the card that says
                    // which kind of notification this is), which takes the 3:1
                    // component floor with no exemption, and a 2 px hairline
                    // at 0.55 was not carrying it.
                    //
                    // Critical is `magma[5]` #ff7847, the rung `Toasts.qml`
                    // uses — NOT `Theme.danger` #ff2d55, which this file used
                    // to reach for. Danger is a magenta-leaning red (hue 344°)
                    // and it is reserved for errors in TEXT; a card edge is
                    // not an error message, and the owner's 2026-09-01 ruling
                    // takes the rose family off this screen. Ordinary stays
                    // glacier[0] (gate 13t80: no purple here).
                    Rectangle {
                        width: 4
                        height: text.implicitHeight
                        radius: 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: note.critical
                            ? Theme.paintLayers.magma[5]
                            : Theme.paintLayers.glacier[0]
                    }

                    Column {
                        id: text
                        width: parent.width - Theme.s5 - 4
                        spacing: Theme.s1

                        // ── the header row ───────────────────────────────
                        // Summary FIRST and large, sender second, small and
                        // right — `Toasts.qml`'s order. It used to be the
                        // other way round here: the sender got the first line
                        // to itself and the thing the notification actually
                        // SAYS was the second. On a glance surface the subject
                        // has to be the first thing read, and stacking the two
                        // also cost a whole line of height per card.
                        //
                        // Anchors, not a Layout: this file has no
                        // QtQuick.Layouts import and a lock screen is not the
                        // place to add one for a two-item row.
                        Item {
                            width: parent.width
                            height: Math.max(summaryText.implicitHeight,
                                             appText.implicitHeight)

                            Text {
                                id: appText
                                anchors.right: parent.right
                                anchors.baseline: summaryText.baseline
                                text: (note.n && note.n.appName)
                                    ? note.n.appName.toUpperCase() : "SYSTEM"
                                color: Theme.textDim
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tMicro
                                font.letterSpacing: Theme.trackMicro
                            }

                            Text {
                                id: summaryText
                                anchors.left: parent.left
                                anchors.right: appText.left
                                anchors.rightMargin: Theme.s4
                                text: (note.n && note.n.summary)
                                    ? note.n.summary : ""
                                color: Theme.text
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tLabel
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }
                        }

                        // THE BODY, and the whole reason this file has a
                        // setting. SHOWN by default -- see the header, and do
                        // not "correct" it back to hidden.
                        Text {
                            width: parent.width
                            visible: !notes.hideBodies
                                     && !!note.n && !!note.n.body
                            text: (note.n && note.n.body) ? note.n.body : ""
                            color: Theme.textMuted
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // "and 3 more" — so the count is honest even when the column is capped.
        Text {
            width: column.width
            visible: notes.overflow > 0
            // Left-aligned and indented to the cards' own text inset, not
            // centred. A centred line under a left-aligned stack was the one
            // element breaking the column's edge, and a broken edge is exactly
            // what reads as "off" next to the rest of this page.
            leftPadding: Theme.s5
            horizontalAlignment: Text.AlignLeft
            text: notes.overflow === 1 ? qsTr("and 1 more")
                                       : "and " + notes.overflow + " more"
            color: Theme.textDim
            font.family: Theme.fUi
            font.pixelSize: Theme.tCaption
            font.letterSpacing: Theme.trackMicro
        }
    }
}
