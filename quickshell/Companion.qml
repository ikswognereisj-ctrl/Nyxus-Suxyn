pragma ComponentBehavior: Bound
// Nyxus Suxyn — THE COMPANION. The streetwear alien, living on the desktop.
//
// ── WHY 2D AND NOT THE GODOT BUILD ──────────────────────────────────────────
// There is an older `companion-3d/` Godot project (a transparent overlay window
// driving a Meshy-generated `nyxus_alien.glb`). The owner's verdict on it,
// 2026-09-05: "it didnt work good or look good at all." Both halves are real:
//   · LOOK — the model is an AI photogrammetry-style export. Those arrive
//     low-poly with stretched UVs, and no lighting rig recovers the detail that
//     the 2D turnaround already has. The art was BETTER than the model made
//     from it, so rendering the art directly is a strict upgrade.
//   · WORK — it needed a whole Godot runtime (never installed on the daily
//     driver), an X11 rendering driver under Hyprland, its own launcher, its
//     own Hyprland window rules and a click-passthrough hit-test. Four moving
//     parts outside the shell, for a sprite.
// This file is the sprite, hosted by the shell that is already running. No new
// runtime, no second window manager contract, and it wears the same art.
//
// ── WHAT IT IS ──────────────────────────────────────────────────────────────
//   · `WlrLayer.Bottom`, like the widget chips: it lives ON the desktop, so the
//     owner's windows cover it rather than it covering them. A desktop pet that
//     floats over a terminal is a nuisance, not a companion.
//   · The input mask is the SPRITE'S BOX ONLY (`mask: Region` over the image,
//     not the window). The window is full-width so the alien can walk; without
//     a tight mask that would eat every desktop click across the screen — the
//     "whispers lesson" this build already learned once.
//   · Idle is a slow breathing bob, never a loop of poses: at 200 px the eye
//     reads MOTION, and a 2-frame walk cycle would strobe. Facing flips by
//     mirroring, which is what the turnaround's side view is for.
import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    // Full width so the companion has somewhere to walk; the tall strip is
    // only as high as the sprite plus its shadow.
    anchors { left: true; right: true; bottom: true }
    // ⚠ MUST clear the sprite PLUS its hop, or the window edge crops his head.
    // v1 shipped 260 against a 346 px sprite and cut 86 px off the top — the
    // owner saw it immediately. The window is derived from the sprite now, so
    // resizing him can never re-introduce the crop.
    implicitHeight: sprite.height + root.hopLift + 18
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "nyxus-companion"
    color: "transparent"
    visible: Prefs.companionEnabled

    // ── WHERE HIS FEET GO ───────────────────────────────────────────────
    // `Theme.chromeH`, because that is the height Bar.qml gives its own
    // `shelf` rectangle (Bar.qml: `height: Theme.chromeH`, anchored bottom).
    // Reading the SAME token the bar draws with is what guarantees his feet
    // and the bar's top edge cannot drift apart.
    //
    // v2 used `Theme.barHeight` (52) and the owner reported he "still sits
    // below the top of the bottom bar" — correct: the shelf is 84, so 52 sank
    // him 32 px INTO it. `barHeight` is a different measurement (the row the
    // bar's contents lay out in), not the chrome's extent. Measured off the
    // live screenshot the visible edge reads ~64 px only because the shelf's
    // top ~20 px is the gradient's dark end fading into the desktop.
    margins.bottom: Theme.chromeH

    // How far the hop lifts him. Declared here because the window height is
    // derived from it — the two cannot drift apart.
    readonly property int hopLift: 34

    // ── the window gate ─────────────────────────────────────────────────
    // Same two-stage gate every animated surface in this build uses: a
    // per-frame binding left running inside an unmapped window is the
    // WIP-245/249 segfault. `backingWindowVisible` is the backer's own state,
    // not the requested one.
    property bool windowExposed: false
    onBackingWindowVisibleChanged: {
        if (backingWindowVisible) expose.restart();
        else { expose.stop(); windowExposed = false; }
    }
    Component.onCompleted: if (root.backingWindowVisible) expose.restart()
    Timer { id: expose; interval: 250; onTriggered: root.windowExposed = true }

    readonly property bool live: root.visible && root.windowExposed

    // ── where he is, and which way he faces ─────────────────────────────
    property real posX: root.width * 0.16
    property bool facingLeft: false
    property bool walking: false

    // Only the sprite takes clicks. Everything else is desktop.
    mask: Region {
        x: Math.round(root.posX - sprite.width / 2)
        y: Math.round(root.height - sprite.height)
        width: Math.round(sprite.width)
        height: Math.round(sprite.height)
    }

    Item {
        id: sprite
        // Smaller than v1 (was 172x346) at the owner's request. Height is the
        // dimension that matters; width follows the artwork's 278:560 ratio so
        // he is never stretched.
        height: 250
        width: Math.round(height * 278 / 560)
        x: root.posX - width / 2
        y: root.height - height
        transformOrigin: Item.Bottom

        // A walk is a long ease, not a constant slide — he sets off and settles.
        Behavior on x {
            enabled: root.walking
            NumberAnimation {
                duration: Theme.durCeremony
                easing.type: Easing.InOutCubic
            }
        }

        // ── the breathing bob ────────────────────────────────────────────
        // ±3 px over 2.6 s. Slow enough to read as alive, small enough that it
        // never draws the eye away from the owner's work.
        SequentialAnimation on y {
            running: root.live
            loops: Animation.Infinite
            NumberAnimation {
                to: root.height - sprite.height - 3
                duration: 1300; easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: root.height - sprite.height
                duration: 1300; easing.type: Easing.InOutSine
            }
        }

        // The ground shadow — an ellipse that tightens as he lifts, which is
        // what sells the bob as weight rather than a floating cutout.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -6
            width: parent.width * 0.52
            height: 12
            radius: height / 2
            color: Theme.soften(Theme.void_, 0.55)
            opacity: 0.7
        }

        Image {
            id: art
            anchors.fill: parent
            source: Qt.resolvedUrl(root.facingLeft ? "companion-side.png"
                                                   : "companion-front.png")
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            // Mirror the side view so one asset serves both directions.
            transform: Scale {
                origin.x: art.width / 2
                xScale: root.facingLeft ? -1 : 1
            }
        }

        // A press squashes him a touch — the same confirmation language the
        // buttons use (`Theme.curveSnap`), so the desktop feels like one kit.
        scale: tap.pressed ? 0.96 : 1.0
        Behavior on scale {
            NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutCubic }
        }

        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            id: tap
            onTapped: root.greet()
        }
    }

    // ── the hop ─────────────────────────────────────────────────────────
    // The reaction to a click. Deliberately ONE gesture: a companion with a
    // repertoire needs a state machine, and a state machine needs somewhere to
    // live. This is v1 — it says hello and it never gets in the way.
    SequentialAnimation {
        id: hop
        NumberAnimation {
            target: sprite; property: "y"
            to: root.height - sprite.height - root.hopLift
            duration: 180; easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: sprite; property: "y"
            to: root.height - sprite.height
            duration: 260; easing.type: Easing.OutBounce
        }
    }

    function greet() {
        if (!root.live)
            return;
        hop.restart();
    }

    // ── the wander ──────────────────────────────────────────────────────
    // Every 45 s he MAY amble somewhere else along the strip. Randomised and
    // infrequent on purpose: a pet that paces is a distraction, and the owner
    // is trying to work. `live` gates the timer, so an unmapped or disabled
    // companion costs nothing.
    Timer {
        running: root.live
        repeat: true
        interval: 45000
        onTriggered: {
            if (Math.random() > 0.55)
                return;
            var target = root.width * (0.10 + Math.random() * 0.78);
            root.facingLeft = target < root.posX;
            root.walking = true;
            root.posX = target;
            settle.restart();
        }
    }
    Timer {
        id: settle
        interval: Theme.durCeremony + 120
        onTriggered: { root.walking = false; root.facingLeft = false; }
    }
}
