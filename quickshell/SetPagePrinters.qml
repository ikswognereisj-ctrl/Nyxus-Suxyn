pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ Devices ▸ Printers & scanners.   MODULE 4.
//
// ── the backend ─────────────────────────────────────────────────────────
// CUPS, through its own command-line clients, which are the supported API and
// are shipped with the `cups` package this build already installs:
//
//   lpstat -p -d        every printer, its state, and which is default
//   lpstat -o           the queue — every job, on every printer
//   lpstat -e           destinations CUPS knows about, including discovered
//   lpinfo -v           devices attached or visible on the network
//   lpadmin             add a printer, set the default
//   cupsenable/disable  resume and pause a printer
//   cancel              one job, or all of a printer's jobs
//   lp                  print the test page
//   ipptool             ink and toner levels, where the printer reports them
//
// **One gather process, not eight.** Everything above that only READS runs in a
// single `sh -c` that emits typed, tab-separated records, and the page parses
// one stream. Eight subprocesses per refresh is the shape of the hyprlock
// failure recorded in `HANDOFF.md`; and a queue that is read by one process and
// a printer list read by another can disagree about which printer a job is on.
//
// **Nothing polls.** The gather runs when the page opens and after any action
// that could change the answer.
//
// Ice plates, not printer/queue/ink spreadsheet rows. Magma only Clear queue
// and Cancel (jobs go). Pause / default / test / add stay ice.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    property var entry: null

    title: qsTr("Printers & scanners")
    blurb: qsTr("Add a printer, watch what is printing, and check what it has left.")

    property var printers: []
    property var jobs: []
    property var candidates: []
    property var markers: []
    property bool gathered: false
    property bool cupsUp: true
    property string defaultPrinter: ""
    property string lastError: ""

    property string focusPrinter: ""
    readonly property string subject: page.focusPrinter !== ""
                                      ? page.focusPrinter : page.defaultPrinter

    // ── audit-0908 · TRK-3975 · read the printer, not the store ─────────
    //
    // These three were `SettingsStore.stringValue("print_paper", …)` and so
    // on: ONE global value each, for a control whose write is per-printer
    // (`lpoptions -p <subject> -o media=…`). Nothing anywhere in the tree
    // reads those keys back — a grep for `print_paper` across the shell,
    // /usr/local/bin and ~/.config/hypr on the owner's machine finds only
    // this file writing it — so the card showed the LAST CHOICE MADE ON ANY
    // PRINTER while writing to whichever printer happened to be focused.
    // Focus a second printer and the highlighted paper size does not change,
    // but the machine it applies to does.
    //
    // CUPS already stores this correctly, per queue, in the user's own
    // `~/.cups/lpoptions`, and `lpoptions -p <queue>` prints it back. So CUPS
    // is the source of truth now and this page reads it, which makes the card
    // per-printer in the same motion — the highlighted segment is what THAT
    // printer will do, because it was read off that printer.
    //
    // Nothing is selected until the read-back lands. A default of "Letter"
    // when we have not looked yet is the same lie as a static "Automatic" was
    // on the fan control: it claims to report a machine we have not asked.
    property string paper: ""
    property int duplexState: -1          // -1 unknown, 0 one-sided, 1 two-sided
    property string quality: ""
    readonly property bool duplex: page.duplexState === 1
    property bool optionsRead: false

    Component.onCompleted: page.gather()

    // Re-read whenever the card's subject changes — that is exactly the case
    // the old code got wrong.
    onSubjectChanged: page.readOptions()

    function readOptions() {
        page.optionsRead = false;
        page.paper = "";
        page.quality = "";
        page.duplexState = -1;
        if (page.subject === "" || optionsProc.running)
            return;
        optionsProc.command = ["lpoptions", "-p", page.subject];
        optionsProc.running = true;
    }

    // `lpoptions -p X` prints one line of `key=value` pairs, values sometimes
    // quoted. Only the three this card owns are read; everything else on the
    // queue is left alone, because this page did not set it and must not
    // pretend to own it.
    Process {
        id: optionsProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var t = String(this.text);
                function opt(name) {
                    var m = t.match(new RegExp("(?:^|\\s)" + name
                                               + "=(?:'([^']*)'|\"([^\"]*)\"|(\\S+))"));
                    if (!m)
                        return "";
                    return String(m[1] !== undefined ? m[1]
                                  : (m[2] !== undefined ? m[2] : m[3]));
                }
                var media = opt("media");
                // CUPS spells the sizes na_letter_8.5x11in / iso_a4_… as well
                // as the plain names, depending on the driver.
                page.paper = /a4/i.test(media) ? "A4"
                           : (/legal/i.test(media) ? "Legal"
                              : (/letter/i.test(media) ? "Letter" : ""));
                var sides = opt("sides");
                page.duplexState = sides === "" ? -1
                                 : (sides.indexOf("two-sided") === 0 ? 1 : 0);
                var q = opt("print-quality");
                page.quality = /^[345]$/.test(q) ? q : "";
                page.optionsRead = true;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                var m = String(this.text).trim();
                if (m !== "")
                    console.warn("Printers: lpoptions — " + m);
            }
        }
    }

    function gather() { if (!collector.running) collector.running = true; }

    Process {
        id: collector
        running: false
        command: ["sh", "-c", `
            if ! command -v lpstat >/dev/null 2>&1; then
              printf 'X\tnocups\n'; exit 0
            fi
            if ! lpstat -r >/dev/null 2>&1; then
              printf 'X\tnotrunning\n'; exit 0
            fi

            # default destination
            def=$(lpstat -d 2>/dev/null | sed -n 's/^system default destination: //p')
            printf 'F\t%s\n' "$def"

            # printers: name, state word, and the reason line CUPS gives
            lpstat -p 2>/dev/null | while IFS= read -r line; do
              case "$line" in
                printer\\ *)
                  name=$(printf '%s' "$line" | awk '{print $2}')
                  if printf '%s' "$line" | grep -q 'is idle'; then st=idle
                  elif printf '%s' "$line" | grep -q 'now printing'; then st=printing
                  elif printf '%s' "$line" | grep -q 'disabled'; then st=paused
                  else st=unknown; fi
                  why=$(printf '%s' "$line" | sed -n 's/.* - //p')
                  info=$(lpstat -l -p "$name" 2>/dev/null | sed -n 's/^\\s*Description: //p' | head -n1)
                  loc=$(lpstat -l -p "$name" 2>/dev/null | sed -n 's/^\\s*Location: //p' | head -n1)
                  acc=$(lpstat -a "$name" 2>/dev/null | grep -c 'accepting requests')
                  printf 'P\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$st" "$why" "$info" "$loc" "$acc"
                  ;;
              esac
            done

            # the queue
            lpstat -o 2>/dev/null | while IFS= read -r j; do
              id=$(printf '%s' "$j" | awk '{print $1}')
              usr=$(printf '%s' "$j" | awk '{print $2}')
              sz=$(printf '%s' "$j" | awk '{print $3}')
              when=$(printf '%s' "$j" | cut -d' ' -f4- | sed 's/^ *//')
              pr=$(printf '%s' "$id" | sed 's/-[0-9]*$//')
              printf 'J\t%s\t%s\t%s\t%s\t%s\n' "$id" "$pr" "$usr" "$sz" "$when"
            done

            # devices we could add that are not set up yet
            if command -v lpinfo >/dev/null 2>&1; then
              existing=$(lpstat -v 2>/dev/null | sed -n 's/.*: //p')
              lpinfo -v 2>/dev/null | while IFS= read -r d; do
                cls=$(printf '%s' "$d" | awk '{print $1}')
                uri=$(printf '%s' "$d" | cut -d' ' -f2-)
                case "$cls" in direct|network) ;; *) continue;; esac
                case "$uri" in *"://"*) ;; *) continue;; esac
                printf '%s\n' "$existing" | grep -qxF "$uri" && continue
                printf 'D\t%s\t%s\n' "$uri" "$cls"
              done
            fi

            # ink / toner for the default destination, when it reports any
            if [ -n "$def" ] && command -v ipptool >/dev/null 2>&1 \\
               && [ -r /usr/share/cups/ipptool/get-printer-attributes.test ]; then
              ipptool -tv "ipp://localhost/printers/$def" \\
                      /usr/share/cups/ipptool/get-printer-attributes.test 2>/dev/null \\
              | awk '
                  /marker-names/ { sub(/^[^=]*= */, ""); names=$0 }
                  /marker-levels/ { sub(/^[^=]*= */, ""); levels=$0 }
                  END {
                    if (names == "" || levels == "") exit
                    n=split(names, N, ","); l=split(levels, L, ",")
                    for (i=1; i<=n && i<=l; i++) {
                      gsub(/^ +| +$/, "", N[i]); gsub(/^ +| +$/, "", L[i])
                      printf "M\\t%s\\t%s\\n", N[i], L[i]
                    }
                  }'
            fi
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                var P = [], J = [], D = [], M = [];
                var def = "";
                var up = true;
                var lines = String(this.text).split("\n");

                for (var i = 0; i < lines.length; ++i) {
                    var f = lines[i].split("\t");
                    if (f.length < 2)
                        continue;
                    switch (f[0]) {
                    case "X":
                        up = false;
                        page.lastError = f[1] === "nocups"
                            ? "The CUPS client tools are not installed."
                            : "The CUPS service is not running.";
                        break;
                    case "F":
                        def = (f[1] || "").trim();
                        break;
                    case "P":
                        P.push({ name: f[1], state: f[2], why: (f[3] || "").trim(),
                                 info: (f[4] || "").trim(), location: (f[5] || "").trim(),
                                 accepting: String(f[6]).trim() !== "0" });
                        break;
                    case "J":
                        J.push({ id: f[1], printer: f[2], user: f[3],
                                 size: f[4], when: (f[5] || "").trim() });
                        break;
                    case "D":
                        D.push({ uri: f[1], kind: (f[2] || "").trim() });
                        break;
                    case "M":
                        var lv = parseInt(f[2], 10);
                        M.push({ name: f[1], level: isNaN(lv) ? -1 : lv });
                        break;
                    }
                }

                page.cupsUp = up;
                if (up)
                    page.lastError = "";
                page.defaultPrinter = def;
                page.printers = P;
                page.jobs = J;
                page.candidates = D;
                page.markers = M;
                page.gathered = true;
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                var m = String(this.text).trim();
                if (m !== "")
                    console.warn("Printers: gather — " + m);
            }
        }
    }

    property string busyTag: ""

    Process {
        id: actor
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                var m = String(this.text).trim();
                if (m !== "") {
                    page.lastError = m;
                    console.warn("Printers: " + m);
                }
            }
        }
        onRunningChanged: {
            if (actor.running)
                return;
            page.busyTag = "";
            page.gather();
            // TRK-3975: read the queue back after every action. `lpoptions`
            // is what these controls write to, so it is what says whether the
            // write landed — the card must never show a value only because
            // this page believes it wrote it.
            page.readOptions();
        }
    }

    function act(tag, argv) {
        if (actor.running)
            return;
        page.lastError = "";
        page.busyTag = tag;
        actor.command = argv;
        actor.running = true;
    }

    function stateText(p) {
        if (!p.accepting)
            return "Not accepting jobs";
        switch (p.state) {
        case "idle":     return "Ready";
        case "printing": return "Printing";
        case "paused":   return p.why !== "" ? "Paused · " + p.why : "Paused";
        default:         return p.why !== "" ? p.why : "Unknown";
        }
    }

    function jobsFor(name) {
        return page.jobs.filter(function (j) { return j.printer === name; });
    }

    // ══ PRINTERS ═══════════════════════════════════════════════════════
    SetCard {
        heading: qsTr("Printers")
        tone: page.tone
        note: page.lastError !== "" ? page.lastError : ""

        SetIceFace {
            visible: !page.cupsUp
            kicker: "CUPS"
            caption: qsTr("Printing service is not available")
            detail: qsTr("CUPS is what discovers printers and holds the queue. Without it ")
                    + "nothing on this page can work."
        }

        SetIceFace {
            visible: page.cupsUp && page.gathered && page.printers.length === 0
            compact: true
            kicker: qsTr("PRINTERS")
            caption: qsTr("No printer is set up yet")
            detail: qsTr("Anything found on the network or over USB is listed under Add a printer below.")
        }

        Repeater {
            model: page.printers

            delegate: ColumnLayout {
                id: pr
                required property var modelData
                readonly property bool isDefault: modelData.name === page.defaultPrinter
                readonly property int queued: page.jobsFor(modelData.name).length
                Layout.fillWidth: true
                spacing: Theme.s2

                SetIceFace {
                    Layout.fillWidth: true
                    kicker: pr.isDefault ? "DEFAULT" : (pr.modelData.state === "printing" ? qsTr("PRINTING") : qsTr("PRINTER"))
                    reading: pr.queued > 0 ? String(pr.queued) : ""
                    caption: pr.modelData.info !== "" ? pr.modelData.info : pr.modelData.name
                    detail: {
                        var bits = [page.stateText(pr.modelData)];
                        if (pr.modelData.location !== "")
                            bits.push(pr.modelData.location);
                        if (pr.queued > 0)
                            bits.push(pr.queued === 1 ? "1 job waiting" : pr.queued + " jobs waiting");
                        return bits.join(" · ");
                    }
                    selected: pr.modelData.name === page.subject
                    interactive: true
                    onActivated: page.focusPrinter = pr.modelData.name
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.s4
                    Layout.rightMargin: Theme.s4
                    spacing: Theme.s4

                    SetButton {
                        text: pr.modelData.state === "paused" ? qsTr("Resume") : qsTr("Pause")
                        glyph: ""
                        tone: page.tone
                        busy: page.busyTag === "pause-" + pr.modelData.name
                        onClicked: page.act("pause-" + pr.modelData.name,
                            [pr.modelData.state === "paused" ? "cupsenable" : "cupsdisable",
                             pr.modelData.name])
                    }

                    SetButton {
                        text: qsTr("Make default")
                        glyph: ""
                        tone: page.tone
                        enabled: !pr.isDefault
                        busy: page.busyTag === "def-" + pr.modelData.name
                        onClicked: page.act("def-" + pr.modelData.name,
                                            ["lpoptions", "-d", pr.modelData.name])
                    }

                    SetButton {
                        text: qsTr("Test page")
                        glyph: ""
                        tone: page.tone
                        busy: page.busyTag === "test-" + pr.modelData.name
                        onClicked: page.act("test-" + pr.modelData.name, ["sh", "-c",
                            'for f in /usr/share/cups/data/testprint '
                          + '/usr/share/cups/data/testprint.ps; do '
                          + '[ -r "$f" ] && exec lp -d "$1" "$f"; done; '
                          + 'echo "CUPS test page not found on this system" >&2; exit 1',
                            "sh", pr.modelData.name])
                    }
                }
            }
        }
    }

    // ══ THE QUEUE ══════════════════════════════════════════════════════
    SetCard {
        heading: qsTr("Queue")
        tone: page.tone
        note: qsTr("Cancelling a job cannot un-print pages the printer has already ")
              + "started. Anything still in its own memory finishes."

        SetIceFace {
            visible: page.jobs.length === 0
            compact: true
            kicker: qsTr("QUEUE")
            caption: page.gathered ? qsTr("Nothing is waiting") : qsTr("Reading the queue…")
            detail: page.gathered ? qsTr("The queue is empty on every printer.") : ""
        }

        Repeater {
            model: page.jobs

            delegate: ColumnLayout {
                id: jb
                required property var modelData
                Layout.fillWidth: true
                spacing: Theme.s2

                SetIceFace {
                    Layout.fillWidth: true
                    compact: true
                    kicker: qsTr("JOB")
                    caption: jb.modelData.id
                    detail: jb.modelData.user + " · " + jb.modelData.size
                            + (jb.modelData.when !== "" ? " · " + jb.modelData.when : "")
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.s4
                    Layout.rightMargin: Theme.s4

                    SetButton {
                        text: qsTr("Cancel")
                        glyph: ""
                        danger: true
                        confirmText: "Cancel " + jb.modelData.id
                        tone: page.tone
                        busy: page.busyTag === "cancel-" + jb.modelData.id
                        onClicked: page.act("cancel-" + jb.modelData.id,
                                            ["cancel", jb.modelData.id])
                    }
                }
            }
        }

        SetIceFace {
            visible: page.jobs.length > 0
            compact: true
            kicker: qsTr("CLEAR QUEUE")
            caption: qsTr("Cancels every job on every printer, including other people's")
        }

        RowLayout {
            visible: page.jobs.length > 0
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4

            SetButton {
                text: qsTr("Clear queue")
                glyph: ""
                danger: true
                confirmText: page.jobs.length === 1
                             ? "Cancel 1 job" : "Cancel " + page.jobs.length + " jobs"
                busy: page.busyTag === "clear"
                onClicked: page.act("clear", ["cancel", "-a"])
            }
        }
    }

    // ══ SUPPLIES ═══════════════════════════════════════════════════════
    SetCard {
        heading: qsTr("Ink & toner")
        tone: page.tone
        visible: page.subject !== ""
        note: page.subject !== ""
              ? "Reported by " + page.subject + " over IPP. Printers that do not "
                + "publish levels show nothing here rather than a guess."
              : ""

        SetIceFace {
            visible: page.markers.length === 0
            compact: true
            kicker: qsTr("SUPPLIES")
            caption: qsTr("This printer does not report its levels")
            detail: qsTr("Most USB inkjets do not. Network printers usually do, and the ")
                    + "figure comes straight from the printer."
        }

        Repeater {
            model: page.markers

            delegate: SetIceFace {
                required property var modelData
                kicker: qsTr("INK")
                reading: modelData.level >= 0 ? modelData.level + "%" : "—"
                caption: modelData.name
                detail: modelData.level < 0 ? qsTr("Reported, but not as a percentage")
                      : modelData.level <= 10 ? "Low — worth ordering a replacement"
                      : ""
                fillPct: modelData.level >= 0 ? modelData.level : -1
            }
        }
    }

    // ══ ADD ════════════════════════════════════════════════════════════
    SetCard {
        heading: qsTr("Add a printer")
        tone: page.tone
        note: qsTr("Added with the driverless IPP Everywhere profile, which is what ")
              + "modern printers speak. No driver is downloaded and nothing is "
              + "fetched from the internet."

        SetIceFace {
            visible: page.candidates.length === 0
            compact: true
            kicker: page.gathered ? qsTr("NONE NEW") : qsTr("LOOKING")
            caption: page.gathered ? qsTr("Nothing new found") : qsTr("Looking…")
            detail: page.gathered
                    ? "Everything CUPS can see is already set up. Network printers "
                      + "must be switched on and on the same network to be found."
                    : ""
        }

        Repeater {
            model: page.candidates

            delegate: ColumnLayout {
                id: cand
                required property var modelData
                readonly property string shortName: {
                    var u = String(cand.modelData.uri);
                    var tail = u.split("/").pop().split("?")[0];
                    if (tail === "")
                        tail = u.replace(/^[a-z]+:\/\//, "").split("/")[0];
                    return tail.replace(/%20/g, " ");
                }
                readonly property string queueName:
                    cand.shortName.replace(/[^A-Za-z0-9_-]/g, "_").slice(0, 40)
                Layout.fillWidth: true
                spacing: Theme.s2

                SetIceFace {
                    Layout.fillWidth: true
                    compact: true
                    kicker: cand.modelData.kind === "direct" ? "USB" : qsTr("NETWORK")
                    caption: cand.shortName
                    detail: cand.modelData.uri
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.s4
                    Layout.rightMargin: Theme.s4

                    SetButton {
                        text: qsTr("Add")
                        glyph: ""
                        tone: page.tone
                        busy: page.busyTag === "add-" + cand.queueName
                        onClicked: page.act("add-" + cand.queueName,
                            ["lpadmin", "-p", cand.queueName, "-E",
                             "-v", cand.modelData.uri, "-m", "everywhere"])
                    }
                }
            }
        }

        SetIceFace {
            compact: true
            kicker: qsTr("LOOK AGAIN")
            caption: qsTr("Re-reads the printers, the queue and the network")
            interactive: true
            // TRK-1781: discovering is BUSY, not switched on.
            attention: collector.running
            onActivated: page.gather()
        }
    }

    // ══ DEFAULTS ═══════════════════════════════════════════════════════
    SetCard {
        heading: qsTr("Printing defaults")
        tone: page.tone
        visible: page.subject !== ""
        // The note names the printer these apply to AND says the values were
        // read off it, because the previous version of this card could show
        // one printer's settings over another printer's name (TRK-3975).
        // Until the read-back lands nothing is highlighted and the note says
        // why, rather than the card defaulting to Letter on a machine nobody
        // has asked yet.
        note: page.subject === ""
              ? ""
              : (page.optionsRead
                 ? "Read from " + page.subject + " just now, and applied to it "
                   + "for every job that does not ask for something else. "
                   + "Stored by CUPS in your own lpoptions."
                 : "Reading what " + page.subject + " is currently set to…")

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s3

            SetIceFace {
                property string key: "print_paper"; property string defaultValue: "Letter"
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("LETTER")
                selected: page.paper === "Letter"
                interactive: true
                onActivated: {
                    SettingsStore.setValue("print_paper", "Letter");
                    page.act("paper", ["lpoptions", "-p", page.subject, "-o", "media=Letter"]);
                }
            }
            SetIceFace {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: "A4"
                selected: page.paper === "A4"
                interactive: true
                onActivated: {
                    SettingsStore.setValue("print_paper", "A4");
                    page.act("paper", ["lpoptions", "-p", page.subject, "-o", "media=A4"]);
                }
            }
            SetIceFace {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("LEGAL")
                selected: page.paper === "Legal"
                interactive: true
                onActivated: {
                    SettingsStore.setValue("print_paper", "Legal");
                    page.act("paper", ["lpoptions", "-p", page.subject, "-o", "media=Legal"]);
                }
            }
        }

        SetIceFace {
            property string key: "print_duplex"; property bool defaultValue: false
            compact: true
            kicker: qsTr("BOTH SIDES")
            // Three states, not two: -1 is "this queue has not been asked
            // yet", which is not the same as OFF (TRK-3975).
            reading: page.duplexState < 0 ? qsTr("—")
                     : (page.duplex ? qsTr("ON") : qsTr("OFF"))
            caption: page.duplexState < 0
                     ? qsTr("Reading this printer's setting…")
                     : qsTr("Only takes effect on printers that can do it")
            selected: page.duplex
            interactive: true
            onActivated: {
                var next = !page.duplex;
                SettingsStore.setValue("print_duplex", next);
                page.act("duplex", ["lpoptions", "-p", page.subject, "-o",
                                    "sides=" + (next ? "two-sided-long-edge" : "one-sided")]);
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s3

            SetIceFace {
                property string key: "print_quality"; property string defaultValue: "4"
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("DRAFT")
                selected: page.quality === "3"
                interactive: true
                onActivated: {
                    SettingsStore.setValue("print_quality", "3");
                    page.act("quality", ["lpoptions", "-p", page.subject, "-o",
                                         "print-quality=3"]);
                }
            }
            SetIceFace {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("NORMAL")
                selected: page.quality === "4"
                interactive: true
                onActivated: {
                    SettingsStore.setValue("print_quality", "4");
                    page.act("quality", ["lpoptions", "-p", page.subject, "-o",
                                         "print-quality=4"]);
                }
            }
            SetIceFace {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("BEST")
                selected: page.quality === "5"
                interactive: true
                onActivated: {
                    SettingsStore.setValue("print_quality", "5");
                    page.act("quality", ["lpoptions", "-p", page.subject, "-o",
                                         "print-quality=5"]);
                }
            }
        }
    }

    SetCard {
        heading: qsTr("Also on this machine")
        tone: page.tone
        note: qsTr("Wi-Fi, Bluetooth, sound, displays — the same Devices story.")

        SetRow {
            title: qsTr("Wi-Fi")
            sub: qsTr("Scan, join, forget")
            navigates: true
            onActivated: Bus.openSettings("network")
        }
        SetRow {
            title: qsTr("Bluetooth")
            navigates: true
            onActivated: Bus.openSettings("bluetooth")
        }
        SetRow {
            title: qsTr("Sound")
            sub: qsTr("Default output — tap a stone, no terminal")
            navigates: true
            onActivated: Bus.openSettings("sound")
        }
        SetRow {
            title: qsTr("Display")
            sub: qsTr("Monitors and Night Light")
            navigates: true
            onActivated: Bus.openSettings("display")
        }
    }
}
