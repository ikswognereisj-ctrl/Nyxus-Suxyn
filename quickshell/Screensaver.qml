// Nyxus Suxyn — THE SCREENSAVER. Owner commission, 2026-08-17.
//
//   "set a screensaver as well that really works and then goes to login
//    after so long after that as well"
//
// ── WHY THE OLD ONE NEVER APPEARED, MEASURED BEFORE THIS WAS WRITTEN ─────────
// The build already had a screensaver and it had not run on the owner's machine
// for some time. Two independent reasons, both established from his live
// session rather than reasoned about:
//
//   1. `/usr/local/bin/nyxus-screensaver` DOES NOT EXIST on his machine. It is
//      an ISO-profile file; his session is a dev checkout, so the launcher
//      hypridle was told to run was never installed. `have("nyxus-screensaver")`
//      in `nyxus_settings.py` is therefore false, which alone deletes the stage
//      from the generated config.
//   2. His `power.saver_on` is `0`, so `build_hypridle_conf()` emits NO saver
//      listener at all — and his live `~/.config/hypr/hypridle.conf` proves it:
//      three listeners, at 600 s (lock), 900 s (dpms) and 1800 s (suspend), and
//      nothing between 0 and 600. The 45 s idle-glass stage is gated on the
//      same flag and is missing for the same reason.
//
// Neither of those is a bug in the saver's ART. They are both the same shape of
// failure: the screensaver was a SEPARATE PROGRAM that had to be installed, be
// on PATH, be enabled, and be reached by a config file a settings page rewrites.
// Four things had to be true and one of them silently was not.
//
// ── SO IT IS A SHELL SURFACE, NOT A PROGRAM ──────────────────────────────────
// This file needs nothing installed. If the shell is running, the screensaver
// exists; there is no fifth thing to be missing. It also makes Parts 2 and 3 of
// the commission ONE surface family: the desktop ground, the lock screen and
// the screensaver are the same `HeadlinerSky` over the same `headliner.frag`.
//
// ── HOW IT ENGAGES, AND WHY NOT VIA HYPRIDLE ─────────────────────────────────
// `IdleMonitor` is Quickshell's binding for `ext-idle-notify-v1` — the SAME
// compositor protocol hypridle itself consumes. So this is not a second, weaker
// idle mechanism running beside the real one; it is the same source of truth,
// read directly, one process earlier.
//
// That matters most for the dismissal, which the owner named as a requirement:
// `isIdle` is driven by the compositor's own notion of input, so it goes false
// on the first real event, before any client has had to decide anything. There
// is no polling interval to be unlucky with and no keystroke to lose.
//
// ⚠ THE LOCK IS STILL HYPRIDLE'S, AND THAT IS DELIBERATE. This surface does not
// lock and must never learn how. Every lock route in this build goes through
// `nyxus-lock-guard`, which is the only thing that refuses to lock an account
// with NO PASSWORD — the WIP-114 trap that once cost the owner his session with
// no way back but a hard reset. hypridle's `lock_secs` listener already calls
// the guard, already fires the lock chime, and already kicks the weather cache
// so the lock's sky is current when it paints. Reproducing any of that here
// would have been a second lock route to keep in step with the first. So the
// chain is: THIS surface owns idle → screensaver, hypridle owns
// screensaver → lock, and `Prefs` reads both timers out of the one file so they
// cannot disagree about what "so long after that" means.
//
// ── AND IT CANNOT TRAP HIM ───────────────────────────────────────────────────
// A layer-shell surface is not a session lock. If this process dies with the
// saver up, the surface dies with it and the desktop is simply there — the
// opposite of `ext-session-lock`, where a dying client leaves the compositor
// locked with no surface. On top of that there are four independent ways out,
// listed at `hide()`.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Item {
    id: saver

    // Up? One boolean; everything else is a consequence of it.
    property bool shown: false

    // The owner's switch and his timer, read from the file Settings writes.
    // Nothing here is a second spelling of either.
    // ⚠ `wanted`, NOT `enabled`, and this is a MEASURED bug rather than a
    // naming preference. `Item` already has a built-in `enabled`. Declaring
    // `readonly property bool enabled` here shadowed it, `onEnabledChanged`
    // bound to the wrong one, and the whole surface went dead: with
    // `saver_on: 1` and `saver_secs: 15` in a scratch HOME, the shell sat at
    // `state: idle` for MINUTES while a bare `IdleMonitor { timeout: 3 }`
    // probe on the same compositor reported `isIdle=true` after three seconds.
    // Prefs was innocent too — a second probe read
    // `saverEnabled=true saverSecs=15` off the same file. The protocol worked,
    // the settings worked, and the surface still never appeared, which is
    // exactly the shape of failure this file was written to end.
    readonly property bool wanted: Prefs.saverEnabled && !saver.blocked

    // ── STAND DOWN UNDER THE LOCK ────────────────────────────────────────────
    // Bound to `Lock.locked` from shell.qml. An `ext-session-lock` surface is
    // above every layer-shell surface by protocol, so the saver could not
    // OBSCURE the lock even if it tried — but it would sit underneath it,
    // shown, stepping its twinkle Timer at 25 Hz, for as long as the machine
    // stayed locked. And nothing would ever take it down: the saver hides on
    // INPUT, and the lock arriving is not input.
    //
    // That is exactly the shape this whole commission exists to fix — a
    // surface that is invisible to inspection and costs something anyway — so
    // it is handled where it can be seen rather than left to a `pkill` in a
    // config file.
    property bool blocked: false
    onBlockedChanged: if (saver.blocked) saver.hide()

    function show(): void { saver.shown = true; }

    // ── THE ARMING DELAY, AND WHY IT IS NOT A FUDGE ──────────────────────────
    // MEASURED, 2026-08-17, and it is the reason this property exists: with the
    // pointer-motion handler live from the first frame, the saver dismissed
    // ITSELF the instant it mapped, every time. `qs ipc call screensaver
    // engage` returned "shown" and `state` returned "idle" one command later,
    // with nobody touching anything.
    //
    // The cause is not a race and not a stray event. A `hoverEnabled` MouseArea
    // that maps UNDER the cursor receives an enter with a position, and Qt
    // delivers that as `positionChanged` — the pointer has not moved, the
    // surface arrived beneath it. Since the saver always maps under the cursor
    // (the cursor is wherever it was left five minutes ago), that fired on
    // 100% of engagements.
    //
    // So pointer MOTION is ignored for 600 ms after the surface appears. Keys,
    // buttons and the wheel are NOT delayed: those cannot be produced by a
    // surface mapping, so there is nothing to filter and no reason to make the
    // owner's keypress wait. The window is short enough that a hand already
    // moving crosses it in the noise, and `IdleMonitor` is unaffected — a real
    // input inside those 600 ms still clears `isIdle` and still takes the saver
    // down through the binding below.
    property bool armed: false
    onShownChanged: {
        saver.armed = false;
        if (saver.shown) armTimer.restart(); else armTimer.stop();
    }
    Timer {
        id: armTimer
        interval: 600
        onTriggered: saver.armed = true
    }

    // ── THE WAYS BACK ────────────────────────────────────────────────────────
    // 1. Any input at all: `idle.isIdle` goes false and the binding below hides
    //    this in the same event loop turn. This is the normal one and it is the
    //    compositor's own signal, not a guess.
    // 2. The surface's own MouseArea / Keys handlers, which fire on the same
    //    event and do not wait for the round trip.
    // 3. `qs ipc call screensaver hide`, from a terminal or another TTY.
    // 4. Killing the shell, which takes the layer surface with it.
    // The owner never has to reach past 1; 2, 3 and 4 exist so that a bug in 1
    // is an annoyance and not a lockout.
    function hide(): void { saver.shown = false; }

    // ── the idle source ──────────────────────────────────────────────────────
    // `ext-idle-notify-v1`, via the compositor. `respectInhibitors` is left at
    // its default true so a video player or a long build that has taken an idle
    // inhibit is not interrupted — the same courtesy hypridle extends, and the
    // reason `ignore_dbus_inhibit = false` is in the generated config.
    // ⚠ AND IT MUST BE RE-ARMED WHEN THE TIMEOUT CHANGES. MEASURED, and this is
    // the bug that made the whole surface look dead.
    //
    // `IdleMonitor` creates its `ext_idle_notification_v1` when `enabled` goes
    // true, with the timeout it has AT THAT MOMENT. Writing `timeout` afterwards
    // updates the QML property and does NOT re-create the notification — so the
    // property reads back the new value while the compositor is still counting
    // to the old one. It is the same trap `Lock.qml`'s header records for
    // `WlSessionLock.locked`: the property reads back what you wrote, and the
    // thing it controls did not change.
    //
    // That is fatal HERE specifically, because `Prefs` cannot avoid changing it:
    // a `FileView` hands out its declared defaults first and the file's real
    // values one event-loop turn later, so `timeout` ALWAYS goes 300 → whatever
    // the user set. Proven on a probe that reproduced only the binding shape:
    // with `timeout` written as a literal 3 it reported `isIdle=true` after
    // three seconds; with the identical monitor whose timeout moved 300 → 15
    // after 1.5 s it reported `enabled=true timeout=15 isIdle=false` for thirty
    // seconds straight. Nothing was wrong with the protocol, the settings or the
    // surface — and a screensaver that silently never appears is the exact
    // defect this file was written to end, so it would have shipped as a
    // like-for-like replacement for the bug.
    //
    // The re-arm is one blink of `enabled`: false destroys the notification,
    // true re-creates it with the current timeout.
    IdleMonitor {
        id: idle
        enabled: saver.wanted && idle.timeout > 0 && !reArm.running
        timeout: Prefs.saverSecs
        onTimeoutChanged: reArm.restart()
        onIsIdleChanged: saver.shown = idle.isIdle && saver.wanted
    }
    Timer { id: reArm; interval: 1 }

    // If the switch is turned off while the saver is up, it comes down at once
    // rather than at the next input. A settings toggle that does not take
    // effect until you touch something is a toggle people press twice.
    onWantedChanged: if (!saver.wanted) saver.hide()

    Variants {
        model: saver.shown ? Quickshell.screens : []

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            anchors { left: true; right: true; top: true; bottom: true }
            exclusionMode: ExclusionMode.Ignore

            // OVERLAY, and above everything else on it. The saver has to cover
            // the Start menu and the context menu, which are the two other
            // Overlay surfaces in this shell — and layer-shell stacks
            // same-level surfaces in creation order, so a surface created LAST
            // is on top. This one is created when it is shown, which is always
            // after both of those exist.
            //
            // It does NOT need to cover the lock: an `ext-session-lock` surface
            // is above every layer-shell surface by protocol, whatever this
            // does. That is also why the saver being up when the lock arrives
            // is harmless.
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "nyxus-screensaver"

            // EXCLUSIVE, and this is the half that stops keystrokes falling
            // through to whatever is underneath. Without it the first key of
            // the owner's password would be typed into whichever window had
            // focus when the machine went idle — which on this build could be a
            // terminal. `OnDemand` is not enough: it only grants focus on a
            // click, so the very first keypress would still land behind.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            // No `mask: Region {}` here, unlike every other ground surface in
            // this build. `Headliner`, `Starlight` and `LiveWall` all give up
            // their input region because they must never eat a click meant for
            // the desktop. This one is the exact opposite: EATING the click is
            // the job. The default (whole surface) is correct and is stated
            // here because the house habit is to blank it.

            color: "black"

            // ── the sky ──────────────────────────────────────────────────────
            // The same `headliner.frag`, through the same `HeadlinerSky`, that
            // the desktop and the lock screen wear. `master` is pulled back a
            // little: this is the only one of the three that runs unattended on
            // a panel that may be showing it for hours, and a screensaver is
            // supposed to be quieter than a desktop, not louder.
            HeadlinerSky {
                id: sky
                anchors.fill: parent
                active: win.visible
                // TRK-1221: reduced motion holds the sky still — the
                // twinkle Timer stops, uTime freezes, zero scheduled
                // frames. The hour still shows; the saver still engages.
                twinkling: !Prefs.reducedMotion
                twinkleDepth: 0.45
                density: 1.0
                master: 0.85
            }

            // ── the figures ──────────────────────────────────────────────
            // Owner, 2026-09-07: "can we add in the stars on that screen a few
            // constellations ... simple yet nice looking". Ursa Major, Orion
            // and Cassiopeia, sitting IN the sky above rather than on it.
            //
            // ⚠ It carries no timer and no ticking binding, deliberately. The
            // reasoning three comments up -- that this surface may run for
            // hours unwatched, which is why its clock is Minutes and not
            // Seconds -- applies twice over to decoration. `HeadlinerSky`
            // already twinkles behind these and already holds still under
            // reduced motion; the figures inherit both for free.
            //
            // Placed clear of the centre band: the 112 px hour below is the
            // largest type this build ever draws, and a chart line crossing a
            // numeral is the one way this reads as clutter instead of sky.
            SkyConstellations {
                anchors.fill: parent
                active: win.visible
            }

            // ── the hour ─────────────────────────────────────────────────────
            // One line, and nothing else. A screensaver that carries a weather
            // cluster and a media widget is a lock screen without the password,
            // and this build already has a very good lock screen.
            //
            // ⚠ THIS CLOCK IS NOT THE LOCK'S CLOCK and shares nothing with it
            // beyond the face. `Lock.qml`'s clock, date and weather layout are
            // untouched by this commission — nothing here reads them, resizes
            // them or sits in their tree.
            Text {
                anchors.centerIn: parent
                // ⚠ WAS the literal "HH:mm", so the screensaver's clock — the
                // single largest piece of type this build ever puts on screen —
                // ignored the 12/24-hour setting outright. On a machine set to
                // 12-hour it still read 13:47. TRK-3728 fixed nine sites and
                // this was not one of them, because it never branched on the
                // pref at all and so did not match a search for the branch.
                text: Qt.formatDateTime(tick.date, Prefs.timeFmt)
                color: Theme.text
                font.family: Theme.fTech
                // The lock's own 112, for the same reason it is not a Theme
                // token there: Theme's scale tops out at 30 px because it
                // describes shell CHROME, and a full-screen time readout is
                // not chrome. Matching the lock's number is the point — the
                // saver hands over to the lock, and the hour must not jump.
                font.pixelSize: 112
                font.weight: Font.DemiBold
                font.letterSpacing: 0
                opacity: 0.72
            }

            // A minute clock, not a second clock. `SystemClock` at
            // `Minutes` precision wakes the process 60 times an hour; at
            // `Seconds` it would be 3600, on the surface whose entire purpose
            // is to be cheap while nobody is watching.
            SystemClock {
                id: tick
                enabled: win.visible
                precision: SystemClock.Minutes
            }

            // ── dismissal, at the surface ────────────────────────────────────
            // Belt and braces beside `IdleMonitor`. These fire on the event
            // itself rather than on the compositor's idle notification, so in
            // the worst case they are the same frame and in the best case they
            // are one round trip earlier. `acceptedButtons: AllButtons` and
            // `hoverEnabled` between them cover "moving the mouse OR pressing a
            // key", which is what the owner asked for by name.
            //
            // Every handler ACCEPTS its event. That is the second half of "does
            // not fall through to the application beneath": exclusive keyboard
            // focus stops the key reaching another client, and accepting stops
            // it reaching anything inside this window either — so the gesture
            // that dismisses the saver is consumed by the dismissal and is not
            // also a click on whatever the saver was covering.
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.AllButtons
                focus: true
                // Motion waits for `armed` — see the note on that property for
                // the measurement that made it necessary. Everything else is
                // immediate.
                onPositionChanged: (m) => {
                    if (saver.armed) saver.hide();
                    m.accepted = true;
                }
                onPressed:         (m) => { saver.hide(); m.accepted = true; }
                onWheel:           (w) => { saver.hide(); w.accepted = true; }
                Keys.onPressed:    (e) => { saver.hide(); e.accepted = true; }
                Component.onCompleted: forceActiveFocus()
            }
        }
    }

    // ── the door ─────────────────────────────────────────────────────────────
    // `qs ipc call screensaver show|hide|state`. Every function returns a
    // STRING for `IpcHandler`'s recorded reason: `qs ipc call` exits 0 even
    // when the target does not exist — it prints "Target not found." and
    // reports success — so a caller can only tell "it answered" from "there is
    // no shell" by matching the OUTPUT.
    //
    // `engage` is what makes this testable without waiting five minutes, and
    // `hide` is the documented way back that does not involve killing anything.
    //
    // ⚠ `engage`, NOT `show`, and that is a CLI collision rather than taste.
    // MEASURED 2026-08-17: `qs ipc call screensaver show` prints the target's
    // FUNCTION LIST and calls nothing, because `show` is also a `qs ipc`
    // subcommand and the parser takes it first. It works as
    // `qs ipc call screensaver -- show`, which is a booby trap to leave lying
    // around: the obvious spelling silently does nothing and exits 0. `engage`
    // has no such clash, and it is the verb `Lock.qml`'s handler already uses
    // for the same idea, so the two stages of the chain read alike.
    IpcHandler {
        target: "screensaver"
        function engage(): string { saver.show(); return "shown"; }
        function hide(): string   { saver.hide(); return "hidden"; }
        function state(): string  { return saver.shown ? "shown" : "idle"; }
        function ready(): string  { return "ready"; }
    }
}
