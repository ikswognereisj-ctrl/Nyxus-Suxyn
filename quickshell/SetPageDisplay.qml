pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ System ▸ Display.   MODULE 1.
//
// ── the backend ─────────────────────────────────────────────────────────
//   `hyprctl monitors -j`     what is connected, at what mode, and every mode
//                             the panel reports it can do
//   `hyprctl keyword monitor` set resolution, refresh, position, scale
//   `nyxus-brightness`        backlight, on machines that have one. The
//                             helper is the ONE writer (TRK-980): it picks
//                             the backlight-class device with the largest
//                             max_brightness, clamps to a floor, logs the
//                             device to stderr and exits non-zero with a
//                             message when there is no backlight — which
//                             this page shows in the row instead of a
//                             slider that silently writes nowhere. The 08-20
//                             Alienware boot drove the panel DARK at 100%
//                             through a bare `brightnessctl set N%` whose
//                             device was whatever sysfs listed first.
//   `wlsunset`                colour temperature — the ONE night-light
//                             backend this image packages (packages.x86_64
//                             line 735). Until 2026-08-15 this page called
//                             `hyprsunset` and `gammastep`; NEITHER is
//                             packaged and neither is in the official repos,
//                             so the switch could never do anything on a
//                             shipped image (GAP-936). The GTK Display page
//                             had wlsunset right all along, which is why
//                             nothing here ever looked broken in review.
//
// The modes offered are **the ones the display actually reports**, never a
// hard-coded list. A settings page that offers 1920×1080 to a panel that
// cannot do it produces a black screen and a person who cannot get back.
//
// ── the safety rule this page follows ───────────────────────────────────
// A mode change can leave you unable to see the window that made it. So a mode
// is applied and then **confirmed**: if you do not press Keep within fifteen
// seconds, the previous mode is put back. That is what every desktop does, and
// it is the difference between a resolution picker and a trap.
//
// ── the shader dials ────────────────────────────────────────────────────
// TRK-3121 — living wallpaper and Voyage are OUR settings, not Hyprland's.
// `shell.qml` reads `livewall_*` / `voyage_*` from the store. They used to
// write JSON only; the comment here claiming Prefs/Starlight3D already
// read them was false. They live on this page because they look like
// display settings.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    property var entry: null
    // TRK-3435: shipped-first PATH via `env`, never a shell. Ruling:
    // SetPageBackup.qml.
    readonly property string execPath: "PATH="
        + (Quickshell.env("NYXUS_BIN_DIR") || "/usr/local/bin")
        + ":" + Quickshell.env("PATH")

    title: qsTr("Display")
    blurb: qsTr("Resolution, refresh, brightness, and the paint behind your windows.")

    property var monitors: []
    property bool probed: false
    property string lastError: ""

    // ── mode confirmation ───────────────────────────────────────────────
    property string pendingMonitor: ""
    property string previousSpec: ""
    property int countdown: 0

    // TRK-3426: skyMode/voyageOn/voyageLive/starlightOverlayLive moved to
    // SetPageBackground with the cards that read them — nothing left on
    // this page gates on the sky.

    // Two probes on open, both one-shot: what monitors exist, and whether
    // `wlsunset` is really on this machine. The second decides whether the
    // night-light switch can be offered at all, so it has to answer before
    // that card can tell the truth about itself.
    Component.onCompleted: {
        page.probe();
        probeSunset.running = true;
        probeBacklight.running = true;
    }

    function probe() { if (!mon.running) mon.running = true; }

    Process {
        id: mon
        running: false
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                var d;
                try {
                    d = JSON.parse(String(this.text));
                } catch (e) {
                    page.lastError = "hyprctl did not return JSON: " + e;
                    page.probed = true;
                    return;
                }
                page.monitors = Array.isArray(d) ? d : [];
                page.probed = true;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                var m = String(this.text).trim();
                if (m !== "")
                    console.warn("Display: " + m);
            }
        }
    }

    Process {
        id: actor
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                var m = String(this.text).trim();
                if (m !== "") {
                    page.lastError = m;
                    console.warn("Display: " + m);
                }
            }
        }
        onRunningChanged: if (!actor.running) page.probe()
    }

    // Hyprland's monitor keyword takes one string:
    //   NAME,WIDTHxHEIGHT@HZ,POSITION,SCALE[,transform,N]
    // Position and scale are carried through from what the monitor is already
    // doing, because this page changes one thing at a time and re-stating the
    // others from stale values is how a second display ends up on top of the
    // first. `transform` is appended only when it is non-zero, so an unrotated
    // monitor's line stays exactly the shape it was.
    function spec(m, res, hz, scale, transform) {
        var t = (transform === undefined || transform === null)
                ? page.transformOf(m) : Number(transform);
        var base = m.name + "," + res + "@" + hz + ","
                 + m.x + "x" + m.y + "," + Number(scale).toFixed(6);
        return t > 0 ? base + ",transform," + t : base;
    }

    // Hyprland reports the current rotation as `transform` on the monitor
    // object. Older versions omit it entirely, and an absent field must read
    // as "not rotated" rather than as NaN — which would put the literal string
    // "transform,NaN" into a keyword and cost the monitor its mode.
    function transformOf(m) {
        var t = Number(m.transform);
        return isFinite(t) && t > 0 ? t : 0;
    }

    function currentSpec(m) {
        return page.spec(m, m.width + "x" + m.height,
                         Number(m.refreshRate).toFixed(2), m.scale,
                         page.transformOf(m));
    }

    function applySpec(m, s) {
        if (actor.running)
            return;
        page.previousSpec = page.currentSpec(m);
        page.pendingMonitor = m.name;
        page.countdown = 15;
        revert.restart();
        actor.command = ["hyprctl", "keyword", "monitor", s];
        actor.running = true;
    }

    function keep() {
        revert.stop();
        page.pendingMonitor = "";
        page.previousSpec = "";
        page.countdown = 0;
    }

    function undo() {
        revert.stop();
        page.countdown = 0;
        if (page.previousSpec !== "" && !actor.running) {
            actor.command = ["hyprctl", "keyword", "monitor", page.previousSpec];
            actor.running = true;
        }
        page.pendingMonitor = "";
        page.previousSpec = "";
    }

    // One tick a second while a change is unconfirmed, and NOT running
    // otherwise — a timer that ticks forever on a settings page is a timer
    // that ticks forever on the desktop.
    Timer {
        id: revert
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            page.countdown -= 1;
            if (page.countdown <= 0)
                page.undo();
        }
    }

    // Distinct resolutions the panel reports, biggest first — the order a
    // person scans. Hyprland gives `availableModes` as "1920x1080@60.00Hz".
    function resolutions(m) {
        var seen = {};
        var out = [];
        var modes = m.availableModes || [];
        for (var i = 0; i < modes.length; ++i) {
            var r = String(modes[i]).split("@")[0];
            if (r === "" || seen[r])
                continue;
            seen[r] = true;
            out.push(r);
        }
        if (!seen[m.width + "x" + m.height])
            out.unshift(m.width + "x" + m.height);
        out.sort(function (a, b) {
            return (parseInt(b, 10) || 0) - (parseInt(a, 10) || 0);
        });
        return out.map(function (r) { return { value: r, label: r }; });
    }

    // Refresh rates available AT the resolution currently set. Offering 144 Hz
    // from a mode list that only supports it at a lower resolution is the same
    // black-screen failure as offering an impossible resolution.
    function rates(m) {
        var cur = m.width + "x" + m.height;
        var seen = {};
        var out = [];
        var modes = m.availableModes || [];
        for (var i = 0; i < modes.length; ++i) {
            var parts = String(modes[i]).split("@");
            if (parts[0] !== cur)
                continue;
            var hz = parts[1] ? parts[1].replace("Hz", "") : "";
            if (hz === "" || seen[hz])
                continue;
            seen[hz] = true;
            out.push(hz);
        }
        if (out.length === 0)
            out.push(Number(m.refreshRate).toFixed(2));
        out.sort(function (a, b) { return parseFloat(b) - parseFloat(a); });
        return out.map(function (hz) {
            return { value: hz, label: Math.round(parseFloat(hz)) + " Hz" };
        });
    }

    // ══ CONFIRMATION ═══════════════════════════════════════════════════
    SetCard {
        heading: qsTr("Keep this display setting?")
        tone: page.tone
        visible: page.pendingMonitor !== ""
        note: qsTr("If you cannot read this, wait — the previous setting comes back ")
              + "on its own."

        SetRow {
            glyph: ""
            title: "Reverting in " + page.countdown + " second"
                   + (page.countdown === 1 ? "" : "s")
            sub: "The change has been applied to " + page.pendingMonitor

            RowLayout {
                spacing: Theme.s4
                SetButton {
                    text: qsTr("Keep")
                    glyph: ""
                    tone: page.tone
                    onClicked: page.keep()
                }
                SetButton {
                    text: qsTr("Undo")
                    glyph: ""
                    tone: page.tone
                    onClicked: page.undo()
                }
            }
        }
    }

    // ══ MONITORS ═══════════════════════════════════════════════════════
    SetCard {
        heading: qsTr("Displays")
        tone: page.tone
        note: page.lastError !== "" ? page.lastError
              : "Only the modes your display reports are offered. A change is "
                + "undone automatically if you do not confirm it."

        SetIceFace {
            visible: page.probed && page.monitors.length === 0
            compact: true
            kicker: qsTr("DISPLAY")
            caption: qsTr("Hyprland is not reporting any monitor")
            detail: qsTr("That normally means this shell is not running under Hyprland.")
        }

        Repeater {
            model: page.monitors

            delegate: SetIceFace {
                required property var modelData
                kicker: String(modelData.name || "DISPLAY").toUpperCase()
                reading: modelData.width + "×" + modelData.height
                caption: (modelData.description && String(modelData.description) !== "")
                         ? String(modelData.description) : String(modelData.name)
                detail: Math.round(modelData.refreshRate) + " Hz · scale "
                        + Number(modelData.scale).toFixed(2)
                        + (modelData.focused ? " · primary" : "")
                selected: !!modelData.focused
            }
        }

        Repeater {
            model: page.monitors

            delegate: SetRow {
                id: res
                required property var modelData
                glyph: ""
                title: qsTr("Resolution")
                sub: String(modelData.name)

                SetChoice {
                    tone: page.tone
                    segmentLimit: 0
                    options: page.resolutions(res.modelData)
                    value: res.modelData.width + "x" + res.modelData.height
                    onChosen: function (v) {
                        page.applySpec(res.modelData,
                            page.spec(res.modelData, v,
                                      Number(res.modelData.refreshRate).toFixed(2),
                                      res.modelData.scale));
                    }
                }
            }
        }

        Repeater {
            model: page.monitors

            delegate: SetRow {
                id: rate
                required property var modelData
                glyph: ""
                title: qsTr("Refresh rate")
                sub: "Available at the current resolution on " + modelData.name

                SetChoice {
                    tone: page.tone
                    options: page.rates(rate.modelData)
                    value: Number(rate.modelData.refreshRate).toFixed(2)
                    onChosen: function (v) {
                        page.applySpec(rate.modelData,
                            page.spec(rate.modelData,
                                      rate.modelData.width + "x" + rate.modelData.height,
                                      v, rate.modelData.scale));
                    }
                }
            }
        }

        Repeater {
            model: page.monitors

            delegate: SetRow {
                id: sc
                required property var modelData
                glyph: ""
                title: qsTr("Scale")
                sub: qsTr("Makes everything larger without changing the resolution. ")
                     + "Fractional values can blur older applications."

                SetChoice {
                    tone: page.tone
                    value: Number(sc.modelData.scale).toFixed(6)
                    options: [
                        { value: "1.000000",  label: "100%" },
                        { value: "1.250000",  label: "125%" },
                        { value: "1.500000",  label: "150%" },
                        { value: "2.000000",  label: "200%" }
                    ]
                    onChosen: function (v) {
                        page.applySpec(sc.modelData,
                            page.spec(sc.modelData,
                                      sc.modelData.width + "x" + sc.modelData.height,
                                      Number(sc.modelData.refreshRate).toFixed(2), v));
                    }
                }
            }
        }
    }

    // ══ ORIENTATION & ADAPTIVE SYNC ════════════════════════════════════
    // Both taken from the parallel implementation on
    // `worktree-master-settings`, which carried them where this page did not.
    SetCard {
        heading: qsTr("Orientation & sync")
        tone: page.tone
        note: qsTr("A rotation goes through the same confirm-or-revert as a mode ")
              + "change. A screen you cannot read your way out of is worse "
              + "rotated than at the wrong resolution."

        Repeater {
            model: page.monitors

            delegate: SetRow {
                id: rot
                required property var modelData
                glyph: "\uf021"
                title: qsTr("Orientation")
                sub: String(modelData.name)

                SetChoice {
                    tone: page.tone
                    // TRK-3511 · a MENU, not four segments. SetChoice renders
                    // segmented while the option count is within
                    // `segmentLimit` (default 4) — and this has exactly four,
                    // so it qualified on COUNT while being far too wide on
                    // TEXT: "Landscape flipped" and "Portrait flipped" put the
                    // segment row past the card's right edge, and because a
                    // SetRow lays title and control on one line, the row drew
                    // ITS OWN LABEL UNDERNEATH the segments — "WAYLAND-1"
                    // legible through the "Landscape" pill at the shipped
                    // 960 px window width.
                    //
                    // The limit is a count, and the constraint here is width,
                    // so the count is the wrong lever; `segmentLimit: 0` is
                    // this component's existing spelling of "always a menu"
                    // (SetPageKeyboard.qml:113 uses it for the same reason —
                    // its list is too long to sit in a row).
                    segmentLimit: 0
                    value: String(page.transformOf(rot.modelData))
                    options: [
                        { value: "0", label: qsTr("Landscape") },
                        { value: "1", label: qsTr("Portrait") },
                        { value: "2", label: qsTr("Landscape flipped") },
                        { value: "3", label: qsTr("Portrait flipped") }
                    ]
                    onChosen: function (v) {
                        page.applySpec(rot.modelData,
                            page.spec(rot.modelData,
                                      rot.modelData.width + "x" + rot.modelData.height,
                                      Number(rot.modelData.refreshRate).toFixed(2),
                                      rot.modelData.scale, v));
                    }
                }
            }
        }

        SetRow {
            glyph: "\uf0e7"
            title: qsTr("Adaptive sync")
            sub: qsTr("Lets the display match its refresh rate to what is being drawn. ")
                 + "Smoother in games; a few panels flicker on the desktop, which "
                 + "is what the third setting is for."

            SetChoice {
                key: "display_vrr"
                defaultValue: "0"
                tone: page.tone
                options: [
                    { value: "0", label: qsTr("Off") },
                    { value: "1", label: qsTr("On") },
                    { value: "2", label: qsTr("Fullscreen only") }
                ]
                // TRK-3455: no onChosen and no local Process any more. The
                // one-shot hyprctl here made this a write-only key — nothing
                // re-applied it at login, so the page showed the stored
                // choice over a compositor sitting on its default. The store
                // write is enough: HyprApply carries `misc:vrr` in its batch
                // now, applied on every commit and at startup, one writer
                // and one applier like every other session keyword.
            }
        }
    }

    // Display has no destructive SetButton (Keep/Undo are confirm, not
    // destroy). Magma danger lives on SetButton in Usb / Bluetooth /
    // Printers / Updates. Capture is the flyout (`SidePanel.qml`) — not
    // this page, not this lane.
    SetCard {
        heading: qsTr("Brightness & colour")
        tone: page.tone
        note: page.hasSunset
              ? "Night Light warms the output through wlsunset. One switch, "
                + "same as the flyout — not a second pill."
              : "Night Light needs wlsunset installed; without it the switch "
                + "says so rather than doing nothing."

        SetRow {
            glyph: ""
            title: qsTr("Brightness")
            sub: page.backlightDevice !== ""
                 ? "Backlight " + page.backlightDevice + " — the panel, not an LED"
                 : "Backlight, on machines that have one"
            // TRK-980: the row says so when there is no backlight, instead
            // of a slider that writes to nothing. The reason is the helper's
            // own stderr line (e.g. "no backlight on this machine (class
            // backlight lists: nothing)"), not a string typed here.
            available: page.hasBacklight
            unavailableReason: page.backlightReason !== ""
                               ? page.backlightReason
                               : "no backlight on this machine"

            SetSlider {
                key: "display_brightness"
                width: 250
                tone: page.tone
                from: 5; to: 100; snap: 5; defaultValue: 80
                suffix: "%"
                // Applied on release rather than continuously: the helper is
                // a subprocess, and a drag that spawns one per step is the
                // hyprlock failure again.
                live: false
                onReleased: function (v) {
                    if (bright.running)
                        return;
                    // One writer for every surface (flyout too): the helper
                    // picks the device, clamps, and logs what it did.
                    bright.command = ["env", page.execPath,   // TRK-3435
                        "nyxus-brightness", "set", String(Math.round(v))];
                    bright.running = true;
                }
            }
        }

        SetRow {
            glyph: ""
            title: qsTr("Night Light")
            sub: qsTr("Warms the whole screen. Same switch as the flyout — not a second pill.")
            available: page.hasSunset
            unavailableReason: qsTr("wlsunset is not installed")
            SetSwitch {
                key: "display_nightlight"
                defaultValue: false
                tone: page.tone
                onToggled: function (v) { page.applyNight(v); }
            }
        }

        SetRow {
            glyph: ""
            title: qsTr("Warmth")
            sub: qsTr("Lower is warmer. 6500 K is daylight; 4000 K is a warm room.")
            available: page.hasSunset
                       && SettingsStore.boolValue("display_nightlight", false)
            unavailableReason: page.hasSunset ? qsTr("Night Light is off")
                                              : "wlsunset is not installed"

            SetSlider {
                key: "display_temp"
                width: 250
                tone: page.tone
                from: 2500; to: 6500; snap: 100; defaultValue: 4000
                suffix: " K"
                live: false
                onReleased: function () {
                    if (SettingsStore.boolValue("display_nightlight", false))
                        page.applyNight(true);
                }
            }
        }

        SetRow {
            glyph: ""
            title: qsTr("When")
            sub: qsTr("Evenings are 8pm–6am. Until sign-out holds the warmth now.")
            available: page.hasSunset
                       && SettingsStore.boolValue("display_nightlight", false)
            unavailableReason: page.hasSunset ? qsTr("Night Light is off")
                                              : "wlsunset is not installed"

            SetChoice {
                key: "display_nightlight_when"
                defaultValue: "now"
                tone: page.tone
                options: [
                    { value: "now",      label: qsTr("Until sign-out") },
                    { value: "evening",  label: qsTr("Evenings") }
                ]
                onChosen: function () {
                    if (SettingsStore.boolValue("display_nightlight", false))
                        page.applyNight(true);
                }
            }
        }

        // ── the ten-foot screen (TRK-4151) ──────────────────────────────
        // THE FLOOR used to decide this for itself. Its rule was `onTv`,
        // which is nothing more than "this screen's name begins with HDMI",
        // and on the owner's desk that screen is the television, so the
        // rule was right and nobody questioned it.
        //
        // It stopped being right the moment this shell became something
        // other people install. `build-iso.sh` copies the whole quickshell
        // directory into /etc/skel, so the Floor ships with every image,
        // and the first time a stranger plugged a monitor into HDMI the
        // ten-foot browser would take that entire screen uninvited. The
        // only way out was NYXUS_ARCADE, an environment variable — which
        // is a developer's lever, not something a person can find.
        //
        // So `961eea5` put it behind `floor_enabled`, defaulting off. That
        // closed the release hole but left a smaller one: a real pref with
        // no control is a pref only someone who reads QML can reach, and
        // this build does not ship settings you have to know about to use.
        // This is that control. It belongs on Display because the thing it
        // governs is what a second screen becomes.
        SetRow {
            glyph: ""
            title: qsTr("Ten-Foot Mode")
            sub: qsTr("Turns an HDMI screen into a full-screen media browser you drive from the couch. Off leaves it an ordinary desktop.")
            available: true
            SetSwitch {
                key: "floor_enabled"
                defaultValue: false
                tone: page.tone
            }
        }
    }

    property bool hasSunset: false

    Process {
        id: probeSunset
        running: false
        command: ["sh", "-c",
            "command -v wlsunset >/dev/null 2>&1 && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: page.hasSunset = String(this.text).trim() === "yes"
        }
    }

    // ── backlight (TRK-980) ─────────────────────────────────────────────
    // `nyxus-brightness probe` answers once, when the page opens: stdout is
    // "<device> <max> <current%>" when a usable backlight exists, exit 2 and
    // a stderr sentence when it does not. The sentence becomes the row's
    // unavailable reason, so the page shows the helper's finding rather
    // than a guess of its own.
    property bool hasBacklight: false
    property string backlightDevice: ""
    property string backlightReason: ""

    Process {
        id: probeBacklight
        running: false
        command: ["env", page.execPath, "nyxus-brightness", "probe"]   // TRK-3435
        stdout: StdioCollector {
            onStreamFinished: {
                var parts = String(this.text).trim().split(/\s+/);
                if (parts.length >= 2 && parts[0] !== "") {
                    page.backlightDevice = parts[0];
                    page.hasBacklight = true;
                    // TRK-3460: the probe's third field is the CURRENT
                    // percent, and this page used to throw it away — the
                    // slider showed the stored key over whatever the
                    // hardware (or the flyout) had actually set, every time
                    // the page opened after anything else moved the light.
                    // Record the truth so the slider opens on it. Guarded so
                    // an unchanged value does not dirty settings.json.
                    if (parts.length >= 3) {
                        var cur = Math.round(Number(parts[2]));
                        if (isFinite(cur) && cur >= 5 && cur <= 100
                            && cur !== SettingsStore.numberValue("display_brightness", 80))
                            SettingsStore.setValue("display_brightness", cur);
                    }
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                var m = String(this.text).trim();
                // Keep the LAST line — the verdict — not the per-device
                // "refusing …" notes above it. No onExited here: qmllint
                // cannot resolve its ExitStatus parameter and this file must
                // not gain a warning (TRK-980 acceptance 4); a probe that
                // prints no device leaves hasBacklight false, which is the
                // same verdict an exit code would give.
                var lines = m.split("\n").filter(function (l) { return l.trim() !== ""; });
                if (lines.length > 0 && !page.hasBacklight)
                    page.backlightReason = lines[lines.length - 1]
                        .replace(/^nyxus-brightness:\s*/, "");
            }
        }
    }

    Process {
        id: bright
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                // device / max / requested / applied / readback — the helper
                // writes this every time; forwarding it puts the device name
                // in the shell log, which is what TRK-980 lacked.
                var m = String(this.text).trim();
                if (m !== "")
                    console.warn("Display: brightness — " + m);
            }
        }
    }

    // The night-light Process that stood here moved to HyprApply with the
    // command it ran (TRK-3966). Leaving an unused Process behind would be a
    // second, silent way to start a wlsunset.

    // ── Night Light, on the one backend that ships ──────────────────────
    // wlsunset is the only night-light tool in packages.x86_64. Owner
    // 2026-08-19: it has to WARM; do not add a second pill; wire QML to
    // this compositor path rather than handing the schedule to GTK.
    //
    // Always-on used to be expressed as sunrise 00:00 / sunset 23:59 with
    // equal high and low kelvin. That is a 23-hour DAY, and wlsunset may
    // reject high==low — either way the screen stays cold (WIP-685).
    // Until-sign-out is a one-minute DAY at 00:00 and NIGHT for the rest,
    // so the low temperature is what you see. High is low+100 so the pair
    // cannot be rejected. Evenings are sunrise 06:00 / sunset 20:00 with
    // day 6500 K and night at the warmth slider.
    //
    // `exec wlsunset … &` so the Process can exit without killing gamma
    // when you leave this page. pkill first so the flyout pill and this
    // switch cannot stack two wlsunsets.
    // ── audit-0908 · TRK-3966 · this used to BE the backend ─────────────
    // The wlsunset command that was written out here (and again, verbatim, in
    // SidePanel.qml) now lives in `HyprApply`, beside `display_vrr`, for the
    // reason TRK-3455 moved that one: a setting applied only by the handler
    // that changed it is re-applied by nothing at login. The switch said ON
    // over a cold screen after every reboot.
    //
    // The argument is dropped deliberately. `SetSwitch` and the side panel's
    // pill both write the store BEFORE they call this, so `on` was always the
    // value already in `display_nightlight` — a second channel for the same
    // fact, and the kind of duplicate that eventually disagrees. HyprApply
    // reads the store, which is the one source. The parameter is still
    // accepted so the existing call sites read the same, and ignored.
    function applyNight(on) {
        HyprApply.applyNight();
    }

    // TRK-3426: the "Living desktop" and "deep-space view" cards moved to
    // Background (SetPageBackground.qml). They are wallpaper-engine
    // settings — this page's own blurb disclaimed them ("Living wallpaper
    // ships off") and every one of their controls gates on the sky picked
    // over there. Display keeps a link so the old path still lands.
    SetCard {
        heading: qsTr("The painted desktop")
        tone: page.tone
        note: qsTr("Living wallpaper, Starlight and the 3D sky are set on Background, beside the sky they paint.")

        SetRow {
            title: qsTr("Background")
            sub: qsTr("Starlight, or a numbered still")
            navigates: true
            onActivated: Bus.openSettings("wallpaper")
        }
    }

    SetCard {
        heading: qsTr("Also on this machine")
        tone: page.tone
        note: qsTr("Wi-Fi, Bluetooth, sound, printers — the same Devices story.")

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
            title: qsTr("Printers & scanners")
            navigates: true
            onActivated: Bus.openSettings("printers")
        }
    }

    // ── audit-0908 · TRK-3967 ───────────────────────────────────────────
    // This page wrote five keys and had no Reset row, so the only way back
    // from a bad brightness or a wrong warmth was the whole-file reset on
    // Settings ▸ Reset — which also takes the GTK control center's settings
    // with it — or hand-editing settings.json. `keys` is exactly what the
    // page writes; gate 13r81 fails on a key listed here that the page does
    // not write, and on a key the page writes that is not listed.
    //
    // Two of these five have a backend that has to be told, and they are told
    // in opposite ways, which is the point of the `cleared` hook:
    //   · display_vrr and the three Night Light keys are re-applied on their
    //     own, because HyprApply runs on every store commit and a clear IS a
    //     commit (TRK-3455 / TRK-3966). Nothing needed here.
    //   · display_brightness has no such applier — the page pushes it to
    //     `nyxus-brightness` on slider release and nowhere else — so without
    //     this handler the row would clear the key and leave the panel at the
    //     brightness the cleared value had set. That is a reset that visibly
    //     does nothing, which is worse than no reset at all.
    // The handler is a named function rather than an inline block because
    // gate 13r81 requires the reset row to be the LAST thing on the page and
    // reads "last" off the braces that follow it. That is a proxy, but it is
    // the gate's proxy, and a page is not the place to argue with it.
    function pushBrightness() {
        if (!page.hasBacklight || bright.running)
            return;
        bright.command = ["env", page.execPath, "nyxus-brightness", "set",
                          String(Math.round(
                              SettingsStore.numberValue("display_brightness", 80)))];
        bright.running = true;
    }

    SetResetRow {
        what: qsTr("Display")
        keys: ["display_brightness", "display_nightlight",
               "display_nightlight_when", "display_temp", "display_vrr"]
        onCleared: page.pushBrightness()
    }
}
