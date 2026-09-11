pragma ComponentBehavior: Bound
// Nyxus Suxyn — the media icon family. TRK-2605.
//
// The 2026-08-22 mockups set the rule: "One icon family. 16px grid, 1.4
// stroke, round caps, drawn as inline SVG and inheriting `currentColor`. No
// colour emoji anywhere in the chrome — a desaturated emoji is not an icon
// set." (design/mockups-0822/README.md, rule 4.)
//
// Both media surfaces broke it in different ways. `LockMedia.qml` drew its
// transport with the literal characters U+23EE / U+23F8 / U+25B6 / U+23ED and
// a U+266A for the art fallback: those are EMOJI-PRESENTATION codepoints, so
// on a machine with a colour emoji font in the fallback chain the lock screen
// rendered four colour pictograms where the design says monochrome icons —
// and on one without, they came out as tofu. `MediaCrest.qml` drew its
// transport from Nerd Font private-use codepoints, which is monochrome and
// consistent but is a SECOND family, sized on the font's own grid rather than
// the 16px one, and cannot take a 1.4 stroke.
//
// This is the one family, as geometry: a 16-unit box scaled to `size`, paths
// stroked at 1.4 with round caps and joins, everything painted in `color` so
// it inherits from the call site the way `currentColor` does.
//
// Solid shapes (the play triangle, the pause bars, the skip wedges) are
// FILLED rather than stroked — a stroked triangle at 16px reads as an outline
// arrow, not a play button, and every reference set in the mockup draws
// transport as solid.
import QtQuick
import QtQuick.Shapes

Item {
    id: glyph

    // prev · play · pause · next · chevronDown · more · note
    property string name: "play"
    property real size: 16
    property color color: "white"
    property real stroke: 1.4

    implicitWidth: glyph.size
    implicitHeight: glyph.size
    width: implicitWidth
    height: implicitHeight

    readonly property real u: glyph.size / 16

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        // ── stroked paths ────────────────────────────────────────────────
        ShapePath {
            strokeColor: glyph.color
            fillColor: "transparent"
            strokeWidth: glyph.stroke * glyph.u
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: {
                    const u = glyph.u;
                    function p(s) {
                        // Scale a 16-grid path string by `u`.
                        return s.replace(/-?\d+(\.\d+)?/g, function (m) {
                            return (parseFloat(m) * u).toFixed(3);
                        });
                    }
                    switch (glyph.name) {
                    case "prev":
                        return p("M 4.2 3.6 L 4.2 12.4");
                    case "next":
                        return p("M 11.8 3.6 L 11.8 12.4");
                    case "chevronDown":
                        return p("M 4.2 6.4 L 8 10.2 L 11.8 6.4");
                    case "more":
                        return p("M 3.4 8 L 3.4 8 M 8 8 L 8 8 M 12.6 8 L 12.6 8");
                    case "note":
                        return p("M 6.2 12.2 L 6.2 3.6 L 12.4 2.4 L 12.4 10.6");
                    }
                    return "";
                }
            }
        }

        // The three dots of `more` need real caps; a zero-length segment is
        // not guaranteed to paint one on every renderer, so they are drawn.
        ShapePath {
            strokeColor: "transparent"
            fillColor: glyph.name === "more" ? glyph.color : "transparent"
            PathSvg {
                path: {
                    if (glyph.name !== "more")
                        return "";
                    const u = glyph.u;
                    const r = 1.05 * u;
                    let d = "";
                    const xs = [3.4, 8, 12.6];
                    for (let i = 0; i < xs.length; i++) {
                        const cx = xs[i] * u;
                        const cy = 8 * u;
                        d += "M " + (cx - r) + " " + cy
                           + " a " + r + " " + r + " 0 1 0 " + (r * 2) + " 0"
                           + " a " + r + " " + r + " 0 1 0 " + (-r * 2) + " 0 ";
                    }
                    return d;
                }
            }
        }

        // ── filled shapes ────────────────────────────────────────────────
        ShapePath {
            strokeColor: "transparent"
            fillColor: glyph.color
            PathSvg {
                path: {
                    const u = glyph.u;
                    function p(s) {
                        return s.replace(/-?\d+(\.\d+)?/g, function (m) {
                            return (parseFloat(m) * u).toFixed(3);
                        });
                    }
                    switch (glyph.name) {
                    case "play":
                        return p("M 5.2 3.4 L 13 8 L 5.2 12.6 Z");
                    case "pause":
                        return p("M 5.4 3.6 L 7.2 3.6 L 7.2 12.4 L 5.4 12.4 Z "
                               + "M 8.8 3.6 L 10.6 3.6 L 10.6 12.4 L 8.8 12.4 Z");
                    case "prev":
                        return p("M 12.4 3.6 L 12.4 12.4 L 5.6 8 Z");
                    case "next":
                        return p("M 3.6 3.6 L 3.6 12.4 L 10.4 8 Z");
                    case "note":
                        return p("M 6.2 9.4 a 2.1 1.7 0 1 0 0.02 0 Z "
                               + "M 12.4 8.0 a 1.7 1.4 0 1 0 0.02 0 Z");
                    }
                    return "";
                }
            }
        }
    }
}
