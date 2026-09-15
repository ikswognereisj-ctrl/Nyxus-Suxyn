// Nyxus Suxyn — the interrupt. Ephemeral toast; the flyout is the inbox.
//
// ══ TRK-3664 · the redesign the owner asked for, 2026-09-01 ════════════════
// *"the notifications were supposed to be like a Hyprland's but better —
// smoother, cleaner, better eye candy — but matching our system."*
//
// Nothing here is copied from dunst, mako or swaync. What those get right is
// the SHAPE of the information (who → what → what you can do about it); what
// they get wrong on this build is that they are a second material. So this is
// the same five things a good notification has to do, built out of the parts
// this shell already owns — `SetSlab`, `GlassEdge`, `Theme`'s one motion
// system — and measured against what was on screen before.
//
//   1 · IT ARRIVES AND LEAVES WITHOUT JARRING. Before: the card faded in over
//       a 14 px lift, and when it went, the ListModel row was deleted under a
//       ColumnLayout — every card above it SNAPPED to its new position in one
//       frame. That snap was the whole "not smooth". Now a card owns a
//       `hFactor` 0→1 that its own height is multiplied by, so it GROWS into
//       the stack and COLLAPSES out of it on `curveRise` / `curveSink`, and
//       the cards around it are carried by the layout at animation rate
//       instead of teleporting. The row is removed only after the collapse.
//   2 · IT READS AT A GLANCE. Sender first — an app icon plate (the real
//       `appIcon`/`image` off the server notification, a monogram when the app
//       ships none) — then the summary, then the body. Three ranks, one
//       column, nothing centred.
//   3 · IT STACKS SANELY. Capped at `toast_stack` cards (default 3). Past the
//       cap the OLDEST is closed, not the newest dropped, and the count of
//       what went is carried on one quiet pill at the far end of the stack.
//       A wall of nine cards cannot happen.
//   4 · URGENCY IS LEGIBLE WITHOUT SHOUTING, IN FORM AS WELL AS COLOUR. The
//       kind rail is a short 2 px TICK beside the title for a routine
//       notification and a full-height 3 px BAR for a critical one. The
//       silhouette differs before the colour is read, which is the build's
//       own rule and also the only version of this that survives being
//       glanced at in peripheral vision.
//   5 · IT IS DISMISSABLE AND ITS ACTIONS ARE OBVIOUS. Hover pauses the whole
//       stack's dwell (you are reading it — it must not evaporate mid-word),
//       raises a close glyph, and shows the notification's own actions as
//       chips. Tapping an action invokes it on the server object.
//
// The dwell itself is now VISIBLE: a hairline along the card's bottom edge
// draining over `toast_seconds`. dunst and mako have no such thing; it is the
// difference between a card that vanishes and a card that finishes.
//
// ══ what did NOT change, and must not ══════════════════════════════════════
// Owner 2026-08-19: KEEP BOTH. The popup is brief. The right-rail badge +
// Notifications flyout is the inbox. Do not put a scrolling list in the thin
// bar (Bar.qml is BQ). If they miss a toast, it is still in the flyout —
// this surface removes only its own `toastModel` card. It MUST NOT call
// `dismiss()` / `expire()` on the server notification. Sys marks every
// arrival `tracked = true`, so the record outlives this fade. (Invoking an
// ACTION is the one thing that touches the server object, and it is not a
// dismissal: it is the user deliberately answering the notification.)
//
// Owner 2026-08-12 overruled HORIZON §5.3's critical-only popup: every
// notification toasts unless DND is on (DND hides this surface, not the
// record). Critical cards wait for a tap; the rest honour `toast_seconds`.
//
// ══ THE MATERIAL, and the rim that was being drawn twice ═══════════════════
// Owner 2026-08-20: the card is an ICE OBJECT, not a glass Pane — an opaque
// elevated body, a glacier seam, no translucent veil (WIP-783). That still
// holds and `SetSlab` (TRK-3370) is what supplies it: opaque `Theme.elevated`
// floor, Start's paint, the widgets' swell, its own GlassEdge and MirrorEdge,
// and a `glacier[4]` seam.
//
// MEASURED DEFECT, fixed here (TRK-3665). The card was carrying FOUR rims:
// SetSlab's GlassEdge (`edging` 0.46) and MirrorEdge (depth 12), then a
// Canvas stroking a 1.2 px `glacier[4]` outline, then a SECOND GlassEdge
// (0.35) and a SECOND MirrorEdge (depth 14, strength 1.0) declared in this
// file. Three of those four are the same edge drawn again at a different
// weight, which is why a 380 px transient card read louder than a page-scale
// pane — the brief for every tuned surface in this build is the opposite
// (SidePanel 0.85, widget chips 0.70/0.85, SetSlab 0.46–0.66, a toast BELOW
// all of them). One rim now: SetSlab's, with `seam: true` so the glacier
// hairline is the slab's rather than a hand-stroked copy, and `lifted` bound
// to hover so the one rim brightens instead of a second one appearing.
//
// The Canvas is gone with it. It existed to stroke that outline and had to be
// `requestPaint()`ed from six change handlers; a rounded rectangle with a
// border does the same thing declaratively and animates for free.
//
// This file still declares a `GlassEdge` with an explicit `body: 0`, because
// it is a layer-shell surface and gate 13pu requires both — but at
// `edging: 0.22` at rest it is the Lip/Sheen only, quieter than anything else
// that floats, which is what a small transient object should be.
//
// ══ COLOUR (owner ruling, 2026-09-01) ══════════════════════════════════════
// Glacier on matte black. No magenta, no rose — `Theme.danger` (#ff2d55) is
// therefore NOT used here even for critical. Ice `glacier[0]` is the routine
// mark, `magma[5]` (#ff7847, hue 19° — ember, not magenta) stays the critical
// mark exactly as the 08-20 ruling set it, and it is 3 px wide on a 380 px
// card. Every other coloured pixel on this surface is glacier or text.
//
// NOTE for anyone widening this: there is no raw hex in this file. Gate 13pu
// fails the build on one.
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    WlrLayershell.layer: WlrLayer.Overlay
    // See Bar.qml: the blur floor only matches ^(nyxus.*)$.
    WlrLayershell.namespace: "nyxus-toasts"
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // ── what Settings ▸ Notifications owns ──────────────────────────────
    // Defaults match that page. Bar.qml is not consulted.
    readonly property string corner: SettingsStore.stringValue("toast_corner",
                                                              "bottom-right")
    readonly property bool atLeft: root.corner.indexOf("left") >= 0
    readonly property bool atTop:  root.corner.indexOf("top") >= 0

    readonly property int stayMs: Math.max(2000,
        Math.round(SettingsStore.numberValue("toast_seconds", 6) * 1000))

    // How many cards may share the screen. Clamped here as well as on the
    // page: a hand-edited settings.json cannot ask for a wall.
    readonly property int maxCards: Math.max(1, Math.min(5,
        Math.round(SettingsStore.numberValue("toast_stack", 3))))

    readonly property bool wantActions: SettingsStore.boolValue("toast_actions", true)

    // Reduced motion (Settings ▸ Accessibility, `reduced_motion`). Every
    // duration in this file goes through `root.moveMs()`, the entrance slide
    // is skipped, and the draining dwell hairline — which is motion whatever
    // else it is — is not drawn. The dwell TIMING is untouched: a card that
    // still leaves after six seconds is the contract, only the animation of
    // it goes away.
    readonly property bool still: Prefs.reducedMotion
    function moveMs(ms) { return root.still ? 0 : ms }

    readonly property bool wantDwellBar:
        SettingsStore.boolValue("toast_dwell", true) && !root.still

    // Padded past the surface for the bloom, input masked back to it — see
    // Flyout.qml.
    anchors {
        left: root.atLeft
        right: !root.atLeft
        top: root.atTop
        bottom: !root.atTop
    }
    // Owner 2026-08-19: optical air above the bar. Subtracting bloomPad
    // put the WINDOW 12 px into the exclusive zone (chromeH 84, M 72).
    // The card sat 12 px above the bar; the transparent pad still
    // composited over the horizon. Margin is now chromeH + s5 so the
    // window itself clears the bar; the card is bloomPad further up.
    // Side inset matches Start's s5 so the card is not flush to the
    // screen edge (the Hyprland debug toast in the nested still was).
    margins {
        bottom: root.atTop ? 0 : (Theme.chromeH + Theme.s5)
        top: root.atTop ? Theme.s5 : 0
        right: Theme.s5
        left: Theme.s5
    }

    readonly property int cardW: 380

    implicitWidth: root.cardW + Theme.bloomPad

    // ── the window does NOT breathe with the stack (TRK-3664) ───────────
    // It used to be `stack.implicitHeight + pad`, so every frame of an
    // entrance or a collapse resized a layer-shell surface — a round trip to
    // the compositor per frame, and the visible half of "not smooth". The
    // window is now a fixed envelope big enough for `maxCards` at their
    // tallest, the stack lays out inside it, and `mask` keeps the empty part
    // transparent to input. Nothing composites there: it is not painted.
    implicitHeight: Theme.bloomPad * 2 + root.maxCards * 168 + 40

    mask: Region { item: stack }
    // Only mapped while there is something to show, so it never eats clicks.
    // (The old version bound this to `stack.children.length`, which counts the
    // Repeater itself and is therefore never zero — the window stayed mapped
    // forever as a 2px sliver.)
    visible: toastModel.count > 0

    // Ice object tokens — Theme.elevated / paintLayers.glacier, not hex
    // literals at the use site. Magma is the critical mark only.
    readonly property color iceMark: Theme.stateLayer[0]
    readonly property color iceSeam:     Theme.lookSeam
    readonly property color iceSoft:     Theme.paintLayers.glacier[5]
    readonly property color markCritical: Theme.paintLayers.magma[5]

    // ══ the record ══════════════════════════════════════════════════════
    // `key` is a monotonic id. Everything that closes or removes a card does
    // it BY KEY, never by delegate index: the old code captured `toast.index`
    // in a Timer and removed that row when it fired, so two cards expiring
    // within 200 ms of each other removed the wrong row (the index had
    // already shifted under it).
    ListModel { id: toastModel }
    property int seq: 0
    // How many cards the cap has closed since the stack was last empty.
    property int overflow: 0

    // The whole stack pauses while the pointer is anywhere over it. Reading a
    // notification and having it evaporate mid-sentence is the single most
    // common complaint about every toast daemon; it costs one HoverHandler.
    property bool stackHovered: false

    // ── finding the server object for an arrival ────────────────────────
    // `Sys.notified` carries only (summary, body, appName) and widening it
    // would mean editing Sys.qml plus BatteryWatch.qml plus Bar.qml — three
    // files, two of them other lanes'. It does not need widening: Sys marks
    // every arrival `tracked = true` BEFORE it emits, so the object reaches
    // `Sys.notifications` for the same arrival. Match on the same
    // summary/appName pair Sys itself derived, newest id wins.
    //
    // ⚠ IT IS NOT THERE YET INSIDE THE SIGNAL. Measured on the live machine,
    // 2026-09-01: resolving this from `onNotified` returned null every time —
    // `tracked = true` queues the object into the model, and the model has not
    // grown by the time Sys emits from the same handler. The card came up with
    // a monogram and no action chips for a `notify-send -i firefox -A ...`
    // that carried both. The lookup therefore runs from a zero-interval Timer
    // in the delegate, i.e. on the next turn of the event loop, which is the
    // first moment the list is current. A card whose sender is gone by then
    // simply keeps the monogram — that is the same fallback an app with no
    // icon gets, so the failure mode is a shape the design already has.
    function _lookup(summary, appName) {
        var model = Sys.notifications;
        if (!model)
            return null;
        var list = (model.values !== undefined && model.values !== null)
                   ? model.values : model;
        if (!list)
            return null;
        var best = null;
        for (var i = 0; i < list.length; i++) {
            var n = list[i];
            if (!n)
                continue;
            var s = String(n.summary || n.appName || "Notification");
            if (s !== String(summary))
                continue;
            if (String(n.appName || "") !== String(appName))
                continue;
            if (best === null || n.id > best.id)
                best = n;
        }
        return best;
    }

    // The sender's own icon, if it sent one. `image` is the raw pixmap a
    // messaging app attaches; `appIcon` is an icon-theme name. Everything is
    // guarded: a notification object can be torn down by its app at any
    // moment and a throw here would take the whole surface with it.
    function iconFor(n) {
        if (!n)
            return "";
        try {
            var img = String(n.image || "");
            if (img !== "")
                return img;
        } catch (e1) {
            return "";
        }
        var name = "";
        try {
            name = String(n.appIcon || "");
        } catch (e2) {
            return "";
        }
        if (name === "")
            return "";
        if (name.charAt(0) === "/" || name.indexOf("file:") === 0)
            return name;
        try {
            return Quickshell.iconPath(name, true);
        } catch (e3) {
            return "";
        }
    }

    // At most three, and never the freedesktop "default" action — that one is
    // the whole card, not a button, and rendering it gives every notification
    // a chip labelled "Default".
    function actionsFor(n) {
        if (!root.wantActions || !n)
            return [];
        var list = null;
        try {
            list = n.actions;
        } catch (e1) {
            return [];
        }
        if (!list)
            return [];
        var out = [];
        for (var i = 0; i < list.length && out.length < 3; i++) {
            var a = list[i];
            var label = "";
            try {
                label = String(a.text || "");
            } catch (e2) {
                continue;
            }
            if (label === "")
                continue;
            var id = "";
            try {
                id = String(a.identifier || "");
            } catch (e3) {
                id = "";
            }
            if (id === "default")
                continue;
            out.push(a);
        }
        return out;
    }

    function rowFor(key) {
        for (var i = 0; i < toastModel.count; i++)
            if (toastModel.get(i).key === key)
                return i;
        return -1;
    }

    // Start the collapse. Idempotent — a card the cap already closed cannot
    // be closed twice, which is what would double-decrement `overflow`.
    function closeKey(key) {
        var i = root.rowFor(key);
        if (i < 0 || toastModel.get(i).gone)
            return;
        toastModel.setProperty(i, "gone", true);
    }

    // Called by the delegate when its collapse has finished playing.
    function dropKey(key) {
        var i = root.rowFor(key);
        if (i >= 0)
            toastModel.remove(i);
        if (toastModel.count === 0)
            root.overflow = 0;
    }

    // ── the cap ─────────────────────────────────────────────────────────
    // Close the OLDEST live card, not the newest arrival. A cap that drops
    // the thing that just happened is a cap that hides the thing you were
    // waiting for. The record is untouched either way — the flyout has it.
    function capStack() {
        var live = [];
        for (var i = 0; i < toastModel.count; i++)
            if (!toastModel.get(i).gone)
                live.push(toastModel.get(i).key);
        var n = 0;
        while (live.length - n > root.maxCards) {
            root.closeKey(live[n]);
            root.overflow = root.overflow + 1;
            n = n + 1;
        }
    }

    // EVERY notification toasts, not only Critical ones (owner, 2026-08-12:
    // "for the notification I did want them to popup whenever").
    //
    // This listens to `Sys.notified`, which fires for every notification the
    // server tracks, rather than `Sys.urgent`, which fires only when
    // `n.urgency === NotificationUrgency.Critical`. Both signals still exist
    // and `urgent` still fires — nothing else that consumes it changes.
    //
    // Do NOT "fix" this back to `onUrgent` on the grounds that it is noisy.
    // It was Critical-only until 08-12 and the owner asked for the other
    // behaviour in his own words. If it proves too noisy in use, the answer
    // is a per-app filter or a Settings toggle, not a silent revert to a
    // decision he has already overruled once. (Both of those now exist: the
    // flyout's per-app Allow, and the stack cap above.)
    //
    // Do-not-disturb is unaffected: `Sys.onNotification` returns before
    // emitting either signal when `sys.dnd` is set, so DND still hides the
    // toast while the notification is still recorded in the list.
    //
    // ⚠ THE COUPLING, STATED SO IT CANNOT ROT SILENTLY. Urgency arrives on a
    // SECOND signal: `Sys.notified` carries no urgency, and `Sys.urgent`
    // already carries exactly this. This depends on `Sys.qml` emitting
    // `notified` and then `urgent` for the same notification, synchronously,
    // from the one `onNotification` handler — which is what it does today. If
    // that order ever changes, the rail goes quiet rather than wrong (it
    // falls back to informational), but it WILL be wrong-quiet, so a reader
    // changing Sys.qml's emission order needs to change this too.
    Connections {
        target: Sys
        function onNotified(summary, body, appName) {
            root.seq = root.seq + 1;
            var key = root.seq;
            toastModel.append({
                key: key,
                summary: summary,
                body: body,
                appName: appName,
                urgency: "normal",
                gone: false
            });
            root.capStack();
        }
        function onUrgent(summary, body, appName) {
            if (toastModel.count > 0)
                toastModel.setProperty(toastModel.count - 1, "urgency", "critical");
        }
    }

    ColumnLayout {
        id: stack
        anchors {
            left: root.atLeft ? parent.left : undefined
            right: !root.atLeft ? parent.right : undefined
            top: root.atTop ? parent.top : undefined
            bottom: !root.atTop ? parent.bottom : undefined
        }
        anchors.rightMargin: 0
        anchors.leftMargin: 0
        anchors.bottomMargin: root.atTop ? 0 : Theme.bloomPad
        anchors.topMargin: root.atTop ? Theme.bloomPad : 0
        width: root.cardW
        spacing: Theme.s3

        HoverHandler {
            onHoveredChanged: root.stackHovered = hovered
        }

        // ── the overflow pill ───────────────────────────────────────────
        // Declared FIRST, so it sits at the far end of the stack in both
        // orientations: for a bottom corner the newest card is at the bottom
        // and the ones the cap took were at the top; for a top corner the
        // oldest are at the top too. It says where they went — the flyout is
        // the inbox and the pill is the only place this surface ever names
        // it.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.overflow > 0 ? 22 : 0
            visible: root.overflow > 0
            opacity: root.overflow > 0 ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: root.moveMs(Theme.durQuick) }
            }

            Rectangle {
                anchors.right: root.atLeft ? undefined : parent.right
                anchors.left: root.atLeft ? parent.left : undefined
                anchors.verticalCenter: parent.verticalCenter
                height: 20
                width: pillText.implicitWidth + Theme.s5 * 2
                radius: height / 2
                color: Theme.soften(Theme.elevated, 0.86)
                border.width: 1
                border.color: Theme.soften(root.iceSeam, 0.35)
                antialiasing: true

                Text {
                    id: pillText
                    anchors.centerIn: parent
                    text: qsTr("+%1 more waiting").arg(root.overflow)
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    font.letterSpacing: Theme.trackMicro
                }
            }
        }

        Repeater {
            model: toastModel

            delegate: Item {
                id: toast
                required property int key
                required property string summary
                required property string body
                required property string appName
                required property string urgency
                required property bool gone

                readonly property bool lit: toast.urgency === "critical"
                property bool hovered: false
                property bool shown: false

                // Resolved once, at creation: the server object can be torn
                // down by its app while the card is still on screen, and a
                // binding that re-reads it would then evaluate against a
                // dead QObject.
                property string iconSrc: ""
                property var acts: []

                // WIP-335 / WIP-348: all four corners, one radius. A toast
                // floats free — it touches no screen edge. Owner 08-20: do
                // not retouch Theme.r3.
                readonly property int rad: Theme.r3

                // The card's real height. `Layout.preferredHeight` is this
                // times `hFactor`, which is what makes the stack open and
                // close instead of jumping.
                readonly property int cardH: content.implicitHeight + Theme.s5 * 2

                // 0 before the entrance, 1 while alive, 0 again through the
                // collapse. A Behavior cannot be attached to an attached
                // property (`Layout.preferredHeight`), which is why this is a
                // plain real that the layout reads.
                property real hFactor: (toast.shown && !toast.gone) ? 1 : 0

                Layout.fillWidth: true
                implicitWidth: root.cardW
                Layout.preferredHeight: Math.round(toast.cardH * toast.hFactor)
                clip: true

                Behavior on hFactor {
                    NumberAnimation {
                        duration: root.moveMs(toast.gone ? Theme.durSink
                                                         : Theme.durRise)
                        easing.type: Easing.OutQuint
                    }
                }

                // The collapse has to finish before the row is removed, or
                // the layout snaps — which was the whole defect. One Timer,
                // armed by `gone`, keyed by `key`.
                Timer {
                    id: reaper
                    interval: root.moveMs(Theme.durSink) + 20
                    running: toast.gone
                    onTriggered: Qt.callLater(root.dropKey, toast.key)
                }

                // ── dwell ───────────────────────────────────────────────
                // An animation rather than a repeating Timer: it gives the
                // hairline its position for free, it pauses natively while
                // the stack is hovered, and it costs no wakeups when nothing
                // is on screen. Critical never runs it — those wait for a
                // tap (SetPageNotifications: "Urgent ones ignore this").
                property real dwell: 1.0
                NumberAnimation on dwell {
                    id: dwellRun
                    from: 1.0
                    to: 0.0
                    duration: root.stayMs
                    running: toast.shown && !toast.lit && !toast.gone
                    paused: root.stackHovered
                    onFinished: root.closeKey(toast.key)
                }

                Component.onCompleted: toast.shown = true

                // The sender's icon and its actions, resolved one turn of the
                // event loop after the card exists — see `_lookup`'s header
                // for why not sooner. `repeat: false`, so this is one wakeup
                // per card, not a poll.
                Timer {
                    interval: 0
                    repeat: false
                    running: true
                    onTriggered: {
                        var n = root._lookup(toast.summary, toast.appName);
                        toast.iconSrc = root.iconFor(n);
                        toast.acts = root.actionsFor(n);
                    }
                }

                // ── the card ────────────────────────────────────────────
                // Held at its full height and anchored to the delegate's top
                // while the delegate's height animates, so the collapse WIPES
                // the card instead of squashing its type.
                Item {
                    id: card
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: toast.cardH

                    opacity: (toast.shown && !toast.gone) ? 1 : 0
                    scale: (toast.shown && !toast.gone) ? 1.0 : 0.94
                    transformOrigin: Item.Center
                    Behavior on opacity {
                        NumberAnimation {
                            duration: root.moveMs(toast.gone ? Theme.durSink
                                                             : Theme.durRise)
                            easing.type: Easing.OutQuint
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: root.moveMs(toast.gone ? Theme.durSink
                                                             : Theme.durRise)
                            easing.type: Easing.OutQuint
                        }
                    }

                    // Comes in from the screen edge it is anchored to. A
                    // transform, not `x`: this item's geometry is anchored.
                    transform: Translate {
                        x: (toast.shown || root.still)
                           ? 0
                           : (root.atLeft ? -Theme.riseDist : Theme.riseDist)
                        Behavior on x {
                            NumberAnimation {
                                duration: root.moveMs(Theme.durRise)
                                easing.type: Easing.OutQuint
                            }
                        }
                    }

                    // ── ONE RIM ─────────────────────────────────────────
                    // The slab is the material: opaque floor, Start's paint,
                    // the widgets' swell, one GlassEdge, one MirrorEdge and
                    // the glacier seam. `lifted` on hover brightens THAT rim
                    // rather than adding a second one — Pane §4.4, "never a
                    // blue outline".
                    SetSlab {
                        anchors.fill: parent
                        anchors.margins: 1
                        cornerRadius: toast.rad
                        lifted: toast.hovered
                        seam: true
                    }

                    // Critical wears a second, inset rule — a form cue that
                    // survives being seen out of the corner of the eye, and
                    // the only place magma appears on the card besides the
                    // 3 px rail.
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        visible: toast.lit
                        radius: toast.rad - 3
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.soften(root.markCritical, 0.34)
                        antialiasing: true
                    }

                    // 13pu: a layer-shell surface draws the shared edge and
                    // says what thickness it is. `body: 0` — the slab under
                    // this already has one, and stacking a second is the
                    // documented "dark card on a dark card" (WIP-259).
                    // `edging` 0.22 at rest is the quietest in the build on
                    // purpose: this is a small transient object, not a page.
                    GlassEdge {
                        anchors.fill: parent
                        radiusTL: toast.rad
                        radiusTR: toast.rad
                        radiusBR: toast.rad
                        radiusBL: toast.rad
                        edging: toast.hovered ? 0.34 : 0.22
                        body: 0
                        wash: 0
                        glaze: 0
                        bleed: 0
                        Behavior on edging {
                            NumberAnimation {
                                duration: root.moveMs(Theme.durQuick)
                                easing.type: Easing.OutQuint
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: toast.rad
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.soften(root.iceMark,
                                                   toast.hovered ? 0.72 : 0)
                        antialiasing: true
                        Behavior on border.color {
                            ColorAnimation {
                                duration: root.moveMs(Theme.durQuick)
                                easing.type: Easing.OutQuint
                            }
                        }
                    }

                    // ── the dwell hairline ──────────────────────────────
                    // Along the bottom inner edge, depleting from the right —
                    // the direction every progress bar in the build already
                    // runs, and the one a reader does not have to think about.
                    // glacier[5] prize fill. It brightens while the stack
                    // is hovered, because that is the moment it stops moving
                    // and the reason has to be visible.
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 3
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.s6
                        anchors.rightMargin: Theme.s6
                        height: 2
                        radius: 1
                        antialiasing: true
                        visible: root.wantDwellBar && !toast.lit && !toast.gone
                        width: Math.max(0, (parent.width - Theme.s6 * 2) * toast.dwell)
                        color: Theme.soften(root.iceSoft, root.stackHovered ? 0.70 : 0.38)
                        Behavior on color {
                            ColorAnimation {
                                duration: root.moveMs(Theme.durQuick)
                                easing.type: Easing.OutQuint
                            }
                        }
                    }

                    // ── the close glyph ─────────────────────────────────
                    // Only on hover. A permanent × on a card that leaves on
                    // its own is chrome for a thing that is already handled.
                    Item {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: Theme.s2
                        anchors.rightMargin: Theme.s2
                        width: 22
                        height: 22
                        opacity: toast.hovered ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity {
                            NumberAnimation { duration: root.moveMs(Theme.durQuick) }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            font.family: Theme.fIcon
                            font.pixelSize: Theme.tCaption
                            color: closeHov.hovered ? Theme.text : Theme.textDim
                        }
                        HoverHandler { id: closeHov; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.closeKey(toast.key) }
                    }

                    // ── the content ─────────────────────────────────────
                    RowLayout {
                        id: content
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: Theme.s6
                        anchors.rightMargin: Theme.s6
                        anchors.topMargin: Theme.s5
                        spacing: Theme.s4

                        // §4.12's kind rail, KEYED TO URGENCY IN FORM AND
                        // COLOUR. Not a seam: it is the only thing on the
                        // card that says which kind of notification this is,
                        // so it is state information and takes the 3:1
                        // component floor with no exemption.
                        //
                        //   routine   2 px, the height of the title line —
                        //             a tick beside the sender
                        //   critical  3 px, the height of the whole column —
                        //             a bar down the card
                        //
                        // Colour alone was never enough here: this surface is
                        // seen in peripheral vision more often than it is
                        // looked at.
                        Rectangle {
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 2
                            Layout.preferredWidth: toast.lit ? 3 : 2
                            Layout.preferredHeight: toast.lit
                                                    ? notifCol.implicitHeight
                                                    : Math.max(14, headRow.implicitHeight)
                            radius: width / 2
                            antialiasing: true
                            color: toast.lit ? root.markCritical : root.iceMark
                            Behavior on color {
                                ColorAnimation { duration: root.moveMs(Theme.durQuick) }
                            }
                        }

                        // ── the sender plate ────────────────────────────
                        // The app's own icon when it sent one; its initial in
                        // ice when it did not. Never blank: an empty square
                        // where an icon should be is worse than no plate, and
                        // an app with no icon is the common case for
                        // `notify-send`.
                        Rectangle {
                            Layout.alignment: Qt.AlignTop
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            radius: Theme.r1
                            antialiasing: true
                            color: Theme.soften(toast.lit ? root.markCritical
                                                          : root.iceMark, 0.08)
                            border.width: 1
                            border.color: Theme.soften(root.iceSeam, 0.40)

                            Image {
                                id: senderIcon
                                anchors.centerIn: parent
                                width: 20
                                height: 20
                                sourceSize.width: 40
                                sourceSize.height: 40
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                smooth: true
                                source: toast.iconSrc
                                visible: status === Image.Ready
                            }
                            StatusPip {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: -2
                                visible: toast.lit
                                kind: "magma"
                                pulse: true
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: senderIcon.status !== Image.Ready
                                text: (toast.appName.length > 0
                                       ? toast.appName.charAt(0)
                                       : toast.summary.charAt(0)).toUpperCase()
                                color: root.iceSoft
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tHead
                                font.weight: Font.DemiBold
                            }
                        }

                        ColumnLayout {
                            id: notifCol
                            Layout.fillWidth: true
                            spacing: Theme.s1

                            RowLayout {
                                id: headRow
                                Layout.fillWidth: true
                                Layout.rightMargin: 14
                                spacing: Theme.s3

                                Text {
                                    Layout.fillWidth: true
                                    text: toast.summary
                                    color: Theme.text
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tLabel
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                    clip: true
                                }

                                // Critical says so in a word as well as in the
                                // rail. Ember, never rose — see the header.
                                Text {
                                    visible: toast.lit
                                    text: qsTr("URGENT")
                                    color: root.markCritical
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tMicro
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: Theme.trackMicro
                                }

                                Text {
                                    text: toast.appName.toUpperCase()
                                    visible: toast.appName !== ""
                                    color: Theme.textDim
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tMicro
                                    font.letterSpacing: Theme.trackMicro
                                    elide: Text.ElideRight
                                    clip: true
                                    Layout.maximumWidth: 120
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: toast.body
                                color: Theme.textMuted
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                                lineHeight: 1.25
                                wrapMode: Text.WordWrap
                                visible: !!toast.body
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }

                            // ── the app's own actions ───────────────────
                            // Real `NotificationAction`s off the server
                            // object. Invoking one is the user answering the
                            // notification; it is the only thing on this
                            // surface that touches the server object, and it
                            // is still not a `dismiss()` / `expire()`.
                            RowLayout {
                                Layout.fillWidth: true
                                Layout.topMargin: Theme.s2
                                spacing: Theme.s2
                                visible: toast.acts.length > 0

                                Repeater {
                                    model: toast.acts

                                    delegate: Rectangle {
                                        id: actChip
                                        required property var modelData
                                        implicitHeight: 24
                                        implicitWidth: Math.min(140,
                                            actLabel.implicitWidth + Theme.s5 * 2)
                                        radius: height / 2
                                        antialiasing: true
                                        scale: actHov.hovered ? 1.05 : 1.0
                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: root.moveMs(Theme.durQuick)
                                                easing.type: Easing.OutQuint
                                            }
                                        }
                                        color: actHov.hovered
                                               ? Theme.soften(root.iceMark, 0.14)
                                               : "transparent"
                                        border.width: 1
                                        border.color: Theme.soften(root.iceSeam,
                                                                   actHov.hovered ? 0.85 : 0.45)
                                        Behavior on color {
                                            ColorAnimation { duration: root.moveMs(Theme.durQuick) }
                                        }
                                        Behavior on border.color {
                                            ColorAnimation { duration: root.moveMs(Theme.durQuick) }
                                        }

                                        Text {
                                            id: actLabel
                                            anchors.centerIn: parent
                                            text: String(actChip.modelData.text || "")
                                            color: actHov.hovered ? Theme.text : root.iceSoft
                                            font.family: Theme.fUi
                                            font.pixelSize: Theme.tCaption
                                            elide: Text.ElideRight
                                            clip: true
                                            width: Math.min(actLabel.implicitWidth, 116)
                                            wrapMode: Text.NoWrap
                                        }

                                        HoverHandler {
                                            id: actHov
                                            cursorShape: Qt.PointingHandCursor
                                        }
                                        TapHandler {
                                            onTapped: {
                                                try {
                                                    actChip.modelData.invoke();
                                                } catch (e) {
                                                    // The app went away between
                                                    // the card appearing and the
                                                    // tap. Close the card; the
                                                    // record stays in the flyout.
                                                }
                                                root.closeKey(toast.key);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                    onHoveredChanged: toast.hovered = hovered
                }

                // Tapping the card dismisses THE CARD. The flyout list is
                // `Sys.notifications` and is not touched — a missed toast is
                // still waiting there.
                TapHandler {
                    onTapped: root.closeKey(toast.key)
                }
            }
        }
    }
}
