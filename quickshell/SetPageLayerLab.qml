pragma ComponentBehavior: Bound
// Layer lab — one page to look at every swirl dye on widgets, glass, and
// the living paint. Preview only. Glacier stays the house until you tap Wear.
import QtQuick
import QtQuick.Layouts

SetPage {
    id: page
    property var entry: null
    title: qsTr("Layer lab")
    blurb: qsTr("Same 7-stop ladder, different hues. Watch the bar, a widget, and a stone together. Wear one to try it; Glacier puts the house back.")

    // ── TRK-4161 · which card reads as WORN ─────────────────────────────
    // This was `Prefs.swirlPreview` alone, and on this machine that key sat
    // at "glacier" while look_set sat at "magma" — so the page insisted the
    // house ice dye was being worn while the entire desktop behind it was
    // ember. The keys had drifted apart because, before the fix in wear()
    // above, three of the five Wear buttons moved one without the other.
    //
    // MAGMA overrides the dye in Theme.paintRamp, so when it is on, the
    // worn dye IS magma no matter what the preview key remembers. Deriving
    // it here rather than repairing settings.json means every machine that
    // already drifted comes back into agreement on next launch, without a
    // migration.
    readonly property string wearing: Theme.lookMagma ? "magma" : Prefs.swirlPreview

    // rampOf paints the PREVIEW cards — each one captioned with the dye it
    // claims to show. So glacier resolves to paintPaleIce, which is built
    // from iceLayer and never remapped, rather than paintPaleGlacier, which
    // is magma when MAGMA is on. The live-paint strip above deliberately
    // does the opposite and reads Theme.paintRamp (TRK-4161).
    function rampOf(id) {
        if (id === "wine")
            return Theme.paintPaleWine;
        if (id === "rose" || id === "magma" || id === "violet")
            return Theme.paleFromLayer(id);
        return Theme.paintPaleIce;
    }

    // ── TRK-4161 · wearing a dye has to actually put it on ──────────────
    // Owner: "anything clicked on actually works and goes to what it should
    // go to." Two of the three ways to leave this function were broken.
    //
    // Theme.paintRamp opens with `if (lookMagma) return theme.lookLayer;`
    // and never consults Prefs.swirlPreview. Glacier and Magma were fine
    // here because they already moved look_set themselves. Rose, Violet and
    // Wine did not — so wearing one while MAGMA was on wrote the key, lit
    // the card, and left the bar exactly as ember as it was.
    //
    // Those three dyes only exist as pale ICE ladders (paleFromLayer walks
    // the glacier-family stops; paintPaleWine is hand-written ice-side art).
    // There is no MAGMA form of Wine to fall back to. So wearing one means
    // ICE, the same way wearing Magma means MAGMA — stated here rather than
    // left for the ramp to silently ignore.
    function wear(id) {
        SettingsStore.setValue("swirl_preview", id);
        if (id === "magma")
            SettingsStore.setValue("look_set", "magma");
        else
            SettingsStore.setValue("look_set", "ice");
        if (id !== "glacier")
            SettingsStore.setValue("swirl_mode", "paint");
    }

    SetCard {
        heading: qsTr("On the bar now")
        tone: page.tone
        note: qsTr("The strip is the living paint at this dye. Wear Magma also switches the complete look (ember rims and seams). Wear Glacier puts ice back.")

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 96
            radius: Theme.r2
            // Reads Theme.paintRamp, not rampOf(wearing). This card is headed
            // "On the bar now", and paintRamp is what the bar is painting —
            // rampOf() is what the dye WOULD be if the look allowed it. Under
            // MAGMA those two disagreed, so the one card whose whole job is
            // to show the truth was the one showing a colour that was not on
            // screen anywhere. Same value under ICE, where they agree.
            color: Theme.paintRamp[1]
            clip: true

            Swirl {
                anchors.fill: parent
                ramp: Theme.paintRamp
                alwaysAlive: true
                opaque: false
                clip: true
            }
        }
    }

    LayerLabCard {
        tone: page.tone
        layerId: "glacier"
        layerLabel: qsTr("Glacier")
        layerNote: qsTr("House ice")
        ramp: page.rampOf("glacier")
        wearing: page.wearing === "glacier"
        onWearRequested: function (id) { page.wear(id); }
    }
    LayerLabCard {
        tone: page.tone
        layerId: "rose"
        layerLabel: qsTr("Rose")
        layerNote: qsTr("Teal into plum — how the widgets got that colour")
        ramp: page.rampOf("rose")
        wearing: page.wearing === "rose"
        onWearRequested: function (id) { page.wear(id); }
    }
    LayerLabCard {
        tone: page.tone
        layerId: "magma"
        layerLabel: qsTr("Magma")
        layerNote: qsTr("Ember / what matters")
        ramp: page.rampOf("magma")
        wearing: page.wearing === "magma"
        onWearRequested: function (id) { page.wear(id); }
    }
    LayerLabCard {
        tone: page.tone
        layerId: "violet"
        layerLabel: qsTr("Violet")
        layerNote: qsTr("Orchid")
        ramp: page.rampOf("violet")
        wearing: page.wearing === "violet"
        onWearRequested: function (id) { page.wear(id); }
    }
    LayerLabCard {
        tone: page.tone
        layerId: "wine"
        layerLabel: qsTr("Wine")
        layerNote: qsTr("New dusty rose")
        ramp: page.rampOf("wine")
        wearing: page.wearing === "wine"
        onWearRequested: function (id) { page.wear(id); }
    }
}
