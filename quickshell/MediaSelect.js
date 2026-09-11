.pragma library

// Nyxus Suxyn — WHICH MPRIS player the shell shows, and WHETHER it shows
// anything at all. TRK-2600..TRK-2604.
//
// This is a pragma-library so it has no QML context and no imports, which is
// the point: `iso-builder/verify-profile.sh` gate 14b1 loads THIS FILE under
// `qml` and runs the real functions over a table of synthetic players, so the
// gate computes the shipped behaviour instead of grepping for a name. Keep it
// pure — a `Theme` or `Sys` reference here would make the gate impossible to
// run and it would quietly become a name check like the ones AGENTS.md bans.
//
// The rules, and why each one is not the obvious alternative:
//
//   TIER 1  playing AND titled   the ordinary case
//   TIER 2  playing, NO title    THE 2026-08-22 DEFECT. Chromium registers
//                                org.mpris.MediaPlayer2.chromium.instanceN
//                                the moment a media session starts but fills
//                                Metadata from the page's MediaSession API,
//                                so a page that never sets one plays with
//                                Metadata = {}. `playerctl -l` names it,
//                                `playerctl status` says Playing, and
//                                `playerctl metadata` fails. Dropping this
//                                tier is what made the whole media surface
//                                vanish while audio was audible.
//   TIER 3  titled, not playing  "paused is not gone" — the 2026-08-12
//                                supervisor ruling. The owner pausing is
//                                exactly when he wants the play button.
//   TIER 4  idle and untitled    selected so a caller can still ADDRESS it,
//                                but NOT enough to draw a surface — see
//                                `visibility` below. WIP-640(b) had already
//                                had to remove a strip that claimed the lock
//                                screen's height to say "Unknown track".
//
// AUDIBLE BEATS NAMEABLE. Tier 2 sits above tier 3 deliberately: with a
// paused, fully-tagged Spotify AND a nameless browser making noise, the card
// shows the browser. The surface's first duty is to let the owner STOP the
// sound — that is the complaint this whole row came from — and a paused
// player is not going to surprise anyone by staying off screen for a moment.
//
// Ties inside a tier go to the FIRST such player, which is the order the
// service reports; there is no better signal available and picking at random
// would make the surface flicker between two sources.

// `cands` is an array of { hasTitle: bool, playing: bool, control: bool }.
// Returns { index: int, tier: int } — index -1 / tier 0 when nothing at all
// is registered.
function classify(cands) {
    var playingTitled = -1;
    var titled = -1;
    var playingBare = -1;
    var idle = -1;

    for (var i = 0; i < cands.length; i++) {
        var c = cands[i];
        if (!c)
            continue;
        var hasTitle = c.hasTitle === true;
        var playing = c.playing === true;
        var control = c.control === true;
        if (playing && hasTitle) {
            if (playingTitled < 0)
                playingTitled = i;
        } else if (hasTitle) {
            if (titled < 0)
                titled = i;
        } else if (playing) {
            if (playingBare < 0)
                playingBare = i;
        } else if (control) {
            if (idle < 0)
                idle = i;
        }
    }

    if (playingTitled >= 0)
        return { index: playingTitled, tier: 1 };
    if (playingBare >= 0)
        return { index: playingBare, tier: 2 };
    if (titled >= 0)
        return { index: titled, tier: 3 };
    if (idle >= 0)
        return { index: idle, tier: 4 };
    return { index: -1, tier: 0 };
}

// What the surfaces do with the chosen player.
//
//   present            draw a surface at all. A track to NAME, or sound to
//                      SILENCE. NOT `hasTitle` (that is the reported defect)
//                      and NOT "a player is registered" (that is WIP-640(b)).
//   titleUnpublished   audible, and the source is not saying what it is —
//                      the surfaces word this instead of drawing a blank.
function visibility(hasTitle, playing) {
    var t = hasTitle === true;
    var p = playing === true;
    return {
        hasTrack: t,
        audible: p,
        present: t || p,
        titleUnpublished: p && !t
    };
}

// "chromium.instance4242" is a process id wearing a name badge. The owner
// should read "Chromium". Identity and desktop entry come first because a
// player that names itself is always better than a bus name.
function sourceLabel(identity, desktopEntry, dbusName) {
    if (identity && identity.length)
        return identity;
    if (desktopEntry && desktopEntry.length)
        return desktopEntry;
    var bus = dbusName || "";
    bus = bus.replace("org.mpris.MediaPlayer2.", "");
    var at = bus.indexOf(".instance");
    if (at > 0)
        bus = bus.substring(0, at);
    return bus;
}
