pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ Personalization ▸ Background.   MODULE 1.
//
// ── the backend ─────────────────────────────────────────────────────────
//   still image   `nyxus-set-wallpaper` with a FULL PATH (WIP-839: the
//                 short-name shim used to print `applied:` with an empty
//                 path). Fallback `awww img` / `swww img`.
//   reach         `sky_mode=wallpaper` in settings.json — a sky is a
//                 Bottom-layer surface and wins the pixel over any still
//                 (WIP-555). Picking a picture is asking to SEE it.
//   listing       /usr/share/backgrounds/nyxus then ~/.config/hypr/walls,
//                 suxyn-*.png, dupes skipped, sorted by slug. The grid
//                 then keeps only keepSlugs. Pair probe:
//                 ~/.local/share/nyxus/walls/<slug>-{bg,fg}.png.
//
// Pictures grid is a keep-set, not the whole rotation. Other suxyn-*.png
// files stay on disk; they are hidden from this picker. Numbering is 1..N
// in keepSlugs order (stable), not the old 48-wide nl.
//
// Ships from shell/ only (`QS_SRC` → skel `.config/quickshell`). There is
// no airootfs twin of SetPage*. Do not invent one.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    property var entry: null

    title: qsTr("Background")
    blurb: qsTr("Starlight, or pick a numbered still.")

    readonly property color iceFocus: Theme.paintLayers.glacier[0]
    readonly property color iceHover: Theme.paintLayers.glacier[5]

    property var featured: []
    property var moreWalls: []
    property string currentSlug: ""
    property string currentPath: ""
    // Keep-set. Old grid n was `nl` after sort of suxyn-*.png in
    // /usr/share/backgrounds/nyxus then ~/.config/hypr/walls (dupes skipped).
    // New n is this array's index + 1, and stays put if a file is missing.
    //   1  suxyn-concrete-rose     was  3
    //   2  suxyn-ocular-wide       pulled-back 14 (hyprlock-eye stays on disk)
    //   3  suxyn-nebula-veil       was 27  (layered still)
    //   4  suxyn-tatra-nocturne    was 37
    //   5  suxyn-twin-moons        was 40
    //   6  suxyn-urban-astronaut   was 41
    //   7  suxyn-violet-rapture    was 42
    //   8  suxyn-voyage-galaxy     was 46
    //   9  suxyn-voyage-rings      was 47
    //  10  suxyn-fiber-headliner   RR fibre-star roof (new)
    //  11  suxyn-meteor-strike     two meteors colliding (new)
    readonly property var keepSlugs: [
        "suxyn-concrete-rose",
        "suxyn-ocular-wide",
        "suxyn-nebula-veil",
        "suxyn-tatra-nocturne",
        "suxyn-twin-moons",
        "suxyn-urban-astronaut",
        "suxyn-violet-rapture",
        "suxyn-voyage-galaxy",
        "suxyn-voyage-rings",
        "suxyn-fiber-headliner",
        "suxyn-meteor-strike"
    ]
    // TRK-3502 · the same records as `moreWalls`, keyed by slug for the
    // "Also shipped" picker. Kept as its own binding rather than mapped inline
    // so the grid above and the list below cannot drift apart.
    readonly property var moreChoices: page.moreWalls.map(function (r) {
        return { value: r.slug, label: r.label };
    })
    property string lastError: ""
    property bool probed: false

    function prettyLabel(slug) {
        var s = String(slug).replace(/^suxyn-/, "").replace(/-/g, " ");
        return s.replace(/\b\w/g, function (c) { return c.toUpperCase(); });
    }

    LiveMark { id: applyMark; visible: false; actual: page.currentSlug !== "" ? page.currentSlug : page.currentPath }

    readonly property string skyMode: SettingsStore.stringValue("sky_mode", "headliner")
    // TRK-3426 (moved with the cards): the 3D window only maps when the sky
    // is Voyage; the flat Starlight overlay lives on any non-Headliner,
    // non-wallpaper sky while Voyage is off (SETX TRK-3121).
    readonly property bool voyageOn: SettingsStore.boolValue("voyage_enabled", true)
    readonly property bool voyageLive: page.skyMode === "voyage"
    readonly property bool starlightOverlayLive: page.skyMode !== "headliner"
                                                 && page.skyMode !== "wallpaper"
                                                 && !page.voyageOn

    Component.onCompleted: {
        page.readCurrent();
        listWalls.running = true;
    }

    function readCurrent() {
        if (!curProc.running)
            curProc.running = true;
    }

    Process {
        id: curProc
        running: false
        command: ["sh", "-c",
            'f="$HOME/.config/nyxus/wallpaper.conf"; '
          + '[ -r "$f" ] || exit 0; '
          + 'slug=""; path=""; '
          + 'while IFS= read -r ln; do '
          + '  case "$ln" in '
          // TRK-3452 (same class as listWalls below): `\"` in a JS string is
          // just `"` — the shell got ${slug#"} , an UNBALANCED quote, and
          // this whole script died at parse time. currentSlug/currentPath
          // never populated, so ON THE DESKTOP always read "—".
          + '    WALLPAPER=*) slug=${ln#WALLPAPER=}; slug=${slug#\\"}; slug=${slug%\\"} ;; '
          + '    WALLPAPER_PATH=*) path=${ln#WALLPAPER_PATH=}; path=${path#\\"}; path=${path%\\"} ;; '
          + '  esac; '
          + 'done < "$f"; '
          + 'printf "%s\\t%s\\n" "$slug" "$path"']
        stdout: StdioCollector {
            onStreamFinished: {
                var line = String(this.text).trim();
                var tab = line.indexOf("\t");
                if (tab < 0)
                    return;
                page.currentSlug = line.slice(0, tab);
                page.currentPath = line.slice(tab + 1);
            }
        }
    }

    Process {
        id: listWalls
        running: false
        command: ["sh", "-c",
            'seen=""; '
          + 'for d in "$HOME/.local/share/nyxus/walls" "$HOME/.config/hypr/walls" /usr/share/backgrounds/nyxus; do '
          + '  [ -d "$d" ] || continue; '
          + '  for p in "$d"/suxyn-*.png; do '
          + '    [ -f "$p" ] || continue; '
          + '    b=$(basename "$p" .png); '
          + '    case "$b" in *-bg|*-fg) continue ;; esac; '
          + '    case " $seen " in *" $b "*) continue ;; esac; '
          + '    seen="$seen $b"; '
          + '    pair=""; '
          + '    lay="$HOME/.local/share/nyxus/walls/$b"; '
          + '    if [ -f "$lay-bg.png" ] && [ -f "$lay-fg.png" ]; then pair="$lay"; fi; '
          + '    printf "%s\\t%s\\t%s\\n" "$b" "$p" "$pair"; '
          + '  done; '
          + 'done | sort -k1,1']
        stdout: StdioCollector {
            onStreamFinished: {
                var bySlug = {};
                var lines = String(this.text).split("\n");
                for (var i = 0; i < lines.length; ++i) {
                    var f = lines[i].split("\t");
                    if (f.length < 2 || f[0] === "")
                        continue;
                    bySlug[f[0]] = {
                        slug: f[0],
                        path: f[1],
                        layeredBase: f.length > 2 ? f[2] : ""
                    };
                }
                var feat = [];
                for (var k = 0; k < page.keepSlugs.length; ++k) {
                    var rec = bySlug[page.keepSlugs[k]];
                    if (!rec)
                        continue;
                    feat.push({
                        n: k + 1,
                        slug: rec.slug,
                        label: page.prettyLabel(rec.slug),
                        path: rec.path,
                        value: rec.path,
                        layeredBase: rec.layeredBase
                    });
                }
                page.featured = feat;
                page.moreWalls = [];
                page.probed = true;
            }
        }
    }

    Process {
        id: applyProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var text = String(this.text);
                var lines = text.split("\n");
                var applied = "";
                var layered = null;
                for (var i = 0; i < lines.length; ++i) {
                    var ln = lines[i].trim();
                    if (ln.indexOf("layered:") === 0)
                        layered = ln.slice(8).trim();
                    else if (ln.indexOf("applied:") === 0)
                        applied = ln.slice(8).trim();
                }
                if (layered !== null)
                    page.applySkyFor(layered);
                if (applied === "" && text.indexOf("applied:") >= 0) {
                    console.warn("Background: setter reported applied with an empty path");
                    page.lastError = qsTr("Could not apply the wallpaper.");
                    applyMark.fail();
                    return;
                }
                if (applied !== "") {
                    page.lastError = "";
                    page.readCurrent();
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                var m = String(this.text).trim();
                if (m !== "") {
                    console.warn("Background: " + m);
                    page.lastError = qsTr("Could not apply the wallpaper.");
                    applyMark.fail();
                }
            }
        }
        onExited: function (code) {
            if (code !== 0) {
                if (!applyMark.failed)
                    applyMark.fail();
                return;
            }
            page.readCurrent();
        }
    }

    function layeredBaseFor(slug) {
        if (!slug)
            return "";
        var feat = page.featured;
        for (var i = 0; i < feat.length; i++) {
            if (feat[i].slug === slug && feat[i].layeredBase)
                return feat[i].layeredBase;
        }
        return "";
    }

    // Pair at ~/.local/share/nyxus/walls/<slug>-{bg,fg}.png → sky_mode=layered
    // and layered_wall_base=that prefix. Otherwise wallpaper, the still.
    function applySkyFor(layeredBase) {
        if (layeredBase) {
            SettingsStore.setValues({
                sky_mode: "layered",
                layered_wall_base: layeredBase
            });
        } else {
            SettingsStore.setValue("sky_mode", "wallpaper");
        }
        SettingsStore.flush();
    }

    function applyPath(path, slug) {
        if (applyProc.running || !path)
            return;
        applyMark.request(slug || path);
        page.applySkyFor(page.layeredBaseFor(slug));
        applyProc.command = ["sh", "-c",
            'p="$1"; slug="$2"; '
          + '[ -n "$p" ] || { echo "empty path — refusing" >&2; exit 2; }; '
          + '[ -f "$p" ] && [ -r "$p" ] || { echo "cannot read $p" >&2; exit 1; }; '
          + 'base="$HOME/.local/share/nyxus/walls/$slug"; '
          + 'if [ -n "$slug" ] && [ -f "$base-bg.png" ] && [ -f "$base-fg.png" ]; then '
          + '  printf "layered: %s\\n" "$base"; '
          + 'else '
          + '  printf "layered:\\n"; '
          + 'fi; '
          + 'PATH="${NYXUS_BIN_DIR:-/usr/local/bin}:$PATH"; '   // TRK-3435
          + 'if command -v nyxus-set-wallpaper >/dev/null 2>&1; then '
          + '  nyxus-set-wallpaper "$p"; '
          + '  rc=$?; '
          + 'elif command -v awww >/dev/null 2>&1; then '
          + '  awww img "$p"; rc=$?; echo "applied: $p"; '
          + 'elif command -v swww >/dev/null 2>&1; then '
          + '  swww img "$p"; rc=$?; echo "applied: $p"; '
          + 'else '
          + '  echo "no wallpaper backend (nyxus-set-wallpaper / awww / swww)" >&2; '
          + '  exit 1; '
          + 'fi; '
          + 'exit $rc',
            "sh", path, slug || ""];
        applyProc.running = true;
    }

    SetCard {
        heading: qsTr("Source")
        tone: page.tone
        note: page.lastError !== ""
              ? page.lastError
              : (page.skyMode === "headliner"
                 ? qsTr("Starlight is the live ground. A still sits under it until you pick Picture.")
                 : page.skyMode === "layered"
                   ? qsTr("This picture is split: far plate behind the chips, near veil in front of the void.")
                   : qsTr("This is the still on the desktop."))

        SetRow {
            title: qsTr("Sky")
            sub: page.skyMode === "headliner"
                 ? qsTr("Starlight — fibre stars, the one you use")
                 : page.skyMode === "layered"
                   ? qsTr("Layers — this still, cut so the chips sit in it")
                   : qsTr("Picture — the still you pick below")

            SetChoice {
                key: "sky_mode"
                defaultValue: "headliner"
                tone: page.tone
                options: [
                    { value: "headliner", label: qsTr("Starlight") },
                    { value: "wallpaper", label: qsTr("Picture") },
                    { value: "layered", label: qsTr("Layers") }
                ]
            }
        }

        SetRow {
            title: qsTr("On the desktop")
            valueText: page.currentPath !== "" ? page.currentPath
                     : (page.currentSlug !== "" ? page.currentSlug : "—")
            sub: page.lastError !== "" ? page.lastError
                 : (page.currentSlug !== "" ? page.currentSlug : qsTr("Nothing applied yet"))

            StatusPip {
                Layout.alignment: Qt.AlignVCenter
                kind: applyMark.failed ? "amber" : (applyMark.pending ? "ice" : "off")
                pulse: applyMark.pending || applyMark.failed
            }
        }
    }

    SetCard {
        heading: qsTr("Pictures")
        tone: page.tone
        visible: page.skyMode === "wallpaper" || page.featured.length > 0
        note: page.probed && page.featured.length === 0
              ? qsTr("No stills on this machine.")
              : qsTr("%1 stills, numbered.")
                .arg(page.featured.length)

        GridLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.s4
            // TRK-2913. Two columns of a 16:9 still. At the settings page's
            // 664 body a card was (664 − 2×s4 − s4) / 2 = 320 wide, and the
            // picture inside it (less s1 either side and the 24 label band) is
            // **316 × 82 — 3.85:1 against the 1.78 the file actually is**, so
            // `PreserveAspectCrop` threw away the top and bottom THIRD of
            // every wallpaper: a thumbnail grid that could not show you the
            // thing you were picking. The eight stills also took FOUR rows,
            // 4×108 + 3×s4 = **456 px** of a 640 px window. Three columns:
            // card (664 − 2×s4 − 2×s4) / 3 = 210, picture **206 × 82 = 2.51:1**,
            // a third less crop, and the eight land in three rows —
            // 3×108 + 2×s4 = **340 px, 116 fewer** — with the ninth slot free
            // instead of a fourth row holding two tiles and a gap.
            columns: 3
            columnSpacing: Theme.s4
            rowSpacing: Theme.s4

            Repeater {
                model: page.featured

                delegate: Item {
                    id: card
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: 108

                    readonly property bool on: page.currentSlug === card.modelData.slug
                                               || page.currentPath === card.modelData.path
                    readonly property bool waiting: (applyMark.pending || applyMark.failed)
                                                    && applyMark.want === card.modelData.slug

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.r2
                        color: Theme.soften(Theme.void_, 0.55)
                        border.width: 1
                        border.color: hov.hovered && !card.on ? page.iceHover
                                      : Theme.paintLayers.glacier[4]
                    }

                    // Selected ring — 1 px, ice, local opacity breathe.
                    // Theme.durSettle / durRise. Not a full-surface veil.
                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.r2
                        color: "transparent"
                        border.width: 1
                        border.color: page.iceFocus
                        visible: card.on
                        opacity: 0.85
                        SequentialAnimation on opacity {
                            running: card.on
                                     && card.Window.window !== null
                                     && card.Window.window.visible
                            loops: Animation.Infinite
                            NumberAnimation { to: 1.0; duration: Theme.durSettle }
                            NumberAnimation { to: 0.55; duration: Theme.durRise }
                        }
                    }

                    Image {
                        id: thumb
                        anchors.fill: parent
                        // TRK-2913: two off-scale literals for what is a
                        // hairline inset and a label band — s1 (2) and s8
                        // (24), rungs the rest of this page already uses. The
                        // band gains 2 px, which is the label's own descender
                        // room at tCaption and was the reason it sat tight
                        // against the picture.
                        anchors.margins: Theme.s1
                        anchors.bottomMargin: Theme.s8
                        source: "file://" + card.modelData.path
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 320
                        sourceSize.height: 180
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.leftMargin: Theme.s2
                        anchors.topMargin: Theme.s2
                        width: Math.max(22, numLab.implicitWidth + 10)
                        height: 18
                        radius: 4
                        color: Theme.soften(Theme.void_, 0.72)
                        border.width: 1
                        border.color: Theme.paintLayers.glacier[4]
                        Text {
                            id: numLab
                            anchors.centerIn: parent
                            text: String(card.modelData.n || (card.index + 1))
                            color: Theme.text
                            font.family: Theme.fNum
                            font.pixelSize: Theme.tMicro
                        }
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: Theme.s3
                        text: card.modelData.label
                        color: card.on ? page.iceFocus : Theme.text
                        font.family: Theme.fUi
                        font.pixelSize: Theme.tCaption
                        elide: Text.ElideRight
                        clip: true
                    }

                    StatusPip {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: Theme.s3
                        anchors.topMargin: Theme.s3
                        kind: card.waiting ? (applyMark.failed ? "amber" : "ice") : "off"
                        pulse: card.waiting
                    }

                    HoverHandler { id: hov }
                    TapHandler {
                        onTapped: page.applyPath(card.modelData.path,
                                                 card.modelData.slug)
                    }
                }
            }
        }
    }

    SetCard {
        heading: qsTr("Also")
        tone: page.tone

        SetRow {
            title: qsTr("Desktop widgets")
            sub: qsTr("Six chips on the wallpaper — none of them is the bar clock")
            navigates: true
            onActivated: Bus.openSettings("widgets")
        }

        SetRow {
            title: qsTr("Appearance")
            sub: qsTr("Living paint on chrome, and how Start opens")
            navigates: true
            onActivated: Bus.openSettings("appearance")
        }
    }


    // TRK-1261 — the one settings.json key this page writes (the wallpaper itself is wallpaper.conf, not this file).
    SetResetRow {
        what: qsTr("Background")
        // TRK-3426: the moved cards' keys, with sky_mode. 13r81 holds this
        // list equal to what the page writes.
        keys: ["sky_mode", "layered_wall_base"]
    }
}
