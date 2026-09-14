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

    readonly property string wearing: Prefs.swirlPreview

    function rampOf(id) {
        if (id === "wine")
            return Theme.paintPaleWine;
        if (id === "rose" || id === "magma" || id === "violet")
            return Theme.paleFromLayer(id);
        return Theme.paintPaleGlacier;
    }

    function wear(id) {
        SettingsStore.setValue("swirl_preview", id);
        if (id === "magma")
            SettingsStore.setValue("look_set", "magma");
        else if (id === "glacier")
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
            color: page.rampOf(page.wearing)[1]
            clip: true

            Swirl {
                anchors.fill: parent
                ramp: page.rampOf(page.wearing)
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
