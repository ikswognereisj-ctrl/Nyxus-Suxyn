// Nyxus Suxyn — the Sigil. The mark, and the Start button.
//
// 2026-09-05: the mark is the ETCHED-CRYSTAL alien head, at the owner's
// ruling "yes alien on the bar". `sigil-mark.png` is 112×112 — the slot ships
// at 4× for HiDPI and RENDERS at 28, so the file must match the SLOT, not the
// render size; a 28 px file here upscales visibly soft.
//
// ⚠ IT IS THE PURPOSE-BUILT REDUCED MARK, NOT A DOWNSCALE of the full crystal.
// Rendered side by side at a true 28 px, the downscale loses the silhouette and
// the eyes go to mush: the volumetric stack has nothing left to resolve that
// small. Rule: 64 px and below take the reduced mark, above it the crystal.
//
// It is a FINISHED, coloured brand mark, so — unlike the achromatic
// moon+meander medallion this slot used to hold — it is drawn in its own
// colours and NOT recoloured into the glyph family. This file only ever PAINTS
// the art; the artwork is never edited.
//
// THE MEDALLION IS GONE FROM THIS SLOT, and this note exists because that fact
// was not written down: on 2026-09-05 a reviewer read an older copy of this
// header, reported to the owner that swapping the Sigil would delete the
// build's only Nyx reference, and asked him to accept a cost that had already
// been paid weeks earlier. He ruled the same way regardless, and declined a
// crescent variant outright ("no just the alien is fine no cresent"). The
// lesson is the reason this paragraph is here: verify the ASSET, not its
// header. `sigil-moon.png` is unreferenced but still on disk, so the medallion
// remains one revert away.
//
// KNOWN, DELIBERATELY NOT FIXED: TRK-3073's teal tube and outer bloom were
// tuned to the medallion's DISC edge. Over this silhouette the glow reads as a
// circular halo behind an egg-shaped head rather than hugging its outline.
// That tuning is the owner's 4cfda079 and retuning it is his call, not a thing
// to adjust in passing.
//
// The component's contract is unchanged: a 28×28 Item exposing `lit` and
// `engaged`, clicked as Start (`Bus.toggleLauncher` in Bar.qml), with the
// wordmark hanging off the fixed 28 px box (`autoPaddingEnabled` stays false
// so the layout never grows). Callers are untouched.
//
// `lit` / `engaged` stay: Bar drives hover and "Start is open". The neon
// halo the owner signed off (16:10) is preserved — a teal bloom + a hotter
// corona read the mark's silhouette and glow BEHIND it, brightening on `lit`
// and going full on `engaged`. Idle chrome does not spin; engaged is the
// same 1.06 confirmation hold the blades used to keep. The old circular
// disc-tube and the crescent moon-tube belonged to the round medallion's
// geometry (a hard circle around a portrait head, and a sliver aligned to a
// crescent that no longer exists) and are gone with that art.
import QtQuick
import QtQuick.Effects

Item {
    id: sigil

    property bool lit: false
    property bool engaged: false

    implicitWidth: 28
    implicitHeight: 28

    // Neon, not ice. The halo colour, kept from the approved disc glow.
    readonly property color neon: Theme.tealGlow
    readonly property color neonHot: Theme.mix(Theme.tokenAccentPeak,
                                               Theme.tealGlow, 0.70)

    // Outer bloom. Host is 34 px tall with clip off, so a 22 px pad can
    // spill past the box — that spill IS the neon, not a clip accident. It
    // reads the mark's silhouette, so the halo hugs the head, not a box.
    MultiEffect {
        id: bloom
        z: -2
        anchors.centerIn: parent
        width: parent.width + 22
        height: parent.height + 22
        source: mark
        autoPaddingEnabled: false
        paddingRect: Qt.rect(11, 11, 11, 11)
        blurEnabled: true
        blurMax: 24
        blur: 0.85
        brightness: sigil.lit ? 0.72 : 0.48
        saturation: 0.55
        colorization: 1.0
        colorizationColor: sigil.neon
        opacity: sigil.engaged ? 1.0 : (sigil.lit ? 1.0 : 0.88)
        Behavior on opacity { NumberAnimation { duration: Theme.durQuick } }
        Behavior on brightness { NumberAnimation { duration: Theme.durQuick } }
    }

    // Inner corona — a tighter, hotter ring so the edge of the mark itself
    // looks lit, not only a fog around it.
    MultiEffect {
        id: corona
        z: -1
        anchors.centerIn: parent
        width: parent.width + 8
        height: parent.height + 8
        source: mark
        autoPaddingEnabled: false
        paddingRect: Qt.rect(4, 4, 4, 4)
        blurEnabled: true
        blurMax: 12
        blur: 0.40
        brightness: sigil.lit ? 0.90 : 0.62
        saturation: 0.35
        colorization: 0.85
        colorizationColor: sigil.neonHot
        opacity: 1.0
        Behavior on brightness { NumberAnimation { duration: Theme.durQuick } }
    }

    // The glow source: the owner's mark, held hidden and untinted so the
    // bloom/corona above keep the silhouette they colourise. NOT drawn.
    Image {
        id: mark
        visible: false
        anchors.fill: parent
        source: Qt.resolvedUrl("sigil-mark.png")
        sourceSize.width: 112
        sourceSize.height: 112
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        asynchronous: false
    }

    // The mark itself, painted in its own colours on top of the halo. This
    // is the finished brand art — matte black head, white eyes — so it is
    // shown as drawn, never recoloured. `engaged` is the 1.06 confirmation
    // scale; crisp at 28 px via smooth + mipmap.
    Image {
        id: face
        z: 1
        anchors.fill: parent
        source: Qt.resolvedUrl("sigil-mark.png")
        sourceSize.width: 112
        sourceSize.height: 112
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        asynchronous: false
        scale: sigil.engaged ? 1.06 : 1.0
        Behavior on scale {
            NumberAnimation {
                // 640 ms (durSettle) on a 6% confirmation scale read as
                // lag, not ceremony. durBase is the rest of the chrome.
                duration: Theme.durBase
                easing.type: Easing.Bezier
                easing.bezierCurve: Theme.curveRise
            }
        }
    }
}
