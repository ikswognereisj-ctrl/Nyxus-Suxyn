/*
 * NYXUS · Calamares branding slideshow              rev 2026-08-17 r4
 *
 * 6-slide installer slideshow, cross-faded. Runs beside the install log on the
 * one page the user actually sits and watches, so it is the surface with the
 * most dwell time in the whole product.
 *
 * THIS COPY SHIPS. scripts/ship-manifest.py resolves
 *   /etc/calamares/branding/nyxus/show.qml
 *     ← iso-builder/nyx-profile/airootfs/etc/calamares/branding/nyxus/show.qml
 *       build-iso.sh:134, twin_exists FALSE.
 * The artifacts/api-server/nyxus-scripts/ copy is a different destination
 * (/opt/nyxus-cache/…, build-iso.sh:1345), not a losing twin.
 *
 * ── WHAT r4 CHANGED, AND THE RULE BEHIND EACH ──────────────────────────────
 * COLOUR · every value is a theme/accent.json token, named inline. The two
 *   seam alphas are derived from the teal token with Qt.rgba() rather than
 *   written as #AARRGGBB, because gate 13q11 only reads alpha-first 8-digit
 *   notation under /qt5ct/, /qt6ct/ and /syslinux/ and would decline to decode
 *   an 8-digit run here. Deriving keeps the hex greppable and the gate happy.
 *   The old background was a #03040c → #000000 wash: #03040c is the
 *   `_swirl._emission.base` MIRROR of void, not `_palette_fixed.void`, and rev 3
 *   §1.1 allows no wash at all ("light lives on the EDGES and in STATE, never as
 *   a wash"). It is now flat `void` — the ground `_tokens.edges.ground` names, so
 *   every ratio accent.json publishes is true of this surface verbatim.
 *   The old `hairline` property was named for a hairline and valued `elevated`
 *   #071318 — a FILL token doing an edge's job, and at 1.09:1 on the ground the
 *   inactive pagination dots were effectively invisible.
 * THE GRADIENT RULE · ADDENDUM §A4, and this is its ONE HOME IN THE INSTALLER.
 *   §A4: "Exactly one per window. It marks the page header and nothing else.
 *   Every additional gradient rule costs it its meaning." The slide title is the
 *   only page header the installer has that branding can reach — Calamares' own
 *   chrome exposes no styleable title widget — so the 80px teal tick that used to
 *   sit under the title becomes the full-width cyan→purple→magenta hairline, and
 *   stylesheet.qss deliberately carries no gradient at all.
 *   §A4 spells its three stops as literal hexes, but those are REVISION-1 values
 *   that the design language's own precedence notice withdraws ("This file no
 *   longer publishes color values … Color: theme/accent.json"). The repository's
 *   equivalents, by hue, are teal → indigo_glow → plum; the withdrawn purple and
 *   indigo_glow differ by roughly one degree of hue. Those three withdrawn
 *   values are deliberately NOT SPELLED IN THIS FILE, not even in a comment:
 *   gate 13q11 walks .qml and its comment stripper only understands `//`, so a
 *   hex named inside this C-style block would be read as a shipped colour. It
 *   was — an earlier draft of this header quoted all three and 13q11 failed the
 *   build on exactly them, which is the gate behaving correctly.
 *   §A4's 0.25-alpha glow under the rule is NOT drawn: QML has no box-shadow and
 *   Calamares' QML runtime cannot be assumed to carry QtGraphicalEffects.
 *   Recorded, not faked.
 * TYPE · HORIZON §6 owns the ladder and states outright which faces exist:
 *   "Available on the ISO and on the host: Inter and Inter Display, JetBrains
 *   Mono Nerd Font, Font Awesome." Rev 3 §2 asks for Rajdhani; RAJDHANI IS NOT
 *   PACKAGED (absent from packages.x86_64, fc-match resolves it to Noto Sans).
 *   The repository is the authority, so this file is Inter / Inter Display, with
 *   mono kept only for the box-drawing brand glyph. Every size is one of
 *   HORIZON's seven: fDisplay 30 · fTitle 20 · fBody 13 · fMicro 9. The old
 *   32/18/14/11 and letterSpacing 6 were all off-ladder.
 * MOTION · HORIZON §3.1/§3.2 own durations and curves, and "exits are faster
 *   than entrances" — 340 up, 200 down, "because perception is not symmetrical".
 *   The old single 380ms OutCubic did both directions at one speed. The
 *   cross-fade is now durSink 200 on curveSink out, durRise 340 on curveRise in,
 *   and the dots travel on durBase 260 / curveMove. QML needs the trailing
 *   (1,1) control point appended to bezierCurve, which is why each array has six
 *   numbers rather than four.
 * COPY · VOICE_AND_COPY §0 rule 1 is "sentence case everywhere" except uppercase
 *   typographic labels; four slide titles were Title Case. §1 and ADDENDUM
 *   defect 6 ban leaked internals: the `SNAPPER` tagline named the daemon, and a
 *   `~/.cache/nyxus/<app>.log` path shipped a template placeholder on a
 *   first-contact screen. "Bottom horizon chrome" was internal jargon for what
 *   §1 calls the "Bar". `NYXUS · Suxyn` is neither canonical form (§1: `NYXUS`
 *   and `Nyxus Suxyn`).
 *
 */
import QtQuick 2.15

Item {
    id: root
    width: 800
    height: 460

    // ── colour · theme/accent.json, token named on every line ──────────────
    readonly property color ground:   "#020506"   // _palette_fixed.void = _tokens.edges.ground
    readonly property color teal:     "#b7e6f2"   // glacier ice · chrome, not fill
    readonly property color tealGlow: "#4f7fa6"   // glacier hairline
    readonly property color indigo:   "#7a63f0"
    readonly property color plum:     "#ff7847"   // magma · what matters
    readonly property color textHi:   "#e8f4f8"
    readonly property color textLo:   "#8aa4b0"

    // The two SEAM rungs of _tokens.edges, ladder A: teal at 0.07 and 0.22.
    // WCAG 1.4.11-exempt by seams._exemption; 1.06:1 and 1.32:1 on the ground
    // are CORRECT and seams._do_not_fix says so in as many words.
    readonly property color seamStructural: Qt.rgba(teal.r, teal.g, teal.b, 0.07)
    readonly property color seamIdle:       Qt.rgba(teal.r, teal.g, teal.b, 0.22)

    // ── motion · HORIZON §3.1 durations, §3.2 curves ────────────────────────
    readonly property int  durRise: 340
    readonly property int  durSink: 200
    readonly property int  durBase: 260
    readonly property var  curveRise: [0.16, 1.0,  0.30, 1.0,  1, 1]
    readonly property var  curveSink: [0.55, 0.0,  0.85, 0.15, 1, 1]
    readonly property var  curveMove: [0.62, 0.0,  0.20, 1.0,  1, 1]

    // Flat ground. No wash — rev 3 §1.1.
    Rectangle {
        anchors.fill: parent
        color: root.ground
    }

    property int currentSlide: 0
    readonly property var slides: [
        {
            title:   "Welcome to Nyxus Suxyn",
            // The hardware-support line (TRK-1205 / CS-1058): Intel, AMD and
            // NVIDIA graphics are all v1 targets — owner ruling 2026-08-20,
            // "any typical PC ~2012-now". Uppercase label form per VOICE_AND_COPY.
            // TRK-3687: the date is NOT typed here. `2026.09.02` is
            // substituted with build-iso.sh's ${ISO_DATE} at bake, the same
            // one that names the ISO and stamps branding.desc, profiledef.sh
            // and os-release. A hand-pinned date on slide 1 is the same lie
            // the welcome page was telling; the bake aborts if the token
            // survives. Gate 13s52 still reads the support line from here.
            tagline: "Nyxus Suxyn · 2026.09.02 · INTEL · AMD · NVIDIA",
            body:    "A daily-driver Arch desktop: Starlight sky, a living\nHorizon bar, glass panels, and first-party apps —\nso you can live here without opening a terminal\nunless you want to."
        },
        {
            title:   "One desktop.",
            tagline: "START · FILES · SETTINGS · DONE",
            body:    "A Horizon bar, a real Start menu, Files, Notes,\nMedia, Calendar, Store, and Settings — glass\nfurniture, crystal identity, magma for what matters."
        },
        {
            title:   "Your computer. Yours.",
            tagline: "NO TELEMETRY · NO ACCOUNTS REQUIRED",
            body:    "Crash reporting and account sync are explicit opt-in.\nNothing leaves the machine unless you said so.\nDiagnostics stay here, readable and rotatable."
        },
        {
            title:   "Restore points. Always.",
            tagline: "RESTORE POINTS · FROM SETTINGS",
            body:    "A restore point is taken before updates, so an update\nthat breaks something has an answer. Restore from\nBackup in Settings — no terminal required."
        },
        {
            title:   "Familiar, then yours.",
            tagline: "FLOATING WINDOWS · SNAP · OPTIONAL TILING",
            body:    "Windows float by default. Drag to an edge to snap.\nSuper+Arrow does Aero Snap. Tiling stays available\non Super+Alt+T for whoever wants it — never required."
        },
        {
            title:   "Make it yours.",
            tagline: "OPEN SETTINGS → BEGIN",
            body:    "Tap Super for Start. Open Settings for wallpaper,\naccent, displays, sound, and privacy. Welcome to\nNyxus Suxyn."
        }
    ]

    // Dwell, not motion: 8 s is how long a slide is READ for, so it is not one
    // of HORIZON's durations and deliberately does not use them.
    Timer {
        interval: 8000
        running:  true
        repeat:   true
        onTriggered: advance.restart()
    }

    // Exits are faster than entrances — HORIZON §3.1, 340 up / 200 down.
    SequentialAnimation {
        id: advance
        NumberAnimation {
            target: slideContent; property: "opacity"; to: 0.0
            duration: root.durSink
            easing.type: Easing.Bezier; easing.bezierCurve: root.curveSink
        }
        ScriptAction {
            script: root.currentSlide = (root.currentSlide + 1) % root.slides.length
        }
        NumberAnimation {
            target: slideContent; property: "opacity"; to: 1.0
            duration: root.durRise
            easing.type: Easing.Bezier; easing.bezierCurve: root.curveRise
        }
    }

    // ── Brand lockup (top-left) ────────────────────────────────────────────
    Row {
        x: 40; y: 36
        spacing: 12                              // HORIZON s5
        Text {
            text: "◤ X ◥"
            color: root.teal
            font.family: "JetBrainsMono Nerd Font"   // box-drawing glyphs need mono
            font.pixelSize: 30                       // HORIZON fDisplay
        }
        Column {
            spacing: 2                           // HORIZON s1
            Text {
                text: "NYXUS"
                color: root.teal
                font.family: "Inter Display"     // HORIZON fTitle
                font.pixelSize: 20
                font.weight: Font.Light
            }
            Text {
                text: "SUXYN"
                color: root.textLo
                font.family: "Inter"             // HORIZON fMicro — the wordmark
                font.pixelSize: 9
                font.weight: Font.Medium
                font.letterSpacing: 1.4
            }
        }
    }

    // Corner bracket — brand mark, top right. Rev 3 §1.2 allows the identity
    // accent "at most twice per screen": this and the gradient rule's tail.
    Rectangle {
        width: 60; height: 2
        color: root.tealGlow                     // _palette_fixed.teal_glow
        x: parent.width - 100; y: 48
    }
    Rectangle {
        width: 2; height: 22
        color: root.tealGlow
        x: parent.width - 42; y: 38
    }

    // ── Slide content (centre) ─────────────────────────────────────────────
    Column {
        id: slideContent
        anchors.centerIn: parent
        spacing: 16                              // HORIZON s6
        width: 640
        opacity: 1.0

        // fMicro — "the system's own voice", uppercase, tracked, muted.
        Text {
            text: root.slides[root.currentSlide].tagline
            color: root.tealGlow
            font.family: "Inter"
            font.pixelSize: 9
            font.weight: Font.Medium
            font.letterSpacing: 1.4
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // fDisplay — Inter Display 30 Light.
        Text {
            text: root.slides[root.currentSlide].title
            color: root.textHi                   // 18.14:1 on the ground
            font.family: "Inter Display"
            font.pixelSize: 30
            font.weight: Font.Light
            anchors.horizontalCenter: parent.horizontalCenter
        }

        // ── THE GRADIENT RULE · ADDENDUM §A4 · EXACTLY ONE PER WINDOW ──────
        // Full content width, 1px, 0.85 alpha, stops at 0 / 0.55 / 1.
        // On the ground: teal 6.96:1 · indigo_glow 4.74:1 · plum 3.14:1 — every
        // stop clears the 3:1 component floor, so the rule is legible along its
        // whole length rather than fading out at the magenta end.
        // DO NOT ADD A SECOND ONE ANYWHERE IN THE INSTALLER.
        Rectangle {
            width:   parent.width
            height:  1
            opacity: 0.85
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.00; color: root.teal }    // teal
                GradientStop { position: 0.55; color: root.indigo }  // indigo_glow
                GradientStop { position: 1.00; color: root.plum }    // plum
            }
        }

        // fBody — Inter 13 Regular at text_muted, which is rev 3 §1.3's
        // secondary rung, instead of the old text-primary at an ad-hoc 0.85
        // opacity. 13.31:1 on the ground.
        Text {
            text: root.slides[root.currentSlide].body
            color: root.textLo
            font.family: "Inter"
            font.pixelSize: 13
            lineHeight: 1.5
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            width: parent.width
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // ── Pagination dots ────────────────────────────────────────────────────
    // The inactive dot was `elevated` #071318 on the ground: 1.09:1, invisible.
    // It is now the seams.idle rung — a resting mark is a boundary, not a state.
    Row {
        spacing: 8                               // HORIZON s4
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 32                 // HORIZON s9
        anchors.horizontalCenter: parent.horizontalCenter
        Repeater {
            model: root.slides.length
            Rectangle {
                width:  index === root.currentSlide ? 24 : 8   // HORIZON s8 / s4
                height: 4
                radius: 2                                      // rFull at 4px
                color:  index === root.currentSlide ? root.teal : root.seamIdle
                Behavior on width {
                    NumberAnimation {
                        duration: root.durBase
                        easing.type: Easing.Bezier; easing.bezierCurve: root.curveMove
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: root.durBase
                        easing.type: Easing.Bezier; easing.bezierCurve: root.curveMove
                    }
                }
            }
        }
    }

    // ── Footer seam · a divider, so ladder A structural ────────────────────
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        height: 1
        color:  root.seamStructural
    }
}
