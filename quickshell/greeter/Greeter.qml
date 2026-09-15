pragma ComponentBehavior: Bound
// Nyxus Suxyn — THE GREETER. The screen before the desktop.
//
// ── WHY THIS EXISTS ──────────────────────────────────────────────────────────
// ReGreet is a GTK4 app, and `/etc/greetd/regreet.css` already documents the
// wall it hits (line 136): "NOTE FOR ANYONE ADDING A WORDMARK HERE: you cannot."
// GTK cannot place the mark, there is no compositor blur behind the greeter, so
// no real glass — the login could only ever approximate the desktop.
//
// This is the same kit the desktop is built from, so it does not approximate
// anything: the live Starlight sky as fallback, the build's glass, the same
// Theme tokens. What the owner sees before logging in is what he logs in to.
//
// ── THE HANDOFF, AND WHY AUTH AND START ARE SEPARATE ─────────────────────────
// greetd kills the greeter the instant `start_session` succeeds. If the two
// were one step the unlock swirl would be killed halfway. So `nyxus-greet-auth`
// splits them: AUTH verifies and stops, this file plays the transition, and
// only when the swirl has covered the screen does START fire. The desktop shell
// comes up already covered by its own swirl, which then dissipates — so the two
// processes hand off underneath a single continuous animation and the user
// never sees the seam.
//
// ── SAFETY ───────────────────────────────────────────────────────────────────
// If this file fails to load, greetd's launcher falls through to ReGreet, then
// tuigreet, then agreety. A hang is the one case a fallback chain cannot catch,
// so `watchdog` below exits non-zero if no session has started in 90 s, which
// hands control back to the chain.
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io

Window {
    id: root

    visible: true
    visibility: Window.FullScreen
    color: "#020506"                       // Theme.void_ — the ground under everything

    property string username: Quickshell.env("NYXUS_GREET_USER") || "gowski"
    readonly property string hostLabel:
        Quickshell.env("HOSTNAME") || Quickshell.env("HOST") || "nyxus suxyn"
    // Full path: greeter's PATH does not include /usr/local/libexec.
    readonly property string authBin:
        Quickshell.env("NYXUS_GREET_AUTH") || "/usr/local/libexec/nyxus-greet-auth"
    property string sessionCmd: "nyxus-session-start"
    property string status: ""
    property bool busy: false
    property bool unlocking: false
    property bool capsOn: false

    // glacier[4] is the 1 px seam rung — a divider, never a fill.
    // Routed through a color property: paintLayers values are strings, and
    // Theme.soften reads .r off a string as undefined (Lock.qml TRK-3670).
    readonly property color iceHairline: Theme.paintLayers["glacier"][4]
    readonly property color icePrimary:  Theme.paintLayers["glacier"][5]
    readonly property color magmaHot:    Theme.paintLayers["magma"][5]   // #ff7847 — the no

    readonly property string greetTheme:
        (Quickshell.env("NYXUS_GREET_THEME") === "alien") ? "alien" : "nyxus"
    readonly property bool _alien: greetTheme === "alien"

    // ── the sky ──────────────────────────────────────────────────────────────
    // Fallback only. The photograph is the login picture; this is what you
    // get if neither candidate is readable, instead of a black screen.
    HeadlinerSky {
        anchors.fill: parent
        active: !root.unlocking
        twinkling: true
        density: 1.0
        master: 1.0
    }

    // ── his login image ──────────────────────────────────────────────────────
    // B&W milky way + vortex Earth. Bundled copy is frame 0 so cage's first
    // buffer is the photograph, not void (TRK-3243). /etc/greetd is the
    // seed; cache is last because the GTK lane may overwrite it with GRUB
    // starlight. lock-still.png is a different picture — do not use it.
    readonly property var bgCandidates: [
        Qt.resolvedUrl("login-still.png"),
        "file:///etc/greetd/nyxus-login-bg.png",
        "file:///var/cache/regreet/nyxus-login-bg.png"
    ]
    property int bgIndex: 0
    // Hide the pointer until the still is up. cage has no hide-until-first-
    // frame flag; a blank cursor on the first buffer is the remaining trick.
    MouseArea {
        anchors.fill: parent
        z: 1
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        cursorShape: loginBg.status === Image.Ready ? Qt.ArrowCursor : Qt.BlankCursor
    }
    Image {
        id: loginBg
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: true
        smooth: true
        source: root.bgCandidates[root.bgIndex]
        visible: status === Image.Ready
        opacity: root.unlocking ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 380 } }
        onStatusChanged: {
            if (status === Image.Error
                && root.bgIndex + 1 < root.bgCandidates.length)
                root.bgIndex++;
        }
    }

    // ── slow motion IN the photograph ────────────────────────────────────────
    // UV warp of the BOTTOM vortex only. The still Image stays on screen
    // underneath; this pass writes premultiplied alpha equal to the mask, so
    // every pixel outside the Earth is the file, bit for bit.
    //
    // Swirl dye is NOT used here. Over greyscale it read as a clouded film
    // (opacity had to be forced to 0). The fluid stays on the unlock handoff
    // below, where it is supposed to cover the screen.
    ShaderEffect {
        id: vortexFx
        anchors.fill: parent
        visible: loginBg.status === Image.Ready && !root.unlocking
        blending: true
        fragmentShader: Qt.resolvedUrl("shaders/login_vortex.frag.qsb")
        property variant src: loginBg
        property vector2d u_resolution: Qt.vector2d(width, height)
        // Centre of the hole, ellipse covering the Earth disk, not the sky.
        property vector4d u_vortex: Qt.vector4d(0.50, 0.89, 0.56, 0.30)
        // t seconds · y-fade 0.66→0.78 (milky way is ~0.25–0.55) · 0.014 rad/s
        property vector4d u_time: Qt.vector4d(vortexClock.t, 0.66, 0.78, 0.014)
        opacity: root.unlocking ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 380 } }
    }
    // 20 Hz is enough for a 10-minute revolution. A FrameAnimation would
    // pin Qt's global animation driver at the panel rate for one slow twist.
    Timer {
        id: vortexClock
        running: vortexFx.visible
        interval: 50
        repeat: true
        property real t: 0
        onTriggered: vortexClock.t += interval / 1000.0
    }

    // ── the input ────────────────────────────────────────────────────────────
    // BOXED glass card, parked in the dark sky ABOVE the milky way. The
    // vortex lives in the bottom third; a card on the Earth is the lock
    // screen lesson (owner 2026-08-23: "the login card and what not are on
    // the earth image") and is not repeated here.
    Item {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * 0.08)
        width: Math.min(340, parent.width * 0.28)
        height: fieldsCol.implicitHeight
        z: 3
        opacity: root.unlocking ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

        readonly property int cardCut: 0
        readonly property int cardR: Theme.r2
        readonly property int pad: 20

        // ── THE CARD · widget glass, not a strip ─────────────────────────
        // Desktop WidgetChip recipe (Widgets.qml TRK-3042 / TRK-3056):
        //   swellGround well  →  panelMid paint  →  GlassEdge body 0
        // plus a glacier[4] 1 px seam. No teal fill. No purple haze.
        // Chamfer stays 0 — owner 2026-09-07: "dont do the edges like that".
        Item {
            id: plate
            anchors.fill: parent
            anchors.margins: -panel.pad

            CutRect {
                anchors.fill: parent
                radius: panel.cardR
                chamfer: panel.cardCut
                gradTop:  Theme.swellGroundTop
                gradMid:  Theme.swellGroundMid
                gradFoot: Theme.swellGroundFoot
            }
            CutRect {
                anchors.fill: parent
                radius: panel.cardR
                chamfer: panel.cardCut
                color: Theme.panelMid
            }
            GlassEdge {
                anchors.fill: parent
                radiusTL: panel.cardR; radiusTR: panel.cardR
                radiusBR: panel.cardR; radiusBL: panel.cardR
                body: 0
                wash: 0
                bleed: 0
                edging: 0.85
            }
            // glacier[4] 1 px seam. Magma only when the machine says no.
            CutRect {
                anchors.fill: parent
                radius: panel.cardR
                chamfer: panel.cardCut
                color: "transparent"
                borderWidth: 1
                borderColor: root.status === "bad" ? root.magmaHot : root.iceHairline
                Behavior on borderColor { ColorAnimation { duration: 160 } }
            }
        }

        Column {
            id: fieldsCol
            width: parent.width
            spacing: 10

            // Name.
            Rectangle {
                id: nameWell
                width: parent.width
                height: 44
                radius: 11
                color: Theme.soften(Theme.void_, 0.62)
                border.width: 1
                border.color: userField.activeFocus ? root.iceHairline
                            : Theme.soften(root.iceHairline, 0.35)
                Behavior on border.color { ColorAnimation { duration: 160 } }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: parent.radius
                    anchors.rightMargin: parent.radius
                    anchors.topMargin: 1
                    height: 1
                    color: Qt.rgba(0, 0, 0, 0.42)
                }

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: Text.AlignVCenter
                    visible: userField.text.length === 0 && !userField.activeFocus
                    text: qsTr("name")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: 13
                    font.letterSpacing: 1.4
                }
                TextInput {
                    id: userField
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fUi
                    font.pixelSize: 14
                    font.letterSpacing: 1.2
                    selectByMouse: true
                    enabled: !root.busy && !root.unlocking
                    Component.onCompleted: text = root.username
                    onTextChanged: root.username = text
                    onAccepted: {
                        if (pw.text.length === 0)
                            pw.forceActiveFocus();
                        else
                            root.submit();
                    }
                    Keys.onTabPressed: function (event) {
                        pw.forceActiveFocus();
                        event.accepted = true;
                    }
                    Keys.onPressed: function (event) {
                        root.capsOn = (event.modifiers & Qt.CapsLockModifier) !== 0;
                    }
                }
            }

            // Password. Shake lives on this wrapper — the well itself is
            // x/y laid out, so animating anchors.horizontalCenterOffset
            // (the previous field) was a no-op.
            Item {
                id: fieldWrap
                width: parent.width
                height: 44

                Rectangle {
                    id: field
                    anchors.fill: parent
                    radius: 11
                    color: Theme.soften(Theme.void_, 0.62)
                    border.width: 1
                    border.color: root.status === "bad" ? root.magmaHot
                                : (pw.activeFocus ? root.iceHairline
                                                  : Theme.soften(root.iceHairline, 0.35))
                    Behavior on border.color { ColorAnimation { duration: 160 } }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: parent.radius
                        anchors.rightMargin: parent.radius
                        anchors.topMargin: 1
                        height: 1
                        color: Qt.rgba(0, 0, 0, 0.42)
                    }
                    // Focus cue is a 1 px glacier[4] underline, never a fill.
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: parent.width * 0.18
                        anchors.rightMargin: parent.width * 0.18
                        anchors.bottomMargin: 1
                        height: 1
                        color: root.status === "bad" ? root.magmaHot : root.iceHairline
                        opacity: root.status === "bad" ? 0.85
                               : (pw.activeFocus ? 0.70 : 0.0)
                        Behavior on opacity { NumberAnimation { duration: 220 } }
                        Behavior on color { ColorAnimation { duration: 160 } }
                    }

                    GlyphTrack {
                        visible: root._alien
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        count: pw.text.length
                        alarmed: root.status === "bad"
                        glyphColor: pw.activeFocus ? root.icePrimary : root.iceHairline
                    }

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: Text.AlignVCenter
                        visible: !root._alien && pw.text.length === 0 && !pw.activeFocus
                        text: qsTr("password")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: 13
                        font.letterSpacing: 1.4
                    }
                    TextInput {
                        id: pw
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: root._alien ? "transparent" : Theme.text
                        font.family: Theme.fUi
                        font.pixelSize: 15
                        selectByMouse: true
                        focus: true
                        enabled: !root.busy && !root.unlocking
                        onAccepted: root.submit()
                        onTextChanged: if (root.status === "bad") root.status = ""
                        Keys.onPressed: function (event) {
                            root.capsOn = (event.modifiers & Qt.CapsLockModifier) !== 0;
                        }
                    }
                }

                SequentialAnimation {
                    id: shake
                    loops: 2
                    NumberAnimation { target: fieldWrap; property: "x"; to: 9;  duration: 45 }
                    NumberAnimation { target: fieldWrap; property: "x"; to: -9; duration: 90 }
                    NumberAnimation { target: fieldWrap; property: "x"; to: 0;  duration: 45 }
                }
            }

            Text {
                id: subline
                width: parent.width
                elide: Text.ElideRight
                text: root.busy ? qsTr("Checking…")
                     : root.status === "bad" ? qsTr("Not that one")
                     : root.hostLabel
                color: root.status === "bad" ? root.magmaHot : Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: 11
                font.letterSpacing: 1.6
                Behavior on color { ColorAnimation { duration: 160 } }
            }
        }
    }

    Text {
        id: capsWarn
        anchors.horizontalCenter: parent.horizontalCenter
        y: panel.y + panel.height + panel.pad + 10
        z: 3
        visible: root.capsOn && !root.unlocking
        text: qsTr("Caps Lock is on")
        color: "#f7a83b"
        font.family: Theme.fUi
        font.pixelSize: 13
    }

    // ── the swirl ────────────────────────────────────────────────────────────
    // Unlock handoff only. Opaque flood, then START. Not the photo drift.
    Swirl {
        id: swirl
        anchors.fill: parent
        z: 50
        opaque: true
        interactive: false
        cornerRadius: 0
        intensity: 1.0
        opacity: 0
        visible: opacity > 0.001
        Behavior on opacity { NumberAnimation { duration: 520; easing.type: Easing.InOutCubic } }
    }

    // ── chrome ───────────────────────────────────────────────────────────────
    GreeterChrome {
        anchors.fill: parent
        z: 4
        opacity: root.unlocking ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 380 } }
        onPower: function (what) { power.command = ["systemctl", what]; power.running = true; }
    }

    Process { id: power; running: false }

    // ── the session picker ───────────────────────────────────────────────────
    // Hidden until a second session exists. The scan never writes sessionCmd
    // — only a click does.
    property var sessions: []
    Process {
        id: sessionScan
        running: true
        command: ["sh", "-c",
            "for f in /usr/share/wayland-sessions/*.desktop " +
            "/usr/share/xsessions/*.desktop; do [ -f \"$f\" ] || continue; " +
            "n=$(grep -m1 '^Name=' \"$f\" | cut -d= -f2-); " +
            "e=$(grep -m1 '^Exec=' \"$f\" | cut -d= -f2-); " +
            "[ -n \"$e\" ] && printf '%s\\t%s\\n' \"$n\" \"$e\"; done"]
        stdout: SplitParser {
            onRead: function (line) {
                var s = String(line).trim();
                if (s === "") return;
                var i = s.indexOf("\t");
                if (i < 1) return;
                var nm = s.substring(0, i).trim();
                var ex = s.substring(i + 1).trim();
                if (ex === "") return;
                var list = root.sessions.slice();
                list.push({ name: nm === "" ? ex : nm, exec: ex });
                root.sessions = list;
            }
        }
    }

    Row {
        id: sessionRow
        anchors.horizontalCenter: parent.horizontalCenter
        y: panel.y + panel.height + panel.pad + 28
        spacing: 18
        z: 3
        visible: root.sessions.length > 1 && !root.unlocking
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220 } }

        Repeater {
            model: root.sessions
            delegate: Text {
                required property var modelData
                readonly property bool picked:
                    root.sessionCmd === modelData.exec
                text: modelData.name
                color: picked ? root.icePrimary : Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: 12
                font.letterSpacing: 1.6
                Behavior on color { ColorAnimation { duration: 160 } }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.sessionCmd = parent.modelData.exec
                }
            }
        }
    }

    // ── the conversation ─────────────────────────────────────────────────────
    Process {
        id: auth
        running: true
        command: [root.authBin]
        stdinEnabled: true
        stdout: SplitParser {
            onRead: function (line) {
                var s = String(line).trim();
                if (s === "OK") {
                    if (root.unlocking) return;      // START's OK — greetd takes over
                    root.busy = false;
                    root.beginUnlock();
                } else if (s.indexOf("FAIL") === 0) {
                    root.busy = false;
                    root.status = "bad";
                    pw.text = "";
                    shake.restart();
                } else if (s.indexOf("ERR") === 0) {
                    root.busy = false;
                    root.status = "bad";
                }
            }
        }
    }

    function submit() {
        if (root.busy || root.unlocking || pw.text.length === 0)
            return;
        var who = String(userField.text).trim();
        if (who.length === 0)
            return;
        root.username = who;
        root.busy = true;
        root.status = "";
        auth.write("AUTH " + root.username + "\n" + pw.text + "\n");
        pw.text = "";
    }

    // ── the unlock ───────────────────────────────────────────────────────────
    // Ignite from the field, let the solver flood, and only hand off once the
    // screen is covered. `handoff` fires START; greetd then replaces us.
    function beginUnlock() {
        root.unlocking = true;
        swirl.opacity = 1;
        swirl.ignite();
        swirl.dropAt(0.5, 0.55, 1.0, 0.0, -1.0);
        swirl.dropAt(0.32, 0.5, 0.8, -0.6, -0.4);
        swirl.dropAt(0.68, 0.5, 0.8, 0.6, -0.4);
        handoff.start();
    }

    Timer {
        id: handoff
        interval: 900                       // swirl has covered by here
        onTriggered: auth.write("START " + root.sessionCmd + "\n")
    }

    // ── the watchdog ─────────────────────────────────────────────────────────
    // The fallback chain catches a greeter that EXITS. It cannot catch one that
    // hangs — a black screen with no prompt is the worst outcome, so this exits
    // non-zero and hands control back to ReGreet.
    Timer {
        id: watchdog
        running: true
        interval: 90000
        onTriggered: {
            if (!root.unlocking)
                Qt.exit(1);
        }
    }
}
