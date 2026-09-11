// Nyxus Suxyn — the Rail. A divider made of light instead of a grey line.
//
// The shell was full of `Rectangle { height: 1; color: soften(text, 0.08) }` —
// a grey hairline, which is the one thing HORIZON §3.5 says this palette does
// not contain ("there is no such thing in them as a dull dark"). A Rail is the
// same job done in the build's own material: it takes its colour from where it
// sits on screen via `Theme.sweepAt`, and it fades out at both ends so it
// never reads as a box edge — the thing §2 spends a page saying this desktop
// does not have.
//
// Horizontal by default. Set `vertical: true` for the upright form that
// separates the groups inside the Gauge.
import QtQuick

Rectangle {
    id: rail

    property bool vertical: false
    // Position on the signature sweep, 0 (teal, screen left) → 1 (plum, right).
    property real tone: 0.5
    property real strength: 0.26
    // How much of the run is at full strength before the ends fade out.
    property real waist: 0.62

    implicitWidth: vertical ? 1 : 80
    implicitHeight: vertical ? 22 : 1
    color: "transparent"

    readonly property color _c: Theme.soften(Theme.sweepAt(rail.tone), rail.strength)

    gradient: Gradient {
        orientation: rail.vertical ? Gradient.Vertical : Gradient.Horizontal
        GradientStop { position: 0.0; color: "transparent" }
        GradientStop { position: (1.0 - rail.waist) / 2; color: rail._c }
        GradientStop { position: 1.0 - (1.0 - rail.waist) / 2; color: rail._c }
        GradientStop { position: 1.0; color: "transparent" }
    }
}
