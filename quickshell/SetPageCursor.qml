pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ Personalization ▸ Mouse pointer.   MODULE 2.
//
// ── the backend ─────────────────────────────────────────────────────────
// A cursor theme has to be told to three things, and missing any one of them
// is why "my cursor changed everywhere except one window" is such a common
// complaint on Wayland:
//
//   the compositor   `hyprctl setcursor <theme> <size>` — Hyprland's own
//                    pointer, which is what you see over the desktop and over
//                    any client that does not set its own
//   the environment  `XCURSOR_THEME` / `XCURSOR_SIZE` — read by XWayland and
//                    by toolkits at start-up, so newly launched apps agree
//   GTK              `gsettings … cursor-theme` / `cursor-size`, which GTK
//                    apps re-read live
//
// The first two are `HyprApply.qml`'s job (it already owns the hyprctl batch
// and the env keywords); this page writes the store keys it watches, and does
// the gsettings half itself.
//
// "Hide while typing" and "Enlarge on shake" are saved, not active: Hyprland
// has no keyword for either, so they are presented cleanly disabled rather
// than removed — see the note on that card.
import Quickshell
import Quickshell.Io
import QtQuick

SetPage {
    id: page
    property var entry: null

    title: qsTr("Mouse pointer")
    blurb: qsTr("How the pointer looks, how big it is, and how easy it is to find.")

    property var themes: []
    property bool probed: false

    Process {
        id: themeList
        running: false
        command: ["sh", "-c",
            'for base in "$HOME/.local/share/icons" "$HOME/.icons" '
          + '            /usr/share/icons /usr/local/share/icons; do '
          + '  [ -d "$base" ] || continue; '
          + '  for d in "$base"/*/; do '
          + '    [ -d "$d/cursors" ] || continue; '
          + '    n=$(basename "$d"); '
          + '    c=$(ls "$d/cursors" 2>/dev/null | wc -l); '
          + '    printf "%s\\t%s\\n" "$n" "$c"; '
          + '  done; '
          + 'done | sort -u']

        stdout: StdioCollector {
            onStreamFinished: {
                var seen = {};
                var out = [];
                var lines = String(this.text).split("\n");
                for (var i = 0; i < lines.length; ++i) {
                    var f = lines[i].split("\t");
                    var name = (f[0] || "").trim();
                    if (name === "" || seen[name])
                        continue;
                    var count = parseInt(f[1], 10);
                    // A "cursors" directory with one or two files is a partial
                    // theme that inherits the rest; usable, but worth saying so,
                    // because it is why some pointers change and others do not.
                    seen[name] = true;
                    out.push({
                        value: name,
                        label: name,
                        sub: isNaN(count) ? ""
                             : count < 20 ? count + " shapes · inherits the rest"
                                          : count + " shapes"
                    });
                }
                out.sort(function (a, b) { return a.label.localeCompare(b.label); });
                page.themes = out;
                page.probed = true;
            }
        }
    }

    Component.onCompleted: themeList.running = true

    readonly property string theme: SettingsStore.stringValue("cursor_theme", "")
    readonly property int cursorSize: SettingsStore.numberValue("cursor_size", 24)

    Process {
        id: gtkApply
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                var m = String(this.text).trim();
                if (m !== "")
                    console.warn("Cursor: " + m);
            }
        }
    }

    function applyGtk() {
        if (gtkApply.running || page.theme === "")
            return;
        gtkApply.command = ["sh", "-c",
            'command -v gsettings >/dev/null 2>&1 || exit 0; '
          + 'gsettings set org.gnome.desktop.interface cursor-theme "$1" 2>/dev/null || true; '
          + 'gsettings set org.gnome.desktop.interface cursor-size "$2" 2>/dev/null || true',
            "sh", page.theme, String(page.cursorSize)];
        gtkApply.running = true;
    }

    Connections {
        target: SettingsStore
        function onCommitted(keys) {
            for (var i = 0; i < keys.length; ++i)
                if (String(keys[i]).indexOf("cursor_") === 0) {
                    page.applyGtk();
                    return;
                }
        }
    }

    // ══ THEME ══════════════════════════════════════════════════════════
    SetCard {
        heading: qsTr("Pointer theme")
        tone: page.tone
        note: page.probed && page.themes.length === 0
              ? qsTr("No cursor themes are installed beyond the built-in pointer. Installing one puts it in this list.")
              : qsTr("Applications already running keep the old pointer until they restart.")

        SetRow {
            title: qsTr("Theme")
            sub: page.theme === "" ? qsTr("System default") : ""

            SetChoice {
                tone: page.tone
                key: "cursor_theme"
                defaultValue: ""
                segmentLimit: 0
                options: page.themes
                emptyText: qsTr("System default")
            }
        }

        SetRow {
            title: qsTr("Size")
            sub: qsTr("Bigger pointers are easier to follow on a large or high-resolution screen")

            SetSlider {
                key: "cursor_size"
                tone: page.tone
                from: 16; to: 64; snap: 4; defaultValue: 24
                suffix: " px"
            }
        }

        // A live sample, at the chosen size. Cursor themes ship an
        // `index.theme` and XCursor binaries rather than previewable images,
        // so rather than fake a picture this shows the SIZE honestly — a
        // square of exactly the pixel dimensions the pointer will occupy.
        SetRow {
            title: qsTr("Preview")
            sub: qsTr("Exactly how many pixels the pointer will take up")

            Item {
                implicitWidth: Math.max(page.cursorSize, 16)
                implicitHeight: Math.max(page.cursorSize, 16)

                Rectangle {
                    width: page.cursorSize
                    height: page.cursorSize
                    anchors.centerIn: parent
                    radius: Theme.r0
                    color: Theme.elevated
                    border.width: 1
                    border.color: Theme.paintLayers.glacier[0]
                }
            }
        }
    }

    // ══ FINDING IT ═════════════════════════════════════════════════════
    SetCard {
        heading: qsTr("Finding the pointer")
        tone: page.tone
        note: qsTr("Saved for later — nothing on this build can act on these two yet, so nothing changes on screen until support is added.")

        SetRow {
            title: qsTr("Hide while typing")
            available: false
            unavailableReason: qsTr("Unavailable")
        }

        SetRow {
            title: qsTr("Enlarge on shake")
            available: false
            unavailableReason: qsTr("Unavailable")
        }

        SetRow {
            title: qsTr("Re-apply")
            sub: qsTr("Pushes the theme and size to the compositor again")

            SetButton {
                text: qsTr("Apply")
                glyph: ""
                tone: page.tone
                busy: gtkApply.running
                onClicked: { themeList.running = true; HyprApply.apply(); page.applyGtk(); }
            }
        }
    }

    SetResetRow {
        what: qsTr("Mouse pointer")
        keys: ["cursor_theme", "cursor_size"]
    }
}
