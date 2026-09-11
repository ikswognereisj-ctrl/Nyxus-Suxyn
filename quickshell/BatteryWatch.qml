pragma Singleton
// Nyxus Suxyn — the battery watch.   GAP-933, battery half.
//
// ── what was wrong ──────────────────────────────────────────────────────
// `SetPageNotifications.qml` has shipped a switch called `notify_battery`,
// defaulting ON, described to the user as "When the battery gets low, and
// when it is critically low" — and **nothing in the build read that key**.
// Measured 2026-08-15: the string `notify_battery` occurred exactly ONCE in
// the whole repository, in the line that declares the switch. The bar's
// crest changes colour at ≤15% and that was the entire warning; a laptop on
// this build ran flat with no notification of any kind.
//
// That is the same defect class as the archive app's `format` preference
// (`WIP-501`) and the Accessibility page's `wvkbd` (`GAP-950`): the parts all
// ship and nothing joins them. So the gate that pins this one pins the
// WIRING — that `notify_battery` is read here and that this file is brought
// to life by `shell.qml` — not the presence of a string.
//
// ── why a singleton in the shell, and not the Settings page ─────────────
// Same reason `UsbWatch.qml` gives: a Settings page is alive only while it
// is open, so a battery watcher living in one would warn you about the
// battery exactly when you were already looking at the battery. This is the
// "something that starts it" of HANDOFF's three-part rule.
//
// ⚠ A QML singleton is constructed on FIRST USE. `shell.qml`'s
// `Component.onCompleted` Item touches this one at startup for exactly the
// reason written there about UsbWatch — without that line the first warning
// would arrive the first time somebody opened the Notifications page, which
// is never.
//
// ── NOTHING POLLS ───────────────────────────────────────────────────────
// `Sys.batteryPercent` and `Sys.batteryCharging` are readonly properties
// bound to the UPower display device, so UPower's own D-Bus PropertiesChanged
// is what moves them and QML's generated `…Changed` signals are what wake
// this file. There is no Timer here at all — not one at 1000 ms, not one at
// any interval. HANDOFF's floor exists because two hyprlock labels spawning
// subprocesses every 50 ms starved the event loop and cost a hard reset; the
// cheapest way to obey a floor is to own no clock.
import Quickshell
import QtQuick

Singleton {
    id: watch

    // ── the shipped setting, read live ──────────────────────────────────
    // Written by `SetPageNotifications.qml` through `SettingsStore`. Read
    // here rather than passed in, so turning the warnings off takes effect
    // immediately in a running shell. The default MUST match the page's
    // `defaultValue: true` — two defaults for one key is how a switch starts
    // disagreeing with what it does.
    readonly property bool notify: SettingsStore.boolValue("notify_battery", true)

    // ── the two levels ──────────────────────────────────────────────────
    // 20 is a warning: enough charge left to finish a sentence, save, and
    // find a cable. 10 is the one that interrupts.
    readonly property int lowPercent: 20
    readonly property int criticalPercent: 10
    // Hysteresis. A battery sitting exactly on a threshold jitters across it,
    // and a warning that fires every jitter is the notification behaviour
    // people turn off and never turn back on (`UsbWatch.qml` records the same
    // reasoning for its first read). A level re-arms only once the charge has
    // climbed a real margin back above it.
    readonly property int rearmMargin: 5

    // Latches. False = this level has already been announced for this
    // discharge and must not be announced again.
    property bool lowArmed: true
    property bool criticalArmed: true

    // The first reading is the state the machine was ALREADY in when the
    // shell started. It arms the latches and announces nothing: logging in
    // with a laptop already at 8% should not throw a card, because the user
    // has not just crossed anything, and because `Sys.batteryPercent` reads 0
    // for a moment before UPower answers — which would otherwise trip both
    // levels on every single login, on desktops included.
    property bool primed: false
    property int lastPercent: -1
    property bool lastCharging: false

    // ── the route ───────────────────────────────────────────────────────
    // `Sys.notified` — NOT `Sys.urgent`. `Toasts.qml` connects to `onNotified`
    // and carries an explicit instruction not to be "fixed" back to
    // `onUrgent`, so `urgent` currently has no listener anywhere in the shell
    // (measured 2026-08-15; filed as its own row, since it means `UsbWatch`'s
    // toasts do not reach the screen either). A warning that emits down a
    // signal nobody hears is the very bug this file exists to close, so it
    // uses the one Toasts actually renders.
    //
    // Do-not-disturb: the 20% warning and the charger notice respect
    // `Sys.dnd` — they are courtesies. The CRITICAL one does not. GAP-933 is
    // "a laptop that dies with no warning", and a mode that suppressed the
    // last warning before the machine stops would reproduce exactly that
    // defect for the people most likely to be presenting when it happens.
    function _announce(summary, body, critical, soundEv) {
        // TRK-3190: one door. Critical still force-breaks Quiet (GAP-933).
        Sys.announce(summary, body, "Battery", soundEv || "notification", critical);
    }

    function _evaluate() {
        var pct = Sys.batteryPercent;
        var charging = Sys.batteryCharging;

        // No battery, or UPower has not answered yet. `hasBattery` is false on
        // a desktop, and this is what keeps a desktop silent.
        if (!Sys.hasBattery || pct <= 0) {
            watch.lastPercent = -1;
            return;
        }

        var wasCharging = watch.lastCharging;
        var first = !watch.primed;
        watch.lastPercent = pct;
        watch.lastCharging = charging;
        watch.primed = true;

        // Re-arm on the way up, whether that is from charging or from a
        // battery that recovered a little on its own.
        if (pct >= watch.lowPercent + watch.rearmMargin)
            watch.lowArmed = true;
        if (pct >= watch.criticalPercent + watch.rearmMargin)
            watch.criticalArmed = true;

        if (first)
            return;

        if (!watch.notify)
            return;

        // ── the charger came out ────────────────────────────────────────
        // Announced because it is frequently an accident — a foot on a cable,
        // a dock that dropped — and on a machine whose screen is full of work
        // the first sign otherwise is the 20% warning an hour later.
        if (wasCharging && !charging) {
            watch._announce("Running on battery",
                            "The charger was unplugged · " + pct + "% left",
                            false, "unplug");
        }

        if (!wasCharging && charging)
            Sys.playSound("plug");

        // A machine that is plugged in and filling is not running out, and
        // saying so while the cable is in is noise.
        if (charging)
            return;

        if (pct <= watch.criticalPercent && watch.criticalArmed) {
            watch.criticalArmed = false;
            watch.lowArmed = false;      // the louder one supersedes the other
            watch._announce("Battery critically low",
                            pct + "% left — save your work and plug in now",
                            true, "battery-critical");
            return;                      // never both cards for one step
        }

        if (pct <= watch.lowPercent && watch.lowArmed) {
            watch.lowArmed = false;
            watch._announce("Battery low",
                            pct + "% left — a good moment to find the charger",
                            false, "battery-low");
        }
    }

    // ── what wakes it: property changes, nothing else ───────────────────
    Connections {
        target: Sys
        function onBatteryPercentChanged() { watch._evaluate(); }
        function onBatteryChargingChanged() { watch._evaluate(); }
        function onHasBatteryChanged() { watch._evaluate(); }
    }

    // The public door, so `shell.qml` has a call to make rather than a bare
    // property reference that reads like a typo and lints like one. Same
    // shape as `UsbWatch.refresh()`.
    //
    // ⚠ The early return is load-bearing and it was found by the proof, not
    // by reading. `start()` is what `shell.qml` calls to force this singleton
    // into existence — and constructing it runs `Component.onCompleted`,
    // which primes it. So by the time the caller's own `start()` body runs,
    // `primed` is ALREADY true, `first` is false, and a machine sitting at 8%
    // would have thrown a critical card at the login it just finished. The
    // first version of this function claimed in its comment to be idempotent
    // and was not; the harness fired a "Battery critically low" toast on step
    // one and that is how it was caught. Waking a second time is not an
    // event, and only events are announced.
    function start() {
        if (watch.primed)
            return;
        watch._evaluate();
    }

    // Read the state once at startup so the latches start from the truth and
    // the first real change has something to be a change FROM. This one call
    // announces nothing — see `primed`.
    Component.onCompleted: watch.start()
}
