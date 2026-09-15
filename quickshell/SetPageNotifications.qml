pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ System ▸ Notifications & actions.   MODULE 3.
//
// Backend: the shell's own notification server —
// `Quickshell.Services.Notifications`, already running inside `Sys.qml`, with
// `Toasts.qml` as its surface. There is no dunst here and no second daemon to
// configure: the thing being configured is this shell.
//
// TRK-3180: Quiet persists as `notify_dnd` through Sys.dnd (flyout, Start,
// and this page share that one bool). In-shell nags go through Sys.announce
// so DND actually silences them. Quiet hours are the existing
// notifications.quiet_* block (nyxus-quiet-hours), not a second scheduler.
import Quickshell
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    property var entry: null

    title: qsTr("Notifications")
    blurb: qsTr("What is allowed to interrupt you, where it appears, and for how long.")

    readonly property int liveCount: {
        var n = Sys.notifications;
        if (!n)
            return 0;
        if (n.values !== undefined && n.values !== null)
            return n.values.length;
        return n.length === undefined ? 0 : n.length;
    }

    readonly property int toastSecs: Math.round(SettingsStore.numberValue("toast_seconds", 6))
    readonly property string corner: SettingsStore.stringValue("toast_corner", "bottom-right")
    // TRK-4133 — where the volume/brightness OSD pins. See Prefs.osdPosition.
    readonly property string osdPlace: SettingsStore.stringValue("osd_position", "left")
    readonly property bool soundOn: Prefs.uiSoundNotify
    readonly property bool usbOn: SettingsStore.boolValue("usb_notify", true)
    readonly property bool battOn: SettingsStore.boolValue("notify_battery", true)

    // TRK-3664 — the redesigned toast's own dials. Clamped the same way
    // Toasts.qml clamps them, so the page and the surface cannot disagree
    // about what a hand-edited settings.json means.
    readonly property int toastStack: Math.max(1, Math.min(5,
        Math.round(SettingsStore.numberValue("toast_stack", 3))))
    readonly property bool actionsOn: SettingsStore.boolValue("toast_actions", true)
    readonly property bool dwellOn: SettingsStore.boolValue("toast_dwell", true)
    readonly property bool stillOn: Prefs.reducedMotion

    function _toggle(key, fallback) {
        SettingsStore.setValue(key, !SettingsStore.boolValue(key, fallback));
    }

    // ══ INTERRUPTIONS ══════════════════════════════════════════════════
    SetCard {
        heading: qsTr("Interruptions")
        tone: page.tone
        note: qsTr("Quiet stays on after a reload. In-shell timers and reminders ")
              + qsTr("honour it. Quiet hours, if already set elsewhere, ")
              + qsTr("are the same window — not a second clock.")

        SetRow {
            title: qsTr("Do Not Disturb")
            sub: Sys.dnd
                 ? qsTr("Quiet. Toasts and in-shell nags wait. Still saved after reload.")
                 : qsTr("Notifications appear as they arrive. Quiet survives a reload.")

            SetSwitch {
                tone: page.tone
                checked: Sys.dnd
                onToggled: function (v) { Sys.dnd = v; }
            }
        }

        SetRow {
            title: qsTr("Waiting")
            sub: page.liveCount === 0
                 ? qsTr("Nothing held")
                 : qsTr("Notifications the shell is currently holding")
            valueText: page.liveCount === 0 ? "0" : String(page.liveCount)
        }

        SetRow {
            title: qsTr("Lock screen")
            sub: qsTr("Notifications and media while locked — the live switches are in Privacy ▸ Lock screen")
            navigates: true
            onActivated: Bus.openSettings("screenlock")
        }
    }

    // ══ HOW THEY APPEAR ════════════════════════════════════════════════
    SetCard {
        heading: qsTr("How they appear")
        tone: page.tone

        // ── TRK-4133 · where the volume/brightness card lands ───────────
        // Owner, 2026-09-14: "instead of that popping up dead center could
        // we make it show at one of the far edges to the left or right on
        // the screen so its not dead center and so its not like any other
        // system".
        //
        // This is the OSD, not a toast — it is the feedback that fires when
        // you turn the volume or brightness knob. It lives on this page
        // because this is where "things that appear on their own" are set,
        // and it had no setting anywhere before now.
        SetRow {
            title: qsTr("Volume and brightness popup")
            sub: page.osdPlace === "center"
                 ? qsTr("Dead centre, over whatever you are looking at — where every other desktop puts it")
                 : page.osdPlace === "right"
                   ? qsTr("Pinned to the right edge, halfway up, clear of your work")
                   : qsTr("Pinned to the left edge, halfway up, clear of your work")

            SetChoice {
                key: "osd_position"
                defaultValue: "left"
                tone: page.tone
                options: [
                    { value: "left", label: qsTr("Left edge") },
                    { value: "center", label: qsTr("Centre") },
                    { value: "right", label: qsTr("Right edge") }
                ]
            }
        }

        SetRow {
            title: qsTr("How long they stay")
            // TRK-3664: the card now SHOWS this. A hairline along its bottom
            // edge drains over exactly this many seconds, and it stops while
            // the pointer is anywhere over the stack — so the number below is
            // a floor on reading time, not a race against it.
            sub: qsTr("Before a toast fades on its own. Hovering the stack holds it, and urgent ones ignore it entirely.")

            SetSlider {
                key: "toast_seconds"
                tone: page.tone
                from: 2; to: 20; snap: 1; defaultValue: 6
                suffix: " s"
            }
        }

        // ── TRK-3664 · the stack cap ────────────────────────────────────
        // The surface caps itself so a burst cannot become a wall. The oldest
        // card closes, never the newest arrival, and the ones that went are
        // counted on a pill at the far end of the stack. Nothing is lost
        // either way: the record is in the flyout.
        SetRow {
            title: qsTr("How many at once")
            sub: qsTr("Past this the oldest card closes and a counted pill takes its place. Every one is still in the panel.")

            SetSlider {
                key: "toast_stack"
                tone: page.tone
                from: 1; to: 5; snap: 1; defaultValue: 3
            }
        }

        // Four corners since TRK-3664 — the surface used to know three, and
        // `top-left` fell through to bottom-right.
        SetRow {
            title: qsTr("Corner")
            sub: qsTr("Where toasts rise from")

            SetChoice {
                tone: page.tone
                value: page.corner
                options: [
                    { value: "bottom-right", label: qsTr("Bottom right") },
                    { value: "bottom-left",  label: qsTr("Bottom left") },
                    { value: "top-right",    label: qsTr("Top right") },
                    { value: "top-left",     label: qsTr("Top left") }
                ]
                onChosen: function (v) { SettingsStore.setValue("toast_corner", v); }
            }
        }

        SetRow {
            title: qsTr("Sound")
            sub: qsTr("Uses the build's own notification sound")

            SetSwitch {
                tone: page.tone
                checked: page.soundOn
                // TRK-3423: this used to also write `notify_sound` — a key with
                // ZERO readers anywhere in the tree, a second spelling of this
                // one fact (the WIP-108 shape). One key now.
                onToggled: function (v) { SettingsStore.setValue("ui_sound_notify", v); }
            }
        }
    }

    // ══ WHAT IS ON THE CARD ════════════════════════════════════════════
    // TRK-3664 — these three describe the card itself. They are here rather
    // than under "How they appear" because that card is about WHERE and FOR
    // HOW LONG; this one is about what the thing actually shows you.
    SetCard {
        heading: qsTr("What is on the card")
        tone: page.tone
        note: qsTr("The sender's icon, then the summary, then the message. ")
              + qsTr("Urgent notifications carry a full-height ember rail and an ")
              + qsTr("inset rule instead of a short ice tick, so the kind reads ")
              + qsTr("from the shape before the colour — and they never fade on ")
              + qsTr("a timer.")

        SetRow {
            title: qsTr("App buttons")
            sub: qsTr("Reply, Snooze, Open — the app's own actions, as chips on the card. Apps that offer none simply do not show any.")

            SetSwitch {
                tone: page.tone
                checked: page.actionsOn
                onToggled: function (v) { SettingsStore.setValue("toast_actions", v); }
            }
        }

        SetRow {
            title: qsTr("Time left")
            sub: qsTr("A hairline along the card's bottom edge, draining as its time runs out. Held still while you hover the stack.")

            SetSwitch {
                tone: page.tone
                checked: page.dwellOn
                onToggled: function (v) { SettingsStore.setValue("toast_dwell", v); }
            }
        }

        // The toast honours `reduced_motion` (TRK-3664): no slide-in, no
        // grow-and-collapse, and no draining hairline — the dwell TIMING is
        // unchanged, only the animation of it. The switch lives on
        // Accessibility and this is the pointer to it, not a second copy.
        SetRow {
            title: qsTr("Motion")
            sub: page.stillOn
                 ? qsTr("Reduce motion is on — cards appear and go without animating. The switch is in Accessibility ▸ Reduce motion.")
                 : qsTr("Cards grow into the stack and collapse out of it. The switch is in Accessibility ▸ Reduce motion.")
            navigates: true
            onActivated: Bus.openSettings("access")
        }
    }

    // ══ WHAT MAY INTERRUPT ═════════════════════════════════════════════
    SetCard {
        heading: qsTr("What may interrupt you")
        tone: page.tone
        note: qsTr("These are the desktop's own announcements. Applications ask the ")
              + "notification server directly and are governed by Do Not Disturb."

        // TRK-3423: `usb_notify` is OWNED by the USB page now — it has the
        // switch, the automount pair it belongs beside, and the reset row.
        // Two pages writing one key meant this page's Reset silently reset
        // a USB setting, and USB had no reset at all.
        SetRow {
            title: qsTr("Removable drives")
            sub: page.usbOn ? qsTr("On — set under USB & removable devices")
                            : qsTr("Off — set under USB & removable devices")
            navigates: true
            onActivated: Bus.openSettings("usb")
        }

        SetRow {
            title: qsTr("Wi-Fi")
            sub: qsTr("When you join a network, leave it, or a join fails")

            SetSwitch {
                key: "notify_wifi"
                defaultValue: true
                tone: page.tone
            }
        }

        // ── TRK-4135 · the wire ────────────────────────────────────────
        // Owner, 2026-09-14: "... or lose network or it comes back".
        //
        // Wi-Fi had a card for joining, leaving and failing. Ethernet had
        // none: LinkWatch was Wi-Fi-only for anything network-shaped, so
        // pulling the cable was the one connectivity event on the machine
        // that happened in complete silence.
        SetRow {
            title: qsTr("Wired")
            sub: qsTr("When an ethernet cable or a dock's network port comes up or goes down")

            SetSwitch {
                key: "notify_wired"
                defaultValue: true
                tone: page.tone
            }
        }

        SetRow {
            title: qsTr("Bluetooth")
            sub: qsTr("When a device connects or disconnects — headphones especially")

            SetSwitch {
                key: "notify_bluetooth"
                defaultValue: true
                tone: page.tone
            }
        }

        SetRow {
            title: qsTr("Battery")
            sub: qsTr("At 20%, at 10%, and when the charger is unplugged")

            SetSwitch {
                tone: page.tone
                checked: page.battOn
                onToggled: function (v) { SettingsStore.setValue("notify_battery", v); }
            }
        }

        SetRow {
            title: qsTr("Updates")
            sub: qsTr("Available updates already toast from the checker. Install lives under Updates.")
            navigates: true
            onActivated: Bus.openSettings("updates")
        }
    }

    // TRK-1261 / TRK-3135 — keys this page WRITES. notify_dnd is written
    // by Sys.qml (one bool, many toggles), not here — 13r81 would fail if
    // it sat on this Reset row. usb_notify stays on the USB page (TRK-3423).
    // notify_updates is not a key: nyxus-update-check already toasts.
    SetResetRow {
        what: qsTr("Notifications")
        // TRK-3423: `notify_sound` (reader-less twin, no longer written) and
        // `usb_notify` (USB page owns it now) are off this list with their
        // writes — 13r81 holds the two sides equal.
        // TRK-3664 adds the three the redesigned card brought with it.
        keys: ["toast_seconds", "toast_stack", "toast_corner", "toast_actions",
               "toast_dwell", "ui_sound_notify", "notify_battery",
               "notify_wifi", "notify_bluetooth", "notify_wired",
               "osd_position"]
    }
}
