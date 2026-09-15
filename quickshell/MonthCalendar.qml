// Nyxus Suxyn — a compact month calendar, Monday-first.
//
// Ice day stone: today is an elevated chip, not a teal sweep fill.
// Weekday headers use the micro style, the same voice every other section
// header in the shell speaks in.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

Item {
    id: calRoot
    implicitWidth: inner.implicitWidth
    implicitHeight: inner.implicitHeight

    property var now: new Date()
    property int viewYear: now.getFullYear()
    property int viewMonth: now.getMonth()   // 0-based

    readonly property var monthNames: ["January", "February", "March", "April",
                                       "May", "June", "July", "August",
                                       "September", "October", "November", "December"]

    // Ice day stone — same rungs as SetIceFace. Today was Theme.sweep0→sweep2
    // (`#0aa2d6` fill, banned). Magma none. Hover glacier[5], focus glacier[0].
    readonly property color iceElevated: Theme.elevated                 // #071318
    readonly property color iceSeam:     Theme.lookSeam   // #4f7fa6
    readonly property color icePeak: Theme.stateLayer[6]   // #eefcff
    readonly property color iceHover: Theme.stateLayer[5]   // #b7e6f2
    readonly property color iceFocus: Theme.stateLayer[0]   // #7fe8ff

    // Emitted when a day is tapped. The calendar does not own what happens
    // next — a month grid is the wrong place to host an editor — so it reports
    // the day and whoever embedded it decides. WIP-108: one store, many views.
    signal daySelected(int y, int m, int d)

    function daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate(); }
    // Monday-first offset for the 1st of the month (0 = Monday).
    function firstOffset(y, m) { return (new Date(y, m, 1).getDay() + 6) % 7; }

    // ── TRK-2902 · THE GRID IS AS MANY ROWS AS THE MONTH HAS ────────────
    // The Repeater's model was the literal 42 — six rows, always. Six rows
    // is the WORST case (a 31-day month whose 1st falls on a Saturday or
    // Sunday), and it is rare: over 2026 exactly four months need it. The
    // other eight drew a whole row of empty cells, 21 px of cell plus one
    // s2 of row spacing = 25 px of nothing at the bottom of every calendar
    // this component appears in — the Clock popup and the side panel's
    // Calendar section both.
    //
    // Computed from the month, not counted by hand: offset + length, rounded
    // up to whole weeks. A 28-day February that begins on a Monday resolves
    // to FOUR rows and gives back 50 px.
    readonly property int gridRows:
        Math.ceil((calRoot.firstOffset(calRoot.viewYear, calRoot.viewMonth)
                   + calRoot.daysInMonth(calRoot.viewYear, calRoot.viewMonth)) / 7)

    // §11.1: a live control is a chip of the material. Ice day stones stay
    // the face; this is the shared edge, not a second fill (body/glaze/bleed
    // off so it does not veil the elevated chips).
    GlassEdge {
        anchors.fill: parent
        radiusTL: Theme.r2
        radiusTR: Theme.r2
        radiusBR: Theme.r2
        radiusBL: Theme.r2
        edging: 0.30
        body: 0
        wash: 0
        glaze: 0
        bleed: 0
    }

    ColumnLayout {
        id: inner
        anchors.fill: parent
        spacing: Theme.s4

    // ── header ───────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true

        Text {
            text: "‹"
            color: Theme.textMuted
            font.pixelSize: Theme.tHead
            TapHandler {
                onTapped: {
                    if (calRoot.viewMonth === 0) {
                        calRoot.viewMonth = 11;
                        calRoot.viewYear--;
                    } else
                        calRoot.viewMonth--;
                }
            }
        }
        Item { Layout.fillWidth: true }
        Text {
            text: calRoot.monthNames[calRoot.viewMonth] + " " + calRoot.viewYear
            color: Theme.text
            font.family: Theme.fUi
            font.pixelSize: Theme.tLabel
            font.weight: Font.Medium
        }
        Item { Layout.fillWidth: true }
        Text {
            text: "›"
            color: Theme.textMuted
            font.pixelSize: Theme.tHead
            TapHandler {
                onTapped: {
                    if (calRoot.viewMonth === 11) {
                        calRoot.viewMonth = 0;
                        calRoot.viewYear++;
                    } else
                        calRoot.viewMonth++;
                }
            }
        }
    }

    // ── weekday row ──────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        Repeater {
            model: ["M", "T", "W", "T", "F", "S", "S"]
            delegate: Text {
                required property var modelData
                Layout.fillWidth: true
                text: modelData
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tMicro
                font.weight: Font.Medium
                font.letterSpacing: Theme.trackMicro
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // ── day grid ─────────────────────────────────────────────────────
    GridLayout {
        Layout.fillWidth: true
        columns: 7
        rowSpacing: Theme.s2
        columnSpacing: 0

        Repeater {
            model: calRoot.gridRows * 7
            delegate: Item {
                id: cell
                required property int index
                Layout.fillWidth: true
                Layout.preferredHeight: 21

                readonly property int dayNum: index - calRoot.firstOffset(calRoot.viewYear, calRoot.viewMonth) + 1
                readonly property bool inMonth: dayNum >= 1 && dayNum <= calRoot.daysInMonth(calRoot.viewYear, calRoot.viewMonth)
                readonly property bool isToday: inMonth
                    && dayNum === calRoot.now.getDate()
                    && calRoot.viewMonth === calRoot.now.getMonth()
                    && calRoot.viewYear === calRoot.now.getFullYear()

                // Re-reads whenever the store changes: `Reminders.items` is
                // reassigned on every write rather than mutated, precisely so
                // this binding fires. Mutating the array in place would leave
                // the dot stale until something else happened to repaint.
                readonly property int reminderCount: (Reminders.items, cell.inMonth)
                    ? Reminders.countForDay(calRoot.viewYear, calRoot.viewMonth, cell.dayNum)
                    : 0
                readonly property bool isHoliday: cell.inMonth
                    && Holidays.hasKind(calRoot.viewYear, calRoot.viewMonth, cell.dayNum, "federal")
                readonly property bool isDst: cell.inMonth
                    && Holidays.hasKind(calRoot.viewYear, calRoot.viewMonth, cell.dayNum, "dst")
                readonly property bool isSeason: cell.inMonth
                    && Holidays.hasKind(calRoot.viewYear, calRoot.viewMonth, cell.dayNum, "season")
                readonly property bool isMarked: cell.reminderCount > 0
                    || cell.isHoliday || cell.isDst || cell.isSeason

                // Today only is a stone. Rest days stay open — 42 elevated
                // discs read as a waffle, not a month.
                Rectangle {
                    anchors.centerIn: parent
                    width: 20
                    height: 20
                    radius: 10
                    visible: cell.inMonth
                    color: cell.isToday ? calRoot.iceElevated
                         : (cell.isHoliday ? Theme.soften(calRoot.iceFocus, 0.16)
                         : (cellHov.hovered ? Theme.soften(calRoot.iceHover, 0.18) : "transparent"))
                    border.width: (cell.isToday || cellHov.hovered || cell.isHoliday) ? 1 : 0
                    border.color: cell.isToday ? calRoot.iceFocus
                                : (cell.isHoliday ? calRoot.iceFocus : calRoot.iceHover)

                    Rectangle {
                        visible: cell.isToday
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 3
                        width: 8
                        height: 1
                        radius: 0.5
                        // TRK-3057 — teal catch, not glacier[6] ice. Same
                        // strength as TRK-3009 (0.38 rest / 0.70 hover).
                        color: Theme.soften(Theme.teal, cellHov.hovered ? 0.70 : 0.38)
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cell.dayNum
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                        font.weight: cell.isToday ? Font.DemiBold : Font.Normal
                        color: cell.isToday ? Theme.teal : Theme.textMuted
                    }
                }

                // Event (ice) and holiday (teal) pips. DST is goldGlow so
                // the spring-forward / fall-back days are not the same mark
                // as a federal holiday. Season hinges share the holiday pip
                // (first day of summer is the one people look for).
                Row {
                    visible: cell.inMonth && cell.isMarked
                    spacing: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    Rectangle {
                        visible: cell.reminderCount > 0
                        width: 3; height: 3; radius: 1.5
                        color: cell.isToday ? Theme.teal : calRoot.iceFocus
                    }
                    Rectangle {
                        visible: cell.isHoliday || cell.isSeason
                        width: 3; height: 3; radius: 1.5
                        color: Theme.teal
                    }
                    Rectangle {
                        visible: cell.isDst
                        width: 3; height: 3; radius: 1.5
                        color: Theme.goldGlow
                    }
                }

                HoverHandler { id: cellHov; enabled: cell.inMonth; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    enabled: cell.inMonth
                    onTapped: calRoot.daySelected(calRoot.viewYear, calRoot.viewMonth, cell.dayNum)
                }
            }
        }
    }
    }
}
