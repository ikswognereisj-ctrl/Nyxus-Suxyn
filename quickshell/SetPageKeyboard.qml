pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ Devices ▸ Keyboard.   MODULE 3.
//
// Backend: Hyprland `input:kb_*` and `input:repeat_*` through `HyprApply.qml`;
// the layout list comes from `localectl list-x11-keymap-layouts`, which is the
// xkeyboard-config database every Wayland compositor resolves names against.
//
// One row per setting. The layout and variant menus stay SetChoice (the
// layout list is hundreds long). Repeat rate and delay stay sliders. The
// test field stays a field: repeat rate and delay mean nothing until you
// hold a key down.
import Quickshell
import Quickshell.Io
import QtQuick

SetPage {
    id: page
    property var entry: null

    title: qsTr("Keyboard")
    blurb: qsTr("Layout, how keys repeat when held, and what the keyboard does at login.")

    property var layouts: []

    // Layout names that the xkeyboard-config DATABASE advertises but that no
    // XKB implementation can actually compile. `localectl
    // list-x11-keymap-layouts` reads /usr/share/X11/xkb/rules/base.lst, and
    // base.lst carries the line
    //     custom          A user-defined custom Layout
    // as a placeholder for people who hand-write their own symbols file.
    // xkeyboard-config ships NO /usr/share/X11/xkb/symbols/custom, so the
    // include never resolves:
    //     $ xkbcli compile-keymap --layout custom
    //     xkbcommon: ERROR: [XKB-661] Couldn't process include statement for 'custom'
    //     xkbcommon: ERROR: [XKB-822] Failed to compile keymap
    // (`--layout us` compiles fine, so this is the layout and not the tool.)
    //
    // That is the same failure the 2026-08-17 boot audit recorded from
    // systemd-localed — `Cannot compile XKB keymap … layout='custom'`, after
    // which localed leaves X11 Layout unset. This dropdown was handing the
    // user a guaranteed-broken choice, and picking a layout you cannot type on
    // is the one setting on this page you cannot undo with the keyboard.
    //
    // Filtered here rather than "fixed" by writing `us` somewhere: `custom` is
    // not this project's intent, it is an upstream placeholder leaking into a
    // user-facing list. Anyone genuinely authoring a custom symbols file is
    // editing XKB by hand and is not reaching for this menu.
    readonly property var uncompilableLayouts: ["custom"]

    Process {
        id: layoutList
        running: false
        command: ["sh", "-c",
            'if command -v localectl >/dev/null 2>&1; then '
          + 'localectl list-x11-keymap-layouts 2>/dev/null; fi']
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                var seen = {};
                var lines = String(this.text).split("\n");
                for (var i = 0; i < lines.length; ++i) {
                    var l = lines[i].trim();
                    if (l === "" || seen[l])
                        continue;
                    if (page.uncompilableLayouts.indexOf(l) !== -1)
                        continue;
                    seen[l] = true;
                    out.push({ value: l, label: l });
                }
                // A machine without localectl still has to be able to state
                // its layout, so the current one is always in the list even if
                // the database could not be read — unless it is one of the
                // names that cannot compile, which must not be re-offered here
                // just because it is the value already stored.
                var cur = SettingsStore.stringValue("kb_layout", "us");
                if (!seen[cur] && page.uncompilableLayouts.indexOf(cur) === -1)
                    out.unshift({ value: cur, label: cur });
                page.layouts = out;
            }
        }
    }

    Component.onCompleted: layoutList.running = true

    // ══ LAYOUT ═════════════════════════════════════════════════════════
    SetCard {
        heading: qsTr("Layout")
        tone: page.tone
        note: qsTr("Changing this takes effect immediately. If you pick a layout you ")
              + "cannot type on, the keys to get back here are still where they "
              + "were on your old layout."

        SetRow {
            title: qsTr("Layout")
            sub: qsTr("The layout every application uses")

            SetChoice {
                key: "kb_layout"
                defaultValue: "us"
                tone: page.tone
                options: page.layouts
                segmentLimit: 0     // always a menu: this list is hundreds long
                emptyText: "us"
            }
        }

        SetRow {
            title: qsTr("Variant")
            sub: qsTr("Leave Standard unless you want Dvorak, Colemak, or International")

            SetChoice {
                key: "kb_variant"
                defaultValue: ""
                tone: page.tone
                segmentLimit: 0
                options: [
                    { value: "",        label: qsTr("Standard") },
                    { value: "intl",    label: qsTr("International") },
                    { value: "dvorak",  label: qsTr("Dvorak") },
                    { value: "colemak", label: qsTr("Colemak") }
                ]
            }
        }
    }

    // ══ REPEAT ═════════════════════════════════════════════════════════
    SetCard {
        heading: qsTr("Repeat")
        tone: page.tone

        SetRow {
            title: qsTr("Repeat delay")
            sub: qsTr("How long a key is held before it starts repeating")

            SetSlider {
                key: "kb_repeat_delay"
                tone: page.tone
                from: 150; to: 1200; snap: 25; defaultValue: 600
                suffix: " ms"
            }
        }

        SetRow {
            title: qsTr("Repeat rate")
            sub: qsTr("Characters per second once it starts")

            SetSlider {
                key: "kb_repeat_rate"
                tone: page.tone
                from: 5; to: 60; snap: 1; defaultValue: 25
                suffix: "/s"
            }
        }

        // The test field. A plain TextInput on the build's own glass — the
        // shell carries no QtQuick.Controls and one import of it here would
        // pull a second widget style into a build whose whole premise is one
        // material.
        SetRow {
            title: qsTr("Try it")
            sub: qsTr("Hold a key down — the settings above are already live")

            Pane {
                implicitWidth: 200
                implicitHeight: 28
                elevation: 1
                radius: Theme.r1
                fill: Theme.soften(Theme.void_, 0.50)
                focusLevel: tester.activeFocus ? 1.0 : 0.0

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.r1
                    color: "transparent"
                    border.width: 1
                    border.color: tester.activeFocus
                                  ? Theme.paintLayers.glacier[0]
                                  : Theme.soften(Theme.text, 0.14)
                    Behavior on border.color { ColorAnimation { duration: Theme.durQuick } }
                }

                TextInput {
                    id: tester
                    anchors.fill: parent
                    anchors.leftMargin: Theme.s4
                    anchors.rightMargin: Theme.s4
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tLabel
                    selectByMouse: true
                    clip: true

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: tester.text === "" && !tester.activeFocus
                        text: qsTr("Hold a key…")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tLabel
                    }
                }
            }
        }
    }

    // ══ AT LOGIN ═══════════════════════════════════════════════════════
    SetCard {
        heading: qsTr("At login")
        tone: page.tone
        note: qsTr("The login screen has its own number lock. This one is for the desktop after you are in.")

        SetRow {
            title: qsTr("Number Lock")
            sub: qsTr("Turns the numeric keypad on when the desktop starts")
            SetSwitch { key: "kb_numlock"; defaultValue: false; tone: page.tone }
        }

        SetRow {
            title: qsTr("Keyboard shortcuts")
            sub: qsTr("Search Start, lock, screenshot, rooms")
            navigates: true
            onActivated: Bus.openSettings("shortcuts")
        }
    }

    SetResetRow {
        what: qsTr("Keyboard")
        keys: ["kb_layout", "kb_variant", "kb_repeat_delay", "kb_repeat_rate", "kb_numlock"]
    }
}
