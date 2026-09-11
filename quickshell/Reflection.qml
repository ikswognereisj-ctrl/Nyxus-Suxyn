// Nyxus Suxyn — the REFLECTION, as a component.
//
// The dock icons' mirrored fall of light (Bar.qml § the Reflection), packaged
// so every other icon in the build can carry the identical one. Owner,
// 2026-08-14, of the mirror look: "not everything has that, so that needs to
// also be complete — and if that's something we are using system wide those
// changes need to be made through all of the system."
//
// Same construction as the bar's, which is the reference: the content is
// flipped about its own vertical centre, faded through the build's one
// alpha-mask gradient (`Theme.reflectH` deep, `Theme.reflectAlpha` strong),
// and never dimmed with a scrim — the living paint is usually directly behind
// a reflection and a scrim would punch a dull rectangle through it.
//
// Usage: size and place this item where the reflection should LAND (normally
// anchored to the bottom edge of the thing it mirrors, same width and
// height), and put a copy of the mirrored thing inside as content:
//
//     Text { id: glyph; ... }
//     Reflection {
//         anchors.top: glyph.bottom
//         anchors.horizontalCenter: glyph.horizontalCenter
//         width: glyph.width; height: glyph.height
//         Text { anchors.fill: parent; text: glyph.text; ... }
//     }
//
// The copy is deliberate and cheap: a live mirror of an arbitrary sibling
// needs a ShaderEffectSource of an item the caller does not control, which is
// the segfault class WIP-245 documents. A second Text/Image bound to the same
// properties costs one node and can never take the window down.
//
// ══ 2026-09-07 · IT IS THE ONLY REFLECTION IN THE BUILD NOW ═ TRK-3826 ══
// Owner: "you know on the music bar how half of it is suppose to be like a
// mirror in a sense you said can we make that look more like a mirror".
//
// Bar.qml's dock carried a byte-for-byte inline copy of this component. It
// is gone; the dock instantiates this. That had to happen BEFORE anything
// below could change, because a change made to one copy and not the other
// produces exactly the complaint that opened the row — "so everything looks
// part of the same build".
//
// ══ WHAT MAKES IT READ AS A MIRROR AND NOT AS AN UPSIDE-DOWN COPY ══════
// A flipped copy at 30% alpha is a decal. Two things separate it from a
// reflection, and NEITHER COSTS A RENDER PASS — both are properties of
// nodes that were being drawn anyway:
//
//   · FORESHORTENING. A surface reflecting an object in front of it
//     returns a vertically COMPRESSED image, because the far end of the
//     reflection is further from the eye than the near end. A 1:1 flip is
//     what you get from a mirror in the same plane as the object — a
//     shop window, not a floor. `squash` compresses about the contact
//     line, so the reflection stays welded to the object's base and
//     shortens away from it.
//
//   · A FALL-OFF THAT IS NOT A RAMP. The mask was two stops: full at the
//     contact line, nothing at `Theme.reflectH`. That is a linear ramp,
//     and a linear ramp is the one profile no real surface produces —
//     reflected light drops fast right after contact and then trails. The
//     middle stop bends it: still `Theme.reflectH` deep, so nothing in the
//     build's spacing moves, but 0.38 of the way down it is already at a
//     quarter rather than at half.
//
// ⚠ WHAT WAS MEASURED AND LEFT OUT. A distance-varying BLUR is the third
// thing real reflections do and it is not here. MultiEffect's blur is
// uniform, so a true one needs the near band and the far band composited
// as two passes — doubling the shader work of every reflection on a bar
// that now carries about a dozen. Gate 13uv exists because the owner
// killed a live wallpaper for lagging his machine; a decorative effect
// does not get to double its cost on a plate that redraws every frame.
// Measured cost of everything that IS here: see the row's proof.
//
// ══ "A LITTLE MORE MIRROR" ═════════════════════════ TRK-3828 · 09-07 ══
// Owner, having seen the above on his own bar: "can we add just a little
// more mirrior feature to it too".
//
// ⚠ MORE MIRROR IS NOT MORE ALPHA, and getting that backwards is how the
// effect dies. A reflection is convincing BECAUSE it is dimmer and softer
// than the thing it reflects; raise its alpha until it competes and the
// eye stops reading two objects and starts reading two drawings. So the
// volume moves a little and the DEPTH moves a lot:
//
//   `depth`  Theme.reflectH x 1.45 (0.46 -> 0.667 of the box). The fall
//            reaches further, so MORE OF THE OBJECT comes back before it
//            dies — which is the thing that reads as a better mirror. The
//            bend introduced above keeps it from becoming a slab: it is
//            still at a quarter by 0.38 of the way down, it simply has
//            further to travel after that.
//   `gain`   1.18 on Theme.reflectAlpha (0.30 -> 0.354). Enough to be
//            seen on the near band, nowhere near the real content.
//
// ⚠ THE TOKENS THEMSELVES DID NOT MOVE, deliberately. `Theme.reflectH`
// and `Theme.reflectAlpha` are also read by `MirrorEdge`'s shader, which
// is a RIM effect — a hairline and a fall along a pane's edge, not an
// object's fall onto a floor. The owner asked for more mirror under the
// things on his bar, not for every card's rim in the build to thicken by
// half. The multipliers live here, on the component he was looking at,
// and either can be overridden per call site.
import QtQuick
import QtQuick.Effects

Item {
    id: m

    // One dial, like MirrorEdge's, so a quiet surface can carry a quiet
    // reflection without the recipe's numbers drifting per call site.
    property real strength: 1.0

    // Vertical compression of the reflected image, about the contact line.
    // 1.0 is a flat mirror facing the object; below 1.0 is a surface the
    // object stands ON, seen from above. The bar, the dock and every card
    // in this build are the second kind.
    property real squash: 0.88

    // How far into the box the fall reaches, as a fraction of the box.
    // See § "A LITTLE MORE MIRROR" for why this is a multiple of the token
    // rather than the token, and why the token did not move.
    property real depth: Math.min(1.0, Theme.reflectH * 1.45)

    // Multiplier on Theme.reflectAlpha. Small on purpose.
    property real gain: 1.18

    default property alias content: flip.data

    // Clamped once, here, so a call site cannot push a gradient stop past
    // 1.0 and silently invert the mask.
    readonly property real _d: Math.max(0.05, Math.min(0.98, m.depth))

    Item {
        id: srcBox
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Item {
            id: flip
            anchors.fill: parent
            // Order matters and is the whole trick: flip about the box's own
            // centre first, THEN compress about the box's TOP — which is the
            // contact line, because the caller anchors this item's top to the
            // bottom of the thing being mirrored. Compressing about the
            // centre instead would float the reflection off its object.
            transform: [
                Scale {
                    origin.y: flip.height / 2
                    yScale: -1
                },
                Scale {
                    origin.y: 0
                    yScale: Math.max(0.2, Math.min(1.0, m.squash))
                }
            ]
        }
    }
    Item {
        id: maskBox
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.soften(Theme.text, 1.0) }
                // The bend. The fall is not a straight line from full to
                // nothing — that is the one profile no real surface
                // produces. Reflected light drops fast just after contact
                // and then trails, so the middle stop is at a quarter where
                // a ramp would be at half, and `depth` decides how far the
                // trail runs.
                GradientStop { position: m._d * 0.38; color: Theme.soften(Theme.text, 0.26) }
                GradientStop { position: m._d; color: Theme.soften(Theme.text, 0.0) }
                GradientStop { position: 1.0; color: Theme.soften(Theme.text, 0.0) }
            }
        }
    }
    MultiEffect {
        anchors.fill: parent
        source: srcBox
        maskEnabled: true
        maskSource: maskBox
        opacity: Theme.reflectAlpha * m.gain * m.strength
    }
}
