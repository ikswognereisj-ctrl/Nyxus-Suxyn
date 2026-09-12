pragma ComponentBehavior: Bound
// Nyxus Suxyn — NOTES. Glass app. Replaces GTK nyxus_notes.py.
//
// Same store: ~/.config/nyxus/notes, one file per note, first line is the
// title. The widget sticky chip is a different file (sticky.txt); this is
// the workstation the chip's "Notes" link opens.
//
// Luxury glass: AppCard stack on the selected rail stone, glacier[4] 1 px
// seams, glacier[0] hover rim only, gold StatusPip on NOTE only, magma on
// Trash. Find lives over the editor. Lock is a header, not encryption.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

AppWindow {
    id: win

    titleText: qsTr("Notes")
    iconName: "nyxus-notes"
    subtitleText: win.noteLocked
                  ? qsTr("Locked")
                  : (win.savedAt.length > 0
                     ? qsTr("Saved %1").arg(win.savedAt)
                     : (win.dirty ? qsTr("Unsaved")
                                  : (win.currentTitle.length > 0
                                     ? win.currentTitle : qsTr("notebook"))))
    open: Bus.notesOpen
    onDismissed: {
        win.flush();
        Bus.notesOpen = false;
    }

    implicitWidth: 960
    implicitHeight: 640
    minimumSize: Qt.size(640, 420)

    property var notes: []
    property string selectedPath: ""
    property string query: ""
    property string savedAt: ""
    property bool dirty: false
    property string pendingOpen: ""
    property bool loading: false
    property string findNeedle: ""
    property var findHits: []
    property int findAt: 0
    property bool findArmed: false
    property bool fileLocked: false
    property var books: ["Notes"]
    property string book: "Notes"
    property bool previewOn: false
    property bool namingBook: false
    property string replaceWith: ""
    property var spellMiss: []
    property bool wantEmoji: false

    readonly property int railW: 260
    readonly property int spineW: 88
    readonly property color iceHair: Theme.tokenAccentHairline
    readonly property color iceFocus: Theme.paintLayers.glacier[0]
    readonly property color magma: Theme.paintLayers.magma[5]
    readonly property color magmaHot: Theme.paintLayers.magma[0]
    readonly property string lockMark: "NYXUS-NOTE-LOCK-v1\n"

    readonly property bool sidebarOn: SettingsStore.boolValue("app_notes_sidebar", true)
    readonly property int editorSize: Math.max(9, Math.min(28,
        Math.round(SettingsStore.numberValue("app_notes_font_size", 13))))
    readonly property int autosaveSecs: Math.max(0, Math.round(
        SettingsStore.numberValue("app_notes_autosave_secs", 10)))
    readonly property string noteFormat: SettingsStore.stringValue("app_notes_format", "Markdown")

    readonly property string currentTitle: {
        var n = win.currentNote;
        return n ? String(n.title || "") : "";
    }
    readonly property var currentNote: {
        for (var i = 0; i < win.notes.length; i++)
            if (win.notes[i].path === win.selectedPath)
                return win.notes[i];
        return null;
    }
    readonly property bool noteLocked: win.fileLocked
                                       || !!(win.currentNote && win.currentNote.locked)
    readonly property var visibleNotes: {
        var q = win.query.trim().toLowerCase();
        var out = [];
        for (var i = 0; i < win.notes.length; i++) {
            var n = win.notes[i];
            if (!q.length && String(n.book || "Notes") !== win.book)
                continue;
            if (q.length) {
                var hay = (n.title + " " + n.snippet + " " + n.name).toLowerCase();
                if (hay.indexOf(q) < 0)
                    continue;
            }
            out.push(n);
        }
        return out;
    }
    readonly property int wordCount: {
        if (win.noteLocked)
            return 0;
        var s = String(editor.text || "").trim();
        if (!s.length)
            return 0;
        return s.split(/\s+/).length;
    }
    readonly property int charCount: win.noteLocked ? 0 : String(editor.text || "").length
    readonly property string findCountText: {
        var n = win.findHits.length;
        if (win.findNeedle.length === 0)
            return "";
        if (n === 0)
            return "0 / 0";
        return (win.findAt + 1) + " / " + n;
    }

    function io() {
        return (Quickshell.env("HOME") || "") + "/.config/quickshell/notes-io.py";
    }

    function refresh() {
        listProc.running = false;
        listProc.running = true;
    }

    function select(path) {
        if (path === win.selectedPath)
            return;
        win.flush();
        win.loading = true;
        win.selectedPath = path;
        win.dirty = false;
        win.savedAt = "";
        win.fileLocked = false;
        win.findAt = 0;
        win.findHits = [];
        win.findArmed = false;
        var n = null;
        for (var i = 0; i < win.notes.length; i++)
            if (win.notes[i].path === path)
                n = win.notes[i];
        if (n && n.book && n.book !== win.book)
            win.book = n.book;
    }

    function flush() {
        if (!win.dirty || win.selectedPath.length === 0 || win.noteLocked || win.loading)
            return;
        noteFile.setText(editor.text);
        win.dirty = false;
        win.savedAt = Qt.formatTime(new Date(), Prefs.timeFmt);
        win.refresh();
    }

    function createNote() {
        win.flush();
        createProc.command = ["python3", win.io(), "create", win.book];
        createProc.running = false;
        createProc.running = true;
    }

    function refreshBooks() {
        booksProc.running = false;
        booksProc.running = true;
    }

    function createBook(name) {
        var n = String(name || "").trim();
        if (!n.length)
            return;
        bookProc.command = ["python3", win.io(), "create-book", n];
        bookProc.running = false;
        bookProc.running = true;
    }

    function replaceCurrent() {
        if (win.noteLocked || !win.findNeedle.length)
            return;
        var hay = editor.text;
        var n = win.findNeedle;
        var r = win.replaceWith;
        var i = hay.toLowerCase().indexOf(n.toLowerCase(),
            win.findHits.length ? win.findHits[win.findAt] : 0);
        if (i < 0)
            i = hay.toLowerCase().indexOf(n.toLowerCase());
        if (i < 0)
            return;
        editor.text = hay.substring(0, i) + r + hay.substring(i + n.length);
        win.findNeedle = n;
        win.recomputeFind();
        win.findReveal();
    }

    function replaceAll() {
        if (win.noteLocked || !win.findNeedle.length)
            return;
        var hay = editor.text;
        var n = win.findNeedle;
        var r = win.replaceWith;
        var h = hay.toLowerCase();
        var q = n.toLowerCase();
        var out = "";
        var p = 0;
        while (true) {
            var j = h.indexOf(q, p);
            if (j < 0) {
                out += hay.substring(p);
                break;
            }
            out += hay.substring(p, j) + r;
            p = j + n.length;
        }
        editor.text = out;
        win.recomputeFind();
    }

    function spellPath() {
        return (Quickshell.env("HOME") || "") + "/.cache/nyxus/spell-in.txt";
    }
    function spellIo() {
        return (Quickshell.env("HOME") || "") + "/.config/quickshell/spell-io.py";
    }
    function runSpell() {
        if (win.noteLocked || !win.visible)
            return;
        spellDraft.setText(editor.text);
    }
    function missAt(pos) {
        var list = win.spellMiss;
        for (var i = 0; i < list.length; i++) {
            var m = list[i];
            var a = Number(m.start);
            var b = a + String(m.word || "").length;
            if (pos >= a && pos <= b)
                return m;
        }
        return null;
    }
    function applySuggestion(word, start, next) {
        var hay = editor.text;
        var a = Number(start);
        var n = String(word || "").length;
        editor.text = hay.substring(0, a) + next + hay.substring(a + n);
        editor.cursorPosition = a + String(next).length;
        spellDebounce.restart();
    }
    function openSpellMenu(sx, sy) {
        var pos = editor.cursorPosition;
        var m = win.missAt(pos);
        var entries = [];
        if (m && m.suggestions && m.suggestions.length) {
            for (var i = 0; i < m.suggestions.length; i++) {
                (function (s) {
                    entries.push({
                        label: s,
                        action: function () { win.applySuggestion(m.word, m.start, s); }
                    });
                })(m.suggestions[i]);
            }
            entries.push({ separator: true });
        } else if (m) {
            entries.push({ label: qsTr("No suggestions"), enabled: false });
            entries.push({ separator: true });
        }
        var hasSel = String(editor.selectedText || "").length > 0;
        entries.push({
            label: qsTr("Cut"),
            enabled: hasSel && !win.noteLocked,
            action: function () { editor.cut(); }
        });
        entries.push({
            label: qsTr("Copy"),
            enabled: hasSel,
            action: function () { editor.copy(); }
        });
        entries.push({
            label: qsTr("Paste"),
            enabled: !win.noteLocked,
            action: function () { editor.paste(); }
        });
        entries.push({ separator: true });
        entries.push({
            label: qsTr("Emoji…"),
            action: function () {
                win.wantEmoji = true;
                Bus.toggleEmoji();
            }
        });
        var ax = sx;
        var ay = sy;
        if (ax === undefined || ay === undefined) {
            var r = editor.cursorRectangle;
            var p = editor.mapToItem(null, r.x, r.y + r.height);
            ax = win.x + p.x;
            ay = win.y + p.y;
        }
        Menu.openAt(ax, ay, entries, null, m ? m.word : qsTr("Note"));
    }

    function trashCurrent() {
        if (win.selectedPath.length === 0)
            return;
        trashProc.command = ["python3", win.io(), "trash", win.selectedPath];
        trashProc.running = false;
        trashProc.running = true;
    }

    function lockCurrent() {
        if (win.selectedPath.length === 0 || win.noteLocked)
            return;
        win.flush();
        win.loading = true;
        lockProc.command = ["python3", win.io(), "lock", win.selectedPath];
        lockProc.running = false;
        lockProc.running = true;
    }

    function unlockCurrent() {
        if (win.selectedPath.length === 0 || !win.noteLocked)
            return;
        win.loading = true;
        lockProc.command = ["python3", win.io(), "unlock", win.selectedPath];
        lockProc.running = false;
        lockProc.running = true;
    }

    function collectHits(hay, needle) {
        var out = [];
        if (!needle || !needle.length || !hay || !hay.length)
            return out;
        var h = hay.toLowerCase();
        var n = needle.toLowerCase();
        var p = 0;
        var step = Math.max(1, n.length);
        while (true) {
            var j = h.indexOf(n, p);
            if (j < 0)
                break;
            out.push(j);
            p = j + step;
        }
        return out;
    }

    function recomputeFind() {
        if (win.noteLocked) {
            win.findHits = [];
            win.findAt = 0;
            return;
        }
        var hits = win.collectHits(editor.text, win.findNeedle);
        win.findHits = hits;
        if (win.findAt >= hits.length)
            win.findAt = Math.max(0, hits.length - 1);
    }

    function findStep(dir) {
        win.findArmed = true;
        win.recomputeFind();
        var n = win.findHits.length;
        if (n === 0)
            return;
        var i = win.findAt + dir;
        if (i < 0)
            i = n - 1;
        if (i >= n)
            i = 0;
        win.findAt = i;
        win.findReveal();
    }

    function findReveal() {
        if (!win.findArmed || win.findHits.length === 0)
            return;
        var i = win.findHits[win.findAt];
        var n = win.findNeedle.length;
        editor.select(i, i + n);
        var r = editor.cursorRectangle;
        var top = editFlick.contentY;
        var bot = top + editFlick.height;
        if (r.y < top)
            editFlick.contentY = Math.max(0, r.y - Theme.s4);
        else if (r.y + r.height > bot)
            editFlick.contentY = Math.max(0, r.y + r.height - editFlick.height + Theme.s4);
    }

    function matchRect(start, len) {
        if (typeof editor.positionToRectangle !== "function" || len <= 0)
            return { x: 0, y: 0, w: 0, h: 0 };
        try {
            var a = editor.positionToRectangle(start);
            var b = editor.positionToRectangle(start + Math.max(0, len - 1));
            var w = (a.y === b.y) ? Math.max(2, (b.x + b.width) - a.x)
                                  : Math.max(a.width, 2) * Math.min(len, 24);
            return { x: a.x, y: a.y, w: w, h: Math.max(a.height, 1) };
        } catch (e) {
            return { x: 0, y: 0, w: 0, h: 0 };
        }
    }

    function ageText(mtime) {
        var secs = Math.max(0, (Date.now() / 1000) - mtime);
        if (secs < 60) return qsTr("now");
        if (secs < 3600) return qsTr("%1m").arg(Math.floor(secs / 60));
        if (secs < 86400) return qsTr("%1h").arg(Math.floor(secs / 3600));
        var days = Math.floor(secs / 86400);
        if (days < 7) return qsTr("%1d").arg(days);
        return Qt.formatDateTime(new Date(mtime * 1000), "dd MMM");
    }

    onOpenChanged: {
        if (win.open) {
            win.refreshBooks();
            win.refresh();
        } else {
            win.flush();
        }
    }
    onVisibleChanged: if (win.visible) {
        win.refreshBooks();
        win.refresh();
    }

    Shortcut {
        sequences: ["Ctrl+F"]
        enabled: win.visible && !win.noteLocked && win.selectedPath.length > 0
        onActivated: findField.forceActiveFocus()
    }
    Shortcut {
        sequences: ["Ctrl+S"]
        enabled: win.visible
        onActivated: win.flush()
    }
    Shortcut {
        sequences: ["Ctrl+N"]
        enabled: win.visible
        onActivated: win.createNote()
    }
    Shortcut {
        sequences: ["Ctrl+H"]
        enabled: win.visible && !win.noteLocked
        onActivated: win.previewOn = !win.previewOn
    }
    Shortcut {
        sequences: ["Ctrl+."]
        enabled: win.visible && !win.noteLocked && editor.activeFocus
        onActivated: win.openSpellMenu()
    }
    Shortcut {
        sequences: ["Escape"]
        enabled: win.visible && findField.activeFocus
        onActivated: {
            findField.text = "";
            win.findNeedle = "";
            win.findHits = [];
            win.findArmed = false;
            editor.forceActiveFocus();
        }
    }

    IpcHandler {
        target: "notes"
        function ready(): string { return "ready"; }
        function engage(): string {
            Bus.notesOpen = true;
            win.refresh();
            return "notes";
        }
        function dismiss(): string {
            win.flush();
            Bus.notesOpen = false;
            return "hidden";
        }
        function at(path: string): string {
            Bus.notesOpen = true;
            win.pendingOpen = path;
            win.refresh();
            return path;
        }
    }

    Process {
        id: listProc
        running: false
        command: ["python3", win.io(), "list"]
        onExited: function (code) { if (code !== 0) console.warn("[Notes] note list exited code " + code); }
        stdout: StdioCollector {
            onStreamFinished: {
                var rows;
                try {
                    rows = JSON.parse(String(this.text));
                } catch (e) {
                    return;
                }
                win.notes = rows;
                if (win.pendingOpen.length > 0) {
                    win.select(win.pendingOpen);
                    win.pendingOpen = "";
                    return;
                }
                if (win.selectedPath.length === 0 && rows.length > 0)
                    win.select(rows[0].path);
            }
        }
    }

    Process {
        id: booksProc
        running: false
        command: ["python3", win.io(), "books"]
        onExited: function (code) { if (code !== 0) console.warn("[Notes] notebook list exited code " + code); }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var rows = JSON.parse(String(this.text));
                    if (rows && rows.length)
                        win.books = rows;
                } catch (e) { }
                var ok = false;
                for (var i = 0; i < win.books.length; i++)
                    if (win.books[i] === win.book)
                        ok = true;
                if (!ok && win.books.length)
                    win.book = win.books[0];
            }
        }
    }

    Process {
        id: bookProc
        running: false
        command: ["python3", win.io(), "create-book", "Notes"]
        onExited: function (code) { if (code !== 0) console.warn("[Notes] notebook create exited code " + code); }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    if (j && j.ok && j.book) {
                        win.book = j.book;
                        win.namingBook = false;
                    }
                } catch (e) { }
                win.refreshBooks();
                win.refresh();
            }
        }
    }

    Process {
        id: createProc
        running: false
        command: ["python3", win.io(), "create", "Notes"]
        onExited: function (code) { if (code !== 0) console.warn("[Notes] note create exited code " + code); }
        stdout: StdioCollector {
            onStreamFinished: {
                var p = String(this.text).trim();
                if (p.length === 0)
                    return;
                win.pendingOpen = p;
                win.refresh();
            }
        }
    }

    Process {
        id: trashProc
        running: false
        command: ["python3", win.io(), "list"]
        onExited: function (code) { if (code !== 0) console.warn("[Notes] note trash exited code " + code); }
        stdout: StdioCollector {
            onStreamFinished: {
                win.selectedPath = "";
                win.fileLocked = false;
                win.loading = true;
                editor.text = "";
                win.dirty = false;
                win.loading = false;
                win.refresh();
            }
        }
    }

    Process {
        id: lockProc
        running: false
        command: ["python3", win.io(), "list"]
        onExited: function (code) { if (code !== 0) console.warn("[Notes] note lock exited code " + code); }
        stdout: StdioCollector {
            onStreamFinished: {
                win.dirty = false;
                win.refresh();
                noteFile.reload();
            }
        }
    }

    FileView {
        id: noteFile
        path: win.selectedPath
        watchChanges: true
        printErrors: false
        onFileChanged: noteFile.reload()
        onLoaded: {
            win.loading = true;
            if (editor.activeFocus && win.dirty) {
                win.loading = false;
                return;
            }
            var t = noteFile.text() || "";
            var locked = t.indexOf(win.lockMark) === 0;
            win.fileLocked = locked;
            if (locked) {
                if (editor.text !== "")
                    editor.text = "";
                win.dirty = false;
                win.loading = false;
                win.spellMiss = [];
                win.recomputeFind();
                return;
            }
            if (editor.text !== t)
                editor.text = t;
            win.dirty = false;
            win.loading = false;
            win.recomputeFind();
            spellDebounce.restart();
        }
    }

    Timer {
        id: saveTimer
        interval: Math.max(1, win.autosaveSecs) * 1000
        onTriggered: win.flush()
    }
    Timer {
        id: spellDebounce
        interval: 480
        onTriggered: win.runSpell()
    }
    FileView {
        id: spellDraft
        path: win.spellPath()
        printErrors: false
        onLoaded: { }
        onSaved: {
            spellProc.command = ["python3", win.spellIo(), "file", win.spellPath()];
            spellProc.running = false;
            spellProc.running = true;
        }
    }
    Process {
        id: spellProc
        running: false
        command: ["python3", win.spellIo(), "file", win.spellPath()]
        onExited: function (code) { if (code !== 0) console.warn("[Notes] spell check exited code " + code); }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var j = JSON.parse(String(this.text));
                    win.spellMiss = j.miss || [];
                } catch (e) { }
            }
        }
    }
    Connections {
        target: Bus
        function onEmojiPicked(glyph) {
            if (!win.wantEmoji)
                return;
            win.wantEmoji = false;
            if (win.noteLocked)
                return;
            editor.insert(editor.cursorPosition, glyph);
            editor.forceActiveFocus();
        }
        function onEmojiOpenChanged() {
            if (Bus.emojiOpen && win.visible && !win.noteLocked
                    && (editor.activeFocus || win.wantEmoji))
                win.wantEmoji = true;
        }
    }

    component Ghost: Item {
        id: g
        property string mark: ""
        property bool on: false
        property bool danger: false
        property bool enabled: true
        signal tapped()

        implicitWidth: Math.max(36, lab.implicitWidth + 18)
        implicitHeight: 28
        width: implicitWidth
        height: implicitHeight
        opacity: g.enabled ? 1 : 0.35
        scale: tap.pressed ? 0.985 : (gh.hovered && g.enabled ? 1.012 : 1.0)
        Behavior on scale {
            NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutQuint }
        }

        CutRect {
            anchors.fill: parent
            radius: Theme.r1
            color: g.on ? Theme.elevated : "transparent"
            borderWidth: 1
            borderColor: Theme.soften(
                g.danger ? win.magma
                         : (gh.hovered ? win.iceFocus : win.iceHair),
                g.on || gh.hovered ? 0.85 : 0.45)
        }
        Text {
            id: lab
            anchors.centerIn: parent
            text: g.mark
            color: g.danger
                   ? (gh.hovered ? win.magmaHot : win.magma)
                   : Theme.text
            font.family: Theme.fUi
            font.pixelSize: Theme.tCaption
            font.weight: Theme.wStrong
            elide: Text.ElideRight
            clip: true
        }
        HoverHandler { id: gh; cursorShape: g.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler { id: tap; enabled: g.enabled; onTapped: g.tapped() }
    }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.s5

        // ── notebook spine (Notes++ books) ──────────────────────────
        Item {
            visible: win.sidebarOn
            Layout.preferredWidth: win.sidebarOn ? win.spineW : 0
            Layout.maximumWidth: win.sidebarOn ? win.spineW : 0
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                spacing: Theme.s3

                Text {
                    text: qsTr("BOOKS")
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    font.weight: Theme.wStrong
                    font.letterSpacing: Theme.trackMicro
                }

                Flickable {
                    id: spineFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: spineCol.height
                    interactive: contentHeight > height
                    Column {
                        id: spineCol
                        width: spineFlick.width
                        spacing: Theme.s2
                        Repeater {
                            model: win.books
                            delegate: Item {
                                id: tab
                                required property string modelData
                                width: spineCol.width
                                height: 36
                                readonly property bool current: tab.modelData === win.book
                                CutRect {
                                    anchors.fill: parent
                                    radius: Theme.r1
                                    color: tab.current ? Theme.elevated : "transparent"
                                    borderWidth: 1
                                    borderColor: Theme.soften(
                                        tab.current || tabHov.hovered ? win.iceFocus : win.iceHair,
                                        tab.current ? 0.85 : (tabHov.hovered ? 0.70 : 0.28))
                                }
                                Text {
                                    anchors.fill: parent
                                    anchors.margins: Theme.s3
                                    text: tab.modelData
                                    color: tab.current ? Theme.text : Theme.textMuted
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tCaption
                                    font.weight: tab.current ? Theme.wStrong : Font.Normal
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                    clip: true
                                }
                                HoverHandler { id: tabHov; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: win.book = tab.modelData }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: win.namingBook
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: Theme.r1
                    color: Theme.soften(Theme.void_, 0.50)
                    border.width: 1
                    border.color: Theme.soften(win.iceFocus, 0.80)
                    TextInput {
                        id: bookName
                        anchors.fill: parent
                        anchors.margins: Theme.s3
                        color: Theme.text
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        clip: true
                        Keys.onReturnPressed: function (e) {
                            win.createBook(bookName.text);
                            bookName.text = "";
                            e.accepted = true;
                        }
                        Keys.onEscapePressed: function (e) {
                            win.namingBook = false;
                            bookName.text = "";
                            e.accepted = true;
                        }
                    }
                }
                Ghost {
                    Layout.fillWidth: true
                    mark: win.namingBook ? qsTr("Save") : qsTr("+ Book")
                    onTapped: {
                        if (win.namingBook) {
                            win.createBook(bookName.text);
                            bookName.text = "";
                        } else {
                            win.namingBook = true;
                            bookName.forceActiveFocus();
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: win.sidebarOn
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Theme.soften(win.iceHair, 0.45)
        }

        // ── rail ────────────────────────────────────────────────────
        Item {
            visible: win.sidebarOn
            Layout.preferredWidth: win.sidebarOn ? win.railW : 0
            Layout.maximumWidth: win.sidebarOn ? win.railW : 0
            Layout.fillHeight: true

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
                        text: win.query.length ? qsTr("ALL NOTES") : win.book.toUpperCase()
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tMicro
                        font.weight: Theme.wStrong
                        font.letterSpacing: Theme.trackMicro
                        elide: Text.ElideRight
                        clip: true
                    }
                    Text {
                        text: String(win.visibleNotes.length)
                        color: Theme.textMuted
                        font.family: Theme.fNum
                        font.pixelSize: Theme.tMicro
                        font.features: ({ "tnum": 1 })
                    }
                    Item { Layout.fillWidth: true }
                    Ghost {
                        mark: qsTr("New")
                        onTapped: win.createNote()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: Theme.r1
                    color: Theme.soften(Theme.void_, 0.62)
                    border.width: 1
                    border.color: Theme.soften(searchHov.hovered || queryField.activeFocus
                                               ? win.iceFocus : win.iceHair,
                                               searchHov.hovered || queryField.activeFocus ? 0.80 : 0.45)

                    HoverHandler { id: searchHov }

                    TextInput {
                        id: queryField
                        anchors.fill: parent
                        anchors.leftMargin: Theme.s4
                        anchors.rightMargin: Theme.s4
                        color: Theme.text
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        clip: true
                        selectByMouse: true
                        selectionColor: Theme.soften(win.iceFocus, 0.28)
                        onTextChanged: win.query = text
                    }
                    Text {
                        anchors.fill: queryField
                        visible: queryField.text.length === 0 && !queryField.activeFocus
                        text: qsTr("Search notes")
                        color: Theme.textDim
                        font.family: Theme.fUi
                        font.italic: true
                        font.pixelSize: Theme.tCaption
                        elide: Text.ElideRight
                        clip: true
                        enabled: false
                    }
                }

                Flickable {
                    id: listFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: listCol.height
                    interactive: contentHeight > height
                    ScrollRail { flick: listFlick }

                    Column {
                        id: listCol
                        width: listFlick.width
                        spacing: Theme.s3

                        Repeater {
                            model: win.visibleNotes
                            delegate: Item {
                                id: row
                                required property var modelData
                                width: listCol.width
                                height: 64

                                readonly property bool current: row.modelData.path === win.selectedPath

                                scale: rowHov.hovered ? 1.012 : 1.0
                                Behavior on scale {
                                    NumberAnimation { duration: Theme.durQuick; easing.type: Easing.OutQuint }
                                }

                                CutRect {
                                    anchors.fill: parent
                                    radius: Theme.r1
                                    color: row.current ? Theme.elevated
                                         : (rowHov.hovered ? Theme.soften(Theme.elevated, 0.40)
                                                           : "transparent")
                                }
                                Pane {
                                    visible: row.current
                                    anchors.fill: parent
                                    elevation: 1
                                    bloomAtRest: false
                                    fill: Theme.panelMid
                                    radius: Theme.r1
                                    focusLevel: rowHov.hovered ? 0.55 : 0.18

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
                                }
                                CutRect {
                                    anchors.fill: parent
                                    radius: Theme.r1
                                    color: "transparent"
                                    borderWidth: 1
                                    borderColor: Theme.soften(
                                        rowHov.hovered && !row.current ? win.iceFocus : win.iceHair,
                                        row.current ? 0.85 : (rowHov.hovered ? 0.80 : 0.28))
                                    Behavior on borderColor {
                                        ColorAnimation { duration: Theme.durQuick }
                                    }
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.s4
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.s3
                                        StatusPip {
                                            kind: row.modelData.locked ? "ice" : "off"
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: row.modelData.locked
                                                  ? row.modelData.name
                                                  : (row.modelData.title || row.modelData.name)
                                            color: Theme.text
                                            font.family: Theme.fUi
                                            font.pixelSize: Theme.tBody
                                            font.weight: row.current ? Theme.wStrong : Font.Normal
                                            elide: Text.ElideRight
                                            clip: true
                                            maximumLineCount: 1
                                            wrapMode: Text.NoWrap
                                        }
                                        Text {
                                            text: win.ageText(row.modelData.mtime)
                                            color: Theme.textDim
                                            font.family: Theme.fNum
                                            font.pixelSize: Theme.tMicro
                                            font.features: ({ "tnum": 1 })
                                            elide: Text.ElideRight
                                            clip: true
                                        }
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: row.modelData.locked
                                              ? qsTr("Locked")
                                              : (row.modelData.snippet.length > 0
                                                 ? row.modelData.snippet
                                                 : qsTr("Empty note"))
                                        color: Theme.textMuted
                                        font.family: Theme.fUi
                                        font.pixelSize: Theme.tCaption
                                        elide: Text.ElideRight
                                        clip: true
                                        maximumLineCount: 1
                                        wrapMode: Text.NoWrap
                                    }
                                }

                                HoverHandler { id: rowHov; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: win.select(row.modelData.path) }
                            }
                        }

                        Text {
                            visible: win.visibleNotes.length === 0
                            width: listCol.width
                            text: win.query.length > 0
                                  ? qsTr("No notes match.")
                                  : qsTr("Nothing noted. Click New.")
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.italic: true
                            font.pixelSize: Theme.tBody
                            wrapMode: Text.Wrap
                            elide: Text.ElideRight
                            clip: true
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: win.sidebarOn
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            color: Theme.soften(win.iceHair, 0.45)
        }

        // ── editor ──────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.s4

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s4
                Text {
                    Layout.fillWidth: true
                    text: win.noteLocked
                          ? (win.currentNote ? win.currentNote.name : qsTr("Locked"))
                          : (win.currentTitle.length > 0 ? win.currentTitle : qsTr("No note open"))
                    color: Theme.text
                    font.family: Theme.fUiTitle
                    font.pixelSize: Theme.tHead
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    clip: true
                    maximumLineCount: 1
                    wrapMode: Text.NoWrap
                }
                Ghost {
                    visible: win.selectedPath.length > 0 && !win.noteLocked
                    mark: win.previewOn ? qsTr("Write") : qsTr("Preview")
                    on: win.previewOn
                    onTapped: win.previewOn = !win.previewOn
                }
                Ghost {
                    visible: win.selectedPath.length > 0
                    mark: win.noteLocked ? qsTr("Unlock") : qsTr("Lock")
                    onTapped: win.noteLocked ? win.unlockCurrent() : win.lockCurrent()
                }
                Ghost {
                    visible: win.selectedPath.length > 0
                    mark: qsTr("Trash")
                    danger: true
                    onTapped: win.trashCurrent()
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                CutRect {
                    anchors.fill: parent
                    radius: Theme.r1
                    color: Theme.elevated
                }
                CutRect {
                    anchors.fill: parent
                    radius: Theme.r1
                    color: "transparent"
                    borderWidth: 1
                    borderColor: Theme.soften(win.iceHair, 0.45)
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 1
                    spacing: 0
                    visible: !win.noteLocked

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        color: "transparent"
                        visible: win.selectedPath.length > 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.s4
                            anchors.rightMargin: Theme.s4
                            spacing: Theme.s3

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 28
                                radius: Theme.r1
                                color: Theme.soften(Theme.void_, 0.50)
                                border.width: 1
                                border.color: Theme.soften(
                                    findHov.hovered || findField.activeFocus ? win.iceFocus : win.iceHair,
                                    findHov.hovered || findField.activeFocus ? 0.80 : 0.45)
                                HoverHandler { id: findHov }
                                TextInput {
                                    id: findField
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.s4
                                    anchors.rightMargin: Theme.s4
                                    color: Theme.text
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tCaption
                                    clip: true
                                    selectByMouse: true
                                    persistentSelection: true
                                    selectionColor: Theme.soften(win.iceFocus, 0.28)
                                    enabled: win.selectedPath.length > 0 && !win.noteLocked
                                    onTextChanged: {
                                        win.findNeedle = text;
                                        win.findAt = 0;
                                        win.findArmed = text.length > 0;
                                        win.recomputeFind();
                                        win.findReveal();
                                    }
                                    Keys.onReturnPressed: function (e) {
                                        win.findStep(e.modifiers & Qt.ShiftModifier ? -1 : 1);
                                        e.accepted = true;
                                    }
                                    Keys.onEnterPressed: function (e) {
                                        win.findStep(e.modifiers & Qt.ShiftModifier ? -1 : 1);
                                        e.accepted = true;
                                    }
                                }
                                Text {
                                    anchors.fill: findField
                                    visible: findField.text.length === 0 && !findField.activeFocus
                                    text: qsTr("Find in note")
                                    color: Theme.textDim
                                    font.family: Theme.fUi
                                    font.italic: true
                                    font.pixelSize: Theme.tCaption
                                    elide: Text.ElideRight
                                    clip: true
                                    enabled: false
                                }
                            }
                            Text {
                                visible: win.findNeedle.length > 0
                                text: win.findCountText
                                color: Theme.textMuted
                                font.family: Theme.fNum
                                font.pixelSize: Theme.tMicro
                                font.features: ({ "tnum": 1 })
                                elide: Text.ElideRight
                                clip: true
                            }
                            Ghost {
                                mark: "‹"
                                enabled: win.findHits.length > 0
                                onTapped: win.findStep(-1)
                            }
                            Ghost {
                                mark: "›"
                                enabled: win.findHits.length > 0
                                onTapped: win.findStep(1)
                            }
                            Rectangle {
                                Layout.preferredWidth: 120
                                Layout.preferredHeight: 28
                                radius: Theme.r1
                                color: Theme.soften(Theme.void_, 0.50)
                                border.width: 1
                                border.color: Theme.soften(
                                    repHov.hovered || replaceField.activeFocus ? win.iceFocus : win.iceHair,
                                    replaceField.activeFocus ? 0.80 : 0.45)
                                HoverHandler { id: repHov }
                                TextInput {
                                    id: replaceField
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.s3
                                    anchors.rightMargin: Theme.s3
                                    color: Theme.text
                                    font.family: Theme.fUi
                                    font.pixelSize: Theme.tCaption
                                    clip: true
                                    onTextChanged: win.replaceWith = text
                                    Keys.onReturnPressed: function (e) {
                                        win.replaceCurrent();
                                        e.accepted = true;
                                    }
                                }
                                Text {
                                    anchors.fill: replaceField
                                    visible: replaceField.text.length === 0 && !replaceField.activeFocus
                                    text: qsTr("Replace")
                                    color: Theme.textDim
                                    font.family: Theme.fUi
                                    font.italic: true
                                    font.pixelSize: Theme.tCaption
                                    enabled: false
                                }
                            }
                            Ghost {
                                mark: qsTr("One")
                                enabled: win.findHits.length > 0
                                onTapped: win.replaceCurrent()
                            }
                            Ghost {
                                mark: qsTr("All")
                                enabled: win.findHits.length > 0
                                onTapped: win.replaceAll()
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 1
                            color: Theme.soften(win.iceHair, 0.45)
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 0

                    Flickable {
                        id: editFlick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: Math.max(height, editor.paintedHeight + Theme.s3)
                        interactive: contentHeight > height
                        ScrollRail { flick: editFlick }

                        Item {
                            id: hitLayer
                            width: editor.width
                            height: editor.paintedHeight
                            enabled: false
                            z: 0
                            Repeater {
                                model: win.spellMiss
                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property var box: {
                                        var _h = editor.paintedHeight;
                                        var _w = editor.width;
                                        return win.matchRect(Number(modelData.start), String(modelData.word || "").length);
                                    }
                                    x: box.x
                                    y: box.y + Math.max(0, box.h - 2)
                                    width: box.w
                                    height: 2
                                    visible: box.w > 0 && !win.findNeedle.length
                                    color: Theme.soften(win.magma, 0.70)
                                    radius: 1
                                }
                            }
                            Repeater {
                                model: win.findHits
                                delegate: Rectangle {
                                    required property int index
                                    required property var modelData
                                    readonly property var box: {
                                        var _h = editor.paintedHeight;
                                        var _w = editor.width;
                                        return win.matchRect(Number(modelData), win.findNeedle.length);
                                    }
                                    x: box.x
                                    y: box.y
                                    width: box.w
                                    height: box.h
                                    visible: box.w > 0 && win.findNeedle.length > 0
                                    color: Theme.soften(win.iceFocus, index === win.findAt ? 0.28 : 0.12)
                                    radius: 2
                                }
                            }
                        }

                        TextEdit {
                            id: editor
                            width: editFlick.width
                            z: 1
                            wrapMode: TextEdit.Wrap
                            color: Theme.text
                            font.family: Theme.fUi
                            font.pixelSize: win.editorSize
                            selectByMouse: true
                            persistentSelection: true
                            activeFocusOnPress: true
                            enabled: win.selectedPath.length > 0 && !win.noteLocked
                            selectionColor: Theme.soften(win.iceFocus, 0.28)
                            onTextChanged: {
                                if (win.loading || !win.visible || win.noteLocked)
                                    return;
                                if (win.selectedPath.length === 0)
                                    return;
                                win.dirty = true;
                                if (win.autosaveSecs > 0)
                                    saveTimer.restart();
                                win.recomputeFind();
                                spellDebounce.restart();
                            }
                            onEditingFinished: win.flush()
                            onActiveFocusChanged: if (editor.activeFocus) win.findArmed = false
                            TapHandler {
                                acceptedButtons: Qt.RightButton
                                onTapped: function (eventPoint) {
                                    var local = eventPoint.position;
                                    if (typeof editor.positionAt === "function")
                                        editor.cursorPosition = editor.positionAt(local.x, local.y);
                                    var gp = editor.mapToItem(null, local.x, local.y);
                                    win.openSpellMenu(win.x + gp.x, win.y + gp.y);
                                }
                            }

                            Text {
                                anchors.fill: parent
                                enabled: false
                                visible: editor.text.length === 0 && !editor.activeFocus
                                text: win.selectedPath.length === 0
                                      ? qsTr("Pick a note, or click New.")
                                      : qsTr("Nothing noted. Click to write.")
                                color: Theme.textDim
                                font.family: Theme.fUi
                                font.italic: true
                                font.pixelSize: win.editorSize
                                wrapMode: Text.Wrap
                            }
                        }
                    }

                    Rectangle {
                        visible: win.previewOn && win.noteFormat === "Markdown"
                        Layout.preferredWidth: 1
                        Layout.fillHeight: true
                        color: Theme.soften(win.iceHair, 0.45)
                    }
                    Flickable {
                        id: previewFlick
                        visible: win.previewOn && win.noteFormat === "Markdown"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: width
                        contentHeight: Math.max(height, previewBody.implicitHeight + Theme.s5)
                        interactive: contentHeight > height
                        ScrollRail { flick: previewFlick }
                        Text {
                            id: previewBody
                            width: previewFlick.width - Theme.s5
                            x: Theme.s4
                            y: Theme.s3
                            text: editor.text
                            textFormat: Text.MarkdownText
                            wrapMode: Text.Wrap
                            color: Theme.text
                            font.family: Theme.fUi
                            font.pixelSize: win.editorSize
                        }
                    }
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: win.noteLocked
                    z: 2

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.s4
                        width: Math.min(parent.width - Theme.s8, 280)

                        StatusPip {
                            kind: "ice"
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            width: parent.width
                            text: qsTr("This note is locked")
                            color: Theme.text
                            font.family: Theme.fUiTitle
                            font.pixelSize: Theme.tHead
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            clip: true
                        }
                        Text {
                            width: parent.width
                            text: qsTr("Unlock to read and write. The lock is a header, not a cipher.")
                            color: Theme.textDim
                            font.family: Theme.fUi
                            font.pixelSize: Theme.tCaption
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Ghost {
                            anchors.horizontalCenter: parent.horizontalCenter
                            mark: qsTr("Unlock")
                            onTapped: win.unlockCurrent()
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.s4
                Text {
                    Layout.fillWidth: true
                    text: {
                        var n = win.currentNote;
                        if (!n)
                            return "";
                        var book = String(n.book || "");
                        var name = String(n.name || n.path || "");
                        return book.length ? (book + " · " + name) : name;
                    }
                    color: Theme.textMuted
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    elide: Text.ElideRight
                    clip: true
                    maximumLineCount: 1
                    wrapMode: Text.NoWrap
                }
                Text {
                    visible: win.selectedPath.length > 0
                    text: win.noteLocked
                          ? qsTr("Locked")
                          : qsTr("%1 words · %2 ch").arg(win.wordCount).arg(win.charCount)
                    color: Theme.textMuted
                    font.family: Theme.fNum
                    font.pixelSize: Theme.tMicro
                    font.features: ({ "tnum": 1 })
                    elide: Text.ElideRight
                    clip: true
                }
                Text {
                    visible: win.selectedPath.length > 0
                    text: win.noteFormat
                    color: Theme.textDim
                    font.family: Theme.fUi
                    font.pixelSize: Theme.tMicro
                    font.letterSpacing: Theme.trackMicro
                    elide: Text.ElideRight
                    clip: true
                }
            }
        }
    }
}
