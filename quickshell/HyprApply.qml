pragma Singleton
// Nyxus Suxyn — the input applier.   MODULES 2 and 3.
//
// ── the problem this solves ─────────────────────────────────────────────
// Pointer speed, key repeat, layout and cursor all live in Hyprland, and
// `hyprctl keyword` changes them **for the running session only**. A settings
// page that only called hyprctl would work perfectly and forget everything at
// the next login, which is the worst of both worlds: it looks like it saved.
//
// The obvious fix — write a `conf.d` shard and add a `source =` line — is not
// available to a shell: `hyprland.conf` lives in the skel and belongs to
// another lane, and a `source` line that goes missing makes Hyprland boot to
// an error banner instead of a desktop (`HANDOFF.md`, learned the hard way).
//
// So the truth lives where every other setting in this build lives —
// `settings.json` — and the SHELL is what applies it, at startup and on every
// change. One writer, one applier, no second copy of the value to drift, and
// nothing outside the user's own config directory is touched.
//
// ── the backend ─────────────────────────────────────────────────────────
// `hyprctl --batch`, one process for the whole set. Not one per key: sixteen
// subprocesses on a slider drag is the shape of the hyprlock failure that cost
// a hard reset, and a batch is atomic from the compositor's point of view.
//
// Defaults below are the values shipped in `hyprland.conf`'s own `input {}`
// block, so a fresh install applies exactly what it would have had anyway and
// this file changes nothing until somebody moves a control.
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: applier

    // ── pointer ─────────────────────────────────────────────────────────
    readonly property real  sensitivity:   SettingsStore.numberValue("mouse_sensitivity", 0.0)
    readonly property string accelProfile: SettingsStore.stringValue("mouse_accel_profile", "adaptive")
    readonly property bool  naturalScroll: SettingsStore.boolValue("mouse_natural_scroll", false)
    readonly property real  scrollFactor:  SettingsStore.numberValue("mouse_scroll_factor", 1.0)
    readonly property bool  leftHanded:    SettingsStore.boolValue("mouse_left_handed", false)
    readonly property int   followMouse:   SettingsStore.numberValue("mouse_follow", 1)

    // ── touchpad ────────────────────────────────────────────────────────
    readonly property bool tpNatural: SettingsStore.boolValue("touchpad_natural_scroll", true)
    readonly property bool tpTap:     SettingsStore.boolValue("touchpad_tap", true)
    readonly property bool tpDwt:     SettingsStore.boolValue("touchpad_dwt", true)
    readonly property real tpScroll:  SettingsStore.numberValue("touchpad_scroll_factor", 1.0)

    // ── keyboard ────────────────────────────────────────────────────────
    readonly property string kbLayout:  SettingsStore.stringValue("kb_layout", "us")
    readonly property string kbVariant: SettingsStore.stringValue("kb_variant", "")
    readonly property int    kbRate:    SettingsStore.numberValue("kb_repeat_rate", 25)
    readonly property int    kbDelay:   SettingsStore.numberValue("kb_repeat_delay", 600)
    readonly property bool   kbNumlock: SettingsStore.boolValue("kb_numlock", false)

    // ── display ─────────────────────────────────────────────────────────
    // TRK-3455: `display_vrr` was a write-only key — SetPageDisplay applied
    // it with a one-shot hyprctl and NOTHING re-applied it at login, so after
    // a reboot the page showed the stored choice while the compositor sat on
    // its config default. It lives here now, like every other session-only
    // keyword: applied at startup and on every store commit. "0" is
    // Hyprland's own default (no shipped conf sets misc:vrr).
    readonly property string vrr: SettingsStore.stringValue("display_vrr", "0")

    // ── Night Light ─────────────────────────────────────────────────────
    // audit-0908 / TRK-3966. `display_vrr` was moved here by TRK-3455 for
    // exactly one reason: it was applied by a page handler and re-applied by
    // nothing, so after a reboot the page showed the stored choice and the
    // screen did not have it. Night Light is the SAME defect and it was left
    // behind by that refactor, because the refactor was scoped to hyprctl
    // KEYWORDS and this backend is a process. `grep exec-once ~/.config/hypr`
    // on the owner's machine finds no wlsunset: turn the warmth on, reboot,
    // and the switch still says ON over a cold screen.
    //
    // Being a process rather than a keyword changes two things and neither of
    // them is a reason to sit outside this file:
    //
    //   * It cannot ride the hyprctl batch, so it has its own Process.
    //   * It is not idempotent — re-running it kills and respawns wlsunset,
    //     which flashes the gamma ramp. The batch can be fired on every
    //     commit because writing a keyword twice costs nothing; this cannot.
    //     So `_nightSpec` is the full state as one string and the process
    //     runs only when that string CHANGES, which makes "apply on every
    //     commit" as safe here as it is for the keywords.
    //
    // The command is the one SetPageDisplay had; both that page and the side
    // panel now call in here instead of carrying their own copy, so the three
    // sites that could each pkill the other's wlsunset are one site.
    readonly property bool   nightOn:   SettingsStore.boolValue("display_nightlight", false)
    readonly property int    nightTemp: SettingsStore.numberValue("display_temp", 4000)
    readonly property string nightWhen: SettingsStore.stringValue("display_nightlight_when", "now")

    readonly property string _nightSpec: applier.nightOn
        ? ("on|" + Math.round(applier.nightTemp) + "|" + applier.nightWhen)
        : "off"
    // "" is "we have not applied anything yet", which is NOT the same as
    // "off": at shell start something may already be running from a previous
    // session, so the first pass must run even when the setting is off — that
    // is what stops a stale wlsunset outliving the switch that started it.
    property string _nightApplied: ""
    onNightOnChanged: applier.applyNight()
    onNightTempChanged: applier.applyNight()
    onNightWhenChanged: applier.applyNight()
    Component.onCompleted: Qt.callLater(function () {
        applier.applyNight();
        if (SettingsStore.loaded)
            applier.apply();
    })

    Process {
        id: night
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                var m = String(this.text).trim();
                if (m !== "")
                    console.warn("HyprApply: night light — " + m);
            }
        }
    }

    function applyNight() {
        if (night.running || applier._nightApplied === applier._nightSpec)
            return;
        applier._nightApplied = applier._nightSpec;
        // Until-sign-out is a one-minute DAY at 00:00 and NIGHT for the rest,
        // so the low temperature is what you see. High is low+100 so the pair
        // cannot be rejected. Evenings are sunrise 06:00 / sunset 20:00 with
        // day 6500 K and night at the warmth slider.
        //
        // `exec wlsunset … &` so the Process can exit without killing gamma.
        // pkill first so no two wlsunsets can stack.
        night.command = ["sh", "-c",
            'on="$1"; t="$2"; when="${3:-now}"; '
          + 'pkill -x wlsunset 2>/dev/null; '
          + 'pkill -x hyprsunset 2>/dev/null; pkill -x gammastep 2>/dev/null; '
          + '[ "$on" = "false" ] && exit 0; '
          + 'command -v wlsunset >/dev/null 2>&1 || '
          + '{ echo "wlsunset is not installed" >&2; exit 1; }; '
          // setsid -f: Quickshell's Process kills its process group when
          // this script exits. `exec … &` was still in that group, so
          // Night Light said ON with no wlsunset (owner 2026-09-10).
          + 'if [ "$when" = "evening" ]; then '
          + '  setsid -f wlsunset -T 6500 -t "$t" -S 06:00 -s 20:00; '
          + 'else '
          + '  setsid -f wlsunset -T "$((t + 100))" -t "$t" -S 00:00 -s 00:01; '
          + 'fi; '
          + 'exit 0',
            "sh", applier.nightOn ? "true" : "false",
            String(Math.round(applier.nightTemp)), applier.nightWhen];
        night.running = true;
    }

    // ── the frost (Frost.qml; Settings ▸ Windowing) ─────────────────────
    // Read from the same store as everything else here so the compositor half
    // and the shell half of the feature can never disagree about whether it
    // is on. Prefs.qml exposes the same key to the panes themselves.
    readonly property bool frostOn: SettingsStore.boolValue("frost_enabled", false)

    // ── cursor ──────────────────────────────────────────────────────────
    // Empty theme means "whatever the system already has" — a fresh install
    // must not be forced onto a theme name that may not be installed, which
    // would leave the pointer as an X, or invisible.
    readonly property string cursorTheme: SettingsStore.stringValue("cursor_theme", "")
    readonly property int    cursorSize:  SettingsStore.numberValue("cursor_size", 24)

    function _b(v) { return v ? "true" : "false"; }

    // Everything, in one batch. Rebuilt from the current values each time
    // rather than diffed: sixteen keywords is a millisecond, and a diff is a
    // second model of the state that can disagree with the first one.
    function _batch() {
        var k = [];
        k.push("keyword input:sensitivity " + applier.sensitivity.toFixed(3));
        k.push("keyword input:accel_profile " + applier.accelProfile);
        k.push("keyword input:natural_scroll " + applier._b(applier.naturalScroll));
        k.push("keyword input:scroll_factor " + applier.scrollFactor.toFixed(2));
        k.push("keyword input:left_handed " + applier._b(applier.leftHanded));
        k.push("keyword input:follow_mouse " + applier.followMouse);

        k.push("keyword input:touchpad:natural_scroll " + applier._b(applier.tpNatural));
        k.push("keyword input:touchpad:tap-to-click " + applier._b(applier.tpTap));
        k.push("keyword input:touchpad:disable_while_typing " + applier._b(applier.tpDwt));
        k.push("keyword input:touchpad:scroll_factor " + applier.tpScroll.toFixed(2));

        // A layout that does not exist leaves you unable to type, and you
        // cannot type your way out of it. Anything that is not a plain XKB
        // name is refused here rather than handed to the compositor.
        //
        // The shape test alone is NOT enough, and `custom` is the proof: it is
        // six lowercase letters, so it passes the regex, but xkeyboard-config
        // advertises it in rules/base.lst while shipping no symbols/custom
        // file, so it can never compile —
        //     xkbcli compile-keymap --layout custom
        //     -> [XKB-661] Couldn't process include statement for 'custom'
        // and that is exactly the `layout='custom'` failure the 2026-08-17
        // boot audit caught coming out of systemd-localed. SetPageKeyboard.qml
        // no longer offers it, but a settings file written by an older build
        // can still carry it, so the guard that exists to stop an untypable
        // keyboard has to reject it by name too.
        if (/^[a-z]{2,8}(,[a-z]{2,8})*$/.test(applier.kbLayout)
            && applier.kbLayout.split(",").indexOf("custom") === -1)
            k.push("keyword input:kb_layout " + applier.kbLayout);
        else
            console.warn("HyprApply: refusing kb_layout '" + applier.kbLayout
                         + "' — not an XKB layout name. Keeping the current layout.");
        k.push("keyword input:kb_variant " + applier.kbVariant);
        k.push("keyword input:repeat_rate " + applier.kbRate);
        k.push("keyword input:repeat_delay " + applier.kbDelay);
        k.push("keyword input:numlock_by_default " + applier._b(applier.kbNumlock));

        // Same shape-guard idea as kb_layout: only the three values the
        // page offers may reach the compositor.
        if (/^[012]$/.test(applier.vrr))
            k.push("keyword misc:vrr " + applier.vrr);


        // ── THE FROST's compositor half (Frost.qml) ─────────────────────
        //
        // `layerrule = blur on, match:namespace nyxus-frost` is a NO-OP
        // unless the global blur pass exists. Measured both ways with the
        // layerrule installed and only this global moved (docs/proof/
        // frost-0831, captures F and G): off → under-pane edge energy 41.8,
        // the text under the pane fully legible, the panes do nothing at all;
        // on → 2.9, destroyed. So the feature's switch has to reach here.
        //
        // ⚠ IT IS APPLIED FROM HERE RATHER THAN SHIPPED IN THE CONF, and that
        // is the whole point. The owner turned `decoration:blur:enabled` OFF
        // on 2026-08-12 and `nyxus-hyprland-blur.conf` still says `false` —
        // untouched, his ruling intact and still the boot default. Shipping
        // `true` in that file would have turned a GPU pass back on for
        // everyone to serve a feature that defaults to OFF. Instead the pass
        // exists only while the frost is actually switched on, which is what
        // this file was built to do: "the truth lives in settings.json and the
        // SHELL is what applies it."
        //
        // `ignore_opacity` goes FALSE with it, and that is what keeps his
        // ruling honoured in effect rather than only in the file. His
        // complaint was that every window read as frosted — "if we could take
        // off the thing that makes all the tabs open blurred too" — and
        // `ignore_opacity = true` is what caused it: it blurs behind a window
        // no matter how opaque that window is. Every window in this build is
        // ruled `opacity 1.0 1.0` by nyxus-hyprland-opacity.conf, so with this
        // false there is nothing translucent for the pass to act on and no
        // window can frost. Captures J and K are that control: the same two
        // opaque windows with the pass off and on measure 52.195 and 52.195,
        // identical to three decimals.
        //
        // Written on BOTH edges — true when on, false when off — because a
        // keyword beats the config file for the life of the session. Writing
        // only the `true` would leave the pass on after the user turned the
        // feature off, until the next login, and it would look like the
        // setting did not work.
        k.push("keyword decoration:blur:enabled " + applier._b(applier.frostOn));
        k.push("keyword decoration:blur:ignore_opacity " + applier._b(!applier.frostOn));
        // xray true would make the panes sample the WALLPAPER instead of the
        // window under them — the window disappears and you are back at the
        // transparency defect the frost replaces. hyprland.conf sets it true
        // globally; this pins it false whenever the frost is live. The
        // per-namespace layerrule says the same thing, deliberately twice.
        if (applier.frostOn)
            k.push("keyword decoration:blur:xray false");

        return k.join(" ; ");
    }

    function apply() { settle.restart(); }

    // A slider drag changes the store on every step. The store debounces its
    // FILE write; this debounces the COMPOSITOR write, and they are different
    // budgets — 120 ms keeps the pointer feeling live under the finger while
    // still collapsing a drag into a handful of calls.
    Timer {
        id: settle
        interval: 120
        repeat: false
        onTriggered: {
            // Before the `batch.running` bail-out below, not after: the
            // warmth is a separate process and has no reason to be skipped
            // because an hyprctl batch happens to be in flight. Guarded by
            // `_nightSpec` (see applyNight), so running it on every settle
            // costs nothing when nothing about the warmth changed.
            applier.applyNight();
            if (batch.running)
                return;
            batch.command = ["hyprctl", "--batch", applier._batch()];
            batch.running = true;
            applier._applyCursor();
        }
    }

    Process {
        id: batch
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                var m = String(this.text).trim();
                if (m !== "")
                    console.warn("HyprApply: hyprctl — " + m);
            }
        }
    }

    // The cursor is a separate call because `setcursor` is not a keyword — it
    // reloads the theme and resizes the pointer, and Hyprland also needs the
    // two environment variables so that XWayland and GTK clients follow. The
    // env write is what makes an application launched AFTER the change agree
    // with the shell; already-running ones keep the old pointer until they
    // restart, which is a Wayland fact rather than a bug here.
    Process {
        id: cursorProc
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                var m = String(this.text).trim();
                if (m !== "")
                    console.warn("HyprApply: setcursor — " + m);
            }
        }
    }

    function _applyCursor() {
        if (applier.cursorTheme === "" || cursorProc.running)
            return;
        cursorProc.command = ["hyprctl", "--batch",
            "keyword env XCURSOR_THEME," + applier.cursorTheme
          + " ; keyword env XCURSOR_SIZE," + applier.cursorSize
          + " ; setcursor " + applier.cursorTheme + " " + applier.cursorSize];
        cursorProc.running = true;
    }

    // Apply once the store has actually read the file. Applying before that
    // would push the shipped defaults over whatever the user saved, one second
    // before reading what they saved — briefly, visibly, every login.
    Connections {
        target: SettingsStore
        function onLoadedChanged() { if (SettingsStore.loaded) applier.apply(); }
        function onCommitted(keys) { applier.apply(); }
    }
}
