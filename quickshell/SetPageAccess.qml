pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ Ease of Access ▸ Accessibility (TRK-1220 / CS-1061).
//
// The escape hatch for a shell of springs and swirls. Every control goes
// through SettingsStore the way Feel does; Prefs.qml only reads.
//
//   reduced_motion  the shell key SoftPress / BorderPulse already read and
//                   TRK-1221 spread to every animated host. The same flip
//                   also writes gsettings enable-animations for GTK apps,
//                   which is what the GTK Settings "Reduce motion (apps)"
//                   switch has always done — one switch, both worlds.
//   font_scale      NOT a new key. GTK Settings ▸ Accessibility has written
//                   this (0.85–1.40) and applied gsettings
//                   text-scaling-factor since before the glass existed. A
//                   `text_scale` twin would be a second spelling of one
//                   fact (WIP-108). Three stops here: 1.0 / 1.15 / 1.3.
//   high_contrast   new key. Reaches libadwaita apps through
//                   org.gnome.desktop.a11y.interface high-contrast (via the
//                   gtk settings portal). The shell's own tokens live in
//                   Theme.qml (fenced) and do not read it yet — TRK-1224.
//
// Assistive tools are SYSTEM facts, so their switches are driven, not
// key-bound: orca / squeekboard are probed with pgrep and started detached
// (setsid -f) so leaving this page cannot take them down. The ISO packages
// orca + speech-dispatcher + at-spi2-core and squeekboard (packages.x86_64
// — squeekboard REPLACES wvkbd, which is AUR-only and would kill pacstrap).
// A dev checkout may have neither; the rows then say so instead of offering
// a Launch that cannot work.
//
// Magnifier: the compositor zoom `cursor:zoom_factor`, driven by the skel's
// own ~/.config/hypr/scripts/nyxus-lens.sh (also Super+Alt+scroll / = / -).
// No third-party magnifier exists in the repos this image is built from.
//
// ISO ice: named Theme tokens only, no hex. No restructure of any host.
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    property var entry: null
    title: qsTr("Accessibility")
    blurb: qsTr("Motion, text size, contrast, and the assistive tools on this machine.")

    readonly property bool reduced: SettingsStore.boolValue("reduced_motion", false)
    readonly property real textScale: SettingsStore.numberValue("font_scale", 1.0)
    readonly property bool contrast: SettingsStore.boolValue("high_contrast", false)

    // ── what the probe found ─────────────────────────────────────────────
    property bool probed: false
    property string orcaBin: ""
    property bool orcaRunning: false
    property string oskBin: ""
    property bool oskRunning: false
    property bool lensHere: false
    property real zoom: 1.0
    property bool gsettingsHere: false
    property string lastNote: ""

    // One sh, one pass, tab-separated facts. pgrep -x is exact-name; the
    // zoom is hyprctl's own JSON so no jq is needed here.
    Process {
        id: probe
        running: false
        command: ["sh", "-c",
            'o=$(command -v orca 2>/dev/null || true); '
          + 'k=$(command -v squeekboard 2>/dev/null || true); '
          + 'printf "orca\\t%s\\n" "$o"; '
          + 'pgrep -x orca >/dev/null 2>&1 && printf "orca_run\\t1\\n" || printf "orca_run\\t0\\n"; '
          + 'printf "osk\\t%s\\n" "$k"; '
          + 'pgrep -x squeekboard >/dev/null 2>&1 && printf "osk_run\\t1\\n" || printf "osk_run\\t0\\n"; '
          + '[ -x "$HOME/.config/hypr/scripts/nyxus-lens.sh" ] && printf "lens\\t1\\n" || printf "lens\\t0\\n"; '
          + 'command -v gsettings >/dev/null 2>&1 && printf "gs\\t1\\n" || printf "gs\\t0\\n"; '
          + 'z=$(hyprctl getoption cursor:zoom_factor -j 2>/dev/null | tr -d "\\n" || true); '
          + 'printf "zoom\\t%s\\n" "$z"']
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = String(this.text).split("\n");
                for (var i = 0; i < lines.length; ++i) {
                    var f = lines[i].split("\t");
                    var k = (f[0] || "").trim();
                    var v = (f.length > 1 ? f.slice(1).join("\t") : "").trim();
                    if (k === "orca")          page.orcaBin = v;
                    else if (k === "orca_run") page.orcaRunning = v === "1";
                    else if (k === "osk")      page.oskBin = v;
                    else if (k === "osk_run")  page.oskRunning = v === "1";
                    else if (k === "lens")     page.lensHere = v === "1";
                    else if (k === "gs")       page.gsettingsHere = v === "1";
                    else if (k === "zoom") {
                        var z = 1.0;
                        try {
                            var j = JSON.parse(v);
                            if (j && typeof j["float"] === "number")
                                z = j["float"];
                        } catch (e) {
                            z = 1.0;
                        }
                        page.zoom = z > 0 ? z : 1.0;
                    }
                }
                page.probed = true;
            }
        }
    }

    Component.onCompleted: probe.running = true

    // Re-probe a beat after an action (a daemon needs a moment to appear
    // in pgrep), and slowly while the page is up — someone may start orca
    // from a keybind or close squeekboard from its own button.
    Timer {
        id: reprobe
        interval: 1200
        repeat: false
        onTriggered: if (!probe.running) probe.running = true
    }
    Timer {
        interval: 4000
        repeat: true
        running: page.visible
        onTriggered: if (!probe.running) probe.running = true
    }

    // ── actions — one Process, one command at a time ─────────────────────
    // `onRunningChanged`, not `onExited`: Quickshell's `exited` carries a
    // QProcess::ExitStatus the QML type system cannot compile a handler
    // for, and every handler of it is a qmllint warning (SettingsStore.qml
    // records the same choice). Diagnosis comes from stderr.
    Process {
        id: act
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                var m = String(this.text).trim();
                if (m !== "")
                    page.lastNote = m.split("\n")[0];
            }
        }
        onRunningChanged: if (!act.running) reprobe.restart()
    }

    function run(cmd) {
        if (act.running)
            return;
        page.lastNote = "";
        act.command = cmd;
        act.running = true;
    }

    // Screen reader. `setsid -f` double-forks so orca outlives this page
    // and this process. toolkit-accessibility is what at-spi-bus-launcher
    // reads to raise org.a11y.Status.IsEnabled — the flag Qt and GTK apps
    // check before they build an accessibility tree, which is why no
    // always-on env variable is set for the whole session (TRK-1222).
    function setOrca(on) {
        page.run(["sh", "-c",
            'if [ "$1" = on ]; then '
          + '  if command -v gsettings >/dev/null 2>&1; then gsettings set org.gnome.desktop.interface toolkit-accessibility true 2>/dev/null || true; fi; '
          + '  pgrep -x orca >/dev/null 2>&1 || setsid -f orca --replace >/dev/null 2>&1 </dev/null; '
          + 'else '
          + '  pkill -x orca 2>/dev/null || true; '
          + '  if command -v gsettings >/dev/null 2>&1; then gsettings set org.gnome.desktop.interface toolkit-accessibility false 2>/dev/null || true; fi; '
          + 'fi', "sh", on ? "on" : "off"]);
    }

    // On-screen keyboard. squeekboard rises on its own when a text field
    // takes focus (input-method-v2); "Show now" forces it up over its
    // sm.puri.OSK0 D-Bus name so the first tap has something to tap.
    function setOsk(on) {
        page.run(["sh", "-c",
            'if [ "$1" = on ]; then '
          + '  pgrep -x squeekboard >/dev/null 2>&1 || setsid -f squeekboard >/dev/null 2>&1 </dev/null; '
          + 'else '
          + '  pkill -x squeekboard 2>/dev/null || true; '
          + 'fi', "sh", on ? "on" : "off"]);
    }
    function showOsk() {
        page.run(["busctl", "--user", "call", "sm.puri.OSK0", "/sm/puri/OSK0",
                  "sm.puri.OSK0", "SetVisible", "b", "true"]);
    }

    // Magnifier: the skel script, by its skel path. Same file the keybinds
    // call, so this page and Super+Alt+scroll cannot disagree.
    function lens(verb) {
        page.run(["sh", "-c", 'exec "$HOME/.config/hypr/scripts/nyxus-lens.sh" "$1"',
                  "sh", verb]);
    }

    // ── apps follow the shell keys ───────────────────────────────────────
    // gsettings is the path GTK / libadwaita apps read (directly, or via
    // the gtk settings portal). Missing gsettings is a clean no-op, not an
    // error — a fresh ISO without gsettings-desktop-schemas (TRK-1204)
    // still gets the shell half of every switch.
    Process {
        id: gsApply
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                var m = String(this.text).trim();
                if (m !== "")
                    console.warn("Accessibility: " + m);
            }
        }
        onRunningChanged: {
            if (!gsApply.running && applyAgain.pending) {
                applyAgain.pending = false;
                page.applyApps();
            }
        }
    }
    Timer {
        id: applyAgain
        property bool pending: false
        interval: Theme.durBase
        repeat: false
        onTriggered: page.applyApps()
    }

    function applyApps() {
        if (gsApply.running) {
            applyAgain.pending = true;
            return;
        }
        gsApply.command = ["sh", "-c",
            'command -v gsettings >/dev/null 2>&1 || exit 0; '
          + 'gsettings set org.gnome.desktop.interface enable-animations "$1" 2>/dev/null || true; '
          + 'gsettings set org.gnome.desktop.interface text-scaling-factor "$2" 2>/dev/null || true; '
          + 'gsettings set org.gnome.desktop.a11y.interface high-contrast "$3" 2>/dev/null || true',
            "sh",
            page.reduced ? "false" : "true",
            String(page.textScale),
            page.contrast ? "true" : "false"];
        gsApply.running = true;
    }

    Connections {
        target: SettingsStore
        function onCommitted(keys) {
            for (var i = 0; i < keys.length; ++i) {
                var k = String(keys[i]);
                if (k === "reduced_motion" || k === "font_scale" || k === "high_contrast") {
                    page.applyApps();
                    return;
                }
            }
        }
    }

    // ── MOTION ───────────────────────────────────────────────────────────
    SetCard {
        heading: qsTr("Motion")
        tone: page.tone
        note: qsTr("Reduce motion stills the shell: no press sink or release bounce, ")
              + "Start and the flyout appear in place instead of growing from "
              + "their origin, toasts fade instead of rising, the nameplate and "
              + "glass drift hold still, the screensaver sky stops twinkling, the "
              + "pointer trail is off. Apps that read enable-animations follow."

        SetRow {
            glyph: ""
            title: qsTr("Reduce motion")
            sub: page.reduced ? qsTr("On — the shell holds still")
                              : "Off — springs, swirls, and origin grows are live"
            SetSwitch { key: "reduced_motion"; defaultValue: false; tone: page.tone }
        }
    }

    // ── TEXT ─────────────────────────────────────────────────────────────
    SetCard {
        heading: qsTr("Text")
        tone: page.tone
        note: qsTr("Reaches GTK and libadwaita apps through text-scaling-factor. ")
              + "The glass shell's own type ramp is a Theme token and does not "
              + "follow this yet (TRK-1224) — a pixel size here is still a pixel "
              + "size on the Line."

        SetRow {
            glyph: ""
            title: qsTr("Text size")
            sub: qsTr("Default 1.00 · Large 1.15 · Larger 1.30")
            SetChoice {
                key: "font_scale"
                defaultValue: 1.0
                tone: page.tone
                options: [
                    { value: 1.0,  label: qsTr("Default") },
                    { value: 1.15, label: qsTr("Large") },
                    { value: 1.3,  label: qsTr("Larger") }
                ]
            }
        }
    }

    // ── CONTRAST ─────────────────────────────────────────────────────────
    SetCard {
        heading: qsTr("Contrast")
        tone: page.tone
        note: qsTr("Writes high_contrast and the a11y high-contrast setting that ")
              + "libadwaita apps honour. The shell's glass keeps its own "
              + "contrast floors (gated) and does not switch skins on this yet — "
              + "Theme.qml is where that lands (TRK-1224)."

        SetRow {
            glyph: ""
            title: qsTr("High contrast")
            sub: page.contrast ? qsTr("On — apps that honour it switch")
                               : "Off"
            SetSwitch { key: "high_contrast"; defaultValue: false; tone: page.tone }
        }
    }

    // ── ASSISTIVE TOOLS ──────────────────────────────────────────────────
    SetCard {
        heading: qsTr("Assistive tools")
        tone: page.tone
        note: qsTr("These are the tools this machine actually has. Orca reads the ")
              + "screen aloud; squeekboard rises when a text field takes focus. "
              + "Both ship on the ISO; a dev checkout may lack them."

        SetRow {
            glyph: ""
            title: qsTr("Screen reader")
            sub: page.orcaBin !== ""
                 ? (page.orcaRunning ? "Orca is running" : "Orca is installed and stopped")
                 : ""
            available: page.orcaBin !== ""
            unavailableReason: page.probed ? qsTr("Unavailable")
                                           : qsTr("Looking…")
            SetSwitch {
                checked: page.orcaRunning
                enabled: page.orcaBin !== "" && !act.running
                tone: page.tone
                onToggled: function (v) { page.setOrca(v); }
            }
        }

        SetRow {
            glyph: ""
            title: qsTr("On-screen keyboard")
            sub: page.oskBin !== ""
                 ? (page.oskRunning ? "squeekboard is running — it shows when you tap into a text field"
                                    : "squeekboard is installed and stopped")
                 : ""
            available: page.oskBin !== ""
            unavailableReason: page.probed ? qsTr("Unavailable")
                                           : qsTr("Looking…")
            SetSwitch {
                checked: page.oskRunning
                enabled: page.oskBin !== "" && !act.running
                tone: page.tone
                onToggled: function (v) { page.setOsk(v); }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            visible: page.oskRunning
            SetButton {
                text: qsTr("Show keyboard now")
                glyph: ""
                tone: page.tone
                busy: act.running
                onClicked: page.showOsk()
            }
        }

        SetRow {
            visible: page.lastNote !== ""
            title: page.lastNote
        }
    }

    // ── MAGNIFIER ────────────────────────────────────────────────────────
    SetCard {
        heading: qsTr("Magnifier")
        tone: page.tone
        note: qsTr("The compositor's own zoom, following the pointer. Also ")
              + "Super+Alt+scroll, Super+Alt+= and Super+Alt+-; Super+Alt+middle-click "
              + "resets. No separate magnifier app is in the repositories this "
              + "image is built from."

        SetRow {
            glyph: ""
            title: qsTr("Zoom")
            valueText: page.zoom.toFixed(2) + "×"
            available: page.lensHere
            unavailableReason: page.probed ? qsTr("Unavailable")
                                           : qsTr("Looking…")
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            spacing: Theme.s3
            visible: page.lensHere
            SetButton {
                text: qsTr("Zoom in")
                glyph: ""
                tone: page.tone
                busy: act.running
                onClicked: page.lens("in")
            }
            SetButton {
                text: qsTr("Zoom out")
                glyph: ""
                tone: page.tone
                busy: act.running
                onClicked: page.lens("out")
            }
            SetButton {
                text: qsTr("Reset")
                glyph: ""
                tone: page.tone
                busy: act.running
                onClicked: page.lens("reset")
            }
        }
    }

    // ── KEYBOARD ONLY ────────────────────────────────────────────────────
    SetCard {
        heading: qsTr("Keyboard only")
        tone: page.tone
        note: qsTr("Every control in Settings is reachable without a pointer.")

        SetRow { title: qsTr("Tab / Shift+Tab — move between controls; Space or Enter flips a switch or presses a button; arrow keys nudge a slider") }
        SetRow { title: qsTr("Super+Space — Start · Super+Tab — Task view · Super+Return — terminal") }
        SetRow { title: qsTr("Super+Ctrl+Alt+L — lock · Super+Shift+E — power menu · Super+1…9 — workspaces") }
    }

    SetResetRow {
        what: "Access"
        keys: ["reduced_motion", "font_scale", "high_contrast"]
    }
}
