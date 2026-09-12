pragma ComponentBehavior: Bound
// Nyxus Suxyn — CALCULATOR. Glass app. Replaces GTK nyxus_calculator.py.
//
// Widget recipe (owner capture of the desktop chips):
//   glacier[5] #b7e6f2  pale ice FILL (meters, identity, equals wash)
//   glacier[4] #4f7fa6  1 px seam only
//   glacier[0] #7fe8ff  hover / focus / pressed ring
//   glacier[6] #eefcff  peak type (clock numerals, digit glyphs)
//   Theme.elevated      key floor    Theme.surface  aux floor
//   Theme.goldGlow      kicker pip   no magma on C
// Pad is the signature: IceKey tiles, same ladder as the GTK IceKey,
// painted in QML so the pad is one hue family at five depths.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

AppWindow {
    id: win

    titleText: qsTr("Calculator")
    iconName: "nyxus-calculator"
    subtitleText: win.degrees ? qsTr("DEG") : qsTr("RAD")
    open: Bus.calculatorOpen
    onDismissed: Bus.calculatorOpen = false

    implicitWidth: 400
    implicitHeight: 720
    minimumSize: Qt.size(360, 560)

    property string expr: ""
    property string result: "0"
    property var tape: []
    property var baseRows: []
    property real memory: 0
    property bool awaiting: false

    readonly property bool degrees: SettingsStore.stringValue("app_calc_angle", "Degrees") !== "Radians"
    readonly property bool group: SettingsStore.boolValue("app_calc_thousands", true)
    readonly property int precision: Math.round(SettingsStore.numberValue("app_calc_precision", 10))
    readonly property bool copyOnEquals: SettingsStore.boolValue("app_calc_copy_on_equals", false)

    // Widget recipe only. glacier[0] #7fe8ff is the teal the owner
    // keeps catching — it is hover light on a chip rim, never a fill
    // and never a glyph. Pale identity is glacier[5]; seams are
    // glacier[4]; numerals are Theme.text, same as the clock.
    readonly property color ice: Theme.tokenAccentPrimary
    readonly property color iceHair: Theme.tokenAccentHairline
    readonly property color iceFocus: Theme.tokenAccentInteractive

    function io() {
        return (Quickshell.env("HOME") || "") + "/.config/quickshell/calc-io.py";
    }

    function toggleAngle() {
        SettingsStore.setValue("app_calc_angle", win.degrees ? "Radians" : "Degrees");
    }

    function toggleGroup() {
        SettingsStore.setValue("app_calc_thousands", !win.group);
    }

    function roleOf(k) {
        if (k === "=") return "equals";
        if (k === "C") return "clear";
        if ("÷×−+".indexOf(k) >= 0) return "op";
        if ("()%".indexOf(k) >= 0) return "aux";
        return "digit";
    }

    function press(k) {
        if (k === "C") {
            win.expr = "";
            win.result = "0";
            win.baseRows = [];
            win.awaiting = false;
            return;
        }
        if (k === "=") {
            win.evaluateNow();
            return;
        }
        if (win.awaiting && "0123456789.".indexOf(k) >= 0) {
            win.expr = k;
            win.awaiting = false;
            return;
        }
        win.awaiting = false;
        win.expr += k;
    }

    function evaluateNow() {
        if (win.expr.length === 0)
            return;
        evalProc.command = ["python3", win.io(), JSON.stringify({
            expr: win.expr,
            degrees: win.degrees,
            group: win.group,
            precision: win.precision
        })];
        evalProc.running = false;
        evalProc.running = true;
    }

    function mem(op) {
        var n = Number(win.result);
        if (op === "MC") win.memory = 0;
        else if (op === "MR") {
            win.expr += String(win.memory);
            win.awaiting = false;
        } else if (op === "M+") {
            if (!isNaN(n)) win.memory += n;
        } else if (op === "M−" || op === "M-") {
            if (!isNaN(n)) win.memory -= n;
        }
    }

    function sci(sk) {
        win.awaiting = false;
        win.expr += sk;
    }

    onVisibleChanged: if (win.visible) padFocus.forceActiveFocus()

    IpcHandler {
        target: "calculator"
        function ready(): string { return "ready"; }
        function engage(): string {
            Bus.calculatorOpen = true;
            return "calculator";
        }
        function dismiss(): string {
            Bus.calculatorOpen = false;
            return "hidden";
        }
    }

    Process {
        id: evalProc
        running: false
        command: ["python3", win.io(), "{\"expr\":\"\"}"]
        onExited: function (code) { if (code !== 0) { win.result = qsTr("Error"); console.warn("[Calculator] io exited code " + code); } }
        stdout: StdioCollector {
            onStreamFinished: {
                var j;
                try { j = JSON.parse(String(this.text)); }
                catch (e) { win.result = qsTr("Error"); return; }
                if (!j.ok) {
                    win.result = qsTr("Error");
                    win.baseRows = [];
                    return;
                }
                win.result = j.text;
                win.baseRows = j.bases || [];
                var next = win.tape.slice();
                next.unshift({ expr: win.expr, result: j.text });
                if (next.length > 24)
                    next = next.slice(0, 24);
                win.tape = next;
                win.awaiting = true;
                if (win.copyOnEquals && String(j.text).length > 0)
                    Quickshell.execDetached(["wl-copy", "-n", "--", String(j.text)]);
            }
        }
    }

    // One widget chip, shrunk to a key. Same five layers as
    // Widgets.qml WidgetChip: opaque floor, Pane(panelMid), swell,
    // GlassEdge body 0, glacier[4] 1 px seam. Hover is glacier[0]
    // on that seam, never a second outline colour.
    component IceKey: Item {
        id: key
        property string caption: ""
        property string role: "digit"
        signal tapped()

        Layout.fillWidth: true
        Layout.fillHeight: true
        implicitHeight: 44
        implicitWidth: 72
        clip: false
        z: keyHov.hovered || tap.pressed ? 2 : 0

        readonly property bool prize: key.role === "equals"
        readonly property bool lifted: keyHov.hovered || key.prize || tap.pressed
        readonly property int rad: Theme.r1
        readonly property color glyph:
            key.prize ? Theme.void_
            : key.role === "aux" ? Theme.textDim
            : key.role === "clear" ? win.ice
            : Theme.text
        readonly property color ring:
            keyHov.hovered || tap.pressed ? win.iceFocus : win.iceHair

        scale: tap.pressed ? 0.97 : (keyHov.hovered ? 1.03 : 1.0)
        Behavior on scale {
            NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutQuint }
        }

        CutRect {
            anchors.fill: parent
            radius: key.rad
            color: key.role === "aux" ? Theme.surface : Theme.elevated
        }
        Pane {
            anchors.fill: parent
            elevation: 1
            bloomAtRest: false
            fill: Theme.panelMid
            radius: key.rad
            live: key.prize || tap.pressed ? 1 : 0
            focusLevel: key.lifted ? 0.45 : 0

            CutRect {
                anchors.fill: parent
                radius: key.rad
                gradTop: Theme.swellGroundTop
                gradMid: Theme.swellGroundMid
                gradFoot: Theme.swellGroundFoot
            }
            GlassEdge {
                anchors.fill: parent
                radiusTL: key.rad; radiusTR: key.rad
                radiusBR: key.rad; radiusBL: key.rad
                body: 0
                wash: 0
                edging: 0.70
            }
            MirrorEdge {
                radiusTL: key.rad; radiusTR: key.rad
                radiusBR: key.rad; radiusBL: key.rad
                depth: 10
                strength: 0.34
            }
            CutRect {
                anchors.fill: parent
                radius: key.rad
                color: "transparent"
                borderWidth: 1
                borderColor: Theme.soften(key.ring, key.lifted || key.prize ? 0.85 : 0.45)
                Behavior on borderColor {
                    ColorAnimation { duration: Theme.durQuick }
                }
            }
            // Equals is pale glacier[5] — the same ice that fills the
            // widget meters. Dark glyph on that fill. Not gold, not teal.
            Rectangle {
                visible: key.prize
                anchors.fill: parent
                anchors.margins: 4
                radius: Theme.r1
                color: Theme.tokenAccentPrimary
            }
        }
        Text {
            anchors.centerIn: parent
            z: 2
            text: key.caption
            color: key.glyph
            font.family: Theme.fNum
            font.pixelSize: Theme.tHead
            font.weight: (key.role === "op" || key.role === "equals" || key.role === "clear")
                         ? Font.Bold : Font.DemiBold
        }
        HoverHandler { id: keyHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: tap; onTapped: key.tapped() }
    }

    component GhostPill: Item {
        id: pill
        property string caption: ""
        property bool on: false
        signal tapped()
        Layout.preferredHeight: 28
        implicitWidth: lab.implicitWidth + Theme.s6
        implicitHeight: 28

        CutRect {
            anchors.fill: parent
            radius: height / 2
            color: Theme.elevated
        }
        Pane {
            anchors.fill: parent
            elevation: 1
            bloomAtRest: false
            fill: Theme.panelMid
            radius: height / 2
            focusLevel: pill.on || pillHov.hovered ? 0.45 : 0
            GlassEdge {
                anchors.fill: parent
                radiusTL: pill.height / 2; radiusTR: pill.height / 2
                radiusBR: pill.height / 2; radiusBL: pill.height / 2
                body: 0
                wash: 0
                edging: 0.70
            }
            CutRect {
                anchors.fill: parent
                radius: pill.height / 2
                color: "transparent"
                borderWidth: 1
                borderColor: Theme.soften(Theme.tokenAccentHairline,
                                          pill.on || pillHov.hovered ? 0.85 : 0.45)
            }
        }
        Text {
            id: lab
            anchors.centerIn: parent
            z: 2
            text: pill.caption
            color: pill.on ? Theme.text : Theme.textMuted
            font.family: Theme.fUi
            font.pixelSize: Theme.tCaption
            font.weight: Theme.wStrong
        }
        HoverHandler { id: pillHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: pill.tapped() }
    }

    Item {
        id: padFocus
        anchors.fill: parent
        focus: true
        Keys.onPressed: function (e) {
            var t = e.text;
            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                win.press("="); e.accepted = true;
            } else if (e.key === Qt.Key_Escape || e.key === Qt.Key_Delete) {
                win.press("C"); e.accepted = true;
            } else if (e.key === Qt.Key_Backspace) {
                win.expr = win.expr.slice(0, -1); e.accepted = true;
            } else if (t === "*") { win.press("×"); e.accepted = true; }
            else if (t === "/") { win.press("÷"); e.accepted = true; }
            else if (t === "-") { win.press("−"); e.accepted = true; }
            else if (t.length === 1 && "0123456789.+%()=".indexOf(t) >= 0) {
                win.press(t); e.accepted = true;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.s4

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s3
                StatusPip {
                    kind: "amber"
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    text: qsTr("CALCULATOR")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    font.weight: Theme.wStrong
                    font.letterSpacing: Theme.trackMicro
                }
                Item { Layout.fillWidth: true }
                StatusPip {
                    kind: "ice"
                    visible: win.memory !== 0
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    visible: win.memory !== 0
                    text: qsTr("M")
                    color: Theme.textDim
                    font.family: Theme.fNum
                    font.pixelSize: Theme.tMicro
                    font.features: ({ "tnum": 1 })
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 88
                spacing: Theme.s3

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    CutRect {
                        anchors.fill: parent
                        radius: Theme.r2
                        color: Theme.elevated
                    }
                    Pane {
                        anchors.fill: parent
                        elevation: 1
                        bloomAtRest: false
                        fill: Theme.panelMid
                        radius: Theme.r2
                        CutRect {
                            anchors.fill: parent
                            radius: Theme.r2
                            gradTop: Theme.swellGroundTop
                            gradMid: Theme.swellGroundMid
                            gradFoot: Theme.swellGroundFoot
                        }
                        GlassEdge {
                            anchors.fill: parent
                            radiusTL: Theme.r2; radiusTR: Theme.r2
                            radiusBR: Theme.r2; radiusBL: Theme.r2
                            body: 0
                            wash: 0
                            edging: 0.70
                        }
                        MirrorEdge {
                            radiusTL: Theme.r2; radiusTR: Theme.r2
                            radiusBR: Theme.r2; radiusBL: Theme.r2
                            depth: 10
                            strength: 0.34
                        }
                        CutRect {
                            anchors.fill: parent
                            radius: Theme.r2
                            color: "transparent"
                            borderWidth: 1
                            borderColor: Theme.soften(Theme.tokenAccentHairline, 0.45)
                        }
                    }
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.s4
                        z: 2
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: win.expr.length > 0 ? win.expr : " "
                            color: Theme.textMuted
                            font.family: Theme.fNum
                            font.pixelSize: Theme.tCaption
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideLeft
                            maximumLineCount: 1
                            wrapMode: Text.NoWrap
                            clip: true
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: win.result
                            color: Theme.text
                            font.family: Theme.fNum
                            font.pixelSize: Theme.tDisplay
                            font.weight: Theme.wStrong
                            horizontalAlignment: Text.AlignRight
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideLeft
                            maximumLineCount: 1
                            wrapMode: Text.NoWrap
                            clip: true
                            font.features: ({ "tnum": 1 })
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: win.degrees ? qsTr("DEG") : qsTr("RAD")
                    color: Theme.textDim
                    font.family: Theme.fNum
                    font.pixelSize: Theme.tMicro
                    font.features: ({ "tnum": 1 })
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: win.toggleAngle() }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s3
                GhostPill { caption: "1,000"; on: win.group; onTapped: win.toggleGroup() }
                Item { Layout.fillWidth: true }
                Repeater {
                    model: ["MC", "MR", "M+", "M−"]
                    GhostPill {
                        required property string modelData
                        caption: modelData
                        onTapped: win.mem(modelData)
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 4
                rowSpacing: Theme.s2
                columnSpacing: Theme.s2
                Repeater {
                    model: ["sqrt(", "^", "pi", "ln(", "log(", "sin(", "cos(", "tan("]
                    GhostPill {
                        required property string modelData
                        Layout.fillWidth: true
                        caption: modelData.replace("(", "")
                        onTapped: win.sci(modelData)
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 4
                rowSpacing: Theme.s3
                columnSpacing: Theme.s3
                Repeater {
                    model: [
                        "(", ")", "%", "C",
                        "7", "8", "9", "÷",
                        "4", "5", "6", "×",
                        "1", "2", "3", "−",
                        "0", ".", "=", "+"
                    ]
                    IceKey {
                        required property string modelData
                        caption: modelData
                        role: win.roleOf(modelData)
                        onTapped: win.press(modelData)
                    }
                }
            }

            RowLayout {
                visible: win.baseRows.length > 0
                Layout.fillWidth: true
                spacing: Theme.s4
                Repeater {
                    model: win.baseRows
                    Text {
                        required property var modelData
                        Layout.fillWidth: true
                        text: modelData.k + "  " + modelData.v
                        color: Theme.textMuted
                        font.family: Theme.fNum
                        font.pixelSize: Theme.tMicro
                        font.features: ({ "tnum": 1 })
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        wrapMode: Text.NoWrap
                        clip: true
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                visible: win.tape.length > 0
                clip: true
                ColumnLayout {
                    anchors.fill: parent
                    spacing: Theme.s2
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: qsTr("TAPE")
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tMicro
                            font.weight: Theme.wStrong
                            font.letterSpacing: Theme.trackMicro
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: qsTr("Clear tape")
                            color: Theme.textMuted
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            elide: Text.ElideRight
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: win.tape = [] }
                        }
                    }
                    Repeater {
                        model: win.tape.slice(0, 2)
                        Text {
                            required property var modelData
                            Layout.fillWidth: true
                            text: modelData.expr + "  =  " + modelData.result
                            color: Theme.textMuted
                            font.family: Theme.fNum
                            font.pixelSize: Theme.tCaption
                            elide: Text.ElideRight
                            maximumLineCount: 1
                            wrapMode: Text.NoWrap
                            clip: true
                        }
                    }
                }
            }
        }
    }
}
