pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ Personalization ▸ Appearance.
// Writes settings.json keys Prefs.qml already reads. Does not edit Swirl.qml
// or shaders (BQ). launcher_style is Start; living-paint toggles are the
// keys the bar already honours.
//
// Ice stones, not a labelled spreadsheet. Four-chip colour-layer picker
// stays retired — no swirl_layer, no rose/magma/violet chips.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    property var entry: null
    title: qsTr("Appearance")
    blurb: qsTr("Bar swirls, hover, the music visualizer, lyrics, and the player card.")

    readonly property bool paintOn: SettingsStore.boolValue("swirl_enabled", true)
    readonly property string motion: SettingsStore.stringValue("swirl_motion", "ambient")
    readonly property bool musicOn: SettingsStore.boolValue("swirl_music", true)
    // TRK-3711 · default MUST match Prefs.qml's adapter (true), the standing
    // rule on this page: the page and the shell are two readers of one file,
    // and a disagreeing default reads OFF here while the bar turns over.
    readonly property bool spectrumOn: SettingsStore.boolValue("bar_spectrum", true)
    readonly property bool mediaPop: SettingsStore.boolValue("media_bar_pop", true)
    // TRK-3812 · SYNCED LYRICS. Default MUST match Prefs.qml's adapter
    // (false), the standing rule at the top of this file — and here it is
    // more than a display bug: a page that read ON while the shell read OFF
    // would be telling the owner he had consented to something he had not.
    readonly property bool lyricsOn: SettingsStore.boolValue("lyrics_online", false)
    // Three states, never two — HardwareCaps.qml's rule, and NEVER A DEAD
    // TOGGLE. -1 unknown (the probe has not answered yet), 0 the helper is
    // not installed on this image, 1 it is here and can be used.
    //   ⚠ "available" deliberately does NOT mean "lrclib.net answered". The
    //   only way to learn that is to ask it, and asking before consent is
    //   the exact thing this switch exists to prevent. So the probe reads
    //   the disk and nothing else, and the caption never promises a hit —
    //   LRCLIB's catalogue is far smaller than YouTube Music's and "no
    //   lyrics" is the ordinary outcome, not a fault.
    property int lyricsHelper: -1
    readonly property string swirlMode: SettingsStore.stringValue("swirl_mode", "paint")
    readonly property string swirlPreview: SettingsStore.stringValue("swirl_preview", "glacier")
    readonly property string lookSet: SettingsStore.stringValue("look_set", "ice") === "magma" ? "magma" : "ice"
    // TRK-3492 · PAINT STRENGTH. `swirl_intensity` is read by nine surfaces
    // (Bar, BarSeam, Spill, Frame, SidePanel x2, Launcher, PowerMenu,
    // SwirlChip) and the GTK Settings twin has shipped a slider for it since
    // nyxus_settings.py:4412 — but this page, the one the shell actually
    // opens, had no writer for it at all. Two shipped Settings apps
    // disagreeing about which knobs exist is the drift this pass closes.
    // Default MUST match Prefs.qml's adapter (1.0), same rule as controlPaint.
    readonly property real paintStrength: SettingsStore.numberValue("swirl_intensity", 1.0)
    // TRK-3361/3312 · the control paint. Defaults here MUST match Prefs.qml's
    // adapter defaults, or the page reads OFF on a fresh HOME while the shell
    // paints — the page and the shell are two readers of one file.
    readonly property bool controlPaint: SettingsStore.boolValue("swirl_controls", false)
    readonly property real controlSpeed: SettingsStore.numberValue("swirl_control_speed", 0.55)
    readonly property string sky: SettingsStore.stringValue("sky_mode", "headliner")
    readonly property string startStyle: SettingsStore.stringValue("launcher_style", "daily")

    // ── THE THEME ──────────────────────────────────────────────
    // Owner, 2026-09-06: both themes ship in one build — "like a dark theme
    // light theme type deal". This is the ONE control for that, and NYXUS is
    // the default, so an unset key and a fresh install both land neutral.
    //
    // Default MUST match Prefs.qml's adapter ("nyxus"), the standing rule at
    // the top of this file: the page and the shell are two readers of one
    // file, and a disagreeing default reads ALIEN here while the bar wears
    // the medallion.
    readonly property string markTheme: SettingsStore.stringValue("mark_theme", "nyxus")
    // Default MUST match Prefs.qml's adapter (0), same rule as the others.
    readonly property int panelChamfer: SettingsStore.numberValue("panel_chamfer", 0)

    // TRK-3435 shipped-first PATH via `env`, never a shell. Ruling:
    // SetPageBackup.qml. Same form as SetPageScreenlock.qml:18.
    readonly property string execPath: "PATH="
        + (Quickshell.env("NYXUS_BIN_DIR") || "/usr/local/bin")
        + ":" + Quickshell.env("PATH")

    // Sound follows the theme AS A SIDE EFFECT, so there is no second toggle
    // to forget. `nyxus-sound set-theme` writes gsettings per-user — no
    // pkexec, so this cannot prompt and cannot fail closed on a locked seat.
    Process {
        id: soundTheme
        running: false
    }

    // TRK-3812 · the lyrics helper probe. One shot, when the page opens, and
    // never again — `--probe` makes NO network request by design (see
    // `lyricsHelper` above). An exit code that is not 0, or a body that does
    // not parse, both mean "not installed", because an answer we cannot read
    // is not an answer.
    Process {
        id: lyricsProbe
        running: false
        command: ["env", page.execPath, "nyxus-lyrics", "--probe"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(String(this.text));
                    page.lyricsHelper = (d && d.v === 1) ? 1 : 0;
                } catch (e) {
                    page.lyricsHelper = 0;
                }
            }
        }
        onExited: function (code) {
            if (code !== 0)
                page.lyricsHelper = 0;
        }
    }

    Component.onCompleted: lyricsProbe.running = true

    // ⚠ The four OTHER manifest items need no code here and that is the
    // design: the Sigil, the lock scene's fallback, the greeter subject and
    // the password mask are all BINDINGS on `Prefs.markTheme`, so they follow
    // this key the moment it lands. Sound is the only one that is not a
    // binding — it is a process against another daemon's state — which is
    // exactly why it is the only thing this function has to do by hand.
    function applyTheme(name) {
        if (name === page.markTheme)
            return;
        SettingsStore.setValue("mark_theme", name);
        soundTheme.command = ["env", page.execPath, "nyxus-sound", "set-theme",
                              name === "alien" ? "nyxus-alien" : "nyxus"];
        soundTheme.running = true;
    }

    SetCard {
        heading: qsTr("Mark")
        tone: page.tone
        note: qsTr("NYXUS is the default. This switch moves five things only: the mark on the bar, the lock fallback, the login screen, system sounds, and the password mask. Desktop paint and widgets are the Desktop theme below.")

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s3

            SetIceFace {
                // 13q19 greps `key: "mark_theme"` — the stones write that key.
                property string key: "mark_theme"
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("NYXUS")
                caption: qsTr("The medallion, and the Earth")
                selected: page.markTheme === "nyxus"
                interactive: true
                onActivated: page.applyTheme("nyxus")
            }

            SetIceFace {
                property string key: "mark_theme"
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("ALIEN")
                caption: qsTr("The etched mark, and the Ocular")
                selected: page.markTheme === "alien"
                interactive: true
                onActivated: page.applyTheme("alien")
            }
        }
    }

    SetCard {
        heading: qsTr("Theme")
        tone: page.tone
        note: qsTr("Two complete themes. ICE is glacier living paint, plum, and Starlight. MAGMA is magma-to-black dye, the same Starlight sky, and the lava world as its own layer — not a photo of the two flattened together.")

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s3

            SetIceFace {
                property string key: "look_set"
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("ICE")
                caption: qsTr("Glacier + plum")
                selected: page.lookSet === "ice"
                interactive: true
                onActivated: {
                    SettingsStore.setValues({
                        look_set: "ice",
                        swirl_preview: "glacier",
                        swirl_mode: "paint",
                        sky_mode: "headliner",
                        layered_wall_base: ""
                    });
                }
            }
            SetIceFace {
                property string key: "look_set"
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("MAGMA")
                caption: qsTr("Live magma + Starlight")
                selected: page.lookSet === "magma"
                interactive: true
                onActivated: {
                    const home = Quickshell.env("HOME") || "";
                    SettingsStore.setValues({
                        look_set: "magma",
                        swirl_preview: "glacier",
                        swirl_mode: "paint",
                        sky_mode: "headliner",
                        layered_wall_base: home + "/.local/share/nyxus/walls/suxyn-magma-open"
                    });
                }
            }
        }
    }

    SetCard {
        heading: qsTr("Panel corners")
        tone: page.tone
        note: qsTr("Cut corners instead of round ones, the way the login card is. It applies to the shell\u2019s own PANELS \u2014 the surfaces things sit on. App windows keep their rounded corners: the compositor cannot draw a cut one (measured 2026-09-06). Switches, sliders, pills and rows stay round on purpose too \u2014 a cut corner means \u201cthis is a surface\u201d, a round one means \u201cthis is a control\u201d. Rounded is the shipped look and nothing changes until you pick Cut.")

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s3

            SetIceFace {
                // 13q19 greps `key: "panel_chamfer"` — the stones write it.
                property string key: "panel_chamfer"
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("ROUNDED")
                caption: qsTr("The shipped look")
                selected: page.panelChamfer === 0
                interactive: true
                onActivated: SettingsStore.setValue("panel_chamfer", 0)
            }

            SetIceFace {
                property string key: "panel_chamfer"
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("CUT")
                caption: qsTr("Machined, like the login card")
                // 18, because that is the cut the card he approved actually
                // used (greeter-nyxus-mockup.html, --chamfer:18px) rather
                // than a number picked here. Prefs clamps 0..32 regardless.
                selected: page.panelChamfer > 0
                interactive: true
                onActivated: SettingsStore.setValue("panel_chamfer", 18)
            }
        }
    }

    SetCard {
        heading: qsTr("Living paint")
        tone: page.tone
        note: qsTr("On the bar: swirls on/off, always vs hover, follow music, the visualizer, and lyrics. The filaments stay BQ. PAINT is pale glacier. BLACK SHADOW is the optional black-filament look. Rose, magma and violet are not a pick — magma is still destroy/record, violet is still unread/DND.")

        SetIceFace {
            kicker: qsTr("LIVING PAINT")
            reading: page.paintOn ? qsTr("ON") : qsTr("OFF")
            caption: page.paintOn
                     ? qsTr("Swirls on the bar")
                     : qsTr("Off — no swirls on the bar")
            selected: page.paintOn
            interactive: true
            onActivated: SettingsStore.setValue("swirl_enabled", !page.paintOn)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s3

            SetIceFace {
                // 13q19 greps `key: "swirl_motion"` — the stones write that key.
                property string key: "swirl_motion"
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("ALWAYS")
                caption: qsTr("Motion even at rest")
                selected: page.motion === "ambient"
                interactive: true
                onActivated: SettingsStore.setValue("swirl_motion", "ambient")
            }
            SetIceFace {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("ON HOVER")
                caption: qsTr("Only when the pointer is over the Line")
                selected: page.motion === "interactive"
                interactive: true
                onActivated: SettingsStore.setValue("swirl_motion", "interactive")
            }
        }

        SetIceFace {
            compact: true
            kicker: qsTr("FOLLOW MUSIC")
            reading: page.musicOn ? qsTr("ON") : qsTr("OFF")
            caption: qsTr("Beat from the playing sink — window rims and filaments")
            selected: page.musicOn
            interactive: true
            onActivated: SettingsStore.setValue("swirl_music", !page.musicOn)
        }

        // TRK-3711 · THE MUSIC VISUALISER. Owner 2026-09-01, having seen it:
        // "yes it will need its own setting."
        //
        // Directly under FOLLOW MUSIC and INDENTED BY ITS DEPENDENCE, not by
        // a Layout margin: `interactive` follows `musicOn`, so with the
        // parent off this stone cannot be pressed and its caption says why.
        // `_tokens.edges.state.disabled._rule` — "a control that cannot be
        // operated has no state to report" — is exactly this case, and
        // SetIceFace already honours it.
        SetIceFace {
            property string key: "bar_spectrum"
            compact: true
            kicker: qsTr("MUSIC VISUALISER")
            reading: page.musicOn ? (page.spectrumOn ? qsTr("ON") : qsTr("OFF"))
                                  : qsTr("UNAVAILABLE")
            caption: page.musicOn
                     ? qsTr("The bar turns over into a full-width spectrum while audio is playing")
                     : qsTr("Turn FOLLOW MUSIC on first — the visualizer is unavailable while that is off")
            selected: page.musicOn && page.spectrumOn
            interactive: page.musicOn
            onActivated: SettingsStore.setValue("bar_spectrum", !page.spectrumOn)
        }

        // TRK-3812 · SYNCED LYRICS — the one control in this build that lets
        // anything leave the machine, so the caption IS the consent and it
        // names the site. It sits here because this is where the bar's media
        // controls live; it is not indented under FOLLOW MUSIC because it
        // does not depend on it — lyrics come from the track's NAME, not
        // from the sink.
        //
        // ⚠ NEVER A DEAD TOGGLE (the standing mandate). Three states:
        // UNAVAILABLE when the helper is not on this image, "…" while the
        // probe has not answered, ON/OFF once it has — and the stone can
        // only be pressed in the last case.
        SetIceFace {
            property string key: "lyrics_online"
            compact: true
            kicker: qsTr("SYNCED LYRICS")
            reading: page.lyricsHelper < 0 ? qsTr("…")
                   : page.lyricsHelper === 0 ? qsTr("UNAVAILABLE")
                   : (page.lyricsOn ? qsTr("ON") : qsTr("OFF"))
            caption: page.lyricsHelper === 0
                     ? qsTr("The lyrics helper is not installed on this image")
                     : page.lyricsOn
                       ? qsTr("On. The artist, title and length of what you are playing are sent to lrclib.net to look up timed lyrics. Nothing else is sent — no album, no account, no history — and each track is asked about once. Many tracks have no lyrics there; the bar simply stays as it is.")
                       : qsTr("Off — nothing leaves this machine. Turning it on sends the artist, title and length of what you are playing to lrclib.net to look up timed lyrics, and nothing else.")
            selected: page.lyricsHelper === 1 && page.lyricsOn
            interactive: page.lyricsHelper === 1
            onActivated: SettingsStore.setValue("lyrics_online", !page.lyricsOn)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s3

            SetIceFace {
                // Writer for Prefs.swirlMode. 13q19 greps motion, forbids
                // swirl_layer / value magma, and forbids a pointer-trail picker.
                property string key: "swirl_mode"
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("PAINT")
                caption: qsTr("Shipped — pale glacier filaments")
                selected: page.swirlMode === "paint"
                interactive: true
                onActivated: SettingsStore.setValue("swirl_mode", "paint")
            }
            SetIceFace {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("BLACK SHADOW")
                caption: qsTr("Filaments go black and block a faint glow")
                selected: page.swirlMode === "shadow"
                        || page.swirlMode === "shadow-rendered"
                interactive: true
                onActivated: SettingsStore.setValue("swirl_mode", "shadow")
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s3

            SetIceFace {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("DIMMER")
                caption: qsTr("Same look, a little darker")
                selected: page.swirlMode === "shadow-dim"
                interactive: true
                onActivated: SettingsStore.setValue("swirl_mode", "shadow-dim")
            }
            SetIceFace {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("DARKEST")
                caption: qsTr("The lowest of the four rungs")
                selected: page.swirlMode === "shadow-darkest"
                interactive: true
                onActivated: SettingsStore.setValue("swirl_mode", "shadow-darkest")
            }
        }

        SetCard {
            heading: qsTr("Swirl preview")
            tone: page.tone
            // ── TRK-4161 · five buttons that did nothing under MAGMA ────────
            // Owner: "anything clicked on actually works and goes to what it
            // should go to". These five did not. Theme.paintRamp opens with
            // `if (lookMagma) return theme.lookLayer;` and never reads
            // Prefs.swirlPreview at all, so under MAGMA every dye here wrote
            // its key to settings.json, lit its own tile as SELECTED, and
            // changed not one pixel of paint.
            //
            // That is the worst shape a dead control can take: it looks like
            // it worked. The setting even survives a reboot, so the evidence
            // of the click persists while the effect never arrives.
            //
            // The MAGMA ramp is not an oversight to be undone — TRK-4138
            // measured and retuned its stops (stop 6 #ffb080 → #ffa85e) so
            // molten rock does not dim to khaki. MAGMA owns its dye on
            // purpose. So the honest fix is for this page to say so and stop
            // taking the click, rather than for MAGMA to start obeying a
            // picker built for the ICE paint.
            note: Theme.lookMagma
                ? qsTr("The MAGMA look brings its own ember dye, so these stay off while it is on. Switch back to ICE in Look to choose a swirl colour.")
                : qsTr("Look only. Tapping a colour turns PAINT on so you can see the dye. For widgets + stones + the bar on one page, open Layer lab from Personalization. Put GLACIER back when you are done.")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s3

            SetIceFace {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("GLACIER")
                caption: qsTr("House — pale ice")
                selected: !Theme.lookMagma && page.swirlPreview === "glacier"
                interactive: !Theme.lookMagma
                onActivated: SettingsStore.setValue("swirl_preview", "glacier")
            }
            SetIceFace {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("ROSE")
                caption: qsTr("Teal into plum")
                selected: !Theme.lookMagma && page.swirlPreview === "rose"
                interactive: !Theme.lookMagma
                onActivated: {
                    SettingsStore.setValue("swirl_preview", "rose");
                    SettingsStore.setValue("swirl_mode", "paint");
                }
            }
            SetIceFace {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("MAGMA")
                caption: qsTr("Ember / hot")
                selected: !Theme.lookMagma && page.swirlPreview === "magma"
                interactive: !Theme.lookMagma
                onActivated: {
                    SettingsStore.setValue("swirl_preview", "magma");
                    SettingsStore.setValue("swirl_mode", "paint");
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s3

            SetIceFace {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("VIOLET")
                caption: qsTr("Orchid / plum")
                selected: !Theme.lookMagma && page.swirlPreview === "violet"
                interactive: !Theme.lookMagma
                onActivated: {
                    SettingsStore.setValue("swirl_preview", "violet");
                    SettingsStore.setValue("swirl_mode", "paint");
                }
            }
            SetIceFace {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("WINE")
                caption: qsTr("New dusty rose")
                selected: !Theme.lookMagma && page.swirlPreview === "wine"
                interactive: !Theme.lookMagma
                onActivated: {
                    SettingsStore.setValue("swirl_preview", "wine");
                    SettingsStore.setValue("swirl_mode", "paint");
                }
            }
            SetIceFace {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("LAB")
                caption: qsTr("All layers on one page")
                selected: false
                interactive: true
                onActivated: Bus.openSettings("layerlab")
            }
        }

        // Strength, as three named stops for the same reason DRIFT/CALM/
        // LIVELY are stops and not a slider: the honest answer to "what
        // number is right" is a feel, not a figure. The GTK twin's slider
        // runs 0.40-1.60 (nyxus_settings.py:4384); these three sit inside
        // that range so a value set in either app reads back sensibly in
        // the other. Bands, not equality, so a slider-set 0.75 still lights
        // a stone instead of leaving all three dark.
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s3

            SetIceFace {
                // 13q19 greps `key:` on the writers it polices; this key is
                // not one it forbids (that list is swirl_layer and the
                // retired pointer-trail picker).
                property string key: "swirl_intensity"
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                enabled: page.paintOn
                kicker: qsTr("SOFT")
                caption: qsTr("Least paint per stroke")
                selected: page.paintStrength < 0.80
                interactive: true
                onActivated: SettingsStore.setValue("swirl_intensity", 0.60)
            }
            SetIceFace {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                enabled: page.paintOn
                kicker: qsTr("SHIPPED")
                caption: qsTr("The strength the Line is tuned at")
                selected: page.paintStrength >= 0.80 && page.paintStrength < 1.20
                interactive: true
                onActivated: SettingsStore.setValue("swirl_intensity", 1.0)
            }
            SetIceFace {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                enabled: page.paintOn
                kicker: qsTr("BOLD")
                caption: qsTr("Most paint — the dye reads heavier")
                selected: page.paintStrength >= 1.20
                interactive: true
                onActivated: SettingsStore.setValue("swirl_intensity", 1.40)
            }
        }
    }

    // ── TRK-3361/3312 · the control paint, its own card ──────────────────
    // Deliberately NOT rows on the Living paint card above. That card is the
    // Line, and folding these into it would make "turn the swirls down"
    // ambiguous about which surface it meant — which is the confusion this
    // split exists to remove. The master switch still lives up there: with
    // LIVING PAINT off, nothing here paints regardless (SwirlChip._paintOn).
    SetCard {
        heading: qsTr("Paint in controls")
        tone: page.tone
        note: qsTr("Toggles, switches and buttons can carry the same living paint the Line does. It is the same solver and the same colours, just a lot smaller. Big controls hold the picture well; a narrow switch track cannot fit a filament with dark either side of it, so if the small ones read as a smudge, this is the switch that turns them off.")

        SetIceFace {
            kicker: qsTr("PAINT IN CONTROLS")
            reading: page.controlPaint ? qsTr("ON") : qsTr("OFF")
            caption: page.controlPaint
                     ? qsTr("Toggles and buttons carry the paint")
                     : qsTr("Off — controls are chrome only, the Line is unchanged")
            selected: page.controlPaint
            interactive: true
            onActivated: SettingsStore.setValue("swirl_controls", !page.controlPaint)
        }

        // Speed, as three named stops rather than a slider. A slider invites
        // the question "what number is right", and the answer is a feel; the
        // stops are the three feels that are actually different at this size.
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s3

            SetIceFace {
                property string key: "swirl_control_speed"
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                enabled: page.controlPaint
                kicker: qsTr("DRIFT")
                caption: qsTr("Slowest — barely moves at rest")
                selected: page.controlSpeed < 0.42
                interactive: true
                onActivated: SettingsStore.setValue("swirl_control_speed", 0.30)
            }
            SetIceFace {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                enabled: page.controlPaint
                kicker: qsTr("CALM")
                caption: qsTr("Shipped — the Line's pace at this size")
                selected: page.controlSpeed >= 0.42 && page.controlSpeed < 0.78
                interactive: true
                onActivated: SettingsStore.setValue("swirl_control_speed", 0.55)
            }
            SetIceFace {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                enabled: page.controlPaint
                kicker: qsTr("LIVELY")
                caption: qsTr("Fastest — the Line's own numbers, unscaled")
                selected: page.controlSpeed >= 0.78
                interactive: true
                onActivated: SettingsStore.setValue("swirl_control_speed", 1.0)
            }
        }
    }

    SetCard {
        heading: qsTr("Now playing")
        tone: page.tone
        note: qsTr("When anything is playing (YouTube Music, Nyxus Media, a browser) a player card sits above the bar. The chevron docks it into the right of the bar, the same slot a notice uses. Click that line to raise the card. The clock stays the clock. Opening Media is a separate app.")

        SetIceFace {
            kicker: qsTr("CARD ON THE BAR")
            reading: page.mediaPop ? qsTr("ON") : qsTr("OFF")
            caption: qsTr("Player card above the Line while something is playing")
            selected: page.mediaPop
            interactive: true
            onActivated: SettingsStore.setValue("media_bar_pop", !page.mediaPop)
        }
    }

    // TRK-3424/TRK-3425: the sky and the Start style used to have FULL
    // pickers here AND on their own pages — the same key sold twice, and
    // this page's reset row reset settings that belong to Background and
    // Taskbar. One owner each now (Background owns `sky_mode`, it has the
    // stills; Taskbar owns `launcher_style`, Start lives on the Line), and
    // this page keeps honest link rows in their place.
    SetCard {
        heading: qsTr("Elsewhere")
        tone: page.tone
        note: qsTr("The desktop sky is picked on Background, beside the stills it shows. How Start opens is picked on Taskbar, where the Line is set.")

        SetRow {
            title: qsTr("Desktop sky")
            sub: page.sky === "headliner" ? qsTr("Starlight — the shipped ground")
                 : page.sky === "voyage" ? qsTr("Voyage — the 3D sky")
                 : page.sky === "layered" ? qsTr("Layers — the still, cut around the chips")
                 : qsTr("Picture — the still under Background")
            navigates: true
            onActivated: Bus.openSettings("wallpaper")
        }

        SetRow {
            title: qsTr("Start menu")
            sub: page.startStyle === "classic" ? qsTr("Classic — keeps the Atrium")
                                               : qsTr("Daily — the shipped layout")
            navigates: true
            onActivated: Bus.openSettings("dock")
        }
    }

    // TRK-1261 — every key this page writes, and ONLY this page's keys:
    // `sky_mode` and `launcher_style` left with their pickers (TRK-3424/25).
    // ⚠ `mark_theme` IS IN THIS LIST NOW, AND THE `onCleared` HANDLER IS WHY.
    // TRK-3746. It was excluded until 2026-09-06 for a real reason, recorded
    // here at the time: SetResetRow did exactly one thing —
    // `SettingsStore.clearValues(keys)` — with no completion signal, so a reset
    // that removed the key flipped the mark, the lock fallback, the greeter and
    // the mask back to NYXUS while `nyxus-sound` kept playing the ALIEN set.
    // A desync with no control anywhere that fixed it, because the only writer
    // of the sound theme is `applyTheme()`.
    //
    // That reason was about a missing HOOK, not about the theme, and the answer
    // to a missing hook is the hook. `SetResetRow.cleared()` now fires after
    // the clear, so the row can finish the job — and "Reset Appearance" stops
    // quietly leaving the most visible thing on the page exactly as it was,
    // which is what a reset that does not reset looks like to the owner.
    //
    // ⚠ `applyTheme("nyxus")` cannot be the handler: its first line returns
    // when the theme already reads as nyxus, which after the clear it does.
    // The sound side effect has to be re-asserted directly.
    //
    // `launcher_style` and `sky_mode` stay out on their own reasoning — they
    // belong to their pickers (TRK-3424/25), not to this page.
    SetResetRow {
        what: qsTr("Appearance")
        keys: ["panel_chamfer", "mark_theme", "look_set",
               "swirl_enabled", "swirl_motion", "swirl_music", "swirl_mode",
               "swirl_intensity", "bar_spectrum", "lyrics_online",
               "swirl_controls", "swirl_control_speed",
               "media_bar_pop"]
        onCleared: {
            soundTheme.command = ["env", page.execPath, "nyxus-sound",
                                  "set-theme", "nyxus"];
            soundTheme.running = true;
        }
    }
}
