// Nyxus Suxyn — Settings ▸ System ▸ About this system.
//
// The engine's proof page. It exists to show that the scaffolding actually
// carries a real page end to end: a live backend, a card, rows, a value on the
// right, an action button, and a copy of the whole report.
//
// ── the backend ─────────────────────────────────────────────────────────
// Everything here comes from files and commands that exist on any Arch
// machine, read ONCE when the page opens and again only when asked:
//
//   /etc/os-release            edition, build id and version stamp
//   uname -r / -m              kernel and architecture
//   /proc/cpuinfo              CPU model and core count
//   /proc/meminfo              installed memory
//   /proc/uptime               uptime
//   hostnamectl                chassis and hardware vendor/model
//   lspci                      graphics adapters
//   $XDG_SESSION_TYPE, $XDG_CURRENT_DESKTOP, $WAYLAND_DISPLAY
//   hyprctl version            compositor build
//   qs --version               shell build
//
// ONE `Process`, not eleven. The `hyprlock` lesson in `HANDOFF.md` is that
// subprocess-per-field starves the event loop; the rule that came out of it is
// that a panel gathers on open, in one shot, and never on a short timer. This
// page has no timer at all — uptime is stamped "as of" the read, which is
// honest, rather than counting up and pretending it is live.
//
// Nothing here writes. About is a report, and a report with a settings control
// in it is how someone changes their hostname while trying to read it.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page

    // Handed in by the window's Loader. Declared here rather than in
    // `SetPage.qml` because it is the loader's contract with a PAGE, not part
    // of what a page scaffold is.
    property var entry: null

    title: qsTr("About this system")
    blurb: qsTr("Nyxus Suxyn — this machine, this installation, Horizon glass, ice accent.")

    // ── the report ──────────────────────────────────────────────────────
    // One flat map, filled by the collector below. Every row binds to a key
    // and shows `unknownText` until the collector answers — never an empty
    // string, because a blank value on the right of a row reads as a failure
    // rather than as "still reading".
    property var facts: ({})
    property bool collected: false
    readonly property string unknownText: "—"

    function fact(k) {
        var v = page.facts[k];
        return (v === undefined || v === null || v === "") ? page.unknownText : String(v);
    }

    // ── the collector ───────────────────────────────────────────────────
    // A single `sh -c` emitting `key\tvalue` lines. Tab-separated because a
    // value can contain anything — a GPU model has colons and commas in it —
    // and a tab is the one character none of these fields carry.
    //
    // Every lookup is guarded: a machine with no `lspci`, no battery, or no
    // `hyprctl` on PATH must still produce a complete report with the missing
    // line simply absent, not a shell error on stderr and a half-empty page.
    Process {
        id: collector
        running: false
        command: ["sh", "-c", `
            emit() { printf '%s\t%s\n' "$1" "$2"; }

            if [ -r /etc/os-release ]; then
              . /etc/os-release 2>/dev/null
              emit edition   "\${PRETTY_NAME:-\$NAME}"
              emit osversion "\${VERSION_ID:-rolling}"
              emit buildid   "\${BUILD_ID:-unstamped}"
            fi

            emit kernel "$(uname -r 2>/dev/null)"
            emit arch   "$(uname -m 2>/dev/null)"
            emit host   "$(uname -n 2>/dev/null)"

            if [ -r /proc/cpuinfo ]; then
              emit cpu "$(awk -F': ' '/^model name/{print $2; exit}' /proc/cpuinfo)"
              emit cores "$(awk '/^processor/{n++} END{print n+0}' /proc/cpuinfo) threads"
            fi

            if [ -r /proc/meminfo ]; then
              emit memory "$(awk '/^MemTotal:/{printf "%.1f GiB", $2/1048576}' /proc/meminfo)"
              emit memfree "$(awk '/^MemAvailable:/{printf "%.1f GiB available", $2/1048576}' /proc/meminfo)"
            fi

            if [ -r /proc/uptime ]; then
              emit uptime "$(awk '{d=int($1/86400); h=int(($1%86400)/3600); m=int(($1%3600)/60);
                                   if (d>0) printf "%dd %dh %dm", d, h, m;
                                   else if (h>0) printf "%dh %dm", h, m;
                                   else printf "%dm", m}' /proc/uptime)"
            fi

            if command -v hostnamectl >/dev/null 2>&1; then
              emit vendor  "$(hostnamectl --json=short 2>/dev/null | sed -n 's/.*"HardwareVendor":"\\([^"]*\\)".*/\\1/p')"
              emit model   "$(hostnamectl --json=short 2>/dev/null | sed -n 's/.*"HardwareModel":"\\([^"]*\\)".*/\\1/p')"
              emit chassis "$(hostnamectl --json=short 2>/dev/null | sed -n 's/.*"Chassis":"\\([^"]*\\)".*/\\1/p')"
            fi

            if command -v lspci >/dev/null 2>&1; then
              emit gpu "$(lspci 2>/dev/null | grep -iE 'vga|3d controller' \\
                          | sed 's/^[^ ]* //; s/^[^:]*: //' | paste -sd' · ' -)"
            fi

            emit session   "\${XDG_SESSION_TYPE:-unknown}"
            emit desktop   "\${XDG_CURRENT_DESKTOP:-unknown}"
            emit wayland   "\${WAYLAND_DISPLAY:-none}"

            if command -v hyprctl >/dev/null 2>&1; then
              emit compositor "$(hyprctl version 2>/dev/null | awk 'NR==1{print}' \\
                                 | sed 's/^Hyprland //; s/ built.*//')"
            fi
            if command -v qs >/dev/null 2>&1; then
              emit shell "$(qs --version 2>/dev/null | head -n1)"
            fi

            if [ -r /sys/firmware/efi ] || [ -d /sys/firmware/efi ]; then
              emit firmware "UEFI"
            else
              emit firmware "BIOS / legacy"
            fi
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                var next = {};
                var lines = String(this.text).split("\n");
                for (var i = 0; i < lines.length; ++i) {
                    var line = lines[i];
                    if (line.length === 0)
                        continue;
                    var tab = line.indexOf("\t");
                    if (tab <= 0)
                        continue;
                    var v = line.substring(tab + 1).trim();
                    if (v !== "")
                        next[line.substring(0, tab)] = v;
                }
                page.facts = next;
                page.collected = true;
                page.stampedAt = Qt.formatDateTime(new Date(), "HH:mm:ss");
            }
        }

        // stderr is deliberately not swallowed into the page. A tool that is
        // missing already shows as an absent row; anything else is a genuine
        // problem and belongs where a developer will see it.
        stderr: StdioCollector {
            onStreamFinished: {
                if (String(this.text).trim() !== "")
                    console.warn("About: collector stderr: " + this.text);
            }
        }
    }

    property string stampedAt: ""

    // Gather when the page is constructed — which, because the window's Loader
    // builds a page on selection and destroys it on the next, means "every
    // time you open About" and never while you are somewhere else.
    Component.onCompleted: collector.running = true

    // ── the report, as text ─────────────────────────────────────────────
    // Built from the same map the rows show, so what lands on the clipboard is
    // exactly what is on screen. A support paste that disagrees with the
    // window is worse than no button.
    function reportText() {
        var order = [
            ["Edition",     "edition"],   ["Build",       "buildid"],
            ["Kernel",      "kernel"],    ["Architecture", "arch"],
            ["Hostname",    "host"],      ["Firmware",    "firmware"],
            ["Vendor",      "vendor"],    ["Model",       "model"],
            ["CPU",         "cpu"],       ["Threads",     "cores"],
            ["Memory",      "memory"],    ["Graphics",    "gpu"],
            ["Session",     "session"],   ["Desktop",     "desktop"],
            ["Compositor",  "compositor"],["Shell",       "shell"],
            ["Uptime",      "uptime"]
        ];
        var out = "Nyxus Suxyn — system report\n";
        for (var i = 0; i < order.length; ++i)
            out += order[i][0] + ": " + page.fact(order[i][1]) + "\n";
        return out;
    }

    Process { id: copyProc; running: false }

    // ══ the page ═══════════════════════════════════════════════════════
    // The certificate is the object. Model / CPU / RAM as a labelled
    // spreadsheet was the leftover form. Copy still dumps the same map.

    SetCard {
        heading: qsTr("This machine")
        tone: page.tone
        note: qsTr("Nyxus Suxyn. Horizon layout, Nyxus Glass, glacier/ice accent. ")
              + "Suxyn is the edition name on this stamp."

        SetRow {
            title: page.fact("edition") === page.unknownText
                   ? qsTr("Nyxus Suxyn") : page.fact("edition")
            sub: page.fact("vendor") === page.unknownText
                 ? page.fact("model")
                 : (page.fact("vendor") + " " + page.fact("model"))
            valueText: page.fact("host")
        }

        SetRow {
            title: qsTr("Hardware")
            sub: [
                     page.fact("cpu"),
                     page.fact("memory"),
                     page.fact("gpu"),
                     page.fact("firmware")
                 ].filter(function (s) {
                     return s && s !== page.unknownText;
                 }).join(" · ")
        }

        SetRow {
            glyph: "\uf013"
            title: qsTr("Kernel")
            sub: page.fact("arch")
            valueText: page.fact("kernel")
        }

        SetRow {
            glyph: "\uf02e"
            title: qsTr("Build")
            sub: page.stampedAt === "" ? "" : qsTr("as of ") + page.stampedAt
            valueText: page.fact("buildid")
        }

        SetRow {
            glyph: "\uf017"
            title: qsTr("Up for")
            valueText: page.fact("uptime")
        }
    }

    SetCard {
        heading: qsTr("The desktop")
        tone: page.tone

        SetRow {
            glyph: "\uf53f"
            title: qsTr("Look")
            sub: qsTr("Horizon layout, Nyxus Glass, glacier/ice chrome")
            valueText: qsTr("Nyxus Suxyn")
        }

        SetRow {
            glyph: "\uf108"
            title: qsTr("Session")
            valueText: page.fact("session") + " · " + page.fact("desktop")
        }

        SetRow {
            glyph: "\uf009"
            title: qsTr("Compositor")
            sub: qsTr("Hyprland — windows, workspaces, input and the border")
            valueText: page.fact("compositor")
        }

        SetRow {
            glyph: "\uf120"
            title: qsTr("Shell")
            sub: qsTr("Quickshell — the taskbar, Start menu, panels and this window")
            valueText: page.fact("shell")
        }

        SetRow {
            glyph: "\uf26c"
            title: qsTr("Wayland display")
            valueText: page.fact("wayland")
        }
    }

    SetCard {
        heading: qsTr("Report")
        tone: page.tone
        note: qsTr("The copy goes to the Wayland clipboard through wl-copy, which is ")
              + "what every other copy button in this build uses."

        SetRow {
            glyph: "\uf0c5"
            title: qsTr("Copy system report")
            sub: qsTr("Everything on this page, as plain text, for a support message")

            SetButton {
                text: qsTr("Copy")
                glyph: "\uf0c5"
                tone: page.tone
                enabled: page.collected
                onClicked: {
                    copyProc.command = ["wl-copy", "--", page.reportText()];
                    copyProc.running = true;
                }
            }
        }

        // TRK-1233: the door to the doctor. About is a report; Health is the
        // check. Same deep-link every other cross-page row uses.
        SetRow {
            glyph: "\uf21e"
            title: qsTr("Check this system")
            sub: qsTr("nyxus doctor — portals, keyring, polkit, audio, network, disk, units — and the off switches")
            navigates: true
            onActivated: Bus.openSettings("health")
        }

        SetRow {
            glyph: "\uf021"
            title: qsTr("Read the system again")
            sub: page.stampedAt === ""
                 ? "Reading…"
                 : "Last read at " + page.stampedAt + ". Nothing here polls."

            SetButton {
                text: qsTr("Refresh")
                glyph: "\uf021"
                tone: page.tone
                busy: collector.running
                onClicked: collector.running = true
            }
        }
    }
}
