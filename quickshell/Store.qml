pragma ComponentBehavior: Bound
// Nyxus Suxyn — STORE. GTK rail (Recommended / Featured / shelves /
// Installed / Updates) with widget glass. Install is pkexec pacman, same
// as GTK. Tape/Media/MediaCrest untouched.
// Ice ration: glass carries, solid signals, ~9:1. Pale glacier[5] is the
// Calculator `=` — one prize, not a shelf. Install is a repeating action:
// outline only, glacier[4] 1 px seam, Theme.text. glacier[0] is not a fill.
// Magma is what MATTERS: STORE kicker pip, Updates count. Not a fill on
// every card. Cover art is AppStream icons / cached screenshots, same as GTK.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

AppWindow {
    id: win

    titleText: qsTr("Store")
    iconName: "nyxus-store"
    subtitleText: qsTr("Install apps")
    open: Bus.storeOpen
    onDismissed: Bus.storeOpen = false
    implicitWidth: 1180
    implicitHeight: 760
    minimumSize: Qt.size(900, 560)

    property string page: "featured"
    property var categories: []
    property var featured: []
    property var recommended: []
    property var updates: []
    property string query: ""
    property string busyId: ""
    property string status: ""
    property string pendingId: ""

    readonly property bool includeAur: SettingsStore.boolValue("app_store_include_aur", true)
    readonly property bool includeFlatpak: SettingsStore.boolValue("app_store_include_flatpak", true)
    readonly property bool confirmInstall: SettingsStore.boolValue("app_store_confirm_install", true)
    readonly property string landingRaw: SettingsStore.stringValue("app_store_landing", "Featured")
    readonly property string landingId: {
        var s = String(win.landingRaw || "Featured").trim().toLowerCase();
        if (s === "featured" || s === "recommended" || s === "installed" || s === "updates")
            return s;
        return "featured";
    }

    readonly property color ice: Theme.tokenAccentPrimary
    readonly property color iceHair: Theme.tokenAccentHairline
    readonly property color iceFocus: Theme.tokenAccentInteractive
    readonly property color magma: Theme.paintLayers.magma[5]

    function artUrl(p) {
        var s = String(p || "");
        if (!s.length) return "";
        if (s.indexOf("file:") === 0 || s.indexOf("http") === 0) return s;
        return "file://" + s;
    }
    function sourceOk(app) {
        if (!app) return false;
        var s = String(app.source || "").toLowerCase();
        if (s === "aur" && !win.includeAur) return false;
        if ((s === "flatpak" || s === "flathub") && !win.includeFlatpak) return false;
        return true;
    }
    function telemetryOf(app) {
        if (!app) return "";
        var repo = String(app.repo || app.source || "");
        var ver = String(app.version || "");
        if (repo.length && ver.length) return repo + " / " + ver;
        return repo.length ? repo : ver;
    }
    function ioCmd(op) {
        return ["python3", win.io(), op,
                win.includeAur ? "--aur" : "--no-aur",
                win.includeFlatpak ? "--flatpak" : "--no-flatpak"];
    }
    function applyLanding() { win.page = win.landingId; }
    function sectionId(section) {
        var s = String(section || "").trim().toLowerCase();
        if (s === "featured" || s === "recommended" || s === "installed" || s === "updates")
            return s;
        return s;
    }

    readonly property bool coverPage: win.page === "featured" || win.page === "recommended"
    readonly property int tileW: win.coverPage ? 196 : 220
    readonly property int tileH: win.coverPage ? 248 : 176

    readonly property var nav: {
        var n = [
            { id: "recommended", label: qsTr("Recommended") },
            { id: "featured", label: qsTr("Featured") }
        ];
        for (var i = 0; i < win.categories.length; i++)
            n.push({ id: win.categories[i].id, label: win.categories[i].name });
        n.push({ id: "aur", label: qsTr("AUR") });
        n.push({ id: "flatpak", label: qsTr("Flatpak") });
        n.push({ id: "installed", label: qsTr("Installed") });
        n.push({ id: "updates", label: qsTr("Updates") });
        return n;
    }

    readonly property var shownUpdates: {
        var out = [];
        for (var i = 0; i < win.updates.length; i++)
            if (win.sourceOk(win.updates[i]))
                out.push(win.updates[i]);
        return out;
    }

    readonly property var shownApps: {
        var q = win.query.trim().toLowerCase();
        var src = [];
        if (q.length) {
            var seen = {};
            function add(list) {
                for (var x = 0; x < list.length; x++) {
                    if (!win.sourceOk(list[x])) continue;
                    if (seen[list[x].id]) continue;
                    seen[list[x].id] = true;
                    src.push(list[x]);
                }
            }
            add(win.recommended);
            add(win.featured);
            for (var c = 0; c < win.categories.length; c++)
                add(win.categories[c].apps);
        } else if (win.page === "featured")
            src = win.featured;
        else if (win.page === "recommended")
            src = win.recommended;
        else if (win.page === "installed") {
            for (var k = 0; k < win.categories.length; k++)
                for (var a = 0; a < win.categories[k].apps.length; a++)
                    if (win.categories[k].apps[a].installed)
                        src.push(win.categories[k].apps[a]);
        } else if (win.page === "updates")
            src = [];
        else if (win.page === "aur" || win.page === "flatpak") {
            var want = win.page;
            function take(list) {
                for (var x = 0; x < list.length; x++) {
                    var s = String(list[x].source || "").toLowerCase();
                    if (want === "aur" && s === "aur") src.push(list[x]);
                    if (want === "flatpak" && (s === "flatpak" || s === "flathub")) src.push(list[x]);
                }
            }
            take(win.recommended);
            take(win.featured);
            for (var c = 0; c < win.categories.length; c++)
                take(win.categories[c].apps);
        } else {
            for (var i = 0; i < win.categories.length; i++)
                if (win.categories[i].id === win.page)
                    src = win.categories[i].apps;
        }
        var kept = [];
        for (var t = 0; t < src.length; t++)
            if (win.sourceOk(src[t])) kept.push(src[t]);
        src = kept;
        if (!q.length) return src;
        var out = [];
        for (var j = 0; j < src.length; j++) {
            var hay = (src[j].name + " " + src[j].summary + " " + src[j].id).toLowerCase();
            if (hay.indexOf(q) >= 0) out.push(src[j]);
        }
        return out;
    }

    readonly property string pageTitle: {
        if (win.query.trim().length) return qsTr("Search");
        if (win.page === "featured") return qsTr("Featured");
        if (win.page === "recommended") return qsTr("Recommended");
        if (win.page === "installed") return qsTr("Installed");
        if (win.page === "aur") return qsTr("AUR");
        if (win.page === "flatpak") return qsTr("Flatpak");
        if (win.page === "updates") return qsTr("Updates");
        for (var i = 0; i < win.nav.length; i++)
            if (win.nav[i].id === win.page) return win.nav[i].label;
        return "";
    }

    function io() { return (Quickshell.env("HOME") || "") + "/.config/quickshell/store-io.py"; }
    function refresh() {
        catProc.command = win.ioCmd("catalog");
        catProc.running = false;
        catProc.running = true;
        updProc.command = win.ioCmd("updates");
        updProc.running = false;
        updProc.running = true;
    }
    function requestInstall(app) {
        if (!app || !app.pkgs || !app.pkgs.length) return;
        if (win.busyId.length) return;
        if (win.confirmInstall && win.pendingId !== app.id) {
            win.pendingId = app.id;
            disarm.restart();
            return;
        }
        win.pendingId = "";
        disarm.stop();
        win.installApp(app);
    }
    function installApp(app) {
        if (!app || !app.pkgs || !app.pkgs.length) return;
        win.busyId = app.id;
        win.status = qsTr("Installing %1…").arg(app.name);
        var cmd = ["python3", win.io(), "install", app.source || "pacman"];
        for (var i = 0; i < app.pkgs.length; i++)
            cmd.push(app.pkgs[i]);
        instProc.command = cmd;
        instProc.running = false;
        instProc.running = true;
    }
    function upgradeAll() {
        win.busyId = "__upgrade";
        win.status = qsTr("Updating…");
        upgProc.command = win.ioCmd("upgrade");
        upgProc.running = false;
        upgProc.running = true;
    }

    onOpenChanged: if (open) {
        win.applyLanding();
        win.pendingId = "";
        win.refresh();
    }
    onVisibleChanged: if (visible) win.refresh()
    onIncludeAurChanged: if (win.open) win.refresh()
    onIncludeFlatpakChanged: if (win.open) win.refresh()
    onPageChanged: win.pendingId = ""
    onQueryChanged: win.pendingId = ""

    Timer {
        id: disarm
        interval: 4000
        onTriggered: win.pendingId = ""
    }

    IpcHandler {
        target: "store"
        function ready(): string { return "ready"; }
        function engage(): string {
            Bus.storeOpen = true;
            win.applyLanding();
            win.refresh();
            return "store";
        }
        function at(section: string): string {
            Bus.storeOpen = true;
            if (section && section.length)
                win.page = win.sectionId(section);
            else
                win.applyLanding();
            win.refresh();
            return section || "store";
        }
        function dismiss(): string { Bus.storeOpen = false; return "hidden"; }
    }

    Process {
        id: catProc
        running: false
        command: ["python3", win.io(), "catalog"]
        onExited: function (code) { if (code !== 0) console.warn("[Store] catalog read exited code " + code); }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.categories = j.categories || [];
                    win.featured = j.featured || [];
                    win.recommended = j.recommended || [];
                } catch (e) { }
            }
        }
    }
    Process {
        id: updProc
        running: false
        command: ["python3", win.io(), "updates"]
        onExited: function (code) { if (code !== 0) console.warn("[Store] updates read exited code " + code); }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.updates = j.updates || [];
                } catch (e) { }
            }
        }
    }
    Process {
        id: instProc
        running: false
        command: ["python3", win.io(), "catalog"]
        onExited: function (code) { if (code !== 0) console.warn("[Store] install exited code " + code); }
        stdout: StdioCollector {
            onStreamFinished: {
                win.busyId = "";
                try {
                    var j = JSON.parse(String(this.text));
                    win.status = j.ok ? qsTr("Installed.") : qsTr("Install did not finish.");
                } catch (e) {
                    win.status = qsTr("Install did not finish.");
                }
                win.refresh();
            }
        }
    }
    Process {
        id: upgProc
        running: false
        command: ["python3", win.io(), "upgrade"]
        onExited: function (code) { if (code !== 0) console.warn("[Store] upgrade exited code " + code); }
        stdout: StdioCollector {
            onStreamFinished: {
                win.busyId = "";
                try {
                    var j = JSON.parse(String(this.text));
                    win.status = j.ok ? qsTr("Updated.") : qsTr("Update did not finish.");
                } catch (e) {
                    win.status = qsTr("Update did not finish.");
                }
                win.refresh();
            }
        }
    }

    component NavRow: Item {
        id: nr
        property string nid: ""
        property string label: ""
        property string badge: ""
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        height: 40
        readonly property bool on: win.page === nr.nid
        CutRect {
            visible: nr.on
            anchors.fill: parent
            radius: Theme.r1
            color: Theme.elevated
        }
        Pane {
            visible: nr.on
            anchors.fill: parent
            elevation: 1
            bloomAtRest: false
            fill: Theme.panelMid
            radius: Theme.r1
            focusLevel: 0.40
            crown: 0.78
            CutRect {
                anchors.fill: parent
                radius: Theme.r1
                gradTop: Theme.swellGroundTop
                gradMid: Theme.swellGroundMid
                gradFoot: Theme.swellGroundFoot
            }
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
                borderColor: Theme.soften(win.iceHair, 0.85)
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Theme.s5
            anchors.right: badgeRow.visible ? badgeRow.left : parent.right
            anchors.rightMargin: Theme.s3
            text: nr.label
            color: nr.on ? Theme.text : Theme.textMuted
            font.family: Theme.fUi
            font.pixelSize: 16
            font.weight: nr.on ? Theme.wStrong : Font.Normal
            elide: Text.ElideRight
        }
        Row {
            id: badgeRow
            visible: nr.badge.length > 0
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Theme.s4
            spacing: Theme.s2
            StatusPip {
                visible: nr.nid === "updates"
                kind: "magma"
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: nr.badge
                color: nr.nid === "updates" ? win.magma : Theme.textMuted
                font.family: Theme.fNum
                font.pixelSize: Theme.tCaption
                font.features: ({ "tnum": 1 })
            }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: { win.query = ""; qField.text = ""; win.page = nr.nid; } }
    }

    component StoreCard: Item {
        id: card
        property var app: ({})
        width: win.tileW
        height: win.tileH

        readonly property bool hot: tileHov.hovered
        readonly property bool prize: !(card.app && card.app.installed) && win.busyId !== (card.app && card.app.id)
        readonly property bool armed: win.pendingId === (card.app && card.app.id)
        readonly property string tel: win.telemetryOf(card.app)

        scale: card.hot ? 1.012 : 1.0
        Behavior on scale {
            NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutQuint }
        }

        HoverHandler { id: tileHov }

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
            focusLevel: card.hot ? 0.55 : 0.12
            crown: card.hot ? 0.90 : 0.68

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
                borderColor: Theme.soften(card.hot ? win.iceFocus : win.iceHair,
                                          card.hot ? 0.90 : 0.50)
                Behavior on borderColor { ColorAnimation { duration: Theme.durQuick } }
            }

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: instBtn.top
                anchors.margins: Theme.s5
                anchors.bottomMargin: Theme.s3
                spacing: Theme.s3
                Item {
                    width: parent.width
                    height: win.coverPage ? 110 : 48
                    clip: true
                    Image {
                        visible: String(card.app.art || "").length > 0
                        anchors.fill: parent
                        source: win.artUrl(card.app.art)
                        fillMode: card.app.artKind === "shot"
                                   ? Image.PreserveAspectCrop
                                   : Image.PreserveAspectFit
                        asynchronous: true
                        cache: true
                        smooth: true
                    }
                    Rectangle {
                        visible: String(card.app.art || "").length === 0
                        width: 28
                        height: 28
                        radius: 14
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.elevated
                        border.width: 1
                        border.color: Theme.soften(win.iceHair, 0.70)
                        Text {
                            anchors.centerIn: parent
                            text: String(card.app.name || "·").charAt(0)
                            color: Theme.text
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            font.weight: Theme.wStrong
                        }
                    }
                }
                Text {
                    width: parent.width
                    text: card.app.name || ""
                    color: Theme.text
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tHead
                    font.weight: Theme.wStrong
                    elide: Text.ElideRight
                    clip: true
                }
                Text {
                    visible: card.tel.length > 0
                    width: parent.width
                    text: card.tel
                    color: Theme.textMuted
                    font.family: Theme.fNum
                    font.pixelSize: Theme.tMicro
                    font.features: ({ "tnum": 1 })
                    elide: Text.ElideRight
                    clip: true
                }
                Text {
                    width: parent.width
                    text: card.app.summary || ""
                    color: Theme.textMuted
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    wrapMode: Text.WordWrap
                    maximumLineCount: win.coverPage ? 2 : 1
                    elide: Text.ElideRight
                    clip: true
                }
            }
            Item {
                id: instBtn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.s5
                height: 36
                scale: card.armed ? 1.04 : 1.0
                transformOrigin: Item.Center
                Behavior on scale {
                    NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutQuint }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.r1
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.soften(win.iceHair,
                                               card.prize || instHov.hovered || card.armed ? 0.85 : 0.55)
                    Behavior on border.color { ColorAnimation { duration: Theme.durQuick } }
                }
                Text {
                    anchors.centerIn: parent
                    width: parent.width - Theme.s3
                    horizontalAlignment: Text.AlignHCenter
                    text: card.app.installed ? qsTr("Installed")
                          : (win.busyId === card.app.id ? qsTr("Working…")
                             : (card.armed ? qsTr("Confirm") : qsTr("Install")))
                    color: card.prize ? Theme.text : Theme.textMuted
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tBody
                    font.weight: Theme.wStrong
                    elide: Text.ElideRight
                }
                HoverHandler { id: instHov; cursorShape: card.prize ? Qt.PointingHandCursor : Qt.ArrowCursor }
                TapHandler {
                    enabled: card.app && !card.app.installed && win.busyId === ""
                    onTapped: win.requestInstall(card.app)
                }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0
        Item {
            Layout.preferredWidth: 240
            Layout.maximumWidth: 240
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.s5
                spacing: Theme.s2
                Row {
                    spacing: Theme.s3
                    StatusPip {
                        kind: "magma"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: qsTr("STORE")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        font.weight: Theme.wStrong
                        font.letterSpacing: Theme.trackMicro
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Apps")
                    color: Theme.text
                    font.family: Theme.fUiTitle
                    font.pixelSize: Theme.tDisplay
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: Theme.r1
                    color: Theme.soften(Theme.void_, 0.62)
                    border.width: 1
                    border.color: Theme.soften(win.iceHair, 0.45)
                    TextInput {
                        id: qField
                        anchors.fill: parent
                        anchors.margins: 10
                        color: Theme.text
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tBody
                        clip: true
                        onTextChanged: win.query = text
                    }
                    Text {
                        anchors.fill: qField
                        visible: qField.text.length === 0 && !qField.activeFocus
                        text: qsTr("Search")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tBody
                        enabled: false
                    }
                }
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: navCol.height
                    boundsBehavior: Flickable.StopAtBounds
                    Column {
                        id: navCol
                        width: parent.width
                        spacing: 2
                        Repeater {
                            model: win.nav
                            NavRow {
                                required property var modelData
                                width: navCol.width
                                nid: modelData.id
                                label: modelData.label
                                badge: modelData.id === "updates" && win.shownUpdates.length > 0
                                       ? String(win.shownUpdates.length) : ""
                            }
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: win.status
                    color: Theme.textMuted
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tCaption
                    wrapMode: Text.WordWrap
                    visible: win.status.length > 0
                    elide: Text.ElideRight
                }
            }
        }
        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Theme.soften(win.iceHair, 0.45)
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            Flickable {
                id: gridFlick
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: gridCol.height
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: gridCol
                    width: gridFlick.width
                    padding: Theme.s6
                    spacing: Theme.s5
                    Text {
                        text: win.pageTitle
                        color: Theme.text
                        font.family: Theme.fScript
                        font.pixelSize: Theme.tTitle
                        leftPadding: Theme.s6
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: win.page === "updates" && win.query.trim().length === 0
                        text: win.shownUpdates.length === 0
                              ? qsTr("No updates")
                              : (win.shownUpdates.length === 1 ? qsTr("1 update") : qsTr("%1 updates").arg(win.shownUpdates.length))
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        leftPadding: Theme.s6
                    }
                    Item {
                        visible: win.page === "updates" && win.shownUpdates.length > 0 && win.query.trim().length === 0
                        width: gridCol.width - Theme.s6 * 2
                        x: Theme.s6
                        height: 36
                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.r1
                            color: "transparent"
                            border.width: 1
                            border.color: Theme.soften(win.iceHair, 0.85)
                        }
                        Text {
                            anchors.centerIn: parent
                            text: win.busyId === "__upgrade" ? qsTr("Working…") : qsTr("Update all")
                            color: Theme.text
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tBody
                            font.weight: Theme.wStrong
                        }
                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            enabled: win.busyId === ""
                            onTapped: win.upgradeAll()
                        }
                    }
                    Column {
                        visible: win.page === "updates" && win.query.trim().length === 0
                        width: gridCol.width - Theme.s6 * 2
                        x: Theme.s6
                        spacing: 4
                        Repeater {
                            model: win.shownUpdates
                            delegate: Item {
                                id: updRow
                                required property var modelData
                                width: parent.width
                                height: 44
                                readonly property bool hot: updHov.hovered
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
                                    focusLevel: updRow.hot ? 0.45 : 0.10
                                    crown: updRow.hot ? 0.86 : 0.68
                                    CutRect {
                                        anchors.fill: parent
                                        radius: Theme.r1
                                        gradTop: Theme.swellGroundTop
                                        gradMid: Theme.swellGroundMid
                                        gradFoot: Theme.swellGroundFoot
                                    }
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
                                        borderColor: Theme.soften(updRow.hot ? win.iceFocus : win.iceHair,
                                                                  updRow.hot ? 0.90 : 0.45)
                                        Behavior on borderColor { ColorAnimation { duration: Theme.durQuick } }
                                    }
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Theme.s4
                                        anchors.rightMargin: Theme.s5
                                        spacing: Theme.s4
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            color: Theme.text
                                            font.family: Theme.fUi
                                            font.pixelSize: Theme.tBody
                                            elide: Text.ElideRight
                                            clip: true
                                        }
                                        Text {
                                            text: win.telemetryOf(modelData)
                                            visible: text.length > 0
                                            color: Theme.textMuted
                                            font.family: Theme.fNum
                                            font.pixelSize: Theme.tMicro
                                            font.features: ({ "tnum": 1 })
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 120
                                            clip: true
                                        }
                                        Text {
                                            text: modelData.from && modelData.to
                                                  ? (modelData.from + " → " + modelData.to) : ""
                                            color: Theme.textDim
                                            font.family: Theme.fNum
                                            font.pixelSize: Theme.tCaption
                                            font.features: ({ "tnum": 1 })
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                                HoverHandler { id: updHov }
                            }
                        }
                    }
                    Text {
                        visible: win.page !== "updates" && win.shownApps.length === 0
                        text: win.query.trim().length ? qsTr("No matches") : qsTr("Nothing here yet.")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tBody
                        leftPadding: Theme.s6
                    }
                    Flow {
                        visible: win.page !== "updates" || win.query.trim().length > 0
                        width: gridCol.width - Theme.s6 * 2
                        x: Theme.s6
                        spacing: Theme.s5
                        Repeater {
                            model: win.shownApps
                            delegate: StoreCard {
                                required property var modelData
                                app: modelData
                            }
                        }
                    }
                }
            }
        }
    }
}
