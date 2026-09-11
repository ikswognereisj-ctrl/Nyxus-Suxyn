pragma ComponentBehavior: Bound
// Nyxus Suxyn — Settings ▸ Personalization ▸ Fonts & text size.   MODULE 2.
//
// ── the backend, and why there are three of them ────────────────────────
// A desktop font setting has to reach three different worlds or the machine
// ends up in two typefaces:
//
//   GTK apps      `gsettings set org.gnome.desktop.interface font-name`
//                 (Files, Settings-classic, Thunderbird, Chromium's menus)
//   Qt apps       `~/.config/qt6ct/qt6ct.conf` / `qt5ct`, read at app start
//   rendering     `~/.config/fontconfig/fonts.conf` — hinting, antialiasing
//                 and subpixel order apply to *everything*, including both
//                 of the above
//
// All three are written here, from one choice. `gsettings` persists into dconf
// immediately and running GTK apps follow within a frame; Qt apps pick it up
// the next time they start, which is a Qt fact rather than a bug here, and the
// page says so rather than pretending otherwise.
//
// Ice stones, not typeface/size/rendering spreadsheet rows. Family menus stay
// SetChoice — fc-list is long, and offering icon fonts as an interface face
// gives you a window of boxes. Size stays sliders under stones. The shell's
// own type is still Theme.qml (another lane); this page says so.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    property var entry: null

    title: qsTr("Fonts & text size")
    blurb: qsTr("The typeface the desktop uses, how big it is, and how it is rendered.")

    property var families: []
    property var monoFamilies: []
    property bool probed: false

    Process {
        id: fontList
        running: false
        command: ["sh", "-c",
            'if command -v fc-list >/dev/null 2>&1; then '
          + '  fc-list : family 2>/dev/null; '
          + '  printf "\\037\\n"; '
          + '  fc-list :spacing=100 family 2>/dev/null; '
          + 'fi']

        stdout: StdioCollector {
            onStreamFinished: {
                var parts = String(this.text).split("");
                page.families = page._parse(parts[0] || "");
                page.monoFamilies = page._parse(parts[1] || "");
                page.probed = true;
            }
        }
    }

    function _parse(blob) {
        var seen = {};
        var out = [];
        var lines = blob.split("\n");
        for (var i = 0; i < lines.length; ++i) {
            var name = lines[i].split(",")[0].trim();
            if (name === "" || seen[name])
                continue;
            if (/awesome|emoji|symbols|icons|glyph|webdings|wingdings/i.test(name))
                continue;
            seen[name] = true;
            out.push({ value: name, label: name });
        }
        out.sort(function (a, b) { return a.label.localeCompare(b.label); });
        return out;
    }

    Component.onCompleted: fontList.running = true

    Process {
        id: applier
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                var m = String(this.text).trim();
                if (m !== "")
                    console.warn("Fonts: " + m);
            }
        }
    }

    readonly property string family: SettingsStore.stringValue("ui_font_family", "Inter")
    readonly property int    size:   SettingsStore.numberValue("ui_font_size", 11)
    readonly property string mono:   SettingsStore.stringValue("ui_font_mono", "JetBrainsMono Nerd Font")
    // TRK-3463: this was `ui_font_scale` — a SECOND spelling of `font_scale`,
    // the exact WIP-108 defect the Accessibility header documents. Both pages
    // wrote gsettings text-scaling-factor from their own key, so the last
    // page visited silently overwrote the other's scale and each then
    // reported a number the screen was not using. One key now, the one
    // Prefs.textScale and the schema (0.85–1.40, "outside that the type
    // blows up or vanishes") already own.
    readonly property real   textScale: SettingsStore.numberValue("font_scale", 1.0)
    readonly property bool   hinting: SettingsStore.boolValue("font_hinting", true)
    readonly property string rgba:   SettingsStore.stringValue("font_rgba", "rgb")

    function apply() {
        if (applier.running)
            return;
        applier.command = ["sh", "-c", `
            fam="$1"; sz="$2"; mono="$3"; scale="$4"; hint="$5"; rgba="$6"

            if command -v gsettings >/dev/null 2>&1; then
              iface=org.gnome.desktop.interface
              gsettings set $iface font-name "$fam $sz"            2>/dev/null || true
              gsettings set $iface document-font-name "$fam $sz"   2>/dev/null || true
              gsettings set $iface monospace-font-name "$mono $sz" 2>/dev/null || true
              gsettings set $iface text-scaling-factor "$scale"    2>/dev/null || true
              if [ "$hint" = "true" ]; then
                gsettings set $iface font-hinting slight 2>/dev/null || true
              else
                gsettings set $iface font-hinting none   2>/dev/null || true
              fi
              # ── audit-0908 · TRK-3974 ────────────────────────────────
              # This line was "font-antialiasing rgba", hardcoded, five lines
              # below a $hint branch that IS written correctly. The fontconfig
              # half below has always honoured the choice
              # (<const>$rgba</const>), so picking "Off" turned subpixel off
              # for Qt and fontconfig apps and left every GTK app on subpixel
              # RGB — the page showed one answer and the screen showed two.
              #
              # GTK splits what fontconfig keeps in one key: WHETHER subpixel
              # rendering is used (font-antialiasing) and WHICH ORDER the
              # stripes are in (font-rgba-order). So "off" is grayscale, NOT
              # "none" — "none" is no antialiasing at all, which is a
              # different setting this page does not offer and nobody asked
              # for. rgb and bgr are both subpixel and differ only in order.
              # GNOME 48+ `font-rendering=automatic` forces grayscale on
              # Wayland and ignores rgba. Manual is what lets subpixel land.
              gsettings set $iface font-rendering manual 2>/dev/null || true
              case "$rgba" in
                bgr)  gsettings set $iface font-antialiasing rgba      2>/dev/null || true
                      gsettings set $iface font-rgba-order  bgr        2>/dev/null || true ;;
                none) gsettings set $iface font-antialiasing grayscale 2>/dev/null || true ;;
                *)    gsettings set $iface font-antialiasing rgba      2>/dev/null || true
                      gsettings set $iface font-rgba-order  rgb        2>/dev/null || true ;;
              esac
            fi

            # Qt, read at application start. qt6ct and qt5ct keep the same key.
            for d in "$HOME/.config/qt6ct" "$HOME/.config/qt5ct"; do
              [ -d "$d" ] || continue
              f="$d/$(basename "$d").conf"
              [ -f "$f" ] || continue
              tmp="$f.nyxus.$$"
              # TRK-3454: the old program was "/^general=/ {next} {print}
              # END { }" — it DELETED the general= line and wrote nothing in
              # its place, so "applies to Qt apps on next start" was false and
              # every Apply stripped the user's Qt font config a little more.
              # This one drops the old line, writes the fresh value under the
              # [Fonts] header, and appends the section if the file lacks one.
              awk -v val="$fam,$sz,-1,5,50,0,0,0,0,0,Regular" '
                /^general=/ { next }
                { print }
                /^\\[Fonts\\]/ { infonts=1; print "general=\\"" val "\\"" }
                END { if (!infonts) { print "[Fonts]"; print "general=\\"" val "\\"" } }
              ' "$f" > "$tmp" 2>/dev/null && mv "$tmp" "$f"
            done

            # Rendering, for everything at once.
            mkdir -p "$HOME/.config/fontconfig"
            cat > "$HOME/.config/fontconfig/fonts.conf" <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<!-- Written by NYXUS Settings. Edit it there, not here. -->
<fontconfig>
  <match target="font">
    <edit name="antialias" mode="assign"><bool>true</bool></edit>
    <edit name="hinting" mode="assign"><bool>$hint</bool></edit>
    <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
    <edit name="rgba" mode="assign"><const>$rgba</const></edit>
    <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
    <edit name="embeddedbitmap" mode="assign"><bool>false</bool></edit>
  </match>
  <match target="pattern">
    <edit name="dpi" mode="assign"><double>96</double></edit>
  </match>
  <alias binding="same">
    <family>JetBrains Mono</family>
    <prefer><family>JetBrainsMono Nerd Font</family></prefer>
  </alias>
  <alias><family>sans-serif</family><prefer><family>$fam</family></prefer></alias>
  <alias><family>monospace</family><prefer><family>$mono</family></prefer></alias>
</fontconfig>
EOF
        `, "sh", page.family, String(page.size), page.mono,
           page.textScale.toFixed(2), page.hinting ? "true" : "false", page.rgba];
        applier.running = true;
    }

    Connections {
        target: SettingsStore
        function onCommitted(keys) {
            for (var i = 0; i < keys.length; ++i)
                if (String(keys[i]).indexOf("font") === 0
                        || String(keys[i]).indexOf("ui_font") === 0) {
                    page.apply();
                    return;
                }
        }
    }

    // ══ TYPEFACE ═══════════════════════════════════════════════════════
    SetCard {
        heading: qsTr("Typeface")
        tone: page.tone
        note: page.probed && page.families.length === 0
              ? "fontconfig returned no families. That normally means fc-list is "
                + "missing, not that the machine has no fonts."
              : "Applies to applications immediately. Qt applications pick it up "
                + "the next time they start."

        SetIceFace {
            kicker: qsTr("INTERFACE")
            caption: page.family
            detail: qsTr("Menus, labels and buttons across the desktop")
        }

        SetChoice {
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            key: "ui_font_family"
            defaultValue: "Inter"
            tone: page.tone
            segmentLimit: 0
            options: page.families
            emptyText: "Inter"
        }

        SetIceFace {
            kicker: qsTr("MONOSPACE")
            caption: page.mono
            detail: qsTr("Terminals, code, and anything that lines up in columns")
        }

        SetChoice {
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            key: "ui_font_mono"
            defaultValue: "JetBrainsMono Nerd Font"
            tone: page.tone
            segmentLimit: 0
            options: page.monoFamilies
            emptyText: "JetBrainsMono Nerd Font"
        }
    }

    // ══ SIZE ═══════════════════════════════════════════════════════════
    SetCard {
        heading: qsTr("Size")
        tone: page.tone
        note: qsTr("Text size and scale do the same job from two directions: size is ")
              + "the font itself, scale multiplies everything including spacing. "
              + "Move size first. The bar, Start menu and this window keep the "
              + "shell's own type until that theme file follows — the choice "
              + "here is saved as ui_font_family and font_scale — the same "
              + "scale Accessibility ▸ Text size moves."

        SetIceFace {
            kicker: qsTr("TEXT SIZE")
            reading: page.size + "pt"
            caption: qsTr("The base point size applications are asked to use")
            fillPct: Math.min(100, (page.size - 8) / (20 - 8) * 100)
        }

        SetSlider {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            key: "ui_font_size"
            tone: page.tone
            from: 8; to: 20; snap: 1; defaultValue: 11
            suffix: " pt"
        }

        SetIceFace {
            kicker: qsTr("SCALE")
            reading: Math.round(page.textScale * 100) + "%"
            caption: qsTr("Scales text and the space around it together, for readability rather than for taste")
            fillPct: Math.min(100, (page.textScale - 0.85) / (1.40 - 0.85) * 100)
        }

        SetSlider {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            // TRK-3463: `font_scale`, at the schema's own legal range —
            // 0.8–2.0 here used to save values the migration then clamped.
            key: "font_scale"
            tone: page.tone
            from: 0.85; to: 1.40; snap: 0.05; defaultValue: 1.0
            format: function (v) { return Math.round(v * 100) + "%"; }
        }

        SetIceFace {
            compact: true
            kicker: qsTr("PREVIEW")
            caption: qsTr("The quick brown fox jumps")
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s5
            Layout.rightMargin: Theme.s5
            text: qsTr("The quick brown fox jumps")
            color: Theme.text
            elide: Text.ElideRight
            font.family: page.family
            font.pixelSize: Math.round(page.size * 1.333 * page.textScale)
        }

        SetIceFace {
            compact: true
            kicker: qsTr("RE-APPLY")
            caption: qsTr("Writes the settings out again — useful after installing a new font")
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4

            SetButton {
                text: qsTr("Apply")
                glyph: ""
                tone: page.tone
                busy: applier.running
                onClicked: { fontList.running = true; page.apply(); }
            }
        }
    }

    // ══ RENDERING ══════════════════════════════════════════════════════
    SetCard {
        heading: qsTr("Rendering")
        tone: page.tone
        note: qsTr("Written to ~/.config/fontconfig/fonts.conf, which applies to every ")
              + "application on the machine."

        SetIceFace {
            property string key: "font_hinting"; property bool defaultValue: true
            compact: true
            kicker: qsTr("HINTING")
            reading: page.hinting ? qsTr("ON") : qsTr("OFF")
            caption: qsTr("Snaps letter shapes to the pixel grid. Sharper on low-resolution screens, slightly less faithful to the typeface.")
            selected: page.hinting
            interactive: true
            onActivated: SettingsStore.setValue("font_hinting", !page.hinting)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s3

            SetIceFace {
                property string key: "font_rgba"; property string defaultValue: "rgb"
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: "RGB"
                caption: qsTr("Almost always right")
                selected: page.rgba === "rgb"
                interactive: true
                onActivated: SettingsStore.setValue("font_rgba", "rgb")
            }
            SetIceFace {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: "BGR"
                selected: page.rgba === "bgr"
                interactive: true
                onActivated: SettingsStore.setValue("font_rgba", "bgr")
            }
            SetIceFace {
                Layout.fillWidth: true
                Layout.leftMargin: 0
                Layout.rightMargin: 0
                compact: true
                kicker: qsTr("OFF")
                caption: qsTr("No subpixel")
                selected: page.rgba === "none"
                interactive: true
                onActivated: SettingsStore.setValue("font_rgba", "none")
            }
        }
    }
}
