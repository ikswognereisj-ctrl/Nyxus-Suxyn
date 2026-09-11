pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ System ▸ Apps & defaults.   MODULE 6.
//
// Backend: `xdg-mime query default` / `xdg-mime default`. Same handlers
// the same handlers the desktop already uses. This is the glass surface
// for the handful a person actually changes (browser, photos, mail,
// files). It is not the installed-package dump — that dump is what made
// first-open feel like too much. Uninstall stays in the package manager.
import Quickshell
import Quickshell.Io
import QtQuick

SetPage {
    id: page
    property var entry: null

    title: qsTr("Apps & defaults")
    blurb: qsTr("Which app opens the browser, photos, mail, and files.")

    property var everyday: []
    property var media: []
    property var documents: []
    property bool probed: false
    property bool lastFailed: false

    readonly property var everydayIds: ["browser", "mail", "files"]
    readonly property var mediaIds: ["photos", "video", "music"]
    readonly property var documentIds: ["pdf", "text"]

    Component.onCompleted: probe.running = true

    Process {
        id: probe
        running: false
        command: ["python3", "-c",
            "import json, os, glob, subprocess, sys\n"
            + "roles = [\n"
            + " ('browser','Web browser','x-scheme-handler/https'),\n"
            + " ('mail','Email','x-scheme-handler/mailto'),\n"
            + " ('files','Files','inode/directory'),\n"
            + " ('photos','Photos','image/jpeg'),\n"
            + " ('video','Video','video/mp4'),\n"
            + " ('music','Music','audio/mpeg'),\n"
            + " ('pdf','PDF','application/pdf'),\n"
            + " ('text','Plain text','text/plain'),\n"
            + "]\n"
            + "def handlers(mime):\n"
            + "    out, seen = [], set()\n"
            + "    roots = ['/usr/share/applications',\n"
            + "             os.path.expanduser('~/.local/share/applications')]\n"
            + "    for root in roots:\n"
            + "        if not os.path.isdir(root):\n"
            + "            continue\n"
            + "        for path in sorted(glob.glob(os.path.join(root, '*.desktop'))):\n"
            + "            name = os.path.basename(path)\n"
            + "            if name in seen:\n"
            + "                continue\n"
            + "            try:\n"
            + "                txt = open(path, errors='ignore').read()\n"
            + "            except OSError:\n"
            + "                continue\n"
            + "            if 'NoDisplay=true' in txt or 'Hidden=true' in txt:\n"
            + "                continue\n"
            + "            mt = ''\n"
            + "            for ln in txt.splitlines():\n"
            + "                if ln.startswith('MimeType='):\n"
            + "                    mt = ln.split('=',1)[1]\n"
            + "                    break\n"
            + "            if mime not in [p.strip() for p in mt.split(';') if p.strip()]:\n"
            + "                continue\n"
            + "            label = name.replace('.desktop','')\n"
            + "            for ln in txt.splitlines():\n"
            + "                if ln.startswith('Name='):\n"
            + "                    label = ln.split('=',1)[1].strip()\n"
            + "                    break\n"
            + "            out.append({'value': name, 'label': label})\n"
            + "            seen.add(name)\n"
            + "    return out\n"
            + "def current(mime):\n"
            + "    try:\n"
            + "        r = subprocess.run(['xdg-mime','query','default',mime],\n"
            + "                           capture_output=True, text=True, timeout=2)\n"
            + "        return (r.stdout or '').strip()\n"
            + "    except Exception:\n"
            + "        return ''\n"
            + "rows = []\n"
            + "for rid, title, mime in roles:\n"
            + "    hs = handlers(mime)\n"
            + "    cur = current(mime)\n"
            + "    rows.append({'id': rid, 'title': title, 'mime': mime,\n"
            + "                 'current': cur, 'options': hs})\n"
            + "json.dump(rows, sys.stdout)\n"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                var rows;
                try {
                    rows = JSON.parse(String(this.text));
                } catch (e) {
                    page.lastFailed = true;
                    page.probed = true;
                    return;
                }
                var ev = [], me = [], doc = [];
                for (var i = 0; i < rows.length; ++i) {
                    var r = rows[i];
                    if (page.everydayIds.indexOf(r.id) >= 0)
                        ev.push(r);
                    else if (page.mediaIds.indexOf(r.id) >= 0)
                        me.push(r);
                    else
                        doc.push(r);
                }
                page.everyday = ev;
                page.media = me;
                page.documents = doc;
                page.probed = true;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                var m = String(this.text).trim();
                if (m !== "")
                    page.lastFailed = true;
            }
        }
    }

    Process {
        id: setter
        running: false
        property bool failed: false
        stderr: StdioCollector {
            onStreamFinished: {
                var m = String(this.text).trim();
                if (m !== "")
                    setter.failed = true;
            }
        }
        onRunningChanged: {
            if (!setter.running) {
                page.lastFailed = setter.failed;
                setter.failed = false;
                probe.running = true;
            }
        }
    }

    function setDefault(mime, desktop, roleId) {
        if (setter.running || !desktop || !mime)
            return;
        page.lastFailed = false;
        var extra = "";
        if (roleId === "browser")
            extra = 'xdg-mime default "$2" x-scheme-handler/http >/dev/null 2>&1 || true; '
                  + 'command -v xdg-settings >/dev/null 2>&1 && '
                  + 'xdg-settings set default-web-browser "$2" >/dev/null 2>&1 || true; ';
        setter.command = ["sh", "-c",
            'command -v xdg-mime >/dev/null 2>&1 || { echo "unavailable" >&2; exit 1; }; '
          + 'xdg-mime default "$2" "$1"; ' + extra,
            "sh", mime, desktop];
        setter.running = true;
    }

    SetCard {
        heading: qsTr("Everyday")
        tone: page.tone
        note: page.lastFailed
              ? qsTr("Something went wrong updating a default.")
              : qsTr("Folders open Files — the glass file manager.")

        Repeater {
            model: page.everyday
            delegate: SetRow {
                id: ev
                required property var modelData
                title: ev.modelData.title
                sub: ev.modelData.current !== ""
                     ? ev.modelData.current.replace(".desktop", "")
                     : qsTr("No default set")

                SetChoice {
                    tone: page.tone
                    segmentLimit: 0
                    value: ev.modelData.current
                    options: ev.modelData.options
                    emptyText: qsTr("Unavailable")
                    onChosen: function (v) {
                        page.setDefault(ev.modelData.mime, v, ev.modelData.id);
                    }
                }
            }
        }

        SetRow {
            visible: page.probed && page.everyday.length === 0
            title: qsTr("Defaults")
            sub: qsTr("Unavailable")
        }
    }

    SetCard {
        heading: qsTr("Photos & media")
        tone: page.tone
        note: qsTr("Music opens Media. Photos open Viewer — the glass gallery. The bar popup is unchanged.")

        Repeater {
            model: page.media
            delegate: SetRow {
                id: md
                required property var modelData
                title: md.modelData.title
                sub: md.modelData.current !== ""
                     ? md.modelData.current.replace(".desktop", "")
                     : qsTr("No default set")

                SetChoice {
                    tone: page.tone
                    segmentLimit: 0
                    value: md.modelData.current
                    options: md.modelData.options
                    emptyText: qsTr("Unavailable")
                    onChosen: function (v) {
                        page.setDefault(md.modelData.mime, v, md.modelData.id);
                    }
                }
            }
        }
    }

    SetCard {
        heading: qsTr("Documents")
        tone: page.tone
        note: qsTr("Plain text opens Notes. PDFs open Reader — the glass viewer.")

        Repeater {
            model: page.documents
            delegate: SetRow {
                id: dc
                required property var modelData
                title: dc.modelData.title
                sub: dc.modelData.current !== ""
                     ? dc.modelData.current.replace(".desktop", "")
                     : qsTr("No default set")

                SetChoice {
                    tone: page.tone
                    segmentLimit: 0
                    value: dc.modelData.current
                    options: dc.modelData.options
                    emptyText: qsTr("Unavailable")
                    onChosen: function (v) {
                        page.setDefault(dc.modelData.mime, v, dc.modelData.id);
                    }
                }
            }
        }
    }
}
