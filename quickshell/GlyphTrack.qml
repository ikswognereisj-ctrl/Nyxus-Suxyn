pragma ComponentBehavior: Bound
// Nyxus Suxyn — THE PASSWORD TRACK. Alien glyphs instead of dots.
//
// ── THE SECURITY PROPERTY, WHICH IS THE WHOLE POINT ──────────────────────────
// Each keystroke lands as its own glyph, and the glyph is drawn AT RANDOM. It is
// NEVER derived from the character typed. That is not a detail — deriving it
// would paint a substitution cipher of the owner's password on a screen that is,
// by definition, visible to whoever is standing in the room, and stable across
// attempts. Random glyphs leak exactly what dots leak: the LENGTH. Nothing else.
//
// Three ways to get this wrong, all avoided here:
//   1. Mapping glyph <- character. A monoalphabetic cipher, in public.
//   2. Seeding the generator from the text. Same thing, one step removed.
//   3. Reusing the head of the array when the length grows — a PASTE of N
//      characters must mint N NEW glyphs. Otherwise the leading glyphs stay
//      stable across attempts, and stable means informative.
//
// ── WHY THE REAL FIELD STAYS ─────────────────────────────────────────────────
// This draws only. The value lives in a real TextInput at `echoMode: Password`
// with its own text rendered invisible. Switching that field to Normal to make
// drawing easier would put the plaintext into the accessibility tree and into
// screen captures — the exact exposure the glyphs exist to prevent.
import QtQuick

Item {
    id: track

    // Driven by the real field's length. Never by its text.
    property int count: 0
    property color glyphColor: "#b7e6f2"
    property real glyphSize: 20
    property bool alarmed: false

    implicitHeight: glyphSize * 1.4
    implicitWidth: row.width

    // Greek, Cyrillic and geometric forms — legible as marks, unrelated to any
    // Latin keyboard, so nothing about the shape suggests a letter.
    // ── EVERY GLYPH HERE IS IN THE CMAP OF EVERY FONT THIS CAN RESOLVE TO ────
    // The first version of this list was written against a browser mockup using
    // a webfont, and eleven of its thirty-eight characters are absent from the
    // fonts actually installed — they would have rendered as TOFU BOXES on the
    // real login screen. Measured on the machine:
    //
    //     Orbitron                 0 / 38   (no Greek, no Cyrillic, at all)
    //     Inter                   25 / 38
    //     JetBrainsMono Nerd      27 / 38
    //     DejaVu Sans Mono        30 / 38
    //
    // Same family of mistake as a qrc: path that resolves in one context and
    // silently to nothing in another: RENDERED THERE IS NOT BUILT HERE.
    //
    // These twenty-four are present in JetBrainsMono Nerd, DejaVu Sans Mono,
    // Noto Sans Mono AND Inter, checked by reading the cmap tables rather than
    // by looking at a preview. ⊙ was dropped from the candidate set for being
    // absent from Inter alone.
    //
    // ⚠ Circles and squares (○ ● □ ■) are deliberately absent: in a password
    // field they read as a conventional mask character, which is the one thing
    // the glyphs exist not to look like.
    readonly property var _alphabet: [
        "Ξ","Ψ","Ω","Λ","Δ","Σ","Φ","Θ","Π","Γ",
        "Ж","И","Л","Ф","Ц","Ч","Ш","Э","Я",
        "⊘","⊗","◇","▽","△"
    ]

    property var _glyphs: []

    // Mint glyphs on GROWTH, drop them on shrink. Growth of N always mints N —
    // never reuses what is already there — so a paste cannot leave a stable
    // prefix behind.
    onCountChanged: {
        var g = track._glyphs.slice();
        if (track.count > g.length) {
            var n = track.count - g.length;
            for (var i = 0; i < n; ++i)
                g.push(track._alphabet[Math.floor(Math.random() * track._alphabet.length)]);
        } else if (track.count < g.length) {
            g.length = Math.max(0, track.count);
        }
        track._glyphs = g;          // reassign: QML only re-renders on a new ref
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: track.glyphSize * 0.42

        Repeater {
            model: track._glyphs
            delegate: Text {
                required property var modelData
                required property int index
                text: modelData
                color: track.alarmed ? "#ff7847" : track.glyphColor
                // ⚠ STATED, NEVER INHERITED. The field this sits over uses
                // Theme.fUi, and a display face anywhere in the chain (Orbitron
                // covers none of these) turns the whole track into boxes. The
                // fallbacks are ordered by how complete their coverage measured,
                // and every glyph above survives all of them.
                font.family: "JetBrainsMono Nerd Font, DejaVu Sans Mono, "
                             + "Noto Sans Mono, monospace"
                font.pixelSize: track.glyphSize
                opacity: 0.92

                // Each glyph settles as it lands, so typing has a pulse. The
                // animation is per-glyph and fires on creation only.
                scale: 1.0
                Component.onCompleted: settle.start()
                SequentialAnimation {
                    id: settle
                    NumberAnimation { target: parent; property: "scale"; from: 0.4; to: 1.14; duration: 90;  easing.type: Easing.OutQuad }
                    NumberAnimation { target: parent; property: "scale"; to: 1.0;             duration: 130; easing.type: Easing.OutCubic }
                }
                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }
    }
}
