pragma ComponentBehavior: Bound
// Nyxus Suxyn — WEATHER. Luxury glass: sky hero, AppCards, 24h, week.
// Open-Meteo via weather-io / weather.json. Magma pip on WEATHER only.
// Units from the file. Live sky and refresh interval from Settings.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

AppWindow {
    id: win

    titleText: qsTr("Weather")
    iconName: "nyxus-weather"
    subtitleText: win.placeName.length ? win.placeName : qsTr("Search for a city")
    open: Bus.weatherOpen
    onDismissed: Bus.weatherOpen = false
    implicitWidth: 1020
    implicitHeight: 780
    minimumSize: Qt.size(820, 600)

    property string placeName: ""
    property string admin: ""
    property string units: "imperial"
    property var places: []
    property var hours: []
    property var days: []
    property var temp: null
    property var feel: null
    property string label: ""
    property string unit: "°F"
    property var wind: null
    property string wunit: "mph"
    property var gust: null
    property var hum: null
    property var press: null
    property var uv: null
    property var aqi: null
    property var cloud: null
    property string sunrise: ""
    property string sunset: ""
    property string status: qsTr("Search for a city to begin.")
    property string query: ""
    property bool fetching: false
    property real skyPhase: 0
    property int nowMin: 0

    readonly property color iceHair: Theme.tokenAccentHairline
    readonly property color iceFocus: Theme.stateLayer[0]

    readonly property bool liveSky: SettingsStore.boolValue("app_weather_live_sky", true)
    readonly property int refreshMins: Math.max(10, Math.round(SettingsStore.numberValue("app_weather_refresh_mins", 60)))

    readonly property real tempFill: {
        if (win.temp === null || win.temp === undefined || win.temp === "")
            return -1;
        var t = Number(win.temp);
        if (isNaN(t))
            return -1;
        if (win.units === "metric")
            return Math.max(0, Math.min(1, (t + 15) / 50));
        return Math.max(0, Math.min(1, (t - 5) / 95));
    }
    readonly property bool hasSun: win.sunrise.length >= 16 && win.sunset.length >= 16
    readonly property real sunT: {
        var sr = win.mins(win.sunrise);
        var ss = win.mins(win.sunset);
        if (sr < 0 || ss <= sr)
            return -1;
        return Math.max(0, Math.min(1, (win.nowMin - sr) / (ss - sr)));
    }
    readonly property int sunIdx: win.sunT < 0 ? -1 : Math.round(win.sunT * 12)
    readonly property string where: win.placeName.length
        ? (win.placeName + (win.admin.length ? (", " + win.admin) : ""))
        : qsTr("No place set")
    readonly property string bulletin: {
        if (!win.placeName.length || win.temp === null || win.temp === undefined)
            return "";
        var s = win.placeName + ". " + win.label + ", " + win.temp + win.unit;
        if (win.feel !== null && win.feel !== undefined)
            s += ", feels like " + win.feel;
        if (win.wind !== null && win.wind !== undefined)
            s += ". Wind " + win.wind + " " + win.wunit;
        return s + ".";
    }

    function io() { return (Quickshell.env("HOME") || "") + "/.config/quickshell/weather-io.py"; }
    function apply(j) {
        if (!j) return;
        if (j.empty) {
            win.status = qsTr("Search for a city to begin.");
            return;
        }
        if (j.ok === false) {
            win.status = j.error || qsTr("Could not update.");
            return;
        }
        win.placeName = j.name || "";
        win.admin = j.admin || "";
        win.units = j.units || win.units;
        win.places = j.places || [];
        win.temp = j.temp;
        win.feel = j.feel;
        win.label = j.label || "";
        win.unit = j.unit || (win.units === "imperial" ? "°F" : "°C");
        win.wind = j.wind;
        win.wunit = j.wunit || (win.units === "imperial" ? "mph" : "km/h");
        win.gust = j.gust;
        win.hum = j.hum;
        win.press = j.press;
        win.uv = j.uv;
        win.aqi = j.aqi;
        win.cloud = j.cloud;
        win.sunrise = j.sunrise || "";
        win.sunset = j.sunset || "";
        win.hours = j.hours || [];
        win.days = j.days || [];
        win.status = (j.cached ? qsTr("Last reading") : qsTr("Updated"))
                     + (j.at ? ("  ·  " + j.at) : "");
    }
    function run(op) {
        wxProc.command = ["python3", win.io(), op];
        wxProc.running = false;
        wxProc.running = true;
    }
    function speakBulletin() {
        if (!win.bulletin.length) return;
        speakProc.running = false;
        speakProc.running = true;
        win.status = win.bulletin;
    }
    function searchCity() {
        var q = win.query.trim();
        if (!q.length) return;
        win.fetching = true;
        wxProc.command = ["python3", win.io(), "search", q];
        wxProc.running = false;
        wxProc.running = true;
    }
    function n(v) {
        if (v === null || v === undefined || v === "") return "—";
        return Math.round(Number(v));
    }
    function clock(iso) {
        if (!iso || iso.length < 16) return "—";
        return iso.substring(11, 16);
    }
    function weekday(iso) {
        if (!iso) return "";
        var d = new Date(iso + "T12:00:00");
        return Qt.formatDate(d, "ddd");
    }
    function mins(iso) {
        if (!iso || iso.length < 16) return -1;
        var h = Number(iso.substring(11, 13));
        var m = Number(iso.substring(14, 16));
        if (isNaN(h) || isNaN(m)) return -1;
        return h * 60 + m;
    }
    function stampNow() {
        var d = new Date();
        win.nowMin = d.getHours() * 60 + d.getMinutes();
    }

    onOpenChanged: if (open) {
        win.stampNow();
        win.run("show");
        fetchTimer.restart();
    }

    Timer {
        id: fetchTimer
        interval: 400
        repeat: false
        onTriggered: {
            win.fetching = true;
            win.run("fetch");
        }
    }
    Timer {
        id: pollTimer
        interval: win.refreshMins * 60 * 1000
        running: win.open
        repeat: true
        onTriggered: {
            win.fetching = true;
            win.run("fetch");
        }
    }
    Timer {
        id: sunTimer
        interval: 30000
        running: win.open
        repeat: true
        onTriggered: win.stampNow()
    }
    Timer {
        id: skyTimer
        interval: 80
        running: win.liveSky && win.open
        repeat: true
        onTriggered: win.skyPhase = (win.skyPhase + 0.003) % 1
    }

    IpcHandler {
        target: "weather"
        function ready(): string { return "ready"; }
        function engage(): string { Bus.weatherOpen = true; win.stampNow(); win.run("show"); fetchTimer.restart(); return "weather"; }
        function dismiss(): string { Bus.weatherOpen = false; return "hidden"; }
    }

    Process {
        id: wxProc
        running: false
        command: ["python3", win.io(), "show"]
        onExited: function (code) { if (code !== 0) { win.fetching = false; win.status = qsTr("Could not update."); console.warn("[Weather] io exited code " + code); } }
        stdout: StdioCollector {
            onStreamFinished: {
                win.fetching = false;
                try { win.apply(JSON.parse(String(this.text))); }
                catch (e) { win.status = qsTr("Could not update."); }
            }
        }
    }
    Process {
        id: speakProc
        running: false
        command: ["python3", win.io(), "speak"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    if (j.text) win.status = j.text;
                    else if (j.error) win.status = j.error;
                } catch (e) { }
            }
        }
    }

    FileView {
        id: confWatch
        path: (Quickshell.env("HOME") || "") + "/.config/nyxus/weather.json"
        watchChanges: true
        printErrors: false
        onFileChanged: {
            confWatch.reload();
            if (win.open && !wxProc.running) {
                win.fetching = true;
                win.run("fetch");
            }
        }
    }

    component Ghost: Item {
        id: g
        property string mark: ""
        property bool on: false
        signal tapped()
        implicitWidth: Math.max(36, lab.implicitWidth + 22)
        implicitHeight: 32
        width: implicitWidth
        height: 32
        scale: tap.pressed ? 0.985 : (gh.hovered ? 1.04 : 1.0)
        Behavior on scale {
            NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutQuint }
        }
        CutRect {
            anchors.fill: parent
            radius: Theme.r1
            color: g.on || gh.hovered ? Theme.elevated : "transparent"
        }
        Pane {
            visible: g.on || gh.hovered
            anchors.fill: parent
            elevation: 1
            bloomAtRest: false
            fill: Theme.panelMid
            radius: Theme.r1
            focusLevel: 0.45
            crown: 0.86
            GlassEdge {
                anchors.fill: parent
                radiusTL: Theme.r1; radiusTR: Theme.r1
                radiusBR: Theme.r1; radiusBL: Theme.r1
                body: 0
                wash: 0
                edging: 0.70
            }
        }
        CutRect {
            anchors.fill: parent
            radius: Theme.r1
            color: "transparent"
            borderWidth: 1
            borderColor: Theme.soften(gh.hovered ? win.iceFocus : win.iceHair,
                                      g.on || gh.hovered ? 0.85 : 0.45)
            Behavior on borderColor { ColorAnimation { duration: Theme.durQuick } }
        }
        Text {
            id: lab
            anchors.centerIn: parent
            z: 2
            text: g.mark
            color: Theme.text
            font.family: Theme.fUi
            font.pixelSize: Theme.tBody
            font.weight: Theme.wStrong
        }
        HoverHandler { id: gh; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: tap; onTapped: g.tapped() }
    }

    component HourCell: Item {
        id: hour
        property var row: ({})
        width: 52
        height: 86
        scale: hourHov.hovered ? 1.04 : 1.0
        Behavior on scale {
            NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutQuint }
        }
        CutRect {
            anchors.fill: parent
            radius: Theme.r1
            color: Theme.elevated
            borderWidth: 1
            borderColor: Theme.soften(hourHov.hovered ? win.iceFocus : win.iceHair,
                                      hourHov.hovered ? 0.90 : 0.40)
            Behavior on borderColor { ColorAnimation { duration: Theme.durQuick } }
        }
        Column {
            anchors.fill: parent
            anchors.margins: Theme.s2
            spacing: 2
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: hour.row.t || "—"
                color: Theme.textDim
                font.family: Theme.fNum
                font.pixelSize: Theme.tCaption
                font.features: ({ "tnum": 1 })
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: win.n(hour.row.temp)
                color: Theme.text
                font.family: Theme.fNum
                font.pixelSize: Theme.tBody
                font.weight: Theme.wStrong
                font.features: ({ "tnum": 1 })
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: hour.row.pop === null || hour.row.pop === undefined
                      ? "" : (win.n(hour.row.pop) + "%")
                color: Theme.textMuted
                font.family: Theme.fNum
                font.pixelSize: Theme.tCaption
                font.features: ({ "tnum": 1 })
                elide: Text.ElideRight
            }
        }
        HoverHandler { id: hourHov }
    }

    component DayCell: Item {
        id: day
        property var row: ({})
        property real cellW: 88
        width: day.cellW
        height: 108
        scale: dayHov.hovered ? 1.03 : 1.0
        Behavior on scale {
            NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutQuint }
        }
        CutRect {
            anchors.fill: parent
            radius: Theme.r1
            color: Theme.elevated
        }
        Pane {
            anchors.fill: parent
            elevation: 1
            bloomAtRest: false
            fill: Theme.panelMid
            radius: Theme.r1
            focusLevel: dayHov.hovered ? 0.50 : 0.10
            crown: dayHov.hovered ? 0.88 : 0.64
            GlassEdge {
                anchors.fill: parent
                radiusTL: Theme.r1; radiusTR: Theme.r1
                radiusBR: Theme.r1; radiusBL: Theme.r1
                body: 0
                wash: 0
                edging: 0.70
            }
            CutRect {
                anchors.fill: parent
                radius: Theme.r1
                color: "transparent"
                borderWidth: 1
                borderColor: Theme.soften(dayHov.hovered ? win.iceFocus : win.iceHair,
                                          dayHov.hovered ? 0.90 : 0.45)
                Behavior on borderColor { ColorAnimation { duration: Theme.durQuick } }
            }
        }
        Column {
            anchors.fill: parent
            anchors.margins: Theme.s3
            spacing: 4
            Text {
                width: parent.width
                text: win.weekday(day.row.date)
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                font.weight: Theme.wStrong
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: win.n(day.row.max) + " / " + win.n(day.row.min)
                color: Theme.text
                font.family: Theme.fNum
                font.pixelSize: Theme.tBody
                font.weight: Theme.wStrong
                font.features: ({ "tnum": 1 })
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: day.row.label || ""
                color: Theme.textMuted
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                visible: day.row.pop !== null && day.row.pop !== undefined
                text: win.n(day.row.pop) + "%"
                color: Theme.textDim
                font.family: Theme.fNum
                font.pixelSize: Theme.tCaption
                font.features: ({ "tnum": 1 })
                elide: Text.ElideRight
            }
        }
        HoverHandler { id: dayHov }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.s3

        Row {
            spacing: Theme.s3
            StatusPip {
                anchors.verticalCenter: parent.verticalCenter
                kind: "magma"
                pulse: win.fetching
            }
            Text {
                text: qsTr("WEATHER")
                color: Theme.textDim
                font.family: Theme.fUi
                font.pixelSize: Theme.tCaption
                font.weight: Theme.wStrong
                font.letterSpacing: Theme.trackMicro
            }
        }
        Text {
            text: qsTr("Sky")
            color: Theme.text
            font.family: Theme.fUiTitle
            font.pixelSize: Theme.tDisplay
            font.weight: Font.DemiBold
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s3
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                CutRect {
                    anchors.fill: parent
                    radius: Theme.r1
                    color: Theme.soften(Theme.void_, 0.62)
                }
                Pane {
                    anchors.fill: parent
                    elevation: 1
                    bloomAtRest: false
                    fill: Theme.panelMid
                    radius: Theme.r1
                    focusLevel: qField.activeFocus ? 0.50 : 0.08
                    crown: qField.activeFocus ? 0.88 : 0.64
                    GlassEdge {
                        anchors.fill: parent
                        radiusTL: Theme.r1; radiusTR: Theme.r1
                        radiusBR: Theme.r1; radiusBL: Theme.r1
                        body: 0
                        wash: 0
                        edging: 0.70
                    }
                    CutRect {
                        anchors.fill: parent
                        radius: Theme.r1
                        color: "transparent"
                        borderWidth: 1
                        borderColor: Theme.soften(qField.activeFocus ? win.iceFocus : win.iceHair,
                                                  qField.activeFocus ? 0.90 : 0.45)
                        Behavior on borderColor { ColorAnimation { duration: Theme.durQuick } }
                    }
                }
                TextInput {
                    id: qField
                    z: 2
                    anchors.fill: parent
                    anchors.margins: 10
                    color: Theme.text
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tBody
                    clip: true
                    onTextChanged: win.query = text
                    Keys.onReturnPressed: win.searchCity()
                }
                Text {
                    z: 2
                    anchors.fill: qField
                    visible: qField.text.length === 0 && !qField.activeFocus
                    text: qsTr("City — e.g. Boston, or Kyoto")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tBody
                    elide: Text.ElideRight
                    enabled: false
                }
            }
            Ghost { mark: qsTr("Search"); onTapped: win.searchCity() }
            Ghost {
                mark: win.units === "metric" ? "°F" : "°C"
                onTapped: { win.fetching = true; win.run("units"); }
            }
            Ghost {
                mark: qsTr("Refresh")
                onTapped: { win.fetching = true; win.run("fetch"); }
            }
            Ghost {
                mark: qsTr("Speak")
                onTapped: win.speakBulletin()
            }
        }

        Text {
            visible: win.bulletin.length > 0
            Layout.fillWidth: true
            text: win.bulletin
            color: Theme.textMuted
            font.family: Theme.fUi
            font.pixelSize: Theme.tCaption
            wrapMode: Text.WordWrap
        }

        Row {
            spacing: 6
            Repeater {
                model: win.places
                Ghost {
                    required property var modelData
                    mark: modelData.name || "—"
                    on: modelData.name === win.placeName
                    onTapped: {
                        win.fetching = true;
                        wxProc.command = ["python3", win.io(), "place", modelData.name];
                        wxProc.running = false;
                        wxProc.running = true;
                    }
                }
            }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: bodyCol.height
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: bodyCol
                width: parent.width
                spacing: Theme.s5

                Item {
                    id: hero
                    width: parent.width
                    height: 168
                    clip: true
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
                        focusLevel: heroHov.hovered ? 0.50 : 0.14
                        crown: heroHov.hovered ? 0.90 : 0.68
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
                        CutRect {
                            anchors.fill: parent
                            radius: Theme.r2
                            color: "transparent"
                            borderWidth: 1
                            borderColor: Theme.soften(heroHov.hovered ? win.iceFocus : win.iceHair,
                                                      heroHov.hovered ? 0.90 : 0.55)
                            Behavior on borderColor { ColorAnimation { duration: Theme.durQuick } }
                        }
                    }

                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            width: 110 + index * 36
                            height: 26 + index * 8
                            radius: height / 2
                            color: Theme.soften(Theme.tealGlow, 0.10 + index * 0.03)
                            opacity: 0.22 + Math.min(0.28, (Number(win.cloud) || 35) / 280)
                            y: 22 + index * 18
                            x: 36 + index * 92
                               + Math.sin((win.skyPhase + index * 0.28) * Math.PI * 2) * 26
                        }
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Theme.s6
                        width: parent.width * 0.52
                        spacing: 4
                        Text {
                            width: parent.width
                            text: win.where
                            color: Theme.textMuted
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tBody
                            elide: Text.ElideRight
                        }
                        Row {
                            spacing: 8
                            Text {
                                text: win.n(win.temp)
                                color: Theme.text
                                font.family: Theme.fNum
                                font.pixelSize: 42
                                font.weight: Font.DemiBold
                                font.features: ({ "tnum": 1 })
                            }
                            Text {
                                anchors.baseline: parent.children[0].baseline
                                text: win.unit
                                color: Theme.textDim
                                font.family: Theme.fUi
                                font.pixelSize: Theme.tCaption
                                font.weight: Theme.wStrong
                                font.letterSpacing: Theme.trackMicro
                            }
                        }
                        Text {
                            width: parent.width
                            text: win.label
                            color: Theme.textMuted
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tBody
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            visible: win.feel !== null && win.feel !== undefined && win.feel !== ""
                            text: qsTr("feels %1").arg(win.n(win.feel) + win.unit)
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            elide: Text.ElideRight
                        }
                    }

                    Item {
                        id: arc
                        visible: win.hasSun
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: Theme.s6
                        width: 220
                        height: 108
                        Repeater {
                            model: 13
                            Rectangle {
                                required property int index
                                width: index === win.sunIdx ? 8 : 3
                                height: width
                                radius: width / 2
                                color: index === win.sunIdx
                                       ? Theme.goldGlow
                                       : Theme.soften(win.iceHair, 0.55)
                                x: (index / 12) * (arc.width - width)
                                y: (1 - Math.sin((index / 12) * Math.PI)) * (arc.height - 36 - height)
                                opacity: index === win.sunIdx ? 1 : 0.70
                            }
                        }
                        Row {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            Text {
                                width: parent.width / 2
                                text: win.clock(win.sunrise)
                                color: Theme.textDim
                                font.family: Theme.fNum
                                font.pixelSize: Theme.tCaption
                                font.features: ({ "tnum": 1 })
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width / 2
                                horizontalAlignment: Text.AlignRight
                                text: win.clock(win.sunset)
                                color: Theme.textDim
                                font.family: Theme.fNum
                                font.pixelSize: Theme.tCaption
                                font.features: ({ "tnum": 1 })
                                elide: Text.ElideRight
                            }
                        }
                    }
                    HoverHandler { id: heroHov }
                }

                RowLayout {
                    width: bodyCol.width
                    spacing: Theme.s4
                    AppCard {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 112
                        kicker: qsTr("NOW")
                        value: win.n(win.temp)
                        unit: win.unit
                        telemetry: qsTr("DEG")
                        fill: win.tempFill
                        pipKind: "off"
                    }
                    AppCard {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 112
                        kicker: qsTr("WIND")
                        value: win.n(win.wind)
                        unit: win.wunit
                        telemetry: win.wunit
                        pipKind: "off"
                    }
                    AppCard {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 112
                        kicker: qsTr("HUMIDITY")
                        value: win.n(win.hum)
                        unit: "%"
                        telemetry: "%"
                        pipKind: "off"
                    }
                    AppCard {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 112
                        kicker: qsTr("UV")
                        value: win.n(win.uv)
                        pipKind: "off"
                    }
                    AppCard {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 112
                        kicker: qsTr("AQI")
                        value: win.n(win.aqi)
                        pipKind: "off"
                    }
                }

                Text {
                    text: qsTr("NEXT 24 HOURS")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    font.weight: Theme.wStrong
                    font.letterSpacing: Theme.trackMicro
                }
                Flickable {
                    width: bodyCol.width
                    height: 96
                    clip: true
                    contentWidth: hourRow.width
                    contentHeight: height
                    boundsBehavior: Flickable.StopAtBounds
                    Row {
                        id: hourRow
                        spacing: Theme.s3
                        Repeater {
                            model: win.hours
                            HourCell {
                                required property var modelData
                                row: modelData
                            }
                        }
                    }
                }

                Text {
                    text: qsTr("THE WEEK")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    font.weight: Theme.wStrong
                    font.letterSpacing: Theme.trackMicro
                }
                Row {
                    spacing: Theme.s3
                    Repeater {
                        model: win.days
                        DayCell {
                            required property var modelData
                            row: modelData
                            cellW: Math.max(88, (bodyCol.width - Theme.s3 * 6) / 7)
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: win.fetching ? qsTr("Updating…") : win.status
            color: Theme.textDim
            font.family: Theme.fUi
            font.pixelSize: Theme.tCaption
            elide: Text.ElideRight
        }
    }
}
