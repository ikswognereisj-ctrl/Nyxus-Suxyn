// Nyxus Suxyn — the greeter's NYXUS subject: the medallion emblem.
//
// The peer of OcularMark.qml. It copies OcularMark's property surface exactly
// — `drift`, `running`, `eyeColor`, `eyeBoost` — so the greeter's Loader binds
// both subjects with ONE set of bindings and nothing upstream has to know
// which one it got.
//
// ⚠ IT IS DELIBERATELY NOT A HERO, and that is the design, not a shortfall.
// On the alien screen the mark IS the subject: a ray-marched head filling
// 34% of the screen height. On the NYXUS screen THE CARD is the subject
// (greeter-nyxus-mockup.html:28, "THE CARD is the subject here, not a mark")
// and the medallion is the card's light source — "it pools on the glass
// beneath it" (ibid:124). So this renders small and sits above the card. The
// two themes differ in what the eye lands on first, which is the whole point
// of having two.
//
// ⚠ AND IT IS SIZE-CAPPED FOR A MEASURED REASON. `sigil-mark.png` is 112x112 —
// it is the bar's asset, and there is no larger master of the medallion in the
// tree (checked 2026-09-06: sigil-mark, sigil-moon and the alien pair are the
// only NYXUS marks that exist). Blown up to the alien subject's ~408 px it is
// visibly soft. `maxPx` holds it at its native size and the emblem simply
// stops growing; the card, which is vector-clean at any size, carries the
// screen. Raising the cap needs a bigger master first, not a bigger number.
//
// THE ART IS PAINTED, NEVER RECOLOURED. Like the bar Sigil, this is finished
// brand art shown in its own colours — only the glow behind it takes the
// status tint. It is drawn as TWO images because the medallion is: the disc,
// and `sigil-moon.png`, the crescent that is pixel-aligned to it.
//
// WHY THIS IS NOT A SHADER. OcularMark ray-marches `ocular_crystal.frag`
// because the alien head is a SOLID being lit — the volume is the point. The
// medallion is flat, achromatic line art, so there is no depth field to march.
// This uses the shipped Sigil.qml treatment one step larger: bloom + a hotter
// corona reading the art's own silhouette.
import QtQuick
import QtQuick.Effects

Item {
    id: root

    // ── OcularMark's contract, mirrored ──────────────────────────────────
    // `drift` and `running` are accepted and INTENTIONALLY UNUSED: the greeter
    // sets `drift: 0` ("hold the pose; a login screen is still") and this
    // subject has no pose to hold. They exist so the Loader's bindings are
    // identical for both subjects — omitting them would make `drift: 0` a
    // "Member not found" the moment the Loader sets it.
    property real drift: 0.0
    property bool running: true

    // The status light. On the alien subject this is the EYES; here there are
    // no eyes to light, so it is the HALO. Keeping the peer's names is worth
    // more than accurate ones: renamed properties would mean a conditional at
    // every call site, which is the thing this component exists to avoid.
    // Black is the same "no opinion" sentinel OcularMark uses — here it means
    // fall through to the resting ice halo.
    property color eyeColor: Qt.rgba(0, 0, 0, 1)
    property real  eyeBoost: 1.0

    // The native size of the art. See the header: growing past this is soft.
    readonly property int maxPx: 112
    readonly property int px: Math.min(maxPx, Math.min(width, height))

    readonly property bool _tinted: eyeColor.r + eyeColor.g + eyeColor.b > 0.02
    // Paler at rest than it was (0.55,0.86,0.96). The medallion now sits on
    // his login image, which is greyscale, and a saturated cyan pool on a
    // monochrome picture is the thing that read as 'stuck on top of it'.
    readonly property color _halo: _tinted ? eyeColor : Qt.rgba(0.74, 0.87, 0.93, 1)

    // The art, at its true size, centred in whatever box the Loader gives it.
    Item {
        id: emblem
        anchors.centerIn: parent
        width: root.px
        height: root.px

        // ── THE ART, WHICH IS ALSO THE GLOW SOURCE ───────────────────
        // ONE COPY, NOT TWO. Sigil.qml feeds its effects from a hidden Image
        // and paints a second visible copy on top; this draws the source
        // itself and puts the effects behind it. The reason is that the source
        // here must be a CONTAINER — the medallion is two files, the disc and
        // its pixel-aligned crescent, and they have to blur as one silhouette
        // rather than as two — and a container with `visible: false` is not
        // rendered, so its layer texture would never be filled. Keeping the
        // container visible sidesteps that question rather than betting on it,
        // and costs nothing: the pixels drawn are identical either way.
        //
        // ⚠ THE GLOW ITSELF IS UNVERIFIED ON SCREEN. Established 2026-09-06
        // with a two-square control test (a plain Rectangle beside the same
        // Rectangle through a MultiEffect): in an offscreen + software-GL
        // harness the plain square renders and THE MULTIEFFECT PRODUCES NO
        // PIXELS AT ALL. So this file's geometry, art and sizing are captured
        // and correct, but every brightness/blur/colorization number below is
        // reasoned from Sigil.qml's shipped values and has never been seen.
        // They want an eye on a real GPU. Do not read the numbers as measured.
        //
        // That harness limit is also why the nested-compositor preview is the
        // only real check here — and it needs a seat, so it must be run from
        // the owner's own session: `greeter/preview-greeter.sh <tree> <out>`.
        Item {
            id: art
            anchors.fill: parent
            z: 1
            layer.enabled: true          // flatten the pair into one texture
            Image {
                anchors.fill: parent
                source: Qt.resolvedUrl("sigil-mark.png")
                sourceSize.width: 112; sourceSize.height: 112
                fillMode: Image.PreserveAspectFit
                smooth: true; mipmap: true; asynchronous: false
            }
            Image {
                anchors.fill: parent
                source: Qt.resolvedUrl("sigil-moon.png")
                sourceSize.width: 112; sourceSize.height: 112
                fillMode: Image.PreserveAspectFit
                smooth: true; mipmap: true; asynchronous: false
            }
        }

        // Outer bloom — the pool of light the card sits in.
        //
        // ⚠ NOT A BLURRED COPY OF THE ART ANY MORE, and the reason is
        // structural rather than a tuning miss. A MultiEffect blur is clipped
        // by its own item bounds, so whatever brightness its tail still has
        // when it reaches the edge is drawn as a straight line -- the
        // medallion sat inside a visible RECTANGLE of light. Seen on a real
        // GPU through a nested compositor twice, at 2.10x and again at 3.20x:
        // widening the box only produced a bigger rectangle, because size was
        // never the variable.
        //
        // star-glow.png is a radial sprite already shipping in this tree, and
        // its alpha is 0 at every edge AND every corner (measured, not
        // assumed). A pool drawn from it cannot have an edge to see.
        Image {
            z: -2
            anchors.centerIn: parent
            width: parent.width * 3.10
            height: width
            source: Qt.resolvedUrl("star-glow.png")
            smooth: true
            mipmap: true
            asynchronous: false
            opacity: Math.min(1.0, 0.40 * root.eyeBoost)
            layer.enabled: true
            layer.effect: MultiEffect {
                colorization: 1.0
                colorizationColor: root._halo
                brightness: 0.06
                saturation: 0.55
            }
            Behavior on opacity {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
        }

        // Inner corona — tight and hotter, so the strokes themselves look lit
        // rather than sitting in front of a cloud.
        MultiEffect {
            z: -1
            anchors.centerIn: parent
            width: parent.width * 1.30
            height: parent.height * 1.30
            source: art
            autoPaddingEnabled: false
            paddingRect: Qt.rect(emblem.width * 0.15, emblem.height * 0.15,
                                 emblem.width * 0.15, emblem.height * 0.15)
            blurEnabled: true
            blurMax: 16
            blur: 0.45
            brightness: 0.42 * root.eyeBoost
            saturation: 0.55
            colorization: 0.92
            colorizationColor: root._halo
            Behavior on brightness { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        }
    }
}
