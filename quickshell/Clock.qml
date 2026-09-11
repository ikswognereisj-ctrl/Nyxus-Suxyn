// Nyxus Suxyn — the clock surface. WIP-103.
//
// The owner: "the clock on the bottom bar, same — I click on it, I should be
// able to go to the clock, which I should be able to change the time or the
// time format, time zone etc, along with the calendar because it has the date
// as well ... so everything is tied together and connects as one."
//
// So this is not a bigger clock. It is the clock's SUBJECT: what time it is,
// where that time is, and what is coming up — and the "what is coming up" is
// read straight out of Reminders, the same singleton the calendar writes to.
// A reminder filed on a day in the calendar appears here without either
// surface knowing the other exists. That is WIP-108 in one screen.
//
// WHAT THIS DELIBERATELY DOES NOT DO: change the time format itself. Prefs is
// documented single-writer — NYXUS Settings owns settings.json, and the shell
// only reads it, because the shell's adapter declares a handful of keys and
// writing back through it would strip every other section on save. So the
// format and time zone are DISPLAYED here and edited in Settings, which this
// surface links straight into. One fact, one writer, reachable from the place
// you were already looking. Deep-linking is the fix, not a second writer.
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    // Must match ^(nyxus.*)$ or Hyprland's blur rule never sees the surface
    // and the glass renders over raw wallpaper (Theme.qml records this).
    WlrLayershell.namespace: "nyxus-clock"
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // WIP-640(c). This was anchored `bottom + right`, so clicking the clock —
    // which the owner's own 2026-08-09 ruling moved to DEAD CENTRE of the bar
    // ("the clock and date in the middle", Bar.qml § the Meridian) — opened
    // its surface in the far corner, a screen width away from the thing that
    // was pressed. A popup that does not come out of the control belongs to
    // nothing on screen.
    //
    // Dropping the `right` anchor is the whole fix: a layer-shell surface
    // anchored on neither edge of an axis is CENTRED on that axis by the
    // compositor, which lands it under the centred Meridian without this
    // file having to know the bar's geometry (it cannot — it is a different
    // surface). ⚠ If the clock is ever moved off centre, this must move with
    // it, and the honest way would be an anchor x published on Bus.
    // Owner 2026-08-19: optical air above the bar, same s5 as Start.
    anchors { bottom: true }
    margins { bottom: Theme.chromeH - Theme.bloomPad + Theme.s5 }
    implicitWidth: 320 + Theme.bloomPad * 2

    // ── TRK-2903 · THE POPUP IS AS TALL AS WHAT IS IN IT ────────────────
    // It was a flat 600 and the comment above it said what that number was:
    // "the ceiling moved 520 → 600 … the ColumnLayout's fillHeight spacer
    // absorbs any slack". A ceiling sized for the worst case is a floor for
    // every other case, and the slack an invisible spacer absorbs is the
    // empty space you are looking at. Measured at 320 wide, s6 gutters,
    // s4 between rows:
    //
    //   FOUR reminders (the case 600 was cut for)   568 + 32 = 600 exactly
    //   NONE, on a five-row month (the usual case)  356 + 32 = 388
    //
    // So the surface the owner opens to check the time was 212 px — 35% of
    // itself — of nothing, every day that nothing was scheduled.
    //
    // `clockCol` publishes an implicitHeight computed from its children's
    // implicit sizes at a width this file fixes (320); the fillHeight spacer
    // contributes 0 to it and so cannot feed the height back into itself.
    // That is the same discipline SidePanel.qml § TRK-2901 sets out, and the
    // same trap (a content-sized surface that also sizes its content) that
    // parked the eww home deck at y=-59.
    //
    // The spacer STAYS: once the clamp bites on a short screen it is what
    // keeps "Time settings ›" on the floor instead of adrift mid-card.
    // GAP-2, the same clamp Launcher.qml § the swell applies: never taller
    // than the screen it opens on, less the bar and this window's own air.
    readonly property int availH:
        (screen ? screen.height : 800) - Theme.chromeH - Theme.s5
        - Theme.bloomPad * 2
    readonly property int bodyH:
        Math.min(clockCol.implicitHeight + Theme.s6 * 2, root.availH)
    implicitHeight: root.bodyH + Theme.bloomPad * 2
    visible: Bus.clockOpen

    // Screen origin of this window (centred on x, sitting on the bar).
    // SkyBehind needs it so the Headliner lattice matches the chips.
    readonly property int winScreenX: {
        var sw = screen ? screen.width : 1920
        return Math.round((sw - implicitWidth) / 2)
    }
    readonly property int winScreenY: {
        var sh = screen ? screen.height : 1080
        return sh - implicitHeight - (Theme.chromeH - Theme.bloomPad + Theme.s5)
    }

    // Input is the pane, not the padded window — the bloom pad would otherwise
    // swallow clicks meant for the taskbar underneath. Same reasoning, and the
    // same trap, as Flyout.qml: these are the untransformed geometry.
    mask: Region {
        x: pane.x; y: pane.y; width: pane.width; height: pane.height
    }

    HyprlandFocusGrab {
        windows: [root]
        active: Bus.clockOpen
        onCleared: Bus.clockOpen = false
    }
    Shortcut {
        sequence: "Escape"
        enabled: Bus.clockOpen
        onActivated: Bus.clockOpen = false
    }

    Timer {
        running: root.timerRun
        interval: 1000
        repeat: true
        onTriggered: {
            if (root.timerRemain <= 1) {
                root.timerRemain = 0;
                root.timerRun = false;
                Sys.announce(qsTr("Timer"), qsTr("Time is up"), "Nyxus", "alert");
            } else {
                root.timerRemain -= 1;
            }
        }
    }

    // Seconds only when the user asked for them. The bar's clock runs at
    // minute precision precisely so the shell wakes 60× less often, and this
    // surface has no business undoing that while it is merely open.
    SystemClock {
        id: clock
        precision: Prefs.clockShowSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    // On root, because every reference says root.upcoming. Declared inside the
    // ColumnLayout on the first cut, which QML resolves to a DIFFERENT object —
    // the list would simply never have populated, with no error anywhere.
    //
    // The `Reminders.items` term is load-bearing: it makes this binding depend
    // on the store's property, so filing a reminder in the calendar re-evaluates
    // it here. Without it the binding only tracks the function call and the
    // list would go stale the moment it was first read.
    readonly property var upcoming: (Reminders.items, Reminders.upcoming(4))

    property string clockPane: "agenda"
    property int timerRemain: 0
    property int timerSet: 300
    property bool timerRun: false
    property int alarmH: 7
    property int alarmM: 0
    property string alarmRecur: "none"

    readonly property var worldCities: [
        { iana: "America/New_York", label: "New York" },
        { iana: "Europe/London", label: "London" },
        { iana: "Asia/Tokyo", label: "Tokyo" },
        { iana: "UTC", label: "UTC" }
    ]

    function worldLine(row) {
        try {
            var opts = {
                timeZone: row.iana,
                hour: "2-digit",
                minute: "2-digit",
                hour12: !Prefs.clock24h,
                timeZoneName: "short"
            };
            var bits = new Intl.DateTimeFormat("en-GB", opts).formatToParts(clock.date);
            var hm = "";
            var tz = row.iana;
            for (var i = 0; i < bits.length; i++) {
                if (bits[i].type === "hour" || bits[i].type === "minute"
                        || bits[i].type === "literal" || bits[i].type === "dayPeriod")
                    hm += bits[i].value;
                if (bits[i].type === "timeZoneName")
                    tz = bits[i].value;
            }
            return row.label + "  " + hm.trim() + "  ·  " + tz;
        } catch (e) {
            return row.label + "  ·  " + row.iana;
        }
    }

    function addAlarm() {
        var d = new Date(clock.date);
        d.setHours(root.alarmH, root.alarmM, 0, 0);
        if (d.getTime() <= Date.now())
            d.setDate(d.getDate() + 1);
        Reminders.add(d.getTime(), qsTr("Alarm"), "alarm", root.alarmRecur);
        root.clockPane = "agenda";
    }

    function timerLabel() {
        var s = Math.max(0, root.timerRemain);
        var m = Math.floor(s / 60);
        var r = s % 60;
        return (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r;
    }

    readonly property string tz: Prefs.clockTimeZone
    // TRK-3728 · both shapes come from Prefs; see the note there. Composing
    // this as `timeFmt + ":ss"` is what would put the seconds after the AM/PM
    // marker once the 12-hour arm stopped being a 24-hour clock in disguise.
    readonly property string timeFmt: Prefs.clockShowSeconds ? Prefs.timeFmtSeconds
                                                             : Prefs.timeFmt

    // Ice object (SetIceFace rungs). Beat/cava held — this is the Clock
    // popup, not the bar analyser. Face is the lock (owner 09:40,
    // TRK-3048/3049): Theme.panelMid + swellGround, GlassEdge.body 0 —
    // widgets and the right-side flyout, not the old iceElevated slab
    // (`Theme.elevated` #071318, body 1). WIP-259 photographed body over
    // a swell as a dark box; WIP-265 moved density under the paint.
    // Magma none here. No sweep0 `#0aa2d6` fill. `#891955` never a fill.
    readonly property color iceElevated: Theme.elevated                 // #071318 — retired fill
    readonly property color iceSeam:     Theme.paintLayers.glacier[4]   // #4f7fa6
    readonly property color icePeak:     Theme.paintLayers.glacier[6]   // #eefcff
    readonly property color iceHover:    Theme.paintLayers.glacier[5]   // #b7e6f2
    readonly property color iceFocus:    Theme.paintLayers.glacier[0]   // #7fe8ff

    Pane {
        id: pane
        anchors.fill: parent
        anchors.margins: Theme.bloomPad
        elevation: 2
        // TRK-3651 — no outer glow at rest; see Pane.qml. The bloomPad margin
        // above stays: it only insets this pane inside its window, and moving
        // it would move the popup.
        bloomAtRest: false
        fill: Theme.panelMid
        radiusTL: Theme.r3
        radiusTR: Theme.r3
        // Lifted off the bar (owner 2026-08-19): bottom corners are free,
        // so they take the same r3 as the top. Flush r0 was for sitting on
        // the horizon.
        radiusBL: Theme.r3
        radiusBR: Theme.r3

        // TRK-3082: chips sit on the sky; this popup sits on windows.
        // Same glass as WidgetChip (panelMid + swell, body 0). The sky
        // under the glass is what makes that recipe look solid and plum.
        // z -1 puts it behind Pane's own fill shader.
        SkyBehind {
            z: -1
            anchors.fill: parent
            live: Bus.clockOpen
            paneScreenX: root.winScreenX + pane.x
            paneScreenY: root.winScreenY + pane.y
            screenW: root.screen ? root.screen.width : 1920
            screenH: root.screen ? root.screen.height : 1080
            radius: Theme.r3
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.r3
            gradient: Gradient {
                GradientStop { position: 0.00; color: Theme.swellGroundTop }
                GradientStop { position: 0.50; color: Theme.swellGroundMid }
                GradientStop { position: 1.00; color: Theme.swellGroundFoot }
            }
        }

        // Gate 13pu caught this missing on the first cut of this file, which
        // is exactly what it is for: the Crown/Lip/Sheen/Glaze stack is what
        // makes a surface read as Nyxus Glass, and a new surface that skips it
        // looks *nearly* right — which is how three surfaces once had it and
        // three did not. Drawn with the shared component, never re-derived
        // from the recipe.
        GlassEdge {
            anchors.fill: parent
            radiusTL: Theme.r3
            radiusTR: Theme.r3
            radiusBL: Theme.r3
            radiusBR: Theme.r3
            // Lock: body 0. WIP-259 / WIP-265 — body over a swell stacks
            // into a dark box. Density is the swell Rectangle above, not
            // this layer. Edging is WidgetChip's loud rung (TRK-3081);
            // default 1.0 is the bar lip and reads shinier than the chips.
            body: 0
            wash: 0
            edging: 0.85
        }
        // The living border (owner ruling 2026-08-09): load mood + music
        // kick, same bands as the window borders. See ReactiveEdge.qml.
        ReactiveEdge {
            // TRK-3649 - no resting outer halo. This pane floats over the
            // desktop, so the always-on 8 px band outside its edge read as a
            // second edge - the widgets never drew it. The beat bloom stays.
            haloAtRest: false
            radiusTL: Theme.r3
            radiusTR: Theme.r3
            radiusBL: Theme.r3
            radiusBR: Theme.r3
        }
        // Mirror rim: WidgetChip default zRole 1 (TRK-3081). Was flyout
        // 14/0.62; the chips beside this popup are 10/0.46.
        MirrorEdge {
            radiusTL: Theme.r3; radiusTR: Theme.r3
            radiusBL: Theme.r3; radiusBR: Theme.r3
            depth: 10
            strength: 0.46
        }

        // ── 4 · THE SEAM (TRK-3372) ─────────────────────────────────
        // 1 px, `iceSeam` = glacier[4]. Declared at the top of this file
        // since TRK-3056 and never drawn: the popup had the floor, the
        // paint, the ramp and the edge, and stopped one layer short. The
        // chips it sits beside carry it, so this is the cue that made a
        // reference and a copy of the reference not quite match.
        Rectangle {
            anchors.fill: parent
            radius: Theme.r3
            color: "transparent"
            antialiasing: true
            border.width: 1
            border.color: Theme.soften(root.iceSeam, 0.45)
        }

        ColumnLayout {
            id: clockCol
            anchors.fill: parent
            anchors.margins: Theme.s6
            spacing: Theme.s4

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s3
                CrystalGem {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    hot: false
                    on: Bus.clockOpen
                }
                Text {
                    text: qsTr("CLOCK")
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    font.weight: Font.Medium
                    font.letterSpacing: Theme.trackMicro
                    color: Theme.textDim
                    Layout.alignment: Qt.AlignVCenter
                }
                Item { Layout.fillWidth: true }
            }

            Text {
                Layout.fillWidth: true
                text: Qt.formatDateTime(clock.date, root.timeFmt)
                // The desk clock is the one readout in the shell that is
                // BIG and is nothing but numerals, which is exactly what
                // `fTech` exists for. It was set in the body face at
                // display size — a text font doing a display job — and
                // without tabular figures, so the colon walked sideways
                // every time a 1 turned into a 4.
                font.family: Theme.fTech
                font.pixelSize: Theme.tDisplay
                // Orbitron starts at 400; asking it for Light synthesises a
                // thinner face and the strokes break up at this size.
                font.weight: Theme.wBody
                font.letterSpacing: Theme.trackTech
                font.features: ({ "tnum": 1 })
                color: Theme.text
            }
            Text {
                Layout.fillWidth: true
                text: Qt.formatDateTime(clock.date, "dddd d MMMM yyyy")
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                color: Theme.textMuted
            }
            Text {
                Layout.fillWidth: true
                // An empty preference means "follow the system", which is the
                // honest thing to say rather than inventing a zone name.
                text: root.tz && root.tz.length > 0 ? root.tz : qsTr("System time zone")
                font.family: Theme.fUi
                font.pixelSize: Theme.tMicro
                color: Theme.textDim
            }

            Rail { Layout.fillWidth: true }

            // ── the month ────────────────────────────────────────────────
            // WIP-640(c). The owner's brief for this surface says the clock
            // and the calendar are the same subject ("along with the calendar
            // because it has the date as well … everything is tied together
            // and connects as one") — and this screen printed one date and
            // then went straight to a reminder list, so there was no month
            // anywhere on it. `MonthCalendar.qml` already existed, already
            // Monday-first, already reading the SAME `Reminders` store this
            // surface's COMING UP list reads, and was used on exactly one
            // surface (SidePanel's Calendar section). It is embedded, not
            // re-drawn: a second month grid is a second thing that can
            // disagree about what day it is.
            MonthCalendar {
                id: month
                Layout.fillWidth: true
                // `now` is a plain property, so it does NOT follow the clock
                // on its own — bind it, or the "today" disc would be stuck on
                // whichever day the shell happened to start.
                now: clock.date
                // A month grid is the wrong place to host an editor (its own
                // header says so), and this surface has no editor. So a tap
                // hands off to the one that does: the panel's Calendar
                // section, the same store, one write path.
                //
                // Honest limit: the handoff carries the SECTION, not the day
                // — there is no day channel on Bus today, and inventing one
                // for this would be a second way to say "which day is open".
                onDaySelected: function (y, m, d) {
                    Bus.clockOpen = false;
                    Bus.openCalendar();
                }
            }

            Rail { Layout.fillWidth: true }

            Text {
                text: qsTr("COMING UP")
                font.family: Theme.fUi
                font.pixelSize: Theme.tMicro
                font.weight: Font.Medium
                font.letterSpacing: Theme.trackMicro
                color: Theme.textDim
            }

            // The join. These are the reminders the CALENDAR wrote — no copy,
            // no sync step, no second list that can disagree.
            Text {
                Layout.fillWidth: true
                text: qsTr("Nothing scheduled")
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                visible: root.upcoming.length === 0
            }

            Repeater {
                model: root.upcoming
                delegate: ColumnLayout {
                    id: upWrap
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Theme.s1
                    ReminderFace {
                        Layout.fillWidth: true
                        when: Qt.formatDateTime(new Date(upWrap.modelData.ts), root.timeFmt)
                        caption: (upWrap.modelData.kind === "alarm" ? qsTr("Alarm · ") : "")
                                 + upWrap.modelData.text
                                 + (upWrap.modelData.recur && upWrap.modelData.recur !== "none"
                                    ? " · " + upWrap.modelData.recur : "")
                        done: !!upWrap.modelData.done
                        onToggled: Reminders.toggleDone(upWrap.modelData.id)
                        onRemoved: Reminders.remove(upWrap.modelData.id)
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.s3
                        Text {
                            text: qsTr("Snooze 5")
                            color: snoozeHov.hovered ? root.iceHover : root.iceFocus
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                            HoverHandler { id: snoozeHov; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: Reminders.snooze(upWrap.modelData.id, 5) }
                        }
                        Text {
                            text: qsTr("Snooze 10")
                            color: snooze10Hov.hovered ? root.iceHover : root.iceFocus
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                            HoverHandler { id: snooze10Hov; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: Reminders.snooze(upWrap.modelData.id, 10) }
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s4
                Repeater {
                    model: [
                        { id: "agenda", label: qsTr("Agenda") },
                        { id: "timer", label: qsTr("Timer") },
                        { id: "world", label: qsTr("World") },
                        { id: "alarm", label: qsTr("Alarm") }
                    ]
                    delegate: Text {
                        required property var modelData
                        text: modelData.label
                        color: root.clockPane === modelData.id ? root.iceFocus : Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                        font.weight: Font.Medium
                        font.letterSpacing: Theme.trackMicro
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.clockPane = modelData.id }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.clockPane === "timer"
                spacing: Theme.s2
                Text {
                    text: root.timerLabel()
                    font.family: Theme.fTech
                    font.pixelSize: Theme.tHead
                    font.features: ({ "tnum": 1 })
                    color: Theme.text
                }
                RowLayout {
                    spacing: Theme.s3
                    Text {
                        text: root.timerRun ? qsTr("Pause") : qsTr("Start")
                        color: root.iceFocus
                        font.pixelSize: Theme.tCaption
                        TapHandler {
                            onTapped: {
                                if (!root.timerRun && root.timerRemain <= 0)
                                    root.timerRemain = root.timerSet;
                                root.timerRun = !root.timerRun;
                            }
                        }
                    }
                    Text {
                        text: qsTr("Reset")
                        color: Theme.textMuted
                        font.pixelSize: Theme.tCaption
                        TapHandler {
                            onTapped: {
                                root.timerRun = false;
                                root.timerRemain = root.timerSet;
                            }
                        }
                    }
                    Text {
                        text: "+1"
                        color: Theme.textMuted
                        font.pixelSize: Theme.tCaption
                        TapHandler { onTapped: { root.timerSet += 60; if (!root.timerRun) root.timerRemain = root.timerSet; } }
                    }
                    Text {
                        text: "+5"
                        color: Theme.textMuted
                        font.pixelSize: Theme.tCaption
                        TapHandler { onTapped: { root.timerSet += 300; if (!root.timerRun) root.timerRemain = root.timerSet; } }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.clockPane === "world"
                spacing: Theme.s2
                Repeater {
                    model: root.worldCities
                    delegate: Text {
                        required property var modelData
                        Layout.fillWidth: true
                        text: root.worldLine(modelData)
                        color: Theme.textMuted
                        font.family: Theme.fTech
                        font.pixelSize: Theme.tCaption
                        font.features: ({ "tnum": 1 })
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: root.clockPane === "alarm"
                spacing: Theme.s2
                Text {
                    text: qsTr("Next alarm at %1:%2  ·  %3")
                          .arg(root.alarmH < 10 ? "0" + root.alarmH : root.alarmH)
                          .arg(root.alarmM < 10 ? "0" + root.alarmM : root.alarmM)
                          .arg(root.alarmRecur === "none" ? qsTr("once")
                             : (root.alarmRecur === "daily" ? qsTr("daily") : qsTr("weekly")))
                    color: Theme.textMuted
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    font.features: ({ "tnum": 1 })
                }
                RowLayout {
                    spacing: Theme.s3
                    Text {
                        text: "−h"
                        color: root.iceFocus
                        TapHandler { onTapped: root.alarmH = (root.alarmH + 23) % 24 }
                    }
                    Text {
                        text: "+h"
                        color: root.iceFocus
                        TapHandler { onTapped: root.alarmH = (root.alarmH + 1) % 24 }
                    }
                    Text {
                        text: "−m"
                        color: root.iceFocus
                        TapHandler { onTapped: root.alarmM = (root.alarmM + 55) % 60 }
                    }
                    Text {
                        text: "+m"
                        color: root.iceFocus
                        TapHandler { onTapped: root.alarmM = (root.alarmM + 5) % 60 }
                    }
                    Text {
                        text: root.alarmRecur === "none" ? qsTr("Once")
                            : (root.alarmRecur === "daily" ? qsTr("Daily") : qsTr("Weekly"))
                        color: root.iceHover
                        TapHandler {
                            onTapped: root.alarmRecur = root.alarmRecur === "none" ? "daily"
                                      : (root.alarmRecur === "daily" ? "weekly" : "none")
                        }
                    }
                    Text {
                        text: qsTr("Set")
                        color: root.iceFocus
                        font.weight: Font.Medium
                        TapHandler { onTapped: root.addAlarm() }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            Text {
                text: qsTr("Time settings  ›")
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                color: settingsHov.hovered ? root.iceHover : root.iceFocus
                HoverHandler { id: settingsHov; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        Bus.clockOpen = false;
                        // QML Settings, never PATH `nyxus-settings` (that
                        // name is NYXUS Panel on this host). datetime is
                        // still a pending page in the catalog.
                        Bus.openSettings("datetime");
                    }
                }
            }
        }
    }
}
