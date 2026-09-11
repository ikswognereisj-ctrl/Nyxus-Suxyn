pragma Singleton
// Nyxus Suxyn — WHAT THIS MACHINE'S HARDWARE EXPOSES.            TRK-3693
//
// The QML side of `/usr/local/bin/nyxus-hwcaps`. The script does the
// looking; this holds the answer and offers it as properties a page can
// bind to. Nothing here knows a vendor name, and that is the design:
//
//   "how would we know what a machine will have to whoever downloads it
//    theres alot of machines out there"                (owner, 2026-09-01)
//
// We do not know, and a device table would be a lie the day after it was
// written. The kernel has already matched the DMI strings and loaded
// msi_ec / dell_smm_hwmon / thinkpad_acpi / asus_wmi by the time the shell
// starts; whatever that driver exposed is in /sys, and /sys is the only
// thing this build reads. On the machine this was written on that yields
// four fan tachometers and NO writable pwm — so the page shows fan
// readings and says, in words, that this hardware does not offer fan
// control. On somebody's ThinkPad the same code will find a charge
// threshold it can write and a keyboard light, with nothing changed.
//
// ── the rule this exists to keep ────────────────────────────────────────
// Every system feature gets a real, working, themed, no-terminal setting —
// and NEVER A DEAD TOGGLE. So every capability answers in three states,
// never two: settable, present-but-read-only, absent. `canSet(x)` is the
// only thing a control should ever be enabled by.
//
// ── why a singleton and not per-page state ──────────────────────────────
// The probe is a subprocess. Two consumers (the page, and later anything
// in the bar that wants to know whether fan control exists) must not each
// spawn one, and the page must not re-probe on every navigation. The
// refresh TIMER runs only while something is watching — `watch()` /
// `unwatch()` — so an idle machine with Settings closed runs nothing at
// all, which is the same shape UsbWatch's monitor uses.
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: caps

    // The whole capability document, exactly as `nyxus-hwcaps --json`
    // printed it. Kept whole rather than unpacked into thirty properties:
    // the script is the schema, and a page that reads `caps.doc.thermal`
    // cannot drift from it the way a hand-copied mirror does.
    property var doc: ({})

    // False until the first probe has come back — so the page can tell
    // "this machine has no fans" from "we have not looked yet". That
    // distinction is the whole difference between an honest empty state
    // and a wrong one.
    property bool probed: false
    property bool busy: false

    // Non-empty when the last probe or write failed, in words a person can
    // act on. Shown on the page; never swallowed.
    property string lastError: ""
    property string lastNote: ""

    // TRK-3435 — shipped-first PATH, composed in QML and applied through
    // `env`, so argv never crosses a shell. It governs which copy of the
    // helper runs AND which copy pkexec elevates, since pkexec resolves a
    // bare program name through the CALLER's path. Ruling:
    // SetPageBackup.qml; the same line is in SetPageAccount.qml.
    readonly property string execPath: "PATH="
        + (Quickshell.env("NYXUS_BIN_DIR") || "/usr/local/bin")
        + ":" + Quickshell.env("PATH")

    // ── the three-state answers ─────────────────────────────────────────
    // `has` = the kernel exposes it at all.  `canSet` = a write can land,
    // either because this user may write the node or because root may and
    // pkexec is here to become root. A control is enabled by canSet and
    // ONLY by canSet.
    function _settable(o) {
        if (!o || o.present !== true)
            return false;
        return o.writable === true
                || (o.root_writable === true && caps.hasPkexec);
    }

    readonly property bool hasPkexec: caps.doc && caps.doc.tools
                                      ? caps.doc.tools.pkexec === true : false

    readonly property var backlights: caps.doc.backlight || []
    readonly property var fans: caps.doc.thermal ? (caps.doc.thermal.fans || []) : []
    readonly property var temps: caps.doc.thermal ? (caps.doc.thermal.temps || []) : []
    readonly property var pwm: caps.doc.thermal ? (caps.doc.thermal.pwm || []) : []
    readonly property var pwmWritable: caps.doc.thermal
                                       ? (caps.doc.thermal.pwm_writable || []) : []
    readonly property var kbdLeds: caps.doc.leds ? (caps.doc.leds.keyboard || []) : []
    readonly property var batteries: caps.doc.battery || []
    readonly property var vendorModules: caps.doc.vendor
                                         ? (caps.doc.vendor.modules || []) : []
    readonly property var providers: caps.doc.providers || ({})

    // ── the cpufreq / firmware-profile capabilities ─────────────────────
    // TRK-3745. These three used to be read as `caps.doc.cpufreq.epp.present`
    // — objects carrying a `present` flag. The helper has never emitted that.
    // It emits `epp` and `governor` as PLAIN STRINGS beside `epp_available` /
    // `governor_available`, and `platform_profile` as
    // `{ current, choices, writable }`. So every `.present` read `undefined`,
    // `hasEpp` / `hasGovernor` / `hasProfile` were permanently false, and this
    // machine — which has all three, and which the helper reports as writable
    // — was told in words that it had none of them. The 2026-09-08 settings
    // audit caught it on screen: three greyed rows, one of them reading "This
    // machine has no cpufreq governor" while /sys held `scaling_governor`.
    //
    // The script is the schema (see this file's header), so the QML is what
    // moves. These properties normalise the helper's REAL output into the
    // { present, value, choices, writable, root_writable } shape `_settable`
    // and the page's three states are written against — in ONE place, so
    // nothing below and nothing on the page touches the raw document.
    //
    // On `writable`: the helper reports `writable: true` for cpufreq and for
    // platform_profile when the NODE EXISTS, not when this user may write it.
    // Those nodes are root-owned on every machine, and the helper elevates
    // ITSELF through pkexec to write them. So node-exists maps to
    // `root_writable`, which is exactly the gate `_settable` already applies
    // (`root_writable === true && hasPkexec`) and exactly what the write path
    // then does. `user_writable` is read too, so that if the helper ever
    // starts reporting real per-user writability this side already honours it.
    function _cpufreqCap(current, available) {
        if (current === null || current === undefined || String(current) === "")
            return undefined;
        var c = caps.doc.cpufreq || ({});
        var raw = available || [];
        var ch = [];
        for (var i = 0; i < raw.length; ++i) {
            // `custom` appears in energy_performance_available_preferences on
            // amd_pstate and cannot be written back — the kernel answers
            // EINVAL. An option that can never apply is a dead control, which
            // is the one thing this page exists not to ship.
            if (String(raw[i]) === "custom")
                continue;
            ch.push(String(raw[i]));
        }
        return {
            present: true,
            value: String(current),
            choices: ch,
            writable: c.user_writable === true,
            root_writable: c.writable === true,
            policies: c.policies === undefined ? 0 : c.policies
        };
    }

    readonly property var epp: caps.doc.cpufreq
        ? caps._cpufreqCap(caps.doc.cpufreq.epp, caps.doc.cpufreq.epp_available)
        : undefined
    readonly property var governor: caps.doc.cpufreq
        ? caps._cpufreqCap(caps.doc.cpufreq.governor, caps.doc.cpufreq.governor_available)
        : undefined

    readonly property var platformProfile: {
        var p = caps.doc.platform_profile;
        if (!p || p.current === null || p.current === undefined)
            return undefined;
        return {
            present: true,
            value: String(p.current),
            choices: p.choices || [],
            writable: p.user_writable === true,
            root_writable: p.writable === true
        };
    }

    readonly property bool hasBacklight: caps.backlights.length > 0
    readonly property bool canSetBacklight:
        caps.hasBacklight && (caps.backlights[0].writable === true
                              || (caps.backlights[0].root_writable === true && caps.hasPkexec))

    // The panel's level as a percentage of its OWN maximum. The helper emits
    // raw `value` / `max` (65535 on this amdgpu panel) and no `percent`; the
    // page's slider is 5-100 and every write leaves as a percentage. So the
    // conversion lives here and on the helper's write side — never half in
    // each, which is how `backlights[0].percent` came to be `undefined` and
    // how a percentage came to be written raw into a 65535-wide node.
    readonly property int backlightPercent: {
        if (!caps.hasBacklight)
            return 100;
        var b = caps.backlights[0];
        var mx = b.max > 0 ? b.max : 0;
        if (mx === 0)
            return 100;
        return Math.max(0, Math.min(100, Math.round((b.value || 0) * 100 / mx)));
    }

    readonly property bool hasProfile: caps.platformProfile
                                       ? caps.platformProfile.present === true : false
    readonly property bool canSetProfile: caps._settable(caps.platformProfile)

    readonly property bool hasEpp: caps.epp ? caps.epp.present === true : false
    readonly property bool canSetEpp: caps._settable(caps.epp)

    readonly property bool hasGovernor: caps.governor ? caps.governor.present === true : false
    readonly property bool canSetGovernor: caps._settable(caps.governor)

    readonly property bool hasFanReadings: caps.fans.length > 0
    readonly property bool canSetFan: caps.pwmWritable.length > 0

    // ── what the fans are ACTUALLY doing ────────────────────────────────
    // TRK-3745 gave this control its first real read-back; TRK-3962 moves the
    // derivation OUT of here and into `nyxus-hwcaps`, which is where it
    // belongs: the helper owns the duty→mode table, so a second copy of that
    // arithmetic in QML would drift the moment a duty moved. This side now
    // reads the answer.
    //
    // Two facts from the measurement that this file used to get wrong:
    //
    //   * `pwm1` reads back correctly (255) while the channel is MANUAL and
    //     reads EMPTY under firmware control. The old code judged partly by
    //     the duty, so the normal state produced an unreadable number and the
    //     read-back looked broken. `pwm*_enable` is the authority.
    //   * "full" is not a mode this hardware really has one of — see the step
    //     table in `nyxus-hwcaps`. The modes are auto / low / high / max.
    //
    // `""` still means a state this control cannot name; the choice then
    // shows NOTHING selected rather than picking a segment, because
    // highlighting a wrong segment is the same lie the static literal was.
    readonly property string fanMode: caps.doc.thermal
                                      ? (caps.doc.thermal.fan_mode || "") : ""

    // Manual, at a duty this control did not put there. Worth naming on the
    // page: it is exactly the state the pre-TRK-3745 fan write could leave a
    // machine in — handed to userspace with no speed ever written.
    readonly property bool fanManualUnknown: caps.doc.thermal
        ? caps.doc.thermal.fan_manual_unknown === true : false

    // The mode table as the helper publishes it — `{ value, duty, rpm }`,
    // where `rpm` is what THIS machine's tachometers were measured reading in
    // that mode, or null if it has never been run here. The page prints a
    // number only where one exists; it never invents one for hardware it has
    // not seen. See the "learned on THIS machine" note in `nyxus-hwcaps`.
    readonly property var fanModes: caps.doc.thermal
                                    ? (caps.doc.thermal.fan_modes || []) : []
    readonly property int fanRpmNow: caps.doc.thermal
                                     ? (caps.doc.thermal.fan_rpm_now || 0) : 0

    // Observed rpm for one mode, or 0. Used for the labels on the picker.
    function fanRpmFor(mode) {
        for (var i = 0; i < caps.fanModes.length; ++i)
            if (caps.fanModes[i].value === mode)
                return caps.fanModes[i].rpm || 0;
        return 0;
    }

    readonly property bool hasKbdLed: caps.kbdLeds.length > 0
    readonly property bool canSetKbdLed:
        caps.hasKbdLed && (caps.kbdLeds[0].writable === true
                           || (caps.kbdLeds[0].root_writable === true && caps.hasPkexec))

    // Same reasoning as backlightPercent: `max_brightness` on a keyboard LED
    // is usually 2 or 3, the slider is 0-100, and the helper emits no
    // `percent` — so the raw number was rendering as `undefined`.
    readonly property int kbdLedPercent: {
        if (caps.kbdLeds.length === 0)
            return 0;
        var l = caps.kbdLeds[0];
        var mx = l.max > 0 ? l.max : 0;
        if (mx === 0)
            return 0;
        return Math.max(0, Math.min(100, Math.round((l.value || 0) * 100 / mx)));
    }

    // TRK-3745. Was `limit_supported` / `limit_settable` / `end_threshold.value`
    // — three field names the helper has never emitted. It emits
    // `{ name, capacity, status, end_threshold, end_writable }`, where
    // `end_threshold` is an integer or null and `end_writable` says whether
    // the node exists at all. On the audited machine the node does not exist,
    // so the answer on screen is unchanged ("this battery exposes no charge
    // threshold") — but it was right by accident, and on a ThinkPad the old
    // code hid a threshold that does work.
    readonly property var chargeBattery: {
        for (var i = 0; i < caps.batteries.length; ++i)
            if (caps.batteries[i].end_writable === true)
                return caps.batteries[i];
        return undefined;
    }
    readonly property bool hasChargeLimit: caps.chargeBattery !== undefined
    // The threshold node is root-owned; the helper elevates itself through
    // pkexec, so this is settable exactly when pkexec is here to do it.
    readonly property bool canSetChargeLimit: caps.hasChargeLimit && caps.hasPkexec
    readonly property int chargeLimit: {
        var b = caps.chargeBattery;
        if (!b || b.end_threshold === null || b.end_threshold === undefined)
            return 100;
        var v = parseInt(b.end_threshold, 10);
        // A threshold reading 0 is the driver saying "no limit set", not a
        // limit of zero. Showing 0 would invite you to believe the battery
        // stops charging the moment it is plugged in.
        return (isNaN(v) || v <= 0) ? 100 : v;
    }
    readonly property bool chargeLimitIsZero: {
        var b = caps.chargeBattery;
        return b !== undefined && b.end_threshold === 0;
    }

    // The hottest sensor, or -1 when this machine reports none in a
    // plausible range. `-1` and not `0`: 0 °C is a temperature.
    readonly property real hottest: caps.doc.thermal
                                    && caps.doc.thermal.hottest !== null
                                    && caps.doc.thermal.hottest !== undefined
                                    ? caps.doc.thermal.hottest : -1

    // True when the helper itself is missing — a development tree, or an
    // install where /usr/local/bin was not staged. The page says exactly
    // that rather than drawing an empty machine, because "no capabilities"
    // and "nothing asked" look identical on screen and are not the same.
    property bool helperMissing: false

    // ── probing ─────────────────────────────────────────────────────────
    // `silent` is not a nicety. `busy` drives SetButton's spinner AND its
    // "Done" acknowledgement, which fires on the falling edge — so a
    // background poll that raised `busy` made the Re-detect button flash
    // "Done" every four seconds, acknowledging an action nobody took.
    // Caught in the first capture (docs/proof/hardware-0901). A poll is
    // not the user waiting for something, and must not say it is.
    function refresh(silent) {
        if (prober.running)
            return;
        if (silent !== true)
            caps.busy = true;
        prober.running = true;
    }

    Process {
        id: prober
        running: false
        command: ["env", caps.execPath, "nyxus-hwcaps", "--json"]

        stdout: StdioCollector {
            onStreamFinished: {
                var raw = String(this.text).trim();
                if (raw === "")
                    return;
                try {
                    caps.doc = JSON.parse(raw);
                    caps.probed = true;
                    caps.helperMissing = false;
                    caps.lastError = "";
                } catch (e) {
                    // A parse failure wearing the costume of a reading is
                    // the defect this project has caught before (the
                    // usbguard status panel drew "0 devices" off a broken
                    // document). Say it instead of defaulting to empty.
                    caps.lastError = "The hardware probe returned something "
                                   + "that is not JSON. Nothing below is trustworthy.";
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                var e = String(this.text).trim();
                if (e !== "")
                    console.warn("HardwareCaps: " + e);
            }
        }

        onExited: function (code) {
            caps.busy = false;
            if (code === 127 || (code !== 0 && !caps.probed)) {
                caps.helperMissing = code === 127;
                if (caps.lastError === "")
                    caps.lastError = code === 127
                        ? "nyxus-hwcaps is not installed on this machine."
                        : "The hardware probe exited " + code + ".";
            }
        }
    }

    // ── writing ─────────────────────────────────────────────────────────
    // One entry point. The helper decides whether the write needs root and
    // elevates itself through pkexec — the page never builds a pkexec
    // command line, so there is one privilege path for hardware and it is
    // the one the rest of this build already uses.
    function apply(target, value) {
        if (writer.running) {
            caps.lastNote = "Still applying the last change.";
            return;
        }
        caps.lastError = "";
        caps.lastNote = "";
        writer.target = target;
        writer.value = String(value);
        caps.busy = true;
        writer.running = true;
    }

    Process {
        id: writer
        running: false
        property string target: ""
        property string value: ""
        command: ["env", caps.execPath, "nyxus-hwcaps", "set",
                  writer.target, writer.value]

        stderr: StdioCollector {
            onStreamFinished: {
                var e = String(this.text).trim();
                if (e !== "")
                    caps.lastError = e.replace("nyxus-hwcaps: ", "");
            }
        }

        onExited: function (code) {
            caps.busy = false;
            // Always re-probe, success or failure. The value the page shows
            // is then what the kernel says, never what we asked for — a
            // write that "succeeded" while the value did not move is the
            // failure this build keeps finding, and the only defence is to
            // read back rather than to assume.
            if (code === 0 && caps.lastError === "")
                caps.lastNote = "Applied.";
            else if (caps.lastError === "")
                caps.lastError = "The change did not go through (exit " + code + ").";
            caps.refresh();
        }
    }

    // ── the watch ───────────────────────────────────────────────────────
    // Fan speed and temperature move; a page showing a frozen number is
    // lying quietly. But nothing may poll while nobody is looking, so the
    // timer is reference-counted by the surfaces that want it.
    property int watchers: 0
    function watch() { caps.watchers += 1; caps.refresh(); }
    function unwatch() { caps.watchers = Math.max(0, caps.watchers - 1); }

    Timer {
        interval: 4000
        repeat: true
        running: caps.watchers > 0
        onTriggered: caps.refresh(true)
    }
}
