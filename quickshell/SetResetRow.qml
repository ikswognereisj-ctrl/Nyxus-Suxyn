// Nyxus Suxyn — the RESET row. Every settings page that writes keys ends
// with one of these.                                               TRK-1261
//
//     SetResetRow {
//         what: "Feel"
//         keys: ["softpress_enabled", "softpress_material", "softpress_gain"]
//     }
//
// What it does, exactly: `SettingsStore.clearValues(keys)` — the keys are
// REMOVED from settings.json, in one write, so every one of them falls back
// to the shipped default. Not "written to the default": `SettingsStore`'s
// `clearValue()` header has the reason (a written default is a decision the
// user made, and a later change to the shipped default would never reach
// them). Nothing else in the file moves — not the GTK control center's
// sections, not another page's keys.
//
// Two taps, like every dangerous `SetButton`: the first arms it and the label
// says how many settings will go; the second does it. No dialogue. Since the
// 2026-08-24 ruling the button is MAGMA AT REST, so this row reads as
// destructive before the first tap rather than after it; arming is still a
// visible step up (see `SetButton.qml` for the measured ladder). The row
// counts what is actually SET on this page right now (a key absent from the
// file is already at its default), so the button is inert on a page that has
// nothing to reset and says so — a Reset that "does nothing" with no
// explanation is how a settings app looks broken.
//
// `keys` are TOP-LEVEL settings.json keys. A page that writes a nested object
// (Keep awake writes `power`) lists the object's key, and the whole object
// goes — that is the page's setting.
import QtQuick

SetRow {
    id: reset

    // The page's name, as the user sees it — "Feel", "Keep awake".
    property string what: "this page"
    // Every top-level key this page writes. Keep it in step with the page's
    // setValue / SetSlider `key:` calls; gate 13r81 checks that each listed
    // key is one the page really writes.
    property var keys: []

    // ── TRK-3746 · THE SIDE-EFFECT HOOK ──────────────────────────────────
    // Emitted AFTER `clearValues`, for the one case `clearValues` alone cannot
    // finish: a key whose writer does more than write it.
    //
    // `mark_theme` is the example and it is why this exists. Settings ▸
    // Appearance's theme stones call `applyTheme()`, which writes the key AND
    // runs `nyxus-sound set-theme`. Clearing the key returns every visual to
    // NYXUS and leaves the ALIEN sound stems playing — a half-reset, and the
    // page's own comment used to answer that by omitting the key from this row
    // entirely, which left "Reset Appearance" quietly not resetting the most
    // visible thing on the page.
    //
    // Note `applyTheme("nyxus")` cannot be the handler: it early-returns when
    // the theme already reads as nyxus, which after the clear it does. The
    // handler must re-assert the side effect directly.
    signal cleared()

    // How many of those keys are set in the file right now. Reads `doc` as a
    // whole so the binding follows every store change (the store reassigns
    // `doc` rather than mutating it — its header says why).
    readonly property int setCount: {
        var d = SettingsStore.doc;
        var n = 0;
        for (var i = 0; i < reset.keys.length; ++i)
            if (d && d[reset.keys[i]] !== undefined && d[reset.keys[i]] !== null)
                ++n;
        return n;
    }

    glyph: ""                                   // undo arrow
    title: "Reset " + reset.what
    sub: reset.setCount === 0
         ? "Everything on this page is already the shipped default."
         : (reset.setCount === 1 ? "One setting on this page is changed from the shipped default."
                                 : reset.setCount + " settings on this page are changed from the shipped default.")
           + " Reset removes them from settings.json; nothing else in the file moves."

    SetButton {
        text: qsTr("Reset")
        glyph: ""
        danger: true
        enabled: reset.setCount > 0
        confirmText: reset.setCount === 1 ? qsTr("Reset 1 setting")
                                          : "Reset " + reset.setCount + " settings"
        onClicked: {
            SettingsStore.clearValues(reset.keys);
            reset.cleared();
        }
    }
}
