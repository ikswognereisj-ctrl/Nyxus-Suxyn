pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ Privacy & security ▸ Lock screen.   MODULE 2.
//
// The three keys already existed on Notifications (`WIP-415`, `WIP-419`).
// No new keys and no new defaults: `13uv` checks each key has both a switch
// and a reader. This page is the catalog stub filled in — same store, same
// readers (Toasts / LockMedia), kit controls only.
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

    title: qsTr("Lock screen")
    blurb: qsTr("Lock this session, then choose what is visible while it is locked.")

    readonly property bool showNotif: SettingsStore.boolValue("lock_notifications", true)
    readonly property bool hideBody: SettingsStore.boolValue("lock_notifications_hide_body", false)
    readonly property bool mediaCtl: SettingsStore.boolValue("lock_media_control", false)

    // ── THE EARTH (owner ask, 2026-08-23) ────────────────────────────────
    // ⚠ TRUE (owner 08-27). Stay in step with Prefs.qml's `lock_earth_on`.
    // These two defaults disagreed for one commit: Prefs went to false after
    // the 2026-08-23 lock failure and this page was left saying true. The
    // result is the worst kind of settings bug — the page showed the Earth as
    // ON, the lock had it OFF, and the owner went and looked at his lock screen
    // twice before reporting that the switch was lying to him. A default is
    // duplicated here because SettingsStore reads the file directly; when one
    // moves, the other moves.
    readonly property bool   earthOn:     SettingsStore.boolValue("lock_earth_on", true)
    // ── SNAPPED TO AN OFFERED SIZE ───────────────────────────────────────
    // The three choices are 0.55 / 0.72 / 0.90, and settings.json can easily
    // hold something that is none of them — the owner's still says 1.30, left
    // over from when that was on the menu. A SetChoice whose value matches no
    // option renders with NOTHING selected, so the page would show a size
    // chooser with no size chosen while the lock quietly used a fourth number.
    // Snapping to the nearest offered value means the page always tells the
    // truth about what is in force.
    readonly property real earthSizeRaw:
        Math.min(0.95, SettingsStore.numberValue("lock_earth_size", 0.72))
    readonly property real earthSize: {
        const opts = [0.55, 0.72, 0.90];
        let best = opts[0];
        for (let i = 1; i < opts.length; i++)
            if (Math.abs(opts[i] - page.earthSizeRaw) < Math.abs(best - page.earthSizeRaw))
                best = opts[i];
        return best;
    }
    readonly property string earthSide:   SettingsStore.stringValue("lock_earth_side", "left")
    readonly property bool   earthMarker: SettingsStore.boolValue("lock_earth_marker", true)
    readonly property bool   earthBolts:  SettingsStore.boolValue("lock_earth_bolts", true)

    readonly property real earthCentreX: page.earthSide === "centre" ? 0.50
                                       : page.earthSide === "right"  ? 0.70 : 0.30

    readonly property bool moonOn: SettingsStore.boolValue("lock_moon_on", false)
    // ⚠ THE FALLBACK IS THEME-DEPENDENT, and this page has to compute it the
    // SAME WAY Prefs.lockScene does. Since 2026-09-06 an ABSENT `lock_scene`
    // means "the scene this theme opens with" — the orbit view on NYXUS (the
    // one the owner kept; earthrise is a pick, never a default), the Ocular on
    // alien. A page that kept a flat default would
    // show "In orbit" selected on a fresh alien install while the lock screen
    // actually drew the Ocular: the page and the shell are two readers of one
    // file, and this is precisely the disagreement the rule at the top of
    // SetPageAppearance.qml exists to prevent.
    //
    // Keep this expression and Prefs.lockScene's in step. Both must also stay
    // in step with the options list below — a value the enum accepts but the
    // list does not show is a setting the owner can land on and cannot leave.
    // ⚠ Neither sentence is the enforcement: `scripts/verify-settings-
    // wiring.py` check 5 compares the options against the reader's accepted
    // set, and check 7 compares this expression's answers against
    // Prefs.lockScene's. A comment cannot check itself (TRK-3744).
    readonly property string markTheme: SettingsStore.stringValue("mark_theme", "nyxus")
    readonly property string sceneFallback: page.markTheme === "alien" ? "ocular"
                                                                      : "sky"
    readonly property string scene: SettingsStore.stringValue("lock_scene",
                                                             page.sceneFallback)

    Process {
        id: lockNow
        running: false
        command: ["env", page.execPath, "nyxus-lock-guard"]   // TRK-3435
    }

    SetCard {
        heading: qsTr("Lock now")
        tone: page.tone
        note: qsTr("Same path as the shelf menu and Security. Super+L too.")

        SetRow {
            title: qsTr("Lock now")
            sub: qsTr("Locks this session immediately")

            SetButton {
                text: qsTr("Lock")
                tone: page.tone
                busy: lockNow.running
                enabled: !lockNow.running
                onClicked: lockNow.running = true
            }
        }

        SetRow {
            title: qsTr("Sign-in & encryption")
            sub: qsTr("Fingerprint report, LUKS, firmware, firewall")
            navigates: true
            onActivated: Bus.openSettings("security")
        }

        SetRow {
            title: qsTr("Keep awake")
            sub: qsTr("Screensaver. Lock delay is hypridle at 10 minutes.")
            navigates: true
            onActivated: Bus.openSettings("idle")
        }
    }

    SetCard {
        heading: qsTr("The scene")
        tone: page.tone
        note: qsTr("Where you are standing. In orbit, the Earth hangs in the star field with the "
                 + "moon where it really is tonight. On the Moon, you are on the surface with the "
                 + "lunar ground below you and the Earth rising over it — still turning, still "
                 + "wearing its real weather. The Ocular is deep sky instead: no planet, a live "
                 + "star field under aurora, and the mark drawn in stars overhead. Switching "
                 + "away from a scene never changes its settings — your Earth comes back exactly "
                 + "as you left it.")

        SetRow {
            title: qsTr("Scene")

            SetChoice {
                key: "lock_scene"
                // Not a literal: the default IS the theme's fallback, so that
                // "unset" highlights the scene the lock screen actually draws.
                defaultValue: page.sceneFallback
                value: page.scene
                // ⚠ These must stay in step with Prefs.lockScene's accepted
                // list. A value the enum takes but this list does not show is a
                // setting the owner can land on and cannot get back out of.
                options: [
                    { label: qsTr("In orbit"),    value: "sky" },
                    { label: qsTr("On the Moon"), value: "earthrise" },
                    { label: qsTr("The Ocular"),  value: "ocular" }
                ]
                tone: page.tone
                onChosen: function (v) { SettingsStore.setValue("lock_scene", v); }
            }
        }
    }

    SetCard {
        heading: qsTr("The Moon")
        tone: page.tone
        note: qsTr("Tonight's actual moon, in the place it actually is. The phase is not a drawn "
                 + "shape — a real sphere wearing NASA's lunar map is lit from where the sun "
                 + "really is, so the crescent falls across real craters. It sits low when the "
                 + "moon is low, and goes orange then too, because that is what the air does to "
                 + "it. Below the horizon it is not drawn, because it is not there.")

        SetRow {
            title: qsTr("Moon")
            sub: qsTr("Show tonight's moon on the lock screen")
            available: page.scene === "sky"
            unavailableReason: qsTr("Only shown in orbit")

            SetSwitch {
                key: "lock_moon_on"
                defaultValue: false
                tone: page.tone
            }
        }

        SetRow {
            title: qsTr("Moon size")
            sub: qsTr("How large tonight's moon is drawn. The lock already reads this.")
            available: page.moonOn && page.scene === "sky"
            unavailableReason: page.scene !== "sky"
                               ? qsTr("Only shown in orbit")
                               : qsTr("Moon is off")
            SetSlider {
                key: "lock_moon_scale"
                width: 250
                tone: page.tone
                from: 0.5; to: 2.0; snap: 0.1; defaultValue: 1.0
                format: function (v) { return Math.round(v * 100) + "%"; }
            }
        }
    }

    SetCard {
        heading: qsTr("The Earth")
        tone: page.tone
        note: qsTr("A real Earth in the lock screen's starfield, turned to where you are and lit "
                 + "by the actual sun. The clouds are live satellite weather, so the sky on the "
                 + "planet is the sky outside. The wallpaper underneath is untouched — this is a "
                 + "layer over it, and turning it off gives back exactly the lock you had.")

        // ── the preview ──────────────────────────────────────────────────
        // The owner's ask, in his words: "i want people to be able to choose
        // from and view it before to see if thats what they want". So this is
        // the real thing, not a picture of it — the same LockEarth component
        // and the same shader the lock draws, reading the same settings, at
        // 16:9 so the proportions are honest.
        //
        // `live: false` here as everywhere else: it redraws on its own minute
        // timer, so an open Settings page costs nothing while you read it.
        Item {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            Layout.preferredHeight: width * 9 / 16
            clip: true

            Rectangle { anchors.fill: parent; color: Theme.void_; radius: Theme.r2 }
            Image {
                anchors.fill: parent
                source: Qt.resolvedUrl("lock-still.png")
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: page.earthOn
            }
            LockEarth {
                anchors.fill: parent
                visible: page.earthOn
                sizeFrac: page.earthSize
                centreX: page.earthCentreX
                markerStrength: page.earthMarker ? 0.55 : 0.0
                lightning: page.earthBolts
                live: false
            }
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: Theme.r2
                border.width: 1
                border.color: Theme.soften(Theme.paintLayers["glacier"][0], 0.07)
            }
            Text {
                anchors.centerIn: parent
                visible: !page.earthOn
                text: qsTr("Off — the lock keeps its starfield")
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
            }
        }

        SetRow {
            title: qsTr("Earth")
            sub: qsTr("Show the Earth on the lock screen")

            SetSwitch {
                key: "lock_earth_on"
                defaultValue: true
                tone: page.tone
            }
        }

        // All three sizes kept, by owner ruling — he was shown these and kept
        // the set rather than picking one and discarding the others.
        SetRow {
            title: qsTr("Earth size")
            available: page.earthOn
            unavailableReason: qsTr("Turn on the Earth to choose a size")

            SetChoice {
                key: "lock_earth_size"
                defaultValue: 0.72
                value: page.earthSize
                // ⚠ The largest is 0.90, not the 1.30 this shipped with. At 1.30
                // the globe is 1404 px across on a 1080 px screen, so it was cut
                // off top and bottom -- the owner: "it gets cut out of the
                // background its so big". 0.90 is the largest that still shows the
                // whole planet on a 16:9 panel with a margin.
                options: [
                    { label: qsTr("Small"),  value: 0.55 },
                    { label: qsTr("Medium"), value: 0.72 },
                    { label: qsTr("Large"),  value: 0.90 }
                ]
                tone: page.tone
                onChosen: function (v) { SettingsStore.setValue("lock_earth_size", v); }
            }
        }

        SetRow {
            title: qsTr("Earth position")
            available: page.earthOn
            unavailableReason: qsTr("Turn on the Earth to set its position")

            SetChoice {
                key: "lock_earth_side"
                defaultValue: "left"
                value: page.earthSide
                options: [
                    { label: qsTr("Left"),   value: "left" },
                    { label: qsTr("Centre"), value: "centre" },
                    { label: qsTr("Right"),  value: "right" }
                ]
                tone: page.tone
                onChosen: function (v) { SettingsStore.setValue("lock_earth_side", v); }
            }
        }

        SetRow {
            title: qsTr("Mark your location")
            sub: qsTr("A small ring shows where you are")
            available: page.earthOn
            unavailableReason: qsTr("Turn on the Earth to show this")

            SetSwitch {
                key: "lock_earth_marker"
                defaultValue: true
                tone: page.tone
            }
        }

        SetRow {
            title: qsTr("Storms")
            sub: qsTr("Let thunderstorms flash on the night side")
            available: page.earthOn
            unavailableReason: qsTr("Turn on the Earth to show this")

            SetSwitch {
                key: "lock_earth_bolts"
                defaultValue: true
                tone: page.tone
            }
        }
    }

    SetCard {
        heading: qsTr("While locked")
        tone: page.tone
        note: qsTr("The same toasts as the desktop. Hiding contents still shows that ")
              + "something arrived and which application it came from. Media "
              + "control is off by default — anyone at a locked laptop can then "
              + "pause or skip without the password."

        SetRow {
            title: qsTr("Notifications")
            sub: qsTr("Show notifications while locked")

            SetSwitch {
                key: "lock_notifications"
                defaultValue: true
                tone: page.tone
            }
        }

        SetRow {
            title: qsTr("Hide contents")
            sub: qsTr("Shows that something arrived and which application it came from, without the message itself")
            available: page.showNotif
            unavailableReason: qsTr("Notifications are off")

            SetSwitch {
                key: "lock_notifications_hide_body"
                defaultValue: false
                tone: page.tone
            }
        }

        SetRow {
            title: qsTr("Media controls")
            sub: qsTr("Play, pause and skip from the lock screen")

            SetSwitch {
                key: "lock_media_control"
                defaultValue: false
                tone: page.tone
            }
        }
    }

    SetResetRow {
        what: qsTr("Lock screen")
        keys: ["lock_scene", "lock_moon_on", "lock_moon_scale", "lock_earth_on",
               "lock_earth_size", "lock_earth_side", "lock_earth_marker", "lock_earth_bolts",
               "lock_notifications", "lock_notifications_hide_body", "lock_media_control"]
    }
}
