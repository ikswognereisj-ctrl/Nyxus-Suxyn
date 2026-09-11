pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ Devices ▸ This machine's hardware.       MODULE 3.
//
// The surface for `HardwareCaps.qml`, which is the surface for
// `/usr/local/bin/nyxus-hwcaps`. Read that script's header for why there is
// no vendor database anywhere in this build.
//
// ── what this page is FOR ───────────────────────────────────────────────
// Somebody downloads this ISO and puts it on a laptop nobody here has ever
// touched. The owner's question was exactly that: *"how would we know what
// a machine will have to whoever downloads it theres alot of machines out
// there"*. This page's answer is that it does not know until it looks, and
// it looks every time it opens.
//
// So EVERY card below has two renderings — the control, and the sentence
// that replaces it. Which one you get is decided by `HardwareCaps.canSetX`,
// never by a model name, never by a driver being loaded. A loaded driver is
// not a capability: `msi_ec` is loaded on the machine this was written on
// and the fans are still not controllable from userspace.
//
// ── never ship a dead toggle ────────────────────────────────────────────
// The standing rule is that every system feature gets a real, working,
// themed, no-terminal setting. Its corollary is the harder half: a control
// that looks functional and is not is WORSE than an absent one, because the
// person believes the machine did what they asked. Hence `SetRow.available`
// with an `unavailableReason` that names the actual reason — "this hardware
// exposes no writable pwm" — rather than a greyed row with no explanation,
// and hence three states everywhere: settable, read-only, absent.
//
// Writes go through the helper, which elevates ITSELF through pkexec when a
// node needs root. The page never builds a pkexec line; that is the same
// arrangement Date & time and Your account use.
import Quickshell
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    property var entry: null

    title: qsTr("This machine's hardware")
    blurb: qsTr("What this laptop actually exposes — and what it does not.")

    // The probe is cheap and the answer changes (a fan spins up, a battery
    // driver appears after a suspend). Watch while the page is open; the
    // singleton stops the timer when the last watcher leaves, so a closed
    // Settings window costs nothing.
    Component.onCompleted: HardwareCaps.watch()
    Component.onDestruction: HardwareCaps.unwatch()

    readonly property bool ready: HardwareCaps.probed
    readonly property var m: HardwareCaps.doc.machine || ({})

    // TRK-3962. The one place a fan mode gets a human name, so the picker,
    // the sub-line and any future caller cannot disagree about what "high"
    // is called. The helper's vocabulary (auto/low/high/max) is deliberately
    // machine-side and untranslated; the words a person reads are here.
    function fanLabel(mode) {
        if (mode === "auto")
            return qsTr("Automatic");
        if (mode === "low")
            return qsTr("Low");
        if (mode === "high")
            return qsTr("High");
        if (mode === "max")
            return qsTr("Maximum");
        return String(mode);
    }

    // ══ WHAT THIS MACHINE IS ═══════════════════════════════════════════
    SetCard {
        heading: qsTr("This machine")
        tone: page.tone
        note: HardwareCaps.lastError !== ""
              ? HardwareCaps.lastError
              : "Everything on this page was read from this machine just now. "
                + "Nothing here is looked up in a table of models."

        SetRow {
            title: page.ready
                   ? ((page.m.vendor || "") + " " + (page.m.product || "")).trim()
                   : qsTr("This machine")
            sub: page.ready
                 ? qsTr("Board %1 · BIOS %2").arg(page.m.board || "?").arg(page.m.bios || "?")
                 : qsTr("Reading what this machine exposes…")
        }

        SetRow {
            visible: HardwareCaps.helperMissing
            title: qsTr("Hardware detection")
            sub: qsTr("Unavailable on this system")
        }

        // What is actually driving each capability, derived from the nodes
        // themselves — not from the loaded module list, which contains
        // drivers that provide nothing you can use.
        Repeater {
            model: page.ready ? Object.keys(HardwareCaps.providers) : []
            delegate: SetRow {
                required property var modelData
                glyph: ""
                title: modelData
                sub: qsTr("Provides ") + HardwareCaps.providers[modelData].join(", ")
            }
        }

        SetRow {
            visible: page.ready
            glyph: ""
            title: qsTr("Vendor drivers the kernel loaded by itself")
            sub: HardwareCaps.vendorModules.length > 0
                 ? HardwareCaps.vendorModules.join(", ")
                     + " — matched from this machine's DMI strings at boot, "
                     + "with nothing installed for it"
                 : "None. On this machine the generic drivers are all there is, "
                   + "and the list below is what they offer."
        }
    }

    // ══ SCREEN BRIGHTNESS ══════════════════════════════════════════════
    SetCard {
        heading: qsTr("Screen brightness")
        tone: page.tone
        note: HardwareCaps.hasBacklight
              ? "Driven through " + (HardwareCaps.backlights[0].provider || "the panel driver")
                + ", the same device the brightness keys use."
              : "A backlight is a laptop panel thing. An external monitor is "
                + "controlled by its own buttons, or by DDC, which this page "
                + "does not attempt."

        SetRow {
            glyph: ""
            title: qsTr("Brightness")
            sub: HardwareCaps.hasBacklight
                 ? HardwareCaps.backlights[0].name + " · "
                   + HardwareCaps.backlights[0].value + " of "
                   + HardwareCaps.backlights[0].max
                 : ""
            available: HardwareCaps.canSetBacklight
            unavailableReason: !page.ready
                ? (HardwareCaps.helperMissing ? qsTr("Unavailable") : qsTr("Reading…"))
                : (HardwareCaps.hasBacklight
                   ? qsTr("This backlight is read-only for you and for root — nothing can move it")
                   : qsTr("This machine exposes no backlight device"))

            SetSlider {
                visible: HardwareCaps.canSetBacklight
                from: 5
                to: 100
                snap: 1
                live: false
                tone: page.tone
                suffix: "%"
                // TRK-3745: was `backlights[0].percent`, a field the helper
                // has never emitted — the slider bound to `undefined`. The
                // helper emits raw value/max; HardwareCaps does the division
                // once, and the helper scales the percentage back to the
                // panel's range on the way in.
                value: HardwareCaps.backlightPercent
                // `live: false` on purpose — every emission is a process.
                onReleased: function (v) { HardwareCaps.apply("backlight", Math.round(v)); }
            }
        }
    }

    // ══ PERFORMANCE ════════════════════════════════════════════════════
    // Three different mechanisms, and a machine may have any, all or none:
    //
    //   platform_profile  the firmware's own modes (quiet/balanced/perf).
    //                     ThinkPads, most Dells, newer HPs. NOT this MSI.
    //   EPP               intel_pstate / amd_pstate's hint to the silicon.
    //   governor          the classic cpufreq governor.
    //
    // They are shown separately because they ARE separate, and a page that
    // folds them into one "Performance" switch is guessing which one is
    // present. Power profiles (power-profiles-daemon) stay on the Power
    // page — that is the friendly front end; this is the hardware truth
    // underneath it.
    SetCard {
        heading: qsTr("Performance and power")
        tone: page.tone
        note: qsTr("Three different mechanisms. Which of them exists is up to the ")
              + "firmware and the CPU driver, so this card shows only the ones "
              + "this machine actually has."

        SetRow {
            glyph: ""
            title: qsTr("Firmware performance mode")
            sub: HardwareCaps.hasProfile
                 ? qsTr("Set in the firmware itself — quiet, balanced, performance")
                 : ""
            available: HardwareCaps.canSetProfile
            unavailableReason: !page.ready
                ? (HardwareCaps.helperMissing ? qsTr("Unavailable") : qsTr("Reading…"))
                : (HardwareCaps.hasProfile
                   ? qsTr("Exposed but read-only on this firmware")
                   : qsTr("This firmware has no ACPI platform profile — most gaming laptops do not"))

            SetChoice {
                id: profileChoice
                visible: HardwareCaps.canSetProfile
                tone: page.tone
                // TRK-3462's trap, on the other side of the kit: in
                // key-less mode `SetChoice.select()` ASSIGNS `value`, and a
                // JS assignment destroys the `value:` binding underneath
                // it. Without this the control would keep showing what you
                // clicked even when the kernel refused it — the exact "a
                // write that succeeded while the value did not move" lie
                // this page is built to avoid. Re-assert the kernel's
                // answer every time the probe comes back.
                Connections {
                    target: HardwareCaps
                    function onDocChanged() {
                        profileChoice.value = HardwareCaps.platformProfile
                                              ? HardwareCaps.platformProfile.value : "";
                    }
                }
                options: {
                    var out = [];
                    var ch = HardwareCaps.platformProfile
                             ? (HardwareCaps.platformProfile.choices || []) : [];
                    for (var i = 0; i < ch.length; ++i)
                        out.push({ value: ch[i], label: ch[i] });
                    return out;
                }
                value: HardwareCaps.platformProfile
                       ? HardwareCaps.platformProfile.value : ""
                onChosen: function (v) { HardwareCaps.apply("platform-profile", v); }
            }
        }

        SetRow {
            glyph: ""
            title: qsTr("Energy preference")
            // TRK-3745: both halves of this line were reading fields that did
            // not exist. `policies` and `driver` are now probed and emitted;
            // each half is still guarded, so an older helper renders a shorter
            // sentence rather than the word `undefined`.
            sub: {
                if (!HardwareCaps.hasEpp)
                    return "";
                var c = HardwareCaps.doc.cpufreq || ({});
                var bits = [];
                if (c.policies > 0)
                    bits.push(c.policies + qsTr(" CPU policies, all set together"));
                if (c.driver)
                    bits.push(String(c.driver));
                return bits.join(" · ");
            }
            available: HardwareCaps.canSetEpp
            unavailableReason: !page.ready
                ? (HardwareCaps.helperMissing ? qsTr("Unavailable") : qsTr("Reading…"))
                : (HardwareCaps.hasEpp
                   ? qsTr("Exposed but nothing may write it")
                   : qsTr("This CPU driver offers no energy preference"))

            SetChoice {
                id: eppChoice
                visible: HardwareCaps.canSetEpp
                tone: page.tone
                segmentLimit: 2
                // See profileChoice: the control follows the kernel, not
                // the click.
                Connections {
                    target: HardwareCaps
                    function onDocChanged() {
                        eppChoice.value = HardwareCaps.epp ? HardwareCaps.epp.value : "";
                    }
                }
                options: {
                    var out = [];
                    var ch = HardwareCaps.epp ? (HardwareCaps.epp.choices || []) : [];
                    for (var i = 0; i < ch.length; ++i)
                        out.push({ value: ch[i], label: ch[i].replace(/_/g, " ") });
                    return out;
                }
                value: HardwareCaps.epp ? HardwareCaps.epp.value : ""
                onChosen: function (v) { HardwareCaps.apply("epp", v); }
            }
        }

        SetRow {
            glyph: ""
            title: qsTr("CPU governor")
            sub: HardwareCaps.hasGovernor
                 ? qsTr("The scheduler's clock policy. Performance holds clocks up; powersave lets them fall.")
                 : ""
            available: HardwareCaps.canSetGovernor
            unavailableReason: !page.ready
                ? (HardwareCaps.helperMissing ? qsTr("Unavailable") : qsTr("Reading…"))
                : (HardwareCaps.hasGovernor
                   ? qsTr("Exposed but nothing may write it")
                   : qsTr("This machine has no cpufreq governor"))

            SetChoice {
                id: govChoice
                visible: HardwareCaps.canSetGovernor
                tone: page.tone
                // See profileChoice.
                Connections {
                    target: HardwareCaps
                    function onDocChanged() {
                        govChoice.value = HardwareCaps.governor
                                          ? HardwareCaps.governor.value : "";
                    }
                }
                options: {
                    var out = [];
                    var ch = HardwareCaps.governor
                             ? (HardwareCaps.governor.choices || []) : [];
                    for (var i = 0; i < ch.length; ++i)
                        out.push({ value: ch[i], label: ch[i] });
                    return out;
                }
                value: HardwareCaps.governor ? HardwareCaps.governor.value : ""
                onChosen: function (v) { HardwareCaps.apply("governor", v); }
            }
        }

        SetRow {
            glyph: ""
            title: qsTr("Power profiles")
            sub: qsTr("Saver / Balanced / Performance, through power-profiles-daemon")
            navigates: true
            onActivated: Bus.openSettings("power")
        }
    }

    // ══ FANS AND HEAT ══════════════════════════════════════════════════
    // The sharp case, and the reason this page exists in this shape: this
    // machine reports four fan speeds and cannot be told to change any of
    // them. Reading a tachometer is not controlling a fan, and a build that
    // conflates them ships a slider that does nothing.
    SetCard {
        heading: qsTr("Fans and heat")
        tone: page.tone
        note: HardwareCaps.hasFanReadings
              ? "Read straight from hwmon, refreshed while this page is open."
              : "No fan tachometer is exposed. Fanless, or the firmware keeps "
                + "the fans to itself — from userspace those look the same."

        SetRow {
            visible: HardwareCaps.hottest >= 0
            title: qsTr("Hottest sensor")
            sub: HardwareCaps.temps.length + qsTr(" temperature sensors across the machine")
            valueText: HardwareCaps.hottest + "°C"
        }

        // TRK-3745. This delegate read `modelData.label` and `modelData.chip`.
        // The helper emits one fan as `{ "name": "dell_smm:fan1_input",
        // "rpm": 2451 }` — no label, no chip — so every row on the audited
        // machine drew the literal word `undefined` next to a correct rpm.
        // The chip and the tachometer are both inside `name`, either side of
        // the colon the helper joins them with (`f"{label}:{basename}"`), so
        // the split happens here rather than adding two fields the probe
        // would have to keep in step.
        Repeater {
            model: HardwareCaps.fans
            delegate: SetRow {
                required property var modelData
                readonly property string fanName: String(modelData.name || "")
                readonly property int fanCut: fanName.indexOf(":")
                readonly property string fanChip: fanCut > 0 ? fanName.substring(0, fanCut) : ""
                glyph: ""
                // "dell_smm:fan1_input" → "Fan 1", falling back to whatever
                // the node is actually called if it is not numbered.
                title: {
                    var leaf = fanCut >= 0 ? fanName.substring(fanCut + 1) : fanName;
                    var m = leaf.match(/^fan([0-9]+)/);
                    return m ? qsTr("Fan ") + m[1] : (leaf === "" ? qsTr("Fan") : leaf);
                }
                sub: fanChip + (modelData.rpm === 0
                     ? qsTr(" · stopped — a fan at rest, not a missing fan")
                     : "")
                valueText: modelData.rpm + " rpm"
            }
        }

        // ── TRK-3745 / TRK-3962 · THE DANGEROUS ONE ────────────────────
        // This control once offered Automatic / 50% / 75% / 100%. The helper
        // understood exactly two fan values: it wrote pwm*_enable = 2 for
        // "auto" and = 1 (manual) for ANYTHING else, and it wrote an actual
        // duty cycle only for the literal string "full" — which this page
        // could not send. So picking 50% handed the fans from the firmware to
        // userspace and then set no speed at all, on a machine with two
        // writable pwm channels, while the page said "Applied."
        //
        // TRK-3745 deleted the percentages rather than pretend, because
        // nobody had measured what a duty cycle DOES here. TRK-3962 measured
        // it on the owner's Alienware — the table is at the top of
        // `nyxus-hwcaps` — and the measurement is why they are never coming
        // back:
        //
        //     pwm 128 → 2458 rpm     pwm 223 → register reads back 255
        //     pwm 160 → 2457 rpm     pwm 255 → 6756 rpm
        //     pwm 191 → 2458 rpm
        //
        // 128, 160 and 191 are one fan speed, and 223 is not a speed at all —
        // dell-smm-hwmon stores a LEVEL, not a duty, so 223 rounds into the
        // same level as 255. A percentage slider here would be a dial whose
        // middle two thirds do nothing. The hardware has two manual speeds
        // and firmware control, and that is what this page shows on it.
        //
        // NOTHING about that is written into this file. The picker is built
        // from `HardwareCaps.fanModes`, which the helper derives by writing
        // each candidate duty and reading the register back — so a board with
        // a real 8-bit pwm gets Low / High / Maximum here with no change, and
        // this laptop gets Low / Maximum, because that is what it has.
        //
        // The rpm figures shown BELOW are likewise not literals: they are
        // whatever THIS machine's tachometers were seen reading in each mode
        // while the page was open. A mode nobody has run here carries no
        // number rather than borrowing the owner's laptop's.
        SetRow {
            glyph: ""
            title: qsTr("Fan speed control")
            sub: {
                if (!HardwareCaps.canSetFan)
                    return "";
                if (HardwareCaps.fanManualUnknown)
                    return qsTr("The fans are under manual control at a speed this page did not set. Automatic hands them back to the firmware.");
                var meas = [];
                for (var i = 0; i < HardwareCaps.fanModes.length; ++i) {
                    var m = HardwareCaps.fanModes[i];
                    if (m.value !== "auto" && m.rpm)
                        meas.push(page.fanLabel(m.value) + " " + m.rpm);
                }
                if (meas.length > 0)
                    return qsTr("Automatic hands the fans back to the firmware. Measured on this machine: ")
                           + meas.join(qsTr(" rpm · ")) + qsTr(" rpm.");
                return qsTr("Automatic hands the fans back to the firmware. The other three are the speed steps this hardware really has — it is not a percentage dial.");
            }
            available: HardwareCaps.canSetFan
            unavailableReason: !page.ready
                ? (HardwareCaps.helperMissing ? qsTr("Unavailable") : qsTr("Reading…"))
                : (HardwareCaps.pwm.length > 0
                   ? qsTr("This machine's pwm controls are read-only — the firmware owns the fans")
                   : qsTr("Your hardware doesn't expose fan control. The readings above are all it offers."))

            SetChoice {
                id: fanChoice
                visible: HardwareCaps.canSetFan
                tone: page.tone
                // Was a static `value: "auto"` — the one control on this card
                // without the read-back its three siblings carry, so it
                // claimed "Automatic" whatever pwm*_enable held and reset to
                // it on every reopen. Same Connections block, same reason:
                // a key-less SetChoice ASSIGNS `value` on click, destroying
                // the binding underneath it.
                Connections {
                    target: HardwareCaps
                    function onDocChanged() { fanChoice.value = HardwareCaps.fanMode; }
                }
                // Built from the helper's own table, never a literal list —
                // the helper owns which modes exist and what each one writes,
                // and a hand-copied list here is how the "full" that nothing
                // could send got into the last version of this control.
                options: {
                    var out = [];
                    for (var i = 0; i < HardwareCaps.fanModes.length; ++i) {
                        var m = HardwareCaps.fanModes[i];
                        out.push({ value: m.value, label: page.fanLabel(m.value) });
                    }
                    // Before the first probe lands there is no table yet; the
                    // control is not visible then, but an empty `options` also
                    // makes SetChoice draw its "None found" button, so give it
                    // the four names it will have.
                    if (out.length === 0)
                        out = [{ value: "auto", label: page.fanLabel("auto") },
                               { value: "low", label: page.fanLabel("low") },
                               { value: "high", label: page.fanLabel("high") },
                               { value: "max", label: page.fanLabel("max") }];
                    return out;
                }
                value: HardwareCaps.fanMode
                onChosen: function (v) { HardwareCaps.apply("fan", v); }
            }
        }
    }

    // ══ KEYBOARD LIGHT ═════════════════════════════════════════════════
    SetCard {
        heading: qsTr("Keyboard light")
        tone: page.tone
        note: qsTr("Only lights the kernel exposes as an LED device can be driven ")
              + "here. Per-key RGB on most gaming laptops is a USB protocol with "
              + "no kernel presence at all — this build ships no vendor RGB "
              + "implementation, and says so rather than drawing a colour wheel "
              + "that changes nothing."

        SetRow {
            glyph: ""
            title: qsTr("Backlight level")
            sub: HardwareCaps.hasKbdLed ? HardwareCaps.kbdLeds[0].name : ""
            available: HardwareCaps.canSetKbdLed
            unavailableReason: !page.ready
                ? (HardwareCaps.helperMissing ? qsTr("Unavailable") : qsTr("Reading…"))
                : (HardwareCaps.hasKbdLed
                   ? qsTr("This LED is exposed read-only")
                   : qsTr("No keyboard LED is exposed on this machine"))

            SetSlider {
                visible: HardwareCaps.canSetKbdLed
                from: 0
                to: 100
                snap: 1
                live: false
                tone: page.tone
                suffix: "%"
                // TRK-3745: `kbdLeds[0].percent` was never emitted either.
                // max_brightness on a keyboard LED is typically 2 or 3.
                value: HardwareCaps.kbdLedPercent
                onReleased: function (v) { HardwareCaps.apply("kbd-led", Math.round(v)); }
            }
        }
    }

    // ══ BATTERY ════════════════════════════════════════════════════════
    SetCard {
        heading: qsTr("Battery charge limit")
        tone: page.tone
        note: qsTr("Stopping the charge short of full is the single biggest thing ")
              + "you can do for a battery that lives on mains. It works only if "
              + "the firmware offers the threshold — this is not something an "
              + "operating system can impose."
              + (HardwareCaps.hasChargeLimit && !HardwareCaps.canSetChargeLimit
                 ? ""
                 : (HardwareCaps.hasChargeLimit
                    ? " Setting it asks for an administrator password, and the "
                      + "number is read back from the battery afterwards — so a "
                      + "refused write cannot look like a success."
                    : ""))

        Repeater {
            model: HardwareCaps.batteries
            delegate: SetRow {
                required property var modelData
                title: modelData.name
                sub: modelData.status
                // TRK-3745: the helper's field is `capacity`, not `percent`.
                valueText: modelData.capacity !== null
                           && modelData.capacity !== undefined
                           ? (modelData.capacity + "%") : ""
            }
        }

        SetRow {
            glyph: ""
            title: qsTr("Stop charging at")
            sub: HardwareCaps.canSetChargeLimit
                 ? qsTr("100% means no limit. 80% is the usual choice for a laptop that lives plugged in.")
                 : ""
            available: HardwareCaps.canSetChargeLimit
            unavailableReason: !page.ready
                ? (HardwareCaps.helperMissing ? qsTr("Unavailable") : qsTr("Reading…"))
                : (HardwareCaps.hasChargeLimit
                   ? qsTr("The threshold node exists but nothing may write it — the firmware decides here")
                   : qsTr("This battery exposes no charge threshold"))

            SetSlider {
                visible: HardwareCaps.canSetChargeLimit
                from: 50
                to: 100
                snap: 5
                live: false
                tone: page.tone
                suffix: "%"
                // TRK-3745: was `b.end_threshold.value` — the helper emits
                // `end_threshold` as an integer or null, so `.value` on it was
                // `undefined` (and on null, a hard TypeError). The 0-means-
                // no-limit reading moved into HardwareCaps with it.
                value: HardwareCaps.chargeLimit
                onReleased: function (v) { HardwareCaps.apply("battery-end", Math.round(v)); }
            }
        }

        SetRow {
            visible: HardwareCaps.chargeLimitIsZero
            glyph: ""
            title: qsTr("This battery reports a threshold of 0")
            sub: qsTr("Which its driver means as \"no limit\", not as \"stop at zero\". ")
                 + "It is shown as 100% above for that reason."
        }
    }

    // ══ ABOUT THIS PAGE ══════════════════════════════════════════════════
    SetCard {
        heading: qsTr("About this page")
        tone: page.tone
        // The failure of a write says more than its success, and it must be
        // readable without hunting: a denied polkit prompt, a driver that
        // refused the value. Error first, note second.
        note: HardwareCaps.lastError !== "" ? HardwareCaps.lastError
                                            : HardwareCaps.lastNote

        SetRow {
            title: qsTr("Detected, not looked up")
            sub: qsTr("Everything above is read from this machine directly — there is no list of models behind it.")
        }

        SetRow {
            title: qsTr("Read this machine again")
            sub: HardwareCaps.busy ? qsTr("Reading…")
                                   : qsTr("Nothing here is changed by reading it")

            SetButton {
                text: qsTr("Re-detect")
                tone: page.tone
                busy: HardwareCaps.busy
                onClicked: HardwareCaps.refresh()
            }
        }
    }

    // This page writes no settings keys — every control writes to the
    // hardware, and the hardware's own value is what it reads back. So
    // there is nothing here for SetResetRow to reset, and adding one would
    // imply a stored preference that does not exist.
}
